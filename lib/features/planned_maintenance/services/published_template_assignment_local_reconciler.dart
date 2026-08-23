import '../providers/job_module_provider.dart';
import '../providers/planned_maintenance_provider.dart';
import 'published_template_assignment_server_service.dart';

class PublishedTemplateAssignmentLocalReconciler {
  const PublishedTemplateAssignmentLocalReconciler({
    required this.plannedRepository,
    required this.moduleRepository,
  });

  final PlannedMaintenanceRepository plannedRepository;
  final JobModuleRepository moduleRepository;

  Future<void> persist(PublishedTemplateAssignmentServerResult result) async {
    final executionFirestoreId = result.execution.firestoreId!;
    final existingExecution = await plannedRepository.getExecutionByFirestoreId(
      executionFirestoreId,
    );
    if (existingExecution == null) {
      await plannedRepository.insertExecutionFromRemote(result.execution);
    } else {
      result.execution.id = existingExecution.id;
      await plannedRepository.updateExecutionFromRemote(result.execution);
    }

    final localExecution = await plannedRepository.getExecutionByFirestoreId(
      executionFirestoreId,
    );
    if (localExecution == null) {
      throw StateError(
        'The server-created JobExecution could not be reconciled into the local store.',
      );
    }

    final moduleFirestoreIds = result.modules
        .map((module) => module.firestoreId!)
        .toList(growable: false);
    final existingModules = await moduleRepository.getModulesByFirestoreIds(
      moduleFirestoreIds,
    );
    final existingModuleIds = <String, int>{
      for (final module in existingModules)
        if (module.firestoreId != null) module.firestoreId!: module.id,
    };

    for (final module in result.modules) {
      final firestoreId = module.firestoreId!;
      final existingLocalId = existingModuleIds[firestoreId];
      module
        ..jobExecutionFirestoreId = executionFirestoreId
        ..jobExecutionLocalId = null
        ..isSynced = true;
      if (existingLocalId == null) {
        await moduleRepository.insertModuleFromRemote(module);
        continue;
      }
      module.id = existingLocalId;
      await moduleRepository.updateModuleFromRemote(module);
    }
  }
}
