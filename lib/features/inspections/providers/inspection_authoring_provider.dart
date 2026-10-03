import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/release/command_capability_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';

const inspectionV2AuthoringCapability = 'inspectionReadingsV2.authoring.v1';
const inspectionV2AuthoringUnavailableMessage =
    'New labelled-reading definitions and programmes are not enabled yet. '
    'Existing inspection records remain available.';

/// Each explicit v2 save checks the executable server again. This optional
/// capability is not needed for scalar definitions or existing campaign work.
final inspectionAuthoringCapabilityServiceProvider =
    Provider<CommandCapabilityService>(
      (ref) => const CommandCapabilityService(),
    );

final inspectionV2AuthoringCapabilityProvider =
    Provider<Future<void> Function(String)>((ref) {
      final service = ref.watch(inspectionAuthoringCapabilityServiceProvider);
      return (originUid) async {
        void requireCurrentActor() {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady || access.actor!.uid != originUid) {
            throw const CommandCapabilityException(
              'inspection-authoring-account-unverified',
              'Verify your account before creating a new inspection contract. Your entries are retained.',
            );
          }
        }

        requireCurrentActor();
        try {
          await service.requireCapabilities(
            callableName: maintenanceWorkflowV2CallableName,
            originActorUid: originUid,
            requiredCapabilities: const {inspectionV2AuthoringCapability},
          );
        } on CommandCapabilityException catch (error) {
          if (error.code == 'command-capability-unavailable') {
            throw const CommandCapabilityException(
              'inspection-v2-authoring-unavailable',
              inspectionV2AuthoringUnavailableMessage,
            );
          }
          rethrow;
        }
        requireCurrentActor();
      };
    });

/// Dialog-scoped, actor-bound UI hint. Loading, failed or retained old results
/// never enable controls; the independent server gate remains authoritative.
final inspectionV2AuthoringAvailabilityProvider =
    FutureProvider.autoDispose<String?>((ref) async {
      final access = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      );
      if (!access.isReady) return null;
      final uid = access.actor!.uid;
      await ref.watch(inspectionV2AuthoringCapabilityProvider)(uid);
      return uid;
    });

bool inspectionV2AuthoringAvailable(
  AsyncValue<String?> availability,
  AsyncValue<AppUser?> actor,
) {
  final access = CurrentActorAccess.resolve(actor);
  return !availability.isLoading &&
      !availability.hasError &&
      access.isReady &&
      availability.valueOrNull == access.actor!.uid;
}

String inspectionV2AuthoringStatusMessage(AsyncValue<String?> availability) {
  if (availability.isLoading) {
    return 'Checking whether new labelled-reading authoring is enabled. Existing inspection records remain available.';
  }
  if (availability.hasError) {
    final error = availability.error;
    if (error is! CommandCapabilityException ||
        error.code != 'inspection-v2-authoring-unavailable') {
      return 'Server support for new labelled-reading authoring could not be checked. Your entries and existing records are retained.';
    }
  }
  return inspectionV2AuthoringUnavailableMessage;
}
