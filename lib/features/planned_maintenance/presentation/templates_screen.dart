// FILE: lib/features/planned_maintenance/presentation/templates_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../features/maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../maintenance_workflow/presentation/screens/workflow_queue_view.dart';
import 'create_template_screen.dart';
import 'open_executions_view.dart';
import 'published_template_assignment_screen.dart';
import 'template_detail_screen.dart';

enum _PlannedWorkView { openJobs, workflow, templates }

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  _PlannedWorkView _selectedView = _PlannedWorkView.openJobs;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(activeTemplatesProvider);
    final executionsAsync = ref.watch(openExecutionsProvider);
    final appUser = ref.watch(currentAppUserProvider).value;
    final canCreateTemplate = appUser?.canCreateLegacyJobTemplate ?? false;
    final canAssignJob = appUser?.canAssignJobExecution ?? false;
    final canSeeTemplates =
        canCreateTemplate ||
        canAssignJob ||
        (appUser?.canManageTemplateGovernance ?? false);
    final filteredExecutions = _filterExecutions(
      executionsAsync.value ?? const <JobExecution>[],
      _query,
    );
    final filteredTemplates = _filterTemplates(
      templatesAsync.value ?? const <JobTemplate>[],
      _query,
    );
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final fabBottomGap = BafSpacing.lg + bottomSafeInset;
    final showCreateTemplateFab =
        canCreateTemplate && _selectedView == _PlannedWorkView.templates;
    final showAssignFab =
        canAssignJob && _selectedView == _PlannedWorkView.openJobs;
    final hasAnyFab = showCreateTemplateFab || showAssignFab;
    final listBottomPadding =
        hasAnyFab ? 132 + bottomSafeInset + BafSpacing.xl : BafSpacing.xl;

    return Stack(
      children: [
        ColoredBox(
          color: BafColors.background,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  _PlannedWorkSelector(
                    selectedView: _selectedView,
                    openJobCount: executionsAsync.value?.length,
                    templateCount: templatesAsync.value?.length,
                    canSeeTemplates: canSeeTemplates,
                    query: _query,
                    onQueryChanged: (value) => setState(() => _query = value),
                    onChanged: (view) {
                      if (view == _selectedView) return;
                      setState(() => _selectedView = view);
                    },
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: switch (_selectedView) {
                        _PlannedWorkView.openJobs => KeyedSubtree(
                          key: const ValueKey('planned-work-open-jobs'),
                          child: executionsAsync.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error:
                                (e, _) => _ErrorState(
                                  message: 'Could not load open jobs: $e',
                                ),
                            data:
                                (_) => OpenExecutionsView(
                                  executions: filteredExecutions,
                                  bottomPadding: listBottomPadding,
                                ),
                          ),
                        ),
                        _PlannedWorkView.workflow => WorkflowQueueView(
                          key: const ValueKey('planned-work-workflow'),
                          query: _query,
                          bottomPadding: listBottomPadding,
                        ),
                        _PlannedWorkView.templates => KeyedSubtree(
                          key: const ValueKey('planned-work-templates'),
                          child: templatesAsync.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error:
                                (e, _) => _ErrorState(
                                  message: 'Could not load templates: $e',
                                ),
                            data: (_) {
                              if (filteredTemplates.isEmpty) {
                                return const _EmptyTemplatesState();
                              }
                              return _TemplateList(
                                templates: filteredTemplates,
                                bottomPadding: listBottomPadding,
                              );
                            },
                          ),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showAssignFab)
          Positioned(
            bottom: showCreateTemplateFab ? fabBottomGap + 64 : fabBottomGap,
            right: BafSpacing.lg,
            child: FloatingActionButton.extended(
              heroTag: 'published_templates_fab',
              backgroundColor: BafColors.planned,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.verified_rounded),
              label: const Text(
                'Assign Published',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublishedTemplateAssignmentScreen(),
                  ),
                );
              },
            ),
          ),
        if (showCreateTemplateFab)
          Positioned(
            bottom: fabBottomGap,
            right: BafSpacing.lg,
            child: FloatingActionButton.extended(
              heroTag: 'templates_fab',
              backgroundColor: BafColors.planned,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Template',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTemplateScreen(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  List<JobExecution> _filterExecutions(
    List<JobExecution> executions,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return executions;
    return executions
        .where((execution) {
          return <String?>[
            execution.templateName,
            execution.templatePackageCode,
            execution.assetType.name,
            '${execution.assetNumber}',
            execution.assignedByName,
            ...execution.assignedAgencies,
          ].any((value) => value?.toLowerCase().contains(needle) == true);
        })
        .toList(growable: false);
  }

  List<JobTemplate> _filterTemplates(
    List<JobTemplate> templates,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return templates;
    return templates
        .where((template) {
          return <String?>[
            template.jobName,
            template.description,
            template.applicableAssetType.name,
            ...template.assignedAgencies,
          ].any((value) => value?.toLowerCase().contains(needle) == true);
        })
        .toList(growable: false);
  }
}

class _PlannedWorkSelector extends StatelessWidget {
  final _PlannedWorkView selectedView;
  final int? openJobCount;
  final int? templateCount;
  final bool canSeeTemplates;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_PlannedWorkView> onChanged;

  const _PlannedWorkSelector({
    required this.selectedView,
    required this.openJobCount,
    required this.templateCount,
    required this.canSeeTemplates,
    required this.query,
    required this.onQueryChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planned Maintenance',
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jobs, workflow obligations and governed planning.',
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.25,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_PlannedWorkView>(
              showSelectedIcon: false,
              segments: [
                const ButtonSegment<_PlannedWorkView>(
                  value: _PlannedWorkView.openJobs,
                  label: Text('Jobs'),
                ),
                const ButtonSegment<_PlannedWorkView>(
                  value: _PlannedWorkView.workflow,
                  label: Text('Workflow'),
                ),
                if (canSeeTemplates)
                  const ButtonSegment<_PlannedWorkView>(
                    value: _PlannedWorkView.templates,
                    label: Text('Templates'),
                  ),
              ],
              selected: <_PlannedWorkView>{selectedView},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onChanged(selection.first);
              },
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextField(
            key: const ValueKey('planned-work-search'),
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText:
                  selectedView == _PlannedWorkView.openJobs
                      ? 'Search jobs or assets'
                      : selectedView == _PlannedWorkView.workflow
                      ? 'Search lanes or compliance'
                      : 'Search templates',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            '${openJobCount ?? 0} open jobs'
            '${canSeeTemplates ? ' · ${templateCount ?? 0} templates' : ''}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  final List<JobTemplate> templates;
  final double bottomPadding;

  const _TemplateList({required this.templates, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    final grouped = <AssetType, List<JobTemplate>>{};
    for (final template in _sortedTemplates(templates)) {
      grouped.putIfAbsent(template.applicableAssetType, () => []).add(template);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        bottomPadding,
      ),
      children: [
        _TemplatesHeader(count: templates.length),
        const SizedBox(height: BafSpacing.lg),
        ...grouped.entries.expand((entry) {
          return [
            _AssetSectionHeader(
              assetType: entry.key,
              count: entry.value.length,
            ),
            const SizedBox(height: BafSpacing.sm),
            ...entry.value.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                child: _TemplateCard(template: template),
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
          ];
        }),
      ],
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  final int count;

  const _TemplatesHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Template library',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: BafSpacing.xs),
              Text(
                'Reusable plans for preventive and structured work.',
                style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: BafSpacing.sm),
        StatusBadge(
          label: '$count active',
          color: BafColors.planned,
          icon: Icons.task_alt_rounded,
        ),
      ],
    );
  }
}

class _AssetSectionHeader extends StatelessWidget {
  final AssetType assetType;
  final int count;

  const _AssetSectionHeader({required this.assetType, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_assetIcon(assetType), color: BafColors.assets, size: 19),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            _assetLabel(assetType),
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        StatusBadge(label: '$count', color: BafColors.assets),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final JobTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final fieldRead = template.fieldsReadResult;
    final agencies =
        template.assignedAgencies
            .where((agency) => agency.trim().isNotEmpty)
            .toList();

    return Material(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.large),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TemplateDetailScreen(template: template),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color: BafColors.card,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BafColors.planned.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: BafColors.planned,
                  size: 28,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.jobName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (template.description != null &&
                        template.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        template.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: BafSpacing.sm),
                    Wrap(
                      spacing: BafSpacing.sm,
                      runSpacing: BafSpacing.sm,
                      children: [
                        StatusBadge(
                          label:
                              fieldRead.isValid
                                  ? '${fieldRead.entries.length} fields'
                                  : 'Fields need repair',
                          color:
                              fieldRead.isValid
                                  ? BafColors.planned
                                  : BafColors.danger,
                          icon:
                              fieldRead.isValid
                                  ? Icons.list_alt_rounded
                                  : Icons.warning_amber_rounded,
                        ),
                        if (template.hasComponentScope)
                          const StatusBadge(
                            label: 'Scoped',
                            color: BafColors.assets,
                            icon: Icons.account_tree_rounded,
                          ),
                        ...agencies.map(
                          (agency) => StatusBadge(
                            label: agency.toUpperCase(),
                            color: _agencyColor(agency),
                          ),
                        ),
                      ],
                    ),
                    if (template.createdByName != null &&
                        template.createdByName!.trim().isNotEmpty) ...[
                      const SizedBox(height: BafSpacing.sm),
                      Text(
                        'Created by ${template.createdByName!.trim()}',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
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

class _EmptyTemplatesState extends StatelessWidget {
  const _EmptyTemplatesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BafSpacing.xl),
          decoration: BoxDecoration(
            color: BafColors.card,
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
                  color: BafColors.planned.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  size: 38,
                  color: BafColors.planned,
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              const Text(
                'No templates yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Create a planned job template to standardize recurring work.',
                textAlign: TextAlign.center,
                style: TextStyle(
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

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: BafColors.danger),
        ),
      ),
    );
  }
}

List<JobTemplate> _sortedTemplates(List<JobTemplate> templates) {
  return List<JobTemplate>.from(templates)..sort((a, b) {
    final typeCompare = a.applicableAssetType.index.compareTo(
      b.applicableAssetType.index,
    );
    if (typeCompare != 0) return typeCompare;
    return a.jobName.toLowerCase().compareTo(b.jobName.toLowerCase());
  });
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

Color _agencyColor(String agency) {
  switch (agency) {
    case 'operations':
      return BafColors.sync;
    case 'electrical':
      return BafColors.warning;
    case 'mechanical':
      return BafColors.planned;
    case 'instrumentation':
      return BafColors.audit;
    case 'refractory':
      return BafColors.directives;
    case 'emd':
      return BafColors.assets;
    case 'shiftInCharge':
      return BafColors.charges;
    case 'others':
      return BafColors.admin;
    default:
      return BafColors.admin;
  }
}
