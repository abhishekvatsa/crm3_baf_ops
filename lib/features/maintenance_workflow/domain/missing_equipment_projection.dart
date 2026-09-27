import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/plant_condition_evidence.dart';
import '../data/equipment_status_record.dart';
import 'workflow_command_contract.dart';
import 'workflow_types.dart';
import '../services/workflow_command_factory.dart';

/// A reviewed registry identity, not an invented equipment-status record.
class MissingEquipmentProjection {
  const MissingEquipmentProjection(this.asset, this.assetClass);

  final AssetInstanceRecord asset;
  final AssetClassRecord assetClass;

  String get assetTypeKey => assetClass.legacyAssetTypeKey ?? 'governedCustom';
  String get documentId => assetTypeKey == 'governedCustom'
      ? 'governedCustom_${assetClass.id}_${asset.id}'
      : '${assetTypeKey}_${asset.assetNumber}';
  String get reviewBasis =>
      '$documentId|${assetClass.id}:${assetClass.version}:${assetClass.code}|'
      '${asset.id}:${asset.version}:${asset.serviceState.name}';

  WorkflowCommand command() => WorkflowCommandFactory.create(
    type: WorkflowCommandType.reconcileEquipment,
    aggregateId: 'equipment_$documentId',
    expectedVersion: 0,
    payload: {
      'assetTypeKey': assetTypeKey,
      'assetNumber': asset.assetNumber,
      'assetClassId': assetClass.id,
      'assetInstanceId': asset.id,
    },
  );
}

/// Null means absence cannot be established. A complete empty projection feed
/// is legitimate; cached, rejected or ambiguous identities never become zeroes.
List<MissingEquipmentProjection>? missingEquipmentProjections({
  required PlantEvidenceBatch<AssetClassRecord>? classes,
  required PlantEvidenceBatch<AssetInstanceRecord>? assets,
  required PlantEvidenceBatch<EquipmentStatusRecord>? workflow,
}) {
  if (classes?.complete != true ||
      assets?.complete != true ||
      workflow?.complete != true) {
    return null;
  }
  final result = <MissingEquipmentProjection>[];
  for (final asset in assets!.rows.where((row) => row.isActive)) {
    final matches = classes!.rows
        .where((row) => row.id == asset.assetClassId)
        .toList();
    if (matches.length != 1 ||
        !matches.single.isActive ||
        matches.single.code != asset.assetClassCode ||
        assets.rows.where((row) => row.id == asset.id).length != 1) {
      continue;
    }
    final cls = matches.single;
    final legacyKey = cls.legacyAssetTypeKey;
    // Inner Covers are serial lifecycle assets, not numbered equipment slots.
    if (legacyKey == 'innerCover' ||
        (legacyKey != null &&
            !const {'base', 'furnace', 'forceCooler'}.contains(legacyKey))) {
      continue;
    }
    if (legacyKey != null &&
        classes.rows
                .where((row) => row.legacyAssetTypeKey == legacyKey)
                .length !=
            1) {
      continue;
    }
    // Include retired physical identities when checking reused number slots.
    if (assets.rows
            .where(
              (row) =>
                  row.assetClassId == cls.id &&
                  row.assetNumber == asset.assetNumber,
            )
            .length !=
        1) {
      continue;
    }
    final candidate = MissingEquipmentProjection(asset, cls);
    if (workflow!.rows.any(
      (row) =>
          row.firestoreId == candidate.documentId ||
          (row.assetTypeKey == candidate.assetTypeKey &&
              (candidate.assetTypeKey == 'governedCustom'
                  ? row.assetClassId == cls.id &&
                        row.assetInstanceId == asset.id
                  : row.assetNumber == asset.assetNumber)) ||
          (row.assetInstanceId == asset.id && row.assetTypeKey != 'innerCover'),
    )) {
      continue;
    }
    result.add(candidate);
  }
  result.sort((a, b) {
    final byClass = a.assetClass.name.compareTo(b.assetClass.name);
    final byNumber = a.asset.assetNumber.compareTo(b.asset.assetNumber);
    return byClass != 0
        ? byClass
        : byNumber != 0
        ? byNumber
        : a.asset.id.compareTo(b.asset.id);
  });
  return List.unmodifiable(result);
}
