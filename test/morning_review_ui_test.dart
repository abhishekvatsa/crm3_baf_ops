import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_editors.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

void main() {
  test('Admin can start at any time while SI remains inside the window', () {
    final beforeWindow = DateTime.utc(2026, 8, 31, 2); // 07:30 IST
    final inWindow = DateTime.utc(2026, 8, 31, 3); // 08:30 IST
    final afterWindow = DateTime.utc(2026, 8, 31, 4, 31); // 10:01 IST

    expect(canStartMorningReviewNow(_actor(AppRole.admin), beforeWindow), true);
    expect(canStartMorningReviewNow(_actor(AppRole.admin), afterWindow), true);
    expect(canStartMorningReviewNow(_actor(AppRole.si), beforeWindow), false);
    expect(canStartMorningReviewNow(_actor(AppRole.si), inWindow), true);
    expect(canStartMorningReviewNow(_actor(AppRole.si), afterWindow), false);
  });

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

AppUser _actor(AppRole role) => AppUser(
  uid: 'actor-1',
  name: 'Actor One',
  email: 'actor@example.com',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
