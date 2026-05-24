// FILE: lib/features/admin/presentation/admin_data_browser.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../../features/maintenance/data/maintenance_model.dart';
import '../../../features/maintenance/providers/maintenance_provider.dart';
import '../../../features/maintenance/utils/asset_validator.dart';
import '../../../features/directives/data/operational_directive_model.dart';
import '../../../features/directives/providers/operational_directive_provider.dart';
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
import '../utils/admin_ticket_helpers.dart';

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
// TICKETS BROWSER (with search, edit, delete, and timeline invalidation)
// ============================================================================

Color _adminTicketStatusColor(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return BafColors.danger;
    case TicketStatus.acknowledged:
      return BafColors.warning;
    case TicketStatus.inProgress:
      return BafColors.planned;
    case TicketStatus.resolved:
      return BafColors.success;
  }
}

class _AdminDeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const _AdminDeleteDecision({this.reason, this.notes});
}

class _AdminDeleteReasonDialog extends StatefulWidget {
  final String title;
  final String message;

  const _AdminDeleteReasonDialog({required this.title, required this.message});

  @override
  State<_AdminDeleteReasonDialog> createState() =>
      _AdminDeleteReasonDialogState();
}

class _AdminDeleteReasonDialogState extends State<_AdminDeleteReasonDialog> {
  final TextEditingController _notesController = TextEditingController();
  AuditReason? _selectedReason;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.message),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<AuditReason>(
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                items:
                    AuditReason.values.map((reason) {
                      return DropdownMenuItem<AuditReason>(
                        value: reason,
                        child: Text(
                          reason.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _selectedReason = value),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed:
              () => Navigator.pop(
                context,
                _AdminDeleteDecision(
                  reason: _selectedReason,
                  notes: cleanAdminOptionalText(_notesController.text),
                ),
              ),
          child: const Text('Mark Deleted'),
        ),
      ],
    );
  }
}

class _AdminEditTicketDialog extends StatefulWidget {
  final MaintenanceRecord ticket;
  final String editedByUid;
  final String editedByName;

  const _AdminEditTicketDialog({
    required this.ticket,
    required this.editedByUid,
    required this.editedByName,
  });

  @override
  State<_AdminEditTicketDialog> createState() => _AdminEditTicketDialogState();
}

class _AdminEditTicketDialogState extends State<_AdminEditTicketDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _assetNumberController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _componentController;
  late final TextEditingController _tagController;
  late final TextEditingController _remarksController;

  late AssetType _selectedType;
  late RoutedTo _selectedRouted;
  late MaintenanceType _selectedMaintenanceType;
  late TicketStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _assetNumberController = TextEditingController(
      text: ticket.assetNumber.toString(),
    );
    _descriptionController = TextEditingController(text: ticket.description);
    _componentController = TextEditingController(text: ticket.component ?? '');
    _tagController = TextEditingController(text: ticket.tag ?? '');
    _remarksController = TextEditingController(text: ticket.remarks ?? '');
    _selectedType = ticket.assetType;
    _selectedRouted = ticket.routedTo;
    _selectedMaintenanceType = ticket.maintenanceType;
    _selectedStatus = ticket.status;
  }

  @override
  void dispose() {
    _assetNumberController.dispose();
    _descriptionController.dispose();
    _componentController.dispose();
    _tagController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Ticket'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AssetType>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Asset Type'),
                  items:
                      AssetType.values.map((type) {
                        return DropdownMenuItem<AssetType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _assetNumberController,
                  decoration: const InputDecoration(labelText: 'Asset Number'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final raw = value?.trim();
                    if (raw == null || raw.isEmpty) {
                      return 'Required';
                    }
                    if (int.tryParse(raw) == null) {
                      return 'Enter a valid whole number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RoutedTo>(
                  initialValue: _selectedRouted,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Route To'),
                  items:
                      RoutedTo.values.map((route) {
                        return DropdownMenuItem<RoutedTo>(
                          value: route,
                          child: Text(route.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedRouted = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<MaintenanceType>(
                  initialValue: _selectedMaintenanceType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance Type',
                  ),
                  items:
                      MaintenanceType.values.map((type) {
                        return DropdownMenuItem<MaintenanceType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedMaintenanceType = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<TicketStatus>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      TicketStatus.values.map((status) {
                        return DropdownMenuItem<TicketStatus>(
                          value: status,
                          child: Text(status.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedStatus = value);
                  },
                ),
                if (_selectedStatus == TicketStatus.resolved &&
                    !widget.ticket.isResolved) ...[
                  const SizedBox(height: BafSpacing.sm),
                  const Text(
                    'Saving as resolved will stamp this ticket with the current admin identity and current time if closure fields are missing.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _componentController,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Tag (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.pop(
              context,
              copyTicketForAdminEdit(
                source: widget.ticket,
                assetType: _selectedType,
                assetNumber: int.parse(_assetNumberController.text.trim()),
                description: _descriptionController.text.trim(),
                routedTo: _selectedRouted,
                maintenanceType: _selectedMaintenanceType,
                status: _selectedStatus,
                component: cleanAdminOptionalText(_componentController.text),
                tag: cleanAdminTagText(_tagController.text),
                remarks: cleanAdminOptionalText(_remarksController.text),
                editedByUid: widget.editedByUid,
                editedByName: widget.editedByName,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AdminEditDirectiveDialog extends StatefulWidget {
  final OperationalDirective directive;

  const _AdminEditDirectiveDialog({required this.directive});

  @override
  State<_AdminEditDirectiveDialog> createState() =>
      _AdminEditDirectiveDialogState();
}

class _AdminEditDirectiveDialogState extends State<_AdminEditDirectiveDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _remarksController;
  late final TextEditingController _assetNumberController;
  late final TextEditingController _componentController;
  late final TextEditingController _subsystemController;
  late final TextEditingController _tagController;

  late AppRole _selectedRole;
  AssetType? _selectedAssetType;

  @override
  void initState() {
    super.initState();
    final directive = widget.directive;
    _titleController = TextEditingController(text: directive.title);
    _descriptionController = TextEditingController(text: directive.description);
    _remarksController = TextEditingController(text: directive.remarks ?? '');
    _assetNumberController = TextEditingController(
      text: directive.assetNumber?.toString() ?? '',
    );
    _componentController = TextEditingController(
      text: directive.component ?? '',
    );
    _subsystemController = TextEditingController(
      text: directive.subsystem ?? '',
    );
    _tagController = TextEditingController(text: directive.tag ?? '');
    _selectedRole = directive.directedTo;
    _selectedAssetType = directive.assetType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _remarksController.dispose();
    _assetNumberController.dispose();
    _componentController.dispose();
    _subsystemController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Directive'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<AppRole>(
                  initialValue: _selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Directed To'),
                  items:
                      AppRole.values.map((role) {
                        return DropdownMenuItem<AppRole>(
                          value: role,
                          child: Text(role.name),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedRole = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<AssetType?>(
                  initialValue: _selectedAssetType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Asset Type'),
                  items: [
                    const DropdownMenuItem<AssetType?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...AssetType.values.map(
                      (type) => DropdownMenuItem<AssetType?>(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAssetType = value;
                      if (value == null) {
                        _assetNumberController.clear();
                      }
                    });
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _assetNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Asset Number (required if type selected)',
                  ),
                  keyboardType: TextInputType.number,
                  enabled: _selectedAssetType != null,
                  validator: (value) {
                    if (_selectedAssetType == null) {
                      return null;
                    }
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Asset number is required when type is selected';
                    }
                    final number = int.tryParse(text);
                    if (number == null) {
                      return 'Invalid number';
                    }
                    if (!AssetValidator.isValid(_selectedAssetType!, number)) {
                      return AssetValidator.getValidationMessage(
                        _selectedAssetType!,
                        number,
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _componentController,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _subsystemController,
                  decoration: const InputDecoration(
                    labelText: 'Subsystem (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Tag (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            final updated =
                copyOperationalDirective(widget.directive)
                  ..title = _titleController.text.trim()
                  ..description = _descriptionController.text.trim()
                  ..directedTo = _selectedRole
                  ..assetType = _selectedAssetType
                  ..assetNumber =
                      _selectedAssetType == null
                          ? null
                          : int.parse(_assetNumberController.text.trim())
                  ..component = cleanAdminOptionalText(
                    _componentController.text,
                  )
                  ..subsystem = cleanAdminOptionalText(
                    _subsystemController.text,
                  )
                  ..tag = cleanAdminTagText(_tagController.text)
                  ..remarks = cleanAdminOptionalText(_remarksController.text);
            Navigator.pop(context, updated);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

void _showAdminDataSnack(BuildContext context, String message, {Color? color}) {
  if (!context.mounted) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: color),
  );
}

class TicketsBrowser extends ConsumerStatefulWidget {
  const TicketsBrowser({super.key});

  @override
  ConsumerState<TicketsBrowser> createState() => _TicketsBrowserState();
}

class _TicketsBrowserState extends ConsumerState<TicketsBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminTicketsStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search by asset number, description, tag, or component',
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
              onChanged:
                  (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (tickets) {
                final filtered =
                    tickets.where((t) {
                      if (_searchQuery.isEmpty) return true;
                      return t.assetNumber.toString().contains(_searchQuery) ||
                          t.description.toLowerCase().contains(_searchQuery) ||
                          (t.tag?.toLowerCase().contains(_searchQuery) ??
                              false) ||
                          (t.component?.toLowerCase().contains(_searchQuery) ??
                              false);
                    }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tickets match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) => _TicketCard(ticket: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  final MaintenanceRecord ticket;
  const _TicketCard({required this.ticket});

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final statusColor = _adminTicketStatusColor(ticket.status);

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
        title: Text(
          '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber} – ${ticket.description}',
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Text(
            'Logged: ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt)} | By: ${ticket.loggedByName ?? ticket.reportedBy ?? 'Unknown'}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        leading: Container(
          width: 10,
          height: 42,
          decoration: BoxDecoration(
            color: ticket.isDeleted ? BafColors.textSecondary : statusColor,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                ticket.isDeleted ? 'DELETED' : ticket.status.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              backgroundColor:
                  ticket.isDeleted ? BafColors.textSecondary : statusColor,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: BafSpacing.xs),
            IconButton(
              tooltip: 'Edit ticket',
              icon: const Icon(Icons.edit, color: BafColors.planned),
              onPressed: () => _showEditDialog(ticket),
            ),
            if (!ticket.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(ticket),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(MaintenanceRecord ticket) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final updatedTicket = await showDialog<MaintenanceRecord>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _AdminEditTicketDialog(
            ticket: ticket,
            editedByUid: appUser.uid,
            editedByName: appUser.name,
          ),
    );
    if (!mounted || updatedTicket == null) return;

    try {
      if (!appUser.canAdminEditMaintenanceTicket) {
        throw StateError('Admin authority required to edit tickets.');
      }
      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.updateTicket(updatedTicket, actor: appUser);

      unawaited(
        syncCoordinator.runFullSync(reason: 'admin_ticket_edited', force: true),
      );

      if (!mounted) return;
      _showAdminDataSnack(context, 'Ticket updated');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(context, 'Save failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _confirmDelete(MaintenanceRecord ticket) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<_AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const _AdminDeleteReasonDialog(
            title: 'Mark Ticket as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? ticket.firestoreId : ticket.id;
    if (id == null) {
      _showAdminDataSnack(context, 'Ticket is missing its sync identifier.');
      return;
    }

    try {
      if (!appUser.canSoftDeleteMaintenanceTicket) {
        throw StateError('Admin authority required to delete tickets.');
      }
      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteTicket(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: ticket.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_ticket_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      _showAdminDataSnack(context, 'Ticket marked as deleted');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(
        context,
        'Delete failed: $e',
        color: BafColors.danger,
      );
    }
  }
}

// ============================================================================
// DIRECTIVES BROWSER (with search, edit, delete)
// ============================================================================

class DirectivesBrowser extends ConsumerStatefulWidget {
  const DirectivesBrowser({super.key});

  @override
  ConsumerState<DirectivesBrowser> createState() => _DirectivesBrowserState();
}

class _DirectivesBrowserState extends ConsumerState<DirectivesBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final directivesAsync = ref.watch(adminDirectivesStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search title, target, asset, component, tag, issuer, or remarks',
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
            child: directivesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (directives) {
                final filtered = directives.where(_matchesSearch).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No directives match.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.md,
                    BafSpacing.sm,
                    BafSpacing.md,
                    BafSpacing.xl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: BafSpacing.sm),
                  itemBuilder:
                      (ctx, idx) => _DirectiveCard(directive: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(OperationalDirective directive) {
    if (_searchQuery.isEmpty) return true;

    final haystack =
        [
          directive.title,
          directive.description,
          directive.directedTo.name,
          directive.status.name,
          directive.priority.name,
          directive.assetType?.name,
          directive.assetNumber?.toString(),
          directive.component,
          directive.subsystem,
          directive.tag,
          directive.hierarchyPath?.join(' '),
          directiveOwnerName(directive),
          directive.remarks,
        ].whereType<String>().join(' ').toLowerCase();

    return haystack.contains(_searchQuery);
  }
}

class _DirectiveCard extends ConsumerStatefulWidget {
  final OperationalDirective directive;

  const _DirectiveCard({required this.directive});

  @override
  ConsumerState<_DirectiveCard> createState() => _DirectiveCardState();
}

class _DirectiveCardState extends ConsumerState<_DirectiveCard> {
  @override
  Widget build(BuildContext context) {
    final d = widget.directive;
    final statusColor = _statusColor(d.status);

    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(Icons.assignment_late_rounded, color: statusColor),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        d.title,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BafSpacing.sm,
                        vertical: BafSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        d.status.name.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'To: ${_roleLabel(d.directedTo)} · Issued: ${DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt)}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'By ${directiveOwnerName(d) ?? 'Unknown'}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (d.assetType != null ||
                    d.component != null ||
                    d.tag != null) ...[
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.sm,
                    children: [
                      if (d.assetType != null)
                        _MiniChip(
                          label:
                              '${_assetTypeLabel(d.assetType!)} ${d.assetNumber ?? ''}'
                                  .trim(),
                          color: BafColors.assets,
                        ),
                      if (d.component != null)
                        _MiniChip(
                          label: d.component!,
                          color: BafColors.planned,
                        ),
                      if (d.tag != null)
                        _MiniChip(label: d.tag!, color: BafColors.audit),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit directive',
                icon: const Icon(Icons.edit_rounded, color: BafColors.assets),
                onPressed: () => _showEditDialog(d),
              ),
              if (!d.isDeleted)
                IconButton(
                  tooltip: 'Mark directive deleted',
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: BafColors.danger,
                  ),
                  onPressed: () => _confirmDelete(d),
                )
              else
                const _MiniChip(label: 'DELETED', color: BafColors.admin),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.si:
        return 'SI';
      case AppRole.contractSupervisor:
        return 'Contract Supervisor';
      case AppRole.shiftSupervisor:
        return 'Shift Supervisor';
      case AppRole.seniorElectrical:
        return 'Sr. Electrical';
      case AppRole.seniorMechanical:
        return 'Sr. Mechanical';
      case AppRole.seniorInstrumentation:
        return 'Sr. I&A';
      case AppRole.seniorRefractory:
        return 'Sr. Refractory';
      case AppRole.refractory:
        return 'Refractory';
      case AppRole.operations:
        return 'Operations';
      case AppRole.admin:
        return 'Admin';
    }
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCE COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
    }
  }

  Color _statusColor(DirectiveStatus status) {
    switch (status) {
      case DirectiveStatus.open:
        return BafColors.warning;
      case DirectiveStatus.acknowledged:
        return BafColors.planned;
      case DirectiveStatus.closed:
        return BafColors.sync;
    }
  }

  Future<void> _showEditDialog(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final updated = await showDialog<OperationalDirective>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminEditDirectiveDialog(directive: directive),
    );
    if (!mounted || updated == null) return;

    try {
      final repository = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.updateDirective(updated, actor: appUser);

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_directive_edited',
          force: true,
        ),
      );

      if (!mounted) return;
      _showAdminDataSnack(context, 'Directive updated');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(context, 'Save failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _confirmDelete(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Please try again.',
        color: BafColors.warning,
      );
      return;
    }

    if (!appUser.canDeleteDirective) {
      _showAdminDataSnack(
        context,
        'Only Admin can delete directives.',
        color: BafColors.danger,
      );
      return;
    }

    final decision = await showDialog<_AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const _AdminDeleteReasonDialog(
            title: 'Mark Directive as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? directive.firestoreId : directive.id;
    if (id == null) {
      _showAdminDataSnack(
        context,
        'Directive is missing its sync identifier.',
        color: BafColors.warning,
      );
      return;
    }

    try {
      final repository = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteDirective(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: directive.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_directive_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      _showAdminDataSnack(context, 'Directive marked as deleted');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(
        context,
        'Delete failed: $e',
        color: BafColors.danger,
      );
    }
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.sm,
        vertical: BafSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
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
                  _AdminChip(
                    label: '$fieldCount fields',
                    color: BafColors.planned,
                  ),
                  if (scopeLabel != null)
                    _AdminChip(label: scopeLabel, color: BafColors.assets),
                  if (template.isDeprecated)
                    const _AdminChip(
                      label: 'DEPRECATED',
                      color: BafColors.warning,
                    ),
                  if (template.isDeleted)
                    const _AdminChip(
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
              const _AdminChip(
                label: 'DELETED',
                color: BafColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobTemplate template) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<_AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const _AdminDeleteReasonDialog(
            title: 'Mark Template as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? template.firestoreId : template.id;
    if (id == null) {
      _showAdminDataSnack(
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
      _showAdminDataSnack(context, 'Template marked as deleted');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(
        context,
        'Delete failed: $e',
        color: BafColors.danger,
      );
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
                  _AdminChip(label: statusLabel, color: statusColor),
                  _AdminChip(
                    label:
                        'Assigned ${DateFormat('dd MMM yyyy').format(execution.createdAt)}',
                    color: BafColors.planned,
                  ),
                  if (execution.completedAt != null)
                    _AdminChip(
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
              const _AdminChip(
                label: 'DELETED',
                color: BafColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobExecution execution) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      _showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<_AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const _AdminDeleteReasonDialog(
            title: 'Mark Execution as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? execution.firestoreId : execution.id;
    if (id == null) {
      _showAdminDataSnack(
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
      _showAdminDataSnack(context, 'Execution marked as deleted');
    } catch (e) {
      if (!mounted) return;
      _showAdminDataSnack(
        context,
        'Delete failed: $e',
        color: BafColors.danger,
      );
    }
  }
}

class _AdminChip extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
