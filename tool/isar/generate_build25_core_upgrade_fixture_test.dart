import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/charges/data/charge_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../test_support/build25_isar_upgrade_fixture.dart';
import '../test_support/test_isar_core.dart';

const _build25WindowsCoreSha256 =
    '5E67863F188C5F9681A37F84F2EB942EAF702509D3F994C0344D5049EBC9E48F';

Future<void> _initializeExactBuild25Core() async {
  final configuredPath = Platform.environment['CRM_ISAR_CORE_PATH']?.trim();
  if (configuredPath == null || configuredPath.isEmpty) {
    throw StateError(
      'Fixture generation requires CRM_ISAR_CORE_PATH to identify the exact '
      'Build 25 Windows native core.',
    );
  }
  final core = File(configuredPath).absolute;
  if (!core.existsSync()) {
    throw StateError('Build 25 native core does not exist: ${core.path}');
  }
  final actualSha256 = sha256
      .convert(await core.readAsBytes())
      .toString()
      .toUpperCase();
  if (actualSha256 != _build25WindowsCoreSha256) {
    throw StateError(
      'Fixture generation requires the exact Build 25 native core; '
      'expected $_build25WindowsCoreSha256, got $actualSha256.',
    );
  }
  await initializeTestIsarCore();
}

void main() {
  setUpAll(_initializeExactBuild25Core);

  test('generate populated Build 25 native-core fixture', () async {
    final output = Platform.environment['CRM_ISAR_FIXTURE_DIR'];
    expect(output, isNotNull);
    final directory = Directory(output!)..createSync(recursive: true);
    final isar = await Isar.open(
      build25UpgradeSchemas,
      directory: directory.path,
      name: build25UpgradeFixtureName,
    );
    await isar.writeTxn(() async {
      await isar.charges.put(build25UpgradeCharge());
      await isar.maintenanceRecords.put(build25UpgradeIssue());
    });
    await isar.close();
    expect(
      File('${directory.path}/$build25UpgradeFixtureName.isar').existsSync(),
      isTrue,
    );
  });
}
