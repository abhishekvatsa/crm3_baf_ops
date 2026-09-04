// FILE: lib/features/abnormalities/data/abnormality_model.dart

import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../../core/validation/charge_number.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import 'remote_abnormality_timestamps.dart';

part 'abnormality_model.g.dart';
part 'remote_abnormality_reader.dart';

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

enum AbnormalitySeverity { low, medium, high, critical }

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
  final AssetHierarchyReference? assetHierarchyReference;

  const AffectedAssetRef({
    required this.assetType,
    required this.assetNumber,
    this.assetHierarchyReference,
  });

  Map<String, dynamic> toMap() {
    return {
      'assetType': assetType.name,
      'assetNumber': assetNumber,
      if (assetHierarchyReference != null)
        'assetHierarchyRef': assetHierarchyReference!.toMap(),
    };
  }

  Map<String, dynamic> toIdentityMap() => {
    'assetType': assetType.name,
    'assetNumber': assetNumber,
  };

  Map<String, dynamic>? toHierarchyReferenceMap() {
    if (assetHierarchyReference == null) return null;
    return toMap();
  }

  factory AffectedAssetRef.fromMap(Map<String, dynamic> map, {String? source}) {
    final hasHierarchyReference = map.containsKey('assetHierarchyRef');
    if ((map.length != 2 && !(map.length == 3 && hasHierarchyReference)) ||
        !map.containsKey('assetType') ||
        !map.containsKey('assetNumber')) {
      throw PersistedDataFormatException(
        field: 'affectedAssets',
        source: source,
        detail:
            'each asset must contain assetType, assetNumber and an optional assetHierarchyRef',
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
    final rawReference = map['assetHierarchyRef'];
    final AssetHierarchyReference? hierarchyReference;
    if (!hasHierarchyReference) {
      hierarchyReference = null;
    } else if (rawReference is Map) {
      hierarchyReference = AssetHierarchyReference.fromMap(
        Map<String, dynamic>.from(rawReference),
        source: '$source assetHierarchyRef',
      );
      if (hierarchyReference.scope == AssetHierarchyReferenceScope.definition ||
          hierarchyReference.assetInstanceId == null ||
          hierarchyReference.assetNumber != assetNumber) {
        throw PersistedDataFormatException(
          field: 'assetHierarchyRef',
          source: source,
          detail: 'must identify the same exact physical asset',
        );
      }
    } else {
      throw PersistedDataFormatException(
        field: 'assetHierarchyRef',
        source: source,
        detail: 'must be a governed hierarchy object when present',
      );
    }
    return AffectedAssetRef(
      assetType: assetType,
      assetNumber: assetNumber,
      assetHierarchyReference: hierarchyReference,
    );
  }

  bool get isGoverned => assetHierarchyReference != null;

  String? get componentLabel {
    final reference = assetHierarchyReference;
    if (reference == null ||
        reference.scope == AssetHierarchyReferenceScope.physicalAsset) {
      return null;
    }
    return reference.nodeName;
  }

  String get label => switch (assetType) {
    AssetType.innerCover => 'Inner Cover at Base $assetNumber',
    AssetType.governedCustom when assetHierarchyReference != null =>
      '${assetHierarchyReference!.assetClassName} $assetNumber',
    _ => '${_assetTypeLabel(assetType)} $assetNumber',
  };

  @override
  String toString() => label;
}

bool isAffectedAssetPermittedForCorrection({
  required AffectedAssetRef asset,
  required Iterable<AssetType> currentlyApplicableTypes,
  required Iterable<AffectedAssetRef> existingAffectedAssets,
  required bool retainsExistingType,
}) {
  final applicableTypes = currentlyApplicableTypes.toSet();
  if (applicableTypes.isEmpty || applicableTypes.contains(asset.assetType)) {
    return true;
  }
  if (!retainsExistingType) return false;
  return existingAffectedAssets.any(
    (existing) =>
        existing.assetType == asset.assetType &&
        existing.assetNumber == asset.assetNumber,
  );
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
  ) => readRemoteAbnormalityType(map, documentId: documentId);

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
    RootReasonCategory possibleRootReasonCategory = RootReasonCategory.unknown,
    String? possibleRootReasonNotes,
    int? reannealedToChargeNo,
    required String? loggedByUid,
    required String? loggedByName,
  }) {
    final now = DateTime.now();

    final abnormality =
        ChargeAbnormality()
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
    final assets = affectedAssets;

    return {
      'firestoreId': firestoreId,
      'sourceChargeNo': sourceChargeNo,
      'abnormalityTypeId': abnormalityTypeId,
      'abnormalityTypeTitle': abnormalityTypeTitle,
      'abnormalityTypeCode': abnormalityTypeCode,
      'category': category.name,
      'severity': severity.name,
      // Keep the long-standing identity list readable by older pilot builds.
      // Rich hierarchy evidence travels in a separate optional field so one
      // new-format record cannot make an older global-pull page undecodable.
      'affectedAssets': assets.map((asset) => asset.toIdentityMap()).toList(),
      // An upgraded phone can still hold a Build 23 offline draft with no
      // affected asset. Omitting this newly introduced field preserves that
      // legacy create contract; current authoring requires at least one asset.
      if (assets.isNotEmpty)
        'affectedAssetHierarchyRefs':
            assets
                .map((asset) => asset.toHierarchyReferenceMap())
                .whereType<Map<String, dynamic>>()
                .toList(),
      'component': component,
      'observedReason': observedReason,
      'description': description,
      'possibleRootReasonCategory': possibleRootReasonCategory.name,
      'possibleRootReasonNotes': possibleRootReasonNotes,
      'reannealingStatus': reannealingStatus.name,
      'reannealedToChargeNo': reannealedToChargeNo,
      'loggedAt': loggedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'loggedByUid': loggedByUid,
      'loggedByName': loggedByName,
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
      'linkedTicketFirestoreId': linkedTicketFirestoreId,
      'linkedExecutionFirestoreId': linkedExecutionFirestoreId,
      'version': version,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
    };
  }

  factory ChargeAbnormality.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) => readRemoteChargeAbnormality(map, documentId: documentId);

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
  dynamic decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException {
    throw PersistedDataFormatException(
      field: 'affectedAssetsJson',
      detail: 'malformed JSON',
    );
  }
  return _readAffectedAssetList(
    decoded,
    field: 'affectedAssetsJson',
    source: 'local charge abnormality',
  );
}

List<AffectedAssetRef> decodeAffectedAssetsFromDynamic(dynamic value) {
  if (value == null) return [];

  if (value is String) {
    return decodeAffectedAssets(value);
  }
  return _readAffectedAssetList(
    value,
    field: 'affectedAssets',
    source: 'charge abnormality',
  );
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
    case AssetType.governedCustom:
      return 'Governed Asset';
  }
}
