part of 'inner_cover_lifecycle_screen.dart';

class _PairingSelection {
  final InnerCoverProfile cover;
  final String reason;

  const _PairingSelection({required this.cover, required this.reason});
}

class _PairingDialog extends StatefulWidget {
  final AssetInstanceRecord base;
  final BaseInnerCoverAssignment? current;
  final List<InnerCoverProfile> candidates;

  const _PairingDialog({
    required this.base,
    required this.current,
    required this.candidates,
  });

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  late final List<InnerCoverProfile> _candidates = [...widget.candidates]
    ..sort((left, right) {
      final availability = (left.isAvailable ? 0 : 1).compareTo(
        right.isAvailable ? 0 : 1,
      );
      return availability != 0
          ? availability
          : _compareInnerCoverSerial(left, right);
    });
  late InnerCoverProfile _selected = _candidates.first;
  final _search = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.current == null
            ? 'Link to Base ${widget.base.assetNumber}'
            : 'Change cover on Base ${widget.base.assetNumber}';
    final query = _search.text.trim().toLowerCase();
    final filtered =
        _candidates.where((cover) {
          if (query.isEmpty) return true;
          return cover.serialNumber.toLowerCase().contains(query) ||
              '${cover.currentBaseAssetNumber ?? ''}'.contains(query) ||
              cover.lifecycleState.label.toLowerCase().contains(query);
        }).toList();
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Find Inner Cover',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _search.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              Flexible(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'No Inner Cover matches this search.',
                            style: TextStyle(color: BafColors.textSecondary),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final cover = filtered[index];
                            final selected = cover.id == _selected.id;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              title: Text(
                                cover.serialNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                cover.isInstalled
                                    ? 'Currently on Base ${cover.currentBaseAssetNumber}'
                                    : 'Available for assignment',
                              ),
                              onTap: () => setState(() => _selected = cover),
                            );
                          },
                        ),
              ),
              if (_selected.isInstalled)
                const Padding(
                  padding: EdgeInsets.only(top: BafSpacing.sm),
                  child: Text(
                    'This serial is already linked to another Base. Confirming transfers it or swaps both installed covers atomically.',
                    style: TextStyle(color: BafColors.warning),
                  ),
                ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                ),
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
            final reason = _reason.text.trim();
            if (reason.isEmpty) return;
            Navigator.pop(
              context,
              _PairingSelection(cover: _selected, reason: reason),
            );
          },
          child: Text(widget.current == null ? 'Link' : 'Confirm change'),
        ),
      ],
    );
  }
}

class _BaseAssignmentSelection {
  final AssetInstanceRecord base;
  final String reason;

  const _BaseAssignmentSelection({required this.base, required this.reason});
}

class _BaseAssignmentDialog extends StatefulWidget {
  final InnerCoverProfile cover;
  final List<AssetInstanceRecord> bases;
  final Map<String, BaseInnerCoverAssignment> assignments;

  const _BaseAssignmentDialog({
    required this.cover,
    required this.bases,
    required this.assignments,
  });

  @override
  State<_BaseAssignmentDialog> createState() => _BaseAssignmentDialogState();
}

class _BaseAssignmentDialogState extends State<_BaseAssignmentDialog> {
  final _search = TextEditingController();
  final _reason = TextEditingController();
  AssetInstanceRecord? _selected;
  late bool _showOccupied = widget.bases.every(
    (base) => widget.assignments.containsKey(base.id),
  );

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final vacantCount =
        widget.bases
            .where((base) => !widget.assignments.containsKey(base.id))
            .length;
    final filtered =
        widget.bases.where((base) {
            final assignment = widget.assignments[base.id];
            if (!_showOccupied && assignment != null) return false;
            if (query.isEmpty) return true;
            return '${base.assetNumber}'.contains(query) ||
                base.name.toLowerCase().contains(query) ||
                (assignment?.innerCoverSerialNumber.toLowerCase().contains(
                      query,
                    ) ??
                    false);
          }).toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final selectedAssignment =
        _selected == null ? null : widget.assignments[_selected!.id];
    final canSubmit = _selected != null && _reason.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text('Assign ${widget.cover.serialNumber} to a Base'),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Find Base number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon:
                      _search.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text('Vacant $vacantCount'),
                    selected: !_showOccupied,
                    onSelected:
                        (_) => setState(() {
                          _showOccupied = false;
                          if (_selected != null &&
                              widget.assignments.containsKey(_selected!.id)) {
                            _selected = null;
                          }
                        }),
                  ),
                  ChoiceChip(
                    label: Text('All ${widget.bases.length}'),
                    selected: _showOccupied,
                    onSelected: (_) => setState(() => _showOccupied = true),
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              Flexible(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'No Base matches this search and filter.',
                            style: TextStyle(color: BafColors.textSecondary),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final base = filtered[index];
                            final assignment = widget.assignments[base.id];
                            final selected = _selected?.id == base.id;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                              ),
                              title: Text(
                                'Base ${base.assetNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                assignment == null
                                    ? 'Vacant'
                                    : 'Inner Cover ${assignment.innerCoverSerialNumber} installed',
                              ),
                              onTap: () => setState(() => _selected = base),
                            );
                          },
                        ),
              ),
              if (selectedAssignment != null)
                Padding(
                  padding: const EdgeInsets.only(top: BafSpacing.sm),
                  child: Text(
                    'Confirming replaces Inner Cover ${selectedAssignment.innerCoverSerialNumber}; the displaced cover returns to inspection.',
                    style: const TextStyle(color: BafColors.warning),
                  ),
                ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reason,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Assignment reason',
                  alignLabelWithHint: true,
                ),
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
              canSubmit
                  ? () => Navigator.pop(
                    context,
                    _BaseAssignmentSelection(
                      base: _selected!,
                      reason: _reason.text.trim(),
                    ),
                  )
                  : null,
          child: Text(selectedAssignment == null ? 'Assign' : 'Replace'),
        ),
      ],
    );
  }
}

class _StateReasonResult {
  final InnerCoverLifecycleState state;
  final InnerCoverRetirementCondition? retirementCondition;
  final String reason;

  const _StateReasonResult({
    required this.state,
    required this.retirementCondition,
    required this.reason,
  });
}

class _StateReasonDialog extends StatefulWidget {
  final String title;
  final List<InnerCoverLifecycleState> states;
  final InnerCoverLifecycleState initialState;
  final String? supportingText;
  final bool requireHistoricalRetirementCondition;

  const _StateReasonDialog({
    required this.title,
    required this.states,
    required this.initialState,
    this.supportingText,
    this.requireHistoricalRetirementCondition = false,
  });

  @override
  State<_StateReasonDialog> createState() => _StateReasonDialogState();
}

class _StateReasonDialogState extends State<_StateReasonDialog> {
  late InnerCoverLifecycleState _state = widget.initialState;
  InnerCoverRetirementCondition? _retirementCondition;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _needsRetirementCondition =>
      _state == InnerCoverLifecycleState.retiredForSalvage ||
      (widget.requireHistoricalRetirementCondition &&
          _state == InnerCoverLifecycleState.awaitingInspection);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.supportingText != null) ...[
            Text(
              widget.supportingText!,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.md),
          ],
          DropdownButtonFormField<InnerCoverLifecycleState>(
            initialValue: _state,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Resulting state'),
            items:
                widget.states
                    .map(
                      (state) => DropdownMenuItem(
                        value: state,
                        child: Text(state.label),
                      ),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() {
                  _state = value ?? _state;
                  if (!_needsRetirementCondition) {
                    _retirementCondition = null;
                  }
                }),
          ),
          if (_needsRetirementCondition) ...[
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<InnerCoverRetirementCondition>(
              initialValue: _retirementCondition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Condition recorded at retirement',
              ),
              items: [
                for (final condition in InnerCoverRetirementCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              onChanged:
                  (value) => setState(() => _retirementCondition = value),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              alignLabelWithHint: true,
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
      FilledButton(
        onPressed: () {
          final reason = _reason.text.trim();
          if (reason.isEmpty) return;
          if (_needsRetirementCondition && _retirementCondition == null) {
            return;
          }
          Navigator.pop(
            context,
            _StateReasonResult(
              state: _state,
              retirementCondition: _retirementCondition,
              reason: reason,
            ),
          );
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _AcceptanceResult {
  final DateTime inspectedOn;
  final String acceptanceReference;
  final String? leakTestReference;
  final String? ndtReference;
  final String? notes;
  final String reason;

  const _AcceptanceResult({
    required this.inspectedOn,
    required this.acceptanceReference,
    this.leakTestReference,
    this.ndtReference,
    this.notes,
    required this.reason,
  });
}

class _AcceptanceDialog extends StatefulWidget {
  const _AcceptanceDialog();

  @override
  State<_AcceptanceDialog> createState() => _AcceptanceDialogState();
}

class _AcceptanceDialogState extends State<_AcceptanceDialog> {
  final _acceptance = TextEditingController();
  final _leak = TextEditingController();
  final _ndt = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _acceptance.dispose();
    _leak.dispose();
    _ndt.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Accept Inner Cover'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _acceptance,
              decoration: const InputDecoration(
                labelText: 'Acceptance reference',
              ),
            ),
            TextField(
              controller: _leak,
              decoration: const InputDecoration(
                labelText: 'Leak-test reference',
              ),
            ),
            TextField(
              controller: _ndt,
              decoration: const InputDecoration(labelText: 'NDT reference'),
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Inspection notes'),
            ),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Acceptance reason'),
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
          if (_acceptance.text.trim().isEmpty || _reason.text.trim().isEmpty) {
            return;
          }
          String? optional(TextEditingController controller) {
            final value = controller.text.trim();
            return value.isEmpty ? null : value;
          }

          Navigator.pop(
            context,
            _AcceptanceResult(
              inspectedOn: DateTime.now(),
              acceptanceReference: _acceptance.text.trim(),
              leakTestReference: optional(_leak),
              ndtReference: optional(_ndt),
              notes: optional(_notes),
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Accept'),
      ),
    ],
  );
}

class _RegistrationResult {
  final String serialNumber;
  final InnerCoverSourceType sourceType;
  final InnerCoverOriginClassification originClassification;
  final String? supplierOrFabricator;
  final DateTime? receivedOrCompletedOn;
  final DateTime? incorporatedOn;
  final String? drawingReference;
  final String? materialGrade;
  final String? notes;
  final String reason;
  final List<InnerCoverFabricationSectionDraft> sections;

  const _RegistrationResult({
    required this.serialNumber,
    required this.sourceType,
    required this.originClassification,
    this.supplierOrFabricator,
    this.receivedOrCompletedOn,
    this.incorporatedOn,
    this.drawingReference,
    this.materialGrade,
    this.notes,
    required this.reason,
    required this.sections,
  });
}

class _RegistrationDialog extends StatefulWidget {
  final List<InnerCoverProfile> profiles;

  const _RegistrationDialog({required this.profiles});

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  final _scrollController = ScrollController();
  final _identityKey = GlobalKey();
  final _timelineKey = GlobalKey();
  final _fabricationKey = GlobalKey();
  final _recordKey = GlobalKey();
  final _serial = TextEditingController();
  final _supplier = TextEditingController();
  final _drawing = TextEditingController();
  final _material = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();
  String? _serialError;
  String? _reasonError;
  String? _sectionsError;
  String? _dateError;
  InnerCoverOriginClassification _origin =
      InnerCoverOriginClassification.documentedPurchase;
  DateTime? _receivedOrCompletedOn;
  DateTime? _incorporatedOn;
  late final Map<InnerCoverFabricationSectionType, _SectionEditorState>
  _sections = {
    for (final type in const [
      InnerCoverFabricationSectionType.lowerAssembly,
      InnerCoverFabricationSectionType.flatVertical,
      InnerCoverFabricationSectionType.corrugatedShell,
      InnerCoverFabricationSectionType.topCover,
    ])
      type: _SectionEditorState(type),
  };

  @override
  void dispose() {
    _scrollController.dispose();
    _serial.dispose();
    _supplier.dispose();
    _drawing.dispose();
    _material.dispose();
    _notes.dispose();
    _reason.dispose();
    for (final state in _sections.values) {
      state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final donors =
        widget.profiles
            .where(
              (cover) => const {
                InnerCoverLifecycleState.retiredForSalvage,
                InnerCoverLifecycleState.partiallyDismantled,
              }.contains(cover.lifecycleState),
            )
            .toList();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final form = SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          compact
              ? const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.lg,
                BafSpacing.lg,
                BafSpacing.xl,
              )
              : EdgeInsets.zero,
      child: _buildForm(donors),
    );

    if (compact) {
      return Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: BafColors.background,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancel registration',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
            title: const Text('Register Inner Cover'),
          ),
          body: SafeArea(top: false, child: form),
          bottomNavigationBar: _RegistrationActionBar(
            onCancel: () => Navigator.pop(context),
            onRegister: _submit,
            keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Register Inner Cover'),
      content: SizedBox(width: 620, child: form),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Register'),
        ),
      ],
    );
  }

  Widget _buildForm(List<InnerCoverProfile> donors) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KeyedSubtree(
        key: _identityKey,
        child: _RegistrationFormSection(
          icon: Icons.badge_outlined,
          title: 'Identity and route',
          subtitle: _originDescription(_origin),
          children: [
            DropdownButtonFormField<InnerCoverOriginClassification>(
              initialValue: _origin,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Registration route',
              ),
              items:
                  InnerCoverOriginClassification.values
                      .map(
                        (origin) => DropdownMenuItem(
                          value: origin,
                          child: Text(
                            origin.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: _changeOrigin,
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              onChanged:
                  (_) => setState(() {
                    _serialError = null;
                  }),
              decoration: InputDecoration(
                labelText: 'Inner Cover serial number',
                hintText: 'For example, GR4 or N16',
                errorText: _serialError,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: BafSpacing.xxl),
      KeyedSubtree(
        key: _timelineKey,
        child: _RegistrationFormSection(
          icon: Icons.event_available_outlined,
          title: 'Plant timeline',
          subtitle:
              'Use the actual historical dates when this cover predates the app.',
          children: [
            _ResponsiveFormPair(
              first: InnerCoverRegistrationDateField(
                label: _sourceType.receiptOrCompletionDateLabel,
                helperText: _sourceType.receiptOrCompletionDateHelp,
                value: _receivedOrCompletedOn,
                clearTooltip: 'Clear historical date',
                chooseTooltip: 'Choose historical date',
                onClear:
                    () => setState(() {
                      _receivedOrCompletedOn = null;
                      _dateError = null;
                    }),
                onChoose: _pickReceivedOrCompletedDate,
              ),
              second: InnerCoverRegistrationDateField(
                label: 'Date incorporated',
                helperText: 'Optional plant incorporation date',
                value: _incorporatedOn,
                errorText: _dateError,
                clearTooltip: 'Clear incorporation date',
                chooseTooltip: 'Choose incorporation date',
                onClear:
                    () => setState(() {
                      _incorporatedOn = null;
                      _dateError = null;
                    }),
                onChoose: _pickIncorporationDate,
              ),
            ),
          ],
        ),
      ),
      const Divider(height: BafSpacing.xxl),
      _RegistrationFormSection(
        icon: _originIcon(_origin),
        title: _sourceRecordTitle(_origin),
        subtitle: _sourceRecordDescription(_origin),
        children: [
          TextField(
            controller: _supplier,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: _supplierLabel(_origin)),
          ),
          const SizedBox(height: BafSpacing.md),
          _ResponsiveFormPair(
            first: TextField(
              controller: _drawing,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Drawing reference (optional)',
              ),
            ),
            second: TextField(
              controller: _material,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Material grade (optional)',
              ),
            ),
          ),
        ],
      ),
      if (_isFabricatedOrigin) ...[
        const Divider(height: BafSpacing.xxl),
        KeyedSubtree(
          key: _fabricationKey,
          child: _RegistrationFormSection(
            icon: Icons.precision_manufacturing_outlined,
            title: 'Fabrication sections',
            subtitle:
                'Expand a section to record its material source, dimensions or donor trace.',
            children: [
              if (_sectionsError != null) ...[
                _InlineFormError(message: _sectionsError!),
                const SizedBox(height: BafSpacing.sm),
              ],
              ..._sections.values.map(
                (state) => _FabricationSectionEditor(
                  state: state,
                  donors: donors,
                  onChanged:
                      () => setState(() {
                        _sectionsError = null;
                      }),
                ),
              ),
            ],
          ),
        ),
      ],
      const Divider(height: BafSpacing.xxl),
      KeyedSubtree(
        key: _recordKey,
        child: _RegistrationFormSection(
          icon: Icons.edit_note_rounded,
          title: 'Registration record',
          subtitle:
              'Retain useful context and state why this asset is being added.',
          children: [
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Registration notes (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged:
                  (_) => setState(() {
                    _reasonError = null;
                  }),
              decoration: InputDecoration(
                labelText: 'Registration reason',
                helperText: 'Required for the audit trail',
                errorText: _reasonError,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _changeOrigin(InnerCoverOriginClassification? value) {
    setState(() {
      final nextOrigin = value ?? _origin;
      final sourceChanged = _sourceTypeForOrigin(nextOrigin) != _sourceType;
      _origin = nextOrigin;
      if (sourceChanged) _receivedOrCompletedOn = null;
      if (_origin == InnerCoverOriginClassification.ownerDeclaredFabricated) {
        for (final state in _sections.values) {
          state.markAncestryUnknown();
        }
      } else if (_origin ==
          InnerCoverOriginClassification.documentedFabrication) {
        for (final state in _sections.values) {
          state.markNewFabricated();
        }
      }
      _sectionsError = null;
      _dateError = null;
    });
  }

  void _submit() {
    final serial = _serial.text.trim();
    final reason = _reason.text.trim();
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final sections =
        _isFabricatedOrigin
            ? _sections.values.map((state) => state.toDraft()).toList()
            : const <InnerCoverFabricationSectionDraft>[];
    final sectionErrors = sections
        .expand((section) => section.validate())
        .toList(growable: false);
    final serialError =
        normalizeInnerCoverSerial(serial).length < 2
            ? 'Enter an Inner Cover serial number.'
            : null;
    final reasonError = reason.isEmpty ? 'Explain the registration.' : null;
    final dateError = innerCoverRegistrationChronologyError(
      receivedOrCompletedOn: _receivedOrCompletedOn,
      incorporatedOn: _incorporatedOn,
    );
    if (serialError != null ||
        reasonError != null ||
        sectionErrors.isNotEmpty ||
        dateError != null) {
      final errorSection =
          serialError != null
              ? _identityKey
              : dateError != null
              ? _timelineKey
              : sectionErrors.isNotEmpty
              ? _fabricationKey
              : _recordKey;
      setState(() {
        _serialError = serialError;
        _reasonError = reasonError;
        _dateError = dateError;
        _sectionsError =
            sectionErrors.isEmpty
                ? null
                : 'Complete the fabrication evidence: ${sectionErrors.first}';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = errorSection.currentContext;
        if (!mounted || targetContext == null) return;
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      });
      return;
    }
    Navigator.pop(
      context,
      _RegistrationResult(
        serialNumber: serial,
        sourceType: _sourceType,
        originClassification: _origin,
        supplierOrFabricator: optional(_supplier),
        receivedOrCompletedOn: _receivedOrCompletedOn,
        incorporatedOn: _incorporatedOn,
        drawingReference: optional(_drawing),
        materialGrade: optional(_material),
        notes: optional(_notes),
        reason: reason,
        sections: sections,
      ),
    );
  }

  Future<void> _pickReceivedOrCompletedDate() async {
    final now = DateTime.now();
    final current = _receivedOrCompletedOn?.toLocal() ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: _sourceType.receiptOrCompletionDateLabel,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _receivedOrCompletedOn = innerCoverRegistrationInstantForLocalDate(
        selected,
      );
      _dateError = null;
    });
  }

  Future<void> _pickIncorporationDate() async {
    final now = DateTime.now();
    final current = _incorporatedOn?.toLocal() ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Date incorporated',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _incorporatedOn = innerCoverIncorporationInstantForLocalDate(selected);
      _dateError = null;
    });
  }

  bool get _isFabricatedOrigin => const {
    InnerCoverOriginClassification.documentedFabrication,
    InnerCoverOriginClassification.ownerDeclaredFabricated,
  }.contains(_origin);

  InnerCoverSourceType get _sourceType => _sourceTypeForOrigin(_origin);
}

InnerCoverSourceType _sourceTypeForOrigin(
  InnerCoverOriginClassification origin,
) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase =>
    InnerCoverSourceType.purchased,
  InnerCoverOriginClassification.documentedFabrication ||
  InnerCoverOriginClassification
      .ownerDeclaredFabricated => InnerCoverSourceType.fabricated,
  InnerCoverOriginClassification.ownerDeclaredNew ||
  InnerCoverOriginClassification
      .legacyUndocumented => InnerCoverSourceType.legacyExisting,
};

String _originDescription(
  InnerCoverOriginClassification origin,
) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase =>
    'Purchased cover supported by supplier or receipt records.',
  InnerCoverOriginClassification.documentedFabrication =>
    'Fabricated cover with traceable fabrication evidence.',
  InnerCoverOriginClassification.ownerDeclaredNew =>
    'New cover recorded on owner declaration where source papers are unavailable.',
  InnerCoverOriginClassification.ownerDeclaredFabricated =>
    'Fabricated cover reconstructed from owner knowledge.',
  InnerCoverOriginClassification.legacyUndocumented =>
    'Existing plant cover whose original source is undocumented.',
};

String _sourceRecordTitle(InnerCoverOriginClassification origin) =>
    switch (origin) {
      InnerCoverOriginClassification.documentedPurchase => 'Purchase record',
      InnerCoverOriginClassification.documentedFabrication =>
        'Fabrication identity',
      InnerCoverOriginClassification.ownerDeclaredNew =>
        'Owner-declared provenance',
      InnerCoverOriginClassification.ownerDeclaredFabricated =>
        'Owner-declared fabrication',
      InnerCoverOriginClassification.legacyUndocumented =>
        'Known legacy provenance',
    };

String _sourceRecordDescription(InnerCoverOriginClassification origin) =>
    switch (origin) {
      InnerCoverOriginClassification.documentedPurchase =>
        'Capture any available supplier and technical references.',
      InnerCoverOriginClassification.documentedFabrication =>
        'Capture the fabricator and governing technical references.',
      InnerCoverOriginClassification.ownerDeclaredNew =>
        'Record whatever source information can still be established.',
      InnerCoverOriginClassification.ownerDeclaredFabricated =>
        'Record the known fabricator or shop and any surviving references.',
      InnerCoverOriginClassification.legacyUndocumented =>
        'Optional provenance may be added without overstating certainty.',
    };

String _supplierLabel(
  InnerCoverOriginClassification origin,
) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase => 'Supplier (optional)',
  InnerCoverOriginClassification.documentedFabrication =>
    'Fabricator / shop (optional)',
  InnerCoverOriginClassification.ownerDeclaredNew =>
    'Known supplier / source (optional)',
  InnerCoverOriginClassification.ownerDeclaredFabricated =>
    'Known fabricator / shop (optional)',
  InnerCoverOriginClassification.legacyUndocumented =>
    'Known supplier / fabricator (optional)',
};

IconData _originIcon(InnerCoverOriginClassification origin) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase =>
    Icons.local_shipping_outlined,
  InnerCoverOriginClassification.documentedFabrication ||
  InnerCoverOriginClassification
      .ownerDeclaredFabricated => Icons.precision_manufacturing_outlined,
  InnerCoverOriginClassification.ownerDeclaredNew =>
    Icons.new_releases_outlined,
  InnerCoverOriginClassification.legacyUndocumented => Icons.history_rounded,
};
