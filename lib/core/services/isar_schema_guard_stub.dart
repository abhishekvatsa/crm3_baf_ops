// FILE: lib/core/services/isar_schema_guard_stub.dart

import 'isar_schema_migration.dart';

Future<IsarSchemaMigrationResult> ensureIsarSchemaBeforeOpen({
  required String databaseDirectoryPath,
}) async {
  return IsarSchemaMigrator.ensureBeforeOpen(
    store: InMemoryIsarSchemaVersionStore(),
    databaseDirectoryPath: databaseDirectoryPath,
    hasExistingLocalStore: false,
  );
}
