// FILE: lib/core/services/isar_schema_migration.dart

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _canonicalMarkerFields = <String>{
  'markerFormatVersion',
  'state',
  'schemaVersion',
  'schemaFingerprint',
  'databaseGenerationId',
  'origin',
  'sourceSchemaVersion',
  'sourceSchemaFingerprint',
};

const _databaseGenerationPattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-'
    r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

enum IsarSchemaMarkerState {
  prepared('PREPARED'),
  committed('COMMITTED');

  final String wireName;
  const IsarSchemaMarkerState(this.wireName);

  static IsarSchemaMarkerState? fromWireName(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

enum IsarSchemaMarkerOrigin {
  freshInstall('FRESH_INSTALL'),
  storeReplacement('STORE_REPLACEMENT'),
  legacyCompleteMarker('LEGACY_COMPLETE_MARKER'),
  schemaMigration('SCHEMA_MIGRATION');

  final String wireName;
  const IsarSchemaMarkerOrigin(this.wireName);

  bool get requiresSource =>
      this == legacyCompleteMarker || this == schemaMigration;

  bool get canResumeWithoutDurableStore =>
      this == freshInstall || this == storeReplacement;

  static IsarSchemaMarkerOrigin? fromWireName(String value) {
    for (final origin in values) {
      if (origin.wireName == value) return origin;
    }
    return null;
  }
}

class IsarSchemaProvenanceMarker {
  static const int currentMarkerFormatVersion = 1;

  final int markerFormatVersion;
  final IsarSchemaMarkerState state;
  final int schemaVersion;
  final String schemaFingerprint;
  final String databaseGenerationId;
  final IsarSchemaMarkerOrigin origin;
  final int? sourceSchemaVersion;
  final String? sourceSchemaFingerprint;

  const IsarSchemaProvenanceMarker({
    this.markerFormatVersion = currentMarkerFormatVersion,
    required this.state,
    required this.schemaVersion,
    required this.schemaFingerprint,
    required this.databaseGenerationId,
    required this.origin,
    required this.sourceSchemaVersion,
    required this.sourceSchemaFingerprint,
  });

  IsarSchemaProvenanceMarker committed() {
    return IsarSchemaProvenanceMarker(
      markerFormatVersion: markerFormatVersion,
      state: IsarSchemaMarkerState.committed,
      schemaVersion: schemaVersion,
      schemaFingerprint: schemaFingerprint,
      databaseGenerationId: databaseGenerationId,
      origin: origin,
      sourceSchemaVersion: sourceSchemaVersion,
      sourceSchemaFingerprint: sourceSchemaFingerprint,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'markerFormatVersion': markerFormatVersion,
      'state': state.wireName,
      'schemaVersion': schemaVersion,
      'schemaFingerprint': schemaFingerprint,
      'databaseGenerationId': databaseGenerationId,
      'origin': origin.wireName,
      'sourceSchemaVersion': sourceSchemaVersion,
      'sourceSchemaFingerprint': sourceSchemaFingerprint,
    };
  }

  String encode() => jsonEncode(toJson());

  static IsarSchemaProvenanceMarker decode(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException catch (error) {
      throw IsarSchemaMarkerFormatException(
        'The canonical Isar provenance marker is not valid JSON.',
        reasonCode: 'canonical-marker-invalid-json',
        details: error.message,
      );
    }

    if (decoded is! Map) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance marker must be a JSON object.',
        reasonCode: 'canonical-marker-not-object',
      );
    }
    final data = Map<String, Object?>.from(decoded);
    final keys = data.keys.toSet();
    if (keys.length != _canonicalMarkerFields.length ||
        !keys.containsAll(_canonicalMarkerFields)) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance marker has an incomplete or unsupported shape.',
        reasonCode: 'canonical-marker-invalid-shape',
      );
    }

    final markerFormatVersion = data['markerFormatVersion'];
    final schemaVersion = data['schemaVersion'];
    final schemaFingerprint = data['schemaFingerprint'];
    final databaseGenerationId = data['databaseGenerationId'];
    final stateRaw = data['state'];
    final originRaw = data['origin'];
    final sourceSchemaVersion = data['sourceSchemaVersion'];
    final sourceSchemaFingerprint = data['sourceSchemaFingerprint'];

    if (markerFormatVersion != currentMarkerFormatVersion) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance marker format is unsupported.',
        reasonCode: 'canonical-marker-format-unsupported',
      );
    }
    if (schemaVersion is! int || schemaVersion <= 0) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance schema version is invalid.',
        reasonCode: 'canonical-marker-schema-version-invalid',
      );
    }
    if (schemaFingerprint is! String ||
        schemaFingerprint.trim().isEmpty ||
        schemaFingerprint.length > 4096) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance fingerprint is invalid.',
        reasonCode: 'canonical-marker-fingerprint-invalid',
      );
    }
    if (databaseGenerationId is! String ||
        !RegExp(
          _databaseGenerationPattern,
          caseSensitive: false,
        ).hasMatch(databaseGenerationId)) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar database generation identity is invalid.',
        reasonCode: 'canonical-marker-generation-invalid',
      );
    }
    if (stateRaw is! String ||
        IsarSchemaMarkerState.fromWireName(stateRaw) == null) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance state is invalid.',
        reasonCode: 'canonical-marker-state-invalid',
      );
    }
    if (originRaw is! String ||
        IsarSchemaMarkerOrigin.fromWireName(originRaw) == null) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance origin is invalid.',
        reasonCode: 'canonical-marker-origin-invalid',
      );
    }
    if (sourceSchemaVersion != null &&
        (sourceSchemaVersion is! int || sourceSchemaVersion <= 0)) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar source schema version is invalid.',
        reasonCode: 'canonical-marker-source-version-invalid',
      );
    }
    if (sourceSchemaFingerprint != null &&
        (sourceSchemaFingerprint is! String ||
            sourceSchemaFingerprint.trim().isEmpty ||
            sourceSchemaFingerprint.length > 4096)) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar source fingerprint is invalid.',
        reasonCode: 'canonical-marker-source-fingerprint-invalid',
      );
    }

    final origin = IsarSchemaMarkerOrigin.fromWireName(originRaw)!;
    final hasSourceVersion = sourceSchemaVersion != null;
    final hasSourceFingerprint = sourceSchemaFingerprint != null;
    if (hasSourceVersion != hasSourceFingerprint ||
        origin.requiresSource != hasSourceVersion) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance source evidence is inconsistent.',
        reasonCode: 'canonical-marker-source-inconsistent',
      );
    }
    if (origin == IsarSchemaMarkerOrigin.schemaMigration &&
        (sourceSchemaVersion as int) >= schemaVersion) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar migration source must precede its target.',
        reasonCode: 'canonical-marker-migration-range-invalid',
      );
    }

    return IsarSchemaProvenanceMarker(
      markerFormatVersion: markerFormatVersion as int,
      state: IsarSchemaMarkerState.fromWireName(stateRaw)!,
      schemaVersion: schemaVersion,
      schemaFingerprint: schemaFingerprint,
      databaseGenerationId: databaseGenerationId,
      origin: origin,
      sourceSchemaVersion: sourceSchemaVersion as int?,
      sourceSchemaFingerprint: sourceSchemaFingerprint as String?,
    );
  }
}

class LegacyIsarSchemaMarker {
  final int? schemaVersion;
  final String? schemaFingerprint;

  const LegacyIsarSchemaMarker({
    required this.schemaVersion,
    required this.schemaFingerprint,
  });

  bool get isAbsent => schemaVersion == null && schemaFingerprint == null;
  bool get isComplete => schemaVersion != null && schemaFingerprint != null;
  bool get isPartial => !isAbsent && !isComplete;
}

/// Persistent provenance store used before opening Isar.
///
/// The canonical marker is one JSON value so version, fingerprint, generation,
/// origin, and lifecycle state cannot be torn across independent keys.
abstract class IsarSchemaProvenanceStore {
  Future<String?> readCanonicalMarkerJson();
  Future<bool> writeCanonicalMarkerJson(String encoded);

  Future<int?> readLegacySchemaVersion();
  Future<String?> readLegacySchemaFingerprint();
  Future<bool> clearLegacySchemaMarker();
}

class SharedPreferencesIsarSchemaProvenanceStore
    implements IsarSchemaProvenanceStore {
  static const String canonicalMarkerKey = 'baf_isar_schema_provenance_v1';
  static const String legacySchemaVersionKey = 'baf_isar_schema_version';
  static const String legacySchemaFingerprintKey =
      'baf_isar_schema_fingerprint';

  final SharedPreferences _preferences;

  SharedPreferencesIsarSchemaProvenanceStore(this._preferences);

  @override
  Future<String?> readCanonicalMarkerJson() async {
    final value = _preferences.get(canonicalMarkerKey);
    if (value == null) return null;
    if (value is! String) {
      throw const IsarSchemaMarkerFormatException(
        'The canonical Isar provenance marker has an invalid stored type.',
        reasonCode: 'canonical-marker-storage-type-invalid',
      );
    }
    return value;
  }

  @override
  Future<bool> writeCanonicalMarkerJson(String encoded) async {
    final written = await _preferences.setString(canonicalMarkerKey, encoded);
    return written && _preferences.getString(canonicalMarkerKey) == encoded;
  }

  @override
  Future<int?> readLegacySchemaVersion() async {
    final value = _preferences.get(legacySchemaVersionKey);
    if (value == null) return null;
    if (value is! int) {
      throw const IsarSchemaMarkerFormatException(
        'The legacy Isar schema version marker has an invalid stored type.',
        reasonCode: 'legacy-marker-version-type-invalid',
      );
    }
    return value;
  }

  @override
  Future<String?> readLegacySchemaFingerprint() async {
    final value = _preferences.get(legacySchemaFingerprintKey);
    if (value == null) return null;
    if (value is! String) {
      throw const IsarSchemaMarkerFormatException(
        'The legacy Isar schema fingerprint marker has an invalid stored type.',
        reasonCode: 'legacy-marker-fingerprint-type-invalid',
      );
    }
    return value;
  }

  @override
  Future<bool> clearLegacySchemaMarker() async {
    var cleared = true;
    if (_preferences.containsKey(legacySchemaVersionKey)) {
      cleared = await _preferences.remove(legacySchemaVersionKey) && cleared;
    }
    if (_preferences.containsKey(legacySchemaFingerprintKey)) {
      cleared =
          await _preferences.remove(legacySchemaFingerprintKey) && cleared;
    }
    return cleared &&
        !_preferences.containsKey(legacySchemaVersionKey) &&
        !_preferences.containsKey(legacySchemaFingerprintKey);
  }
}

/// Test-only store. It deliberately has no platform dependency.
class InMemoryIsarSchemaProvenanceStore implements IsarSchemaProvenanceStore {
  String? canonicalMarkerJson;
  int? legacyVersion;
  String? legacyFingerprint;
  bool failCanonicalWrites;
  bool failLegacyClear;
  int canonicalWriteCount = 0;

  InMemoryIsarSchemaProvenanceStore({
    this.canonicalMarkerJson,
    this.legacyVersion,
    this.legacyFingerprint,
    this.failCanonicalWrites = false,
    this.failLegacyClear = false,
  });

  @override
  Future<String?> readCanonicalMarkerJson() async => canonicalMarkerJson;

  @override
  Future<bool> writeCanonicalMarkerJson(String encoded) async {
    canonicalWriteCount++;
    if (failCanonicalWrites) return false;
    canonicalMarkerJson = encoded;
    return true;
  }

  @override
  Future<int?> readLegacySchemaVersion() async => legacyVersion;

  @override
  Future<String?> readLegacySchemaFingerprint() async => legacyFingerprint;

  @override
  Future<bool> clearLegacySchemaMarker() async {
    if (failLegacyClear) return false;
    legacyVersion = null;
    legacyFingerprint = null;
    return true;
  }
}

class IsarSchemaMigrationContext {
  final int fromVersion;
  final int toVersion;
  final String databaseDirectoryPath;
  final bool hasExistingLocalStore;
  final String targetFingerprint;
  final String databaseGenerationId;

  const IsarSchemaMigrationContext({
    required this.fromVersion,
    required this.toVersion,
    required this.databaseDirectoryPath,
    required this.hasExistingLocalStore,
    required this.targetFingerprint,
    required this.databaseGenerationId,
  });
}

typedef IsarSchemaMigrationStep =
    Future<void> Function(IsarSchemaMigrationContext context);

class IsarSchemaMigrationPlan {
  final int currentVersion;
  final String schemaFingerprint;
  final Map<int, Set<String>> acceptedFingerprintsByVersion;
  final Map<int, IsarSchemaMigrationStep> stepsByTargetVersion;

  const IsarSchemaMigrationPlan({
    required this.currentVersion,
    required this.schemaFingerprint,
    required this.acceptedFingerprintsByVersion,
    this.stepsByTargetVersion = const <int, IsarSchemaMigrationStep>{},
  }) : assert(currentVersion >= 1);

  IsarSchemaMigrationStep? stepForTargetVersion(int targetVersion) {
    return stepsByTargetVersion[targetVersion];
  }

  bool acceptsFingerprint(int version, String fingerprint) {
    return acceptedFingerprintsByVersion[version]?.contains(fingerprint) ??
        false;
  }
}

enum IsarSchemaMigrationOutcome {
  freshInstallInitialized,
  storeReplacementInitialized,
  legacyMarkerMigrated,
  preparedOpenResumed,
  alreadyCurrent,
  migrated,
}

class IsarSchemaMigrationResult {
  final IsarSchemaMigrationOutcome outcome;
  final int fromVersion;
  final int toVersion;
  final bool hadExistingLocalStore;
  final IsarSchemaProvenanceMarker marker;

  const IsarSchemaMigrationResult({
    required this.outcome,
    required this.fromVersion,
    required this.toVersion,
    required this.hadExistingLocalStore,
    required this.marker,
  });

  String get schemaFingerprint => marker.schemaFingerprint;
  String get databaseGenerationId => marker.databaseGenerationId;
  IsarSchemaMarkerOrigin get origin => marker.origin;
  bool get changed => fromVersion != toVersion;
}

class IsarSchemaMigrationException implements Exception {
  final String message;
  final String reasonCode;
  final int? storedVersion;
  final int targetVersion;
  final bool? hasExistingLocalStore;
  final String? markerDisposition;

  const IsarSchemaMigrationException(
    this.message, {
    required this.reasonCode,
    this.storedVersion,
    required this.targetVersion,
    this.hasExistingLocalStore,
    this.markerDisposition,
  });

  @override
  String toString() {
    final stored = storedVersion == null ? 'unknown' : '$storedVersion';
    final store =
        hasExistingLocalStore == null ? 'unknown' : '$hasExistingLocalStore';
    final marker = markerDisposition ?? 'unknown';
    return 'IsarSchemaMigrationException('
        'reason=$reasonCode; stored=$stored; target=$targetVersion; '
        'existingStore=$store; marker=$marker; message=$message)';
  }
}

class IsarSchemaMarkerFormatException implements Exception {
  final String message;
  final String reasonCode;
  final String? details;

  const IsarSchemaMarkerFormatException(
    this.message, {
    required this.reasonCode,
    this.details,
  });

  @override
  String toString() {
    return 'IsarSchemaMarkerFormatException('
        'reason=$reasonCode; message=$message)';
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
         'Missing Isar schema migration step from '
         'v$missingFromVersion to v$missingToVersion.',
         reasonCode: 'schema-migration-step-missing',
         storedVersion: missingFromVersion,
         targetVersion: targetVersion,
         hasExistingLocalStore: true,
         markerDisposition: 'migration-prepared',
       );
}

class IsarSchemaOpenPreparation {
  final IsarSchemaProvenanceStore _store;
  final bool _clearLegacyMarkerAfterOpen;
  final IsarSchemaMigrationResult result;
  IsarSchemaProvenanceMarker _marker;
  bool _completed = false;

  IsarSchemaOpenPreparation._({
    required IsarSchemaProvenanceStore store,
    required bool clearLegacyMarkerAfterOpen,
    required this.result,
    required IsarSchemaProvenanceMarker marker,
  }) : _store = store,
       _clearLegacyMarkerAfterOpen = clearLegacyMarkerAfterOpen,
       _marker = marker;

  IsarSchemaProvenanceMarker get marker => _marker;

  /// Commits provenance only after Isar.open and all post-open repair succeeds.
  Future<IsarSchemaProvenanceMarker> commitAfterSuccessfulOpen() async {
    if (_completed) return _marker;

    if (_marker.state == IsarSchemaMarkerState.prepared) {
      final committed = _marker.committed();
      await _persistCanonicalMarker(
        store: _store,
        marker: committed,
        targetVersion: committed.schemaVersion,
      );
      _marker = committed;
    }

    if (_clearLegacyMarkerAfterOpen) {
      final cleared = await _store.clearLegacySchemaMarker();
      final legacy = await _readLegacyMarker(_store);
      if (!cleared || !legacy.isAbsent) {
        throw IsarSchemaMigrationException(
          'The legacy Isar marker could not be cleared after canonical provenance was committed.',
          reasonCode: 'legacy-marker-clear-failed',
          storedVersion: _marker.schemaVersion,
          targetVersion: _marker.schemaVersion,
          markerDisposition: 'canonical-committed-legacy-present',
        );
      }
    }

    _completed = true;
    return _marker;
  }
}

class IsarSchemaMigrator {
  static const int currentSchemaVersion = 10;

  static const String v1SchemaFingerprint =
      'v1:Charge,MaintenanceRecord,JobTemplate,JobExecution,JobDiaryEntry,'
      'JobModuleInstance,TemplatePackage,TemplateVersion,TemplatePublishAudit,'
      'BafKnowledgeRow,BafKnowledgeMatrixMetaStore,OperationalDirective,'
      'AuditEvent,SyncRejection,AbnormalityType,ChargeAbnormality';

  static const String v3SchemaFingerprint =
      'v3:Charge,MaintenanceRecord+WorkflowBridge,JobTemplate,'
      'JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,'
      'TemplatePublishAudit,BafKnowledgeRow,BafKnowledgeMatrixMetaStore,'
      'OperationalDirective,AuditEvent,SyncRejection,AbnormalityType,'
      'ChargeAbnormality,WorkflowAggregateRecord,JobLaneRecord,'
      'ComplianceRequestRecord,ComplianceAttemptRecord,EquipmentStatusRecord,'
      'EquipmentPromptRecord,WorkflowEventRecord,WorkflowCommandRecord,'
      'WorkflowCommandReceiptRecord';

  static const String v4SchemaFingerprint =
      'v4:Charge,MaintenanceRecord+WorkflowBridge,JobTemplate,'
      'JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,'
      'TemplatePublishAudit,BafKnowledgeRow,BafKnowledgeMatrixMetaStore,'
      'OperationalDirective,AuditEvent,SyncRejection,AbnormalityType,'
      'ChargeAbnormality,WorkflowAggregateRecord,JobLaneRecord,'
      'ComplianceRequestRecord+OperationalAssurance,ComplianceAttemptRecord,'
      'EquipmentStatusRecord,EquipmentPromptRecord,WorkflowEventRecord,'
      'WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const String v5SchemaFingerprint =
      'v5:Charge,MaintenanceRecord+WorkflowBridge,JobTemplate,'
      'JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,'
      'TemplatePublishAudit,BafKnowledgeRow,BafKnowledgeMatrixMetaStore,'
      'OperationalDirective,AuditEvent,SyncRejection,AbnormalityType,'
      'ChargeAbnormality,WorkflowAggregateRecord+GovernedAssetIdentity,'
      'JobLaneRecord,ComplianceRequestRecord+OperationalAssurance,'
      'ComplianceAttemptRecord,EquipmentStatusRecord+GovernedAssetIdentity,'
      'EquipmentPromptRecord,WorkflowEventRecord,WorkflowCommandRecord,'
      'WorkflowCommandReceiptRecord';

  static const String v6SchemaFingerprint =
      'v6:Charge,MaintenanceRecord+WorkflowBridge+OperationalEventIssueLinks,'
      'JobTemplate,JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,'
      'TemplatePublishAudit,BafKnowledgeRow,BafKnowledgeMatrixMetaStore,'
      'OperationalDirective,AuditEvent,SyncRejection,AbnormalityType,'
      'ChargeAbnormality,WorkflowAggregateRecord+GovernedAssetIdentity,'
      'JobLaneRecord,ComplianceRequestRecord+OperationalAssurance,'
      'ComplianceAttemptRecord,EquipmentStatusRecord+GovernedAssetIdentity,'
      'EquipmentPromptRecord,WorkflowEventRecord,WorkflowCommandRecord,'
      'WorkflowCommandReceiptRecord';

  static const String v7SchemaFingerprint =
      'v7:Charge,MaintenanceRecord+WorkflowBridge+OperationalEventIssueLinks+'
      'ReopenEvidence,JobTemplate,JobExecution+WorkflowTerminalState,'
      'JobDiaryEntry+EMD+RED,JobModuleInstance+EMD+RED,TemplatePackage,'
      'TemplateVersion,TemplatePublishAudit,BafKnowledgeRow,'
      'BafKnowledgeMatrixMetaStore,OperationalDirective,AuditEvent,'
      'SyncRejection,AbnormalityType,ChargeAbnormality,'
      'WorkflowAggregateRecord+GovernedAssetIdentity,JobLaneRecord,'
      'ComplianceRequestRecord+OperationalAssurance,ComplianceAttemptRecord,'
      'EquipmentStatusRecord+GovernedAssetIdentity,EquipmentPromptRecord,'
      'WorkflowEventRecord,WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const String v8SchemaFingerprint =
      'v8:Charge,MaintenanceRecord+WorkflowBridge+OperationalEventIssueLinks+'
      'ReopenEvidence,JobTemplate,JobExecution+WorkflowTerminalState,'
      'JobDiaryEntry+EMD+RED,JobModuleInstance+EMD+RED,TemplatePackage,'
      'TemplateVersion,TemplatePublishAudit,BafKnowledgeRow,'
      'BafKnowledgeMatrixMetaStore,OperationalDirective,AuditEvent,'
      'SyncRejection+OriginatingUid,AbnormalityType,ChargeAbnormality,'
      'WorkflowAggregateRecord+GovernedAssetIdentity,JobLaneRecord,'
      'ComplianceRequestRecord+OperationalAssurance,ComplianceAttemptRecord,'
      'EquipmentStatusRecord+GovernedAssetIdentity,EquipmentPromptRecord,'
      'WorkflowEventRecord,WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const String v9SchemaFingerprint =
      'v9:Charge,MaintenanceRecord+WorkflowBridge+OperationalEventIssueLinks+'
      'ReopenEvidence+PlantConditionEffect,JobTemplate,'
      'JobExecution+WorkflowTerminalState,JobDiaryEntry+EMD+RED,'
      'JobModuleInstance+EMD+RED,TemplatePackage,TemplateVersion,'
      'TemplatePublishAudit,BafKnowledgeRow,BafKnowledgeMatrixMetaStore,'
      'OperationalDirective,AuditEvent,SyncRejection+OriginatingUid,'
      'AbnormalityType,ChargeAbnormality,'
      'WorkflowAggregateRecord+GovernedAssetIdentity,JobLaneRecord,'
      'ComplianceRequestRecord+OperationalAssurance,ComplianceAttemptRecord,'
      'EquipmentStatusRecord+GovernedAssetIdentity,EquipmentPromptRecord,'
      'WorkflowEventRecord,WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const String currentSchemaFingerprint =
      'v10:Charge,MaintenanceRecord+WorkflowBridge+OperationalEventIssueLinks+'
      'ReopenEvidence+PlantConditionEffect+PlantConditionContributionIndex,'
      'JobTemplate,JobExecution+WorkflowTerminalState,'
      'JobDiaryEntry+EMD+RED,JobModuleInstance+EMD+RED,TemplatePackage,'
      'TemplateVersion,TemplatePublishAudit,BafKnowledgeRow,'
      'BafKnowledgeMatrixMetaStore,OperationalDirective,AuditEvent,'
      'SyncRejection+OriginatingUid,AbnormalityType,ChargeAbnormality,'
      'WorkflowAggregateRecord+GovernedAssetIdentity,JobLaneRecord,'
      'ComplianceRequestRecord+OperationalAssurance,ComplianceAttemptRecord,'
      'EquipmentStatusRecord+GovernedAssetIdentity,EquipmentPromptRecord,'
      'WorkflowEventRecord,WorkflowCommandRecord,WorkflowCommandReceiptRecord';

  static const IsarSchemaMigrationPlan defaultPlan = IsarSchemaMigrationPlan(
    currentVersion: currentSchemaVersion,
    schemaFingerprint: currentSchemaFingerprint,
    acceptedFingerprintsByVersion: <int, Set<String>>{
      1: <String>{v1SchemaFingerprint},
      // No repository-proven v2 fingerprint exists. A v2 store therefore
      // requires the governed 70K fixture/adoption path and is not guessed.
      3: <String>{v3SchemaFingerprint},
      4: <String>{v4SchemaFingerprint},
      5: <String>{v5SchemaFingerprint},
      6: <String>{v6SchemaFingerprint},
      7: <String>{v7SchemaFingerprint},
      8: <String>{v8SchemaFingerprint},
      9: <String>{v9SchemaFingerprint},
      10: <String>{currentSchemaFingerprint},
    },
    stepsByTargetVersion: <int, IsarSchemaMigrationStep>{
      2: _registerMaintenanceWorkflowCollections,
      3: _reconcileV4WorkflowPersistence,
      4: _addOperationalAssuranceRequestFields,
      5: _addGovernedAssetIdentityFields,
      6: _addOperationalEventIssueLinkProjection,
      7: _addMaintenanceReopenEvidenceFields,
      8: _addSyncRejectionOriginatingUid,
      9: _addMaintenancePlantConditionEffect,
      10: _addMaintenancePlantConditionContributionIndex,
    },
  );

  static Future<void> _registerMaintenanceWorkflowCollections(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 1 || context.toVersion != 2) {
      throw IsarSchemaMigrationException(
        'Unexpected maintenance-workflow schema transition.',
        reasonCode: 'unexpected-v1-v2-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
  }

  static Future<void> _reconcileV4WorkflowPersistence(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 2 || context.toVersion != 3) {
      throw IsarSchemaMigrationException(
        'Unexpected v4 workflow-persistence transition.',
        reasonCode: 'unexpected-v2-v3-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar performs the additive migration when the reconciled schemas open.
    // Pre-open steps must remain idempotent because PREPARED recovery retries.
  }

  static Future<void> _addOperationalAssuranceRequestFields(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 3 || context.toVersion != 4) {
      throw IsarSchemaMigrationException(
        'Unexpected operational-assurance schema transition.',
        reasonCode: 'unexpected-v3-v4-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the fields during open. The idempotent post-open repair gives
    // legacy rows their explicit assurance purpose before provenance commits.
  }

  static Future<void> _addGovernedAssetIdentityFields(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 4 || context.toVersion != 5) {
      throw IsarSchemaMigrationException(
        'Unexpected governed-asset identity schema transition.',
        reasonCode: 'unexpected-v4-v5-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the nullable identity fields during open. The idempotent
    // post-open repair removes only custom projections that cannot be bound to
    // a physical asset without guessing, then resets their pull cursors.
  }

  static Future<void> _addOperationalEventIssueLinkProjection(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 5 || context.toVersion != 6) {
      throw IsarSchemaMigrationException(
        'Unexpected operational-event issue-link schema transition.',
        reasonCode: 'unexpected-v5-v6-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the list during open; legacy rows decode it as an empty list.
  }

  static Future<void> _addMaintenanceReopenEvidenceFields(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 6 || context.toVersion != 7) {
      throw IsarSchemaMigrationException(
        'Unexpected maintenance reopen-evidence schema transition.',
        reasonCode: 'unexpected-v6-v7-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the nullable evidence fields during open. Legacy tickets have
    // no reopening evidence; future reopen mutations populate the full set.
  }

  static Future<void> _addSyncRejectionOriginatingUid(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 7 || context.toVersion != 8) {
      throw IsarSchemaMigrationException(
        'Unexpected sync-rejection provenance schema transition.',
        reasonCode: 'unexpected-v7-v8-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the nullable provenance field during open. Existing rows stay
    // null and cannot be removed through user-owned recovery without proof.
  }

  static Future<void> _addMaintenancePlantConditionEffect(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 8 || context.toVersion != 9) {
      throw IsarSchemaMigrationException(
        'Unexpected maintenance Plant Condition schema transition.',
        reasonCode: 'unexpected-v8-v9-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the enum during open. Legacy rows decode to none; their old
    // server documents are not rewritten until an admitted ticket mutation.
  }

  static Future<void> _addMaintenancePlantConditionContributionIndex(
    IsarSchemaMigrationContext context,
  ) async {
    if (context.fromVersion != 9 || context.toVersion != 10) {
      throw IsarSchemaMigrationException(
        'Unexpected maintenance Plant Condition index transition.',
        reasonCode: 'unexpected-v9-v10-transition',
        storedVersion: context.fromVersion,
        targetVersion: context.toVersion,
        hasExistingLocalStore: context.hasExistingLocalStore,
        markerDisposition: 'migration-prepared',
      );
    }
    // Isar adds the property and index during open. The post-open v10 repair
    // reserializes existing tickets before provenance can be committed.
  }

  const IsarSchemaMigrator._();

  static Future<IsarSchemaOpenPreparation> prepareBeforeOpen({
    required IsarSchemaProvenanceStore store,
    required String databaseDirectoryPath,
    required bool hasExistingLocalStore,
    IsarSchemaMigrationPlan plan = defaultPlan,
    String Function()? databaseGenerationIdFactory,
  }) async {
    final canonicalJson = await store.readCanonicalMarkerJson();
    final legacy = await _readLegacyMarker(store);
    IsarSchemaProvenanceMarker? canonicalMarker;
    IsarSchemaMarkerFormatException? markerFormatError;

    if (canonicalJson != null) {
      try {
        canonicalMarker = IsarSchemaProvenanceMarker.decode(canonicalJson);
      } on IsarSchemaMarkerFormatException catch (error) {
        markerFormatError = error;
      }
    }

    if (!hasExistingLocalStore) {
      if (canonicalMarker != null &&
          canonicalMarker.state == IsarSchemaMarkerState.prepared &&
          canonicalMarker.origin.canResumeWithoutDurableStore &&
          _markerTargetsPlan(canonicalMarker, plan)) {
        return _resumePreparedMarker(
          store: store,
          marker: canonicalMarker,
          legacy: legacy,
          databaseDirectoryPath: databaseDirectoryPath,
          hasExistingLocalStore: false,
          plan: plan,
        );
      }

      return _prepareFreshStore(
        store: store,
        legacy: legacy,
        origin:
            canonicalJson == null && legacy.isAbsent
                ? IsarSchemaMarkerOrigin.freshInstall
                : IsarSchemaMarkerOrigin.storeReplacement,
        databaseDirectoryPath: databaseDirectoryPath,
        plan: plan,
        databaseGenerationIdFactory: databaseGenerationIdFactory,
      );
    }

    if (markerFormatError != null) {
      throw IsarSchemaMigrationException(
        'The existing Isar store has malformed canonical provenance and will not be opened.',
        reasonCode: markerFormatError.reasonCode,
        targetVersion: plan.currentVersion,
        hasExistingLocalStore: true,
        markerDisposition: 'canonical-malformed',
      );
    }

    if (canonicalMarker != null) {
      if (canonicalMarker.state == IsarSchemaMarkerState.prepared) {
        if (!_markerTargetsPlan(canonicalMarker, plan)) {
          throw IsarSchemaMigrationException(
            'The prepared Isar marker targets a different app schema.',
            reasonCode: 'prepared-marker-target-mismatch',
            storedVersion: canonicalMarker.schemaVersion,
            targetVersion: plan.currentVersion,
            hasExistingLocalStore: true,
            markerDisposition: 'canonical-prepared',
          );
        }
        return _resumePreparedMarker(
          store: store,
          marker: canonicalMarker,
          legacy: legacy,
          databaseDirectoryPath: databaseDirectoryPath,
          hasExistingLocalStore: true,
          plan: plan,
        );
      }
      return _prepareCommittedMarker(
        store: store,
        marker: canonicalMarker,
        legacy: legacy,
        databaseDirectoryPath: databaseDirectoryPath,
        plan: plan,
      );
    }

    if (legacy.isPartial) {
      throw IsarSchemaMigrationException(
        'The existing Isar store has only part of its legacy schema marker.',
        reasonCode: 'legacy-marker-incomplete',
        storedVersion: legacy.schemaVersion,
        targetVersion: plan.currentVersion,
        hasExistingLocalStore: true,
        markerDisposition: 'legacy-partial',
      );
    }
    if (legacy.isAbsent) {
      throw IsarSchemaMigrationException(
        'The existing Isar store has no schema provenance marker and will not be stamped or opened automatically.',
        reasonCode: 'existing-store-unmarked',
        targetVersion: plan.currentVersion,
        hasExistingLocalStore: true,
        markerDisposition: 'absent',
      );
    }

    return _prepareLegacyMarker(
      store: store,
      legacy: legacy,
      databaseDirectoryPath: databaseDirectoryPath,
      plan: plan,
      databaseGenerationIdFactory: databaseGenerationIdFactory,
    );
  }

  static Future<IsarSchemaProvenanceMarker?> readCommittedMarker(
    IsarSchemaProvenanceStore store,
  ) async {
    final encoded = await store.readCanonicalMarkerJson();
    if (encoded == null) return null;
    final marker = IsarSchemaProvenanceMarker.decode(encoded);
    return marker.state == IsarSchemaMarkerState.committed ? marker : null;
  }

  static Future<IsarSchemaOpenPreparation> _prepareFreshStore({
    required IsarSchemaProvenanceStore store,
    required LegacyIsarSchemaMarker legacy,
    required IsarSchemaMarkerOrigin origin,
    required String databaseDirectoryPath,
    required IsarSchemaMigrationPlan plan,
    required String Function()? databaseGenerationIdFactory,
  }) async {
    final generationId = _newDatabaseGenerationId(
      databaseGenerationIdFactory,
      plan.currentVersion,
    );
    final marker = IsarSchemaProvenanceMarker(
      state: IsarSchemaMarkerState.prepared,
      schemaVersion: plan.currentVersion,
      schemaFingerprint: plan.schemaFingerprint,
      databaseGenerationId: generationId,
      origin: origin,
      sourceSchemaVersion: null,
      sourceSchemaFingerprint: null,
    );
    await _persistCanonicalMarker(
      store: store,
      marker: marker,
      targetVersion: plan.currentVersion,
    );
    return IsarSchemaOpenPreparation._(
      store: store,
      clearLegacyMarkerAfterOpen: !legacy.isAbsent,
      marker: marker,
      result: IsarSchemaMigrationResult(
        outcome:
            origin == IsarSchemaMarkerOrigin.freshInstall
                ? IsarSchemaMigrationOutcome.freshInstallInitialized
                : IsarSchemaMigrationOutcome.storeReplacementInitialized,
        fromVersion: 0,
        toVersion: plan.currentVersion,
        hadExistingLocalStore: false,
        marker: marker,
      ),
    );
  }

  static Future<IsarSchemaOpenPreparation> _prepareLegacyMarker({
    required IsarSchemaProvenanceStore store,
    required LegacyIsarSchemaMarker legacy,
    required String databaseDirectoryPath,
    required IsarSchemaMigrationPlan plan,
    required String Function()? databaseGenerationIdFactory,
  }) async {
    final version = legacy.schemaVersion!;
    final fingerprint = legacy.schemaFingerprint!;
    _validateStoredSchema(
      version: version,
      fingerprint: fingerprint,
      plan: plan,
      markerDisposition: 'legacy-complete',
    );

    final generationId = _newDatabaseGenerationId(
      databaseGenerationIdFactory,
      plan.currentVersion,
    );
    final marker = IsarSchemaProvenanceMarker(
      state: IsarSchemaMarkerState.prepared,
      schemaVersion: plan.currentVersion,
      schemaFingerprint: plan.schemaFingerprint,
      databaseGenerationId: generationId,
      origin: IsarSchemaMarkerOrigin.legacyCompleteMarker,
      sourceSchemaVersion: version,
      sourceSchemaFingerprint: fingerprint,
    );
    await _persistCanonicalMarker(
      store: store,
      marker: marker,
      targetVersion: plan.currentVersion,
    );
    await _runMigrationSteps(
      fromVersion: version,
      marker: marker,
      databaseDirectoryPath: databaseDirectoryPath,
      hasExistingLocalStore: true,
      plan: plan,
    );
    return IsarSchemaOpenPreparation._(
      store: store,
      clearLegacyMarkerAfterOpen: true,
      marker: marker,
      result: IsarSchemaMigrationResult(
        outcome: IsarSchemaMigrationOutcome.legacyMarkerMigrated,
        fromVersion: version,
        toVersion: plan.currentVersion,
        hadExistingLocalStore: true,
        marker: marker,
      ),
    );
  }

  static Future<IsarSchemaOpenPreparation> _prepareCommittedMarker({
    required IsarSchemaProvenanceStore store,
    required IsarSchemaProvenanceMarker marker,
    required LegacyIsarSchemaMarker legacy,
    required String databaseDirectoryPath,
    required IsarSchemaMigrationPlan plan,
  }) async {
    _validateStoredSchema(
      version: marker.schemaVersion,
      fingerprint: marker.schemaFingerprint,
      plan: plan,
      markerDisposition: 'canonical-committed',
    );
    _validateMarkerSource(
      marker: marker,
      plan: plan,
      markerDisposition: 'canonical-committed-source',
    );

    if (marker.schemaVersion == plan.currentVersion) {
      return IsarSchemaOpenPreparation._(
        store: store,
        clearLegacyMarkerAfterOpen: !legacy.isAbsent,
        marker: marker,
        result: IsarSchemaMigrationResult(
          outcome: IsarSchemaMigrationOutcome.alreadyCurrent,
          fromVersion: marker.schemaVersion,
          toVersion: plan.currentVersion,
          hadExistingLocalStore: true,
          marker: marker,
        ),
      );
    }

    final prepared = IsarSchemaProvenanceMarker(
      state: IsarSchemaMarkerState.prepared,
      schemaVersion: plan.currentVersion,
      schemaFingerprint: plan.schemaFingerprint,
      databaseGenerationId: marker.databaseGenerationId,
      origin: IsarSchemaMarkerOrigin.schemaMigration,
      sourceSchemaVersion: marker.schemaVersion,
      sourceSchemaFingerprint: marker.schemaFingerprint,
    );
    await _persistCanonicalMarker(
      store: store,
      marker: prepared,
      targetVersion: plan.currentVersion,
    );
    await _runMigrationSteps(
      fromVersion: marker.schemaVersion,
      marker: prepared,
      databaseDirectoryPath: databaseDirectoryPath,
      hasExistingLocalStore: true,
      plan: plan,
    );
    return IsarSchemaOpenPreparation._(
      store: store,
      clearLegacyMarkerAfterOpen: !legacy.isAbsent,
      marker: prepared,
      result: IsarSchemaMigrationResult(
        outcome: IsarSchemaMigrationOutcome.migrated,
        fromVersion: marker.schemaVersion,
        toVersion: plan.currentVersion,
        hadExistingLocalStore: true,
        marker: prepared,
      ),
    );
  }

  static Future<IsarSchemaOpenPreparation> _resumePreparedMarker({
    required IsarSchemaProvenanceStore store,
    required IsarSchemaProvenanceMarker marker,
    required LegacyIsarSchemaMarker legacy,
    required String databaseDirectoryPath,
    required bool hasExistingLocalStore,
    required IsarSchemaMigrationPlan plan,
  }) async {
    if (marker.origin.requiresSource) {
      _validateStoredSchema(
        version: marker.sourceSchemaVersion!,
        fingerprint: marker.sourceSchemaFingerprint!,
        plan: plan,
        markerDisposition: 'canonical-prepared-source',
      );
      await _runMigrationSteps(
        fromVersion: marker.sourceSchemaVersion!,
        marker: marker,
        databaseDirectoryPath: databaseDirectoryPath,
        hasExistingLocalStore: hasExistingLocalStore,
        plan: plan,
      );
    }
    return IsarSchemaOpenPreparation._(
      store: store,
      clearLegacyMarkerAfterOpen: !legacy.isAbsent,
      marker: marker,
      result: IsarSchemaMigrationResult(
        outcome: IsarSchemaMigrationOutcome.preparedOpenResumed,
        fromVersion: marker.sourceSchemaVersion ?? 0,
        toVersion: marker.schemaVersion,
        hadExistingLocalStore: hasExistingLocalStore,
        marker: marker,
      ),
    );
  }

  static Future<void> _runMigrationSteps({
    required int fromVersion,
    required IsarSchemaProvenanceMarker marker,
    required String databaseDirectoryPath,
    required bool hasExistingLocalStore,
    required IsarSchemaMigrationPlan plan,
  }) async {
    var version = fromVersion;
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
          databaseGenerationId: marker.databaseGenerationId,
        ),
      );
      version = target;
    }
  }

  static void _validateStoredSchema({
    required int version,
    required String fingerprint,
    required IsarSchemaMigrationPlan plan,
    required String markerDisposition,
  }) {
    if (version > plan.currentVersion) {
      throw IsarSchemaMigrationException(
        'The local Isar schema marker is newer than this app build.',
        reasonCode: 'stored-schema-newer-than-app',
        storedVersion: version,
        targetVersion: plan.currentVersion,
        hasExistingLocalStore: true,
        markerDisposition: markerDisposition,
      );
    }
    if (!plan.acceptsFingerprint(version, fingerprint)) {
      throw IsarSchemaMigrationException(
        'The local Isar schema fingerprint is not repository-proven for its version.',
        reasonCode: 'stored-schema-fingerprint-unrecognized',
        storedVersion: version,
        targetVersion: plan.currentVersion,
        hasExistingLocalStore: true,
        markerDisposition: markerDisposition,
      );
    }
  }

  static bool _markerTargetsPlan(
    IsarSchemaProvenanceMarker marker,
    IsarSchemaMigrationPlan plan,
  ) {
    return marker.schemaVersion == plan.currentVersion &&
        marker.schemaFingerprint == plan.schemaFingerprint;
  }

  static void _validateMarkerSource({
    required IsarSchemaProvenanceMarker marker,
    required IsarSchemaMigrationPlan plan,
    required String markerDisposition,
  }) {
    if (!marker.origin.requiresSource) return;
    _validateStoredSchema(
      version: marker.sourceSchemaVersion!,
      fingerprint: marker.sourceSchemaFingerprint!,
      plan: plan,
      markerDisposition: markerDisposition,
    );
  }

  static String _newDatabaseGenerationId(
    String Function()? factory,
    int targetVersion,
  ) {
    final value = (factory ?? const Uuid().v4).call().trim();
    if (!RegExp(
      _databaseGenerationPattern,
      caseSensitive: false,
    ).hasMatch(value)) {
      throw IsarSchemaMigrationException(
        'The generated Isar database generation identity is invalid.',
        reasonCode: 'database-generation-invalid',
        targetVersion: targetVersion,
        markerDisposition: 'generation-rejected',
      );
    }
    return value.toLowerCase();
  }
}

Future<LegacyIsarSchemaMarker> _readLegacyMarker(
  IsarSchemaProvenanceStore store,
) async {
  return LegacyIsarSchemaMarker(
    schemaVersion: await store.readLegacySchemaVersion(),
    schemaFingerprint: await store.readLegacySchemaFingerprint(),
  );
}

Future<void> _persistCanonicalMarker({
  required IsarSchemaProvenanceStore store,
  required IsarSchemaProvenanceMarker marker,
  required int targetVersion,
}) async {
  final encoded = marker.encode();
  final written = await store.writeCanonicalMarkerJson(encoded);
  final readBack = await store.readCanonicalMarkerJson();
  if (!written || readBack != encoded) {
    throw IsarSchemaMigrationException(
      'The canonical Isar provenance marker could not be persisted exactly.',
      reasonCode: 'canonical-marker-write-failed',
      storedVersion: marker.sourceSchemaVersion,
      targetVersion: targetVersion,
      markerDisposition: marker.state.wireName.toLowerCase(),
    );
  }
}
