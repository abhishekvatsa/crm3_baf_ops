import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../assets/data/asset_hierarchy_model.dart';

const furnaceStuckupClassification = 'furnaceStuckup';
const furnaceStuckupSchemaVersion = 1;

const furnaceStuckupSynchronizedFieldNames = <String>{
  'furnaceStuckupSchemaVersion',
  'stuckupBaseNumber',
  'stuckupBaseAssetRefJson',
  'stuckupSuspectedCause',
  'stuckupOperatingContext',
};

enum FurnaceStuckupCause {
  innerCoverBulging,
  draftSealPlateDamagedOrFallen,
  insufficientDraftSealClearance,
  combinedCondition,
  other,
  unknown,
  inconclusive,
}

extension FurnaceStuckupCauseLabel on FurnaceStuckupCause {
  String get label => switch (this) {
    FurnaceStuckupCause.innerCoverBulging => 'Inner Cover bulging',
    FurnaceStuckupCause.draftSealPlateDamagedOrFallen =>
      'Draft Seal Plate damaged / fallen',
    FurnaceStuckupCause.insufficientDraftSealClearance =>
      'Insufficient Draft Seal clearance',
    FurnaceStuckupCause.combinedCondition => 'Combined condition',
    FurnaceStuckupCause.other => 'Other suspected cause',
    FurnaceStuckupCause.unknown => 'Cause not yet known',
    FurnaceStuckupCause.inconclusive => 'Inconclusive after inspection',
  };
}

enum FurnaceStuckupOperatingContext {
  postAnnealingRemoval,
  maintenanceMovement,
  other,
}

extension FurnaceStuckupOperatingContextLabel
    on FurnaceStuckupOperatingContext {
  String get label => switch (this) {
    FurnaceStuckupOperatingContext.postAnnealingRemoval =>
      'Post-annealing Furnace removal',
    FurnaceStuckupOperatingContext.maintenanceMovement =>
      'Maintenance movement',
    FurnaceStuckupOperatingContext.other => 'Other movement context',
  };
}

class FurnaceStuckupCase {
  FurnaceStuckupCase({
    required this.baseNumber,
    required this.baseAssetReference,
    required this.suspectedCause,
    required this.operatingContext,
  }) {
    if (baseNumber < 1 || baseNumber > 9999) {
      throw const FormatException('Base number is outside the governed range.');
    }
    if (baseAssetReference.scope !=
            AssetHierarchyReferenceScope.physicalAsset ||
        baseAssetReference.assetNumber != baseNumber ||
        baseAssetReference.assetClassCode.trim().toUpperCase() != 'BASE') {
      throw const FormatException(
        'Furnace stuck-up requires an exact governed Base identity.',
      );
    }
    final association = baseAssetReference.innerCoverAssociation;
    if (association == null ||
        association.positionState != InnerCoverPositionState.linked ||
        association.innerCoverId == null ||
        association.innerCoverSerialNumber == null) {
      throw const FormatException(
        'Furnace stuck-up requires the Inner Cover linked to the Base.',
      );
    }
    if (suspectedCause == FurnaceStuckupCause.inconclusive) {
      throw const FormatException(
        'Inconclusive is reserved for later cause adjudication.',
      );
    }
  }

  final int baseNumber;
  final AssetHierarchyReference baseAssetReference;
  final FurnaceStuckupCause suspectedCause;
  final FurnaceStuckupOperatingContext operatingContext;

  InnerCoverEventReference get innerCoverAssociation =>
      baseAssetReference.innerCoverAssociation!;

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'furnaceStuckupSchemaVersion': furnaceStuckupSchemaVersion,
    'stuckupBaseNumber': baseNumber,
    'stuckupBaseAssetRefJson': baseAssetReference.encode(),
    'stuckupSuspectedCause': suspectedCause.name,
    'stuckupOperatingContext': operatingContext.name,
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'schemaVersion': furnaceStuckupSchemaVersion,
    'baseNumber': baseNumber,
    'baseAssetRefJson': baseAssetReference.encode(),
    'suspectedCause': suspectedCause.name,
    'operatingContext': operatingContext.name,
  };

  factory FurnaceStuckupCase.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        furnaceStuckupSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.length != furnaceStuckupSynchronizedFieldNames.length) {
      throw PersistedDataFormatException(
        field: 'furnaceStuckupSchemaVersion',
        source: source,
        detail: 'Furnace stuck-up fields must be present together',
      );
    }
    final version = readRequiredPersistedInt(
      map['furnaceStuckupSchemaVersion'],
      field: 'furnaceStuckupSchemaVersion',
      source: source,
    );
    if (version != furnaceStuckupSchemaVersion) {
      throw PersistedDataFormatException(
        field: 'furnaceStuckupSchemaVersion',
        source: source,
        detail: 'unsupported schema version $version',
      );
    }
    final encodedReference = readRequiredPersistedString(
      map['stuckupBaseAssetRefJson'],
      field: 'stuckupBaseAssetRefJson',
      source: source,
    );
    try {
      return FurnaceStuckupCase(
        baseNumber: readRequiredPersistedInt(
          map['stuckupBaseNumber'],
          field: 'stuckupBaseNumber',
          source: source,
          minimum: 1,
        ),
        baseAssetReference: AssetHierarchyReference.decode(
          encodedReference,
          source: source,
        ),
        suspectedCause: readRequiredPersistedEnum(
          FurnaceStuckupCause.values,
          map['stuckupSuspectedCause'],
          field: 'stuckupSuspectedCause',
          source: source,
        ),
        operatingContext: readRequiredPersistedEnum(
          FurnaceStuckupOperatingContext.values,
          map['stuckupOperatingContext'],
          field: 'stuckupOperatingContext',
          source: source,
        ),
      );
    } on FormatException catch (error) {
      throw PersistedDataFormatException(
        field: 'stuckupBaseAssetRefJson',
        source: source,
        detail: error.message,
      );
    }
  }

  static FurnaceStuckupCase? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        furnaceStuckupSynchronizedFieldNames.where(map.containsKey).toSet();
    if (present.isEmpty) return null;
    return FurnaceStuckupCase.fromSynchronizedFields(map, source: source);
  }

  static FurnaceStuckupCase? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final raw = Map<String, dynamic>.from(decoded)['furnaceStuckup'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'furnaceStuckup',
        source: 'local maintenance metadata',
        detail: 'expected an object',
      );
    }
    final local = Map<String, dynamic>.from(raw);
    return FurnaceStuckupCase.fromSynchronizedFields(<String, dynamic>{
      'furnaceStuckupSchemaVersion': local['schemaVersion'],
      'stuckupBaseNumber': local['baseNumber'],
      'stuckupBaseAssetRefJson': local['baseAssetRefJson'],
      'stuckupSuspectedCause': local['suspectedCause'],
      'stuckupOperatingContext': local['operatingContext'],
    }, source: 'local maintenance metadata');
  }
}

String mergeFurnaceStuckupIntoMaintenanceMetadata(
  String? existing,
  FurnaceStuckupCase? value,
) {
  final root = <String, dynamic>{};
  if (existing != null && existing.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(existing);
      if (decoded is Map) root.addAll(Map<String, dynamic>.from(decoded));
    } on FormatException {
      root['legacyMetadata'] = existing;
    }
  }
  if (value == null) {
    root.remove('furnaceStuckup');
  } else {
    root['furnaceStuckup'] = value.toLocalMap();
  }
  return jsonEncode(root);
}
