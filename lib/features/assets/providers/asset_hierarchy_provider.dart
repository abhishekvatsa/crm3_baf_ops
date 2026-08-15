import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_hierarchy_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../repositories/asset_hierarchy_repository.dart';

final assetHierarchyRepositoryProvider = Provider<AssetHierarchyRepository>((
  ref,
) {
  return AssetHierarchyRepository();
});

final assetClassesProvider = StreamProvider<List<AssetClassRecord>>((ref) {
  return ref.watch(assetHierarchyRepositoryProvider).watchAssetClasses();
});

final assetHierarchyNodesProvider = StreamProvider.family<
  List<AssetHierarchyNode>,
  String
>((ref, assetClassId) {
  return ref.watch(assetHierarchyRepositoryProvider).watchNodes(assetClassId);
});

final assetInstancesProvider =
    StreamProvider.family<List<AssetInstanceRecord>, String>((
      ref,
      assetClassId,
    ) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchAssetInstances(assetClassId);
    });

final allAssetInstancesProvider = StreamProvider<List<AssetInstanceRecord>>((
  ref,
) {
  return ref.watch(assetHierarchyRepositoryProvider).watchAllAssetInstances();
});

final assetOperationalConditionsProvider =
    StreamProvider<List<AssetOperationalConditionRecord>>((ref) {
      return ref.watch(assetHierarchyRepositoryProvider).watchAssetConditions();
    });

final installedComponentsProvider =
    StreamProvider.family<List<InstalledComponentRecord>, String>((
      ref,
      assetInstanceId,
    ) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInstalledComponents(assetInstanceId);
    });

final installedComponentHistoryProvider =
    StreamProvider.family<List<InstalledComponentLifecycleAudit>, String>((
      ref,
      assetInstanceId,
    ) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInstalledComponentHistory(assetInstanceId);
    });

final innerCoverProfilesProvider = StreamProvider<List<InnerCoverProfile>>((
  ref,
) {
  return ref.watch(assetHierarchyRepositoryProvider).watchInnerCoverProfiles();
});

final innerCoverAssignmentsProvider =
    StreamProvider<List<BaseInnerCoverAssignment>>((ref) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverAssignments();
    });

final innerCoverHistoryProvider =
    StreamProvider.family<List<InnerCoverLinkage>, String>((ref, innerCoverId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverHistory(innerCoverId);
    });

final innerCoverFabricationProvider =
    StreamProvider.family<InnerCoverFabricationDossier?, String>((
      ref,
      innerCoverId,
    ) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverFabrication(innerCoverId);
    });
