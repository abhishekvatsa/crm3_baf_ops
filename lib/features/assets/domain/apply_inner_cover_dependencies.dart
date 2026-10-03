import '../../reports/domain/base_inner_cover_register.dart';
import 'inner_cover_dependencies.dart';
import 'plant_asset_overview.dart';
import 'inner_cover_stock_summary.dart';

/// Adds serial-specific concerns to their verified current host. Recorded host
/// work is deliberately retained: its historical job obligation is not an
/// authorization to transfer work or subtract equipment counters after a move.
PlantAssetOverview applyInnerCoverDependencies({
  required PlantAssetOverview overview,
  required BaseInnerCoverRegister register,
  required InnerCoverDependencies dependencies,
}) {
  final warnings = <String>{
    ...overview.evidenceWarnings,
    ...dependencies.evidenceWarnings,
  };
  final covers = overview.innerCovers
      .map((cover) {
        final dependency = dependencies.byCoverId[cover.profile.id];
        final identityMatches =
            dependency != null &&
            dependency.serialNumber == cover.profile.serialNumber;
        final rowWarnings = <String>{
          ...cover.evidenceWarnings,
          if (!identityMatches)
            'Inner Cover work identity is missing or conflicting.',
          if (identityMatches) ...dependency.warnings,
          if (identityMatches && !dependency.complete)
            'Current Inner Cover issue and maintenance evidence is unverified.',
        }.toList()..sort();
        warnings.addAll(
          rowWarnings.map(
            (w) => 'Inner Cover ${cover.profile.serialNumber}: $w',
          ),
        );
        return PlantInnerCoverState(
          profile: cover.profile,
          dependency: identityMatches ? dependency : null,
          stockCondition: cover.stockCondition,
          evidenceWarnings: List.unmodifiable(rowWarnings),
        );
      })
      .toList(growable: false);
  final coverById = {for (final cover in covers) cover.profile.id: cover};
  final byBase = <String, InnerCoverDependencyState>{};
  final baseWarnings = <String, Set<String>>{};
  for (final row in register.rows) {
    if (row.state == BaseCoverLinkState.unknown ||
        row.state == BaseCoverLinkState.inconsistent) {
      baseWarnings
          .putIfAbsent(row.base.id, () => {})
          .add(
            'Current Inner Cover linkage and its restrictions need verification.',
          );
      continue;
    }
    if (!register.evidenceConfirmed ||
        row.state != BaseCoverLinkState.linked ||
        row.cover == null ||
        row.assignment == null ||
        row.linkage == null) {
      continue;
    }
    final cover = coverById[row.cover!.id];
    if (cover == null ||
        cover.dependency == null ||
        cover.profile.serialNumber != row.cover!.serialNumber) {
      baseWarnings
          .putIfAbsent(row.base.id, () => {})
          .add('The linked Inner Cover work identity is unverified.');
      continue;
    }
    byBase[row.base.id] = cover.dependency!;
    if (cover.dependency!.needsCurrentAssessment) {
      baseWarnings
          .putIfAbsent(row.base.id, () => {})
          .add(
            'Linked Inner Cover ${cover.profile.serialNumber}: current fitness assessment required for an unresolved confirmed-bulging concern.',
          );
    }
    if (cover.evidenceWarnings.isNotEmpty || !cover.dependency!.complete) {
      baseWarnings
          .putIfAbsent(row.base.id, () => {})
          .add(
            'Linked Inner Cover ${cover.profile.serialNumber}: issue/maintenance evidence is unverified.',
          );
    }
  }
  // Preserve work at its original installation. A new linkage is not authority
  // to transfer the job or clear the former host's independent restrictions.
  for (final dependency in dependencies.byCoverId.values) {
    for (final reason in dependency.reasons) {
      final originalRows = register.rows
          .where((row) => row.base.id == reason.eventHostAssetId)
          .toList();
      final row = originalRows.length == 1 ? originalRows.single : null;
      String? warning;
      if (!register.evidenceConfirmed ||
          row == null ||
          row.state == BaseCoverLinkState.unknown ||
          row.state == BaseCoverLinkState.inconsistent) {
        warning =
            'Inner Cover ${dependency.serialNumber}: current linkage and recorded work association need verification.';
      } else if (row.state == BaseCoverLinkState.empty ||
          row.cover?.id != dependency.coverId) {
        warning =
            'Inner Cover ${dependency.serialNumber} is no longer linked here; recorded work remains pending reconciliation.';
      } else if (row.linkage?.id != reason.eventLinkageId) {
        warning =
            'Inner Cover ${dependency.serialNumber} has a different installation linkage; earlier work remains pending reconciliation.';
      }
      if (warning != null) {
        baseWarnings
            .putIfAbsent(reason.eventHostAssetId, () => {})
            .add(warning);
      }
    }
  }
  final assets = overview.assets
      .map((state) {
        final rowWarnings = <String>{
          ...state.evidenceWarnings,
          ...?baseWarnings[state.asset.id],
        }.toList()..sort();
        warnings.addAll(rowWarnings.map((w) => 'Asset ${state.asset.id}: $w'));
        return PlantAssetState(
          asset: state.asset,
          operationalCondition: state.operationalCondition,
          availability: state.availability,
          workflowStatus: state.workflowStatus,
          issueConditionContributions: state.issueConditionContributions,
          permitsManualChange: state.permitsManualChange,
          evidenceWarnings: List.unmodifiable(rowWarnings),
          linkedInnerCoverDependency: byBase[state.asset.id],
        );
      })
      .toList(growable: false);
  return PlantAssetOverview(
    assets: List.unmodifiable(assets),
    physicalInventoryComplete: overview.physicalInventoryComplete,
    innerCovers: List.unmodifiable(covers),
    evidenceWarnings: List.unmodifiable(warnings.toList()..sort()),
    innerCoverEvidenceWarnings: overview.innerCoverEvidenceWarnings,
    hasQualifiedInnerCoverInventory: overview.hasQualifiedInnerCoverInventory,
    baseCoverReconciliation: overview.baseCoverReconciliation,
    innerCoverStock: overview.innerCoverStock == null
        ? null
        : annotateInnerCoverStockDependencies(
            overview.innerCoverStock!,
            dependencies,
          ),
    classes: [
      for (final cls in overview.classes)
        PlantAssetClassSummary(
          assetClass: cls.assetClass,
          inventoryComplete: cls.inventoryComplete,
          assets: assets
              .where((a) => a.asset.assetClassId == cls.assetClass.id)
              .toList(),
          innerCovers: covers
              .where((c) => c.profile.assetClassId == cls.assetClass.id)
              .toList(),
        ),
    ],
  );
}
