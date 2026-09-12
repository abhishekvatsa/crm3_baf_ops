import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../data/quality_warning.dart';
import 'monitoring_creation_store.dart';
import 'quality_command_service.dart';

const qualityMonitoringV2CallableName = 'mutateChargeAbnormalityV2';

/// The native journal owns submission lifetime; the screen only requests checks.
/// A validated receipt is saved before reading the current monitoring record.
class QualityMonitoringSubmissionController
    implements QualityMonitoringCreation {
  QualityMonitoringSubmissionController({
    required this.store,
    required this.projectId,
    required this.requireActor,
    required this.requireCapability,
    required this.invoke,
    required this.readFromServer,
    MonitoringCreationStore? legacyStore,
    String Function()? newId,
  }) : legacyStore = legacyStore ?? MonitoringCreationStore(),
       newId = newId ?? const Uuid().v4;

  final DurableSubmissionRepository store;
  final String projectId;
  final AppUser Function() requireActor;
  final Future<void> Function(String uid) requireCapability;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) invoke;
  final Future<Map<String, dynamic>> Function(String id) readFromServer;
  final MonitoringCreationStore legacyStore;
  final String Function() newId;

  AppUser _actor([String? origin]) {
    final actor = requireActor();
    if (!actor.canManageQualityMonitoring ||
        (origin != null && actor.uid != origin)) {
      throw const QualityCommandException(
        'Return to the original approved quality manager account to check this submission.',
        code: 'account-unavailable',
      );
    }
    return actor;
  }

  String _resource(String uid) => 'qualityMonitoringCreation:$projectId:$uid';

  Future<DurableSubmission?> _pending(String uid) async {
    // Old preference records do not establish whether a request was accepted.
    // Preserve their bytes and block replacement; never turn them into V2 sends.
    for (final evidence in await legacyStore.legacyEvidence(
      '$projectId:$uid',
    )) {
      await store.importLegacyNeedsReview(
        submissionId: 'legacy-quality-${durableSubmissionSha256(evidence.key)}',
        resourceKey: _resource(uid),
        sourceKey: evidence.key,
        sourceBytes: evidence.bytes,
      );
    }
    _actor(uid);
    final saved = await store.findUnresolvedForResource(_resource(uid));
    _actor(uid);
    if (saved != null && saved.isLegacy) {
      throw const QualityCommandException(
        'An earlier monitoring submission needs review. Its original evidence is saved; a replacement has not been created.',
        code: 'legacy-needs-review',
      );
    }
    if (saved != null) _request(saved);
    return saved;
  }

  Map<String, dynamic> _request(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final raw = envelope['request'];
    if (saved.protocol != 'chargeAbnormality.v2' ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        raw is! Map) {
      throw const QualityCommandException(
        'Saved monitoring evidence needs review.',
      );
    }
    final request = Map<String, dynamic>.from(raw);
    MonitoringCreationStore.validateSavedRequest({
      'schemaVersion': 2,
      ...request,
    });
    if (request['requestId'] != saved.requestId ||
        request['monitoringRequestId'] != saved.aggregateId ||
        saved.resourceKey != _resource(saved.actorUid!)) {
      throw const QualityCommandException(
        'Saved monitoring identities do not agree.',
      );
    }
    return request;
  }

  @override
  Future<Map<String, dynamic>?> pending() async {
    final actor = _actor();
    final saved = await _pending(actor.uid);
    return saved == null
        ? null
        : {
            ..._request(saved),
            'savedSubmissionState': saved.state.name,
            'canCancelBeforeSend':
                saved.state == DurableSubmissionState.intent &&
                saved.attemptCount == 0,
          };
  }

  @override
  Future<QualityCommandResult> create(Map<String, dynamic> payload) async {
    final actor = _actor();
    final previous = await _pending(actor.uid);
    if (previous != null) {
      final request = _request(previous);
      if (payload.entries.any(
        (entry) => entry.value is List
            ? request[entry.key] is! List ||
                  !listEquals(request[entry.key] as List, entry.value as List)
            : request[entry.key] != entry.value,
      )) {
        throw const QualityCommandException(
          'Confirm the saved monitoring submission before changing its entries or creating another.',
        );
      }
      return check(previous.submissionId);
    }
    final request = <String, dynamic>{
      'requestId': newId(),
      'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
      'monitoringRequestId': newId(),
      'expectedVersion': 0,
      ...payload,
    };
    MonitoringCreationStore.validateSavedRequest({
      'schemaVersion': 2,
      ...request,
    });
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: request['requestId'] as String,
        actorUid: actor.uid,
        requestId: request['requestId'] as String,
        aggregateId: request['monitoringRequestId'] as String,
        resourceKey: _resource(actor.uid),
        protocol: 'chargeAbnormality.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor.uid,
          'request': request,
        }),
      ),
    );
    _actor(actor.uid);
    return check(saved.submissionId);
  }

  @override
  Future<QualityCommandResult> retry() async {
    final actor = _actor();
    final saved = await _pending(actor.uid);
    if (saved == null) {
      throw const QualityCommandException(
        'No saved monitoring submission was found.',
      );
    }
    return check(saved.submissionId);
  }

  @override
  Future<void> cancelNeverSent() async {
    final actor = _actor();
    final saved = await _pending(actor.uid);
    if (saved == null) return;
    await store.cancelNeverSent(
      submissionId: saved.submissionId,
      actorUid: actor.uid,
    );
    _actor(actor.uid);
  }

  Future<QualityCommandResult> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const QualityCommandException(
        'Saved monitoring was not found. Nothing was sent.',
      );
    }
    _request(saved);
    _actor(saved.actorUid);
    if (saved.state.isAccepted) return _reconcile(saved);
    await requireCapability(saved.actorUid!);
    _actor(saved.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: saved.actorUid!,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcile(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const QualityCommandException(
        'This monitoring submission is already being checked or needs review. Its original entries remain saved.',
      );
    }
    final Map<String, dynamic> raw;
    try {
      _actor(saved.actorUid);
      raw = await invoke(durableSubmissionJsonObject(saved.envelopeJson));
      _receipt(saved, raw);
    } catch (_) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            'The monitoring outcome is not confirmed. Check the saved request.',
        errorCode: 'monitoring-outcome-uncertain',
      );
      throw const QualityCommandException(
        'The monitoring outcome is not confirmed. Its original entries are saved on this device; check them again.',
      );
    }
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: jsonEncode({...raw, 'idempotentReplay': false}),
      validateReceipt: (retained, response) {
        _receipt(retained, response);
        return true;
      },
    );
    return _reconcile(accepted);
  }

  QualityCommandResult _receipt(
    DurableSubmission saved,
    Map<String, dynamic> response,
  ) {
    final request = _request(saved);
    final result = QualityCommandResult.fromMap(
      response,
      expectedRequestId: saved.requestId,
      expectedOperation: QualityCommandOperation.createMonitoringRequest,
      expectedEntityId: saved.aggregateId,
      expectedVersion: 0,
    );
    final entity = result.monitoringRequest!;
    if (!_sameCreation(entity, request, saved.actorUid!) ||
        entity.status != QualityMonitoringStatus.active ||
        entity.updatedByUid != saved.actorUid ||
        !entity.createdAt.isAtSameMomentAs(result.committedAt)) {
      throw const QualityCommandException(
        'The monitoring receipt does not match the saved entries.',
      );
    }
    return result;
  }

  bool _sameCreation(
    QualityMonitoringRequest entity,
    Map<String, dynamic> request,
    String uid,
  ) {
    final charges = List<int>.from(request['chargeNumbers'] as List)..sort();
    return entity.requestId == request['monitoringRequestId'] &&
        entity.createdByUid == uid &&
        entity.baseNumber == request['baseNumber'] &&
        entity.baseAssetClassId ==
            (request['baseAssetClassId'] as String).trim() &&
        entity.baseAssetInstanceId ==
            (request['baseAssetInstanceId'] as String).trim() &&
        entity.baseAssetInstanceVersion ==
            request['baseAssetInstanceVersion'] &&
        entity.grade == (request['grade'] as String).trim() &&
        entity.cycleReference == (request['cycleReference'] as String).trim() &&
        entity.reason == (request['reason'] as String).trim() &&
        listEquals(entity.chargeNumbers, charges);
  }

  Future<QualityCommandResult> _reconcile(DurableSubmission saved) async {
    _actor(saved.actorUid);
    final result = _receipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    final Map<String, dynamic> currentRaw;
    try {
      currentRaw = await readFromServer(saved.aggregateId);
    } catch (_) {
      throw const QualityCommandException(
        'Monitoring was recorded and its receipt is saved. The current record could not be checked; check again without sending creation again.',
      );
    }
    final current = QualityMonitoringRequest.fromMap(
      currentRaw,
      saved.aggregateId,
    );
    if (current.version < result.version ||
        !_sameCreation(current, _request(saved), saved.actorUid!) ||
        !current.createdAt.isAtSameMomentAs(result.committedAt) ||
        (current.version == result.version &&
            (currentRaw['lastMutationId'] != saved.requestId ||
                current.status != QualityMonitoringStatus.active ||
                current.updatedByUid != saved.actorUid ||
                !current.updatedAt.isAtSameMomentAs(result.committedAt)))) {
      throw const QualityCommandException(
        'Monitoring was recorded, but the current record disagrees with its receipt. The evidence is saved for review.',
      );
    }
    _actor(saved.actorUid);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid);
    return result;
  }
}
