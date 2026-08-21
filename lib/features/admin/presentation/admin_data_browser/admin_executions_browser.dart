import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../planned_maintenance/data/job_template_model.dart';
import '../../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_search_sort_helpers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';

// ============================================================================
// EXECUTIONS BROWSER (delete only – no edit)
// ============================================================================

class ExecutionsBrowser extends ConsumerStatefulWidget {
  const ExecutionsBrowser({super.key});

  @override
  ConsumerState<ExecutionsBrowser> createState() => _ExecutionsBrowserState();
}

class _ExecutionsBrowserState extends ConsumerState<ExecutionsBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final executionsAsync = ref.watch(adminExecutionsStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by job, asset, agency, status, or remarks',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: BafColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: executionsAsync.when(
              loading:
                  () => const BafLoadingPanel(
                    label: 'Loading execution records',
                    color: BafColors.admin,
                  ),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (executions) {
                final filtered =
                    executions
                        .where(
                          (execution) => executionMatchesAdminSearch(
                            execution,
                            _searchQuery,
                          ),
                        )
                        .toList()
                      ..sort(compareExecutionsForAdmin);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No executions match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder:
                      (ctx, idx) => _ExecutionCard(execution: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionCard extends ConsumerStatefulWidget {
  final JobExecution execution;

  const _ExecutionCard({required this.execution});

  @override
  ConsumerState<_ExecutionCard> createState() => _ExecutionCardState();
}

class _ExecutionCardState extends ConsumerState<_ExecutionCard> {
  @override
  Widget build(BuildContext context) {
    final execution = widget.execution;
    final statusColor =
        execution.isDeleted
            ? BafColors.textSecondary
            : execution.isCompleted
            ? BafColors.success
            : BafColors.warning;
    final statusLabel =
        execution.isDeleted
            ? 'DELETED'
            : execution.isCompleted
            ? 'COMPLETED'
            : 'OPEN';

    return Card(
      color: BafColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 46,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        title: Text(
          execution.templateName ?? 'Unnamed Job',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${execution.assetType.name.toUpperCase()} ${execution.assetNumber} | ${formatAgencyList(execution.assignedAgencies)}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  AdminChip(label: statusLabel, color: statusColor),
                  AdminChip(
                    label:
                        'Assigned ${DateFormat('dd MMM yyyy').format(execution.createdAt)}',
                    color: BafColors.planned,
                  ),
                  if (execution.completedAt != null)
                    AdminChip(
                      label:
                          'Done ${DateFormat('dd MMM yyyy').format(execution.completedAt!)}',
                      color: BafColors.success,
                    ),
                ],
              ),
              if (execution.assignedByName != null &&
                  execution.assignedByName!.trim().isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'Assigned by ${execution.assignedByName!.trim()}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!execution.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(execution),
              )
            else
              const AdminChip(label: 'DELETED', color: BafColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobExecution execution) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const AdminDeleteReasonDialog(
            title: 'Mark Execution as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? execution.firestoreId : execution.id;
    if (id == null) {
      showAdminDataSnack(
        context,
        'Execution does not have a valid local/remote id.',
        color: BafColors.warning,
      );
      return;
    }

    try {
      if (!appUser.canDeleteJobExecution) {
        throw StateError(
          'Admin authority required to delete planned job executions.',
        );
      }
      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteExecution(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: execution.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_execution_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Execution marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
