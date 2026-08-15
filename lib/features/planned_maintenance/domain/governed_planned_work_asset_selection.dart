import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../maintenance/data/maintenance_model.dart';

class GovernedPlannedWorkAssetRoute {
  const GovernedPlannedWorkAssetRoute({
    required this.assetType,
    required this.templateReference,
    required this.physicalAssetClass,
    required this.innerCoverByBase,
    this.fixedAssetInstanceId,
    this.blockingReason,
  });

  final AssetType assetType;
  final AssetHierarchyReference? templateReference;
  final AssetClassRecord? physicalAssetClass;
  final bool innerCoverByBase;
  final String? fixedAssetInstanceId;
  final String? blockingReason;

  bool get isAvailable => physicalAssetClass != null && blockingReason == null;
}

GovernedPlannedWorkAssetRoute resolveGovernedPlannedWorkAssetRoute({
  required AssetType assetType,
  required AssetHierarchyReference? templateReference,
  required Iterable<AssetClassRecord> allClasses,
}) {
  final classes = allClasses.toList(growable: false);
  final referenceClassResult = _referenceClass(
    assetType: assetType,
    reference: templateReference,
    classes: classes,
  );
  if (referenceClassResult.blockingReason != null) {
    return GovernedPlannedWorkAssetRoute(
      assetType: assetType,
      templateReference: templateReference,
      physicalAssetClass: null,
      innerCoverByBase: assetType == AssetType.innerCover,
      blockingReason: referenceClassResult.blockingReason,
    );
  }

  if (assetType == AssetType.innerCover) {
    final baseClasses = classes
        .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
        .toList(growable: false);
    if (baseClasses.length != 1) {
      return GovernedPlannedWorkAssetRoute(
        assetType: assetType,
        templateReference: templateReference,
        physicalAssetClass: null,
        innerCoverByBase: true,
        blockingReason:
            baseClasses.isEmpty
                ? 'No active governed Base class is available for Inner Cover positioning.'
                : 'More than one active governed Base class exists. Reconcile the class register first.',
      );
    }
    if (templateReference?.assetInstanceId != null) {
      return GovernedPlannedWorkAssetRoute(
        assetType: assetType,
        templateReference: templateReference,
        physicalAssetClass: null,
        innerCoverByBase: true,
        blockingReason:
            'An Inner Cover template fixed to one physical instance cannot be assigned by Base position.',
      );
    }
    return GovernedPlannedWorkAssetRoute(
      assetType: assetType,
      templateReference: templateReference,
      physicalAssetClass: baseClasses.single,
      innerCoverByBase: true,
    );
  }

  final compatibleClasses = classes
      .where((item) => item.isActive && _isCompatible(item, assetType))
      .toList(growable: false);
  final referenceClass = referenceClassResult.assetClass;
  if (referenceClass != null) {
    if (assetType != AssetType.governedCustom &&
        compatibleClasses.length != 1) {
      return GovernedPlannedWorkAssetRoute(
        assetType: assetType,
        templateReference: templateReference,
        physicalAssetClass: null,
        innerCoverByBase: false,
        blockingReason:
            'More than one active governed class matches ${_assetTypeLabel(assetType)}. Reconcile the class register before assignment.',
      );
    }
    return GovernedPlannedWorkAssetRoute(
      assetType: assetType,
      templateReference: templateReference,
      physicalAssetClass: referenceClass,
      innerCoverByBase: false,
      fixedAssetInstanceId: templateReference?.assetInstanceId,
    );
  }
  if (assetType == AssetType.governedCustom) {
    return GovernedPlannedWorkAssetRoute(
      assetType: assetType,
      templateReference: templateReference,
      physicalAssetClass: null,
      innerCoverByBase: false,
      blockingReason:
          'This governed custom template has no published asset-class reference.',
    );
  }
  if (compatibleClasses.length != 1) {
    return GovernedPlannedWorkAssetRoute(
      assetType: assetType,
      templateReference: templateReference,
      physicalAssetClass: null,
      innerCoverByBase: false,
      blockingReason:
          compatibleClasses.isEmpty
              ? 'No active governed asset class matches ${_assetTypeLabel(assetType)}.'
              : 'More than one active governed class matches ${_assetTypeLabel(assetType)}. Publish an exact class reference or reconcile the class register.',
    );
  }
  return GovernedPlannedWorkAssetRoute(
    assetType: assetType,
    templateReference: templateReference,
    physicalAssetClass: compatibleClasses.single,
    innerCoverByBase: false,
  );
}

List<AssetInstanceRecord> eligiblePlannedWorkAssets({
  required GovernedPlannedWorkAssetRoute route,
  required Iterable<AssetInstanceRecord> assets,
}) {
  final classId = route.physicalAssetClass?.id;
  if (!route.isAvailable || classId == null) return const [];
  final eligible =
      assets
          .where(
            (item) =>
                item.isActive &&
                item.assetClassId == classId &&
                (route.fixedAssetInstanceId == null ||
                    item.id == route.fixedAssetInstanceId),
          )
          .toList();
  eligible.sort((left, right) {
    final numberOrder = left.assetNumber.compareTo(right.assetNumber);
    return numberOrder != 0
        ? numberOrder
        : left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
  return List<AssetInstanceRecord>.unmodifiable(eligible);
}

({AssetClassRecord? assetClass, String? blockingReason}) _referenceClass({
  required AssetType assetType,
  required AssetHierarchyReference? reference,
  required List<AssetClassRecord> classes,
}) {
  if (reference == null) return (assetClass: null, blockingReason: null);
  final matches = classes
      .where((item) => item.id == reference.assetClassId)
      .toList(growable: false);
  if (matches.length != 1) {
    return (
      assetClass: null,
      blockingReason:
          matches.isEmpty
              ? 'The template asset class is no longer present in the governed register.'
              : 'The governed register contains duplicate template asset-class identities.',
    );
  }
  final assetClass = matches.single;
  if (!assetClass.isActive) {
    return (
      assetClass: null,
      blockingReason: 'The template asset class is no longer active.',
    );
  }
  if (!_isCompatible(assetClass, assetType)) {
    return (
      assetClass: null,
      blockingReason:
          'The published template asset class does not match ${_assetTypeLabel(assetType)}.',
    );
  }
  return (assetClass: assetClass, blockingReason: null);
}

bool _isCompatible(AssetClassRecord assetClass, AssetType assetType) =>
    assetType == AssetType.governedCustom
        ? assetClass.legacyAssetTypeKey == null
        : assetClass.legacyAssetTypeKey == assetType.name;

String _assetTypeLabel(AssetType assetType) => switch (assetType) {
  AssetType.base => 'Base',
  AssetType.furnace => 'Furnace',
  AssetType.forceCooler => 'Forced Cooler',
  AssetType.innerCover => 'Inner Cover',
  AssetType.governedCustom => 'the governed custom target',
};
