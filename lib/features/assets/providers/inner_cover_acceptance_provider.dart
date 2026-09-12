import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/asset_hierarchy_repository.dart';
import '../services/inner_cover_acceptance_controller.dart';
import 'asset_hierarchy_provider.dart';

final innerCoverAcceptanceControllerProvider =
    Provider<InnerCoverAcceptanceController>((ref) {
      const capabilities = CommandCapabilityService();
      return InnerCoverAcceptanceController(
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
            requiredCapabilities: const {
              'assetHierarchy.v2',
              'innerCoverAcceptance.v1',
            },
          );
        },
      );
    });

final innerCoverAcceptancePendingProvider = FutureProvider.autoDispose
    .family<DurableSubmission?, String>((ref, coverId) {
      ref.watch(currentAppUserProvider);
      return ref.watch(innerCoverAcceptanceControllerProvider).restore(coverId);
    });
