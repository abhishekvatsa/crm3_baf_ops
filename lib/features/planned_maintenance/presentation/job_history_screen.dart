// FILE: lib/features/planned_maintenance/presentation/job_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import 'complete_job_screen.dart';
import 'planned_job_detail_screen.dart';

class JobHistoryScreen extends ConsumerWidget {
  final JobTemplate template;

  const JobHistoryScreen({
    super.key,
    required this.template,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateFirestoreId = template.firestoreId?.trim();
    final hasValidTemplateFirestoreId =
        templateFirestoreId != null && templateFirestoreId.isNotEmpty;
    final executionsFuture = hasValidTemplateFirestoreId
        ? ref
        .read(plannedRepositoryProvider)
        .getExecutionsForTemplate(templateFirestoreId)
        : Future<List<JobExecution>>.value([]);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Job History'),
        backgroundColor: Colors.white,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<List<JobExecution>>(
        future: executionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(message: 'Error: ${snapshot.error}');
          }

          if (!hasValidTemplateFirestoreId) {
            return const _MissingTemplateIdState();
          }

          final executions = [...(snapshot.data ?? <JobExecution>[])]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (executions.isEmpty) {
            return _EmptyHistoryState(template: template);
          }

          final completed = executions.where((e) => e.isCompleted).length;
          final pending = executions.length - completed;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(BafSpacing.lg, BafSpacing.md, BafSpacing.lg, BafSpacing.xl),
            itemCount: executions.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: BafSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _HistoryHeader(
                  template: template,
                  total: executions.length,
                  completed: completed,
                  pending: pending,
                );
              }

              final execution = executions[index - 1];
              return _ExecutionCard(
                execution: execution,
                template: template,
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final JobTemplate template;
  final int total;
  final int completed;
  final int pending;

  const _HistoryHeader({
    required this.template,
    required this.total,
    required this.completed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(
          color: BafColors.planned.withValues(alpha: 0.18),
        ),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: BafColors.planned,
              size: 31,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.jobName,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_assetTypeLabel(template.applicableAssetType)} execution history and completion records.',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: '$total assigned',
                      color: BafColors.planned,
                      icon: Icons.assignment_rounded,
                    ),
                    StatusBadge(
                      label: '$completed complete',
                      color: BafColors.sync,
                      icon: Icons.check_circle_rounded,
                    ),
                    StatusBadge(
                      label: '$pending pending',
                      color: pending > 0 ? BafColors.warning : BafColors.admin,
                      icon: Icons.pending_actions_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCED COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }
}

class _ExecutionCard extends StatelessWidget {
  final JobExecution execution;
  final JobTemplate template;

  const _ExecutionCard({
    required this.execution,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final ex = execution;
    final responseRead = ex.responsesReadResult;
    final responses = responseRead.entries;
    final hasResponses = responseRead.isValid && responses.isNotEmpty;
    final visibleResponses = responses
        .where(
          (r) =>
      r.fieldType != FieldType.sectionHeader &&
          r.fieldType != FieldType.instruction,
    )
        .toList();

    final statusColor = ex.isCompleted ? BafColors.sync : BafColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.22),
        ),
        boxShadow: BafShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              ex.isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.pending_actions_rounded,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_assetTypeLabel(ex.assetType)} ${ex.assetNumber}',
                                  style: const TextStyle(
                                    color: BafColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusBadge(
                                      label: ex.isCompleted
                                          ? 'Completed'
                                          : 'Pending',
                                      color: statusColor,
                                    ),
                                    if (ex.teamsInvolved.isNotEmpty)
                                      StatusBadge(
                                        label:
                                        '${ex.teamsInvolved.length} team${ex.teamsInvolved.length == 1 ? '' : 's'}',
                                        color: BafColors.charges,
                                        icon: Icons.groups_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      _MetaLine(
                        icon: Icons.event_available_rounded,
                        text:
                        'Assigned ${DateFormat('dd MMM yyyy, HH:mm').format(ex.createdAt)}',
                      ),
                      if (ex.isCompleted && ex.completedAt != null) ...[
                        const SizedBox(height: 6),
                        _MetaLine(
                          icon: Icons.task_alt_rounded,
                          text:
                          'Completed ${DateFormat('dd MMM yyyy, HH:mm').format(ex.completedAt!)}',
                        ),
                      ],
                      if (ex.completedByName != null &&
                          ex.completedByName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _MetaLine(
                          icon: Icons.person_outline_rounded,
                          text: 'By ${ex.completedByName}',
                        ),
                      ],

                      if (ex.teamsInvolved.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: ex.teamsInvolved
                              .map(
                                (team) => StatusBadge(
                              label: team.toUpperCase(),
                              color: BafColors.charges,
                            ),
                          )
                              .toList(),
                        ),
                      ],

                      if (ex.remarks != null && ex.remarks!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _RemarksBox(text: ex.remarks!.trim()),
                        ),

                      if (!responseRead.isValid) ...[
                        const SizedBox(height: 12),
                        const PersistedDataIntegrityNotice(
                          title: 'Saved responses need repair',
                          message:
                              'Response preview and counts are hidden. No saved evidence was discarded or replaced.',
                        ),
                      ],

                      if (ex.isCompleted && visibleResponses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: BafColors.background,
                            borderRadius:
                            BorderRadius.circular(BafRadius.medium),
                            border: Border.all(color: BafColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Response preview',
                                style: TextStyle(
                                  color: BafColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...visibleResponses
                                  .take(3)
                                  .map((r) => _ResponsePreviewRow(r)),
                              if (visibleResponses.length > 3)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _showResponseSheet(context, ex),
                                    icon: const Icon(
                                      Icons.expand_more_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'View all ${visibleResponses.length} responses',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      if (!ex.isCompleted)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openJobDetail(context, ex),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BafColors.planned,
                                  side: const BorderSide(color: BafColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.article_rounded),
                                label: const Text(
                                  'View Detail',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    responseRead.isValid &&
                                            ex.actionsReadResult.isValid
                                        ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      CompleteJobScreen(
                                                        execution: ex,
                                                      ),
                                            ),
                                          );
                                        }
                                        : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: BafColors.sync,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.playlist_add_check_rounded,
                                ),
                                label: const Text(
                                  'Complete Job',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (hasResponses)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openJobDetail(context, ex),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BafColors.planned,
                                  side: const BorderSide(color: BafColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.article_rounded),
                                label: const Text(
                                  'View Detail',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showResponseSheet(context, ex),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BafColors.planned,
                                  side: const BorderSide(color: BafColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      BafRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.fact_check_rounded),
                                label: const Text(
                                  'View Responses',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openJobDetail(context, ex),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BafColors.planned,
                              side: const BorderSide(color: BafColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  BafRadius.medium,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.article_rounded),
                            label: const Text(
                              'View Detail',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openJobDetail(BuildContext context, JobExecution ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlannedJobDetailScreen(
          execution: ex,
          template: template,
        ),
      ),
    );
  }

  void _showResponseSheet(BuildContext context, JobExecution ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResponseDetailSheet(
        execution: ex,
        template: template,
      ),
    );
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCED COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }
}

class _ResponsePreviewRow extends StatelessWidget {
  final FieldResponse response;

  const _ResponsePreviewRow(this.response);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              response.fieldLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _ResponseValueWidget(
              response: response,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseDetailSheet extends StatelessWidget {
  final JobExecution execution;
  final JobTemplate template;

  const _ResponseDetailSheet({
    required this.execution,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final ex = execution;
    final responseRead = ex.responsesReadResult;
    final responses = responseRead.entries;
    final templateFields = List<TemplateField>.from(template.parsedFields)
      ..sort((a, b) => a.order.compareTo(b.order));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      minChildSize: 0.42,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: BafColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BafColors.sync.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.fact_check_rounded,
                        color: BafColors.sync,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_assetTypeLabel(ex.assetType)} ${ex.assetNumber}',
                            style: const TextStyle(
                              color: BafColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (ex.completedAt != null)
                            Text(
                              'Completed ${DateFormat('dd MMM yyyy, HH:mm').format(ex.completedAt!)}',
                              style: const TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                  children: [
                    if (!responseRead.isValid)
                      const PersistedDataIntegrityNotice(
                        title: 'Responses unavailable',
                        message:
                            'This saved response payload must be repaired before its evidence can be displayed.',
                      )
                    else if (templateFields.isNotEmpty)
                      ...templateFields.map((field) {
                        if (field.type == FieldType.sectionHeader) {
                          return _SectionHeaderWidget(field.label);
                        }
                        if (field.type == FieldType.instruction) {
                          return _InstructionBox(text: field.instructionText ?? field.label);
                        }

                        final response = _firstResponseForKey(
                          responses,
                          field.key,
                        );

                        return _FieldRow(
                          label: field.label,
                          child: response == null
                              ? const Text(
                            '—',
                            style: TextStyle(
                              color: BafColors.textSecondary,
                            ),
                          )
                              : _ResponseValueWidget(
                            response: response,
                            compact: false,
                          ),
                        );
                      })
                    else
                      ...responses
                          .where(
                            (r) =>
                        r.fieldType != FieldType.sectionHeader &&
                            r.fieldType != FieldType.instruction,
                      )
                          .map(
                            (r) => _FieldRow(
                          label: r.fieldLabel,
                          child: _ResponseValueWidget(
                            response: r,
                            compact: false,
                          ),
                        ),
                      ),

                    if (ex.remarks != null && ex.remarks!.trim().isNotEmpty) ...[
                      const _SectionHeaderWidget('Remarks'),
                      _RemarksBox(text: ex.remarks!.trim()),
                    ],

                    if (ex.completedByName != null &&
                        ex.completedByName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _MetaLine(
                        icon: Icons.person_outline_rounded,
                        text: 'Completed by ${ex.completedByName}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  FieldResponse? _firstResponseForKey(
      List<FieldResponse> responses,
      String key,
      ) {
    for (final response in responses) {
      if (response.key == key) {
        return response;
      }
    }
    return null;
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCED COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }
}

class _SectionHeaderWidget extends StatelessWidget {
  final String label;

  const _SectionHeaderWidget(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 11),
      decoration: BoxDecoration(
        color: BafColors.planned.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color: BafColors.planned.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: BafColors.planned,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _InstructionBox extends StatelessWidget {
  final String text;

  const _InstructionBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: BafColors.textSecondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: child),
        ],
      ),
    );
  }
}

class _ResponseValueWidget extends StatelessWidget {
  final FieldResponse response;
  final bool compact;

  const _ResponseValueWidget({
    required this.response,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final value = response.value;

    switch (response.fieldType) {
      case FieldType.checkbox:
      case FieldType.yesNo:
        final isTrue = value == true ||
            value?.toString().trim().toLowerCase() == 'true' ||
            value?.toString().trim().toLowerCase() == 'yes';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrue ? Icons.check_circle_rounded : Icons.cancel_outlined,
              color: isTrue ? BafColors.sync : BafColors.danger,
              size: compact ? 16 : 20,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                isTrue ? 'Yes' : 'No',
                style: TextStyle(
                  color: isTrue ? BafColors.sync : BafColors.danger,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );

      case FieldType.number:
        return Text(
          _emptyAware(value),
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
          ),
        );

      case FieldType.dropdown:
        if (_isEmpty(value)) return _Dash(compact: compact);
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(
            label: value.toString(),
            color: BafColors.planned,
          ),
        );

      case FieldType.multiSelect:
        final items = _multiSelectItems(value);
        if (items.isEmpty) return _Dash(compact: compact);

        return Wrap(
          spacing: 5,
          runSpacing: 5,
          children: items
              .map(
                (item) => StatusBadge(
              label: item,
              color: BafColors.planned,
            ),
          )
              .toList(),
        );

      case FieldType.dateTime:
        if (_isEmpty(value)) return _Dash(compact: compact);
        final parsed = DateTime.tryParse(value.toString());
        return Text(
          parsed == null
              ? value.toString()
              : DateFormat('dd MMM yyyy, HH:mm').format(parsed),
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        );

      case FieldType.text:
      case FieldType.longText:
        if (_isEmpty(value)) return _Dash(compact: compact);
        return Text(
          value.toString(),
          maxLines: compact ? 1 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: compact ? 12 : 14,
            height: 1.3,
          ),
        );

      case FieldType.sectionHeader:
      case FieldType.instruction:
        return const SizedBox.shrink();
    }
  }

  bool _isEmpty(Object? value) {
    return value == null || value.toString().trim().isEmpty;
  }

  String _emptyAware(Object? value) {
    if (_isEmpty(value)) return '—';
    return value.toString();
  }

  List<String> _multiSelectItems(Object? value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return value
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class _Dash extends StatelessWidget {
  final bool compact;

  const _Dash({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Text(
      '—',
      style: TextStyle(
        color: BafColors.textSecondary,
        fontSize: compact ? 12 : 14,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: BafColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _RemarksBox extends StatelessWidget {
  final String text;

  const _RemarksBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notes_rounded,
            color: BafColors.textSecondary,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTemplateIdState extends StatelessWidget {
  const _MissingTemplateIdState();

  @override
  Widget build(BuildContext context) {
    return const _StateCard(
      icon: Icons.error_outline_rounded,
      iconColor: BafColors.danger,
      title: 'Template ID missing',
      message:
      'This template is missing its local sync ID, so its execution history cannot be loaded.',
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final JobTemplate template;

  const _EmptyHistoryState({required this.template});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.history_rounded,
      iconColor: BafColors.planned,
      title: 'No executions yet',
      message:
      'Assign ${template.jobName} to an asset to start building its history.',
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.error_outline_rounded,
      iconColor: BafColors.danger,
      title: 'Could not load history',
      message: message,
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
