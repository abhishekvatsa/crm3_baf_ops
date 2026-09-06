// FILE: lib/core/services/sync_coordinator.dart

import 'dart:async' show Completer, StreamSubscription, unawaited;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/maintenance_workflow/providers/workflow_providers.dart';
import '../providers/sync_conflict_provider.dart';
import '../providers/sync_status_provider.dart';
import 'app_logger.dart';
import 'global_pull_cursor_store.dart';
import 'global_pull_protocol.dart';
import 'global_pull_service.dart';
import 'local_recovery_session_guard.dart';
import 'local_sync_recovery_service.dart';
import 'sync_service.dart';

enum SyncRequestOutcome { succeeded, failed, queued, throttled }

extension SyncRequestOutcomeX on SyncRequestOutcome {
  bool get isSuccessful => this == SyncRequestOutcome.succeeded;

  bool get isFailure => this == SyncRequestOutcome.failed;

  bool get isDeferred =>
      this == SyncRequestOutcome.queued || this == SyncRequestOutcome.throttled;

  String get diagnosticLabel => switch (this) {
    SyncRequestOutcome.succeeded => 'Success',
    SyncRequestOutcome.failed => 'Failed',
    SyncRequestOutcome.queued => 'Queued',
    SyncRequestOutcome.throttled => 'Throttled',
  };

  String get manualSyncMessage => switch (this) {
    SyncRequestOutcome.succeeded => 'Manual sync completed.',
    SyncRequestOutcome.failed => 'Manual sync could not complete.',
    SyncRequestOutcome.queued =>
      'Manual sync queued behind the sync already running.',
    SyncRequestOutcome.throttled =>
      'Manual sync skipped because another sync completed recently.',
  };
}

const _permanentCallableErrorCodes = <String>{
  'already-exists',
  'data-loss',
  'failed-precondition',
  'invalid-argument',
  'not-found',
  'out-of-range',
  'permission-denied',
  'unauthenticated',
  'unimplemented',
};

@visibleForTesting
bool syncFailureLikelyPermanent(Object error) {
  if (error is GlobalPullCursorException ||
      error is GlobalPullProtocolException) {
    return true;
  }
  return error is FirebaseFunctionsException &&
      _permanentCallableErrorCodes.contains(error.code);
}

@visibleForTesting
Map<String, Object?> syncFailureDiagnosticContext(
  Object error, {
  GlobalPullDomain? pullDomain,
}) {
  final context = <String, Object?>{};
  if (pullDomain != null) {
    context['sync_pull_domain_${_diagnosticToken(pullDomain.wireName)}'] = true;
  }
  if (error is FirebaseFunctionsException) {
    context['sync_callable_code_${_diagnosticToken(error.code)}'] = true;
    final details = error.details;
    if (details is Map && details['reason'] is String) {
      context['sync_callable_reason_${_diagnosticToken(details['reason'] as String)}'] =
          true;
    }
  } else if (error is GlobalPullProtocolException) {
    context['sync_protocol_reason_${_diagnosticToken(error.reasonCode)}'] =
        true;
  } else if (error is GlobalPullCursorException) {
    context['sync_cursor_reason_${_diagnosticToken(error.reasonCode)}'] = true;
  }
  return context;
}

String _diagnosticToken(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (normalized.isEmpty) return 'unknown';
  return normalized.length <= 48 ? normalized : normalized.substring(0, 48);
}

// ─────────────────────────────────────────────────────────────
// COORDINATOR HEALTH
// ─────────────────────────────────────────────────────────────

class SyncRunHealth {
  final bool isRunning;
  final DateTime? lastStartedAt;
  final DateTime? lastCompletedAt;
  final DateTime? lastSkippedAt;
  final String? lastReason;
  final String? lastSkippedReason;
  final bool? lastSucceeded;
  final int successCount;
  final int failureCount;
  final int conflictCount;
  final int runCount;
  final String? lastError;
  final List<SyncFailureDetail> failureDetails;
  final int failureDetailOverflowCount;
  final bool lastFailureLikelyPermanent;
  final bool hasPendingFollowUp;
  final String? pendingFollowUpReason;
  final bool pendingFollowUpForce;

  const SyncRunHealth({
    this.isRunning = false,
    this.lastStartedAt,
    this.lastCompletedAt,
    this.lastSkippedAt,
    this.lastReason,
    this.lastSkippedReason,
    this.lastSucceeded,
    this.successCount = 0,
    this.failureCount = 0,
    this.conflictCount = 0,
    this.runCount = 0,
    this.lastError,
    this.failureDetails = const <SyncFailureDetail>[],
    this.failureDetailOverflowCount = 0,
    this.lastFailureLikelyPermanent = false,
    this.hasPendingFollowUp = false,
    this.pendingFollowUpReason,
    this.pendingFollowUpForce = false,
  });

  SyncRunHealth copyWith({
    bool? isRunning,
    DateTime? lastStartedAt,
    DateTime? lastCompletedAt,
    DateTime? lastSkippedAt,
    String? lastReason,
    String? lastSkippedReason,
    bool? lastSucceeded,
    int? successCount,
    int? failureCount,
    int? conflictCount,
    int? runCount,
    String? lastError,
    List<SyncFailureDetail>? failureDetails,
    int? failureDetailOverflowCount,
    bool? lastFailureLikelyPermanent,
    bool? hasPendingFollowUp,
    String? pendingFollowUpReason,
    bool? pendingFollowUpForce,
    bool clearLastError = false,
    bool clearPendingFollowUp = false,
  }) {
    return SyncRunHealth(
      isRunning: isRunning ?? this.isRunning,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      lastSkippedAt: lastSkippedAt ?? this.lastSkippedAt,
      lastReason: lastReason ?? this.lastReason,
      lastSkippedReason: lastSkippedReason ?? this.lastSkippedReason,
      lastSucceeded: lastSucceeded ?? this.lastSucceeded,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      conflictCount: conflictCount ?? this.conflictCount,
      runCount: runCount ?? this.runCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      failureDetails: failureDetails ?? this.failureDetails,
      failureDetailOverflowCount:
          failureDetailOverflowCount ?? this.failureDetailOverflowCount,
      lastFailureLikelyPermanent:
          lastFailureLikelyPermanent ?? this.lastFailureLikelyPermanent,
      hasPendingFollowUp:
          clearPendingFollowUp
              ? false
              : (hasPendingFollowUp ?? this.hasPendingFollowUp),
      pendingFollowUpReason:
          clearPendingFollowUp
              ? null
              : (pendingFollowUpReason ?? this.pendingFollowUpReason),
      pendingFollowUpForce:
          clearPendingFollowUp
              ? false
              : (pendingFollowUpForce ?? this.pendingFollowUpForce),
    );
  }
}

class _QueuedSyncFollowUp {
  final String reason;
  final bool force;
  final bool recheckPermanentRejections;

  const _QueuedSyncFollowUp({
    required this.reason,
    required this.force,
    required this.recheckPermanentRejections,
  });
}

final syncRunHealthProvider = StateProvider<SyncRunHealth>(
  (ref) => const SyncRunHealth(),
);

final syncLocalRecoveryActiveProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────
// COORDINATOR
// ─────────────────────────────────────────────────────────────

class SyncCoordinator {
  final Ref _ref;
  final SyncService _sync;
  final GlobalPullService _pull;
  final LocalRecoverySessionGuard _recoverySessionGuard;

  bool _running = false;
  bool _initialized = false;
  bool _localRecoveryActive = false;
  bool _followUpRequested = false;
  String? _followUpReason;
  bool _followUpForce = false;
  bool _followUpRecheckPermanentRejections = false;
  Completer<void>? _activeRunCompletion;

  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration minGap = const Duration(seconds: 10);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncCoordinator(
    this._ref,
    this._sync,
    this._pull,
    this._recoverySessionGuard,
  ) {
    _initConnectivityListener();
  }

  // ─────────────────────────────────────────────────────────────
  // PUBLIC ENTRY
  // ─────────────────────────────────────────────────────────────

  Future<void> runFullSync({
    String reason = 'unknown',
    bool force = false,
  }) async {
    await _runFullSync(
      reason: reason,
      force: force,
      recheckPermanentRejections: reason == 'manual_rejection_recheck',
    );
  }

  /// Runs a full sync and distinguishes completion from deferred admission.
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) {
    return _runFullSync(
      reason: reason,
      force: force,
      recheckPermanentRejections: reason == 'manual_rejection_recheck',
    );
  }

  Future<T> runWithSyncPaused<T>({
    required Future<T> Function() operation,
    String reason = 'local_recovery',
    bool resumeSyncAfterRecovery = true,
  }) async {
    if (_localRecoveryActive) {
      throw StateError('Local synchronization recovery is already running.');
    }

    _recoverySessionGuard.beginRecovery();
    _localRecoveryActive = true;

    try {
      _ref.read(syncLocalRecoveryActiveProvider.notifier).state = true;
      final activeRun = _activeRunCompletion;
      if (activeRun != null) {
        await activeRun.future;
      }
      return await operation();
    } finally {
      _localRecoveryActive = false;
      try {
        _ref.read(syncLocalRecoveryActiveProvider.notifier).state = false;

        final followUp = _takeQueuedFollowUp();
        if (followUp != null) {
          _clearPendingFollowUpHealth();
        }
        if (resumeSyncAfterRecovery) {
          unawaited(
            _runFullSync(
              reason: '${followUp?.reason ?? reason} (recovery refresh)',
              force: true,
              queuedFollowUp: true,
              recheckPermanentRejections:
                  followUp?.recheckPermanentRejections ?? false,
            ),
          );
        }
      } finally {
        _recoverySessionGuard.endRecovery();
      }
    }
  }

  Future<SyncRequestOutcome> _runFullSync({
    String reason = 'unknown',
    bool force = false,
    bool queuedFollowUp = false,
    bool recheckPermanentRejections = false,
  }) async {
    final now = DateTime.now();

    if (_running || _localRecoveryActive) {
      _queueFollowUp(
        reason: reason,
        force: force,
        recheckPermanentRejections: recheckPermanentRejections,
      );
      return SyncRequestOutcome.queued;
    }

    if (!force && !queuedFollowUp && now.difference(_lastRun) < minGap) {
      _markSkipped(reason: '$reason (throttled)');
      return SyncRequestOutcome.throttled;
    }

    _running = true;
    _activeRunCompletion = Completer<void>();
    _lastRun = now;

    _ref.read(syncConflictProvider.notifier).state = 0;
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
      isRunning: true,
      lastStartedAt: now,
      lastReason: reason,
      lastSucceeded: false,
      failureDetails: const <SyncFailureDetail>[],
      failureDetailOverflowCount: 0,
      lastFailureLikelyPermanent: false,
      hasPendingFollowUp: _followUpRequested,
      pendingFollowUpReason: _followUpReason,
      pendingFollowUpForce: _followUpForce,
      clearLastError: true,
      clearPendingFollowUp: !_followUpRequested,
    );

    unawaited(
      _publishSyncStartContext(reason: reason, force: force, startedAt: now),
    );

    final runStamp = DateTime.now();

    try {
      // ORDER: ordinary snapshot push → canonical pull → safe replay of
      // uncertain workflow commands → workflow projection pull.
      await _sync.syncAll(
        recheckPermanentRejections: recheckPermanentRejections,
      );
      await _pull.pullAndReconcile();
      await _reconcileAuthoritativePurgeManifests();

      // Workflow is a supplemental control plane. Its retry/pull health is
      // reported independently so it cannot turn a successful mature
      // data-plane sync into an apparent whole-application failure.
      await _runWorkflowSupplementalSync(reason: reason);

      final conflictKeys = <String>{
        ..._sync.lastConflictKeys,
        ..._pull.lastConflictKeys,
      };
      final conflictCount =
          conflictKeys.isNotEmpty
              ? conflictKeys.length
              : _sync.lastConflictCount + _pull.lastConflicted;

      if (conflictCount > 0) {
        _ref.read(syncConflictProvider.notifier).state = conflictCount;
      }

      final hasFailures = _sync.lastFailureCount > 0;

      _ref.read(syncStatusProvider.notifier).state =
          hasFailures ? SyncStatus.failed : SyncStatus.success;

      final completedAt = DateTime.now();
      final nextRunCount = _health.runCount + 1;
      final failureDetails = List<SyncFailureDetail>.unmodifiable(
        _sync.lastFailureDetails,
      );

      _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
        isRunning: false,
        lastCompletedAt: completedAt,
        lastReason: reason,
        lastSucceeded: !hasFailures,
        successCount: _sync.lastSuccessCount,
        failureCount: _sync.lastFailureCount,
        conflictCount: conflictCount,
        runCount: nextRunCount,
        lastError: hasFailures ? 'Push sync reported failures.' : null,
        failureDetails: failureDetails,
        failureDetailOverflowCount: _sync.lastFailureDetailOverflowCount,
        lastFailureLikelyPermanent:
            hasFailures &&
            failureDetails.isNotEmpty &&
            _sync.lastFailureDetailOverflowCount == 0 &&
            failureDetails.every((detail) => detail.isLikelyPermanent),
        clearLastError: !hasFailures,
      );

      unawaited(
        _publishSyncCompletionContext(
          reason: reason,
          force: force,
          succeeded: !hasFailures,
          completedAt: completedAt,
          successCount: _sync.lastSuccessCount,
          failureCount: _sync.lastFailureCount,
          conflictCount: conflictCount,
          runCount: nextRunCount,
          failureDetails: failureDetails,
          failureDetailOverflowCount: _sync.lastFailureDetailOverflowCount,
        ),
      );

      if (hasFailures) {
        final firstFailure =
            failureDetails.isEmpty ? null : failureDetails.first;
        AppLogger.warning(
          'Full sync completed with push failures',
          context: {
            'app_area': 'sync',
            'sync_reason': reason,
            'sync_forced': force,
            'sync_success_count': _sync.lastSuccessCount,
            'sync_failure_count': _sync.lastFailureCount,
            'sync_conflict_count': conflictCount,
            if (firstFailure != null)
              'sync_first_failure_entity_type': firstFailure.entityType,
            if (firstFailure?.errorCode != null)
              'sync_first_failure_error_code': firstFailure!.errorCode!,
            if (firstFailure != null)
              'sync_first_failure_permanent': firstFailure.isLikelyPermanent,
          },
        );
        return SyncRequestOutcome.failed;
      }

      Future.delayed(const Duration(seconds: 5), () {
        final current = _ref.read(syncStatusProvider);

        if (current == SyncStatus.success &&
            !_running &&
            DateTime.now().difference(runStamp) >= const Duration(seconds: 5)) {
          _ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
        }
      });

      return SyncRequestOutcome.succeeded;
    } catch (error, stackTrace) {
      final completedAt = DateTime.now();
      final nextRunCount = _health.runCount + 1;
      final failureDetails = List<SyncFailureDetail>.unmodifiable(
        _sync.lastFailureDetails,
      );
      final conflictCount = _sync.lastConflictCount + _pull.lastConflicted;

      _ref.read(syncStatusProvider.notifier).state = SyncStatus.failed;
      _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
        isRunning: false,
        lastCompletedAt: completedAt,
        lastReason: reason,
        lastSucceeded: false,
        failureCount: _sync.lastFailureCount,
        conflictCount: conflictCount,
        runCount: nextRunCount,
        lastError: '$error',
        failureDetails: failureDetails,
        failureDetailOverflowCount: _sync.lastFailureDetailOverflowCount,
        lastFailureLikelyPermanent: syncFailureLikelyPermanent(error),
      );

      unawaited(
        _publishSyncCompletionContext(
          reason: reason,
          force: force,
          succeeded: false,
          completedAt: completedAt,
          successCount: _sync.lastSuccessCount,
          failureCount: _sync.lastFailureCount,
          conflictCount: conflictCount,
          runCount: nextRunCount,
          failureDetails: failureDetails,
          failureDetailOverflowCount: _sync.lastFailureDetailOverflowCount,
        ),
      );

      AppLogger.error(
        'Full sync threw before normal completion',
        error: error,
        stackTrace: stackTrace,
        fatal: false,
        context: {
          'app_area': 'sync',
          'sync_reason': reason,
          'sync_forced': force,
          'sync_success_count': _sync.lastSuccessCount,
          'sync_failure_count': _sync.lastFailureCount,
          'sync_conflict_count': conflictCount,
          ...syncFailureDiagnosticContext(
            error,
            pullDomain: _pull.lastFailedDomain,
          ),
        },
      );
      return SyncRequestOutcome.failed;
    } finally {
      final followUp = _localRecoveryActive ? null : _takeQueuedFollowUp();
      _running = false;
      final completedRun = _activeRunCompletion;
      _activeRunCompletion = null;
      if (completedRun != null && !completedRun.isCompleted) {
        completedRun.complete();
      }
      unawaited(AppLogger.setCustomKey('sync_running', false));

      if (followUp != null) {
        _clearPendingFollowUpHealth();
        unawaited(
          _runFullSync(
            reason: '${followUp.reason} (queued follow-up)',
            force: followUp.force,
            queuedFollowUp: true,
            recheckPermanentRejections: followUp.recheckPermanentRejections,
          ),
        );
      }
    }
  }

  Future<void> _reconcileAuthoritativePurgeManifests() async {
    final actor = _ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.isApproved) return;
    try {
      await _ref
          .read(localSyncRecoveryServiceProvider)
          .reconcileAuthoritativelyPurgedTombstones(actor: actor);
    } catch (error, stackTrace) {
      // Local compaction is best-effort. A failed manifest read must not turn
      // an otherwise healthy business-data synchronization into a failure.
      debugPrint('Authoritative purge reconciliation deferred: $error');
      unawaited(
        AppLogger.recordNonFatalError(
          error,
          stackTrace,
          reason: 'authoritative_purge_reconciliation_deferred',
          context: const {
            'app_area': 'sync',
            'sync_phase': 'purge_manifest_reconciliation',
          },
        ),
      );
    }
  }

  Future<void> _runWorkflowSupplementalSync({required String reason}) async {
    try {
      await _ref.read(workflowUncertainRetryServiceProvider).retryDueCommands();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Workflow uncertain-command retry failed independently',
        context: {
          'app_area': 'maintenance_workflow',
          'sync_reason': reason,
          'workflow_stage': 'uncertain_retry',
          'workflow_error': '$error',
        },
      );
      unawaited(
        AppLogger.recordNonFatalError(
          error,
          stackTrace,
          reason: 'workflow_uncertain_retry_failed',
          context: {'sync_reason': reason},
        ),
      );
    }

    try {
      final summary = await _ref.read(workflowPullServiceProvider).pull();
      if (summary.hasFailures) {
        AppLogger.warning(
          'Workflow projection pull completed with isolated failures',
          context: {
            'app_area': 'maintenance_workflow',
            'sync_reason': reason,
            'workflow_failed_collections': summary.failures.keys.join(','),
            'workflow_failure_count': summary.failures.length,
            'workflow_quarantined_record_count':
                summary.quarantinedRecords.length,
            'workflow_quarantined_record_ids': summary.quarantinedRecords
                .map((record) => '${record.collection}/${record.documentId}')
                .take(20)
                .join(','),
          },
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Workflow projection pull failed before collection isolation',
        context: {
          'app_area': 'maintenance_workflow',
          'sync_reason': reason,
          'workflow_stage': 'pull_initialization',
          'workflow_error': '$error',
        },
      );
      unawaited(
        AppLogger.recordNonFatalError(
          error,
          stackTrace,
          reason: 'workflow_projection_pull_failed',
          context: {'sync_reason': reason},
        ),
      );
    }
  }

  void _queueFollowUp({
    required String reason,
    required bool force,
    required bool recheckPermanentRejections,
  }) {
    final queuedAt = DateTime.now();
    final mergedReason = _mergeQueuedSyncReasons(_followUpReason, reason);

    _followUpRequested = true;
    _followUpReason = mergedReason;
    _followUpForce = _followUpForce || force;
    _followUpRecheckPermanentRejections =
        _followUpRecheckPermanentRejections || recheckPermanentRejections;

    _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
      lastSkippedAt: queuedAt,
      lastSkippedReason: '$reason (queued while running)',
      hasPendingFollowUp: true,
      pendingFollowUpReason: mergedReason,
      pendingFollowUpForce: _followUpForce,
    );

    unawaited(
      AppLogger.setCustomKeys({
        'sync_last_skipped_at': queuedAt.toIso8601String(),
        'sync_last_skipped_reason': '$reason (queued while running)',
        'sync_followup_pending': true,
        'sync_followup_reason': mergedReason,
        'sync_followup_forced': _followUpForce,
      }),
    );
  }

  _QueuedSyncFollowUp? _takeQueuedFollowUp() {
    if (!_followUpRequested) {
      return null;
    }

    final followUp = _QueuedSyncFollowUp(
      reason: _followUpReason ?? 'queued sync',
      force: _followUpForce,
      recheckPermanentRejections: _followUpRecheckPermanentRejections,
    );

    _followUpRequested = false;
    _followUpReason = null;
    _followUpForce = false;
    _followUpRecheckPermanentRejections = false;

    return followUp;
  }

  void _clearPendingFollowUpHealth() {
    _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
      clearPendingFollowUp: true,
    );
    unawaited(
      AppLogger.setCustomKeys({
        'sync_followup_pending': false,
        'sync_followup_reason': '',
        'sync_followup_forced': false,
      }),
    );
  }

  String _mergeQueuedSyncReasons(String? existing, String next) {
    final cleanNext = next.trim().isEmpty ? 'unknown' : next.trim();
    final cleanExisting = existing?.trim();

    if (cleanExisting == null || cleanExisting.isEmpty) {
      return cleanNext;
    }
    if (cleanExisting.contains(cleanNext)) {
      return cleanExisting;
    }

    final merged = '$cleanExisting; $cleanNext';
    if (merged.length <= 180) {
      return merged;
    }
    return '${merged.substring(0, 177)}...';
  }

  void _markSkipped({required String reason}) {
    final skippedAt = DateTime.now();
    _ref.read(syncRunHealthProvider.notifier).state = _health.copyWith(
      lastSkippedAt: skippedAt,
      lastSkippedReason: reason,
    );
    unawaited(
      AppLogger.setCustomKeys({
        'sync_last_skipped_at': skippedAt.toIso8601String(),
        'sync_last_skipped_reason': reason,
      }),
    );
  }

  Future<void> _publishSyncStartContext({
    required String reason,
    required bool force,
    required DateTime startedAt,
  }) async {
    await AppLogger.setCustomKeys({
      'sync_running': true,
      'sync_last_reason': reason,
      'sync_last_forced': force,
      'sync_last_started_at': startedAt.toIso8601String(),
      'sync_last_succeeded': false,
    });
    AppLogger.info(
      'Full sync started',
      context: {
        'app_area': 'sync',
        'sync_reason': reason,
        'sync_forced': force,
      },
    );
  }

  Future<void> _publishSyncCompletionContext({
    required String reason,
    required bool force,
    required bool succeeded,
    required DateTime completedAt,
    required int successCount,
    required int failureCount,
    required int conflictCount,
    required int runCount,
    required List<SyncFailureDetail> failureDetails,
    required int failureDetailOverflowCount,
  }) async {
    final firstFailure = failureDetails.isEmpty ? null : failureDetails.first;

    await AppLogger.setCustomKeys({
      'sync_running': false,
      'sync_last_reason': reason,
      'sync_last_forced': force,
      'sync_last_completed_at': completedAt.toIso8601String(),
      'sync_last_succeeded': succeeded,
      'sync_last_success_count': successCount,
      'sync_last_failure_count': failureCount,
      'sync_last_conflict_count': conflictCount,
      'sync_run_count': runCount,
      'sync_failure_detail_overflow': failureDetailOverflowCount,
      'sync_first_failure_entity_type': firstFailure?.entityType ?? '',
      'sync_first_failure_error_code': firstFailure?.errorCode ?? '',
      'sync_first_failure_permanent': firstFailure?.isLikelyPermanent ?? false,
    });
  }

  SyncRunHealth get _health => _ref.read(syncRunHealthProvider);

  // ─────────────────────────────────────────────────────────────
  // CONNECTIVITY LISTENER
  // ─────────────────────────────────────────────────────────────

  void _initConnectivityListener() {
    if (_initialized) return;
    _initialized = true;

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection) {
        unawaited(runFullSync(reason: 'reconnected', force: true));
      }
    });

    // Deliberately no immediate checkConnectivity() startup sync here.
    // AuthGate owns startup sync and only marks syncOnceProvider true after a
    // successfully completed run, never for a queued or throttled request.
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    ref,
    ref.read(syncServiceProvider),
    ref.read(pullServiceProvider),
    ref.read(localRecoverySessionGuardProvider),
  );

  ref.onDispose(() => coordinator.dispose());

  return coordinator;
});
