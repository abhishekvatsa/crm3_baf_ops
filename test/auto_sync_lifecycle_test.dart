import 'dart:async';

import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auto sync releases its widget owner without provider access', (
    tester,
  ) async {
    late _ReadProbe reads;
    final serviceProvider = Provider<AutoSyncService>((ref) {
      reads = _ReadProbe(ref);
      return AutoSyncService(reads);
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(serviceProvider);
    var cancellations = 0;
    final changes = StreamController<void>(onCancel: () => cancellations++);
    addTearDown(changes.close);
    final pendingCount = Completer<int>();

    Widget tree({required bool ownService}) => UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          ref.watch(autoSyncHealthProvider);
          return ownService
              ? _SyncOwner(service: service)
              : const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(tree(ownService: true));
    service.start();
    service.watchPendingChanges(
      entityType: 'maintenance_ticket',
      changes: changes.stream,
      countPending: () => pendingCount.future,
    );
    changes.add(null);
    await tester.pump();
    final readsBeforeUnmount = reads.count;
    await tester.pumpWidget(tree(ownService: false));
    expect(tester.takeException(), isNull);
    expect(reads.count, readsBeforeUnmount);
    expect(cancellations, 1);
    pendingCount.complete(1);
    await tester.pump();
    expect(reads.count, readsBeforeUnmount);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an in-flight sync cannot access providers after owner disposal',
    (tester) async {
      final coordinator = _PendingCoordinator();
      late _ReadProbe reads;
      final serviceProvider = Provider<AutoSyncService>((ref) {
        reads = _ReadProbe(ref);
        final service = AutoSyncService(reads);
        ref.onDispose(service.dispose);
        return service;
      });
      final container = ProviderContainer(
        overrides: [syncCoordinatorProvider.overrideWithValue(coordinator)],
      );
      final service = container.read(serviceProvider);
      service.start();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(coordinator.runs, hasLength(1));
      final before = reads.count;
      container.dispose();
      coordinator.runs.single.complete(SyncRequestOutcome.failed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(reads.count, before);
      expect(service.dispose, returnsNormally);
    },
  );

  testWidgets('new account restarts cleanly and ignores the previous run', (
    tester,
  ) async {
    final coordinator = _PendingCoordinator();
    final container = ProviderContainer(
      overrides: [syncCoordinatorProvider.overrideWithValue(coordinator)],
    );
    addTearDown(container.dispose);
    final service = container.read(autoSyncServiceProvider);
    service.start();
    service.markImmediateTicketSyncRequested();
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    service.detach();
    service.start();
    final restarted = container.read(autoSyncHealthProvider);
    expect(restarted.isStarted, isTrue);
    expect(restarted.automaticSyncRunning, isFalse);
    expect(restarted.normalIssueSyncPending, isFalse);
    expect(restarted.lastAutomaticReason, isNull);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(coordinator.runs, hasLength(2));
    coordinator.runs.first.complete(SyncRequestOutcome.failed);
    await tester.pump();
    expect(container.read(autoSyncHealthProvider).automaticSyncRunning, isTrue);
    expect(container.read(autoSyncHealthProvider).lastAutomaticOutcome, isNull);
    coordinator.runs.last.complete(SyncRequestOutcome.succeeded);
    await tester.pump();
    expect(
      container.read(autoSyncHealthProvider).automaticSyncRunning,
      isFalse,
    );
    expect(
      container.read(autoSyncHealthProvider).lastAutomaticOutcome,
      SyncRequestOutcome.succeeded,
    );
    service.stop();
    expect(container.read(autoSyncHealthProvider).isStarted, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _PendingCoordinator extends Fake implements SyncCoordinator {
  final runs = <Completer<SyncRequestOutcome>>[];

  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) {
    final run = Completer<SyncRequestOutcome>();
    runs.add(run);
    return run.future;
  }
}

class _ReadProbe extends Fake implements Ref {
  _ReadProbe(this.delegate);
  final Ref delegate;
  int count = 0;

  @override
  T read<T>(ProviderListenable<T> provider) {
    count++;
    return delegate.read(provider);
  }
}

class _SyncOwner extends StatefulWidget {
  const _SyncOwner({required this.service});
  final AutoSyncService service;

  @override
  State<_SyncOwner> createState() => _SyncOwnerState();
}

class _SyncOwnerState extends State<_SyncOwner> {
  @override
  void dispose() {
    widget.service.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
