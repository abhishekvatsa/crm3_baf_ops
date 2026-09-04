import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_push_snapshot.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

Future<void> _withAbnormalityIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp(
    'charge_abnormality_convergence_',
  );
  final instance = await Isar.open(
    [ChargeAbnormalitySchema],
    directory: dir.path,
    name: 'charge_abnormality_convergence_test',
  );
  app.isar = instance;
  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

ChargeAbnormality _abnormality({
  int version = 2,
  bool isSynced = true,
  bool isDeleted = false,
  DateTime? updatedAt,
}) {
  final at = updatedAt ?? DateTime.utc(2026, 8, 23, 8);
  return ChargeAbnormality()
    ..firestoreId = 'abnormality_1'
    ..sourceChargeNo = 70001
    ..abnormalityTypeId = 'type_1'
    ..abnormalityTypeTitle = 'Cycle deviation'
    ..abnormalityTypeCode = 'CYCLE_DEVIATION'
    ..category = AbnormalityCategory.process
    ..severity = AbnormalitySeverity.medium
    ..affectedAssets = [
      const AffectedAssetRef(assetType: AssetType.base, assetNumber: 201),
    ]
    ..observedReason = 'Temperature deviation'
    ..possibleRootReasonCategory = RootReasonCategory.unknown
    ..reannealingStatus = ReannealingStatus.notApplicable
    ..loggedAt = DateTime.utc(2026, 8, 23, 7)
    ..updatedAt = at
    ..loggedByUid = 'operator_1'
    ..loggedByName = 'Operator'
    ..updatedByUid = 'admin_1'
    ..updatedByName = 'Admin'
    ..version = version
    ..isSynced = isSynced
    ..isDeleted = isDeleted
    ..deletedAt = isDeleted ? at : null
    ..deletedByUid = isDeleted ? 'admin_1' : null
    ..deletedByName = isDeleted ? 'Admin' : null
    ..deleteReason = isDeleted ? 'Duplicate record' : null;
}

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'legacy unsent draft adopts creation receipt version instead of its local edit count',
    () async {
      await _withAbnormalityIsar((isar) async {
        final local = _abnormality(version: 4, isSynced: false);
        await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
        final remote = _abnormality(
          version: 1,
          updatedAt: local.updatedAt.add(const Duration(minutes: 1)),
        );
        final adopted = await IsarAbnormalityRepository()
            .applyAbnormalityServerReadbackIfUnchanged(
              remote,
              expectedLocal: SyncPushSnapshot(
                id: local.id,
                version: local.version,
                updatedAt: local.updatedAt,
              ),
              expectedLocalSynced: false,
            );
        expect(adopted, isTrue);
        final stored = await isar.chargeAbnormalitys.get(local.id);
        expect(stored?.version, 1);
        expect(stored?.updatedAt.isAtSameMomentAs(remote.updatedAt), isTrue);
        expect(stored?.isSynced, isTrue);
      });
    },
  );

  final identityChanges = <String, void Function(ChargeAbnormality)>{
    'source charge': (row) => row.sourceChargeNo = 70002,
    'original time':
        (row) => row.loggedAt = row.loggedAt.add(const Duration(seconds: 1)),
    'original actor': (row) => row.loggedByUid = 'operator_2',
    'original actor name': (row) => row.loggedByName = 'Different operator',
    'source ticket': (row) => row.linkedTicketFirestoreId = 'different-ticket',
    'source execution':
        (row) => row.linkedExecutionFirestoreId = 'different-job',
  };
  for (final change in identityChanges.entries) {
    test('pull and deletion preserve a different ${change.key}', () async {
      await _withAbnormalityIsar((isar) async {
        final local = _abnormality(isSynced: false);
        await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
        final before = local.toMap();
        final remote = _abnormality(
          version: 9,
          updatedAt: local.updatedAt.add(const Duration(minutes: 5)),
        );
        change.value(remote);
        final repository = IsarAbnormalityRepository();
        await expectLater(
          repository.updateAbnormalityFromRemote(remote),
          throwsStateError,
        );
        remote
          ..isDeleted = true
          ..deletedAt = remote.updatedAt
          ..deletedByUid = 'admin_1'
          ..deletedByName = 'Admin'
          ..deleteReason = 'Remote deletion';
        await expectLater(
          repository.applyTombstoneFromAbnormalityRemote(remote),
          throwsStateError,
        );
        await expectLater(
          repository.updateAbnormalityFromRemote(remote),
          throwsStateError,
        );
        final retained = (await isar.chargeAbnormalitys.get(local.id))!;
        expect(retained.toMap(), before);
        expect(retained.isSynced, isFalse);
      });
    });
    test(
      'readback preserves local evidence for a different ${change.key}',
      () async {
        await _withAbnormalityIsar((isar) async {
          final local = _abnormality(isSynced: false);
          await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
          final before = local.toMap();
          final remote = _abnormality();
          change.value(remote);
          final adopted = await IsarAbnormalityRepository()
              .applyAbnormalityServerReadbackIfUnchanged(
                remote,
                expectedLocal: SyncPushSnapshot(
                  id: local.id,
                  version: local.version,
                  updatedAt: local.updatedAt,
                ),
                expectedLocalSynced: false,
              );
          expect(adopted, isFalse);
          final retained = (await isar.chargeAbnormalitys.get(local.id))!;
          expect(retained.toMap(), before);
          expect(retained.isSynced, isFalse);
        });
      },
    );
  }

  test(
    'accepted callable record atomically replaces the inspected row',
    () async {
      await _withAbnormalityIsar((isar) async {
        final local = _abnormality();
        await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
        final remote =
            _abnormality(version: 3, updatedAt: DateTime.utc(2026, 8, 23, 8, 5))
              ..severity = AbnormalitySeverity.high
              ..observedReason = 'Server-accepted temperature deviation';

        final adopted = await IsarAbnormalityRepository()
            .applyAbnormalityServerReadbackIfUnchanged(
              remote,
              expectedLocal: SyncPushSnapshot(
                id: local.id,
                version: local.version,
                updatedAt: local.updatedAt,
              ),
              expectedLocalSynced: true,
            );

        expect(adopted, isTrue);
        final after = await isar.chargeAbnormalitys.get(local.id);
        expect(after!.version, 3);
        expect(after.severity, AbnormalitySeverity.high);
        expect(after.observedReason, 'Server-accepted temperature deviation');
        expect(after.isSynced, isTrue);
      });
    },
  );

  test('accepted callable record cannot overwrite newer local work', () async {
    await _withAbnormalityIsar((isar) async {
      final local = _abnormality();
      await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
      final expected = SyncPushSnapshot(
        id: local.id,
        version: local.version,
        updatedAt: local.updatedAt,
      );
      final remote = _abnormality(
        version: 3,
        updatedAt: DateTime.utc(2026, 8, 23, 8, 5),
      )..observedReason = 'Server result';

      await isar.writeTxn(() async {
        final current = await isar.chargeAbnormalitys.get(local.id);
        current!
          ..observedReason = 'Newer local evidence'
          ..version = 4
          ..updatedAt = DateTime.utc(2026, 8, 23, 8, 10)
          ..isSynced = false;
        await isar.chargeAbnormalitys.put(current);
      });

      final adopted = await IsarAbnormalityRepository()
          .applyAbnormalityServerReadbackIfUnchanged(
            remote,
            expectedLocal: expected,
            expectedLocalSynced: true,
          );

      expect(adopted, isFalse);
      final after = await isar.chargeAbnormalitys.get(local.id);
      expect(after!.version, 4);
      expect(after.observedReason, 'Newer local evidence');
      expect(after.isSynced, isFalse);
    });
  });

  test('accepted server tombstone is adopted at the exact boundary', () async {
    await _withAbnormalityIsar((isar) async {
      final local = _abnormality();
      await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
      final remote = _abnormality(
        version: 3,
        isDeleted: true,
        updatedAt: DateTime.utc(2026, 8, 23, 8, 5),
      );

      final adopted = await IsarAbnormalityRepository()
          .applyAbnormalityServerReadbackIfUnchanged(
            remote,
            expectedLocal: SyncPushSnapshot(
              id: local.id,
              version: local.version,
              updatedAt: local.updatedAt,
            ),
            expectedLocalSynced: true,
          );

      expect(adopted, isTrue);
      final after = await isar.chargeAbnormalitys.get(local.id);
      expect(after!.isDeleted, isTrue);
      expect(after.version, 3);
      expect(after.deleteReason, 'Duplicate record');
      expect(after.isSynced, isTrue);
    });
  });

  test(
    'quality command revives a synchronized local tombstone in place',
    () async {
      await _withAbnormalityIsar((isar) async {
        final tombstone = _abnormality(
          version: 5,
          isDeleted: true,
          updatedAt: DateTime.utc(2026, 8, 23, 8, 5),
        );
        await isar.writeTxn(() => isar.chargeAbnormalitys.put(tombstone));
        final localId = tombstone.id;
        final remote = _abnormality(
          version: 6,
          updatedAt: DateTime.utc(2026, 8, 23, 8, 10),
        )..reannealingStatus = ReannealingStatus.pendingDecision;

        final adopted = await IsarAbnormalityRepository()
            .applyAbnormalityCommandReadback(remote);

        expect(adopted, isTrue);
        final rows = await isar.chargeAbnormalitys.where().findAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, localId);
        expect(rows.single.isDeleted, isFalse);
        expect(rows.single.deletedAt, isNull);
        expect(rows.single.version, 6);
        expect(
          rows.single.reannealingStatus,
          ReannealingStatus.pendingDecision,
        );
        expect(rows.single.isSynced, isTrue);
      });
    },
  );

  test('quality command readback cannot erase unresolved local work', () async {
    await _withAbnormalityIsar((isar) async {
      final local = _abnormality(
        version: 7,
        isSynced: false,
        updatedAt: DateTime.utc(2026, 8, 23, 8, 15),
      )..observedReason = 'Unsynced evidence captured on this phone';
      await isar.writeTxn(() => isar.chargeAbnormalitys.put(local));
      final remote = _abnormality(
        version: 8,
        updatedAt: DateTime.utc(2026, 8, 23, 8, 20),
      )..observedReason = 'Server command result';

      final adopted = await IsarAbnormalityRepository()
          .applyAbnormalityCommandReadback(remote);

      expect(adopted, isFalse);
      final after = await isar.chargeAbnormalitys.get(local.id);
      expect(after!.version, 7);
      expect(after.observedReason, 'Unsynced evidence captured on this phone');
      expect(after.isSynced, isFalse);
    });
  });

  test('quality command inserts an absent canonical case', () async {
    await _withAbnormalityIsar((isar) async {
      final remote = _abnormality(
        version: 3,
        updatedAt: DateTime.utc(2026, 8, 23, 8, 5),
      );

      final adopted = await IsarAbnormalityRepository()
          .applyAbnormalityCommandReadback(remote);

      expect(adopted, isTrue);
      final rows = await isar.chargeAbnormalitys.where().findAll();
      expect(rows, hasLength(1));
      expect(rows.single.firestoreId, 'abnormality_1');
      expect(rows.single.version, 3);
      expect(rows.single.isSynced, isTrue);
    });
  });
}
