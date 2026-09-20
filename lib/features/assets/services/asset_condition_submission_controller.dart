import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/persistence/durable_submission_review_acceptance.dart';
import '../../auth/data/user_model.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../repositories/asset_hierarchy_repository.dart';

/// Saves operational-condition intent before the first network dispatch.
/// Retries always use the saved request and the account that created it.
class AssetConditionSubmissionController {
  AssetConditionSubmissionController({
    required this.store,
    required this.repository,
    required this.requireActor,
    required this.requireCapability,
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

  final DurableSubmissionRepository store;
  final AssetHierarchyRepository repository;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;
  final Uuid _uuid;

  static const _operations = <String>{
    'DECLARE_ASSET_CONDITION',
    'RESTORE_ASSET_CONDITION',
  };

  static String resource(String assetInstanceId) =>
      'assetCondition:$assetInstanceId';

  /// Returns only the current actor's retained request for this asset.
  /// A pending request created by another account must not be disclosed or
  /// offered as this account's recovery action.
  Future<DurableSubmission?> pending(String assetInstanceId) async {
    final actor = requireActor();
    if (!actor.isApproved) return null;
    final saved = await store.findUnresolvedForResource(
      resource(assetInstanceId),
    );
    if (saved == null || saved.actorUid != actor.uid) return null;
    final request = _frozen(saved);
    final operation = request['operation'];
    if (operation is! String) return null;
    return saved;
  }

  AppUser _actor(
    String operation, [
    String? originalUid,
    bool recoveryOnly = false,
  ]) {
    final actor = requireActor();
    final permitted = operation == 'DECLARE_ASSET_CONDITION'
        ? actor.canDeclareAssetOperationalCondition
        : actor.canRestoreAssetOperationalCondition;
    if (!actor.isApproved || (!recoveryOnly && !permitted)) {
      throw const AssetHierarchyException(
        'Your account cannot change this operational condition.',
      );
    }
    if (originalUid != null && actor.uid != originalUid) {
      throw const AssetHierarchyException(
        'Return to the original account to check this asset condition change.',
      );
    }
    return actor;
  }

  Future<AssetOperationalConditionRecord> submitDeclare({
    required AssetInstanceRecord asset,
    required AssetOperationalCondition condition,
    required Set<AssetConditionCause> causes,
    required AssetConditionBasis basis,
    required AssetHierarchyReference? componentReference,
    required String reason,
    required List<String> linkedIssueIds,
    required int expectedVersion,
    required String originActorUid,
    String? replacesRequestId,
  }) {
    _actor('DECLARE_ASSET_CONDITION', originActorUid);
    final request = repository.buildDeclareAssetConditionRequest(
      asset: asset,
      condition: condition,
      causes: causes,
      basis: basis,
      componentReference: componentReference,
      reason: reason,
      linkedIssueIds: linkedIssueIds,
      expectedVersion: expectedVersion,
      requestId: _uuid.v4(),
    );
    if (replacesRequestId != null) {
      request['replacesRequestId'] = replacesRequestId;
    }
    return submit(request: request, originActorUid: originActorUid);
  }

  Future<AssetOperationalConditionRecord> submitRestore({
    required AssetInstanceRecord asset,
    required AssetOperationalConditionRecord current,
    required String reason,
    required String originActorUid,
  }) {
    _actor('RESTORE_ASSET_CONDITION', originActorUid);
    final request = repository.buildRestoreAssetConditionRequest(
      asset: asset,
      current: current,
      reason: reason,
      requestId: _uuid.v4(),
    );
    return submit(request: request, originActorUid: originActorUid);
  }

  Future<AssetOperationalConditionRecord> submit({
    required Map<String, dynamic> request,
    required String originActorUid,
    Map<String, Object?> displayMetadata = const <String, Object?>{},
  }) async {
    final operation = request['operation'];
    final actor = _actor(operation is String ? operation : '', originActorUid);
    final requestId = request['requestId'];
    final assetInstanceId = request['assetInstanceId'];
    if (requestId is! String ||
        requestId.trim().isEmpty ||
        assetInstanceId is! String ||
        assetInstanceId.trim().isEmpty ||
        operation is! String ||
        !_operations.contains(operation)) {
      throw const AssetHierarchyInputRejected(
        'The asset-condition request is incomplete.',
      );
    }
    final existing = await store.read(requestId);
    _actor(operation, actor.uid);
    if (existing != null) {
      final savedRequest = _frozen(existing);
      if (!sameSubmissionJson(savedRequest, request)) {
        throw const AssetHierarchyException(
          'This request ID already contains different asset-condition instructions. Nothing was sent.',
        );
      }
      return check(existing.submissionId);
    }
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: requestId,
        actorUid: actor.uid,
        requestId: requestId,
        aggregateId: assetInstanceId,
        resourceKey: resource(assetInstanceId),
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor.uid,
          'request': request,
        }),
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          ...displayMetadata,
        }),
      ),
    );
    return check(saved.submissionId);
  }

  Map<String, dynamic> _frozen(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final raw = envelope['request'];
    final request = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final operation = request['operation'];
    final assetInstanceId = request['assetInstanceId'];
    if (saved.protocol != 'assetHierarchy.v2' ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != saved.actorUid ||
        saved.actorUid == null ||
        saved.actorUid!.trim().isEmpty ||
        operation is! String ||
        !_operations.contains(operation) ||
        request['requestId'] != saved.requestId ||
        assetInstanceId is! String ||
        assetInstanceId.trim().isEmpty ||
        saved.aggregateId != assetInstanceId ||
        saved.resourceKey != resource(assetInstanceId)) {
      throw const AssetHierarchyException(
        'Saved asset-condition evidence needs review before retry.',
      );
    }
    return request;
  }

  Future<AssetOperationalConditionRecord> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const AssetHierarchyException(
        'The saved asset-condition change could not be found. Nothing was sent.',
      );
    }
    final request = _frozen(saved);
    final actorUid = saved.actorUid;
    if (actorUid == null || actorUid.trim().isEmpty) {
      throw const AssetHierarchyException(
        'The saved asset-condition change has no original account.',
      );
    }
    final operation = request['operation'] as String;
    _actor(operation, actorUid, true);
    if (saved.state.isAccepted) return _reconcile(saved, request);
    await requireCapability(actorUid);
    _actor(operation, actorUid, true);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: actorUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcile(claim.submission, request);
    }
    if (!claim.mayDispatch) {
      throw const AssetHierarchyException(
        'This asset-condition change is already being checked or needs review. Its saved request remains intact.',
      );
    }
    late final AssetHierarchyMutationReceipt receipt;
    try {
      _actor(operation, actorUid, true);
      receipt = await repository.dispatchFrozenAssetCondition(
        request,
        originActorUid: actorUid,
      );
    } catch (error) {
      // A failure on this attempt cannot disprove acceptance of an earlier
      // attempt. Only the server recovery protocol may close that uncertainty.
      final outcome = await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        errorCode: 'asset-condition-outcome-uncertain',
        message:
            'The asset-condition change is not confirmed. Its original request is retained; check it again.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(submissionId);
        if (accepted != null) return _reconcile(accepted, request);
      }
      throw const AssetHierarchyException(
        'The outcome is not confirmed. The original asset-condition request is saved on this device; check it again.',
      );
    }
    final receiptMap = receipt.toAssetConditionMap(
      assetClassId: request['assetClassId'] as String,
      condition: operation == 'RESTORE_ASSET_CONDITION'
          ? 'available'
          : request['condition'] as String,
    )..['idempotentReplay'] = false;
    final receiptJson = jsonEncode(receiptMap);
    _validateReceipt(saved, receiptJson);
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (value, raw) {
        _validateReceipt(value, jsonEncode(raw));
        return true;
      },
    );
    return _reconcile(accepted, request);
  }

  void _validateReceipt(DurableSubmission saved, String receiptJson) {
    final request = _frozen(saved);
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      durableSubmissionJsonObject(receiptJson),
      request: request,
    );
    final expectedVersion = request['expectedVersion'];
    if (expectedVersion is! int || receipt.version != expectedVersion + 1) {
      throw const AssetHierarchyException(
        'The asset-condition receipt does not match the saved revision. Its evidence is retained for review.',
      );
    }
  }

  Future<AssetOperationalConditionRecord> _reconcile(
    DurableSubmission saved,
    Map<String, dynamic> request,
  ) async {
    final receiptJson = saved.receiptJson;
    final receiptHash = saved.receiptSha256;
    if (!saved.state.isAccepted || receiptJson == null || receiptHash == null) {
      throw const AssetHierarchyException(
        'The accepted asset-condition change needs review before adoption.',
      );
    }
    _validateReceipt(saved, receiptJson);
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      durableSubmissionJsonObject(receiptJson),
      request: request,
    );
    final actorUid = saved.actorUid;
    if (actorUid == null || actorUid.trim().isEmpty) {
      throw const AssetHierarchyException(
        'The accepted asset-condition change has no original account.',
      );
    }
    _actor(request['operation'] as String, actorUid, true);
    final condition = await repository.readAssetConditionFromServer(
      request['assetInstanceId'] as String,
      minimumVersion: receipt.version,
    );
    final expectedCondition = request['operation'] == 'RESTORE_ASSET_CONDITION'
        ? AssetOperationalCondition.available
        : AssetOperationalCondition.values.firstWhere(
            (item) => item.name == request['condition'],
          );
    if (condition.assetInstanceId != request['assetInstanceId'] ||
        condition.assetClassId != request['assetClassId'] ||
        condition.version < receipt.version ||
        (condition.version == receipt.version &&
            (condition.condition != expectedCondition ||
                condition.lastMutationId != receipt.requestId))) {
      throw const AssetHierarchyException(
        'The asset-condition change is recorded, but current server evidence has not confirmed it. The accepted request remains saved; check again.',
      );
    }
    _actor(request['operation'] as String, actorUid, true);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: receiptHash,
    );
    _actor(request['operation'] as String, actorUid, true);
    return condition;
  }
}
