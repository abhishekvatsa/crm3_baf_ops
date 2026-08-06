// FILE: lib/features/abnormalities/data/abnormality_model.dart

import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../maintenance/data/maintenance_model.dart';
import 'remote_abnormality_timestamps.dart';

part 'abnormality_model.g.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum AbnormalityCategory {
  process,
  equipment,
  resultQuality,
  reannealing,
  other,
}
enum AbnormalitySeverity {
  low,
  medium,
  high,
  critical,
}

enum ReannealingStatus {
  notApplicable,
  pendingDecision,
  required,
  notRequired,
  completed,
}

enum RootReasonCategory {
  unknown,
  baseRelated,
  furnaceRelated,
  forceCoolerRelated,
  atmosphereRelated,
  thermocoupleTemperature,
  cycleInterruption,
  materialOrCoilCondition,
  operationsRelated,
  other,
}

// ─────────────────────────────────────────────────────────────
// AFFECTED ASSET REF
// Stored as JSON inside ChargeAbnormality. Not an Isar collection.
// ─────────────────────────────────────────────────────────────

class AffectedAssetRef {
  final AssetType assetType;
  final int assetNumber;

  const AffectedAssetRef({
    required this.assetType,
    required this.assetNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'assetType': assetType.name,
      'assetNumber': assetNumber,
    };
  }

  factory AffectedAssetRef.fromMap(Map<String, dynamic> map) {
    return AffectedAssetRef(
      assetType: _assetTypeFromValue(map['assetType']),
      assetNumber: _safeInt(map['assetNumber']) ?? 0,
    );
  }

  String get label => '${_assetTypeLabel(assetType)} $assetNumber';

  @override
  String toString() => label;
}

// ─────────────────────────────────────────────────────────────
// ABNORMALITY TYPE
// Admin-managed master data.
// Firestore collection: abnormality_types
// ─────────────────────────────────────────────────────────────

@collection
class AbnormalityType {
  AbnormalityType();

  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? firestoreId;

  @Index(caseSensitive: false)
  late String code;

  @Index(caseSensitive: false)
  late String title;

  String? description;

  @enumerated
  AbnormalityCategory category = AbnormalityCategory.other;

  @enumerated
  AbnormalitySeverity severity = AbnormalitySeverity.medium;

  /// Stored as AssetType.index values to avoid Isar enum-list complications.
  ///
  /// Use [applicableAssetTypes] getter/setter in app code.
  List<int> applicableAssetTypeIndexes = [];

  bool suggestsReannealing = false;

  @Index()
  bool isActive = true;

  @Index()
  bool isDeleted = false;

  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  int version = 1;
  bool isSynced = false;

  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  String? createdByUid;
  String? createdByName;

  String? lastEditedByUid;
  String? lastEditedByName;

  // ───────────────────────────────────────────────────────────
  // Convenience
  // ───────────────────────────────────────────────────────────

  @ignore
  List<AssetType> get applicableAssetTypes {
    return applicableAssetTypeIndexes
        .where((index) => index >= 0 && index < AssetType.values.length)
        .map((index) => AssetType.values[index])
        .toList();
  }

  set applicableAssetTypes(List<AssetType> values) {
    applicableAssetTypeIndexes = values.map((type) => type.index).toList();
  }

  @ignore
  bool get isRaCoilColourType {
    return code.trim().toUpperCase() == 'RA_COIL_COLOUR';
  }

  void markEdited({
    required String? editedByUid,
    required String? editedByName,
  }) {
    lastEditedByUid = editedByUid;
    lastEditedByName = editedByName;
    updatedAt = DateTime.now();
    version += 1;
    isSynced = false;
  }

  void softDelete({
    required String? deletedByUid,
    required String? deletedByName,
    String? reason,
  }) {
    final now = DateTime.now();

    isDeleted = true;
    isActive = false;

    deletedAt = now;
    this.deletedByUid = deletedByUid;
    this.deletedByName = deletedByName;
    deleteReason = reason;

    lastEditedByUid = deletedByUid;
    lastEditedByName = deletedByName;

    updatedAt = now;
    version += 1;
    isSynced = false;
  }

  // ───────────────────────────────────────────────────────────
  // Seeded default type: RA required due to coil colour
  // ───────────────────────────────────────────────────────────

  static AbnormalityType seedRaCoilColour({
    String? createdByUid,
    String? createdByName,
  }) {
    final now = DateTime.now();

    return AbnormalityType()
      ..firestoreId = 'RA_COIL_COLOUR'
      ..code = 'RA_COIL_COLOUR'
      ..title = 'RA Required – Coil Colour'
      ..description =
          'Re-annealing required based on coil colour or visual condition after cycle completion.'
      ..category = AbnormalityCategory.reannealing
      ..severity = AbnormalitySeverity.high
      ..applicableAssetTypes = [
        AssetType.base,
        AssetType.furnace,
        AssetType.forceCooler,
      ]
      ..suggestsReannealing = true
      ..isActive = true
      ..isDeleted = false
      ..deletedAt = null
      ..deletedByUid = null
      ..deletedByName = null
      ..deleteReason = null
      ..version = 1
      ..isSynced = false
      ..createdAt = now
      ..updatedAt = now
      ..createdByUid = createdByUid
      ..createdByName = createdByName
      ..lastEditedByUid = createdByUid
      ..lastEditedByName = createdByName;
  }

  // ───────────────────────────────────────────────────────────
  // Firestore mapping
  // ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'firestoreId': firestoreId,
      'code': code,
      'title': title,
      'description': description,
      'category': category.name,
      'severity': severity.name,
      'applicableAssetTypes':
      applicableAssetTypes.map((assetType) => assetType.name).toList(),
      'suggestsReannealing': suggestsReannealing,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'lastEditedByUid': lastEditedByUid,
      'lastEditedByName': lastEditedByName,
    };
  }

  factory AbnormalityType.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    final timestamps = readRemoteAbnormalityTypeTimestamps(
      map,
      source: 'abnormality type $documentId',
    );

    final type = AbnormalityType()
      ..firestoreId = _safeString(map['firestoreId']) ?? documentId
      ..code = _safeString(map['code']) ?? documentId
      ..title = _safeString(map['title']) ?? 'Untitled Abnormality'
      ..description = _safeString(map['description'])
      ..category = _enumByNameOr(
        AbnormalityCategory.values,
        map['category'],
        AbnormalityCategory.other,
      )
      ..severity = _enumByNameOr(
        AbnormalitySeverity.values,
        map['severity'],
        AbnormalitySeverity.medium,
      )
      ..suggestsReannealing = _safeBool(map['suggestsReannealing']) ?? false
      ..isActive = _safeBool(map['isActive']) ?? true
      ..isDeleted = _safeBool(map['isDeleted']) ?? false
      ..deletedAt = timestamps.deletedAt
      ..deletedByUid = _safeString(map['deletedByUid'])
      ..deletedByName = _safeString(map['deletedByName'])
      ..deleteReason = _safeString(map['deleteReason'])
      ..version = _safeInt(map['version']) ?? 1
      ..isSynced = true
      ..createdAt = timestamps.createdAt
      ..updatedAt = timestamps.updatedAt
      ..createdByUid = _safeString(map['createdByUid'])
      ..createdByName = _safeString(map['createdByName'])
      ..lastEditedByUid = _safeString(map['lastEditedByUid'])
      ..lastEditedByName = _safeString(map['lastEditedByName']);

    type.applicableAssetTypes =
        _assetTypesFromValue(map['applicableAssetTypes']);

    if (type.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        type.deletedAt,
        entityLabel: 'abnormality type',
        firestoreId: type.firestoreId,
      );
    }

    return type;
  }

  Map<String, dynamic> toAuditMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'code': code,
      'title': title,
      'description': description,
      'category': category.name,
      'severity': severity.name,
      'applicableAssetTypes':
      applicableAssetTypes.map((assetType) => assetType.name).toList(),
      'suggestsReannealing': suggestsReannealing,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'lastEditedByUid': lastEditedByUid,
      'lastEditedByName': lastEditedByName,
    };
  }
}

// ─────────────────────────────────────────────────────────────
// CHARGE ABNORMALITY
// Actual logged event.
// Firestore collection: charge_abnormalities
// ─────────────────────────────────────────────────────────────

@collection
class ChargeAbnormality {
  ChargeAbnormality();

  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? firestoreId;

  /// Original charge number against which abnormality is logged.
  @Index()
  late int sourceChargeNo;

  @Index(caseSensitive: false)
  late String abnormalityTypeId;

  late String abnormalityTypeTitle;
  late String abnormalityTypeCode;

  @enumerated
  AbnormalityCategory category = AbnormalityCategory.other;

  @enumerated
  AbnormalitySeverity severity = AbnormalitySeverity.medium;

  /// JSON array of AffectedAssetRef maps.
  ///
  /// Example:
  /// [
  ///   {"assetType": "base", "assetNumber": 105},
  ///   {"assetType": "furnace", "assetNumber": 7}
  /// ]
  String affectedAssetsJson = '[]';

  String? component;

  /// Required business reason/observation.
  ///
  /// Example:
  /// "Coil colour indicated RA required"
  /// "Furnace got stuck during movement"
  late String observedReason;

  String? description;

  @enumerated
  RootReasonCategory possibleRootReasonCategory = RootReasonCategory.unknown;

  String? possibleRootReasonNotes;

  @enumerated
  ReannealingStatus reannealingStatus = ReannealingStatus.notApplicable;

  /// New charge number if re-annealing has been assigned/performed.
  @Index()
  int? reannealedToChargeNo;

  @Index()
  late DateTime loggedAt;

  late DateTime updatedAt;

  String? loggedByUid;
  String? loggedByName;

  String? updatedByUid;
  String? updatedByName;

  /// Optional future links.
  String? linkedTicketFirestoreId;
  String? linkedExecutionFirestoreId;

  int version = 1;
  bool isSynced = false;

  @Index()
  bool isDeleted = false;

  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  // ───────────────────────────────────────────────────────────
  // Convenience
  // ───────────────────────────────────────────────────────────

  @ignore
  List<AffectedAssetRef> get affectedAssets {
    return decodeAffectedAssets(affectedAssetsJson);
  }

  set affectedAssets(List<AffectedAssetRef> values) {
    affectedAssetsJson = encodeAffectedAssets(values);
  }

  @ignore
  bool get requiresReannealing {
    return reannealingStatus == ReannealingStatus.required ||
        reannealingStatus == ReannealingStatus.completed;
  }

  @ignore
  bool get hasCompletedReannealing {
    return reannealingStatus == ReannealingStatus.completed &&
        reannealedToChargeNo != null;
  }

  @ignore
  String get affectedAssetsLabel {
    final assets = affectedAssets;
    if (assets.isEmpty) return 'No asset specified';
    return assets.map((asset) => asset.label).join(', ');
  }

  void normalizeReannealingState() {
    if (reannealedToChargeNo != null) {
      reannealingStatus = ReannealingStatus.completed;
    }
  }

  void markEdited({
    required String? editedByUid,
    required String? editedByName,
  }) {
    normalizeReannealingState();

    updatedByUid = editedByUid;
    updatedByName = editedByName;
    updatedAt = DateTime.now();
    version += 1;
    isSynced = false;
  }

  void softDelete({
    required String? deletedByUid,
    required String? deletedByName,
    String? reason,
  }) {
    isDeleted = true;
    deletedAt = DateTime.now();
    this.deletedByUid = deletedByUid;
    this.deletedByName = deletedByName;
    deleteReason = reason;

    updatedByUid = deletedByUid;
    updatedByName = deletedByName;
    updatedAt = DateTime.now();
    version += 1;
    isSynced = false;
  }

  // ───────────────────────────────────────────────────────────
  // RA coil colour convenience constructor
  // Repository should assign firestoreId if null before saving.
  // ───────────────────────────────────────────────────────────

  static ChargeAbnormality createRaCoilColour({
    String? firestoreId,
    required int sourceChargeNo,
    required List<AffectedAssetRef> affectedAssets,
    required String observedReason,
    String? description,
    RootReasonCategory possibleRootReasonCategory =
        RootReasonCategory.unknown,
    String? possibleRootReasonNotes,
    int? reannealedToChargeNo,
    required String? loggedByUid,
    required String? loggedByName,
  }) {
    final now = DateTime.now();

    final abnormality = ChargeAbnormality()
      ..firestoreId = firestoreId
      ..sourceChargeNo = sourceChargeNo
      ..abnormalityTypeId = 'RA_COIL_COLOUR'
      ..abnormalityTypeCode = 'RA_COIL_COLOUR'
      ..abnormalityTypeTitle = 'RA Required – Coil Colour'
      ..category = AbnormalityCategory.reannealing
      ..severity = AbnormalitySeverity.high
      ..affectedAssets = affectedAssets
      ..observedReason = observedReason
      ..description = description
      ..possibleRootReasonCategory = possibleRootReasonCategory
      ..possibleRootReasonNotes = possibleRootReasonNotes
      ..reannealingStatus = ReannealingStatus.required
      ..reannealedToChargeNo = reannealedToChargeNo
      ..loggedAt = now
      ..updatedAt = now
      ..loggedByUid = loggedByUid
      ..loggedByName = loggedByName
      ..updatedByUid = loggedByUid
      ..updatedByName = loggedByName
      ..version = 1
      ..isSynced = false
      ..isDeleted = false;

    abnormality.normalizeReannealingState();
    return abnormality;
  }

  // ───────────────────────────────────────────────────────────
  // Firestore mapping
  // ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    normalizeReannealingState();

    return {
      'firestoreId': firestoreId,
      'sourceChargeNo': sourceChargeNo,
      'abnormalityTypeId': abnormalityTypeId,
      'abnormalityTypeTitle': abnormalityTypeTitle,
      'abnormalityTypeCode': abnormalityTypeCode,
      'category': category.name,
      'severity': severity.name,
      'affectedAssets': affectedAssets.map((asset) => asset.toMap()).toList(),
      'component': component,
      'observedReason': observedReason,
      'description': description,
      'possibleRootReasonCategory': possibleRootReasonCategory.name,
      'possibleRootReasonNotes': possibleRootReasonNotes,
      'reannealingStatus': reannealingStatus.name,
      'reannealedToChargeNo': reannealedToChargeNo,
      'loggedAt': loggedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'loggedByUid': loggedByUid,
      'loggedByName': loggedByName,
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
      'linkedTicketFirestoreId': linkedTicketFirestoreId,
      'linkedExecutionFirestoreId': linkedExecutionFirestoreId,
      'version': version,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
    };
  }

  factory ChargeAbnormality.fromMap(
      Map<String, dynamic> map,
      String documentId,
      ) {
    final timestamps = readRemoteChargeAbnormalityTimestamps(
      map,
      source: 'charge abnormality $documentId',
    );

    final abnormality = ChargeAbnormality()
      ..firestoreId = _safeString(map['firestoreId']) ?? documentId
      ..sourceChargeNo = _safeInt(map['sourceChargeNo']) ?? 0
      ..abnormalityTypeId =
          _safeString(map['abnormalityTypeId']) ?? 'UNKNOWN'
      ..abnormalityTypeTitle =
          _safeString(map['abnormalityTypeTitle']) ?? 'Unknown Abnormality'
      ..abnormalityTypeCode =
          _safeString(map['abnormalityTypeCode']) ?? 'UNKNOWN'
      ..category = _enumByNameOr(
        AbnormalityCategory.values,
        map['category'],
        AbnormalityCategory.other,
      )
      ..severity = _enumByNameOr(
        AbnormalitySeverity.values,
        map['severity'],
        AbnormalitySeverity.medium,
      )
      ..component = _safeString(map['component'])
      ..observedReason =
          _safeString(map['observedReason']) ?? 'No reason recorded'
      ..description = _safeString(map['description'])
      ..possibleRootReasonCategory = _enumByNameOr(
        RootReasonCategory.values,
        map['possibleRootReasonCategory'],
        RootReasonCategory.unknown,
      )
      ..possibleRootReasonNotes =
      _safeString(map['possibleRootReasonNotes'])
      ..reannealingStatus = _enumByNameOr(
        ReannealingStatus.values,
        map['reannealingStatus'],
        ReannealingStatus.notApplicable,
      )
      ..reannealedToChargeNo = _safeInt(map['reannealedToChargeNo'])
      ..loggedAt = timestamps.loggedAt
      ..updatedAt = timestamps.updatedAt
      ..loggedByUid = _safeString(map['loggedByUid'])
      ..loggedByName = _safeString(map['loggedByName'])
      ..updatedByUid = _safeString(map['updatedByUid'])
      ..updatedByName = _safeString(map['updatedByName'])
      ..linkedTicketFirestoreId = _safeString(map['linkedTicketFirestoreId'])
      ..linkedExecutionFirestoreId =
      _safeString(map['linkedExecutionFirestoreId'])
      ..version = _safeInt(map['version']) ?? 1
      ..isSynced = true
      ..isDeleted = _safeBool(map['isDeleted']) ?? false
      ..deletedAt = timestamps.deletedAt
      ..deletedByUid = _safeString(map['deletedByUid'])
      ..deletedByName = _safeString(map['deletedByName'])
      ..deleteReason = _safeString(map['deleteReason']);

    abnormality.affectedAssets =
        decodeAffectedAssetsFromDynamic(map['affectedAssets']);

    abnormality.normalizeReannealingState();

    if (abnormality.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        abnormality.deletedAt,
        entityLabel: 'charge abnormality',
        firestoreId: abnormality.firestoreId,
      );
    }

    return abnormality;
  }

  Map<String, dynamic> toAuditMap() {
    normalizeReannealingState();

    return {
      'id': id,
      'firestoreId': firestoreId,
      'sourceChargeNo': sourceChargeNo,
      'abnormalityTypeId': abnormalityTypeId,
      'abnormalityTypeTitle': abnormalityTypeTitle,
      'abnormalityTypeCode': abnormalityTypeCode,
      'category': category.name,
      'severity': severity.name,
      'affectedAssets': affectedAssets.map((asset) => asset.toMap()).toList(),
      'component': component,
      'observedReason': observedReason,
      'description': description,
      'possibleRootReasonCategory': possibleRootReasonCategory.name,
      'possibleRootReasonNotes': possibleRootReasonNotes,
      'reannealingStatus': reannealingStatus.name,
      'reannealedToChargeNo': reannealedToChargeNo,
      'loggedAt': loggedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'loggedByUid': loggedByUid,
      'loggedByName': loggedByName,
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
      'linkedTicketFirestoreId': linkedTicketFirestoreId,
      'linkedExecutionFirestoreId': linkedExecutionFirestoreId,
      'version': version,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
    };
  }
}

// ─────────────────────────────────────────────────────────────
// JSON HELPERS FOR AFFECTED ASSETS
// ─────────────────────────────────────────────────────────────

String encodeAffectedAssets(List<AffectedAssetRef> assets) {
  return jsonEncode(assets.map((asset) => asset.toMap()).toList());
}

List<AffectedAssetRef> decodeAffectedAssets(String? jsonText) {
  if (jsonText == null || jsonText.trim().isEmpty) {
    return [];
  }

  try {
    final decoded = jsonDecode(jsonText);
    return decodeAffectedAssetsFromDynamic(decoded);
  } catch (_) {
    return [];
  }
}

List<AffectedAssetRef> decodeAffectedAssetsFromDynamic(dynamic value) {
  if (value == null) return [];

  if (value is String) {
    return decodeAffectedAssets(value);
  }

  if (value is! List) return [];

  final refs = <AffectedAssetRef>[];

  for (final item in value) {
    if (item is Map<String, dynamic>) {
      refs.add(AffectedAssetRef.fromMap(item));
    } else if (item is Map) {
      refs.add(
        AffectedAssetRef.fromMap(
          item.map(
                (key, value) => MapEntry(key.toString(), value),
          ),
        ),
      );
    }
  }

  return refs;
}

// ─────────────────────────────────────────────────────────────
// SAFE PARSERS
// ─────────────────────────────────────────────────────────────

String? _safeString(dynamic value) {
  if (value == null) return null;

  final text = value.toString().trim();
  if (text.isEmpty) return null;

  return text;
}

int? _safeInt(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;

  if (value is num) return value.toInt();

  if (value is String) return int.tryParse(value.trim());

  return null;
}

bool? _safeBool(dynamic value) {
  if (value == null) return null;

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

T _enumByNameOr<T extends Enum>(
    List<T> values,
    dynamic raw,
    T fallback,
    ) {
  if (raw == null) return fallback;

  if (raw is int && raw >= 0 && raw < values.length) {
    return values[raw];
  }

  final normalized = raw.toString().trim().toLowerCase();

  for (final value in values) {
    if (value.name.toLowerCase() == normalized) {
      return value;
    }
  }

  return fallback;
}

AssetType _assetTypeFromValue(dynamic raw) {
  if (raw == null) return AssetType.base;

  if (raw is int && raw >= 0 && raw < AssetType.values.length) {
    return AssetType.values[raw];
  }

  final normalized = raw.toString().trim().toLowerCase().replaceAll('_', '');

  switch (normalized) {
    case 'base':
      return AssetType.base;
    case 'furnace':
      return AssetType.furnace;
    case 'forcecooler':
    case 'forcecoolers':
    case 'cooler':
    case 'coolers':
      return AssetType.forceCooler;
    case 'innercover':
    case 'innercovers':
    case 'cover':
    case 'covers':
      return AssetType.innerCover;
    default:
      return _enumByNameOr(
        AssetType.values,
        raw,
        AssetType.base,
      );
  }
}

List<AssetType> _assetTypesFromValue(dynamic value) {
  if (value == null) return [];

  if (value is List) {
    return value.map(_assetTypeFromValue).toSet().toList();
  }

  return [_assetTypeFromValue(value)];
}

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Force Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
  }
}
