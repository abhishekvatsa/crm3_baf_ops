import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/widgets/job_module_draft_recovery.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<AppUser?> accounts;
  late ProviderContainer container;
  AppUser actor(String uid) => AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.test',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    accounts = StreamController<AppUser?>();
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => accounts.stream),
      ],
    );
    container.listen(currentAppUserProvider, (_, _) {});
    accounts.add(actor('editor'));
    await container.read(currentAppUserProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await accounts.close();
  });

  JobModuleDraftReview review({bool closed = false}) {
    final current = JobModuleInstance()
      ..id = 7
      ..firestoreId = 'module-7'
      ..moduleTitle = 'Seal'
      ..createdAt = DateTime.utc(2026)
      ..updatedAt = DateTime.utc(2026)
      ..version = 5
      ..draftNote = 'NEWER CURRENT WORK';
    final draft = copyJobModuleForEditing(current)..draftNote = 'MY SAVED WORK';
    final saved = JobModuleSavedDraft(
      conflictId: 'conflict-7',
      moduleLocalId: 7,
      actorUid: 'editor',
      savedAt: DateTime.utc(2026),
      reason: 'reviewed-module-changed',
      evidenceJson: jsonEncode({'attempted': jobModuleLocalSnapshot(draft)}),
    );
    return JobModuleDraftReview(
      saved,
      current,
      blockingReason: closed ? 'parent-closed' : null,
    );
  }

  Future<void> show(WidgetTester tester, {bool closed = false}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: JobModuleDraftReviewDialog(
              review: review(closed: closed),
              originUid: 'editor',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'both versions are shown and replacement needs explicit confirmation',
    (tester) async {
      await show(tester);
      expect(find.text('Notes: NEWER CURRENT WORK'), findsOneWidget);
      expect(find.text('Notes: MY SAVED WORK'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Restore reviewed work'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Restore reviewed work'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'closed parent keeps saved work visible with restoration disabled',
    (tester) async {
      await show(tester, closed: true);
      expect(find.text('Notes: MY SAVED WORK'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Restore reviewed work'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'account switch and account verification error hide retained draft values',
    (tester) async {
      await show(tester);
      accounts.add(actor('different-editor'));
      await tester.pumpAndSettle();
      expect(find.text('Notes: MY SAVED WORK'), findsNothing);
      expect(find.text('Notes: NEWER CURRENT WORK'), findsNothing);
      expect(find.text('Verify your account'), findsOneWidget);
      accounts.add(actor('editor'));
      await tester.pumpAndSettle();
      expect(find.text('Notes: MY SAVED WORK'), findsOneWidget);
      accounts.addError(StateError('verification failed'));
      await tester.pumpAndSettle();
      expect(find.text('Notes: MY SAVED WORK'), findsNothing);
    },
  );
}
