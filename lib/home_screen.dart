// FILE: lib/home_screen.dart

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/maintenance/presentation/ticket_screen.dart';
import 'features/maintenance/presentation/maintenance_form.dart';
import 'features/maintenance/presentation/frequent_issue_catalogue_screen.dart';
import 'features/planned_maintenance/presentation/templates_screen.dart';
import 'features/planned_maintenance/presentation/module_composer_screen.dart';
import 'features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'features/planned_maintenance/presentation/knowledge_governance_screen.dart';
import 'features/planned_maintenance/presentation/closed_job_dossiers_screen.dart';
import 'features/planned_maintenance/presentation/maintenance_intelligence_screen.dart';
import 'features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'features/inspections/data/inspection_campaign.dart';
import 'features/inspections/presentation/inspection_programmes_screen.dart';
import 'features/inspections/providers/inspection_provider.dart';
import 'features/assets/presentation/asset_timeline_screen.dart';
import 'features/assets/presentation/asset_registry_screen.dart';
import 'features/assets/presentation/asset_condition_board.dart';
import 'features/assets/presentation/inner_cover_lifecycle_screen.dart';
import 'features/assets/presentation/furnace_stuckup_board.dart';
import 'features/assets/domain/plant_asset_overview.dart';
import 'features/assets/providers/plant_asset_overview_provider.dart';
import 'features/audit/presentation/audit_timeline_screen.dart';
import 'features/admin/presentation/admin_data_browser.dart';
import 'features/admin/presentation/local_diagnostics_screen.dart';
import 'features/admin/services/device_recovery_listener.dart';
import 'features/directives/presentation/directives_screen.dart';
import 'features/maintenance/presentation/closed_tickets_screen.dart';
import 'features/reports/presentation/fleet_status_screen.dart';
import 'features/reports/presentation/burner_reliability_screen.dart';
import 'features/abnormalities/presentation/abnormalities_home_screen.dart';
import 'features/quality/presentation/quality_home_screen.dart';
import 'features/quality/data/quality_warning.dart';
import 'features/quality/providers/quality_provider.dart';
import 'features/operational_events/presentation/operational_events_screen.dart';
import 'features/operational_events/presentation/operational_control_screen.dart';
import 'features/operational_events/providers/operational_event_provider.dart';
import 'features/maintenance_workflow/presentation/screens/compliance_inbox_screen.dart';
import 'features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart';
import 'features/maintenance_workflow/presentation/screens/equipment_status_board.dart';
import 'features/maintenance_workflow/presentation/screens/workflow_hub_screen.dart';
import 'features/maintenance_workflow/providers/workflow_providers.dart';
import 'features/critical_alarm/presentation/critical_alarm_screen.dart';
import 'features/critical_alarm/providers/critical_alarm_providers.dart';
import 'features/morning_review/presentation/morning_review_screen.dart';

import 'features/auth/data/user_model.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/maintenance/providers/maintenance_provider.dart';
import 'features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'features/directives/providers/operational_directive_provider.dart';

import 'core/theme/baf_design_system.dart';
import 'core/widgets/baf_ui.dart';
import 'core/widgets/brand/brand_widgets.dart';
import 'core/widgets/dashboard/dashboard_widgets.dart';
import 'core/widgets/dashboard/status_badge.dart';
import 'core/providers/sync_status_provider.dart';
import 'core/services/sync_coordinator.dart';

part 'home_insight_widgets.dart';

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
    if (message.data['destinationType'] == 'admin_device_reset') {
      unawaited(
        ref
            .read(deviceRecoveryListenerProvider)
            .checkNow(
              reason: 'notification_opened',
              expectedInstallationId: message.data['installationId'],
            ),
      );
      return;
    }
    if (message.data['destinationType'] == 'critical_alarm') {
      final alarmId = message.data['alarmId']?.trim();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CriticalAlarmScreen(initialAlarmId: alarmId),
        ),
      );
      return;
    }
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
          () => const Scaffold(
            backgroundColor: BafColors.background,
            body: BafLoadingPanel(label: 'Preparing your operations workspace'),
          ),
      error:
          (e, _) => Scaffold(
            backgroundColor: BafColors.background,
            body: BafStatePanel.error(
              title: 'Workspace unavailable',
              message: 'Your approved profile could not be loaded. $e',
            ),
          ),
      data: (appUser) {
        if (appUser == null) {
          return Scaffold(
            backgroundColor: BafColors.background,
            body: BafStatePanel.empty(
              title: 'Approved profile required',
              message:
                  'Sign in with an approved account to open the operations workspace.',
              icon: Icons.person_off_outlined,
              color: BafColors.admin,
            ),
          );
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
        final operationalEventsAsync = ref.watch(
          operationalEventsProvider(appUser.uid),
        );
        final qualityWarningsAsync = ref.watch(qualityWarningsProvider);
        final qualityMonitoringAsync = ref.watch(
          qualityMonitoringRequestsProvider,
        );
        final maintenanceDueStatesAsync = ref.watch(
          maintenanceDueStatesProvider,
        );
        final inspectionFindingsAsync = ref.watch(
          allInspectionFindingsProvider,
        );
        final criticalAlarmsAsync = ref.watch(activeCriticalAlarmsProvider);

        final ticketCount = ticketCountAsync.value ?? 0;
        final executionCount = executionCountAsync?.value ?? 0;
        final directiveCount = directiveCountAsync.value ?? 0;
        final workflowAttentionCount =
            summarizeWorkflowAttention(
              actor: appUser,
              lanes: workflowLanesAsync?.value ?? const [],
              compliance: workflowComplianceAsync?.value ?? const [],
            ).total;
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
        final activeQualityMonitoringCount =
            qualityMonitoringAsync.value
                ?.where(
                  (request) => request.status == QualityMonitoringStatus.active,
                )
                .length ??
            0;
        final overdueMaintenanceCount =
            maintenanceDueStatesAsync.value
                ?.where((state) => state.isOverdue)
                .length ??
            0;
        final activeInspectionFindingCount =
            inspectionFindingsAsync.value
                ?.where(
                  (finding) => {
                    InspectionFindingStatus.open,
                    InspectionFindingStatus.correctiveActionLinked,
                    InspectionFindingStatus.awaitingVerification,
                  }.contains(finding.status),
                )
                .length ??
            0;
        final criticalAlarmSnapshot = criticalAlarmsAsync.asData?.value;
        final criticalAlarmsUnavailable =
            criticalAlarmSnapshot?.isServerVerified != true;
        final activeCriticalAlarmCount =
            criticalAlarmsUnavailable
                ? 0
                : criticalAlarmSnapshot!.alarms.length;
        final operationalEventsUnavailable =
            operationalEventsAsync.value == null;
        final qualityWarningsUnavailable = qualityWarningsAsync.value == null;
        final qualityMonitoringUnavailable =
            qualityMonitoringAsync.value == null;
        final attentionDataUnavailable =
            ticketCountAsync.value == null ||
            directiveCountAsync.value == null ||
            (executionCountAsync != null &&
                executionCountAsync.value == null) ||
            (workflowLanesAsync != null && workflowLanesAsync.value == null) ||
            (workflowComplianceAsync != null &&
                workflowComplianceAsync.value == null) ||
            operationalEventsUnavailable ||
            qualityWarningsUnavailable ||
            qualityMonitoringUnavailable ||
            maintenanceDueStatesAsync.value == null ||
            inspectionFindingsAsync.value == null ||
            criticalAlarmsUnavailable;

        final tabs = _buildTabs(
          appUser: appUser,
          ticketCount: ticketCount,
          executionCount: executionCount,
          directiveCount: directiveCount,
          workflowAttentionCount: workflowAttentionCount,
          openOperationalEventCount: openOperationalEventCount,
          openQualityWarningCount: openQualityWarningCount,
          activeQualityMonitoringCount: activeQualityMonitoringCount,
          overdueMaintenanceCount: overdueMaintenanceCount,
          activeInspectionFindingCount: activeInspectionFindingCount,
          activeCriticalAlarmCount: activeCriticalAlarmCount,
          operationalEventsUnavailable: operationalEventsUnavailable,
          qualityWarningsUnavailable: qualityWarningsUnavailable,
          qualityMonitoringUnavailable: qualityMonitoringUnavailable,
          directiveDataUnavailable: directiveCountAsync.value == null,
          workflowDataUnavailable:
              workflowLanesAsync?.value == null ||
              workflowComplianceAsync?.value == null,
          inspectionFindingsUnavailable: inspectionFindingsAsync.value == null,
          criticalAlarmsUnavailable: criticalAlarmsUnavailable,
          attentionDataUnavailable: attentionDataUnavailable,
          plantOverview: plantOverviewAsync,
        );

        final safeIndex = _currentIndex.clamp(0, tabs.length - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final body = BafPageCanvas(
              child: _LazyIndexedStack(
                index: safeIndex,
                itemCount: tabs.length,
                itemBuilder:
                    (context, index) => tabs[index].buildScreen(context),
              ),
            );
            final useRail = constraints.maxWidth >= 900;

            if (useRail) {
              return Scaffold(
                backgroundColor: BafColors.background,
                body: Row(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: BafColors.surfaceRaised,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x120D1C22),
                            blurRadius: 14,
                            offset: Offset(4, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: NavigationRail(
                          selectedIndex: safeIndex,
                          extended: constraints.maxWidth >= 1200,
                          minExtendedWidth: 210,
                          leading: Padding(
                            padding: const EdgeInsets.only(
                              top: BafSpacing.sm,
                              bottom: BafSpacing.lg,
                            ),
                            child:
                                constraints.maxWidth >= 1200
                                    ? const BafBrandLockup(compact: true)
                                    : const ManmithasMark(size: 38),
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
              bottomNavigationBar: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: BafColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140D1C22),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: safeIndex,
                  onDestinationSelected:
                      (index) => setState(() => _currentIndex = index),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: tabs.map((t) => t.destination).toList(),
                ),
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
    required int activeQualityMonitoringCount,
    required int overdueMaintenanceCount,
    required int activeInspectionFindingCount,
    required int activeCriticalAlarmCount,
    required bool operationalEventsUnavailable,
    required bool qualityWarningsUnavailable,
    required bool qualityMonitoringUnavailable,
    required bool directiveDataUnavailable,
    required bool workflowDataUnavailable,
    required bool inspectionFindingsUnavailable,
    required bool criticalAlarmsUnavailable,
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
              activeQualityMonitoringCount: activeQualityMonitoringCount,
              overdueMaintenanceCount: overdueMaintenanceCount,
              activeInspectionFindingCount: activeInspectionFindingCount,
              activeCriticalAlarmCount: activeCriticalAlarmCount,
              operationalEventsUnavailable: operationalEventsUnavailable,
              qualityWarningsUnavailable: qualityWarningsUnavailable,
              qualityMonitoringUnavailable: qualityMonitoringUnavailable,
              attentionDataUnavailable: attentionDataUnavailable,
              criticalAlarmsUnavailable: criticalAlarmsUnavailable,
              plantOverview: plantOverview,
              onProfileTap: () => _showProfileSheet(context, ref, appUser),
              onRaiseIssue: () => _openMaintenanceForm(context),
              onIssues: () => setState(() => _currentIndex = 1),
              onWork: () => setState(() => _currentIndex = 2),
              onDirectives: () => setState(() => _currentIndex = 3),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onQuality: () => _push(context, const QualityHomeScreen()),
              onQualityMonitoring:
                  () => _push(context, const QualityHomeScreen.monitoring()),
              onOperationalEvents:
                  () => _push(context, const OperationalEventsScreen()),
              onPlantCondition:
                  () => _push(context, const AssetConditionBoard()),
              onPlantConditionFiltered:
                  (filter) => _push(
                    context,
                    AssetConditionBoard(initialFilter: filter),
                  ),
              onMorningReview:
                  () => _push(context, const MorningReviewScreen()),
              onReports: () => _push(context, const FleetStatusScreen()),
              onControl: () => setState(() => _currentIndex = 3),
              onMaintenanceRhythm:
                  () => _push(context, const MaintenanceIntelligenceScreen()),
              onInspectionProgrammes:
                  () => _push(context, const InspectionProgrammesScreen()),
              onCriticalAlarms:
                  () => _push(context, const CriticalAlarmScreen()),
              onManualSync: () => _retryAttentionData(context, appUser),
            ),
        destination: const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded, color: BafColors.teal),
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
            child: const Icon(
              Icons.report_problem_rounded,
              color: BafColors.danger,
            ),
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
            child: const Icon(Icons.handyman_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: executionCount + workflowAttentionCount > 0,
            label: Text('${executionCount + workflowAttentionCount}'),
            child: const Icon(Icons.handyman_rounded, color: BafColors.planned),
          ),
          label: 'Work',
        ),
      ),
      _AppTab(
        label: 'Control',
        screenBuilder:
            (_) => OperationalControlScreen(
              appUser: appUser,
              directiveCount: directiveCount,
              workflowAttentionCount: workflowAttentionCount,
              operationalEventCount: openOperationalEventCount,
              qualityWarningCount: openQualityWarningCount,
              qualityMonitoringCount: activeQualityMonitoringCount,
              inspectionFindingCount: activeInspectionFindingCount,
              criticalAlarmCount: activeCriticalAlarmCount,
              directiveDataUnavailable: directiveDataUnavailable,
              workflowDataUnavailable: workflowDataUnavailable,
              operationalEventsUnavailable: operationalEventsUnavailable,
              qualityWarningsUnavailable: qualityWarningsUnavailable,
              qualityMonitoringUnavailable: qualityMonitoringUnavailable,
              inspectionFindingsUnavailable: inspectionFindingsUnavailable,
              criticalAlarmsUnavailable: criticalAlarmsUnavailable,
              onDirectives: () => _push(context, const DirectivesScreen()),
              onWorkflow: () => setState(() => _currentIndex = 2),
              onOperationalEvents:
                  () => _push(context, const OperationalEventsScreen()),
              onQuality: () => _push(context, const QualityHomeScreen()),
              onQualityMonitoring:
                  () => _push(context, const QualityHomeScreen.monitoring()),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onInspections:
                  () => _push(context, const InspectionProgrammesScreen()),
              onCriticalAlarms:
                  () => _push(context, const CriticalAlarmScreen()),
            ),
        destination: NavigationDestination(
          icon: Badge(
            isLabelVisible:
                directiveCount +
                    openOperationalEventCount +
                    openQualityWarningCount +
                    activeQualityMonitoringCount +
                    activeInspectionFindingCount +
                    activeCriticalAlarmCount >
                0,
            label: Text(
              '${directiveCount + openOperationalEventCount + openQualityWarningCount + activeQualityMonitoringCount + activeInspectionFindingCount + activeCriticalAlarmCount}',
            ),
            child: const Icon(Icons.hub_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible:
                directiveCount +
                    openOperationalEventCount +
                    openQualityWarningCount +
                    activeQualityMonitoringCount +
                    activeInspectionFindingCount +
                    activeCriticalAlarmCount >
                0,
            label: Text(
              '${directiveCount + openOperationalEventCount + openQualityWarningCount + activeQualityMonitoringCount + activeInspectionFindingCount + activeCriticalAlarmCount}',
            ),
            child: const Icon(Icons.hub_rounded, color: BafColors.directives),
          ),
          label: 'Control',
        ),
      ),
      _AppTab(
        label: 'More',
        screenBuilder:
            (_) => _MoreScreen(
              appUser: appUser,
              onRaiseIssue: () => _openMaintenanceForm(context),
              onIssues: () => setState(() => _currentIndex = 1),
              onWork: () => setState(() => _currentIndex = 2),
              onControl: () => setState(() => _currentIndex = 3),
              onDirectives: () => _push(context, const DirectivesScreen()),
              onMorningReview:
                  () => _push(context, const MorningReviewScreen()),
              onWorkflow: () => _push(context, const WorkflowHubScreen()),
              onAssetRegistry:
                  () => _push(context, const AssetRegistryScreen()),
              onPlantCondition:
                  () => _push(context, const AssetConditionBoard()),
              onAssets: () => _push(context, const AssetTimelineScreen()),
              onInnerCovers:
                  () => _push(context, const InnerCoverLifecycleScreen()),
              onFurnaceStuckup:
                  () => _push(context, const FurnaceStuckupBoard()),
              onClosed: () => _push(context, const ClosedTicketsScreen()),
              onClosedJobs:
                  () => _push(context, const ClosedJobDossiersScreen()),
              onMaintenanceRhythm:
                  () => _push(context, const MaintenanceIntelligenceScreen()),
              onInspectionProgrammes:
                  () => _push(context, const InspectionProgrammesScreen()),
              onReports: () => _push(context, const FleetStatusScreen()),
              onBurnerReliability:
                  () => _push(context, const BurnerReliabilityScreen()),
              onAdmin: () => _push(context, const AdminDataBrowser()),
              onAuditLog: () => _push(context, const RecentAuditLogScreen()),
              onAbnormalities:
                  () => _push(context, const AbnormalitiesHomeScreen()),
              onQuality: () => _push(context, const QualityHomeScreen()),
              onQualityMonitoring:
                  () => _push(context, const QualityHomeScreen.monitoring()),
              onOperationalEvents:
                  () => _push(context, const OperationalEventsScreen()),
              onTemplateAuthoring: () => _openModuleComposer(context, appUser),
              onTemplatePublisher:
                  () => _push(context, const TemplatePublisherScreen()),
              onKnowledgeGovernance:
                  () => _push(context, const KnowledgeGovernanceScreen()),
              onFrequentIssues:
                  () => _push(context, const FrequentIssueCatalogueScreen()),
              onLocalDiagnostics:
                  () => _push(context, const LocalDiagnosticsScreen()),
            ),
        destination: const NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(
            Icons.grid_view_rounded,
            color: BafColors.graphite,
          ),
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
    ref.invalidate(operationalEventsProvider(appUser.uid));
    ref.invalidate(qualityWarningsProvider);
    ref.invalidate(maintenanceDueStatesProvider);
    ref.invalidate(allInspectionFindingsProvider);
    ref.invalidate(activeCriticalAlarmsProvider);
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => Center(
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
                              Navigator.pop(sheetContext);
                              try {
                                await ref.read(authServiceProvider).signOut();
                              } catch (error) {
                                messenger?.showSnackBar(
                                  SnackBar(
                                    content: Text('$error'),
                                    backgroundColor: BafColors.warning,
                                  ),
                                );
                              }
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
                        const SizedBox(height: BafSpacing.lg),
                        const Divider(),
                        const SizedBox(height: BafSpacing.md),
                        const Center(child: BafBrandLockup(compact: true)),
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
  final int activeQualityMonitoringCount;
  final int overdueMaintenanceCount;
  final int activeInspectionFindingCount;
  final int activeCriticalAlarmCount;
  final bool operationalEventsUnavailable;
  final bool qualityWarningsUnavailable;
  final bool qualityMonitoringUnavailable;
  final bool attentionDataUnavailable;
  final bool criticalAlarmsUnavailable;
  final AsyncValue<PlantAssetOverview> plantOverview;
  final VoidCallback onProfileTap;
  final VoidCallback onRaiseIssue;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onDirectives;
  final VoidCallback onAbnormalities;
  final VoidCallback onQuality;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onOperationalEvents;
  final VoidCallback onPlantCondition;
  final ValueChanged<AssetConditionFilter> onPlantConditionFiltered;
  final VoidCallback onMorningReview;
  final VoidCallback onReports;
  final VoidCallback onControl;
  final VoidCallback onMaintenanceRhythm;
  final VoidCallback onInspectionProgrammes;
  final VoidCallback onCriticalAlarms;
  final VoidCallback onManualSync;

  const _DashboardHome({
    required this.appUser,
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.openOperationalEventCount,
    required this.openQualityWarningCount,
    required this.activeQualityMonitoringCount,
    required this.overdueMaintenanceCount,
    required this.activeInspectionFindingCount,
    required this.activeCriticalAlarmCount,
    required this.operationalEventsUnavailable,
    required this.qualityWarningsUnavailable,
    required this.qualityMonitoringUnavailable,
    required this.attentionDataUnavailable,
    required this.criticalAlarmsUnavailable,
    required this.plantOverview,
    required this.onProfileTap,
    required this.onRaiseIssue,
    required this.onIssues,
    required this.onWork,
    required this.onDirectives,
    required this.onAbnormalities,
    required this.onQuality,
    required this.onQualityMonitoring,
    required this.onOperationalEvents,
    required this.onPlantCondition,
    required this.onPlantConditionFiltered,
    required this.onMorningReview,
    required this.onReports,
    required this.onControl,
    required this.onMaintenanceRhythm,
    required this.onInspectionProgrammes,
    required this.onCriticalAlarms,
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
        openQualityWarningCount +
        activeQualityMonitoringCount +
        overdueMaintenanceCount +
        activeInspectionFindingCount +
        activeCriticalAlarmCount;

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.md,
              BafSpacing.sm,
              BafSpacing.md,
              BafSpacing.xl,
            ),
            children: [
              DashboardHeader(
                userName: appUser.name,
                avatar: _UserAvatar(appUser: appUser),
                syncIndicator: _CompactSyncPill(onManualSync: onManualSync),
                onProfileTap: onProfileTap,
              ),
              if (activeCriticalAlarmCount > 0 ||
                  criticalAlarmsUnavailable) ...[
                const SizedBox(height: BafSpacing.sm),
                _CriticalAlarmHomeStrip(
                  count: activeCriticalAlarmCount,
                  unavailable: criticalAlarmsUnavailable,
                  onTap: onCriticalAlarms,
                ),
              ],
              const SizedBox(height: BafSpacing.md),
              HomeCommandBar(
                onRaiseIssue: onRaiseIssue,
                onPlantCondition: onPlantCondition,
                onMorningReview: onMorningReview,
                onReports: onReports,
                onControl: onControl,
              ),
              const SizedBox(height: BafSpacing.lg),
              PlantOverviewPanel(
                overview: plantOverview,
                onOpen: onPlantCondition,
                onOpenFiltered: onPlantConditionFiltered,
              ),
              const SizedBox(height: BafSpacing.lg),
              HomeManagementPulsePanel(
                plantOverview: plantOverview,
                actionCount:
                    ticketCount +
                    executionCount +
                    directiveCount +
                    workflowAttentionCount +
                    openOperationalEventCount +
                    openQualityWarningCount,
                assuranceCount:
                    overdueMaintenanceCount +
                    activeInspectionFindingCount +
                    activeQualityMonitoringCount,
                dataUnavailable: attentionDataUnavailable,
                onOpenReports: onReports,
                onPlantCondition: onPlantCondition,
                onIssues: onIssues,
                onWork: onWork,
                onControl: onControl,
                onQualityMonitoring: onQualityMonitoring,
                onRetry: onManualSync,
                onMaintenanceRhythm: onMaintenanceRhythm,
                onInspectionProgrammes: onInspectionProgrammes,
                ticketCount: ticketCount,
                executionCount: executionCount,
                directiveCount: directiveCount,
                workflowAttentionCount: workflowAttentionCount,
                openOperationalEventCount: openOperationalEventCount,
                openQualityWarningCount: openQualityWarningCount,
                activeQualityMonitoringCount: activeQualityMonitoringCount,
                overdueMaintenanceCount: overdueMaintenanceCount,
                activeInspectionFindingCount: activeInspectionFindingCount,
              ),
              const SizedBox(height: BafSpacing.lg),
              _HomeSectionHeader(
                title: 'Needs attention',
                icon: Icons.rule_folder_outlined,
                trailing: StatusBadge(
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
              ),
              const SizedBox(height: BafSpacing.sm),
              BafSectionSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: BafSpacing.md,
                  vertical: BafSpacing.xs,
                ),
                child: _AttentionPanel(
                  ticketCount: ticketCount,
                  executionCount: executionCount,
                  directiveCount: directiveCount,
                  workflowAttentionCount: workflowAttentionCount,
                  openOperationalEventCount: openOperationalEventCount,
                  openQualityWarningCount: openQualityWarningCount,
                  activeQualityMonitoringCount: activeQualityMonitoringCount,
                  overdueMaintenanceCount: overdueMaintenanceCount,
                  activeInspectionFindingCount: activeInspectionFindingCount,
                  attentionDataUnavailable: attentionDataUnavailable,
                  onIssues: onIssues,
                  onWork: onWork,
                  onDirectives: onDirectives,
                  onOperationalEvents: onOperationalEvents,
                  onQuality: onQuality,
                  onQualityMonitoring: onQualityMonitoring,
                  onMaintenanceRhythm: onMaintenanceRhythm,
                  onInspectionProgrammes: onInspectionProgrammes,
                  onRetry: onManualSync,
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              const _HomeSectionHeader(
                title: 'Operational watch',
                icon: Icons.monitor_heart_outlined,
              ),
              const SizedBox(height: BafSpacing.sm),
              _OperationalWatch(
                operationalEventCount: openOperationalEventCount,
                qualityWarningCount: openQualityWarningCount,
                qualityMonitoringCount: activeQualityMonitoringCount,
                operationalEventsUnavailable: operationalEventsUnavailable,
                qualityWarningsUnavailable: qualityWarningsUnavailable,
                qualityMonitoringUnavailable: qualityMonitoringUnavailable,
                onOperationalEvents: onOperationalEvents,
                onQuality: onQuality,
                onQualityMonitoring: onQualityMonitoring,
                onAbnormalities: onAbnormalities,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CriticalAlarmHomeStrip extends StatelessWidget {
  const _CriticalAlarmHomeStrip({
    required this.count,
    required this.unavailable,
    required this.onTap,
  });

  final int count;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color:
        unavailable
            ? BafColors.warning.withValues(alpha: 0.13)
            : BafColors.danger.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(BafRadius.medium),
    child: InkWell(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Row(
          children: [
            Icon(
              unavailable
                  ? Icons.cloud_off_outlined
                  : Icons.notification_important,
              color: unavailable ? BafColors.warning : BafColors.danger,
            ),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Text(
                unavailable
                    ? 'Live critical-alarm state is not verified'
                    : '$count active critical ${count == 1 ? 'alarm' : 'alarms'}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _HomeSectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BafColors.surfaceRaised,
          borderRadius: BorderRadius.circular(BafRadius.small),
          border: Border.all(color: BafColors.border),
          boxShadow: BafShadows.subtle,
        ),
        child: Icon(icon, size: 17, color: BafColors.steel),
      ),
      const SizedBox(width: BafSpacing.sm),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class _OperationalWatch extends StatelessWidget {
  final int operationalEventCount;
  final int qualityWarningCount;
  final int qualityMonitoringCount;
  final bool operationalEventsUnavailable;
  final bool qualityWarningsUnavailable;
  final bool qualityMonitoringUnavailable;
  final VoidCallback onOperationalEvents;
  final VoidCallback onQuality;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onAbnormalities;

  const _OperationalWatch({
    required this.operationalEventCount,
    required this.qualityWarningCount,
    required this.qualityMonitoringCount,
    required this.operationalEventsUnavailable,
    required this.qualityWarningsUnavailable,
    required this.qualityMonitoringUnavailable,
    required this.onOperationalEvents,
    required this.onQuality,
    required this.onQualityMonitoring,
    required this.onAbnormalities,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 4 : 2;
      final width =
          (constraints.maxWidth - BafSpacing.sm * (columns - 1)) / columns;
      final tiles = <Widget>[
        _WatchTile(
          icon: Icons.crisis_alert_outlined,
          color:
              operationalEventsUnavailable
                  ? BafColors.danger
                  : BafColors.warning,
          value:
              operationalEventsUnavailable
                  ? 'Unavailable'
                  : '$operationalEventCount',
          label: 'Events',
          onTap: onOperationalEvents,
        ),
        _WatchTile(
          icon: Icons.verified_user_outlined,
          color:
              qualityWarningsUnavailable ? BafColors.danger : BafColors.charges,
          value:
              qualityWarningsUnavailable
                  ? 'Unavailable'
                  : '$qualityWarningCount',
          label: 'Warnings',
          onTap: onQuality,
        ),
        _WatchTile(
          icon: Icons.monitor_heart_outlined,
          color:
              qualityMonitoringUnavailable
                  ? BafColors.danger
                  : BafColors.instrument,
          value:
              qualityMonitoringUnavailable
                  ? 'Unavailable'
                  : '$qualityMonitoringCount',
          label: 'Monitoring',
          onTap: onQualityMonitoring,
        ),
        _WatchTile(
          icon: Icons.memory_outlined,
          color: BafColors.instrument,
          value: 'Review',
          label: 'Abnormalities',
          onTap: onAbnormalities,
        ),
      ];
      return Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    },
  );
}

class _WatchTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _WatchTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BafRecordSurface(
    onTap: onTap,
    accent: color,
    padding: EdgeInsets.zero,
    child: SizedBox(
      height: 96,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: BafSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: value.length > 6 ? 10 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MoreScreen extends StatelessWidget {
  final AppUser appUser;
  final VoidCallback onRaiseIssue;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onControl;
  final VoidCallback onDirectives;
  final VoidCallback onMorningReview;
  final VoidCallback onWorkflow;
  final VoidCallback onAssetRegistry;
  final VoidCallback onPlantCondition;
  final VoidCallback onAssets;
  final VoidCallback onInnerCovers;
  final VoidCallback onFurnaceStuckup;
  final VoidCallback onClosed;
  final VoidCallback onClosedJobs;
  final VoidCallback onMaintenanceRhythm;
  final VoidCallback onInspectionProgrammes;
  final VoidCallback onReports;
  final VoidCallback onBurnerReliability;
  final VoidCallback onAdmin;
  final VoidCallback onAuditLog;
  final VoidCallback onAbnormalities;
  final VoidCallback onQuality;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onOperationalEvents;
  final VoidCallback onTemplateAuthoring;
  final VoidCallback onTemplatePublisher;
  final VoidCallback onKnowledgeGovernance;
  final VoidCallback onFrequentIssues;
  final VoidCallback onLocalDiagnostics;

  const _MoreScreen({
    required this.appUser,
    required this.onRaiseIssue,
    required this.onIssues,
    required this.onWork,
    required this.onControl,
    required this.onDirectives,
    required this.onMorningReview,
    required this.onWorkflow,
    required this.onAssetRegistry,
    required this.onPlantCondition,
    required this.onAssets,
    required this.onInnerCovers,
    required this.onFurnaceStuckup,
    required this.onClosed,
    required this.onClosedJobs,
    required this.onMaintenanceRhythm,
    required this.onInspectionProgrammes,
    required this.onReports,
    required this.onBurnerReliability,
    required this.onAdmin,
    required this.onAuditLog,
    required this.onAbnormalities,
    required this.onQuality,
    required this.onQualityMonitoring,
    required this.onOperationalEvents,
    required this.onTemplateAuthoring,
    required this.onTemplatePublisher,
    required this.onKnowledgeGovernance,
    required this.onFrequentIssues,
    required this.onLocalDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final canSeeOperationalData = appUser.canViewOperationalAssets;
    final canSeeClosed = appUser.canViewClosedMaintenanceTickets;
    final canSeeClosedJobs = appUser.canViewClosedJobDossiers;
    final canSeeReports = appUser.canViewReports;
    final primaryRoutes = <_RoleRoute>[
      _RoleRoute(
        icon: Icons.add_circle_outline_rounded,
        color: BafColors.maintenance,
        label: 'Raise issue',
        onTap: onRaiseIssue,
      ),
      _RoleRoute(
        icon: Icons.report_problem_outlined,
        color: BafColors.warning,
        label:
            appUser.canCloseMaintenanceTicket
                ? 'Issue supervision'
                : 'Issue queue',
        onTap: onIssues,
      ),
      if (appUser.canViewPlannedMaintenance)
        _RoleRoute(
          icon: Icons.work_outline_rounded,
          color: BafColors.planned,
          label: 'Maintenance work',
          onTap: onWork,
        ),
      if (appUser.canCreateDirective)
        _RoleRoute(
          icon: Icons.assignment_late_outlined,
          color: BafColors.directives,
          label: 'Directives',
          onTap: onDirectives,
        ),
      if (appUser.canRecordOperationalEvent)
        _RoleRoute(
          icon: Icons.crisis_alert_outlined,
          color: BafColors.warning,
          label: 'Plant events',
          onTap: onOperationalEvents,
        ),
      if (appUser.canCloseQualityWarning)
        _RoleRoute(
          icon: Icons.verified_user_outlined,
          color: BafColors.charges,
          label: 'Quality decisions',
          onTap: onQuality,
        ),
      if (appUser.canManageQualityMonitoring)
        _RoleRoute(
          icon: Icons.monitor_heart_outlined,
          color: BafColors.instrument,
          label: 'Cycle monitoring',
          onTap: onQualityMonitoring,
        ),
    ];
    final plantDestinations = <_MoreDestinationSpec>[
      if (canSeeOperationalData)
        _MoreDestinationSpec(
          icon: Icons.monitor_heart_outlined,
          color: BafColors.assets,
          title: 'Plant condition',
          subtitle:
              'Availability, maintenance, stuck-up, down and unfit assets',
          keywords: 'fleet status availability down unfit maintenance',
          onTap: onPlantCondition,
        ),
      if (canSeeOperationalData)
        _MoreDestinationSpec(
          icon: Icons.precision_manufacturing_outlined,
          color: BafColors.assets,
          title: 'Asset registry',
          subtitle: 'Current equipment, components and lifecycle state',
          keywords: 'hierarchy component subassembly ownership',
          onTap: onAssetRegistry,
        ),
      if (canSeeOperationalData)
        _MoreDestinationSpec(
          icon: Icons.timeline_rounded,
          color: BafColors.audit,
          title: 'Asset timeline',
          subtitle: 'Maintenance and planned-work history',
          keywords: 'history component replacement event',
          onTap: onAssets,
        ),
      if (canSeeOperationalData)
        _MoreDestinationSpec(
          icon: Icons.layers_outlined,
          color: BafColors.maintenance,
          title: 'Inner Covers',
          subtitle: 'Base pairing, spare pool and fabrication history',
          keywords: 'link delink pool serial fabrication retire',
          onTap: onInnerCovers,
        ),
      if (canSeeOperationalData)
        _MoreDestinationSpec(
          icon: Icons.vertical_align_top_rounded,
          color: BafColors.warning,
          title: 'Furnace stuck-up',
          subtitle: 'Blocked assemblies, cause review and Inner Cover evidence',
          keywords: 'stuck inner cover base release bulge',
          onTap: onFurnaceStuckup,
        ),
    ];
    final coordinationDestinations = <_MoreDestinationSpec>[
      _MoreDestinationSpec(
        icon: Icons.groups_2_outlined,
        color: BafColors.cobalt,
        title: 'Morning Review',
        subtitle: 'Daily safety, asset status, decisions and owned actions',
        keywords: 'morning meeting attendance action plan safety asset status',
        onTap: onMorningReview,
      ),
      _MoreDestinationSpec(
        icon: Icons.assignment_late_outlined,
        color: BafColors.directives,
        title: 'Directives',
        subtitle: 'Instructions, acknowledgement and closure ownership',
        keywords: 'direction instruction acknowledge comply close',
        onTap: onDirectives,
      ),
      if (appUser.canViewPlannedMaintenance)
        _MoreDestinationSpec(
          icon: Icons.account_tree_outlined,
          color: BafColors.warning,
          title: 'Maintenance workflow',
          subtitle: 'Lane queues, compliance requests and equipment control',
          keywords: 'workflow lane compliance deferment operations support',
          onTap: onWorkflow,
        ),
      if (appUser.canViewPlannedMaintenance)
        _MoreDestinationSpec(
          icon: Icons.event_repeat_rounded,
          color: BafColors.planned,
          title: 'Maintenance rhythm',
          subtitle: 'Due counters, forward plans and classified outcomes',
          keywords: 'cadence overdue due schedule plan',
          onTap: onMaintenanceRhythm,
        ),
      if (canSeeClosed)
        _MoreDestinationSpec(
          icon: Icons.history_rounded,
          color: BafColors.audit,
          title: 'Resolved issues',
          subtitle: 'Closed maintenance issues and reopen history',
          keywords: 'ticket closure maintenance history',
          onTap: onClosed,
        ),
      if (canSeeClosedJobs)
        _MoreDestinationSpec(
          icon: Icons.inventory_2_outlined,
          color: BafColors.planned,
          title: 'Closed job dossiers',
          subtitle: 'Completed and cancelled planned-job records',
          keywords: 'planned maintenance history completed cancelled',
          onTap: onClosedJobs,
        ),
    ];
    final assuranceDestinations = <_MoreDestinationSpec>[
      if (canSeeReports)
        _MoreDestinationSpec(
          icon: Icons.insights_rounded,
          color: BafColors.cobalt,
          title: 'Operations intelligence',
          subtitle: 'Management readout, fleet health, work and reliability',
          keywords: 'reports dashboard metrics summary performance',
          onTap: onReports,
        ),
      if (canSeeReports)
        _MoreDestinationSpec(
          icon: Icons.local_fire_department_outlined,
          color: BafColors.maintenance,
          title: 'Burner reliability',
          subtitle: 'Lockouts, rounds, red-hot evidence and readings',
          keywords: 'burner microamp uv block lockout furnace',
          onTap: onBurnerReliability,
        ),
      _MoreDestinationSpec(
        icon: Icons.memory_outlined,
        color: BafColors.instrument,
        title: 'Abnormalities',
        subtitle: 'Charge events, RA traceability and root causes',
        keywords: 'charge cycle abnormality root cause ra',
        onTap: onAbnormalities,
      ),
      if (appUser.canViewQuality)
        _MoreDestinationSpec(
          icon: Icons.verified_user_outlined,
          color: BafColors.charges,
          title: 'Quality',
          subtitle: 'Warnings, closure assurance and monitoring',
          keywords: 'quality warning grade charge cycle monitoring',
          onTap: onQuality,
        ),
      if (appUser.canViewQuality)
        _MoreDestinationSpec(
          icon: Icons.monitor_heart_outlined,
          color: BafColors.instrument,
          title: 'Cycle monitoring',
          subtitle: 'Active Base, Grade, cycle and charge surveillance',
          keywords: 'quality monitoring grade base cycle charge surveillance',
          onTap: onQualityMonitoring,
        ),
      _MoreDestinationSpec(
        icon: Icons.crisis_alert_outlined,
        color: BafColors.warning,
        title: 'Operational events',
        subtitle: 'Utilities, cranes, transfer cars and plant delays',
        keywords: 'water nitrogen gas power crane delay transfer car',
        onTap: onOperationalEvents,
      ),
      _MoreDestinationSpec(
        icon: Icons.fact_check_outlined,
        color: BafColors.instrument,
        title: 'Inspection programmes',
        subtitle: 'Component checks, cross-asset coverage and findings',
        keywords: 'audit inspection campaign component condition',
        onTap: onInspectionProgrammes,
      ),
    ];
    final governanceDestinations = <_MoreDestinationSpec>[
      if (appUser.canManageFrequentIssueDefinitions)
        _MoreDestinationSpec(
          icon: Icons.rule_folder_outlined,
          color: BafColors.maintenance,
          title: 'Frequent issues',
          subtitle: 'Governed issue choices and default routing',
          keywords: 'catalogue issue routing lane',
          onTap: onFrequentIssues,
        ),
      if (appUser.canManageTemplateGovernance)
        _MoreDestinationSpec(
          icon: Icons.architecture_outlined,
          color: BafColors.planned,
          title: 'Template authoring',
          subtitle: 'Build modules and governed template versions',
          keywords: 'planned maintenance module author publish',
          onTap: onTemplateAuthoring,
        ),
      if (appUser.canManageTemplateGovernance)
        _MoreDestinationSpec(
          icon: Icons.data_object_rounded,
          color: BafColors.textSecondary,
          title: 'Legacy template publisher',
          subtitle: 'Import or inspect historical snapshot JSON',
          keywords: 'legacy json template import',
          badge: 'Legacy',
          onTap: onTemplatePublisher,
        ),
      if (appUser.canManageTemplateGovernance)
        _MoreDestinationSpec(
          icon: Icons.schema_outlined,
          color: BafColors.audit,
          title: 'Knowledge governance',
          subtitle: 'BAF knowledge rows, tags and matrix versions',
          keywords: 'knowledge tag matrix governance',
          onTap: onKnowledgeGovernance,
        ),
    ];
    final adminDestinations = <_MoreDestinationSpec>[
      if (appUser.canOpenAdminDataBrowser)
        _MoreDestinationSpec(
          icon: Icons.admin_panel_settings_outlined,
          color: BafColors.admin,
          title: 'Administration',
          subtitle: 'Users, roles and governed data controls',
          keywords: 'admin users roles data edit',
          onTap: onAdmin,
        ),
      if (appUser.canViewAuditLogs)
        _MoreDestinationSpec(
          icon: Icons.fact_check_outlined,
          color: BafColors.audit,
          title: 'Audit log',
          subtitle: 'Recent governed changes and evidence',
          keywords: 'audit history evidence changes',
          onTap: onAuditLog,
        ),
      if (appUser.canViewMaintenanceWorkflowDiagnostics)
        _MoreDestinationSpec(
          icon: Icons.troubleshoot_outlined,
          color: BafColors.admin,
          title: 'Support diagnostics',
          subtitle: 'Sync inventory, runtime context and recovery',
          keywords: 'diagnostics sync recovery support',
          onTap: onLocalDiagnostics,
        ),
    ];
    final visibleDestinations = <_MoreDestinationSpec>[
      ...plantDestinations,
      ...coordinationDestinations,
      ...assuranceDestinations,
      ...governanceDestinations,
      ...adminDestinations,
    ];

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.md,
              BafSpacing.sm,
              BafSpacing.md,
              BafSpacing.xl,
            ),
            children: [
              const _DirectoryHeader(),
              const SizedBox(height: BafSpacing.md),
              _WorkspaceSearch(destinations: visibleDestinations),
              const SizedBox(height: BafSpacing.lg),
              _RoleStartPanel(
                routes: primaryRoutes,
                onControl: onControl,
                onReports: onReports,
              ),
              const SizedBox(height: BafSpacing.xl),
              _MoreSection(
                title: 'Assets and lifecycle',
                icon: Icons.precision_manufacturing_outlined,
                accent: BafColors.assets,
                destinations: plantDestinations,
              ),
              const SizedBox(height: BafSpacing.lg),
              _MoreSection(
                title: 'Work and coordination',
                icon: Icons.account_tree_outlined,
                accent: BafColors.warning,
                destinations: coordinationDestinations,
              ),
              const SizedBox(height: BafSpacing.lg),
              _MoreSection(
                title: 'Performance and assurance',
                icon: Icons.insights_outlined,
                accent: BafColors.cobalt,
                destinations: assuranceDestinations,
              ),
              if (appUser.canManageTemplateGovernance ||
                  appUser.canManageFrequentIssueDefinitions) ...[
                const SizedBox(height: BafSpacing.xl),
                _MoreSection(
                  title: 'Standards and governance',
                  icon: Icons.account_tree_outlined,
                  accent: BafColors.audit,
                  destinations: governanceDestinations,
                ),
              ],
              if (appUser.canOpenAdminDataBrowser ||
                  appUser.canViewAuditLogs ||
                  appUser.canViewMaintenanceWorkflowDiagnostics) ...[
                const SizedBox(height: BafSpacing.xl),
                _MoreSection(
                  title: 'Administration and support',
                  icon: Icons.admin_panel_settings_outlined,
                  accent: BafColors.admin,
                  destinations: adminDestinations,
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
  final int activeQualityMonitoringCount;
  final int overdueMaintenanceCount;
  final int activeInspectionFindingCount;
  final bool attentionDataUnavailable;
  final VoidCallback onIssues;
  final VoidCallback onWork;
  final VoidCallback onDirectives;
  final VoidCallback onOperationalEvents;
  final VoidCallback onQuality;
  final VoidCallback onQualityMonitoring;
  final VoidCallback onMaintenanceRhythm;
  final VoidCallback onInspectionProgrammes;
  final VoidCallback onRetry;

  const _AttentionPanel({
    required this.ticketCount,
    required this.executionCount,
    required this.directiveCount,
    required this.workflowAttentionCount,
    required this.openOperationalEventCount,
    required this.openQualityWarningCount,
    required this.activeQualityMonitoringCount,
    required this.overdueMaintenanceCount,
    required this.activeInspectionFindingCount,
    required this.attentionDataUnavailable,
    required this.onIssues,
    required this.onWork,
    required this.onDirectives,
    required this.onOperationalEvents,
    required this.onQuality,
    required this.onQualityMonitoring,
    required this.onMaintenanceRhythm,
    required this.onInspectionProgrammes,
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
      if (openQualityWarningCount > 0)
        _AttentionRow(
          icon: Icons.verified_user_outlined,
          color: BafColors.danger,
          title: 'Quality disposition required',
          detail: '$openQualityWarningCount warnings remain open',
          urgency: 'Immediate',
          onTap: onQuality,
        ),
      if (openOperationalEventCount > 0)
        _AttentionRow(
          icon: Icons.crisis_alert_outlined,
          color: BafColors.warning,
          title: 'Operational disruptions',
          detail: '$openOperationalEventCount currently open',
          urgency: 'Plant',
          onTap: onOperationalEvents,
        ),
      if (ticketCount > 0)
        _AttentionRow(
          icon: Icons.report_problem_outlined,
          color: BafColors.maintenance,
          title: 'Open issues',
          detail: '$ticketCount requiring attention',
          urgency: 'Action',
          onTap: onIssues,
        ),
      if (executionCount > 0)
        _AttentionRow(
          icon: Icons.work_outline_rounded,
          color: BafColors.planned,
          title: 'Open planned jobs',
          detail: '$executionCount active',
          urgency: 'Work',
          onTap: onWork,
        ),
      if (workflowAttentionCount > 0)
        _AttentionRow(
          icon: Icons.account_tree_outlined,
          color: BafColors.warning,
          title: 'Workflow obligations',
          detail: '$workflowAttentionCount lane or compliance tasks',
          urgency: 'Due',
          onTap: onWork,
        ),
      if (directiveCount > 0)
        _AttentionRow(
          icon: Icons.assignment_late_outlined,
          color: BafColors.directives,
          title: 'Active directives',
          detail: '$directiveCount visible to your role',
          urgency: 'Direction',
          onTap: onDirectives,
        ),
      if (overdueMaintenanceCount > 0)
        _AttentionRow(
          icon: Icons.event_busy_outlined,
          color: BafColors.danger,
          title: 'Overdue maintenance cadence',
          detail: '$overdueMaintenanceCount asset counters overdue',
          urgency: 'Overdue',
          onTap: onMaintenanceRhythm,
        ),
      if (activeInspectionFindingCount > 0)
        _AttentionRow(
          icon: Icons.fact_check_outlined,
          color: BafColors.maintenance,
          title: 'Active inspection findings',
          detail:
              '$activeInspectionFindingCount conditions under follow-through',
          urgency: 'Assurance',
          onTap: onInspectionProgrammes,
        ),
      if (activeQualityMonitoringCount > 0)
        _AttentionRow(
          icon: Icons.monitor_heart_outlined,
          color: BafColors.instrument,
          title: 'Active cycle monitoring',
          detail: '$activeQualityMonitoringCount quality requests in progress',
          urgency: 'Monitor',
          onTap: onQualityMonitoring,
        ),
    ];

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: BafSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE7F2EA),
                  borderRadius: BorderRadius.all(
                    Radius.circular(BafRadius.small),
                  ),
                ),
                child: Icon(Icons.task_alt_rounded, color: BafColors.success),
              ),
            ),
            SizedBox(width: BafSpacing.md),
            Expanded(
              child: Text(
                'No open work currently requires your attention.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
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
  final String? urgency;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.urgency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(BafRadius.small),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detail),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (urgency != null) StatusBadge(label: urgency!, color: color),
          const SizedBox(width: BafSpacing.xs),
          const Icon(
            Icons.chevron_right_rounded,
            color: BafColors.textSecondary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _MoreDestinationSpec {
  const _MoreDestinationSpec({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String keywords;
  final String? badge;
  final VoidCallback onTap;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return '$title $subtitle $keywords'.toLowerCase().contains(needle);
  }
}

class _RoleRoute {
  const _RoleRoute({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
}

class _RoleStartPanel extends StatelessWidget {
  const _RoleStartPanel({
    required this.routes,
    required this.onControl,
    required this.onReports,
  });

  final List<_RoleRoute> routes;
  final VoidCallback onControl;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final allRoutes = [
      ...routes,
      _RoleRoute(
        icon: Icons.radar_outlined,
        color: BafColors.cobalt,
        label: 'Control centre',
        onTap: onControl,
      ),
      _RoleRoute(
        icon: Icons.insights_outlined,
        color: BafColors.teal,
        label: 'Operations intelligence',
        onTap: onReports,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start here',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        const Text(
          'Primary routes for your assigned responsibilities',
          style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: BafSpacing.sm),
        BafSectionSurface(
          padding: const EdgeInsets.all(BafSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * BafSpacing.sm) /
                  columns;
              return Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  for (final route in allRoutes)
                    SizedBox(
                      width: width,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: route.onTap,
                        icon: Icon(route.icon, color: route.color, size: 19),
                        label: Text(
                          route.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BafSpacing.sm,
                          ),
                          side: BorderSide(
                            color: route.color.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkspaceSearch extends StatelessWidget {
  const _WorkspaceSearch({required this.destinations});

  final List<_MoreDestinationSpec> destinations;

  @override
  Widget build(BuildContext context) => SearchAnchor(
    viewHintText: 'Search screens and business functions',
    suggestionsBuilder: (context, controller) {
      final matches = destinations.where(
        (destination) => destination.matches(controller.text),
      );
      final rows = matches
          .map<Widget>(
            (destination) => ListTile(
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: destination.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Icon(
                  destination.icon,
                  color: destination.color,
                  size: 20,
                ),
              ),
              title: Text(destination.title),
              subtitle: Text(
                destination.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () {
                controller.closeView(destination.title);
                destination.onTap();
              },
            ),
          )
          .toList(growable: false);
      if (rows.isNotEmpty) return rows;
      return const [
        ListTile(
          leading: Icon(Icons.search_off_rounded),
          title: Text('No matching function'),
          subtitle: Text('Try an asset, work type, report or governance term.'),
        ),
      ];
    },
    builder:
        (context, controller) => SearchBar(
          controller: controller,
          hintText: 'Find a screen or function',
          leading: const Icon(Icons.search_rounded),
          trailing: const [
            Tooltip(
              message: 'Search your permitted workspace',
              child: Icon(Icons.manage_search_rounded),
            ),
          ],
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: const WidgetStatePropertyAll(
            BafColors.surfaceRaised,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BafColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
          ),
          onTap: controller.openView,
          onChanged: (_) => controller.openView(),
        ),
  );
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader();

  @override
  Widget build(BuildContext context) => const BafDarkHeaderSurface(
    child: Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x1FFFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(BafRadius.small)),
            ),
            child: ManmithasMark(size: 34, framed: false),
          ),
        ),
        SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All functions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: BafSpacing.xs),
              Text(
                'Task routes, records and controls available to your roles',
                style: TextStyle(
                  color: Color(0xFFC6D7DB),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MoreSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<_MoreDestinationSpec> destinations;

  const _MoreSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.sm),
        BafSectionSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: List<Widget>.generate(destinations.length * 2 - 1, (
              index,
            ) {
              return index.isEven
                  ? _MoreDestinationTile(
                    icon: destinations[index ~/ 2].icon,
                    color: destinations[index ~/ 2].color,
                    title: destinations[index ~/ 2].title,
                    subtitle: destinations[index ~/ 2].subtitle,
                    badge: destinations[index ~/ 2].badge,
                    onTap: destinations[index ~/ 2].onTap,
                  )
                  : const Divider(height: 1, color: BafColors.border);
            }),
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.md,
          vertical: BafSpacing.xs,
        ),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(BafRadius.medium),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
        ),
        trailing:
            badge == null
                ? Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: BafColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: BafColors.textSecondary,
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(label: badge!, color: BafColors.textSecondary),
                    const SizedBox(width: BafSpacing.xs),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
        onTap: onTap,
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
    final foreground = Color.lerp(color, Colors.white, 0.48)!;

    return Tooltip(
      message: disabled ? 'Sync already running' : 'Manual sync now',
      child: InkWell(
        onTap: disabled ? null : onManualSync,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BafSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(color: foreground.withValues(alpha: 0.48)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: BafSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
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
