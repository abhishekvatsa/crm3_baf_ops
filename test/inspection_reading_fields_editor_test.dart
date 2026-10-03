import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_reading_fields_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fields = <InspectionReadingField>[
  InspectionReadingField(
    id: 'verified',
    label: 'Seal verified',
    valueType: InspectionValueType.boolean,
  ),
  InspectionReadingField(
    id: 'due_date',
    label: 'Next examination',
    valueType: InspectionValueType.date,
  ),
  InspectionReadingField(
    id: 'pressure',
    label: 'Pressure',
    valueType: InspectionValueType.number,
    unit: 'bar',
    minimumValue: 1,
    maximumValue: 5,
  ),
  InspectionReadingField(
    id: 'condition',
    label: 'Appearance',
    valueType: InspectionValueType.choice,
    choiceValues: ['Dry', 'Damp'],
  ),
  InspectionReadingField(
    id: 'comment',
    label: 'Witnessed condition',
    valueType: InspectionValueType.text,
  ),
];

const readings = <InspectionReadingValue>[
  InspectionReadingValue(
    fieldId: 'verified',
    valueType: InspectionValueType.boolean,
    value: false,
  ),
  InspectionReadingValue(
    fieldId: 'due_date',
    valueType: InspectionValueType.date,
    value: '2032-02-29',
  ),
  InspectionReadingValue(
    fieldId: 'pressure',
    valueType: InspectionValueType.number,
    value: 7.5,
  ),
  InspectionReadingValue(
    fieldId: 'condition',
    valueType: InspectionValueType.choice,
    value: 'Damp',
  ),
  InspectionReadingValue(
    fieldId: 'comment',
    valueType: InspectionValueType.text,
    value: 'Witnessed with operator',
  ),
];

void main() {
  late GlobalKey<FormState> form;
  late GlobalKey<InspectionReadingFieldsEditorState> editor;

  Future<void> show(
    WidgetTester tester, {
    List<InspectionReadingValue> initial = const [],
    double scale = 1,
  }) async {
    form = GlobalKey<FormState>();
    editor = GlobalKey<InspectionReadingFieldsEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: InspectionReadingFieldsEditor(
                  key: editor,
                  fields: fields,
                  initialValues: initial,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'unanswered boolean and every other reading block a partial submission',
    (tester) async {
      await show(tester);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No'))
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Yes'))
            .selected,
        isFalse,
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose Yes or No.'), findsOneWidget);
      expect(find.text('Choose an observed value.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'No'));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No'))
            .selected,
        isTrue,
      );
      expect(form.currentState!.validate(), isFalse);
    },
  );

  testWidgets(
    'correction prefills every value and preserves false, future leap date and order',
    (tester) async {
      await show(tester, initial: readings);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No'))
            .selected,
        isTrue,
      );
      expect(find.text('29-02-2032'), findsOneWidget);
      expect(form.currentState!.validate(), isTrue);
      expect(
        editor.currentState!
            .validatedValues()
            .map((value) => value.toMap())
            .toList(),
        readings.map((value) => value.toMap()).toList(),
      );
      await tester.enterText(
        find.byKey(const ValueKey('inspection-reading-due_date')),
        '31-12-2040',
      );
      expect(form.currentState!.validate(), isTrue);
      final corrected = editor.currentState!.validatedValues();
      expect(corrected[1].value, '2040-12-31');
      expect(
        corrected
            .where((value) => value.fieldId != 'due_date')
            .map((value) => value.toMap()),
        readings
            .where((value) => value.fieldId != 'due_date')
            .map((value) => value.toMap()),
      );
    },
  );

  testWidgets('invalid calendar dates and non-finite numbers stay invalid', (
    tester,
  ) async {
    await show(tester, initial: readings);
    for (final invalid in [
      '29-02-2031',
      '31-04-2032',
      '2032-02-29',
      '1-2-2032',
    ]) {
      await tester.enterText(
        find.byKey(const ValueKey('inspection-reading-due_date')),
        invalid,
      );
      expect(form.currentState!.validate(), isFalse, reason: invalid);
    }
    await tester.enterText(
      find.byKey(const ValueKey('inspection-reading-due_date')),
      '29-02-2032',
    );
    for (final invalid in ['NaN', 'Infinity', '-Infinity']) {
      await tester.enterText(
        find.byKey(const ValueKey('inspection-reading-pressure')),
        invalid,
      );
      expect(form.currentState!.validate(), isFalse, reason: invalid);
    }
  });

  testWidgets(
    'calendar picker accepts a future reading date without changing its day',
    (tester) async {
      await show(tester, initial: readings);
      await tester.tap(find.byTooltip('Choose Next examination date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(editor.currentState!.validatedValues()[1].value, '2032-02-29');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'labelled readings remain reachable on a narrow screen with enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 680));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await show(tester, initial: readings, scale: 2);
      await tester.ensureVisible(
        find.byKey(const ValueKey('inspection-reading-comment')),
      );
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
