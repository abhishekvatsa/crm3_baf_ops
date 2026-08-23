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
}
