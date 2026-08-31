import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/planned_maintenance/presentation/template_publisher_screen.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../features/audit/presentation/audit_timeline_screen.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import 'user_management_screen.dart';
import 'local_diagnostics_screen.dart';
import 'device_recovery_screen.dart';
import 'pilot_data_cleanup_screen.dart';
import 'admin_data_browser/admin_tickets_browser.dart';
import 'admin_data_browser/admin_directives_browser.dart';
import 'admin_data_browser/admin_templates_browser.dart';
import 'admin_data_browser/admin_executions_browser.dart';
import 'admin_data_browser/admin_abnormalities_tab.dart';
import 'admin_data_browser/admin_asset_hierarchy_tab.dart';
import '../../critical_alarm/presentation/critical_alarm_contacts_panel.dart';

// ============================================================================
// MAIN ADMIN DATA BROWSER (Tab Bar)
// ============================================================================

class AdminDataBrowser extends ConsumerStatefulWidget {
  const AdminDataBrowser({super.key});

  @override
  ConsumerState<AdminDataBrowser> createState() => _AdminDataBrowserState();
}

class _AdminDataBrowserState extends ConsumerState<AdminDataBrowser>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTab) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSupportTool(_AdminSupportTool tool) {
    final Widget screen = switch (tool) {
      _AdminSupportTool.syncConflicts => const SyncConflictReviewScreen(),
      _AdminSupportTool.localDiagnostics => const LocalDiagnosticsScreen(),
      _AdminSupportTool.deviceRecovery => const DeviceRecoveryScreen(),
      _AdminSupportTool.pilotDataCleanup => const PilotDataCleanupScreen(),
      _AdminSupportTool.templatePublisher => const TemplatePublisherScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);

    return appUserAsync.when(
      loading:
          () => const _AdminAccessDeniedScaffold(
            icon: Icons.admin_panel_settings_rounded,
            color: BafColors.admin,
            title: 'Checking admin access',
            message: 'Please wait while your permissions are verified.',
            showProgress: true,
          ),
      error:
          (error, _) => _AdminAccessDeniedScaffold(
            icon: Icons.error_outline_rounded,
            color: BafColors.danger,
            title: 'Could not verify admin access',
            message: '$error',
          ),
      data: (appUser) {
        if (appUser == null || !appUser.isAdmin) {
          return const _AdminAccessDeniedScaffold(
            icon: Icons.lock_outline_rounded,
            color: BafColors.danger,
            title: 'Admin access required',
            message:
                'Only approved admin users can open the Admin Data Browser.',
          );
        }

        final compactHeader = MediaQuery.sizeOf(context).width < 720;
        return Scaffold(
          appBar: AppBar(
            title: const BafAppBarTitle(
              title: 'Administration',
              subtitle: 'Governed data, access and support controls',
              icon: Icons.admin_panel_settings_outlined,
              accent: BafColors.admin,
            ),
            actions:
                compactHeader
                    ? [
                      PopupMenuButton<_AdminSupportTool>(
                        key: const ValueKey('admin-support-menu'),
                        tooltip: 'Administration support tools',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: _openSupportTool,
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: _AdminSupportTool.syncConflicts,
                                child: _AdminSupportMenuItem(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Sync conflicts',
                                ),
                              ),
                              const PopupMenuItem(
                                value: _AdminSupportTool.localDiagnostics,
                                child: _AdminSupportMenuItem(
                                  icon: Icons.fact_check_rounded,
                                  label: 'Local diagnostics',
                                ),
                              ),
                              const PopupMenuItem(
                                value: _AdminSupportTool.deviceRecovery,
                                child: _AdminSupportMenuItem(
                                  icon: Icons.phonelink_erase_rounded,
                                  label: 'Device recovery',
                                ),
                              ),
                              const PopupMenuItem(
                                value: _AdminSupportTool.pilotDataCleanup,
                                child: _AdminSupportMenuItem(
                                  icon: Icons.delete_sweep_outlined,
                                  label: 'Pilot data cleanup',
                                ),
                              ),
                              if (appUser.canManageTemplateGovernance)
                                const PopupMenuItem(
                                  value: _AdminSupportTool.templatePublisher,
                                  child: _AdminSupportMenuItem(
                                    icon: Icons.verified_rounded,
                                    label: 'Template publisher',
                                  ),
                                ),
                            ],
                      ),
                    ]
                    : [
                      IconButton(
                        tooltip: 'Review sync conflicts',
                        icon: const Icon(Icons.warning_amber_rounded),
                        onPressed:
                            () => _openSupportTool(
                              _AdminSupportTool.syncConflicts,
                            ),
                      ),
                      IconButton(
                        tooltip: 'Local diagnostics inventory',
                        icon: const Icon(Icons.fact_check_rounded),
                        onPressed:
                            () => _openSupportTool(
                              _AdminSupportTool.localDiagnostics,
                            ),
                      ),
                      IconButton(
                        tooltip: 'Recover an approved user phone',
                        icon: const Icon(Icons.phonelink_erase_rounded),
                        onPressed:
                            () => _openSupportTool(
                              _AdminSupportTool.deviceRecovery,
                          ),
                      ),
                      IconButton(
                        tooltip: 'Select deleted pilot records for cleanup',
                        icon: const Icon(Icons.delete_sweep_outlined),
                        onPressed:
                            () => _openSupportTool(
                              _AdminSupportTool.pilotDataCleanup,
                            ),
                      ),
                      if (appUser.canManageTemplateGovernance)
                        IconButton(
                          tooltip: 'Template Publisher',
                          icon: const Icon(Icons.verified_rounded),
                          onPressed:
                              () => _openSupportTool(
                                _AdminSupportTool.templatePublisher,
                              ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SyncStatusIndicator(),
                      ),
                    ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Tickets'),
                Tab(text: 'Directives'),
                Tab(text: 'Templates'),
                Tab(text: 'Executions'),
                Tab(text: 'Abnormalities'),
                Tab(text: 'Asset hierarchy'),
                Tab(text: 'Safety contacts'),
                Tab(text: 'Users'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (compactHeader)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SyncStatusIndicator(),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    const TicketsBrowser(),
                    const DirectivesBrowser(),
                    const TemplatesBrowser(),
                    const ExecutionsBrowser(),
                    const AbnormalitiesAdminTab(),
                    AssetHierarchyAdminTab(actor: appUser),
                    const CriticalAlarmContactsPanel(administrationMode: true),
                    const UsersTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _AdminSupportTool {
  syncConflicts,
  localDiagnostics,
  deviceRecovery,
  pilotDataCleanup,
  templatePublisher,
}

class _AdminSupportMenuItem extends StatelessWidget {
  const _AdminSupportMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: BafColors.admin),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class _AdminAccessDeniedScaffold extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool showProgress;

  const _AdminAccessDeniedScaffold({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Administration',
          subtitle: 'Governed data, access and support controls',
          icon: Icons.admin_panel_settings_outlined,
          accent: BafColors.admin,
        ),
      ),
      body: Center(
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
                Icon(icon, color: color, size: 42),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (showProgress) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// USERS TAB – wraps existing UserManagementScreen
// ============================================================================

class UsersTab extends StatelessWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen();
  }
}
