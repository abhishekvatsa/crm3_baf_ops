part of 'charge_abnormalities_screen.dart';

class _ChargeAbnormalityFormDialog extends ConsumerStatefulWidget {
  final int sourceChargeNo;
  final List<AbnormalityType> activeTypes;
  final ChargeAbnormality? existing;

  const _ChargeAbnormalityFormDialog({
    required this.sourceChargeNo,
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
      body: Form(
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
            const SizedBox(height: BafSpacing.lg),
            const _SectionTitle(
              icon: Icons.category_outlined,
              title: 'Classification',
              subtitle: 'Choose the governed event type and observed severity.',
            ),
            const SizedBox(height: BafSpacing.sm),
            DropdownButtonFormField<AbnormalityType>(
              key: ValueKey(
                'abnormality-type-${_selectedType.firestoreId ?? _selectedType.code}',
              ),
              initialValue: _selectedType,
              isExpanded: true,
              decoration: _inputDecoration(label: 'Abnormality type'),
              selectedItemBuilder:
                  (context) =>
                      _availableTypes
                          .map(
                            (type) => Text(
                              '${type.code} - ${type.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                          .toList(),
              items:
                  _availableTypes
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
                  _selectedAssetClassId = null;
                  _selectedAssetInstanceId = null;
                  _pendingTargetReference = null;
                  _assetSelectionError = null;
                  if (widget.existing == null) {
                    _selectedReannealingStatus = _defaultRaStatusForType(value);
                    if (_selectedReannealingStatus !=
                        ReannealingStatus.completed) {
                      _reannealedToChargeController.clear();
                    }
                  }
                });
              },
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<AbnormalitySeverity>(
              key: ValueKey('severity-${_selectedSeverity.name}'),
              initialValue: _selectedSeverity,
              isExpanded: true,
              decoration: _inputDecoration(label: 'Observed severity'),
              items:
                  AbnormalitySeverity.values
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
                if (_selectedType.suggestsReannealing)
                  const StatusBadge(
                    label: 'RA suggested',
                    color: BafColors.audit,
                    icon: Icons.repeat_rounded,
                  ),
              ],
            ),
            const SizedBox(height: BafSpacing.xl),
            const _SectionTitle(
              icon: Icons.visibility_outlined,
              title: 'Observation',
              subtitle:
                  'This opinion is also carried into the linked Quality warning.',
            ),
            const SizedBox(height: BafSpacing.sm),
            TextFormField(
              controller: _observedReasonController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(
                label: 'Observed reason',
                hint:
                    'What happened, what was seen, and why it matters to this charge',
              ),
              validator:
                  (value) => _requiredTextValidation(
                    value,
                    label: 'Observed reason',
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
              validator:
                  (value) => _optionalTextValidation(
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
                  'Select registered assets and, where known, their governed component or subcomponent.',
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
            if (_affectedAssets.isEmpty)
              const _FormNotice(
                icon: Icons.inventory_2_outlined,
                message:
                    'Add at least one governed affected asset before logging this abnormality.',
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
            const _SectionTitle(
              icon: Icons.manage_search_outlined,
              title: 'Initial cause assessment',
              subtitle:
                  'Record an early view; investigation may refine it later.',
            ),
            const SizedBox(height: BafSpacing.sm),
            DropdownButtonFormField<RootReasonCategory>(
              key: ValueKey('root-reason-${_selectedRootReason.name}'),
              initialValue: _selectedRootReason,
              isExpanded: true,
              decoration: _inputDecoration(label: 'Possible root-reason area'),
              items:
                  RootReasonCategory.values
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
              validator:
                  (value) => _optionalTextValidation(
                    value,
                    label: 'Cause notes',
                    maximum: 4000,
                  ),
            ),
            const SizedBox(height: BafSpacing.xl),
            const _SectionTitle(
              icon: Icons.repeat_rounded,
              title: 'Re-annealing / RA traceability',
              subtitle:
                  'Record the operational lifecycle state. The Quality warning remains the formal closure record.',
            ),
            const SizedBox(height: BafSpacing.sm),
            DropdownButtonFormField<ReannealingStatus>(
              key: ValueKey('ra-status-${_selectedReannealingStatus.name}'),
              initialValue: _selectedReannealingStatus,
              isExpanded: true,
              decoration: _inputDecoration(label: 'RA lifecycle state'),
              items:
                  ReannealingStatus.values
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
                  }
                });
              },
            ),
            if (_selectedReannealingStatus == ReannealingStatus.completed) ...[
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
                validator:
                    (value) => _requiredTextValidation(
                      value,
                      label: 'Reason for correction',
                      maximum: 500,
                    ),
              ),
            ],
          ],
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
                    onPressed: _submit,
                    icon: const Icon(Icons.fact_check_outlined),
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
    final height =
        (MediaQuery.sizeOf(context).height * 0.9)
            .clamp(560.0, 860.0)
            .toDouble();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 720, height: height, child: form),
    );
  }

  Widget _buildAffectedEquipmentComposer() {
    final classesValue = ref.watch(assetClassesProvider);
    return classesValue.when(
      loading:
          () => const _AssetSelectionMessage(
            icon: Icons.sync_rounded,
            message: 'Loading the governed asset register...',
            color: BafColors.assets,
            showProgress: true,
          ),
      error:
          (error, stackTrace) => const _AssetSelectionMessage(
            icon: Icons.error_outline_rounded,
            message:
                'The governed asset register could not be loaded. Sync and try again.',
            color: BafColors.danger,
          ),
      data: (allClasses) {
        final classes = activeIssueAssetClasses(allClasses)
            .where(
              (assetClass) =>
                  _selectedType.applicableAssetTypes.isEmpty ||
                  _selectedType.applicableAssetTypes.contains(
                    resolveGovernedIssueAssetRoute(
                      issueClass: assetClass,
                      allClasses: allClasses,
                    ).assetType,
                  ),
            )
            .toList(growable: false);
        if (classes.isEmpty) {
          return const _AssetSelectionMessage(
            icon: Icons.inventory_2_outlined,
            message:
                'No active registered asset class applies to this abnormality type.',
            color: BafColors.warning,
          );
        }
        final selectedClass = _findAssetClass(classes, _selectedAssetClassId);
        final route =
            selectedClass == null
                ? null
                : resolveGovernedIssueAssetRoute(
                  issueClass: selectedClass,
                  allClasses: allClasses,
                );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(
                'abnormality-asset-class-${selectedClass?.id ?? 'none'}-${classes.length}',
              ),
              initialValue: selectedClass?.id,
              isExpanded: true,
              decoration: _inputDecoration(label: 'Asset class'),
              items:
                  classes
                      .map(
                        (assetClass) => DropdownMenuItem(
                          value: assetClass.id,
                          child: Text(
                            assetClass.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (classId) {
                setState(() {
                  _selectedAssetClassId = classId;
                  _selectedAssetInstanceId = null;
                  _pendingTargetReference = null;
                  _assetSelectionError = null;
                });
              },
            ),
            if (route != null) ...[
              const SizedBox(height: BafSpacing.md),
              if (!route.isAvailable)
                _AssetSelectionMessage(
                  icon: Icons.block_outlined,
                  message:
                      route.blockingReason ??
                      'This asset class is not currently available.',
                  color: BafColors.danger,
                )
              else ...[
                if (route.innerCoverByBase) ...[
                  const _FormNotice(
                    icon: Icons.link_rounded,
                    message:
                        'Choose the Base carrying the Inner Cover. The current serial-number linkage is frozen with this event.',
                    color: BafColors.assets,
                  ),
                  const SizedBox(height: BafSpacing.md),
                ],
                _buildPhysicalAssetSelector(route),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildPhysicalAssetSelector(GovernedIssueAssetRoute route) {
    final physicalClass = route.physicalAssetClass!;
    final assetsValue = ref.watch(assetInstancesProvider(physicalClass.id));
    return assetsValue.when(
      loading:
          () => const _AssetSelectionMessage(
            icon: Icons.sync_rounded,
            message: 'Loading active physical assets...',
            color: BafColors.assets,
            showProgress: true,
          ),
      error:
          (error, stackTrace) => const _AssetSelectionMessage(
            icon: Icons.error_outline_rounded,
            message: 'Physical assets could not be loaded. Sync and try again.',
            color: BafColors.danger,
          ),
      data: (allAssets) {
        final assets = eligibleIssueAssets(route: route, assets: allAssets);
        final selectedAsset = _findAsset(assets, _selectedAssetInstanceId);
        if (assets.isEmpty) {
          return _AssetSelectionMessage(
            icon: Icons.precision_manufacturing_outlined,
            message:
                'No active ${physicalClass.name} assets are registered for this selection.',
            color: BafColors.warning,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(
                'abnormality-asset-${physicalClass.id}-${selectedAsset?.id ?? 'none'}-${assets.length}',
              ),
              initialValue: selectedAsset?.id,
              isExpanded: true,
              decoration: _inputDecoration(
                label:
                    route.innerCoverByBase
                        ? 'Base carrying Inner Cover'
                        : 'Registered asset',
              ),
              items:
                  assets
                      .map(
                        (asset) => DropdownMenuItem(
                          value: asset.id,
                          child: Text(
                            _registeredAssetLabel(asset),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (assetId) {
                setState(() {
                  _selectedAssetInstanceId = assetId;
                  _pendingTargetReference = null;
                  _assetSelectionError = null;
                });
              },
            ),
            if (selectedAsset != null) ...[
              const SizedBox(height: BafSpacing.sm),
              if (_pendingTargetReference != null)
                _PendingHierarchyTarget(
                  reference: _pendingTargetReference!,
                  onClear: () => setState(() => _pendingTargetReference = null),
                )
              else
                const _FormNotice(
                  icon: Icons.account_tree_outlined,
                  message:
                      'No component selected. You may add the whole asset, or choose a governed component first.',
                  color: BafColors.textSecondary,
                ),
              const SizedBox(height: BafSpacing.sm),
              OutlinedButton.icon(
                onPressed: _addingAsset ? null : _chooseGovernedComponent,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(
                  _pendingTargetReference == null
                      ? 'Choose component or subcomponent'
                      : 'Change component or subcomponent',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.assets,
                  foregroundColor: Colors.white,
                ),
                onPressed: _addingAsset ? null : _addAffectedAsset,
                icon:
                    _addingAsset
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.add_rounded),
                label: const Text('Add affected equipment'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _chooseGovernedComponent() async {
    final selectionContext = _currentAssetSelection();
    if (selectionContext == null) {
      setState(() {
        _assetSelectionError =
            'Choose an active registered asset before selecting its component.';
      });
      return;
    }
    try {
      final nodes =
          await ref
              .read(assetHierarchyRepositoryProvider)
              .watchNodes(selectionContext.route.issueClass.id)
              .first;
      if (!mounted) return;
      final selection = await showGovernedAssetTargetPicker(
        context: context,
        asset: selectionContext.asset,
        nodes: nodes,
        selectedNodeId: _pendingTargetReference?.nodeId,
        definitionAssetClassId: selectionContext.route.issueClass.id,
      );
      if (!mounted || selection?.reference == null) return;
      setState(() {
        _pendingTargetReference = selection!.reference;
        _assetSelectionError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _assetSelectionError =
            error is AssetHierarchyException
                ? '$error'
                : 'The component hierarchy could not be loaded. Sync and try again.';
      });
    }
  }

  Future<void> _addAffectedAsset() async {
    if (_addingAsset) return;
    if (_affectedAssets.length >= 50) {
      setState(() {
        _assetSelectionError =
            'A charge abnormality can identify at most 50 affected assets.';
      });
      return;
    }
    final selectionContext = _currentAssetSelection();
    if (selectionContext == null) {
      setState(() {
        _assetSelectionError = 'Choose an active registered asset first.';
      });
      return;
    }
    final duplicate = _affectedAssets.any(
      (item) =>
          item.assetType == selectionContext.route.assetType &&
          item.assetNumber == selectionContext.asset.assetNumber,
    );
    if (duplicate) {
      setState(() {
        _assetSelectionError =
            'This asset is already included. Remove it before selecting a different component.';
      });
      return;
    }
    setState(() {
      _addingAsset = true;
      _assetSelectionError = null;
    });
    try {
      final actor = ref.read(currentAppUserProvider).value;
      if (actor == null) {
        throw StateError('The reporting user could not be verified.');
      }
      final confirmedAt = DateTime.now();
      final selectedReference =
          _pendingTargetReference ?? selectionContext.asset.toReference();
      final reference = await _freezeInnerCoverContext(
        route: selectionContext.route,
        asset: selectionContext.asset,
        selectedReference: selectedReference,
        eventAt: _eventAt,
        confirmedAt: confirmedAt,
        historicalCorrection: widget.existing != null,
        reporterUid: actor.uid,
        reporterName: actor.name,
      );
      if (!mounted) return;
      setState(() {
        _affectedAssets.add(
          AffectedAssetRef(
            assetType: selectionContext.route.assetType,
            assetNumber: selectionContext.asset.assetNumber,
            assetHierarchyReference: reference,
          ),
        );
        if (reference.scope != AssetHierarchyReferenceScope.physicalAsset) {
          _legacyComponent = null;
        }
        if (_selectedRootReason == RootReasonCategory.unknown) {
          _selectedRootReason = _rootReasonForAssetType(
            selectionContext.route.assetType,
          );
        }
        _selectedAssetInstanceId = null;
        _pendingTargetReference = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _assetSelectionError =
            error is AssetHierarchyException
                ? '$error'
                : 'The governed equipment selection could not be confirmed. Sync and try again.';
      });
    } finally {
      if (mounted) setState(() => _addingAsset = false);
    }
  }

  _SelectedAbnormalityAsset? _currentAssetSelection() {
    final classes = ref.read(assetClassesProvider).value;
    final classId = _selectedAssetClassId;
    if (classes == null || classId == null) return null;
    final selectedClass = _findAssetClass(classes, classId);
    if (selectedClass == null) return null;
    final route = resolveGovernedIssueAssetRoute(
      issueClass: selectedClass,
      allClasses: classes,
    );
    final physicalClass = route.physicalAssetClass;
    final assetId = _selectedAssetInstanceId;
    if (!route.isAvailable || physicalClass == null || assetId == null) {
      return null;
    }
    final assets = ref.read(assetInstancesProvider(physicalClass.id)).value;
    final asset = _findAsset(assets ?? const <AssetInstanceRecord>[], assetId);
    if (asset == null || !asset.isActive) return null;
    return _SelectedAbnormalityAsset(route: route, asset: asset);
  }

  Future<AssetHierarchyReference> _freezeInnerCoverContext({
    required GovernedIssueAssetRoute route,
    required AssetInstanceRecord asset,
    required AssetHierarchyReference selectedReference,
    required DateTime eventAt,
    required DateTime confirmedAt,
    required bool historicalCorrection,
    required String reporterUid,
    required String reporterName,
  }) async {
    final assetType = route.assetType;
    if (assetType != AssetType.base && assetType != AssetType.innerCover) {
      return selectedReference;
    }
    final eventContext = await ref
        .read(assetHierarchyRepositoryProvider)
        .resolveGovernedAssetEventContext(
          legacyAssetTypeKey: AssetType.base.name,
          assetNumber: asset.assetNumber,
        );
    if (eventContext == null) {
      if (assetType == AssetType.innerCover) {
        throw const AssetHierarchyException(
          'This Base is unavailable in the governed register. Reconcile it before logging an Inner Cover abnormality.',
        );
      }
      return selectedReference;
    }
    if (selectedReference.assetInstanceId != eventContext.asset.id) {
      throw const AssetHierarchyException(
        'The selected component and physical Base do not match.',
      );
    }
    final assignment = eventContext.innerCoverAssignment;
    if (historicalCorrection &&
        (assignment == null || eventAt.isBefore(assignment.linkedAt))) {
      if (assetType == AssetType.innerCover) {
        throw const AssetHierarchyException(
          'The current Inner Cover linkage does not establish which cover occupied this Base at the original event time. Retain the recorded reference or reconcile the linkage history first.',
        );
      }
      // A current vacancy or later linkage cannot prove the Base position at
      // an older event. Preserve the physical/component identity without
      // inventing Inner Cover evidence.
      return selectedReference;
    }
    if (assetType == AssetType.innerCover && assignment == null) {
      throw const AssetHierarchyException(
        'No Inner Cover is linked to this Base. Correct the linkage before logging an Inner Cover abnormality.',
      );
    }
    if (assignment != null && eventAt.isBefore(assignment.linkedAt)) {
      throw const AssetHierarchyException(
        'The abnormality event predates the current Inner Cover linkage. Restart after reconciling the Base linkage history.',
      );
    }
    final association = InnerCoverEventReference(
      baseAssetInstanceId: eventContext.asset.id,
      baseAssetNumber: eventContext.asset.assetNumber,
      positionState:
          assignment == null
              ? InnerCoverPositionState.noneLinked
              : InnerCoverPositionState.linked,
      innerCoverId: assignment?.innerCoverId,
      innerCoverSerialNumber: assignment?.innerCoverSerialNumber,
      linkageId: assignment?.linkageId,
      assignmentVersion: assignment?.version,
      linkedAt: assignment?.linkedAt,
      eventAt: eventAt,
      confirmedAt: confirmedAt,
      confirmedByUid: reporterUid,
      confirmedByName: reporterName,
    );
    return _copyReferenceWithAssociation(selectedReference, association);
  }

  void _removeAffectedAsset(AffectedAssetRef asset) {
    setState(() {
      _affectedAssets.removeWhere(
        (candidate) =>
            candidate.assetType == asset.assetType &&
            candidate.assetNumber == asset.assetNumber,
      );
      _assetSelectionError = null;
    });
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_affectedAssets.isEmpty) {
      setState(() {
        _assetSelectionError =
            'Add at least one governed affected asset before logging.';
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
    final incompatible =
        _affectedAssets
            .where(
              (asset) =>
                  !isAffectedAssetPermittedForCorrection(
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

    Navigator.pop(
      context,
      _ChargeAbnormalityDraft(
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
        correctionReason:
            widget.existing == null
                ? null
                : _correctionReasonController.text.trim(),
      ),
    );
  }
}
