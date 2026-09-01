import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../data/maintenance_model.dart';
import '../domain/issue_administrative_closure.dart';

WorkflowCommand buildMaintenanceIssueAdministrativeClosureCommand({
  required MaintenanceRecord ticket,
  required IssueAdministrativeClosureDisposition disposition,
  required String reason,
  DateTime? commandTime,
}) {
  final ticketId = ticket.firestoreId?.trim();
  if (ticketId == null || ticketId.isEmpty) {
    throw StateError('A governed issue requires a stable remote identity.');
  }
  if (!ticket.issueLanePlanReadResult.isValid) {
    throw StateError(
      'Accountable lane evidence must be reconciled before closure.',
    );
  }
  if (!ticket.isSynced) {
    throw StateError(
      'Synchronize this issue before applying an administrative closure.',
    );
  }
  final endingRetainedRelevance =
      ticket.status == TicketStatus.closedWithoutResolution &&
      ticket.isResolved &&
      ticket.administrativeClosure?.disposition ==
          IssueAdministrativeClosureDisposition.stillRelevant &&
      disposition == IssueAdministrativeClosureDisposition.relevanceEnded;
  if (ticket.isDeleted) {
    throw StateError('A deleted issue cannot be administratively changed.');
  }
  if (ticket.status == TicketStatus.closedWithoutResolution &&
      !endingRetainedRelevance) {
    throw StateError(
      'Only a retained administrative closure can end its relevance.',
    );
  }
  if (!endingRetainedRelevance &&
      (ticket.status.isTerminal || ticket.isResolved)) {
    throw StateError('Only an active issue can be closed without resolution.');
  }
  final cleanReason = reason.trim();
  if (cleanReason.isEmpty || cleanReason.length > 2000) {
    throw StateError(
      'Closure reason is required and cannot exceed 2000 characters.',
    );
  }
  return WorkflowCommandFactory.create(
    type: WorkflowCommandType.closeMaintenanceTicketWithoutResolution,
    aggregateId: ticketId,
    expectedVersion: ticket.version,
    now: commandTime,
    payload: <String, Object?>{
      'disposition': disposition.name,
      'reason': cleanReason,
    },
  );
}

void validateMaintenanceIssueAdministrativeClosureReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
  required IssueAdministrativeClosureDisposition disposition,
}) {
  if (command.type !=
          WorkflowCommandType.closeMaintenanceTicketWithoutResolution ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-closed-without-resolution' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}' ||
      receipt.result['disposition'] != disposition.name ||
      receipt.result['cancelledCoordination'] is! bool) {
    throw StateError(
      'The administrative-closure receipt is inconsistent with the issue.',
    );
  }
}
