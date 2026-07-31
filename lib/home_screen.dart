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
import 'features/assets/presentation/asset_timeline_screen.dart';
import 'features/admin/presentation/admin_data_browser.dart';
import 'features/admin/presentation/local_diagnostics_screen.dart';
import 'features/directives/presentation/directives_screen.dart';
import 'features/maintenance/presentation/closed_tickets_screen.dart';
import 'features/reports/presentation/fleet_status_screen.dart';
import 'features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart';
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

  /// Null means: derive the initial mode from the user's role.
  /// Once the user manually switches, preserve their runtime choice.
  bool? _attendMode;

  @override
  void initState() {
    super.initState();
    _notificationTapSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
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
    final destinationType = message.data['destinationType']?.trim();
    final Widget destination;
    if (destinationType == 'equipment') {
      destination = const EquipmentStatusBoard();
    } else if (sourceCollection == 'compliance_requests' &&
        laneKey != null &&
        laneKey.isNotEmpty) {
      destination = ComplianceInboxScreen(laneKey: laneKey);
    } else {
      destination = WorkflowHubScreen(initialWorkflowId: workflowId);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
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
        final workflowLanesAsync = appUser.canViewPlannedMaintenance
            ? ref.watch(workflowAllLanesProvider)
            : null;
        final workflowComplianceAsync = appUser.canViewPlannedMaintenance
            ? ref.watch(workflowAllComplianceProvider)
            : null;

        final ticketCount = ticketCountAsync.value ?? 0;
        final executionCount = executionCountAsync?.value ?? 0;
        final directiveCount = directiveCountAsync.value ?? 0;
        final pendingLaneAcknowledgements =
            workflowLanesAsync?.value
                    ?.where(
                      (lane) =>
                          lane.statusKey == 'pending' &&
                          appUser.canAcknowledgeOrWorkMaintenanceLane(
                            lane.laneKey,
                          ),
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

        final attendMode = _attendMode ?? _defaultAttendMode(appUser);

        final tabs = _buildTabs(
          appUser: appUser,
          ticketCount: ticketCount,
          executionCount: executionCount,
          directiveCount: directiveCount,
          workflowAttentionCount: workflowAttentionCount,
          attendMode: attendMode,
        );

        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return Scaffold(
          backgroundColor: BafColors.background,
          body: _LazyIndexedStack(
            index: safeIndex,
            itemCount: tabs.length,
            itemBuilder: (context, index) => tabs[index].buildScreen(context),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: BafColors.card,
            indicatorColor: BafColors.navySoft.withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: tabs.map((t) => t.destination).toList(),
          ),
        );
      },
    );
  }

  bool _defaultAttendMode(AppUser appUser) {
    return appUser.canCloseAnyTicket || appUser.canSeeAllTickets;
  }

  List<_AppTab> _buildTabs({
    required AppUser appUser,
    required int ticketCount,
    required int executionCount,
    required int directiveCount,
    required int workflowAttentionCount,
    required bool attendMode,
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
              attendMode: attendMode,
              onAttendModeChanged: (value) {
                setState(() => _attendMode = value);
              },
              onProfileTap: () => _showProfileSheet(context, ref, appUser),
              onRaiseIssue: () => _openMaintenanceForm(context),
              onIssues: () => setState(() => _currentIndex = 1),
              onWork: () => setState(() => _currentIndex = 2),
              onDirectives: () => setState(() => _currentIndex = 3),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onMore: () => setState(() => _currentIndex = 4),
              onManualSync: () => _runManualSync(context),
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
            isLabelVisible: executionCount > 0,
            label: Text('$executionCount'),
            child: const Icon(Icons.work_outline_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: executionCount > 0,
            label: Text('$executionCount'),
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
              workflowAttentionCount: workflowAttentionCount,
              onAssets: () => _push(context, const AssetTimelineScreen()),
              onClosed: () => _push(context, const ClosedTicketsScreen()),
              onReports: () => _push(context, const FleetStatusScreen()),
              onAdmin: () => _push(context, const AdminDataBrowser()),
              onRaiseIssue: () => _openMaintenanceForm(context),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onTemplateAuthoring: () => _openModuleComposer(context, appUser),
              onTemplatePublisher:
                  () => _push(context, const TemplatePublisherScreen()),
              onKnowledgeGovernance:
                  () => _push(context, const KnowledgeGovernanceScreen()),
              onLocalDiagnostics:
                  () => _push(context, const LocalDiagnosticsScreen()),
              onMaintenanceWorkflow:
                  () => _push(context, const WorkflowHubScreen()),
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
              actorUid: appUser.uid,
              actorName: appUser.name,
              canSeedCloudKnowledge: appUser.canManageTemplateGovernance,
              showSaveToPublisher: false,
            ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
  final bool attendMode;
  final ValueChanged<bool> onAttendModeChanged;
  final VoidCallback onProfileTap;
  final VoidCallback onRaiseIssue;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onDirectives;
  final VoidCallback onAbnormalities;
  final VoidCallback onMore;
  final VoidCallback onManualSync;

  const _DashboardHome({
    required this.appUser,
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.attendMode,
    required this.onAttendModeChanged,
    required this.onProfileTap,
    required this.onRaiseIssue,
    required this.onIssues,
    required this.onWork,
    required this.onDirectives,
    required this.onAbnormalities,
    required this.onMore,
    required this.onManualSync,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.md,
              BafSpacing.lg,
              BafSpacing.lg,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                DashboardHeader(
                  userName: appUser.name,
                  avatar: _UserAvatar(appUser: appUser),
                  syncIndicator: _CompactSyncPill(onManualSync: onManualSync),
                  onProfileTap: onProfileTap,
                ),
                const SizedBox(height: BafSpacing.lg),
                ModeSwitchCard(
                  attendMode: attendMode,
                  onChanged: onAttendModeChanged,
                ),
                const SizedBox(height: BafSpacing.lg),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child:
                      attendMode
                          ? AttendingTeamCard(
                            key: const ValueKey('attend'),
                            assignedCount: ticketCount,
                            openTicketCount: ticketCount,
                            plannedJobCount: executionCount,
                            onAssigned: onIssues,
                            onOpenTickets: onIssues,
                            onPlannedJobs: onWork,
                          )
                          : IssueRaiserCard(
                            key: const ValueKey('raise'),
                            onRaiseIssue: onRaiseIssue,
                            onTrackIssues: onIssues,
                            onRecentReports: onIssues,
                          ),
                ),
                const SizedBox(height: BafSpacing.lg),
                const _SectionTitle(
                  title: 'Core modules',
                  subtitle: 'Everything needed from report to resolution',
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 1,
                  module: BafModules.maintenance,
                  status: 'Open $ticketCount',
                  statusColor: BafColors.maintenance,
                  onTap: onIssues,
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 2,
                  module: BafModules.planned,
                  status:
                      appUser.canViewPlannedMaintenance
                          ? 'Due $executionCount'
                          : 'Limited',
                  statusColor: BafColors.planned,
                  onTap: onWork,
                  enabled: appUser.canViewPlannedMaintenance,
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 3,
                  module: BafModules.directives,
                  status: 'New $directiveCount',
                  statusColor: BafColors.directives,
                  onTap: onDirectives,
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 4,
                  module: const ModuleVisual(
                    title: 'Abnormalities',
                    description:
                        'Charge events, RA traceability and root cause memory',
                    icon: Icons.memory_rounded,
                    color: BafColors.charges,
                  ),
                  status: 'Charge log',
                  statusColor: BafColors.charges,
                  onTap: onAbnormalities,
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 5,
                  module: BafModules.audit,
                  status: 'Traceable',
                  statusColor: BafColors.audit,
                  onTap: onMore,
                ),
                const SizedBox(height: BafSpacing.sm),
                ModuleListTile(
                  number: 6,
                  module: BafModules.sync,
                  status: 'Sync now',
                  statusColor: BafColors.sync,
                  onTap: onManualSync,
                ),
                const SizedBox(height: BafSpacing.lg),
                const _PrinciplesStrip(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  final AppUser appUser;
  final int workflowAttentionCount;
  final VoidCallback onAssets;
  final VoidCallback onClosed;
  final VoidCallback onReports;
  final VoidCallback onAdmin;
  final VoidCallback onRaiseIssue;
  final VoidCallback onAbnormalities;
  final VoidCallback onTemplateAuthoring;
  final VoidCallback onTemplatePublisher;
  final VoidCallback onKnowledgeGovernance;
  final VoidCallback onLocalDiagnostics;
  final VoidCallback onMaintenanceWorkflow;

  const _MoreScreen({
    required this.appUser,
    required this.workflowAttentionCount,
    required this.onAssets,
    required this.onClosed,
    required this.onReports,
    required this.onAdmin,
    required this.onRaiseIssue,
    required this.onAbnormalities,
    required this.onTemplateAuthoring,
    required this.onTemplatePublisher,
    required this.onKnowledgeGovernance,
    required this.onLocalDiagnostics,
    required this.onMaintenanceWorkflow,
  });

  @override
  Widget build(BuildContext context) {
    final canSeeOperationalData = appUser.canSeeAllTickets;
    final canSeeClosed = appUser.canCloseAnyTicket;
    final canSeeReports = appUser.canViewReports;

    return SafeArea(
      bottom: false,
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
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          const Text(
            'Tools, records and administrative access.',
            style: TextStyle(color: BafColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: BafSpacing.lg),
          ModuleListTile(
            number: 1,
            module: BafModules.maintenance,
            status: 'Raise',
            statusColor: BafColors.maintenance,
            onTap: onRaiseIssue,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 2,
            module: BafModules.assets,
            status: canSeeOperationalData ? 'Open' : 'Limited',
            statusColor: BafColors.assets,
            onTap: onAssets,
            enabled: canSeeOperationalData,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 3,
            module: BafModules.charges,
            status: 'People',
            statusColor: BafColors.charges,
            onTap: onAssets,
            enabled: canSeeOperationalData,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 4,
            module: const ModuleVisual(
              title: 'Abnormalities',
              description: 'Charge abnormality and RA operational memory',
              icon: Icons.memory_rounded,
              color: BafColors.charges,
            ),
            status: 'Charge log',
            statusColor: BafColors.charges,
            onTap: onAbnormalities,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 5,
            module: BafModules.audit,
            status: canSeeClosed ? 'Closed' : 'Limited',
            statusColor: BafColors.audit,
            onTap: onClosed,
            enabled: canSeeClosed,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 6,
            module: const ModuleVisual(
              title: 'Reports',
              description: 'Fleet status and operational summaries',
              icon: Icons.bar_chart_rounded,
              color: BafColors.planned,
            ),
            status: canSeeReports ? 'Open' : 'Limited',
            statusColor: BafColors.planned,
            onTap: onReports,
            enabled: canSeeReports,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 7,
            module: BafModules.admin,
            status: appUser.canOpenAdminDataBrowser ? 'Admin' : 'Limited',
            statusColor: BafColors.admin,
            onTap: onAdmin,
            enabled: appUser.canOpenAdminDataBrowser,
          ),
          const SizedBox(height: BafSpacing.sm),
          ModuleListTile(
            number: 8,
            module: const ModuleVisual(
              title: 'Maintenance Workflow',
              description: 'Lane acknowledgement, compliance and equipment availability',
              icon: Icons.account_tree_outlined,
              color: BafColors.planned,
            ),
            status: !appUser.canViewPlannedMaintenance
                ? 'Limited'
                : workflowAttentionCount > 0
                    ? '$workflowAttentionCount pending'
                    : 'Open',
            statusColor: BafColors.planned,
            onTap: onMaintenanceWorkflow,
            enabled: appUser.canViewPlannedMaintenance,
          ),
          if (appUser.canManageTemplateGovernance) ...[
            const SizedBox(height: BafSpacing.sm),
            ModuleListTile(
              number: 9,
              module: const ModuleVisual(
                title: 'Template Authoring',
                description:
                    'Build modules and publish governed template versions',
                icon: Icons.architecture_rounded,
                color: BafColors.planned,
              ),
              status: 'Module-first',
              statusColor: BafColors.planned,
              onTap: onTemplateAuthoring,
            ),
            const SizedBox(height: BafSpacing.sm),
            ModuleListTile(
              number: 10,
              module: const ModuleVisual(
                title: 'Template Publisher',
                description:
                    'Legacy JSON-paste publisher. Use when porting external '
                    'content or debugging snapshot bytes.',
                icon: Icons.verified_rounded,
                color: BafColors.planned,
              ),
              status: 'Legacy',
              statusColor: BafColors.textSecondary,
              onTap: onTemplatePublisher,
            ),
            const SizedBox(height: BafSpacing.sm),
            ModuleListTile(
              number: 11,
              module: const ModuleVisual(
                title: 'Knowledge Governance',
                description:
                    'Govern BAF knowledge rows, tags and matrix versions',
                icon: Icons.schema_rounded,
                color: BafColors.audit,
              ),
              status: 'Admin/SI',
              statusColor: BafColors.audit,
              onTap: onKnowledgeGovernance,
            ),
            const SizedBox(height: BafSpacing.sm),
            ModuleListTile(
              number: 12,
              module: const ModuleVisual(
                title: 'Support Diagnostics',
                description:
                    'Local sync inventory, runtime support context and recovery export',
                icon: Icons.troubleshoot_rounded,
                color: BafColors.admin,
              ),
              status: 'Admin/SI',
              statusColor: BafColors.admin,
              onTap: onLocalDiagnostics,
            ),
          ],
        ],
      ),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.dashboard_customize_rounded,
          color: BafColors.navySoft,
          size: 22,
        ),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrinciplesStrip extends StatelessWidget {
  const _PrinciplesStrip();

  @override
  Widget build(BuildContext context) {
    return const DashboardCard(
      padding: EdgeInsets.all(BafSpacing.md),
      child: Column(
        children: [
          _PrincipleRow(
            icon: Icons.touch_app_rounded,
            title: 'Easy to raise',
            subtitle: 'Simple reporting, anytime.',
          ),
          Divider(height: BafSpacing.lg),
          _PrincipleRow(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Easy to attend',
            subtitle: 'Everything needed in one place.',
          ),
          Divider(height: BafSpacing.lg),
          _PrincipleRow(
            icon: Icons.groups_rounded,
            title: 'Clear ownership',
            subtitle: 'Right people, clear accountability.',
          ),
          Divider(height: BafSpacing.lg),
          _PrincipleRow(
            icon: Icons.cloud_done_rounded,
            title: 'Offline reliable',
            subtitle: 'Work anywhere, sync when ready.',
          ),
        ],
      ),
    );
  }
}

class _PrincipleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PrincipleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BafColors.navySoft, size: 24),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
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
