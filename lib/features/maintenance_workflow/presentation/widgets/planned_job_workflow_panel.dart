import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../audit/presentation/audit_timeline_screen.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../../maintenance/providers/maintenance_provider.dart';
import '../../../planned_maintenance/data/job_module_model.dart';
import '../../../planned_maintenance/providers/job_module_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../data/job_lane_record.dart';
import '../../data/workflow_event_record.dart';
import '../../data/workflow_aggregate_record.dart';
import '../../domain/maintenance_lane.dart';
import '../../domain/workflow_command_contract.dart';
import '../../domain/workflow_types.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_command_factory.dart';
import '../screens/compliance_detail_screen.dart';
import '../screens/lane_classification_screen.dart';
import '../models/lane_closure_readiness.dart';
import 'lane_strip.dart';
import 'raise_compliance_dialog.dart';
import 'workflow_timeline.dart';

/// Live workflow control panel embedded in the planned-job dossier.
///
/// The server remains the final authority for every command. UI checks only
/// suppress obviously unavailable controls; they never replace backend role,
/// version, progress, compliance or RED-precondition validation.
class PlannedJobWorkflowPanel extends ConsumerWidget {
  final String workflowId;
  final bool jobCompleted;

  const PlannedJobWorkflowPanel({
    super.key,
    required this.workflowId,
    required this.jobCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: EdgeInsets.all(16), child: _PanelLoading()),
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Approved access is required to inspect this workflow.'),
        ),
      );
    }

    final workflowAsync = ref.watch(workflowRecordProvider(workflowId));
    final lanesAsync = ref.watch(workflowLanesProvider(workflowId));
    final eventsAsync = ref.watch(workflowEventsProvider(workflowId));
    final complianceAsync = ref.watch(workflowComplianceProvider(workflowId));
    final commandState = ref.watch(workflowCommandControllerProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: workflowAsync.when(
          loading: () => const _PanelLoading(),
          error:
              (error, _) => _PanelError(
                message: 'Could not load maintenance workflow: $error',
                onRetry: () => _refresh(ref),
              ),
          data: (workflow) {
            if (workflow == null) {
              return _PanelError(
                message:
                    'Workflow data is not available locally yet. Refresh after synchronization.',
                onRetry: () => _refresh(ref),
              );
            }
            final lanes = lanesAsync.value ?? const <JobLaneRecord>[];
            final compliances =
                complianceAsync.value ?? const <ComplianceRequestRecord>[];
            final moduleInventoryAsync = ref.watch(
              jobModulesProvider(
                JobModuleQueryKey(
                  jobExecutionFirestoreId:
                      workflow.jobExecutionFirestoreId.trim(),
                  limit: 401,
                ),
              ),
            );
            final moduleInventory =
                moduleInventoryAsync.value ?? const <JobModuleInstance>[];
            final readinessInventoryComplete =
                lanesAsync.hasValue &&
                complianceAsync.hasValue &&
                moduleInventoryAsync.hasValue &&
                moduleInventory.length < 401;
            final readinessByLaneId =
                readinessInventoryComplete
                    ? _buildLaneReadiness(
                      lanes: lanes,
                      modules: moduleInventory,
                      compliances: compliances,
                    )
                    : null;
            final readinessError = _readinessError(
              lanesAsync: lanesAsync,
              complianceAsync: complianceAsync,
              moduleInventoryAsync: moduleInventoryAsync,
              moduleInventoryCount: moduleInventory.length,
            );
            final activeLanes = lanes
                .where(
                  (lane) =>
                      lane.statusKey != 'removed' &&
                      lane.statusKey != 'terminated' &&
                      lane.statusKey != 'closed',
                )
                .toList(growable: false);
            final originLanes = lanes
                .where(
                  (lane) =>
                      lane.statusKey != 'removed' &&
                      lane.statusKey != 'terminated' &&
                      actor.canAcknowledgeOrWorkMaintenanceLane(lane.laneKey),
                )
                .toList(growable: false);
            final blockingCompliance = compliances
                .where(
                  (request) =>
                      _isOpenCompliance(request) &&
                      request.gatesLaneFirestoreId != null,
                )
                .toList(growable: false);
            final canManage = actor.canFinalizeMaintenanceLaneSet;
            final workflowTerminal =
                jobCompleted ||
                workflow.statusKey == 'completed' ||
                workflow.statusKey == 'cancelled';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Maintenance workflow',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _statusLabel(workflow.statusKey),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh workflow',
                      onPressed:
                          commandState.isLoading ? null : () => _refresh(ref),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Workflow timeline',
                      onPressed:
                          () => _showTimeline(
                            context,
                            eventsAsync.value ?? const [],
                            workflow.jobExecutionFirestoreId,
                            canViewAuditEvidence: actor.canViewAuditLogs,
                          ),
                      icon: const Icon(Icons.history),
                    ),
                  ],
                ),
                if (workflowTerminal) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'This workflow is closed for mutation. Timeline and state remain available for review.',
                  ),
                ],
                if (blockingCompliance.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...blockingCompliance
                      .take(3)
                      .map(
                        (request) => Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: ListTile(
                            leading: const Icon(Icons.lock_clock_outlined),
                            title: Text(request.title),
                            subtitle: Text(
                              '${request.targetLaneKey.toUpperCase()} · ${request.statusKey}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap:
                                () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => ComplianceDetailScreen(
                                          record: request,
                                        ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                ],
                if (workflow.statusKey == 'pendingLaneClassification') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'This job is awaiting lane classification. Work cannot be acknowledged until the accountable departments are finalised.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        !workflowTerminal &&
                                canManage &&
                                !commandState.isLoading
                            ? () => _openClassification(context, workflow)
                            : null,
                    icon: const Icon(Icons.account_tree),
                    label: const Text('Classify lanes'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  if (lanes.isEmpty)
                    const Text('No lane records are available locally yet.')
                  else
                    WorkflowLaneStrip(
                      lanes: lanes,
                      readinessByLaneId: readinessByLaneId,
                      readinessLoading:
                          !readinessInventoryComplete && readinessError == null,
                      readinessError: readinessError,
                      onLaneTap:
                          workflowTerminal || commandState.isLoading
                              ? null
                              : (lane) => _openLaneActions(
                                context,
                                ref,
                                workflow,
                                lane,
                                canManage: canManage,
                                readiness:
                                    lane.firestoreId == null
                                        ? null
                                        : readinessByLaneId?[lane.firestoreId!
                                            .trim()],
                              ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canManage && !workflowTerminal)
                        OutlinedButton.icon(
                          onPressed:
                              commandState.isLoading
                                  ? null
                                  : () =>
                                      _addLane(context, ref, workflow, lanes),
                          icon: const Icon(Icons.add),
                          label: const Text('Add lane'),
                        ),
                      if (originLanes.isNotEmpty && !workflowTerminal)
                        OutlinedButton.icon(
                          onPressed:
                              commandState.isLoading
                                  ? null
                                  : () => _raiseCompliance(
                                    context,
                                    ref,
                                    workflow,
                                    originLanes,
                                    activeLanes,
                                  ),
                          icon: const Icon(Icons.assignment_add),
                          label: const Text('Raise compliance'),
                        ),
                      if (_redPreparationReady(workflow, lanes) &&
                          actor.canPrepareMaintenanceRedLane &&
                          !workflowTerminal)
                        FilledButton.tonalIcon(
                          onPressed:
                              commandState.isLoading
                                  ? null
                                  : () =>
                                      _prepareRedLane(context, ref, workflow),
                          icon: const Icon(
                            Icons.local_fire_department_outlined,
                          ),
                          label: const Text('Prepare RED lane'),
                        ),
                      if (actor.canCancelMaintenanceWorkflow &&
                          !workflowTerminal)
                        OutlinedButton.icon(
                          onPressed:
                              commandState.isLoading
                                  ? null
                                  : () =>
                                      _cancelWorkflow(context, ref, workflow),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel workflow'),
                        ),
                      OutlinedButton.icon(
                        onPressed:
                            () => _showTimeline(
                              context,
                              eventsAsync.value ?? const [],
                              workflow.jobExecutionFirestoreId,
                              canViewAuditEvidence: actor.canViewAuditLogs,
                            ),
                        icon: const Icon(Icons.history),
                        label: Text(
                          'Timeline (${eventsAsync.value?.length ?? 0})',
                        ),
                      ),
                    ],
                  ),
                ],
                if (commandState.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text('Applying authoritative workflow command…'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(workflowPullServiceProvider).pull();
  }

  Future<void> _openClassification(
    BuildContext context,
    WorkflowAggregateRecord workflow,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => LaneClassificationScreen(
              workflowId: workflow.firestoreId,
              expectedVersion: workflow.version,
            ),
      ),
    );
  }

  Future<void> _openLaneActions(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
    JobLaneRecord lane, {
    required bool canManage,
    required LaneClosureReadiness? readiness,
  }) async {
    final actor = ref.read(currentAppUserProvider).value;
    final mayAcknowledge =
        actor?.canAcknowledgeOrWorkMaintenanceLane(lane.laneKey) ?? false;
    final mayClose = actor?.canCloseMaintenanceLane(lane.laneKey) ?? false;

    final action = await showModalBottomSheet<_LaneAction>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('${lane.laneKey.toUpperCase()} lane'),
                  subtitle: Text(
                    readiness == null
                        ? 'Current status: ${lane.statusKey}'
                        : readiness.summary,
                  ),
                ),
                if (lane.statusKey == 'pending')
                  ListTile(
                    enabled: mayAcknowledge,
                    leading: const Icon(Icons.mark_email_read_outlined),
                    title: const Text('Acknowledge lane'),
                    onTap:
                        () => Navigator.pop(
                          sheetContext,
                          _LaneAction.acknowledge,
                        ),
                  ),
                if (lane.statusKey == 'acknowledged')
                  ListTile(
                    enabled: mayClose,
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Close lane'),
                    subtitle: Text(
                      readiness?.readyForClosure == true
                          ? 'Local module and compliance checks are ready. The server will revalidate before closure.'
                          : _laneCloseSubtitle(readiness),
                    ),
                    onTap: () => Navigator.pop(sheetContext, _LaneAction.close),
                  ),
                if (canManage && lane.statusKey != 'closed') ...[
                  ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: const Text('Remove untouched lane'),
                    subtitle: const Text(
                      'Rejected if protected work, diary, evidence or compliance exists.',
                    ),
                    onTap:
                        () => Navigator.pop(sheetContext, _LaneAction.remove),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined),
                    title: const Text('Terminate lane'),
                    subtitle: const Text(
                      'Preserves all progress and requires a reason.',
                    ),
                    onTap:
                        () =>
                            Navigator.pop(sheetContext, _LaneAction.terminate),
                  ),
                ],
              ],
            ),
          ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _LaneAction.acknowledge:
        await _execute(
          context,
          ref,
          WorkflowCommandFactory.create(
            type: WorkflowCommandType.acknowledgeLane,
            aggregateId: workflow.firestoreId,
            expectedVersion: workflow.version,
            payload: <String, Object?>{'laneKey': lane.laneKey},
          ),
        );
        break;
      case _LaneAction.close:
        final note = await _promptText(
          context,
          title: 'Close ${lane.laneKey.toUpperCase()} lane',
          label: 'Closure note (optional)',
          required: false,
        );
        if (note == null || !context.mounted) return;
        await _execute(
          context,
          ref,
          WorkflowCommandFactory.create(
            type: WorkflowCommandType.closeLane,
            aggregateId: workflow.firestoreId,
            expectedVersion: workflow.version,
            payload: <String, Object?>{
              'laneKey': lane.laneKey,
              if (note.trim().isNotEmpty) 'note': note.trim(),
            },
          ),
        );
        break;
      case _LaneAction.remove:
        final reason = await _promptText(
          context,
          title: 'Remove ${lane.laneKey.toUpperCase()} lane',
          label: 'Reason',
          required: true,
        );
        if (reason == null || !context.mounted) return;
        await _execute(
          context,
          ref,
          WorkflowCommandFactory.create(
            type: WorkflowCommandType.removeLane,
            aggregateId: workflow.firestoreId,
            expectedVersion: workflow.version,
            payload: <String, Object?>{
              'laneKey': lane.laneKey,
              'reason': reason.trim(),
            },
          ),
        );
        break;
      case _LaneAction.terminate:
        final reason = await _promptText(
          context,
          title: 'Terminate ${lane.laneKey.toUpperCase()} lane',
          label: 'Termination reason',
          required: true,
        );
        if (reason == null || !context.mounted) return;
        await _execute(
          context,
          ref,
          WorkflowCommandFactory.create(
            type: WorkflowCommandType.terminateLane,
            aggregateId: workflow.firestoreId,
            expectedVersion: workflow.version,
            payload: <String, Object?>{
              'laneKey': lane.laneKey,
              'reason': reason.trim(),
            },
          ),
        );
        break;
    }
  }

  Map<String, LaneClosureReadiness> _buildLaneReadiness({
    required List<JobLaneRecord> lanes,
    required List<JobModuleInstance> modules,
    required List<ComplianceRequestRecord> compliances,
  }) {
    return <String, LaneClosureReadiness>{
      for (final lane in lanes)
        if (lane.firestoreId?.trim().isNotEmpty == true)
          lane.firestoreId!.trim(): LaneClosureReadiness.fromRecords(
            lane: lane,
            modules: modules,
            complianceRequests: compliances,
          ),
    };
  }

  String? _readinessError({
    required AsyncValue<List<JobLaneRecord>> lanesAsync,
    required AsyncValue<List<ComplianceRequestRecord>> complianceAsync,
    required AsyncValue<List<JobModuleInstance>> moduleInventoryAsync,
    required int moduleInventoryCount,
  }) {
    if (lanesAsync.hasError) return 'Lane readiness could not be loaded.';
    if (complianceAsync.hasError) {
      return 'Compliance readiness could not be loaded.';
    }
    if (moduleInventoryAsync.hasError) {
      return 'Module readiness could not be loaded.';
    }
    if (moduleInventoryCount >= 401) {
      return 'Module inventory exceeds the governed display limit; server validation is required.';
    }
    return null;
  }

  String _laneCloseSubtitle(LaneClosureReadiness? readiness) {
    if (readiness == null) {
      return 'Local readiness is unavailable. The server will verify modules and blocking compliance.';
    }
    final reasons = readiness.blockingReasons;
    if (reasons.isEmpty) {
      return 'The server will verify modules and blocking compliance.';
    }
    return '${reasons.take(2).join('. ')}${reasons.length > 2 ? '. Additional blockers are shown in lane readiness.' : '.'}';
  }

  Future<void> _addLane(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
    List<JobLaneRecord> lanes,
  ) async {
    final active =
        lanes
            .where(
              (lane) =>
                  lane.statusKey != 'removed' && lane.statusKey != 'terminated',
            )
            .map((lane) => lane.laneKey)
            .toSet();
    final lane = await showModalBottomSheet<MaintenanceLaneId>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: MaintenanceLaneCatalog.crm3.definitions
                  .where((definition) => !active.contains(definition.id.value))
                  .map(
                    (definition) => ListTile(
                      leading: CircleAvatar(child: Text(definition.code)),
                      title: Text(definition.displayName),
                      subtitle:
                          definition.delegated
                              ? const Text(
                                'Admin/SI acts transparently on behalf of EMD',
                              )
                              : null,
                      onTap: () => Navigator.pop(sheetContext, definition.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
    );
    if (lane == null || !context.mounted) return;
    final reason = await _promptText(
      context,
      title: 'Add ${lane.value.toUpperCase()} lane',
      label: 'Reason for adding lane',
      required: true,
    );
    if (reason == null || !context.mounted) return;
    await _execute(
      context,
      ref,
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.addLane,
        aggregateId: workflow.firestoreId,
        expectedVersion: workflow.version,
        payload: <String, Object?>{
          'laneKey': lane.value,
          'reason': reason.trim(),
        },
      ),
    );
  }

  bool _isOpenCompliance(ComplianceRequestRecord request) {
    return request.statusKey != 'confirmedClosed' &&
        request.statusKey != 'superseded' &&
        request.statusKey != 'cancelled';
  }

  bool _redPreparationReady(
    WorkflowAggregateRecord workflow,
    List<JobLaneRecord> lanes,
  ) {
    if (workflow.activeRedWork || workflow.awaitingPreparation) return false;
    JobLaneRecord? redLane;
    for (final lane in lanes) {
      if (lane.laneKey == 'red' &&
          lane.statusKey != 'removed' &&
          lane.statusKey != 'terminated') {
        redLane = lane;
        break;
      }
    }
    if (redLane == null || redLane.statusKey != 'pending') return false;
    return lanes
        .where(
          (lane) =>
              lane.laneKey != 'red' &&
              lane.statusKey != 'removed' &&
              lane.statusKey != 'terminated',
        )
        .every((lane) => lane.statusKey == 'closed');
  }

  Future<void> _prepareRedLane(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
  ) async {
    bool preparationRequired = false;
    if (workflow.assetTypeKey == 'furnace') {
      final answer = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Prepare RED work'),
              content: Text(
                'Does furnace ${workflow.assetNumber} need to be placed on the maintenance stand before RED work?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('No — work in position'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Yes — raise Operations preparation'),
                ),
              ],
            ),
      );
      if (answer == null || !context.mounted) return;
      preparationRequired = answer;
    }
    await _execute(
      context,
      ref,
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.prepareRedLane,
        aggregateId: workflow.firestoreId,
        expectedVersion: workflow.version,
        payload: <String, Object?>{'preparationRequired': preparationRequired},
      ),
    );
  }

  Future<void> _raiseCompliance(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
    List<JobLaneRecord> originLanes,
    List<JobLaneRecord> activeLanes,
  ) async {
    final maintenanceTickets = await _eligibleMaintenanceTickets(
      context,
      ref,
      workflow,
    );
    if (!context.mounted) return;
    final draft = await showRaiseComplianceDialog(
      context,
      originLanes: originLanes,
      activeLanes: activeLanes,
      maintenanceTickets: maintenanceTickets,
    );
    if (draft == null || !context.mounted) return;
    JobLaneRecord? originLane;
    for (final lane in originLanes) {
      if (lane.laneKey == draft.originLaneKey) {
        originLane = lane;
        break;
      }
    }
    final gatingId = draft.gatingLane?.firestoreId;
    await _execute(
      context,
      ref,
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.raiseCompliance,
        aggregateId: workflow.firestoreId,
        expectedVersion: workflow.version,
        payload: <String, Object?>{
          'complianceId': WorkflowCommandFactory.uniqueId(
            'compliance_${workflow.firestoreId}',
          ),
          'originLaneKey': draft.originLaneKey,
          'targetLaneKey': draft.targetLaneKey,
          'title': draft.title,
          'description': draft.description,
          'conditionTypeKey': draft.conditionTypeKey,
          if (draft.conditionRef != null) 'conditionRef': draft.conditionRef,
          'priorityKey': draft.priorityKey,
          if (draft.linkedMaintenanceId != null)
            'linkedMaintenanceFirestoreId': draft.linkedMaintenanceId,
          if (originLane?.firestoreId != null)
            'linkedLaneFirestoreId': originLane!.firestoreId,
          if (gatingId != null) 'gatesLaneFirestoreId': 'job_lanes/$gatingId',
        },
      ),
    );
  }

  Future<List<MaintenanceRecord>> _eligibleMaintenanceTickets(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
  ) async {
    AssetType? assetType;
    for (final candidate in AssetType.values) {
      if (candidate.name == workflow.assetTypeKey) {
        assetType = candidate;
        break;
      }
    }
    if (assetType == null || workflow.assetNumber <= 0) return const [];
    try {
      final records = await ref
          .read(maintenanceRepositoryProvider)
          .getTicketsForAsset(assetType, workflow.assetNumber);
      final eligible = records
          .where((ticket) {
            final remoteId = ticket.firestoreId?.trim();
            if (remoteId == null || remoteId.isEmpty) return false;
            if (ticket.isDeleted || ticket.isResolved) return false;
            if (!ticket.isWorkflowLinked) return true;
            return ticket.workflowQueueState == 'released' ||
                ticket.workflowQueueState == 'independent';
          })
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return eligible;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Open maintenance tickets could not be loaded. '
              'Immediate compliance can still be raised without a link: $error',
            ),
          ),
        );
      }
      return const [];
    }
  }

  Future<void> _cancelWorkflow(
    BuildContext context,
    WidgetRef ref,
    WorkflowAggregateRecord workflow,
  ) async {
    final reason = await _promptText(
      context,
      title: 'Cancel maintenance workflow',
      label: 'Cancellation reason',
      required: true,
    );
    if (reason == null || !context.mounted) return;
    await _execute(
      context,
      ref,
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.cancelWorkflow,
        aggregateId: workflow.firestoreId,
        expectedVersion: workflow.version,
        payload: <String, Object?>{'reason': reason.trim()},
      ),
    );
  }

  Future<void> _execute(
    BuildContext context,
    WidgetRef ref,
    WorkflowCommand command,
  ) async {
    try {
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(receipt.resultKey)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String label,
    required bool required,
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (_) => _WorkflowTextPromptDialog(
            title: title,
            label: label,
            isRequired: required,
          ),
    );
  }

  void _showTimeline(
    BuildContext context,
    List<WorkflowEventRecord> events,
    String executionId, {
    required bool canViewAuditEvidence,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.72,
              child: Column(
                children: [
                  if (canViewAuditEvidence) ...[
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Original execution audit evidence'),
                      subtitle: const Text(
                        'Open closure, cancellation and governed module evidence correlated to this workflow.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => AuditTimelineScreen(
                                    entityType: 'execution',
                                    entityId: executionId,
                                  ),
                            ),
                          ),
                    ),
                    const Divider(height: 1),
                  ],
                  Expanded(child: WorkflowTimeline(events: events)),
                ],
              ),
            ),
          ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pendingLaneClassification':
        return 'Pending lane classification';
      case 'partiallyAcknowledged':
        return 'Partially acknowledged';
      case 'fullyAcknowledged':
        return 'Fully acknowledged';
      case 'awaitingCompliance':
        return 'Awaiting compliance';
      case 'readyForClosure':
        return 'Ready for final closure';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class _WorkflowTextPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final bool isRequired;

  const _WorkflowTextPromptDialog({
    required this.title,
    required this.label,
    required this.isRequired,
  });

  @override
  State<_WorkflowTextPromptDialog> createState() =>
      _WorkflowTextPromptDialogState();
}

class _WorkflowTextPromptDialogState extends State<_WorkflowTextPromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (widget.isRequired && value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

enum _LaneAction { acknowledge, close, remove, terminate }

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      SizedBox(width: 12),
      Text('Loading maintenance workflow…'),
    ],
  );
}

class _PanelError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _PanelError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    ],
  );
}
