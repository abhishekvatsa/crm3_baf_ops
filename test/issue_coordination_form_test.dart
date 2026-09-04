import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_coordination_draft.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/issue_coordination_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final purpose in IssueCoordinationPurpose.values) {
    test('${purpose.name} respects server activity and location bounds', () {
      IssueCoordinationDraft draft(int length) =>
          IssueCoordinationDraft.validate(
            purpose: purpose,
            condition: IssueCoordinationCondition.activityRef,
            conditionRef: 'A' * length,
            defermentBasisKey: 'operationalCompliance',
            operationsSupportTypeKey: 'craneMovement',
            operationsResourceKey: 'crane',
            requestedLocation: 'A' * length,
            title: 'Release furnace',
            description: 'Position on the maintenance stand.',
            priorityKey: 'high',
          );
      expect(() => draft(300), returnsNormally);
      expect(() => draft(301), throwsFormatException);
    });
  }

  testWidgets('changing request purpose preserves entered title and evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    IssueCoordinationDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showIssueCoordinationDialog(
                      context,
                      ticket:
                          MaintenanceRecord()
                            ..assetType = AssetType.furnace
                            ..assetNumber = 7
                            ..chargeNoAtEvent = 12345,
                    );
                  },
                  child: const Text('Coordinate'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('Coordinate'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.ensureVisible(find.text('Activity complete'));
    await tester.tap(find.text('Activity complete'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('Request title')).controller!.text,
      'Await operational activity completion',
    );
    await tester.ensureVisible(find.text('Charge complete'));
    await tester.tap(find.text('Charge complete'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('Request title'));
    await tester.enterText(field('Request title'), 'Wait for crane 2');
    await tester.ensureVisible(
      field('Required action and completion evidence'),
    );
    await tester.enterText(
      field('Required action and completion evidence'),
      'Confirm Furnace 7 is positioned at stand 2.',
    );
    await tester.ensureVisible(find.text('Operations support'));
    await tester.tap(find.text('Operations support'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Deferment'));
    await tester.tap(find.text('Deferment'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('Request title')).controller!.text,
      'Wait for crane 2',
    );
    await tester.tap(find.text('Send to Operations'));
    await tester.pumpAndSettle();
    expect(result?.description, 'Confirm Furnace 7 is positioned at stand 2.');
    expect(result?.conditionChargeNo, 12345);
    expect(tester.takeException(), isNull);
  });
}
