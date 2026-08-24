import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../auth/providers/auth_provider.dart';

import '../widgets/planned_job_workflow_panel.dart';
import 'compliance_inbox_screen.dart';
import 'equipment_status_board.dart';
import 'workflow_diagnostics_screen.dart';

/// Operational entry point for the lane/compliance/equipment control plane.
///
/// Visibility is intentionally broader than mutation authority: every approved
/// user may inspect the workflow, while each online command remains protected
/// by server-derived role checks.
class WorkflowHubScreen extends ConsumerWidget {
  final String? initialWorkflowId;

  const WorkflowHubScreen({super.key, this.initialWorkflowId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Maintenance workflow',
          subtitle: 'Lanes, obligations and equipment control',
          icon: Icons.account_tree_outlined,
          accent: BafColors.audit,
        ),
      ),
      body: actorAsync.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Checking workflow access',
              color: BafColors.audit,
            ),
        error:
            (_, _) => BafStatePanel.error(
              title: 'Workflow unavailable',
              message: 'Workflow access could not be verified.',
              onPrimary: () => ref.invalidate(currentAppUserProvider),
            ),
        data: (actor) {
          if (actor == null || !actor.isApproved) {
            return const BafStatePanel(
              icon: Icons.lock_outline_rounded,
              color: BafColors.danger,
              title: 'Approved access required',
              message:
                  'Sign in with an approved account to inspect maintenance workflow.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (initialWorkflowId != null &&
                  initialWorkflowId!.trim().isNotEmpty) ...[
                PlannedJobWorkflowPanel(
                  workflowId: initialWorkflowId!.trim(),
                  jobTerminal: false,
                ),
                const SizedBox(height: 12),
              ],
              _WorkflowHubCard(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Equipment Status',
                subtitle:
                    'In Service, Under Maintenance, Awaiting Preparation, Under RED and Available.',
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EquipmentStatusBoard(),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              _WorkflowHubCard(
                icon: Icons.inbox_outlined,
                title: 'Compliance Inbox',
                subtitle:
                    'Role-aware queue for obligations assigned to you, raised by you, and supervisory review.',
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComplianceInboxScreen(),
                      ),
                    ),
              ),
              if (actor.canViewMaintenanceWorkflowDiagnostics) ...[
                const SizedBox(height: 12),
                _WorkflowHubCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Workflow Diagnostics',
                  subtitle:
                      'Quarantined projection records and uncertain commands requiring support attention.',
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WorkflowDiagnosticsScreen(),
                        ),
                      ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkflowHubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WorkflowHubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
