import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../data/maintenance_model.dart';

WorkflowCommand buildMaintenanceWithdrawalCommand(MaintenanceRecord server, String reason) {
  final id = server.firestoreId;
  if (id == null || id.isEmpty || server.version < 1 || reason.trim().isEmpty) {
    throw StateError('A verified server issue and withdrawal reason are required.');
  }
  return WorkflowCommand(commandId: 'withdraw_${id}_v${server.version}',
    type: WorkflowCommandType.correctMaintenanceTicket, aggregateId: id,
    expectedVersion: server.version,
    payload: {'withdrawInError': true, 'corrections': <String, Object?>{}, 'reason': reason.trim()});
}

void validateMaintenanceWithdrawalReceipt(WorkflowCommand command, WorkflowCommandReceipt receipt) {
  if (receipt.commandId != command.commandId || receipt.resultKey != 'maintenance-ticket-withdrawn' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] != 'server_maintenance_ticket_${command.commandId}') {
    throw StateError('Issue withdrawal is not confirmed by a matching audited receipt.');
  }
}
