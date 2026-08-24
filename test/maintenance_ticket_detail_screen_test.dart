import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_correction_dialog.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('resolved issue dossier is readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final closedAt = DateTime.utc(2026, 8, 23, 12);
    final earlierAction = buildBurnerComponentAction(
      ticketId: 'ticket-closed-1',
      furnaceNumber: 7,
      burnerPosition: 3,
      code: BurnerActionCode.uvDetectorCleaning,
      outcome: BurnerResolutionOutcome.returnedToService,
      microampReading: 2.875,
      performedBy: 'I&A Two',
      performedAt: closedAt.subtract(const Duration(days: 2)),
      remarks: 'UV lens cleaned and flame signal checked.',
    );
    final currentAction = ComponentAction(
      asset: 'Furnace 7',
      component: 'Burner control relay',
      actionType: ActionType.repair,
      resolution: 'Relay contacts restored and tested.',
      performedBy: 'Electrical One',
      createdAt: closedAt.subtract(const Duration(hours: 2)),
      updatedAt: closedAt.subtract(const Duration(minutes: 90)),
    );
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-closed-1'
          ..version = 8
          ..isSynced = true
          ..assetType = AssetType.furnace
          ..assetNumber = 7
          ..maintenanceType = MaintenanceType.breakdown
          ..classification = 'burnerPressureInstability'
          ..description = 'Burner pressure instability was investigated.'
          ..routedTo = RoutedTo.instrumentation
          ..component = 'Burner system'
          ..subsystem = 'Combustion control'
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..loggedByUid = 'operator-1'
          ..loggedByName = 'Operator One'
          ..acknowledgedByUid = 'ia-1'
          ..acknowledgedByName = 'I&A One'
          ..acknowledgedAt = closedAt.subtract(const Duration(hours: 3))
          ..closedByUid = 'si-1'
          ..closedByName = 'SI One'
          ..startDate = closedAt.subtract(const Duration(hours: 4))
          ..endDate = closedAt
          ..createdAt = closedAt.subtract(const Duration(hours: 4))
          ..updatedAt = closedAt
          ..remarks = 'Flame signal stabilized after attendance.'
          ..actionsJson = ComponentAction.encode([currentAction])
          ..resolutionHistory = [
            ResolutionHistory(
              resolvedByUid: 'si-previous',
              resolvedByName: 'SI Previous',
              resolvedAt: closedAt.subtract(const Duration(days: 2)),
              actionsJson: ComponentAction.encode([earlierAction]),
              remarks: 'Reopened after the lockout recurred.',
              downtimeHours: 1.5,
              teamsInvolved: const ['I&A', 'Electrical'],
            ),
          ]
          ..issueLanePlan = IssueLanePlan.initial([
                RoutedTo.instrumentation.name,
              ])
              .acknowledge(RoutedTo.instrumentation.name)
              .complete(RoutedTo.instrumentation.name);

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: MaintenanceTicketDetailScreen(ticket: ticket, onCorrect: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Issue context'), findsOneWidget);
    expect(find.text('Accountability'), findsOneWidget);
    expect(find.text('Timeline and people'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Work recorded'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Work recorded'), findsOneWidget);
    expect(
      find.text(
        'Action time ${DateFormat('dd MMM yyyy, HH:mm').format(currentAction.createdAt.toLocal())}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Updated ${DateFormat('dd MMM yyyy, HH:mm').format(currentAction.updatedAt!.toLocal())}',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Closure evidence'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Closure evidence'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('earlier-closure-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Earlier closure 1'), findsOneWidget);
    expect(find.text('1.50 hours'), findsOneWidget);
    expect(find.text('I&A, Electrical'), findsOneWidget);
    expect(find.textContaining('Burner 3'), findsOneWidget);
    expect(find.textContaining('2.875 µA'), findsOneWidget);
    expect(
      find.textContaining(
        'Action time ${DateFormat('dd MMM yyyy, HH:mm').format(earlierAction.createdAt.toLocal())}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reopened after the lockout recurred.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ticket-detail-correct')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal correction warns the actor and locks accountability', (
    tester,
  ) async {
    final closedAt = DateTime.utc(2026, 8, 23, 12);
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-closed-2'
          ..version = 4
          ..isSynced = true
          ..assetType = AssetType.base
          ..assetNumber = 201
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Cold leak test failed after the operating cycle.'
          ..routedTo = RoutedTo.mechanical
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..startDate = closedAt.subtract(const Duration(hours: 3))
          ..endDate = closedAt
          ..createdAt = closedAt.subtract(const Duration(hours: 3))
          ..updatedAt = closedAt
          ..actionsJson = '[]'
          ..resolutionHistoryJson = '[]'
          ..issueLanePlan = IssueLanePlan.initial([RoutedTo.mechanical.name])
              .acknowledge(RoutedTo.mechanical.name)
              .complete(RoutedTo.mechanical.name);

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(body: MaintenanceTicketCorrectionDialog(ticket: ticket)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Do not invent, erase, or alter evidence'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Status, asset identity, closure authority'),
      findsOneWidget,
    );
    final route = tester.widget<DropdownButtonFormField<RoutedTo>>(
      find.byKey(const ValueKey('ticket-correction-route')),
    );
    expect(route.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });
}
