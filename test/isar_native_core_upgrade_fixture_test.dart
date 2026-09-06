import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/charges/data/charge_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/build25_isar_upgrade_fixture.dart';
import '../tool/test_support/test_isar_core.dart';

const _fixtureRoot = 'test/fixtures/isar_core_upgrade';
const _fixtureArchive = '$_fixtureRoot/build25_isar_3.1.0+1.isar.gz';
const _fixtureReceipt = '$_fixtureRoot/build25_isar_3.1.0+1.json';

String _sha256(List<int> bytes) =>
    sha256.convert(bytes).toString().toUpperCase();

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'maintained Isar core preserves and extends a populated Build 25 database',
    () async {
      final receipt = Map<String, dynamic>.from(
        jsonDecode(File(_fixtureReceipt).readAsStringSync()) as Map,
      );
      final archiveBytes = File(_fixtureArchive).readAsBytesSync();
      expect(receipt['build'], '1.0.0-rc.15+25');
      expect(
        receipt['buildSourceCommit'],
        'c539490d87b6d0bb6dc226e871a95d6b7fc95150',
      );
      expect(receipt['nativePackage'], 'isar_flutter_libs 3.1.0+1');
      expect(
        receipt['windowsNativeCoreSha256'],
        '5E67863F188C5F9681A37F84F2EB942EAF702509D3F994C0344D5049EBC9E48F',
      );
      expect(receipt['productionDataUsed'], isFalse);
      expect(receipt['productionArtifactUsed'], isFalse);
      expect(_sha256(archiveBytes), receipt['compressedFixtureSha256']);
      final databaseBytes = gzip.decode(archiveBytes);
      expect(_sha256(databaseBytes), receipt['databaseSha256']);
      expect(receipt['schemaCount'], build25UpgradeSchemas.length);

      final directory = await Directory.systemTemp.createTemp(
        'crm3_build25_native_upgrade_',
      );
      final databaseFile = File(
        '${directory.path}/$build25UpgradeFixtureName.isar',
      );
      await databaseFile.writeAsBytes(databaseBytes, flush: true);
      Isar? isar;
      try {
        isar = await Isar.open(
          build25UpgradeSchemas,
          directory: directory.path,
          name: build25UpgradeFixtureName,
        );
        final charge = await isar.charges
            .filter()
            .firestoreIdEqualTo(build25UpgradeChargeId)
            .findFirst();
        final issue = await isar.maintenanceRecords
            .filter()
            .firestoreIdEqualTo(build25UpgradeIssueId)
            .findFirst();
        expect(charge?.chargeNo, 250906);
        expect(charge?.baseNo, 207);
        expect(charge?.furnaceNo, 22);
        expect(charge?.rawTelemetry, '{"temperature":710}');
        expect(issue?.version, 8);
        expect(issue?.assetType, AssetType.furnace);
        expect(issue?.assetNumber, 22);
        expect(issue?.hierarchyPath, <String>['Combustion', 'Burner block 4']);
        expect(issue?.metadataJson, '{"fixture":"build25"}');

        final now = DateTime.utc(2026, 9, 6, 5, 45);
        final successor = Charge()
          ..firestoreId = 'community-upgrade-charge'
          ..chargeNo = 250907
          ..status = ChargeStatus.loaded
          ..baseNo = 209
          ..rawTelemetry = '{}'
          ..createdAt = now
          ..updatedAt = now
          ..isSynced = false;
        await isar.writeTxn(() async => isar!.charges.put(successor));
        await isar.close();
        isar = null;

        isar = await Isar.open(
          build25UpgradeSchemas,
          directory: directory.path,
          name: build25UpgradeFixtureName,
        );
        final persistedSuccessor = await isar.charges
            .filter()
            .firestoreIdEqualTo('community-upgrade-charge')
            .findFirst();
        expect(persistedSuccessor?.chargeNo, 250907);
        expect(persistedSuccessor?.isSynced, isFalse);
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close();
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
