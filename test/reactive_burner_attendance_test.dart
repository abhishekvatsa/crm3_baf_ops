import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_attendance_history.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/burner_attendance_history_view.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_resolution_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';

void main() {
  final performed = DateTime.utc(2026, 9, 20, 7);
  final recorded = performed.add(const Duration(hours: 2));
  ComponentAction action(int revision, BurnerResolutionOutcome outcome) => buildBurnerComponentAction(
    ticketId: 'issue-1', furnaceNumber: 7, burnerPosition: 2,
    code: BurnerActionCode.uvDetectorCleaning, outcome: outcome,
    performedBy: 'Operator', performedAt: performed, attendanceRevision: revision);
  Map<String, Object?> entry() => {'requestId': 'visit-1',
    'performedAt': performed.toIso8601String(), 'recordedAt': recorded.toIso8601String(),
    'recordedByUid': 'operator-1', 'recordedByName': 'Operator', 'remarks': 'Still locked out after cleaning.',
    'actionsJson': ComponentAction.encode([action(3, BurnerResolutionOutcome.remainsLockedOut)])};

  test('separate visits cannot reuse physical action identities', () {
    final first = action(3, BurnerResolutionOutcome.remainsLockedOut);
    final later = action(4, BurnerResolutionOutcome.returnedToService);
    expect(first.id, isNot(later.id));
    expect(first.attendanceSessionId, 'burner_issue-1_2_r3');
  });
  test('non-restored work produces attendance acceptance, never repair acceptance', () {
    final ticket = MaintenanceRecord()..firestoreId = 'issue-1'..version = 3
      ..routedTo = RoutedTo.instrumentation
      ..isSynced = true..issueLanePlan = IssueLanePlan.initial(['instrumentation']);
    final command = buildMaintenanceIssueResolutionCommand(ticket: ticket,
      endDate: performed, remarks: 'Still locked out.', teamsInvolved: ['instrumentation'],
      actions: [action(3, BurnerResolutionOutcome.remainsLockedOut)]);
    expect(command.payload['attendanceOnly'], isTrue);
    expect(command.payload['burnerAttendanceContractVersion'], 1);
    WorkflowCommandReceipt receipt(String key, List<String> lanes) => WorkflowCommandReceipt(
      commandId: command.commandId, resultKey: key, aggregateVersion: 4,
      result: {'ticketId': 'issue-1', 'auditId': 'server_maintenance_ticket_${command.commandId}', 'completedLanes': lanes},
      appliedAt: recorded);
    expect(() => validateMaintenanceIssueResolutionReceipt(command: command,
      receipt: receipt('maintenance-ticket-attendance-recorded', []), assignedLanes: ['instrumentation']), returnsNormally);
    expect(() => validateMaintenanceIssueResolutionReceipt(command: command,
      receipt: receipt('maintenance-ticket-resolved', ['instrumentation']), assignedLanes: ['instrumentation']), throwsStateError);
  });
  test('history keeps physical and recording times separate', () {
    final history = readBurnerAttendanceHistory(jsonEncode({'burnerAttendanceHistory': [entry()]}));
    expect(history.single.performedAt.toUtc(), performed);
    expect(history.single.recordedAt.toUtc(), recorded);
    expect(history.single.summary, contains('remainsLockedOut'));
  });
  test('malformed or duplicated attendance cannot become empty history', () {
    expect(() => readBurnerAttendanceHistory(jsonEncode({'burnerAttendanceHistory': [{...entry(), 'recordedAt': 'invalid'}]})), throwsA(isA<FormatException>()));
    expect(() => readBurnerAttendanceHistory(jsonEncode({'burnerAttendanceHistory': [entry(), entry()]})), throwsFormatException);
  });
  testWidgets('unreadable attendance is visibly incomplete', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BurnerAttendanceHistoryView(metadataJson: '{"burnerAttendanceHistory":{}}'))));
    expect(find.text('Burner attendance history is incomplete or unreadable.'), findsOneWidget);
  });
}
