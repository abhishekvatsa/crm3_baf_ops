import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';

import '../../auth/data/user_model.dart';
import '../data/operational_event.dart';
import '../data/operational_event_interval_amendment.dart';
import 'operational_event_service.dart';

const operationalEventAmendmentOperation = 'AMEND_OPERATIONAL_EVENT_INTERVAL';
const operationalEventAmendmentCapability =
    'operationalEventIntervalAmendment.v1';

class OperationalEventAmendmentReview {
  const OperationalEventAmendmentReview({
    required this.event,
    required this.occurrenceIndex,
    required this.originalIntervalJson,
    this.history = const [],
  });
  final OperationalEvent event;
  final int occurrenceIndex;
  final String originalIntervalJson;
  final List<OperationalEventIntervalAmendment> history;
  OperationalEventInterval get original =>
      event.closedOccurrence(occurrenceIndex)!;
  OperationalEventIntervalAmendment? get amendment =>
      event.intervalEndAmendments[occurrenceIndex];
  DateTime get effectiveEnd =>
      amendment?.correctedResolvedAt ?? original.resolvedAt;
  DateTime? get nextStart => occurrenceIndex < event.currentOccurrenceIndex
      ? (occurrenceIndex + 1 < event.currentOccurrenceIndex
            ? event.completedIntervals[occurrenceIndex + 1].startedAt
            : event.startedAt)
      : null;
}

class OperationalEventAmendmentReceipt {
  const OperationalEventAmendmentReceipt(this.result, this.data);
  final OperationalEventCommandResult result;
  final Map<String, dynamic> data;
  String get amendmentId => data['amendmentId'] as String;

  factory OperationalEventAmendmentReceipt.fromMap(
    Map<String, dynamic> data,
    Map<String, dynamic> request,
  ) {
    const fields = {
      'ok',
      'requestId',
      'operation',
      'eventId',
      'status',
      'version',
      'auditId',
      'committedAt',
      'idempotentReplay',
      'amendmentId',
      'occurrenceIndex',
      'correctedResolvedAt',
      'supersedesAmendmentId',
      'amendmentEvidenceDigest',
    };
    if (data.length != fields.length || !fields.every(data.containsKey)) {
      throw const OperationalEventCommandException(
        'The amendment receipt contains missing or unsupported evidence.',
        code: 'data-loss',
      );
    }
    final result = OperationalEventCommandResult.fromMap(
      data,
      expectedRequestId: request['requestId'] as String,
      expectedOperation: OperationalEventCommand.amendInterval,
      expectedEventId: request['eventId'] as String,
    );
    readOperationalAmendmentInstant(
      data['committedAt'],
      field: 'committedAt',
      source: 'amendment receipt',
    );
    final amendment = request['intervalAmendment'] as Map<String, dynamic>;
    final digest = data['amendmentEvidenceDigest'];
    if (data['occurrenceIndex'] is! int ||
        result.version != (request['expectedVersion'] as int) + 1 ||
        data['amendmentId'] != request['requestId'] ||
        data['occurrenceIndex'] != amendment['occurrenceIndex'] ||
        data['supersedesAmendmentId'] != amendment['supersedesAmendmentId'] ||
        !readOperationalAmendmentInstant(
          data['correctedResolvedAt'],
          field: 'correctedResolvedAt',
          source: 'amendment receipt',
        ).isAtSameMomentAs(
          readOperationalAmendmentInstant(
            amendment['correctedResolvedAt'],
            field: 'correctedResolvedAt',
            source: 'saved amendment',
          ),
        ) ||
        digest is! String ||
        !RegExp(
          r'^operational-interval-amendment-v1-sha256:[0-9a-f]{64}$',
        ).hasMatch(digest)) {
      throw const OperationalEventCommandException(
        'The amendment receipt disagrees with the saved request. Keep its evidence for review.',
        code: 'data-loss',
      );
    }
    return OperationalEventAmendmentReceipt(result, Map.unmodifiable(data));
  }
}

/// Native ownership is established before the first dispatch. Recovery uses the
/// same envelope and original account; no retry reconstructs the amendment.
class OperationalEventAmendmentService {
  const OperationalEventAmendmentService({
    required this.store,
    required this.invoke,
    required this.requireActor,
    required this.requireCapability,
    required this.confirmReadback,
  });
  final DurableSubmissionRepository store;
  final Future<Map<String, dynamic>> Function(String envelope) invoke;
  final AppUser Function() requireActor;
  final Future<void> Function(String uid) requireCapability;
  final Future<void> Function(
    DurableSubmission saved,
    OperationalEventAmendmentReceipt receipt,
  )
  confirmReadback;

  static String resource(String eventId, int index) =>
      'operationalEventAmendment:$eventId:$index';

  String _actor([String? originalUid]) {
    final actor = requireActor();
    if (!actor.isApproved ||
        !(actor.isAdmin || actor.isSI) ||
        (originalUid != null && actor.uid != originalUid)) {
      throw const OperationalEventCommandException(
        'Return to the approved Admin or SI account that saved this amendment.',
        code: 'unauthenticated',
      );
    }
    return actor.uid;
  }

  Future<DurableSubmission?> pending(String eventId, int index) async {
    final uid = _actor();
    final saved = await store.findUnresolvedForResource(
      resource(eventId, index),
    );
    _actor(uid);
    if (saved == null) return null;
    _actor(saved.actorUid);
    _request(saved);
    return saved;
  }

  Future<OperationalEventAmendmentReceipt> submit({
    required OperationalEventAmendmentReview review,
    required DateTime correctedResolvedAt,
    required String reason,
  }) async {
    final uid = _actor();
    final corrected = correctedResolvedAt.toUtc();
    if (!review.event.isEffective ||
        corrected.isBefore(review.original.startedAt) ||
        corrected.isAfter(DateTime.now()) ||
        (review.nextStart != null && corrected.isAfter(review.nextStart!)) ||
        corrected.isAtSameMomentAs(review.effectiveEnd) ||
        corrected.microsecond != 0 ||
        reason.trim().isEmpty ||
        reason.trim().length > 1000) {
      throw const OperationalEventCommandException(
        'Choose a changed, verified closure time within this occurrence and explain the amendment.',
        code: 'invalid-argument',
      );
    }
    final id = const Uuid().v4();
    final request = <String, dynamic>{
      'requestId': id,
      'operation': operationalEventAmendmentOperation,
      'eventId': review.event.eventId,
      'expectedVersion': review.event.version,
      'reason': reason.trim(),
      'intervalAmendment': {
        'occurrenceIndex': review.occurrenceIndex,
        'expectedEffectiveResolvedAt': review.effectiveEnd
            .toUtc()
            .toIso8601String(),
        'correctedResolvedAt': corrected.toIso8601String(),
        'supersedesAmendmentId': review.amendment?.amendmentId,
      },
    };
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: id,
        actorUid: uid,
        requestId: id,
        aggregateId: review.event.eventId,
        resourceKey: resource(review.event.eventId, review.occurrenceIndex),
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': uid,
          'request': request,
        }),
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'eventTitle': review.event.title,
          'originalIntervalJson': review.originalIntervalJson,
        }),
      ),
    );
    _actor(uid);
    return resume(saved.submissionId);
  }

  static Map<String, dynamic> requestFor(DurableSubmission saved) =>
      _request(saved);

  static Map<String, dynamic> _request(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final raw = envelope['request'];
    if (saved.protocol != 'assetHierarchy.v2' ||
        saved.actorUid == null ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        raw is! Map<String, dynamic> ||
        raw.length != 6 ||
        raw['operation'] != operationalEventAmendmentOperation ||
        raw['requestId'] != saved.requestId ||
        raw['eventId'] != saved.aggregateId ||
        !operationalEventAmendmentIdPattern.hasMatch(saved.requestId) ||
        raw['expectedVersion'] is! int ||
        (raw['expectedVersion'] as int) < 1 ||
        raw['reason'] is! String ||
        (raw['reason'] as String).trim().isEmpty ||
        (raw['reason'] as String).length > 1000 ||
        raw['reason'] != (raw['reason'] as String).trim() ||
        raw['intervalAmendment'] is! Map<String, dynamic>) {
      throw const OperationalEventCommandException(
        'The saved amendment needs review before it can be checked.',
        code: 'data-loss',
      );
    }
    final amendment = raw['intervalAmendment'] as Map<String, dynamic>;
    final index = amendment['occurrenceIndex'];
    final prior = amendment['supersedesAmendmentId'];
    if (amendment.length != 4 ||
        index is! int ||
        index < 0 ||
        index > 100 ||
        saved.resourceKey != resource(saved.aggregateId, index) ||
        (prior != null &&
            (prior is! String ||
                !operationalEventAmendmentIdPattern.hasMatch(prior)))) {
      throw const OperationalEventCommandException(
        'The saved amendment does not identify one original occurrence.',
        code: 'data-loss',
      );
    }
    for (final field in const [
      'expectedEffectiveResolvedAt',
      'correctedResolvedAt',
    ]) {
      readOperationalAmendmentInstant(
        amendment[field],
        field: field,
        source: 'saved amendment',
      );
    }
    final metadata = durableSubmissionJsonObject(
      saved.displayMetadataJson ?? '{}',
    );
    if (metadata['schemaVersion'] != 1 ||
        metadata['originalIntervalJson'] is! String) {
      throw const OperationalEventCommandException(
        'The original closure evidence is missing from the saved amendment.',
        code: 'data-loss',
      );
    }
    durableSubmissionJsonObject(metadata['originalIntervalJson'] as String);
    return raw;
  }

  Future<OperationalEventAmendmentReceipt> resume(String submissionId) async {
    final uid = _actor();
    final saved = await store.read(submissionId);
    _actor(uid);
    if (saved == null) {
      throw const OperationalEventCommandException(
        'The original saved amendment could not be found. Nothing was sent.',
      );
    }
    _actor(saved.actorUid);
    final request = _request(saved);
    if (saved.state.isAccepted) return _adopt(saved);
    await requireCapability(uid);
    _actor(uid);
    final claim = await store.claim(submissionId: submissionId, actorUid: uid);
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adopt(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const OperationalEventCommandException(
        'This amendment is already being checked or needs review. Its request remains saved.',
      );
    }
    try {
      _actor(uid);
      final raw = await invoke(saved.envelopeJson);
      final receipt = OperationalEventAmendmentReceipt.fromMap(raw, request);
      final accepted = await store.settleAccepted(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptJson: jsonEncode(receipt.data),
        validateReceipt: (row, data) {
          OperationalEventAmendmentReceipt.fromMap(data, _request(row));
          return true;
        },
      );
      return _adopt(accepted);
    } catch (error) {
      final details = error is OperationalEventCommandException
          ? error.details
          : null;
      final reason = details is Map ? details['reasonCode'] : null;
      final refused =
          claim.submission.attemptCount == 1 &&
          const {
            'operational-interval-amendment-stale',
            'operational-interval-amendment-no-change',
            'operational-interval-amendment-chronology',
            'operational-event-version-mismatch',
          }.contains(reason);
      final outcome = await store.recordOutcome(
        claim,
        state: refused
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        errorCode: error is OperationalEventCommandException
            ? error.code ?? 'unconfirmed'
            : 'unconfirmed',
        message:
            'The amendment remains saved. Check the same original request before submitting another amendment.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(submissionId);
        if (accepted != null) return _adopt(accepted);
      }
      rethrow;
    }
  }

  Future<OperationalEventAmendmentReceipt> _adopt(
    DurableSubmission saved,
  ) async {
    _actor(saved.actorUid);
    if (!saved.state.isAccepted ||
        saved.receiptJson == null ||
        saved.receiptSha256 == null) {
      throw const OperationalEventCommandException(
        'The saved amendment has no confirmed acceptance.',
      );
    }
    final receipt = OperationalEventAmendmentReceipt.fromMap(
      durableSubmissionJsonObject(saved.receiptJson!),
      _request(saved),
    );
    await confirmReadback(saved, receipt);
    _actor(saved.actorUid);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid);
    return receipt;
  }
}
