import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/domain/plant_asset_overview.dart';

class OperationsReportAssetCounts {
  const OperationsReportAssetCounts({
    required this.total,
    required this.available,
    required this.underMaintenance,
    required this.down,
    required this.unfit,
  });

  final int total;
  final int available;
  final int underMaintenance;
  final int down;
  final int unfit;
}

class OperationsReportAssetInventory {
  const OperationsReportAssetInventory({
    required this.innerCoverClassIds,
    required this.innerCovers,
    required this.numberedAssetStates,
  });

  final Set<String> innerCoverClassIds;
  final List<InnerCoverProfile> innerCovers;
  final List<PlantAssetState> numberedAssetStates;

  int get total => numberedAssetStates.length + innerCovers.length;
  int get available =>
      numberedAssetStates.where((state) => state.isAvailable).length +
      innerCovers
          .where((profile) => profile.isAvailableForPlantCondition)
          .length;
  int get underMaintenance =>
      numberedAssetStates.where((state) => state.isUnderMaintenance).length +
      innerCovers
          .where((profile) => profile.isUnderMaintenanceForPlantCondition)
          .length;
  int get down => numberedAssetStates.where((state) => state.isDown).length;
  int get unfit =>
      numberedAssetStates.where((state) => state.isUnfit).length +
      innerCovers.where((profile) => profile.isUnfitForPlantCondition).length;

  OperationsReportAssetCounts forAssetClass({
    required AssetClassRecord assetClass,
    required List<PlantAssetState> assetStates,
  }) {
    if (assetClass.legacyAssetTypeKey != 'innerCover') {
      return OperationsReportAssetCounts(
        total: assetStates.length,
        available: assetStates.where((state) => state.isAvailable).length,
        underMaintenance:
            assetStates.where((state) => state.isUnderMaintenance).length,
        down: assetStates.where((state) => state.isDown).length,
        unfit: assetStates.where((state) => state.isUnfit).length,
      );
    }
    final classInnerCovers = innerCovers.where(
      (profile) => profile.assetClassId == assetClass.id,
    );
    return OperationsReportAssetCounts(
      total: classInnerCovers.length,
      available:
          classInnerCovers
              .where((profile) => profile.isAvailableForPlantCondition)
              .length,
      underMaintenance:
          classInnerCovers
              .where((profile) => profile.isUnderMaintenanceForPlantCondition)
              .length,
      down: 0,
      unfit:
          classInnerCovers
              .where((profile) => profile.isUnfitForPlantCondition)
              .length,
    );
  }
}

OperationsReportAssetInventory buildOperationsReportAssetInventory({
  required List<AssetClassRecord> assetClasses,
  required List<PlantAssetState> assetStates,
  required List<InnerCoverProfile> innerCoverProfiles,
  required String? selectedAssetClassId,
  required String? selectedAssetInstanceId,
}) {
  final innerCoverClassIds =
      assetClasses
          .where(
            (assetClass) =>
                assetClass.isActive &&
                assetClass.legacyAssetTypeKey == 'innerCover',
          )
          .map((assetClass) => assetClass.id)
          .toSet();
  final innerCovers = innerCoverProfiles
      .where(
        (profile) =>
            selectedAssetInstanceId == null &&
            innerCoverClassIds.contains(profile.assetClassId) &&
            (selectedAssetClassId == null ||
                profile.assetClassId == selectedAssetClassId),
      )
      .where((profile) => profile.countsAsAssetInventory)
      .toList(growable: false);
  innerCovers.sort(
    (left, right) =>
        left.normalizedSerialNumber.compareTo(right.normalizedSerialNumber),
  );
  final numberedAssetStates = assetStates
      .where((state) => !innerCoverClassIds.contains(state.asset.assetClassId))
      .toList(growable: false);
  return OperationsReportAssetInventory(
    innerCoverClassIds: Set<String>.unmodifiable(innerCoverClassIds),
    innerCovers: List<InnerCoverProfile>.unmodifiable(innerCovers),
    numberedAssetStates: List<PlantAssetState>.unmodifiable(
      numberedAssetStates,
    ),
  );
}

List<AssetInstanceRecord> furnaceAssetsForOperationsReport({
  required List<AssetClassRecord> assetClasses,
  required List<AssetInstanceRecord> assets,
  required String? selectedAssetClassId,
  required String? selectedAssetInstanceId,
}) {
  final activeClassesById = <String, AssetClassRecord>{
    for (final assetClass in assetClasses)
      if (assetClass.isActive) assetClass.id: assetClass,
  };
  final rows = assets
      .where((asset) {
        if (!asset.isActive) return false;
        if (selectedAssetClassId != null &&
            asset.assetClassId != selectedAssetClassId) {
          return false;
        }
        if (selectedAssetInstanceId != null &&
            asset.id != selectedAssetInstanceId) {
          return false;
        }
        return activeClassesById[asset.assetClassId]?.legacyAssetTypeKey ==
            'furnace';
      })
      .toList(growable: false)
    ..sort((left, right) => left.assetNumber.compareTo(right.assetNumber));
  return List<AssetInstanceRecord>.unmodifiable(rows);
}
