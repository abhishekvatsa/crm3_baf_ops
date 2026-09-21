import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../audit/repositories/audit_repository.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_creation_successor_review.dart';
import '../domain/maintenance_ticket_correction.dart';
import '../repositories/maintenance_creation_successor_repository.dart';
import 'maintenance_issue_command_reconciler.dart';

// These paired codes are emitted by correctMaintenanceTicket's fresh-command
// validation (ticketHandlers.ts and ticketLanePlan.ts), before any writes.
// Audit collisions, replay/receipt failures, unclassified validation failures,
// and transport/authority errors do not establish a rejected outcome.
const _precommitCorrectionRefusals = <WorkflowErrorCode, Set<String>>{
  WorkflowErrorCode.versionConflict: {'maintenance-ticket-version-conflict'},
  WorkflowErrorCode.notFound: {
    'maintenance-ticket-not-found',
    'maintenance-ticket-governed-asset-not-found',
  },
  WorkflowErrorCode.aborted: {
    'maintenance-ticket-governed-asset-changed',
    'maintenance-ticket-component-definition-changed',
    'maintenance-ticket-governed-component-changed',
  },
  WorkflowErrorCode.invalidArgument: {
    'maintenance-ticket-asset-reference-required',
    'maintenance-ticket-route-department-invalid',
  },
  WorkflowErrorCode.failedPrecondition: {
    'maintenance-ticket-evidence-invalid',
    'maintenance-ticket-deleted',
    'maintenance-ticket-workflow-deferred',
    'maintenance-ticket-timestamp-invalid',
    'maintenance-ticket-lane-plan-partial',
    'maintenance-ticket-lane-plan-invalid',
    'maintenance-ticket-lane-completion-evidence-invalid',
    'maintenance-ticket-route-invalid',
    'maintenance-ticket-lane-route-inconsistent',
    'maintenance-ticket-lane-status-inconsistent',
    'maintenance-ticket-lane-acknowledgement-incomplete',
    'maintenance-ticket-target-correction-required',
    'maintenance-ticket-target-dependent-evidence',
    'maintenance-ticket-saved-actions-invalid',
    'maintenance-ticket-asset-reference-scope-invalid',
    'maintenance-ticket-inner-cover-class-ambiguous',
    'maintenance-ticket-component-definition-tag-invalid',
    'maintenance-ticket-governed-tag-mismatch',
    'maintenance-ticket-asset-ownership-invalid',
    'maintenance-ticket-inner-cover-not-linked',
    'maintenance-ticket-inner-cover-projection-invalid',
    'maintenance-ticket-inner-cover-linkage-after-event',
    'maintenance-ticket-department-review-required',
    'maintenance-burner-evidence-malformed',
    'maintenance-burner-specialization-immutable',
    'maintenance-stuckup-specialization-immutable',
    'maintenance-inner-cover-availability-immutable',
    'maintenance-ticket-plant-condition-effect-invalid',
    'maintenance-ticket-route-locked',
    'maintenance-ticket-correction-noop',
  },
};

class MaintenanceSuccessorNewerDraftRetained extends StateError {
  MaintenanceSuccessorNewerDraftRetained()
    : super(
        'The reviewed correction is confirmed. Newer device work was kept unchanged and still needs review. Reload the comparison before deciding what to apply.',
      );
}

/// A distinct supervisor command owns selected successor edits. Creation A
/// remains solely in the workflow journal and is never dispatched here.
class MaintenanceCreationSuccessorService {
  const MaintenanceCreationSuccessorService({
    required this.repository,
    required this.store,
    required this.gateway,
    required this.currentActor,
    required this.now,
  });
  final MaintenanceCreationSuccessorRepository repository;
  final DurableSubmissionRepository store;
  final OriginBoundWorkflowCommandGateway gateway;
  final AppUser Function() currentActor;
  final DateTime Function() now;

  static String resource(String ticketId) =>
      'maintenanceCreationSuccessor:$ticketId';

  AppUser _actor([String? expected]) {
    final actor = currentActor();
    if (!actor.isApproved ||
        !actor.canCorrectMaintenanceTicket ||
        actor.uid.isEmpty ||
        (expected != null && actor.uid != expected)) {
      throw StateError(
        'Return to the approved Admin or SI account that saved this review. Original evidence is retained.',
      );
    }
    return actor;
  }

  Future<MaintenanceCreationSuccessorReview> review(String ticketId) async {
    final actor = _actor();
    final result = await repository.review(ticketId);
    _actor(actor.uid);
    return result;
  }

  Future<DurableSubmission?> pending(String ticketId) async {
    final actor = _actor();
    final result = await store.findUnresolvedForResource(resource(ticketId));
    _actor(actor.uid);
    if (result != null) {
      _actor(result.actorUid);
      _command(result);
    }
    return result;
  }

  Future<MaintenanceRecord> _unchangedReview(
    MaintenanceCreationSuccessorReview review,
    String actorUid,
  ) async {
    await repository.requireUnchangedLocal(
      review.ticketId,
      review.localSnapshotJson,
    );
    _actor(actorUid);
    final server = await repository.readServer(review.ticketId);
    _actor(actorUid);
    if (server == null ||
        maintenanceReviewServerBoundary(server) != review.serverBoundaryJson) {
      throw StateError(
        'The server issue changed during review. Refresh the comparison; your selections and reason remain available.',
      );
    }
    review.acceptance.validateServer(server);
    return server;
  }

  void _requireDisposition(
    MaintenanceCreationSuccessorReview review,
    String reason,
    bool acknowledged,
  ) {
    if (reason.trim().isEmpty || reason.trim().length > 2000) {
      throw StateError('Provide a review reason of at most 2000 characters.');
    }
    if (!acknowledged) {
      throw StateError(
        'Confirm that unselected and unsupported device changes will remain in reviewed evidence and will not be applied.',
      );
    }
  }

  Future<void> submit({
    required MaintenanceCreationSuccessorReview review,
    required MaintenanceTicketCorrectionDraft draft,
    required bool acknowledgeRetainedDifferences,
  }) async {
    final actor = _actor();
    _requireDisposition(review, draft.reason, acknowledgeRetainedDifferences);
    // Freeze all input, including the complete native B snapshot, before I/O.
    final metadata = maintenanceReviewJson(
      review.evidence(
        reason: draft.reason,
        corrections: draft.corrections,
        disposition: 'correctSelectedFields',
        targetReferenceJson: draft.targetReferenceJson,
      ),
    );
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.correctMaintenanceTicket,
      aggregateId: review.ticketId,
      expectedVersion: review.server.version,
      payload: Map<String, Object?>.from(
        jsonDecode(
              jsonEncode({
                'reason': draft.reason,
                'corrections': draft.corrections,
                if (draft.targetReferenceJson != null)
                  'targetReferenceJson': draft.targetReferenceJson,
              }),
            )
            as Map,
      ),
    );
    _validateCorrection(command);
    final envelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': actor.uid,
      'command': command.toMap(),
    });
    await _unchangedReview(review, actor.uid);
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: command.commandId,
        actorUid: actor.uid,
        requestId: command.commandId,
        aggregateId: review.ticketId,
        resourceKey: resource(review.ticketId),
        protocol: 'maintenanceWorkflow.v2',
        envelopeJson: envelope,
        displayMetadataJson: metadata,
      ),
    );
    _actor(actor.uid);
    return resume(saved.submissionId);
  }

  Future<void> keepServer({
    required MaintenanceCreationSuccessorReview review,
    required String reason,
    required bool acknowledgeRetainedDifferences,
  }) async {
    final actor = _actor();
    _requireDisposition(review, reason, acknowledgeRetainedDifferences);
    final evidence = durableSubmissionJsonObject(
      maintenanceReviewJson(
        review.evidence(
          reason: reason.trim(),
          corrections: const {},
          disposition: 'keepServer',
        ),
      ),
    );
    if (await store.findUnresolvedForResource(resource(review.ticketId)) !=
        null) {
      throw StateError(
        'Confirm the saved correction before replacing this device draft.',
      );
    }
    _actor(actor.uid);
    final server = await _unchangedReview(review, actor.uid);
    await repository.keepServer(
      review: review,
      server: server,
      evidence: evidence,
      reviewerUid: actor.uid,
      reviewerName: actor.name,
      reviewedAt: now(),
      requireActor: () => _actor(actor.uid),
      requireNoPendingCorrection: () async {
        if (await store.findUnresolvedForResource(resource(review.ticketId)) !=
            null) {
          throw StateError(
            'Confirm the saved correction before replacing this device draft.',
          );
        }
        _actor(actor.uid);
      },
    );
    _actor(actor.uid);
  }

  void _validateCorrection(WorkflowCommand command) {
    final changes = command.payload['corrections'];
    const fields = {
      'description',
      'routedTo',
      'maintenanceType',
      'isCritical',
      'plantConditionEffect',
      'component',
      'subsystem',
      'tag',
      'classification',
      'otherDepartment',
      'remarks',
    };
    final reason = command.payload['reason'];
    if (command.type != WorkflowCommandType.correctMaintenanceTicket ||
        command.expectedVersion < 1 ||
        changes is! Map ||
        changes.keys.any((key) => !fields.contains(key)) ||
        (changes.isEmpty && command.payload['targetReferenceJson'] == null) ||
        reason is! String ||
        reason.trim().isEmpty ||
        reason.length > 2000 ||
        command.payload.keys.any(
          (key) => !const {
            'reason',
            'corrections',
            'targetReferenceJson',
          }.contains(key),
        )) {
      throw StateError(
        'This reviewed correction contains unsupported changes. The complete device draft remains saved.',
      );
    }
  }

  WorkflowCommand _command(DurableSubmission saved) {
    final outer = saved.envelope;
    final raw = outer['command'];
    if (saved.protocol != 'maintenanceWorkflow.v2' ||
        outer.length != 3 ||
        outer['protocolVersion'] != 2 ||
        saved.actorUid == null ||
        outer['originActorUid'] != saved.actorUid ||
        raw is! Map<String, dynamic> ||
        raw.length != 5 ||
        raw['commandId'] != saved.requestId ||
        raw['aggregateId'] != saved.aggregateId ||
        raw['expectedVersion'] is! int ||
        raw['commandType'] != 'correctMaintenanceTicket' ||
        raw['payload'] is! Map ||
        saved.resourceKey != resource(saved.aggregateId)) {
      throw StateError(
        'The saved successor correction has inconsistent identity. Nothing was sent.',
      );
    }
    final command = WorkflowCommand(
      commandId: saved.requestId,
      aggregateId: saved.aggregateId,
      type: WorkflowCommandType.correctMaintenanceTicket,
      expectedVersion: raw['expectedVersion'] as int,
      payload: Map<String, Object?>.from(raw['payload'] as Map),
    );
    _validateCorrection(command);
    final evidence = _evidence(saved);
    if (evidence['ticketId'] != saved.aggregateId ||
        evidence['reason'] != command.payload['reason'] ||
        maintenanceReviewJson(evidence['selectedCorrections']) !=
            maintenanceReviewJson(command.payload['corrections']) ||
        evidence['targetReferenceJson'] !=
            command.payload['targetReferenceJson'] ||
        durableSubmissionJsonObject(
              evidence['serverBoundaryJson'] as String,
            )['version'] !=
            command.expectedVersion) {
      throw StateError(
        'The saved command disagrees with its retained review. Nothing was replaced.',
      );
    }
    return command;
  }

  Map<String, dynamic> _evidence(DurableSubmission saved) {
    final raw = saved.displayMetadataJson;
    if (raw == null) {
      throw StateError('The full reviewed device draft is missing.');
    }
    final evidence = durableSubmissionJsonObject(raw);
    if (evidence['schemaVersion'] != 1 ||
        evidence['kind'] != 'maintenanceCreationSuccessorReview' ||
        evidence['disposition'] != 'correctSelectedFields' ||
        evidence['localSnapshotJson'] is! String ||
        evidence['serverBoundaryJson'] is! String ||
        evidence['originalEnvelopeJson'] is! String ||
        evidence['originalReceipt'] is! Map) {
      throw StateError(
        'The saved comparison evidence is incomplete. Nothing was replaced.',
      );
    }
    return evidence;
  }

  WorkflowCommandReceipt _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final command = _command(saved);
    final receipt = WorkflowCommandReceipt.fromMap(raw);
    validateMaintenanceTicketCorrectionReceipt(
      command: command,
      receipt: receipt,
    );
    if (receipt.result.length != 3) {
      throw StateError('The correction response has unsupported evidence.');
    }
    return receipt;
  }

  Future<void> resume(String submissionId) async {
    final actor = _actor();
    final saved = await store.read(submissionId);
    _actor(actor.uid);
    if (saved == null) {
      throw StateError(
        'The saved correction is unavailable. Nothing was sent.',
      );
    }
    _actor(saved.actorUid);
    _command(saved);
    if (saved.state.isAccepted) return _adopt(saved);
    if (saved.attemptCount == 0) {
      try {
        await repository.requireUnchangedLocal(
          saved.aggregateId,
          _evidence(saved)['localSnapshotJson'] as String,
        );
        _actor(actor.uid);
      } catch (_) {
        _actor(actor.uid);
        await store.cancelNeverSent(
          submissionId: saved.submissionId,
          actorUid: actor.uid,
        );
        rethrow;
      }
    }
    final claim = await store.claim(
      submissionId: submissionId,
      actorUid: actor.uid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adopt(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw StateError(
        'The saved correction is already being checked or needs review. Its original request remains retained.',
      );
    }
    try {
      _actor(actor.uid);
      final receipt = await gateway.executeOriginBoundEnvelope(
        saved.envelopeJson,
      );
      final receiptJson = jsonEncode(maintenanceReviewReceiptMap(receipt));
      _receipt(saved, durableSubmissionJsonObject(receiptJson));
      final accepted = await store.settleAccepted(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptJson: receiptJson,
        validateReceipt: (row, raw) {
          _receipt(row, raw);
          return true;
        },
      );
      return _adopt(accepted);
    } catch (error) {
      final code = error is WorkflowException
          ? error.details['reasonCode']
          : null;
      // A later refusal cannot disprove a previously uncertain attempt.
      final refusal =
          claim.submission.attemptCount == 1 &&
          error is WorkflowException &&
          (_precommitCorrectionRefusals[error.code]?.contains(code) ?? false);
      await store.recordOutcome(
        claim,
        state: refusal
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        errorCode: code is String ? code : 'maintenance-successor-unconfirmed',
        message:
            'The original reviewed correction and complete device draft remain saved. Check this request before creating another.',
      );
      rethrow;
    }
  }

  Future<void> _adopt(DurableSubmission saved) async {
    final actor = _actor(saved.actorUid);
    final receipt = _receipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    final command = _command(saved);
    final evidence = _evidence(saved);
    final audit = await repository.readCorrectionAudit(
      receipt.result['auditId'] as String,
    );
    _actor(actor.uid);
    // Admit every shared audit-reader field before checking this command's
    // request, version and selected-value evidence. This server-only audit
    // requires a native Timestamp even though the shared decoder admits older
    // representations elsewhere; exact native equality also preserves nanos.
    final decodedAudit = decodePersistedAuditEvent(
      audit,
      documentId: receipt.result['auditId'] as String,
    );
    final rawTimestamp = audit['timestamp'];
    final before = durableSubmissionJsonObject(audit['beforeJson'] as String);
    final after = durableSubmissionJsonObject(audit['afterJson'] as String);
    final changes = command.payload['corrections'] as Map;
    final targetCorrection = command.payload['targetReferenceJson'] != null;
    const targetLabels = {'component', 'subsystem', 'tag'};
    if (audit['schemaVersion'] != 1 ||
        audit['auditId'] != receipt.result['auditId'] ||
        audit['entityType'] != 'maintenance' ||
        audit['entityId'] != saved.aggregateId ||
        audit['operation'] != 'correctMaintenanceTicket' ||
        audit['action'] != 'update' ||
        audit['requestId'] != saved.requestId ||
        audit['resultVersion'] != receipt.aggregateVersion ||
        audit['performedByUid'] != actor.uid ||
        audit['reasonNotes'] != command.payload['reason'] ||
        !decodedAudit.timestamp.isAtSameMomentAs(receipt.appliedAt) ||
        (rawTimestamp is! Timestamp ||
            rawTimestamp != Timestamp.fromDate(receipt.appliedAt)) ||
        before['version'] != command.expectedVersion ||
        after['version'] != receipt.aggregateVersion ||
        before['firestoreId'] != saved.aggregateId ||
        after['firestoreId'] != saved.aggregateId ||
        changes.entries.any(
          (entry) =>
              !(targetCorrection && targetLabels.contains(entry.key)) &&
              maintenanceReviewJson(after[entry.key]) !=
                  maintenanceReviewJson(entry.value),
        )) {
      throw StateError(
        'The immutable correction audit does not confirm the saved review. The device draft remains retained.',
      );
    }
    if (targetCorrection) {
      final selected = durableSubmissionJsonObject(
        command.payload['targetReferenceJson'] as String,
      );
      final actual = durableSubmissionJsonObject(
        after['assetHierarchyRefJson'] as String,
      );
      for (final key in [
        'scope',
        'assetClassId',
        'assetInstanceId',
        'assetNumber',
        'nodeId',
        'componentInstanceId',
        'componentTag',
      ]) {
        if (selected[key] != actual[key]) {
          throw StateError(
            'The accepted registered target does not match this review.',
          );
        }
      }
      final path = actual['hierarchyPath'];
      if (path is! List ||
          after['component'] != actual['nodeName'] ||
          after['subsystem'] !=
              (path.length > 1 ? path[path.length - 2] : null) ||
          after['tag'] != actual['componentTag']) {
        throw StateError(
          'The accepted equipment labels do not match its registered target.',
        );
      }
    }
    final server = await repository.readServer(saved.aggregateId);
    _actor(actor.uid);
    final creation = durableSubmissionJsonObject(
      evidence['originalEnvelopeJson'] as String,
    );
    final originalReceipt = WorkflowCommandReceipt.fromMap(
      Map<String, dynamic>.from(evidence['originalReceipt'] as Map),
    );
    if (server == null ||
        server.firestoreId != saved.aggregateId ||
        server.isDeleted ||
        server.version < receipt.aggregateVersion ||
        server.loggedByUid != creation['originActorUid'] ||
        !server.createdAt.isAtSameMomentAs(originalReceipt.appliedAt)) {
      throw StateError(
        'The accepted correction is saved, but current server state cannot yet be adopted.',
      );
    }
    // A later version may legitimately supersede selected values. At the
    // accepted version, the current projection must agree with its audit.
    if (server.version == receipt.aggregateVersion) {
      final currentValues = maintenanceCorrectionValues(server);
      final confirmedFields = {
        ...changes.keys,
        if (targetCorrection) ...targetLabels,
      };
      if (confirmedFields.any(
            (key) =>
                maintenanceReviewJson(currentValues[key]) !=
                maintenanceReviewJson(after[key]),
          ) ||
          (targetCorrection &&
              server.assetHierarchyRefJson != after['assetHierarchyRefJson'])) {
        throw StateError(
          'The current server issue does not match its accepted correction audit. The device draft remains retained.',
        );
      }
    }
    var adopted = true;
    await store.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
      adoptInTransaction: (_) async {
        adopted = await repository.adoptInTransaction(
          ticketId: saved.aggregateId,
          expectedSnapshot: evidence['localSnapshotJson'] as String,
          server: server,
          evidence: {
            ...evidence,
            'acceptedCorrection': maintenanceReviewReceiptMap(receipt),
          },
          reviewerUid: actor.uid,
          reviewerName: actor.name,
          reviewedAt: now(),
          requireActor: () => _actor(actor.uid),
          preserveNewerDraft: true,
        );
      },
    );
    _actor(actor.uid);
    if (!adopted) throw MaintenanceSuccessorNewerDraftRetained();
  }
}
