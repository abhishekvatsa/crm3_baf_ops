import 'dart:convert';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../repositories/asset_hierarchy_repository.dart';

/// One unresolved register change per device. A new UUID must never bypass a
/// lost reply to an earlier creation or replacement.
class AssetRegistrySubmissionController {
  AssetRegistrySubmissionController({
    required this.store,
    required this.repository,
    required this.requireActor,
    required this.requireCapability,
  });
  final DurableSubmissionRepository store;
  final AssetHierarchyRepository repository;
  final AppUser Function() requireActor;
  final Future<void> Function(String) requireCapability;
  static const resource = 'assetRegistry:pending';

  AppUser _actor(
    String uid, {
    bool recovery = false,
    String? operation,
    String? status,
  }) {
    final actor = requireActor();
    final permitted =
        actor.isAdmin ||
        (actor.isSI &&
            operation == 'SET_ASSET_INSTANCE_STATUS' &&
            status == 'retired');
    if (!actor.isApproved || actor.uid != uid || (!recovery && !permitted)) {
      throw const AssetHierarchyException(
        'Return to the original approved account to check this saved register change.',
      );
    }
    return actor;
  }

  Future<AssetHierarchyMutationReceipt> submit(
    Map<String, dynamic> request,
    AppUser origin,
  ) async {
    final operation = request['operation'];
    if (!assetRegistrySubmissionOperations.contains(operation)) {
      throw const AssetHierarchyInputRejected(
        'Unsupported register change. Nothing was sent.',
      );
    }
    final actor = _actor(
      origin.uid,
      operation: operation as String,
      status: request['status'] as String?,
    );
    final requestId = request['requestId'] as String;
    final key = DurableSubmissionRepository.aggregateIdentityKey(
      'assetHierarchy.v2',
      request,
    );
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: requestId,
        actorUid: actor.uid,
        requestId: requestId,
        aggregateId: request[key] as String,
        resourceKey: resource,
        protocol: 'assetHierarchy.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor.uid,
          'request': request,
        }),
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'operation': operation,
          'reason': request['reason'],
        }),
      ),
    );
    return check(saved.submissionId);
  }

  Map<String, dynamic> _request(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final request = envelope['request'];
    if (saved.protocol != 'assetHierarchy.v2' ||
        saved.resourceKey != resource ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        saved.actorUid == null ||
        envelope['originActorUid'] != saved.actorUid ||
        request is! Map<String, dynamic> ||
        !assetRegistrySubmissionOperations.contains(request['operation']) ||
        request['requestId'] != saved.requestId ||
        request[DurableSubmissionRepository.aggregateIdentityKey(
              saved.protocol,
              request,
            )] !=
            saved.aggregateId ||
        !DurableSubmissionRepository.validExpectedVersion(
          saved.protocol,
          request,
        )) {
      throw const AssetHierarchyException(
        'Saved register evidence needs review. Nothing was sent.',
      );
    }
    return request;
  }

  Future<AssetHierarchyMutationReceipt> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const AssetHierarchyException(
        'The saved register change could not be found.',
      );
    }
    final request = _request(saved);
    final uid = saved.actorUid!;
    _actor(uid, recovery: true);
    if (saved.state.isAccepted) return _adopt(saved, request);
    await requireCapability(uid);
    _actor(uid, recovery: true);
    final claim = await store.claim(submissionId: submissionId, actorUid: uid);
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adopt(claim.submission, request);
    }
    if (!claim.mayDispatch) {
      throw const AssetHierarchyException(
        'This saved change is already being checked or needs review. Its details remain on this device.',
      );
    }
    late final AssetHierarchyMutationReceipt receipt;
    try {
      _actor(uid, recovery: true);
      receipt = await repository.dispatchFrozenRegistry(
        request,
        originActorUid: uid,
      );
    } catch (error) {
      // These typed refusals are emitted only after the backend replay check.
      // Transport failures or damaged receipts cannot establish non-acceptance.
      final refused =
          error is AssetTagCollisionException ||
          error is AssetHierarchyCommandRefused;
      await store.recordOutcome(
        claim,
        state: refused
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        errorCode: refused
            ? 'register-change-refused'
            : 'register-outcome-uncertain',
        message: refused
            ? error.toString()
            : 'The original register change is saved. Check it before starting another change.',
      );
      if (refused) rethrow;
      throw const AssetHierarchyException(
        'The outcome is not confirmed. The original register change is saved on this device; use Check saved change before starting another.',
      );
    }
    final raw = receipt.toRegistryMap(request);
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: jsonEncode(raw),
      validateReceipt: (value, evidence) {
        AssetHierarchyMutationReceipt.fromMap(
          evidence,
          request: _request(value),
        );
        return true;
      },
    );
    return _adopt(accepted, request);
  }

  Future<AssetHierarchyMutationReceipt> _adopt(
    DurableSubmission saved,
    Map<String, dynamic> request,
  ) async {
    _actor(saved.actorUid!, recovery: true);
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      durableSubmissionJsonObject(saved.receiptJson!),
      request: request,
    );
    // Register views are server streams. Retain acceptance independently from
    // those mutable views; a later edit must not invalidate historical success.
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    return receipt;
  }
}
