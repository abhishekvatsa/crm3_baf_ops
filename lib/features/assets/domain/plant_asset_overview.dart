import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';

class PlantAssetState {
  final AssetInstanceRecord asset;
  final AssetOperationalConditionRecord? operationalCondition;
  final EquipmentStatusRecord? workflowStatus;

  const PlantAssetState({
    required this.asset,
    required this.operationalCondition,
    required this.workflowStatus,
  });

  bool get isUnderMaintenance =>
      workflowStatus != null &&
      (workflowStatus!.openMaintenanceCount > 0 ||
          workflowStatus!.openRedCount > 0 ||
          workflowStatus!.awaitingPreparationCount > 0);

  bool get isDown =>
      operationalCondition?.active == true &&
      operationalCondition?.condition == AssetOperationalCondition.down;

  bool get isUnfit =>
      operationalCondition?.active == true &&
      operationalCondition?.condition == AssetOperationalCondition.unfit;

  bool get isStandby => asset.serviceState == AssetServiceState.standby;

  bool get isAdministrativelyOutOfService =>
      asset.serviceState == AssetServiceState.outOfService;

  bool get isAvailable =>
      asset.isActive &&
      asset.serviceState == AssetServiceState.inService &&
      !isUnderMaintenance &&
      !isDown &&
      !isUnfit;
}

class PlantAssetClassSummary {
  final AssetClassRecord assetClass;
  final List<PlantAssetState> assets;

  const PlantAssetClassSummary({
    required this.assetClass,
    required this.assets,
  });

  int get total => assets.length;
  int get available => assets.where((asset) => asset.isAvailable).length;
  int get underMaintenance =>
      assets.where((asset) => asset.isUnderMaintenance).length;
  int get down => assets.where((asset) => asset.isDown).length;
  int get unfit => assets.where((asset) => asset.isUnfit).length;
  int get standby => assets.where((asset) => asset.isStandby).length;
  int get outOfService =>
      assets.where((asset) => asset.isAdministrativelyOutOfService).length;
  int get attention =>
      assets
          .where(
            (asset) =>
                asset.isDown ||
                asset.isUnfit ||
                asset.isUnderMaintenance ||
                asset.isAdministrativelyOutOfService,
          )
          .length;
}

class PlantAssetOverview {
  final List<PlantAssetClassSummary> classes;
  final List<PlantAssetState> assets;

  const PlantAssetOverview({required this.classes, required this.assets});

  int get total => assets.length;
  int get available => assets.where((asset) => asset.isAvailable).length;
  int get underMaintenance =>
      assets.where((asset) => asset.isUnderMaintenance).length;
  int get down => assets.where((asset) => asset.isDown).length;
  int get unfit => assets.where((asset) => asset.isUnfit).length;
  int get standby => assets.where((asset) => asset.isStandby).length;
  int get outOfService =>
      assets.where((asset) => asset.isAdministrativelyOutOfService).length;

  factory PlantAssetOverview.build({
    required List<AssetClassRecord> assetClasses,
    required List<AssetInstanceRecord> assetInstances,
    required List<AssetOperationalConditionRecord> operationalConditions,
    required List<EquipmentStatusRecord> workflowStatuses,
  }) {
    final classesById = <String, AssetClassRecord>{};
    for (final assetClass in assetClasses.where((item) => item.isActive)) {
      if (classesById.containsKey(assetClass.id)) {
        throw StateError('Duplicate governed asset class ${assetClass.id}.');
      }
      classesById[assetClass.id] = assetClass;
    }

    final conditionsByAssetId = <String, AssetOperationalConditionRecord>{};
    for (final condition in operationalConditions) {
      if (conditionsByAssetId.containsKey(condition.assetInstanceId)) {
        throw StateError(
          'Duplicate operational condition for ${condition.assetInstanceId}.',
        );
      }
      conditionsByAssetId[condition.assetInstanceId] = condition;
    }

    final workflowByKey = <String, EquipmentStatusRecord>{};
    for (final status in workflowStatuses) {
      final key = status.projectionIdentityKey;
      if (workflowByKey.containsKey(key)) {
        throw StateError('Duplicate workflow projection for $key.');
      }
      workflowByKey[key] = status;
    }

    final states = <PlantAssetState>[];
    for (final asset in assetInstances.where((item) => item.isActive)) {
      final assetClass = classesById[asset.assetClassId];
      if (assetClass == null || asset.assetClassCode != assetClass.code) {
        throw StateError(
          'Asset ${asset.id} disagrees with its governed asset class.',
        );
      }
      final condition = conditionsByAssetId[asset.id];
      if (condition != null &&
          (condition.assetClassId != asset.assetClassId ||
              condition.assetClassCode != asset.assetClassCode ||
              condition.assetNumber != asset.assetNumber)) {
        throw StateError(
          'Operational condition for ${asset.id} disagrees with the asset registry.',
        );
      }
      final legacyKey = assetClass.legacyAssetTypeKey;
      states.add(
        PlantAssetState(
          asset: asset,
          operationalCondition: condition,
          workflowStatus:
              legacyKey == null
                  ? workflowByKey['governedCustom:${asset.assetClassId}:${asset.id}']
                  : workflowByKey['$legacyKey:${asset.assetNumber}'],
        ),
      );
    }
    states.sort((left, right) {
      final classOrder = left.asset.assetClassName.toLowerCase().compareTo(
        right.asset.assetClassName.toLowerCase(),
      );
      return classOrder != 0
          ? classOrder
          : left.asset.assetNumber.compareTo(right.asset.assetNumber);
    });

    final summaries =
        classesById.values.map((assetClass) {
            return PlantAssetClassSummary(
              assetClass: assetClass,
              assets: List<PlantAssetState>.unmodifiable(
                states.where(
                  (state) => state.asset.assetClassId == assetClass.id,
                ),
              ),
            );
          }).toList()
          ..sort((left, right) {
            final areaOrder = left.assetClass.majorArea.toLowerCase().compareTo(
              right.assetClass.majorArea.toLowerCase(),
            );
            return areaOrder != 0
                ? areaOrder
                : left.assetClass.name.toLowerCase().compareTo(
                  right.assetClass.name.toLowerCase(),
                );
          });

    return PlantAssetOverview(
      classes: List<PlantAssetClassSummary>.unmodifiable(summaries),
      assets: List<PlantAssetState>.unmodifiable(states),
    );
  }
}
