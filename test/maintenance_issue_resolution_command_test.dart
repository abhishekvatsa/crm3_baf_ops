import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_administrative_closure_command.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_resolution_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';

void main() {
  test(
    'resolution command carries all accountable parties to server authority',
    () {
      final ticket = _ticket();
      final command = buildMaintenanceIssueResolutionCommand(
        ticket: ticket,
        endDate: DateTime.utc(2026, 8, 23, 8, 45),
        remarks: ' Mechanical and Electrical checks completed. ',
        teamsInvolved: const <String>['electrical', 'operations'],
        actions: const [],
        commandTime: DateTime.utc(2026, 8, 23, 8, 46),
      );

      expect(command.type, WorkflowCommandType.resolveMaintenanceTicket);
      expect(command.aggregateId, 'issue-1');
      expect(command.expectedVersion, 7);
      expect(command.payload, <String, Object?>{
        'endDate': '2026-08-23T08:45:00.000Z',
        'remarks': 'Mechanical and Electrical checks completed.',
        'teamsInvolved': <String>['mechanical', 'electrical', 'operations'],
        'actionsJson': '[]',
      });
    },
  );

  test('resolution receipt must close the exact assigned lane set', () {
    final ticket = _ticket();
    final command = buildMaintenanceIssueResolutionCommand(
      ticket: ticket,
      endDate: DateTime.utc(2026, 8, 23, 8, 45),
      remarks: 'Work completed.',
      teamsInvolved: const <String>[],
      actions: const [],
    );
    final valid = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-resolved',
      aggregateVersion: 8,
      result: <String, Object?>{
        'ticketId': 'issue-1',
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'completedLanes': <String>['mechanical', 'electrical'],
      },
      appliedAt: DateTime.utc(2026, 8, 23, 8, 46),
    );

    expect(
      () => validateMaintenanceIssueResolutionReceipt(
        command: command,
        receipt: valid,
        assignedLanes: ticket.issueLanePlan.assignedLanes,
      ),
      returnsNormally,
    );
    expect(
      () => validateMaintenanceIssueResolutionReceipt(
        command: command,
        receipt: WorkflowCommandReceipt(
          commandId: command.commandId,
          resultKey: valid.resultKey,
          aggregateVersion: valid.aggregateVersion,
          result: <String, Object?>{
            ...valid.result,
            'completedLanes': <String>['mechanical'],
          },
          appliedAt: valid.appliedAt,
        ),
        assignedLanes: ticket.issueLanePlan.assignedLanes,
      ),
      throwsStateError,
    );
  });

  test('reopen command and receipt preserve the assigned lane topology', () {
    final ticket = _ticket();
    final completedPlan = ticket.issueLanePlan.completeAll();
    ticket
      ..status = TicketStatus.resolved
      ..isResolved = true
      ..endDate = DateTime.utc(2026, 8, 23, 8)
      ..closedByUid = 'supervisor-1'
      ..closedByName = 'Supervisor'
      ..issueLanePlan = completedPlan;
    ticket
      ..acknowledgedByUid = 'supervisor-1'
      ..acknowledgedByName = 'Supervisor'
      ..acknowledgedAt = DateTime.utc(2026, 8, 23, 7, 30);
    final command = buildMaintenanceIssueReopenCommand(
      ticket: ticket,
      remarks: ' Recheck required after recurrence. ',
      commandTime: DateTime.utc(2026, 8, 23, 8, 30),
    );
    final receipt = WorkflowCommandReceipt(
      commandId: command.commandId,
      resultKey: 'maintenance-ticket-reopened',
      aggregateVersion: 8,
      result: <String, Object?>{
        'ticketId': 'issue-1',
        'auditId': 'server_maintenance_ticket_${command.commandId}',
        'assignedLanes': <String>['mechanical', 'electrical'],
      },
      appliedAt: DateTime.utc(2026, 8, 23, 8, 30),
    );

    expect(command.type, WorkflowCommandType.reopenMaintenanceTicket);
    expect(command.payload, <String, Object?>{
      'remarks': 'Recheck required after recurrence.',
    });
    expect(
      () => validateMaintenanceIssueReopenReceipt(
        command: command,
        receipt: receipt,
        assignedLanes: ticket.issueLanePlan.assignedLanes,
      ),
      returnsNormally,
    );
  });

  test('resolution and reopen reject an unsynchronized local boundary', () {
    final open = _ticket()..isSynced = false;
    expect(
      () => buildMaintenanceIssueResolutionCommand(
        ticket: open,
        endDate: DateTime.utc(2026, 8, 23, 8, 45),
        remarks: 'Work completed.',
        teamsInvolved: const <String>[],
        actions: const [],
      ),
      throwsStateError,
    );

    final closed =
        _ticket()
          ..isSynced = false
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..issueLanePlan = _ticket().issueLanePlan.completeAll();
    expect(
      () => buildMaintenanceIssueReopenCommand(ticket: closed),
      throwsStateError,
    );
  });

  test(
    'administrative closure accepts deferred work and validates its receipt',
    () {
      final ticket =
          _ticket()
            ..workflowDeferred = true
            ..workflowQueueState = 'deferred'
            ..workflowAggregateId = 'coordination-1'
            ..workflowComplianceId = 'compliance-1';
      final command = buildMaintenanceIssueAdministrativeClosureCommand(
        ticket: ticket,
        disposition: IssueAdministrativeClosureDisposition.stillRelevant,
        reason:
            'The active charge has ended, but the unresolved condition remains relevant.',
        commandTime: DateTime.utc(2026, 8, 23, 8, 30),
      );
      final receipt = WorkflowCommandReceipt(
        commandId: command.commandId,
        resultKey: 'maintenance-ticket-closed-without-resolution',
        aggregateVersion: 8,
        result: <String, Object?>{
          'ticketId': 'issue-1',
          'auditId': 'server_maintenance_ticket_${command.commandId}',
          'disposition': 'stillRelevant',
          'cancelledCoordination': true,
          'cancelledWorkflowId': 'coordination-1',
          'cancelledComplianceId': 'compliance-1',
        },
        appliedAt: DateTime.utc(2026, 8, 23, 8, 30),
      );

      expect(
        command.type,
        WorkflowCommandType.closeMaintenanceTicketWithoutResolution,
      );
      expect(command.payload, <String, Object?>{
        'disposition': 'stillRelevant',
        'reason':
            'The active charge has ended, but the unresolved condition remains relevant.',
      });
      expect(
        () => validateMaintenanceIssueAdministrativeClosureReceipt(
          command: command,
          receipt: receipt,
          disposition: IssueAdministrativeClosureDisposition.stillRelevant,
        ),
        returnsNormally,
      );
    },
  );

  test('administrative closure rejects a weak reason and terminal record', () {
    expect(
      () => buildMaintenanceIssueAdministrativeClosureCommand(
        ticket: _ticket(),
        disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
        reason: 'Too short',
      ),
      throwsStateError,
    );

    final closed =
        _ticket()
          ..status = TicketStatus.closedWithoutResolution
          ..isResolved = true;
    closed.administrativeClosure = const IssueAdministrativeClosure(
      disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
      reason: 'The operating context ended and no further action is required.',
    );
    expect(
      () => buildMaintenanceIssueAdministrativeClosureCommand(
        ticket: closed,
        disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
        reason:
            'The operating context ended and no further action is required.',
      ),
      throwsStateError,
    );
  });
}

MaintenanceRecord _ticket() {
  final ticket =
      MaintenanceRecord()
        ..firestoreId = 'issue-1'
        ..assetType = AssetType.furnace
        ..assetNumber = 7
        ..maintenanceType = MaintenanceType.breakdown
        ..description = 'Drive vibration'
        ..routedTo = RoutedTo.mechanical
        ..startDate = DateTime.utc(2026, 8, 23, 7)
        ..createdAt = DateTime.utc(2026, 8, 23, 7)
        ..updatedAt = DateTime.utc(2026, 8, 23, 8)
        ..version = 7
        ..isSynced = true
        ..status = TicketStatus.open
        ..isResolved = false;
  ticket.issueLanePlan = IssueLanePlan.initial(const <String>[
    'mechanical',
    'electrical',
  ]);
  return ticket;
}
