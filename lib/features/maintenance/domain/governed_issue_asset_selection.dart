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
