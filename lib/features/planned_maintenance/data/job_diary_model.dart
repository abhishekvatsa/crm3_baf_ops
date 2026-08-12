// FILE: lib/features/planned_maintenance/data/job_diary_model.dart

import 'package:isar/isar.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/utils/asset_validator.dart';
import 'remote_job_timestamps.dart';

part 'job_diary_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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

T _enumByNameOr<T extends Enum>(
  List<T> values,
  dynamic value,
  T fallback, {
  required String field,
  required String source,
}) {
  if (value == null) return fallback;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an enum string (${value.runtimeType})',
    );
  }
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'enum value cannot be blank',
    );
  }

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown enum value "$value"',
  );
}

T? _enumByNameOrNull<T extends Enum>(
  List<T> values,
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value == null) return null;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an enum string (${value.runtimeType})',
    );
  }
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'enum value cannot be blank',
    );
  }

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown enum value "$value"',
  );
}

JobDiaryDiscipline _parseDiscipline(dynamic value, {required String source}) {
  if (value == null) return JobDiaryDiscipline.shared;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: 'discipline',
      source: source,
      detail: 'expected an enum string (${value.runtimeType})',
    );
  }
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
    field: 'discipline',
    source: source,
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
    final source = 'job diary entry $documentId';
    final parsedKind = _enumByNameOr(
      JobDiaryKind.values,
      map['kind'],
      JobDiaryKind.note,
      field: 'kind',
      source: source,
    );

    final parsedBlockerStatus = _enumByNameOrNull(
      JobBlockerStatus.values,
      map['blockerStatus'],
      field: 'blockerStatus',
      source: source,
    );
    final persistedIsBlocker = readOptionalPersistedBool(
      map['isBlocker'],
      field: 'isBlocker',
      source: source,
    );
    final persistedIsHandover = readOptionalPersistedBool(
      map['isHandover'],
      field: 'isHandover',
      source: source,
    );
    if (parsedKind == JobDiaryKind.blocker && persistedIsBlocker == false) {
      throw PersistedDataFormatException(
        field: 'isBlocker',
        source: source,
        detail: 'must be true when kind is blocker',
      );
    }
    if (parsedKind == JobDiaryKind.handover && persistedIsHandover == false) {
      throw PersistedDataFormatException(
        field: 'isHandover',
        source: source,
        detail: 'must be true when kind is handover',
      );
    }
    final isBlocker = persistedIsBlocker ?? parsedKind == JobDiaryKind.blocker;
    final isHandover =
        persistedIsHandover ?? parsedKind == JobDiaryKind.handover;
    if (!isBlocker && parsedBlockerStatus != null) {
      throw PersistedDataFormatException(
        field: 'blockerStatus',
        source: source,
        detail: 'requires isBlocker to be true',
      );
    }

    final timestamps = readRemoteJobDiaryTimestamps(map, source: source);
    if (map['isDeleted'] == true && timestamps.deletedAt == null) {
      requireRemoteTombstoneDeletedAt(
        timestamps.deletedAt,
        entityLabel: 'job diary entry',
        firestoreId: documentId,
      );
    }
    final embeddedId = readRequiredPersistedString(
      map['firestoreId'],
      field: 'firestoreId',
      source: source,
    );
    if (embeddedId != documentId) {
      throw PersistedDataFormatException(
        field: 'firestoreId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final assetType = readRequiredPersistedEnum(
      AssetType.values,
      map['assetType'],
      field: 'assetType',
      source: source,
    );
    final assetNumber = readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    if (!AssetValidator.isValid(assetType, assetNumber)) {
      throw PersistedDataFormatException(
        field: 'assetNumber',
        source: source,
        detail: 'outside the governed range for ${assetType.name}',
      );
    }
    final isDeleted = readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    );

    final entry =
        JobDiaryEntry()
          ..firestoreId = embeddedId
          ..jobExecutionFirestoreId = readOptionalPersistedString(
            map['jobExecutionFirestoreId'],
            field: 'jobExecutionFirestoreId',
            source: source,
          )
          // Device-local Isar ids are never imported from Firestore.
          ..jobExecutionLocalId = null
          ..moduleInstanceFirestoreId = readOptionalPersistedString(
            map['moduleInstanceFirestoreId'],
            field: 'moduleInstanceFirestoreId',
            source: source,
          )
          ..moduleInstanceLocalId = null
          ..assetType = assetType
          ..assetNumber = assetNumber
          ..chargeNoAtEvent = readOptionalPersistedInt(
            map['chargeNoAtEvent'],
            field: 'chargeNoAtEvent',
            source: source,
            minimum: 1,
          )
          ..templateFirestoreId = readOptionalPersistedString(
            map['templateFirestoreId'],
            field: 'templateFirestoreId',
            source: source,
          )
          ..templateName = readOptionalPersistedString(
            map['templateName'],
            field: 'templateName',
            source: source,
          )
          ..kind = parsedKind
          ..discipline = _parseDiscipline(map['discipline'], source: source)
          ..severity = _enumByNameOr(
            JobDiarySeverity.values,
            map['severity'],
            JobDiarySeverity.medium,
            field: 'severity',
            source: source,
          )
          ..blockerStatus = parsedBlockerStatus
          ..isBlocker = isBlocker
          ..isHandover = isHandover
          ..functionalSection = _readOptional(map, 'functionalSection', source)
          ..componentGroup = _readOptional(map, 'componentGroup', source)
          ..targetRef = _readOptional(map, 'targetRef', source)
          ..procedureRef = _readOptional(map, 'procedureRef', source)
          ..tags = readOptionalPersistedStringList(
            map['tags'],
            field: 'tags',
            source: source,
          )
          ..title = _readOptional(map, 'title', source)
          ..note = readRequiredPersistedString(
            map['note'],
            field: 'note',
            source: source,
          )
          ..actionTaken = _readOptional(map, 'actionTaken', source)
          ..pendingIssue = _readOptional(map, 'pendingIssue', source)
          ..requiresFollowUp =
              readOptionalPersistedBool(
                map['requiresFollowUp'],
                field: 'requiresFollowUp',
                source: source,
              ) ??
              false
          ..createdByUid = readRequiredPersistedString(
            map['createdByUid'],
            field: 'createdByUid',
            source: source,
          )
          ..createdByName = _readOptional(map, 'createdByName', source)
          ..createdAt = timestamps.createdAt
          ..updatedByUid = readRequiredPersistedString(
            map['updatedByUid'],
            field: 'updatedByUid',
            source: source,
          )
          ..updatedByName = _readOptional(map, 'updatedByName', source)
          ..updatedAt = timestamps.updatedAt
          ..isDeleted = isDeleted
          ..deletedAt = timestamps.deletedAt
          ..deletedByUid = _readOptional(map, 'deletedByUid', source)
          ..deletedByName = _readOptional(map, 'deletedByName', source)
          ..deleteReason = _readOptional(map, 'deleteReason', source)
          ..version = readRequiredPersistedInt(
            map['version'],
            field: 'version',
            source: source,
            minimum: 1,
          )
          ..metadataJson = _readOptional(
            map,
            'metadataJson',
            source,
            emptyAsNull: false,
          )
          ..isSynced = true;

    if (entry.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        entry.deletedAt,
        entityLabel: 'job diary entry',
        firestoreId: entry.firestoreId,
      );
    } else if (entry.deletedAt != null ||
        entry.deletedByUid != null ||
        entry.deletedByName != null ||
        entry.deleteReason != null) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'active diary entries cannot carry deletion state',
      );
    }
    if (entry.updatedAt.isBefore(entry.createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'cannot precede createdAt',
      );
    }

    return entry;
  }
}

String? _readOptional(
  Map<String, dynamic> map,
  String field,
  String source, {
  bool emptyAsNull = true,
}) => readOptionalPersistedString(
  map[field],
  field: field,
  source: source,
  emptyAsNull: emptyAsNull,
);
