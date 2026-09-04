import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_resolution_command.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/widgets/action_mini_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/component_action_time_contract_v1.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  for (final row in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test(
      '${row['name']}: issue and planned actions carry the same UTC instant',
      () {
        final action = _action(
          DateTime.parse(row['performedAt'] as String).toLocal(),
          updatedAt: DateTime.parse(row['updatedAt'] as String).toLocal(),
        );
        expect(action.createdAt.isUtc, isFalse);
        final ticket =
            MaintenanceRecord()
              ..firestoreId = 'ticket-time-contract'
              ..isSynced = true
              ..version = 1
              ..startDate = DateTime.parse(fixture['workStartedAt'] as String)
              ..routedTo = RoutedTo.mechanical
              ..issueLanePlan = IssueLanePlan.initial(const ['mechanical']);
        final command = buildMaintenanceIssueResolutionCommand(
          ticket: ticket,
          endDate: DateTime.parse(fixture['endDate'] as String),
          remarks: 'Inspection completed',
          teamsInvolved: const ['mechanical'],
          actions: [action],
        );
        final issueAction =
            (jsonDecode(command.payload['actionsJson'] as String) as List)
                .single;
        final execution = JobExecution()..actions = [action];
        final plannedAction =
            (jsonDecode(execution.actionsJson) as List).single;
        for (final wire in [action.toMap(), issueAction, plannedAction]) {
          expect(wire['createdAt'], row['createdAtWire']);
          expect(wire['updatedAt'], row['updatedAtWire']);
        }
        expect(command.payload['endDate'], fixture['endDate']);
      },
    );
  }

  for (final raw in [
    '2026-08-14T21:15:00.123456',
    '2026-08-14T21:15:00.123456+05:30',
    '2026-08-14T15:45:00Z',
  ]) {
    test('retained history keeps its original timestamp text: $raw', () {
      final stored =
          _action(DateTime.utc(2026, 8, 14, 15, 45)).toMap()
            ..['createdAt'] = raw
            ..['updatedAt'] = raw;
      final decoded = ComponentAction.fromMap(stored);
      final encoded = ComponentAction.encode([
        decoded,
        _action(DateTime.utc(2026, 8, 14, 15, 50).toLocal()),
      ]);
      final rows = jsonDecode(encoded) as List;
      expect(rows.first, stored);
      expect(rows.last['createdAt'], '2026-08-14T15:50:00.000Z');
      expect(rows.last['updatedAt'], isNull);
    });
  }

  testWidgets('an action read back in UTC is displayed in local time', (
    tester,
  ) async {
    final instant = DateTime.utc(2026, 8, 14, 15, 45);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActionMiniCard(action: _action(instant))),
      ),
    );
    final context = tester.element(find.byType(ActionMiniCard));
    final label = TimeOfDay.fromDateTime(instant.toLocal()).format(context);
    expect(find.text(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ComponentAction _action(DateTime createdAt, {DateTime? updatedAt}) =>
    ComponentAction(
      asset: 'Furnace 7',
      component: 'Furnace shell',
      actionType: ActionType.inspection,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
