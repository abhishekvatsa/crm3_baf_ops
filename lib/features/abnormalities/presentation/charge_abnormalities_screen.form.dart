part of 'charge_abnormalities_screen.dart';

class _ChargeAbnormalityFormDialog extends ConsumerStatefulWidget {
  final int sourceChargeNo;
  final String originUid;
  final List<AbnormalityType> activeTypes;
  final ChargeAbnormality? existing;

  const _ChargeAbnormalityFormDialog({
    required this.sourceChargeNo,
    required this.originUid,
    required this.activeTypes,
    required this.existing,
  });

  @override
  ConsumerState<_ChargeAbnormalityFormDialog> createState() =>
      _ChargeAbnormalityFormDialogState();
}

class _ChargeAbnormalityFormDialogState
    extends ConsumerState<_ChargeAbnormalityFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final List<AbnormalityType> _availableTypes;
  late AbnormalityType _selectedType;
  late AbnormalitySeverity _selectedSeverity;
  late RootReasonCategory _selectedRootReason;
  late ReannealingStatus _selectedReannealingStatus;
  AbnormalityObservationKind? _observationKind;
  final List<CandidateProcessCause> _candidateCauses = [];
  DateTime? _raPerformedAt;
  PostRaResult _postRaResult = PostRaResult.notAssessed;
  final _postRaObservation = TextEditingController();

  late final TextEditingController _observedReasonController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _rootReasonNotesController;
  late final TextEditingController _reannealedToChargeController;
  late final TextEditingController _correctionReasonController;
  late final DateTime _eventAt;

  late final List<AffectedAssetRef> _affectedAssets;
  String? _legacyComponent;
  String? _selectedAssetClassId;
  String? _selectedAssetInstanceId;
  AssetHierarchyReference? _pendingTargetReference;
  String? _assetSelectionError;
  bool _addingAsset = false;
  bool _submitting = false;
  bool _choosingComponent = false;
  bool _assetChoiceInvalid = false;
  bool get _equipmentBusy => _addingAsset || _submitting || _choosingComponent;
  void _updateEquipment(VoidCallback update) => setState(update);

  bool get _formActive => mounted && ModalRoute.of(context)?.isCurrent == true;

  bool get _actorCanSubmit =>
      currentActorActionMessage(
        CurrentActorAccess.resolve(ref.read(currentAppUserProvider)),
        originUid: widget.originUid,
        permission: (actor) => widget.existing == null
            ? actor.canLogChargeAbnormality
            : actor.canEditChargeAbnormality,
      ) ==
      null;
  void _updateAssessment(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _eventAt = existing?.loggedAt ?? DateTime.now();

    _availableTypes = _abnormalityTypesForForm(
      activeTypes: widget.activeTypes,
      existing: existing,
    );
    _selectedType = _availableTypes.first;
    _observationKind = existing == null
        ? AbnormalityObservationKind.resultFinding
        : existing.observationKind ?? AbnormalityObservationKind.legacyUnknown;
    if (existing == null) {
      _selectedType =
          _availableTypes.where(_isResultType).firstOrNull ?? _selectedType;
    }
    _candidateCauses.addAll(existing?.assessment?.candidateCauses ?? []);
    _raPerformedAt = existing?.raPerformedAt;
    _postRaResult =
        existing?.assessment?.postRaResult ?? PostRaResult.notAssessed;
    _postRaObservation.text = existing?.assessment?.postRaObservation ?? '';

    _selectedSeverity = existing?.severity ?? _selectedType.severity;
    _selectedRootReason =
        existing?.possibleRootReasonCategory ?? RootReasonCategory.unknown;

    _selectedReannealingStatus =
        existing?.reannealingStatus ?? _defaultRaStatusForType(_selectedType);

    _legacyComponent = _emptyToNull(existing?.component ?? '');
    _observedReasonController = TextEditingController(
      text: existing?.observedReason ?? '',
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _rootReasonNotesController = TextEditingController(
      text: existing?.possibleRootReasonNotes ?? '',
    );
    _reannealedToChargeController = TextEditingController(
      text: existing?.reannealedToChargeNo?.toString() ?? '',
    );
    _correctionReasonController = TextEditingController();
    _affectedAssets = [
      ...(existing?.affectedAssets ?? const <AffectedAssetRef>[]),
    ];
  }

  @override
  void dispose() {
    _observedReasonController.dispose();
    _descriptionController.dispose();
    _rootReasonNotesController.dispose();
    _reannealedToChargeController.dispose();
    _correctionReasonController.dispose();
    _postRaObservation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    final form = Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          widget.existing == null
              ? 'Log charge abnormality'
              : 'Edit charge abnormality',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _equipmentBusy,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.md,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            children: [
              _ChargeContextStrip(sourceChargeNo: widget.sourceChargeNo),
              const SizedBox(height: BafSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final hasHistoricalChoice =
                      widget.existing != null &&
                      widget.existing!.observationKind == null;
                  final minimumWidth = hasHistoricalChoice ? 580 : 380;
                  return SegmentedButton<AbnormalityObservationKind>(
                    key: const ValueKey('abnormality-observation-kind'),
                    direction: constraints.maxWidth / textScale < minimumWidth
                        ? Axis.vertical
                        : Axis.horizontal,
                    emptySelectionAllowed: _observationKind == null,
                    segments: [
                      const ButtonSegment(
                        value: AbnormalityObservationKind.resultFinding,
                        label: Text('Result finding'),
                      ),
                      const ButtonSegment(
                        value: AbnormalityObservationKind.processEquipment,
                        label: Text('Process / equipment'),
                      ),
                      if (widget.existing != null &&
                          widget.existing!.observationKind == null)
                        const ButtonSegment(
                          value: AbnormalityObservationKind.legacyUnknown,
                          label: Text('Keep historical kind unknown'),
                        ),
                    ],
                    selected: {if (_observationKind != null) _observationKind!},
                    onSelectionChanged: (values) => setState(() {
                      _observationKind = values.single;
                      if (widget.existing == null) {
                        _selectedType =
                            _matchingTypes.firstOrNull ?? _selectedType;
                        _selectedSeverity = _selectedType.severity;
                      }
                    }),
                  );
                },
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                _observationKind == null ||
                        _observationKind ==
                            AbnormalityObservationKind.legacyUnknown
                    ? 'Historical observation kind was not recorded. Keep it unknown unless evidence supports a classification.'
                    : _observationKind ==
                          AbnormalityObservationKind.resultFinding
                    ? 'Record the observed coil result. Colour does not decide whether RA is required.'
                    : 'Record what happened to the process or equipment. A shared charge does not prove a cause.',
              ),
              const SizedBox(height: BafSpacing.lg),
              const _SectionTitle(
                icon: Icons.category_outlined,
                title: 'Classification',
                subtitle:
                    'Choose the governed event type and observed severity.',
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<AbnormalityType>(
                key: ValueKey(
                  'abnormality-type-${_selectedType.firestoreId ?? _selectedType.code}',
                ),
                initialValue: _selectedType,
                isExpanded: true,
                decoration: _inputDecoration(label: 'Abnormality type'),
                selectedItemBuilder: (context) => _visibleTypes
                    .map(
                      (type) => Text(
                        '${type.code} - ${type.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
                items: _visibleTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          '${type.code} - ${type.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedType = value;
                    _selectedSeverity = value.severity;
                    _assetChoiceInvalid = false;
                    _selectedAssetClassId = null;
                    _selectedAssetInstanceId = null;
                    _pendingTargetReference = null;
                    _assetSelectionError = null;
                  });
                },
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<AbnormalitySeverity>(
                key: ValueKey('severity-${_selectedSeverity.name}'),
                initialValue: _selectedSeverity,
                isExpanded: true,
                decoration: _inputDecoration(label: 'Observed severity'),
                items: AbnormalitySeverity.values
                    .map(
                      (severity) => DropdownMenuItem(
                        value: severity,
                        child: Text(_severityLabel(severity)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedSeverity = value);
                },
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  StatusBadge(
                    label: _categoryLabel(_selectedType.category),
                    color: _categoryColor(_selectedType.category),
                    icon: Icons.category_rounded,
                  ),
                  StatusBadge(
                    label: _severityLabel(_selectedSeverity),
                    color: _severityColor(_selectedSeverity),
                    icon: Icons.priority_high_rounded,
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.xl),
              const _SectionTitle(
                icon: Icons.visibility_outlined,
                title: 'Observation',
                subtitle:
                    'Record what was observed; possible causes are assessed separately.',
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                key: const ValueKey('abnormality-observation'),
                controller: _observedReasonController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  label:
                      _observationKind ==
                          AbnormalityObservationKind.legacyUnknown
                      ? 'Recorded observation'
                      : _observationKind ==
                            AbnormalityObservationKind.processEquipment
                      ? 'Process or equipment observation'
                      : 'Observed result',
                  hint:
                      'What happened, what was seen, and why it matters to this charge',
                ),
                validator: (value) => _requiredTextValidation(
                  value,
                  label: 'Observation',
                  maximum: 2000,
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                  label: 'Additional description',
                  hint: 'Optional supporting detail',
                ),
                validator: (value) => _optionalTextValidation(
                  value,
                  label: 'Additional description',
                  maximum: 4000,
                ),
              ),
              const SizedBox(height: BafSpacing.xl),
              const _SectionTitle(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Affected equipment',
                subtitle:
                    'Log abnormality includes your current asset and component selection. Use Add affected equipment only when including more assets.',
              ),
              const SizedBox(height: BafSpacing.sm),
              _buildAffectedEquipmentComposer(),
              if (_assetSelectionError != null) ...[
                const SizedBox(height: BafSpacing.sm),
                _FormNotice(
                  icon: Icons.error_outline_rounded,
                  message: _assetSelectionError!,
                  color: BafColors.danger,
                ),
              ],
              const SizedBox(height: BafSpacing.md),
              if (_affectedAssets.isEmpty && _selectedAssetInstanceId == null)
                const _FormNotice(
                  icon: Icons.inventory_2_outlined,
                  message:
                      'Select at least one governed affected asset before logging this abnormality.',
                  color: BafColors.warning,
                )
              else
                for (final asset in _affectedAssets) ...[
                  _AffectedAssetTile(
                    asset: asset,
                    onRemove: () => _removeAffectedAsset(asset),
                  ),
                  const SizedBox(height: BafSpacing.sm),
                ],
              if (_legacyComponent != null &&
                  !_affectedAssets.any((asset) => asset.componentLabel != null))
                _FormNotice(
                  icon: Icons.history_rounded,
                  message:
                      'Historical component text retained: $_legacyComponent. Replace the legacy asset entry with a governed component when its identity is known.',
                  color: BafColors.audit,
                ),
              const SizedBox(height: BafSpacing.xl),
              if (widget.existing != null &&
                  (_selectedRootReason != RootReasonCategory.unknown ||
                      _rootReasonNotesController.text.isNotEmpty)) ...[
                const _SectionTitle(
                  icon: Icons.history_outlined,
                  title: 'Retained historical cause notes',
                  subtitle:
                      'Record an early view; investigation may refine it later.',
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RootReasonCategory>(
                  key: ValueKey('root-reason-${_selectedRootReason.name}'),
                  initialValue: _selectedRootReason,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Possible root-reason area',
                  ),
                  items: RootReasonCategory.values
                      .map(
                        (rootCategory) => DropdownMenuItem(
                          value: rootCategory,
                          child: Text(
                            _rootReasonCategoryLabel(rootCategory),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRootReason = value);
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _rootReasonNotesController,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    label: 'Cause notes',
                    hint: 'Optional evidence or working hypothesis',
                  ),
                  validator: (value) => _optionalTextValidation(
                    value,
                    label: 'Cause notes',
                    maximum: 4000,
                  ),
                ),
                const SizedBox(height: BafSpacing.xl),
              ],
              ..._assessmentCauseWidgets(),
              const _SectionTitle(
                icon: Icons.repeat_rounded,
                title: 'RA decision and action',
                subtitle:
                    'Record the operational lifecycle state. The Quality warning remains the formal closure record.',
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<ReannealingStatus>(
                key: const ValueKey('abnormality-ra-decision'),
                initialValue:
                    _selectedReannealingStatus == ReannealingStatus.completed
                    ? ReannealingStatus.required
                    : _selectedReannealingStatus,
                isExpanded: true,
                decoration: _inputDecoration(label: 'RA decision'),
                items: ReannealingStatus.values
                    .where((status) => status != ReannealingStatus.completed)
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_raStatusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedReannealingStatus = value;
                    if (value != ReannealingStatus.completed) {
                      _reannealedToChargeController.clear();
                      _raPerformedAt = null;
                      _postRaResult = PostRaResult.notAssessed;
                      _postRaObservation.clear();
                    }
                  });
                },
              ),
              if (_selectedReannealingStatus == ReannealingStatus.required ||
                  _selectedReannealingStatus == ReannealingStatus.completed)
                CheckboxListTile(
                  key: const ValueKey('abnormality-ra-performed'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('RA has actually been performed'),
                  value:
                      _selectedReannealingStatus == ReannealingStatus.completed,
                  onChanged: (value) => setState(() {
                    _selectedReannealingStatus = value == true
                        ? ReannealingStatus.completed
                        : ReannealingStatus.required;
                    if (value != true) {
                      _reannealedToChargeController.clear();
                      _raPerformedAt = null;
                      _postRaResult = PostRaResult.notAssessed;
                      _postRaObservation.clear();
                    }
                  }),
                ),
              if (_selectedReannealingStatus ==
                  ReannealingStatus.completed) ...[
                const SizedBox(height: BafSpacing.md),
                TextFormField(
                  controller: _reannealedToChargeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: chargeNumberInputFormatters,
                  decoration: _inputDecoration(
                    label: 'New RA charge number',
                    hint: 'Exactly five digits',
                  ),
                  validator: _validateRaCharge,
                ),
                RaPerformedAtField(
                  value: _raPerformedAt,
                  onChanged: (value) => setState(() => _raPerformedAt = value),
                ),
                if (widget.existing?.hasCompletedReannealing == true &&
                    widget.existing?.raPerformedAt == null)
                  const Text(
                    'Historical completion date is unknown unless you explicitly supply evidence for it.',
                  ),
                DropdownButtonFormField<PostRaResult>(
                  key: const ValueKey('abnormality-post-ra-result'),
                  initialValue: _postRaResult,
                  isExpanded: true,
                  decoration: _inputDecoration(label: 'Post-RA result'),
                  items: PostRaResult.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(switch (value) {
                            PostRaResult.notAssessed => 'Not assessed',
                            PostRaResult.acceptable => 'Acceptable',
                            PostRaResult.abnormal => 'Still abnormal',
                          }),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _postRaResult = value!),
                ),
                TextFormField(
                  controller: _postRaObservation,
                  decoration: _inputDecoration(
                    label: 'Post-RA observations',
                    hint: 'Required when the result has been assessed',
                  ),
                  validator: (value) =>
                      _postRaResult == PostRaResult.notAssessed
                      ? _optionalTextValidation(
                          value,
                          label: 'Post-RA observations',
                          maximum: 2000,
                        )
                      : _requiredTextValidation(
                          value,
                          label: 'Post-RA observations',
                          maximum: 2000,
                        ),
                ),
              ],
              const SizedBox(height: BafSpacing.sm),
              const _FormNotice(
                icon: Icons.link_rounded,
                message:
                    'Required and completed states appear immediately in the linked Quality case. Warning closure or final adjudication remains a separate governed action.',
                color: BafColors.charges,
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: BafSpacing.xl),
                const _SectionTitle(
                  icon: Icons.history_edu_outlined,
                  title: 'Correction audit',
                  subtitle:
                      'Explain why this record is being changed. The reason and before/after values are retained in the immutable audit trail.',
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _correctionReasonController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    label: 'Reason for correction',
                    hint: 'What is being corrected and why',
                  ),
                  validator: (value) => _requiredTextValidation(
                    value,
                    label: 'Reason for correction',
                    maximum: 500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: BafColors.card,
            border: Border(top: BorderSide(color: BafColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BafSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BafColors.charges,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _equipmentBusy ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(
                      widget.existing == null
                          ? 'Log abnormality'
                          : 'Save correction',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (compact) return Dialog.fullscreen(child: form);
    final height = (MediaQuery.sizeOf(context).height * 0.9)
        .clamp(560.0, 860.0)
        .toDouble();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 720, height: height, child: form),
    );
  }

  String? _validateRaCharge(String? value) {
    final text = value?.trim() ?? '';
    if (_selectedReannealingStatus != ReannealingStatus.completed) {
      return text.isEmpty ? null : 'A new charge applies only to completed RA';
    }
    final existing = widget.existing;
    if (existing != null &&
        existing.reannealingStatus != ReannealingStatus.required &&
        existing.reannealingStatus != ReannealingStatus.completed) {
      return 'Save RA required first, then record completion';
    }
    if (text.isEmpty) return 'Enter the new RA charge number';
    final number = parseOptionalChargeNumber(text);
    if (number == null) return 'Enter exactly five digits';
    if (number == widget.sourceChargeNo) {
      return 'New charge cannot be the source charge';
    }
    if (existing?.reannealingStatus == ReannealingStatus.completed &&
        number != existing?.reannealedToChargeNo) {
      return 'Retain the recorded charge, or first correct the state to RA required';
    }
    return null;
  }

  bool _validateFormInputs() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_observationKind == null ||
        (!_matchingTypes.contains(_selectedType) &&
            (widget.existing == null ||
                _observationKind != widget.existing!.observationKind ||
                _selectedType.firestoreId !=
                    widget.existing!.abnormalityTypeId))) {
      setState(
        () => _assetSelectionError =
            'Select an observation kind and an applicable classification.',
      );
      return false;
    }
    if (_selectedReannealingStatus == ReannealingStatus.completed &&
        _raPerformedAt == null &&
        widget.existing?.hasCompletedReannealing != true) {
      setState(
        () => _assetSelectionError =
            'Confirm the actual RA completion date and time.',
      );
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (_equipmentBusy || !_formActive || !_actorCanSubmit) return;
    var submitted = false;
    setState(() => _submitting = true);
    try {
      if (!_validateFormInputs()) return;

      // A withdrawn popup choice must not be silently omitted just because
      // another asset has already been staged.
      if (_assetChoiceInvalid) {
        setState(
          () => _assetSelectionError =
              'Choose a current registered asset before logging.',
        );
        return;
      }
      if (_selectedAssetInstanceId != null || _pendingTargetReference != null) {
        if (!await _addAffectedAsset()) return;
      }
      if (!mounted || !_formActive || !_actorCanSubmit) return;
      if (!_validateFormInputs()) return;

      if (_affectedAssets.isEmpty) {
        setState(() {
          _assetSelectionError =
              'Select at least one governed affected asset before logging.';
        });
        return;
      }
      final applicable = _selectedType.applicableAssetTypes;
      final existing = widget.existing;
      final selectedTypeId = _selectedType.firestoreId ?? _selectedType.code;
      final retainsExistingType =
          existing != null &&
          (selectedTypeId == existing.abnormalityTypeId ||
              _selectedType.code == existing.abnormalityTypeId ||
              _selectedType.code == existing.abnormalityTypeCode);
      final incompatible = _affectedAssets
          .where(
            (asset) => !isAffectedAssetPermittedForCorrection(
              asset: asset,
              currentlyApplicableTypes: applicable,
              existingAffectedAssets:
                  existing?.affectedAssets ?? const <AffectedAssetRef>[],
              retainsExistingType: retainsExistingType,
            ),
          )
          .firstOrNull;
      if (incompatible != null) {
        setState(() {
          _assetSelectionError =
              '${incompatible.label} does not apply to the selected abnormality type.';
        });
        return;
      }

      final reannealedToChargeNo = parseOptionalChargeNumber(
        _reannealedToChargeController.text.trim(),
      );

      submitted = true;
      Navigator.pop(
        context,
        _ChargeAbnormalityDraft(
          assessment: AbnormalityAssessment(
            observationKind: _observationKind!,
            candidateCauses: List.unmodifiable(_candidateCauses),
            raPerformedAt: _raPerformedAt,
            postRaResult: _postRaResult,
            postRaObservation: _emptyToNull(_postRaObservation.text),
          ),
          eventAt: _eventAt,
          selectedType: _selectedType,
          severity: _selectedSeverity,
          affectedAssets: List<AffectedAssetRef>.from(_affectedAssets),
          component: _componentSummary(_affectedAssets, _legacyComponent),
          observedReason: _observedReasonController.text.trim(),
          description: _emptyToNull(_descriptionController.text),
          rootReasonCategory: _selectedRootReason,
          rootReasonNotes: _emptyToNull(_rootReasonNotesController.text),
          reannealingStatus: _selectedReannealingStatus,
          reannealedToChargeNo: reannealedToChargeNo,
          correctionReason: widget.existing == null
              ? null
              : _correctionReasonController.text.trim(),
        ),
      );
    } finally {
      if (mounted && !submitted) setState(() => _submitting = false);
    }
  }
}
