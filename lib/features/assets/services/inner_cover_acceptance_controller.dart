import 'dart:convert';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../domain/inner_cover_acceptance_input.dart';
import '../domain/inner_cover_acceptance_submission.dart';
import '../repositories/asset_hierarchy_repository.dart';

/// One submission survives its dialog. Native transactions retain the original
/// request before dispatch and its validated receipt before current-state review.
class InnerCoverAcceptanceController {
  InnerCoverAcceptanceController({
    required this.store,
    required this.repository,
    required this.requireActor,
    required this.requireCapability,
  });

  final DurableSubmissionRepository store;
  final AssetHierarchyRepository repository;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;

  AppUser _actor([String? originalUid]) {
    final actor = requireActor();
    if (!actor.isApproved || !actor.isAdmin) {
      throw const AssetHierarchyException(
        'An approved admin account is required to check acceptance.',
      );
    }
    if (originalUid != null && actor.uid != originalUid) {
      throw const AssetHierarchyException(
        'Return to the original account to check this acceptance.',
      );
    }
    return actor;
  }

  Future<DurableSubmission?> restore(String coverId) async {
    final actor = _actor();
    final retained = await store.findUnresolvedForResource(
      'innerCoverAcceptance:$coverId',
    );
    _actor(actor.uid);
    if (retained == null) return null;
    _actor(retained.actorUid);
    _frozen(retained);
    return retained;
  }

  InnerCoverAcceptanceSubmission _frozen(DurableSubmission retained) {
    final frozen = InnerCoverAcceptanceSubmission.parse(retained.envelopeJson);
    if (retained.protocol != 'assetHierarchy.v2' ||
        retained.actorUid != frozen.actorUid ||
        retained.requestId != frozen.requestId ||
        retained.aggregateId != frozen.coverId ||
        retained.resourceKey != frozen.resourceKey) {
      throw const AssetHierarchyException(
        'Saved acceptance identities do not agree. The evidence is retained for support review.',
      );
    }
    return frozen;
  }

  Future<InnerCoverProfile> submit({
    required InnerCoverProfile cover,
    required InnerCoverAcceptanceInput input,
    required String requestId,
  }) async {
    final actor = _actor();
    final existing = await store.read(requestId);
    _actor(actor.uid);
    if (existing != null) {
      final saved = _frozen(existing);
      if (saved.coverId != cover.id || saved.actorUid != actor.uid) {
        throw const AssetHierarchyException(
          'The saved request belongs to another cover or account. Nothing was sent.',
        );
      }
      String? clean(String? value) =>
          value == null || value.trim().isEmpty ? null : value.trim();
      if (saved.input.inspectedOn.millisecondsSinceEpoch !=
              input.inspectedOn.millisecondsSinceEpoch ||
          saved.input.acceptanceReference != input.acceptanceReference.trim() ||
          saved.input.reason != input.reason.trim() ||
          saved.input.leakTestReference != clean(input.leakTestReference) ||
          saved.input.ndtReference != clean(input.ndtReference) ||
          saved.input.notes != clean(input.notes)) {
        throw const AssetHierarchyException(
          'This request already contains different inspection evidence. Reopen its saved entries before checking it.',
        );
      }
      return check(existing.submissionId);
    }
    final frozen = InnerCoverAcceptanceSubmission.prepare(
      cover: cover,
      input: input,
      actorUid: actor.uid,
      requestId: requestId,
      now: DateTime.now(),
    );
    final retained = await store.prepare(
      DurableSubmissionDraft(
        submissionId: requestId,
        actorUid: actor.uid,
        requestId: requestId,
        aggregateId: cover.id,
        resourceKey: frozen.resourceKey,
        protocol: 'assetHierarchy.v2',
        envelopeJson: frozen.envelopeJson,
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'assetClassId': cover.assetClassId,
          'assetClassCode': cover.assetClassCode,
          'normalizedSerialNumber': cover.normalizedSerialNumber,
        }),
      ),
    );
    return check(retained.submissionId);
  }

  Future<InnerCoverProfile> check(String submissionId) async {
    final retained = await store.read(submissionId);
    if (retained == null) {
      throw const AssetHierarchyException(
        'The saved acceptance could not be found. Nothing was sent.',
      );
    }
    final frozen = _frozen(retained);
    _actor(frozen.actorUid);
    if (retained.state.isAccepted) return _reconcile(retained);
    await requireCapability(frozen.actorUid);
    _actor(frozen.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: frozen.actorUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcile(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw AssetHierarchyException(switch (claim.disposition) {
        DurableSubmissionClaimDisposition.claimedElsewhere =>
          'This acceptance is already being checked. Its saved request is retained; try again after the current check expires.',
        DurableSubmissionClaimDisposition.notDue =>
          'This acceptance is saved and waiting for its next retry. Try again shortly.',
        DurableSubmissionClaimDisposition.actorMismatch =>
          'Return to the original account to check this acceptance.',
        _ =>
          'This saved acceptance needs review before another request can be sent.',
      });
    }
    final AssetHierarchyMutationReceipt receipt;
    try {
      _actor(frozen.actorUid);
      receipt = await repository.dispatchFrozenInnerCoverAcceptance(
        frozen.request,
        originActorUid: frozen.actorUid,
      );
    } catch (error) {
      final definiteRefusal = error is AssetHierarchyCommandRefused;
      final outcome = await store.recordOutcome(
        claim,
        state: definiteRefusal
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        message: definiteRefusal
            ? error.message
            : 'The acceptance outcome is not yet confirmed. Retry this saved request.',
        errorCode: definiteRefusal
            ? error.reasonCode ?? error.code
            : 'acceptance-outcome-uncertain',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(submissionId);
        if (accepted != null) return _reconcile(accepted);
      }
      if (definiteRefusal && outcome == DurableSubmissionOutcome.recorded) {
        rethrow;
      }
      throw const AssetHierarchyException(
        'The acceptance outcome is not yet confirmed. Its original request is saved on this device; check or retry it.',
      );
    }
    // Replay is an observation of the same receipt, not a different acceptance.
    final receiptMap = receipt.toInnerCoverMap()..['idempotentReplay'] = false;
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: retained.envelopeSha256,
      receiptJson: jsonEncode(receiptMap),
      validateReceipt: (saved, response) {
        final savedRequest = _frozen(saved);
        AssetHierarchyMutationReceipt.fromMap(
          response,
          request: savedRequest.request,
        );
        return true;
      },
    );
    return _reconcile(accepted);
  }

  Future<InnerCoverProfile> _reconcile(DurableSubmission retained) async {
    final frozen = _frozen(retained);
    _actor(frozen.actorUid);
    final receiptRaw = retained.receiptJson;
    final receiptHash = retained.receiptSha256;
    if (!retained.state.isAccepted ||
        receiptRaw == null ||
        receiptHash == null) {
      throw const AssetHierarchyException(
        'Acceptance evidence is incomplete and needs review.',
      );
    }
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      durableSubmissionJsonObject(receiptRaw),
      request: frozen.request,
    );
    final metadataRaw = retained.displayMetadataJson;
    if (metadataRaw == null) {
      throw const AssetHierarchyException(
        'The saved cover identity needs review.',
      );
    }
    final metadata = durableSubmissionJsonObject(metadataRaw);
    if (metadata.length != 4 ||
        metadata['schemaVersion'] != 1 ||
        const ['assetClassId', 'assetClassCode', 'normalizedSerialNumber'].any(
          (key) =>
              metadata[key] is! String ||
              (metadata[key] as String).trim().isEmpty,
        )) {
      throw const AssetHierarchyException(
        'The saved cover identity needs review.',
      );
    }
    final InnerCoverProfile current;
    try {
      current = await repository.readInnerCoverFromServer(
        frozen.coverId,
        minimumVersion: receipt.version,
      );
    } catch (_) {
      throw const AssetHierarchyException(
        'Acceptance was recorded and saved on this device. The current cover could not yet be confirmed. Check again; acceptance will not be sent again.',
      );
    }
    if (current.id != frozen.coverId ||
        current.version < receipt.version ||
        current.assetClassId != metadata['assetClassId'] ||
        current.assetClassCode != metadata['assetClassCode'] ||
        current.normalizedSerialNumber != metadata['normalizedSerialNumber'] ||
        (current.version == receipt.version &&
            (!current.isAvailable ||
                current.lastMutationId != receipt.requestId ||
                current.acceptedByUid != frozen.actorUid ||
                current.acceptanceReference !=
                    frozen.input.acceptanceReference ||
                current.acceptedAt?.millisecondsSinceEpoch !=
                    frozen.input.inspectedOn.millisecondsSinceEpoch))) {
      throw const AssetHierarchyException(
        'Acceptance is recorded, but the current cover does not agree with its receipt. Both records are retained for review.',
      );
    }
    _actor(frozen.actorUid);
    await store.markReconciled(
      submissionId: retained.submissionId,
      envelopeSha256: retained.envelopeSha256,
      receiptSha256: receiptHash,
    );
    // Reconciliation remains durable if authority changes during the write;
    // only the original verified actor may receive its business result.
    _actor(frozen.actorUid);
    return current;
  }
}
