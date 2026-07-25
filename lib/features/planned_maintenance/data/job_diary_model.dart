// FILE: lib/features/planned_maintenance/data/job_diary_model.dart

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:isar/isar.dart';

import '../../maintenance/data/maintenance_model.dart';

part 'job_diary_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

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

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _cleanStringList(dynamic value) {
  if (value is! List) return [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _normaliseEnumKey(dynamic value) {
  if (value == null) return '';
  return value
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) return fallback;

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  return fallback;
}

T? _enumByNameOrNull<T extends Enum>(List<T> values, dynamic value) {
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) return null;

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  return null;
}

JobDiaryDiscipline _parseDiscipline(dynamic value) {
  final key = _normaliseEnumKey(value);

  if (key == 'ia' ||
      key == 'ianda' ||
      key == 'instrument' ||
      key == 'instrumentation') {
    return JobDiaryDiscipline.instrumentation;
  }

  if (key == 'sic' ||
      key == 'shiftincharge' ||
      key == 'shiftcharge' ||
      key == 'shiftlead') {
    return JobDiaryDiscipline.shiftInCharge;
  }

  return _enumByNameOr(
    JobDiaryDiscipline.values,
    value,
    JobDiaryDiscipline.shared,
  );
}

// ─────────────────────────────────────────────────────────────
// DIARY ENUMS
// ─────────────────────────────────────────────────────────────

/// What kind of entry was added to the running planned-maintenance job.
///
/// This is deliberately separate from module completion status. A job can have
/// many diary entries while its modules remain in draft/in-progress state.
enum JobDiaryKind { note, observation, handover, blocker, correction }

/// Default execution lanes for BAF maintenance, with room for shared/admin
/// entries that do not belong to one discipline lane.
enum JobDiaryDiscipline {
  mechanical,
  electrical,
  instrumentation,
  operations,
  emd,
  refractory,
  shiftInCharge,
  safety,
  admin,
  shared,
  others,
}

String? _laneKeyForDiaryDiscipline(JobDiaryDiscipline discipline) {
  switch (discipline) {
    case JobDiaryDiscipline.electrical:
      return 'elec';
    case JobDiaryDiscipline.mechanical:
      return 'mech';
    case JobDiaryDiscipline.instrumentation:
      return 'inst';
    case JobDiaryDiscipline.operations:
    case JobDiaryDiscipline.shiftInCharge:
      return 'oprn';
    case JobDiaryDiscipline.emd:
      return 'emd';
    case JobDiaryDiscipline.refractory:
      return 'red';
    case JobDiaryDiscipline.safety:
    case JobDiaryDiscipline.admin:
    case JobDiaryDiscipline.shared:
    case JobDiaryDiscipline.others:
      return 'shared';
  }
}

enum JobDiarySeverity { low, medium, high, critical }

enum JobBlockerStatus { open, resolved, carriedForward, waived }

// ─────────────────────────────────────────────────────────────
// JOB DIARY ENTRY
// ─────────────────────────────────────────────────────────────

@Collection()
class JobDiaryEntry {
  JobDiaryEntry();

  Id id = Isar.autoIncrement;

  // ── Sync identity ──────────────────────────────────────────
  @Index()
  String? firestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;

  // ── Parent job linkage ─────────────────────────────────────
  /// Preferred cross-device link. Existing JobExecution records already create
  /// a UUID firestoreId at assignment time, even before sync completes.
  @Index()
  String? jobExecutionFirestoreId;

  /// Defensive device-local link for mobile-only/offline repair utilities.
  /// Never serialize this Isar integer to Firestore or import it from remote.
  @Index()
  int? jobExecutionLocalId;

  /// Future module-instance link. This remains nullable so Phase 1 diary works
  /// before JobModuleInstance is introduced.
  @Index()
  String? moduleInstanceFirestoreId;

  /// Device-local companion link; never a cross-device identity.
  int? moduleInstanceLocalId;

  // ── Job context copied from JobExecution for cheap filtering/dossier use ──
  @Enumerated(EnumType.name)
  @Index()
  AssetType assetType = AssetType.base;

  @Index()
  int assetNumber = 0;

  int? chargeNoAtEvent;

  String? templateFirestoreId;
  String? templateName;

  // ── Entry classification ───────────────────────────────────
  @Enumerated(EnumType.name)
  @Index()
  JobDiaryKind kind = JobDiaryKind.note;

  @Enumerated(EnumType.name)
  @Index()
  JobDiaryDiscipline discipline = JobDiaryDiscipline.shared;

  @Enumerated(EnumType.name)
  JobDiarySeverity severity = JobDiarySeverity.medium;

  @Enumerated(EnumType.name)
  JobBlockerStatus? blockerStatus;

  /// Denormalized flags for simple queries and UI badges.
  @Index()
  bool isBlocker = false;

  @Index()
  bool isHandover = false;

  // ── Technical targeting/context ────────────────────────────
  String? functionalSection;
  String? componentGroup;
  String? targetRef;
  String? procedureRef;
  List<String> tags = [];

  // ── Entry content ──────────────────────────────────────────
  String? title;
  late String note;

  /// Optional action/follow-up summary. Detailed component actions remain in
  /// the existing ComponentAction model until JobModuleInstance is introduced.
  String? actionTaken;
  String? pendingIssue;

  bool requiresFollowUp = false;

  // ── Actor metadata ─────────────────────────────────────────
  String? createdByUid;
  String? createdByName;

  @Index()
  late DateTime createdAt;

  String? updatedByUid;
  String? updatedByName;
  late DateTime updatedAt;

  // ── Tombstone metadata ─────────────────────────────────────
  @Index()
  bool isDeleted = false;

  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  /// Free-form extension point for later app versions. Do not store primary
  /// query fields only here.
  String? metadataJson;

  // ─── Convenience getters ───────────────────────────────────
  @ignore
  bool get isOpenBlocker => isBlocker && blockerStatus == JobBlockerStatus.open;

  @ignore
  bool get isLinkedToModule =>
      moduleInstanceFirestoreId != null || moduleInstanceLocalId != null;

  @ignore
  String get displayTitle {
    final cleaned = _cleanOptionalText(title);
    if (cleaned != null) return cleaned;

    switch (kind) {
      case JobDiaryKind.handover:
        return 'Shift handover';
      case JobDiaryKind.blocker:
        return 'Blocker';
      case JobDiaryKind.observation:
        return 'Observation';
      case JobDiaryKind.correction:
        return 'Correction';
      case JobDiaryKind.note:
        return 'Progress note';
    }
  }

  // ─── Audit snapshot ────────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'jobExecutionFirestoreId': jobExecutionFirestoreId,
    'moduleInstanceFirestoreId': moduleInstanceFirestoreId,
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'kind': kind.name,
    'discipline': discipline.name,
    'laneKey': _laneKeyForDiaryDiscipline(discipline),
    'isBlocker': isBlocker,
    'isHandover': isHandover,
    'blockerStatus': blockerStatus?.name,
    'requiresFollowUp': requiresFollowUp,
    'isDeleted': isDeleted,
  };

  // ─── Firestore serialization ───────────────────────────────
  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'jobExecutionFirestoreId': _cleanOptionalText(jobExecutionFirestoreId),
    'moduleInstanceFirestoreId': _cleanOptionalText(moduleInstanceFirestoreId),
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'chargeNoAtEvent': chargeNoAtEvent,
    'templateFirestoreId': _cleanOptionalText(templateFirestoreId),
    'templateName': _cleanOptionalText(templateName),
    'kind': kind.name,
    'discipline': discipline.name,
    'laneKey': _laneKeyForDiaryDiscipline(discipline),
    'severity': severity.name,
    'blockerStatus': blockerStatus?.name,
    'isBlocker': isBlocker,
    'isHandover': isHandover,
    'functionalSection': _cleanOptionalText(functionalSection),
    'componentGroup': _cleanOptionalText(componentGroup),
    'targetRef': _cleanOptionalText(targetRef),
    'procedureRef': _cleanOptionalText(procedureRef),
    'tags':
        tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
    'title': _cleanOptionalText(title),
    'note': note.trim(),
    'actionTaken': _cleanOptionalText(actionTaken),
    'pendingIssue': _cleanOptionalText(pendingIssue),
    'requiresFollowUp': requiresFollowUp,
    'createdByUid': _cleanOptionalText(createdByUid),
    'createdByName': _cleanOptionalText(createdByName),
    'createdAt': createdAt.toIso8601String(),
    'updatedByUid': _cleanOptionalText(updatedByUid),
    'updatedByName': _cleanOptionalText(updatedByName),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'deletedByUid': _cleanOptionalText(deletedByUid),
    'deletedByName': _cleanOptionalText(deletedByName),
    'deleteReason': _cleanOptionalText(deleteReason),
    'version': version,
    'metadataJson': _cleanOptionalText(metadataJson),
  };

  factory JobDiaryEntry.fromMap(Map<String, dynamic> map, String documentId) {
    final parsedKind = _enumByNameOr(
      JobDiaryKind.values,
      map['kind'],
      JobDiaryKind.note,
    );

    final parsedBlockerStatus = _enumByNameOrNull(
      JobBlockerStatus.values,
      map['blockerStatus'],
    );

    final created = _parseTimestamp(map['createdAt']) ?? DateTime.now();
    final updated = _parseTimestamp(map['updatedAt']) ?? created;

    return JobDiaryEntry()
      ..firestoreId = documentId
      ..jobExecutionFirestoreId = _cleanOptionalText(
        map['jobExecutionFirestoreId'],
      )
      // Device-local Isar ids are never imported from Firestore.
      ..jobExecutionLocalId = null
      ..moduleInstanceFirestoreId = _cleanOptionalText(
        map['moduleInstanceFirestoreId'],
      )
      ..moduleInstanceLocalId = null
      ..assetType = _enumByNameOr(
        AssetType.values,
        map['assetType'],
        AssetType.base,
      )
      ..assetNumber =
          map['assetNumber'] is int
              ? map['assetNumber'] as int
              : int.tryParse(map['assetNumber']?.toString() ?? '') ?? 0
      ..chargeNoAtEvent =
          map['chargeNoAtEvent'] is int
              ? map['chargeNoAtEvent'] as int
              : int.tryParse(map['chargeNoAtEvent']?.toString() ?? '')
      ..templateFirestoreId = _cleanOptionalText(map['templateFirestoreId'])
      ..templateName = _cleanOptionalText(map['templateName'])
      ..kind = parsedKind
      ..discipline = _parseDiscipline(map['discipline'])
      ..severity = _enumByNameOr(
        JobDiarySeverity.values,
        map['severity'],
        JobDiarySeverity.medium,
      )
      ..blockerStatus = parsedBlockerStatus
      ..isBlocker =
          map['isBlocker'] == true || parsedKind == JobDiaryKind.blocker
      ..isHandover =
          map['isHandover'] == true || parsedKind == JobDiaryKind.handover
      ..functionalSection = _cleanOptionalText(map['functionalSection'])
      ..componentGroup = _cleanOptionalText(map['componentGroup'])
      ..targetRef = _cleanOptionalText(map['targetRef'])
      ..procedureRef = _cleanOptionalText(map['procedureRef'])
      ..tags = _cleanStringList(map['tags'])
      ..title = _cleanOptionalText(map['title'])
      ..note = _cleanOptionalText(map['note']) ?? ''
      ..actionTaken = _cleanOptionalText(map['actionTaken'])
      ..pendingIssue = _cleanOptionalText(map['pendingIssue'])
      ..requiresFollowUp = map['requiresFollowUp'] == true
      ..createdByUid = _cleanOptionalText(map['createdByUid'])
      ..createdByName = _cleanOptionalText(map['createdByName'])
      ..createdAt = created
      ..updatedByUid = _cleanOptionalText(map['updatedByUid'])
      ..updatedByName = _cleanOptionalText(map['updatedByName'])
      ..updatedAt = updated
      ..isDeleted = map['isDeleted'] == true
      ..deletedAt = _parseTimestamp(map['deletedAt'])
      ..deletedByUid = _cleanOptionalText(map['deletedByUid'])
      ..deletedByName = _cleanOptionalText(map['deletedByName'])
      ..deleteReason = _cleanOptionalText(map['deleteReason'])
      ..version =
          map['version'] is int
              ? map['version'] as int
              : int.tryParse(map['version']?.toString() ?? '') ?? 1
      ..metadataJson = _cleanOptionalText(map['metadataJson'])
      ..isSynced = true;
  }
}
