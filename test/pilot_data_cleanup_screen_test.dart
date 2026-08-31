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

OperationalDirective _deletedDirective(DateTime now) =>
    OperationalDirective()
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
