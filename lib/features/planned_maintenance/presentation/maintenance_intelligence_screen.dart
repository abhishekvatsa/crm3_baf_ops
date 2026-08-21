import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/maintenance_intelligence.dart';
import '../providers/maintenance_intelligence_provider.dart';
import 'published_template_assignment_screen.dart';

part 'maintenance_intelligence_history.dart';

class MaintenanceIntelligenceScreen extends ConsumerWidget {
  const MaintenanceIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentAppUserProvider);
    return actor.when(
      loading:
          () => BafScreenStateScaffold.loading(
            appBarTitle: 'Maintenance rhythm',
            appBarSubtitle: 'Due state, history, forward plans and classes',
            appBarIcon: Icons.event_repeat_rounded,
            accent: BafColors.planned,
            label: 'Checking maintenance authority',
          ),
      error:
          (_, _) => BafScreenStateScaffold.error(
            appBarTitle: 'Maintenance rhythm',
            appBarSubtitle: 'Due state, history, forward plans and classes',
            appBarIcon: Icons.event_repeat_rounded,
            accent: BafColors.planned,
            message: 'Maintenance authority could not be verified.',
          ),
      data:
          (user) =>
              user == null
                  ? BafScreenStateScaffold.access(
                    appBarTitle: 'Maintenance rhythm',
                    appBarSubtitle:
                        'Due state, history, forward plans and classes',
                    appBarIcon: Icons.event_repeat_rounded,
                    accent: BafColors.planned,
                    title: 'Sign in required',
                    message:
                        'Sign in with an approved account to view maintenance intelligence.',
                  )
                  : _MaintenanceIntelligenceBody(actor: user),
    );
  }
}

class _MaintenanceIntelligenceBody extends ConsumerWidget {
  const _MaintenanceIntelligenceBody({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Maintenance rhythm',
            subtitle: 'Due state, history, forward plans and governed classes',
            icon: Icons.event_repeat_rounded,
            accent: BafColors.planned,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'Due state'),
              Tab(icon: Icon(Icons.history_rounded), text: 'History'),
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Plans'),
              Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Classes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _DueStateTab(),
            _HistoryTab(actor: actor),
            _PlansTab(actor: actor),
            _ClassesTab(actor: actor),
          ],
        ),
      ),
    );
  }
}

class _DueStateTab extends ConsumerWidget {
  const _DueStateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maintenanceDueStatesProvider);
    return state.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading maintenance due state',
            color: BafColors.planned,
          ),
      error:
          (_, _) => _RetryState(
            message:
                'Maintenance due-state records need repair or could not be read.',
            onRetry: () => ref.invalidate(maintenanceDueStatesProvider),
          ),
      data: (rows) {
        final overdue = rows.where((row) => row.isOverdue).length;
        final dueSoon = rows.where((row) => row.isDueSoon).length;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(maintenanceDueStatesProvider);
            await ref.read(maintenanceDueStatesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              _SummaryBand(
                title: 'Preventive maintenance pulse',
                description:
                    'Completion events reset only their governed counters. Unclassified completed work remains visible without changing cadence.',
                metrics: [
                  _Metric('Tracked', '${rows.length}', BafColors.planned),
                  _Metric('Overdue', '$overdue', BafColors.danger),
                  _Metric('Due soon', '$dueSoon', BafColors.warning),
                ],
              ),
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: 'No classified completion yet',
                  message:
                      'Due state starts when a classified job is completed or an authorised user classifies historical completed work.',
                )
              else
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _DueStateCard(state: row),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DueStateCard extends StatelessWidget {
  const _DueStateCard({required this.state});

  final MaintenanceDueState state;

  @override
  Widget build(BuildContext context) {
    final color =
        state.isOverdue
            ? BafColors.danger
            : state.isDueSoon
            ? BafColors.warning
            : BafColors.success;
    final status =
        state.nextDueAt == null
            ? 'Monitoring only'
            : state.isOverdue
            ? '${state.daysUntilDue!.abs()} days overdue'
            : '${state.daysUntilDue} days remaining';
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(Icons.build_circle_outlined, color: color),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.assetDisplayName ?? '${_assetLabel(state.assetTypeKey)} ${state.assetNumber ?? state.assetInstanceId}'} · ${state.counterLabel}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.lastCompletionAt == null
                      ? 'No qualifying completion recorded'
                      : 'Last ${state.lastMaintenanceClassCode ?? 'classified work'} · ${DateFormat('dd MMM yyyy').format(state.lastCompletionAt!.toLocal())}',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Chip(
            avatar: Icon(
              state.isOverdue ? Icons.error_outline : Icons.schedule_rounded,
              size: 18,
              color: color,
            ),
            label: Text(status),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            backgroundColor: color.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

class _PlansTab extends ConsumerWidget {
  const _PlansTab({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(maintenancePlansProvider);
    final classes =
        ref.watch(maintenanceClassDefinitionsProvider).value ??
        const <MaintenanceClassDefinition>[];
    return plans.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading maintenance plans',
            color: BafColors.planned,
          ),
      error:
          (_, _) => _RetryState(
            message: 'Maintenance plans could not be loaded.',
            onRetry: () => ref.invalidate(maintenancePlansProvider),
          ),
      data:
          (rows) => ListView(
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              _ActionHeader(
                title: 'Plan before work is released',
                description:
                    'A plan reserves intent and timing only. It does not mark the asset unavailable or create an execution.',
                actionLabel: 'New plan',
                actionIcon: Icons.add_task_rounded,
                onPressed:
                    actor.canPlanClassifiedMaintenance && classes.isNotEmpty
                        ? () => _editPlan(context, ref, classes)
                        : null,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: 'No maintenance plans',
                  message:
                      'Create a proposed window without taking equipment out of service.',
                )
              else
                ...rows.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _PlanCard(
                      plan: plan,
                      canManage: actor.canPlanClassifiedMaintenance,
                      onTransition:
                          (status) =>
                              _transitionPlan(context, ref, plan, status),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}

class _ClassesTab extends ConsumerWidget {
  const _ClassesTab({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitions = ref.watch(maintenanceClassDefinitionsProvider);
    return definitions.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading maintenance classes',
            color: BafColors.planned,
          ),
      error:
          (_, _) => _RetryState(
            message: 'Maintenance classes could not be loaded.',
            onRetry: () => ref.invalidate(maintenanceClassDefinitionsProvider),
          ),
      data:
          (rows) => ListView(
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              _ActionHeader(
                title: 'Governed maintenance classes',
                description:
                    'Classes describe business outcomes. Their versioned reset matrix is frozen into templates, plans and completed work.',
                actionLabel:
                    rows.isEmpty ? 'Install BAF defaults' : 'Add class',
                actionIcon:
                    rows.isEmpty
                        ? Icons.auto_awesome_rounded
                        : Icons.add_rounded,
                onPressed:
                    actor.canManageMaintenanceClasses
                        ? () =>
                            rows.isEmpty
                                ? _installDefaults(context, ref)
                                : _editClass(context, ref)
                        : null,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.rule_folder_outlined,
                  title: 'Catalogue not installed',
                  message:
                      'Install the six reviewed BAF classes, then refine thresholds through versioned edits.',
                )
              else
                ...rows.map(
                  (definition) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _ClassCard(
                      definition: definition,
                      canManage: actor.canManageMaintenanceClasses,
                      onEdit: () => _editClass(context, ref, definition),
                      onStatus:
                          () => _toggleClassStatus(context, ref, definition),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}

Future<void> _execute(
  BuildContext context,
  WidgetRef ref,
  WorkflowCommand command,
  String success,
) async {
  try {
    await ref.read(workflowCommandControllerProvider.notifier).execute(command);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.sync),
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not apply change: $error'),
        backgroundColor: BafColors.danger,
      ),
    );
  }
}

Future<void> _installDefaults(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Install BAF maintenance classes?'),
          content: const Text(
            'This creates Mid, Full and TRM for Furnaces; Maintenance for Bases and Forced Coolers; and Inner Cover Cleaning. Furnace/Base/Forced Cooler defaults are 30/50/90 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Install'),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return;
  for (final value in _defaultClasses) {
    await _execute(
      context,
      ref,
      WorkflowCommand(
        commandId: 'upsertMaintenanceClassDefinition_${const Uuid().v4()}',
        type: WorkflowCommandType.upsertMaintenanceClassDefinition,
        aggregateId:
            'maintenance-class-${value.code.toLowerCase().replaceAll('_', '-')}',
        expectedVersion: 0,
        payload: {
          'definition': value.toPayload(),
          'reason': 'Install reviewed BAF preventive-maintenance defaults.',
        },
      ),
      '${value.title} installed.',
    );
  }
}

Future<void> _editClass(
  BuildContext context,
  WidgetRef ref, [
  MaintenanceClassDefinition? existing,
]) async {
  final draft = await showDialog<_ClassDraft>(
    context: context,
    builder: (_) => _ClassEditor(existing: existing),
  );
  if (draft == null || !context.mounted) return;
  await _execute(
    context,
    ref,
    WorkflowCommand(
      commandId: 'upsertMaintenanceClassDefinition_${const Uuid().v4()}',
      type: WorkflowCommandType.upsertMaintenanceClassDefinition,
      aggregateId: existing?.id ?? 'maintenance-class-${const Uuid().v4()}',
      expectedVersion: existing?.version ?? 0,
      payload: {'definition': draft.toPayload(), 'reason': draft.reason},
    ),
    existing == null
        ? 'Maintenance class created.'
        : 'Maintenance class updated.',
  );
}

Future<void> _toggleClassStatus(
  BuildContext context,
  WidgetRef ref,
  MaintenanceClassDefinition definition,
) async {
  final target = definition.isActive ? 'retired' : 'active';
  await _execute(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setMaintenanceClassDefinitionStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setMaintenanceClassDefinitionStatus,
      aggregateId: definition.id,
      expectedVersion: definition.version,
      payload: {
        'status': target,
        'reason':
            '${definition.isActive ? 'Retire' : 'Restore'} class through governed catalogue.',
      },
    ),
    'Maintenance class ${definition.isActive ? 'retired' : 'restored'}.',
  );
}

Future<void> _editPlan(
  BuildContext context,
  WidgetRef ref,
  List<MaintenanceClassDefinition> classes,
) async {
  final draft = await showDialog<_PlanDraft>(
    context: context,
    builder:
        (_) => _PlanEditor(
          definitions: classes.where((item) => item.isActive).toList(),
        ),
  );
  if (draft == null || !context.mounted) return;
  await _execute(
    context,
    ref,
    WorkflowCommand(
      commandId: 'upsertMaintenancePlan_${const Uuid().v4()}',
      type: WorkflowCommandType.upsertMaintenancePlan,
      aggregateId: 'maintenance-plan-${const Uuid().v4()}',
      expectedVersion: 0,
      payload: draft.toPayload(),
    ),
    'Maintenance plan proposed.',
  );
}

Future<void> _transitionPlan(
  BuildContext context,
  WidgetRef ref,
  MaintenancePlan plan,
  String status,
) async {
  if (status == 'released') {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublishedTemplateAssignmentScreen(sourcePlan: plan),
      ),
    );
    return;
  }
  if (status == 'completed') {
    final draft = await _capturePlanCompletion(context);
    if (draft == null || !context.mounted) return;
    await _execute(
      context,
      ref,
      WorkflowCommand(
        commandId: 'completeMaintenancePlan_${const Uuid().v4()}',
        type: WorkflowCommandType.completeMaintenancePlan,
        aggregateId: plan.id,
        expectedVersion: plan.version,
        payload: {
          'completedAt': draft.completedAt.toUtc().toIso8601String(),
          'completionEvidence': draft.evidence,
          'reason':
              'Record supervised serial Inner Cover maintenance completion.',
        },
      ),
      'Inner Cover maintenance completion recorded.',
    );
    return;
  }
  await _execute(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setMaintenancePlanStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setMaintenancePlanStatus,
      aggregateId: plan.id,
      expectedVersion: plan.version,
      payload: {
        'status': status,
        'reason':
            'Move maintenance plan to $status through the planning board.',
        'executionId': null,
      },
    ),
    'Plan moved to $status.',
  );
}

class _PlanCompletionDraft {
  const _PlanCompletionDraft({
    required this.completedAt,
    required this.evidence,
  });

  final DateTime completedAt;
  final String evidence;
}

Future<_PlanCompletionDraft?> _capturePlanCompletion(
  BuildContext context,
) async {
  final evidence = TextEditingController();
  var completedAt = DateTime.now();
  final result = await showDialog<_PlanCompletionDraft>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: const Text('Record Inner Cover completion'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('Actual completion time'),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(completedAt),
                        ),
                        trailing: const Icon(Icons.edit_calendar_outlined),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now(),
                            initialDate: completedAt,
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(completedAt),
                          );
                          if (time == null || !context.mounted) return;
                          setState(
                            () =>
                                completedAt = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                ),
                          );
                        },
                      ),
                      TextField(
                        controller: evidence,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Completion evidence',
                          hintText:
                              'Work performed, inspection result and resulting disposition',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final text = evidence.text.trim();
                      if (text.length < 10) return;
                      Navigator.pop(
                        context,
                        _PlanCompletionDraft(
                          completedAt: completedAt,
                          evidence: text,
                        ),
                      );
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Record completion'),
                  ),
                ],
              ),
        ),
  );
  evidence.dispose();
  return result;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.canManage,
    required this.onTransition,
  });

  final MaintenancePlan plan;
  final bool canManage;
  final ValueChanged<String> onTransition;

  @override
  Widget build(BuildContext context) {
    final next = switch (plan.status) {
      MaintenancePlanStatus.proposed => 'scheduled',
      MaintenancePlanStatus.scheduled => 'ready',
      MaintenancePlanStatus.ready =>
        plan.isSerialInnerCover ? 'completed' : 'released',
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: BafColors.planned,
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    '${plan.assetInstanceName} · ${plan.maintenanceClass.title}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text(plan.status.name.toUpperCase())),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              '${DateFormat('dd MMM, HH:mm').format(plan.targetWindowStart.toLocal())} – ${DateFormat('dd MMM, HH:mm').format(plan.targetWindowEnd.toLocal())}',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            if (plan.planningNotes != null) ...[
              const SizedBox(height: 6),
              Text(plan.planningNotes!),
            ],
            if (canManage && next != null) ...[
              const Divider(height: BafSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => onTransition('cancelled'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => onTransition(next),
                    icon: Icon(
                      next == 'released'
                          ? Icons.rocket_launch_outlined
                          : next == 'completed'
                          ? Icons.fact_check_outlined
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      next == 'released'
                          ? 'Link & release'
                          : next == 'completed'
                          ? 'Record completion'
                          : 'Mark $next',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.definition,
    required this.canManage,
    required this.onEdit,
    required this.onStatus,
  });

  final MaintenanceClassDefinition definition;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: BafColors.planned,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${definition.code} · ${definition.assetTypeKeys.map(_assetLabel).join(', ')}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      definition.resetCounters
                          .map(
                            (counter) => Chip(
                              label: Text(
                                '${counter.label}${counter.thresholdDays == null ? '' : ' · ${counter.thresholdDays}d'}',
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (value) => value == 'edit' ? onEdit() : onStatus(),
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit as new version'),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(definition.isActive ? 'Retire' : 'Restore'),
                    ),
                  ],
            ),
        ],
      ),
    ),
  );
}

class _ClassDraft {
  const _ClassDraft({
    required this.code,
    required this.title,
    required this.description,
    required this.assetTypes,
    required this.lane,
    required this.counters,
    required this.reason,
  });
  final String code;
  final String title;
  final String description;
  final List<String> assetTypes;
  final String lane;
  final List<MaintenanceResetCounter> counters;
  final String reason;

  Map<String, dynamic> toPayload() => {
    'schemaVersion': 1,
    'code': code,
    'title': title,
    'description': description,
    'assetTypeKeys': assetTypes,
    'assetClassIds': <String>[],
    'principalLaneKey': lane,
    'resetCounters': counters.map((counter) => counter.toMap()).toList(),
  };
}

class _ClassEditor extends StatefulWidget {
  const _ClassEditor({this.existing});
  final MaintenanceClassDefinition? existing;

  @override
  State<_ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<_ClassEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _counters;
  late final TextEditingController _reason;
  late Set<String> _assetTypes;
  late String _lane;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _code = TextEditingController(text: value?.code);
    _title = TextEditingController(text: value?.title);
    _description = TextEditingController(text: value?.description);
    _counters = TextEditingController(
      text: value?.resetCounters
          .map(
            (counter) =>
                '${counter.key}|${counter.label}|${counter.thresholdDays ?? ''}',
          )
          .join('\n'),
    );
    _reason = TextEditingController(
      text:
          value == null
              ? 'Create governed maintenance class.'
              : 'Revise governed maintenance class.',
    );
    _assetTypes = {...?value?.assetTypeKeys};
    _lane = value?.principalLaneKey ?? 'mech';
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _description.dispose();
    _counters.dispose();
    _reason.dispose();
    super.dispose();
  }

  List<MaintenanceResetCounter>? _parseCounters() {
    final rows = _counters.text
        .split('\n')
        .where((line) => line.trim().isNotEmpty);
    final result = <MaintenanceResetCounter>[];
    for (final row in rows) {
      final parts = row.split('|').map((part) => part.trim()).toList();
      if (parts.length != 3 || parts[0].isEmpty || parts[1].isEmpty) {
        return null;
      }
      final days = parts[2].isEmpty ? null : int.tryParse(parts[2]);
      if (parts[2].isNotEmpty && (days == null || days < 1 || days > 3650)) {
        return null;
      }
      result.add(
        MaintenanceResetCounter(
          key: parts[0].toUpperCase(),
          label: parts[1],
          thresholdDays: days,
        ),
      );
    }
    return result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? 'Add maintenance class'
          : 'Revise maintenance class',
    ),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Stable code'),
                validator:
                    (value) =>
                        RegExp(
                              r'^[A-Z0-9][A-Z0-9_-]{1,47}$',
                            ).hasMatch(value?.trim().toUpperCase() ?? '')
                            ? null
                            : 'Use 2-48 letters, numbers, hyphens or underscores',
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Business title'),
                validator: _required,
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              const SizedBox(height: BafSpacing.md),
              const Text(
                'Applicable asset classes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 6,
                children:
                    _assetTypeOptions
                        .map(
                          (value) => FilterChip(
                            label: Text(_assetLabel(value)),
                            selected: _assetTypes.contains(value),
                            onSelected:
                                (selected) => setState(
                                  () =>
                                      selected
                                          ? _assetTypes.add(value)
                                          : _assetTypes.remove(value),
                                ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _lane,
                decoration: const InputDecoration(
                  labelText: 'Principal owner lane',
                ),
                items: const [
                  DropdownMenuItem(value: 'mech', child: Text('Mechanical')),
                  DropdownMenuItem(value: 'elec', child: Text('Electrical')),
                  DropdownMenuItem(value: 'inst', child: Text('I&A')),
                  DropdownMenuItem(value: 'oprn', child: Text('Operations')),
                  DropdownMenuItem(value: 'red', child: Text('RED')),
                  DropdownMenuItem(value: 'shared', child: Text('Shared')),
                ],
                onChanged: (value) => setState(() => _lane = value ?? _lane),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _counters,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Counter reset matrix',
                  helperText:
                      'One per line: KEY | Label | threshold days (blank = monitoring only)',
                  alignLabelWithHint: true,
                ),
                validator:
                    (_) =>
                        _parseCounters() == null
                            ? 'Add at least one valid reset counter'
                            : null,
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: _required,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate() || _assetTypes.isEmpty) return;
          Navigator.pop(
            context,
            _ClassDraft(
              code: _code.text.trim().toUpperCase(),
              title: _title.text.trim(),
              description: _description.text.trim(),
              assetTypes: _assetTypes.toList()..sort(),
              lane: _lane,
              counters: _parseCounters()!,
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Save version'),
      ),
    ],
  );
}

class _HistoricalMaintenanceDraft {
  const _HistoricalMaintenanceDraft({
    required this.assetClass,
    required this.asset,
    required this.definition,
    required this.completedOn,
    required this.performedByName,
    required this.evidenceNote,
    required this.sourceReference,
  });

  final AssetClassRecord assetClass;
  final _PlanAssetChoice asset;
  final MaintenanceClassDefinition definition;
  final DateTime completedOn;
  final String? performedByName;
  final String evidenceNote;
  final String? sourceReference;

  Map<String, dynamic> toPayload() => {
    'assetTypeKey': assetClass.legacyAssetTypeKey ?? 'governedCustom',
    'assetNumber': asset.assetNumber,
    'assetClassId': assetClass.id,
    'assetInstanceId': asset.id,
    'assetInstanceVersion': asset.version,
    'definitionId': definition.id,
    'definitionVersion': definition.version,
    'completedAt': completedOn.toUtc().toIso8601String(),
    'performedByName': performedByName,
    'evidenceNote': evidenceNote,
    'sourceReference': sourceReference,
  };
}

class _PlanDraft {
  const _PlanDraft({
    required this.assetClass,
    required this.asset,
    required this.definition,
    required this.start,
    required this.end,
    required this.notes,
  });
  final AssetClassRecord assetClass;
  final _PlanAssetChoice asset;
  final MaintenanceClassDefinition definition;
  final DateTime start;
  final DateTime end;
  final String? notes;

  Map<String, dynamic> toPayload() => {
    'assetTypeKey': assetClass.legacyAssetTypeKey ?? 'governedCustom',
    'assetNumber': asset.assetNumber,
    'assetClassId': assetClass.id,
    'assetInstanceId': asset.id,
    'assetInstanceVersion': asset.version,
    'maintenanceClassDefinitionId': definition.id,
    'maintenanceClassDefinitionVersion': definition.version,
    'targetWindowStart': start.toUtc().toIso8601String(),
    'targetWindowEnd': end.toUtc().toIso8601String(),
    'sourceDueStateId': null,
    'templatePackageId': null,
    'templateVersionId': null,
    'templateContentHash': null,
    'planningNotes': notes,
    'reason': 'Create preventive-maintenance plan from due-state workspace.',
  };
}

class _PlanAssetChoice {
  const _PlanAssetChoice({
    required this.id,
    required this.version,
    required this.name,
    required this.assetNumber,
  });

  final String id;
  final int version;
  final String name;
  final int? assetNumber;
}

class _PlanEditor extends ConsumerStatefulWidget {
  const _PlanEditor({required this.definitions});
  final List<MaintenanceClassDefinition> definitions;

  @override
  ConsumerState<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<_PlanEditor> {
  String? _assetClassId;
  String? _assetInstanceId;
  final _notes = TextEditingController();
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  DateTime _end = DateTime.now().add(const Duration(days: 1, hours: 8));
  String? _definitionId;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 8));
      } else {
        _end = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classValue = ref.watch(assetClassesProvider);
    final classes =
        classValue.asData?.value
            .where(
              (assetClass) =>
                  assetClass.isActive &&
                  widget.definitions.any(
                    (definition) => definition.appliesTo(
                      assetTypeKey:
                          assetClass.legacyAssetTypeKey ?? 'governedCustom',
                      assetClassId: assetClass.id,
                    ),
                  ),
            )
            .toList() ??
        const <AssetClassRecord>[];
    if (!classes.any((item) => item.id == _assetClassId)) {
      _assetClassId = classes.firstOrNull?.id;
      _assetInstanceId = null;
    }
    final selectedClass =
        classes.where((item) => item.id == _assetClassId).firstOrNull;
    final assetType = selectedClass?.legacyAssetTypeKey ?? 'governedCustom';
    final matching =
        selectedClass == null
            ? const <MaintenanceClassDefinition>[]
            : widget.definitions
                .where(
                  (definition) => definition.appliesTo(
                    assetTypeKey: assetType,
                    assetClassId: selectedClass.id,
                  ),
                )
                .toList();
    final AsyncValue<List<_PlanAssetChoice>>? assetsValue;
    if (selectedClass == null) {
      assetsValue = null;
    } else if (assetType == 'innerCover') {
      assetsValue = ref
          .watch(innerCoverProfilesProvider)
          .whenData(
            (profiles) =>
                profiles
                    .where(
                      (profile) =>
                          profile.assetClassId == selectedClass.id &&
                          _isMaintainableInnerCover(profile),
                    )
                    .map(
                      (profile) => _PlanAssetChoice(
                        id: profile.id,
                        version: profile.version,
                        name:
                            profile.isInstalled
                                ? 'Base ${profile.currentBaseAssetNumber} · Inner Cover ${profile.serialNumber}'
                                : 'Pool · Inner Cover ${profile.serialNumber} · ${profile.lifecycleState.label}',
                        assetNumber: null,
                      ),
                    )
                    .toList(),
          );
    } else {
      assetsValue = ref
          .watch(assetInstancesProvider(selectedClass.id))
          .whenData(
            (assets) =>
                assets
                    .where((asset) => asset.isActive)
                    .map(
                      (asset) => _PlanAssetChoice(
                        id: asset.id,
                        version: asset.version,
                        name: asset.name,
                        assetNumber: asset.assetNumber,
                      ),
                    )
                    .toList(),
          );
    }
    final assets = assetsValue?.asData?.value ?? const <_PlanAssetChoice>[];
    if (!assets.any((item) => item.id == _assetInstanceId)) {
      _assetInstanceId = assets.firstOrNull?.id;
    }
    if (!matching.any((item) => item.id == _definitionId)) {
      _definitionId = matching.firstOrNull?.id;
    }
    return AlertDialog(
      title: const Text('Propose maintenance window'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _assetClassId,
                decoration: const InputDecoration(labelText: 'Asset class'),
                items:
                    classes
                        .map(
                          (assetClass) => DropdownMenuItem(
                            value: assetClass.id,
                            child: Text(assetClass.name),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) => setState(() {
                      _assetClassId = value;
                      _assetInstanceId = null;
                      _definitionId = null;
                    }),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(_assetClassId),
                initialValue: _assetInstanceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Physical asset',
                  helperText:
                      assetsValue?.isLoading == true
                          ? 'Loading active assets…'
                          : assetType == 'innerCover'
                          ? 'Installed covers are Base-first; pool covers are selected by serial'
                          : 'Exact identity from the governed asset register',
                ),
                items:
                    assets
                        .map(
                          (asset) => DropdownMenuItem(
                            value: asset.id,
                            child: Text(asset.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _assetInstanceId = value),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey('${_assetClassId ?? ''}-${_definitionId ?? ''}'),
                initialValue: _definitionId,
                decoration: const InputDecoration(
                  labelText: 'Maintenance class',
                ),
                items:
                    matching
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _definitionId = value),
              ),
              const SizedBox(height: BafSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Target start'),
                subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(_start)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('Target end'),
                subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(_end)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pick(false),
              ),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Planning notes (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final definition =
                matching.where((item) => item.id == _definitionId).firstOrNull;
            final asset =
                assets.where((item) => item.id == _assetInstanceId).firstOrNull;
            if (selectedClass == null ||
                asset == null ||
                definition == null ||
                !_end.isAfter(_start)) {
              return;
            }
            Navigator.pop(
              context,
              _PlanDraft(
                assetClass: selectedClass,
                asset: asset,
                definition: definition,
                start: _start,
                end: _end,
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ),
            );
          },
          child: const Text('Propose'),
        ),
      ],
    );
  }
}

class _ActionHeader extends StatelessWidget {
  const _ActionHeader({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
  });
  final String title;
  final String description;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _SummaryBand(
    title: title,
    description: description,
    trailing: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(actionIcon),
      label: Text(actionLabel),
    ),
  );
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({
    required this.title,
    required this.description,
    this.metrics = const [],
    this.trailing,
  });
  final String title;
  final String description;
  final List<_Metric> metrics;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BafSpacing.lg),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.border),
    ),
    child: Wrap(
      spacing: BafSpacing.lg,
      runSpacing: BafSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        ...metrics.map(
          (metric) => Container(
            constraints: const BoxConstraints(minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Column(
              children: [
                Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: metric.color,
                  ),
                ),
                Text(
                  metric.label,
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(icon, size: 52, color: BafColors.textTertiary),
        const SizedBox(height: BafSpacing.md),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: BafColors.danger, size: 42),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String _assetLabel(String key) => switch (key) {
  'forceCooler' => 'Forced Cooler',
  'innerCover' => 'Inner Cover',
  'governedCustom' => 'Governed asset',
  _ => '${key[0].toUpperCase()}${key.substring(1)}',
};

const _assetTypeOptions = ['furnace', 'base', 'forceCooler', 'innerCover'];

const _defaultClasses = <_ClassDraft>[
  _ClassDraft(
    code: 'FURNACE_MID',
    title: 'Furnace Mid Maintenance',
    description:
        'Routine classified Furnace maintenance that resets the general and Mid-maintenance histories.',
    assetTypes: ['furnace'],
    lane: 'mech',
    counters: [
      MaintenanceResetCounter(
        key: 'FURNACE_ANY',
        label: 'Furnace any maintenance',
        thresholdDays: 30,
      ),
      MaintenanceResetCounter(
        key: 'FURNACE_MID',
        label: 'Furnace Mid maintenance',
        thresholdDays: null,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
  _ClassDraft(
    code: 'FURNACE_FULL',
    title: 'Furnace Full Maintenance',
    description:
        'Full Furnace maintenance that also satisfies the Mid-maintenance reset.',
    assetTypes: ['furnace'],
    lane: 'mech',
    counters: [
      MaintenanceResetCounter(
        key: 'FURNACE_ANY',
        label: 'Furnace any maintenance',
        thresholdDays: 30,
      ),
      MaintenanceResetCounter(
        key: 'FURNACE_MID',
        label: 'Furnace Mid maintenance',
        thresholdDays: null,
      ),
      MaintenanceResetCounter(
        key: 'FURNACE_FULL',
        label: 'Furnace Full maintenance',
        thresholdDays: null,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
  _ClassDraft(
    code: 'FURNACE_TRM',
    title: 'Furnace Total Refractory Management',
    description:
        'Complete refractory-level repair governed under the RED lane; it does not imply Full Maintenance.',
    assetTypes: ['furnace'],
    lane: 'red',
    counters: [
      MaintenanceResetCounter(
        key: 'FURNACE_ANY',
        label: 'Furnace any maintenance',
        thresholdDays: 30,
      ),
      MaintenanceResetCounter(
        key: 'FURNACE_REFRACTORY',
        label: 'Furnace refractory maintenance',
        thresholdDays: null,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
  _ClassDraft(
    code: 'BASE_MAINTENANCE',
    title: 'Base Maintenance',
    description: 'Classified preventive maintenance for a BAF Base.',
    assetTypes: ['base'],
    lane: 'mech',
    counters: [
      MaintenanceResetCounter(
        key: 'BASE_MAINTENANCE',
        label: 'Base maintenance',
        thresholdDays: 50,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
  _ClassDraft(
    code: 'FORCED_COOLER_MAINTENANCE',
    title: 'Forced Cooler Maintenance',
    description: 'Classified preventive maintenance for a Forced Cooler.',
    assetTypes: ['forceCooler'],
    lane: 'mech',
    counters: [
      MaintenanceResetCounter(
        key: 'FORCED_COOLER_MAINTENANCE',
        label: 'Forced Cooler maintenance',
        thresholdDays: 90,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
  _ClassDraft(
    code: 'INNER_COVER_CLEANING',
    title: 'Inner Cover Cleaning',
    description:
        'Serial-bound Inner Cover cleaning; cadence remains configurable until operating policy is confirmed.',
    assetTypes: ['innerCover'],
    lane: 'mech',
    counters: [
      MaintenanceResetCounter(
        key: 'INNER_COVER_CLEANING',
        label: 'Inner Cover cleaning',
        thresholdDays: null,
      ),
    ],
    reason: 'Install reviewed BAF default.',
  ),
];
