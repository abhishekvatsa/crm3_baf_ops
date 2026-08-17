// FILE: lib/core/widgets/sync_status_indicator.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_conflict_provider.dart';
import '../providers/sync_status_provider.dart';
import '../services/auto_sync_service.dart';
import '../services/live_remote_sync_service.dart';
import '../services/sync_coordinator.dart';
import '../services/sync_rejection_service.dart';
import '../services/sync_service.dart';
import '../../features/audit/models/audit_event_model.dart';
import '../../features/auth/data/user_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../theme/baf_design_system.dart';

// ─────────────────────────────────────────────────────────────
// DURABLE LOCAL SYNC REJECTION SUMMARY
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// SYNC STATUS INDICATOR + HEALTH PANEL
// ─────────────────────────────────────────────────────────────

class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator> {
  bool _isHealthPanelOpen = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final conflictCount = ref.watch(syncConflictProvider);
    final runHealth = ref.watch(syncRunHealthProvider);
    final liveHealth = ref.watch(liveRemoteSyncHealthProvider);
    final pendingAsync = ref.watch(syncPendingCountsProvider);

    final pendingCount = pendingAsync.asData?.value.total;
    final visual = _visualFor(
      status,
      conflictCount,
      runHealth,
      liveHealth,
      pendingCount,
    );
    final isSyncing = status == SyncStatus.syncing || runHealth.isRunning;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: visual.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(BafRadius.medium),
          border: Border.all(color: visual.color.withValues(alpha: 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(BafRadius.medium),
              onTap: () => _showHealthPanel(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BafSpacing.sm,
                  vertical: BafSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child:
                          isSyncing
                              ? SizedBox(
                                key: const ValueKey('spinner'),
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    visual.color,
                                  ),
                                ),
                              )
                              : Icon(
                                visual.icon,
                                key: ValueKey(visual.icon),
                                size: 18,
                                color: visual.color,
                              ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      visual.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: visual.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      color: visual.color.withValues(alpha: 0.78),
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 18,
              color: visual.color.withValues(alpha: 0.20),
            ),
            TextButton.icon(
              onPressed:
                  isSyncing
                      ? null
                      : () => _runManualSync(context, source: 'indicator'),
              style: TextButton.styleFrom(
                foregroundColor: visual.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: BafSpacing.sm,
                  vertical: BafSpacing.xs,
                ),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: Text(
                isSyncing ? 'Syncing' : 'Sync now',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runManualSync(
    BuildContext context, {
    required String source,
  }) async {
    final coordinator = ref.read(syncCoordinatorProvider);
    final autoSyncService = ref.read(autoSyncServiceProvider);

    try {
      final outcome = await coordinator.runFullSyncWithResult(
        reason: 'manual_$source',
        force: true,
      );

      if (!mounted) return;

      if (outcome.isSuccessful) {
        autoSyncService.clearPendingTicketSync();
      }

      ref.invalidate(syncPendingCountsProvider);

      if (!context.mounted) return;
      _showSyncSnack(
        context,
        outcome.manualSyncMessage,
        _manualSyncColor(outcome),
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSyncSnack(context, 'Manual sync failed: $error', BafColors.danger);
    }
  }

  Future<void> _showHealthPanel(BuildContext context) async {
    if (_isHealthPanelOpen) return;
    _isHealthPanelOpen = true;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Consumer(
            builder: (context, ref, _) {
              final status = ref.watch(syncStatusProvider);
              final conflictCount = ref.watch(syncConflictProvider);
              final runHealth = ref.watch(syncRunHealthProvider);
              final liveHealth = ref.watch(liveRemoteSyncHealthProvider);
              final autoHealth = ref.watch(autoSyncHealthProvider);
              final pendingAsync = ref.watch(syncPendingCountsProvider);
              final recentRejectionsAsync = ref.watch(
                recentSyncRejectionsProvider,
              );
              final actorAsync = ref.watch(currentAppUserProvider);
              final actor = actorAsync.asData?.value;
              final canResolveSyncRejections =
                  actor?.canResolveSyncConflicts == true;
              final isSyncing =
                  status == SyncStatus.syncing || runHealth.isRunning;

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.72,
                minChildSize: 0.42,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: BafColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(BafRadius.xLarge),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        BafSpacing.lg,
                        BafSpacing.sm,
                        BafSpacing.lg,
                        BafSpacing.xl,
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: BafColors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: BafSpacing.lg),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: BafColors.sync.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  BafRadius.medium,
                                ),
                              ),
                              child: const Icon(
                                Icons.health_and_safety_rounded,
                                color: BafColors.sync,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: BafSpacing.md),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sync health',
                                    style: TextStyle(
                                      color: BafColors.textPrimary,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Freshness, live receiving, and pending work.',
                                    style: TextStyle(
                                      color: BafColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.lg),
                        _HealthCard(
                          title: 'Manual override',
                          icon: Icons.sync_rounded,
                          color: BafColors.sync,
                          children: [
                            Text(
                              isSyncing
                                  ? 'A sync is already running.'
                                  : 'Press to push and pull everything now, without waiting for the 5-minute or 20-minute timers.',
                              style: const TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: BafSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    isSyncing
                                        ? null
                                        : () async {
                                          await _runManualSync(
                                            sheetContext,
                                            source: 'health_panel',
                                          );
                                        },
                                style: FilledButton.styleFrom(
                                  backgroundColor: BafColors.sync,
                                  foregroundColor: Colors.white,
                                ),
                                icon: Icon(
                                  isSyncing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.sync_rounded,
                                ),
                                label: Text(
                                  isSyncing ? 'Syncing…' : 'Sync now',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        _HealthCard(
                          title: 'Full sync engine',
                          icon: Icons.cloud_done_rounded,
                          color: _statusColor(status, runHealth),
                          children: [
                            _HealthRow(
                              'Status',
                              _statusLabel(status, runHealth),
                            ),
                            _HealthRow(
                              'Last completed',
                              _relativeTime(runHealth.lastCompletedAt),
                            ),
                            _HealthRow(
                              'Last reason',
                              runHealth.lastReason ?? '—',
                            ),
                            if (runHealth.hasPendingFollowUp) ...[
                              _HealthRow(
                                'Pending follow-up',
                                runHealth.pendingFollowUpForce
                                    ? 'Queued · forced'
                                    : 'Queued',
                              ),
                              _HealthRow(
                                'Follow-up reason',
                                runHealth.pendingFollowUpReason ?? '—',
                              ),
                            ],
                            _HealthRow(
                              'Last result',
                              runHealth.lastSucceeded == null
                                  ? 'No completed run yet'
                                  : (runHealth.lastSucceeded!
                                      ? 'Success'
                                      : 'Failed'),
                            ),
                            _HealthRow(
                              'Last push result',
                              '${runHealth.successCount} success / ${runHealth.failureCount} failed',
                            ),
                            if (conflictCount > 0)
                              _HealthRow('Conflicts', '$conflictCount'),
                            if (runHealth.lastSkippedReason != null)
                              _HealthRow(
                                'Last skipped',
                                '${runHealth.lastSkippedReason} • ${_relativeTime(runHealth.lastSkippedAt)}',
                              ),
                            if (runHealth.lastError != null)
                              _HealthRow('Last error', runHealth.lastError!),
                            if (runHealth.failureDetails.isNotEmpty) ...[
                              const SizedBox(height: BafSpacing.sm),
                              const _SectionLabel('Affected records'),
                              ...runHealth.failureDetails
                                  .take(5)
                                  .map(
                                    (detail) =>
                                        _FailureDetailRow(detail: detail),
                                  ),
                              if (runHealth.failureDetails.length > 5 ||
                                  runHealth.failureDetailOverflowCount > 0)
                                _HealthRow(
                                  'More affected',
                                  '+${(runHealth.failureDetails.length > 5 ? runHealth.failureDetails.length - 5 : 0) + runHealth.failureDetailOverflowCount} more',
                                ),
                            ],
                            recentRejectionsAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error:
                                  (error, _) => _HealthRow(
                                    'Durable rejection log',
                                    'Could not read local sync rejections: $error',
                                  ),
                              data: (rejections) {
                                if (rejections.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: BafSpacing.sm),
                                    const _SectionLabel(
                                      'Recent durable sync rejections',
                                    ),
                                    ...rejections.map(
                                      (row) => _SyncRejectionRow(
                                        row: row,
                                        canResolve: canResolveSyncRejections,
                                        onResolve:
                                            canResolveSyncRejections &&
                                                    actor != null
                                                ? () =>
                                                    _showResolveSyncRejectionDialog(
                                                      sheetContext,
                                                      ref,
                                                      row,
                                                      actor,
                                                    )
                                                : null,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        _HealthCard(
                          title: 'Pending local writes',
                          icon: Icons.pending_actions_rounded,
                          color: _pendingColor(pendingAsync.asData?.value),
                          children: [
                            pendingAsync.when(
                              loading:
                                  () => const _InlineLoadingText(
                                    text: 'Checking pending local records…',
                                  ),
                              error:
                                  (error, _) => Text(
                                    'Could not read pending local records: $error',
                                    style: const TextStyle(
                                      color: BafColors.danger,
                                      fontSize: 13,
                                    ),
                                  ),
                              data:
                                  (pending) => Column(
                                    children: [
                                      _HealthRow(
                                        'Total pending',
                                        '${pending.total}',
                                      ),
                                      _HealthRow(
                                        'Maintenance tickets',
                                        '${pending.maintenanceTickets}',
                                      ),
                                      _HealthRow(
                                        'Job templates',
                                        '${pending.jobTemplates}',
                                      ),
                                      _HealthRow(
                                        'Job executions',
                                        '${pending.jobExecutions}',
                                      ),
                                      _HealthRow(
                                        'Directives',
                                        '${pending.directives}',
                                      ),
                                      _HealthRow(
                                        'Abnormality types',
                                        '${pending.abnormalityTypes}',
                                      ),
                                      _HealthRow(
                                        'Charge abnormalities',
                                        '${pending.chargeAbnormalities}',
                                      ),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        _HealthCard(
                          title: 'Issue timers',
                          icon: Icons.timer_rounded,
                          color:
                              autoHealth.normalIssueSyncPending
                                  ? BafColors.warning
                                  : BafColors.success,
                          children: [
                            _HealthRow(
                              'Auto-sync service',
                              autoHealth.isStarted ? 'Active' : 'Stopped',
                            ),
                            _HealthRow(
                              'Normal issue queue',
                              autoHealth.normalIssueSyncPending
                                  ? 'Pending'
                                  : 'None waiting',
                            ),
                            _HealthRow(
                              'Next normal issue sync',
                              _relativeTime(autoHealth.nextNormalIssueSyncAt),
                            ),
                            _HealthRow(
                              'Next 20-minute sync',
                              _relativeTime(autoHealth.nextGeneralSyncAt),
                            ),
                            _HealthRow(
                              'Last automatic attempt',
                              _relativeTime(autoHealth.lastAutomaticAttemptAt),
                            ),
                            _HealthRow(
                              'Last automatic result',
                              autoHealth.lastAutomaticOutcome == null
                                  ? '—'
                                  : autoHealth
                                      .lastAutomaticOutcome!
                                      .diagnosticLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        _HealthCard(
                          title: 'Live receiving',
                          icon: Icons.sensors_rounded,
                          color: _liveColor(liveHealth),
                          children: [
                            _HealthRow(
                              'Open-ticket listener',
                              _liveLabel(liveHealth.maintenanceState),
                            ),
                            _HealthRow(
                              'Scope',
                              liveHealth.maintenanceScopeLabel ?? '—',
                            ),
                            _HealthRow(
                              'Listener count',
                              '${liveHealth.listenerCount}',
                            ),
                            _HealthRow(
                              'Started',
                              _relativeTime(liveHealth.startedAt),
                            ),
                            _HealthRow(
                              'Paused',
                              _relativeTime(liveHealth.pausedAt),
                            ),
                            _HealthRow(
                              'Last remote event',
                              _relativeTime(liveHealth.lastEventAt),
                            ),
                            _HealthRow(
                              'Last applied locally',
                              _relativeTime(liveHealth.lastAppliedAt),
                            ),
                            _HealthRow(
                              'Applied records',
                              '${liveHealth.appliedCount}',
                            ),
                            _HealthRow(
                              'Skipped local edits',
                              '${liveHealth.skippedUnsyncedLocalCount}',
                            ),
                            _HealthRow(
                              'Removed-query events',
                              '${liveHealth.removedEventCount}',
                            ),
                            _HealthRow(
                              'Pause / resume',
                              '${liveHealth.pauseCount} / ${liveHealth.resumeCount}',
                            ),
                            if (liveHealth.lastError != null)
                              _HealthRow(
                                'Last live error',
                                liveHealth.lastError!,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      _isHealthPanelOpen = false;
    }
  }
}

_SyncVisual _visualFor(
  SyncStatus status,
  int conflictCount,
  SyncRunHealth runHealth,
  LiveRemoteSyncHealth liveHealth,
  int? pendingCount,
) {
  if (status == SyncStatus.syncing || runHealth.isRunning) {
    return _SyncVisual(
      icon:
          runHealth.hasPendingFollowUp
              ? Icons.schedule_send_rounded
              : Icons.sync_rounded,
      color: BafColors.planned,
      label: runHealth.hasPendingFollowUp ? 'Sync queued' : 'Syncing',
    );
  }

  if (conflictCount > 0) {
    return _SyncVisual(
      icon: Icons.warning_amber_rounded,
      color: BafColors.warning,
      label: conflictCount == 1 ? '1 conflict' : '$conflictCount conflicts',
    );
  }

  if (status == SyncStatus.failed || liveHealth.hasError) {
    return const _SyncVisual(
      icon: Icons.error_outline_rounded,
      color: BafColors.danger,
      label: 'Sync issue',
    );
  }

  if (pendingCount != null && pendingCount > 0) {
    return _SyncVisual(
      icon: Icons.cloud_upload_outlined,
      color: BafColors.warning,
      label: '$pendingCount pending',
    );
  }

  if (liveHealth.isListening) {
    return const _SyncVisual(
      icon: Icons.sensors_rounded,
      color: BafColors.success,
      label: 'Live',
    );
  }

  if (status == SyncStatus.success) {
    return const _SyncVisual(
      icon: Icons.cloud_done_rounded,
      color: BafColors.success,
      label: 'Synced',
    );
  }

  return const _SyncVisual(
    icon: Icons.cloud_upload_outlined,
    color: BafColors.sync,
    label: 'Sync',
  );
}

Color _manualSyncColor(SyncRequestOutcome outcome) {
  return switch (outcome) {
    SyncRequestOutcome.succeeded => BafColors.sync,
    SyncRequestOutcome.failed => BafColors.danger,
    SyncRequestOutcome.queued => BafColors.planned,
    SyncRequestOutcome.throttled => BafColors.warning,
  };
}

void _showSyncSnack(BuildContext context, String message, Color color) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
}

Future<void> _showResolveSyncRejectionDialog(
  BuildContext context,
  WidgetRef ref,
  SyncRejection rejection,
  AppUser actor,
) async {
  if (!actor.canResolveSyncConflicts) {
    _showSyncSnack(
      context,
      'Only Admin users can resolve sync rejections.',
      BafColors.danger,
    );
    return;
  }

  final initialNote =
      rejection.isLikelyPermanent
          ? 'Reviewed. Underlying data, role, or Firestore rule condition has been corrected; allow retry on next sync.'
          : 'Reviewed; allow retry on next sync.';

  final resolutionNotes = await showDialog<String>(
    context: context,
    builder:
        (dialogContext) => _ResolveSyncRejectionDialog(
          rejection: rejection,
          initialNote: initialNote,
        ),
  );

  if (!context.mounted) return;
  if (resolutionNotes == null) return;

  await _resolveSyncRejection(
    context,
    ref,
    rejection,
    actor,
    notes: resolutionNotes,
  );
}

Future<void> _resolveSyncRejection(
  BuildContext context,
  WidgetRef ref,
  SyncRejection rejection,
  AppUser actor, {
  required String notes,
}) async {
  try {
    await ref
        .read(syncRejectionServiceProvider)
        .resolve(rejectionId: rejection.id, actor: actor, notes: notes);

    ref.invalidate(recentSyncRejectionsProvider);
    ref.invalidate(syncPendingCountsProvider);

    if (!context.mounted) return;
    _showSyncSnack(
      context,
      'Sync rejection marked resolved. The source record remains dirty and may retry on the next sync.',
      BafColors.sync,
    );
  } catch (error) {
    if (!context.mounted) return;
    _showSyncSnack(
      context,
      'Could not resolve sync rejection: $error',
      BafColors.danger,
    );
  }
}

Color _statusColor(SyncStatus status, SyncRunHealth health) {
  if (health.isRunning || status == SyncStatus.syncing) {
    return BafColors.planned;
  }
  if (status == SyncStatus.failed || health.lastSucceeded == false) {
    return BafColors.danger;
  }
  if (health.lastSucceeded == true) {
    return BafColors.success;
  }
  return BafColors.sync;
}

String _statusLabel(SyncStatus status, SyncRunHealth health) {
  if (health.isRunning || status == SyncStatus.syncing) {
    return 'Running';
  }

  switch (status) {
    case SyncStatus.idle:
      return 'Idle';
    case SyncStatus.syncing:
      return 'Running';
    case SyncStatus.success:
      return 'Success';
    case SyncStatus.failed:
      return 'Failed';
  }
}

Color _pendingColor(SyncPendingCounts? pending) {
  if (pending == null) {
    return BafColors.sync;
  }
  return pending.total > 0 ? BafColors.warning : BafColors.success;
}

Color _liveColor(LiveRemoteSyncHealth health) {
  switch (health.maintenanceState) {
    case LiveRemoteSyncConnectionState.disabled:
      return BafColors.textSecondary;
    case LiveRemoteSyncConnectionState.disconnected:
      return BafColors.warning;
    case LiveRemoteSyncConnectionState.paused:
      return BafColors.warning;
    case LiveRemoteSyncConnectionState.listening:
      return BafColors.success;
    case LiveRemoteSyncConnectionState.error:
      return BafColors.danger;
  }
}

String _liveLabel(LiveRemoteSyncConnectionState state) {
  switch (state) {
    case LiveRemoteSyncConnectionState.disabled:
      return 'Disabled on this platform';
    case LiveRemoteSyncConnectionState.disconnected:
      return 'Disconnected';
    case LiveRemoteSyncConnectionState.paused:
      return 'Paused in background';
    case LiveRemoteSyncConnectionState.listening:
      return 'Listening';
    case LiveRemoteSyncConnectionState.error:
      return 'Error';
  }
}

String _relativeTime(DateTime? time) {
  if (time == null) {
    return '—';
  }

  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.isNegative) {
    final until = time.difference(now);
    if (until.inMinutes >= 1) {
      return 'in ${until.inMinutes} min';
    }
    return 'in ${until.inSeconds.clamp(0, 59)} sec';
  }

  if (diff.inDays > 0) {
    return '${diff.inDays} d ago';
  }
  if (diff.inHours > 0) {
    return '${diff.inHours} h ago';
  }
  if (diff.inMinutes > 0) {
    return '${diff.inMinutes} min ago';
  }
  return '${diff.inSeconds.clamp(0, 59)} sec ago';
}

class _ResolveSyncRejectionDialog extends StatefulWidget {
  final SyncRejection rejection;
  final String initialNote;

  const _ResolveSyncRejectionDialog({
    required this.rejection,
    required this.initialNote,
  });

  @override
  State<_ResolveSyncRejectionDialog> createState() =>
      _ResolveSyncRejectionDialogState();
}

class _ResolveSyncRejectionDialogState
    extends State<_ResolveSyncRejectionDialog> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.initialNote);
    _notesController.addListener(_handleNotesChanged);
  }

  void _handleNotesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notesController.removeListener(_handleNotesChanged);
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rejection = widget.rejection;
    final canSubmit = _notesController.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(
        rejection.isLikelyPermanent
            ? 'Resolve retry-held sync rejection?'
            : 'Mark sync rejection reviewed?',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rejection.shortLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: BafSpacing.xs),
              Text(
                rejection.displayMessage,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              const Text(
                'This only resolves the local rejection hold so the record may retry on a future sync. It does not mark the source record as synced, accepted, corrected, or deleted.',
                style: TextStyle(
                  color: BafColors.warning,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Resolution note',
                  hintText: 'What changed before retry is allowed?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              canSubmit
                  ? () =>
                      Navigator.of(context).pop(_notesController.text.trim())
                  : null,
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Mark resolved'),
        ),
      ],
    );
  }
}

class _SyncVisual {
  final IconData icon;
  final Color color;
  final String label;

  const _SyncVisual({
    required this.icon,
    required this.color,
    required this.label,
  });
}

class _HealthCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _HealthCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: BafColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SyncRejectionRow extends StatelessWidget {
  final SyncRejection row;
  final bool canResolve;
  final VoidCallback? onResolve;

  const _SyncRejectionRow({
    required this.row,
    required this.canResolve,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final suffix =
        row.isLikelyPermanent
            ? ' • automatic retry held until resolved'
            : ' • retryable';

    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.xs),
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: BafColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.danger.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: BafSpacing.xs),
              Text(
                '${row.attemptCount}x',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${row.displayMessage}$suffix',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
              height: 1.25,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child:
                canResolve
                    ? TextButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: Text(
                        row.isLikelyPermanent
                            ? 'Resolve / allow retry'
                            : 'Mark reviewed',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: BafColors.sync,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    : Text(
                      row.isLikelyPermanent
                          ? 'Admin review required'
                          : 'Admin can mark reviewed',
                      style: const TextStyle(
                        color: BafColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _FailureDetailRow extends StatelessWidget {
  final SyncFailureDetail detail;

  const _FailureDetailRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final suffix = detail.isLikelyPermanent ? ' • likely needs review' : '';
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.xs),
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: BafColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.danger.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.shortLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${detail.displayMessage}$suffix',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;

  const _HealthRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            flex: 7,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadingText extends StatelessWidget {
  final String text;

  const _InlineLoadingText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
