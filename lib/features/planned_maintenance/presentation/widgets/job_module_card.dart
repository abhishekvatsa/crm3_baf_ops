// FILE: lib/features/planned_maintenance/presentation/widgets/job_module_card.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../data/job_module_model.dart';
import '../../domain/runtime_module_lineage.dart';

/// Compact dossier/workspace card for one JobModuleInstance.
///
/// This widget is intentionally presentation-only. It does not save, submit,
/// reopen, or mutate module data. Those workflows belong in module detail
/// screens and provider actions.
class JobModuleCard extends StatelessWidget {
  final JobModuleInstance module;
  final VoidCallback? onTap;

  const JobModuleCard({super.key, required this.module, this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(module.status);
    final synced = module.isSynced;
    final responseCount = module.responses.length;
    final actionCount = module.actions.length;
    final hasPendingIssue = _text(module.pendingIssue) != null;
    final needsClosureEvidence =
        module.requiredForClosure && responseCount == 0;
    final hasFollowUp = module.requiresFollowUp || hasPendingIssue;
    final lineage = RuntimeModuleLineageInfo.fromModule(module);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: BafSpacing.md),
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color: BafColors.background,
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(
              color: _borderColor(
                statusColor: statusColor,
                needsClosureEvidence: needsClosureEvidence,
                hasFollowUp: hasFollowUp,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _statusIcon(module.status),
                      color: statusColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(module),
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle(module),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: BafSpacing.xs),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: BafColors.textSecondary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge(
                    label: _statusLabel(module.status),
                    color: statusColor,
                  ),
                  StatusBadge(
                    label: _disciplineLabel(module.discipline),
                    color: _disciplineColor(module.discipline),
                  ),
                  StatusBadge(
                    label: _useModeLabel(module.useMode),
                    color: BafColors.planned,
                  ),
                  StatusBadge(
                    label: lineage.badgeLabel,
                    color: _lineageColor(lineage.source),
                    icon: _lineageIcon(lineage.source),
                  ),
                  StatusBadge(
                    label: _safetyLabel(module.safetyClass),
                    color: _safetyColor(module.safetyClass),
                    icon: Icons.health_and_safety_rounded,
                  ),
                  if (module.requiredForClosure)
                    const StatusBadge(
                      label: 'Closure-critical',
                      color: BafColors.danger,
                      icon: Icons.lock_rounded,
                    ),
                  if (module.requiresFollowUp)
                    const StatusBadge(
                      label: 'Follow-up',
                      color: BafColors.warning,
                      icon: Icons.flag_rounded,
                    ),
                  StatusBadge(
                    label: synced ? 'Remote-backed / synced' : 'Saved locally',
                    color: synced ? BafColors.sync : BafColors.warning,
                    icon:
                        synced
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_rounded,
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              _InlineDetail(
                icon: _lineageIcon(lineage.source),
                label: 'Source',
                value: lineage.summary,
                color: _lineageColor(lineage.source),
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ModuleMetricPill(
                    icon: Icons.fact_check_rounded,
                    label:
                        '$responseCount structured response${responseCount == 1 ? '' : 's'}',
                    color:
                        responseCount > 0
                            ? BafColors.sync
                            : BafColors.textSecondary,
                  ),
                  _ModuleMetricPill(
                    icon: Icons.build_circle_rounded,
                    label: '$actionCount action${actionCount == 1 ? '' : 's'}',
                    color:
                        actionCount > 0
                            ? BafColors.planned
                            : BafColors.textSecondary,
                  ),
                  if (_lifecycleActorLine(module) != null)
                    _ModuleMetricPill(
                      icon: _lifecycleIcon(module.status),
                      label: _lifecycleActorLine(module)!,
                      color: statusColor,
                    ),
                ],
              ),
              if (needsClosureEvidence || hasFollowUp) ...[
                const SizedBox(height: BafSpacing.sm),
                if (needsClosureEvidence)
                  const _ModuleAttentionBox(
                    icon: Icons.assignment_late_rounded,
                    text:
                        'Closure-critical module has no structured responses yet. Capture evidence before final closure review.',
                    color: BafColors.danger,
                  ),
                if (hasFollowUp)
                  _ModuleAttentionBox(
                    icon: Icons.flag_rounded,
                    text:
                        _text(module.pendingIssue) ??
                        'Follow-up is marked for this module.',
                    color: BafColors.warning,
                  ),
              ],
              if (_hasText(module.procedureRefs) ||
                  _hasText(module.targetRefs) ||
                  _text(module.notApplicableReason) != null ||
                  _text(module.reopenReason) != null) ...[
                const SizedBox(height: BafSpacing.sm),
                if (_hasText(module.procedureRefs))
                  _InlineDetail(
                    icon: Icons.description_rounded,
                    label: 'Procedure',
                    value: module.procedureRefs.join(', '),
                  ),
                if (_hasText(module.targetRefs))
                  _InlineDetail(
                    icon: Icons.local_offer_rounded,
                    label: 'Targets',
                    value: module.targetRefs.join(', '),
                  ),
                if (_text(module.notApplicableReason) != null)
                  _InlineDetail(
                    icon: Icons.block_rounded,
                    label: 'N/A reason',
                    value: _text(module.notApplicableReason)!,
                    color: BafColors.textSecondary,
                  ),
                if (_text(module.reopenReason) != null)
                  _InlineDetail(
                    icon: Icons.replay_rounded,
                    label: 'Reopen reason',
                    value: _text(module.reopenReason)!,
                    color: BafColors.danger,
                  ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: BafSpacing.sm),
                const Text(
                  'Tap to open module workspace',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Color _borderColor({
    required Color statusColor,
    required bool needsClosureEvidence,
    required bool hasFollowUp,
  }) {
    if (needsClosureEvidence) return BafColors.danger.withValues(alpha: 0.45);
    if (hasFollowUp) return BafColors.warning.withValues(alpha: 0.45);
    return statusColor.withValues(alpha: 0.22);
  }

  static String _title(JobModuleInstance module) {
    final code = _text(module.moduleCode);
    if (code == null) return module.moduleTitle.trim();
    return '$code - ${module.moduleTitle.trim()}';
  }

  static String _subtitle(JobModuleInstance module) {
    final parts = <String>[
      if (_text(module.functionalSection) != null)
        _text(module.functionalSection)!,
      if (_text(module.componentGroup) != null) _text(module.componentGroup)!,
    ];
    return parts.isEmpty ? 'Process module' : parts.join(' • ');
  }

  static bool _hasText(List<String> values) =>
      values.any((value) => value.trim().isNotEmpty);

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _lifecycleActorLine(JobModuleInstance module) {
    switch (module.status) {
      case JobModuleStatus.submitted:
        return _actorWithTime(
          'Submitted',
          module.submittedByName,
          module.submittedAt,
        );
      case JobModuleStatus.accepted:
        return _actorWithTime(
          'Accepted',
          module.acceptedByName,
          module.acceptedAt,
        );
      case JobModuleStatus.reopened:
        return _actorWithTime(
          'Reopened',
          module.reopenedByName,
          module.reopenedAt,
        );
      case JobModuleStatus.notApplicable:
        return _actorWithTime(
          'N/A',
          module.notApplicableByName,
          module.notApplicableAt,
        );
      case JobModuleStatus.notStarted:
      case JobModuleStatus.inProgress:
      case JobModuleStatus.draftSaved:
        return null;
    }
  }

  static String? _actorWithTime(String prefix, String? actor, DateTime? at) {
    final cleanActor = _text(actor);
    final time = _formatCompactDateTime(at);
    if (cleanActor == null && time == null) return prefix;
    if (cleanActor != null && time != null) {
      return '$prefix by $cleanActor • $time';
    }
    if (cleanActor != null) return '$prefix by $cleanActor';
    return '$prefix • $time';
  }

  static String? _formatCompactDateTime(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }
}

class _ModuleMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ModuleMetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleAttentionBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ModuleAttentionBox({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.small),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InlineDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.color = BafColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _lineageColor(RuntimeModuleLineageSource source) {
  switch (source) {
    case RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd:
    case RuntimeModuleLineageSource.publishedTemplateVersionModule:
      return BafColors.sync;
    case RuntimeModuleLineageSource.emergencyManualSeed:
    case RuntimeModuleLineageSource.manualRuntimeAdd:
      return BafColors.warning;
    case RuntimeModuleLineageSource.legacyOrManual:
      return BafColors.textSecondary;
  }
}

IconData _lineageIcon(RuntimeModuleLineageSource source) {
  switch (source) {
    case RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd:
    case RuntimeModuleLineageSource.publishedTemplateVersionModule:
      return Icons.verified_rounded;
    case RuntimeModuleLineageSource.emergencyManualSeed:
      return Icons.warning_amber_rounded;
    case RuntimeModuleLineageSource.manualRuntimeAdd:
      return Icons.edit_note_rounded;
    case RuntimeModuleLineageSource.legacyOrManual:
      return Icons.history_rounded;
  }
}

Color _statusColor(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return BafColors.admin;
    case JobModuleStatus.inProgress:
    case JobModuleStatus.draftSaved:
      return BafColors.warning;
    case JobModuleStatus.submitted:
      return BafColors.planned;
    case JobModuleStatus.accepted:
      return BafColors.sync;
    case JobModuleStatus.reopened:
      return BafColors.danger;
    case JobModuleStatus.notApplicable:
      return BafColors.textSecondary;
  }
}

IconData _statusIcon(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return Icons.radio_button_unchecked_rounded;
    case JobModuleStatus.inProgress:
      return Icons.pending_actions_rounded;
    case JobModuleStatus.draftSaved:
      return Icons.save_rounded;
    case JobModuleStatus.submitted:
      return Icons.outbox_rounded;
    case JobModuleStatus.accepted:
      return Icons.verified_rounded;
    case JobModuleStatus.reopened:
      return Icons.replay_rounded;
    case JobModuleStatus.notApplicable:
      return Icons.block_rounded;
  }
}

IconData _lifecycleIcon(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.submitted:
      return Icons.outbox_rounded;
    case JobModuleStatus.accepted:
      return Icons.verified_user_rounded;
    case JobModuleStatus.reopened:
      return Icons.replay_rounded;
    case JobModuleStatus.notApplicable:
      return Icons.block_rounded;
    case JobModuleStatus.notStarted:
    case JobModuleStatus.inProgress:
    case JobModuleStatus.draftSaved:
      return Icons.info_outline_rounded;
  }
}

String _statusLabel(JobModuleStatus status) {
  switch (status) {
    case JobModuleStatus.notStarted:
      return 'Not started';
    case JobModuleStatus.inProgress:
      return 'In progress';
    case JobModuleStatus.draftSaved:
      return 'Draft saved';
    case JobModuleStatus.submitted:
      return 'Submitted';
    case JobModuleStatus.accepted:
      return 'Accepted';
    case JobModuleStatus.reopened:
      return 'Reopened';
    case JobModuleStatus.notApplicable:
      return 'Not applicable';
  }
}

String _disciplineLabel(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return 'Mechanical';
    case JobModuleDiscipline.electrical:
      return 'Electrical';
    case JobModuleDiscipline.instrumentation:
      return 'I&A';
    case JobModuleDiscipline.operations:
      return 'Operations';
    case JobModuleDiscipline.emd:
      return 'EMD';
    case JobModuleDiscipline.refractory:
      return 'Refractory';
    case JobModuleDiscipline.shiftInCharge:
      return 'Shift in-charge';
    case JobModuleDiscipline.safety:
      return 'Safety';
    case JobModuleDiscipline.admin:
      return 'Admin/SI';
    case JobModuleDiscipline.shared:
      return 'Shared';
    case JobModuleDiscipline.others:
      return 'Others';
  }
}

Color _disciplineColor(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return BafColors.assets;
    case JobModuleDiscipline.electrical:
      return BafColors.danger;
    case JobModuleDiscipline.instrumentation:
      return BafColors.planned;
    case JobModuleDiscipline.operations:
      return BafColors.sync;
    case JobModuleDiscipline.emd:
      return BafColors.admin;
    case JobModuleDiscipline.refractory:
      return BafColors.warning;
    case JobModuleDiscipline.shiftInCharge:
      return BafColors.charges;
    case JobModuleDiscipline.safety:
      return BafColors.warning;
    case JobModuleDiscipline.admin:
    case JobModuleDiscipline.shared:
    case JobModuleDiscipline.others:
      return BafColors.admin;
  }
}

String _useModeLabel(JobModuleUseMode mode) {
  switch (mode) {
    case JobModuleUseMode.scheduledPM:
      return 'Scheduled PM';
    case JobModuleUseMode.troubleshooting:
      return 'Troubleshooting';
    case JobModuleUseMode.correctiveFollowUp:
      return 'Corrective follow-up';
    case JobModuleUseMode.shutdownWork:
      return 'Shutdown work';
    case JobModuleUseMode.preStartVerification:
      return 'Pre-start verification';
    case JobModuleUseMode.postRepairVerification:
      return 'Post-repair verification';
    case JobModuleUseMode.futurePackage:
      return 'Future package';
    case JobModuleUseMode.adHoc:
      return 'Ad-hoc';
  }
}

String _safetyLabel(JobModuleSafetyClass safetyClass) {
  switch (safetyClass) {
    case JobModuleSafetyClass.normal:
      return 'Normal';
    case JobModuleSafetyClass.lotoRequired:
      return 'LOTO';
    case JobModuleSafetyClass.gasRisk:
      return 'Gas risk';
    case JobModuleSafetyClass.hotSurface:
      return 'Hot surface';
    case JobModuleSafetyClass.pressureTest:
      return 'Pressure test';
    case JobModuleSafetyClass.liftingRisk:
      return 'Lifting risk';
    case JobModuleSafetyClass.electricalPanel:
      return 'Electrical panel';
    case JobModuleSafetyClass.combustionSpecialist:
      return 'Combustion';
    case JobModuleSafetyClass.configurationControl:
      return 'Config control';
  }
}

Color _safetyColor(JobModuleSafetyClass safetyClass) {
  switch (safetyClass) {
    case JobModuleSafetyClass.normal:
      return BafColors.admin;
    case JobModuleSafetyClass.lotoRequired:
    case JobModuleSafetyClass.gasRisk:
    case JobModuleSafetyClass.combustionSpecialist:
      return BafColors.danger;
    case JobModuleSafetyClass.hotSurface:
    case JobModuleSafetyClass.pressureTest:
    case JobModuleSafetyClass.liftingRisk:
      return BafColors.warning;
    case JobModuleSafetyClass.electricalPanel:
    case JobModuleSafetyClass.configurationControl:
      return BafColors.planned;
  }
}
