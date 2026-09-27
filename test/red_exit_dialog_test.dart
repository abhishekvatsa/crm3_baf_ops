import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/widgets/red_exit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a direct No answers RED without first asserting Yes', (
    tester,
  ) async {
    RedExitAnswers? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRedExitDialog(context, askPreparation: true);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    expect(find.text('No'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result?.redRequired, isFalse);
    expect(result?.preparationRequired, isNull);
  });

  testWidgets(
    'furnace RED needs explicit preparation answer and clears stale choice',
    (tester) async {
      RedExitAnswers? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showRedExitDialog(
                    context,
                    askPreparation: true,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('planned-red-required-yes')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('planned-red-preparation-yes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('planned-red-required-no')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('planned-red-required-yes')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('planned-red-preparation-no')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(result?.redRequired, isTrue);
      expect(result?.preparationRequired, isFalse);
    },
  );
}
