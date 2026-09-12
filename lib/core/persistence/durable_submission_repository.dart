import 'dart:convert';
import 'dart:typed_data';

import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';

import 'durable_submission.dart';
import 'durable_submission_record.dart';
import 'durable_submission_review.dart';

export 'durable_submission.dart';
export 'durable_submission_record.dart' show DurableSubmissionRecordSchema;

/// Owns native submission transactions, never network dispatch. Controllers
/// must check mayDispatch and use exactly submission.envelopeJson under its
/// authenticated-origin protocol. No unavailable-store fallback is supported.
class DurableSubmissionRepository {
  DurableSubmissionRepository(
    this.isar, {
    DateTime Function()? now,
    String Function()? newClaimToken,
  }) : _now = now ?? DateTime.now,
       _newClaimToken = newClaimToken ?? const Uuid().v4;

  final Isar isar;
  final DateTime Function() _now;
  final String Function() _newClaimToken;
  static const supportedProtocols = <String>{
    'assetHierarchy.v2',
    'maintenanceWorkflow.v2',
    'chargeAbnormality.v2',
    'publishedTemplateAssignment.v2',
  };

  DateTime get _time => _now().toUtc();
  IsarCollection<DurableSubmissionRecord> get _rows =>
      isar.durableSubmissionRecords;

  Future<DurableSubmission> prepare(DurableSubmissionDraft draft) async {
    final immutable = draft.toImmutableMap();
    _validateImmutable(immutable);
    final raw = jsonEncode(immutable);
    final requestKey = _requestKey(draft.protocol, draft.requestId);
    return isar.writeTxn(() async {
      final existing = await _rows
          .where()
          .submissionIdEqualTo(draft.submissionId)
          .findFirst();
      if (existing != null) {
        final view = _view(existing);
        if (existing.immutableJson != raw) {
          _fail(
            'identity-conflict',
            'This submission already has different saved evidence. Nothing was replaced.',
          );
        }
        return view;
      }
      if (await _rows.where().requestKeyEqualTo(requestKey).findFirst() !=
          null) {
        _fail(
          'identity-conflict',
          'This request already belongs to another saved submission.',
        );
      }
      final pending = await _unresolvedForResource(draft.resourceKey);
      if (pending.isNotEmpty) {
        _fail(
          'resource-pending',
          'An earlier submission for this item still needs confirmation.',
          submissionId: pending.first.submissionId,
        );
      }
      final at = _time;
      final row = DurableSubmissionRecord()
        ..submissionId = draft.submissionId
        ..requestKey = requestKey
        ..resourceKey = draft.resourceKey
        ..actorUid = draft.actorUid
        ..immutableJson = raw
        ..immutableSha256 = durableSubmissionSha256(raw)
        ..createdAt = at
        ..updatedAt = at;
      _view(row);
      await _rows.put(row);
      return _view(row);
    });
  }

  Future<DurableSubmission?> read(String submissionId) async {
    final row = await _rows
        .where()
        .submissionIdEqualTo(submissionId)
        .findFirst();
    return row == null ? null : _view(row);
  }

  /// Contains original-actor data. Callers must gate disclosure by live account;
  /// another actor's pending owner still blocks creation of a replacement ID.
  Future<DurableSubmission?> findUnresolvedForResource(
    String resourceKey,
  ) async {
    final rows = await _unresolvedForResource(resourceKey);
    if (rows.length > 1) {
      _fail(
        'resource-conflict',
        'More than one saved submission claims this item. Evidence needs review.',
      );
    }
    return rows.isEmpty ? null : rows.single;
  }

  Future<DurableSubmission?> findUnresolved({
    required String actorUid,
    required String resourceKey,
  }) async {
    final value = await findUnresolvedForResource(resourceKey);
    return value?.actorUid == actorUid ? value : null;
  }

  Future<List<DurableSubmission>> listForActor(
    String actorUid, {
    bool includeTerminal = false,
  }) async {
    final rows = await _rows.where().actorUidEqualTo(actorUid).findAll();
    final values = rows
        .map(_view)
        .where((row) => includeTerminal || row.state.isUnresolved)
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return values;
  }

  Future<DurableSubmissionClaim> claim({
    required String submissionId,
    required String actorUid,
    Duration lease = const Duration(minutes: 5),
  }) {
    if (lease <= Duration.zero || lease > const Duration(hours: 1)) {
      throw ArgumentError.value(lease, 'lease');
    }
    return isar.writeTxn(() async {
      final row = await _required(submissionId);
      final view = _view(row);
      DurableSubmissionClaim stop(DurableSubmissionClaimDisposition value) =>
          DurableSubmissionClaim(disposition: value, submission: view);
      if (view.actorUid != actorUid || actorUid.trim().isEmpty) {
        return stop(DurableSubmissionClaimDisposition.actorMismatch);
      }
      if (view.state.isAccepted) {
        return stop(DurableSubmissionClaimDisposition.accepted);
      }
      if (view.state == DurableSubmissionState.needsReview ||
          view.state == DurableSubmissionState.reviewConflict ||
          view.isLegacy) {
        return stop(DurableSubmissionClaimDisposition.needsReview);
      }
      if (!view.state.isUnresolved) {
        return stop(DurableSubmissionClaimDisposition.terminal);
      }
      await _assertSoleOwner(view);
      final at = _time;
      if (row.claimExpiresAt?.isAfter(at) == true) {
        return stop(DurableSubmissionClaimDisposition.claimedElsewhere);
      }
      if (row.nextRetryAt?.isAfter(at) == true) {
        return stop(DurableSubmissionClaimDisposition.notDue);
      }
      final token = _newClaimToken();
      _text(token, 'claimToken');
      if (token == row.claimToken) {
        _fail('invalid-claim', 'A new claim needs a fresh token.');
      }
      row
        ..stateKey = DurableSubmissionState.sending.name
        ..claimToken = token
        ..claimExpiresAt = at.add(lease)
        ..nextRetryAt = null
        ..attemptCount += 1
        ..updatedAt = at;
      await _rows.put(row);
      return DurableSubmissionClaim(
        disposition: DurableSubmissionClaimDisposition.claimed,
        submission: _view(row),
        token: token,
      );
    });
  }

  Future<DurableSubmissionOutcome> recordOutcome(
    DurableSubmissionClaim claim, {
    required DurableSubmissionState state,
    required String message,
    String? errorCode,
    DateTime? nextRetryAt,
  }) {
    if (!claim.mayDispatch ||
        claim.token == null ||
        !const {
          DurableSubmissionState.uncertain,
          DurableSubmissionState.rejected,
          DurableSubmissionState.needsReview,
        }.contains(state)) {
      throw ArgumentError(
        'Only a dispatch claim can record an attempt outcome.',
      );
    }
    return isar.writeTxn(() async {
      final row = await _required(claim.submission.submissionId);
      final view = _view(row);
      _sameEnvelope(view, claim.submission.envelopeSha256);
      if (view.state.isAccepted) {
        return DurableSubmissionOutcome.alreadyAccepted;
      }
      if (row.claimToken != claim.token ||
          row.stateKey != 'sending' ||
          row.claimExpiresAt?.isAfter(_time) != true) {
        return DurableSubmissionOutcome.staleClaim;
      }
      row
        ..stateKey = state.name
        ..claimToken = null
        ..claimExpiresAt = null
        ..nextRetryAt = state == DurableSubmissionState.uncertain
            ? nextRetryAt?.toUtc()
            : null
        ..lastErrorCode = errorCode
        ..lastErrorMessage = message
        ..updatedAt = _time;
      _view(row);
      await _rows.put(row);
      return DurableSubmissionOutcome.recorded;
    });
  }

  /// Domain validation is synchronous and mandatory before any settlement.
  /// Accepted evidence for this immutable request can outlive its claim lease.
  /// Callers normalize observation-only receipt fields (for example a replay
  /// flag) before encoding; authoritative acceptance fields must stay intact.
  Future<DurableSubmission> settleAccepted({
    required String submissionId,
    required String envelopeSha256,
    required String receiptJson,
    required DurableReceiptValidator validateReceipt,
  }) async {
    final receipt = durableSubmissionJsonObject(receiptJson);
    return isar.writeTxn(() async {
      final row = await _required(submissionId);
      final view = _view(row);
      _sameEnvelope(view, envelopeSha256);
      if (view.isLegacy ||
          view.attemptCount == 0 ||
          !validateReceipt(view, receipt)) {
        _fail(
          'invalid-receipt',
          'The receipt does not validate this submitted request.',
        );
      }
      if (view.state.isAccepted) {
        if (row.receiptJson != receiptJson) {
          _fail(
            'acceptance-conflict',
            'A different acceptance is already retained. Both outcomes need review.',
          );
        }
        return view;
      }
      if (view.state == DurableSubmissionState.reviewResolved ||
          view.state == DurableSubmissionState.reviewConflict) {
        // Never erase a reviewed decision when a valid delayed reply arrives.
        // A contradictory outcome blocks this resource again for investigation.
        final history = durableSubmissionJsonObject(row.receiptJson!);
        final late = (history['lateAcceptances'] as List).toList();
        if (!late.any((item) => jsonEncode(item) == receiptJson)) {
          late.add(receipt);
        }
        final raw = jsonEncode({...history, 'lateAcceptances': late});
        row
          ..stateKey = DurableSubmissionState.reviewConflict.name
          ..receiptJson = raw
          ..receiptSha256 = durableSubmissionSha256(raw)
          ..updatedAt = _time
          ..lastErrorCode = 'acceptance-after-review'
          ..lastErrorMessage =
              'A late acceptance arrived after review. Both outcomes are retained; review this item before continuing.';
        await _rows.put(row);
        return _view(row);
      }
      final at = _time;
      row
        ..stateKey = DurableSubmissionState.acceptedPendingAdoption.name
        ..receiptJson = receiptJson
        ..receiptSha256 = durableSubmissionSha256(receiptJson)
        ..acceptedAt = at
        ..claimToken = null
        ..claimExpiresAt = null
        ..nextRetryAt = null
        ..lastErrorCode = null
        ..lastErrorMessage = null
        ..updatedAt = at;
      // A late valid response can supersede an earlier apparent refusal after
      // another intent was admitted. Retain acceptance and stop every other
      // unresolved owner; an already in-flight request cannot be unsent.
      final neighbours = await _rows
          .where()
          .resourceKeyEqualTo(row.resourceKey)
          .findAll();
      for (final other in neighbours) {
        if (other.submissionId == row.submissionId) continue;
        DurableSubmission otherView;
        try {
          otherView = _view(other);
        } on DurableSubmissionException {
          // Unreadable neighbouring evidence is not absence. Preserve its raw
          // bytes and this valid acceptance; later discovery fails closed.
          row
            ..lastErrorCode = 'resource-evidence-unreadable'
            ..lastErrorMessage =
                'Acceptance is saved, but other evidence for this item needs review.';
          continue;
        }
        if (!otherView.state.isUnresolved) continue;
        const message =
            'Acceptance is saved, but another submission for this item needs review. No further automatic action is permitted.';
        row
          ..lastErrorCode = 'resource-conflict'
          ..lastErrorMessage = message;
        other
          ..lastErrorCode = 'resource-conflict'
          ..lastErrorMessage = message
          ..updatedAt = at;
        if (!otherView.state.isAccepted &&
            otherView.state != DurableSubmissionState.reviewConflict) {
          other
            ..stateKey = DurableSubmissionState.needsReview.name
            ..claimToken = null
            ..claimExpiresAt = null
            ..nextRetryAt = null;
        }
        await _rows.put(other);
      }
      await _rows.put(row);
      return _view(row);
    });
  }

  /// The optional callback may make local Isar writes only. It executes in the
  /// same transaction as the reconciliation marker; throwing rolls both back.
  /// Server reads, actor checks and business validation happen before this call.
  Future<DurableSubmission> markReconciled({
    required String submissionId,
    required String envelopeSha256,
    required String receiptSha256,
    Future<void> Function(Isar transactionStore)? adoptInTransaction,
  }) {
    return isar.writeTxn(() async {
      final row = await _required(submissionId);
      final view = _view(row);
      _sameEnvelope(view, envelopeSha256);
      if (!view.state.isAccepted || row.receiptSha256 != receiptSha256) {
        _fail(
          'unconfirmed-acceptance',
          'Confirm the retained acceptance before reconciliation.',
        );
      }
      if (view.state == DurableSubmissionState.reconciled) return view;
      await _assertSoleOwner(view);
      await adoptInTransaction?.call(isar);
      row
        ..stateKey = DurableSubmissionState.reconciled.name
        ..reconciledAt = _time
        ..updatedAt = _time;
      await _rows.put(row);
      return _view(row);
    });
  }

  Future<DurableSubmission> cancelNeverSent({
    required String submissionId,
    required String actorUid,
  }) => isar.writeTxn(() async {
    final row = await _required(submissionId);
    final view = _view(row);
    if (view.actorUid != actorUid ||
        view.state != DurableSubmissionState.intent ||
        row.attemptCount != 0) {
      _fail(
        'cancellation-unproven',
        'This submission may have been sent. Its outcome must be confirmed first.',
      );
    }
    row
      ..stateKey = DurableSubmissionState.cancelledBeforeSend.name
      ..updatedAt = _time;
    await _rows.put(row);
    return _view(row);
  });

  /// Preserve legacy bytes even if they cannot be parsed or attributed. No
  /// imported row is dispatchable, and no current actor is invented for it.
  Future<DurableSubmission> importLegacyNeedsReview({
    required String submissionId,
    required String resourceKey,
    required String sourceKey,
    required Uint8List sourceBytes,
    String? actorUid,
    String requestId = 'unknown',
    String aggregateId = 'unknown',
  }) async {
    _text(sourceKey, 'sourceKey');
    if (sourceBytes.length > 524288) {
      _fail('invalid-data', 'Legacy evidence exceeds the supported size.');
    }
    final immutable = <String, dynamic>{
      'schemaVersion': 1,
      'submissionId': submissionId,
      'actorUid': actorUid,
      'requestId': requestId,
      'aggregateId': aggregateId,
      'resourceKey': resourceKey,
      'protocol': 'legacy.reviewOnly',
      'envelopeJson': '{}',
      'displayMetadataJson': null,
      'legacySourceKey': sourceKey,
      'legacySourceBase64': base64Encode(sourceBytes),
    };
    _validateImmutable(immutable);
    final raw = jsonEncode(immutable);
    return isar.writeTxn(() async {
      final key = _requestKey('legacy.reviewOnly', sourceKey);
      final byId = await _rows
          .where()
          .submissionIdEqualTo(submissionId)
          .findFirst();
      final bySource = await _rows.where().requestKeyEqualTo(key).findFirst();
      final existing = byId ?? bySource;
      if (existing != null) {
        final view = _view(existing);
        if (existing.immutableJson != raw) {
          _fail(
            'legacy-conflict',
            'Different evidence already owns this legacy source. Nothing was replaced.',
          );
        }
        return view;
      }
      final row = DurableSubmissionRecord()
        ..submissionId = submissionId
        ..requestKey = key
        ..resourceKey = resourceKey
        ..actorUid = actorUid
        ..immutableJson = raw
        ..immutableSha256 = durableSubmissionSha256(raw)
        ..stateKey = DurableSubmissionState.needsReview.name
        ..lastErrorMessage =
            'Legacy submission evidence requires review before any further action.'
        ..createdAt = _time
        ..updatedAt = _time;
      _view(row);
      await _rows.put(row);
      return _view(row);
    });
  }

  /// The caller supplies a fresh approved-admin guard; unknown legacy origins
  /// are visible only in this explicitly administrative local review surface.
  Future<List<DurableSubmission>> listForAdministrativeReview({
    required void Function() requireReviewer,
  }) async {
    requireReviewer();
    final rows = await _rows.where().findAll();
    requireReviewer();
    final result = rows.map(_view).toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return result;
  }

  Future<DurableSubmission> settleReview({
    required String submissionId,
    required String evidenceSha256,
    required String reviewerUid,
    required String decisionJson,
    required void Function() requireReviewer,
  }) async {
    final decision = durableSubmissionJsonObject(decisionJson);
    requireReviewer();
    return isar.writeTxn(() async {
      final row = await _required(submissionId);
      final view = _view(row);
      requireReviewer();
      if (view.reviewEvidenceSha256 != evidenceSha256) {
        _fail(
          'review-evidence-changed',
          'The original saved evidence changed. The hold remains.',
        );
      }
      validateDurableSubmissionReviewDecision(
        view,
        decision,
        reviewerUid: reviewerUid,
      );
      if (view.state.isAccepted) {
        _fail(
          'accepted-needs-adoption',
          'Acceptance arrived during review. Check and adopt that saved result first.',
        );
      }
      if (view.state == DurableSubmissionState.reviewConflict) {
        _fail(
          'review-conflict-investigation',
          'A late acceptance conflicts with an earlier review. Both outcomes require specialist investigation; an old decision cannot release this hold.',
        );
      }
      if (!view.state.isUnresolved &&
          view.state != DurableSubmissionState.reviewResolved) {
        _fail('already-terminal', 'This saved request is already resolved.');
      }
      final reviewed =
          view.state == DurableSubmissionState.reviewResolved ||
          view.state == DurableSubmissionState.reviewConflict;
      final history = reviewed
          ? durableSubmissionJsonObject(row.receiptJson!)
          : {
              'schemaVersion': 1,
              'kind': 'savedSubmissionReview',
              'decisions': <dynamic>[],
              'lateAcceptances': <dynamic>[],
            };
      final decisions = (history['decisions'] as List).toList();
      if (!decisions.any((item) => jsonEncode(item) == decisionJson)) {
        decisions.add(decision);
      }
      final proof = jsonEncode({...history, 'decisions': decisions});
      row
        ..stateKey = DurableSubmissionState.reviewResolved.name
        ..receiptJson = proof
        ..receiptSha256 = durableSubmissionSha256(proof)
        ..acceptedAt = null
        ..reconciledAt = null
        ..claimToken = null
        ..claimExpiresAt = null
        ..nextRetryAt = null
        ..updatedAt = _time
        ..lastErrorCode = 'review-resolved'
        ..lastErrorMessage =
            'An administrator reviewed this saved request. Original evidence and the server decision are retained.';
      _view(row);
      await _rows.put(row);
      requireReviewer();
      return _view(row);
    });
  }

  Future<List<DurableSubmission>> _unresolvedForResource(String key) async =>
      (await _rows.where().resourceKeyEqualTo(key).findAll())
          .map(_view)
          .where((row) => row.state.isUnresolved)
          .toList();

  Future<void> _assertSoleOwner(DurableSubmission view) async {
    final owners = await _unresolvedForResource(view.resourceKey);
    if (owners.length != 1 || owners.single.submissionId != view.submissionId) {
      _fail(
        'resource-conflict',
        'Saved submission ownership needs review. Nothing was sent.',
      );
    }
  }

  Future<DurableSubmissionRecord> _required(String id) async {
    final row = await _rows.where().submissionIdEqualTo(id).findFirst();
    if (row == null) {
      _fail(
        'missing-submission',
        'Saved submission evidence could not be found.',
      );
    }
    return row;
  }

  String _requestKey(String protocol, String id) =>
      durableSubmissionSha256(jsonEncode(<String>[protocol, id]));

  void _sameEnvelope(DurableSubmission view, String hash) {
    if (view.envelopeSha256 != hash) {
      _fail(
        'identity-conflict',
        'This outcome does not belong to the frozen submission.',
      );
    }
  }

  void _validateImmutable(Map<String, dynamic> data) {
    const keys = <String>{
      'schemaVersion',
      'submissionId',
      'actorUid',
      'requestId',
      'aggregateId',
      'resourceKey',
      'protocol',
      'envelopeJson',
      'displayMetadataJson',
      'legacySourceKey',
      'legacySourceBase64',
    };
    if (data.length != keys.length ||
        !data.keys.toSet().containsAll(keys) ||
        data['schemaVersion'] is! int ||
        data['schemaVersion'] != 1) {
      _fail('invalid-data', 'The saved submission schema needs review.');
    }
    for (final key in <String>[
      'submissionId',
      'requestId',
      'aggregateId',
      'resourceKey',
      'protocol',
    ]) {
      _text(data[key], key);
    }
    for (final key in <String>['submissionId', 'requestId', 'aggregateId']) {
      final value = data[key] as String;
      if (value == '.' ||
          value == '..' ||
          value.contains('/') ||
          utf8.encode(value).length > 1500) {
        _fail(
          'invalid-data',
          'Saved submission $key must be a single document ID.',
        );
      }
    }
    if (data['displayMetadataJson'] != null) {
      if (data['displayMetadataJson'] is! String) {
        _fail('invalid-data', 'Saved display evidence is invalid.');
      }
      durableSubmissionJsonObject(data['displayMetadataJson'] as String);
    }
    if (data['envelopeJson'] is! String) {
      _fail('invalid-data', 'The frozen request is missing.');
    }
    if (data['legacySourceKey'] != null) {
      _text(data['legacySourceKey'], 'legacySourceKey');
      if (data['actorUid'] != null) _text(data['actorUid'], 'actorUid');
      if (data['protocol'] != 'legacy.reviewOnly' ||
          data['legacySourceBase64'] is! String ||
          data['envelopeJson'] != '{}') {
        _fail('invalid-data', 'Legacy evidence cannot be dispatched.');
      }
      try {
        base64Decode(data['legacySourceBase64'] as String);
      } on FormatException {
        _fail('invalid-data', 'Legacy source bytes need review.');
      }
      return;
    }
    _text(data['actorUid'], 'actorUid');
    if (data['legacySourceBase64'] != null ||
        !supportedProtocols.contains(data['protocol'])) {
      _fail(
        'unsupported-protocol',
        'This saved protocol cannot be sent by this app.',
      );
    }
    final envelope = durableSubmissionJsonObject(
      data['envelopeJson'] as String,
    );
    final innerKey = data['protocol'] == 'maintenanceWorkflow.v2'
        ? 'command'
        : 'request';
    if (envelope.length != 3 ||
        envelope['protocolVersion'] is! int ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != data['actorUid'] ||
        envelope[innerKey] is! Map<String, dynamic>) {
      _fail(
        'invalid-protocol',
        'The frozen request does not prove its original account.',
      );
    }
    final inner = envelope[innerKey] as Map<String, dynamic>;
    final requestKey = innerKey == 'request' ? 'requestId' : 'commandId';
    final aggregateKey = aggregateIdentityKey(
      data['protocol'] as String,
      inner,
    );
    if (inner[requestKey] != data['requestId'] ||
        inner[aggregateKey] != data['aggregateId'] ||
        !validExpectedVersion(data['protocol'] as String, inner)) {
      _fail(
        'invalid-protocol',
        'The frozen request identities do not match its saved owner.',
      );
    }
  }

  /// Closed protocol routing shared by native storage and UI-only test doubles.
  /// Detailed operation-body and receipt validation belongs to domain adapters.
  static String aggregateIdentityKey(
    String protocol,
    Map<String, dynamic> inner,
  ) {
    if (protocol == 'maintenanceWorkflow.v2') return 'aggregateId';
    if (protocol == 'publishedTemplateAssignment.v2') return 'requestId';
    if (protocol == 'chargeAbnormality.v2') {
      if (inner['operation'] != 'CREATE_QUALITY_MONITORING_REQUEST' ||
          inner['expectedVersion'] != 0) {
        throw const DurableSubmissionException(
          'invalid-protocol',
          'The saved quality request has an unsupported operation or baseline.',
        );
      }
      return 'monitoringRequestId';
    }
    if (protocol == 'assetHierarchy.v2' &&
        const {
          'RECORD_BURNER_CONDITION_ROUND',
          'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
        }.contains(inner['operation'])) {
      return 'assetInstanceId';
    }
    if (protocol == 'assetHierarchy.v2' &&
        _morningReviewOperations.contains(inner['operation'])) {
      return const {
            'START_MORNING_REVIEW',
            'RECORD_MORNING_REVIEW_NOT_HELD',
          }.contains(inner['operation'])
          ? 'requestId'
          : 'sessionId';
    }
    return 'innerCoverId';
  }

  static const _morningReviewOperations = {
    'START_MORNING_REVIEW',
    'JOIN_MORNING_REVIEW',
    'ADD_MORNING_REVIEW_ENTRY',
    'CREATE_MORNING_REVIEW_ACTION',
    'ACCEPT_MORNING_REVIEW_ACTION',
    'COMPLETE_MORNING_REVIEW_ACTION',
    'TAKE_OVER_MORNING_REVIEW',
    'FINALIZE_MORNING_REVIEW',
    'RECORD_MORNING_REVIEW_NOT_HELD',
    'CREATE_MORNING_REVIEW_STANDING_CONCERN',
    'RESOLVE_MORNING_REVIEW_STANDING_CONCERN',
    'CHECK_MORNING_REVIEW_STANDING_CONCERN',
    'ADD_MORNING_REVIEW_ADDENDUM',
  };

  static bool validExpectedVersion(
    String protocol,
    Map<String, dynamic> inner,
  ) {
    if (protocol == 'assetHierarchy.v2' &&
        const {
          'RECORD_BURNER_CONDITION_ROUND',
          'COMPLETE_BURNER_RED_HOT_DIRECTIVE',
        }.contains(inner['operation'])) {
      bool positive(Object? value) =>
          value is int && value >= 1 && value <= 9007199254740991;
      return !inner.containsKey('expectedVersion') &&
          positive(inner['expectedAssetVersion']) &&
          (inner['operation'] != 'COMPLETE_BURNER_RED_HOT_DIRECTIVE' ||
              positive(inner['expectedDirectiveVersion']));
    }
    if (protocol == 'publishedTemplateAssignment.v2') {
      final value = inner['expectedVersionNumber'];
      return !inner.containsKey('expectedVersion') &&
          !inner.containsKey('operation') &&
          value is int &&
          value >= 1 &&
          value <= 9007199254740991;
    }
    var minimum = 0;
    if (protocol == 'assetHierarchy.v2' &&
        _morningReviewOperations.contains(inner['operation'])) {
      if (!const {
        'ACCEPT_MORNING_REVIEW_ACTION',
        'COMPLETE_MORNING_REVIEW_ACTION',
        'TAKE_OVER_MORNING_REVIEW',
        'FINALIZE_MORNING_REVIEW',
        'RESOLVE_MORNING_REVIEW_STANDING_CONCERN',
      }.contains(inner['operation'])) {
        return !inner.containsKey('expectedVersion');
      }
      minimum = 1;
    }
    final value = inner['expectedVersion'];
    return value is int && value >= minimum && value <= 9007199254740991;
  }

  DurableSubmission _view(DurableSubmissionRecord row) {
    if (durableSubmissionSha256(row.immutableJson) != row.immutableSha256) {
      _fail(
        'checksum-mismatch',
        'Saved submission evidence is damaged and has been preserved.',
      );
    }
    final data = durableSubmissionJsonObject(row.immutableJson);
    _validateImmutable(data);
    final legacy = data['legacySourceKey'] as String?;
    if (row.submissionId != data['submissionId'] ||
        row.resourceKey != data['resourceKey'] ||
        row.actorUid != data['actorUid'] ||
        row.requestKey !=
            _requestKey(
              data['protocol'] as String,
              legacy ?? data['requestId'] as String,
            )) {
      _fail(
        'identity-conflict',
        'Saved submission indexes do not match their evidence.',
      );
    }
    final states = DurableSubmissionState.values.where(
      (state) => state.name == row.stateKey,
    );
    if (states.length != 1) {
      _fail('invalid-state', 'The saved submission state needs review.');
    }
    final state = states.single;
    final reviewed =
        state == DurableSubmissionState.reviewResolved ||
        state == DurableSubmissionState.reviewConflict;
    if (row.attemptCount < 0 ||
        ((state == DurableSubmissionState.sending ||
                state == DurableSubmissionState.uncertain ||
                state.isAccepted) &&
            row.attemptCount == 0) ||
        row.createdAt.millisecondsSinceEpoch <= 0 ||
        row.updatedAt.isBefore(row.createdAt) ||
        ((state == DurableSubmissionState.sending) !=
            (row.claimToken != null && row.claimExpiresAt != null)) ||
        ((row.claimToken == null) != (row.claimExpiresAt == null)) ||
        ((row.receiptJson == null) != (row.receiptSha256 == null)) ||
        (!reviewed && (row.receiptJson == null) != (row.acceptedAt == null)) ||
        (reviewed && (row.receiptJson == null || row.acceptedAt != null)) ||
        (state.isAccepted !=
            (row.receiptJson != null &&
                row.receiptSha256 != null &&
                row.acceptedAt != null)) ||
        (state == DurableSubmissionState.reconciled) !=
            (row.reconciledAt != null) ||
        ((state == DurableSubmissionState.intent ||
                state == DurableSubmissionState.cancelledBeforeSend) &&
            row.attemptCount != 0) ||
        (legacy != null &&
            state != DurableSubmissionState.needsReview &&
            !reviewed)) {
      _fail(
        'invalid-state',
        'Saved submission outcome evidence is inconsistent and needs review.',
      );
    }
    if (row.receiptJson != null) {
      if (durableSubmissionSha256(row.receiptJson!) != row.receiptSha256) {
        _fail(
          'checksum-mismatch',
          'Saved acceptance evidence is damaged and has been preserved.',
        );
      }
      durableSubmissionJsonObject(row.receiptJson!);
    }
    final view = DurableSubmission(
      submissionId: row.submissionId,
      actorUid: row.actorUid,
      requestId: data['requestId'] as String,
      aggregateId: data['aggregateId'] as String,
      resourceKey: row.resourceKey,
      protocol: data['protocol'] as String,
      envelopeJson: data['envelopeJson'] as String,
      displayMetadataJson: data['displayMetadataJson'] as String?,
      state: state,
      attemptCount: row.attemptCount,
      createdAt: row.createdAt.toUtc(),
      updatedAt: row.updatedAt.toUtc(),
      claimToken: row.claimToken,
      claimExpiresAt: row.claimExpiresAt?.toUtc(),
      nextRetryAt: row.nextRetryAt?.toUtc(),
      receiptJson: row.receiptJson,
      receiptSha256: row.receiptSha256,
      lastErrorCode: row.lastErrorCode,
      lastErrorMessage: row.lastErrorMessage,
      legacySourceKey: legacy,
      legacySourceBase64: data['legacySourceBase64'] as String?,
    );
    if (reviewed) {
      validateDurableSubmissionReviewHistory(
        view,
        durableSubmissionJsonObject(row.receiptJson!),
      );
    }
    return view;
  }

  void _text(Object? value, String field) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.trim() != value ||
        value.length > 2048 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      _fail(
        'invalid-data',
        'Saved submission $field is invalid. Nothing was sent.',
      );
    }
  }

  Never _fail(String code, String message, {String? submissionId}) =>
      throw DurableSubmissionException(
        code,
        message,
        submissionId: submissionId,
      );
}
