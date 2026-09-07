import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_response_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester, {
    required List<Map<String, dynamic>> definitions,
    required List<FieldResponse> initialResponses,
    required Future<void> Function(List<FieldResponse>) onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobModuleResponseForm(
              fieldDefinitions: definitions,
              initialResponses: initialResponses,
              isEditable: true,
              isBusy: false,
              onSave: onSave,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'uses canonical aliases and preserves an unanswered yes-no field',
    (tester) async {
      List<FieldResponse>? saved;
      await pumpForm(
        tester,
        definitions: const [
          {
            'name': 'pressure',
            'title': 'Pressure reading',
            'fieldType': 'numericWithUnit',
            'unit': 'bar',
            'order': 1,
            'moduleCode': 'PRESSURE-CHECK',
            'futureExtension': ['retained'],
          },
          {
            'fieldKey': 'condition',
            'title': 'Condition acceptable?',
            'fieldType': 'yesNo',
            'order': 2,
          },
          {
            'id': 'remarks',
            'title': 'Inspection remarks',
            'fieldType': 'longText',
            'order': 3,
          },
        ],
        initialResponses: [
          FieldResponse(
            key: 'pressure',
            fieldLabel: 'Pressure reading',
            fieldType: FieldType.number,
            value: 2.7,
          ),
        ],
        onSave: (responses) async => saved = responses,
      );

      expect(find.text('Pressure reading'), findsWidgets);
      expect(find.text('Condition acceptable?'), findsWidgets);
      expect(find.text('Inspection remarks'), findsWidgets);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(
        fields.at(1),
        'Observed during the governed round.',
      );
      await tester.tap(find.text('Save Structured Responses'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.map((response) => response.key), ['pressure', 'remarks']);
      expect(saved!.first.fieldType, FieldType.number);
      expect(saved!.first.value, 2.7);
    },
  );

  testWidgets('required yes-no remains unanswered until explicitly selected', (
    tester,
  ) async {
    List<FieldResponse>? saved;
    await pumpForm(
      tester,
      definitions: const [
        {
          'fieldId': 'isolated',
          'label': 'Equipment isolated?',
          'type': 'boolean',
          'isRequired': true,
        },
      ],
      initialResponses: const [],
      onSave: (responses) async => saved = responses,
    );

    await tester.tap(find.text('Save Structured Responses'));
    await tester.pump();
    expect(saved, isNull);
    expect(find.text('Required'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pump();
    await tester.tap(find.text('Save Structured Responses'));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(saved!.single.key, 'isolated');
    expect(saved!.single.fieldType, FieldType.yesNo);
    expect(saved!.single.value, isFalse);
  });

  testWidgets('editing one answer preserves an older instruction-field note', (
    tester,
  ) async {
    List<FieldResponse>? saved;
    await pumpForm(
      tester,
      definitions: const [
        {
          'fieldKey': 'legacy_instruction',
          'title': 'Earlier operating guidance',
          'fieldType': 'instruction',
          'instructionText': 'Read the approved isolation procedure.',
          'order': 1,
        },
        {
          'fieldKey': 'pressure',
          'title': 'Pressure reading',
          'fieldType': 'numericWithUnit',
          'unit': 'bar',
          'order': 2,
        },
      ],
      initialResponses: [
        FieldResponse(
          key: 'legacy_instruction',
          fieldLabel: 'Earlier operating guidance',
          fieldType: FieldType.text,
          value: 'Older operator note that must remain in evidence.',
        ),
        FieldResponse(
          key: 'pressure',
          fieldLabel: 'Pressure reading',
          fieldType: FieldType.number,
          value: 2.7,
        ),
      ],
      onSave: (responses) async => saved = responses,
    );

    await tester.enterText(find.byType(TextField), '3.1');
    await tester.tap(find.text('Save Structured Responses'));
    await tester.pump();

    expect(saved, hasLength(2));
    final legacy = saved!.firstWhere(
      (response) => response.key == 'legacy_instruction',
    );
    expect(legacy.fieldType, FieldType.text);
    expect(legacy.value, 'Older operator note that must remain in evidence.');
    final pressure = saved!.firstWhere(
      (response) => response.key == 'pressure',
    );
    expect(pressure.fieldType, FieldType.number);
    expect(pressure.value, 3.1);
  });
}
