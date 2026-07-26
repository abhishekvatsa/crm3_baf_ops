import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/services/isar_schema_guard_io.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('durable Isar store detection', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('crm3_isar_guard_');
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('empty or missing directory has no durable store', () async {
      expect(await hasDurableIsarStoreFiles(directory.path), isFalse);
      final missing = '${directory.path}_missing';
      expect(await hasDurableIsarStoreFiles(missing), isFalse);
    });

    test('lock-only residue does not impersonate durable data', () async {
      await File('${directory.path}/default.isar.lock').writeAsString('lock');

      expect(await hasDurableIsarStoreFiles(directory.path), isFalse);
    });

    test('database and interrupted temporary files are data-bearing', () async {
      final database = File('${directory.path}/default.isar');
      await database.writeAsBytes(<int>[1, 2, 3]);
      expect(await hasDurableIsarStoreFiles(directory.path), isTrue);

      await database.delete();
      await File(
        '${directory.path}/default.isar.tmp',
      ).writeAsBytes(<int>[4, 5, 6]);
      expect(await hasDurableIsarStoreFiles(directory.path), isTrue);
    });
  });

  test('provenance snapshot preserves all raw marker values', () async {
    const canonical = '{"state":"PREPARED","databaseGenerationId":"test"}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey: canonical,
      SharedPreferencesIsarSchemaProvenanceStore.legacySchemaVersionKey: 3,
    });

    final snapshot =
        jsonDecode(await readIsarSchemaProvenanceSnapshotJson())
            as Map<String, dynamic>;
    final values = snapshot['values'] as Map<String, dynamic>;
    final canonicalValue =
        values[SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey]
            as Map<String, dynamic>;
    final legacyVersion =
        values[SharedPreferencesIsarSchemaProvenanceStore
                .legacySchemaVersionKey]
            as Map<String, dynamic>;
    final legacyFingerprint =
        values[SharedPreferencesIsarSchemaProvenanceStore
                .legacySchemaFingerprintKey]
            as Map<String, dynamic>;

    expect(snapshot['captureFormatVersion'], 1);
    expect(snapshot['storage'], 'SharedPreferences');
    expect(canonicalValue['present'], isTrue);
    expect(canonicalValue['valueType'], 'String');
    expect(canonicalValue['value'], canonical);
    expect(legacyVersion['value'], 3);
    expect(legacyFingerprint['present'], isFalse);
    expect(legacyFingerprint['value'], isNull);
  });
}
