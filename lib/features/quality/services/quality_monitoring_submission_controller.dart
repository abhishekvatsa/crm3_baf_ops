import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
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
    implements
        QualityMonitoringCreation,
        QualityMonitoringClosure,
        QualityMonitoringReview {
  QualityMonitoringSubmissionController({
    required this.store,
    required this.projectId,
    required this.requireActor,
    required this.requireCapability,
    this.requireReviewCapability,
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
  final Future<void> Function(String uid)? requireReviewCapability;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) invoke;
  final Future<Map<String, dynamic>> Function(String id) readFromServer;
  final MonitoringCreationStore legacyStore;
  final String Function() newId;

  AppUser _actor([String? origin, bool readOnlyAcceptance = false]) {
    final actor = requireActor();
    if (!actor.isApproved ||
        (!readOnlyAcceptance && !actor.canManageQualityMonitoring) ||
        (origin != null && actor.uid != origin)) {
      throw const QualityCommandException(
        'Return to the original approved quality manager account to check this submission.',
        code: 'account-unavailable',
      );
    }
    return actor;
  }

  String _resource(String uid) => 'qualityMonitoringCreation:$projectId:$uid';

  String _closureResource(String uid, String monitoringRequestId) =>
      'qualityMonitoringClosure:$projectId:$monitoringRequestId:$uid';

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
            'savedReasonCode': saved.lastErrorCode,
            'savedExplanation': saved.lastErrorMessage,
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

  Map<String, dynamic> _closeRequest(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final raw = envelope['request'];
    if (saved.protocol != 'chargeAbnormality.v2' ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        raw is! Map) {
      throw const QualityCommandException(
        'Saved monitoring closure needs review.',
      );
    }
    final request = Map<String, dynamic>.from(raw);
    if (!_isReviewShape(request) ||
        request['requestId'] != saved.requestId ||
        request['monitoringRequestId'] != saved.aggregateId ||
        request['expectedVersion'] is! int ||
        (request['expectedVersion'] as int) < 1 ||
        request['reason'] is! String ||
        (request['reason'] as String).trim().isEmpty ||
        (request['reason'] as String).length > 2000 ||
        saved.resourceKey !=
            _closureResource(saved.actorUid!, saved.aggregateId)) {
      throw const QualityCommandException(
        'Saved monitoring closure identities need review.',
      );
    }
    return request;
  }

  @override
  Future<QualityCommandResult> closeMonitoringRequest({
    required QualityMonitoringRequest request,
    required String reason,
  }) async {
    return reviewMonitoring(
      request: request,
      operation: QualityCommandOperation.closeMonitoringRequest,
      payload: {'reason': reason},
    );
  }

  @override
  Future<QualityCommandResult> reviewMonitoring({
    required QualityMonitoringRequest request,
    required QualityCommandOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    if (!{
      QualityCommandOperation.closeMonitoringRequest,
      QualityCommandOperation.cancelMonitoringRequest,
      QualityCommandOperation.correctMonitoringRequest,
    }.contains(operation)) {
      throw const FormatException('Unsupported monitoring change.');
    }
    if (payload.keys.any(
      (key) => {
        'requestId',
        'operation',
        'monitoringRequestId',
        'expectedVersion',
      }.contains(key),
    )) {
      throw const FormatException(
        'Monitoring identity is owned by the journal.',
      );
    }
    final actor = _actor();
    final resource = _closureResource(actor.uid, request.requestId);
    final existing = await store.findUnresolvedForResource(resource);
    if (existing != null) {
      final savedRequest = _closeRequest(existing);
      if (savedRequest['expectedVersion'] != request.version ||
          savedRequest['operation'] != operation.wireName ||
          !payload.entries.every(
            (entry) =>
                jsonEncode(savedRequest[entry.key]) == jsonEncode(entry.value),
          )) {
        throw const QualityCommandException(
          'Confirm the saved monitoring closure before changing its reason or version.',
        );
      }
      return _checkClose(existing.submissionId);
    }
    final closeRequest = <String, dynamic>{
      'requestId': newId(),
      'operation': operation.wireName,
      'monitoringRequestId': request.requestId,
      'expectedVersion': request.version,
      ...payload,
    };
    _closeRequestShape(closeRequest);
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: closeRequest['requestId'] as String,
        actorUid: actor.uid,
        requestId: closeRequest['requestId'] as String,
        aggregateId: request.requestId,
        resourceKey: resource,
        protocol: 'chargeAbnormality.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor.uid,
          'request': closeRequest,
        }),
      ),
    );
    _actor(actor.uid);
    return _checkClose(saved.submissionId);
  }

  bool _isReviewShape(Map<String, dynamic> request) {
    if (request['operation'] == 'CORRECT_QUALITY_MONITORING_REQUEST') {
      try {
        MonitoringCreationStore.validateSavedRequest({
          'schemaVersion': 2,
          ...request,
          'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
          'expectedVersion': 0,
        });
        return true;
      } catch (_) {
        return false;
      }
    }
    return request.keys.toSet().difference({
          'requestId',
          'operation',
          'monitoringRequestId',
          'expectedVersion',
          'reason',
        }).isEmpty &&
        request.length == 5 &&
        {
          'CLOSE_QUALITY_MONITORING_REQUEST',
          'CANCEL_QUALITY_MONITORING_REQUEST',
        }.contains(request['operation']);
  }

  @override
  Future<QualityCommandResult> checkSavedChange(
    String monitoringRequestId,
  ) async {
    final actor = _actor(null, true);
    final saved = await store.findUnresolvedForResource(
      _closureResource(actor.uid, monitoringRequestId),
    );
    if (saved == null) {
      throw const QualityCommandException(
        'No saved monitoring change needs confirmation.',
      );
    }
    return _checkClose(saved.submissionId);
  }

  void _closeRequestShape(Map<String, dynamic> request) {
    if (!_isReviewShape(request) ||
        request['requestId'] is! String ||
        request['monitoringRequestId'] is! String ||
        request['expectedVersion'] is! int ||
        (request['expectedVersion'] as int) < 1 ||
        request['reason'] is! String ||
        (request['reason'] as String).trim().isEmpty ||
        (request['reason'] as String).length > 2000) {
      throw const FormatException('Monitoring closure entries are invalid.');
    }
  }

  Future<QualityCommandResult> _checkClose(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const QualityCommandException(
        'Saved monitoring closure was not found.',
      );
    }
    final request = _closeRequest(saved);
    if (saved.state.isAccepted) return _reconcileClose(saved);
    _actor(saved.actorUid);
    await requireCapability(saved.actorUid!);
    if (request['operation'] != 'CLOSE_QUALITY_MONITORING_REQUEST') {
      await requireReviewCapability?.call(saved.actorUid!);
    }
    _actor(saved.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: saved.actorUid!,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcileClose(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const QualityCommandException(
        'This monitoring closure is already being checked or needs review. Its original reason remains saved.',
      );
    }
    final Map<String, dynamic> raw;
    try {
      _actor(saved.actorUid);
      raw = await invoke(durableSubmissionJsonObject(saved.envelopeJson));
    } on FirebaseFunctionsException catch (error) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            '${error.message ?? 'Monitoring change refused'}. The original outcome still needs review.',
        errorCode: _reasonCode(error) ?? 'monitoring-closure-outcome-uncertain',
      );
      throw QualityCommandException(
        '${error.message ?? 'Monitoring change refused'}. Its original identity is retained; open saved-submission review before replacing it.',
        code: error.code,
        reasonCode: _reasonCode(error),
      );
    } catch (_) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            'The monitoring closure outcome is not confirmed. Check the saved closure.',
        errorCode: 'monitoring-closure-outcome-uncertain',
      );
      throw const QualityCommandException(
        'The monitoring closure outcome is not confirmed. Its original reason is saved on this device; check it again.',
      );
    }
    try {
      _closeReceipt(saved, raw);
    } catch (_) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            'The monitoring closure receipt is not confirmed. Check the saved closure.',
        errorCode: 'monitoring-closure-receipt-uncertain',
      );
      throw const QualityCommandException(
        'The monitoring closure receipt is not confirmed. Its original reason is saved on this device; check it again.',
      );
    }
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: jsonEncode({...raw, 'idempotentReplay': false}),
      validateReceipt: (retained, response) {
        _closeReceipt(retained, response);
        return true;
      },
    );
    return _reconcileClose(accepted);
  }

  QualityCommandResult _closeReceipt(
    DurableSubmission saved,
    Map<String, dynamic> response,
  ) {
    final request = _closeRequest(saved);
    final result = QualityCommandResult.fromMap(
      response,
      expectedRequestId: saved.requestId,
      expectedOperation: QualityCommandOperation.values.singleWhere(
        (op) => op.wireName == request['operation'],
      ),
      expectedEntityId: saved.aggregateId,
      expectedVersion: request['expectedVersion'] as int,
    );
    final entity = result.monitoringRequest!;
    final correcting =
        request['operation'] == 'CORRECT_QUALITY_MONITORING_REQUEST';
    if (entity.updatedByUid != saved.actorUid ||
        (correcting
            ? entity.status != QualityMonitoringStatus.active ||
                  ![
                    'baseNumber',
                    'baseAssetClassId',
                    'baseAssetInstanceId',
                    'baseAssetInstanceVersion',
                    'grade',
                    'cycleReference',
                    'chargeNumbers',
                  ].every(
                    (key) =>
                        jsonEncode((response['entity'] as Map)[key]) ==
                        jsonEncode(
                          key == 'chargeNumbers'
                              ? (List<int>.from(request[key] as List)..sort())
                              : request[key] is String
                              ? (request[key] as String).trim()
                              : request[key],
                        ),
                  )
            : entity.status != QualityMonitoringStatus.closed ||
                  entity.closedByUid != saved.actorUid ||
                  entity.closeReason != (request['reason'] as String).trim() ||
                  (request['operation'] ==
                          'CANCEL_QUALITY_MONITORING_REQUEST' &&
                      !entity.isCancelled))) {
      throw const QualityCommandException(
        'The monitoring receipt does not match the saved change or actor.',
      );
    }
    return result;
  }

  bool _sameOriginalContext(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return a == b;
    return a.length == b.length &&
        a.entries.every(
          (entry) =>
              b.containsKey(entry.key) &&
              jsonEncode(entry.value) == jsonEncode(b[entry.key]),
        );
  }

  bool _sameReviewedBusiness(
    QualityMonitoringRequest a,
    QualityMonitoringRequest b,
  ) =>
      a.baseNumber == b.baseNumber &&
      a.baseAssetClassId == b.baseAssetClassId &&
      a.baseAssetInstanceId == b.baseAssetInstanceId &&
      a.baseAssetInstanceVersion == b.baseAssetInstanceVersion &&
      a.grade == b.grade &&
      a.cycleReference == b.cycleReference &&
      listEquals(a.chargeNumbers, b.chargeNumbers) &&
      a.reason == b.reason &&
      a.status == b.status &&
      a.monitoringDisposition == b.monitoringDisposition &&
      a.closedAt == b.closedAt &&
      a.closedByUid == b.closedByUid &&
      a.closedByName == b.closedByName &&
      a.closeReason == b.closeReason &&
      a.createdByName == b.createdByName &&
      a.updatedByUid == b.updatedByUid &&
      a.updatedByName == b.updatedByName &&
      _sameOriginalContext(
        a.originalMonitoringContext,
        b.originalMonitoringContext,
      );

  Future<QualityCommandResult> _reconcileClose(DurableSubmission saved) async {
    _actor(saved.actorUid, true);
    final result = _closeReceipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    final currentRaw = await readFromServer(saved.aggregateId);
    final current = QualityMonitoringRequest.fromMap(
      currentRaw,
      saved.aggregateId,
    );
    if (current.version < result.version ||
        current.createdByUid != result.monitoringRequest!.createdByUid ||
        !current.createdAt.isAtSameMomentAs(
          result.monitoringRequest!.createdAt,
        ) ||
        (current.version == result.version &&
            (currentRaw['lastMutationId'] != saved.requestId ||
                !_sameReviewedBusiness(current, result.monitoringRequest!) ||
                !current.updatedAt.isAtSameMomentAs(result.committedAt)))) {
      throw const QualityCommandException(
        'The change was recorded, but its current monitoring record needs review. Original evidence remains saved.',
      );
    }
    _actor(saved.actorUid, true);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid, true);
    return result;
  }

  Future<QualityCommandResult> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const QualityCommandException(
        'Saved monitoring was not found. Nothing was sent.',
      );
    }
    _request(saved);
    if (saved.state.isAccepted) return _reconcile(saved);
    _actor(saved.actorUid);
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
    } on FirebaseFunctionsException catch (error) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            '${error.message ?? 'Monitoring request refused'}. The original outcome still needs review.',
        errorCode: _reasonCode(error) ?? 'monitoring-outcome-uncertain',
      );
      throw QualityCommandException(
        '${error.message ?? 'Monitoring request refused'}. Its original entries remain saved; open saved-submission review before replacing it.',
        code: error.code,
        reasonCode: _reasonCode(error),
      );
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
    try {
      _receipt(saved, raw);
    } catch (_) {
      await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        message:
            'The monitoring outcome is not confirmed. Check the saved request.',
        errorCode: 'monitoring-receipt-uncertain',
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

  String? _reasonCode(FirebaseFunctionsException error) {
    final details = error.details;
    final value = details is Map ? details['reasonCode'] : null;
    return value is String && RegExp(r'^[a-z0-9-]{1,120}$').hasMatch(value)
        ? value
        : null;
  }

  // Transport refusals do not establish historical nonacceptance. The server
  // review protocol owns fencing/replacement; never release an uncertain ID.

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
    _actor(saved.actorUid, true);
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
        !(current.originalMonitoringContext == null
            ? _sameCreation(current, _request(saved), saved.actorUid!)
            : _sameCreation(
                QualityMonitoringRequest.fromMap(
                  {
                      ...currentRaw,
                      ...current.originalMonitoringContext!,
                      'schemaVersion': 3,
                    }
                    ..remove('monitoringDisposition')
                    ..remove('originalMonitoringContext'),
                  saved.aggregateId,
                ),
                _request(saved),
                saved.actorUid!,
              )) ||
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
    _actor(saved.actorUid, true);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid, true);
    return result;
  }
}
