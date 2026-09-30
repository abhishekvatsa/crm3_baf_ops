part of 'charge_abnormalities_screen.dart';

// Equipment composition and confirmation are shared by Add and final Log.
extension on _ChargeAbnormalityFormDialogState {
  Widget _buildAffectedEquipmentComposer() {
    final classesValue = ref.watch(assetClassesProvider);
    return classesValue.when(
      loading: () => const _AssetSelectionMessage(
        icon: Icons.sync_rounded,
        message: 'Loading the governed asset register...',
        color: BafColors.assets,
        showProgress: true,
      ),
      error: (error, stackTrace) => const _AssetSelectionMessage(
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
        final selectedClass = _findAssetClass(classes, _selectedAssetClassId);
        final route = selectedClass == null
            ? null
            : resolveGovernedIssueAssetRoute(
                issueClass: selectedClass,
                allClasses: allClasses,
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (classes.isEmpty)
              const _AssetSelectionMessage(
                icon: Icons.inventory_2_outlined,
                message:
                    'No active registered asset class applies to this abnormality type.',
                color: BafColors.warning,
              ),
            LiveDropdownFormField<String>(
              key: const ValueKey('abnormality-asset-class'),
              initialValue: selectedClass?.id,
              decoration: _inputDecoration(label: 'Asset class'),
              items: classes
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
                _updateEquipment(() {
                  _selectedAssetClassId = classId;
                  _assetChoiceInvalid = false;
                  _selectedAssetInstanceId = null;
                  _pendingTargetReference = null;
                  _assetSelectionError = null;
                });
              },
              onInvalidSelection: () => _updateEquipment(() {
                _assetChoiceInvalid = true;
                _assetSelectionError =
                    'That asset class is no longer available. Choose a current registered class.';
              }),
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
      loading: () => const _AssetSelectionMessage(
        icon: Icons.sync_rounded,
        message: 'Loading active physical assets...',
        color: BafColors.assets,
        showProgress: true,
      ),
      error: (error, stackTrace) => const _AssetSelectionMessage(
        icon: Icons.error_outline_rounded,
        message: 'Physical assets could not be loaded. Sync and try again.',
        color: BafColors.danger,
      ),
      data: (allAssets) {
        final assets = eligibleIssueAssets(route: route, assets: allAssets);
        final selectedAsset = _findAsset(assets, _selectedAssetInstanceId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (assets.isEmpty)
              _AssetSelectionMessage(
                icon: Icons.precision_manufacturing_outlined,
                message:
                    'No active ${physicalClass.name} assets are registered for this selection.',
                color: BafColors.warning,
              ),
            LiveDropdownFormField<String>(
              key: ValueKey('abnormality-asset-${physicalClass.id}'),
              initialValue: selectedAsset?.id,
              decoration: _inputDecoration(
                label: route.innerCoverByBase
                    ? 'Base carrying Inner Cover'
                    : 'Registered asset',
              ),
              items: assets
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
                _updateEquipment(() {
                  _assetChoiceInvalid = false;
                  _selectedAssetInstanceId = assetId;
                  _pendingTargetReference = null;
                  _assetSelectionError = null;
                });
              },
              onInvalidSelection: () => _updateEquipment(() {
                _assetChoiceInvalid = true;
                _assetSelectionError =
                    'That asset is no longer available. Choose an active registered asset.';
              }),
            ),
            if (selectedAsset != null) ...[
              const SizedBox(height: BafSpacing.sm),
              if (_pendingTargetReference != null)
                _PendingHierarchyTarget(
                  reference: _pendingTargetReference!,
                  onClear: () =>
                      _updateEquipment(() => _pendingTargetReference = null),
                )
              else
                const _FormNotice(
                  icon: Icons.account_tree_outlined,
                  message:
                      'No component selected. Log abnormality will include the whole asset, or you can choose a component first.',
                  color: BafColors.textSecondary,
                ),
              const SizedBox(height: BafSpacing.sm),
              OutlinedButton.icon(
                onPressed: _equipmentBusy ? null : _chooseGovernedComponent,
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
                onPressed: _equipmentBusy ? null : _addAffectedAsset,
                icon: _addingAsset
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
    if (_equipmentBusy || !_formActive || !_actorCanSubmit) return;
    final selectionContext = _currentAssetSelection();
    if (selectionContext == null) {
      _updateEquipment(() {
        _assetSelectionError =
            'Choose an active registered asset before selecting its component.';
      });
      return;
    }
    _updateEquipment(() => _choosingComponent = true);
    try {
      final nodes = await ref
          .read(assetHierarchyRepositoryProvider)
          .watchNodes(selectionContext.route.issueClass.id)
          .first;
      if (!mounted || !_formActive || !_actorCanSubmit) return;
      if (!_sameSelection(selectionContext, _currentAssetSelection())) {
        throw const AssetHierarchyException(
          'The equipment selection changed. Choose it again before continuing.',
        );
      }
      final selection = await showGovernedAssetTargetPicker(
        context: context,
        asset: selectionContext.asset,
        nodes: nodes,
        selectedNodeId: _pendingTargetReference?.nodeId,
        definitionAssetClassId: selectionContext.route.issueClass.id,
      );
      if (!_formActive || !_actorCanSubmit || selection?.reference == null) {
        return;
      }
      if (!_sameSelection(selectionContext, _currentAssetSelection())) {
        throw const AssetHierarchyException(
          'The equipment selection changed. Choose it again before continuing.',
        );
      }
      _updateEquipment(() {
        _pendingTargetReference = selection!.reference;
        _assetSelectionError = null;
      });
    } on Object catch (error) {
      if (!_formActive) return;
      _updateEquipment(() {
        _assetSelectionError = error is AssetHierarchyException
            ? '$error'
            : 'The component hierarchy could not be loaded. Sync and try again.';
      });
    } finally {
      if (mounted) _updateEquipment(() => _choosingComponent = false);
    }
  }

  Future<bool> _addAffectedAsset() async {
    if (_addingAsset ||
        _choosingComponent ||
        !_formActive ||
        !_actorCanSubmit) {
      return false;
    }
    if (_affectedAssets.length >= 50) {
      _updateEquipment(() {
        _assetSelectionError =
            'A charge abnormality can identify at most 50 affected assets.';
      });
      return false;
    }
    final selectionContext = _currentAssetSelection();
    if (selectionContext == null) {
      _updateEquipment(() {
        _assetSelectionError = 'Choose an active registered asset first.';
      });
      return false;
    }
    final duplicate = _affectedAssets.any(
      (item) =>
          item.assetType == selectionContext.route.assetType &&
          item.assetNumber == selectionContext.asset.assetNumber,
    );
    if (duplicate) {
      _updateEquipment(() {
        _assetSelectionError =
            'This asset is already included. Remove it before selecting a different component.';
      });
      return false;
    }
    final pendingReference = _pendingTargetReference;
    final selectedType = _selectedType;
    _updateEquipment(() {
      _addingAsset = true;
      _assetSelectionError = null;
    });
    try {
      final actor = CurrentActorAccess.resolve(
        ref.read(currentAppUserProvider),
      ).actor;
      if (actor == null || actor.uid != widget.originUid) {
        throw StateError('The reporting user could not be verified.');
      }
      final confirmedAt = DateTime.now();
      final selectedReference =
          _pendingTargetReference ?? selectionContext.asset.toReference();
      if (selectedReference.assetInstanceId != selectionContext.asset.id ||
          selectedReference.assetInstanceVersion !=
              selectionContext.asset.version ||
          selectedReference.assetNumber != selectionContext.asset.assetNumber) {
        throw const AssetHierarchyException(
          'The component no longer matches the registered asset. Choose the component again.',
        );
      }
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
      if (!_formActive || !_actorCanSubmit) return false;
      if (_assetChoiceInvalid ||
          selectedType != _selectedType ||
          !identical(pendingReference, _pendingTargetReference) ||
          !_sameSelection(selectionContext, _currentAssetSelection())) {
        throw const AssetHierarchyException(
          'The equipment selection changed. Choose it again before continuing.',
        );
      }
      _updateEquipment(() {
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
        _assetChoiceInvalid = false;
        _selectedAssetInstanceId = null;
        _pendingTargetReference = null;
      });
      return true;
    } on Object catch (error) {
      if (!_formActive) return false;
      _updateEquipment(() {
        _assetSelectionError = error is AssetHierarchyException
            ? '$error'
            : 'The governed equipment selection could not be confirmed. Sync and try again.';
      });
      return false;
    } finally {
      if (mounted) _updateEquipment(() => _addingAsset = false);
    }
  }

  _SelectedAbnormalityAsset? _currentAssetSelection() {
    final classes = ref.read(assetClassesProvider).asData?.value;
    final classId = _selectedAssetClassId;
    if (classes == null || classId == null) return null;
    final selectedClass = _findAssetClass(classes, classId);
    if (selectedClass == null) return null;
    final route = resolveGovernedIssueAssetRoute(
      issueClass: selectedClass,
      allClasses: classes,
    );
    if (_selectedType.applicableAssetTypes.isNotEmpty &&
        !_selectedType.applicableAssetTypes.contains(route.assetType)) {
      return null;
    }
    final physicalClass = route.physicalAssetClass;
    final assetId = _selectedAssetInstanceId;
    if (!route.isAvailable || physicalClass == null || assetId == null) {
      return null;
    }
    final assets = ref
        .read(assetInstancesProvider(physicalClass.id))
        .asData
        ?.value;
    if (assets == null) return null;
    final asset = _findAsset(
      eligibleIssueAssets(route: route, assets: assets),
      assetId,
    );
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
      positionState: assignment == null
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
    _updateEquipment(() {
      _affectedAssets.removeWhere(
        (candidate) =>
            candidate.assetType == asset.assetType &&
            candidate.assetNumber == asset.assetNumber,
      );
      _assetSelectionError = null;
    });
  }

  bool _sameSelection(
    _SelectedAbnormalityAsset before,
    _SelectedAbnormalityAsset? current,
  ) =>
      current != null &&
      before.route.issueClass.id == current.route.issueClass.id &&
      before.route.issueClass.version == current.route.issueClass.version &&
      before.route.assetType == current.route.assetType &&
      before.route.physicalAssetClass?.id ==
          current.route.physicalAssetClass?.id &&
      before.route.physicalAssetClass?.version ==
          current.route.physicalAssetClass?.version &&
      before.asset.id == current.asset.id &&
      before.asset.version == current.asset.version &&
      before.asset.assetNumber == current.asset.assetNumber;
}
