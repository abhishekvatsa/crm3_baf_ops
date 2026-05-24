// FILE: lib/core/services/isar_schema_guard_io.dart

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'isar_schema_migration.dart';

Future<IsarSchemaMigrationResult> ensureIsarSchemaBeforeOpen({
  required String databaseDirectoryPath,
}) async {
  final preferences = await SharedPreferences.getInstance();
  final hasExistingStore = await _hasLikelyIsarStoreFiles(
    databaseDirectoryPath,
  );

  return IsarSchemaMigrator.ensureBeforeOpen(
    store: SharedPreferencesIsarSchemaVersionStore(preferences),
    databaseDirectoryPath: databaseDirectoryPath,
    hasExistingLocalStore: hasExistingStore,
  );
}

Future<bool> _hasLikelyIsarStoreFiles(String databaseDirectoryPath) async {
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
        fileName.endsWith('.isar.lock') ||
        fileName.endsWith('.isar.tmp') ||
        fileName == 'default.isar' ||
        fileName == 'baf_ops.isar') {
      return true;
    }
  }

  return false;
}
