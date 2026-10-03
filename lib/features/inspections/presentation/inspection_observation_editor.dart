part of 'inspection_programmes_screen.dart';

class _InspectionObservationEditor extends StatefulWidget {
  const _InspectionObservationEditor({
    required this.campaign,
    required this.nodes,
    required this.correction,
    required this.initialTargetKey,
    this.lockTarget = false,
  });

  final InspectionCampaign campaign;
  final List<AssetHierarchyNode> nodes;
  final InspectionObservation? correction;
  final String? initialTargetKey;
  final bool lockTarget;

  @override
  State<_InspectionObservationEditor> createState() =>
      _InspectionObservationEditorState();
}

class _InspectionObservationEditorState
    extends State<_InspectionObservationEditor> {
  final _formKey = GlobalKey<FormState>();
  final _readingsKey = GlobalKey<InspectionReadingFieldsEditorState>();
  late String? _targetKey;
  late DateTime _observedAt;
  late bool? _booleanValue;
  late String? _choiceValue;
  late final TextEditingController _value;
  late final TextEditingController _charge;
  late final TextEditingController _conditions;
  late final TextEditingController _note;
  late final TextEditingController _evidence;

  @override
  void initState() {
    super.initState();
    final correction = widget.correction;
    final requestedTarget = _selectableTargets
        .where((target) => target.targetKey == widget.initialTargetKey)
        .firstOrNull;
    _targetKey =
        correction?.targetKey ??
        requestedTarget?.targetKey ??
        _selectableTargets.firstOrNull?.targetKey;
    _observedAt = correction?.observedAt.toLocal() ?? DateTime.now();
    _booleanValue = correction?.booleanValue;
    _choiceValue = correction?.choiceValue;
    _value = TextEditingController(
      text: widget.campaign.definition.isMultiReading
          ? ''
          : switch (widget.campaign.definition.valueType) {
              InspectionValueType.number => '${correction?.numericValue ?? ''}',
              InspectionValueType.text => correction?.textValue ?? '',
              _ => '',
            },
    );
    _charge = TextEditingController(text: '${correction?.chargeNo ?? ''}');
    _conditions = TextEditingController(
      text:
          correction?.operatingConditions.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('\n') ??
          '',
    );
    _note = TextEditingController(text: correction?.note ?? '');
    _evidence = TextEditingController(
      text: correction?.evidenceUrls.join('\n') ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in [_value, _charge, _conditions, _note, _evidence]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.campaign.definition;
    final correction = widget.correction;
    final nodes = _eligibleNodes(widget);
    final locked = correction != null;
    final targets = _selectableTargets;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(BafSpacing.md),
      title: Text(locked ? 'Record correction' : 'Add field reading'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EditorLead(
                  icon: locked
                      ? Icons.edit_note_rounded
                      : Icons.add_chart_rounded,
                  title: definition.title,
                  text: locked
                      ? 'The original remains intact. Correct its reading at the original location and time; this is not a new inspection at the current installation.'
                      : definition.description,
                ),
                const SizedBox(height: BafSpacing.lg),
                if (targets.isEmpty)
                  const _InlineNotice(
                    icon: Icons.gpp_bad_outlined,
                    text:
                        'No governed target is currently eligible for a reading. Restore a target disposition or add a target first.',
                    danger: true,
                  )
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _targetKey,
                    decoration: const InputDecoration(
                      labelText: 'Governed inspection target',
                      prefixIcon: Icon(Icons.my_location_rounded),
                    ),
                    items: targets
                        .map(
                          (target) => DropdownMenuItem(
                            value: target.targetKey,
                            child: Text(
                              correction == null
                                  ? _targetLabel(target, nodes)
                                  : [
                                      correction.rowLabel,
                                      if (correction.componentName != null)
                                        correction.componentName!,
                                      if (correction.physicalPosition != null)
                                        correction.physicalPosition!,
                                    ].join(' · '),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: locked || widget.lockTarget
                        ? null
                        : (value) => setState(() => _targetKey = value),
                  ),
                if (!locked &&
                    definition.componentNodeIds.isNotEmpty &&
                    nodes.isEmpty)
                  const _InlineNotice(
                    icon: Icons.gpp_bad_outlined,
                    text:
                        'The governed component could not be resolved at its current hierarchy version. Recording is blocked.',
                    danger: true,
                  ),
                const SizedBox(height: BafSpacing.md),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BafSpacing.md,
                  ),
                  tileColor: BafColors.surfaceMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    side: const BorderSide(color: BafColors.border),
                  ),
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Observed at'),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(_observedAt),
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _chooseObservedAt,
                ),
                const SizedBox(height: BafSpacing.md),
                if (definition.isMultiReading)
                  InspectionReadingFieldsEditor(
                    key: _readingsKey,
                    fields: definition.readingFields,
                    initialValues: correction?.readings ?? const [],
                  )
                else
                  _valueEditor(definition),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _charge,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  decoration: InputDecoration(
                    labelText: definition.requiresChargeNo
                        ? 'Charge number'
                        : 'Charge number (optional)',
                    prefixIcon: const Icon(Icons.numbers_rounded),
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return definition.requiresChargeNo
                          ? 'A charge number is required.'
                          : null;
                    }
                    return RegExp(r'^\d{5}$').hasMatch(text)
                        ? null
                        : 'Use exactly five digits.';
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _conditions,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Operating conditions · key=value per line',
                    hintText: 'furnaceState=isolated\nsource=field gauge',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => _parseConditions(value) == null
                      ? 'Use one unique key=value condition per line.'
                      : null,
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Observation note (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _evidence,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Evidence links · one per line (optional)',
                    prefixIcon: Icon(Icons.attach_file_rounded),
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
          onPressed:
              targets.isEmpty ||
                  (!locked &&
                      definition.componentNodeIds.isNotEmpty &&
                      nodes.isEmpty)
              ? null
              : _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(locked ? 'Record correction' : 'Save reading'),
        ),
      ],
    );
  }

  Widget _valueEditor(FrozenInspectionDefinition definition) {
    return switch (definition.valueType) {
      InspectionValueType.number => TextFormField(
        controller: _value,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: 'Reading (${definition.unit})',
          prefixIcon: const Icon(Icons.speed_rounded),
          helperText:
              definition.minimumValue == null && definition.maximumValue == null
              ? null
              : 'Governed range: ${definition.minimumValue ?? '−∞'} to ${definition.maximumValue ?? '∞'} ${definition.unit}',
        ),
        validator: (value) => double.tryParse(value?.trim() ?? '') == null
            ? 'Enter a numeric reading.'
            : null,
      ),
      InspectionValueType.boolean => FormField<bool>(
        initialValue: _booleanValue,
        validator: (value) => value == null ? 'Choose Yes or No.' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observed condition',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: BafSpacing.sm),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Yes'),
                  icon: Icon(Icons.check_rounded),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('No'),
                  icon: Icon(Icons.close_rounded),
                ),
              ],
              selected: _booleanValue == null
                  ? const <bool>{}
                  : <bool>{_booleanValue!},
              emptySelectionAllowed: true,
              onSelectionChanged: (values) {
                final selected = values.isEmpty ? null : values.first;
                setState(() => _booleanValue = selected);
                field.didChange(selected);
              },
            ),
            if (field.hasError) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                field.errorText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      InspectionValueType.text => TextFormField(
        controller: _value,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Observed condition',
          alignLabelWithHint: true,
        ),
        validator: (value) => value?.trim().isNotEmpty == true
            ? null
            : 'Record the observed condition.',
      ),
      InspectionValueType.choice => DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _choiceValue,
        decoration: const InputDecoration(
          labelText: 'Observed choice',
          prefixIcon: Icon(Icons.list_alt_rounded),
        ),
        items: definition.choiceValues
            .map(
              (choice) => DropdownMenuItem(value: choice, child: Text(choice)),
            )
            .toList(),
        onChanged: (value) => setState(() => _choiceValue = value),
        validator: (value) =>
            value == null ? 'Choose an observed value.' : null,
      ),
      InspectionValueType.date || null => throw StateError(
        'Date readings require the labelled reading contract.',
      ),
    };
  }

  Future<void> _chooseObservedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _observedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _observedAt = DateTime(
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
    final target = widget.campaign.targets
        .where((item) => item.targetKey == _targetKey)
        .firstOrNull;
    if (target == null) return;
    final component = _eligibleNodes(
      widget,
    ).where((item) => item.id == target.componentNodeId).firstOrNull;
    final charge = int.tryParse(_charge.text.trim());
    final definition = widget.campaign.definition;
    Navigator.pop(
      context,
      _InspectionObservationDraft(
        observationId: 'inspection-observation-${const Uuid().v4()}',
        campaign: widget.campaign,
        target: target,
        component: component,
        physicalPosition: target.physicalPosition,
        observedAt: _observedAt,
        readings: definition.isMultiReading
            ? _readingsKey.currentState!.validatedValues()
            : const [],
        numericValue:
            !definition.isMultiReading &&
                definition.valueType == InspectionValueType.number
            ? double.parse(_value.text.trim())
            : null,
        booleanValue:
            !definition.isMultiReading &&
                definition.valueType == InspectionValueType.boolean
            ? _booleanValue!
            : null,
        textValue:
            !definition.isMultiReading &&
                definition.valueType == InspectionValueType.text
            ? _value.text.trim()
            : null,
        choiceValue:
            !definition.isMultiReading &&
                definition.valueType == InspectionValueType.choice
            ? _choiceValue
            : null,
        conditions: _parseConditions(_conditions.text)!,
        chargeNo: charge,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        evidenceUrls: _lines(_evidence.text),
        supersedesObservationId: widget.correction?.id,
        correction: widget.correction,
      ),
    );
  }

  List<InspectionCampaignTarget> get _selectableTargets {
    final correction = widget.correction;
    if (correction != null) {
      return widget.campaign.targets
          .where((target) => target.targetKey == correction.targetKey)
          .toList(growable: false);
    }
    return widget.campaign.targets
        .where(
          (target) =>
              (!widget.lockTarget ||
                  target.targetKey == widget.initialTargetKey) &&
              target.disposition !=
                  InspectionTargetDisposition.excludedWithReason &&
              target.disposition != InspectionTargetDisposition.unavailable,
        )
        .toList(growable: false);
  }
}
