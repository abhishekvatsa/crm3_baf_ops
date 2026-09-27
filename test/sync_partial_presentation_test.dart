import 'package:crm3_baf_ops/core/providers/sync_conflict_provider.dart';
import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/services/app_network_access_status.dart';
import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:crm3_baf_ops/core/services/live_remote_sync_service.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_rejection_service.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/sync_status_indicator.dart';
import 'package:crm3_baf_ops/features/admin/presentation/local_diagnostics_screen.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial status and diagnostics never claim full success', () {
    expect(SyncStatus.partial.isPartial, isTrue);
    expect(SyncStatus.partial.isFailure, isTrue);
    expect(SyncStatus.partial.isSuccess, isFalse);
    final snapshot = LocalDiagnosticsSupportSnapshot.capture(
      syncStatus: SyncStatus.partial,
      syncHealth: const SyncRunHealth(
        lastSucceeded: false,
        lastPartiallySucceeded: true,
        successCount: 3,
        failureCount: 1,
      ),
    );
    expect(snapshot.toMap()['syncStatus'], 'partial');
    expect(snapshot.toMap()['syncLastSucceeded'], isFalse);
    expect(snapshot.toMap()['syncLastPartiallySucceeded'], isTrue);
    expect(snapshot.toMap()['syncFailureCount'], 1);
  });

  testWidgets('partial overrides Live and keeps workflow attention separate', (
    tester,
  ) async {
    await _show(
      tester,
      status: SyncStatus.partial,
      health: const SyncRunHealth(
        lastSucceeded: false,
        lastPartiallySucceeded: true,
        successCount: 3,
        failureCount: 1,
        workflowAttentionReason: 'A submitted command needs review',
      ),
      live: const LiveRemoteSyncHealth(
        maintenanceState: LiveRemoteSyncConnectionState.listening,
      ),
    );
    expect(find.text('Live'), findsNothing);
    expect(find.text('Synced'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Partly synced')).style!.color,
      BafColors.warning,
    );
    await tester.tap(find.text('Partly synced'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('A submitted command needs review'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Some changes still need attention'), findsOneWidget);
    expect(
      find.text('Completed; some saved changes could not be sent.'),
      findsOneWidget,
    );
    expect(find.text('3 success / 1 failed'), findsOneWidget);
    expect(find.text('A submitted command needs review'), findsOneWidget);
    expect(find.text('Success'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a health partial marker cannot fall through to Synced', (
    tester,
  ) async {
    final container = await _show(
      tester,
      status: SyncStatus.success,
      health: const SyncRunHealth(
        lastSucceeded: false,
        lastPartiallySucceeded: true,
      ),
    );
    expect(find.text('Partly synced'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    container.read(syncRunHealthProvider.notifier).state = const SyncRunHealth(
      lastSucceeded: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Partly synced'), findsNothing);
    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets('workflow attention alone does not become partial sync', (
    tester,
  ) async {
    await _show(
      tester,
      status: SyncStatus.success,
      health: const SyncRunHealth(
        lastSucceeded: true,
        workflowAttentionReason: 'Submitted command is awaiting review',
      ),
    );
    expect(find.text('Action needed'), findsOneWidget);
    expect(find.text('Partly synced'), findsNothing);
  });

  for (final outcome in SyncRequestOutcome.values) {
    testWidgets('manual $outcome feedback preserves pending work correctly', (
      tester,
    ) async {
      final automatic = _AutoSync();
      await _show(tester, automatic: automatic, outcome: outcome);
      await tester.tap(find.widgetWithText(TextButton, 'Sync now'));
      await tester.pumpAndSettle();
      expect(find.text(outcome.manualSyncMessage), findsOneWidget);
      expect(automatic.cleared, outcome.isSuccessful ? 1 : 0);
      final color = tester
          .widget<SnackBar>(find.byType(SnackBar))
          .backgroundColor;
      expect(color, switch (outcome) {
        SyncRequestOutcome.partial ||
        SyncRequestOutcome.throttled => BafColors.warning,
        SyncRequestOutcome.failed => BafColors.danger,
        SyncRequestOutcome.queued => BafColors.planned,
        SyncRequestOutcome.succeeded => BafColors.sync,
      });
      expect(tester.takeException(), isNull);
    });
  }
}

Future<ProviderContainer> _show(
  WidgetTester tester, {
  SyncStatus status = SyncStatus.idle,
  SyncRunHealth health = const SyncRunHealth(),
  LiveRemoteSyncHealth live = const LiveRemoteSyncHealth(),
  SyncRequestOutcome outcome = SyncRequestOutcome.partial,
  _AutoSync? automatic,
}) async {
  await tester.binding.setSurfaceSize(const Size(700, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      syncStatusProvider.overrideWith((ref) => status),
      syncRunHealthProvider.overrideWith((ref) => health),
      liveRemoteSyncHealthProvider.overrideWith((ref) => live),
      syncConflictProvider.overrideWith((ref) => 0),
      syncPendingCountsProvider.overrideWith(
        (ref) async => const SyncPendingCounts(),
      ),
      appNetworkAccessProvider.overrideWith(
        (ref) => Stream.value(AppNetworkAccess.allowed),
      ),
      currentAppUserProvider.overrideWith(
        (ref) => Stream.value(
          AppUser(
            uid: 'reader',
            name: 'Reader',
            email: 'reader@example.invalid',
            roles: [AppRole.operations],
            isApproved: true,
            createdAt: DateTime.utc(2026),
          ),
        ),
      ),
      recentSyncRejectionsProvider.overrideWith((ref) => Stream.value([])),
      unresolvedPermanentSyncRejectionCountProvider.overrideWith(
        (ref) => Stream.value(0),
      ),
      syncCoordinatorProvider.overrideWithValue(_Coordinator(outcome)),
      autoSyncServiceProvider.overrideWithValue(automatic ?? _AutoSync()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(currentAppUserProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const Scaffold(body: Center(child: SyncStatusIndicator())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Coordinator extends Fake implements SyncCoordinator {
  _Coordinator(this.outcome);
  final SyncRequestOutcome outcome;
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'test',
    bool force = false,
  }) async => outcome;
}

class _AutoSync extends Fake implements AutoSyncService {
  int cleared = 0;
  @override
  void clearPendingTicketSync({String reason = 'test'}) => cleared++;
}
