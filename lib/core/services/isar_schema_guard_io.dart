// FILE: lib/core/services/isar_schema_guard_io.dart

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'isar_schema_migration.dart';

Future<IsarSchemaOpenPreparation> ensureIsarSchemaBeforeOpen({
  required String databaseDirectoryPath,
}) async {
  final preferences = await SharedPreferences.getInstance();
  final hasExistingStore = await hasDurableIsarStoreFiles(
    databaseDirectoryPath,
  );

  return IsarSchemaMigrator.prepareBeforeOpen(
    store: SharedPreferencesIsarSchemaProvenanceStore(preferences),
    databaseDirectoryPath: databaseDirectoryPath,
    hasExistingLocalStore: hasExistingStore,
  );
}

Future<bool> hasDurableIsarStoreFiles(String databaseDirectoryPath) async {
  final directory = Directory(databaseDirectoryPath);
  if (!await directory.exists()) {
    return false;
  }

  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final fileName = entity.uri.pathSegments.last.toLowerCase();
    if (fileName.endsWith('.isar') ||
        fileName.endsWith('.isar.tmp') ||
        fileName == 'default.isar' ||
        fileName == 'baf_ops.isar') {
      return true;
    }
  }

  return false;
}

Future<String> readIsarSchemaProvenanceSnapshotJson() async {
  final preferences = await SharedPreferences.getInstance();
  final keys = <String>[
    SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey,
    SharedPreferencesIsarSchemaProvenanceStore.legacySchemaVersionKey,
    SharedPreferencesIsarSchemaProvenanceStore.legacySchemaFingerprintKey,
  ];
  final values = <String, Object?>{};
  for (final key in keys) {
    final value = preferences.get(key);
    values[key] = <String, Object?>{
      'present': value != null,
      'valueType': value?.runtimeType.toString(),
      'value': value,
    };
  }
  return jsonEncode(<String, Object?>{
    'captureFormatVersion': 1,
    'storage': 'SharedPreferences',
    'values': values,
  });
}
