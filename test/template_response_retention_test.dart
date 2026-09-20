import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_response_form.dart';

void main() {
  Future<void> form(
    WidgetTester tester, {
    num value = 3.7,
    String scope = 'actor-a:module',
    String unit = 'bar',
    Future<void> Function(List<FieldResponse>)? save,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobModuleResponseForm(
              inputScopeKey: scope,
              fieldDefinitions: [
                {
                  'key': 'reading',
                  'label': 'Reading',
                  'type': 'number',
                  'unit': unit,
                },
              ],
              initialResponses: [
                FieldResponse(
                  key: 'reading',
                  fieldLabel: 'Reading',
                  fieldType: FieldType.number,
                  value: value,
                ),
              ],
              isEditable: true,
              isBusy: false,
              onSave: save ?? (_) async {},
            ),
          ),
        ),
      ),
    );
  }

  String value(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;
  testWidgets('equivalent newly decoded lists preserve typed entries', (
    tester,
  ) async {
    await form(tester);
    await tester.enterText(find.byType(TextField), '7.2');
    await form(tester);
    expect(value(tester), '7.2');
    expect(
      find.textContaining('Saved work or requirements changed'),
      findsNothing,
    );
  });
  testWidgets(
    'clean form adopts real updates; dirty form requires explicit review',
    (tester) async {
      await form(tester);
      await form(tester, value: 4.1);
      expect(value(tester), '4.1');
      await tester.enterText(find.byType(TextField), '7.2');
      await form(tester, value: 5.2);
      expect(value(tester), '7.2');
      expect(
        find.textContaining('Saved work or requirements changed'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Reviewed — keep my entries'));
      await tester.pump();
      expect(value(tester), '7.2');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('save echo preserves edits typed while save was in flight', (
    tester,
  ) async {
    final pending = Completer<void>();
    await form(tester, save: (_) => pending.future);
    await tester.enterText(find.byType(TextField), '7.2');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '9.4');
    await form(tester, value: 7.2, save: (_) => pending.future);
    pending.complete();
    await tester.pump();
    expect(value(tester), '9.4');
    expect(
      find.textContaining('Saved work or requirements changed'),
      findsNothing,
    );
  });

  testWidgets(
    'reviewing remote changes advances the clean basis without losing a later edit back to the old value',
    (tester) async {
      await form(tester, value: 3.7);
      await tester.enterText(find.byType(TextField), '7.2');
      await form(tester, value: 5.2);
      await tester.tap(find.text('Reviewed — keep my entries'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '3.7');
      await form(tester, value: 6.3);

      expect(value(tester), '3.7');
      expect(
        find.textContaining('Saved work or requirements changed'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'account switch isolates old entries and changed units block silent rebase',
    (tester) async {
      await form(tester);
      await tester.enterText(find.byType(TextField), '7.2');
      await form(tester, unit: 'MPa');
      expect(value(tester), '7.2');
      expect(find.text('Reviewed — keep my entries'), findsNothing);
      await form(tester, scope: 'actor-b:module', value: 6.1);
      expect(value(tester), '6.1');
      expect(
        find.textContaining('Saved work or requirements changed'),
        findsNothing,
      );
    },
  );

  testWidgets('returning to the reviewed saved value leaves no unsaved edit', (
    tester,
  ) async {
    await form(tester, value: 3.7);
    await tester.enterText(find.byType(TextField), '7.2');
    await form(tester, value: 5.2);
    await tester.tap(find.text('Reviewed — keep my entries'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '5.2');

    await form(tester, value: 6.3);

    expect(value(tester), '6.3');
    expect(
      find.textContaining('Saved work or requirements changed'),
      findsNothing,
    );
  });
}
