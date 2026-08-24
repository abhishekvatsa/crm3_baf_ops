import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'clean local issue adopts exact server creation version and time',
    () async {
      await _withMaintenanceIsar((isar) async {
        final clientTime = DateTime.utc(2026, 8, 17, 12, 5);
        final serverTime = DateTime.utc(2026, 8, 17, 12);
        final record = _record(updatedAt: clientTime, version: 2);
        await isar.writeTxn(() => isar.maintenanceRecords.put(record));
        final expected = SyncPushSnapshot(
          id: record.id,
          version: record.version,
          updatedAt: record.updatedAt,
        );
        final remote =
            _record(updatedAt: serverTime, version: 1)
              ..createdAt = serverTime
              ..isSynced = true;

        final applied = await IsarMaintenanceRepository()
            .applyGovernedCreationServerStateForSync(
              remote: remote,
              expectedLocal: expected,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isTrue);
        expect(stored!.createdAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.updatedAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.version, 1);
        expect(stored.isSynced, isTrue);
      });
    },
  );

  test(
    'collapsed lifecycle adopts exact final server state and version',
    () async {
      await _withMaintenanceIsar((isar) async {
        final historicalClose = DateTime.utc(2026, 8, 17, 10);
        final serverCreateTime = DateTime.utc(2026, 8, 17, 11, 59);
        final serverTime = DateTime.utc(2026, 8, 17, 12);
        final record = _record(updatedAt: historicalClose, version: 4);
        await isar.writeTxn(() => isar.maintenanceRecords.put(record));
        final expected = SyncPushSnapshot(
          id: record.id,
          version: record.version,
          updatedAt: record.updatedAt,
        );
        final remote =
            _record(updatedAt: serverTime, version: 2)
              ..createdAt = serverCreateTime
              ..status = TicketStatus.resolved
              ..isResolved = true
              ..endDate = serverTime
              ..closedByUid = 'mechanical-1'
              ..closedByName = 'Mechanical One'
              ..remarks = 'Resolved after governed creation.'
              ..isSynced = true;

        final applied = await IsarMaintenanceRepository()
            .applyGovernedCreationServerStateForSync(
              remote: remote,
              expectedLocal: expected,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isTrue);
        expect(stored!.createdAt.isAtSameMomentAs(serverCreateTime), isTrue);
        expect(stored.updatedAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.version, 2);
        expect(stored.isResolved, isTrue);
        expect(stored.remarks, 'Resolved after governed creation.');
        expect(stored.isSynced, isTrue);
      });
    },
  );

  test('concurrent local change is preserved dirty', () async {
    await _withMaintenanceIsar((isar) async {
      final originalTime = DateTime.utc(2026, 8, 17, 11);
      final record = _record(updatedAt: originalTime, version: 2);
      await isar.writeTxn(() => isar.maintenanceRecords.put(record));
      final expected = SyncPushSnapshot(
        id: record.id,
        version: record.version,
        updatedAt: record.updatedAt,
      );
      await isar.writeTxn(() async {
        final changed = await isar.maintenanceRecords.get(record.id);
        changed!
          ..version = 3
          ..updatedAt = originalTime.add(const Duration(minutes: 1));
        await isar.maintenanceRecords.put(changed);
      });
      final serverTime = DateTime.utc(2026, 8, 17, 12);
      final remote =
          _record(updatedAt: serverTime, version: 1)
            ..createdAt = serverTime
            ..isSynced = true;

      final applied = await IsarMaintenanceRepository()
          .applyGovernedCreationServerStateForSync(
            remote: remote,
            expectedLocal: expected,
          );
      final stored = await isar.maintenanceRecords.get(record.id);

      expect(applied, isFalse);
      expect(stored!.version, 3);
      expect(
        stored.updatedAt.isAtSameMomentAs(
          originalTime.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(stored.isSynced, isFalse);
    });
  });

  test(
    'lifecycle receipt adopts rebased server version before marking synced',
    () async {
      await _withMaintenanceIsar((isar) async {
        final localCloseTime = DateTime.utc(2026, 8, 22, 10, 3);
        final serverCloseTime = DateTime.utc(2026, 8, 22, 10, 4);
        final priorReopenTime = DateTime.utc(2026, 8, 22, 9, 30);
        final record =
            _record(updatedAt: localCloseTime, version: 6)
              ..isResolved = true
              ..status = TicketStatus.resolved;
        await isar.writeTxn(() => isar.maintenanceRecords.put(record));
        final expected = SyncPushSnapshot(
          id: record.id,
          version: record.version,
          updatedAt: record.updatedAt,
        );
        final remote =
            _record(updatedAt: serverCloseTime, version: 8)
              ..isResolved = true
              ..status = TicketStatus.resolved
              ..acknowledgedByUid = 'server-lane-owner'
              ..acknowledgedByName = 'Server Lane Owner'
              ..acknowledgedAt = serverCloseTime
              ..reopenedByUid = 'operations-2'
              ..reopenedByName = 'Operations Two'
              ..reopenedAt = priorReopenTime
              ..reopenReason = 'The condition recurred during operation.'
              ..workflowQueueState = 'released'
              ..workflowAggregateId = 'workflow-server-1'
              ..workflowUpdatedAt = serverCloseTime;

        final applied = await IsarMaintenanceRepository()
            .applyMaintenanceLifecycleReplayReceiptForSync(
              remote: remote,
              expectedLocal: expected,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isTrue);
        expect(stored!.version, 8);
        expect(stored.updatedAt.isAtSameMomentAs(serverCloseTime), isTrue);
        expect(stored.isSynced, isTrue);
        expect(stored.acknowledgedByUid, 'server-lane-owner');
        expect(stored.reopenedByUid, 'operations-2');
        expect(stored.reopenedByName, 'Operations Two');
        expect(stored.reopenedAt!.isAtSameMomentAs(priorReopenTime), isTrue);
        expect(stored.reopenReason, 'The condition recurred during operation.');
        expect(stored.workflowQueueState, 'released');
        expect(stored.workflowAggregateId, 'workflow-server-1');
        expect(
          stored.version + 1,
          9,
          reason:
              'The next local reopen must advance from the committed server '
              'head, not from stale local version 6.',
        );
      });
    },
  );

  test(
    'lifecycle receipt preserves a concurrent local edit as dirty',
    () async {
      await _withMaintenanceIsar((isar) async {
        final originalTime = DateTime.utc(2026, 8, 22, 10, 3);
        final record = _record(updatedAt: originalTime, version: 6);
        await isar.writeTxn(() => isar.maintenanceRecords.put(record));
        final expected = SyncPushSnapshot(
          id: record.id,
          version: record.version,
          updatedAt: record.updatedAt,
        );
        await isar.writeTxn(() async {
          final changed = await isar.maintenanceRecords.get(record.id);
          changed!
            ..version = 7
            ..updatedAt = originalTime.add(const Duration(minutes: 1));
          await isar.maintenanceRecords.put(changed);
        });

        final applied = await IsarMaintenanceRepository()
            .applyMaintenanceLifecycleReplayReceiptForSync(
              remote: _record(
                updatedAt: DateTime.utc(2026, 8, 22, 10, 5),
                version: 8,
              ),
              expectedLocal: expected,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isFalse);
        expect(stored!.version, 7);
        expect(stored.isSynced, isFalse);
      });
    },
  );
}

MaintenanceRecord _record({required DateTime updatedAt, required int version}) {
  return MaintenanceRecord()
    ..firestoreId = 'ticket-local-1'
    ..version = version
    ..isSynced = false
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..component = 'Furnace body'
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Furnace shell temperature is above the expected range.'
    ..routedTo = RoutedTo.mechanical
    ..loggedByUid = 'mechanical-1'
    ..loggedByName = 'Mechanical One'
    ..startDate = DateTime.utc(2026, 8, 17, 9)
    ..createdAt = DateTime.utc(2026, 8, 17, 9)
    ..updatedAt = updatedAt;
}

Future<void> _withMaintenanceIsar(Future<void> Function(Isar isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'maintenance_creation_receipt_',
  );
  final isar = await Isar.open([
    MaintenanceRecordSchema,
  ], directory: directory.path);
  app.isar = isar;
  try {
    await body(isar);
  } finally {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
