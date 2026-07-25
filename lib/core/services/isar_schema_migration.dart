// FILE: lib/core/services/isar_schema_migration.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent schema-version store used before opening Isar.
///
/// The production implementation stores the marker in SharedPreferences rather
/// than in Isar so the app can make a decision before Isar.open is attempted.
abstract class IsarSchemaVersionStore {
  Future<int?> readSchemaVersion();
  Future<void> writeSchemaVersion(int version);

  Future<String?> readSchemaFingerprint();
  Future<void> writeSchemaFingerprint(String fingerprint);
}

class SharedPreferencesIsarSchemaVersionStore
    implements IsarSchemaVersionStore {
  static const String schemaVersionKey = 'baf_isar_schema_version';
  static const String schemaFingerprintKey = 'baf_isar_schema_fingerprint';

  final SharedPreferences _preferences;

  SharedPreferencesIsarSchemaVersionStore(this._preferences);

  @override
  Future<int?> readSchemaVersion() async {
    return _preferences.getInt(schemaVersionKey);
  }

  @override
  Future<void> writeSchemaVersion(int version) async {
    await _preferences.setInt(schemaVersionKey, version);
  }

  @override
  Future<String?> readSchemaFingerprint() async {
    return _preferences.getString(schemaFingerprintKey);
  }

  @override
  Future<void> writeSchemaFingerprint(String fingerprint) async {
    await _preferences.setString(schemaFingerprintKey, fingerprint);
  }
}

/// Test-only store. It deliberately has no platform dependency.
class InMemoryIsarSchemaVersionStore implements IsarSchemaVersionStore {
  int? version;
  String? fingerprint;

  InMemoryIsarSchemaVersionStore({this.version, this.fingerprint});

  @override
  Future<int?> readSchemaVersion() async => version;

  @override
  Future<void> writeSchemaVersion(int version) async {
    this.version = version;
  }

  @override
  Future<String?> readSchemaFingerprint() async => fingerprint;

  @override
  Future<void> writeSchemaFingerprint(String fingerprint) async {
    this.fingerprint = fingerprint;
  }
}

class IsarSchemaMigrationContext {
  final int fromVersion;
  final int toVersion;
  final String databaseDirectoryPath;
  final bool hasExistingLocalStore;
  final String targetFingerprint;

  const IsarSchemaMigrationContext({
    required this.fromVersion,
    required this.toVersion,
    required this.databaseDirectoryPath,
    required this.hasExistingLocalStore,
    required this.targetFingerprint,
  });
}

typedef IsarSchemaMigrationStep =
    Future<void> Function(IsarSchemaMigrationContext context);

class IsarSchemaMigrationPlan {
  final int currentVersion;
  final String schemaFingerprint;
  final Map<int, IsarSchemaMigrationStep> stepsByTargetVersion;

  const IsarSchemaMigrationPlan({
    required this.currentVersion,
    required this.schemaFingerprint,
    this.stepsByTargetVersion = const <int, IsarSchemaMigrationStep>{},
  }) : assert(currentVersion >= 1);

  IsarSchemaMigrationStep? stepForTargetVersion(int targetVersion) {
    return stepsByTargetVersion[targetVersion];
  }
}

enum IsarSchemaMigrationOutcome {
  freshInstallStamped,
  existingInstallBaselineStamped,
  alreadyCurrent,
  migrated,
}

class IsarSchemaMigrationResult {
  final IsarSchemaMigrationOutcome outcome;
  final int fromVersion;
  final int toVersion;
  final bool hadExistingLocalStore;
  final String schemaFingerprint;

  const IsarSchemaMigrationResult({
    required this.outcome,
    required this.fromVersion,
    required this.toVersion,
    required this.hadExistingLocalStore,
    required this.schemaFingerprint,
  });

  bool get changed => fromVersion != toVersion;
}

class IsarSchemaMigrationException implements Exception {
  final String message;
  final int? storedVersion;
  final int targetVersion;

  const IsarSchemaMigrationException(
    this.message, {
    this.storedVersion,
    required this.targetVersion,
  });

  @override
  String toString() {
    final stored = storedVersion == null ? 'unknown' : '$storedVersion';
    return 'IsarSchemaMigrationException($message; stored=$stored; target=$targetVersion)';
  }
}

class MissingIsarSchemaMigrationStepException
    extends IsarSchemaMigrationException {
  final int missingFromVersion;
  final int missingToVersion;

  MissingIsarSchemaMigrationStepException({
    required this.missingFromVersion,
    required this.missingToVersion,
    required int targetVersion,
  }) : super(
         'Missing Isar schema migration step from v$missingFromVersion to v$missingToVersion.',
         storedVersion: missingFromVersion,
         targetVersion: targetVersion,
       );
}

class IsarSchemaMigrator {
  /// lib(15) baseline marker. Future schema changes must bump this and add a
  /// migration step to [defaultPlan] before any Isar schema-breaking release.
  static const int currentSchemaVersion = 3;

  /// Human-readable fingerprint of the registered Isar collection set in the
  /// current baseline. This is intentionally stable and reviewable in diffs.
  static const String currentSchemaFingerprint =
      'v3:Charge,MaintenanceRecord+WorkflowBridge,JobTemplate,JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,TemplatePublishAudit,'
      'BafKnowledgeRow,BafKnowledgeMatrixMetaStore,OperationalDirective,'
      'AuditEvent,SyncRejection,AbnormalityType,ChargeAbnormality,'
      'WorkflowAggregateRecord,JobLaneRecord,ComplianceRequestRecord,'
      'ComplianceAttemptRecord,EquipmentStatusRecord,EquipmentPromptRecord,'
      'WorkflowEventRecord,WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const IsarSchemaMigrationPlan defaultPlan = IsarSchemaMigrationPlan(
    currentVersion: currentSchemaVersion,
    schemaFingerprint: currentSchemaFingerprint,
    stepsByTargetVersion: <int, IsarSchemaMigrationStep>{
      // Additive collection registration. The current installation contains
      // only controlled fake/test data; no destructive row rewrite is needed.
      2: _registerMaintenanceWorkflowCollections,
      3: _reconcileV4WorkflowPersistence,
    },
  );

  static Future<void> _registerMaintenanceWorkflowCollections(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 1 || context.toVersion != 2) {
      throw IsarSchemaMigrationException(
        'Unexpected maintenance-workflow schema transition.',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
      );
    }
  }


  static Future<void> _reconcileV4WorkflowPersistence(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 2 || context.toVersion != 3) {
      throw IsarSchemaMigrationException(
        'Unexpected v4 workflow-persistence transition.',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
      );
    }
    // Isar performs the additive field/index migration when the reconciled
    // schemas are opened. This pre-open step intentionally records the
    // reviewed transition and prevents same-version fingerprint drift.
  }

  const IsarSchemaMigrator._();

  static Future<IsarSchemaMigrationResult> ensureBeforeOpen({
    required IsarSchemaVersionStore store,
    required String databaseDirectoryPath,
    required bool hasExistingLocalStore,
    IsarSchemaMigrationPlan plan = defaultPlan,
  }) async {
    final storedVersion = await store.readSchemaVersion();

    if (storedVersion == null) {
      await store.writeSchemaVersion(plan.currentVersion);
      await store.writeSchemaFingerprint(plan.schemaFingerprint);
      return IsarSchemaMigrationResult(
        outcome:
            hasExistingLocalStore
                ? IsarSchemaMigrationOutcome.existingInstallBaselineStamped
                : IsarSchemaMigrationOutcome.freshInstallStamped,
        fromVersion: 0,
        toVersion: plan.currentVersion,
        hadExistingLocalStore: hasExistingLocalStore,
        schemaFingerprint: plan.schemaFingerprint,
      );
    }

    if (storedVersion > plan.currentVersion) {
      throw IsarSchemaMigrationException(
        'Local Isar schema marker is newer than this app build. Refusing to open with an older app.',
        storedVersion: storedVersion,
        targetVersion: plan.currentVersion,
      );
    }

    if (storedVersion == plan.currentVersion) {
      final storedFingerprint = await store.readSchemaFingerprint();
      if (storedFingerprint != null &&
          storedFingerprint != plan.schemaFingerprint) {
        throw IsarSchemaMigrationException(
          'Local Isar schema fingerprint does not match this app build at the same schema version. '
          'This usually means an Isar schema changed without bumping the migration version.',
          storedVersion: storedVersion,
          targetVersion: plan.currentVersion,
        );
      }
      if (storedFingerprint == null) {
        await store.writeSchemaFingerprint(plan.schemaFingerprint);
      }
      return IsarSchemaMigrationResult(
        outcome: IsarSchemaMigrationOutcome.alreadyCurrent,
        fromVersion: storedVersion,
        toVersion: plan.currentVersion,
        hadExistingLocalStore: hasExistingLocalStore,
        schemaFingerprint: plan.schemaFingerprint,
      );
    }

    var version = storedVersion;
    while (version < plan.currentVersion) {
      final target = version + 1;
      final step = plan.stepForTargetVersion(target);
      if (step == null) {
        throw MissingIsarSchemaMigrationStepException(
          missingFromVersion: version,
          missingToVersion: target,
          targetVersion: plan.currentVersion,
        );
      }

      await step(
        IsarSchemaMigrationContext(
          fromVersion: version,
          toVersion: target,
          databaseDirectoryPath: databaseDirectoryPath,
          hasExistingLocalStore: hasExistingLocalStore,
          targetFingerprint: plan.schemaFingerprint,
        ),
      );
      await store.writeSchemaVersion(target);
      version = target;
    }

    await store.writeSchemaFingerprint(plan.schemaFingerprint);
    return IsarSchemaMigrationResult(
      outcome: IsarSchemaMigrationOutcome.migrated,
      fromVersion: storedVersion,
      toVersion: plan.currentVersion,
      hadExistingLocalStore: hasExistingLocalStore,
      schemaFingerprint: plan.schemaFingerprint,
    );
  }
}
