import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/planned_maintenance/presentation/template_publisher_screen.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../features/audit/presentation/audit_timeline_screen.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import 'user_management_screen.dart';
import 'local_diagnostics_screen.dart';
import '../../abnormalities/presentation/abnormality_types_screen.dart';
import '../../abnormalities/presentation/abnormality_reports_screen.dart';
import 'admin_data_browser/admin_tickets_browser.dart';
import 'admin_data_browser/admin_directives_browser.dart';
import 'admin_data_browser/admin_templates_browser.dart';
import 'admin_data_browser/admin_executions_browser.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Admin Data Browser',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: BafColors.navy,
            actions: [
              IconButton(
                tooltip: 'Review sync conflicts',
                icon: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SyncConflictReviewScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Local diagnostics inventory',
                icon: const Icon(Icons.fact_check_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LocalDiagnosticsScreen(),
                    ),
                  );
                },
              ),
              if (appUser.canManageTemplateGovernance)
                IconButton(
                  tooltip: 'Template Publisher',
                  icon: const Icon(Icons.verified_rounded, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TemplatePublisherScreen(),
                      ),
                    );
                  },
                ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SyncStatusIndicator(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Tickets'),
                Tab(text: 'Directives'),
                Tab(text: 'Templates'),
                Tab(text: 'Executions'),
                Tab(text: 'Abnormalities'),
                Tab(text: 'Users'),
              ],
            ),
          ),
          body: IndexedStack(
            index: _selectedTab,
            children: const [
              TicketsBrowser(),
              DirectivesBrowser(),
              TemplatesBrowser(),
              ExecutionsBrowser(),
              AbnormalitiesAdminTab(),
              UsersTab(),
            ],
          ),
        );
      },
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
        title: const Text(
          'Admin Data Browser',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: BafColors.navy,
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
// ABNORMALITIES ADMIN TAB – links to master data and intelligence
// ============================================================================

class AbnormalitiesAdminTab extends StatelessWidget {
  const AbnormalitiesAdminTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BafColors.background,
      child: ListView(
        padding: const EdgeInsets.all(BafSpacing.lg),
        children: [
          const _AdminAbnormalityHeader(),
          const SizedBox(height: BafSpacing.lg),
          _AdminAbnormalityActionCard(
            icon: Icons.rule_folder_outlined,
            title: 'Abnormality Types',
            subtitle:
                'Create and maintain the master list used while logging charge abnormalities. Includes RA coil-colour type.',
            color: BafColors.admin,
            actionLabel: 'Manage Types',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AbnormalityTypesScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: BafSpacing.md),
          _AdminAbnormalityActionCard(
            icon: Icons.analytics_rounded,
            title: 'Reports / Intelligence',
            subtitle:
                'Review recurrence, RA pending load, affected assets, severity mix and root-reason patterns.',
            color: BafColors.charges,
            actionLabel: 'Open Reports',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AbnormalityReportsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: BafSpacing.md),
          const _AdminAbnormalityPrincipleCard(),
        ],
      ),
    );
  }
}

class _AdminAbnormalityHeader extends StatelessWidget {
  const _AdminAbnormalityHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.navy,
        borderRadius: BorderRadius.circular(BafRadius.large),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(Icons.memory_rounded, color: Colors.white),
          ),
          const SizedBox(width: BafSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abnormality Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: BafSpacing.xs),
                Text(
                  'Master data and intelligence layer for charge abnormalities, RA traceability and recurrence memory.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAbnormalityActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  const _AdminAbnormalityActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: const BorderSide(color: BafColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.large),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAbnormalityPrincipleCard extends StatelessWidget {
  const _AdminAbnormalityPrincipleCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: BafColors.audit.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: BorderSide(color: BafColors.audit.withValues(alpha: 0.18)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business principle',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            SizedBox(height: BafSpacing.sm),
            Text(
              'An abnormality is operational memory, not merely a fault entry. RA due to coil colour must preserve old charge, new charge, base/assets, reason and possible root reason.',
              style: TextStyle(color: BafColors.textSecondary, height: 1.35),
            ),
          ],
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
