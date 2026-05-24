import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../../features/planned_maintenance/data/job_template_model.dart';
import '../../../features/planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../../features/planned_maintenance/presentation/template_publisher_screen.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../features/audit/models/audit_event_model.dart';
import '../../../features/audit/presentation/audit_timeline_screen.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import 'user_management_screen.dart';
import 'local_diagnostics_screen.dart';
import '../../abnormalities/presentation/abnormality_types_screen.dart';
import '../../abnormalities/presentation/abnormality_reports_screen.dart';
import '../providers/admin_stream_providers.dart';
import '../utils/admin_search_sort_helpers.dart';
import 'admin_data_browser/admin_data_browser_shared.dart';
import 'admin_data_browser/admin_delete_reason_dialog.dart';
import 'admin_data_browser/admin_tickets_browser.dart';
import 'admin_data_browser/admin_directives_browser.dart';

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

// ============================================================================
// TEMPLATES BROWSER (delete only – no edit)
// ============================================================================

class TemplatesBrowser extends ConsumerStatefulWidget {
  const TemplatesBrowser({super.key});

  @override
  ConsumerState<TemplatesBrowser> createState() => _TemplatesBrowserState();
}

class _TemplatesBrowserState extends ConsumerState<TemplatesBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(adminTemplatesStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search by job name, asset type, agency, or component',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: BafColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (templates) {
                final filtered =
                    templates
                        .where(
                          (template) => templateMatchesAdminSearch(
                            template,
                            _searchQuery,
                          ),
                        )
                        .toList()
                      ..sort(compareTemplatesForAdmin);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No templates match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder:
                      (ctx, idx) => _TemplateCard(template: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends ConsumerStatefulWidget {
  final JobTemplate template;

  const _TemplateCard({required this.template});

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final fieldCount = template.parsedFields.length;
    final scopeLabel = templateScopeLabel(template);

    return Card(
      color: BafColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 46,
          decoration: BoxDecoration(
            color:
                template.isDeleted
                    ? BafColors.textSecondary
                    : BafColors.planned,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        title: Text(
          template.jobName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${template.applicableAssetType.name.toUpperCase()} | ${formatAgencyList(template.assignedAgencies)}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  AdminChip(
                    label: '$fieldCount fields',
                    color: BafColors.planned,
                  ),
                  if (scopeLabel != null)
                    AdminChip(label: scopeLabel, color: BafColors.assets),
                  if (template.isDeprecated)
                    const AdminChip(
                      label: 'DEPRECATED',
                      color: BafColors.warning,
                    ),
                  if (template.isDeleted)
                    const AdminChip(
                      label: 'DELETED',
                      color: BafColors.textSecondary,
                    ),
                ],
              ),
              if (template.createdByName != null &&
                  template.createdByName!.trim().isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'Created by ${template.createdByName!.trim()} • ${DateFormat('dd MMM yyyy, HH:mm').format(template.createdAt)}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!template.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(template),
              )
            else
              const AdminChip(label: 'DELETED', color: BafColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobTemplate template) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const AdminDeleteReasonDialog(
            title: 'Mark Template as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? template.firestoreId : template.id;
    if (id == null) {
      showAdminDataSnack(
        context,
        'Template ID is missing',
        color: BafColors.warning,
      );
      return;
    }

    try {
      if (!appUser.canDeleteLegacyJobTemplate) {
        throw StateError(
          'Admin authority required to delete legacy templates.',
        );
      }
      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteTemplate(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: template.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_template_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Template marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}

// ============================================================================
// EXECUTIONS BROWSER (delete only – no edit)
// ============================================================================

class ExecutionsBrowser extends ConsumerStatefulWidget {
  const ExecutionsBrowser({super.key});

  @override
  ConsumerState<ExecutionsBrowser> createState() => _ExecutionsBrowserState();
}

class _ExecutionsBrowserState extends ConsumerState<ExecutionsBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final executionsAsync = ref.watch(adminExecutionsStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by job, asset, agency, status, or remarks',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: BafColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: executionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (executions) {
                final filtered =
                    executions
                        .where(
                          (execution) => executionMatchesAdminSearch(
                            execution,
                            _searchQuery,
                          ),
                        )
                        .toList()
                      ..sort(compareExecutionsForAdmin);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No executions match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder:
                      (ctx, idx) => _ExecutionCard(execution: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionCard extends ConsumerStatefulWidget {
  final JobExecution execution;

  const _ExecutionCard({required this.execution});

  @override
  ConsumerState<_ExecutionCard> createState() => _ExecutionCardState();
}

class _ExecutionCardState extends ConsumerState<_ExecutionCard> {
  @override
  Widget build(BuildContext context) {
    final execution = widget.execution;
    final statusColor =
        execution.isDeleted
            ? BafColors.textSecondary
            : execution.isCompleted
            ? BafColors.success
            : BafColors.warning;
    final statusLabel =
        execution.isDeleted
            ? 'DELETED'
            : execution.isCompleted
            ? 'COMPLETED'
            : 'OPEN';

    return Card(
      color: BafColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 46,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        title: Text(
          execution.templateName ?? 'Unnamed Job',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${execution.assetType.name.toUpperCase()} ${execution.assetNumber} | ${formatAgencyList(execution.assignedAgencies)}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  AdminChip(label: statusLabel, color: statusColor),
                  AdminChip(
                    label:
                        'Assigned ${DateFormat('dd MMM yyyy').format(execution.createdAt)}',
                    color: BafColors.planned,
                  ),
                  if (execution.completedAt != null)
                    AdminChip(
                      label:
                          'Done ${DateFormat('dd MMM yyyy').format(execution.completedAt!)}',
                      color: BafColors.success,
                    ),
                ],
              ),
              if (execution.assignedByName != null &&
                  execution.assignedByName!.trim().isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'Assigned by ${execution.assignedByName!.trim()}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!execution.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(execution),
              )
            else
              const AdminChip(label: 'DELETED', color: BafColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobExecution execution) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const AdminDeleteReasonDialog(
            title: 'Mark Execution as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? execution.firestoreId : execution.id;
    if (id == null) {
      showAdminDataSnack(
        context,
        'Execution does not have a valid local/remote id.',
        color: BafColors.warning,
      );
      return;
    }

    try {
      if (!appUser.canDeleteJobExecution) {
        throw StateError(
          'Admin authority required to delete planned job executions.',
        );
      }
      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteExecution(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: execution.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_execution_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Execution marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
