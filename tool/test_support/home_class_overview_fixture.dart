import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_stock_summary.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import '../../test/plant_asset_overview_test.dart' as f;

/// Synthetic widget-only inventory. It never connects to a device or backend.
PlantAssetOverview homeClassOverviewFixture({bool unverified = false}) {
  final base = f.assetClass(
    id: 'bases',
    code: 'BASE',
    name: 'Bases',
    legacyKey: 'base',
  );
  final furnace = f.assetClass(
    id: 'furnaces',
    code: 'FURNACE',
    name: 'Furnaces',
    legacyKey: 'furnace',
  );
  final cooler = f.assetClass(
    id: 'coolers',
    code: 'COOLER',
    name: 'Forced coolers',
    legacyKey: 'cooler',
  );
  final cover = f.assetClass(
    id: 'covers',
    code: 'INNER_COVER',
    name: 'Inner Covers',
    legacyKey: 'innerCover',
  );
  final summaries = <PlantAssetClassSummary>[];
  final rows = <PlantAssetState>[];
  for (final (assetClass, count) in [(base, 47), (furnace, 25), (cooler, 24)]) {
    final classRows = List.generate(count, (index) {
      final asset = f.asset(
        id: '${assetClass.id}-$index',
        assetClass: assetClass,
        number: assetClass.id == 'bases' ? 101 + index : 1 + index,
      );
      final isBase = assetClass.id == 'bases';
      final down = isBase && index >= 35 && index < 39;
      final maintenance = isBase && index >= 39 && index < 44;
      final stuck = isBase && index >= 44;
      return PlantAssetState(
        asset: asset,
        operationalCondition: down
            ? f.condition(
                asset: asset,
                condition: AssetOperationalCondition.down,
              )
            : null,
        availability: stuck ? f.blocked(asset: asset) : null,
        workflowStatus: unverified && isBase && index == 0
            ? null
            : f.workflow(
                key: assetClass.legacyAssetTypeKey!,
                number: asset.assetNumber,
                assetClassId: assetClass.id,
                assetInstanceId: asset.id,
                maintenance: maintenance ? 1 : 0,
              ),
      );
    });
    rows.addAll(classRows);
    summaries.add(
      PlantAssetClassSummary(assetClass: assetClass, assets: classRows),
    );
  }
  final now = DateTime.utc(2026, 10, 2);
  final stockRows = List.generate(51, (index) {
    final installed = index < 47;
    final excluded = index == 50;
    final serial = 'DEMO-${index + 1}';
    final profile = InnerCoverProfile(
      id: 'cover-$index',
      assetClassId: cover.id,
      assetClassCode: cover.code,
      assetClassName: cover.name,
      serialNumber: serial,
      normalizedSerialNumber: 'DEMO${index + 1}',
      sourceType: InnerCoverSourceType.legacyExisting,
      lifecycleState: installed
          ? InnerCoverLifecycleState.installed
          : excluded
          ? InnerCoverLifecycleState.quarantined
          : InnerCoverLifecycleState.available,
      traceabilityGrade: InnerCoverTraceabilityGrade.t0,
      version: 1,
      createdAt: now,
      updatedAt: now,
      lastMutationId: 'synthetic-$index',
    );
    return InnerCoverStockRow(
      profile: profile,
      disposition: installed
          ? InnerCoverStockDisposition.installed
          : excluded
          ? InnerCoverStockDisposition.excluded
          : InnerCoverStockDisposition.acceptedUnassigned,
      reviewReasons: excluded
          ? const ['Not a spare candidate: Quarantined']
          : const [],
      evidenceUnverified: false,
      activeConfirmedBulging: false,
      pendingBulgeAssessment: false,
      bulgeHistory: false,
      inconclusiveBulgeAssessment: false,
    );
  });
  final stock = InnerCoverStockSummary(
    rows: stockRows,
    inventoryConfirmed: true,
    linkageConfirmed: true,
    bulgeEvidenceConfirmed: true,
    dependencyEvidenceConfirmed: true,
  );
  final covers = [
    for (final row in stockRows)
      PlantInnerCoverState(profile: row.profile, stockCondition: row),
  ];
  summaries.add(
    PlantAssetClassSummary(
      assetClass: cover,
      assets: const [],
      innerCovers: covers,
    ),
  );
  return PlantAssetOverview(
    classes: summaries,
    assets: rows,
    innerCovers: covers,
    hasQualifiedInnerCoverInventory: true,
    innerCoverStock: stock,
  );
}
