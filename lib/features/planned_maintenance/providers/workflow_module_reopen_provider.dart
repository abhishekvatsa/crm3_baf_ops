import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/durable_submission.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../services/workflow_module_reopen_controller.dart';
import 'job_module_provider.dart';

Future<Map<String, dynamic>?> readWorkflowModuleDocumentFromServer(
  String collection,
  String id,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection(collection)
      .doc(id)
      .get(const GetOptions(source: Source.server));
  if (snapshot.metadata.isFromCache) {
    throw StateError('Fresh server confirmation is unavailable.');
  }
  return snapshot.data();
}

final workflowModuleReopenControllerProvider =
    Provider<WorkflowModuleReopenController>((ref) {
      const capabilities = CommandCapabilityService();
      return WorkflowModuleReopenController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        gateway: const FirebaseWorkflowCommandGateway(),
        modules: ref.watch(jobModuleRepositoryProvider),
        readDocument: readWorkflowModuleDocumentFromServer,
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) throw StateError(access.message);
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
final pendingWorkflowModuleReopenProvider = FutureProvider.autoDispose
    .family<DurableSubmission?, String>((ref, id) {
      final access = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      );
      if (!access.isReady || !access.actor!.canReopenJobModule) return null;
      return ref.watch(workflowModuleReopenControllerProvider).restore(id);
    });
