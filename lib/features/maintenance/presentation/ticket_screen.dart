// FILE: lib/features/maintenance/presentation/ticket_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/sync_status_provider.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/presentation/screens/compliance_detail_screen.dart';
import '../../operational_events/presentation/operational_event_issue_links_screen.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_ticket_correction.dart';
import '../providers/maintenance_provider.dart';
import '../services/maintenance_issue_administrative_closure_command.dart';
import '../services/maintenance_issue_command_reconciler.dart';
import 'issue_administrative_closure_dialog.dart';
import 'issue_coordination_dialog.dart';
import 'issue_lane_management_dialog.dart';
import 'maintenance_form.dart';
import 'maintenance_ticket_correction_dialog.dart';
import 'maintenance_ticket_detail_screen.dart';
import 'resolve_form.dart';

part 'ticket_screen.governed_actions.dart';
part 'ticket_screen.card_actions.dart';

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key});

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  Timer? _timer;
  String _query = '';
  String? _busyTicketId;

  void _setBusyTicketId(String? value) => setState(() => _busyTicketId = value);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return ColoredBox(
      color: BafColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: BafColors.maintenance,
          backgroundColor: BafColors.card,
          onRefresh: _refreshTickets,
          child: appUserAsync.when(
            loading: _buildLoadingState,
            error:
                (error, _) => _buildErrorState(
                  title: 'Could not load your access',
                  message: '$error',
                ),
            data: (appUser) {
              if (appUser == null || !appUser.isApproved) {
                return _buildAccessPendingState();
              }

              final openTicketsAsync = ref.watch(openTicketsProvider);

              return openTicketsAsync.when(
                loading: _buildLoadingState,
                error:
                    (error, _) => _buildErrorState(
                      title: 'Could not load issues',
                      message: '$error',
                    ),
                data: (allTickets) {
                  final tickets = _visibleTickets(allTickets, appUser);

                  if (tickets.isEmpty) {
                    return _buildEmptyState(appUser, syncStatus);
                  }

                  return _buildTicketList(tickets, appUser, syncStatus);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _refreshTickets() async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.isApproved) return;

    try {
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final outcome = await syncCoordinator.runFullSyncWithResult(
        reason: 'tickets_manual_refresh',
        force: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(outcome.manualSyncMessage),
          backgroundColor:
              outcome.isFailure
                  ? BafColors.danger
                  : (outcome.isSuccessful ? BafColors.sync : BafColors.warning),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not refresh issues: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  List<MaintenanceRecord> _visibleTickets(
    List<MaintenanceRecord> allTickets,
    AppUser appUser,
  ) {
    return allTickets.where((ticket) {
      final laneRead = ticket.issueLanePlanReadResult;
      if (!laneRead.isValid) {
        return appUser.canViewMaintenanceTicket(
          loggedByUid: ticket.loggedByUid,
          routedTo: ticket.routedTo,
        );
      }
      return appUser.canViewMaintenanceIssue(
        loggedByUid: ticket.loggedByUid,
        lanes: laneRead.value!.assignedLanes.map(RoutedTo.values.byName),
      );
    }).toList();
  }

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(BafSpacing.lg),
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: BafColors.maintenance)),
      ],
    );
  }

  Widget _buildErrorState({required String title, required String message}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(BafSpacing.lg),
      children: [
        _StateCard(
          icon: Icons.error_outline_rounded,
          color: BafColors.danger,
          title: title,
          message: message,
        ),
      ],
    );
  }

  Widget _buildAccessPendingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(BafSpacing.lg),
      children: const [
        SizedBox(height: 80),
        _StateCard(
          icon: Icons.verified_user_outlined,
          color: BafColors.audit,
          title: 'Checking your access',
          message:
              'Your issue list will appear once your approved user profile is loaded.',
        ),
      ],
    );
  }

  Widget _buildTicketList(
    List<MaintenanceRecord> tickets,
    AppUser appUser,
    SyncStatus syncStatus,
  ) {
    final filtered = _filterTickets(tickets, _query);

    return _BoundedIssuesContent(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.lg,
          BafSpacing.lg,
          BafSpacing.xl,
        ),
        children: [
          _IssuesHeader(
            count: filtered.length,
            totalCount: tickets.length,
            canSeeAll: appUser.canSeeAllTickets,
            canSeeAssigned: appUser.canSeeAssignedMaintenanceTickets,
            isSyncing: syncStatus == SyncStatus.syncing,
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
            onRaiseIssue: _openMaintenanceForm,
            onSyncNow: _refreshTickets,
          ),
          const SizedBox(height: BafSpacing.md),
          if (filtered.isEmpty)
            const _NoMatchingIssuesState()
          else
            ...filtered.map((ticket) {
              final laneRead = ticket.issueLanePlanReadResult;
              final plan = laneRead.value;
              final assignedRoutes =
                  plan?.assignedLanes.map(RoutedTo.values.byName).toList() ??
                  const <RoutedTo>[];
              final canResolveThis =
                  ticket.isSynced &&
                  laneRead.isValid &&
                  appUser.canFinalizeMaintenanceIssue(assignedRoutes);
              final ticketId = ticket.firestoreId?.trim();
              final hasGovernedServerState =
                  ticket.isSynced && ticketId != null && ticketId.isNotEmpty;
              final acknowledgeableLanes =
                  plan?.lanesAwaitingAcknowledgement
                      .map(RoutedTo.values.byName)
                      .where(appUser.canAcknowledgeMaintenanceTicket)
                      .toList(growable: false) ??
                  const <RoutedTo>[];
              final completableLanes =
                  plan?.acknowledgedLanes
                      .where((lane) => !plan.completedLanes.contains(lane))
                      .map(RoutedTo.values.byName)
                      .where(appUser.canCompleteMaintenanceIssueLane)
                      .toList(growable: false) ??
                  const <RoutedTo>[];
              final canAcknowledge =
                  laneRead.isValid &&
                  acknowledgeableLanes.isNotEmpty &&
                  !ticket.workflowDeferred &&
                  hasGovernedServerState;
              final canCoordinate =
                  (ticket.status == TicketStatus.acknowledged ||
                      ticket.status == TicketStatus.inProgress) &&
                  !ticket.isResolved &&
                  (ticket.workflowQueueState == 'independent' ||
                      ticket.workflowQueueState == 'released') &&
                  hasGovernedServerState &&
                  plan != null &&
                  plan.acknowledgedLanes
                      .where((lane) => !plan.completedLanes.contains(lane))
                      .map(RoutedTo.values.byName)
                      .any(appUser.canStartIssueCoordination);
              return Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.md),
                child: _TicketCard(
                  ticket: ticket,
                  onViewDetails:
                      () => _openTicketDetails(
                        ticket,
                        canCorrect:
                            appUser.canCorrectMaintenanceTicket &&
                            hasGovernedServerState,
                      ),
                  canResolve: canResolveThis && !ticket.workflowDeferred,
                  onResolve: () => _openResolve(ticket),
                  canCloseWithoutResolution:
                      appUser.canCloseMaintenanceIssueWithoutResolution &&
                      laneRead.isValid &&
                      hasGovernedServerState,
                  onCloseWithoutResolution:
                      () => _closeWithoutResolution(ticket),
                  canAcknowledge: canAcknowledge,
                  isBusy: _busyTicketId == ticketId,
                  onAcknowledge: () => _acknowledgeTicket(ticket),
                  canCompleteLane:
                      completableLanes.isNotEmpty &&
                      !ticket.workflowDeferred &&
                      hasGovernedServerState,
                  onCompleteLane: () => _completeTicketLane(ticket),
                  canManageLanes:
                      laneRead.isValid &&
                      appUser.canManageMaintenanceIssueLanes &&
                      hasGovernedServerState &&
                      !ticket.workflowDeferred &&
                      (ticket.workflowQueueState == 'independent' ||
                          ticket.workflowQueueState == 'released'),
                  onManageLanes: () => _manageTicketLanes(ticket),
                  canRepairLaneData:
                      !laneRead.isValid && hasGovernedServerState,
                  onRepairLaneData: () => _repairTicketFromServer(ticket),
                  canRefreshServer: laneRead.isValid && hasGovernedServerState,
                  onRefreshServer: () => _repairTicketFromServer(ticket),
                  canCoordinate: canCoordinate,
                  onCoordinate: () => _startIssueCoordination(ticket),
                  onOpenCoordination:
                      ticket.workflowComplianceId?.trim().isNotEmpty == true
                          ? () => _openIssueCoordination(ticket)
                          : null,
                  onViewEventLinks:
                      ticket.operationalEventIssueLinkIds.isEmpty
                          ? null
                          : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => MaintenanceIssueEventLinksScreen(
                                    issue: ticket,
                                  ),
                            ),
                          ),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<MaintenanceRecord> _filterTickets(
    List<MaintenanceRecord> tickets,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return tickets;
    return tickets
        .where((ticket) {
          return <String?>[
            ticket.description,
            ticket.assetType.name,
            '${ticket.assetNumber}',
            ticket.component,
            ticket.subsystem,
            ticket.tag,
            ticket.classification,
            ticket.routedTo.name,
            ticket.loggedByName,
            ticket.reportedBy,
          ].any((value) => value?.toLowerCase().contains(needle) == true);
        })
        .toList(growable: false);
  }

  void _openMaintenanceForm() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const MaintenanceForm()),
    );
  }

  Future<void> _openResolve(MaintenanceRecord ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResolveForm(ticket: ticket)),
    );
  }

  Future<void> _acknowledgeTicket(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty || _busyTicketId != null) return;
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    final appUser = ref.read(currentAppUserProvider).value;
    final plan = ticket.issueLanePlanReadResult.value;
    if (appUser == null || plan == null) return;
    final candidates = plan.lanesAwaitingAcknowledgement
        .map(RoutedTo.values.byName)
        .where(appUser.canAcknowledgeMaintenanceTicket)
        .toList(growable: false);
    final lane = await _selectIssueLane(
      title: 'Acknowledge accountable lane',
      lanes: candidates,
    );
    if (lane == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Acknowledge this issue?'),
            content: Text(
              'This records that ${_TicketCard._deptLabel(lane)} has received and accepted responsibility for triage. It does not resolve the issue or another lane.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Acknowledge'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyTicketId = ticketId);
    try {
      final command = WorkflowCommandFactory.create(
        type: WorkflowCommandType.acknowledgeMaintenanceTicket,
        aggregateId: ticketId,
        expectedVersion: expectedLocalVersion,
        payload: <String, Object?>{'lane': lane.name},
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: receipt,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: receipt.aggregateVersion,
        syncReason: 'maintenance_ticket_acknowledged',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? 'Issue lane acknowledged'
                : 'Acknowledgement accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.success : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not acknowledge issue: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Future<void> _completeTicketLane(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty || _busyTicketId != null) return;
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    final appUser = ref.read(currentAppUserProvider).value;
    final plan = ticket.issueLanePlanReadResult.value;
    if (appUser == null || plan == null) return;
    final candidates = plan.acknowledgedLanes
        .where((lane) => !plan.completedLanes.contains(lane))
        .map(RoutedTo.values.byName)
        .where(appUser.canCompleteMaintenanceIssueLane)
        .toList(growable: false);
    final lane = await _selectIssueLane(
      title: 'Complete accountable lane',
      lanes: candidates,
    );
    if (lane == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Complete ${_TicketCard._deptLabel(lane)}?'),
            content: const Text(
              'This settles only this lane. Final issue closure remains a separate supervisory decision.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Complete lane'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyTicketId = ticketId);
    try {
      final command = WorkflowCommandFactory.create(
        type: WorkflowCommandType.completeMaintenanceTicketLane,
        aggregateId: ticketId,
        expectedVersion: expectedLocalVersion,
        payload: <String, Object?>{'lane': lane.name},
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: receipt,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: receipt.aggregateVersion,
        syncReason: 'maintenance_ticket_lane_completed',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? '${_TicketCard._deptLabel(lane)} lane completed'
                : 'Lane completion accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.success : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not complete issue lane: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Future<RoutedTo?> _selectIssueLane({
    required String title,
    required List<RoutedTo> lanes,
  }) async {
    if (lanes.isEmpty) return null;
    if (lanes.length == 1) return lanes.single;
    return showDialog<RoutedTo>(
      context: context,
      builder:
          (dialogContext) => SimpleDialog(
            title: Text(title),
            children: [
              for (final lane in lanes)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, lane),
                  child: Row(
                    children: [
                      Icon(
                        Icons.route_rounded,
                        color: _TicketCard._agencyColor(lane),
                      ),
                      const SizedBox(width: BafSpacing.md),
                      Text(_TicketCard._deptLabel(lane)),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Future<bool> _adoptAcceptedIssueCommand({
    required String ticketId,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
    required int minimumServerVersion,
    required String syncReason,
  }) async {
    if (ticketId.isEmpty || minimumServerVersion < 1) {
      return false;
    }
    final reconciler = ref.read(maintenanceIssueCommandReconcilerProvider);

    Future<bool> adopt() async {
      try {
        await reconciler.adoptServerMutation(
          firestoreId: ticketId,
          expectedLocalVersion: expectedLocalVersion,
          expectedLocalUpdatedAt: expectedLocalUpdatedAt,
          minimumServerVersion: minimumServerVersion,
        );
        return true;
      } on MaintenanceIssueCommandConvergenceException {
        return false;
      }
    }

    var converged = await adopt();
    try {
      await ref
          .read(syncCoordinatorProvider)
          .runFullSync(reason: syncReason, force: true);
    } catch (_) {
      // The governed command has already succeeded. Exact point-read adoption
      // above is sufficient; ordinary sync remains available for later retry.
    }
    if (!converged) converged = await adopt();
    return converged;
  }

  Future<void> _manageTicketLanes(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    final plan = ticket.issueLanePlanReadResult.value;
    if (ticketId == null ||
        ticketId.isEmpty ||
        plan == null ||
        _busyTicketId != null) {
      return;
    }
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    final change = await showIssueLaneManagementDialog(context, ticket: ticket);
    if (change == null || !mounted) return;
    setState(() => _busyTicketId = ticketId);
    try {
      final command = WorkflowCommandFactory.create(
        type: WorkflowCommandType.reconfigureMaintenanceTicketLanes,
        aggregateId: ticketId,
        expectedVersion: expectedLocalVersion,
        payload: <String, Object?>{
          'lanes': change.lanes.map((lane) => lane.name).toList(),
          'otherDepartment': change.otherDepartment,
          'reason': change.reason,
        },
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      validateMaintenanceIssueLaneCommandReceipt(
        command: command,
        receipt: receipt,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: receipt.aggregateVersion,
        syncReason: 'maintenance_ticket_lanes_changed',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? 'Accountable lanes updated'
                : 'Lane change accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.success : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not update accountable lanes: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Future<void> _repairTicketFromServer(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty || _busyTicketId != null) return;
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    setState(() => _busyTicketId = ticketId);
    try {
      final refreshed = await ref
          .read(maintenanceIssueCommandReconcilerProvider)
          .refreshServerState(
            firestoreId: ticketId,
            expectedLocalVersion: expectedLocalVersion,
            expectedLocalUpdatedAt: expectedLocalUpdatedAt,
          );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            refreshed.isDeleted
                ? 'This stale issue was removed from the active device list.'
                : 'Issue refreshed from its exact server record',
          ),
          backgroundColor: BafColors.success,
        ),
      );
    } on MaintenanceIssueCommandConvergenceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not repair this issue: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Future<void> _startIssueCoordination(MaintenanceRecord ticket) async {
    final ticketId = ticket.firestoreId?.trim();
    if (ticketId == null || ticketId.isEmpty || _busyTicketId != null) return;
    final expectedLocalVersion = ticket.version;
    final expectedLocalUpdatedAt = ticket.updatedAt.toUtc();
    final appUser = ref.read(currentAppUserProvider).value;
    final plan = ticket.issueLanePlanReadResult.value;
    if (appUser == null || plan == null) return;
    final candidates = plan.acknowledgedLanes
        .where((lane) => !plan.completedLanes.contains(lane))
        .map(RoutedTo.values.byName)
        .where(appUser.canStartIssueCoordination)
        .toList(growable: false);
    final originLane = await _selectIssueLane(
      title: 'Lane requesting Operations',
      lanes: candidates,
    );
    if (originLane == null || !mounted) return;
    final draft = await showIssueCoordinationDialog(context, ticket: ticket);
    if (draft == null || !mounted) return;
    final workflowId = WorkflowCommandFactory.uniqueId('issue_coordination');
    final complianceId = WorkflowCommandFactory.uniqueId('issue_compliance');
    setState(() => _busyTicketId = ticketId);
    try {
      final command = WorkflowCommandFactory.create(
        type: WorkflowCommandType.startIssueCoordination,
        aggregateId: workflowId,
        expectedVersion: 0,
        payload: draft.toCommandPayload(
          ticketId: ticketId,
          expectedTicketVersion: expectedLocalVersion,
          complianceId: complianceId,
          originRoute: originLane.name,
        ),
      );
      final receipt = await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      final ticketVersion = validateMaintenanceIssueCoordinationReceipt(
        command: command,
        receipt: receipt,
      );
      final converged = await _adoptAcceptedIssueCommand(
        ticketId: ticketId,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
        minimumServerVersion: ticketVersion,
        syncReason: 'maintenance_issue_coordination_started',
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            converged
                ? 'Operations coordination started'
                : 'Operations coordination accepted. Exact device refresh is pending and will retry during sync.',
          ),
          backgroundColor: converged ? BafColors.success : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not coordinate this issue: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyTicketId = null);
    }
  }

  Widget _buildEmptyState(AppUser appUser, SyncStatus syncStatus) {
    return _BoundedIssuesContent(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(BafSpacing.lg),
        children: [
          _IssuesHeader(
            count: 0,
            totalCount: 0,
            canSeeAll: appUser.canSeeAllTickets,
            canSeeAssigned: appUser.canSeeAssignedMaintenanceTickets,
            isSyncing: syncStatus == SyncStatus.syncing,
            query: '',
            onQueryChanged: (_) {},
            onRaiseIssue: _openMaintenanceForm,
            onSyncNow: _refreshTickets,
          ),
          const SizedBox(height: BafSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BafSpacing.xl),
            child: Column(
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  size: 38,
                  color: BafColors.success,
                ),
                const SizedBox(height: BafSpacing.md),
                const Text(
                  'All clear',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  appUser.canSeeAllTickets
                      ? 'No active breakdowns on the floor right now.'
                      : appUser.canSeeAssignedMaintenanceTickets
                      ? 'No active issues are assigned to your team or raised by you.'
                      : 'You have no active issues logged right now.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundedIssuesContent extends StatelessWidget {
  final Widget child;

  const _BoundedIssuesContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }
}

class _IssuesHeader extends StatelessWidget {
  final int count;
  final int totalCount;
  final bool canSeeAll;
  final bool canSeeAssigned;
  final bool isSyncing;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onRaiseIssue;
  final Future<void> Function() onSyncNow;

  const _IssuesHeader({
    required this.count,
    required this.totalCount,
    required this.canSeeAll,
    required this.canSeeAssigned,
    required this.isSyncing,
    required this.query,
    required this.onQueryChanged,
    required this.onRaiseIssue,
    required this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BafScreenIntro(
          title: 'Open issues',
          subtitle:
              canSeeAll
                  ? 'Issues needing attention across the floor.'
                  : canSeeAssigned
                  ? 'Issues raised by you or routed to your team.'
                  : 'Issues raised by you and still active.',
          icon: Icons.report_problem_outlined,
          accent: BafColors.maintenance,
          trailing: IconButton.outlined(
            tooltip: isSyncing ? 'Sync in progress' : 'Refresh issues',
            onPressed: isSyncing ? null : () => onSyncNow(),
            icon:
                isSyncing
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: BafSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final search = BafSearchField(
              fieldKey: const ValueKey('issues-search'),
              hintText: 'Search asset, component or description',
              onChanged: onQueryChanged,
            );
            final raise = FilledButton.icon(
              key: const ValueKey('issues-raise-issue'),
              onPressed: onRaiseIssue,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Raise'),
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.maintenance,
                foregroundColor: Colors.white,
                minimumSize: const Size(88, 48),
              ),
            );
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: BafSpacing.sm),
                  Align(alignment: Alignment.centerRight, child: raise),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: BafSpacing.sm),
                raise,
              ],
            );
          },
        ),
        const SizedBox(height: BafSpacing.sm),
        Text(
          query.trim().isEmpty
              ? '$totalCount open'
              : '$count of $totalCount matching',
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NoMatchingIssuesState extends StatelessWidget {
  const _NoMatchingIssuesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: BafSpacing.xl),
      child: Center(
        child: Text(
          'No open issues match this search.',
          style: TextStyle(color: BafColors.textSecondary),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final MaintenanceRecord ticket;
  final VoidCallback onViewDetails;
  final bool canResolve;
  final VoidCallback onResolve;
  final bool canCloseWithoutResolution;
  final VoidCallback onCloseWithoutResolution;
  final bool canAcknowledge;
  final bool isBusy;
  final VoidCallback onAcknowledge;
  final bool canCompleteLane;
  final VoidCallback onCompleteLane;
  final bool canManageLanes;
  final VoidCallback onManageLanes;
  final bool canRepairLaneData;
  final VoidCallback onRepairLaneData;
  final bool canRefreshServer;
  final VoidCallback onRefreshServer;
  final bool canCoordinate;
  final VoidCallback onCoordinate;
  final VoidCallback? onOpenCoordination;
  final VoidCallback? onViewEventLinks;

  const _TicketCard({
    required this.ticket,
    required this.onViewDetails,
    required this.canResolve,
    required this.onResolve,
    required this.canCloseWithoutResolution,
    required this.onCloseWithoutResolution,
    required this.canAcknowledge,
    required this.isBusy,
    required this.onAcknowledge,
    required this.canCompleteLane,
    required this.onCompleteLane,
    required this.canManageLanes,
    required this.onManageLanes,
    required this.canRepairLaneData,
    required this.onRepairLaneData,
    required this.canRefreshServer,
    required this.onRefreshServer,
    required this.canCoordinate,
    required this.onCoordinate,
    required this.onOpenCoordination,
    required this.onViewEventLinks,
  });

  @override
  Widget build(BuildContext context) {
    final deptColor = _agencyColor(ticket.routedTo);
    final elapsed = DateTime.now().difference(ticket.startDate);
    final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    final elapsedText = _formatDuration(safeElapsed);
    final assetLabel =
        '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}';
    final reporter = _firstNonBlank([
      ticket.loggedByName,
      ticket.reportedBy,
      'Unknown',
    ]);
    final component = ticket.component?.trim();
    final innerCover = ticket.assetHierarchyReference?.innerCoverAssociation;
    final burnerLockout = ticket.burnerLockoutReadResult.value;
    final burnerReadings =
        burnerLockout?.resolutionMicroampReadings.entries.toList() ?? [];
    burnerReadings.sort((left, right) => left.key.compareTo(right.key));
    final laneRead = ticket.issueLanePlanReadResult;
    final lanePlan = laneRead.value;
    final secondaryActions = _ticketCardSecondaryActions(
      onViewDetails: onViewDetails,
      canRefreshServer: canRefreshServer,
      onRefreshServer: onRefreshServer,
      onViewEventLinks: onViewEventLinks,
      onOpenCoordination: onOpenCoordination,
      canManageLanes: canManageLanes,
      onManageLanes: onManageLanes,
      canRepairLaneData: canRepairLaneData,
      onRepairLaneData: onRepairLaneData,
    );

    return Material(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.large),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: BafColors.card,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(
              color:
                  ticket.isCritical
                      ? BafColors.danger.withValues(alpha: 0.42)
                      : BafColors.border,
            ),
            boxShadow: BafShadows.subtle,
          ),
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
                      color: deptColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: Icon(
                      Icons.build_rounded,
                      color: deptColor,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assetLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: BafSpacing.xs),
                        Wrap(
                          spacing: BafSpacing.sm,
                          runSpacing: BafSpacing.sm,
                          children: [
                            if (lanePlan != null)
                              for (final laneName in lanePlan.assignedLanes)
                                StatusBadge(
                                  label: _deptLabel(
                                    RoutedTo.values.byName(laneName),
                                  ),
                                  color: _agencyColor(
                                    RoutedTo.values.byName(laneName),
                                  ),
                                  icon:
                                      lanePlan.completedLanes.contains(laneName)
                                          ? Icons.task_alt_rounded
                                          : lanePlan.acknowledgedLanes.contains(
                                            laneName,
                                          )
                                          ? Icons.verified_rounded
                                          : Icons.schedule_rounded,
                                )
                            else
                              const StatusBadge(
                                label: 'LANE DATA ERROR',
                                color: BafColors.danger,
                                icon: Icons.error_outline_rounded,
                              ),
                            if (ticket.isCritical)
                              const StatusBadge(
                                label: 'CRITICAL',
                                color: BafColors.danger,
                                icon: Icons.priority_high_rounded,
                              ),
                            if (!ticket.isSynced)
                              const StatusBadge(
                                label: 'SYNC PENDING',
                                color: BafColors.warning,
                                icon: Icons.cloud_off_rounded,
                              ),
                            if (burnerLockout != null)
                              StatusBadge(
                                label:
                                    'BURNERS ${burnerLockout.positions.join(', ')}',
                                color: BafColors.audit,
                                icon: Icons.local_fire_department_outlined,
                              ),
                            if (burnerLockout?.hasRedHotObservation == true)
                              StatusBadge(
                                label:
                                    'RED HOT ${burnerLockout!.redHotPositions.map((value) => 'B$value').join(', ')}',
                                color: BafColors.danger,
                                icon: Icons.warning_amber_rounded,
                              ),
                            StatusBadge(
                              label:
                                  ticket.status == TicketStatus.acknowledged
                                      ? 'Acknowledged'
                                      : ticket.status == TicketStatus.inProgress
                                      ? 'In progress'
                                      : 'Open $elapsedText',
                              color:
                                  ticket.status == TicketStatus.acknowledged
                                      ? BafColors.warning
                                      : BafColors.maintenance,
                              icon:
                                  ticket.status == TicketStatus.acknowledged
                                      ? Icons.verified_rounded
                                      : Icons.timer_outlined,
                            ),
                            if (ticket.isWorkflowLinked)
                              StatusBadge(
                                label: ticket.workflowStateLabel,
                                color:
                                    ticket.workflowDeferred
                                        ? BafColors.warning
                                        : BafColors.audit,
                                icon:
                                    ticket.workflowDeferred
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.account_tree_outlined,
                              ),
                            if (ticket.operationalEventIssueLinkIds.isNotEmpty)
                              StatusBadge(
                                label:
                                    '${ticket.operationalEventIssueLinkIds.length} EVENT LINK${ticket.operationalEventIssueLinkIds.length == 1 ? '' : 'S'}',
                                color: BafColors.warning,
                                icon: Icons.link_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Issue record and actions',
                    enabled: !isBusy,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (index) => secondaryActions[index].onSelected(),
                    itemBuilder:
                        (_) => [
                          for (
                            var index = 0;
                            index < secondaryActions.length;
                            index++
                          )
                            PopupMenuItem<int>(
                              value: index,
                              child: Row(
                                children: [
                                  Icon(
                                    secondaryActions[index].icon,
                                    size: 20,
                                    color: BafColors.maintenance,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(secondaryActions[index].label),
                                  ),
                                ],
                              ),
                            ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              Text(
                ticket.description,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              _MetaRow(
                icon: Icons.person_outline_rounded,
                text: 'Raised by $reporter',
              ),
              const SizedBox(height: 5),
              _MetaRow(
                icon: Icons.schedule_rounded,
                text:
                    'Logged ${DateFormat('dd MMM, HH:mm').format(ticket.createdAt)}',
              ),
              if (ticket.chargeNoAtEvent != null) ...[
                const SizedBox(height: 5),
                _MetaRow(
                  icon: Icons.confirmation_number_outlined,
                  text: 'Charge ${ticket.chargeNoAtEvent}',
                ),
              ],
              if (component != null && component.isNotEmpty) ...[
                const SizedBox(height: 5),
                _MetaRow(
                  icon: Icons.account_tree_outlined,
                  text: 'Component: $component',
                ),
              ],
              if (burnerLockout != null) ...[
                const SizedBox(height: 5),
                _MetaRow(
                  icon: Icons.settings_input_component_rounded,
                  text:
                      '${burnerLockout.commonMode ? 'Possible common-mode event' : 'Individual burner event'}; '
                      '${burnerLockout.relightAttempts} relight attempt${burnerLockout.relightAttempts == 1 ? '' : 's'}',
                ),
                if (burnerReadings.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _MetaRow(
                    icon: Icons.speed_rounded,
                    text:
                        'Flame signal: ${burnerReadings.map((entry) => 'B${entry.key} ${NumberFormat('0.###').format(entry.value)} µA').join(' · ')}',
                  ),
                ],
              ],
              if (innerCover != null) ...[
                const SizedBox(height: 5),
                _MetaRow(
                  icon: Icons.layers_outlined,
                  text:
                      innerCover.innerCoverSerialNumber == null
                          ? 'At event: no Inner Cover linked'
                          : 'At event: Inner Cover ${innerCover.innerCoverSerialNumber}',
                ),
              ],
              if (ticket.acknowledgedByName?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                _MetaRow(
                  icon: Icons.verified_user_outlined,
                  text: 'First accepted by ${ticket.acknowledgedByName}',
                ),
              ],
              if (ticket.workflowDeferred) ...[
                const SizedBox(height: BafSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    ticket.workflowCorrectionReason?.trim().isNotEmpty == true
                        ? 'Held by workflow: ${ticket.workflowCorrectionReason}'
                        : 'Held by workflow compliance. Reactivate or release the linked request before resolving this ticket.',
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (canAcknowledge) ...[
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onAcknowledge,
                    icon:
                        isBusy
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.verified_rounded, size: 20),
                    label: Text(isBusy ? 'Acknowledging...' : 'Acknowledge'),
                  ),
                ),
              ],
              if (canCompleteLane) ...[
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onCompleteLane,
                    icon: const Icon(Icons.task_alt_rounded, size: 20),
                    label: const Text('Complete accountable lane'),
                  ),
                ),
              ],
              if (canCoordinate) ...[
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onCoordinate,
                    icon:
                        isBusy
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.handshake_outlined, size: 20),
                    label: Text(
                      isBusy
                          ? 'Starting coordination...'
                          : 'Defer / request Operations',
                    ),
                  ),
                ),
              ],
              if (canCloseWithoutResolution) ...[
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onCloseWithoutResolution,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BafColors.warning,
                      side: BorderSide(
                        color: BafColors.warning.withValues(alpha: 0.65),
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 20),
                    label: const Text('Close without resolution'),
                  ),
                ),
              ],
              if (canResolve) ...[
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onResolve,
                    style: FilledButton.styleFrom(
                      backgroundColor: BafColors.sync,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BafRadius.medium),
                      ),
                    ),
                    icon: const Icon(Icons.task_alt_rounded, size: 20),
                    label: const Text(
                      'Resolve issue',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _agencyColor(RoutedTo dept) {
    switch (dept) {
      case RoutedTo.operations:
        return BafColors.sync;
      case RoutedTo.electrical:
        return BafColors.warning;
      case RoutedTo.mechanical:
        return BafColors.planned;
      case RoutedTo.instrumentation:
        return BafColors.audit;
      case RoutedTo.refractory:
        return BafColors.directives;
      case RoutedTo.emd:
        return BafColors.assets;
      case RoutedTo.shiftInCharge:
        return BafColors.charges;
      case RoutedTo.others:
        return BafColors.admin;
    }
  }

  static String _deptLabel(RoutedTo dept) {
    switch (dept) {
      case RoutedTo.instrumentation:
        return 'I&A';
      case RoutedTo.refractory:
        return 'RED';
      case RoutedTo.emd:
        return 'EMD';
      case RoutedTo.shiftInCharge:
        return 'SIC';
      case RoutedTo.others:
        return 'OTHER';
      default:
        return dept.name.toUpperCase();
    }
  }

  static String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) return '$days d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  static String _firstNonBlank(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return 'Unknown';
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _StateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

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
      child: Column(
        children: [
          Icon(icon, size: 62, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
