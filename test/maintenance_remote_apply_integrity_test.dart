import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'fetched remote cannot overwrite an edit made before application',
    () async {
      await _withMaintenanceIsar((isar) async {
        final originalTime = DateTime.utc(2026, 9, 6, 8);
        final fetchedRemote = _record(
          version: 7,
          updatedAt: originalTime.add(const Duration(minutes: 7)),
          description: 'Remote description',
          isSynced: true,
        );
        final local = _record(
          version: 3,
          updatedAt: originalTime,
          description: 'Original description',
          isSynced: true,
        );
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));

        // The pull has already fetched its remote snapshot. The operator edits
        // before the deferred application reaches the local transaction.
        await isar.writeTxn(() async {
          final edited = await isar.maintenanceRecords.get(local.id);
          edited!
            ..version = 4
            ..updatedAt = originalTime.add(const Duration(minutes: 1))
            ..description = 'Unsynced operator edit'
            ..isSynced = false;
          await isar.maintenanceRecords.put(edited);
        });

        final result = await IsarMaintenanceRepository()
            .applyMaintenanceRecordFromRemote(fetchedRemote);
        final stored = await isar.maintenanceRecords.get(local.id);

        expect(result.outcome, RemoteRecordApplyOutcome.localDirtyPreserved);
        expect(stored!.description, 'Unsynced operator edit');
        expect(stored.version, 4);
        expect(stored.isSynced, isFalse);
      });
    },
  );

  test(
    'competing live insert and pull resolve to one local identity',
    () async {
      await _withMaintenanceIsar((isar) async {
        final serverTime = DateTime.utc(2026, 9, 6, 8, 5);
        final fetchedRemote = _record(
          version: 7,
          updatedAt: serverTime,
          description: 'Fetched by pull',
          isSynced: true,
        );

        expect(
          await IsarMaintenanceRepository().getByFirestoreId('ticket-remote-1'),
          isNull,
        );

        // A live listener wins the race after the pull's initial observation.
        final liveRecord = _record(
          version: 7,
          updatedAt: serverTime,
          description: 'Fetched by pull',
          isSynced: true,
        );
        await isar.writeTxn(() => isar.maintenanceRecords.put(liveRecord));

        final result = await IsarMaintenanceRepository()
            .applyMaintenanceRecordFromRemote(fetchedRemote);
        final matches = await isar.maintenanceRecords
            .filter()
            .firestoreIdEqualTo('ticket-remote-1')
            .findAll();

        expect(result.outcome, RemoteRecordApplyOutcome.unchanged);
        expect(matches, hasLength(1));
      });
    },
  );

  test(
    'higher remote version cannot overwrite a later clean local snapshot',
    () async {
      await _withMaintenanceIsar((isar) async {
        final remoteTime = DateTime.utc(2026, 9, 6, 8);
        final local = _record(
          version: 3,
          updatedAt: remoteTime.add(const Duration(minutes: 5)),
          description: 'Later clean local evidence',
          isSynced: true,
        );
        await isar.writeTxn(() => isar.maintenanceRecords.put(local));

        final result = await IsarMaintenanceRepository()
            .applyMaintenanceRecordFromRemote(
              _record(
                version: 7,
                updatedAt: remoteTime,
                description: 'Older remote snapshot',
                isSynced: true,
              ),
            );
        final stored = await isar.maintenanceRecords.get(local.id);

        expect(result.outcome, RemoteRecordApplyOutcome.staleRemoteSkipped);
        expect(result.remoteIsNewer, isFalse);
        expect(stored!.description, 'Later clean local evidence');
        expect(stored.version, 3);
        expect(stored.isSynced, isTrue);
      });
    },
  );

  test('pre-existing duplicate identity blocks automatic overwrite', () async {
    await _withMaintenanceIsar((isar) async {
      final localTime = DateTime.utc(2026, 9, 6, 8);
      final first = _record(
        version: 2,
        updatedAt: localTime,
        description: 'First retained row',
        isSynced: true,
      );
      final second = _record(
        version: 3,
        updatedAt: localTime.add(const Duration(minutes: 1)),
        description: 'Second retained row',
        isSynced: false,
      );
      await isar.writeTxn(
        () =>
            isar.maintenanceRecords.putAll(<MaintenanceRecord>[first, second]),
      );

      final result = await IsarMaintenanceRepository()
          .applyMaintenanceRecordFromRemote(
            _record(
              version: 8,
              updatedAt: localTime.add(const Duration(minutes: 8)),
              description: 'Remote must not choose a duplicate winner',
              isSynced: true,
            ),
          );
      final matches = await isar.maintenanceRecords
          .filter()
          .firestoreIdEqualTo('ticket-remote-1')
          .findAll();

      expect(result.outcome, RemoteRecordApplyOutcome.duplicateLocalIdentity);
      expect(matches, hasLength(2));
      expect(
        matches.map((record) => record.description),
        containsAll(<String>['First retained row', 'Second retained row']),
      );
    });
  });
}

MaintenanceRecord _record({
  required int version,
  required DateTime updatedAt,
  required String description,
  required bool isSynced,
}) {
  return MaintenanceRecord()
    ..firestoreId = 'ticket-remote-1'
    ..version = version
    ..isSynced = isSynced
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..component = 'Furnace body'
    ..maintenanceType = MaintenanceType.breakdown
    ..description = description
    ..routedTo = RoutedTo.mechanical
    ..loggedByUid = 'operator-1'
    ..loggedByName = 'Operator One'
    ..startDate = DateTime.utc(2026, 9, 6, 7)
    ..createdAt = DateTime.utc(2026, 9, 6, 7)
    ..updatedAt = updatedAt;
}

Future<void> _withMaintenanceIsar(Future<void> Function(Isar isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'maintenance_remote_apply_',
  );
  final isar = await Isar.open(<CollectionSchema<dynamic>>[
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
