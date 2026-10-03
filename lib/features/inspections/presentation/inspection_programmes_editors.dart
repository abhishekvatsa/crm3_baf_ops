part of 'inspection_programmes_screen.dart';

const _observerRoles = <String, String>{
  'operations': 'Operations',
  'seniorElectrical': 'Electrical',
  'seniorMechanical': 'Mechanical',
  'seniorInstrumentation': 'I&A',
  'refractory': 'Refractory',
  'seniorRefractory': 'Sr. Refractory',
  'contractSupervisor': 'Contract Supervisor',
  'shiftSupervisor': 'Shift Supervisor',
  'si': 'SI',
};

class _InspectionDefinitionDraft {
  const _InspectionDefinitionDraft({
    this.readingFields = const [],
    required this.code,
    required this.title,
    required this.description,
    required this.assetTypeKey,
    required this.assetClassId,
    required this.componentNodeIds,
    required this.valueType,
    required this.unit,
    required this.choiceValues,
    required this.minimumValue,
    required this.maximumValue,
    required this.preconditions,
    required this.requiresChargeNo,
    required this.reason,
  });

  final List<InspectionReadingField> readingFields;
  final String code;
  final String title;
  final String description;
  final String assetTypeKey;
  final String assetClassId;
  final List<String> componentNodeIds;
  final InspectionValueType valueType;
  final String? unit;
  final List<String> choiceValues;
  final double? minimumValue;
  final double? maximumValue;
  final List<String> preconditions;
  final bool requiresChargeNo;
  final String reason;

  Map<String, Object?> toPayload() => {
    'schemaVersion': readingFields.isEmpty ? 1 : 2,
    'code': code,
    'title': title,
    'description': description,
    'assetTypeKeys': [assetTypeKey],
    'assetClassIds': [assetClassId],
    'componentNodeIds': componentNodeIds,
    if (readingFields.isNotEmpty)
      'readingFields': readingFields.map((field) => field.toMap()).toList()
    else ...{
      'valueType': valueType.name,
      'unit': unit,
      'choiceValues': choiceValues,
      'minimumValue': minimumValue,
      'maximumValue': maximumValue,
    },
    'preconditions': preconditions,
    'requiresChargeNo': requiresChargeNo,
  };
}

class _InspectionDefinitionEditor extends ConsumerStatefulWidget {
  const _InspectionDefinitionEditor({
    required this.classes,
    required this.existing,
  });

  final List<AssetClassRecord> classes;
  final InspectionDefinition? existing;

  @override
  ConsumerState<_InspectionDefinitionEditor> createState() =>
      _InspectionDefinitionEditorState();
}

class _InspectionDefinitionEditorState
    extends ConsumerState<_InspectionDefinitionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _choices;
  late final TextEditingController _preconditions;
  late final TextEditingController _reason;
  late String _assetClassId;
  late InspectionValueType _valueType;
  late List<InspectionReadingField> _readingFields;
  late bool _requiresCharge;
  late Set<String> _componentIds;

  @override
  void initState() {
    super.initState();
    final frozen = widget.existing?.frozen;
    final activeClasses = widget.classes
        .where((item) => item.isActive)
        .toList();
    final existingClassId = frozen?.assetClassIds.firstOrNull;
    final existingClassIsActive = activeClasses.any(
      (item) => item.id == existingClassId,
    );
    _assetClassId = existingClassIsActive
        ? existingClassId!
        : activeClasses.first.id;
    _valueType = frozen?.valueType ?? InspectionValueType.number;
    _readingFields = frozen?.readingFields ?? const [];
    _requiresCharge = frozen?.requiresChargeNo ?? false;
    _componentIds = existingClassIsActive
        ? {...?frozen?.componentNodeIds}
        : <String>{};
    _code = TextEditingController(text: frozen?.code ?? '');
    _title = TextEditingController(text: frozen?.title ?? '');
    _description = TextEditingController(text: frozen?.description ?? '');
    _unit = TextEditingController(text: frozen?.unit ?? '');
    _minimum = TextEditingController(text: '${frozen?.minimumValue ?? ''}');
    _maximum = TextEditingController(text: '${frozen?.maximumValue ?? ''}');
    _choices = TextEditingController(
      text: frozen?.choiceValues.join('\n') ?? '',
    );
    _preconditions = TextEditingController(
      text: frozen?.preconditions.join('\n') ?? '',
    );
    _reason = TextEditingController(
      text: widget.existing == null
          ? 'Create a reviewed field-inspection definition.'
          : 'Revise the governed inspection definition.',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _title,
      _description,
      _unit,
      _minimum,
      _maximum,
      _choices,
      _preconditions,
      _reason,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeClasses = widget.classes
        .where((item) => item.isActive)
        .toList();
    final selectedClass = activeClasses.firstWhere(
      (item) => item.id == _assetClassId,
      orElse: () => activeClasses.first,
    );
    final nodes = ref.watch(assetHierarchyNodesProvider(_assetClassId));
    return AlertDialog(
      insetPadding: const EdgeInsets.all(BafSpacing.md),
      title: Text(
        widget.existing == null
            ? 'New inspection definition'
            : 'New definition version',
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EditorLead(
                  icon: Icons.rule_folder_outlined,
                  title: 'Define the evidence once',
                  text:
                      'Campaigns freeze this definition. Later edits never rewrite readings already collected.',
                ),
                const SizedBox(height: BafSpacing.lg),
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Definition code',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: (value) =>
                      RegExp(
                        r'^[A-Z0-9][A-Z0-9_-]{1,47}$',
                      ).hasMatch(value?.trim().toUpperCase() ?? '')
                      ? null
                      : 'Use 2-48 letters, numbers, hyphens or underscores.',
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Field-facing title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Enter a clear title.',
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What this inspection establishes',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Describe the inspection purpose.',
                ),
                const SizedBox(height: BafSpacing.lg),
                Text(
                  'Asset and component scope',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedClass.id,
                  decoration: const InputDecoration(
                    labelText: 'Asset class',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                  ),
                  items: activeClasses
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _assetClassId = value!;
                    _componentIds.clear();
                  }),
                ),
                const SizedBox(height: BafSpacing.md),
                nodes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const Text(
                    'Components could not be loaded safely.',
                    style: TextStyle(color: BafColors.danger),
                  ),
                  data: (all) {
                    final components = all
                        .where(
                          (node) =>
                              node.isActive &&
                              (node.nodeType ==
                                      AssetHierarchyNodeType.component ||
                                  node.nodeType ==
                                      AssetHierarchyNodeType.subcomponent),
                        )
                        .toList();
                    if (components.isEmpty) {
                      return const _InlineNotice(
                        icon: Icons.info_outline_rounded,
                        text:
                            'No component nodes are available. This definition will observe the asset as a whole.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Component scope (optional)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: BafSpacing.sm,
                          runSpacing: BafSpacing.sm,
                          children: components
                              .map(
                                (node) => FilterChip(
                                  selected: _componentIds.contains(node.id),
                                  label: Text(node.name),
                                  avatar: Icon(
                                    node.nodeType ==
                                            AssetHierarchyNodeType.subcomponent
                                        ? Icons.account_tree_outlined
                                        : Icons.settings_outlined,
                                    size: 17,
                                  ),
                                  onSelected: (selected) => setState(() {
                                    selected
                                        ? _componentIds.add(node.id)
                                        : _componentIds.remove(node.id);
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: BafSpacing.lg),
                Text(
                  'Reading contract',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: BafSpacing.sm),
                if (_readingFields.isNotEmpty)
                  InspectionReadingContractEditor(
                    fields: _readingFields,
                    onChanged: (fields) =>
                        setState(() => _readingFields = fields),
                  )
                else ...[
                  BafHorizontalControlRail(
                    child: SegmentedButton<InspectionValueType>(
                      segments: const [
                        ButtonSegment(
                          value: InspectionValueType.number,
                          icon: Icon(Icons.numbers_rounded),
                          label: Text('Number'),
                        ),
                        ButtonSegment(
                          value: InspectionValueType.boolean,
                          icon: Icon(Icons.toggle_on_outlined),
                          label: Text('Yes/No'),
                        ),
                        ButtonSegment(
                          value: InspectionValueType.text,
                          icon: Icon(Icons.notes_rounded),
                          label: Text('Text'),
                        ),
                        ButtonSegment(
                          value: InspectionValueType.choice,
                          icon: Icon(Icons.list_alt_rounded),
                          label: Text('Choice'),
                        ),
                        ButtonSegment(
                          value: InspectionValueType.date,
                          icon: Icon(Icons.calendar_today_outlined),
                          label: Text('Date'),
                        ),
                      ],
                      selected: {_valueType},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        if (value.single == InspectionValueType.date) {
                          _upgradeReadingContract(asDate: true);
                        } else {
                          setState(() => _valueType = value.single);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: BafSpacing.md),
                  if (_valueType == InspectionValueType.number) ...[
                    TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Engineering unit',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Numeric readings require a unit.',
                    ),
                    const SizedBox(height: BafSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minimum,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Minimum (optional)',
                            ),
                            validator: _optionalNumberValidator,
                          ),
                        ),
                        const SizedBox(width: BafSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _maximum,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Maximum (optional)',
                            ),
                            validator: _optionalNumberValidator,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_valueType == InspectionValueType.choice)
                    TextFormField(
                      controller: _choices,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Choices · one per line',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => _lines(value).isNotEmpty
                          ? null
                          : 'Provide at least one choice.',
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('inspection-enable-multiple-readings'),
                    onPressed: _upgradeReadingContract,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another reading'),
                  ),
                ],
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _preconditions,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Preconditions · one per line',
                    hintText: 'Furnace isolated\nImpulse line available',
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requiresCharge,
                  onChanged: (value) => setState(() => _requiresCharge = value),
                  title: const Text('Require exact five-digit charge number'),
                  subtitle: const Text(
                    'Use only when every reading must be bound to a charge.',
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Governance reason',
                    prefixIcon: Icon(Icons.history_edu_outlined),
                  ),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Record a reason.',
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
          onPressed: () => _submit(selectedClass),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save version'),
        ),
      ],
    );
  }

  Future<void> _upgradeReadingContract({bool asDate = false}) async {
    final title = _title.text.trim();
    final label = title.isNotEmpty && title.length <= 120 ? title : 'Reading 1';
    final id = 'reading_${const Uuid().v4().replaceAll('-', '')}';
    if (asDate) {
      setState(
        () => _readingFields = [
          InspectionReadingField(
            id: id,
            label: label,
            valueType: InspectionValueType.date,
          ),
        ],
      );
      return;
    }
    final InspectionReadingField original;
    try {
      original = prepareLegacyInspectionReadingField(
        id: id,
        label: label,
        valueType: _valueType,
        unit: _unit.text,
        choices: _lines(_choices.text),
        minimum: _minimum.text,
        maximum: _maximum.text,
      );
    } on FormatException {
      _showEditorError(
        context,
        'Correct the existing reading unit, choices or numeric limits before adding another reading.',
      );
      return;
    }
    final added = await showInspectionReadingFieldEditor(
      context,
      otherLabels: [original.label],
    );
    if (!mounted || added == null) return;
    setState(() => _readingFields = [original, added]);
  }

  void _submit(AssetClassRecord selectedClass) {
    if (!_formKey.currentState!.validate()) return;
    final min = double.tryParse(_minimum.text.trim());
    final max = double.tryParse(_maximum.text.trim());
    if (_readingFields.isEmpty && min != null && max != null && min > max) {
      _showEditorError(context, 'Minimum cannot exceed maximum.');
      return;
    }
    if (_readingFields.isNotEmpty) {
      try {
        readInspectionReadingFields(
          _readingFields.map((field) => field.toMap()).toList(),
        );
      } on Object {
        _showEditorError(
          context,
          'Check every reading label, type, unit and range before saving.',
        );
        return;
      }
    }
    Navigator.pop(
      context,
      _InspectionDefinitionDraft(
        readingFields: _readingFields,
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        assetTypeKey: selectedClass.legacyAssetTypeKey ?? 'governedCustom',
        assetClassId: selectedClass.id,
        componentNodeIds: _componentIds.toList()..sort(),
        valueType: _valueType,
        unit: _valueType == InspectionValueType.number
            ? _unit.text.trim()
            : null,
        choiceValues: _valueType == InspectionValueType.choice
            ? _lines(_choices.text)
            : const [],
        minimumValue: _valueType == InspectionValueType.number ? min : null,
        maximumValue: _valueType == InspectionValueType.number ? max : null,
        preconditions: _lines(_preconditions.text),
        requiresChargeNo: _requiresCharge,
        reason: _reason.text.trim(),
      ),
    );
  }
}

class _InspectionCampaignDraft {
  const _InspectionCampaignDraft({
    required this.definition,
    required this.purpose,
    required this.assetTypeKey,
    required this.assetClassId,
    required this.populationMode,
    required this.hostAssetClassId,
    required this.targetNumbers,
    required this.expectedPopulation,
    required this.physicalPositionLabels,
    required this.baselineCampaignId,
    required this.observerRoles,
    required this.reason,
  });

  final InspectionDefinition definition;
  final String purpose;
  final String assetTypeKey;
  final String? assetClassId;
  final InspectionCampaignPopulationMode populationMode;
  final String? hostAssetClassId;
  final List<int> targetNumbers;
  final int expectedPopulation;
  final List<String> physicalPositionLabels;
  final String? baselineCampaignId;
  final List<String> observerRoles;
  final String reason;

  Map<String, Object?> toPayload() => {
    'definitionId': definition.id,
    'definitionVersion': definition.version,
    'purpose': purpose,
    'assetTypeKey': assetTypeKey,
    'assetClassId': assetClassId,
    'populationMode': populationMode.name,
    'hostAssetClassId': hostAssetClassId,
    'targetAssetNumbers': targetNumbers,
    'expectedPopulation': expectedPopulation,
    'physicalPositionLabels': physicalPositionLabels,
    'baselineCampaignId': baselineCampaignId,
    'observerRoleKeys': observerRoles,
    'reason': reason,
  };
}

class _InspectionCampaignEditor extends StatefulWidget {
  const _InspectionCampaignEditor({
    required this.definitions,
    required this.assets,
    required this.assetClasses,
    required this.innerCovers,
    required this.innerCoverAssignments,
    required this.closedCampaigns,
  });

  final List<InspectionDefinition> definitions;
  final List<AssetInstanceRecord> assets;
  final List<AssetClassRecord> assetClasses;
  final List<InnerCoverProfile> innerCovers;
  final List<BaseInnerCoverAssignment> innerCoverAssignments;
  final List<InspectionCampaign> closedCampaigns;

  @override
  State<_InspectionCampaignEditor> createState() =>
      _InspectionCampaignEditorState();
}

class _InspectionCampaignEditorState extends State<_InspectionCampaignEditor> {
  final _formKey = GlobalKey<FormState>();
  late InspectionDefinition _definition;
  late final TextEditingController _purpose;
  late final TextEditingController _positions;
  late final TextEditingController _reason;
  final Set<int> _selectedTargetNumbers = <int>{};
  String? _baselineCampaignId;
  final Set<String> _roles = {
    'operations',
    'seniorElectrical',
    'seniorMechanical',
    'seniorInstrumentation',
    'refractory',
  };

  @override
  void initState() {
    super.initState();
    _definition = widget.definitions.first;
    _purpose = TextEditingController();
    _positions = TextEditingController();
    _reason = TextEditingController(
      text: 'Open a governed cross-asset inspection programme.',
    );
    _selectedTargetNumbers.addAll(
      _targetOptionsFor(_definition).map((item) => item.number),
    );
  }

  @override
  void dispose() {
    _purpose.dispose();
    _positions.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(BafSpacing.md),
      title: const Text('New inspection programme'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EditorLead(
                  icon: Icons.radar_outlined,
                  title: 'Choose the population, not an outage',
                  text:
                      'A campaign may cover every asset, a named subset, or whatever can be reached in the current window.',
                ),
                const SizedBox(height: BafSpacing.lg),
                DropdownButtonFormField<InspectionDefinition>(
                  isExpanded: true,
                  initialValue: _definition,
                  decoration: const InputDecoration(
                    labelText: 'Governed definition',
                    prefixIcon: Icon(Icons.rule_folder_outlined),
                  ),
                  items: widget.definitions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.frozen.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _definition = value!;
                    _selectedTargetNumbers
                      ..clear()
                      ..addAll(
                        _targetOptionsFor(value).map((item) => item.number),
                      );
                    _positions.clear();
                    _baselineCampaignId = null;
                  }),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _purpose,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Purpose of this programme',
                    hintText:
                        'Verify pressure-transmitter settings across all Furnaces.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Describe the campaign purpose.',
                ),
                const SizedBox(height: BafSpacing.md),
                _GovernedInspectionTargetField(
                  options: _targetOptions,
                  selectedNumbers: _selectedTargetNumbers,
                  installedInnerCovers:
                      _populationMode ==
                      InspectionCampaignPopulationMode
                          .installedInnerCoversByBase,
                  onChoose: _chooseTargets,
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _positions,
                  decoration: const InputDecoration(
                    labelText: 'Physical positions (optional)',
                    hintText: 'B01, B02, B03',
                    helperText:
                        'Use when every listed position is a separate target, such as eight burners.',
                    prefixIcon: Icon(Icons.pin_drop_outlined),
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _baselineCampaignId,
                  decoration: const InputDecoration(
                    labelText: 'Re-audit baseline (optional)',
                    prefixIcon: Icon(Icons.compare_arrows_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No baseline · first campaign'),
                    ),
                    ..._baselineOptions.map(
                      (campaign) => DropdownMenuItem<String?>(
                        value: campaign.id,
                        child: Text(
                          '${campaign.definition.title} · ${DateFormat('dd MMM yyyy').format(campaign.createdAt.toLocal())}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _baselineCampaignId = value),
                ),
                const SizedBox(height: BafSpacing.lg),
                Text(
                  'Who may record',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: BafSpacing.sm),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: _observerRoles.entries
                      .map(
                        (entry) => FilterChip(
                          selected: _roles.contains(entry.key),
                          label: Text(entry.value),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _roles.add(entry.key)
                                : _roles.remove(entry.key);
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Opening reason',
                    prefixIcon: Icon(Icons.history_edu_outlined),
                  ),
                  validator: (value) => (value?.trim().isNotEmpty ?? false)
                      ? null
                      : 'Record a reason.',
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
          icon: const Icon(Icons.radar_outlined),
          label: const Text('Open programme'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_roles.isEmpty) {
      _showEditorError(context, 'Select at least one observer role.');
      return;
    }
    final numbers = _selectedTargetNumbers.toList()..sort();
    if (numbers.isEmpty) {
      _showEditorError(context, 'Choose at least one governed target.');
      return;
    }
    if (_populationMode ==
            InspectionCampaignPopulationMode.installedInnerCoversByBase &&
        _hostAssetClassId == null) {
      _showEditorError(
        context,
        'The active governed Base class is unavailable or ambiguous.',
      );
      return;
    }
    final available = _targetOptions.map((item) => item.number).toSet();
    final unknown = numbers
        .where((number) => !available.contains(number))
        .toList();
    if (unknown.isNotEmpty) {
      _showEditorError(
        context,
        'These asset numbers are absent or inactive in the selected class: ${unknown.join(', ')}.',
      );
      return;
    }
    final positions = _commaValues(_positions.text);
    final componentCount = _definition.frozen.componentNodeIds.isEmpty
        ? 1
        : _definition.frozen.componentNodeIds.length;
    final expected =
        numbers.length *
        componentCount *
        (positions.isEmpty ? 1 : positions.length);
    if (expected > 500) {
      _showEditorError(
        context,
        'This programme creates $expected targets. Split it so each campaign has at most 500.',
      );
      return;
    }
    Navigator.pop(
      context,
      _InspectionCampaignDraft(
        definition: _definition,
        purpose: _purpose.text.trim(),
        assetTypeKey: _assetTypeKey(_definition),
        assetClassId: _definition.frozen.assetClassIds.firstOrNull,
        populationMode: _populationMode,
        hostAssetClassId: _hostAssetClassId,
        targetNumbers: numbers,
        expectedPopulation: expected,
        physicalPositionLabels: positions,
        baselineCampaignId: _baselineCampaignId,
        observerRoles: _roles.toList()..sort(),
        reason: _reason.text.trim(),
      ),
    );
  }

  InspectionCampaignPopulationMode get _populationMode =>
      _assetTypeKey(_definition) == 'innerCover'
      ? InspectionCampaignPopulationMode.installedInnerCoversByBase
      : InspectionCampaignPopulationMode.assetInstances;

  String? get _hostAssetClassId {
    if (_populationMode == InspectionCampaignPopulationMode.assetInstances) {
      return null;
    }
    final baseClasses = widget.assetClasses
        .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
        .toList(growable: false);
    return baseClasses.length == 1 ? baseClasses.single.id : null;
  }

  List<_InspectionTargetOption> get _targetOptions =>
      _targetOptionsFor(_definition);

  List<_InspectionTargetOption> _targetOptionsFor(
    InspectionDefinition definition,
  ) {
    if (_assetTypeKey(definition) != 'innerCover') {
      final classId = definition.frozen.assetClassIds.firstOrNull;
      final options =
          widget.assets
              .where((asset) => asset.isActive && asset.assetClassId == classId)
              .map(
                (asset) => _InspectionTargetOption(
                  number: asset.assetNumber,
                  label: asset.name,
                  detail: 'Governed asset ${asset.assetNumber}',
                ),
              )
              .toList(growable: false)
            ..sort((left, right) => left.number.compareTo(right.number));
      return options;
    }
    final innerCoverClassId = definition.frozen.assetClassIds.firstOrNull;
    final hostClassId = widget.assetClasses
        .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
        .map((item) => item.id)
        .singleOrNull;
    if (innerCoverClassId == null || hostClassId == null) {
      return const <_InspectionTargetOption>[];
    }
    final profilesById = <String, InnerCoverProfile>{
      for (final profile in widget.innerCovers)
        if (profile.assetClassId == innerCoverClassId && profile.isInstalled)
          profile.id: profile,
    };
    return _installedInnerCoverTargetOptions(
      subjectAssetClassId: innerCoverClassId,
      hostAssetClassId: hostClassId,
      assets: widget.assets,
      profilesById: profilesById,
      assignments: widget.innerCoverAssignments,
    );
  }

  Future<void> _chooseTargets() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _InspectionTargetPickerDialog(
        options: _targetOptions,
        selectedNumbers: _selectedTargetNumbers,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedTargetNumbers
        ..clear()
        ..addAll(selected);
    });
  }

  List<InspectionCampaign> get _baselineOptions => widget.closedCampaigns
      .where(
        (campaign) =>
            campaign.definition.id == _definition.id &&
            campaign.assetClassId ==
                _definition.frozen.assetClassIds.firstOrNull &&
            campaign.populationMode == _populationMode &&
            campaign.hostAssetClassId == _hostAssetClassId,
      )
      .toList(growable: false);
}

class _EditorLead extends StatelessWidget {
  const _EditorLead({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: BafColors.instrument.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.instrument.withValues(alpha: 0.18)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BafColors.instrument),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(text, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? BafColors.danger : BafColors.instrument;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String? _optionalNumberValidator(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty || double.tryParse(text) != null
      ? null
      : 'Enter a valid number.';
}

List<String> _lines(String? value) => (value ?? '')
    .split(RegExp(r'[\r\n]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList();

List<String> _commaValues(String? value) =>
    (value ?? '')
        .split(RegExp(r'[,\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

Map<String, String>? _parseConditions(String? value) {
  final result = <String, String>{};
  for (final line in _lines(value)) {
    final split = line.indexOf('=');
    if (split < 1 || split == line.length - 1) return null;
    final key = line.substring(0, split).trim();
    final content = line.substring(split + 1).trim();
    if (key.isEmpty || content.isEmpty || result.containsKey(key)) return null;
    result[key] = content;
  }
  return result;
}

String _assetTypeKey(InspectionDefinition definition) =>
    definition.frozen.assetTypeKeys.firstOrNull ?? 'governedCustom';

List<AssetHierarchyNode> _eligibleNodes(_InspectionObservationEditor widget) {
  final allowed = widget.campaign.definition.componentNodeIds.toSet();
  return widget.nodes
      .where(
        (node) =>
            node.isActive &&
            allowed.contains(node.id) &&
            (node.nodeType == AssetHierarchyNodeType.component ||
                node.nodeType == AssetHierarchyNodeType.subcomponent),
      )
      .toList(growable: false);
}

String _targetLabel(
  InspectionCampaignTarget target,
  List<AssetHierarchyNode> nodes,
) {
  final component = nodes
      .where((node) => node.id == target.componentNodeId)
      .firstOrNull;
  return [
    target.rowLabel,
    if (component != null) component.name,
    if (target.physicalPosition != null) target.physicalPosition!,
  ].join(' · ');
}

void _showEditorError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: BafColors.danger),
  );
}
