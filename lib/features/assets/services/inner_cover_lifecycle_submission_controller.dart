import 'dart:convert';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/persistence/durable_submission_review_acceptance.dart';
import '../../auth/data/user_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../repositories/asset_hierarchy_repository.dart';

/// Owns durable recovery for Inner Cover lifecycle actions other than the
/// dedicated acceptance evidence flow. The exact request is saved before the
/// first dispatch and is the only request ever retried.
class InnerCoverLifecycleSubmissionController {
  InnerCoverLifecycleSubmissionController({
    required this.store,
    required this.repository,
    required this.requireActor,
    required this.requireCapability,
  });

  final DurableSubmissionRepository store;
  final AssetHierarchyRepository repository;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;

  static const _operations = <String>{
    'REGISTER_INNER_COVER',
    'SET_INNER_COVER_STATE',
    'LINK_INNER_COVER',
    'DELINK_INNER_COVER',
    'TRANSFER_INNER_COVER',
    'REPLACE_INNER_COVER',
    'SWAP_INNER_COVERS',
  };

  static String resource(String innerCoverId) =>
      'innerCoverLifecycle:$innerCoverId';

  AppUser _actor([String? originalUid]) {
    final actor = requireActor();
    if (!actor.isApproved || !actor.isAdmin) {
      throw const AssetHierarchyException(
        'An approved admin account is required to change Inner Cover lifecycle.',
      );
    }
    if (originalUid != null && actor.uid != originalUid) {
      throw const AssetHierarchyException(
        'Return to the original account to check this Inner Cover change.',
      );
    }
    return actor;
  }

  Future<DurableSubmission?> restore(String innerCoverId) async {
    final actor = _actor();
    final saved = await store.findUnresolvedForResource(resource(innerCoverId));
    _actor(actor.uid);
    if (saved != null) {
      _actor(saved.actorUid);
      _frozen(saved);
    }
    return saved;
  }

  /// Lists retained registrations without requiring a server profile row.
  /// Registration is the one lifecycle operation whose first accepted write
  /// may be the profile itself, so its recovery entry point cannot be attached
  /// only to a decoded profile list.
  Future<List<DurableSubmission>> pendingRegistrations() async {
    final actor = _actor();
    final rows = await store.listForActor(actor.uid);
    _actor(actor.uid);
    return rows
        .where((row) {
          if (row.protocol != 'assetHierarchy.v2' ||
              !row.resourceKey.startsWith('innerCoverLifecycle:')) {
            return false;
          }
          try {
            return _frozen(row)['operation'] == 'REGISTER_INNER_COVER';
          } on Object {
            return true;
          }
        })
        .toList(growable: false);
  }

  Map<String, dynamic> registrationRequestOf(DurableSubmission saved) {
    _actor(_savedActor(saved));
    return _frozen(saved);
  }

  Map<String, dynamic> _frozen(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final actorUid = saved.actorUid;
    final raw = envelope['request'];
    final request = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final operation = request['operation'];
    final innerCoverId = request['innerCoverId'];
    if (saved.protocol != 'assetHierarchy.v2' ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        envelope['originActorUid'] != actorUid ||
        actorUid == null ||
        actorUid.trim().isEmpty ||
        operation is! String ||
        !_operations.contains(operation) ||
        request['requestId'] != saved.requestId ||
        innerCoverId is! String ||
        innerCoverId.trim().isEmpty ||
        saved.aggregateId != innerCoverId ||
        saved.resourceKey != resource(innerCoverId)) {
      throw const AssetHierarchyException(
        'Saved Inner Cover lifecycle evidence needs review before retry.',
      );
    }
    return request;
  }

  String _savedActor(DurableSubmission saved) {
    final actorUid = saved.actorUid;
    if (actorUid == null || actorUid.trim().isEmpty) {
      throw const AssetHierarchyException(
        'Saved Inner Cover lifecycle evidence has no original account.',
      );
    }
    return actorUid;
  }

  Future<InnerCoverProfile> submit({
    required Map<String, dynamic> request,
    required String originActorUid,
    Map<String, Object?> displayMetadata = const <String, Object?>{},
  }) async {
    final actor = _actor(originActorUid);
    final operation = request['operation'];
    final innerCoverId = request['innerCoverId'];
    final requestId = request['requestId'];
    if (operation is! String ||
        !_operations.contains(operation) ||
        innerCoverId is! String ||
        innerCoverId.trim().isEmpty ||
        requestId is! String ||
        requestId.trim().isEmpty) {
      throw const AssetHierarchyInputRejected(
        'The Inner Cover lifecycle request is incomplete.',
      );
    }
    final existing = await store.read(requestId);
    _actor(actor.uid);
    if (existing != null) {
      final savedRequest = _frozen(existing);
      if (!sameSubmissionJson(savedRequest, request)) {
        throw const AssetHierarchyException(
          'This request ID already contains different Inner Cover instructions. Nothing was sent.',
        );
      }
      return check(existing.submissionId);
    }
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: requestId,
        actorUid: actor.uid,
        requestId: requestId,
        aggregateId: innerCoverId,
        resourceKey: resource(innerCoverId),
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

  Future<InnerCoverProfile> check(String submissionId) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const AssetHierarchyException(
        'The saved Inner Cover change could not be found. Nothing was sent.',
      );
    }
    final request = _frozen(saved);
    final actorUid = _savedActor(saved);
    _actor(actorUid);
    if (saved.state.isAccepted) return _reconcile(saved, request);
    await requireCapability(actorUid);
    _actor(actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: actorUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _reconcile(claim.submission, request);
    }
    if (!claim.mayDispatch) {
      throw const AssetHierarchyException(
        'This Inner Cover change is already being checked or needs review. Its saved request remains intact.',
      );
    }
    late final AssetHierarchyMutationReceipt receipt;
    try {
      _actor(actorUid);
      receipt = await repository.dispatchFrozenInnerCoverLifecycle(
        request,
        originActorUid: actorUid,
      );
    } catch (error) {
      final definiteRefusal =
          error is AssetHierarchyCommandRefused ||
          error is AssetHierarchyInputRejected;
      final refusalCode = error is AssetHierarchyCommandRefused
          ? error.reasonCode ?? error.code
          : 'inner-cover-lifecycle-input-rejected';
      final outcome = await store.recordOutcome(
        claim,
        state: definiteRefusal
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        errorCode: definiteRefusal
            ? refusalCode
            : 'inner-cover-lifecycle-outcome-uncertain',
        message: definiteRefusal
            ? (error as AssetHierarchyException).message
            : 'The Inner Cover change is not confirmed. Its original request is retained; check it again.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await store.read(submissionId);
        if (accepted != null) return _reconcile(accepted, request);
      }
      if (definiteRefusal && outcome == DurableSubmissionOutcome.recorded) {
        rethrow;
      }
      throw const AssetHierarchyException(
        'The outcome is not confirmed. The original Inner Cover request is saved on this device; check it again.',
      );
    }
    // idempotentReplay describes this observation, not the accepted operation.
    // It must not enter the immutable local acceptance capsule.
    final receiptMap = receipt.toInnerCoverMap()..['idempotentReplay'] = false;
    final receiptJson = jsonEncode(receiptMap);
    _receipt(saved, receiptJson);
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (value, raw) {
        _receipt(value, jsonEncode(raw));
        return true;
      },
    );
    return _reconcile(accepted, request);
  }

  void _receipt(DurableSubmission saved, String receiptJson) {
    final raw = durableSubmissionJsonObject(receiptJson);
    final request = _frozen(saved);
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      raw,
      request: request,
    );
    final expectedVersion = request['operation'] == 'REGISTER_INNER_COVER'
        ? 0
        : request['expectedVersion'];
    final hasSecondary =
        request['operation'] == 'REPLACE_INNER_COVER' ||
        request['operation'] == 'SWAP_INNER_COVERS';
    final expectedSecondary = request['expectedDisplacedVersion'];
    if (expectedVersion is! int ||
        receipt.version != expectedVersion + 1 ||
        (hasSecondary
            ? expectedSecondary is! int ||
                  receipt.secondaryVersion != expectedSecondary + 1
            : receipt.secondaryVersion != null)) {
      throw const AssetHierarchyException(
        'The Inner Cover receipt does not match the saved revisions. Its evidence is retained for review.',
      );
    }
  }

  Future<InnerCoverProfile> _reconcile(
    DurableSubmission saved,
    Map<String, dynamic> request,
  ) async {
    final receiptJson = saved.receiptJson;
    final receiptHash = saved.receiptSha256;
    if (!saved.state.isAccepted || receiptJson == null || receiptHash == null) {
      throw const AssetHierarchyException(
        'The accepted Inner Cover change needs review before adoption.',
      );
    }
    _receipt(saved, receiptJson);
    final receipt = AssetHierarchyMutationReceipt.fromMap(
      durableSubmissionJsonObject(receiptJson),
      request: request,
    );
    final actorUid = _savedActor(saved);
    Future<InnerCoverProfile> readAffected(String id, int version) async {
      _actor(actorUid);
      final profile = await repository.readInnerCoverFromServer(
        id,
        minimumVersion: version,
      );
      _actor(actorUid);
      if (profile.id != id ||
          profile.version < version ||
          (profile.version == version &&
              profile.lastMutationId != receipt.requestId)) {
        throw const AssetHierarchyException(
          'The Inner Cover change is recorded, but an affected cover has not been confirmed from current server evidence. The accepted request remains saved; check again.',
        );
      }
      return profile;
    }

    final current = await readAffected(receipt.entityId, receipt.version);
    if (receipt.secondaryVersion != null) {
      final displacedId = request['displacedInnerCoverId'];
      if (displacedId is! String || displacedId.isEmpty) {
        throw const AssetHierarchyException(
          'The accepted change is missing its second cover identity. Its saved evidence needs review.',
        );
      }
      await readAffected(displacedId, receipt.secondaryVersion!);
    }
    if (request['operation'] == 'REGISTER_INNER_COVER') {
      final draft = request['registrationDraft'];
      final sections = draft is Map ? draft['fabricationSections'] : null;
      final donorVersions = <String, int>{};
      if (sections is List) {
        for (final section in sections) {
          if (section is! Map ||
              section['materialSource'] != 'reusedKnownDonor') {
            continue;
          }
          final id = section['donorInnerCoverId'];
          final version = section['donorExpectedVersion'];
          if (id is! String ||
              id.isEmpty ||
              version is! int ||
              version < 1 ||
              (donorVersions.containsKey(id) &&
                  donorVersions[id] != version + 1)) {
            throw const AssetHierarchyException(
              'The accepted fabrication has incomplete donor identities. Its saved evidence needs review.',
            );
          }
          donorVersions[id] = version + 1;
        }
      }
      for (final donor in donorVersions.entries) {
        await readAffected(donor.key, donor.value);
      }
    }
    _actor(actorUid);
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: receiptHash,
    );
    _actor(saved.actorUid);
    return current;
  }
}
