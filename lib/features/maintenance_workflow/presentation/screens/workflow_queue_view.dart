import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../data/job_lane_record.dart';
import '../../domain/compliance_visibility_policy.dart';
import '../../providers/workflow_providers.dart';
import 'compliance_detail_screen.dart';
import 'compliance_inbox_screen.dart';
import 'equipment_status_board.dart';
import 'workflow_hub_screen.dart';

class WorkflowQueueView extends ConsumerWidget {
  final String query;
  final double bottomPadding;

  const WorkflowQueueView({
    super.key,
    this.query = '',
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final needle = query.trim().toLowerCase();
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
                  canUserSeeComplianceRequest(record, actor) &&
                  _complianceMatches(record, needle),
            )
            .toList()
          ..sort((a, b) {
            final due = (b.becameDueAt != null ? 1 : 0).compareTo(
              a.becameDueAt != null ? 1 : 0,
            );
            return due != 0 ? due : b.updatedAt.compareTo(a.updatedAt);
          });

    return RefreshIndicator(
      onRefresh: () => _refreshWorkflowQueue(context, ref),
      child: ListView(
        key: const ValueKey('workflow-queue-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.sm,
          BafSpacing.lg,
          bottomPadding,
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
          Wrap(
            spacing: BafSpacing.xs,
            runSpacing: BafSpacing.xs,
            children: [
              StatusBadge(
                label: '${lanes.length} lanes',
                color: BafColors.planned,
              ),
              StatusBadge(
                label: '${compliance.length} obligations',
                color: BafColors.warning,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WorkflowHubScreen(),
                      ),
                    ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Workflow overview'),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComplianceInboxScreen(),
                      ),
                    ),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Compliance inbox'),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EquipmentStatusBoard(),
                      ),
                    ),
                icon: const Icon(Icons.precision_manufacturing_outlined),
                label: const Text('Equipment'),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          if (lanes.isEmpty && compliance.isEmpty)
            const _WorkflowQueueEmpty()
          else ...[
            if (lanes.isNotEmpty) ...[
              const _QueueSectionTitle('Lane assignments'),
              ...lanes.map(
                (lane) => _LaneQueueTile(
                  lane: lane,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => WorkflowHubScreen(
                                initialWorkflowId: lane.workflowFirestoreId,
                              ),
                        ),
                      ),
                ),
              ),
            ],
            if (compliance.isNotEmpty) ...[
              if (lanes.isNotEmpty) const SizedBox(height: BafSpacing.lg),
              const _QueueSectionTitle('Compliance obligations'),
              ...compliance.map(
                (record) => _ComplianceQueueTile(
                  record: record,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => ComplianceDetailScreen(record: record),
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

class _LaneQueueTile extends StatelessWidget {
  final JobLaneRecord lane;
  final VoidCallback onTap;

  const _LaneQueueTile({required this.lane, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(
          Icons.account_tree_outlined,
          color: BafColors.planned,
        ),
        title: Text('${_laneLabel(lane.laneKey)} lane'),
        subtitle: Text(
          '${lane.assetTypeKey.toUpperCase()} ${lane.assetNumber} · ${lane.statusKey}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
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
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          record.becameDueAt == null
              ? Icons.assignment_outlined
              : Icons.warning_amber_rounded,
          color:
              record.becameDueAt == null
                  ? BafColors.planned
                  : BafColors.warning,
        ),
        title: Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_laneLabel(record.targetLaneKey)} · ${record.statusKey}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _WorkflowQueueEmpty extends StatelessWidget {
  const _WorkflowQueueEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: BafSpacing.xl),
      child: Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 36, color: BafColors.success),
          SizedBox(height: BafSpacing.md),
          Text(
            'No workflow tasks need your attention.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
