import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/asset_hierarchy_repository.dart';
import '../services/asset_condition_submission_controller.dart';
import 'asset_hierarchy_provider.dart';

final assetConditionSubmissionControllerProvider =
    Provider<AssetConditionSubmissionController>((ref) {
      const capabilities = CommandCapabilityService();
      return AssetConditionSubmissionController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        repository: ref.watch(assetHierarchyRepositoryProvider),
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) throw AssetHierarchyException(access.message);
          return access.actor!;
        },
        requireCapability: (actorUid) async {
          await capabilities.requireCapabilities(
            callableName: assetHierarchyV2CallableName,
            originActorUid: actorUid,
            requiredCapabilities: const {'assetHierarchy.v2'},
          );
        },
      );
    });

final assetConditionPendingProvider = FutureProvider.autoDispose
    .family<DurableSubmission?, String>((ref, assetInstanceId) {
      ref.watch(currentAppUserProvider);
      return ref
          .watch(assetConditionSubmissionControllerProvider)
          .pending(assetInstanceId);
    });
