import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
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
      innerCovers.where(_innerCoverIsAvailable).length;
  int get underMaintenance =>
      numberedAssetStates.where((state) => state.isUnderMaintenance).length +
      innerCovers.where(_innerCoverIsUnderMaintenance).length;
  int get down => numberedAssetStates.where((state) => state.isDown).length;
  int get unfit =>
      numberedAssetStates.where((state) => state.isUnfit).length +
      innerCovers.where(_innerCoverIsUnfit).length;

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
      available: classInnerCovers.where(_innerCoverIsAvailable).length,
      underMaintenance:
          classInnerCovers.where(_innerCoverIsUnderMaintenance).length,
      down: 0,
      unfit: classInnerCovers.where(_innerCoverIsUnfit).length,
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
      .where(_countsAsInnerCoverInventory)
      .toList(growable: false);
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

bool _countsAsInnerCoverInventory(InnerCoverProfile profile) =>
    !const {
      InnerCoverLifecycleState.fullyConsumedAsDonor,
      InnerCoverLifecycleState.disposed,
    }.contains(profile.lifecycleState);

bool _innerCoverIsAvailable(InnerCoverProfile profile) => const {
  InnerCoverLifecycleState.available,
  InnerCoverLifecycleState.installed,
}.contains(profile.lifecycleState);

bool _innerCoverIsUnderMaintenance(InnerCoverProfile profile) => const {
  InnerCoverLifecycleState.underInspection,
  InnerCoverLifecycleState.underRepair,
  InnerCoverLifecycleState.underFabrication,
}.contains(profile.lifecycleState);

bool _innerCoverIsUnfit(InnerCoverProfile profile) => const {
  InnerCoverLifecycleState.quarantined,
  InnerCoverLifecycleState.rejected,
  InnerCoverLifecycleState.retiredForSalvage,
  InnerCoverLifecycleState.partiallyDismantled,
}.contains(profile.lifecycleState);
