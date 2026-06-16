part of 'module_composer_screen.dart';

class _SeedCloudKnowledgeBaselineDialog extends StatefulWidget {
  const _SeedCloudKnowledgeBaselineDialog();

  @override
  State<_SeedCloudKnowledgeBaselineDialog> createState() =>
      _SeedCloudKnowledgeBaselineDialogState();
}

class _SeedCloudKnowledgeBaselineDialogState
    extends State<_SeedCloudKnowledgeBaselineDialog> {
  final _reasonController = TextEditingController();
  String _currentReason = '';

  bool get _canSeed =>
      _currentReason.trim().length >=
      BafKnowledgeRepository.changeReasonMinLength;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seed cloud knowledge baseline?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This writes the embedded BAF Knowledge Matrix safety baseline to the governed cloud knowledge_base collection. This is a governance/audit event.',
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Change reason / audit justification',
                  hintText:
                      'Example: Initial governed seed of BAF Knowledge Matrix v0.1 after SI review.',
                  helperText:
                      'Minimum ${BafKnowledgeRepository.changeReasonMinLength} characters required.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _currentReason = value),
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
        FilledButton.icon(
          onPressed:
              _canSeed
                  ? () => Navigator.pop(context, _currentReason.trim())
                  : null,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Seed cloud'),
        ),
      ],
    );
  }
}

class _SafetyCriticalFieldRemovalDialog extends StatefulWidget {
  final ComposerFieldDraft field;

  const _SafetyCriticalFieldRemovalDialog({required this.field});

  @override
  State<_SafetyCriticalFieldRemovalDialog> createState() =>
      _SafetyCriticalFieldRemovalDialogState();
}

class _SafetyCriticalFieldRemovalDialogState
    extends State<_SafetyCriticalFieldRemovalDialog> {
  final _controller = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _reason.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Safety-critical field removal'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Field: ${widget.field.label}'),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Reason is required before removing a safety-critical suggested field.',
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _controller,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Justification',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _reason = value),
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
          onPressed:
              canContinue
                  ? () => Navigator.pop(context, _controller.text.trim())
                  : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class ComposerFieldEditorDialog extends StatefulWidget {
  final ComposerFieldDraft field;

  const ComposerFieldEditorDialog({super.key, required this.field});

  @override
  State<ComposerFieldEditorDialog> createState() =>
      _ComposerFieldEditorDialogState();
}

class _ComposerFieldEditorDialogState extends State<ComposerFieldEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late final TextEditingController _unitController;
  late final TextEditingController _optionsController;
  late final TextEditingController _instructionController;
  late ComposerFieldType _type;
  late ComposerEvidenceRole _evidenceRole;
  late final Object? _initialEvidenceRoleValue;
  bool _evidenceRoleChanged = false;
  late bool _required;
  late bool _safetyCritical;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.field.key);
    _labelController = TextEditingController(text: widget.field.label);
    _unitController = TextEditingController(text: widget.field.unit ?? '');
    _optionsController = TextEditingController(
      text: widget.field.options.join(', '),
    );
    _instructionController = TextEditingController(
      text: widget.field.instructionText,
    );
    _type = widget.field.type;
    _initialEvidenceRoleValue = widget.field.meta[kComposerEvidenceRoleMetaKey];
    _evidenceRole = widget.field.evidenceRole;
    _required = widget.field.isRequired;
    _safetyCritical = widget.field.isSafetyCriticalPreset;
    _keyController.addListener(_refreshSemanticSuggestions);
    _labelController.addListener(_refreshSemanticSuggestions);
    _instructionController.addListener(_refreshSemanticSuggestions);
  }

  @override
  void dispose() {
    _keyController.removeListener(_refreshSemanticSuggestions);
    _labelController.removeListener(_refreshSemanticSuggestions);
    _instructionController.removeListener(_refreshSemanticSuggestions);
    _keyController.dispose();
    _labelController.dispose();
    _unitController.dispose();
    _optionsController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _refreshSemanticSuggestions() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedRole = suggestComposerEvidenceRole(
      '${_labelController.text} ${_keyController.text} '
      '${_instructionController.text}',
    );
    final roleForKeySuggestion =
        _evidenceRole == ComposerEvidenceRole.none
            ? suggestedRole
            : _evidenceRole;
    final suggestedKey = suggestedComposerFieldKey(
      label: _labelController.text,
      evidenceRole: roleForKeySuggestion,
    );
    final normalizedCurrentKey = _slugKey(_keyController.text);
    final canUseSuggestedKey =
        suggestedKey.isNotEmpty && normalizedCurrentKey != suggestedKey;

    return AlertDialog(
      title: const Text('Edit field'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('composer-field-label-input'),
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                key: const Key('composer-field-key-input'),
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Technical field key',
                  helperText:
                      'Stable machine-readable key used by validation and runtime evidence.',
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Container(
                padding: const EdgeInsets.all(BafSpacing.sm),
                decoration: BoxDecoration(
                  color: BafColors.sync.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                  border: Border.all(
                    color: BafColors.sync.withValues(alpha: 0.25),
                  ),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.xs,
                  children: [
                    Text(
                      'Suggested key: $suggestedKey',
                      key: const Key('composer-field-suggested-key'),
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('composer-field-use-suggested-key'),
                      onPressed:
                          canUseSuggestedKey
                              ? () => _keyController.text = suggestedKey
                              : null,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Use suggested key'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<ComposerEvidenceRole>(
                key: const Key('composer-field-evidence-role'),
                isExpanded: true,
                initialValue: _evidenceRole,
                decoration: const InputDecoration(
                  labelText: 'Evidence role',
                  helperText:
                      'Structured governance meaning stored in existing field metadata.',
                ),
                items: ComposerEvidenceRole.values
                    .map(
                      (role) => DropdownMenuItem<ComposerEvidenceRole>(
                        value: role,
                        child: Text(composerEvidenceRoleLabel(role)),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    (value) => setState(() {
                      _evidenceRoleChanged = true;
                      _evidenceRole = value ?? ComposerEvidenceRole.none;
                    }),
              ),
              if (suggestedRole != ComposerEvidenceRole.none &&
                  _evidenceRole == ComposerEvidenceRole.none) ...[
                const SizedBox(height: BafSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(BafSpacing.sm),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      Text(
                        'Suggested role: '
                        '${composerEvidenceRoleLabel(suggestedRole)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      OutlinedButton(
                        key: const Key('composer-field-use-suggested-role'),
                        onPressed:
                            () => setState(() {
                              _evidenceRoleChanged = true;
                              _evidenceRole = suggestedRole;
                            }),
                        child: const Text('Use suggested role'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<ComposerFieldType>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Field type'),
                items:
                    ComposerFieldType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_enumLabel(type.name)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit / source unit',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _optionsController,
                decoration: const InputDecoration(
                  labelText: 'Options, comma-separated',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _instructionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instruction / evidence guidance',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required field'),
                onChanged:
                    (value) => setState(() => _required = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _safetyCritical,
                title: const Text('Safety-critical preset / governed field'),
                subtitle: const Text(
                  'Deletion/material weakening should require justification.',
                ),
                onChanged:
                    (value) => setState(() => _safetyCritical = value ?? false),
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
          key: const Key('composer-field-save'),
          onPressed: () {
            final nextMeta = Map<String, dynamic>.from(widget.field.meta);
            if (_evidenceRole == ComposerEvidenceRole.none) {
              final initialRoleWasRecognized =
                  composerEvidenceRoleFromValue(_initialEvidenceRoleValue) !=
                  ComposerEvidenceRole.none;
              if (_evidenceRoleChanged || initialRoleWasRecognized) {
                nextMeta.remove(kComposerEvidenceRoleMetaKey);
              }
            } else {
              nextMeta[kComposerEvidenceRoleMetaKey] = _evidenceRole.name;
            }
            Navigator.pop(
              context,
              ComposerFieldDraft(
                key: _slugKey(_keyController.text),
                label:
                    _labelController.text.trim().isEmpty
                        ? 'Field'
                        : _labelController.text.trim(),
                type: _type,
                isRequired: _required,
                order: widget.field.order,
                unit:
                    _unitController.text.trim().isEmpty
                        ? null
                        : _unitController.text.trim(),
                options: _splitComma(_optionsController.text),
                instructionText: _instructionController.text.trim(),
                validation: Map<String, dynamic>.from(widget.field.validation),
                meta: nextMeta,
                isSafetyCriticalPreset: _safetyCritical,
                sourcePresetId: widget.field.sourcePresetId,
              ),
            );
          },
          child: const Text('Save field'),
        ),
      ],
    );
  }
}

class _ChecklistEditorDialog extends StatefulWidget {
  final ComposerChecklistItemDraft item;

  const _ChecklistEditorDialog({required this.item});

  @override
  State<_ChecklistEditorDialog> createState() => _ChecklistEditorDialogState();
}

class _ChecklistEditorDialogState extends State<_ChecklistEditorDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkedFieldController;
  late final TextEditingController _safetyController;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.item.id);
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _linkedFieldController = TextEditingController(
      text: widget.item.linkedFieldKey ?? '',
    );
    _safetyController = TextEditingController(
      text: widget.item.safetyClasses.join(', '),
    );
    _required = widget.item.isRequired;
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _linkedFieldController.dispose();
    _safetyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit checklist item'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Item id'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description / instruction',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _linkedFieldController,
                decoration: const InputDecoration(
                  labelText: 'Linked field key, optional',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _safetyController,
                decoration: const InputDecoration(
                  labelText: 'Safety classes, comma-separated',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required checklist item'),
                onChanged:
                    (value) => setState(() => _required = value ?? false),
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
          onPressed: () {
            Navigator.pop(
              context,
              ComposerChecklistItemDraft(
                id:
                    _idController.text.trim().isEmpty
                        ? widget.item.id
                        : _idController.text.trim(),
                title:
                    _titleController.text.trim().isEmpty
                        ? 'Checklist item'
                        : _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                isRequired: _required,
                order: widget.item.order,
                linkedFieldKey:
                    _linkedFieldController.text.trim().isEmpty
                        ? null
                        : _linkedFieldController.text.trim(),
                safetyClasses: _splitComma(_safetyController.text),
                metadata: Map<String, dynamic>.from(widget.item.metadata),
              ),
            );
          },
          child: const Text('Save item'),
        ),
      ],
    );
  }
}

class _SavedTemplateDraftEntry {
  final TemplatePackage package;
  final TemplateVersion version;

  const _SavedTemplateDraftEntry({
    required this.package,
    required this.version,
  });

  bool get canAttemptRestore => version.isArchivedDraft && version.isSynced;

  String get restoreGuidance {
    if (!version.isArchivedDraft) {
      return 'Only archived TemplateVersion drafts can be restored.';
    }
    if (!version.isSynced) {
      return 'Wait for the archived TemplateVersion state to synchronize before restoring it.';
    }
    return 'Restore will revalidate the synchronized archive audit in the governance repository before changing lifecycle state.';
  }
}

enum _SavedTemplateDraftAction { resume, archive, restore }

class _SavedTemplateDraftPickerResult {
  final _SavedTemplateDraftEntry entry;
  final _SavedTemplateDraftAction action;

  const _SavedTemplateDraftPickerResult({
    required this.entry,
    required this.action,
  });
}

class _SavedTemplateDraftPickerDialog extends StatelessWidget {
  final List<_SavedTemplateDraftEntry> entries;

  const _SavedTemplateDraftPickerDialog({required this.entries});

  @override
  Widget build(BuildContext context) {
    final activeEntries = entries
        .where((entry) => entry.version.isDraft)
        .toList(growable: false);
    final archivedEntries = entries
        .where((entry) => entry.version.isArchivedDraft)
        .toList(growable: false);

    return AlertDialog(
      scrollable: true,
      title: const Text('Governed Template Drafts'),
      content: SizedBox(
        width: 760,
        child:
            entries.isEmpty
                ? const Text(
                  'No active or archived TemplateVersion drafts are available for the active packages.',
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TemplateDraftGroupHeader(
                      title: 'Active drafts',
                      count: activeEntries.length,
                      description:
                          'Resume an active draft or archive it with a mandatory reason.',
                    ),
                    if (activeEntries.isEmpty)
                      const _TemplateDraftEmptyGroup(
                        message: 'No active saved drafts.',
                      )
                    else
                      ...activeEntries.map(
                        (entry) => _TemplateDraftEntryCard(
                          entry: entry,
                          onResume:
                              () => Navigator.pop(
                                context,
                                _SavedTemplateDraftPickerResult(
                                  entry: entry,
                                  action: _SavedTemplateDraftAction.resume,
                                ),
                              ),
                          onArchive:
                              () => Navigator.pop(
                                context,
                                _SavedTemplateDraftPickerResult(
                                  entry: entry,
                                  action: _SavedTemplateDraftAction.archive,
                                ),
                              ),
                        ),
                      ),
                    const SizedBox(height: BafSpacing.md),
                    _TemplateDraftGroupHeader(
                      title: 'Archived drafts',
                      count: archivedEntries.length,
                      description:
                          'Archived drafts remain recoverable under the same identity. The governance repository performs the final archive-audit readiness check.',
                    ),
                    if (archivedEntries.isEmpty)
                      const _TemplateDraftEmptyGroup(
                        message: 'No archived drafts.',
                      )
                    else
                      ...archivedEntries.map(
                        (entry) => _TemplateDraftEntryCard(
                          entry: entry,
                          onRestore:
                              entry.canAttemptRestore
                                  ? () => Navigator.pop(
                                    context,
                                    _SavedTemplateDraftPickerResult(
                                      entry: entry,
                                      action: _SavedTemplateDraftAction.restore,
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                  ],
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _TemplateDraftGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final String description;

  const _TemplateDraftGroupHeader({
    required this.title,
    required this.count,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ($count)',
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            description,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateDraftEmptyGroup extends StatelessWidget {
  final String message;

  const _TemplateDraftEmptyGroup({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(color: BafColors.textSecondary),
      ),
    );
  }
}

class _TemplateDraftEntryCard extends StatelessWidget {
  final _SavedTemplateDraftEntry entry;
  final VoidCallback? onResume;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _TemplateDraftEntryCard({
    required this.entry,
    this.onResume,
    this.onArchive,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final version = entry.version;
    final archived = version.isArchivedDraft;
    final label = (version.versionLabel ?? '').trim();
    final updatedAt = version.updatedAt.toLocal();
    final actorName =
        version.updatedByName ?? version.createdByName ?? 'unknown';

    return Container(
      key: Key(
        '${archived ? 'archived' : 'saved'}-template-draft-${version.firestoreId ?? version.id}',
      ),
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                archived ? Icons.archive_rounded : Icons.edit_note_rounded,
                color: archived ? BafColors.admin : BafColors.planned,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.package.packageCode} · v${version.versionNumber}'
                      '${label.isEmpty ? '' : ' · $label'}',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      'Updated ${updatedAt.toIso8601String()} · By $actorName',
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BafSpacing.sm,
                  vertical: BafSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (archived ? BafColors.admin : BafColors.warning)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  archived ? 'archived' : 'draft',
                  style: TextStyle(
                    color: archived ? BafColors.admin : BafColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (archived) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              entry.restoreGuidance,
              style: TextStyle(
                color:
                    entry.canAttemptRestore
                        ? BafColors.textSecondary
                        : BafColors.warning,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              if (!archived && onArchive != null)
                OutlinedButton.icon(
                  key: Key(
                    'archive-template-draft-${version.firestoreId ?? version.id}',
                  ),
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archive draft'),
                ),
              if (!archived && onResume != null)
                FilledButton.tonalIcon(
                  key: Key(
                    'resume-template-draft-${version.firestoreId ?? version.id}',
                  ),
                  onPressed: onResume,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Resume draft'),
                ),
              if (archived)
                Tooltip(
                  message: entry.restoreGuidance,
                  child: OutlinedButton.icon(
                    key: Key(
                      'restore-template-draft-${version.firestoreId ?? version.id}',
                    ),
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(
                      entry.canAttemptRestore
                          ? 'Restore draft'
                          : 'Awaiting archived state sync',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchiveTemplateDraftReasonDialog extends StatefulWidget {
  final _SavedTemplateDraftEntry entry;

  const _ArchiveTemplateDraftReasonDialog({required this.entry});

  @override
  State<_ArchiveTemplateDraftReasonDialog> createState() =>
      _ArchiveTemplateDraftReasonDialogState();
}

class _ArchiveTemplateDraftReasonDialogState
    extends State<_ArchiveTemplateDraftReasonDialog> {
  static const _minimumReasonLength = 10;

  final _reasonController = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.entry.version;
    final package = widget.entry.package;
    final canArchive = _reason.trim().length >= _minimumReasonLength;

    return AlertDialog(
      title: const Text('Discard/archive saved draft?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${package.packageCode} · v${version.versionNumber} will be archived as governed history. '
              'Its payload and audit trail will be retained, but it will no longer appear in the active draft picker.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('archive-template-draft-reason'),
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              onChanged: (value) => setState(() => _reason = value),
              decoration: const InputDecoration(
                labelText: 'Mandatory archive reason',
                helperText: 'Enter at least 10 characters.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('confirm-archive-template-draft'),
          style: FilledButton.styleFrom(backgroundColor: BafColors.danger),
          onPressed:
              canArchive ? () => Navigator.pop(context, _reason.trim()) : null,
          icon: const Icon(Icons.archive_rounded),
          label: const Text('Archive draft'),
        ),
      ],
    );
  }
}

class _RestoreTemplateDraftReasonDialog extends StatefulWidget {
  final _SavedTemplateDraftEntry entry;

  const _RestoreTemplateDraftReasonDialog({required this.entry});

  @override
  State<_RestoreTemplateDraftReasonDialog> createState() =>
      _RestoreTemplateDraftReasonDialogState();
}

class _RestoreTemplateDraftReasonDialogState
    extends State<_RestoreTemplateDraftReasonDialog> {
  static const _minimumReasonLength = 10;

  final _reasonController = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.entry.version;
    final package = widget.entry.package;
    final canRestore = _reason.trim().length >= _minimumReasonLength;

    return AlertDialog(
      title: const Text('Restore archived draft?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${package.packageCode} · v${version.versionNumber} will return to active draft authoring under the same Isar and Firestore identity. '
              'Its archived history remains preserved and a restored lifecycle audit will be created.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('restore-template-draft-reason'),
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              onChanged: (value) => setState(() => _reason = value),
              decoration: const InputDecoration(
                labelText: 'Mandatory restore reason',
                helperText: 'Enter at least 10 characters.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('confirm-restore-template-draft'),
          onPressed:
              canRestore ? () => Navigator.pop(context, _reason.trim()) : null,
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore draft'),
        ),
      ],
    );
  }
}
