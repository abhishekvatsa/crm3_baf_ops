import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import '../domain/module_workshop_actions.dart';
import '../domain/module_composer_models.dart';
import '../domain/module_workshop_merge.dart';

class ModuleEditorScreen extends StatefulWidget {
  final ComposerModuleDraft module;

  const ModuleEditorScreen({super.key, required this.module});

  @override
  State<ModuleEditorScreen> createState() => _ModuleEditorScreenState();
}

class _ModuleEditorScreenState extends State<ModuleEditorScreen> {
  late ComposerModuleDraft _module;

  @override
  void initState() {
    super.initState();
    _module = cloneComposerModuleDraft(widget.module);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0.4,
        title: const Text('Focused Module Editor'),
        actions: [
          TextButton.icon(
            onPressed: _discard,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Discard'),
          ),
          const SizedBox(width: BafSpacing.sm),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save Module'),
          ),
          const SizedBox(width: BafSpacing.md),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(BafSpacing.md),
          children: [
            _EditorBanner(module: _module),
            if (hasUnresolvedMergeConflicts(_module)) ...[
              const SizedBox(height: BafSpacing.md),
              _MergeConflictWorkspaceCard(
                module: _module,
                onMarkResolved: () {
                  setState(() {
                    markMergeConflictsResolved(_module);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Merge conflicts marked resolved for this draft module.',
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: BafSpacing.md),
            _ModuleEditorCard(
              title: 'Module identity',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _module.moduleCode,
                          decoration: _inputDecoration(
                            'Module code',
                            Icons.tag_rounded,
                          ),
                          onChanged:
                              (value) => setState(
                                () => _module.moduleCode = value.trim(),
                              ),
                        ),
                      ),
                      const SizedBox(width: BafSpacing.md),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: const Key('module-editor-title-field'),
                          initialValue: _module.title,
                          decoration: _inputDecoration(
                            'Title',
                            Icons.title_rounded,
                          ),
                          onChanged:
                              (value) => setState(() => _module.title = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BafSpacing.md),
                  TextFormField(
                    initialValue: _module.description,
                    minLines: 2,
                    maxLines: 5,
                    decoration: _inputDecoration(
                      'Description / task basis',
                      Icons.notes_rounded,
                    ),
                    onChanged:
                        (value) => setState(() => _module.description = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            _ModuleEditorCard(
              title: 'Classification',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _assetDropdown()),
                      const SizedBox(width: BafSpacing.md),
                      Expanded(child: _disciplineDropdown()),
                    ],
                  ),
                  const SizedBox(height: BafSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _useModeDropdown()),
                      const SizedBox(width: BafSpacing.md),
                      Expanded(child: _frequencyDropdown()),
                    ],
                  ),
                  const SizedBox(height: BafSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _module.functionalSection,
                          decoration: _inputDecoration(
                            'Functional section',
                            Icons.account_tree_rounded,
                          ),
                          onChanged:
                              (value) => setState(
                                () => _module.functionalSection = value,
                              ),
                        ),
                      ),
                      const SizedBox(width: BafSpacing.md),
                      Expanded(
                        child: TextFormField(
                          initialValue: _module.componentGroup,
                          decoration: _inputDecoration(
                            'Component group',
                            Icons.category_rounded,
                          ),
                          onChanged:
                              (value) => setState(
                                () => _module.componentGroup = value,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BafSpacing.md),
                  TextFormField(
                    initialValue: _module.subsystem,
                    decoration: _inputDecoration(
                      'Subsystem / catalogue area',
                      Icons.hub_rounded,
                    ),
                    onChanged:
                        (value) => setState(() => _module.subsystem = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _module.requiredForClosure,
                    title: const Text('Required for closure'),
                    subtitle: const Text(
                      'Publishing still requires Admin/SI closure-critical review confirmation.',
                    ),
                    onChanged:
                        (value) =>
                            setState(() => _module.requiredForClosure = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            _ModuleEditorCard(
              title: 'Ownership and safety',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Owner disciplines',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: BafSpacing.xs),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      for (final owner in _ownerOptions)
                        FilterChip(
                          label: Text(_enumLabel(owner)),
                          selected: _module.ownerDisciplines.contains(owner),
                          onSelected:
                              (selected) => _toggleOwner(owner, selected),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _module.requiresJointReview,
                    title: const Text('Requires joint review'),
                    subtitle: const Text(
                      'Shared modules remain supervisor/Admin/SI controlled at execution time.',
                    ),
                    onChanged:
                        (value) =>
                            setState(() => _module.requiresJointReview = value),
                  ),
                  TextFormField(
                    initialValue: _module.safetyClasses.join(', '),
                    decoration: _inputDecoration(
                      'Safety classes',
                      Icons.health_and_safety_rounded,
                    ),
                    onChanged:
                        (value) => setState(
                          () => _module.safetyClasses = _splitComma(value),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            _ModuleEditorCard(
              title: 'Tags, procedures and references',
              child: Column(
                children: [
                  _csvField(
                    label: 'Device tags',
                    icon: Icons.sensors_rounded,
                    values: _module.deviceTagRefs,
                    onChanged:
                        (values) =>
                            _module.deviceTagRefs =
                                values.map((tag) => tag.toUpperCase()).toList(),
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  _csvField(
                    label: 'Target refs',
                    icon: Icons.account_tree_rounded,
                    values: _module.targetRefs,
                    onChanged: (values) => _module.targetRefs = values,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  _csvField(
                    label: 'Procedure refs',
                    icon: Icons.description_rounded,
                    values: _module.procedureRefs,
                    onChanged: (values) => _module.procedureRefs = values,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  _csvField(
                    label: 'Part refs',
                    icon: Icons.settings_rounded,
                    values: _module.partRefs,
                    onChanged: (values) => _module.partRefs = values,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  _csvField(
                    label: 'Operational preconditions',
                    icon: Icons.rule_rounded,
                    values: _module.operationalStatePreconditions,
                    onChanged:
                        (values) =>
                            _module.operationalStatePreconditions = values,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            _buildFieldsCard(),
            const SizedBox(height: BafSpacing.md),
            _buildChecklistCard(),
            const SizedBox(height: BafSpacing.md),
            _ModuleEditorCard(
              title: 'Authoring notes',
              child: TextFormField(
                initialValue: _module.authoringNotes,
                minLines: 2,
                maxLines: 5,
                decoration: _inputDecoration(
                  'Notes for future publisher/reviewer',
                  Icons.edit_note_rounded,
                ),
                onChanged:
                    (value) => setState(() => _module.authoringNotes = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetDropdown() {
    return DropdownButtonFormField<AssetType>(
      isExpanded: true,
      initialValue: _module.assetType,
      decoration: _inputDecoration(
        'Asset type',
        Icons.precision_manufacturing_rounded,
      ),
      items:
          AssetType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(_assetLabel(type)),
                ),
              )
              .toList(),
      onChanged:
          (value) =>
              setState(() => _module.assetType = value ?? _module.assetType),
    );
  }

  Widget _disciplineDropdown() {
    return DropdownButtonFormField<JobModuleDiscipline>(
      isExpanded: true,
      initialValue: _module.discipline,
      decoration: _inputDecoration('Discipline', Icons.groups_rounded),
      items:
          JobModuleDiscipline.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_enumLabel(value.name)),
                ),
              )
              .toList(),
      onChanged:
          (value) => setState(() {
            _module.discipline = value ?? _module.discipline;
            if (_module.discipline == JobModuleDiscipline.shared &&
                _module.ownerDisciplines.length < 2) {
              _module.requiresJointReview = true;
            }
          }),
    );
  }

  Widget _useModeDropdown() {
    return DropdownButtonFormField<JobModuleUseMode>(
      isExpanded: true,
      initialValue: _module.useMode,
      decoration: _inputDecoration('Use mode', Icons.work_history_rounded),
      items:
          JobModuleUseMode.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_enumLabel(value.name)),
                ),
              )
              .toList(),
      onChanged:
          (value) => setState(() => _module.useMode = value ?? _module.useMode),
    );
  }

  Widget _frequencyDropdown() {
    return DropdownButtonFormField<MaintenanceFrequency>(
      isExpanded: true,
      initialValue: _module.frequency,
      decoration: _inputDecoration('Frequency', Icons.event_repeat_rounded),
      items:
          MaintenanceFrequency.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_enumLabel(value.name)),
                ),
              )
              .toList(),
      onChanged:
          (value) =>
              setState(() => _module.frequency = value ?? _module.frequency),
    );
  }

  Widget _csvField({
    required String label,
    required IconData icon,
    required List<String> values,
    required ValueChanged<List<String>> onChanged,
  }) {
    return TextFormField(
      initialValue: values.join(', '),
      decoration: _inputDecoration(label, icon),
      onChanged: (value) => setState(() => onChanged(_splitComma(value))),
    );
  }

  Widget _buildFieldsCard() {
    final fields = [..._module.fields]
      ..sort((a, b) => a.order.compareTo(b.order));
    return _ModuleEditorCard(
      title: 'Field definitions',
      trailing: Wrap(
        spacing: BafSpacing.xs,
        children: [
          IconButton(
            tooltip: 'Add yes/no field',
            icon: const Icon(Icons.check_box_rounded, color: BafColors.sync),
            onPressed: () => _addField(ComposerFieldType.yesNo),
          ),
          IconButton(
            tooltip: 'Add numeric evidence field',
            icon: const Icon(Icons.speed_rounded, color: BafColors.planned),
            onPressed: () => _addField(ComposerFieldType.numericWithUnit),
          ),
          IconButton(
            tooltip: 'Add observation field',
            icon: const Icon(Icons.add_rounded, color: BafColors.planned),
            onPressed: () => _addField(ComposerFieldType.longText),
          ),
        ],
      ),
      child: Column(
        children: [
          if (fields.isEmpty)
            const Padding(
              padding: EdgeInsets.all(BafSpacing.sm),
              child: Text(
                'No fields yet.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          for (final field in fields)
            _EditableFieldTile(
              field: field,
              onRequiredChanged:
                  (value) => setState(() => field.isRequired = value),
              onEdit: () => _editField(field),
              onDuplicate: () => _duplicateField(field),
              onDelete: () => _deleteField(field),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    final items = [..._module.checklistItems]
      ..sort((a, b) => a.order.compareTo(b.order));
    return _ModuleEditorCard(
      title: 'Checklist / task items',
      trailing: IconButton(
        tooltip: 'Add checklist item',
        icon: const Icon(Icons.add_task_rounded, color: BafColors.planned),
        onPressed: _addChecklistItem,
      ),
      child: Column(
        children: [
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(BafSpacing.sm),
              child: Text(
                'No checklist items yet.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          for (final item in items)
            _EditableChecklistTile(
              item: item,
              onEdit: () => _editChecklistItem(item),
              onDuplicate: () => _duplicateChecklistItem(item),
              onDelete:
                  () => setState(() => _module.checklistItems.remove(item)),
            ),
        ],
      ),
    );
  }

  Future<void> _addField(ComposerFieldType type) async {
    final field = ComposerFieldDraft(
      key: _uniqueFieldKey('field_${_module.fields.length + 1}'),
      label: 'New field',
      type: type,
      isRequired: false,
      order: _module.fields.length + 1,
    );
    final edited = await _showFieldDialog(field, isNew: true);
    if (edited == null || !mounted) {
      return;
    }
    setState(() => _module.fields.add(edited));
  }

  Future<void> _editField(ComposerFieldDraft field) async {
    final edited = await _showFieldDialog(cloneComposerFieldDraft(field));
    if (edited == null || !mounted) {
      return;
    }
    setState(() {
      final index = _module.fields.indexOf(field);
      if (index >= 0) {
        _module.fields[index] = edited;
      }
    });
  }

  void _duplicateField(ComposerFieldDraft field) {
    setState(() {
      final duplicate = cloneComposerFieldDraft(field);
      duplicate.key = _uniqueFieldKey('${field.key}_copy');
      duplicate.label =
          field.label.trim().isEmpty
              ? 'Field copy'
              : '${field.label.trim()} (copy)';
      duplicate.order = _module.fields.length + 1;
      duplicate.meta['duplicatedFromFieldKey'] = field.key;
      _module.fields.add(duplicate);
    });
  }

  Future<void> _deleteField(ComposerFieldDraft field) async {
    if (field.isSafetyCriticalPreset) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Safety-critical field not removed here'),
              content: const Text(
                'Remove safety-critical preset fields from the inline composer path so the required safety justification is captured in TemplateVersion metadata.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }
    setState(() => _module.fields.remove(field));
  }

  Future<ComposerFieldDraft?> _showFieldDialog(
    ComposerFieldDraft initial, {
    bool isNew = false,
  }) async {
    return showDialog<ComposerFieldDraft>(
      context: context,
      builder:
          (context) => _ComposerFieldDraftDialog(
            initial: initial,
            isNew: isNew,
            uniqueFieldKey:
                (value) => _uniqueFieldKey(
                  value,
                  ignoreKey: isNew ? null : initial.key,
                ),
          ),
    );
  }

  Future<void> _addChecklistItem() async {
    final item = ComposerChecklistItemDraft(
      id: _uniqueChecklistId(
        '${_module.moduleCode}-item-${_module.checklistItems.length + 1}',
      ),
      title: 'New checklist item',
      isRequired: false,
      order: _module.checklistItems.length + 1,
    );
    final edited = await _showChecklistDialog(item, isNew: true);
    if (edited == null || !mounted) {
      return;
    }
    setState(() => _module.checklistItems.add(edited));
  }

  Future<void> _editChecklistItem(ComposerChecklistItemDraft item) async {
    final edited = await _showChecklistDialog(
      cloneComposerChecklistItemDraft(item),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() {
      final index = _module.checklistItems.indexOf(item);
      if (index >= 0) {
        _module.checklistItems[index] = edited;
      }
    });
  }

  void _duplicateChecklistItem(ComposerChecklistItemDraft item) {
    setState(() {
      final duplicate = cloneComposerChecklistItemDraft(item);
      duplicate.id = _uniqueChecklistId('${item.id}-copy');
      duplicate.title =
          item.title.trim().isEmpty
              ? 'Checklist item copy'
              : '${item.title.trim()} (copy)';
      duplicate.order = _module.checklistItems.length + 1;
      duplicate.metadata['duplicatedFromChecklistItemId'] = item.id;
      _module.checklistItems.add(duplicate);
    });
  }

  Future<ComposerChecklistItemDraft?> _showChecklistDialog(
    ComposerChecklistItemDraft initial, {
    bool isNew = false,
  }) async {
    return showDialog<ComposerChecklistItemDraft>(
      context: context,
      builder:
          (context) => _ComposerChecklistItemDraftDialog(
            initial: initial,
            isNew: isNew,
            uniqueChecklistId:
                (value) => _uniqueChecklistId(
                  value,
                  ignoreId: isNew ? null : initial.id,
                ),
          ),
    );
  }

  void _toggleOwner(String owner, bool selected) {
    setState(() {
      if (selected) {
        _module.ownerDisciplines =
            {..._module.ownerDisciplines, owner}.toList()..sort();
      } else {
        _module.ownerDisciplines =
            _module.ownerDisciplines.where((item) => item != owner).toList();
      }
      _module.requiresJointReview = _module.ownerDisciplines.length > 1;
      if (_module.ownerDisciplines.length > 1) {
        _module.discipline = JobModuleDiscipline.shared;
      }
      _module.primaryOwner =
          _module.ownerDisciplines.isEmpty
              ? null
              : _module.ownerDisciplines.first;
    });
  }

  void _discard() {
    Navigator.pop(context);
  }

  void _save() {
    Navigator.pop(context, _module);
  }

  String _uniqueFieldKey(String preferred, {String? ignoreKey}) {
    final existing =
        _module.fields
            .map((field) => field.key.toLowerCase())
            .where((key) => key != ignoreKey?.toLowerCase())
            .toSet();
    var key = _slugKey(preferred);
    if (key.isEmpty) {
      key = 'field_${_module.fields.length + 1}';
    }
    if (!existing.contains(key.toLowerCase())) {
      return key;
    }
    var suffix = 2;
    while (existing.contains('${key}_$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '${key}_$suffix';
  }

  String _uniqueChecklistId(String preferred, {String? ignoreId}) {
    final existing =
        _module.checklistItems
            .map((item) => item.id.toLowerCase())
            .where((id) => id != ignoreId?.toLowerCase())
            .toSet();
    var id =
        preferred.trim().isEmpty
            ? '${_module.moduleCode}-item-${_module.checklistItems.length + 1}'
            : preferred.trim();
    if (!existing.contains(id.toLowerCase())) {
      return id;
    }
    var suffix = 2;
    while (existing.contains('$id-$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '$id-$suffix';
  }
}

class _MergeConflictWorkspaceCard extends StatelessWidget {
  final ComposerModuleDraft module;
  final VoidCallback onMarkResolved;

  const _MergeConflictWorkspaceCard({
    required this.module,
    required this.onMarkResolved,
  });

  @override
  Widget build(BuildContext context) {
    final summaries = unresolvedMergeConflictSummaries(module);
    final renameSummaries = mergeFieldRenameSummaries(module);
    final count = unresolvedMergeConflictCount(module);
    return Container(
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.merge_type_rounded, color: BafColors.warning),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Merge conflict workspace',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: BafColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      '$count conflict${count == 1 ? '' : 's'} must be reviewed before this module can be saved to publisher.',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    const Text(
                      'When values differ, the first selected module is kept as the staged default; alternatives remain listed below.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summaries.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.md),
            for (final summary in summaries.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.xs),
                child: Text(
                  '• $summary',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ),
          ],
          if (renameSummaries.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.md),
            const Text(
              'Field-key rename staging',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            for (final rename in renameSummaries.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.xs),
                child: Text(
                  '• $rename',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ),
          ],
          const SizedBox(height: BafSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onMarkResolved,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark merge conflicts resolved'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorBanner extends StatelessWidget {
  final ComposerModuleDraft module;

  const _EditorBanner({required this.module});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.planned.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.view_module_rounded, color: BafColors.planned),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title.trim().isEmpty
                      ? 'Untitled module'
                      : module.title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  '${module.moduleCode} • ${_enumLabel(module.discipline.name)} • ${module.fields.length} fields • ${module.checklistItems.length} checklist items',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleEditorCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _ModuleEditorCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _ComposerFieldDraftDialog extends StatefulWidget {
  final ComposerFieldDraft initial;
  final bool isNew;
  final String Function(String value) uniqueFieldKey;

  const _ComposerFieldDraftDialog({
    required this.initial,
    required this.isNew,
    required this.uniqueFieldKey,
  });

  @override
  State<_ComposerFieldDraftDialog> createState() =>
      _ComposerFieldDraftDialogState();
}

class _ComposerFieldDraftDialogState extends State<_ComposerFieldDraftDialog> {
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
    final initial = widget.initial;
    _keyController = TextEditingController(text: initial.key);
    _labelController = TextEditingController(text: initial.label);
    _unitController = TextEditingController(text: initial.unit ?? '');
    _optionsController = TextEditingController(
      text: initial.options.join(', '),
    );
    _instructionController = TextEditingController(
      text: initial.instructionText,
    );
    _type = initial.type;
    _initialEvidenceRoleValue = initial.meta[kComposerEvidenceRoleMetaKey];
    _evidenceRole = initial.evidenceRole;
    _required = initial.isRequired;
    _safetyCritical = initial.isSafetyCriticalPreset;
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
      title: Text(widget.isNew ? 'Add field' : 'Edit field'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('module-editor-field-key-input'),
              controller: _keyController,
              decoration: _inputDecoration('Field key', Icons.key_rounded),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              key: const Key('module-editor-field-label-input'),
              controller: _labelController,
              decoration: _inputDecoration('Label', Icons.label_rounded),
            ),
            const SizedBox(height: BafSpacing.xs),
            Container(
              width: double.infinity,
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
                    key: const Key('module-editor-field-suggested-key'),
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('module-editor-field-use-suggested-key'),
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
              key: const Key('module-editor-field-evidence-role'),
              isExpanded: true,
              initialValue: _evidenceRole,
              decoration: _inputDecoration(
                'Evidence role',
                Icons.verified_user_rounded,
              ).copyWith(
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
                width: double.infinity,
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
                      key: const Key('module-editor-field-suggested-role'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    OutlinedButton(
                      key: const Key('module-editor-field-use-suggested-role'),
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
              decoration: _inputDecoration('Type', Icons.list_alt_rounded),
              items:
                  ComposerFieldType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_enumLabel(value.name)),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _unitController,
              decoration: _inputDecoration('Unit', Icons.straighten_rounded),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _optionsController,
              decoration: _inputDecoration(
                'Options, comma separated',
                Icons.checklist_rounded,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _instructionController,
              decoration: _inputDecoration(
                'Instruction text',
                Icons.notes_rounded,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _required,
              title: const Text('Required'),
              onChanged:
                  (value) => setState(() => _required = value ?? _required),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _safetyCritical,
              title: const Text('Safety critical preset'),
              onChanged:
                  (value) => setState(
                    () => _safetyCritical = value ?? _safetyCritical,
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final key = widget.uniqueFieldKey(_keyController.text);
    final nextMeta = Map<String, dynamic>.from(widget.initial.meta);
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
        key: key,
        label:
            _labelController.text.trim().isEmpty
                ? _enumLabel(key)
                : _labelController.text.trim(),
        type: _type,
        isRequired: _required,
        order: widget.initial.order,
        unit:
            _unitController.text.trim().isEmpty
                ? null
                : _unitController.text.trim(),
        options: _splitComma(_optionsController.text),
        instructionText: _instructionController.text.trim(),
        validation: cloneComposerMetadata(widget.initial.validation),
        meta: nextMeta,
        isSafetyCriticalPreset: _safetyCritical,
        sourcePresetId: widget.initial.sourcePresetId,
      ),
    );
  }
}

class _ComposerChecklistItemDraftDialog extends StatefulWidget {
  final ComposerChecklistItemDraft initial;
  final bool isNew;
  final String Function(String value) uniqueChecklistId;

  const _ComposerChecklistItemDraftDialog({
    required this.initial,
    required this.isNew,
    required this.uniqueChecklistId,
  });

  @override
  State<_ComposerChecklistItemDraftDialog> createState() =>
      _ComposerChecklistItemDraftDialogState();
}

class _ComposerChecklistItemDraftDialogState
    extends State<_ComposerChecklistItemDraftDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkedFieldController;
  late final TextEditingController _safetyController;
  late bool _required;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _idController = TextEditingController(text: initial.id);
    _titleController = TextEditingController(text: initial.title);
    _descriptionController = TextEditingController(text: initial.description);
    _linkedFieldController = TextEditingController(
      text: initial.linkedFieldKey ?? '',
    );
    _safetyController = TextEditingController(
      text: initial.safetyClasses.join(', '),
    );
    _required = initial.isRequired;
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
      title: Text(widget.isNew ? 'Add checklist item' : 'Edit checklist item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: _inputDecoration('Item id', Icons.key_rounded),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration('Title', Icons.title_rounded),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _descriptionController,
              decoration: _inputDecoration('Description', Icons.notes_rounded),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _linkedFieldController,
              decoration: _inputDecoration(
                'Linked field key',
                Icons.link_rounded,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            TextField(
              controller: _safetyController,
              decoration: _inputDecoration(
                'Safety classes',
                Icons.health_and_safety_rounded,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _required,
              title: const Text('Required'),
              onChanged:
                  (value) => setState(() => _required = value ?? _required),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final id = widget.uniqueChecklistId(_idController.text);
    Navigator.pop(
      context,
      ComposerChecklistItemDraft(
        id: id,
        title:
            _titleController.text.trim().isEmpty
                ? 'Checklist item'
                : _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        isRequired: _required,
        order: widget.initial.order,
        linkedFieldKey:
            _linkedFieldController.text.trim().isEmpty
                ? null
                : _linkedFieldController.text.trim(),
        safetyClasses: _splitComma(_safetyController.text),
        metadata: cloneComposerMetadata(widget.initial.metadata),
      ),
    );
  }
}

class _EditableFieldTile extends StatelessWidget {
  final ComposerFieldDraft field;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _EditableFieldTile({
    required this.field,
    required this.onRequiredChanged,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          field.label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${field.key} • ${_enumLabel(field.type.name)}'),
        leading: Checkbox(
          value: field.isRequired,
          onChanged: (value) => onRequiredChanged(value ?? field.isRequired),
        ),
        trailing: PopupMenuButton<_FieldAction>(
          key: Key('module-editor-field-menu-${field.key}'),
          onSelected: (action) {
            switch (action) {
              case _FieldAction.edit:
                onEdit();
                break;
              case _FieldAction.duplicate:
                onDuplicate();
                break;
              case _FieldAction.delete:
                onDelete();
                break;
            }
          },
          itemBuilder:
              (context) => const [
                PopupMenuItem(value: _FieldAction.edit, child: Text('Edit')),
                PopupMenuItem(
                  value: _FieldAction.duplicate,
                  child: Text('Duplicate'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _FieldAction.delete,
                  child: Text('Delete'),
                ),
              ],
        ),
      ),
    );
  }
}

class _EditableChecklistTile extends StatelessWidget {
  final ComposerChecklistItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _EditableChecklistTile({
    required this.item,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(item.id),
        leading: Icon(
          item.isRequired
              ? Icons.task_alt_rounded
              : Icons.check_circle_outline_rounded,
          color: item.isRequired ? BafColors.success : BafColors.textSecondary,
        ),
        trailing: PopupMenuButton<_ChecklistAction>(
          onSelected: (action) {
            switch (action) {
              case _ChecklistAction.edit:
                onEdit();
                break;
              case _ChecklistAction.duplicate:
                onDuplicate();
                break;
              case _ChecklistAction.delete:
                onDelete();
                break;
            }
          },
          itemBuilder:
              (context) => const [
                PopupMenuItem(
                  value: _ChecklistAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: _ChecklistAction.duplicate,
                  child: Text('Duplicate'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _ChecklistAction.delete,
                  child: Text('Delete'),
                ),
              ],
        ),
      ),
    );
  }
}

enum _FieldAction { edit, duplicate, delete }

enum _ChecklistAction { edit, duplicate, delete }

const _ownerOptions = <String>[
  'mechanical',
  'instrumentation',
  'electrical',
  'operations',
  'refractory',
];

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

List<String> _splitComma(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _slugKey(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug;
}

String _assetLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Forced Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
    case AssetType.governedCustom:
      return 'Governed Asset';
  }
}

String _enumLabel(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => ' ${match.group(0)}',
  );
  return spaced
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            part.length == 1
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
