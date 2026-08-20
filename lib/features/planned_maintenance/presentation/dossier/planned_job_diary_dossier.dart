part of '../planned_job_detail_screen.dart';

class _DiaryDossier extends StatelessWidget {
  final AsyncValue<List<JobDiaryEntry>> entriesAsync;
  final bool isOpenJob;
  final VoidCallback? onAddEntry;

  const _DiaryDossier({
    required this.entriesAsync,
    required this.isOpenJob,
    required this.onAddEntry,
  });

  @override
  Widget build(BuildContext context) {
    return entriesAsync.when(
      loading: () => const _InlineLoadingRow(label: 'Loading diary entries'),
      error:
          (error, _) =>
              _WarningBox(text: 'Could not load diary entries: $error'),
      data: (entries) {
        if (entries.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EmptyInlineState(
                icon: Icons.forum_outlined,
                text:
                    'No diary, handover or blocker entries are attached to this job yet.',
                color: BafColors.admin,
              ),
              if (isOpenJob && onAddEntry != null) ...[
                const SizedBox(height: BafSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onAddEntry,
                    icon: const Icon(Icons.add_comment_rounded),
                    label: const Text('Add diary entry'),
                  ),
                ),
              ],
            ],
          );
        }

        final blockers = entries.where((entry) => entry.isOpenBlocker).length;
        final handovers = entries.where((entry) => entry.isHandover).length;
        final followUps =
            entries.where((entry) => entry.requiresFollowUp).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label:
                      '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                  color: BafColors.admin,
                  icon: Icons.forum_rounded,
                ),
                if (blockers > 0)
                  StatusBadge(
                    label: '$blockers open blocker${blockers == 1 ? '' : 's'}',
                    color: BafColors.danger,
                    icon: Icons.report_problem_rounded,
                  ),
                if (handovers > 0)
                  StatusBadge(
                    label: '$handovers handover${handovers == 1 ? '' : 's'}',
                    color: BafColors.charges,
                    icon: Icons.swap_horiz_rounded,
                  ),
                if (followUps > 0)
                  StatusBadge(
                    label: '$followUps follow-up${followUps == 1 ? '' : 's'}',
                    color: BafColors.warning,
                    icon: Icons.flag_rounded,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            ...entries.take(8).map(_DiaryEntryCard.new),
            if (entries.length > 8) ...[
              const SizedBox(height: BafSpacing.sm),
              Text(
                'Showing latest 8 of ${entries.length} diary entries.',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (isOpenJob && onAddEntry != null) ...[
              const SizedBox(height: BafSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onAddEntry,
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('Add diary entry'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  final JobDiaryEntry entry;

  const _DiaryEntryCard(this.entry);

  @override
  Widget build(BuildContext context) {
    final color = _diaryColor(entry);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(_diaryIcon(entry.kind), color: color, size: 21),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(
                          label: _diaryKindLabel(entry.kind),
                          color: color,
                        ),
                        StatusBadge(
                          label: _disciplineLabel(entry.discipline),
                          color: _disciplineColor(entry.discipline),
                        ),
                        StatusBadge(
                          label: _titleCase(entry.severity.name),
                          color: _diarySeverityColor(entry.severity),
                        ),
                        if (entry.blockerStatus != null)
                          StatusBadge(
                            label: _blockerStatusLabel(entry.blockerStatus!),
                            color:
                                entry.blockerStatus == JobBlockerStatus.open
                                    ? BafColors.danger
                                    : BafColors.sync,
                          ),
                        if (entry.requiresFollowUp)
                          const StatusBadge(
                            label: 'Follow-up',
                            color: BafColors.warning,
                            icon: Icons.flag_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Text(
            entry.note,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_hasText(entry.actionTaken)) ...[
            const SizedBox(height: BafSpacing.sm),
            _TextBlock(label: 'Action taken', text: entry.actionTaken!.trim()),
          ],
          if (_hasText(entry.pendingIssue)) ...[
            const SizedBox(height: BafSpacing.sm),
            _TextBlock(
              label: 'Pending issue',
              text: entry.pendingIssue!.trim(),
            ),
          ],
          const SizedBox(height: BafSpacing.sm),
          _CompactInfoGrid(
            rows: [
              _InfoPair('By', entry.createdByName),
              _InfoPair('Time', _formatDateTime(entry.createdAt)),
              _InfoPair('Target', entry.targetRef),
              _InfoPair('Procedure', entry.procedureRef),
              _InfoPair('Section', entry.functionalSection),
              _InfoPair('Component', entry.componentGroup),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiaryEntryDraft {
  final JobDiaryKind kind;
  final JobDiaryDiscipline discipline;
  final JobDiarySeverity severity;
  final String? title;
  final String note;
  final String? functionalSection;
  final String? componentGroup;
  final String? targetRef;
  final String? procedureRef;
  final String? actionTaken;
  final String? pendingIssue;
  final bool requiresFollowUp;

  const _DiaryEntryDraft({
    required this.kind,
    required this.discipline,
    required this.severity,
    required this.title,
    required this.note,
    required this.functionalSection,
    required this.componentGroup,
    required this.targetRef,
    required this.procedureRef,
    required this.actionTaken,
    required this.pendingIssue,
    required this.requiresFollowUp,
  });
}

class _AddDiaryEntrySheet extends StatefulWidget {
  final JobDiaryDiscipline initialDiscipline;

  const _AddDiaryEntrySheet({required this.initialDiscipline});

  @override
  State<_AddDiaryEntrySheet> createState() => _AddDiaryEntrySheetState();
}

class _AddDiaryEntrySheetState extends State<_AddDiaryEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _functionalSectionController = TextEditingController();
  final _componentGroupController = TextEditingController();
  final _targetRefController = TextEditingController();
  final _procedureRefController = TextEditingController();
  final _actionTakenController = TextEditingController();
  final _pendingIssueController = TextEditingController();

  JobDiaryKind _kind = JobDiaryKind.note;
  late JobDiaryDiscipline _discipline;
  JobDiarySeverity _severity = JobDiarySeverity.medium;
  bool _requiresFollowUp = false;

  @override
  void initState() {
    super.initState();
    _discipline = widget.initialDiscipline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _functionalSectionController.dispose();
    _componentGroupController.dispose();
    _targetRefController.dispose();
    _procedureRefController.dispose();
    _actionTakenController.dispose();
    _pendingIssueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        bottomInset + BafSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.add_comment_rounded,
                      color: BafColors.planned,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add diary entry',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Save a running note, handover or blocker without completing the job.',
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
              const SizedBox(height: BafSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<JobDiaryKind>(
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: _sheetInputDecoration('Type'),
                      items:
                          JobDiaryKind.values
                              .map(
                                (kind) => DropdownMenuItem(
                                  value: kind,
                                  child: Text(
                                    _diaryKindLabel(kind),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _kind = value;
                          if (_kind == JobDiaryKind.blocker) {
                            _severity = JobDiarySeverity.high;
                            _requiresFollowUp = true;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<JobDiaryDiscipline>(
                      initialValue: _discipline,
                      isExpanded: true,
                      decoration: _sheetInputDecoration('Lane'),
                      items:
                          JobDiaryDiscipline.values
                              .map(
                                (discipline) => DropdownMenuItem(
                                  value: discipline,
                                  child: Text(
                                    _disciplineLabel(discipline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _discipline = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<JobDiarySeverity>(
                initialValue: _severity,
                isExpanded: true,
                decoration: _sheetInputDecoration('Severity'),
                items:
                    JobDiarySeverity.values
                        .map(
                          (severity) => DropdownMenuItem(
                            value: severity,
                            child: Text(
                              _titleCase(severity.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _severity = value);
                },
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _titleController,
                decoration: _sheetInputDecoration('Title (optional)'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _noteController,
                minLines: 4,
                maxLines: 7,
                decoration: _sheetInputDecoration('Diary note *'),
                validator:
                    (value) => _hasText(value) ? null : 'Enter the note.',
              ),
              const SizedBox(height: BafSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _functionalSectionController,
                      decoration: _sheetInputDecoration('Section'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _componentGroupController,
                      decoration: _sheetInputDecoration('Component'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetRefController,
                      decoration: _sheetInputDecoration('Target/tag'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _procedureRefController,
                      decoration: _sheetInputDecoration('Procedure ref'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _actionTakenController,
                minLines: 2,
                maxLines: 4,
                decoration: _sheetInputDecoration('Action taken (optional)'),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _pendingIssueController,
                minLines: 2,
                maxLines: 4,
                decoration: _sheetInputDecoration(
                  'Pending issue / handover note',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              CheckboxListTile(
                value: _requiresFollowUp,
                contentPadding: EdgeInsets.zero,
                activeColor: BafColors.warning,
                title: const Text(
                  'Requires follow-up',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Flag this entry in the final dossier.',
                  style: TextStyle(color: BafColors.textSecondary),
                ),
                onChanged: (value) {
                  setState(() => _requiresFollowUp = value ?? false);
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
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save entry'),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      _DiaryEntryDraft(
        kind: _kind,
        discipline: _discipline,
        severity: _severity,
        title: _cleanOptionalString(_titleController.text),
        note: _noteController.text.trim(),
        functionalSection: _cleanOptionalString(
          _functionalSectionController.text,
        ),
        componentGroup: _cleanOptionalString(_componentGroupController.text),
        targetRef: _cleanOptionalString(_targetRefController.text),
        procedureRef: _cleanOptionalString(_procedureRefController.text),
        actionTaken: _cleanOptionalString(_actionTakenController.text),
        pendingIssue: _cleanOptionalString(_pendingIssueController.text),
        requiresFollowUp: _requiresFollowUp,
      ),
    );
  }
}

InputDecoration _sheetInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: BafColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.planned, width: 1.4),
    ),
  );
}
