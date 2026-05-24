// FILE: lib/features/planned_maintenance/presentation/template_detail_screen.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../audit/models/audit_event_model.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import 'assign_job_screen.dart';
import 'job_history_screen.dart';
import 'template_designer_screen.dart';

class TemplateDetailScreen extends ConsumerWidget {
  final JobTemplate template;

  const TemplateDetailScreen({super.key, required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAppUserProvider);
    final appUser = userAsync.maybeWhen(
      data: (user) => user,
      orElse: () => null,
    );
    final canAssignJob = appUser?.canAssignJobExecution ?? false;
    final canEditTemplate = appUser?.canEditLegacyJobTemplate ?? false;
    final canDeleteTemplate = appUser?.canDeleteLegacyJobTemplate ?? false;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Template Details'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.xl,
        ),
        children: [
          _TemplateSummaryCard(template: template),
          const SizedBox(height: BafSpacing.lg),
          _FieldsPreviewCard(template: template),
          const SizedBox(height: BafSpacing.lg),
          const _SectionTitle(
            title: 'Actions',
            subtitle: 'Assign work, review history, or manage this template.',
          ),
          const SizedBox(height: 10),
          if (canAssignJob) ...[
            _ActionTile(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Assign Job',
              subtitle: 'Create a new job execution for a specific asset.',
              color: BafColors.planned,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignJobScreen(template: template),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          _ActionTile(
            icon: Icons.history_rounded,
            label: 'View History',
            subtitle: 'See all completed executions of this job.',
            color: BafColors.charges,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobHistoryScreen(template: template),
                ),
              );
            },
          ),
          if (canEditTemplate || canDeleteTemplate) ...[
            const SizedBox(height: 10),
            if (canEditTemplate) ...[
              _ActionTile(
                icon: Icons.edit_note_rounded,
                label: 'Edit Template',
                subtitle: 'Modify fields, structure, and template details.',
                color: BafColors.warning,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => TemplateDesignerScreen(template: template),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            if (canDeleteTemplate)
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Template',
                subtitle:
                    'Hide from active records while preserving audit trail.',
                color: BafColors.danger,
                onTap: () => _confirmDelete(context, ref),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.canDeleteLegacyJobTemplate) {
      _showTemplateDetailSnack(
        context,
        'Only Admin can delete legacy job templates.',
        color: BafColors.danger,
      );
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    final actorUid = appUser.uid;
    final actorName =
        _cleanOptionalText(appUser.name) ??
        _cleanOptionalText(firebaseUser?.displayName) ??
        _cleanOptionalText(firebaseUser?.email);

    final decision = await showDialog<_TemplateDeleteDecision>(
      context: context,
      builder: (_) => const _TemplateDeleteDialog(),
    );

    if (!context.mounted || decision == null) {
      return;
    }

    final dynamic id = kIsWeb ? template.firestoreId : template.id;
    if (id == null) {
      _showTemplateDetailSnack(context, 'Template ID is missing');
      return;
    }

    try {
      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteTemplate(
            id,
            actor: appUser,
            auditContext: AuditContext(
              performedByUid: actorUid,
              performedByName: actorName,
              reason: decision.reason,
              reasonNotes: decision.notes,
              before: template.toAuditMap(),
            ),
          );

      unawaited(
        syncCoordinator.runFullSync(reason: 'template_deleted', force: true),
      );

      if (!context.mounted) {
        return;
      }

      _showTemplateDetailSnack(
        context,
        'Template marked as deleted',
        color: BafColors.sync,
      );

      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      _showTemplateDetailSnack(
        context,
        'Delete failed: $e',
        color: BafColors.danger,
      );
    }
  }
}

void _showTemplateDetailSnack(
  BuildContext context,
  String message, {
  Color? color,
}) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
}

class _TemplateDeleteDecision {
  final AuditReason? reason;
  final String? notes;

  const _TemplateDeleteDecision({this.reason, this.notes});
}

class _TemplateDeleteDialog extends StatefulWidget {
  const _TemplateDeleteDialog();

  @override
  State<_TemplateDeleteDialog> createState() => _TemplateDeleteDialogState();
}

class _TemplateDeleteDialogState extends State<_TemplateDeleteDialog> {
  final _reasonController = TextEditingController();
  AuditReason? _selectedReason;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Template'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will hide the template from active records while retaining it for audit and recovery.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
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
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _selectedReason = value),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reasonController,
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
                _TemplateDeleteDecision(
                  reason: _selectedReason,
                  notes: _cleanOptionalText(_reasonController.text),
                ),
              ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _TemplateSummaryCard extends StatelessWidget {
  final JobTemplate template;

  const _TemplateSummaryCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: BafColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: BafColors.planned,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  template.jobName,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ),
            ],
          ),
          if (template.description != null &&
              template.description!.trim().isNotEmpty) ...[
            const SizedBox(height: BafSpacing.md),
            Text(
              template.description!.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: template.applicableAssetType.name.toUpperCase(),
                color: BafColors.assets,
                icon: Icons.precision_manufacturing_rounded,
              ),
              StatusBadge(
                label: '${template.parsedFields.length} fields',
                color: BafColors.planned,
                icon: Icons.list_alt_rounded,
              ),
              ...template.assignedAgencies.map(
                (agency) => StatusBadge(
                  label: agency.toUpperCase(),
                  color: _agencyColor(agency),
                ),
              ),
            ],
          ),
          if (template.createdByName != null &&
              template.createdByName!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Created by ${template.createdByName}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldsPreviewCard extends StatelessWidget {
  final JobTemplate template;

  const _FieldsPreviewCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final fields = template.parsedFields;

    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Template fields',
            subtitle:
                'Checklist and response fields captured during completion.',
          ),
          const SizedBox(height: BafSpacing.md),
          if (fields.isEmpty)
            const Text(
              'No custom fields configured.',
              style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
            )
          else
            ...fields.take(8).map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      _fieldIcon(field.type),
                      size: 18,
                      color: BafColors.planned,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (field.isRequired)
                      const StatusBadge(
                        label: 'Required',
                        color: BafColors.warning,
                      ),
                  ],
                ),
              );
            }),
          if (fields.length > 8) ...[
            const SizedBox(height: 4),
            Text(
              '+${fields.length - 8} more fields',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.large),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
            color: BafColors.card,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: BafColors.textSecondary,
              ),
            ],
          ),
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
        const Icon(Icons.tune_rounded, size: 20, color: BafColors.planned),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
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

String? _cleanOptionalText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

IconData _fieldIcon(FieldType type) {
  switch (type) {
    case FieldType.text:
      return Icons.short_text_rounded;
    case FieldType.longText:
      return Icons.notes_rounded;
    case FieldType.number:
      return Icons.pin_rounded;
    case FieldType.yesNo:
      return Icons.toggle_on_rounded;
    case FieldType.checkbox:
      return Icons.check_box_rounded;
    case FieldType.dropdown:
      return Icons.arrow_drop_down_circle_rounded;
    case FieldType.multiSelect:
      return Icons.checklist_rounded;
    case FieldType.dateTime:
      return Icons.event_rounded;
    case FieldType.sectionHeader:
      return Icons.title_rounded;
    case FieldType.instruction:
      return Icons.info_rounded;
  }
}

Color _agencyColor(String agency) {
  switch (agency) {
    case 'operations':
      return BafColors.sync;
    case 'electrical':
      return const Color(0xFFF59E0B);
    case 'mechanical':
      return BafColors.planned;
    case 'instrumentation':
      return BafColors.audit;
    case 'refractory':
      return BafColors.directives;
    case 'emd':
      return BafColors.assets;
    case 'shiftInCharge':
      return BafColors.charges;
    case 'others':
      return BafColors.admin;
    default:
      return BafColors.admin;
  }
}
