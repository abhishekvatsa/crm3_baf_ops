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
}
