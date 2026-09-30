import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/admin/presentation/admin_data_browser/admin_directives_browser.dart';
import 'package:crm3_baf_ops/features/admin/presentation/pilot_data_cleanup_screen.dart';
import 'package:crm3_baf_ops/features/admin/providers/admin_stream_providers.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late ProviderContainer container;
  final directives = IsarDirectiveRepository();
  final tickets = IsarMaintenanceRepository();
  final templates = IsarPlannedRepository();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('admin_tombstones_');
    db = await Isar.open(
      [OperationalDirectiveSchema, MaintenanceRecordSchema, JobTemplateSchema],
      directory: directory.path,
      name: 'admin_tombstones',
      inspector: false,
    );
    app.isar = db;
    container = ProviderContainer(
      overrides: [
        directiveRepositoryProvider.overrideWithValue(directives),
        maintenanceRepositoryProvider.overrideWithValue(tickets),
        plannedRepositoryProvider.overrideWithValue(templates),
        currentAppUserProvider.overrideWith((ref) => Stream.value(_admin)),
      ],
    );
    await db.writeTxn(() async {
      await db.operationalDirectives.putAll([
        _directive('active'),
        _directive('deleted', deleted: true),
        _directive('unsynced', deleted: true)..isSynced = false,
        _directive('local-only', deleted: true)..firestoreId = null,
      ]);
      await db.maintenanceRecords.putAll([
        _ticket('active'),
        _ticket('deleted', deleted: true),
      ]);
      await db.jobTemplates.putAll([
        _template('active'),
        _template('deleted', deleted: true),
      ]);
    });
  });
  tearDown(() async {
    container.dispose();
    await db.close(deleteFromDisk: true);
    await directory.delete(recursive: true);
  });

  test(
    'admin directives include tombstones while ordinary history excludes them',
    () async {
      final rows = await container.read(adminDirectivesStreamProvider.future);
      expect(rows.map((row) => row.firestoreId), contains('directive-deleted'));
      expect(
        (await directives.watchAllDirectives().first).map(
          (row) => row.firestoreId,
        ),
        ['directive-active'],
      );
      expect(
        (await directives.watchOpenDirectives().first).every(
          (row) => !row.isDeleted,
        ),
        isTrue,
      );
    },
  );

  test(
    'admin tickets include tombstones while ordinary tickets exclude them',
    () async {
      final rows = await container.read(adminTicketsStreamProvider.future);
      expect(rows.map((row) => row.firestoreId), contains('ticket-deleted'));
      expect(
        (await tickets.watchAllTickets().first).map((row) => row.firestoreId),
        ['ticket-active'],
      );
    },
  );

  test(
    'admin templates include tombstones while ordinary templates exclude them',
    () async {
      final rows = await container.read(adminTemplatesStreamProvider.future);
      expect(rows.map((row) => row.firestoreId), contains('template-deleted'));
      expect(
        (await templates.watchAllTemplates().first).map(
          (row) => row.firestoreId,
        ),
        ['template-active'],
      );
    },
  );

  test(
    'server-pulled directive tombstone remains in native admin inventory',
    () async {
      final local = await db.operationalDirectives
          .filter()
          .firestoreIdEqualTo('directive-active')
          .findFirst();
      final remote = _directive('active', deleted: true)..version = 2;
      final applied = await directives.applyTombstoneFromDirectiveRemote(
        remote,
      );
      expect(applied.outcome.name, 'applied');
      final retained = await db.operationalDirectives.get(local!.id);
      expect(retained, isNotNull);
      expect(retained!.isDeleted, isTrue);
      expect(retained.isSynced, isTrue);
      expect(retained.deletedAt!.toUtc(), remote.deletedAt!.toUtc());
      expect(retained.version, 2);
      final rows = await container.read(adminDirectivesStreamProvider.future);
      expect(rows.map((row) => row.firestoreId), contains('directive-active'));
      expect(await directives.watchAllDirectives().first, isEmpty);
    },
  );

  testWidgets(
    'real native feeders expose tombstones in Admin All and cleanup',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await Future.wait([
          container.read(adminDirectivesStreamProvider.future),
          container.read(adminTicketsStreamProvider.future),
          container.read(adminTemplatesStreamProvider.future),
          container.read(currentAppUserProvider.future),
        ]);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DirectivesBrowser())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trial directive deleted'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('admin-directives-status-all')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trial directive deleted'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('admin-directive-directive-deleted')),
          matching: find.text('DELETED'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PilotDataCleanupScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 eligible | 0 selected'), findsOneWidget);
      expect(find.text('Trial directive deleted'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.text('Trial directive unsynced'), findsNothing);
      expect(find.text('Trial directive local-only'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

final _created = DateTime.utc(2026, 9, 20);
final _deleted = DateTime.utc(2026, 9, 21);
final _admin = AppUser(
  uid: 'test-admin',
  name: 'Test Admin',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: _created,
);

OperationalDirective _directive(String key, {bool deleted = false}) =>
    OperationalDirective()
      ..firestoreId = 'directive-$key'
      ..title = 'Trial directive $key'
      ..description = 'Synthetic cleanup test only'
      ..directedTo = AppRole.operations
      ..createdByUid = _admin.uid
      ..createdByName = _admin.name
      ..issuedByUid = _admin.uid
      ..issuedByName = _admin.name
      ..issuedAt = _created
      ..createdAt = _created
      ..updatedAt = deleted ? _deleted : _created
      ..isDeleted = deleted
      ..isSynced = true
      ..deletedAt = deleted ? _deleted : null
      ..deletedByUid = deleted ? _admin.uid : null
      ..deletedByName = deleted ? _admin.name : null
      ..deleteReason = deleted ? 'Synthetic cleanup' : null;

MaintenanceRecord _ticket(String key, {bool deleted = false}) =>
    MaintenanceRecord()
      ..firestoreId = 'ticket-$key'
      ..description = 'Trial ticket $key'
      ..assetType = AssetType.base
      ..assetNumber = 1
      ..maintenanceType = MaintenanceType.inspection
      ..routedTo = RoutedTo.mechanical
      ..startDate = _created
      ..createdAt = _created
      ..updatedAt = deleted ? _deleted : _created
      ..isDeleted = deleted
      ..isSynced = true
      ..deletedAt = deleted ? _deleted : null
      ..deletedByUid = deleted ? _admin.uid : null;

JobTemplate _template(String key, {bool deleted = false}) => JobTemplate()
  ..firestoreId = 'template-$key'
  ..jobName = 'Trial template $key'
  ..applicableAssetType = AssetType.base
  ..createdAt = _created
  ..updatedAt = deleted ? _deleted : _created
  ..isDeleted = deleted
  ..isSynced = true
  ..deletedAt = deleted ? _deleted : null
  ..deletedByUid = deleted ? _admin.uid : null;
