part of '../planned_job_detail_screen.dart';

class _ProcessModuleDossier extends StatelessWidget {
  final AsyncValue<List<JobModuleInstance>> modulesAsync;
  final bool isOpenJob;
  final ValueChanged<List<JobModuleInstance>>? onAddModule;
  final ValueChanged<JobModuleInstance> onOpenModule;

  const _ProcessModuleDossier({
    required this.modulesAsync,
    required this.isOpenJob,
    required this.onAddModule,
    required this.onOpenModule,
  });

  @override
  Widget build(BuildContext context) {
    return modulesAsync.when(
      loading: () => const _InlineLoadingRow(label: 'Loading process modules'),
      error: (error, _) => _WarningBox(text: 'Could not load modules: $error'),
      data: (modules) {
        final visibleModules =
            modules.toList()..sort((a, b) {
              final orderCompare = a.displayOrder.compareTo(b.displayOrder);
              if (orderCompare != 0) return orderCompare;
              return a.createdAt.compareTo(b.createdAt);
            });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOpenJob) ...[
              const _ClosedModulesReadOnlyBanner(),
              const SizedBox(height: BafSpacing.md),
            ],
            if (isOpenJob && onAddModule != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => onAddModule!(visibleModules),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BafColors.planned,
                    side: const BorderSide(color: BafColors.planned),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                  ),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text(
                    'Add module from BAF catalogue',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: BafSpacing.md),
            ],
            if (visibleModules.isEmpty)
              _EmptyInlineState(
                icon: Icons.account_tree_outlined,
                text:
                    isOpenJob
                        ? 'No process modules have been added yet. Add one from the published governed catalogue or the Emergency/manual seed catalogue.'
                        : 'No process modules were attached to this closed job.',
                color: BafColors.planned,
              )
            else ...[
              _ModuleDossierOverview(modules: visibleModules),
              const SizedBox(height: BafSpacing.md),
              ...visibleModules.map(
                (module) => _ModuleDossierTile(
                  module: module,
                  isClosedJob: !isOpenJob,
                  onOpenModule: () => onOpenModule(module),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ClosedModulesReadOnlyBanner extends StatelessWidget {
  const _ClosedModulesReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: BafColors.sync, size: 20),
          SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              'Closed-job module evidence is read-only. Tap a module to inspect the full workspace, but final dossier evidence is shown inline below each module card.',
              style: TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleDossierTile extends StatelessWidget {
  final JobModuleInstance module;
  final bool isClosedJob;
  final VoidCallback onOpenModule;

  const _ModuleDossierTile({
    required this.module,
    required this.isClosedJob,
    required this.onOpenModule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JobModuleCard(module: module, onTap: onOpenModule),
        _ModuleSourceNotice(module: module),
        if (isClosedJob) ...[
          _ClosedModuleEvidenceCard(module: module),
          const SizedBox(height: BafSpacing.md),
        ],
      ],
    );
  }
}

class _ClosedModuleEvidenceCard extends StatelessWidget {
  final JobModuleInstance module;

  const _ClosedModuleEvidenceCard({required this.module});

  @override
  Widget build(BuildContext context) {
    final actionRead = module.actionsReadResult;
    final fieldRead = module.fieldDefinitionsReadResult;
    final responseRead = module.responsesReadResult;
    final payloadsValid =
        fieldRead.isValid && responseRead.isValid && actionRead.isValid;
    final closureSatisfied =
        payloadsValid &&
        !module.isDeleted &&
        (!module.requiredForClosure ||
            module.status == JobModuleStatus.accepted ||
            module.status == JobModuleStatus.notApplicable);
    final lifecycleRows = _moduleLifecycleRows(module);
    final hasTechnicalContext =
        _hasTextList(module.procedureRefs) ||
        _hasTextList(module.targetRefs) ||
        _hasTextList(module.safetyConfirmations) ||
        _hasTextList(module.operationalStatePreconditions);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        left: BafSpacing.sm,
        right: BafSpacing.sm,
        bottom: BafSpacing.md,
      ),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color:
              closureSatisfied
                  ? BafColors.sync.withValues(alpha: 0.20)
                  : BafColors.warning.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                closureSatisfied
                    ? Icons.verified_rounded
                    : Icons.warning_rounded,
                color: closureSatisfied ? BafColors.sync : BafColors.warning,
                size: 20,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.isDeleted
                          ? 'Cancelled module evidence'
                          : 'Closed module evidence',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      module.isDeleted
                          ? 'Work captured before cancellation remains preserved and read-only.'
                          : closureSatisfied
                          ? 'Lifecycle evidence and structured responses preserved for this module.'
                          : 'This closed job contains a module that is not accepted or N/A. It remains visible for historical review.',
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(
                label:
                    module.isDeleted
                        ? 'Cancelled with job'
                        : _moduleStatusLabel(module.status),
                color:
                    module.isDeleted
                        ? BafColors.warning
                        : _moduleStatusColor(module.status),
              ),
              StatusBadge(
                label: _jobModuleDisciplineLabel(module.discipline),
                color: BafColors.planned,
              ),
              StatusBadge(
                label: _jobModuleSafetyLabel(module.safetyClass),
                color: _jobModuleSafetyColor(module.safetyClass),
                icon: Icons.health_and_safety_rounded,
              ),
              if (module.requiredForClosure)
                StatusBadge(
                  label:
                      closureSatisfied
                          ? 'Closure evidence satisfied'
                          : 'Closure evidence exception',
                  color: closureSatisfied ? BafColors.sync : BafColors.warning,
                  icon:
                      closureSatisfied
                          ? Icons.verified_rounded
                          : Icons.warning_rounded,
                ),
              if (_moduleSourceInfo(module) case final sourceInfo?)
                StatusBadge(
                  label: sourceInfo.badgeLabel,
                  color: sourceInfo.color,
                  icon: sourceInfo.icon,
                ),
              if (module.requiresFollowUp ||
                  _moduleText(module.pendingIssue) != null)
                const StatusBadge(
                  label: 'Follow-up / issue recorded',
                  color: BafColors.warning,
                  icon: Icons.flag_rounded,
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          if (lifecycleRows.isNotEmpty) _CompactInfoGrid(rows: lifecycleRows),
          if (hasTechnicalContext) ...[
            const SizedBox(height: BafSpacing.md),
            _ClosedModuleContextBlock(module: module),
          ],
          const SizedBox(height: BafSpacing.md),
          if (!fieldRead.isValid)
            const PersistedDataIntegrityNotice(
              title: 'Module field definitions need repair',
              message:
                  'Saved dynamic-field metadata is malformed, so no field or evidence interpretation is inferred.',
            )
          else if (!responseRead.isValid)
            const PersistedDataIntegrityNotice(
              title: 'Module responses need repair',
              message:
                  'Saved response evidence is malformed, so no response count or detail is inferred.',
            )
          else
            JobModuleResponseSummary(
              responses: responseRead.entries,
              fieldDefinitions: fieldRead.entries,
              emptyText:
                  'No structured responses were captured for this module before closure.',
            ),
          if (!actionRead.isValid) ...[
            const SizedBox(height: BafSpacing.md),
            const PersistedDataIntegrityNotice(
              title: 'Module actions need repair',
              message:
                  'Saved action evidence is malformed, so no action count or detail is inferred.',
            ),
          ] else if (actionRead.entries.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.md),
            const Text(
              'Module actions / observations',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            ...actionRead.entries.map(_ActionDossierCard.new),
          ],
          if (_moduleText(module.draftNote) != null ||
              _moduleText(module.submissionNote) != null ||
              _moduleText(module.acceptanceNote) != null ||
              _moduleText(module.reopenReason) != null ||
              _moduleText(module.notApplicableReason) != null ||
              _moduleText(module.pendingIssue) != null) ...[
            const SizedBox(height: BafSpacing.md),
            _ClosedModuleNarrativeBlock(module: module),
          ],
        ],
      ),
    );
  }
}

class _ClosedModuleContextBlock extends StatelessWidget {
  final JobModuleInstance module;

  const _ClosedModuleContextBlock({required this.module});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Technical context',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        if (_hasTextList(module.procedureRefs))
          _EvidenceStringList(
            icon: Icons.description_rounded,
            label: 'Procedures',
            values: module.procedureRefs,
            color: BafColors.planned,
          ),
        if (_hasTextList(module.targetRefs))
          _EvidenceStringList(
            icon: Icons.local_offer_rounded,
            label: 'Targets',
            values: module.targetRefs,
            color: BafColors.assets,
          ),
        if (_hasTextList(module.safetyConfirmations))
          _EvidenceStringList(
            icon: Icons.health_and_safety_rounded,
            label: 'Safety confirmations',
            values: module.safetyConfirmations,
            color: BafColors.danger,
          ),
        if (_hasTextList(module.operationalStatePreconditions))
          _EvidenceStringList(
            icon: Icons.rule_rounded,
            label: 'Operational preconditions',
            values: module.operationalStatePreconditions,
            color: BafColors.warning,
          ),
      ],
    );
  }
}

class _EvidenceStringList extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> values;
  final Color color;

  const _EvidenceStringList({
    required this.icon,
    required this.label,
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                cleaned
                    .map((value) => StatusBadge(label: value, color: color))
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _ClosedModuleNarrativeBlock extends StatelessWidget {
  final JobModuleInstance module;

  const _ClosedModuleNarrativeBlock({required this.module});

  @override
  Widget build(BuildContext context) {
    final entries =
        <_InfoPair>[
          _InfoPair('Draft note', module.draftNote),
          _InfoPair('Submission note', module.submissionNote),
          _InfoPair('Acceptance note', module.acceptanceNote),
          _InfoPair('Reopen reason', module.reopenReason),
          _InfoPair('N/A reason', module.notApplicableReason),
          _InfoPair('Pending issue', module.pendingIssue),
        ].where((entry) => _moduleText(entry.value) != null).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Module notes and decisions',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: BafSpacing.sm),
            child: _RemarksBox(text: '${entry.label}: ${entry.value!.trim()}'),
          ),
        ),
      ],
    );
  }
}

class _ModuleDossierOverview extends StatelessWidget {
  final List<JobModuleInstance> modules;

  const _ModuleDossierOverview({required this.modules});

  @override
  Widget build(BuildContext context) {
    final total = modules.length;
    final accepted =
        modules
            .where((module) => module.status == JobModuleStatus.accepted)
            .length;
    final submitted =
        modules
            .where((module) => module.status == JobModuleStatus.submitted)
            .length;
    final notApplicable =
        modules
            .where((module) => module.status == JobModuleStatus.notApplicable)
            .length;
    final open = modules.where((module) => module.isOpenForWork).length;
    final invalidPayloads =
        modules
            .where(
              (module) =>
                  !module.fieldDefinitionsReadResult.isValid ||
                  !module.responsesReadResult.isValid ||
                  !module.actionsReadResult.isValid,
            )
            .length;
    final responseCount = modules.fold<int>(
      0,
      (sum, module) =>
          sum +
          (module.responsesReadResult.isValid
              ? module.responsesReadResult.entries.length
              : 0),
    );
    final requiredWithoutResponses =
        modules
            .where(
              (module) =>
                  module.requiredForClosure &&
                  module.responsesReadResult.isValid &&
                  module.responsesReadResult.entries.isEmpty,
            )
            .length;
    final requiredStillOpen =
        modules
            .where(
              (module) =>
                  module.requiredForClosure &&
                  !module.isFinalisedForNormalUsers,
            )
            .length;
    final followUps =
        modules
            .where(
              (module) =>
                  module.requiresFollowUp ||
                  _moduleText(module.pendingIssue) != null,
            )
            .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BafColors.planned.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: BafColors.planned,
                  size: 20,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Module dossier overview',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Snapshot of module completion, responses and closure attention items.',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ModuleOverviewPill(
                label: 'Total',
                value: '$total',
                color: BafColors.planned,
              ),
              _ModuleOverviewPill(
                label: 'Open',
                value: '$open',
                color: open == 0 ? BafColors.sync : BafColors.warning,
              ),
              _ModuleOverviewPill(
                label: 'Submitted',
                value: '$submitted',
                color: BafColors.planned,
              ),
              _ModuleOverviewPill(
                label: 'Accepted',
                value: '$accepted',
                color: accepted > 0 ? BafColors.sync : BafColors.textSecondary,
              ),
              _ModuleOverviewPill(
                label: 'N/A',
                value: '$notApplicable',
                color: BafColors.textSecondary,
              ),
              _ModuleOverviewPill(
                label: 'Responses',
                value: '$responseCount',
                color:
                    responseCount > 0
                        ? BafColors.sync
                        : BafColors.textSecondary,
              ),
            ],
          ),
          if (requiredWithoutResponses > 0 ||
              requiredStillOpen > 0 ||
              followUps > 0 ||
              invalidPayloads > 0) ...[
            const SizedBox(height: BafSpacing.md),
            if (invalidPayloads > 0)
              _ModuleOverviewWarning(
                icon: Icons.warning_amber_rounded,
                color: BafColors.danger,
                text:
                    '$invalidPayloads module${invalidPayloads == 1 ? '' : 's'} ${invalidPayloads == 1 ? 'has' : 'have'} saved evidence that needs repair.',
              ),
            if (requiredWithoutResponses > 0)
              _ModuleOverviewWarning(
                icon: Icons.assignment_late_rounded,
                color: BafColors.danger,
                text:
                    '$requiredWithoutResponses required module${requiredWithoutResponses == 1 ? '' : 's'} still ${requiredWithoutResponses == 1 ? 'has' : 'have'} no structured responses.',
              ),
            if (requiredStillOpen > 0)
              _ModuleOverviewWarning(
                icon: Icons.lock_clock_rounded,
                color: BafColors.warning,
                text:
                    '$requiredStillOpen required module${requiredStillOpen == 1 ? '' : 's'} still ${requiredStillOpen == 1 ? 'is' : 'are'} open for work.',
              ),
            if (followUps > 0)
              _ModuleOverviewWarning(
                icon: Icons.flag_rounded,
                color: BafColors.warning,
                text:
                    '$followUps module${followUps == 1 ? '' : 's'} ${followUps == 1 ? 'has' : 'have'} pending issue or follow-up marked.',
              ),
          ],
        ],
      ),
    );
  }

  static String? _moduleText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _ModuleOverviewPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ModuleOverviewPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.small),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleOverviewWarning extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ModuleOverviewWarning({
    required this.icon,
    required this.color,
    required this.text,
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
          Icon(icon, size: 16, color: color),
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

String _moduleStatusLabel(JobModuleStatus status) {
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

Color _moduleStatusColor(JobModuleStatus status) {
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

List<_InfoPair> _moduleLifecycleRows(JobModuleInstance module) {
  final sourceInfo = _moduleSourceInfo(module);
  final rows = <_InfoPair>[
    _InfoPair('Status', _moduleStatusLabel(module.status)),
    _InfoPair('Closure-critical', module.requiredForClosure ? 'Yes' : 'No'),
    if (sourceInfo != null) _InfoPair('Module source', sourceInfo.auditLabel),
    if (sourceInfo != null) _InfoPair('Source note', sourceInfo.detail),
    _InfoPair(
      'Added by',
      _actorLine(module.addedByName, module.addedByUid, module.addedAt),
    ),
    _InfoPair(
      'Created by',
      _actorLine(module.createdByName, module.createdByUid, module.createdAt),
    ),
    _InfoPair(
      'Updated by',
      _actorLine(module.updatedByName, module.updatedByUid, module.updatedAt),
    ),
    _InfoPair(
      'Submitted by',
      _actorLine(
        module.submittedByName,
        module.submittedByUid,
        module.submittedAt,
      ),
    ),
    _InfoPair(
      'Accepted by',
      _actorLine(
        module.acceptedByName,
        module.acceptedByUid,
        module.acceptedAt,
      ),
    ),
    _InfoPair(
      'Reopened by',
      _actorLine(
        module.reopenedByName,
        module.reopenedByUid,
        module.reopenedAt,
      ),
    ),
    _InfoPair(
      'Marked N/A by',
      _actorLine(
        module.notApplicableByName,
        module.notApplicableByUid,
        module.notApplicableAt,
      ),
    ),
    if (module.isDeleted)
      _InfoPair(
        'Cancelled by',
        _actorLine(module.deletedByName, module.deletedByUid, module.deletedAt),
      ),
    if (module.isDeleted && _moduleText(module.deleteReason) != null)
      _InfoPair('Cancellation reason', module.deleteReason!),
  ];

  return rows.where((row) => _moduleText(row.value) != null).toList();
}

class _ModuleSourceNotice extends StatelessWidget {
  final JobModuleInstance module;

  const _ModuleSourceNotice({required this.module});

  @override
  Widget build(BuildContext context) {
    final sourceInfo = _moduleSourceInfo(module);
    if (sourceInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        left: BafSpacing.sm,
        right: BafSpacing.sm,
        bottom: BafSpacing.sm,
      ),
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: sourceInfo.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: sourceInfo.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(sourceInfo.icon, color: sourceInfo.color, size: 18),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceInfo.title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sourceInfo.detail,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
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

class _ModuleSourceInfo {
  final String title;
  final String badgeLabel;
  final String auditLabel;
  final String detail;
  final Color color;
  final IconData icon;

  const _ModuleSourceInfo({
    required this.title,
    required this.badgeLabel,
    required this.auditLabel,
    required this.detail,
    required this.color,
    required this.icon,
  });
}

_ModuleSourceInfo? _moduleSourceInfo(JobModuleInstance module) {
  final lineage = RuntimeModuleLineageInfo.fromModule(module);
  switch (lineage.source) {
    case RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd:
      return _ModuleSourceInfo(
        title: 'Published governed runtime addition',
        badgeLabel: lineage.badgeLabel,
        auditLabel: _lineageAuditLabel(
          lineage,
          fallback: 'Published governed runtime addition',
        ),
        detail:
            'Added during active execution from the published governed TemplateVersion catalogue.',
        color: BafColors.sync,
        icon: Icons.add_task_rounded,
      );
    case RuntimeModuleLineageSource.emergencyManualSeed:
      return _ModuleSourceInfo(
        title: 'Emergency/manual seed addition',
        badgeLabel: lineage.badgeLabel,
        auditLabel: _lineageAuditLabel(
          lineage,
          fallback: 'Emergency/manual seed catalogue',
        ),
        detail:
            'Added during active execution from the Emergency/manual seed catalogue, not from the published governed TemplateVersion.',
        color: BafColors.warning,
        icon: Icons.report_gmailerrorred_rounded,
      );
    case RuntimeModuleLineageSource.publishedTemplateVersionModule:
      return _ModuleSourceInfo(
        title: 'Published TemplateVersion snapshot',
        badgeLabel: 'Published snapshot',
        auditLabel: _lineageAuditLabel(
          lineage,
          fallback: 'Published TemplateVersion snapshot',
        ),
        detail:
            'This module was frozen from the published governed TemplateVersion assigned to this job.',
        color: BafColors.sync,
        icon: Icons.verified_rounded,
      );
    case RuntimeModuleLineageSource.manualRuntimeAdd:
      return _ModuleSourceInfo(
        title: 'Manual runtime addition',
        badgeLabel: lineage.badgeLabel,
        auditLabel: _lineageAuditLabel(
          lineage,
          fallback: 'Manual runtime addition',
        ),
        detail:
            'Added during active execution without governed source metadata; confirm provenance before using it as closure-critical evidence.',
        color: BafColors.warning,
        icon: Icons.add_circle_outline_rounded,
      );
    case RuntimeModuleLineageSource.legacyOrManual:
      return _ModuleSourceInfo(
        title: 'Legacy/manual module',
        badgeLabel: lineage.badgeLabel,
        auditLabel: _lineageAuditLabel(
          lineage,
          fallback: 'Legacy/manual module',
        ),
        detail:
            'No governed runtime lineage metadata is attached to this module.',
        color: BafColors.admin,
        icon: Icons.history_rounded,
      );
  }
}

String _lineageAuditLabel(
  RuntimeModuleLineageInfo lineage, {
  required String fallback,
}) {
  final summary = _moduleText(lineage.summary);
  return summary == null ? fallback : '${lineage.label}: $summary';
}

String? _actorLine(String? name, String? uid, DateTime? at) {
  final actor = _moduleText(name) ?? _moduleText(uid);
  final when = at == null ? null : _formatDateTime(at);
  if (actor == null && when == null) return null;
  if (actor != null && when != null) return '$actor • $when';
  return actor ?? when;
}

bool _hasTextList(List<String> values) =>
    values.any((value) => value.trim().isNotEmpty);

String? _moduleText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _PublishedRuntimeCatalogueLoad {
  final List<PublishedRuntimeModuleCandidate> candidates;
  final String? errorMessage;

  const _PublishedRuntimeCatalogueLoad({
    required this.candidates,
    this.errorMessage,
  });
}

class _PublishedRuntimeModuleDraft {
  final PublishedRuntimeModuleCandidate? candidate;
  final String addReason;
  final bool useEmergencyManualFallback;

  const _PublishedRuntimeModuleDraft({
    required this.candidate,
    required this.addReason,
  }) : useEmergencyManualFallback = false;

  const _PublishedRuntimeModuleDraft.useEmergencyManualFallback()
    : candidate = null,
      addReason = '',
      useEmergencyManualFallback = true;
}

class _JobModuleDraft {
  final BafModuleSeed seed;
  final JobModuleUseMode useMode;
  final JobModuleDiscipline discipline;
  final bool requiredForClosure;
  final String addReason;

  const _JobModuleDraft({
    required this.seed,
    required this.useMode,
    required this.discipline,
    required this.requiredForClosure,
    required this.addReason,
  });
}

class _AddPublishedRuntimeModuleSheet extends StatefulWidget {
  final List<PublishedRuntimeModuleCandidate> candidates;
  final AppUser actor;

  const _AddPublishedRuntimeModuleSheet({
    required this.candidates,
    required this.actor,
  });

  @override
  State<_AddPublishedRuntimeModuleSheet> createState() =>
      _AddPublishedRuntimeModuleSheetState();
}

class _AddPublishedRuntimeModuleSheetState
    extends State<_AddPublishedRuntimeModuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late PublishedRuntimeModuleCandidate _selectedCandidate;

  @override
  void initState() {
    super.initState();
    _selectedCandidate = widget.candidates.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final requiresElevatedControl =
        _selectedCandidate.requiresElevatedRuntimeAddControl();
    final canConfirmElevatedControl = _canConfirmElevatedRuntimeModuleAddition(
      widget.actor,
    );
    final isBlocked = requiresElevatedControl && !canConfirmElevatedControl;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        bottomInset + BafSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: BafColors.sync.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: BafColors.sync,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add governed process module',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Preferred source: published TemplateVersion catalogue. Use Emergency/manual seed only as fallback.',
                          style: TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.lg),
              DropdownButtonFormField<PublishedRuntimeModuleCandidate>(
                initialValue: _selectedCandidate,
                isExpanded: true,
                decoration: _sheetInputDecoration('Published module *'),
                items:
                    widget.candidates.map((candidate) {
                      return DropdownMenuItem<PublishedRuntimeModuleCandidate>(
                        value: candidate,
                        child: Text(
                          candidate.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                validator:
                    (value) =>
                        value == null ? 'Select a published module.' : null,
                onChanged: (candidate) {
                  if (candidate == null) return;
                  setState(() => _selectedCandidate = candidate);
                },
              ),
              const SizedBox(height: BafSpacing.md),
              _PublishedRuntimeModulePreview(candidate: _selectedCandidate),
              if (requiresElevatedControl) ...[
                const SizedBox(height: BafSpacing.sm),
                _WarningBox(
                  text: _publishedRuntimeControlWarningText(
                    _selectedCandidate,
                    canConfirmElevatedControl: canConfirmElevatedControl,
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                decoration: _sheetInputDecoration('Reason / work context *'),
                validator:
                    (value) =>
                        _hasText(value)
                            ? null
                            : 'Record why this governed module is being added.',
              ),
              const SizedBox(height: BafSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          () => Navigator.pop(
                            context,
                            const _PublishedRuntimeModuleDraft.useEmergencyManualFallback(),
                          ),
                      child: const Text('Use emergency/manual seed'),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isBlocked ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.sync,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text(
                        isBlocked
                            ? 'Supervisor confirmation required'
                            : 'Add governed module',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCandidate.requiresElevatedRuntimeAddControl()) {
      final canConfirmElevatedControl =
          _canConfirmElevatedRuntimeModuleAddition(widget.actor);
      if (!canConfirmElevatedControl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Supervisor/Admin/SI confirmation is required for this governed module.',
            ),
            backgroundColor: BafColors.danger,
          ),
        );
        return;
      }

      final confirmed = await _confirmElevatedPublishedRuntimeAddition();
      if (!mounted || !confirmed) return;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      _PublishedRuntimeModuleDraft(
        candidate: _selectedCandidate,
        addReason: _reasonController.text.trim(),
      ),
    );
  }

  Future<bool> _confirmElevatedPublishedRuntimeAddition() async {
    final reasons = _publishedRuntimeControlReasons(
      _selectedCandidate,
    ).join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm governed runtime module'),
          content: Text(
            'This published governed module is $reasons and requires '
            'Supervisor/Admin/SI confirmation before it is added during active '
            'execution. Confirm only if this job genuinely needs this additional '
            'published module scope.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm add'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }
}

class _AddJobModuleSheet extends StatefulWidget {
  final AssetType assetType;
  final JobModuleDiscipline initialDiscipline;
  final AppUser actor;
  final bool isGovernedTemplateAssignment;

  const _AddJobModuleSheet({
    required this.assetType,
    required this.initialDiscipline,
    required this.actor,
    required this.isGovernedTemplateAssignment,
  });

  @override
  State<_AddJobModuleSheet> createState() => _AddJobModuleSheetState();
}

class _AddJobModuleSheetState extends State<_AddJobModuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late final List<BafModuleSeed> _availableSeeds;
  BafModuleSeed? _selectedSeed;
  late JobModuleUseMode _useMode;
  late JobModuleDiscipline _discipline;
  bool _requiredForClosure = false;

  @override
  void initState() {
    super.initState();
    _availableSeeds = BafModuleCatalogueSeed.modulesForAsset(widget.assetType);
    _selectedSeed = _availableSeeds.isEmpty ? null : _availableSeeds.first;
    _useMode = _selectedSeed?.defaultUseMode ?? JobModuleUseMode.adHoc;
    _discipline = _selectedSeed?.defaultDiscipline ?? widget.initialDiscipline;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectedSeed = _selectedSeed;
    final selectedRequiresElevatedControl =
        selectedSeed?.requiresElevatedManualAddControl(
          requiredForClosure: _requiredForClosure,
        ) ??
        false;
    final canConfirmElevatedControl =
        _canConfirmElevatedManualSeedModuleAddition(widget.actor);
    final isBlockedManualSeedSelection =
        selectedRequiresElevatedControl && !canConfirmElevatedControl;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        bottomInset + BafSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      color: BafColors.planned,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add process module',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select a module from the Emergency/manual seed catalogue for ${_assetTypeLabel(widget.assetType)}.',
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.lg),
              if (widget.isGovernedTemplateAssignment) ...[
                const _WarningBox(
                  text:
                      'This job was assigned from a published governed template. '
                      'Modules added here come from the Emergency/manual seed catalogue, '
                      'not from the published TemplateVersion.',
                ),
                const SizedBox(height: BafSpacing.md),
              ],
              if (_availableSeeds.isEmpty)
                const _WarningBox(
                  text:
                      'No catalogue modules are available for this asset type yet.',
                )
              else ...[
                DropdownButtonFormField<BafModuleSeed>(
                  initialValue: _selectedSeed,
                  isExpanded: true,
                  decoration: _sheetInputDecoration('BAF module *'),
                  items:
                      _availableSeeds.map((seed) {
                        return DropdownMenuItem<BafModuleSeed>(
                          value: seed,
                          child: Text(
                            seed.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                  validator:
                      (value) => value == null ? 'Select a module.' : null,
                  onChanged: (seed) {
                    if (seed == null) return;
                    setState(() {
                      _selectedSeed = seed;
                      _useMode = seed.defaultUseMode;
                      _discipline = seed.defaultDiscipline;
                    });
                  },
                ),
                if (selectedSeed != null) ...[
                  const SizedBox(height: BafSpacing.md),
                  _ModuleSeedPreview(seed: selectedSeed),
                  if (selectedRequiresElevatedControl) ...[
                    const SizedBox(height: BafSpacing.sm),
                    _WarningBox(
                      text: _manualSeedControlWarningText(
                        selectedSeed,
                        requiredForClosure: _requiredForClosure,
                        canConfirmElevatedControl: canConfirmElevatedControl,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: BafSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<JobModuleUseMode>(
                        key: ValueKey(_useMode),
                        initialValue: _useMode,
                        isExpanded: true,
                        decoration: _sheetInputDecoration('Use mode'),
                        items:
                            JobModuleUseMode.values.map((mode) {
                              return DropdownMenuItem<JobModuleUseMode>(
                                value: mode,
                                child: Text(
                                  _jobModuleUseModeLabel(mode),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _useMode = value);
                        },
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<JobModuleDiscipline>(
                        key: ValueKey(_discipline),
                        initialValue: _discipline,
                        isExpanded: true,
                        decoration: _sheetInputDecoration('Lane'),
                        items:
                            JobModuleDiscipline.values.map((discipline) {
                              return DropdownMenuItem<JobModuleDiscipline>(
                                value: discipline,
                                child: Text(
                                  _jobModuleDisciplineLabel(discipline),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _discipline = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _sheetInputDecoration('Reason / work context *'),
                  validator:
                      (value) =>
                          _hasText(value)
                              ? null
                              : 'Record why this module is being added.',
                ),
                const SizedBox(height: BafSpacing.sm),
                CheckboxListTile(
                  value: _requiredForClosure,
                  contentPadding: EdgeInsets.zero,
                  activeColor: BafColors.danger,
                  title: const Text(
                    'Required for job closure',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Use this when the module must be submitted, accepted or marked not applicable before final closure.',
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                  onChanged: (value) {
                    setState(() => _requiredForClosure = value ?? false);
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            isBlockedManualSeedSelection ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: BafColors.planned,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              BafRadius.medium,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add_task_rounded),
                        label: Text(
                          isBlockedManualSeedSelection
                              ? 'Supervisor confirmation required'
                              : 'Add module',
                        ),
                      ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedSeed = _selectedSeed;
    if (selectedSeed == null) return;

    final requiresElevatedControl = selectedSeed
        .requiresElevatedManualAddControl(
          requiredForClosure: _requiredForClosure,
        );

    if (requiresElevatedControl) {
      final canConfirmElevatedControl =
          _canConfirmElevatedManualSeedModuleAddition(widget.actor);
      if (!canConfirmElevatedControl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Supervisor/Admin/SI confirmation is required for this Emergency/manual seed module.',
            ),
            backgroundColor: BafColors.danger,
          ),
        );
        return;
      }

      final confirmed = await _confirmElevatedManualSeedAddition(selectedSeed);
      if (!mounted || !confirmed) return;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      _JobModuleDraft(
        seed: selectedSeed,
        useMode: _useMode,
        discipline: _discipline,
        requiredForClosure: _requiredForClosure,
        addReason: _reasonController.text.trim(),
      ),
    );
  }

  Future<bool> _confirmElevatedManualSeedAddition(BafModuleSeed seed) async {
    final reasons = _manualSeedControlReasons(
      seed,
      requiredForClosure: _requiredForClosure,
    ).join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Emergency/manual seed module'),
          content: Text(
            'This module is $reasons and is being added from the '
            'Emergency/manual seed catalogue, not from the published governed '
            'TemplateVersion. Confirm only if this active job genuinely needs '
            'this manual scope addition.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm add'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }
}

class _PublishedRuntimeModulePreview extends StatelessWidget {
  final PublishedRuntimeModuleCandidate candidate;

  const _PublishedRuntimeModulePreview({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(
                label: candidate.sourceLabel,
                color: BafColors.sync,
                icon: Icons.verified_rounded,
              ),
              StatusBadge(
                label: _jobModuleSafetyLabel(candidate.safetyClass),
                color: _jobModuleSafetyColor(candidate.safetyClass),
                icon: Icons.health_and_safety_rounded,
              ),
              if (candidate.requiredForClosure)
                const StatusBadge(
                  label: 'Closure-critical',
                  color: BafColors.danger,
                  icon: Icons.lock_rounded,
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            candidate.moduleTitle,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          if (_hasText(candidate.moduleDescription)) ...[
            const SizedBox(height: 4),
            Text(
              candidate.moduleDescription!.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          if (candidate.procedureRefs.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              'Procedures: ${candidate.procedureRefs.join(', ')}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleSeedPreview extends StatelessWidget {
  final BafModuleSeed seed;

  const _ModuleSeedPreview({required this.seed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusBadge(label: seed.catalogueArea, color: BafColors.planned),
              StatusBadge(
                label: _jobModuleSafetyLabel(seed.defaultSafetyClass),
                color: _jobModuleSafetyColor(seed.defaultSafetyClass),
                icon: Icons.health_and_safety_rounded,
              ),
              if (seed.procedureRefs.isNotEmpty)
                StatusBadge(
                  label: seed.procedureRefs.join(', '),
                  color: BafColors.admin,
                  icon: Icons.description_rounded,
                ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            seed.functionalSection,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            seed.closedDossierOutput,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          if (seed.standardItems.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            ...seed.standardItems.take(3).map((item) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: BafColors.sync,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
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
            }),
          ],
        ],
      ),
    );
  }
}

bool _canConfirmElevatedRuntimeModuleAddition(AppUser user) {
  return user.isAdmin ||
      user.isSI ||
      user.isContractSupervisor ||
      user.isShiftSupervisor;
}

bool _canConfirmElevatedManualSeedModuleAddition(AppUser user) {
  return user.isAdmin ||
      user.isSI ||
      user.isContractSupervisor ||
      user.isShiftSupervisor;
}

List<String> _manualSeedControlReasons(
  BafModuleSeed seed, {
  required bool requiredForClosure,
}) {
  return <String>[
    if (seed.requiresSafetyControl) 'safety-critical',
    if (seed.isSharedModule) 'shared',
    if (requiredForClosure) 'closure-critical',
  ];
}

List<String> _publishedRuntimeControlReasons(
  PublishedRuntimeModuleCandidate candidate,
) {
  return <String>[
    if (candidate.safetyClass != JobModuleSafetyClass.normal)
      'safety-classified',
    if (candidate.discipline == JobModuleDiscipline.shared) 'shared',
    if (candidate.requiredForClosure) 'closure-critical',
  ];
}

String _publishedRuntimeControlWarningText(
  PublishedRuntimeModuleCandidate candidate, {
  required bool canConfirmElevatedControl,
}) {
  final reasons = _publishedRuntimeControlReasons(candidate).join(', ');
  final prefix =
      'This published governed module is $reasons and is being added during active execution.';

  if (!canConfirmElevatedControl) {
    return '$prefix Supervisor/Admin/SI confirmation is required before it can be added.';
  }

  return '$prefix You must explicitly confirm this warning before adding it.';
}

String _manualSeedControlWarningText(
  BafModuleSeed seed, {
  required bool requiredForClosure,
  required bool canConfirmElevatedControl,
}) {
  final reasons = _manualSeedControlReasons(
    seed,
    requiredForClosure: requiredForClosure,
  ).join(', ');

  final prefix =
      'This Emergency/manual seed module is $reasons and is not from the '
      'published governed TemplateVersion.';

  if (!canConfirmElevatedControl) {
    return '$prefix Supervisor/Admin/SI confirmation is required before it can be added.';
  }

  return '$prefix You must explicitly confirm this warning before adding it.';
}

JobModuleDiscipline _moduleDisciplineForUser(AppUser user) {
  if (user.isMechanical) return JobModuleDiscipline.mechanical;
  if (user.isElectrical) return JobModuleDiscipline.electrical;
  if (user.isInstrumentation) return JobModuleDiscipline.instrumentation;
  if (user.isShiftSupervisor || user.isContractSupervisor) {
    return JobModuleDiscipline.shiftInCharge;
  }
  if (user.isAdmin || user.isSI) return JobModuleDiscipline.admin;
  if (user.isOperations) return JobModuleDiscipline.operations;
  return JobModuleDiscipline.shared;
}
