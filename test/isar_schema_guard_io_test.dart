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

  test('privacy-safe installed-store inventory performs no marker writes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'crm3_isar_inventory_',
    );
    try {
      await File('${directory.path}/default.isar').writeAsBytes(<int>[1, 2, 3]);
      const generation = '123e4567-e89b-42d3-a456-426614174000';
      final marker = const IsarSchemaProvenanceMarker(
        state: IsarSchemaMarkerState.committed,
        schemaVersion: IsarSchemaMigrator.currentSchemaVersion,
        schemaFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
        databaseGenerationId: generation,
        origin: IsarSchemaMarkerOrigin.freshInstall,
        sourceSchemaVersion: null,
        sourceSchemaFingerprint: null,
      ).encode();
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey: marker,
      });
      final before = await SharedPreferences.getInstance();
      final beforeKeys = before.getKeys();
      final beforeMarker = before.getString(
        SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey,
      );

      final inventory = await readPrivacySafeIsarProvenanceInventory(
        databaseDirectoryPath: directory.path,
      );

      final after = await SharedPreferences.getInstance();
      expect(inventory.overallDisposition, 'EXISTING_STORE_CANONICAL_CURRENT');
      expect(inventory.hasDurableStore, isTrue);
      expect(inventory.toDiagnosticsText(), isNot(contains(generation)));
      expect(after.getKeys(), beforeKeys);
      expect(
        after.getString(
          SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey,
        ),
        beforeMarker,
      );
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
