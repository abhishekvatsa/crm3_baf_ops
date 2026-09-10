import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../data/maintenance_model.dart';

class GovernedIssueAssetRoute {
  const GovernedIssueAssetRoute({
    required this.issueClass,
    required this.assetType,
    required this.physicalAssetClass,
    required this.innerCoverByBase,
    this.blockingReason,
  });

  final AssetClassRecord issueClass;
  final AssetType assetType;
  final AssetClassRecord? physicalAssetClass;
  final bool innerCoverByBase;
  final String? blockingReason;

  bool get isAvailable => physicalAssetClass != null && blockingReason == null;
}

List<AssetClassRecord> activeIssueAssetClasses(
  Iterable<AssetClassRecord> classes,
) {
  final active = classes.where((item) => item.isActive).toList();
  active.sort((left, right) {
    final nameOrder = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    return nameOrder != 0 ? nameOrder : left.code.compareTo(right.code);
  });
  return List<AssetClassRecord>.unmodifiable(active);
}

GovernedIssueAssetRoute resolveGovernedIssueAssetRoute({
  required AssetClassRecord issueClass,
  required Iterable<AssetClassRecord> allClasses,
}) {
  final assetType = _legacyAssetType(issueClass.legacyAssetTypeKey);
  if (!issueClass.isActive) {
    return GovernedIssueAssetRoute(
      issueClass: issueClass,
      assetType: assetType,
      physicalAssetClass: null,
      innerCoverByBase: false,
      blockingReason: 'The selected asset class is no longer active.',
    );
  }
  if (assetType != AssetType.innerCover) {
    return GovernedIssueAssetRoute(
      issueClass: issueClass,
      assetType: assetType,
      physicalAssetClass: issueClass,
      innerCoverByBase: false,
    );
  }

  final baseClasses = allClasses
      .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
      .toList(growable: false);
  if (baseClasses.length != 1) {
    return GovernedIssueAssetRoute(
      issueClass: issueClass,
      assetType: assetType,
      physicalAssetClass: null,
      innerCoverByBase: true,
      blockingReason:
          baseClasses.isEmpty
              ? 'No active governed Base class is available for Inner Cover positioning.'
              : 'More than one active governed Base class exists. Reconcile the class register first.',
    );
  }
  return GovernedIssueAssetRoute(
    issueClass: issueClass,
    assetType: assetType,
    physicalAssetClass: baseClasses.single,
    innerCoverByBase: true,
  );
}

List<AssetInstanceRecord> eligibleIssueAssets({
  required GovernedIssueAssetRoute route,
  required Iterable<AssetInstanceRecord> assets,
}) {
  final classId = route.physicalAssetClass?.id;
  if (!route.isAvailable || classId == null) return const [];
  final eligible =
      assets
          .where((item) => item.isActive && item.assetClassId == classId)
          .toList();
  eligible.sort((left, right) {
    final numberOrder = left.assetNumber.compareTo(right.assetNumber);
    return numberOrder != 0
        ? numberOrder
        : left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
  return List<AssetInstanceRecord>.unmodifiable(eligible);
}

AssetType _legacyAssetType(String? key) => switch (key) {
  'base' => AssetType.base,
  'furnace' => AssetType.furnace,
  'forceCooler' => AssetType.forceCooler,
  'innerCover' => AssetType.innerCover,
  _ => AssetType.governedCustom,
};

/// Resolves the issue asset route a submit should act on.
///
/// The live register is preferred, so a class that has genuinely been retired
/// is still caught. [retained] is what the picker resolved when the operator
/// chose it, and is used only when the register has nothing to say at all -
/// the class stream is re-subscribing or has errored.
///
/// Without that fallback a submit rejects a selection the operator can still
/// see on screen, which is what operators reported on Build 27: choose the
/// asset type and number, then be told to choose a governed asset.
GovernedIssueAssetRoute? resolveSelectedIssueAssetRoute({
  required String classId,
  required List<AssetClassRecord>? liveClasses,
  required GovernedIssueAssetRoute? retained,
}) {
  if (liveClasses != null) {
    final issueClass =
        liveClasses.where((item) => item.id == classId).firstOrNull;
    // The register loaded and the class is gone, so the selection really is
    // stale and must not be resurrected from a retained copy.
    if (issueClass == null) return null;
    return resolveGovernedIssueAssetRoute(
      issueClass: issueClass,
      allClasses: liveClasses,
    );
  }
  return retained?.issueClass.id == classId ? retained : null;
}

/// Resolves the exact physical asset a submit should act on.
///
/// [liveAssets] wins when present. When the instance stream has no value the
/// retained record is accepted, but only if it still satisfies what made it
/// eligible when it was offered. The server remains the final authority on
/// whether it is still eligible; refusing here only loses the operator's work.
AssetInstanceRecord? resolveSelectedPhysicalAsset({
  required String assetId,
  required String physicalClassId,
  required List<AssetInstanceRecord>? liveAssets,
  required AssetInstanceRecord? retained,
}) {
  bool eligible(AssetInstanceRecord asset) =>
      asset.id == assetId &&
      asset.isActive &&
      asset.assetClassId == physicalClassId;

  if (liveAssets != null) {
    return liveAssets.where(eligible).firstOrNull;
  }
  return retained != null && eligible(retained) ? retained : null;
}
