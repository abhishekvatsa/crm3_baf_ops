import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../models/operations_report.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/domain/plant_asset_overview.dart';
import '../../assets/domain/physical_plant_inventory.dart';

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
  const OperationsReportAssetInventory(this.population);
  final PlantAssetOverview population;
  Set<String> get innerCoverClassIds => population.classes
      .where((c) => c.assetClass.legacyAssetTypeKey == 'innerCover')
      .map((c) => c.assetClass.id)
      .toSet();
  List<InnerCoverProfile> get innerCovers =>
      population.innerCovers.map((c) => c.profile).toList(growable: false);
  List<PlantAssetState> get numberedAssetStates => population.assets;
  List<String> get evidenceWarnings => population.evidenceWarnings;
  int get unknown => population.unverifiedWorkflowEvidence;
  int get total => population.total;
  int get available => population.available;
  int get underMaintenance => population.underMaintenance;
  int get down => population.down;
  int get unfit => population.unfit;

  OperationsReportAssetCounts forAssetClass({
    required AssetClassRecord assetClass,
    required List<PlantAssetState> assetStates,
  }) {
    final summary = PlantAssetClassSummary(
      assetClass: assetClass,
      assets: numberedAssetStates
          .where((s) => s.asset.assetClassId == assetClass.id)
          .toList(),
      innerCovers: population.innerCovers
          .where((s) => s.profile.assetClassId == assetClass.id)
          .toList(),
    );
    return OperationsReportAssetCounts(
      total: summary.total,
      available: summary.available,
      underMaintenance: summary.underMaintenance,
      down: summary.down,
      unfit: summary.unfit,
    );
  }
}

OperationsReportAssetInventory buildOperationsReportAssetInventory({
  required List<AssetClassRecord> assetClasses,
  required List<PlantAssetState> assetStates,
  required List<InnerCoverProfile> innerCoverProfiles,
  required String? selectedAssetClassId,
  required String? selectedAssetInstanceId,
  List<String> evidenceWarnings = const [],
  List<String> coverSourceWarnings = const [],
  List<PlantInnerCoverState>? qualifiedCoverStates,
  OperationsReportSubjectKind selectedSubjectKind =
      OperationsReportSubjectKind.numberedAsset,
}) {
  final population = physicalPlantInventory(
    overview: PlantAssetOverview(
      classes: const [],
      assets: assetStates,
      evidenceWarnings: evidenceWarnings,
    ),
    classes: assetClasses,
    profiles:
        qualifiedCoverStates?.map((s) => s.profile).toList() ??
        innerCoverProfiles,
    coverSourceWarnings: coverSourceWarnings,
  );
  bool inClass(String id) =>
      selectedAssetClassId == null || selectedAssetClassId == id;
  final numbered = population.assets
      .where(
        (s) =>
            inClass(s.asset.assetClassId) &&
            (selectedAssetInstanceId == null ||
                (selectedSubjectKind ==
                        OperationsReportSubjectKind.numberedAsset &&
                    s.asset.id == selectedAssetInstanceId)),
      )
      .toList();
  final covers = (qualifiedCoverStates ?? population.innerCovers)
      .where(
        (s) =>
            inClass(s.profile.assetClassId) &&
            (selectedAssetInstanceId == null ||
                (selectedSubjectKind ==
                        OperationsReportSubjectKind.innerCover &&
                    s.profile.id == selectedAssetInstanceId)),
      )
      .toList();
  return OperationsReportAssetInventory(
    PlantAssetOverview(
      classes: population.classes,
      assets: List.unmodifiable(numbered),
      innerCovers: List.unmodifiable(covers),
      evidenceWarnings: population.evidenceWarnings,
      innerCoverEvidenceWarnings: population.innerCoverEvidenceWarnings,
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
  final rows =
      assets
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
