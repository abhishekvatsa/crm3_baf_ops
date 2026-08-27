import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../data/maintenance_model.dart';

WorkflowCommand buildMaintenanceIssueResolutionCommand({
  required MaintenanceRecord ticket,
  required DateTime endDate,
  required String remarks,
  required Iterable<String> teamsInvolved,
  required Iterable<ComponentAction> actions,
  DateTime? commandTime,
}) {
  final ticketId = ticket.firestoreId?.trim();
  final laneRead = ticket.issueLanePlanReadResult;
  if (ticketId == null || ticketId.isEmpty) {
    throw StateError('A governed issue requires a stable remote identity.');
  }
  if (!laneRead.isValid || laneRead.value == null) {
    throw StateError(
      'Accountable lane evidence must be reconciled before closure.',
    );
  }
  if (!ticket.isSynced) {
    throw StateError(
      'Synchronize this issue before applying a governed resolution.',
    );
  }
  if (ticket.isDeleted || ticket.isResolved || ticket.isWorkflowActionBlocked) {
    throw StateError('Only an active, released issue can be resolved.');
  }
  final cleanRemarks = remarks.trim();
  if (cleanRemarks.isEmpty) {
    throw StateError('Resolution remarks are required.');
  }
  final assigned = laneRead.value!.assignedLanes;
  final teams = <String>{...assigned, ...teamsInvolved}.toList(growable: false);
  final actionList = actions.toList(growable: false);

  return WorkflowCommandFactory.create(
    type: WorkflowCommandType.resolveMaintenanceTicket,
    aggregateId: ticketId,
    expectedVersion: ticket.version,
    now: commandTime,
    payload: <String, Object?>{
      'endDate': endDate.toUtc().toIso8601String(),
      'remarks': cleanRemarks,
      'teamsInvolved': teams,
      'actionsJson': ComponentAction.encode(actionList),
      'actionTargetContractVersion': 1,
    },
  );
}

void validateMaintenanceIssueResolutionReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
  required Iterable<String> assignedLanes,
}) {
  final completed = receipt.result['completedLanes'];
  final expected = assignedLanes.toList(growable: false);
  if (command.type != WorkflowCommandType.resolveMaintenanceTicket ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-resolved' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}' ||
      completed is! List ||
      completed.length != expected.length) {
    throw StateError(
      'The governed issue-resolution receipt is inconsistent with the issue.',
    );
  }
  for (var index = 0; index < expected.length; index++) {
    if (completed[index] != expected[index]) {
      throw StateError(
        'The governed issue-resolution receipt has inconsistent lane evidence.',
      );
    }
  }
}

WorkflowCommand buildMaintenanceIssueReopenCommand({
  required MaintenanceRecord ticket,
  String? remarks,
  DateTime? commandTime,
}) {
  final ticketId = ticket.firestoreId?.trim();
  final laneRead = ticket.issueLanePlanReadResult;
  if (ticketId == null || ticketId.isEmpty) {
    throw StateError('A governed issue requires a stable remote identity.');
  }
  if (!laneRead.isValid || laneRead.value == null) {
    throw StateError(
      'Accountable lane evidence must be reconciled before reopening.',
    );
  }
  if (!ticket.isSynced) {
    throw StateError(
      'Synchronize this issue before applying a governed reopen.',
    );
  }
  if (ticket.isDeleted || !ticket.isResolved || ticket.workflowDeferred) {
    throw StateError('Only a resolved, released issue can be reopened.');
  }
  final cleanRemarks = remarks?.trim();
  return WorkflowCommandFactory.create(
    type: WorkflowCommandType.reopenMaintenanceTicket,
    aggregateId: ticketId,
    expectedVersion: ticket.version,
    now: commandTime,
    payload: <String, Object?>{
      'remarks':
          cleanRemarks == null || cleanRemarks.isEmpty ? null : cleanRemarks,
    },
  );
}

void validateMaintenanceIssueReopenReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
  required Iterable<String> assignedLanes,
}) {
  final assigned = receipt.result['assignedLanes'];
  final expected = assignedLanes.toList(growable: false);
  if (command.type != WorkflowCommandType.reopenMaintenanceTicket ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-reopened' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}' ||
      assigned is! List ||
      assigned.length != expected.length) {
    throw StateError(
      'The governed issue-reopen receipt is inconsistent with the issue.',
    );
  }
  for (var index = 0; index < expected.length; index++) {
    if (assigned[index] != expected[index]) {
      throw StateError(
        'The governed issue-reopen receipt has inconsistent lane evidence.',
      );
    }
  }
}
