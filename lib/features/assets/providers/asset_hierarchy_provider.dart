import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/asset_hierarchy_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../repositories/asset_hierarchy_repository.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../../core/persistence/durable_submission.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/asset_registry_submission_controller.dart';

final assetRegistrySubmissionControllerProvider =
    Provider<AssetRegistrySubmissionController>((ref) {
      return AssetRegistrySubmissionController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        repository: ref.watch(assetHierarchyRepositoryProvider),
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) throw AssetHierarchyException(access.message);
          return access.actor!;
        },
        requireCapability: (uid) async {
          await const CommandCapabilityService().requireCapabilities(
            callableName: assetHierarchyV2CallableName,
            originActorUid: uid,
            requiredCapabilities: const {
              'assetHierarchy.v2',
              'assetRegistry.durable.v1',
            },
          );
        },
      );
    });

final savedRegistryChangesProvider = StreamProvider<List<DurableSubmission>>((
  ref,
) {
  final access = CurrentActorAccess.resolve(ref.watch(currentAppUserProvider));
  if (!access.isReady) return Stream.value(const []);
  return ref
      .watch(durableSubmissionRepositoryProvider)
      .watchForActor(access.actor!.uid)
      .map(
        (rows) => rows
            .where(
              (row) =>
                  row.resourceKey ==
                      AssetRegistrySubmissionController.resource &&
                  (row.state.isUnresolved ||
                      row.state == DurableSubmissionState.rejected),
            )
            .toList(),
      );
});

final Provider<AssetHierarchyRepository> assetHierarchyRepositoryProvider =
    Provider<AssetHierarchyRepository>((ref) {
      return AssetHierarchyRepository(
        submitRegistry: (request, actor) => ref
            .read(assetRegistrySubmissionControllerProvider)
            .submit(request, actor),
      );
    });

final assetClassesProvider = StreamProvider<List<AssetClassRecord>>((ref) {
  return ref.watch(assetHierarchyRepositoryProvider).watchAssetClasses();
});

final assetHierarchyNodesProvider = StreamProvider.autoDispose
    .family<List<AssetHierarchyNode>, String>((ref, assetClassId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchNodes(assetClassId);
    });

final assetInstancesProvider = StreamProvider.autoDispose
    .family<List<AssetInstanceRecord>, String>((ref, assetClassId) {
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

final installedComponentsProvider = StreamProvider.autoDispose
    .family<List<InstalledComponentRecord>, String>((ref, assetInstanceId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInstalledComponents(assetInstanceId);
    });

final installedComponentHistoryProvider = StreamProvider.autoDispose
    .family<List<InstalledComponentLifecycleAudit>, String>((
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

final innerCoverProfileBatchProvider =
    StreamProvider<DecodedSnapshotBatch<InnerCoverProfile>>((ref) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverProfileBatches();
    });

final innerCoverAssignmentsProvider =
    StreamProvider<List<BaseInnerCoverAssignment>>((ref) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverAssignments();
    });

final innerCoverAssignmentBatchProvider =
    StreamProvider<DecodedSnapshotBatch<BaseInnerCoverAssignment>>((ref) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverAssignmentBatches();
    });

final innerCoverHistoryProvider = StreamProvider.autoDispose
    .family<List<InnerCoverLinkage>, String>((ref, innerCoverId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverHistory(innerCoverId);
    });

final baseInnerCoverHistoryProvider = StreamProvider.autoDispose
    .family<List<InnerCoverLinkage>, String>((ref, baseId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchBaseInnerCoverHistory(baseId);
    });

final innerCoverFabricationProvider = StreamProvider.autoDispose
    .family<InnerCoverFabricationDossier?, String>((ref, innerCoverId) {
      return ref
          .watch(assetHierarchyRepositoryProvider)
          .watchInnerCoverFabrication(innerCoverId);
    });
