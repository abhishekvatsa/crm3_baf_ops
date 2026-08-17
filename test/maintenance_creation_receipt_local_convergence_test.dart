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

        final applied = await IsarMaintenanceRepository()
            .applyGovernedCreationReceiptForSync(
              firestoreId: record.firestoreId!,
              expectedLocal: expected,
              serverCreateVersion: 2,
              serverAppliedAt: serverTime,
              hasPostCreateLifecycle: false,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isTrue);
        expect(stored!.createdAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.updatedAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.version, 2);
        expect(stored.isSynced, isTrue);
      });
    },
  );

  test(
    'collapsed lifecycle keeps final version and floors mutation time',
    () async {
      await _withMaintenanceIsar((isar) async {
        final historicalClose = DateTime.utc(2026, 8, 17, 10);
        final serverTime = DateTime.utc(2026, 8, 17, 12);
        final record = _record(updatedAt: historicalClose, version: 4);
        await isar.writeTxn(() => isar.maintenanceRecords.put(record));
        final expected = SyncPushSnapshot(
          id: record.id,
          version: record.version,
          updatedAt: record.updatedAt,
        );

        final applied = await IsarMaintenanceRepository()
            .applyGovernedCreationReceiptForSync(
              firestoreId: record.firestoreId!,
              expectedLocal: expected,
              serverCreateVersion: 2,
              serverAppliedAt: serverTime,
              hasPostCreateLifecycle: true,
            );
        final stored = await isar.maintenanceRecords.get(record.id);

        expect(applied, isTrue);
        expect(stored!.createdAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.updatedAt.isAtSameMomentAs(serverTime), isTrue);
        expect(stored.version, 4);
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

      final applied = await IsarMaintenanceRepository()
          .applyGovernedCreationReceiptForSync(
            firestoreId: record.firestoreId!,
            expectedLocal: expected,
            serverCreateVersion: 2,
            serverAppliedAt: DateTime.utc(2026, 8, 17, 12),
            hasPostCreateLifecycle: false,
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
