import 'dart:convert';
import '../../../core/persistence/durable_submission_repository.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../data/job_module_model.dart';
import '../providers/job_module_provider.dart';
import 'workflow_module_reopen_timestamps.dart';

typedef WorkflowModuleDocumentReader =
    Future<Map<String, dynamic>?> Function(String collection, String id);

Object? _sortedJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sortedJson(value[key])};
  }
  if (value is List) return value.map(_sortedJson).toList();
  return value;
}

bool _sameJson(Object? first, Object? second) =>
    jsonEncode(_sortedJson(first)) == jsonEncode(_sortedJson(second));

/// Validates the immutable original reopen audit before reading today's module.
/// A later legitimate lifecycle state is returned as-is, never forced reopened.
Future<JobModuleInstance> readWorkflowReopenedModule({
  required WorkflowModuleDocumentReader read,
  required WorkflowCommandReceipt receipt,
  required String executionId,
  required String moduleId,
  required String actorUid,
  required String reason,
  required JobModuleInstance baseline,
}) async {
  final audit = await read(
    'audit_logs',
    'workflow_module_reopen_${moduleId}_${receipt.aggregateVersion}',
  );
  if (audit == null ||
      audit['entityType'] != 'jobModule' ||
      audit['entityId'] != moduleId ||
      audit['action'] != 'reopen' ||
      audit['performedByUid'] != actorUid ||
      audit['reason'] != 'workflowModuleReopened' ||
      audit['reasonNotes'] != reason ||
      audit['workflowAggregateId'] != executionId ||
      audit['laneKey'] != receipt.result['laneKey'] ||
      !readWorkflowReopenTimestamp(
        audit['timestamp'],
      ).isAtSameMomentAs(receipt.appliedAt)) {
    throw StateError(
      'Accepted reopen audit is not confirmed. Its receipt is retained.',
    );
  }
  final before = durableSubmissionJsonObject(audit['beforeJson'] as String);
  final after = durableSubmissionJsonObject(audit['afterJson'] as String);
  if (!_sameJson(after, {
    ...before,
    'status': 'reopened',
    'isOpenForWork': true,
  })) {
    throw StateError('The original reopen audit is contradictory.');
  }
  final original = JobModuleInstance.fromMap(
    workflowReopenModuleSnapshot(before),
    moduleId,
  );
  final raw = await read('job_modules', moduleId);
  if (raw == null) {
    throw StateError(
      'Server module readback is unavailable. The accepted reopen is retained.',
    );
  }
  final current = JobModuleInstance.fromMap(
    workflowReopenModuleSnapshot(raw),
    moduleId,
  );
  Map<String, dynamic> identity(JobModuleInstance value) {
    final all = jobModuleLocalSnapshot(value);
    return {
      for (final key in const [
        'firestoreId',
        'jobExecutionFirestoreId',
        'laneKey',
        'laneActivationGeneration',
        'workflowLaneFirestoreId',
        'templateFirestoreId',
        'templatePackageId',
        'templateVersionId',
        'templateModuleId',
        'moduleCode',
        'createdAt',
        'createdByUid',
        'assetType',
        'assetNumber',
        'discipline',
      ])
        key: key == 'createdAt'
            ? value.createdAt.toUtc().toIso8601String()
            : all[key],
    };
  }

  final firstVersion = original.version + 1;
  if (original.jobExecutionFirestoreId != executionId ||
      original.isDeleted ||
      !const {
        JobModuleStatus.submitted,
        JobModuleStatus.accepted,
        JobModuleStatus.notApplicable,
      }.contains(original.status) ||
      original.laneKey != receipt.result['laneKey'] ||
      original.version < 1 ||
      !_sameJson(identity(original), identity(baseline)) ||
      !_sameJson(identity(original), identity(current)) ||
      current.version < firstVersion ||
      current.updatedAt.isBefore(receipt.appliedAt) ||
      !current.fieldDefinitionsReadResult.isValid ||
      !current.responsesReadResult.isValid ||
      !current.actionsReadResult.isValid) {
    throw StateError(
      'The server module does not match the accepted reopen lineage.',
    );
  }
  if (current.version == firstVersion &&
      (current.status != JobModuleStatus.reopened ||
          current.isDeleted ||
          current.reopenedByUid != actorUid ||
          current.reopenReason != reason ||
          current.reopenedAt?.isAtSameMomentAs(receipt.appliedAt) != true ||
          !current.updatedAt.isAtSameMomentAs(receipt.appliedAt))) {
    throw StateError(
      'The first reopened module revision contradicts its receipt.',
    );
  }
  return current;
}

class WorkflowModuleReopenController {
  WorkflowModuleReopenController({
    required this.store,
    required this.gateway,
    required this.modules,
    required this.readDocument,
    required this.requireActor,
    required this.requireCapability,
  });
  final DurableSubmissionRepository store;
  final OriginBoundWorkflowCommandGateway gateway;
  final JobModuleRepository modules;
  final WorkflowModuleDocumentReader readDocument;
  final AppUser Function() requireActor;
  final Future<void> Function(String actorUid) requireCapability;
  static String resource(String id) => 'workflowModuleReopen:$id';
  AppUser _actor([String? uid]) {
    final actor = requireActor();
    if (!actor.isApproved ||
        !actor.canReopenJobModule ||
        (uid != null && actor.uid != uid)) {
      throw StateError(
        'Return to the original approved account to check this module reopen.',
      );
    }
    return actor;
  }

  Future<DurableSubmission?> restore(String moduleId) async {
    final actor = _actor();
    final row = await store.findUnresolvedForResource(resource(moduleId));
    _actor(actor.uid);
    if (row != null) {
      _actor(row.actorUid);
      _command(row);
    }
    return row;
  }

  WorkflowCommand _command(DurableSubmission row) {
    final envelope = durableSubmissionJsonObject(row.envelopeJson);
    final raw = Map<String, dynamic>.from(envelope['command'] as Map);
    final payload = Map<String, Object?>.from(raw['payload'] as Map);
    if (row.actorUid == null ||
        row.actorUid!.isEmpty ||
        row.protocol != 'maintenanceWorkflow.v2' ||
        envelope['originActorUid'] != row.actorUid ||
        envelope['protocolVersion'] != 2 ||
        raw['commandType'] != 'reopenWorkflowModule' ||
        raw['commandId'] != row.requestId ||
        raw['aggregateId'] != row.aggregateId ||
        payload.length != 2 ||
        payload['moduleFirestoreId'] is! String ||
        payload['reason'] is! String ||
        (payload['reason'] as String).trim().isEmpty ||
        row.resourceKey != resource(payload['moduleFirestoreId'] as String)) {
      throw StateError('Saved module reopen identity needs review.');
    }
    return WorkflowCommand(
      commandId: row.requestId,
      type: WorkflowCommandType.reopenWorkflowModule,
      aggregateId: row.aggregateId,
      expectedVersion: raw['expectedVersion'] as int,
      payload: payload,
    );
  }

  Future<DurableSubmission> prepare({
    required String actorUid,
    required String executionId,
    required int workflowVersion,
    required String reason,
    required JobModuleInstance baseline,
  }) async {
    _actor(actorUid);
    if (!baseline.isSynced ||
        baseline.firestoreId == null ||
        baseline.jobExecutionFirestoreId != executionId ||
        baseline.isDeleted ||
        !const {
          JobModuleStatus.submitted,
          JobModuleStatus.accepted,
          JobModuleStatus.notApplicable,
        }.contains(baseline.status)) {
      throw StateError(
        'Sync and review this module before saving a reopen request.',
      );
    }
    final canonical = JobModuleInstance.fromMap(
      baseline.toMap(),
      baseline.firestoreId!,
    );
    if (canonical.laneKey == null ||
        !canonical.fieldDefinitionsReadResult.isValid ||
        !canonical.responsesReadResult.isValid ||
        !canonical.actionsReadResult.isValid) {
      throw StateError(
        'The module baseline needs review before any request is sent.',
      );
    }
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.reopenWorkflowModule,
      aggregateId: executionId,
      expectedVersion: workflowVersion,
      payload: {
        'moduleFirestoreId': baseline.firestoreId,
        'reason': reason.trim(),
      },
    );
    final saved = await store.prepare(
      DurableSubmissionDraft(
        submissionId: command.commandId,
        actorUid: actorUid,
        requestId: command.commandId,
        aggregateId: executionId,
        resourceKey: resource(baseline.firestoreId!),
        protocol: 'maintenanceWorkflow.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actorUid,
          'command': command.toMap(),
        }),
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'module': baseline.toMap(),
          'local': jobModuleLocalSnapshot(baseline),
        }),
      ),
    );
    _actor(actorUid);
    return saved;
  }

  WorkflowCommandReceipt _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final command = _command(saved),
        receipt = WorkflowCommandReceipt.fromMap(raw);
    final baseline = _baseline(saved);
    if (receipt.commandId != command.commandId ||
        receipt.resultKey != 'workflow-module-reopened' ||
        receipt.aggregateVersion != command.expectedVersion + 1 ||
        receipt.result.length != 3 ||
        receipt.result['moduleFirestoreId'] !=
            command.payload['moduleFirestoreId'] ||
        receipt.result['laneKey'] != baseline.laneKey ||
        receipt.result['laneReactivated'] is! bool) {
      throw StateError(
        'The receipt does not confirm this saved module reopen.',
      );
    }
    return receipt;
  }

  Map<String, dynamic> _metadata(DurableSubmission row) {
    final data = durableSubmissionJsonObject(row.displayMetadataJson!);
    if (data.length != 3 || data['schemaVersion'] != 1) {
      throw StateError('Saved module baseline needs review.');
    }
    return data;
  }

  JobModuleInstance _baseline(DurableSubmission row) {
    final id = _command(row).payload['moduleFirestoreId'] as String;
    return JobModuleInstance.fromMap(
      Map<String, dynamic>.from(_metadata(row)['module'] as Map),
      id,
    );
  }

  // The server validates an existing receipt before its version fence. Only
  // this exact forward-only conflict proves this frozen command cannot commit.
  bool _isNewerVersionRefusal(DurableSubmission saved, Object error) {
    if (error is! WorkflowException ||
        error.code != WorkflowErrorCode.versionConflict) {
      return false;
    }
    final details = error.details;
    final expected = _command(saved).expectedVersion;
    return details.length == 3 &&
        details['workflowCode'] == 'workflow-version-conflict' &&
        details['expectedVersion'] is int &&
        details['expectedVersion'] == expected &&
        details['actualVersion'] is int &&
        (details['actualVersion'] as int) > expected;
  }

  Future<JobModuleInstance> check(String submissionId) async {
    var saved = await store.read(submissionId);
    if (saved == null) {
      throw StateError('The saved module reopen is missing. Nothing was sent.');
    }
    _actor(saved.actorUid);
    _command(saved);
    if (!saved.state.isAccepted) {
      await requireCapability(saved.actorUid!);
      _actor(saved.actorUid);
      final claim = await store.claim(
        submissionId: submissionId,
        actorUid: saved.actorUid!,
      );
      if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
        saved = claim.submission;
      } else {
        if (!claim.mayDispatch) {
          throw StateError(
            'This reopen is being checked or needs review. No replacement was sent.',
          );
        }
        late String receiptJson;
        try {
          _actor(saved.actorUid);
          final receipt = await gateway.executeOriginBoundEnvelope(
            saved.envelopeJson,
          );
          receiptJson = jsonEncode({
            'commandId': receipt.commandId,
            'resultKey': receipt.resultKey,
            'aggregateVersion': receipt.aggregateVersion,
            'result': receipt.result,
            'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
          });
          _receipt(saved, durableSubmissionJsonObject(receiptJson));
        } catch (error) {
          final refused = _isNewerVersionRefusal(saved, error);
          final outcome = await store.recordOutcome(
            claim,
            state: refused
                ? DurableSubmissionState.rejected
                : DurableSubmissionState.uncertain,
            errorCode: refused
                ? 'workflow-version-conflict'
                : 'module-reopen-uncertain',
            message: refused
                ? 'The workflow advanced before this request was applied. Its original record is retained. Synchronize and review the module before starting a new reopen.'
                : 'The original reopen request is saved. Check it again to confirm the outcome.',
          );
          if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
            return check(submissionId);
          }
          if (refused) {
            throw StateError(
              'The workflow changed. Synchronize and review the module, then start a new reopen. The refused request is retained.',
            );
          }
          rethrow;
        }
        saved = await store.settleAccepted(
          submissionId: submissionId,
          envelopeSha256: saved.envelopeSha256,
          receiptJson: receiptJson,
          validateReceipt: (row, receipt) {
            _receipt(row, receipt);
            return true;
          },
        );
      }
    }
    // Acceptance stays durable before every read and local transaction below.
    final actor = _actor(saved.actorUid);
    final receipt = _receipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    final command = _command(saved);
    final remote = await readWorkflowReopenedModule(
      read: readDocument,
      receipt: receipt,
      executionId: saved.aggregateId,
      moduleId: command.payload['moduleFirestoreId'] as String,
      actorUid: saved.actorUid!,
      reason: command.payload['reason'] as String,
      baseline: _baseline(saved),
    );
    _actor(saved.actorUid);
    final local = Map<String, dynamic>.from(_metadata(saved)['local'] as Map);
    final adopted = await modules.applyWorkflowModuleReopenProjection(
      remote,
      actor: actor,
      expectedLocal: JobModuleSaveBaseline.fromSnapshot(local),
    );
    _actor(saved.actorUid);
    await store.markReconciled(
      submissionId: submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid);
    return adopted;
  }
}
