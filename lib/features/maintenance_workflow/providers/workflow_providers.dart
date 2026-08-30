import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/app_database.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_event_record.dart';
import '../domain/compliance_visibility_policy.dart';
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

final workflowProjectionRefreshProvider = Provider<Future<void> Function()>((
  ref,
) {
  Future<void>? inFlight;
  return () {
    final current = inFlight;
    if (current != null) return current;

    final refresh = ref
        .read(workflowPullServiceProvider)
        .pull()
        .then<void>((_) {});
    return inFlight = refresh.whenComplete(() => inFlight = null);
  };
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

final class WorkflowAttentionSummary {
  final int activeLaneCount;
  final int activeComplianceCount;

  const WorkflowAttentionSummary({
    required this.activeLaneCount,
    required this.activeComplianceCount,
  });

  int get total => activeLaneCount + activeComplianceCount;
}

WorkflowAttentionSummary summarizeWorkflowAttention({
  required AppUser actor,
  required Iterable<JobLaneRecord> lanes,
  required Iterable<ComplianceRequestRecord> compliance,
}) {
  if (!actor.isApproved) {
    return const WorkflowAttentionSummary(
      activeLaneCount: 0,
      activeComplianceCount: 0,
    );
  }

  final activeLaneCount =
      lanes
          .where(
            (lane) =>
                !lane.isDeleted &&
                (lane.statusKey == 'pending' ||
                    lane.statusKey == 'acknowledged') &&
                actor.canAcknowledgeOrWorkMaintenanceLane(lane.laneKey),
          )
          .length;
  final activeComplianceCount =
      compliance
          .where(
            (request) =>
                !request.isDeleted &&
                (request.statusKey == 'raised' ||
                    request.statusKey == 'acknowledged' ||
                    request.statusKey == 'complied') &&
                isComplianceRequestRelevantToUser(request, actor),
          )
          .length;

  return WorkflowAttentionSummary(
    activeLaneCount: activeLaneCount,
    activeComplianceCount: activeComplianceCount,
  );
}

typedef WorkflowComplianceRecordScope =
    ({String actorUid, String complianceId});
typedef WorkflowServerRecordScope = ({String actorUid, String workflowId});
typedef WorkflowCompliancePointReader =
    Future<ComplianceRequestRecord?> Function(String complianceId);
typedef WorkflowAggregatePointReader =
    Future<WorkflowAggregateRecord?> Function(String workflowId);
typedef ActorSessionComplianceLookup =
    ({bool isTrusted, ComplianceRequestRecord? record});

final workflowCompliancePointReaderProvider =
    Provider<WorkflowCompliancePointReader>((ref) {
      return ref
          .watch(firestoreWorkflowReadRepositoryProvider)
          .fetchComplianceById;
    });

final workflowAggregatePointReaderProvider =
    Provider<WorkflowAggregatePointReader>((ref) {
      return ref
          .watch(firestoreWorkflowReadRepositoryProvider)
          .fetchWorkflowById;
    });

final workflowComplianceSessionCacheProvider =
    Provider<ActorSessionComplianceCache>((ref) {
      final cache = ActorSessionComplianceCache();

      void observeAuthority(AsyncValue<AppUser?> authority) {
        if (authority.isLoading || authority.hasError) {
          cache.observeActor(null);
          return;
        }
        final actor = authority.value;
        cache.observeActor(
          actor != null && actor.isApproved ? actor.uid : null,
        );
      }

      observeAuthority(ref.read(currentAppUserProvider));
      ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (_, next) {
        observeAuthority(next);
      });
      return cache;
    });

@visibleForTesting
final class ActorSessionComplianceCache {
  String? _actorUid;
  final Set<String> _confirmedIds = <String>{};
  final Map<String, ComplianceRequestRecord?> _records =
      <String, ComplianceRequestRecord?>{};

  void observeActor(String? actorUid) {
    final normalized = actorUid?.trim();
    final nextActor =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (nextActor == _actorUid) return;
    _actorUid = nextActor;
    _confirmedIds.clear();
    _records.clear();
  }

  bool remember({
    required String actorUid,
    required String complianceId,
    required ComplianceRequestRecord? record,
  }) {
    final normalizedActor = actorUid.trim();
    final normalizedId = complianceId.trim();
    if (normalizedActor.isEmpty ||
        normalizedId.isEmpty ||
        normalizedActor != _actorUid) {
      return false;
    }
    _confirmedIds.add(normalizedId);
    _records[normalizedId] = record;
    return true;
  }

  ActorSessionComplianceLookup lookup({
    required String actorUid,
    required String complianceId,
  }) {
    final normalizedActor = actorUid.trim();
    final normalizedId = complianceId.trim();
    final isTrusted =
        normalizedActor.isNotEmpty &&
        normalizedActor == _actorUid &&
        _confirmedIds.contains(normalizedId);
    return (
      isTrusted: isTrusted,
      record: isTrusted ? _records[normalizedId] : null,
    );
  }
}

final workflowComplianceRecordProvider = FutureProvider.autoDispose.family<
  ComplianceRequestRecord?,
  WorkflowComplianceRecordScope
>((ref, scope) async {
  final actorUid = scope.actorUid.trim();
  final id = scope.complianceId.trim();
  if (id.isEmpty) return null;
  _requireApprovedWorkflowActor(ref.watch(currentAppUserProvider), actorUid);
  final cache = ref.watch(workflowComplianceSessionCacheProvider);
  try {
    final remote = await ref.watch(workflowCompliancePointReaderProvider)(id);
    final record = remote?.isDeleted == true ? null : remote;
    if (!cache.remember(actorUid: actorUid, complianceId: id, record: record)) {
      throw StateError(
        'Compliance authority changed before the record was verified.',
      );
    }
    return record;
  } on FirebaseException catch (error) {
    if (!_isOfflineCompliancePointRead(error)) rethrow;
    final cached = cache.lookup(actorUid: actorUid, complianceId: id);
    if (!cached.isTrusted) {
      throw StateError(
        'This compliance record has not been server-verified for the current approved session.',
      );
    }
    return cached.record;
  }
});

final workflowAuthoritativeRecordProvider = FutureProvider.autoDispose.family<
  WorkflowAggregateRecord?,
  WorkflowServerRecordScope
>((ref, scope) async {
  final actorUid = scope.actorUid.trim();
  final id = scope.workflowId.trim();
  if (id.isEmpty) return null;
  _requireApprovedWorkflowActor(ref.watch(currentAppUserProvider), actorUid);
  return ref.watch(workflowAggregatePointReaderProvider)(id);
});

void _requireApprovedWorkflowActor(
  AsyncValue<AppUser?> authority,
  String actorUid,
) {
  final actor = authority.asData?.value;
  if (authority.isLoading ||
      authority.hasError ||
      actor == null ||
      !actor.isApproved ||
      actor.uid != actorUid ||
      actorUid.isEmpty) {
    throw StateError('Approved compliance access is required.');
  }
}

bool _isOfflineCompliancePointRead(FirebaseException error) =>
    error.code == 'unavailable' || error.code == 'deadline-exceeded';

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
