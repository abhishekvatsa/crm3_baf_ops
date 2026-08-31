import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_editors.dart';

void main() {
  testWidgets('Morning Review editors remain usable on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    TextButton(
                      onPressed:
                          () => showMorningReviewEntryEditor(
                            context,
                            assets: const [],
                            allowedKinds: const [
                              MorningReviewEntryKind.update,
                              MorningReviewEntryKind.maintenanceUpdate,
                            ],
                          ),
                      child: const Text('Open entry editor'),
                    ),
                    TextButton(
                      onPressed:
                          () => showMorningReviewActionEditor(
                            context,
                            assets: const [],
                            participants: const [],
                          ),
                      child: const Text('Open action editor'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open entry editor'));
    await tester.pumpAndSettle();
    expect(find.text('Add meeting contribution'), findsOneWidget);
    expect(find.text('Asset scope'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open action editor'));
    await tester.pumpAndSettle();
    expect(find.text('Create owned action'), findsOneWidget);
    expect(find.text('Asset scope'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
