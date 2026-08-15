// FILE: lib/home_screen.dart

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/maintenance/presentation/ticket_screen.dart';
import 'features/maintenance/presentation/maintenance_form.dart';
import 'features/planned_maintenance/presentation/templates_screen.dart';
import 'features/planned_maintenance/presentation/module_composer_screen.dart';
import 'features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'features/planned_maintenance/presentation/knowledge_governance_screen.dart';
import 'features/planned_maintenance/presentation/closed_job_dossiers_screen.dart';
import 'features/assets/presentation/asset_timeline_screen.dart';
import 'features/assets/presentation/asset_registry_screen.dart';
import 'features/assets/presentation/asset_condition_board.dart';
import 'features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'features/assets/domain/plant_asset_overview.dart';
import 'features/assets/providers/plant_asset_overview_provider.dart';
import 'features/audit/presentation/audit_timeline_screen.dart';
import 'features/admin/presentation/admin_data_browser.dart';
import 'features/admin/presentation/local_diagnostics_screen.dart';
import 'features/directives/presentation/directives_screen.dart';
import 'features/maintenance/presentation/closed_tickets_screen.dart';
import 'features/reports/presentation/fleet_status_screen.dart';
import 'features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'features/quality/presentation/quality_home_screen.dart';
import 'features/quality/data/quality_warning.dart';
import 'features/quality/providers/quality_provider.dart';
import 'features/operational_events/presentation/operational_events_screen.dart';
import 'features/operational_events/providers/operational_event_provider.dart';
import 'features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart';
import 'features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart';
import 'features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'features/maintenance_workflow/presentation/screens/workflow_hub_screen.dart';
import 'features/maintenance_workflow/providers/workflow_providers.dart';

import 'features/auth/data/user_model.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/maintenance/providers/maintenance_provider.dart';
import 'features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'features/directives/providers/operational_directive_provider.dart';

import 'core/theme/baf_design_system.dart';
import 'core/widgets/dashboard/dashboard_widgets.dart';
import 'core/widgets/dashboard/status_badge.dart';
import 'core/providers/sync_status_provider.dart';
import 'core/services/sync_coordinator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<RemoteMessage>? _notificationTapSubscription;
  bool _initialNotificationHandled = false;

  @override
  void initState() {
    super.initState();
    _notificationTapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openInitialNotification());
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openInitialNotification() async {
    if (_initialNotificationHandled) return;
    _initialNotificationHandled = true;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _handleNotificationTap(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final workflowId = message.data['aggregateId']?.trim();
    if (!mounted || workflowId == null || workflowId.isEmpty) return;
    final laneKey = message.data['laneKey']?.trim();
    final sourceCollection = message.data['sourceCollection']?.trim();
    final complianceId = message.data['complianceId']?.trim();
    final destinationType = message.data['destinationType']?.trim();
    final Widget destination;
    if (destinationType == 'equipment') {
      destination = const EquipmentStatusBoard();
    } else if (sourceCollection == 'compliance_requests' &&
        complianceId != null &&
        complianceId.isNotEmpty) {
      destination = ComplianceNotificationScreen(
        complianceId: complianceId,
        laneKey: laneKey,
      );
    } else if (sourceCollection == 'compliance_requests') {
      destination = ComplianceInboxScreen(laneKey: laneKey);
    } else {
      destination = WorkflowHubScreen(initialWorkflowId: workflowId);
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return appUserAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('User error: $e'))),
      data: (appUser) {
        if (appUser == null) {
          return const Scaffold(body: Center(child: Text('No user found')));
        }

        final ticketCountAsync = ref.watch(
          visibleOpenTicketCountProvider(appUser),
        );
        final executionCountAsync =
            appUser.canViewPlannedMaintenance
                ? ref.watch(openExecutionCountProvider)
                : null;
        final directiveCountAsync = ref.watch(
          visibleOpenDirectiveCountProvider(appUser),
        );
        final workflowLanesAsync =
            appUser.canViewPlannedMaintenance
                ? ref.watch(workflowAllLanesProvider)
                : null;
        final workflowComplianceAsync =
            appUser.canViewPlannedMaintenance
                ? ref.watch(workflowAllComplianceProvider)
                : null;
        final plantOverviewAsync = ref.watch(plantAssetOverviewProvider);
        final operationalEventsAsync = ref.watch(operationalEventsProvider);
        final qualityWarningsAsync = ref.watch(qualityWarningsProvider);

        final ticketCount = ticketCountAsync.value ?? 0;
        final executionCount = executionCountAsync?.value ?? 0;
        final directiveCount = directiveCountAsync.value ?? 0;
        final pendingLaneAcknowledgements =
            workflowLanesAsync?.value
                ?.where(
                  (lane) =>
                      lane.statusKey == 'pending' &&
                      appUser.canAcknowledgeOrWorkMaintenanceLane(lane.laneKey),
                )
                .length ??
            0;
        final dueCompliance =
            workflowComplianceAsync?.value
                ?.where(
                  (request) =>
                      request.becameDueAt != null &&
                      request.statusKey != 'confirmedClosed' &&
                      request.statusKey != 'superseded' &&
                      request.statusKey != 'cancelled' &&
                      appUser.canAcknowledgeOrWorkMaintenanceLane(
                        request.targetLaneKey,
                      ),
                )
                .length ??
            0;
        final workflowAttentionCount =
            pendingLaneAcknowledgements + dueCompliance;
        final openOperationalEventCount =
            operationalEventsAsync.value
                ?.where((event) => event.isOpen)
                .length ??
            0;
        final openQualityWarningCount =
            qualityWarningsAsync.value
                ?.where(
                  (warning) => warning.status != QualityWarningStatus.closed,
                )
                .length ??
            0;
        final attentionDataUnavailable =
            ticketCountAsync.value == null ||
            directiveCountAsync.value == null ||
            (executionCountAsync != null &&
                executionCountAsync.value == null) ||
            (workflowLanesAsync != null && workflowLanesAsync.value == null) ||
            (workflowComplianceAsync != null &&
                workflowComplianceAsync.value == null) ||
            operationalEventsAsync.value == null ||
            qualityWarningsAsync.value == null;

        final tabs = _buildTabs(
          appUser: appUser,
          ticketCount: ticketCount,
          executionCount: executionCount,
          directiveCount: directiveCount,
          workflowAttentionCount: workflowAttentionCount,
          openOperationalEventCount: openOperationalEventCount,
          openQualityWarningCount: openQualityWarningCount,
          attentionDataUnavailable: attentionDataUnavailable,
          plantOverview: plantOverviewAsync,
        );

        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final body = _LazyIndexedStack(
              index: safeIndex,
              itemCount: tabs.length,
              itemBuilder: (context, index) => tabs[index].buildScreen(context),
            );
            final useRail = constraints.maxWidth >= 900;

            if (useRail) {
              return Scaffold(
                backgroundColor: BafColors.background,
                body: Row(
                  children: [
                    SafeArea(
                      child: NavigationRail(
                        selectedIndex: safeIndex,
                        extended: constraints.maxWidth >= 1200,
                        minExtendedWidth: 210,
                        backgroundColor: BafColors.card,
                        indicatorColor: BafColors.navySoft.withValues(
                          alpha: 0.12,
                        ),
                        onDestinationSelected:
                            (index) => setState(() => _currentIndex = index),
                        labelType:
                            constraints.maxWidth >= 1200
                                ? NavigationRailLabelType.none
                                : NavigationRailLabelType.all,
                        destinations: tabs
                            .map(
                              (tab) => NavigationRailDestination(
                                icon: tab.destination.icon,
                                selectedIcon:
                                    tab.destination.selectedIcon ??
                                    tab.destination.icon,
                                label: Text(tab.label),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            }

            return Scaffold(
              backgroundColor: BafColors.background,
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: safeIndex,
                onDestinationSelected:
                    (index) => setState(() => _currentIndex = index),
                backgroundColor: BafColors.card,
                indicatorColor: BafColors.navySoft.withValues(alpha: 0.12),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: tabs.map((t) => t.destination).toList(),
              ),
            );
          },
        );
      },
    );
  }

  List<_AppTab> _buildTabs({
    required AppUser appUser,
    required int ticketCount,
    required int executionCount,
    required int directiveCount,
    required int workflowAttentionCount,
    required int openOperationalEventCount,
    required int openQualityWarningCount,
    required bool attentionDataUnavailable,
    required AsyncValue<PlantAssetOverview> plantOverview,
  }) {
    return [
      _AppTab(
        label: 'Home',
        screenBuilder:
            (_) => _DashboardHome(
              appUser: appUser,
              ticketCount: ticketCount,
              executionCount: executionCount,
              directiveCount: directiveCount,
              workflowAttentionCount: workflowAttentionCount,
              openOperationalEventCount: openOperationalEventCount,
              openQualityWarningCount: openQualityWarningCount,
              attentionDataUnavailable: attentionDataUnavailable,
              plantOverview: plantOverview,
              onProfileTap: () => _showProfileSheet(context, ref, appUser),
              onRaiseIssue: () => _openMaintenanceForm(context),
              onIssues: () => setState(() => _currentIndex = 1),
              onWork: () => setState(() => _currentIndex = 2),
              onDirectives: () => setState(() => _currentIndex = 3),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onQuality: () => _push(context, const QualityHomeScreen()),
              onOperationalEvents:
                  () => _push(context, const OperationalEventsScreen()),
              onPlantCondition:
                  () => _push(context, const AssetConditionBoard()),
              onManualSync: () => _retryAttentionData(context, appUser),
            ),
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
      ),
      _AppTab(
        label: 'Issues',
        screenBuilder: (_) => const TicketScreen(),
        destination: NavigationDestination(
          icon: Badge(
            isLabelVisible: ticketCount > 0,
            label: Text('$ticketCount'),
            child: const Icon(Icons.report_problem_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: ticketCount > 0,
            label: Text('$ticketCount'),
            child: const Icon(Icons.report_problem_rounded),
          ),
          label: 'Issues',
        ),
      ),
      _AppTab(
        label: 'Work',
        screenBuilder:
            (_) =>
                appUser.canViewPlannedMaintenance
                    ? const TemplatesScreen()
                    : const _AccessLimitedScreen(
                      title: 'Planned Work',
                      message:
                          'Planned maintenance jobs are available to supervisors and authorized teams.',
                    ),
        destination: NavigationDestination(
          icon: Badge(
            isLabelVisible: executionCount + workflowAttentionCount > 0,
            label: Text('${executionCount + workflowAttentionCount}'),
            child: const Icon(Icons.work_outline_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: executionCount + workflowAttentionCount > 0,
            label: Text('${executionCount + workflowAttentionCount}'),
            child: const Icon(Icons.work_rounded),
          ),
          label: 'Work',
        ),
      ),
      _AppTab(
        label: 'Directives',
        screenBuilder: (_) => const DirectivesScreen(),
        destination: NavigationDestination(
          icon: Badge(
            isLabelVisible: directiveCount > 0,
            label: Text('$directiveCount'),
            child: const Icon(Icons.assignment_late_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: directiveCount > 0,
            label: Text('$directiveCount'),
            child: const Icon(Icons.assignment_late_rounded),
          ),
          label: 'Directives',
        ),
      ),
      _AppTab(
        label: 'More',
        screenBuilder:
            (_) => _MoreScreen(
              appUser: appUser,
              onAssetRegistry:
                  () => _push(context, const AssetRegistryScreen()),
              onAssets: () => _push(context, const AssetTimelineScreen()),
              onInnerCovers:
                  () => _push(context, const InnerCoverLifecycleScreen()),
              onClosed: () => _push(context, const ClosedTicketsScreen()),
              onClosedJobs:
                  () => _push(context, const ClosedJobDossiersScreen()),
              onReports: () => _push(context, const FleetStatusScreen()),
              onAdmin: () => _push(context, const AdminDataBrowser()),
              onAuditLog: () => _push(context, const RecentAuditLogScreen()),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onQuality: () => _push(context, const QualityHomeScreen()),
              onOperationalEvents:
                  () => _push(context, const OperationalEventsScreen()),
              onTemplateAuthoring: () => _openModuleComposer(context, appUser),
              onTemplatePublisher:
                  () => _push(context, const TemplatePublisherScreen()),
              onKnowledgeGovernance:
                  () => _push(context, const KnowledgeGovernanceScreen()),
              onLocalDiagnostics:
                  () => _push(context, const LocalDiagnosticsScreen()),
            ),
        destination: const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          selectedIcon: Icon(Icons.more_horiz_rounded),
          label: 'More',
        ),
      ),
    ];
  }

  void _openMaintenanceForm(BuildContext context) {
    _push(context, const MaintenanceForm());
  }

  void _openModuleComposer(BuildContext context, AppUser appUser) {
    // Empty initial payloads land the composer on a fresh draft. The
    // composer's draft-recovery path (_checkForRecoverableDraft) still
    // runs and will surface any recoverable in-progress draft for this
    // user. The legacy Template Publisher remains on its own More tile
    // for power users (Admin and SI) who need the JSON-paste/edit
    // surface — see _MoreScreen below. Home launches the composer as
    // a standalone authoring route, so the legacy Save-to-Publisher
    // handoff is hidden here.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ModuleComposerScreen(
              initialJobTemplateJson: '{}',
              initialModuleSnapshotsJson: '[]',
              initialFieldDefinitionsJson: '[]',
              initialChecklistJson: '[]',
              canSeedCloudKnowledge: appUser.canManageTemplateGovernance,
              showSaveToPublisher: false,
            ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _retryAttentionData(BuildContext context, AppUser appUser) {
    ref.invalidate(visibleOpenTicketCountProvider(appUser));
    ref.invalidate(visibleOpenDirectiveCountProvider(appUser));
    if (appUser.canViewPlannedMaintenance) {
      ref.invalidate(openExecutionCountProvider);
      ref.invalidate(workflowAllLanesProvider);
      ref.invalidate(workflowAllComplianceProvider);
    }
    ref.invalidate(operationalEventsProvider);
    ref.invalidate(qualityWarningsProvider);
    unawaited(_runManualSync(context));
  }

  Future<void> _runManualSync(BuildContext context) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.isApproved) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final outcome = await ref
          .read(syncCoordinatorProvider)
          .runFullSyncWithResult(reason: 'manual_home', force: true);

      if (!mounted) return;

      messenger?.showSnackBar(
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
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Manual sync failed: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref, AppUser appUser) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BafSpacing.xl,
                      BafSpacing.sm,
                      BafSpacing.xl,
                      BafSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _UserAvatar(appUser: appUser),
                            const SizedBox(width: BafSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appUser.name,
                                    style: const TextStyle(
                                      color: BafColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: BafSpacing.xs),
                                  Text(
                                    appUser.email,
                                    style: const TextStyle(
                                      color: BafColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        Wrap(
                          spacing: BafSpacing.sm,
                          runSpacing: BafSpacing.sm,
                          children:
                              appUser.roles.map<Widget>((r) {
                                final roleName =
                                    r.toString().split('.').last.toUpperCase();

                                return Chip(
                                  label: Text(
                                    roleName,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  backgroundColor: BafColors.navySoft,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: BafSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref.read(authServiceProvider).signOut();
                            },
                            icon: const Icon(
                              Icons.logout,
                              color: BafColors.danger,
                            ),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(color: BafColors.danger),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: BafColors.danger),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  BafRadius.medium,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  final AppUser appUser;
  final int ticketCount;
  final int executionCount;
  final int directiveCount;
  final int workflowAttentionCount;
  final int openOperationalEventCount;
  final int openQualityWarningCount;
  final bool attentionDataUnavailable;
  final AsyncValue<PlantAssetOverview> plantOverview;
  final VoidCallback onProfileTap;
  final VoidCallback onRaiseIssue;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onDirectives;
  final VoidCallback onAbnormalities;
  final VoidCallback onQuality;
  final VoidCallback onOperationalEvents;
  final VoidCallback onPlantCondition;
  final VoidCallback onManualSync;

  const _DashboardHome({
    required this.appUser,
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.openOperationalEventCount,
    required this.openQualityWarningCount,
    required this.attentionDataUnavailable,
    required this.plantOverview,
    required this.onProfileTap,
    required this.onRaiseIssue,
    required this.onIssues,
    required this.onWork,
    required this.onDirectives,
    required this.onAbnormalities,
    required this.onQuality,
    required this.onOperationalEvents,
    required this.onPlantCondition,
    required this.onManualSync,
  });

  @override
  Widget build(BuildContext context) {
    final totalAttention =
        ticketCount +
        executionCount +
        directiveCount +
        workflowAttentionCount +
        openOperationalEventCount +
        openQualityWarningCount;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.md,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            children: [
              DashboardHeader(
                userName: appUser.name,
                avatar: _UserAvatar(appUser: appUser),
                syncIndicator: _CompactSyncPill(onManualSync: onManualSync),
                onProfileTap: onProfileTap,
              ),
              const SizedBox(height: BafSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('home-raise-issue'),
                      onPressed: onRaiseIssue,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Raise issue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.maintenance,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  IconButton.outlined(
                    tooltip: 'Open abnormalities',
                    onPressed: onAbnormalities,
                    icon: const Icon(Icons.memory_outlined),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.xl),
              PlantOverviewPanel(
                overview: plantOverview,
                onOpen: onPlantCondition,
              ),
              const SizedBox(height: BafSpacing.xl),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Needs attention',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label:
                        attentionDataUnavailable
                            ? 'Incomplete'
                            : totalAttention == 0
                            ? 'All clear'
                            : '$totalAttention',
                    color:
                        attentionDataUnavailable
                            ? BafColors.danger
                            : totalAttention == 0
                            ? BafColors.success
                            : BafColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              _AttentionPanel(
                ticketCount: ticketCount,
                executionCount: executionCount,
                directiveCount: directiveCount,
                workflowAttentionCount: workflowAttentionCount,
                openOperationalEventCount: openOperationalEventCount,
                openQualityWarningCount: openQualityWarningCount,
                attentionDataUnavailable: attentionDataUnavailable,
                onIssues: onIssues,
                onWork: onWork,
                onDirectives: onDirectives,
                onOperationalEvents: onOperationalEvents,
                onQuality: onQuality,
                onRetry: onManualSync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  final AppUser appUser;
  final VoidCallback onAssetRegistry;
  final VoidCallback onAssets;
  final VoidCallback onInnerCovers;
  final VoidCallback onClosed;
  final VoidCallback onClosedJobs;
  final VoidCallback onReports;
  final VoidCallback onAdmin;
  final VoidCallback onAuditLog;
  final VoidCallback onAbnormalities;
  final VoidCallback onQuality;
  final VoidCallback onOperationalEvents;
  final VoidCallback onTemplateAuthoring;
  final VoidCallback onTemplatePublisher;
  final VoidCallback onKnowledgeGovernance;
  final VoidCallback onLocalDiagnostics;

  const _MoreScreen({
    required this.appUser,
    required this.onAssetRegistry,
    required this.onAssets,
    required this.onInnerCovers,
    required this.onClosed,
    required this.onClosedJobs,
    required this.onReports,
    required this.onAdmin,
    required this.onAuditLog,
    required this.onAbnormalities,
    required this.onQuality,
    required this.onOperationalEvents,
    required this.onTemplateAuthoring,
    required this.onTemplatePublisher,
    required this.onKnowledgeGovernance,
    required this.onLocalDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final canSeeOperationalData = appUser.canViewOperationalAssets;
    final canSeeClosed = appUser.canViewClosedMaintenanceTickets;
    final canSeeClosedJobs = appUser.canViewClosedJobDossiers;
    final canSeeReports = appUser.canViewReports;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            children: [
              const Text(
                'More',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              const Text(
                'Records, reporting and governed administration.',
                style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: BafSpacing.xl),
              _MoreSection(
                title: 'Operations and records',
                children: [
                  if (canSeeOperationalData)
                    _MoreDestinationTile(
                      icon: Icons.precision_manufacturing_outlined,
                      color: BafColors.assets,
                      title: 'Asset registry',
                      subtitle:
                          'Current equipment, components and lifecycle state',
                      onTap: onAssetRegistry,
                    ),
                  if (canSeeOperationalData)
                    _MoreDestinationTile(
                      icon: Icons.timeline_rounded,
                      color: BafColors.audit,
                      title: 'Asset timeline',
                      subtitle: 'Maintenance and planned-work history',
                      onTap: onAssets,
                    ),
                  if (canSeeOperationalData)
                    _MoreDestinationTile(
                      icon: Icons.layers_outlined,
                      color: BafColors.maintenance,
                      title: 'Inner Covers',
                      subtitle:
                          'Base pairing, spare pool and fabrication history',
                      onTap: onInnerCovers,
                    ),
                  _MoreDestinationTile(
                    icon: Icons.memory_outlined,
                    color: BafColors.charges,
                    title: 'Abnormalities',
                    subtitle: 'Charge events, RA traceability and root causes',
                    onTap: onAbnormalities,
                  ),
                  if (appUser.canViewQuality)
                    _MoreDestinationTile(
                      icon: Icons.verified_user_outlined,
                      color: BafColors.warning,
                      title: 'Quality',
                      subtitle: 'Warnings, closure assurance and monitoring',
                      onTap: onQuality,
                    ),
                  _MoreDestinationTile(
                    icon: Icons.crisis_alert_outlined,
                    color: BafColors.warning,
                    title: 'Operational events',
                    subtitle:
                        'Utilities, cranes, transfer cars and plant delays',
                    onTap: onOperationalEvents,
                  ),
                  if (canSeeClosed)
                    _MoreDestinationTile(
                      icon: Icons.history_rounded,
                      color: BafColors.audit,
                      title: 'Resolved issues',
                      subtitle: 'Closed maintenance issues and reopen history',
                      onTap: onClosed,
                    ),
                  if (canSeeClosedJobs)
                    _MoreDestinationTile(
                      icon: Icons.inventory_2_outlined,
                      color: BafColors.planned,
                      title: 'Closed job dossiers',
                      subtitle:
                          'Recent completed and cancelled planned-job records',
                      onTap: onClosedJobs,
                    ),
                  if (canSeeReports)
                    _MoreDestinationTile(
                      icon: Icons.bar_chart_rounded,
                      color: BafColors.planned,
                      title: 'Reports',
                      subtitle: 'Fleet status and operational summaries',
                      onTap: onReports,
                    ),
                ],
              ),
              if (appUser.canManageTemplateGovernance) ...[
                const SizedBox(height: BafSpacing.xl),
                _MoreSection(
                  title: 'Governance',
                  children: [
                    _MoreDestinationTile(
                      icon: Icons.architecture_outlined,
                      color: BafColors.planned,
                      title: 'Template authoring',
                      subtitle: 'Build modules and governed template versions',
                      onTap: onTemplateAuthoring,
                    ),
                    _MoreDestinationTile(
                      icon: Icons.data_object_rounded,
                      color: BafColors.textSecondary,
                      title: 'Legacy template publisher',
                      subtitle: 'Import or inspect historical snapshot JSON',
                      badge: 'Legacy',
                      onTap: onTemplatePublisher,
                    ),
                    _MoreDestinationTile(
                      icon: Icons.schema_outlined,
                      color: BafColors.audit,
                      title: 'Knowledge governance',
                      subtitle: 'BAF knowledge rows, tags and matrix versions',
                      onTap: onKnowledgeGovernance,
                    ),
                  ],
                ),
              ],
              if (appUser.canOpenAdminDataBrowser ||
                  appUser.canViewAuditLogs ||
                  appUser.canViewMaintenanceWorkflowDiagnostics) ...[
                const SizedBox(height: BafSpacing.xl),
                _MoreSection(
                  title: 'Administration and support',
                  children: [
                    if (appUser.canOpenAdminDataBrowser)
                      _MoreDestinationTile(
                        icon: Icons.admin_panel_settings_outlined,
                        color: BafColors.admin,
                        title: 'Administration',
                        subtitle: 'Users, roles and governed data controls',
                        onTap: onAdmin,
                      ),
                    if (appUser.canViewAuditLogs)
                      _MoreDestinationTile(
                        icon: Icons.fact_check_outlined,
                        color: BafColors.audit,
                        title: 'Audit log',
                        subtitle: 'Recent governed changes and evidence',
                        onTap: onAuditLog,
                      ),
                    if (appUser.canViewMaintenanceWorkflowDiagnostics)
                      _MoreDestinationTile(
                        icon: Icons.troubleshoot_outlined,
                        color: BafColors.admin,
                        title: 'Support diagnostics',
                        subtitle:
                            'Sync inventory, runtime context and recovery',
                        onTap: onLocalDiagnostics,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  final int ticketCount;
  final int executionCount;
  final int directiveCount;
  final int workflowAttentionCount;
  final int openOperationalEventCount;
  final int openQualityWarningCount;
  final bool attentionDataUnavailable;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onDirectives;
  final VoidCallback onOperationalEvents;
  final VoidCallback onQuality;
  final VoidCallback onRetry;

  const _AttentionPanel({
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.openOperationalEventCount,
    required this.openQualityWarningCount,
    required this.attentionDataUnavailable,
    required this.onIssues,
    required this.onWork,
    required this.onDirectives,
    required this.onOperationalEvents,
    required this.onQuality,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (attentionDataUnavailable)
        _AttentionRow(
          icon: Icons.sync_problem_outlined,
          color: BafColors.danger,
          title: 'Live attention data unavailable',
          detail: 'Some work counts could not be loaded. Tap to retry sync.',
          onTap: onRetry,
        ),
      if (ticketCount > 0)
        _AttentionRow(
          icon: Icons.report_problem_outlined,
          color: BafColors.maintenance,
          title: 'Open issues',
          detail: '$ticketCount requiring attention',
          onTap: onIssues,
        ),
      if (executionCount > 0)
        _AttentionRow(
          icon: Icons.work_outline_rounded,
          color: BafColors.planned,
          title: 'Open planned jobs',
          detail: '$executionCount active',
          onTap: onWork,
        ),
      if (workflowAttentionCount > 0)
        _AttentionRow(
          icon: Icons.account_tree_outlined,
          color: BafColors.warning,
          title: 'Workflow obligations',
          detail: '$workflowAttentionCount lane or compliance tasks',
          onTap: onWork,
        ),
      if (directiveCount > 0)
        _AttentionRow(
          icon: Icons.assignment_late_outlined,
          color: BafColors.directives,
          title: 'Active directives',
          detail: '$directiveCount visible to your role',
          onTap: onDirectives,
        ),
      if (openOperationalEventCount > 0)
        _AttentionRow(
          icon: Icons.crisis_alert_outlined,
          color: BafColors.warning,
          title: 'Operational disruptions',
          detail: '$openOperationalEventCount currently open',
          onTap: onOperationalEvents,
        ),
      if (openQualityWarningCount > 0)
        _AttentionRow(
          icon: Icons.verified_user_outlined,
          color: BafColors.danger,
          title: 'Quality warnings',
          detail: '$openQualityWarningCount awaiting disposition',
          onTap: onQuality,
        ),
    ];

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: BafSpacing.xl),
        child: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: BafColors.success),
            SizedBox(width: BafSpacing.md),
            Expanded(
              child: Text(
                'No open work currently requires your attention.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List<Widget>.generate(rows.length * 2 - 1, (index) {
        return index.isEven
            ? rows[index ~/ 2]
            : const Divider(height: 1, color: BafColors.border);
      }),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _MoreSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MoreSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        ...List<Widget>.generate(children.length * 2 - 1, (index) {
          return index.isEven
              ? children[index ~/ 2]
              : const Divider(height: 1, color: BafColors.border);
        }),
      ],
    );
  }
}

class _MoreDestinationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MoreDestinationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: BafSpacing.xs),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(BafRadius.medium),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing:
          badge == null
              ? const Icon(Icons.chevron_right_rounded)
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(label: badge!, color: BafColors.textSecondary),
                  const SizedBox(width: BafSpacing.xs),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
      onTap: onTap,
    );
  }
}

class _CompactSyncPill extends ConsumerWidget {
  final VoidCallback onManualSync;

  const _CompactSyncPill({required this.onManualSync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    late final String label;
    late final Color color;
    late final IconData icon;

    switch (status) {
      case SyncStatus.syncing:
        label = 'Syncing';
        color = BafColors.warning;
        icon = Icons.sync_rounded;
        break;
      case SyncStatus.success:
        label = 'Sync now';
        color = BafColors.sync;
        icon = Icons.cloud_done_rounded;
        break;
      case SyncStatus.failed:
        label = 'Retry sync';
        color = BafColors.danger;
        icon = Icons.error_outline_rounded;
        break;
      case SyncStatus.idle:
        label = 'Sync now';
        color = BafColors.sync;
        icon = Icons.cloud_upload_outlined;
        break;
    }

    final disabled = status == SyncStatus.syncing;

    return Tooltip(
      message: disabled ? 'Sync already running' : 'Manual sync now',
      child: InkWell(
        onTap: disabled ? null : onManualSync,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: StatusBadge(label: label, color: color, icon: icon),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final AppUser appUser;

  const _UserAvatar({required this.appUser});

  @override
  Widget build(BuildContext context) {
    final photoUrl = appUser.photoUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final fallback =
        appUser.name.isNotEmpty ? appUser.name[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 18,
      backgroundColor: BafColors.navySoft.withValues(alpha: 0.10),
      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
      child:
          hasPhoto
              ? null
              : Text(
                fallback,
                style: const TextStyle(
                  color: BafColors.navySoft,
                  fontWeight: FontWeight.w900,
                ),
              ),
    );
  }
}

class _AccessLimitedScreen extends StatelessWidget {
  final String title;
  final String message;

  const _AccessLimitedScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(BafSpacing.xl),
            child: DashboardCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: BafColors.textSecondary,
                  ),
                  const SizedBox(height: BafSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 20,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTab {
  final String label;
  final WidgetBuilder screenBuilder;
  final NavigationDestination destination;

  const _AppTab({
    required this.label,
    required this.screenBuilder,
    required this.destination,
  });

  Widget buildScreen(BuildContext context) => screenBuilder(context);
}

class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _LazyIndexedStack({
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  final Set<int> _visitedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _rememberCurrentIndex();
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visitedIndexes.removeWhere((index) => index >= widget.itemCount);
    _rememberCurrentIndex();
  }

  void _rememberCurrentIndex() {
    if (widget.itemCount <= 0) return;
    final safeIndex = widget.index.clamp(0, widget.itemCount - 1);
    _visitedIndexes.add(safeIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) {
      return const SizedBox.shrink();
    }

    final safeIndex = widget.index.clamp(0, widget.itemCount - 1);

    return IndexedStack(
      index: safeIndex,
      children: List<Widget>.generate(widget.itemCount, (index) {
        if (!_visitedIndexes.contains(index)) {
          return const SizedBox.shrink();
        }

        return TickerMode(
          enabled: index == safeIndex,
          child: KeyedSubtree(
            key: PageStorageKey<String>('home_tab_$index'),
            child: widget.itemBuilder(context, index),
          ),
        );
      }),
    );
  }
}
