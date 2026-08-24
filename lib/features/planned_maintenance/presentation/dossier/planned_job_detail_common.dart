part of '../planned_job_detail_screen.dart';

class _DossierHeaderCard extends StatelessWidget {
  final JobExecution execution;
  final JobTemplate? template;
  final Color statusColor;

  const _DossierHeaderCard({
    required this.execution,
    required this.template,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled = execution.isCancelled;
    final terminal = execution.isTerminal;
    final templateName = _cleanDisplay(
      execution.templateName ?? template?.jobName,
      fallback: 'Planned maintenance job',
    );

    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: statusColor.withValues(alpha: 0.20)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(
              cancelled
                  ? Icons.cancel_outlined
                  : execution.isCompleted
                  ? Icons.task_alt_rounded
                  : Icons.pending_actions_rounded,
              color: statusColor,
              size: 33,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  execution.isCancelled
                      ? 'Cancelled job dossier'
                      : terminal
                      ? 'Closed job dossier'
                      : 'Open job dossier',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  templateName,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: [
                    StatusBadge(
                      label:
                          '${_assetTypeLabel(execution.assetType)} ${execution.assetNumber}',
                      color: BafColors.assets,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    StatusBadge(
                      label:
                          cancelled
                              ? 'Cancelled'
                              : execution.isCompleted
                              ? 'Completed'
                              : 'Open',
                      color: statusColor,
                      icon:
                          cancelled
                              ? Icons.cancel_outlined
                              : execution.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                    ),
                    StatusBadge(
                      label:
                          execution.isGovernedTemplateAssignment
                              ? 'Governed version'
                              : 'Legacy template',
                      color: BafColors.planned,
                      icon:
                          execution.isGovernedTemplateAssignment
                              ? Icons.verified_rounded
                              : Icons.layers_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedDossierStatusCard extends StatelessWidget {
  final JobExecution execution;

  const _ClosedDossierStatusCard({required this.execution});

  @override
  Widget build(BuildContext context) {
    final cancelled = execution.isCancelled;
    final accent = cancelled ? BafColors.warning : BafColors.sync;
    final closedAt = cancelled ? execution.cancelledAt : execution.completedAt;
    final completionText =
        closedAt == null
            ? cancelled
                ? 'Cancelled job'
                : 'Completed job'
            : '${cancelled ? 'Cancelled' : 'Completed'} on ${_formatDateTime(closedAt)}';
    final actorText =
        _hasText(
              cancelled ? execution.cancelledByName : execution.completedByName,
            )
            ? (cancelled
                    ? execution.cancelledByName
                    : execution.completedByName)!
                .trim()
            : _cleanDisplay(
              cancelled ? execution.cancelledByUid : execution.completedByUid,
              fallback: 'Unknown actor',
            );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: BafShadows.subtle,
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
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(
                  cancelled
                      ? Icons.cancel_outlined
                      : Icons.verified_user_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cancelled
                          ? 'Cancelled-job dossier is read-only'
                          : 'Closed-job dossier is read-only',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cancelled
                          ? 'This view preserves the job context and evidence recorded before cancellation. Runtime edits are locked; only governed lifecycle evidence may change the canonical record.'
                          : 'This view preserves the final job context, checklist, actions, diary and process-module evidence. Runtime edits are locked; reopen or correction workflows should happen through governed lifecycle actions only.',
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
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
              StatusBadge(
                label: completionText,
                color: accent,
                icon:
                    cancelled ? Icons.cancel_outlined : Icons.task_alt_rounded,
              ),
              StatusBadge(
                label: '${cancelled ? 'Cancelled' : 'Closed'} by $actorText',
                color: BafColors.admin,
                icon: Icons.person_rounded,
              ),
              StatusBadge(
                label:
                    execution.isSynced || kIsWeb
                        ? 'Remote-backed / synced'
                        : 'Saved locally · pending sync',
                color:
                    execution.isSynced || kIsWeb
                        ? BafColors.sync
                        : BafColors.warning,
                icon:
                    execution.isSynced || kIsWeb
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_upload_rounded,
              ),
            ],
          ),
          if (cancelled && _hasText(execution.cancellationReason)) ...[
            const SizedBox(height: BafSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BafSpacing.md),
              decoration: BoxDecoration(
                color: BafColors.card,
                borderRadius: BorderRadius.circular(BafRadius.medium),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Text(
                'Reason: ${execution.cancellationReason!.trim()}',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BafColors.planned, size: 22),
              const SizedBox(width: BafSpacing.sm),
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
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _LegacyModuleCard extends StatelessWidget {
  final JobExecution execution;
  final JobTemplate? template;

  const _LegacyModuleCard({required this.execution, required this.template});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        execution.isCompleted
            ? BafColors.sync
            : execution.isCancelled
            ? BafColors.warning
            : BafColors.planned;
    final responseRead = execution.responsesReadResult;
    final responseCount =
        responseRead.isValid
            ? responseRead.entries.where(_isRealResponse).length
            : null;
    final actionRead = execution.actionsReadResult;

    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.layers_rounded, color: statusColor, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanDisplay(
                        template?.jobName ?? execution.templateName,
                        fallback: 'Legacy planned job module',
                      ),
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This record predates module instances. It is displayed as one legacy module so old jobs remain readable during the architecture migration.',
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
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label:
                    execution.isCancelled
                        ? 'Cancelled'
                        : execution.isCompleted
                        ? 'Submitted'
                        : 'Not submitted',
                color: statusColor,
              ),
              StatusBadge(
                label:
                    responseCount == null
                        ? 'Responses need repair'
                        : '$responseCount response${responseCount == 1 ? '' : 's'}',
                color:
                    responseCount == null
                        ? BafColors.danger
                        : BafColors.planned,
                icon:
                    responseCount == null
                        ? Icons.warning_amber_rounded
                        : Icons.fact_check_rounded,
              ),
              if (actionRead.isValid)
                StatusBadge(
                  label:
                      '${actionRead.entries.length} action${actionRead.entries.length == 1 ? '' : 's'}',
                  color: BafColors.assets,
                  icon: Icons.build_rounded,
                )
              else
                const StatusBadge(
                  label: 'Actions need repair',
                  color: BafColors.danger,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          if (!responseRead.isValid) ...[
            const SizedBox(height: BafSpacing.md),
            const PersistedDataIntegrityNotice(
              title: 'Legacy responses need repair',
              message:
                  'Saved response evidence is malformed, so no response count or detail is inferred.',
            ),
          ],
        ],
      ),
    );
  }

  static bool _isRealResponse(FieldResponse response) {
    return response.fieldType != FieldType.sectionHeader &&
        response.fieldType != FieldType.instruction;
  }
}

class _ChecklistDossier extends StatelessWidget {
  final JobTemplate? template;
  final List<FieldResponse> responses;
  final bool isLoadingTemplate;

  const _ChecklistDossier({
    required this.template,
    required this.responses,
    required this.isLoadingTemplate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingTemplate) {
      return const _InlineLoadingRow(label: 'Loading template fields');
    }

    final fieldRead = template?.fieldsReadResult;
    if (fieldRead != null && !fieldRead.isValid) {
      return const PersistedDataIntegrityNotice(
        title: 'Template fields unavailable',
        message:
            'This saved template field payload must be repaired before checklist labels can be displayed.',
      );
    }
    final fields = List<TemplateField>.from(
      fieldRead?.entries ?? const <TemplateField>[],
    )..sort((a, b) => a.order.compareTo(b.order));

    if (fields.isEmpty && responses.where(_isRealResponse).isEmpty) {
      return const _EmptyInlineState(
        icon: Icons.fact_check_outlined,
        text: 'No checklist responses were recorded for this job.',
        color: BafColors.planned,
      );
    }

    if (fields.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            fields.map((field) {
              if (field.type == FieldType.sectionHeader) {
                return _DossierSectionHeader(field.label);
              }
              if (field.type == FieldType.instruction) {
                return _InstructionBox(
                  text: field.instructionText ?? field.label,
                );
              }

              final response = _firstResponseForKey(field.key);
              return _FieldValueRow(
                label: field.label,
                requiredField: field.isRequired,
                child:
                    response == null
                        ? const _Dash()
                        : _ResponseValueWidget(
                          response: response,
                          unit: field.unit,
                        ),
              );
            }).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          responses.where(_isRealResponse).map((response) {
            return _FieldValueRow(
              label: response.fieldLabel,
              child: _ResponseValueWidget(response: response),
            );
          }).toList(),
    );
  }

  FieldResponse? _firstResponseForKey(String key) {
    for (final response in responses) {
      if (response.key == key) return response;
    }
    return null;
  }

  static bool _isRealResponse(FieldResponse response) {
    return response.fieldType != FieldType.sectionHeader &&
        response.fieldType != FieldType.instruction;
  }
}

class _ActionDossierCard extends StatelessWidget {
  final ComponentAction action;

  const _ActionDossierCard(this.action);

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(action.severity);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(
                  _actionIcon(action.actionType),
                  color: severityColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cleanDisplay(
                        action.component,
                        fallback: 'Component action',
                      ),
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(
                          label: _titleCase(action.actionType.name),
                          color: BafColors.planned,
                        ),
                        StatusBadge(
                          label: _titleCase(action.severity.name),
                          color: severityColor,
                        ),
                        if (action.status != null)
                          StatusBadge(
                            label: _titleCase(action.status!.name),
                            color:
                                action.status == ActionStatus.resolved
                                    ? BafColors.sync
                                    : BafColors.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          _CompactInfoGrid(
            rows: [
              _InfoPair('Asset', action.asset),
              _InfoPair('System', action.system),
              _InfoPair('Subsystem', action.subsystem),
              _InfoPair('Sub-component', action.subComponent),
              _InfoPair('Tag', action.tag),
              _InfoPair('Instance', action.instance),
              _InfoPair('Replacement', action.replacement?.name),
              _InfoPair('Performed by', action.performedBy),
              _InfoPair('Created', _formatDateTime(action.createdAt)),
            ],
          ),
          if (_hasText(action.issue)) ...[
            const SizedBox(height: BafSpacing.sm),
            _TextBlock(label: 'Issue', text: action.issue!.trim()),
          ],
          if (_hasText(action.resolution)) ...[
            const SizedBox(height: BafSpacing.sm),
            _TextBlock(label: 'Resolution', text: action.resolution!.trim()),
          ],
          if (_hasText(action.remarks)) ...[
            const SizedBox(height: BafSpacing.sm),
            _TextBlock(label: 'Remarks', text: action.remarks!.trim()),
          ],
        ],
      ),
    );
  }

  static IconData _actionIcon(ActionType type) {
    switch (type) {
      case ActionType.issue:
        return Icons.report_problem_rounded;
      case ActionType.repair:
        return Icons.handyman_rounded;
      case ActionType.replacement:
        return Icons.sync_alt_rounded;
      case ActionType.inspection:
        return Icons.search_rounded;
    }
  }

  static Color _severityColor(ActionSeverity severity) {
    switch (severity) {
      case ActionSeverity.low:
        return BafColors.textSecondary;
      case ActionSeverity.medium:
        return BafColors.warning;
      case ActionSeverity.high:
        return BafColors.danger;
      case ActionSeverity.critical:
        return BafColors.danger;
    }
  }
}

class _CompactInfoGrid extends StatelessWidget {
  final List<_InfoPair> rows;

  const _CompactInfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((row) => _hasText(row.value)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children:
          visible
              .map(
                (row) => _InfoRow(
                  label: row.label,
                  value: row.value!.trim(),
                  dense: true,
                ),
              )
              .toList(),
    );
  }
}

class _InfoPair {
  final String label;
  final String? value;

  const _InfoPair(this.label, this.value);
}

class _FieldValueRow extends StatelessWidget {
  final String label;
  final Widget child;
  final bool requiredField;

  const _FieldValueRow({
    required this.label,
    required this.child,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              requiredField ? '$label *' : label,
              style: TextStyle(
                color:
                    requiredField
                        ? BafColors.textPrimary
                        : BafColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(flex: 3, child: child),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool dense;

  const _InfoRow({
    required this.label,
    required this.value,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: BafColors.textSecondary,
                fontSize: dense ? 12 : 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: dense ? 12 : 13,
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

class _ChipInfoRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final Color Function(String value) colorFor;
  final String emptyText;

  const _ChipInfoRow({
    required this.label,
    required this.values,
    required this.colorFor,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned =
        values
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            flex: 3,
            child:
                cleaned.isEmpty
                    ? Text(
                      emptyText,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    )
                    : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          cleaned
                              .map(
                                (value) => StatusBadge(
                                  label: _teamLabel(value),
                                  color: colorFor(value),
                                ),
                              )
                              .toList(),
                    ),
          ),
        ],
      ),
    );
  }
}

class _ResponseValueWidget extends StatelessWidget {
  final FieldResponse response;
  final String? unit;

  const _ResponseValueWidget({required this.response, this.unit});

  @override
  Widget build(BuildContext context) {
    final value = response.value;

    switch (response.fieldType) {
      case FieldType.checkbox:
      case FieldType.yesNo:
        final isTrue = _truthy(value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTrue ? Icons.check_circle_rounded : Icons.cancel_outlined,
              color: isTrue ? BafColors.sync : BafColors.danger,
              size: 19,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                isTrue ? 'Yes' : 'No',
                style: TextStyle(
                  color: isTrue ? BafColors.sync : BafColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );

      case FieldType.dropdown:
        if (!_hasObjectValue(value)) return const _Dash();
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(label: value.toString(), color: BafColors.planned),
        );

      case FieldType.multiSelect:
        final values = _multiSelectItems(value);
        if (values.isEmpty) return const _Dash();
        return Wrap(
          spacing: 5,
          runSpacing: 5,
          children:
              values
                  .map(
                    (item) =>
                        StatusBadge(label: item, color: BafColors.planned),
                  )
                  .toList(),
        );

      case FieldType.dateTime:
        if (!_hasObjectValue(value)) return const _Dash();
        final parsed = DateTime.tryParse(value.toString());
        return Text(
          parsed == null ? value.toString() : _formatDateTime(parsed),
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.3,
          ),
        );

      case FieldType.number:
        if (!_hasObjectValue(value)) return const _Dash();
        final unitText = unit?.trim();
        final renderedValue =
            unitText == null || unitText.isEmpty
                ? value.toString()
                : '${value.toString()} $unitText';
        return Text(
          renderedValue,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            height: 1.3,
          ),
        );

      case FieldType.text:
      case FieldType.longText:
        if (!_hasObjectValue(value)) return const _Dash();
        return Text(
          value.toString(),
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            height: 1.3,
          ),
        );

      case FieldType.sectionHeader:
      case FieldType.instruction:
        return const SizedBox.shrink();
    }
  }

  static bool _truthy(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return value == true || normalized == 'true' || normalized == 'yes';
  }

  static List<String> _multiSelectItems(Object? value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return value
        .toString()
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}

class _DossierSectionHeader extends StatelessWidget {
  final String label;

  const _DossierSectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 11),
      decoration: BoxDecoration(
        color: BafColors.planned.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.16)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: BafColors.planned,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _InstructionBox extends StatelessWidget {
  final String text;

  const _InstructionBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.assets.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.assets.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: BafColors.assets,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemarksBox extends StatelessWidget {
  final String text;

  const _RemarksBox({required this.text});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notes_rounded,
            color: BafColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataBox extends StatelessWidget {
  final String metadataJson;

  const _MetadataBox({required this.metadataJson});

  @override
  Widget build(BuildContext context) {
    final decoded = _decodeMetadata(metadataJson);
    if (decoded == null || decoded.isEmpty) {
      return _TextBlock(label: 'Metadata', text: metadataJson);
    }

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
          const Text(
            'Metadata',
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          ...decoded.entries.map(
            (entry) => _InfoRow(
              label: entry.key,
              value: entry.value?.toString() ?? '—',
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic>? _decodeMetadata(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;

  const _TextBlock({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;

  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: BafSpacing.sm),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: BafColors.warning,
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadingRow extends StatelessWidget {
  final String label;

  const _InlineLoadingRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: BafSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _EmptyInlineState({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '—',
      style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
    );
  }
}

class _OpenJobBottomBar extends StatelessWidget {
  final VoidCallback? onAddEntry;
  final VoidCallback? onComplete;

  const _OpenJobBottomBar({required this.onAddEntry, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: Row(
          children: [
            if (onAddEntry != null)
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: onAddEntry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BafColors.planned,
                      side: const BorderSide(color: BafColors.planned),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BafRadius.medium),
                      ),
                    ),
                    icon: const Icon(Icons.add_comment_rounded),
                    label: const Text(
                      'Add Note',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            if (onAddEntry != null && onComplete != null)
              const SizedBox(width: BafSpacing.sm),
            if (onComplete != null)
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: BafColors.sync,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BafRadius.medium),
                      ),
                    ),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text(
                      'Complete Job',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _jobModuleDisciplineLabel(JobModuleDiscipline discipline) {
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

String _jobModuleUseModeLabel(JobModuleUseMode mode) {
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

String _jobModuleSafetyLabel(JobModuleSafetyClass safetyClass) {
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

Color _jobModuleSafetyColor(JobModuleSafetyClass safetyClass) {
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

JobDiaryDiscipline _disciplineForUser(AppUser user) {
  if (user.isMechanical) return JobDiaryDiscipline.mechanical;
  if (user.isElectrical) return JobDiaryDiscipline.electrical;
  if (user.isInstrumentation) return JobDiaryDiscipline.instrumentation;
  if (user.isRefractory) return JobDiaryDiscipline.refractory;
  if (user.isShiftSupervisor || user.isContractSupervisor) {
    return JobDiaryDiscipline.shiftInCharge;
  }
  if (user.isAdmin || user.isSI) return JobDiaryDiscipline.admin;
  if (user.isOperations) return JobDiaryDiscipline.operations;
  return JobDiaryDiscipline.shared;
}

String _diaryKindLabel(JobDiaryKind kind) {
  switch (kind) {
    case JobDiaryKind.note:
      return 'Progress note';
    case JobDiaryKind.observation:
      return 'Observation';
    case JobDiaryKind.handover:
      return 'Handover';
    case JobDiaryKind.blocker:
      return 'Blocker';
    case JobDiaryKind.correction:
      return 'Correction';
  }
}

IconData _diaryIcon(JobDiaryKind kind) {
  switch (kind) {
    case JobDiaryKind.note:
      return Icons.notes_rounded;
    case JobDiaryKind.observation:
      return Icons.visibility_rounded;
    case JobDiaryKind.handover:
      return Icons.swap_horiz_rounded;
    case JobDiaryKind.blocker:
      return Icons.report_problem_rounded;
    case JobDiaryKind.correction:
      return Icons.edit_note_rounded;
  }
}

Color _diaryColor(JobDiaryEntry entry) {
  if (entry.isOpenBlocker) return BafColors.danger;
  switch (entry.kind) {
    case JobDiaryKind.blocker:
      return BafColors.warning;
    case JobDiaryKind.handover:
      return BafColors.charges;
    case JobDiaryKind.observation:
      return BafColors.audit;
    case JobDiaryKind.correction:
      return BafColors.directives;
    case JobDiaryKind.note:
      return BafColors.admin;
  }
}

Color _diarySeverityColor(JobDiarySeverity severity) {
  switch (severity) {
    case JobDiarySeverity.low:
      return BafColors.textSecondary;
    case JobDiarySeverity.medium:
      return BafColors.warning;
    case JobDiarySeverity.high:
      return BafColors.danger;
    case JobDiarySeverity.critical:
      return BafColors.danger;
  }
}

String _disciplineLabel(JobDiaryDiscipline discipline) {
  switch (discipline) {
    case JobDiaryDiscipline.mechanical:
      return 'MECHANICAL';
    case JobDiaryDiscipline.electrical:
      return 'ELECTRICAL';
    case JobDiaryDiscipline.instrumentation:
      return 'I&A';
    case JobDiaryDiscipline.operations:
      return 'OPERATIONS';
    case JobDiaryDiscipline.emd:
      return 'EMD';
    case JobDiaryDiscipline.refractory:
      return 'REFRACTORY';
    case JobDiaryDiscipline.shiftInCharge:
      return 'SHIFT IN-CHARGE';
    case JobDiaryDiscipline.safety:
      return 'SAFETY';
    case JobDiaryDiscipline.admin:
      return 'ADMIN / SI';
    case JobDiaryDiscipline.shared:
      return 'SHARED';
    case JobDiaryDiscipline.others:
      return 'OTHERS';
  }
}

Color _disciplineColor(JobDiaryDiscipline discipline) {
  switch (discipline) {
    case JobDiaryDiscipline.mechanical:
      return BafColors.planned;
    case JobDiaryDiscipline.electrical:
      return BafColors.warning;
    case JobDiaryDiscipline.instrumentation:
      return BafColors.audit;
    case JobDiaryDiscipline.operations:
      return BafColors.sync;
    case JobDiaryDiscipline.emd:
      return BafColors.admin;
    case JobDiaryDiscipline.refractory:
      return BafColors.warning;
    case JobDiaryDiscipline.shiftInCharge:
      return BafColors.charges;
    case JobDiaryDiscipline.safety:
      return BafColors.danger;
    case JobDiaryDiscipline.admin:
    case JobDiaryDiscipline.shared:
    case JobDiaryDiscipline.others:
      return BafColors.admin;
  }
}

String _blockerStatusLabel(JobBlockerStatus status) {
  switch (status) {
    case JobBlockerStatus.open:
      return 'Open blocker';
    case JobBlockerStatus.resolved:
      return 'Resolved';
    case JobBlockerStatus.carriedForward:
      return 'Carried forward';
    case JobBlockerStatus.waived:
      return 'Waived';
  }
}

String? _cleanOptionalString(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatDateTime(DateTime value) {
  return DateFormat('dd MMM yyyy, HH:mm').format(value);
}

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'BASE';
    case AssetType.furnace:
      return 'FURNACE';
    case AssetType.forceCooler:
      return 'FORCED COOLER';
    case AssetType.innerCover:
      return 'INNER COVER';
    case AssetType.governedCustom:
      return 'GOVERNED ASSET';
  }
}

String _templateScopeLabel(JobTemplate template) {
  final parts = <String>[
    _assetTypeLabel(template.applicableAssetType),
    if (_hasText(template.component)) template.component!.trim(),
    if (_hasText(template.subsystem)) template.subsystem!.trim(),
  ];

  if (template.hierarchyPath != null && template.hierarchyPath!.isNotEmpty) {
    parts.add(template.hierarchyPath!.where(_hasText).join(' › '));
  }

  return parts.where(_hasText).join(' / ');
}

Color _agencyColor(String agency) {
  switch (_teamKey(agency)) {
    case 'operations':
      return BafColors.sync;
    case 'electrical':
      return BafColors.warning;
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

String _teamLabel(String team) {
  switch (_teamKey(team)) {
    case 'electrical':
      return 'ELECTRICAL';
    case 'mechanical':
      return 'MECHANICAL';
    case 'instrumentation':
      return 'I&A';
    case 'operations':
      return 'OPERATIONS';
    case 'refractory':
      return 'REFRACTORY';
    case 'emd':
      return 'EMD';
    case 'shiftInCharge':
      return 'SHIFT IN-CHARGE';
    case 'others':
      return 'OTHERS';
    default:
      return team.trim().toUpperCase();
  }
}

String _teamKey(String value) {
  final compact = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );

  if (compact == 'ia' ||
      compact == 'ianda' ||
      compact == 'instrument' ||
      compact == 'instrumentation' ||
      compact == 'instruments') {
    return 'instrumentation';
  }
  if (compact == 'shiftincharge' || compact == 'sic') {
    return 'shiftInCharge';
  }
  if (compact == 'mech') return 'mechanical';
  if (compact == 'elec') return 'electrical';
  if (compact == 'ops') return 'operations';
  return compact;
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _cleanDisplay(String? value, {required String fallback}) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

bool _hasText(Object? value) {
  return value != null && value.toString().trim().isNotEmpty;
}

bool _hasObjectValue(Object? value) {
  return value != null && value.toString().trim().isNotEmpty;
}
