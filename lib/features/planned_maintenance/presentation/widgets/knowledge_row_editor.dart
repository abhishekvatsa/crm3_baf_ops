// FILE: lib/features/planned_maintenance/presentation/widgets/knowledge_row_editor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/data/user_model.dart';
import '../../data/baf_knowledge_model.dart';
import '../../domain/baf_knowledge_layer.dart';
import '../../domain/knowledge_governance_diff.dart';
import '../../domain/knowledge_governance_models.dart';
import '../../domain/module_composer_models.dart';
import '../../providers/knowledge_governance_provider.dart';

class KnowledgeRowEditor extends ConsumerStatefulWidget {
  final AppUser actor;
  final BafKnowledgeRow? before;
  final bool isCreate;

  const KnowledgeRowEditor._({
    required this.actor,
    required this.isCreate,
    this.before,
  });

  factory KnowledgeRowEditor.forCreate({required AppUser actor}) =>
      KnowledgeRowEditor._(actor: actor, isCreate: true);

  factory KnowledgeRowEditor.forUpdate({
    required AppUser actor,
    required BafKnowledgeRow before,
  }) => KnowledgeRowEditor._(actor: actor, isCreate: false, before: before);

  @override
  ConsumerState<KnowledgeRowEditor> createState() => _KnowledgeRowEditorState();
}

class _KnowledgeRowEditorState extends ConsumerState<KnowledgeRowEditor> {
  late KnowledgeRowDraft _draft;
  bool _saving = false;
  String? _error;

  late final TextEditingController _rowCodeController;
  late final TextEditingController _taskTextController;
  late final TextEditingController _moduleCandidateController;
  late final TextEditingController _assetFamilyController;
  late final TextEditingController _functionalSectionController;
  late final TextEditingController _componentGroupController;
  late final TextEditingController _taskTypeController;
  late final TextEditingController _consultQuestionController;
  late final TextEditingController _sourceManualController;
  late final TextEditingController _sourcePageController;
  late final TextEditingController _ownerDisciplinesController;
  late final TextEditingController _safetyClassesController;
  late final TextEditingController _procedureRefsController;
  late final TextEditingController _partRefsController;
  late final TextEditingController _deviceTagsController;
  late final TextEditingController _targetRefsController;
  late final TextEditingController _suggestedFieldsController;
  late final TextEditingController _changeReasonController;

  @override
  void initState() {
    super.initState();
    _draft =
        widget.before == null
            ? KnowledgeRowDraft.blank()
            : KnowledgeRowDraft.fromRow(widget.before!);
    _rowCodeController = TextEditingController(text: _draft.rowCode);
    _taskTextController = TextEditingController(text: _draft.taskText);
    _moduleCandidateController = TextEditingController(
      text: _draft.moduleCandidateCode,
    );
    _assetFamilyController = TextEditingController(text: _draft.assetFamily);
    _functionalSectionController = TextEditingController(
      text: _draft.functionalSection,
    );
    _componentGroupController = TextEditingController(
      text: _draft.componentGroup,
    );
    _taskTypeController = TextEditingController(text: _draft.taskType);
    _consultQuestionController = TextEditingController(
      text: _draft.consultQuestion,
    );
    _sourceManualController = TextEditingController(text: _draft.sourceManual);
    _sourcePageController = TextEditingController(text: _draft.sourcePage);
    _ownerDisciplinesController = TextEditingController(
      text: _draft.ownerDisciplines.join(', '),
    );
    _safetyClassesController = TextEditingController(
      text: _draft.safetyClasses.join(', '),
    );
    _procedureRefsController = TextEditingController(
      text: _draft.procedureRefs.join(', '),
    );
    _partRefsController = TextEditingController(
      text: _draft.partRefs.join(', '),
    );
    _deviceTagsController = TextEditingController(
      text: _draft.deviceTags.join(', '),
    );
    _targetRefsController = TextEditingController(
      text: _draft.targetRefs.join(', '),
    );
    _suggestedFieldsController = TextEditingController(
      text: _draft.suggestedFields.join(', '),
    );
    _changeReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _rowCodeController.dispose();
    _taskTextController.dispose();
    _moduleCandidateController.dispose();
    _assetFamilyController.dispose();
    _functionalSectionController.dispose();
    _componentGroupController.dispose();
    _taskTypeController.dispose();
    _consultQuestionController.dispose();
    _sourceManualController.dispose();
    _sourcePageController.dispose();
    _ownerDisciplinesController.dispose();
    _safetyClassesController.dispose();
    _procedureRefsController.dispose();
    _partRefsController.dispose();
    _deviceTagsController.dispose();
    _targetRefsController.dispose();
    _suggestedFieldsController.dispose();
    _changeReasonController.dispose();
    super.dispose();
  }

  void _harvestControllers() {
    _draft.rowCode = _rowCodeController.text.trim();
    _draft.taskText = _taskTextController.text;
    _draft.moduleCandidateCode = _moduleCandidateController.text.trim();
    _draft.assetFamily = _assetFamilyController.text.trim();
    _draft.functionalSection = _functionalSectionController.text.trim();
    _draft.componentGroup = _componentGroupController.text.trim();
    _draft.taskType = _taskTypeController.text.trim();
    _draft.consultQuestion = _consultQuestionController.text;
    _draft.sourceManual = _sourceManualController.text;
    _draft.sourcePage = _sourcePageController.text;
    _draft.ownerDisciplines = _splitList(_ownerDisciplinesController.text);
    _draft.safetyClasses = _splitList(_safetyClassesController.text);
    _draft.procedureRefs = _splitList(_procedureRefsController.text);
    _draft.partRefs = _splitList(_partRefsController.text);
    _draft.deviceTags =
        _splitList(
          _deviceTagsController.text,
        ).map((tag) => tag.toUpperCase()).toList();
    _draft.targetRefs = _splitList(_targetRefsController.text);
    _draft.suggestedFields = _splitList(_suggestedFieldsController.text);
    _draft.changeSummary = _changeReasonController.text.trim();
  }

  List<String> _splitList(String value) {
    return value
        .split(RegExp(r'[,;]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: BafColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(BafRadius.medium),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BafColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.md,
                  BafSpacing.lg,
                  BafSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.isCreate ? 'New knowledge row' : 'Edit row',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: BafColors.textPrimary,
                        ),
                      ),
                    ),
                    if (widget.before != null)
                      StatusBadge(
                        label:
                            'v${widget.before!.version} → v${widget.before!.version + 1}',
                        color: BafColors.audit,
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: BafSpacing.lg),
                  padding: const EdgeInsets.all(BafSpacing.sm),
                  decoration: BoxDecoration(
                    color: BafColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                    border: Border.all(
                      color: BafColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: BafColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.sm,
                    BafSpacing.lg,
                    BafSpacing.md,
                  ),
                  children: [
                    _section('Identity'),
                    _field(
                      'Row code',
                      _rowCodeController,
                      enabled: widget.isCreate,
                    ),
                    _field('Module candidate code', _moduleCandidateController),
                    _field(
                      'Matrix version',
                      null,
                      textValue: _draft.matrixVersion,
                      enabled: false,
                    ),
                    _section('Task'),
                    _field('Task text', _taskTextController, maxLines: 3),
                    _field('Task type', _taskTypeController),
                    _field(
                      'Frequency',
                      null,
                      textValue: _draft.frequency,
                      enabled: false,
                    ),
                    _section('Asset taxonomy'),
                    _field('Asset family', _assetFamilyController),
                    _field('Functional section', _functionalSectionController),
                    _field('Component group', _componentGroupController),
                    _section('Owners and safety'),
                    _enumPicker(
                      label: 'Discipline',
                      value: _draft.discipline,
                      options: const [
                        'mechanical',
                        'electrical',
                        'instrumentation',
                        'operations',
                        'safety',
                        'shared',
                        'others',
                      ],
                      onChanged:
                          (value) => setState(() => _draft.discipline = value),
                    ),
                    _field(
                      'Owner disciplines (comma-separated)',
                      _ownerDisciplinesController,
                    ),
                    _field(
                      'Safety classes (comma-separated)',
                      _safetyClassesController,
                    ),
                    _section('References'),
                    _field(
                      'Procedure refs (comma-separated)',
                      _procedureRefsController,
                    ),
                    _field('Part refs (comma-separated)', _partRefsController),
                    _field(
                      'Device tags (comma-separated)',
                      _deviceTagsController,
                    ),
                    _field(
                      'Target refs (comma-separated)',
                      _targetRefsController,
                    ),
                    _field(
                      'Suggested field keys (comma-separated)',
                      _suggestedFieldsController,
                    ),
                    _section('Readiness'),
                    _enumPicker(
                      label: 'Composer readiness',
                      value: _draft.composerReadiness.name,
                      options:
                          ComposerReadiness.values
                              .map((value) => value.name)
                              .toList(),
                      onChanged: (value) {
                        for (final state in ComposerReadiness.values) {
                          if (state.name == value) {
                            setState(() => _draft.composerReadiness = state);
                            break;
                          }
                        }
                      },
                    ),
                    _enumPicker(
                      label: 'Confidence',
                      value: _draft.confidence.name,
                      options:
                          KnowledgeConfidence.values
                              .map((value) => value.name)
                              .toList(),
                      onChanged: (value) {
                        for (final state in KnowledgeConfidence.values) {
                          if (state.name == value) {
                            setState(() => _draft.confidence = state);
                            break;
                          }
                        }
                      },
                    ),
                    _enumPicker(
                      label: 'Required for closure',
                      value: _draft.requiredForClosure,
                      options: const ['yes', 'no', 'consult'],
                      onChanged:
                          (value) =>
                              setState(() => _draft.requiredForClosure = value),
                    ),
                    _enumPicker(
                      label: 'Resolver impact',
                      value: _draft.resolverImpact,
                      options: const ['yes', 'no'],
                      onChanged:
                          (value) =>
                              setState(() => _draft.resolverImpact = value),
                    ),
                    _enumPicker(
                      label: 'Lifecycle',
                      value: _draft.lifecycleStatus.name,
                      options:
                          KnowledgeLifecycleStatus.values
                              .map((value) => value.name)
                              .toList(),
                      onChanged:
                          (value) => setState(() {
                            _draft.lifecycleStatus =
                                KnowledgeLifecycleStatusX.parse(value);
                          }),
                      enabled: !widget.isCreate,
                    ),
                    _section('Provenance'),
                    _field('Source manual', _sourceManualController),
                    _field('Source page', _sourcePageController),
                    _field(
                      'Consult question',
                      _consultQuestionController,
                      maxLines: 2,
                    ),
                    _section('Change reason (audit)'),
                    TextField(
                      controller: _changeReasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Explain why this row is changing. ≥15 characters; must differ from prior version.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(BafRadius.small),
                        ),
                      ),
                    ),
                    if (widget.before != null) _diffPreview(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.sm,
                    BafSpacing.lg,
                    BafSpacing.md,
                  ),
                  child: Row(
                    children: [
                      if (!widget.isCreate &&
                          widget.before!.lifecycleStatus == 'active')
                        OutlinedButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : () => _lifecycle(
                                    KnowledgeLifecycleStatus.retired,
                                  ),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Retire'),
                        ),
                      if (!widget.isCreate &&
                          widget.before!.lifecycleStatus == 'retired')
                        OutlinedButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : () => _lifecycle(
                                    KnowledgeLifecycleStatus.archived,
                                  ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Archive'),
                        ),
                      if (!widget.isCreate &&
                          widget.before!.lifecycleStatus != 'active')
                        OutlinedButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : () => _lifecycle(
                                    KnowledgeLifecycleStatus.active,
                                  ),
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Restore'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        onPressed: _saving ? null : _onSave,
                        icon:
                            _saving
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.save_rounded),
                        label: Text(
                          widget.isCreate
                              ? 'Create'
                              : 'Save v${(widget.before?.version ?? 0) + 1}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.md, bottom: BafSpacing.xs),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: BafColors.textPrimary,
        letterSpacing: 0,
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController? controller, {
    int maxLines = 1,
    bool enabled = true,
    String? textValue,
  }) {
    final decoration = InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child:
          controller == null
              ? TextFormField(
                key: ValueKey('readonly_knowledge_field_$label'),
                initialValue: textValue ?? '',
                enabled: enabled,
                maxLines: maxLines,
                decoration: decoration,
              )
              : TextField(
                controller: controller,
                enabled: enabled,
                maxLines: maxLines,
                decoration: decoration,
              ),
    );
  }

  Widget _enumPicker({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : options.first,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        onChanged:
            enabled
                ? (v) {
                  if (v != null) onChanged(v);
                }
                : null,
        items:
            options
                .map(
                  (option) =>
                      DropdownMenuItem(value: option, child: Text(option)),
                )
                .toList(),
      ),
    );
  }

  Widget _diffPreview() {
    _harvestControllers();
    final diff = KnowledgeGovernanceDiff.between(
      before: widget.before,
      after: _draft,
    );
    if (diff.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: BafSpacing.md),
        child: Text(
          'No field changes detected. The save button will be rejected; lifecycle moves are separate actions.',
          style: TextStyle(fontSize: 12, color: BafColors.textSecondary),
        ),
      );
    }
    final lines = KnowledgeGovernanceDiff.summarise(diff);
    return Padding(
      padding: const EdgeInsets.only(top: BafSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(BafSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BafRadius.small),
          border: Border.all(color: BafColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diff preview (${diff.entries.length} change${diff.entries.length == 1 ? "" : "s"})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: BafColors.textPrimary,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_saving) {
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    _harvestControllers();
    if (_draft.matrixVersion.trim().isEmpty) {
      _draft.matrixVersion = BafKnowledgeLayer.matrixVersion;
    }
    final controller = ref.read(knowledgeGovernanceControllerProvider);
    try {
      if (widget.isCreate) {
        await controller.createRow(draft: _draft, actor: widget.actor);
      } else {
        await controller.updateRow(
          before: widget.before!,
          draft: _draft,
          actor: widget.actor,
        );
      }
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop<bool>(context, true);
      messenger?.showSnackBar(
        SnackBar(content: Text('Saved ${_draft.rowCode}.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  Future<void> _lifecycle(KnowledgeLifecycleStatus next) async {
    if (_saving) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _KnowledgeLifecycleReasonDialog(next: next),
    );
    if (!mounted || reason == null || reason.trim().isEmpty) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(knowledgeGovernanceControllerProvider);
    try {
      switch (next) {
        case KnowledgeLifecycleStatus.retired:
          await controller.retireRow(
            before: widget.before!,
            actor: widget.actor,
            reason: reason,
          );
          break;
        case KnowledgeLifecycleStatus.archived:
          await controller.archiveRow(
            before: widget.before!,
            actor: widget.actor,
            reason: reason,
          );
          break;
        case KnowledgeLifecycleStatus.active:
          await controller.restoreRow(
            before: widget.before!,
            actor: widget.actor,
            reason: reason,
          );
          break;
      }
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop<bool>(context, true);
      messenger?.showSnackBar(
        SnackBar(content: Text('${widget.before!.rowCode} → ${next.name}.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }
}

class _KnowledgeLifecycleReasonDialog extends StatefulWidget {
  final KnowledgeLifecycleStatus next;

  const _KnowledgeLifecycleReasonDialog({required this.next});

  @override
  State<_KnowledgeLifecycleReasonDialog> createState() =>
      _KnowledgeLifecycleReasonDialogState();
}

class _KnowledgeLifecycleReasonDialogState
    extends State<_KnowledgeLifecycleReasonDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleChanged);
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    final canSubmit = reason.length >= 15;
    final errorText =
        reason.isEmpty || canSubmit ? null : 'Enter at least 15 characters.';

    return AlertDialog(
      title: Text('Reason for ${widget.next.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: TextField(
            controller: _controller,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Why is this row being changed? ≥15 characters.',
              helperText:
                  'Minimum 15 characters for governed lifecycle changes.',
              errorText: errorText,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSubmit ? () => Navigator.pop(context, reason) : null,
          child: Text(widget.next.name),
        ),
      ],
    );
  }
}
