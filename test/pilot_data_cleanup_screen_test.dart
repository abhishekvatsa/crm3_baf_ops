import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_pilot_purge.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';

import 'package:crm3_baf_ops/features/admin/presentation/pilot_data_cleanup_screen.dart';
import 'package:crm3_baf_ops/features/admin/providers/admin_stream_providers.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cleanup hides retained authority and clears selections for another actor',
    (tester) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final now = DateTime.utc(2026, 9, 30);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            adminTicketsStreamProvider.overrideWith(
              (ref) => Stream.value(const <MaintenanceRecord>[]),
            ),
            adminDirectivesStreamProvider.overrideWith(
              (ref) => Stream.value([_deletedDirective(now)]),
            ),
            adminTemplatesStreamProvider.overrideWith(
              (ref) => Stream.value(const <JobTemplate>[]),
            ),
          ],
          child: const MaterialApp(home: PilotDataCleanupScreen()),
        ),
      );
      actors.add(_admin(now));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(find.text('1 eligible | 1 selected'), findsOneWidget);
      final context = tester.element(find.byType(PilotDataCleanupScreen));
      ProviderScope.containerOf(context).invalidate(currentAppUserProvider);
      await tester.pump();
      await tester.pump();
      expect(find.text('Fresh Admin authority is required.'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
      actors.add(
        AppUser(
          uid: 'other-admin',
          name: 'Other',
          email: 'other@example.invalid',
          roles: [AppRole.admin],
          isApproved: true,
          createdAt: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 eligible | 0 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final interruptedBy in ['another Admin', 'authority refresh']) {
    testWidgets('bulk confirmation cannot survive $interruptedBy', (
      tester,
    ) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final now = DateTime.utc(2026, 9, 30);
      var preflightReads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            adminTicketsStreamProvider.overrideWith(
              (ref) => Stream.value(const <MaintenanceRecord>[]),
            ),
            adminDirectivesStreamProvider.overrideWith(
              (ref) => Stream.value([_deletedDirective(now)]),
            ),
            adminTemplatesStreamProvider.overrideWith(
              (ref) => Stream.value(const <JobTemplate>[]),
            ),
            syncCoordinatorProvider.overrideWith((ref) {
              preflightReads++;
              throw StateError(
                'The test must never reach synchronization or purge.',
              );
            }),
          ],
          child: const MaterialApp(home: PilotDataCleanupScreen()),
        ),
      );
      actors.add(_admin(now));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Permanently remove 1 selected'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      if (interruptedBy == 'another Admin') {
        actors.add(
          AppUser(
            uid: 'admin-2',
            name: 'Other Admin',
            email: 'other@example.invalid',
            roles: [AppRole.admin],
            isApproved: true,
            createdAt: now,
          ),
        );
        await tester.pumpAndSettle();
      } else {
        final context = tester.element(find.byType(PilotDataCleanupScreen));
        ProviderScope.containerOf(context).invalidate(currentAppUserProvider);
        await tester.pump();
        await tester.pump();
        // Even the original Admin returning does not inherit the old confirmation.
        actors.add(_admin(now));
        await tester.pumpAndSettle();
      }
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Remove synthetic trial only');
      await tester.enterText(fields.at(1), 'DELETE 1 RECORDS');
      await tester.tap(find.text('Remove permanently'));
      await tester.pumpAndSettle();
      expect(preflightReads, 0);
      expect(
        find.textContaining('Admin authority changed or needed verification'),
        findsOneWidget,
      );
      expect(find.text('1 eligible | 0 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final interruptedBy in ['another Admin', 'authority refresh']) {
    testWidgets('single-record confirmation cannot survive $interruptedBy', (
      tester,
    ) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final now = DateTime.utc(2026, 9, 30);
      var dispatchReads = 0;
      bool? removed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            workflowCommandControllerProvider.overrideWith((ref) {
              dispatchReads++;
              throw StateError('The test must never dispatch a purge.');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  ref.watch(currentAppUserProvider);
                  return TextButton(
                    onPressed: () async {
                      removed = await purgePilotBusinessRecord(
                        context: context,
                        ref: ref,
                        collectionId: 'operational_directives',
                        documentId: 'synthetic-record',
                        expectedVersion: 2,
                        recordLabel: 'Synthetic trial only',
                      );
                    },
                    child: const Text('Open fixture removal'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      actors.add(_admin(now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open fixture removal'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      if (interruptedBy == 'another Admin') {
        actors.add(
          AppUser(
            uid: 'admin-2',
            name: 'Other Admin',
            email: 'other@example.invalid',
            roles: [AppRole.admin],
            isApproved: true,
            createdAt: now,
          ),
        );
        await tester.pumpAndSettle();
      } else {
        ProviderScope.containerOf(
          tester.element(find.text('Open fixture removal')),
        ).invalidate(currentAppUserProvider);
        await tester.pump();
        await tester.pump();
        actors.add(_admin(now));
        await tester.pumpAndSettle();
      }
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Remove synthetic trial only');
      await tester.enterText(fields.at(1), 'DELETE synthetic-record');
      await tester.tap(find.text('Remove permanently'));
      await tester.pumpAndSettle();
      expect(removed, isFalse);
      expect(dispatchReads, 0);
      expect(
        find.textContaining('Admin authority changed or needed verification'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Admin can select an eligible deleted pilot record on phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 8, 31, 6);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_admin(now)),
          ),
          adminTicketsStreamProvider.overrideWith(
            (ref) => Stream.value(const <MaintenanceRecord>[]),
          ),
          adminDirectivesStreamProvider.overrideWith(
            (ref) =>
                Stream.value(<OperationalDirective>[_deletedDirective(now)]),
          ),
          adminTemplatesStreamProvider.overrideWith(
            (ref) => Stream.value(const <JobTemplate>[]),
          ),
        ],
        child: const MaterialApp(home: PilotDataCleanupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 eligible | 0 selected'), findsOneWidget);
    expect(find.text('Trial crane coordination'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Permanently remove 0 selected'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(find.text('1 eligible | 1 selected'), findsOneWidget);
    expect(find.text('Permanently remove 1 selected'), findsOneWidget);
  });
}

AppUser _admin(DateTime now) => AppUser(
  uid: 'admin-1',
  name: 'Administrator',
  email: 'admin@example.invalid',
  roles: const <AppRole>[AppRole.admin],
  isApproved: true,
  createdAt: now,
);

OperationalDirective _deletedDirective(DateTime now) => OperationalDirective()
  ..firestoreId = 'trial-directive-1'
  ..title = 'Trial crane coordination'
  ..description = 'Pilot-only directive that is no longer required.'
  ..directedTo = AppRole.operations
  ..status = DirectiveStatus.closed
  ..priority = DirectivePriority.medium
  ..createdByUid = 'admin-1'
  ..createdByName = 'Administrator'
  ..issuedByUid = 'admin-1'
  ..issuedByName = 'Administrator'
  ..issuedAt = now.subtract(const Duration(days: 2))
  ..isActive = false
  ..isDeleted = true
  ..deletedAt = now.subtract(const Duration(days: 1))
  ..deletedByUid = 'admin-1'
  ..deletedByName = 'Administrator'
  ..deleteReason = 'Pilot record'
  ..createdAt = now.subtract(const Duration(days: 2))
  ..updatedAt = now.subtract(const Duration(days: 1))
  ..version = 2
  ..isSynced = true;
