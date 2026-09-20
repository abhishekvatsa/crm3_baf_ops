import 'dart:convert';

import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/repositories/workflow_repository.dart';
import '../../maintenance_workflow/services/workflow_online_executor.dart';
import 'maintenance_issue_create_command.dart';

/// Reuses the workflow journal as the sole immutable owner of ticket creation.
/// A changed local ticket remains a successor draft; it cannot replace A's bytes
/// when asking whether the server accepted creation A.
class MaintenanceCreationOwner {
  const MaintenanceCreationOwner({
    required this.repository,
    required this.executor,
    required this.currentActorUid,
  });

  final WorkflowRepository repository;
  final WorkflowOnlineExecutor executor;
  final String? Function() currentActorUid;

  void _requireActor(String actorUid) {
    if (actorUid.isEmpty || currentActorUid() != actorUid) {
      throw StateError('The original reporter must be signed in to recover this issue.');
    }
  }

  Future<({WorkflowCommand command, WorkflowCommandReceipt receipt, bool hasSuccessor})> execute({
    required WorkflowCommand draft,
    required String actorUid,
  }) async {
    // Freeze caller input before the first storage await.
    final frozen = jsonDecode(jsonEncode(draft.toMap())) as Map;
    _requireActor(actorUid);
    final accepted = await repository.getReceipt(draft.commandId);
    _requireActor(actorUid);
    final pending = await repository.getRetryCommand(draft.commandId);
    _requireActor(actorUid);
    Map saved = frozen;
    if (accepted != null) {
      final stored = jsonDecode(accepted.resultJson) as Map;
      final envelope = jsonDecode(stored['__workflowAcceptedEnvelopeV1'] as String) as Map;
      if (envelope['protocolVersion'] != 2 || envelope['originActorUid'] != actorUid) {
        throw StateError('The saved acceptance has no matching original account. Review is required.');
      }
      saved = envelope['command'] as Map;
    } else if (pending != null) {
      final stored = jsonDecode(pending.payloadJson) as Map;
      if (stored['__workflowOriginBoundV1'] != actorUid) {
        throw StateError('The saved creation has no matching original account. Review is required.');
      }
      saved = {'commandId': pending.commandId, 'commandType': pending.commandTypeKey,
        'aggregateId': pending.aggregateId, 'expectedVersion': pending.expectedVersion,
        'payload': stored['payload']};
    }
    if (saved['commandId'] != draft.commandId || saved['aggregateId'] != draft.aggregateId ||
        saved['commandType'] != WorkflowCommandType.createMaintenanceTicket.name || saved['expectedVersion'] != 0) {
      throw StateError('The retained creation identity is inconsistent. Nothing was replaced.');
    }
    final command = WorkflowCommand(commandId: saved['commandId'] as String,
      type: WorkflowCommandType.createMaintenanceTicket, aggregateId: saved['aggregateId'] as String,
      expectedVersion: 0, payload: Map<String, Object?>.from(saved['payload'] as Map));
    void validate(WorkflowCommandReceipt receipt) => validateMaintenanceIssueCreateReceipt(
      command: command, receipt: receipt, createVersion: 1);
    final receipt = await executor.execute(command, validateReceipt: validate);
    _requireActor(actorUid);
    validate(receipt);
    return (command: command, receipt: receipt,
      hasSuccessor: jsonEncode(command.toMap()) != jsonEncode(frozen));
  }
}
