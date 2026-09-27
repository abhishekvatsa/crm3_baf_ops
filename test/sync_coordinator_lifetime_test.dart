import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/services/global_pull_service.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_run_guard.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_pull_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_uncertain_retry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a reconciled conflict without deferred stages is not a failed push',
    (tester) async {
      final owner = _Owner();
      addTearDown(owner.dispose);
      owner.pushConflicts = 1;
      expect(
        await owner.coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.succeeded,
      );
      final health = owner.container.read(syncRunHealthProvider);
      expect(health.conflictCount, 1);
      expect(health.failureCount, 0);
      expect(health.deferredStageCount, 0);
      expect(health.lastPartiallySucceeded, isFalse);
      owner.dispose();
    },
  );

  testWidgets('push failures still pull and remain partial until a clean run', (
    tester,
  ) async {
    final owner = _Owner();
    addTearDown(owner.dispose);
    owner.pushFailures = 1;
    expect(
      await owner.coordinator.runFullSyncWithResult(force: true),
      SyncRequestOutcome.partial,
    );
    expect(owner.calls, [
      'push',
      'pull',
      'retry',
      'inventory',
      'workflow pull',
    ]);
    final health = owner.container.read(syncRunHealthProvider);
    expect(health.lastSucceeded, isFalse);
    expect(health.lastPartiallySucceeded, isTrue);
    expect(health.failureCount, 1);
    expect(owner.container.read(syncStatusProvider), SyncStatus.partial);
    await tester.pump(const Duration(seconds: 6));
    expect(owner.container.read(syncStatusProvider), SyncStatus.partial);
    owner.pushFailures = 0;
    expect(
      await owner.coordinator.runFullSyncWithResult(force: true),
      SyncRequestOutcome.succeeded,
    );
    expect(
      owner.container.read(syncRunHealthProvider).lastPartiallySucceeded,
      isFalse,
    );
    owner.dispose();
  });

  testWidgets(
    'failed pull cannot be described as a partial completed refresh',
    (tester) async {
      final owner = _Owner();
      addTearDown(owner.dispose);
      owner.pushFailures = 1;
      owner.failedPhase = 'pull';
      expect(
        await owner.coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.failed,
      );
      expect(owner.calls, ['push', 'pull']);
      expect(
        owner.container.read(syncRunHealthProvider).lastPartiallySucceeded,
        isFalse,
      );
      expect(owner.container.read(syncStatusProvider), SyncStatus.failed);
    },
  );

  for (final phase in ['push', 'pull', 'retry', 'inventory', 'workflow pull']) {
    testWidgets('session invalidation during $phase stops remaining work', (
      tester,
    ) async {
      final owner = _Owner(blockedPhase: phase);
      addTearDown(owner.dispose);
      final result = owner.coordinator.runFullSyncWithResult(force: true);
      await tester.pump();
      expect(owner.calls.last, phase);
      final calls = List.of(owner.calls);
      owner.sessionEpoch++;
      owner.pending.complete();
      await tester.pump();
      expect(await result, SyncRequestOutcome.failed);
      expect(owner.calls, calls);
      expect(
        owner.container.read(syncRunHealthProvider).lastPartiallySucceeded,
        isFalse,
      );
    });
  }

  testWidgets(
    'unsafe storage in push stops pull rather than becoming partial',
    (tester) async {
      final owner = _Owner();
      addTearDown(owner.dispose);
      owner.failedPhase = 'push';
      owner.phaseError = const SyncRunAborted('local-storage-unavailable');
      expect(
        await owner.coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.failed,
      );
      expect(owner.calls, ['push']);
    },
  );

  testWidgets(
    'completed sync cancels its delayed reset when the actual provider is disposed',
    (tester) async {
      final owner = _Owner();
      expect(
        await owner.coordinator.runFullSyncWithResult(force: true),
        SyncRequestOutcome.succeeded,
      );
      expect(owner.container.read(syncStatusProvider), SyncStatus.success);
      owner.dispose();
      final reads = owner.reads.count;
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
      expect(owner.reads.count, reads);
      expect(owner.connectivity.cancellations, 1);
      expect(owner.coordinator.dispose, returnsNormally);
    },
  );

  testWidgets('older success reset cannot clear a newer completed run', (
    tester,
  ) async {
    final owner = _Owner();
    addTearDown(owner.dispose);
    await owner.coordinator.runFullSyncWithResult(force: true);
    await tester.pump(const Duration(seconds: 4));
    await owner.coordinator.runFullSyncWithResult(force: true);
    await tester.pump(const Duration(seconds: 2));
    expect(owner.container.read(syncStatusProvider), SyncStatus.success);
    await tester.pump(const Duration(seconds: 3));
    expect(owner.container.read(syncStatusProvider), SyncStatus.idle);
  });

  for (final phase in ['push', 'pull', 'retry', 'inventory', 'workflow pull']) {
    testWidgets(
      'disposal during $phase stops later phases and provider access',
      (tester) async {
        final owner = _Owner(blockedPhase: phase);
        final outcome = owner.coordinator.runFullSyncWithResult(force: true);
        await tester.pump();
        expect(owner.calls.last, phase);
        expect(
          await owner.coordinator.runFullSyncWithResult(
            reason: 'queued',
            force: true,
          ),
          SyncRequestOutcome.queued,
        );
        owner.dispose();
        final calls = List.of(owner.calls);
        final reads = owner.reads.count;
        owner.pending.complete();
        await tester.pump();
        expect(await outcome, SyncRequestOutcome.failed);
        expect(owner.calls, calls);
        expect(owner.reads.count, reads);
        expect(tester.takeException(), isNull);
        expect(
          await owner.coordinator.runFullSyncWithResult(force: true),
          SyncRequestOutcome.failed,
        );
        expect(owner.reads.count, reads);
      },
    );
  }

  testWidgets(
    'late repository failure after disposal does not publish or restart work',
    (tester) async {
      final owner = _Owner(blockedPhase: 'push');
      final outcome = owner.coordinator.runFullSyncWithResult(force: true);
      owner.dispose();
      final reads = owner.reads.count;
      owner.pending.completeError(
        StateError('repository failed after owner exit'),
      );
      await tester.pump();
      expect(await outcome, SyncRequestOutcome.failed);
      expect(owner.reads.count, reads);
      expect(owner.calls, ['push']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery waiting for disposed sync releases guard and never starts operation',
    (tester) async {
      final owner = _Owner(blockedPhase: 'push');
      final run = owner.coordinator.runFullSyncWithResult(force: true);
      var operations = 0;
      final recovery = owner.coordinator.runWithSyncPaused(
        operation: () async {
          operations++;
        },
      );
      final rejected = expectLater(recovery, throwsStateError);
      expect(owner.guard.isRecoveryProtectionActive, isTrue);
      owner.dispose();
      final reads = owner.reads.count;
      owner.pending.complete();
      await tester.pump();
      await rejected;
      expect(await run, SyncRequestOutcome.failed);
      expect(operations, 0);
      expect(owner.guard.isRecoveryProtectionActive, isFalse);
      expect(owner.reads.count, reads);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'already-started recovery completes and releases guard without disposed provider writes',
    (tester) async {
      final owner = _Owner();
      final operation = Completer<int>();
      final result = owner.coordinator.runWithSyncPaused(
        operation: () => operation.future,
      );
      expect(owner.guard.isRecoveryProtectionActive, isTrue);
      owner.dispose();
      final reads = owner.reads.count;
      operation.complete(42);
      await tester.pump();
      expect(await result, 42);
      expect(owner.guard.isRecoveryProtectionActive, isFalse);
      expect(owner.reads.count, reads);
      expect(owner.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Owner {
  _Owner({String? blockedPhase}) {
    Future<void> phase(String name) async {
      calls.add(name);
      if (blockedPhase == name) await pending.future;
      if (failedPhase == name) throw phaseError;
    }

    final provider = Provider<SyncCoordinator>((ref) {
      reads = _Reads(ref);
      final value = SyncCoordinator(
        reads,
        _Push(phase, () => pushFailures, () => pushConflicts),
        _Pull(phase),
        guard,
        connectivity: connectivity,
        runGuardFactory: () {
          final epoch = sessionEpoch;
          return SyncRunGuard(() {
            if (sessionEpoch != epoch) {
              throw const SyncRunAborted('account-or-authority-changed');
            }
          });
        },
      );
      ref.onDispose(value.dispose);
      return value;
    });
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(null)),
        workflowUncertainRetryServiceProvider.overrideWithValue(_Retry(phase)),
        workflowRepositoryProvider.overrideWithValue(_Repository(phase)),
        workflowPullServiceProvider.overrideWithValue(_WorkflowPull(phase)),
      ],
    );
    coordinator = container.read(provider);
  }
  final pending = Completer<void>();
  final calls = <String>[];
  int pushFailures = 0;
  int pushConflicts = 0;
  int sessionEpoch = 0;
  String? failedPhase;
  Object phaseError = StateError('injected repository failure');
  final connectivity = _Connectivity();
  final guard = LocalRecoverySessionGuard();
  late final ProviderContainer container;
  late final SyncCoordinator coordinator;
  late final _Reads reads;
  bool disposed = false;
  void dispose() {
    if (disposed) return;
    disposed = true;
    container.dispose();
    unawaited(connectivity.controller.close());
  }
}

typedef _Phase = Future<void> Function(String);

class _Reads extends Fake implements Ref {
  _Reads(this.delegate);
  final Ref delegate;
  int count = 0;
  @override
  T read<T>(ProviderListenable<T> provider) {
    count++;
    return delegate.read(provider);
  }
}

class _Connectivity extends Fake implements Connectivity {
  int cancellations = 0;
  late final controller = StreamController<List<ConnectivityResult>>(
    onCancel: () => cancellations++,
  );
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      controller.stream;
}

class _Push extends Fake implements SyncService {
  _Push(this.phase, this.failureCount, this.conflictCount);
  final _Phase phase;
  final int Function() failureCount;
  final int Function() conflictCount;
  @override
  Future<void> syncAll({
    bool recheckPermanentRejections = false,
    SyncRunGuard? runGuard,
  }) => phase('push');
  @override
  int get lastSuccessCount => 1;
  @override
  int get lastFailureCount => failureCount();
  @override
  int get lastConflictCount => conflictCount();
  @override
  Set<String> get lastDeferredPushStages => {};
  @override
  Set<String> get lastDeferredPushRecordKeys => {};
  @override
  int get lastFailureDetailOverflowCount => 0;
  @override
  Set<String> get lastConflictKeys => {};
  @override
  List<SyncFailureDetail> get lastFailureDetails => [];
}

class _Pull extends Fake implements GlobalPullService {
  _Pull(this.phase);
  final _Phase phase;
  @override
  Future<void> pullAndReconcile({SyncRunGuard? runGuard}) => phase('pull');
  @override
  Set<String> get lastConflictKeys => {};
  @override
  int get lastConflicted => 0;
  @override
  Null get lastFailedDomain => null;
}

class _Retry extends Fake implements WorkflowUncertainRetryService {
  _Retry(this.phase);
  final _Phase phase;
  @override
  Future<WorkflowRetryRunSummary> retryDueCommands({
    SyncRunGuard? runGuard,
  }) async {
    await phase('retry');
    return const WorkflowRetryRunSummary();
  }
}

class _Repository extends Fake implements WorkflowRepository {
  _Repository(this.phase);
  final _Phase phase;
  @override
  Future<WorkflowOutcomeInventory> readOutcomeInventory() async {
    await phase('inventory');
    return const WorkflowOutcomeInventory();
  }
}

class _WorkflowPull extends Fake implements WorkflowPullService {
  _WorkflowPull(this.phase);
  final _Phase phase;
  @override
  Future<WorkflowPullSummary> pull({SyncRunGuard? runGuard}) async {
    await phase('workflow pull');
    return const WorkflowPullSummary(
      workflows: 0,
      lanes: 0,
      compliance: 0,
      attempts: 0,
      equipment: 0,
      prompts: 0,
      events: 0,
    );
  }
}
