import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../data/job_lane_record.dart';
import '../../domain/compliance_visibility_policy.dart';
import '../../providers/workflow_providers.dart';
import '../widgets/workflow_progress_route.dart';
import 'compliance_detail_screen.dart';
import 'compliance_inbox_screen.dart';
import 'equipment_status_board.dart';
import 'workflow_hub_screen.dart';

class WorkflowQueueView extends ConsumerStatefulWidget {
  final String query;
  final double bottomPadding;

  const WorkflowQueueView({
    super.key,
    this.query = '',
    required this.bottomPadding,
  });

  @override
  ConsumerState<WorkflowQueueView> createState() => _WorkflowQueueViewState();
}

enum _WorkflowQueueFilter { all, lanes, actions, confirmations }

class _WorkflowQueueViewState extends ConsumerState<WorkflowQueueView> {
  _WorkflowQueueFilter _filter = _WorkflowQueueFilter.all;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (actorAsync.hasError) {
      return const Center(child: Text('Could not verify workflow access.'));
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return const Center(child: Text('Approved access is required.'));
    }

    final lanesAsync = ref.watch(workflowAllLanesProvider);
    final complianceAsync = ref.watch(workflowAllComplianceProvider);
    if (lanesAsync.isLoading || complianceAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lanesAsync.hasError || complianceAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Text(
            'Could not load workflow queue: '
            '${lanesAsync.error ?? complianceAsync.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final needle = widget.query.trim().toLowerCase();
    final lanes =
        (lanesAsync.value ?? const <JobLaneRecord>[])
            .where(
              (lane) =>
                  !lane.isDeleted &&
                  !_terminalLaneStates.contains(lane.statusKey) &&
                  actor.canAcknowledgeOrWorkMaintenanceLane(lane.laneKey) &&
                  _laneMatches(lane, needle),
            )
            .toList()
          ..sort((a, b) {
            final status = _laneSort(
              a.statusKey,
            ).compareTo(_laneSort(b.statusKey));
            return status != 0 ? status : b.updatedAt.compareTo(a.updatedAt);
          });
    final compliance =
        (complianceAsync.value ?? const <ComplianceRequestRecord>[])
            .where(
              (record) =>
                  !record.isDeleted &&
                  !_terminalComplianceStates.contains(record.statusKey) &&
                  isComplianceRequestRelevantToUser(record, actor) &&
                  _complianceMatches(record, needle),
            )
            .toList()
          ..sort((a, b) {
            final due = (b.becameDueAt != null ? 1 : 0).compareTo(
              a.becameDueAt != null ? 1 : 0,
            );
            return due != 0 ? due : b.updatedAt.compareTo(a.updatedAt);
          });
    final actionCompliance = compliance
        .where((record) => complianceRequiresActionFrom(record, actor))
        .toList(growable: false);
    final awaitingOriginConfirmation = compliance
        .where((record) => complianceRequiresOriginConfirmation(record, actor))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => _refreshWorkflowQueue(context, ref),
      child: ListView(
        key: const ValueKey('workflow-queue-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.sm,
          BafSpacing.lg,
          widget.bottomPadding,
        ),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Workflow queue',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh workflow obligations',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _refreshWorkflowQueue(context, ref),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          _WorkflowQueueMetrics(
            lanes: lanes.length,
            actions: actionCompliance.length,
            confirmations: awaitingOriginConfirmation.length,
            selected: _filter,
            onSelected: _selectFilter,
          ),
          if (_filter != _WorkflowQueueFilter.all) ...[
            const SizedBox(height: BafSpacing.sm),
            _ActiveQueueFilter(
              label: _filterLabel(_filter),
              onClear: () => setState(() => _filter = _WorkflowQueueFilter.all),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          _WorkflowQueueDestinations(
            onOverview: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WorkflowHubScreen(),
              ),
            ),
            onCompliance: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ComplianceInboxScreen(),
              ),
            ),
            onEquipment: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EquipmentStatusBoard(),
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          if (_visibleCount(
                lanes: lanes,
                actions: actionCompliance,
                confirmations: awaitingOriginConfirmation,
              ) ==
              0)
            _WorkflowQueueEmpty(
              filter: _filter,
              lanes: lanes.length,
              actions: actionCompliance.length,
              confirmations: awaitingOriginConfirmation.length,
              onOverview: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkflowHubScreen(),
                ),
              ),
            )
          else ...[
            if (_shows(_WorkflowQueueFilter.lanes) && lanes.isNotEmpty) ...[
              const _QueueSectionTitle('Lane assignments'),
              ...lanes.map(
                (lane) => _LaneQueueTile(
                  lane: lane,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkflowHubScreen(
                        initialWorkflowId: lane.workflowFirestoreId,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_shows(_WorkflowQueueFilter.actions) &&
                actionCompliance.isNotEmpty) ...[
              if (_shows(_WorkflowQueueFilter.lanes) && lanes.isNotEmpty)
                const SizedBox(height: BafSpacing.lg),
              const _QueueSectionTitle(
                'Actions requiring your work or decision',
              ),
              ...actionCompliance.map(
                (record) => _ComplianceQueueTile(
                  record: record,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComplianceDetailScreen(record: record),
                    ),
                  ),
                ),
              ),
            ],
            if (_shows(_WorkflowQueueFilter.confirmations) &&
                awaitingOriginConfirmation.isNotEmpty) ...[
              if ((_shows(_WorkflowQueueFilter.lanes) && lanes.isNotEmpty) ||
                  (_shows(_WorkflowQueueFilter.actions) &&
                      actionCompliance.isNotEmpty))
                const SizedBox(height: BafSpacing.lg),
              const _QueueSectionTitle('Awaiting origin confirmation'),
              ...awaitingOriginConfirmation.map(
                (record) => _ComplianceQueueTile(
                  record: record,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComplianceDetailScreen(record: record),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _selectFilter(_WorkflowQueueFilter filter) {
    setState(() {
      _filter = _filter == filter ? _WorkflowQueueFilter.all : filter;
    });
  }

  bool _shows(_WorkflowQueueFilter filter) =>
      _filter == _WorkflowQueueFilter.all || _filter == filter;

  int _visibleCount({
    required List<JobLaneRecord> lanes,
    required List<ComplianceRequestRecord> actions,
    required List<ComplianceRequestRecord> confirmations,
  }) {
    return switch (_filter) {
      _WorkflowQueueFilter.all =>
        lanes.length + actions.length + confirmations.length,
      _WorkflowQueueFilter.lanes => lanes.length,
      _WorkflowQueueFilter.actions => actions.length,
      _WorkflowQueueFilter.confirmations => confirmations.length,
    };
  }

  Future<void> _refreshWorkflowQueue(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(workflowProjectionRefreshProvider)();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh workflow obligations: $error'),
        ),
      );
    }
  }
}

String _filterLabel(_WorkflowQueueFilter filter) => switch (filter) {
  _WorkflowQueueFilter.all => 'All obligations',
  _WorkflowQueueFilter.lanes => 'Lane assignments',
  _WorkflowQueueFilter.actions => 'Actions required',
  _WorkflowQueueFilter.confirmations => 'Completions to confirm',
};

const _terminalLaneStates = <String>{'closed', 'removed', 'terminated'};
const _terminalComplianceStates = <String>{
  'confirmedClosed',
  'superseded',
  'cancelled',
};

int _laneSort(String status) => status == 'pending' ? 0 : 1;

bool _laneMatches(JobLaneRecord lane, String needle) {
  if (needle.isEmpty) return true;
  return <String>[
    lane.laneKey,
    lane.statusKey,
    lane.assetTypeKey,
    '${lane.assetNumber}',
    lane.workflowFirestoreId,
  ].any((value) => value.toLowerCase().contains(needle));
}

bool _complianceMatches(ComplianceRequestRecord record, String needle) {
  if (needle.isEmpty) return true;
  return <String>[
    record.title,
    record.description,
    record.targetLaneKey,
    record.statusKey,
    record.assetTypeKey,
    '${record.assetNumber}',
  ].any((value) => value.toLowerCase().contains(needle));
}

String _laneLabel(String laneKey) {
  return switch (laneKey) {
    'elec' => 'Electrical',
    'mech' => 'Mechanical',
    'inst' => 'Instrumentation',
    'oprn' => 'Operations',
    'red' => 'Refractory',
    'shared' => 'Shared',
    _ => laneKey,
  };
}

class _QueueSectionTitle extends StatelessWidget {
  final String title;

  const _QueueSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(
          color: BafColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WorkflowQueueMetrics extends StatelessWidget {
  const _WorkflowQueueMetrics({
    required this.lanes,
    required this.actions,
    required this.confirmations,
    required this.selected,
    required this.onSelected,
  });

  final int lanes;
  final int actions;
  final int confirmations;
  final _WorkflowQueueFilter selected;
  final ValueChanged<_WorkflowQueueFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WorkflowQueueMetric(
              key: const ValueKey('workflow-queue-lanes-metric'),
              value: lanes,
              label: 'Lanes',
              color: BafColors.planned,
              selected: selected == _WorkflowQueueFilter.lanes,
              onTap: () => onSelected(_WorkflowQueueFilter.lanes),
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: _WorkflowQueueMetric(
              key: const ValueKey('workflow-queue-actions-metric'),
              value: actions,
              label: 'Actions',
              color: BafColors.warning,
              selected: selected == _WorkflowQueueFilter.actions,
              onTap: () => onSelected(_WorkflowQueueFilter.actions),
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: _WorkflowQueueMetric(
              key: const ValueKey('workflow-queue-confirmations-metric'),
              value: confirmations,
              label: 'To confirm',
              color: BafColors.audit,
              selected: selected == _WorkflowQueueFilter.confirmations,
              onTap: () => onSelected(_WorkflowQueueFilter.confirmations),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowQueueMetric extends StatelessWidget {
  const _WorkflowQueueMetric({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $value. Filter workflow queue.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BafRadius.small),
          child: AnimatedContainer(
            duration: BafMotion.quick,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: BafSpacing.sm,
              vertical: BafSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.16 : 0.08),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.72 : 0.22),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveQueueFilter extends StatelessWidget {
  const _ActiveQueueFilter({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $label',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          key: const ValueKey('workflow-queue-show-all'),
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Show all'),
        ),
      ],
    );
  }
}

class _WorkflowQueueDestinations extends StatelessWidget {
  const _WorkflowQueueDestinations({
    required this.onOverview,
    required this.onCompliance,
    required this.onEquipment,
  });

  final VoidCallback onOverview;
  final VoidCallback onCompliance;
  final VoidCallback onEquipment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WorkflowDestinationButton(
                  key: const ValueKey('workflow-queue-overview'),
                  tooltip: 'Open workflow overview',
                  label: compact ? 'Overview' : 'Workflow overview',
                  icon: Icons.account_tree_outlined,
                  color: BafColors.planned,
                  onPressed: onOverview,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: _WorkflowDestinationButton(
                  key: const ValueKey('workflow-queue-compliance'),
                  tooltip: 'Open compliance inbox',
                  label: compact ? 'Inbox' : 'Compliance inbox',
                  icon: Icons.inbox_outlined,
                  color: BafColors.audit,
                  onPressed: onCompliance,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: _WorkflowDestinationButton(
                  key: const ValueKey('workflow-queue-equipment'),
                  tooltip: 'Open equipment status',
                  label: 'Equipment',
                  icon: Icons.precision_manufacturing_outlined,
                  color: BafColors.assets,
                  onPressed: onEquipment,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkflowDestinationButton extends StatelessWidget {
  const _WorkflowDestinationButton({
    super.key,
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: BafColors.textPrimary,
          minimumSize: const Size(0, 70),
          padding: const EdgeInsets.symmetric(
            horizontal: BafSpacing.xs,
            vertical: BafSpacing.sm,
          ),
          side: const BorderSide(color: BafColors.borderStrong),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: BafSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaneQueueTile extends StatelessWidget {
  final JobLaneRecord lane;
  final VoidCallback onTap;

  const _LaneQueueTile({required this.lane, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: BafColors.planned,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_laneLabel(lane.laneKey)} lane',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lane.assetTypeKey.toUpperCase()} ${lane.assetNumber}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    LaneProgressRoute(lane: lane, compact: true),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComplianceQueueTile extends StatelessWidget {
  final ComplianceRequestRecord record;
  final VoidCallback onTap;

  const _ComplianceQueueTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final awaitingConfirmation = record.statusKey == 'complied';
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  awaitingConfirmation
                      ? Icons.pending_actions_outlined
                      : record.becameDueAt == null
                      ? Icons.assignment_outlined
                      : Icons.warning_amber_rounded,
                  color: awaitingConfirmation
                      ? BafColors.audit
                      : record.becameDueAt == null
                      ? BafColors.planned
                      : BafColors.warning,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complianceNextStepLabel(record),
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    ComplianceProgressRoute(record: record, compact: true),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowQueueEmpty extends StatelessWidget {
  const _WorkflowQueueEmpty({
    required this.filter,
    required this.lanes,
    required this.actions,
    required this.confirmations,
    required this.onOverview,
  });

  final _WorkflowQueueFilter filter;
  final int lanes;
  final int actions;
  final int confirmations;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      _WorkflowQueueFilter.all => 'Nothing requires your action',
      _WorkflowQueueFilter.lanes => 'No lane assignments',
      _WorkflowQueueFilter.actions => 'No actions awaiting you',
      _WorkflowQueueFilter.confirmations => 'No completions to confirm',
    };
    final message = filter == _WorkflowQueueFilter.all
        ? '$lanes assigned lanes - $actions requests to act - '
              '$confirmations completions to confirm'
        : 'This category is clear. Other records remain in Overview.';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('workflow-queue-empty-state'),
        onTap: onOverview,
        borderRadius: BorderRadius.circular(BafRadius.small),
        child: Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color: BafColors.success.withValues(alpha: 0.07),
            border: Border.all(
              color: BafColors.success.withValues(alpha: 0.18),
            ),
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                size: 30,
                color: BafColors.success,
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
