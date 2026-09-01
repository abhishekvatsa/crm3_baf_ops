import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/baf_ui.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../domain/morning_review_models.dart';
import '../services/morning_review_command_service.dart';

Future<MorningReviewEntryInput?> showMorningReviewEntryEditor(
  BuildContext context, {
  required List<AssetInstanceRecord> assets,
  required List<MorningReviewEntryKind> allowedKinds,
  MorningReviewSourceFact? sourceFact,
  MorningReviewEntryKind? initialKind,
}) => showDialog<MorningReviewEntryInput>(
  context: context,
  builder:
      (_) => _MorningReviewEntryEditor(
        assets: assets,
        allowedKinds: allowedKinds,
        sourceFact: sourceFact,
        initialKind: initialKind,
      ),
);

Future<MorningReviewActionInput?> showMorningReviewActionEditor(
  BuildContext context, {
  required List<AssetInstanceRecord> assets,
  required List<MorningReviewParticipant> participants,
  MorningReviewSection initialSection = MorningReviewSection.plantWide,
}) => showDialog<MorningReviewActionInput>(
  context: context,
  builder:
      (_) => _MorningReviewActionEditor(
        assets: assets,
        participants: participants,
        initialSection: initialSection,
      ),
);

Future<MorningReviewStandingConcernInput?>
showMorningReviewStandingConcernEditor(BuildContext context) =>
    showDialog<MorningReviewStandingConcernInput>(
      context: context,
      builder: (_) => const _MorningReviewStandingConcernEditor(),
    );

Future<MorningReviewConcernCheckInput?> showMorningReviewConcernCheckEditor(
  BuildContext context, {
  required MorningReviewStandingConcern concern,
}) => showDialog<MorningReviewConcernCheckInput>(
  context: context,
  builder: (_) => _MorningReviewConcernCheckEditor(concern: concern),
);

Future<String?> showMorningReviewTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? supportingText,
  int maximum = 2000,
  int minLines = 3,
}) => showDialog<String>(
  context: context,
  builder:
      (_) => _MorningReviewTextPrompt(
        title: title,
        label: label,
        actionLabel: actionLabel,
        supportingText: supportingText,
        maximum: maximum,
        minLines: minLines,
      ),
);

class MorningReviewConcernCheckInput {
  const MorningReviewConcernCheckInput({
    required this.state,
    required this.note,
  });

  final MorningReviewConcernCheckState state;
  final String note;
}

class _MorningReviewEntryEditor extends StatefulWidget {
  const _MorningReviewEntryEditor({
    required this.assets,
    required this.allowedKinds,
    required this.sourceFact,
    required this.initialKind,
  });

  final List<AssetInstanceRecord> assets;
  final List<MorningReviewEntryKind> allowedKinds;
  final MorningReviewSourceFact? sourceFact;
  final MorningReviewEntryKind? initialKind;

  @override
  State<_MorningReviewEntryEditor> createState() =>
      _MorningReviewEntryEditorState();
}

class _MorningReviewEntryEditorState extends State<_MorningReviewEntryEditor> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _provisionalClass = TextEditingController();
  final _provisionalNumber = TextEditingController();
  late MorningReviewSection _section;
  late MorningReviewEntryKind _kind;
  String _assetMode = 'none';
  String? _assetId;

  @override
  void initState() {
    super.initState();
    _section = widget.sourceFact?.section ?? MorningReviewSection.plantWide;
    _kind =
        widget.initialKind ??
        (widget.allowedKinds.contains(MorningReviewEntryKind.update)
            ? MorningReviewEntryKind.update
            : widget.allowedKinds.first);
    final source = widget.sourceFact;
    if (source?.assetInstanceId != null) {
      final matches = widget.assets.where(
        (asset) => asset.id == source!.assetInstanceId,
      );
      if (matches.isNotEmpty) {
        _assetMode = 'registered';
        _assetId = matches.first.id;
      } else {
        _assetMode = 'provisional';
        _provisionalClass.text = source?.assetClassName ?? '';
        _provisionalNumber.text = source?.assetNumber ?? '';
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _provisionalClass.dispose();
    _provisionalNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = [...widget.assets]..sort((left, right) {
      final byClass = left.assetClassName.compareTo(right.assetClassName);
      return byClass != 0
          ? byClass
          : left.assetNumber.compareTo(right.assetNumber);
    });
    return AlertDialog(
      title: Text(
        _kind == MorningReviewEntryKind.addendum
            ? 'Add meeting addendum'
            : widget.sourceFact == null
            ? 'Add meeting contribution'
            : 'Discuss source fact',
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.sourceFact != null) ...[
                  _SourceFactContext(fact: widget.sourceFact!),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<MorningReviewSection>(
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Agenda area'),
                  items:
                      MorningReviewSection.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                morningReviewSectionLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _section = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MorningReviewEntryKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Record as'),
                  items:
                      widget.allowedKinds
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                morningReviewEntryKindLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _kind = value!),
                ),
                const SizedBox(height: 16),
                _AssetTargetFields(
                  mode: _assetMode,
                  assetId: _assetId,
                  assets: assets,
                  provisionalClass: _provisionalClass,
                  provisionalNumber: _provisionalNumber,
                  onModeChanged:
                      (value) => setState(() {
                        _assetMode = value;
                        if (value != 'registered') _assetId = null;
                      }),
                  onAssetChanged:
                      (value) => setState(() {
                        _assetId = value;
                        final selected = _assetById(value);
                        if (selected != null) {
                          _section = _sectionForAsset(selected);
                        }
                      }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Update, decision or idea',
                    alignLabelWithHint: true,
                  ),
                  validator: _requiredText,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Add to review'),
        ),
      ],
    );
  }

  AssetInstanceRecord? _assetById(String? id) {
    if (id == null) return null;
    for (final asset in widget.assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final target = _assetTarget(
      mode: _assetMode,
      registered: _assetById(_assetId),
      provisionalClass: _provisionalClass.text,
      provisionalNumber: _provisionalNumber.text,
      sourceFact: widget.sourceFact,
    );
    if (target == null && _assetMode != 'none') return;
    Navigator.pop(
      context,
      MorningReviewEntryInput(
        section: _section,
        kind: _kind,
        text: _text.text,
        assetClassId: target?.assetClassId,
        assetClassName: target?.assetClassName,
        assetInstanceId: target?.assetInstanceId,
        assetNumber: target?.assetNumber,
        sourceReferences:
            widget.sourceFact == null
                ? const []
                : [
                  '${widget.sourceFact!.sourceCollection}/'
                      '${widget.sourceFact!.sourceDocumentId}',
                ],
      ),
    );
  }
}

class _MorningReviewActionEditor extends StatefulWidget {
  const _MorningReviewActionEditor({
    required this.assets,
    required this.participants,
    required this.initialSection,
  });

  final List<AssetInstanceRecord> assets;
  final List<MorningReviewParticipant> participants;
  final MorningReviewSection initialSection;

  @override
  State<_MorningReviewActionEditor> createState() =>
      _MorningReviewActionEditorState();
}

class _MorningReviewActionEditorState
    extends State<_MorningReviewActionEditor> {
  final _formKey = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _provisionalClass = TextEditingController();
  final _provisionalNumber = TextEditingController();
  late MorningReviewSection _section;
  String _assetMode = 'none';
  String? _assetId;
  String? _ownerKey;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void dispose() {
    _text.dispose();
    _provisionalClass.dispose();
    _provisionalNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = [...widget.assets]..sort((left, right) {
      final byClass = left.assetClassName.compareTo(right.assetClassName);
      return byClass != 0
          ? byClass
          : left.assetNumber.compareTo(right.assetNumber);
    });
    final owners = _ownerChoices(widget.participants);
    return AlertDialog(
      title: const Text('Create owned action'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MorningReviewSection>(
                  initialValue: _section,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Agenda area'),
                  items:
                      MorningReviewSection.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                morningReviewSectionLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _section = value!),
                ),
                const SizedBox(height: 16),
                _AssetTargetFields(
                  mode: _assetMode,
                  assetId: _assetId,
                  assets: assets,
                  provisionalClass: _provisionalClass,
                  provisionalNumber: _provisionalNumber,
                  onModeChanged:
                      (value) => setState(() {
                        _assetMode = value;
                        if (value != 'registered') _assetId = null;
                      }),
                  onAssetChanged:
                      (value) => setState(() {
                        _assetId = value;
                        final selected = _assetById(value);
                        if (selected != null) {
                          _section = _sectionForAsset(selected);
                        }
                      }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 1200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Action to be completed',
                    alignLabelWithHint: true,
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _ownerKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Responsible person or role',
                  ),
                  items:
                      owners
                          .map(
                            (choice) => DropdownMenuItem(
                              value: choice.key,
                              child: Text(
                                choice.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  validator:
                      (value) => value == null ? 'Select an owner.' : null,
                  onChanged: (value) => setState(() => _ownerKey = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(
                    _dueAt == null
                        ? 'No due time set'
                        : DateFormat('dd MMM yyyy, HH:mm').format(_dueAt!),
                  ),
                  subtitle: const Text('Optional commitment time'),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (_dueAt != null)
                        IconButton(
                          tooltip: 'Clear due time',
                          onPressed: () => setState(() => _dueAt = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        tooltip: 'Choose due time',
                        onPressed: _pickDueAt,
                        icon: const Icon(Icons.edit_calendar_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.assignment_add),
          label: const Text('Create action'),
        ),
      ],
    );
  }

  AssetInstanceRecord? _assetById(String? id) {
    if (id == null) return null;
    for (final asset in widget.assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _dueAt ?? now.add(const Duration(hours: 2)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final target = _assetTarget(
      mode: _assetMode,
      registered: _assetById(_assetId),
      provisionalClass: _provisionalClass.text,
      provisionalNumber: _provisionalNumber.text,
    );
    if (target == null && _assetMode != 'none') return;
    final owner = _ownerChoices(
      widget.participants,
    ).firstWhere((choice) => choice.key == _ownerKey);
    Navigator.pop(
      context,
      MorningReviewActionInput(
        section: _section,
        text: _text.text,
        assigneeUid: owner.userUid,
        assigneeRole: owner.roleKey,
        assetClassId: target?.assetClassId,
        assetClassName: target?.assetClassName,
        assetInstanceId: target?.assetInstanceId,
        assetNumber: target?.assetNumber,
        dueAt: _dueAt,
      ),
    );
  }
}

class _MorningReviewStandingConcernEditor extends StatefulWidget {
  const _MorningReviewStandingConcernEditor();

  @override
  State<_MorningReviewStandingConcernEditor> createState() =>
      _MorningReviewStandingConcernEditorState();
}

class _MorningReviewStandingConcernEditorState
    extends State<_MorningReviewStandingConcernEditor> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _detail = TextEditingController();
  MorningReviewConcernCriticality _criticality =
      MorningReviewConcernCriticality.standing;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add standing concern'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BafHorizontalControlRail(
                child: SegmentedButton<MorningReviewConcernCriticality>(
                  segments: const [
                    ButtonSegment(
                      value: MorningReviewConcernCriticality.standing,
                      icon: Icon(Icons.push_pin_outlined),
                      label: Text('Standing'),
                    ),
                    ButtonSegment(
                      value: MorningReviewConcernCriticality.safety,
                      icon: Icon(Icons.health_and_safety_outlined),
                      label: Text('Safety'),
                    ),
                  ],
                  selected: {_criticality},
                  onSelectionChanged:
                      (value) => setState(() => _criticality = value.single),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detail,
                minLines: 4,
                maxLines: 8,
                maxLength: 1600,
                decoration: const InputDecoration(
                  labelText: 'Condition to carry and verify',
                  alignLabelWithHint: true,
                ),
                validator: _requiredText,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            MorningReviewStandingConcernInput(
              title: _title.text,
              detail: _detail.text,
              criticality: _criticality,
            ),
          );
        },
        icon: const Icon(Icons.push_pin_outlined),
        label: const Text('Carry forward'),
      ),
    ],
  );
}

class _MorningReviewConcernCheckEditor extends StatefulWidget {
  const _MorningReviewConcernCheckEditor({required this.concern});

  final MorningReviewStandingConcern concern;

  @override
  State<_MorningReviewConcernCheckEditor> createState() =>
      _MorningReviewConcernCheckEditorState();
}

class _MorningReviewConcernCheckEditorState
    extends State<_MorningReviewConcernCheckEditor> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  MorningReviewConcernCheckState _state =
      MorningReviewConcernCheckState.complied;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.concern.title),
    content: SizedBox(
      width: 540,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BafHorizontalControlRail(
              child: SegmentedButton<MorningReviewConcernCheckState>(
                segments: const [
                  ButtonSegment(
                    value: MorningReviewConcernCheckState.complied,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Complied'),
                  ),
                  ButtonSegment(
                    value: MorningReviewConcernCheckState.exception,
                    icon: Icon(Icons.error_outline_rounded),
                    label: Text('Exception'),
                  ),
                ],
                selected: {_state},
                onSelectionChanged:
                    (value) => setState(() => _state = value.single),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              minLines: 3,
              maxLines: 7,
              maxLength: 1600,
              decoration: const InputDecoration(
                labelText: 'Today\'s verification note',
                alignLabelWithHint: true,
              ),
              validator: _requiredText,
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
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            MorningReviewConcernCheckInput(state: _state, note: _note.text),
          );
        },
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Record check'),
      ),
    ],
  );
}

class _MorningReviewTextPrompt extends StatefulWidget {
  const _MorningReviewTextPrompt({
    required this.title,
    required this.label,
    required this.actionLabel,
    required this.supportingText,
    required this.maximum,
    required this.minLines,
  });

  final String title;
  final String label;
  final String actionLabel;
  final String? supportingText;
  final int maximum;
  final int minLines;

  @override
  State<_MorningReviewTextPrompt> createState() =>
      _MorningReviewTextPromptState();
}

class _MorningReviewTextPromptState extends State<_MorningReviewTextPrompt> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 540,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.supportingText != null) ...[
              Text(widget.supportingText!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _controller,
              minLines: widget.minLines,
              maxLines: widget.minLines + 5,
              maxLength: widget.maximum,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: widget.label,
                alignLabelWithHint: true,
              ),
              validator: _requiredText,
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
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _controller.text.trim());
        },
        child: Text(widget.actionLabel),
      ),
    ],
  );
}

class _AssetTargetFields extends StatelessWidget {
  const _AssetTargetFields({
    required this.mode,
    required this.assetId,
    required this.assets,
    required this.provisionalClass,
    required this.provisionalNumber,
    required this.onModeChanged,
    required this.onAssetChanged,
  });

  final String mode;
  final String? assetId;
  final List<AssetInstanceRecord> assets;
  final TextEditingController provisionalClass;
  final TextEditingController provisionalNumber;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String?> onAssetChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder:
            (context, constraints) =>
                constraints.maxWidth < 440
                    ? DropdownButtonFormField<String>(
                      initialValue: mode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Asset scope',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('General / plant-wide'),
                        ),
                        DropdownMenuItem(
                          value: 'registered',
                          child: Text('Registered asset'),
                        ),
                        DropdownMenuItem(
                          value: 'provisional',
                          child: Text('Asset not yet registered'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onModeChanged(value);
                      },
                    )
                    : SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'none',
                          icon: Icon(Icons.public_outlined),
                          label: Text('General'),
                        ),
                        ButtonSegment(
                          value: 'registered',
                          icon: Icon(Icons.precision_manufacturing_outlined),
                          label: Text('Registered'),
                        ),
                        ButtonSegment(
                          value: 'provisional',
                          icon: Icon(Icons.add_box_outlined),
                          label: Text('Not registered'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged:
                          (value) => onModeChanged(value.single),
                    ),
      ),
      if (mode == 'registered') ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: assetId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Plant asset'),
          items:
              assets
                  .where((asset) => asset.isActive)
                  .map(
                    (asset) => DropdownMenuItem(
                      value: asset.id,
                      child: Text(
                        '${asset.assetClassName} ${asset.assetNumber}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          validator:
              (value) =>
                  mode == 'registered' && value == null
                      ? 'Select a registered asset.'
                      : null,
          onChanged: onAssetChanged,
        ),
      ],
      if (mode == 'provisional') ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: provisionalClass,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Unregistered asset class',
          ),
          validator:
              (value) => mode == 'provisional' ? _requiredText(value) : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: provisionalNumber,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Asset number / name'),
          validator:
              (value) => mode == 'provisional' ? _requiredText(value) : null,
        ),
      ],
    ],
  );
}

class _SourceFactContext extends StatelessWidget {
  const _SourceFactContext({required this.fact});

  final MorningReviewSourceFact fact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_done_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fact.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(fact.summary),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AssetTarget {
  const _AssetTarget({
    required this.assetClassId,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetNumber,
  });

  final String assetClassId;
  final String assetClassName;
  final String assetInstanceId;
  final String assetNumber;
}

class _OwnerChoice {
  const _OwnerChoice({
    required this.key,
    required this.label,
    this.userUid,
    this.roleKey,
  });

  final String key;
  final String label;
  final String? userUid;
  final String? roleKey;
}

List<_OwnerChoice> _ownerChoices(List<MorningReviewParticipant> participants) {
  final uniqueParticipants = <String, MorningReviewParticipant>{
    for (final participant in participants) participant.userUid: participant,
  };
  final people =
      uniqueParticipants.values.toList()
        ..sort((left, right) => left.userName.compareTo(right.userName));
  return [
    ...people.map(
      (participant) => _OwnerChoice(
        key: 'user:${participant.userUid}',
        label: '${participant.userName} · participant',
        userUid: participant.userUid,
      ),
    ),
    ...AppRole.values.map(
      (role) => _OwnerChoice(
        key: 'role:${role.name}',
        label: '${morningReviewRoleLabel(role.name)} · role',
        roleKey: role.name,
      ),
    ),
  ];
}

_AssetTarget? _assetTarget({
  required String mode,
  required AssetInstanceRecord? registered,
  required String provisionalClass,
  required String provisionalNumber,
  MorningReviewSourceFact? sourceFact,
}) {
  if (mode == 'none') return null;
  if (mode == 'registered' && registered != null) {
    return _AssetTarget(
      assetClassId: registered.assetClassId,
      assetClassName: registered.assetClassName,
      assetInstanceId: registered.id,
      assetNumber: '${registered.assetNumber}',
    );
  }
  final className = provisionalClass.trim();
  final number = provisionalNumber.trim();
  if (className.isEmpty || number.isEmpty) return null;
  if (sourceFact?.assetClassId != null &&
      sourceFact?.assetInstanceId != null &&
      sourceFact?.assetClassName == className &&
      sourceFact?.assetNumber == number) {
    return _AssetTarget(
      assetClassId: sourceFact!.assetClassId!,
      assetClassName: className,
      assetInstanceId: sourceFact.assetInstanceId!,
      assetNumber: number,
    );
  }
  final classKey = 'meeting-provisional:${_safeIdPart(className)}';
  return _AssetTarget(
    assetClassId: classKey,
    assetClassName: className,
    assetInstanceId: '$classKey:${_safeIdPart(number)}',
    assetNumber: number,
  );
}

MorningReviewSection _sectionForAsset(AssetInstanceRecord asset) {
  final key = '${asset.assetClassCode} ${asset.assetClassName}'.toLowerCase();
  if (key.contains('furnace')) return MorningReviewSection.furnace;
  if (key.contains('base') || key.contains('inner cover')) {
    return MorningReviewSection.base;
  }
  if (key.contains('forced cooler') || key.contains('force cooler')) {
    return MorningReviewSection.forcedCooler;
  }
  return MorningReviewSection.otherAsset;
}

String _safeIdPart(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_.-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty
      ? 'asset'
      : cleaned.substring(0, cleaned.length.clamp(0, 80));
}

String? _requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

String morningReviewSectionLabel(MorningReviewSection value) => switch (value) {
  MorningReviewSection.safety => 'Safety and standing concerns',
  MorningReviewSection.furnace => 'Furnaces',
  MorningReviewSection.base => 'Bases and Inner Covers',
  MorningReviewSection.forcedCooler => 'Forced Coolers',
  MorningReviewSection.otherAsset => 'Other assets',
  MorningReviewSection.plantWide => 'Plant-wide and general',
};

String morningReviewEntryKindLabel(MorningReviewEntryKind value) =>
    switch (value) {
      MorningReviewEntryKind.update => 'Update',
      MorningReviewEntryKind.observation => 'Observation',
      MorningReviewEntryKind.plan => 'Today\'s plan',
      MorningReviewEntryKind.blocker => 'Blocker / dependency',
      MorningReviewEntryKind.decision => 'Decision',
      MorningReviewEntryKind.idea => 'Idea / discussion point',
      MorningReviewEntryKind.currentCompliance =>
        'Current compliance · meeting update',
      MorningReviewEntryKind.remainingCompliance =>
        'Remaining compliance / today\'s commitment',
      MorningReviewEntryKind.maintenanceUpdate => 'Maintenance update',
      MorningReviewEntryKind.conclusion => 'Room conclusion',
      MorningReviewEntryKind.safetyConcern => 'Safety concern',
      MorningReviewEntryKind.standingConcernCheck => 'Standing concern check',
      MorningReviewEntryKind.addendum => 'Post-finalization addendum',
    };

String morningReviewRoleLabel(String role) => switch (role) {
  'admin' => 'Admin',
  'si' => 'SI',
  'contractSupervisor' => 'Contract Supervisor',
  'shiftSupervisor' => 'Shift Supervisor',
  'seniorElectrical' => 'Sr. Electrical',
  'seniorMechanical' => 'Sr. Mechanical',
  'seniorInstrumentation' => 'Sr. I&A',
  'seniorRefractory' => 'Sr. Refractory',
  'refractory' => 'Refractory',
  'operations' => 'Operations',
  _ => role,
};
