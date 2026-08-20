// FILE: lib/features/planned_maintenance/data/template_governance_model.dart

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:isar/isar.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import 'maintenance_intelligence.dart';

part 'template_governance_model.g.dart';
part 'remote_template_governance_reader.dart';

// ─────────────────────────────────────────────────────────────
// TEMPLATE GOVERNANCE MODEL
// ─────────────────────────────────────────────────────────────
// This governance layer deliberately sits ABOVE the existing JobTemplate /
// JobExecution runtime layer. Runtime jobs keep their own frozen snapshots;
// published TemplateVersion records are immutable source records for future
// assignment only.

String? _cleanOptionalText(dynamic value) {
  if (value == null || value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _cleanRequiredText(dynamic value, String fallback) {
  final cleaned = _cleanOptionalText(value);
  return cleaned ?? fallback;
}

Map<String, dynamic>? _maintenanceClassificationFromMetadata(
  String? metadataJson,
) {
  final cleaned = _cleanOptionalText(metadataJson);
  if (cleaned == null) return null;
  final decoded = jsonDecode(cleaned);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('TemplateVersion metadata must be an object.');
  }
  final raw = decoded['maintenanceClassification'];
  if (raw == null) return null;
  if (raw is! Map) {
    throw const FormatException(
      'TemplateVersion maintenance classification must be an object.',
    );
  }
  return FrozenMaintenanceClass.fromMap(
    Map<String, dynamic>.from(raw),
    source: 'TemplateVersion.metadataJson/maintenanceClassification',
  ).toMap();
}

bool _moduleRequiresClosure(
  Map<String, dynamic> module, {
  required String source,
}) {
  const keys = <String>[
    'requiredForClosure',
    'requiredForCloseout',
    'required',
    'isRequired',
  ];
  for (final key in keys) {
    final parsed = readOptionalPersistedBool(
      module[key],
      field: key,
      source: source,
    );
    if (parsed != null) return parsed;
  }
  return false;
}

class _TemplateClosureReviewState {
  const _TemplateClosureReviewState({
    required this.confirmed,
    required this.criticalModuleCount,
    this.confirmedByUid,
    this.confirmedByName,
    this.confirmedAt,
  });

  final bool confirmed;
  final int criticalModuleCount;
  final String? confirmedByUid;
  final String? confirmedByName;
  final DateTime? confirmedAt;
}

_TemplateClosureReviewState _deriveClosureReviewState({
  required String jobTemplateSnapshotJson,
  required String moduleSnapshotsJson,
  String source = 'template closure-review snapshot',
}) {
  final jobSnapshot = readRequiredJsonObject(
    jobTemplateSnapshotJson,
    field: 'jobTemplateSnapshotJson',
    source: source,
  );
  final composer =
      readOptionalJsonObject(
        jobSnapshot['composer'],
        field: 'composer',
        source: source,
      ) ??
      const <String, dynamic>{};
  final modules = readRequiredJsonObjectList(
    moduleSnapshotsJson,
    field: 'moduleSnapshotsJson',
    source: source,
  );
  final actualCriticalCount =
      modules
          .where((module) => _moduleRequiresClosure(module, source: source))
          .length;
  final declaredCriticalCount =
      readOptionalPersistedInt(
        jobSnapshot['closureCriticalCount'],
        field: 'closureCriticalCount',
        source: source,
        minimum: 0,
      ) ??
      0;
  final criticalCount =
      actualCriticalCount > declaredCriticalCount
          ? actualCriticalCount
          : declaredCriticalCount;

  return _TemplateClosureReviewState(
    confirmed:
        readOptionalPersistedBool(
          composer['closureReviewConfirmed'],
          field: 'closureReviewConfirmed',
          source: source,
        ) ??
        false,
    criticalModuleCount: criticalCount,
    confirmedByUid: _cleanOptionalText(composer['closureReviewConfirmedByUid']),
    confirmedByName: _cleanOptionalText(
      composer['closureReviewConfirmedByName'],
    ),
    confirmedAt: readOptionalPersistedDateTime(
      composer['closureReviewConfirmedAt'],
      field: 'closureReviewConfirmedAt',
      source: source,
    ),
  );
}

/// Stable governance content fingerprint for immutable-version guards.
///
/// Existing records may still carry the legacy `tg1-fnv1a32:<8 hex>` trace
/// hash. New hashes use SHA-256 while preserving the same `contentHash` string
/// field, so no Isar or Firestore schema change is required for this upgrade.
String stableTemplateContentHash(String payload) {
  final digest = sha256.convert(utf8.encode(payload)).toString();
  return 'tg2-sha256:$digest';
}

enum TemplatePackageLifecycleStatus { active, retired, archived }

enum TemplateVersionStatus { draft, published, retired, archived }

enum TemplatePublishAuditAction {
  created,
  edited,
  published,
  retired,
  restored,
  archived,
}

// ─────────────────────────────────────────────────────────────
// TEMPLATE PACKAGE
// ─────────────────────────────────────────────────────────────

@Collection()
class TemplatePackage {
  TemplatePackage();

  Id id = Isar.autoIncrement;

  @Index()
  String? firestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;
  int schemaVersion = 1;

  @Index(caseSensitive: false)
  late String packageCode;

  @Index(caseSensitive: false)
  late String title;

  String? description;

  String? assetType;
  String? assetNumberScope;
  String? disciplineScope;

  @Enumerated(EnumType.name)
  @Index()
  TemplatePackageLifecycleStatus lifecycleStatus =
      TemplatePackageLifecycleStatus.active;

  @Index()
  String? activeVersionFirestoreId;

  int latestVersionNumber = 0;

  String? createdByUid;
  String? createdByName;
  String? updatedByUid;
  String? updatedByName;

  String? retiredByUid;
  String? retiredByName;
  DateTime? retiredAt;
  String? retireReason;

  bool isDeleted = false;
  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  // Reserved extension points. They are intentionally strings/lists instead of
  // strongly linked objects so this foundation can absorb DeviceTagMaster,
  // procedure libraries, and safety gates later without another migration.
  List<String> targetRefs = [];
  List<String> deviceTagRefs = [];
  String? safetyClass;
  String? safetyGatePolicyJson;
  List<String> procedureRefs = [];
  List<String> operationalStatePreconditions = [];
  String? metadataJson;

  bool get isRetired =>
      lifecycleStatus == TemplatePackageLifecycleStatus.retired;
  bool get isArchived =>
      lifecycleStatus == TemplatePackageLifecycleStatus.archived;
  bool get isAssignable =>
      !isDeleted &&
      lifecycleStatus == TemplatePackageLifecycleStatus.active &&
      _cleanOptionalText(activeVersionFirestoreId) != null;

  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'packageCode': packageCode,
    'title': title,
    'lifecycleStatus': lifecycleStatus.name,
    'activeVersionFirestoreId': activeVersionFirestoreId,
    'latestVersionNumber': latestVersionNumber,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
  };

  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'packageCode': packageCode.trim(),
    'title': title.trim(),
    'description': _cleanOptionalText(description),
    'assetType': _cleanOptionalText(assetType),
    'assetNumberScope': _cleanOptionalText(assetNumberScope),
    'disciplineScope': _cleanOptionalText(disciplineScope),
    'lifecycleStatus': lifecycleStatus.name,
    'activeVersionFirestoreId': _cleanOptionalText(activeVersionFirestoreId),
    'latestVersionNumber': latestVersionNumber,
    'createdByUid': _cleanOptionalText(createdByUid),
    'createdByName': _cleanOptionalText(createdByName),
    'updatedByUid': _cleanOptionalText(updatedByUid),
    'updatedByName': _cleanOptionalText(updatedByName),
    'retiredByUid': _cleanOptionalText(retiredByUid),
    'retiredByName': _cleanOptionalText(retiredByName),
    'retiredAt': retiredAt?.toIso8601String(),
    'retireReason': _cleanOptionalText(retireReason),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'deletedByUid': _cleanOptionalText(deletedByUid),
    'deletedByName': _cleanOptionalText(deletedByName),
    'deleteReason': _cleanOptionalText(deleteReason),
    'version': version,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'targetRefs': targetRefs,
    'deviceTagRefs': deviceTagRefs,
    'safetyClass': _cleanOptionalText(safetyClass),
    'safetyGatePolicyJson': _cleanOptionalText(safetyGatePolicyJson),
    'procedureRefs': procedureRefs,
    'operationalStatePreconditions': operationalStatePreconditions,
    'metadataJson': _cleanOptionalText(metadataJson),
  };

  factory TemplatePackage.fromMap(Map<String, dynamic> map, String documentId) {
    return readRemoteTemplatePackage(map, documentId: documentId);
  }
}

// ─────────────────────────────────────────────────────────────
// TEMPLATE VERSION
// ─────────────────────────────────────────────────────────────

@Collection()
class TemplateVersion {
  TemplateVersion();

  Id id = Isar.autoIncrement;

  @Index()
  String? firestoreId;

  @Index()
  String? packageFirestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;
  int schemaVersion = 1;

  @Index()
  int versionNumber = 1;

  String? versionLabel;

  @Enumerated(EnumType.name)
  @Index()
  TemplateVersionStatus status = TemplateVersionStatus.draft;

  String? sourceVersionFirestoreId;
  String? contentHash;

  // Frozen published payloads. These are editable only while status=draft.
  String jobTemplateSnapshotJson = '{}';
  String moduleSnapshotsJson = '[]';
  String fieldDefinitionsJson = '[]';
  String checklistJson = '[]';

  String? releaseNotes;
  String? changeSummary;

  // First-class governance closure-review state derived from the frozen
  // Composer/Publisher payloads. Existing JSON snapshots remain the source
  // payload, but these fields make the publish invariant auditable without
  // reparsing nested JSON everywhere.
  bool closureReviewConfirmed = false;
  int closureCriticalModuleCount = 0;
  String? closureReviewConfirmedByUid;
  String? closureReviewConfirmedByName;
  DateTime? closureReviewConfirmedAt;

  String? createdByUid;
  String? createdByName;
  String? updatedByUid;
  String? updatedByName;
  String? publishedByUid;
  String? publishedByName;
  DateTime? publishedAt;
  String? retiredByUid;
  String? retiredByName;
  DateTime? retiredAt;
  String? retireReason;

  String? minAppVersion;

  bool isDeleted = false;
  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  List<String> targetRefs = [];
  List<String> deviceTagRefs = [];
  String? safetyClass;
  String? safetyGatePolicyJson;
  List<String> procedureRefs = [];
  List<String> operationalStatePreconditions = [];
  String? metadataJson;

  bool get isDraft => status == TemplateVersionStatus.draft;
  bool get isPublished => status == TemplateVersionStatus.published;
  bool get isRetired => status == TemplateVersionStatus.retired;
  bool get isArchived => status == TemplateVersionStatus.archived;
  bool get isArchivedDraft =>
      isArchived &&
      !isDeleted &&
      publishedAt == null &&
      publishedByUid == null &&
      publishedByName == null &&
      retiredAt == null &&
      retiredByUid == null &&
      retiredByName == null &&
      retireReason == null;
  bool get isAssignable => !isDeleted && isPublished;

  void refreshClosureReviewStateFromSnapshots() {
    final state = _deriveClosureReviewState(
      jobTemplateSnapshotJson: jobTemplateSnapshotJson,
      moduleSnapshotsJson: moduleSnapshotsJson,
    );
    closureReviewConfirmed = state.confirmed;
    closureCriticalModuleCount = state.criticalModuleCount;
    closureReviewConfirmedByUid = state.confirmedByUid;
    closureReviewConfirmedByName = state.confirmedByName;
    closureReviewConfirmedAt = state.confirmedAt;
  }

  String buildCanonicalContentPayload() {
    final closureState = _deriveClosureReviewState(
      jobTemplateSnapshotJson: jobTemplateSnapshotJson,
      moduleSnapshotsJson: moduleSnapshotsJson,
    );
    final maintenanceClassification = _maintenanceClassificationFromMetadata(
      metadataJson,
    );
    return jsonEncode({
      'jobTemplateSnapshotJson': jobTemplateSnapshotJson,
      'moduleSnapshotsJson': moduleSnapshotsJson,
      'fieldDefinitionsJson': fieldDefinitionsJson,
      'checklistJson': checklistJson,
      'closureReviewConfirmed': closureState.confirmed,
      'closureCriticalModuleCount': closureState.criticalModuleCount,
      'closureReviewConfirmedByUid': _cleanOptionalText(
        closureState.confirmedByUid,
      ),
      'closureReviewConfirmedByName': _cleanOptionalText(
        closureState.confirmedByName,
      ),
      'closureReviewConfirmedAt': closureState.confirmedAt?.toIso8601String(),
      'targetRefs': targetRefs,
      'deviceTagRefs': deviceTagRefs,
      'safetyClass': _cleanOptionalText(safetyClass),
      'safetyGatePolicyJson': _cleanOptionalText(safetyGatePolicyJson),
      'procedureRefs': procedureRefs,
      'operationalStatePreconditions': operationalStatePreconditions,
      'schemaVersion': schemaVersion,
      if (maintenanceClassification != null)
        'maintenanceClassification': maintenanceClassification,
    });
  }

  String computeContentHash() =>
      stableTemplateContentHash(buildCanonicalContentPayload());

  void refreshContentHash() {
    refreshClosureReviewStateFromSnapshots();
    contentHash = computeContentHash();
  }

  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'packageFirestoreId': packageFirestoreId,
    'versionNumber': versionNumber,
    'status': status.name,
    'contentHash': contentHash,
    'closureReviewConfirmed': closureReviewConfirmed,
    'closureCriticalModuleCount': closureCriticalModuleCount,
    'closureReviewConfirmedByUid': _cleanOptionalText(
      closureReviewConfirmedByUid,
    ),
    'closureReviewConfirmedByName': _cleanOptionalText(
      closureReviewConfirmedByName,
    ),
    'closureReviewConfirmedAt': closureReviewConfirmedAt?.toIso8601String(),
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
  };

  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'packageFirestoreId': _cleanOptionalText(packageFirestoreId),
    'versionNumber': versionNumber,
    'versionLabel': _cleanOptionalText(versionLabel),
    'status': status.name,
    'sourceVersionFirestoreId': _cleanOptionalText(sourceVersionFirestoreId),
    'contentHash': _cleanOptionalText(contentHash),
    'jobTemplateSnapshotJson': _cleanRequiredText(
      jobTemplateSnapshotJson,
      '{}',
    ),
    'moduleSnapshotsJson': _cleanRequiredText(moduleSnapshotsJson, '[]'),
    'fieldDefinitionsJson': _cleanRequiredText(fieldDefinitionsJson, '[]'),
    'checklistJson': _cleanRequiredText(checklistJson, '[]'),
    'releaseNotes': _cleanOptionalText(releaseNotes),
    'changeSummary': _cleanOptionalText(changeSummary),
    'closureReviewConfirmed': closureReviewConfirmed,
    'closureCriticalModuleCount': closureCriticalModuleCount,
    'closureReviewConfirmedByUid': _cleanOptionalText(
      closureReviewConfirmedByUid,
    ),
    'closureReviewConfirmedByName': _cleanOptionalText(
      closureReviewConfirmedByName,
    ),
    'closureReviewConfirmedAt': closureReviewConfirmedAt?.toIso8601String(),
    'createdByUid': _cleanOptionalText(createdByUid),
    'createdByName': _cleanOptionalText(createdByName),
    'updatedByUid': _cleanOptionalText(updatedByUid),
    'updatedByName': _cleanOptionalText(updatedByName),
    'publishedByUid': _cleanOptionalText(publishedByUid),
    'publishedByName': _cleanOptionalText(publishedByName),
    'publishedAt': publishedAt?.toIso8601String(),
    'retiredByUid': _cleanOptionalText(retiredByUid),
    'retiredByName': _cleanOptionalText(retiredByName),
    'retiredAt': retiredAt?.toIso8601String(),
    'retireReason': _cleanOptionalText(retireReason),
    'minAppVersion': _cleanOptionalText(minAppVersion),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'deletedByUid': _cleanOptionalText(deletedByUid),
    'deletedByName': _cleanOptionalText(deletedByName),
    'deleteReason': _cleanOptionalText(deleteReason),
    'version': version,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'targetRefs': targetRefs,
    'deviceTagRefs': deviceTagRefs,
    'safetyClass': _cleanOptionalText(safetyClass),
    'safetyGatePolicyJson': _cleanOptionalText(safetyGatePolicyJson),
    'procedureRefs': procedureRefs,
    'operationalStatePreconditions': operationalStatePreconditions,
    'metadataJson': _cleanOptionalText(metadataJson),
  };

  factory TemplateVersion.fromMap(Map<String, dynamic> map, String documentId) {
    return readRemoteTemplateVersion(map, documentId: documentId);
  }
}

// ─────────────────────────────────────────────────────────────
// TEMPLATE PUBLISH AUDIT
// ─────────────────────────────────────────────────────────────

@Collection()
class TemplatePublishAudit {
  TemplatePublishAudit();

  Id id = Isar.autoIncrement;

  @Index()
  String? firestoreId;

  @Index()
  String? packageFirestoreId;

  @Index()
  String? versionFirestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;
  int schemaVersion = 1;
  bool isDeleted = false;

  @Enumerated(EnumType.name)
  @Index()
  TemplatePublishAuditAction action = TemplatePublishAuditAction.edited;

  String? performedByUid;
  String? performedByName;

  @Index()
  late DateTime performedAt;

  @Index()
  late DateTime updatedAt;

  String? reason;
  String? beforeHash;
  String? afterHash;
  String? payloadSnapshotJson;
  String? metadataJson;

  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'packageFirestoreId': packageFirestoreId,
    'versionFirestoreId': versionFirestoreId,
    'action': action.name,
    'performedByUid': performedByUid,
    'performedAt': performedAt.toIso8601String(),
    'beforeHash': beforeHash,
    'afterHash': afterHash,
  };

  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'packageFirestoreId': _cleanOptionalText(packageFirestoreId),
    'versionFirestoreId': _cleanOptionalText(versionFirestoreId),
    'action': action.name,
    'performedByUid': _cleanOptionalText(performedByUid),
    'performedByName': _cleanOptionalText(performedByName),
    'performedAt': performedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reason': _cleanOptionalText(reason),
    'beforeHash': _cleanOptionalText(beforeHash),
    'afterHash': _cleanOptionalText(afterHash),
    'payloadSnapshotJson': _cleanOptionalText(payloadSnapshotJson),
    'metadataJson': _cleanOptionalText(metadataJson),
    'version': version,
    'schemaVersion': schemaVersion,
    'isDeleted': isDeleted,
  };

  factory TemplatePublishAudit.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return readRemoteTemplatePublishAudit(map, documentId: documentId);
  }
}
