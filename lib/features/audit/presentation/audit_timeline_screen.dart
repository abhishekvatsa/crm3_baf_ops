// FILE: lib/features/audit/presentation/audit_timeline_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_event_model.dart';
import '../providers/audit_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final auditTimelineProvider = FutureProvider.family
    .autoDispose<List<AuditEvent>, ({String type, String id})>((ref, args) {
      final repo = ref.read(auditRepositoryProvider);

      if (kIsWeb) {
        return repo.getRemoteEventsForEntity(args.type, args.id);
      }

      return repo.getLocalEventsForEntity(args.type, args.id);
    });

final syncConflictAuditProvider = FutureProvider.autoDispose<List<AuditEvent>>((
  ref,
) {
  return ref.read(auditRepositoryProvider).getRecentSyncConflictEvents();
});

final recentAuditEventsProvider = FutureProvider.autoDispose<List<AuditEvent>>((
  ref,
) {
  return ref.read(auditRepositoryProvider).getRecentLocalEvents();
});

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────

class AuditTimelineScreen extends ConsumerWidget {
  final String entityType;
  final String entityId;

  const AuditTimelineScreen({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const _AuditAccessState(
        appBarTitle: 'Audit Timeline',
        title: 'Checking audit access',
        message: 'Please wait while your permissions are verified.',
        showProgress: true,
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewAuditLogs) {
      return const _AuditAccessState(
        appBarTitle: 'Audit Timeline',
        title: 'Admin access required',
        message: 'Only approved Admin users can inspect audit evidence.',
      );
    }

    final auditAsync = ref.watch(
      auditTimelineProvider((type: entityType, id: entityId)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Audit Timeline")),
      body: auditAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text("No history available"));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                auditTimelineProvider((type: entityType, id: entityId)),
              );
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (_, i) => _AuditTile(event: events[i]),
            ),
          );
        },
      ),
    );
  }
}

class RecentAuditLogScreen extends ConsumerWidget {
  const RecentAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const _AuditAccessState(
        appBarTitle: 'Audit Log',
        title: 'Checking audit access',
        message: 'Please wait while your permissions are verified.',
        showProgress: true,
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewAuditLogs) {
      return const _AuditAccessState(
        appBarTitle: 'Audit Log',
        title: 'Admin access required',
        message: 'Only approved Admin users can inspect the audit log.',
      );
    }

    final eventsAsync = ref.watch(recentAuditEventsProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            tooltip: 'Refresh audit log',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(recentAuditEventsProvider),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(BafSpacing.lg),
                child: Text(
                  'Could not load audit activity: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BafColors.danger),
                ),
              ),
            ),
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('No audit activity available'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(recentAuditEventsProvider);
              await ref.read(recentAuditEventsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
              itemCount: events.length,
              itemBuilder: (_, index) => _AuditTile(event: events[index]),
            ),
          );
        },
      ),
    );
  }
}

class SyncConflictReviewScreen extends ConsumerWidget {
  const SyncConflictReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const _AuditAccessState(
        appBarTitle: 'Sync Conflict Review',
        title: 'Checking conflict-review access',
        message: 'Please wait while your permissions are verified.',
        showProgress: true,
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canReviewSyncConflicts) {
      return const _AuditAccessState(
        appBarTitle: 'Sync Conflict Review',
        title: 'Admin access required',
        message: 'Only approved Admin users can review sync conflicts.',
      );
    }

    final conflictsAsync = ref.watch(syncConflictAuditProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Sync Conflict Review',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: BafColors.navy,
        actions: [
          IconButton(
            tooltip: 'Refresh conflicts',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.invalidate(syncConflictAuditProvider),
          ),
        ],
      ),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(BafSpacing.lg),
                child: Text(
                  'Could not load sync conflicts: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BafColors.danger),
                ),
              ),
            ),
        data: (events) {
          if (events.isEmpty) {
            return const _NoSyncConflictsState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(syncConflictAuditProvider);
              await ref.read(syncConflictAuditProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.md,
                BafSpacing.xl,
              ),
              children: [
                _SyncConflictSummaryCard(count: events.length),
                const SizedBox(height: BafSpacing.md),
                ...events.map((event) => _AuditTile(event: event)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AuditAccessState extends StatelessWidget {
  final String appBarTitle;
  final String title;
  final String message;
  final bool showProgress;

  const _AuditAccessState({
    required this.appBarTitle,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(title: Text(appBarTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress)
                const CircularProgressIndicator()
              else
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 44,
                  color: BafColors.danger,
                ),
              const SizedBox(height: BafSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: BafColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSyncConflictsState extends StatelessWidget {
  const _NoSyncConflictsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BafSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: BafColors.success, size: 42),
              SizedBox(height: BafSpacing.md),
              Text(
                'No sync conflicts found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: BafSpacing.sm),
              Text(
                'When sync preserves a local/remote conflict, it will appear here for admin review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BafColors.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncConflictSummaryCard extends StatelessWidget {
  final int count;

  const _SyncConflictSummaryCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: BafColors.warning,
            size: 30,
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count preserved sync ${count == 1 ? 'conflict' : 'conflicts'}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                const Text(
                  'These records were not auto-overwritten. Review the before/after snapshots before deciding a resolution policy.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TILE
// ─────────────────────────────────────────────────────────────

class _AuditTile extends StatefulWidget {
  final AuditEvent event;

  const _AuditTile({required this.event});

  @override
  State<_AuditTile> createState() => _AuditTileState();
}

class _AuditTileState extends State<_AuditTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final color = _colorForSeverity(e.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───────── HEADER ─────────
              Row(
                children: [
                  Icon(_iconForAction(e.action), color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.summary ?? e.action.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(e.timestamp),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ───────── META ─────────
              Text(
                "By: ${e.performedByName ?? e.performedByUid}",
                style: const TextStyle(fontSize: 12),
              ),

              if (e.reason != null)
                Text(
                  "Reason: ${e.reason!.name}",
                  style: const TextStyle(fontSize: 12),
                ),

              if (e.reasonNotes != null)
                Text(
                  "Notes: ${e.reasonNotes}",
                  style: const TextStyle(fontSize: 12),
                ),

              // ───────── EXPANDED DIFF ─────────
              if (expanded) ...[const Divider(), _buildDiff(e)],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DIFF VIEW
  // ─────────────────────────────────────────────

  Widget _buildDiff(AuditEvent e) {
    final before = e.before;
    final after = e.after;

    if (before == null && after == null) {
      return const Text("No additional data");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (before != null) ...[
          const Text("Before:", style: TextStyle(fontWeight: FontWeight.bold)),
          _jsonView(before),
        ],
        if (after != null) ...[
          const SizedBox(height: 6),
          const Text("After:", style: TextStyle(fontWeight: FontWeight.bold)),
          _jsonView(after),
        ],
      ],
    );
  }

  Widget _jsonView(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        const JsonEncoder.withIndent('  ').convert(data),
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  IconData _iconForAction(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle;
      case AuditAction.update:
        return Icons.edit;
      case AuditAction.resolve:
        return Icons.check_circle;
      case AuditAction.reopen:
        return Icons.refresh;
      case AuditAction.delete:
        return Icons.delete;
    }
  }

  Color _colorForSeverity(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.low:
        return Colors.grey;
      case AuditSeverity.medium:
        return Colors.orange;
      case AuditSeverity.high:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dt) {
    return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
