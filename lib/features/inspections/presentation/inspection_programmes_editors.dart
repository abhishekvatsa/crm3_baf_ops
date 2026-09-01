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
    'schemaVersion': 1,
    'code': code,
    'title': title,
    'description': description,
    'assetTypeKeys': [assetTypeKey],
    'assetClassIds': [assetClassId],
    'componentNodeIds': componentNodeIds,
    'valueType': valueType.name,
    'unit': unit,
    'choiceValues': choiceValues,
    'minimumValue': minimumValue,
    'maximumValue': maximumValue,
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
  late bool _requiresCharge;
  late Set<String> _componentIds;

  @override
  void initState() {
    super.initState();
    final frozen = widget.existing?.frozen;
    final activeClasses =
        widget.classes.where((item) => item.isActive).toList();
    final existingClassId = frozen?.assetClassIds.firstOrNull;
    final existingClassIsActive = activeClasses.any(
      (item) => item.id == existingClassId,
    );
    _assetClassId =
        existingClassIsActive ? existingClassId! : activeClasses.first.id;
    _valueType = frozen?.valueType ?? InspectionValueType.number;
    _requiresCharge = frozen?.requiresChargeNo ?? false;
    _componentIds =
        existingClassIsActive ? {...?frozen?.componentNodeIds} : <String>{};
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
      text:
          widget.existing == null
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
    final activeClasses =
        widget.classes.where((item) => item.isActive).toList();
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
                  validator:
                      (value) =>
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
                  validator:
                      (value) =>
                          (value?.trim().isNotEmpty ?? false)
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
                  validator:
                      (value) =>
                          (value?.trim().isNotEmpty ?? false)
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
                  items:
                      activeClasses
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _assetClassId = value!;
                        _componentIds.clear();
                      }),
                ),
                const SizedBox(height: BafSpacing.md),
                nodes.when(
                  loading: () => const LinearProgressIndicator(),
                  error:
                      (_, _) => const Text(
                        'Components could not be loaded safely.',
                        style: TextStyle(color: BafColors.danger),
                      ),
                  data: (all) {
                    final components =
                        all
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
                          children:
                              components
                                  .map(
                                    (node) => FilterChip(
                                      selected: _componentIds.contains(node.id),
                                      label: Text(node.name),
                                      avatar: Icon(
                                        node.nodeType ==
                                                AssetHierarchyNodeType
                                                    .subcomponent
                                            ? Icons.account_tree_outlined
                                            : Icons.settings_outlined,
                                        size: 17,
                                      ),
                                      onSelected:
                                          (selected) => setState(() {
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
                    ],
                    selected: {_valueType},
                    showSelectedIcon: false,
                    onSelectionChanged:
                        (value) => setState(() => _valueType = value.single),
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
                    validator:
                        (value) =>
                            value?.trim().isNotEmpty == true
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
                    validator:
                        (value) =>
                            _lines(value).isNotEmpty
                                ? null
                                : 'Provide at least one choice.',
                  ),
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
                  validator:
                      (value) =>
                          (value?.trim().isNotEmpty ?? false)
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

  void _submit(AssetClassRecord selectedClass) {
    if (!_formKey.currentState!.validate()) return;
    final min = double.tryParse(_minimum.text.trim());
    final max = double.tryParse(_maximum.text.trim());
    if (min != null && max != null && min > max) {
      _showEditorError(context, 'Minimum cannot exceed maximum.');
      return;
    }
    Navigator.pop(
      context,
      _InspectionDefinitionDraft(
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        assetTypeKey: selectedClass.legacyAssetTypeKey ?? 'governedCustom',
        assetClassId: selectedClass.id,
        componentNodeIds: _componentIds.toList()..sort(),
        valueType: _valueType,
        unit:
            _valueType == InspectionValueType.number ? _unit.text.trim() : null,
        choiceValues:
            _valueType == InspectionValueType.choice
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
    required this.closedCampaigns,
  });

  final List<InspectionDefinition> definitions;
  final List<AssetInstanceRecord> assets;
  final List<InspectionCampaign> closedCampaigns;

  @override
  State<_InspectionCampaignEditor> createState() =>
      _InspectionCampaignEditorState();
}

class _InspectionCampaignEditorState extends State<_InspectionCampaignEditor> {
  final _formKey = GlobalKey<FormState>();
  late InspectionDefinition _definition;
  late final TextEditingController _purpose;
  late final TextEditingController _targets;
  late final TextEditingController _positions;
  late final TextEditingController _reason;
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
    _targets = TextEditingController(text: _defaultTargets(_definition));
    _positions = TextEditingController();
    _reason = TextEditingController(
      text: 'Open a governed cross-asset inspection programme.',
    );
  }

  @override
  void dispose() {
    _purpose.dispose();
    _targets.dispose();
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
                  items:
                      widget.definitions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.frozen.title),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() {
                        _definition = value!;
                        _targets.text = _defaultTargets(value);
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
                  validator:
                      (value) =>
                          (value?.trim().isNotEmpty ?? false)
                              ? null
                              : 'Describe the campaign purpose.',
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _targets,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Exact target asset numbers',
                    hintText: '1-26 or 1, 2, 3, 8, 12',
                    helperText:
                        'Every target remains accounted. Use ranges or comma-separated numbers.',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                  ),
                  validator:
                      (value) =>
                          _parseNumbers(value) == null ||
                                  _parseNumbers(value)!.isEmpty
                              ? 'Use comma-separated positive whole numbers.'
                              : null,
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
                  onChanged:
                      (value) => setState(() => _baselineCampaignId = value),
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
                  children:
                      _observerRoles.entries
                          .map(
                            (entry) => FilterChip(
                              selected: _roles.contains(entry.key),
                              label: Text(entry.value),
                              onSelected:
                                  (selected) => setState(() {
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
                  validator:
                      (value) =>
                          (value?.trim().isNotEmpty ?? false)
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
    final numbers = _parseNumbers(_targets.text)!;
    final available = _matchingAssets.map((item) => item.assetNumber).toSet();
    final unknown =
        numbers.where((number) => !available.contains(number)).toList();
    if (unknown.isNotEmpty) {
      _showEditorError(
        context,
        'These asset numbers are absent or inactive in the selected class: ${unknown.join(', ')}.',
      );
      return;
    }
    final positions = _commaValues(_positions.text);
    final componentCount =
        _definition.frozen.componentNodeIds.isEmpty
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
        targetNumbers: numbers,
        expectedPopulation: expected,
        physicalPositionLabels: positions,
        baselineCampaignId: _baselineCampaignId,
        observerRoles: _roles.toList()..sort(),
        reason: _reason.text.trim(),
      ),
    );
  }

  List<AssetInstanceRecord> get _matchingAssets {
    final classId = _definition.frozen.assetClassIds.firstOrNull;
    return widget.assets
        .where((asset) => asset.assetClassId == classId)
        .toList(growable: false)
      ..sort((left, right) => left.assetNumber.compareTo(right.assetNumber));
  }

  List<InspectionCampaign> get _baselineOptions => widget.closedCampaigns
      .where(
        (campaign) =>
            campaign.definition.id == _definition.id &&
            campaign.assetClassId ==
                _definition.frozen.assetClassIds.firstOrNull,
      )
      .toList(growable: false);

  String _defaultTargets(InspectionDefinition definition) {
    final classId = definition.frozen.assetClassIds.firstOrNull;
    final numbers =
        widget.assets
            .where((asset) => asset.assetClassId == classId)
            .map((asset) => asset.assetNumber)
            .toList()
          ..sort();
    return _compactNumberRanges(numbers);
  }
}

class _InspectionObservationDraft {
  const _InspectionObservationDraft({
    required this.observationId,
    required this.campaign,
    required this.assetNumber,
    required this.asset,
    required this.component,
    required this.physicalPosition,
    required this.observedAt,
    required this.numericValue,
    required this.booleanValue,
    required this.textValue,
    required this.choiceValue,
    required this.conditions,
    required this.chargeNo,
    required this.note,
    required this.evidenceUrls,
    required this.supersedesObservationId,
  });

  final String observationId;
  final InspectionCampaign campaign;
  final int assetNumber;
  final AssetInstanceRecord? asset;
  final AssetHierarchyNode? component;
  final String? physicalPosition;
  final DateTime observedAt;
  final double? numericValue;
  final bool? booleanValue;
  final String? textValue;
  final String? choiceValue;
  final Map<String, String> conditions;
  final int? chargeNo;
  final String? note;
  final List<String> evidenceUrls;
  final String? supersedesObservationId;

  Map<String, Object?> toPayload() => {
    'observationId': observationId,
    'definitionVersion': campaign.definition.version,
    'assetTypeKey': campaign.assetTypeKey,
    'assetNumber': assetNumber,
    'assetClassId': asset?.assetClassId,
    'assetInstanceId': asset?.id,
    'componentNodeId': component?.id,
    'componentNodeVersion': component?.version,
    'componentName': component?.name,
    'hierarchyPath': component?.hierarchyPath ?? const <String>[],
    'physicalPosition': physicalPosition,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'value': {
      'valueType': campaign.definition.valueType.name,
      'numericValue': numericValue,
      'booleanValue': booleanValue,
      'textValue': textValue,
      'choiceValue': choiceValue,
    },
    'unit': campaign.definition.unit,
    'operatingConditions': conditions,
    'chargeNo': chargeNo,
    'note': note,
    'evidenceUrls': evidenceUrls,
    'supersedesObservationId': supersedesObservationId,
  };
}

class _InspectionObservationEditor extends StatefulWidget {
  const _InspectionObservationEditor({
    required this.campaign,
    required this.nodes,
    required this.instances,
    required this.correction,
  });

  final InspectionCampaign campaign;
  final List<AssetHierarchyNode> nodes;
  final List<AssetInstanceRecord> instances;
  final InspectionObservation? correction;

  @override
  State<_InspectionObservationEditor> createState() =>
      _InspectionObservationEditorState();
}

class _InspectionObservationEditorState
    extends State<_InspectionObservationEditor> {
  final _formKey = GlobalKey<FormState>();
  late String? _targetKey;
  late DateTime _observedAt;
  late bool _booleanValue;
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
    _targetKey =
        correction?.targetKey ?? _selectableTargets.firstOrNull?.targetKey;
    _observedAt = DateTime.now();
    _booleanValue = correction?.booleanValue ?? false;
    _choiceValue =
        correction?.choiceValue ??
        widget.campaign.definition.choiceValues.firstOrNull;
    _value = TextEditingController(
      text: switch (widget.campaign.definition.valueType) {
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
                  icon:
                      locked
                          ? Icons.edit_note_rounded
                          : Icons.add_chart_rounded,
                  title: definition.title,
                  text:
                      locked
                          ? 'The original remains intact. This creates a new current result for the same target.'
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
                    items:
                        targets
                            .map(
                              (target) => DropdownMenuItem(
                                value: target.targetKey,
                                child: Text(_targetLabel(target, nodes)),
                              ),
                            )
                            .toList(),
                    onChanged:
                        locked
                            ? null
                            : (value) => setState(() => _targetKey = value),
                  ),
                if (definition.componentNodeIds.isNotEmpty && nodes.isEmpty)
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
                _valueEditor(definition),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _charge,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  decoration: InputDecoration(
                    labelText:
                        definition.requiresChargeNo
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
                  validator:
                      (value) =>
                          _parseConditions(value) == null
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
                      (definition.componentNodeIds.isNotEmpty && nodes.isEmpty)
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
        validator:
            (value) =>
                double.tryParse(value?.trim() ?? '') == null
                    ? 'Enter a numeric reading.'
                    : null,
      ),
      InspectionValueType.boolean => SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: BafSpacing.md),
        tileColor: BafColors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          side: const BorderSide(color: BafColors.border),
        ),
        value: _booleanValue,
        onChanged: (value) => setState(() => _booleanValue = value),
        title: Text(_booleanValue ? 'Yes' : 'No'),
        subtitle: const Text('Observed condition'),
      ),
      InspectionValueType.text => TextFormField(
        controller: _value,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Observed condition',
          alignLabelWithHint: true,
        ),
        validator:
            (value) =>
                value?.trim().isNotEmpty == true
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
        items:
            definition.choiceValues
                .map(
                  (choice) =>
                      DropdownMenuItem(value: choice, child: Text(choice)),
                )
                .toList(),
        onChanged: (value) => setState(() => _choiceValue = value),
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
    if (time == null) return;
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
    final target =
        widget.campaign.targets
            .where((item) => item.targetKey == _targetKey)
            .firstOrNull;
    if (target == null) return;
    final asset =
        widget.instances
            .where((item) => item.id == target.assetInstanceId)
            .firstOrNull;
    final component =
        _eligibleNodes(
          widget,
        ).where((item) => item.id == target.componentNodeId).firstOrNull;
    final charge = int.tryParse(_charge.text.trim());
    final definition = widget.campaign.definition;
    Navigator.pop(
      context,
      _InspectionObservationDraft(
        observationId: 'inspection-observation-${const Uuid().v4()}',
        campaign: widget.campaign,
        assetNumber: target.assetNumber,
        asset: asset,
        component: component,
        physicalPosition: target.physicalPosition,
        observedAt: _observedAt,
        numericValue:
            definition.valueType == InspectionValueType.number
                ? double.parse(_value.text.trim())
                : null,
        booleanValue:
            definition.valueType == InspectionValueType.boolean
                ? _booleanValue
                : null,
        textValue:
            definition.valueType == InspectionValueType.text
                ? _value.text.trim()
                : null,
        choiceValue:
            definition.valueType == InspectionValueType.choice
                ? _choiceValue
                : null,
        conditions: _parseConditions(_conditions.text)!,
        chargeNo: charge,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        evidenceUrls: _lines(_evidence.text),
        supersedesObservationId: widget.correction?.id,
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
              target.disposition !=
                  InspectionTargetDisposition.excludedWithReason &&
              target.disposition != InspectionTargetDisposition.unavailable,
        )
        .toList(growable: false);
  }
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

List<String> _lines(String? value) =>
    (value ?? '')
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

List<int>? _parseNumbers(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return <int>[];
  final numbers = <int>{};
  for (final part in text.split(RegExp(r'[,\s]+'))) {
    final range = part.split('-');
    if (range.length == 1) {
      final parsed = int.tryParse(part);
      if (parsed == null || parsed < 1) return null;
      numbers.add(parsed);
      continue;
    }
    if (range.length != 2) return null;
    final start = int.tryParse(range.first);
    final end = int.tryParse(range.last);
    if (start == null || end == null || start < 1 || end < start) return null;
    if (end - start > 500) return null;
    for (var number = start; number <= end; number += 1) {
      numbers.add(number);
    }
  }
  return numbers.toList()..sort();
}

List<String> _commaValues(String? value) =>
    (value ?? '')
        .split(RegExp(r'[,\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

String _compactNumberRanges(List<int> values) {
  if (values.isEmpty) return '';
  final sorted = values.toSet().toList()..sort();
  final parts = <String>[];
  var start = sorted.first;
  var previous = start;
  for (final value in sorted.skip(1)) {
    if (value == previous + 1) {
      previous = value;
      continue;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    start = previous = value;
  }
  parts.add(start == previous ? '$start' : '$start-$previous');
  return parts.join(', ');
}

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
  final component =
      nodes.where((node) => node.id == target.componentNodeId).firstOrNull;
  return [
    target.assetInstanceName,
    if (component != null) component.name,
    if (target.physicalPosition != null) target.physicalPosition!,
  ].join(' · ');
}

void _showEditorError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: BafColors.danger),
  );
}
