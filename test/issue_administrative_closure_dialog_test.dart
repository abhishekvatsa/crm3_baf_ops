import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/issue_administrative_closure_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin closure requires a disposition and accountable reason', (
    tester,
  ) async {
    final ticket =
        MaintenanceRecord()
          ..assetType = AssetType.furnace
          ..assetNumber = 8
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Annealing-cycle observation remained open'
          ..routedTo = RoutedTo.mechanical
          ..status = TicketStatus.open
          ..isResolved = false
          ..workflowQueueState = 'deferred';
    IssueAdministrativeClosureDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showIssueAdministrativeClosureDialog(
                      context,
                      ticket: ticket,
                    );
                  },
                  child: const Text('Open closure'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open closure'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The linked Operations obligation will be cancelled with this closure.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Close issue'));
    await tester.pump();
    expect(find.text('Select why the issue is being closed.'), findsOneWidget);

    await tester.tap(find.text('Still relevant'));
    await tester.enterText(
      find.byType(TextField),
      'The cycle ended, but this unresolved condition must remain visible.',
    );
    await tester.tap(find.text('Close issue'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.disposition,
      IssueAdministrativeClosureDisposition.stillRelevant,
    );
    expect(
      result!.reason,
      'The cycle ended, but this unresolved condition must remain visible.',
    );
  });
}
