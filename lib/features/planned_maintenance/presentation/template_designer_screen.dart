// FILE: lib/features/planned_maintenance/presentation/template_designer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';

class TemplateDesignerScreen extends ConsumerStatefulWidget {
  final JobTemplate template;

  const TemplateDesignerScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateDesignerScreen> createState() =>
      _TemplateDesignerScreenState();
}

class _TemplateDesignerScreenState
    extends ConsumerState<TemplateDesignerScreen> {
  late List<TemplateField> _fields;
  FormatException? _fieldLoadError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final fieldRead = widget.template.fieldsReadResult;
    _fieldLoadError = fieldRead.error;
    _fields = List<TemplateField>.from(fieldRead.entries)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _addField() async {
    final field = await showDialog<TemplateField>(
      context: context,
      builder: (_) => const _FieldEditorDialog(),
    );

    if (!mounted || field == null) return;
    setState(() => _fields.add(field));
  }

  Future<void> _editField(int index) async {
    final updated = await showDialog<TemplateField>(
      context: context,
      builder: (_) => _FieldEditorDialog(field: _fields[index]),
    );

    if (!mounted || updated == null) return;
    setState(() => _fields[index] = updated);
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.canEditLegacyJobTemplate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admin/SI can edit job templates.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final orderedFields = <TemplateField>[];
      for (var i = 0; i < _fields.length; i++) {
        final f = _fields[i];
        orderedFields.add(
          TemplateField(
            key: f.key,
            label: f.label,
            type: f.type,
            isRequired: f.isRequired,
            order: i,
            unit: f.unit,
            options: f.options == null ? null : List<String>.from(f.options!),
            instructionText: f.instructionText,
            meta: f.meta == null ? null : Map<String, dynamic>.from(f.meta!),
            validation:
                f.validation == null
                    ? null
                    : Map<String, dynamic>.from(f.validation!),
            validationJson: f.validationJson,
            version: f.version,
            extensions: Map<String, dynamic>.from(f.extensions),
          ),
        );
      }

      final updatedTemplate =
          widget.template
            ..updatedAt = DateTime.now()
            ..isSynced = false;
      updatedTemplate.setFields(orderedFields);

      final repo = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      await repo.saveTemplate(updatedTemplate, actor: appUser);

      final syncOutcome =
          updatedTemplate.isSynced
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason: 'template_updated',
                force: true,
              );
      final (message, color) = switch (syncOutcome) {
        SyncRequestOutcome.succeeded => (
          'Template design saved and synchronized.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          'Template design saved on this device; synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          'Template design saved on this device, but cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };

      if (!mounted) return;

      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message), backgroundColor: color));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to save template: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fieldSubtitle(TemplateField field) {
    final parts = <String>[_typeLabel(field.type)];
    if (field.unit != null && field.unit!.isNotEmpty) {
      parts.add('unit: ${field.unit}');
    }
    final options = field.options ?? [];
    if (options.isNotEmpty) {
      parts.add('${options.length} options');
    }
    if (field.isRequired) parts.add('Required');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final fabBottomGap = BafSpacing.lg + bottomSafeInset;
    final listBottomPadding = 56 + fabBottomGap + BafSpacing.xl;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Template designer',
          subtitle: 'Build governed fields and maintenance evidence',
          icon: Icons.design_services_outlined,
          accent: BafColors.planned,
        ),
        actions: [
          IconButton(
            icon:
                _isSaving
                    ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_rounded),
            tooltip: 'Save template',
            onPressed: _isSaving || _fieldLoadError != null ? null : _save,
          ),
        ],
      ),
      floatingActionButton:
          _fieldLoadError == null
              ? SafeArea(
                minimum: EdgeInsets.only(
                  bottom: bottomSafeInset > 0 ? BafSpacing.sm : 0,
                ),
                child: FloatingActionButton.extended(
                  heroTag: 'designer_fab',
                  backgroundColor: BafColors.planned,
                  foregroundColor: Colors.white,
                  onPressed: _addField,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add Field',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              )
              : null,
      body:
          _fieldLoadError != null
              ? ListView(
                padding: const EdgeInsets.all(BafSpacing.lg),
                children: const [
                  PersistedDataIntegrityNotice(
                    title: 'Saved template fields need repair',
                    message:
                        'No fields were discarded or replaced. Editing is blocked until the saved field payload is repaired.',
                  ),
                ],
              )
              : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      BafSpacing.lg,
                      BafSpacing.sm,
                      BafSpacing.lg,
                      BafSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _DesignerHeader(
                        templateName: widget.template.jobName,
                        assetType:
                            widget.template.applicableAssetType.name
                                .toUpperCase(),
                        fieldCount: _fields.length,
                      ),
                    ),
                  ),
                  if (_fields.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyFieldsState(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        BafSpacing.lg,
                        BafSpacing.xs,
                        BafSpacing.lg,
                        listBottomPadding,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _fields.length,
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = _fields.removeAt(oldIndex);
                              _fields.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final field = _fields[index];
                            final isDisplayOnly =
                                field.type == FieldType.sectionHeader ||
                                field.type == FieldType.instruction;

                            return _FieldCard(
                              key: ValueKey(field.key),
                              index: index,
                              field: field,
                              subtitle: _fieldSubtitle(field),
                              isDisplayOnly: isDisplayOnly,
                              onTap: () => _editField(index),
                              onDelete: () => _removeField(index),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  static String _typeLabel(FieldType type) {
    switch (type) {
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.yesNo:
        return 'Yes / No';
      case FieldType.number:
        return 'Number';
      case FieldType.text:
        return 'Short Text';
      case FieldType.longText:
        return 'Long Text';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.multiSelect:
        return 'Multi-Select';
      case FieldType.dateTime:
        return 'Date & Time';
      case FieldType.sectionHeader:
        return 'Section Header';
      case FieldType.instruction:
        return 'Instruction';
    }
  }
}

class _DesignerHeader extends StatelessWidget {
  final String templateName;
  final String assetType;
  final int fieldCount;

  const _DesignerHeader({
    required this.templateName,
    required this.assetType,
    required this.fieldCount,
  });

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: const Icon(
              Icons.dynamic_form_rounded,
              color: BafColors.planned,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  templateName,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Build the checklist your attending team will complete in the field.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: assetType,
                      color: BafColors.assets,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    StatusBadge(
                      label: '$fieldCount fields',
                      color: BafColors.planned,
                      icon: Icons.format_list_bulleted_rounded,
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

class _EmptyFieldsState extends StatelessWidget {
  const _EmptyFieldsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: BafColors.card,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: BafColors.planned.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dynamic_form_outlined,
                  size: 38,
                  color: BafColors.planned,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No fields yet',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap “Add Field” to start building this job checklist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final int index;
  final TemplateField field;
  final String subtitle;
  final bool isDisplayOnly;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FieldCard({
    super.key,
    required this.index,
    required this.field,
    required this.subtitle,
    required this.isDisplayOnly,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisplayOnly ? BafColors.admin : BafColors.planned;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BafRadius.large),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(BafRadius.large),
              border: Border.all(color: BafColors.border),
              boxShadow: BafShadows.subtle,
              color: BafColors.card,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: BafColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                  ),
                  child: Icon(_fieldIcon(field.type), color: color, size: 24),
                ),
                const SizedBox(width: BafSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 15,
                          fontWeight:
                              isDisplayOnly ? FontWeight.w700 : FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: BafColors.danger,
                  ),
                  tooltip: 'Remove field',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _fieldIcon(FieldType type) {
    switch (type) {
      case FieldType.checkbox:
        return Icons.check_box_outlined;
      case FieldType.yesNo:
        return Icons.toggle_on_outlined;
      case FieldType.number:
        return Icons.numbers_rounded;
      case FieldType.text:
        return Icons.short_text_rounded;
      case FieldType.longText:
        return Icons.notes_rounded;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle_outlined;
      case FieldType.multiSelect:
        return Icons.checklist_rounded;
      case FieldType.dateTime:
        return Icons.calendar_today_outlined;
      case FieldType.sectionHeader:
        return Icons.title_rounded;
      case FieldType.instruction:
        return Icons.info_outline_rounded;
    }
  }
}

class _FieldEditorDialog extends StatefulWidget {
  final TemplateField? field;

  const _FieldEditorDialog({this.field});

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _unitController = TextEditingController();
  final _instructionController = TextEditingController();
  final _optionController = TextEditingController();

  late FieldType _type;
  bool _isRequired = false;
  List<String> _options = [];

  static const _displayTypes = {FieldType.sectionHeader, FieldType.instruction};

  static const _optionTypes = {FieldType.dropdown, FieldType.multiSelect};

  static const _unitTypes = {FieldType.number};

  static const _instructionTypes = {
    FieldType.instruction,
    FieldType.sectionHeader,
  };

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    _labelController.text = field?.label ?? '';
    _unitController.text = field?.unit ?? '';
    _instructionController.text = field?.instructionText ?? '';
    _type = field?.type ?? FieldType.text;
    _isRequired = field?.isRequired ?? false;
    _options = List<String>.from(field?.options ?? []);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _unitController.dispose();
    _instructionController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  void _addOption() {
    final text = _optionController.text.trim();
    if (text.isEmpty || _options.contains(text)) return;

    setState(() {
      _options.add(text);
      _optionController.clear();
    });
  }

  void _removeOption(String option) {
    setState(() => _options.remove(option));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_optionTypes.contains(_type) && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one option'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final field = TemplateField(
      key: widget.field?.key ?? const Uuid().v4(),
      label: _labelController.text.trim(),
      type: _type,
      isRequired: _displayTypes.contains(_type) ? false : _isRequired,
      order: widget.field?.order ?? DateTime.now().millisecondsSinceEpoch,
      unit:
          _unitTypes.contains(_type) && _unitController.text.trim().isNotEmpty
              ? _unitController.text.trim()
              : null,
      options: _optionTypes.contains(_type) ? _options : [],
      instructionText:
          _instructionTypes.contains(_type) &&
                  _instructionController.text.trim().isNotEmpty
              ? _instructionController.text.trim()
              : null,
      validation:
          widget.field?.validation == null
              ? null
              : Map<String, dynamic>.from(widget.field!.validation!),
      validationJson: widget.field?.validationJson,
      meta:
          widget.field?.meta == null
              ? null
              : Map<String, dynamic>.from(widget.field!.meta!),
      version: widget.field?.version ?? 1,
      extensions: Map<String, dynamic>.from(
        widget.field?.extensions ?? const <String, dynamic>{},
      ),
    );

    Navigator.pop(context, field);
  }

  @override
  Widget build(BuildContext context) {
    final isDisplayOnly = _displayTypes.contains(_type);
    final needsOptions = _optionTypes.contains(_type);
    final needsUnit = _unitTypes.contains(_type);
    final needsInstruction = _instructionTypes.contains(_type);

    return AlertDialog(
      backgroundColor: BafColors.card,
      surfaceTintColor: BafColors.card,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.lg,
        vertical: BafSpacing.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(
              widget.field == null ? Icons.add_rounded : Icons.edit_rounded,
              color: BafColors.planned,
              size: 21,
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              widget.field == null ? 'Add Field' : 'Edit Field',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<FieldType>(
              initialValue: _type,
              isExpanded: true,
              decoration: _dialogDecoration('Field type'),
              items:
                  FieldType.values
                      .map(
                        (type) => DropdownMenuItem<FieldType>(
                          value: type,
                          child: Text(
                            _typeLabel(type),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _type = value;
                  if (!_optionTypes.contains(value)) _options = [];
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: _dialogDecoration(
                isDisplayOnly ? 'Header / label' : 'Field label',
                hint:
                    isDisplayOnly
                        ? 'e.g. Safety checks'
                        : 'e.g. Zone 3 temperature',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            if (needsInstruction) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionController,
                maxLines: 2,
                decoration: _dialogDecoration(
                  'Instruction text',
                  hint: 'Optional guidance shown to technician',
                ),
              ),
            ],
            if (needsUnit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: _dialogDecoration(
                  'Unit',
                  hint: 'e.g. °C, bar, mm, RPM',
                ),
              ),
            ],
            if (needsOptions) ...[
              const SizedBox(height: 16),
              const Text(
                'Options',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (_options.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      _options
                          .map(
                            (option) => Chip(
                              label: Text(
                                option,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => _removeOption(option),
                            ),
                          )
                          .toList(),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _optionController,
                      decoration: _dialogDecoration(
                        'Add option',
                        hint: 'Type option and tap +',
                        dense: true,
                      ),
                      onFieldSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: BafColors.planned,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _addOption,
                    tooltip: 'Add option',
                  ),
                ],
              ),
            ],
            if (!isDisplayOnly) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _isRequired,
                onChanged:
                    (value) => setState(() => _isRequired = value ?? false),
                title: const Text('Required field'),
                subtitle: const Text(
                  'Technician must fill this before completing',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        0,
        BafSpacing.lg,
        BafSpacing.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton.icon(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.planned,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
          ),
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text(
            'Save Field',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  InputDecoration _dialogDecoration(
    String label, {
    String? hint,
    bool dense = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: dense,
      filled: true,
      fillColor: BafColors.background,
      labelStyle: const TextStyle(
        color: BafColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: BafColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }

  String _typeLabel(FieldType type) {
    switch (type) {
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.yesNo:
        return 'Yes / No';
      case FieldType.number:
        return 'Number';
      case FieldType.text:
        return 'Short Text';
      case FieldType.longText:
        return 'Long Text';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.multiSelect:
        return 'Multi-Select';
      case FieldType.dateTime:
        return 'Date & Time';
      case FieldType.sectionHeader:
        return 'Section Header';
      case FieldType.instruction:
        return 'Instruction';
    }
  }
}
