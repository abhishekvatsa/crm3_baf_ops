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

class _FieldEditorDialog extends StatefulWidget {
  final ComposerFieldDraft field;

  const _FieldEditorDialog({required this.field});

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late final TextEditingController _unitController;
  late final TextEditingController _optionsController;
  late final TextEditingController _instructionController;
  late ComposerFieldType _type;
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
    _required = widget.field.isRequired;
    _safetyCritical = widget.field.isSafetyCriticalPreset;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    _unitController.dispose();
    _optionsController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit field'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(labelText: 'Field key'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
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
          onPressed: () {
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
                meta: Map<String, dynamic>.from(widget.field.meta),
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
}

class _SavedTemplateDraftPickerDialog extends StatelessWidget {
  final List<_SavedTemplateDraftEntry> entries;

  const _SavedTemplateDraftPickerDialog({required this.entries});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saved Template Drafts'),
      content: SizedBox(
        width: 760,
        child:
            entries.isEmpty
                ? const Text(
                  'No saved TemplateVersion drafts are available for the active packages.',
                )
                : ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final version = entry.version;
                    final label = (version.versionLabel ?? '').trim();
                    final updatedAt = version.updatedAt.toLocal();
                    return ListTile(
                      key: Key(
                        'saved-template-draft-${version.firestoreId ?? version.id}',
                      ),
                      leading: const Icon(Icons.edit_note_rounded),
                      title: Text(
                        '${entry.package.packageCode} · v${version.versionNumber}'
                        '${label.isEmpty ? '' : ' · $label'}',
                      ),
                      subtitle: Text(
                        'Updated ${updatedAt.toIso8601String()}\n'
                        'By ${version.updatedByName ?? version.createdByName ?? 'unknown'}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(context, entry),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Resume'),
                      ),
                    );
                  },
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
