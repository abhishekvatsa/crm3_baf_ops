import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/issue_lane_management_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('removing the primary lane adopts a surviving primary', (
    tester,
  ) async {
    final ticket =
        MaintenanceRecord()
          ..assetType = AssetType.base
          ..assetNumber = 201
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Cold leak test failed'
          ..routedTo = RoutedTo.electrical
          ..status = TicketStatus.open
          ..isResolved = false;
    ticket.issueLanePlan = IssueLanePlan.initial(const <String>[
      'electrical',
      'mechanical',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => showIssueLaneManagementDialog(
                        context,
                        ticket: ticket,
                      ),
                  child: const Text('Open lane manager'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open lane manager'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Electrical'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButtonFormField<RoutedTo>>(
      find.byType(DropdownButtonFormField<RoutedTo>),
    );
    expect(dropdown.initialValue, RoutedTo.mechanical);
  });

  testWidgets('keeps overlong server-bound values in the open dialog', (
    tester,
  ) async {
    final ticket =
        MaintenanceRecord()
          ..assetType = AssetType.base
          ..assetNumber = 201
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Cold leak test failed'
          ..routedTo = RoutedTo.electrical
          ..status = TicketStatus.open
          ..isResolved = false;
    ticket.issueLanePlan = IssueLanePlan.initial(const <String>['electrical']);
    IssueLaneChange? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showIssueLaneManagementDialog(
                      context,
                      ticket: ticket,
                    );
                  },
                  child: const Text('Open lane manager'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open lane manager'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('issue-lane-change-reason')),
      'R'.padRight(2001, 'R'),
    );
    await tester.tap(find.text('Apply lanes'));
    await tester.pump();

    expect(
      find.text('Keep the reason within 2,000 characters.'),
      findsOneWidget,
    );
    expect(find.text('Manage accountable lanes'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const Key('issue-lane-change-reason')),
      'Add Operations coordination for this repair.',
    );
    final othersChip = find.widgetWithText(FilterChip, 'Others');
    await tester.ensureVisible(othersChip);
    await tester.tap(othersChip);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('issue-lane-other-department')),
      'T'.padRight(81, 'T'),
    );
    await tester.tap(find.text('Apply lanes'));
    await tester.pump();

    expect(
      find.text('Keep the receiving team name within 80 characters.'),
      findsOneWidget,
    );
    expect(find.text('Manage accountable lanes'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byKey(const Key('issue-lane-other-department')),
      'Utilities',
    );
    await tester.tap(find.text('Apply lanes'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.otherDepartment, 'Utilities');
    expect(result!.reason, 'Add Operations coordination for this repair.');
  });
}
