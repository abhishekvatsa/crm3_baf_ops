import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_template_model.dart';
import 'planned_job_detail_screen.dart';

class OpenExecutionsView extends StatelessWidget {
  final List<JobExecution> executions;
  final double bottomPadding;

  const OpenExecutionsView({
    super.key,
    required this.executions,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<JobExecution>.from(executions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.sm,
        BafSpacing.lg,
        bottomPadding,
      ),
      children: [
        _OpenJobsHeader(count: sorted.length),
        const SizedBox(height: BafSpacing.md),
        if (sorted.isEmpty)
          const _EmptyOpenJobsState()
        else
          ...sorted.map(
            (execution) => Padding(
              padding: const EdgeInsets.only(bottom: BafSpacing.sm),
              child: _OpenExecutionCard(execution: execution),
            ),
          ),
      ],
    );
  }
}

class _OpenJobsHeader extends StatelessWidget {
  final int count;

  const _OpenJobsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.22)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.work_history_rounded,
              color: BafColors.warning,
              size: 29,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Open assigned jobs',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jobs instantiated from legacy or governed published templates.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                StatusBadge(
                  label: '$count open',
                  color: BafColors.warning,
                  icon: Icons.pending_actions_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenExecutionCard extends StatelessWidget {
  final JobExecution execution;

  const _OpenExecutionCard({required this.execution});

  @override
  Widget build(BuildContext context) {
    final identity = execution.firestoreId?.trim();
    final cardKey =
        identity == null || identity.isEmpty
            ? 'local-${execution.id}'
            : identity;
    final title = _cleanText(execution.templateName) ?? 'Unnamed planned job';
    final packageCode = _cleanText(execution.templatePackageCode);
    final versionNumber = execution.templateVersionNumber;
    final sourceLabel =
        execution.isGovernedTemplateAssignment
            ? [
              packageCode ?? 'Governed catalogue',
              if (versionNumber != null) 'v$versionNumber',
            ].join(' · ')
            : 'Legacy template assignment';

    return Material(
      key: ValueKey<String>('open-job-$cardKey'),
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.large),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlannedJobDetailScreen(execution: execution),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(
              color: BafColors.warning.withValues(alpha: 0.22),
            ),
            boxShadow: BafShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BafColors.warning.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(
                  _assetIcon(execution.assetType),
                  color: BafColors.warning,
                  size: 27,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_assetLabel(execution.assetType)} ${execution.assetNumber} · assigned ${_formatJobDate(execution.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            execution.isGovernedTemplateAssignment
                                ? BafColors.sync
                                : BafColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_cleanText(execution.assignedByName) != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Assigned by ${execution.assignedByName!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: BafSpacing.sm),
                    Wrap(
                      spacing: BafSpacing.sm,
                      runSpacing: BafSpacing.sm,
                      children: [
                        const StatusBadge(
                          label: 'Open',
                          color: BafColors.warning,
                          icon: Icons.pending_actions_rounded,
                        ),
                        StatusBadge(
                          label:
                              execution.isSynced
                                  ? 'Remote-backed / synced'
                                  : 'Saved locally · pending sync',
                          color:
                              execution.isSynced
                                  ? BafColors.sync
                                  : BafColors.warning,
                          icon:
                              execution.isSynced
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_upload_outlined,
                        ),
                        if (execution.isGovernedTemplateAssignment)
                          const StatusBadge(
                            label: 'Governed source',
                            color: BafColors.sync,
                            icon: Icons.verified_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: BafColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOpenJobsState extends StatelessWidget {
  const _EmptyOpenJobsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.xl),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 38, color: BafColors.sync),
          SizedBox(height: BafSpacing.md),
          Text(
            'No open assigned jobs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: BafSpacing.sm),
          Text(
            'Use Assign Published to instantiate a governed job for an asset.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatJobDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}-${two(local.month)}-${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _assetLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'BASE';
    case AssetType.furnace:
      return 'FURNACE';
    case AssetType.forceCooler:
      return 'FORCE COOLER';
    case AssetType.innerCover:
      return 'INNER COVER';
  }
}

IconData _assetIcon(AssetType type) {
  switch (type) {
    case AssetType.base:
      return Icons.grid_view_rounded;
    case AssetType.furnace:
      return Icons.local_fire_department_rounded;
    case AssetType.forceCooler:
      return Icons.air_rounded;
    case AssetType.innerCover:
      return Icons.layers_rounded;
  }
}
