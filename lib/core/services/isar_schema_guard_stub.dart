// FILE: lib/core/services/isar_schema_guard_stub.dart

import 'isar_schema_migration.dart';

Future<IsarSchemaOpenPreparation> ensureIsarSchemaBeforeOpen({
  required String databaseDirectoryPath,
}) async {
  return IsarSchemaMigrator.prepareBeforeOpen(
    store: InMemoryIsarSchemaProvenanceStore(),
    databaseDirectoryPath: databaseDirectoryPath,
    hasExistingLocalStore: false,
  );
}

Future<String> readIsarSchemaProvenanceSnapshotJson() async {
  return '{"captureFormatVersion":1,"storage":"unsupported","values":{}}';
}
