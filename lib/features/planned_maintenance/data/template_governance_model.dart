// FILE: lib/features/planned_maintenance/data/template_governance_model.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crypto/crypto.dart' show sha256;
import 'package:isar/isar.dart';

import '../../../core/services/remote_tombstone_apply_result.dart';

part 'template_governance_model.g.dart';

// ─────────────────────────────────────────────────────────────
// TEMPLATE GOVERNANCE MODEL
// ─────────────────────────────────────────────────────────────
// This governance layer deliberately sits ABOVE the existing JobTemplate /
// JobExecution runtime layer. Runtime jobs keep their own frozen snapshots;
// published TemplateVersion records are immutable source records for future
// assignment only.

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);

  try {
    final dynamic maybeTimestamp = value;
    final converted = maybeTimestamp.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // Fall through to null.
  }

  return null;
}

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
  if (value is! String) return fallback;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

String? _cleanOptionalText(dynamic value) {
  if (value == null || value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _cleanRequiredText(dynamic value, String fallback) {
  final cleaned = _cleanOptionalText(value);
  return cleaned ?? fallback;
}

List<String> _cleanStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool? _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

Map<String, dynamic> _decodeJsonObjectSafely(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Invalid draft JSON is handled by the Publisher UI. Governance metadata
    // derivation must remain defensive for legacy/offline records.
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _decodeJsonObjectListSafely(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  } catch (_) {
    // Invalid draft JSON is handled by the Publisher UI. Governance metadata
    // derivation must remain defensive for legacy/offline records.
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _mapFrom(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

bool _moduleRequiresClosure(Map<String, dynamic> module) {
  const keys = <String>[
    'requiredForClosure',
    'requiredForCloseout',
    'required',
    'isRequired',
  ];
  for (final key in keys) {
    final parsed = _parseBool(module[key]);
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
}) {
  final jobSnapshot = _decodeJsonObjectSafely(jobTemplateSnapshotJson);
  final composer = _mapFrom(jobSnapshot['composer']);
  final modules = _decodeJsonObjectListSafely(moduleSnapshotsJson);
  final actualCriticalCount = modules.where(_moduleRequiresClosure).length;
  final declaredCriticalCount =
      _parseInt(jobSnapshot['closureCriticalCount']) ?? 0;
  final criticalCount =
      actualCriticalCount > declaredCriticalCount
          ? actualCriticalCount
          : declaredCriticalCount;

  return _TemplateClosureReviewState(
    confirmed: _parseBool(composer['closureReviewConfirmed']) ?? false,
    criticalModuleCount: criticalCount,
    confirmedByUid: _cleanOptionalText(composer['closureReviewConfirmedByUid']),
    confirmedByName: _cleanOptionalText(
      composer['closureReviewConfirmedByName'],
    ),
    confirmedAt: _parseTimestamp(composer['closureReviewConfirmedAt']),
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
    final templatePackage = TemplatePackage()
      ..firestoreId = documentId
      ..packageCode = _cleanRequiredText(map['packageCode'], '')
      ..title = _cleanRequiredText(map['title'], '')
      ..description = _cleanOptionalText(map['description'])
      ..assetType = _cleanOptionalText(map['assetType'])
      ..assetNumberScope = _cleanOptionalText(map['assetNumberScope'])
      ..disciplineScope = _cleanOptionalText(map['disciplineScope'])
      ..lifecycleStatus = _enumByNameOr(
        TemplatePackageLifecycleStatus.values,
        map['lifecycleStatus'],
        TemplatePackageLifecycleStatus.active,
      )
      ..activeVersionFirestoreId = _cleanOptionalText(
        map['activeVersionFirestoreId'],
      )
      ..latestVersionNumber =
          map['latestVersionNumber'] is int
              ? map['latestVersionNumber'] as int
              : 0
      ..createdByUid = _cleanOptionalText(map['createdByUid'])
      ..createdByName = _cleanOptionalText(map['createdByName'])
      ..updatedByUid = _cleanOptionalText(map['updatedByUid'])
      ..updatedByName = _cleanOptionalText(map['updatedByName'])
      ..retiredByUid = _cleanOptionalText(map['retiredByUid'])
      ..retiredByName = _cleanOptionalText(map['retiredByName'])
      ..retiredAt = _parseTimestamp(map['retiredAt'])
      ..retireReason = _cleanOptionalText(map['retireReason'])
      ..isDeleted = map['isDeleted'] == true
      ..deletedAt = _parseTimestamp(map['deletedAt'])
      ..deletedByUid = _cleanOptionalText(map['deletedByUid'])
      ..deletedByName = _cleanOptionalText(map['deletedByName'])
      ..deleteReason = _cleanOptionalText(map['deleteReason'])
      ..version = map['version'] is int ? map['version'] as int : 1
      ..schemaVersion =
          map['schemaVersion'] is int ? map['schemaVersion'] as int : 1
      ..createdAt = _parseTimestamp(map['createdAt']) ?? DateTime.now()
      ..updatedAt =
          _parseTimestamp(map['updatedAt']) ??
          _parseTimestamp(map['createdAt']) ??
          DateTime.now()
      ..targetRefs = _cleanStringList(map['targetRefs'])
      ..deviceTagRefs = _cleanStringList(map['deviceTagRefs'])
      ..safetyClass = _cleanOptionalText(map['safetyClass'])
      ..safetyGatePolicyJson = _cleanOptionalText(map['safetyGatePolicyJson'])
      ..procedureRefs = _cleanStringList(map['procedureRefs'])
      ..operationalStatePreconditions = _cleanStringList(
        map['operationalStatePreconditions'],
      )
      ..metadataJson = _cleanOptionalText(map['metadataJson'])
      ..isSynced = true;

    if (templatePackage.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        templatePackage.deletedAt,
        entityLabel: 'template package',
        firestoreId: templatePackage.firestoreId,
      );
    }

    return templatePackage;
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
    final jobTemplateSnapshotJson = _cleanRequiredText(
      map['jobTemplateSnapshotJson'],
      '{}',
    );
    final moduleSnapshotsJson = _cleanRequiredText(
      map['moduleSnapshotsJson'],
      '[]',
    );
    final inferredClosureState = _deriveClosureReviewState(
      jobTemplateSnapshotJson: jobTemplateSnapshotJson,
      moduleSnapshotsJson: moduleSnapshotsJson,
    );

    final templateVersion = TemplateVersion()
      ..firestoreId = documentId
      ..packageFirestoreId = _cleanOptionalText(map['packageFirestoreId'])
      ..versionNumber =
          map['versionNumber'] is int ? map['versionNumber'] as int : 1
      ..versionLabel = _cleanOptionalText(map['versionLabel'])
      ..status = _enumByNameOr(
        TemplateVersionStatus.values,
        map['status'],
        TemplateVersionStatus.draft,
      )
      ..sourceVersionFirestoreId = _cleanOptionalText(
        map['sourceVersionFirestoreId'],
      )
      ..contentHash = _cleanOptionalText(map['contentHash'])
      ..jobTemplateSnapshotJson = jobTemplateSnapshotJson
      ..moduleSnapshotsJson = moduleSnapshotsJson
      ..fieldDefinitionsJson = _cleanRequiredText(
        map['fieldDefinitionsJson'],
        '[]',
      )
      ..checklistJson = _cleanRequiredText(map['checklistJson'], '[]')
      ..releaseNotes = _cleanOptionalText(map['releaseNotes'])
      ..changeSummary = _cleanOptionalText(map['changeSummary'])
      ..closureReviewConfirmed =
          _parseBool(map['closureReviewConfirmed']) ??
          inferredClosureState.confirmed
      ..closureCriticalModuleCount =
          _parseInt(map['closureCriticalModuleCount']) ??
          inferredClosureState.criticalModuleCount
      ..closureReviewConfirmedByUid =
          _cleanOptionalText(map['closureReviewConfirmedByUid']) ??
          inferredClosureState.confirmedByUid
      ..closureReviewConfirmedByName =
          _cleanOptionalText(map['closureReviewConfirmedByName']) ??
          inferredClosureState.confirmedByName
      ..closureReviewConfirmedAt =
          _parseTimestamp(map['closureReviewConfirmedAt']) ??
          inferredClosureState.confirmedAt
      ..createdByUid = _cleanOptionalText(map['createdByUid'])
      ..createdByName = _cleanOptionalText(map['createdByName'])
      ..updatedByUid = _cleanOptionalText(map['updatedByUid'])
      ..updatedByName = _cleanOptionalText(map['updatedByName'])
      ..publishedByUid = _cleanOptionalText(map['publishedByUid'])
      ..publishedByName = _cleanOptionalText(map['publishedByName'])
      ..publishedAt = _parseTimestamp(map['publishedAt'])
      ..retiredByUid = _cleanOptionalText(map['retiredByUid'])
      ..retiredByName = _cleanOptionalText(map['retiredByName'])
      ..retiredAt = _parseTimestamp(map['retiredAt'])
      ..retireReason = _cleanOptionalText(map['retireReason'])
      ..minAppVersion = _cleanOptionalText(map['minAppVersion'])
      ..isDeleted = map['isDeleted'] == true
      ..deletedAt = _parseTimestamp(map['deletedAt'])
      ..deletedByUid = _cleanOptionalText(map['deletedByUid'])
      ..deletedByName = _cleanOptionalText(map['deletedByName'])
      ..deleteReason = _cleanOptionalText(map['deleteReason'])
      ..version = map['version'] is int ? map['version'] as int : 1
      ..schemaVersion =
          map['schemaVersion'] is int ? map['schemaVersion'] as int : 1
      ..createdAt = _parseTimestamp(map['createdAt']) ?? DateTime.now()
      ..updatedAt =
          _parseTimestamp(map['updatedAt']) ??
          _parseTimestamp(map['createdAt']) ??
          DateTime.now()
      ..targetRefs = _cleanStringList(map['targetRefs'])
      ..deviceTagRefs = _cleanStringList(map['deviceTagRefs'])
      ..safetyClass = _cleanOptionalText(map['safetyClass'])
      ..safetyGatePolicyJson = _cleanOptionalText(map['safetyGatePolicyJson'])
      ..procedureRefs = _cleanStringList(map['procedureRefs'])
      ..operationalStatePreconditions = _cleanStringList(
        map['operationalStatePreconditions'],
      )
      ..metadataJson = _cleanOptionalText(map['metadataJson'])
      ..isSynced = true;

    if (templateVersion.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        templateVersion.deletedAt,
        entityLabel: 'template version',
        firestoreId: templateVersion.firestoreId,
      );
    }

    return templateVersion;
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
    final performedAt =
        _parseTimestamp(map['performedAt']) ??
        _parseTimestamp(map['updatedAt']) ??
        DateTime.now();

    return TemplatePublishAudit()
      ..firestoreId = documentId
      ..packageFirestoreId = _cleanOptionalText(map['packageFirestoreId'])
      ..versionFirestoreId = _cleanOptionalText(map['versionFirestoreId'])
      ..action = _enumByNameOr(
        TemplatePublishAuditAction.values,
        map['action'],
        TemplatePublishAuditAction.edited,
      )
      ..performedByUid = _cleanOptionalText(map['performedByUid'])
      ..performedByName = _cleanOptionalText(map['performedByName'])
      ..performedAt = performedAt
      ..updatedAt = _parseTimestamp(map['updatedAt']) ?? performedAt
      ..reason = _cleanOptionalText(map['reason'])
      ..beforeHash = _cleanOptionalText(map['beforeHash'])
      ..afterHash = _cleanOptionalText(map['afterHash'])
      ..payloadSnapshotJson = _cleanOptionalText(map['payloadSnapshotJson'])
      ..metadataJson = _cleanOptionalText(map['metadataJson'])
      ..version = map['version'] is int ? map['version'] as int : 1
      ..schemaVersion =
          map['schemaVersion'] is int ? map['schemaVersion'] as int : 1
      ..isDeleted = map['isDeleted'] == true
      ..isSynced = true;
  }
}
