// FILE: lib/core/services/auto_sync_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../features/abnormalities/data/abnormality_model.dart';
import '../../features/directives/data/operational_directive_model.dart';
import '../../features/maintenance/data/maintenance_model.dart';
import '../../features/planned_maintenance/data/baf_knowledge_model.dart';
import '../../features/planned_maintenance/data/job_diary_model.dart';
import '../../features/planned_maintenance/data/job_module_model.dart';
import '../../features/planned_maintenance/data/job_template_model.dart';
import '../../features/planned_maintenance/data/template_governance_model.dart';
import 'sync_coordinator.dart';

// ─────────────────────────────────────────────────────────────
// AUTO SYNC SERVICE
// ─────────────────────────────────────────────────────────────
//
// Policy:
// - Every unsynced business collection wakes the coordinator immediately.
// - Incoming approved-user state is received by bounded live Firestore mirrors.
// - Reconnect and app resume immediately reconcile any interrupted work.
// - Durable permanent rejections remain held until reviewed or safely removed.
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
      automaticSyncRunning: automaticSyncRunning ?? this.automaticSyncRunning,
      normalIssueSyncPending:
          normalIssueSyncPending ?? this.normalIssueSyncPending,
      nextNormalIssueSyncAt:
          clearNextNormalIssueSyncAt
              ? null
              : (nextNormalIssueSyncAt ?? this.nextNormalIssueSyncAt),
      nextGeneralSyncAt:
          clearNextGeneralSyncAt
              ? null
              : (nextGeneralSyncAt ?? this.nextGeneralSyncAt),
      lastAutomaticAttemptAt:
          lastAutomaticAttemptAt ?? this.lastAutomaticAttemptAt,
      lastAutomaticCompletedAt:
          lastAutomaticCompletedAt ?? this.lastAutomaticCompletedAt,
      lastAutomaticReason: lastAutomaticReason ?? this.lastAutomaticReason,
      lastAutomaticOutcome: lastAutomaticOutcome ?? this.lastAutomaticOutcome,
      lastTicketQueueReason:
          clearLastTicketQueueReason
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

  final List<StreamSubscription<void>> _pendingWriteSubscriptions =
      <StreamSubscription<void>>[];

  bool _started = false;
  bool _resumeSyncRunning = false;
  bool _pendingWakeScheduled = false;
  Timer? _failureRetryTimer;
  int _consecutiveTransientFailures = 0;

  AutoSyncService(this._ref);

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    _setHealth(_health.copyWith(isStarted: true, clearNextGeneralSyncAt: true));
    _startPendingWriteListeners();
  }

  void stop() {
    if (!_started) return;

    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _pendingWriteSubscriptions) {
      unawaited(subscription.cancel());
    }
    _pendingWriteSubscriptions.clear();
    _pendingWakeScheduled = false;
    _clearFailureRetry();

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

  void markImmediateTicketSyncRequested({String reason = 'ticket_changed'}) {
    _setHealth(
      _health.copyWith(
        normalIssueSyncPending: true,
        clearNextNormalIssueSyncAt: true,
        lastTicketQueueReason: reason,
      ),
    );
  }

  void clearPendingTicketSync({String reason = 'manual_sync'}) {
    _setHealth(
      _health.copyWith(
        normalIssueSyncPending: false,
        clearNextNormalIssueSyncAt: true,
        lastTicketQueueReason: reason,
      ),
    );
  }

  Future<void> _runAutomaticSync({
    required String reason,
    bool continuingFailureRetry = false,
  }) async {
    if (!_started || _ref.read(syncLocalRecoveryActiveProvider)) {
      return;
    }
    if (!continuingFailureRetry) {
      _clearFailureRetry();
    }
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
        .runFullSyncWithResult(reason: reason, force: true);

    final finishedAt = DateTime.now();
    _setHealth(
      _health.copyWith(
        automaticSyncRunning: false,
        lastAutomaticCompletedAt: outcome.isDeferred ? null : finishedAt,
        lastAutomaticReason: reason,
        lastAutomaticOutcome: outcome,
        normalIssueSyncPending:
            outcome.isSuccessful ? false : _health.normalIssueSyncPending,
        clearNextGeneralSyncAt: true,
        clearNextNormalIssueSyncAt: true,
      ),
    );

    if (outcome.isSuccessful) {
      _clearFailureRetry();
    } else if (outcome.isFailure && _lastFailureMayBeTransient) {
      _scheduleFailureRetry();
    }
  }

  bool get _lastFailureMayBeTransient {
    final health = _ref.read(syncRunHealthProvider);
    if (health.failureDetails.isEmpty) {
      return true;
    }
    return health.failureDetailOverflowCount > 0 ||
        health.failureDetails.any((detail) => !detail.isLikelyPermanent);
  }

  void _scheduleFailureRetry() {
    if (!_started || _ref.read(syncLocalRecoveryActiveProvider)) {
      return;
    }
    _consecutiveTransientFailures += 1;
    final delay = automaticSyncFailureRetryDelay(_consecutiveTransientFailures);
    if (delay == null) {
      return;
    }

    _failureRetryTimer?.cancel();
    _failureRetryTimer = Timer(delay, () {
      _failureRetryTimer = null;
      if (!_started || _ref.read(syncLocalRecoveryActiveProvider)) {
        return;
      }
      unawaited(
        _runAutomaticSync(
          reason: 'transient_failure_retry',
          continuingFailureRetry: true,
        ),
      );
    });
  }

  void _clearFailureRetry() {
    _failureRetryTimer?.cancel();
    _failureRetryTimer = null;
    _consecutiveTransientFailures = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || state != AppLifecycleState.resumed) return;

    if (_resumeSyncRunning) return;

    _resumeSyncRunning = true;
    unawaited(
      _runAutomaticSync(reason: 'app_resumed').whenComplete(() {
        _resumeSyncRunning = false;
      }),
    );
  }

  void _startPendingWriteListeners() {
    if (kIsWeb) return;
    final database = Isar.getInstance();
    if (database == null) return;

    _watchPending(
      'maintenance_ticket',
      database.maintenanceRecords.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'job_template',
      database.jobTemplates.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'job_execution',
      database.jobExecutions.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'job_diary_entry',
      database.jobDiaryEntrys.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'job_module',
      database.jobModuleInstances.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'directive',
      database.operationalDirectives.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'abnormality_type',
      database.abnormalityTypes.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'charge_abnormality',
      database.chargeAbnormalitys.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'template_package',
      database.templatePackages.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'template_version',
      database.templateVersions.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'template_publish_audit',
      database.templatePublishAudits.filter().isSyncedEqualTo(false),
    );
    _watchPending(
      'baf_knowledge_row',
      database.bafKnowledgeRows.filter().isSyncedEqualTo(false),
    );
  }

  void _watchPending<T>(
    String entityType,
    QueryBuilder<T, T, QAfterFilterCondition> query,
  ) {
    _pendingWriteSubscriptions.add(
      query.watchLazy().listen((_) {
        unawaited(_wakeIfPending(entityType, query));
      }),
    );
  }

  Future<void> _wakeIfPending<T>(
    String entityType,
    QueryBuilder<T, T, QAfterFilterCondition> query,
  ) async {
    if (!_started ||
        _pendingWakeScheduled ||
        _ref.read(syncLocalRecoveryActiveProvider) ||
        await query.count() == 0) {
      return;
    }
    _pendingWakeScheduled = true;
    scheduleMicrotask(() {
      _pendingWakeScheduled = false;
      if (!_started || _ref.read(syncLocalRecoveryActiveProvider)) return;
      unawaited(_runAutomaticSync(reason: 'local_${entityType}_changed'));
    });
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

@visibleForTesting
Duration? automaticSyncFailureRetryDelay(int failureCount) {
  const delays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];
  if (failureCount < 1) {
    return null;
  }
  return failureCount > delays.length ? delays.last : delays[failureCount - 1];
}
