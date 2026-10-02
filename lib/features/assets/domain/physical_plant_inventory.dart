import '../data/asset_hierarchy_model.dart';
import '../data/inner_cover_lifecycle.dart';
import 'plant_asset_overview.dart';
import 'base_cover_reconciliation.dart';
import 'inner_cover_stock_summary.dart';

/// Physical population shared by Home, Plant condition and reporting. Numbered
/// Inner Cover positions are not extra covers: serial lifecycle profiles are
/// the inventory identities. Dismantled stock is retained until consumed/disposed.
PlantAssetOverview physicalPlantInventory({
  required PlantAssetOverview overview,
  required List<AssetClassRecord> classes,
  required List<InnerCoverProfile> profiles,
  List<String> coverSourceWarnings = const [],
  List<String> coverPopulationWarnings = const [],
  Set<String> rejectedProfiles = const {},
  Set<String> rejectedClasses = const {},
  BaseCoverReconciliation? baseCoverReconciliation,
  InnerCoverStockSummary? innerCoverStock,
}) {
  final coverClassIds = classes
      .where((c) => c.legacyAssetTypeKey == 'innerCover')
      .map((c) => c.id)
      .toSet();
  final numbered = overview.assets
      .where(
        (s) =>
            s.asset.isActive && !coverClassIds.contains(s.asset.assetClassId),
      )
      .toList();
  final warnings = [
    ...overview.evidenceWarnings,
    ...coverSourceWarnings,
    ...coverPopulationWarnings,
  ];
  final byId = <String, List<InnerCoverProfile>>{};
  for (final profile in profiles) {
    byId.putIfAbsent(profile.id, () => []).add(profile);
  }
  final covers = <PlantInnerCoverState>[];
  final stock = innerCoverStock ?? overview.innerCoverStock;
  for (final entry in byId.entries) {
    final extant = entry.value.where((c) => c.countsAsAssetInventory).toList();
    if (extant.isEmpty) continue;
    final profile = extant.first;
    final rowWarnings = [...coverSourceWarnings];
    final stockRows = stock?.rows
        .where((r) => r.profile.id == profile.id)
        .toList();
    final stockIdentityMatches =
        stockRows?.length == 1 &&
        stockRows!.single.profile.normalizedSerialNumber ==
            profile.normalizedSerialNumber &&
        stockRows.single.profile.assetClassId == profile.assetClassId &&
        stockRows.single.profile.version == profile.version;
    if (stock != null && !stockIdentityMatches) {
      rowWarnings.add(
        'Current Inner Cover condition identity needs verification.',
      );
    }
    final matches = classes.where((c) => c.id == profile.assetClassId).toList();
    if (matches.length != 1 ||
        !matches.single.isActive ||
        matches.single.legacyAssetTypeKey != 'innerCover' ||
        matches.single.code != profile.assetClassCode ||
        rejectedClasses.contains(profile.assetClassId)) {
      rowWarnings.add('Inner Cover class is missing, retired or unverified.');
    }
    if (entry.value.length != 1 || rejectedProfiles.contains(profile.id)) {
      rowWarnings.add(
        'Inner Cover profile identity is conflicting or unverified.',
      );
    }
    if (profiles.any(
      (p) =>
          p.id != profile.id &&
          p.normalizedSerialNumber == profile.normalizedSerialNumber,
    )) {
      rowWarnings.add(
        'The serial number belongs to more than one profile; physical identity needs review.',
      );
    }
    warnings.addAll(
      rowWarnings.map((w) => 'Inner Cover ${profile.serialNumber}: $w'),
    );
    covers.add(
      PlantInnerCoverState(
        profile: profile,
        evidenceWarnings: List.unmodifiable(rowWarnings),
        stockCondition: stockIdentityMatches ? stockRows.single : null,
      ),
    );
  }
  covers.sort(
    (a, b) => a.profile.normalizedSerialNumber.compareTo(
      b.profile.normalizedSerialNumber,
    ),
  );
  final uniqueClasses = <String, AssetClassRecord>{};
  for (final cls in classes) {
    if (classes.where((c) => c.id == cls.id).length == 1) {
      uniqueClasses[cls.id] = cls;
    }
  }
  return PlantAssetOverview(
    assets: List.unmodifiable(numbered),
    physicalInventoryComplete: overview.physicalInventoryComplete,
    innerCovers: List.unmodifiable(covers),
    innerCoverEvidenceWarnings: List.unmodifiable(coverSourceWarnings),
    hasQualifiedInnerCoverInventory: true,
    innerCoverStock: innerCoverStock ?? overview.innerCoverStock,
    baseCoverReconciliation:
        baseCoverReconciliation ?? overview.baseCoverReconciliation,
    evidenceWarnings: List.unmodifiable(warnings.toSet().toList()..sort()),
    classes: [
      for (final cls in uniqueClasses.values)
        if (cls.isActive ||
            numbered.any((s) => s.asset.assetClassId == cls.id) ||
            covers.any((s) => s.profile.assetClassId == cls.id))
          PlantAssetClassSummary(
            assetClass: cls,
            inventoryComplete:
                overview.physicalInventoryComplete &&
                (!coverClassIds.contains(cls.id) ||
                    (coverSourceWarnings.isEmpty &&
                        coverPopulationWarnings.isEmpty &&
                        rejectedProfiles.isEmpty &&
                        rejectedClasses.isEmpty)),
            assets: numbered
                .where((s) => s.asset.assetClassId == cls.id)
                .toList(),
            innerCovers: covers
                .where((s) => s.profile.assetClassId == cls.id)
                .toList(),
          ),
    ],
  );
}
