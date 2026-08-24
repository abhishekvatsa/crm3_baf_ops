import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../planned_maintenance/data/job_template_model.dart';
import '../../../planned_maintenance/presentation/planned_job_detail_screen.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_search_sort_helpers.dart';
import 'admin_data_browser_shared.dart';

// ============================================================================
// EXECUTIONS BROWSER (read-only audit and dossier access)
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
            : execution.isCancelled
            ? BafColors.warning
            : execution.isCompleted
            ? BafColors.success
            : BafColors.planned;
    final statusLabel =
        execution.isDeleted
            ? 'DELETED'
            : execution.isCancelled
            ? 'CANCELLED'
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
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlannedJobDetailScreen(execution: execution),
              ),
            ),
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
                  if (execution.cancelledAt != null)
                    AdminChip(
                      label:
                          'Cancelled ${DateFormat('dd MMM yyyy').format(execution.cancelledAt!)}',
                      color: BafColors.warning,
                    ),
                ],
              ),
              if (execution.isCancelled &&
                  execution.cancellationReason != null &&
                  execution.cancellationReason!.trim().isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                Text(
                  execution.cancellationReason!.trim(),
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
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
        trailing: const Tooltip(
          message: 'View complete planned-job dossier',
          child: Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}
