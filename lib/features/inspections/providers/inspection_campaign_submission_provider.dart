import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../domain/inspection_campaign_submission.dart';
import '../repositories/inspection_campaign_creation_reader.dart';
import '../services/inspection_campaign_submission_controller.dart';

final inspectionCampaignSubmissionControllerProvider =
    Provider<InspectionCampaignSubmissionController>((ref) {
      const capabilities = CommandCapabilityService();
      return InspectionCampaignSubmissionController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        gateway: const FirebaseWorkflowCommandGateway(),
        reader: InspectionCampaignCreationReader(),
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) {
            throw InspectionCampaignSubmissionException(access.message);
          }
          return access.actor!;
        },
        requireCapability: (actorUid) async {
          await capabilities.requireCapabilities(
            callableName: maintenanceWorkflowV2CallableName,
            originActorUid: actorUid,
            requiredCapabilities: const {'maintenanceWorkflow.v2'},
          );
        },
      );
    });

final pendingInspectionCampaignSubmissionProvider =
    FutureProvider.autoDispose<DurableSubmission?>((ref) {
      final access = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      );
      if (!access.isReady || !access.actor!.canManageInspectionCampaigns) {
        return null;
      }
      return ref
          .watch(inspectionCampaignSubmissionControllerProvider)
          .restore();
    });
