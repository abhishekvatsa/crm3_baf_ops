// FILE: lib/core/services/auto_sync_service.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_coordinator.dart';

// ─────────────────────────────────────────────────────────────
// AUTO SYNC SERVICE
// ─────────────────────────────────────────────────────────────
//
// Policy:
// - Critical writes call SyncCoordinator directly with force:true.
// - Normal raised issues attempt an immediate forced sync from the write path.
// - The five-minute normal-issue timer is a retry/catch-up safety net if that
//   immediate attempt fails, is interrupted, or misses connectivity.
// - General app consistency runs every twenty minutes while an approved user
//   is in the app.
// - App resume performs a lightweight catch-up if the last automatic attempt
//   is old enough.
//
// This service never writes data itself. It only asks the central
// SyncCoordinator to run push → pull.

class AutoSyncHealth {
  final bool isStarted;
  final bool automaticSyncRunning;
  final bool normalIssueSyncPending;
  final DateTime? nextNormalIssueSyncAt;
  final DateTime? nextGeneralSyncAt;
  final DateTime? lastAutomaticAttemptAt;
  final DateTime? lastAutomaticCompletedAt;
  final String? lastAutomaticReason;
  final SyncRequestOutcome? lastAutomaticOutcome;
  final String? lastTicketQueueReason;

  const AutoSyncHealth({
    this.isStarted = false,
    this.automaticSyncRunning = false,
    this.normalIssueSyncPending = false,
    this.nextNormalIssueSyncAt,
    this.nextGeneralSyncAt,
    this.lastAutomaticAttemptAt,
    this.lastAutomaticCompletedAt,
    this.lastAutomaticReason,
    this.lastAutomaticOutcome,
    this.lastTicketQueueReason,
  });

  AutoSyncHealth copyWith({
    bool? isStarted,
    bool? automaticSyncRunning,
    bool? normalIssueSyncPending,
    DateTime? nextNormalIssueSyncAt,
    bool clearNextNormalIssueSyncAt = false,
    DateTime? nextGeneralSyncAt,
    bool clearNextGeneralSyncAt = false,
    DateTime? lastAutomaticAttemptAt,
    DateTime? lastAutomaticCompletedAt,
    String? lastAutomaticReason,
    SyncRequestOutcome? lastAutomaticOutcome,
    String? lastTicketQueueReason,
    bool clearLastTicketQueueReason = false,
  }) {
    return AutoSyncHealth(
      isStarted: isStarted ?? this.isStarted,
      automaticSyncRunning:
      automaticSyncRunning ?? this.automaticSyncRunning,
      normalIssueSyncPending:
      normalIssueSyncPending ?? this.normalIssueSyncPending,
      nextNormalIssueSyncAt: clearNextNormalIssueSyncAt
          ? null
          : (nextNormalIssueSyncAt ?? this.nextNormalIssueSyncAt),
      nextGeneralSyncAt: clearNextGeneralSyncAt
          ? null
          : (nextGeneralSyncAt ?? this.nextGeneralSyncAt),
      lastAutomaticAttemptAt:
      lastAutomaticAttemptAt ?? this.lastAutomaticAttemptAt,
      lastAutomaticCompletedAt:
      lastAutomaticCompletedAt ?? this.lastAutomaticCompletedAt,
      lastAutomaticReason: lastAutomaticReason ?? this.lastAutomaticReason,
      lastAutomaticOutcome:
      lastAutomaticOutcome ?? this.lastAutomaticOutcome,
      lastTicketQueueReason: clearLastTicketQueueReason
          ? null
          : (lastTicketQueueReason ?? this.lastTicketQueueReason),
    );
  }
}

final autoSyncHealthProvider = StateProvider<AutoSyncHealth>(
      (ref) => const AutoSyncHealth(),
);

class AutoSyncService with WidgetsBindingObserver {
  final Ref _ref;

  Timer? _generalTimer;
  Timer? _normalIssueTimer;

  bool _started = false;
  bool _resumeSyncRunning = false;

  static const Duration generalInterval = Duration(minutes: 20);
  static const Duration normalIssueDelay = Duration(minutes: 5);
  static const Duration resumeMinGap = Duration(minutes: 5);

  AutoSyncService(this._ref);

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();
    _setHealth(
      _health.copyWith(
        isStarted: true,
        nextGeneralSyncAt: now.add(generalInterval),
      ),
    );

    _generalTimer?.cancel();
    _generalTimer = Timer.periodic(generalInterval, (_) {
      unawaited(_runAutomaticSync(reason: 'periodic_20min'));
    });
  }

  void stop() {
    if (!_started) return;

    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _generalTimer?.cancel();
    _generalTimer = null;
    _normalIssueTimer?.cancel();
    _normalIssueTimer = null;

    _setHealth(
      _health.copyWith(
        isStarted: false,
        automaticSyncRunning: false,
        normalIssueSyncPending: false,
        clearNextNormalIssueSyncAt: true,
        clearNextGeneralSyncAt: true,
        clearLastTicketQueueReason: true,
      ),
    );
  }

  /// Called after a non-critical maintenance issue is raised. The write path
  /// should also attempt an immediate forced sync. This timer is a retry /
  /// catch-up safety net that guarantees another push/pull attempt within five
  /// minutes if the immediate send fails or is interrupted. Manual sync still
  /// overrides this and can clear the queue earlier.
  void scheduleTicketSyncWithinFiveMinutes({String reason = 'normal_ticket'}) {
    final nextRun = DateTime.now().add(normalIssueDelay);

    _normalIssueTimer?.cancel();
    _normalIssueTimer = Timer(normalIssueDelay, () {
      _normalIssueTimer = null;
      _setHealth(
        _health.copyWith(
          normalIssueSyncPending: false,
          clearNextNormalIssueSyncAt: true,
        ),
      );
      unawaited(_runAutomaticSync(reason: '${reason}_5min'));
    });

    _setHealth(
      _health.copyWith(
        normalIssueSyncPending: true,
        nextNormalIssueSyncAt: nextRun,
        lastTicketQueueReason: reason,
      ),
    );
  }

  /// Called after a successful manual sync. Manual sync sends pending normal
  /// tickets earlier, so the unattended 5-minute timer can be cancelled.
  void clearPendingTicketSync({String reason = 'manual_sync'}) {
    _normalIssueTimer?.cancel();
    _normalIssueTimer = null;
    _setHealth(
      _health.copyWith(
        normalIssueSyncPending: false,
        clearNextNormalIssueSyncAt: true,
        lastTicketQueueReason: reason,
      ),
    );
  }

  Future<void> _runAutomaticSync({required String reason}) async {
    final now = DateTime.now();

    _setHealth(
      _health.copyWith(
        automaticSyncRunning: true,
        lastAutomaticAttemptAt: now,
        lastAutomaticReason: reason,
      ),
    );

    final outcome = await _ref
        .read(syncCoordinatorProvider)
        .runFullSyncWithResult(reason: reason, force: false);

    final finishedAt = DateTime.now();
    _setHealth(
      _health.copyWith(
        automaticSyncRunning: false,
        lastAutomaticCompletedAt: outcome.isDeferred ? null : finishedAt,
        lastAutomaticReason: reason,
        lastAutomaticOutcome: outcome,
        nextGeneralSyncAt: finishedAt.add(generalInterval),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || state != AppLifecycleState.resumed) return;

    final now = DateTime.now();
    final last = _health.lastAutomaticAttemptAt;

    if (_resumeSyncRunning) return;
    if (last != null && now.difference(last) < resumeMinGap) return;

    _resumeSyncRunning = true;
    unawaited(
      _runAutomaticSync(reason: 'app_resumed').whenComplete(() {
        _resumeSyncRunning = false;
      }),
    );
  }

  AutoSyncHealth get _health => _ref.read(autoSyncHealthProvider);

  void _setHealth(AutoSyncHealth health) {
    _ref.read(autoSyncHealthProvider.notifier).state = health;
  }

  void dispose() => stop();
}

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  final service = AutoSyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});
