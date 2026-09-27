import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_date_picker.dart';
import 'package:crm3_baf_ops/features/assets/presentation/widgets/inner_cover_physical_event_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calendar = InnerCoverCalendarDelegate();
  const locale = DefaultMaterialLocalizations();
  test(
    'day-first typed date is exact, strict and independent of US defaults',
    () {
      expect(
        calendar.formatCompactDate(DateTime(2026, 9, 7), locale),
        '07-09-2026',
      );
      expect(
        calendar.parseCompactDate('07-09-2026', locale),
        DateTime(2026, 9, 7),
      );
      expect(
        calendar.parseCompactDate('29-02-2024', locale),
        DateTime(2024, 2, 29),
      );
      for (final invalid in [
        '09/07/2026',
        '7-9-2026',
        '31-02-2026',
        '29-02-2025',
      ]) {
        expect(
          calendar.parseCompactDate(invalid, locale),
          isNull,
          reason: invalid,
        );
      }
    },
  );

  testWidgets(
    'real calendar text mode accepts dd-MM-yyyy without US date reinterpretation',
    (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showInnerCoverDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 9, 27),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2026, 9, 27),
                  );
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      expect(find.text('Date (dd-MM-yyyy)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '07-09-2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 9, 7));
    },
  );

  testWidgets(
    'future physical choice remains visible unchanged until corrected through picker',
    (tester) async {
      final now = DateTime(2026, 9, 27, 12);
      var value = now;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => InnerCoverPhysicalEventField(
                value: value,
                clock: () => now,
                onChanged: (chosen) => setState(() => value = chosen),
              ),
            ),
          ),
        ),
      );
      Future<void> chooseTime(String hour, String minute) async {
        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Switch to text input mode'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), hour);
        await tester.enterText(find.byType(TextField).at(1), minute);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      await chooseTime('13', '30');
      expect(value, DateTime(2026, 9, 27, 13, 30));
      expect(find.text('Physical event: 27-09-2026 13:30'), findsOneWidget);
      expect(find.textContaining('cannot be in the future'), findsOneWidget);
      await chooseTime('11', '15');
      expect(value, DateTime(2026, 9, 27, 11, 15));
      expect(find.textContaining('cannot be in the future'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
