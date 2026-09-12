import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import 'published_template_assignment_durable_adoption.dart';
import 'published_template_assignment_idempotency_store.dart';
import 'published_template_assignment_server_service.dart';

class PublishedTemplateAssignmentSubmissionController {
  PublishedTemplateAssignmentSubmissionController({
    required this.store,
    required this.server,
    required this.legacy,
    required this.requireActor,
    required this.requireCapability,
  });
  final DurableSubmissionRepository store;
  final PublishedTemplateAssignmentServerService server;
  final PublishedTemplateAssignmentIdempotencyStore legacy;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;

  AppUser _actor([String? original]) {
    final actor = requireActor();
    if (!actor.isApproved ||
        !actor.canAssignJobExecution ||
        (original != null && original != actor.uid)) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'origin-account-mismatch',
        message:
            'Use the approved account that saved this assignment before continuing. Its entries are retained.',
      );
    }
    return actor;
  }

  String _resource(String actor) => 'publishedTemplateAssignment:$actor';

  Future<void> _importLegacy(String actor) async {
    final evidence = await legacy.rawEvidence(actor);
    _actor(actor);
    for (final entry in evidence) {
      await store.importLegacyNeedsReview(
        submissionId: 'legacy-assignment-${durableSubmissionSha256(entry.key)}',
        resourceKey: _resource(actor),
        sourceKey: entry.key,
        sourceBytes: entry.bytes,
      );
      _actor(actor);
    }
  }

  Future<DurableSubmission?> restore() async {
    final actor = _actor();
    await _importLegacy(actor.uid);
    final saved = await store.findUnresolvedForResource(_resource(actor.uid));
    _actor(actor.uid);
    if (saved != null && !saved.isLegacy) requestFromSaved(saved);
    return saved;
  }

  Future<DurableSubmission> prepare({
    required String originActorUid,
    required PublishedTemplateAssignmentRequest request,
  }) async {
    _actor(originActorUid);
    await _importLegacy(originActorUid);
    _actor(originActorUid);
    final raw = request.toCallableData();
    PublishedTemplateAssignmentRequest.fromCallableData(raw);
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: request.requestId,
        actorUid: originActorUid,
        requestId: request.requestId,
        aggregateId: request.requestId,
        resourceKey: _resource(originActorUid),
        protocol: 'publishedTemplateAssignment.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': originActorUid,
          'request': raw,
        }),
      ),
    );
    _actor(originActorUid);
    return saved;
  }

  PublishedTemplateAssignmentRequest requestFromSaved(DurableSubmission saved) {
    final outer = saved.envelope;
    if (saved.isLegacy ||
        saved.protocol != 'publishedTemplateAssignment.v2' ||
        outer.length != 3 ||
        outer['protocolVersion'] != 2 ||
        outer['originActorUid'] != saved.actorUid ||
        outer['request'] is! Map<String, dynamic> ||
        saved.resourceKey != _resource(saved.actorUid!)) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'saved-evidence-invalid',
        message: 'Saved assignment evidence needs review. Nothing was sent.',
      );
    }
    final request = PublishedTemplateAssignmentRequest.fromCallableData(
      outer['request'] as Map<String, dynamic>,
    );
    if (request.requestId != saved.requestId ||
        request.requestId != saved.aggregateId) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'saved-evidence-invalid',
        message: 'Saved assignment identity does not match its request.',
      );
    }
    return request;
  }

  PublishedTemplateAssignmentServerResult _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final request = requestFromSaved(saved);
    final result = PublishedTemplateAssignmentServerResult.fromCallableData(
      raw,
      fallbackRequestId: request.requestId,
      expectedRequest: request,
      expectedOriginActorUid: saved.actorUid,
      allowCompletedProjection: true,
    );
    final execution = result.execution;
    void origin(String? rawMetadata, String? actor) {
      if (rawMetadata == null || actor != saved.actorUid) _badReceipt();
      final metadata = durableSubmissionJsonObject(rawMetadata);
      if (metadata['source'] !=
              'server_governed_published_template_assignment' ||
          metadata['requestId'] != request.requestId ||
          metadata['publicationAuditId'] !=
              result.publicationAuditFirestoreId) {
        _badReceipt();
      }
    }

    origin(execution.metadataJson, execution.assignedByUid);
    final executionMetadata = durableSubmissionJsonObject(
      execution.metadataJson!,
    );
    if (executionMetadata['sourceMaintenancePlanId'] != request.sourcePlanId ||
        executionMetadata['sourceMaintenancePlanVersion'] !=
            request.sourcePlanExpectedVersion) {
      _badReceipt();
    }
    for (final module in result.modules) {
      origin(module.metadataJson, module.createdByUid);
      if (!module.createdAt.isAtSameMomentAs(result.assignedAt)) _badReceipt();
    }
    return result;
  }

  Future<PublishedTemplateAssignmentServerResult> check(
    String submissionId,
  ) async {
    final saved = await store.read(submissionId);
    if (saved == null) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'missing-submission',
        message: 'The saved assignment could not be found. Nothing was sent.',
      );
    }
    _actor(saved.actorUid);
    requestFromSaved(saved);
    if (saved.state.isAccepted) return _adopt(saved);
    await requireCapability(saved.actorUid!);
    _actor(saved.actorUid);
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: saved.actorUid!,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adopt(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'submission-held',
        message:
            'This assignment is already being checked or needs review. The saved request is retained.',
      );
    }
    final String raw;
    try {
      _actor(saved.actorUid);
      final response = await server.assignFrozenEnvelope(saved.envelopeJson);
      _receipt(saved, response);
      // Canonical acceptance receipt: replay is an observation flag only; all
      // authoritative request, actor, execution and module evidence is retained.
      raw = jsonEncode({...response, 'idempotentReplay': false});
    } catch (_) {
      final outcome = await store.recordOutcome(
        claim,
        state: DurableSubmissionState.uncertain,
        errorCode: 'assignment-outcome-uncertain',
        message:
            'Assignment is not confirmed. The original request and complete entries are saved.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final retained = await store.read(submissionId);
        if (retained != null) return _adopt(retained);
      }
      throw const PublishedTemplateAssignmentServerException(
        code: 'assignment-outcome-uncertain',
        message:
            'Assignment is not confirmed. Check the saved assignment to retry its original request.',
      );
    }
    final accepted = await store.settleAccepted(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: raw,
      validateReceipt: (value, response) {
        _receipt(value, response);
        return true;
      },
    );
    return _adopt(accepted);
  }

  Future<PublishedTemplateAssignmentServerResult> _adopt(
    DurableSubmission saved,
  ) async {
    _actor(saved.actorUid);
    if (!saved.state.isAccepted ||
        saved.receiptJson == null ||
        saved.receiptSha256 == null) {
      _badReceipt();
    }
    final result = _receipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
      adoptInTransaction: (database) =>
          adoptPublishedAssignmentInTransaction(database, result, () {
            _actor(saved.actorUid);
          }),
    );
    _actor(saved.actorUid);
    return result;
  }

  Future<void> cancelNeverSent(String id) async {
    final actor = _actor();
    await store.cancelNeverSent(submissionId: id, actorUid: actor.uid);
    _actor(actor.uid);
  }

  Never _badReceipt() => throw const PublishedTemplateAssignmentServerException(
    code: 'invalid-response',
    message:
        'The acceptance does not match this assignment origin. Its evidence is retained for review.',
  );
}

final publishedTemplateAssignmentSubmissionControllerProvider =
    Provider<PublishedTemplateAssignmentSubmissionController>((ref) {
      const capabilities = CommandCapabilityService();
      return PublishedTemplateAssignmentSubmissionController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        server: ref.watch(publishedTemplateAssignmentServerServiceProvider),
        legacy: ref.watch(publishedTemplateAssignmentIdempotencyStoreProvider),
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) {
            throw PublishedTemplateAssignmentServerException(
              code: 'account-unverified',
              message: access.message,
            );
          }
          return access.actor!;
        },
        requireCapability: (uid) async {
          await capabilities.requireCapabilities(
            callableName: publishedTemplateAssignmentV2CallableName,
            originActorUid: uid,
            requiredCapabilities: const {'publishedTemplateAssignment.v2'},
          );
        },
      );
    });

final pendingPublishedTemplateAssignmentProvider =
    FutureProvider.autoDispose<DurableSubmission?>((ref) {
      final access = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      );
      if (!access.isReady || !access.actor!.canAssignJobExecution) return null;
      return ref
          .watch(publishedTemplateAssignmentSubmissionControllerProvider)
          .restore();
    });
