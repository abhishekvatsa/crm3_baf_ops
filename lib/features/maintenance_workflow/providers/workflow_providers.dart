import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/app_database.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_event_record.dart';
import '../domain/workflow_command_contract.dart';
import '../domain/workflow_models.dart';
import '../repositories/firestore_workflow_read_repository.dart';
import '../repositories/isar_workflow_repository.dart';
import '../repositories/workflow_repository.dart';
import '../services/workflow_aggregate_service.dart';
import '../services/workflow_command_gateway.dart';
import '../services/workflow_online_executor.dart';
import '../services/workflow_pull_service.dart';
import '../services/workflow_uncertain_retry_service.dart';

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  return IsarWorkflowRepository(isar);
});

final firestoreWorkflowReadRepositoryProvider =
    Provider<FirestoreWorkflowReadRepository>((ref) {
      return FirestoreWorkflowReadRepository(FirebaseFirestore.instance);
    });

final workflowCommandGatewayProvider = Provider<WorkflowCommandGateway>((ref) {
  return const FirebaseWorkflowCommandGateway();
});

final workflowOnlineExecutorProvider = Provider<WorkflowOnlineExecutor>((ref) {
  return WorkflowOnlineExecutor(
    connectivity: Connectivity(),
    gateway: ref.read(workflowCommandGatewayProvider),
    repository: ref.read(workflowRepositoryProvider),
    now: DateTime.now,
  );
});

final workflowPullServiceProvider = Provider<WorkflowPullService>((ref) {
  return WorkflowPullService(
    remote: ref.read(firestoreWorkflowReadRepositoryProvider),
    local: ref.read(workflowRepositoryProvider),
  );
});

final workflowUncertainRetryServiceProvider =
    Provider<WorkflowUncertainRetryService>((ref) {
      return WorkflowUncertainRetryService(
        repository: ref.read(workflowRepositoryProvider),
        executor: ref.read(workflowOnlineExecutorProvider),
        now: DateTime.now,
      );
    });

final workflowAggregateServiceProvider = Provider<WorkflowAggregateService>((
  ref,
) {
  return WorkflowAggregateService(ref.read(workflowRepositoryProvider));
});

final workflowAggregateProvider =
    FutureProvider.family<WorkflowAggregateSnapshot?, String>((
      ref,
      workflowId,
    ) {
      return ref.watch(workflowAggregateServiceProvider).load(workflowId);
    });

final workflowRecordProvider =
    StreamProvider.family<WorkflowAggregateRecord?, String>((ref, workflowId) {
      return ref.watch(workflowRepositoryProvider).watchWorkflow(workflowId);
    });

final workflowLanesProvider =
    StreamProvider.family<List<JobLaneRecord>, String>((ref, workflowId) {
      return ref.watch(workflowRepositoryProvider).watchLanes(workflowId);
    });

final workflowAllLanesProvider = StreamProvider<List<JobLaneRecord>>((ref) {
  return ref.watch(workflowRepositoryProvider).watchAllLanes();
});

final workflowComplianceProvider =
    StreamProvider.family<List<ComplianceRequestRecord>, String>((
      ref,
      workflowId,
    ) {
      return ref.watch(workflowRepositoryProvider).watchCompliance(workflowId);
    });

final workflowEventsProvider =
    StreamProvider.family<List<WorkflowEventRecord>, String>((ref, workflowId) {
      return ref.watch(workflowRepositoryProvider).watchEvents(workflowId);
    });

final workflowComplianceInboxProvider = StreamProvider.family<
  List<ComplianceRequestRecord>,
  String
>((ref, laneKey) {
  return ref.watch(workflowRepositoryProvider).watchComplianceInbox(laneKey);
});

final workflowAllComplianceProvider =
    StreamProvider<List<ComplianceRequestRecord>>((ref) {
      return ref.watch(workflowRepositoryProvider).watchAllCompliance();
    });

final workflowComplianceRecordProvider = FutureProvider.autoDispose
    .family<ComplianceRequestRecord?, String>((ref, complianceId) async {
      final id = complianceId.trim();
      if (id.isEmpty) return null;

      final repository = ref.watch(workflowRepositoryProvider);
      final local = await repository.getComplianceById(id);
      if (local != null) return local;

      await ref.read(workflowPullServiceProvider).pull();
      return repository.getComplianceById(id);
    });

final equipmentStatusProvider = StreamProvider.family<
  List<EquipmentStatusRecord>,
  String?
>((ref, stateKey) {
  return ref.watch(workflowRepositoryProvider).watchEquipmentByState(stateKey);
});

class WorkflowCommandController
    extends StateNotifier<AsyncValue<WorkflowCommandReceipt?>> {
  WorkflowCommandController(
    WorkflowOnlineExecutor executor,
    WorkflowPullService pullService,
  ) : _executeCommand = executor.execute,
      _pullProjections = (() async {
        await pullService.pull();
      }),
      super(const AsyncData(null));

  WorkflowCommandController.forTesting({
    required Future<WorkflowCommandReceipt> Function(WorkflowCommand command)
    executeCommand,
    required Future<void> Function() pullProjections,
  }) : _executeCommand = executeCommand,
       _pullProjections = pullProjections,
       super(const AsyncData(null));

  final Future<WorkflowCommandReceipt> Function(WorkflowCommand command)
  _executeCommand;
  final Future<void> Function() _pullProjections;

  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    state = const AsyncLoading();
    late final WorkflowCommandReceipt receipt;
    try {
      receipt = await _executeCommand(command);
    } catch (error, stackTrace) {
      try {
        await _pullProjections();
      } catch (_) {
        // Preserve the original command failure; reconciliation is best effort.
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }

    state = AsyncData(receipt);
    try {
      await _pullProjections();
    } catch (_) {
      // The receipt proves that the command succeeded. Projection refresh is
      // independent and will retry through normal synchronization.
    }
    return receipt;
  }
}

final workflowCommandControllerProvider = StateNotifierProvider<
  WorkflowCommandController,
  AsyncValue<WorkflowCommandReceipt?>
>((ref) {
  return WorkflowCommandController(
    ref.read(workflowOnlineExecutorProvider),
    ref.read(workflowPullServiceProvider),
  );
});
