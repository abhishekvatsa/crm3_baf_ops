import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_reading_contract_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy upgrade preserves numeric limits and refuses malformed nonempty limits',
    () {
      InspectionReadingField convert(String minimum, String maximum) =>
          prepareLegacyInspectionReadingField(
            id: 'existing',
            label: 'Pressure',
            valueType: InspectionValueType.number,
            unit: 'bar',
            choices: const [],
            minimum: minimum,
            maximum: maximum,
          );
      final preserved = convert('2', '4');
      expect(preserved.minimumValue, 2);
      expect(preserved.maximumValue, 4);
      expect(preserved.unit, 'bar');
      expect(convert('', '').minimumValue, isNull);
      for (final invalid in ['wrong', '2x', 'NaN', 'Infinity']) {
        expect(() => convert(invalid, '4'), throwsFormatException);
        expect(() => convert('2', invalid), throwsFormatException);
      }
      expect(() => convert('5', '4'), throwsFormatException);
    },
  );

  const yes = InspectionReadingField(
    id: 'completed',
    label: 'Completed?',
    valueType: InspectionValueType.boolean,
  );
  const date = InspectionReadingField(
    id: 'completed_on',
    label: 'Completion date',
    valueType: InspectionValueType.date,
  );

  Future<void> mount(
    WidgetTester tester,
    List<InspectionReadingField> initial,
    ValueChanged<List<InspectionReadingField>> changed,
  ) async {
    var fields = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => InspectionReadingContractEditor(
                fields: fields,
                onChanged: (next) {
                  setState(() => fields = next);
                  changed(next);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('add Date alongside Yes/No, edit/reorder retain field identity', (
    tester,
  ) async {
    var saved = <InspectionReadingField>[yes];
    await mount(tester, saved, (next) => saved = next);
    await tap(
      tester,
      find.byKey(const ValueKey('inspection-contract-add-reading')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('inspection-reading-label')),
      'Completion date',
    );
    await tap(tester, find.byKey(const ValueKey('inspection-reading-type')));
    await tap(tester, find.text('Date (dd-mm-yyyy)').last);
    await tap(tester, find.byKey(const ValueKey('inspection-reading-save')));
    expect(saved.length, 2);
    expect(saved.first, same(yes));
    expect(saved.last.valueType, InspectionValueType.date);
    final dateId = saved.last.id;
    expect(dateId, matches(RegExp(r'^[a-z][a-z0-9_]{0,47}$')));
    await tap(tester, find.byKey(ValueKey('inspection-contract-edit-$dateId')));
    await tester.enterText(
      find.byKey(const ValueKey('inspection-reading-label')),
      'Completed on',
    );
    await tap(tester, find.byKey(const ValueKey('inspection-reading-save')));
    expect(saved.last.id, dateId);
    expect(saved.last.label, 'Completed on');
    await tap(tester, find.byKey(ValueKey('inspection-contract-up-$dateId')));
    expect(saved.map((field) => field.id), [dateId, 'completed']);
    expect(saved.last, same(yes));
  });

  testWidgets(
    'duplicate labels rejected and cancelling leaves contract intact',
    (tester) async {
      var changes = 0;
      await mount(tester, const [yes, date], (_) => changes++);
      await tap(
        tester,
        find.byKey(const ValueKey('inspection-contract-edit-completed_on')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('inspection-reading-label')),
        'completed?',
      );
      await tap(tester, find.byKey(const ValueKey('inspection-reading-save')));
      expect(
        find.text('Each reading needs a different label.'),
        findsOneWidget,
      );
      expect(changes, 0);
      await tap(tester, find.text('Cancel'));
      expect(find.text('Completion date'), findsOneWidget);
      expect(changes, 0);
    },
  );

  testWidgets('narrow large text editor preserves every label and action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: InspectionReadingContractEditor(
              fields: const [yes, date],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tap(
      tester,
      find.byKey(const ValueKey('inspection-contract-edit-completed_on')),
    );
    await tap(tester, find.byKey(const ValueKey('inspection-reading-save')));
    expect(
      find.byKey(const ValueKey('inspection-contract-field-completed_on')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
