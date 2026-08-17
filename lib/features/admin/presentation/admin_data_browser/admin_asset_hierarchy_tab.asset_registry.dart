part of 'admin_asset_hierarchy_tab.dart';

class _PhysicalAssetRegistry extends ConsumerStatefulWidget {
  final AssetClassRecord assetClass;
  final AppUser actor;

  const _PhysicalAssetRegistry({required this.assetClass, required this.actor});

  @override
  ConsumerState<_PhysicalAssetRegistry> createState() =>
      _PhysicalAssetRegistryState();
}

class _PhysicalAssetRegistryState
    extends ConsumerState<_PhysicalAssetRegistry> {
  String? _selectedAssetId;
  bool _showRetired = false;
  bool _busy = false;

  AssetHierarchyRepository get _repository =>
      ref.read(assetHierarchyRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetInstancesProvider(widget.assetClass.id));
    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => _LoadFailure(
            message: 'Physical assets could not be loaded: $error',
            onRetry:
                () => ref.invalidate(
                  assetInstancesProvider(widget.assetClass.id),
                ),
          ),
      data: (assets) {
        final visible =
            _showRetired
                ? assets
                : assets.where((asset) => asset.isActive).toList();
        final selected = assets.cast<AssetInstanceRecord?>().firstWhere(
          (asset) => asset?.id == _selectedAssetId,
          orElse: () => visible.isEmpty ? null : visible.first,
        );
        if (selected != null && selected.id != _selectedAssetId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedAssetId = selected.id);
          });
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = Text(
                    '${visible.length} physical assets',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: BafColors.textSecondary,
                    ),
                  );
                  final controls = <Widget>[
                    FilterChip(
                      selected: _showRetired,
                      onSelected:
                          (value) => setState(() => _showRetired = value),
                      label: Text(
                        'Retired ${assets.where((asset) => !asset.isActive).length}',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _busy || !widget.assetClass.isActive
                              ? null
                              : _createAsset,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Physical asset'),
                    ),
                  ];
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        count,
                        const SizedBox(height: BafSpacing.sm),
                        Wrap(
                          spacing: 10,
                          runSpacing: BafSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: controls,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      count,
                      const Spacer(),
                      controls.first,
                      const SizedBox(width: 10),
                      controls.last,
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonFormField<String>(
                            initialValue: selected?.id,
                            decoration: const InputDecoration(
                              labelText: 'Physical asset',
                              border: OutlineInputBorder(),
                            ),
                            isExpanded: true,
                            items:
                                visible
                                    .map(
                                      (asset) => DropdownMenuItem(
                                        value: asset.id,
                                        child: Text(
                                          '${asset.name} · ${asset.assetNumber}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) =>
                                    setState(() => _selectedAssetId = value),
                          ),
                        ),
                        Expanded(child: _assetDetail(selected)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 265,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 8, 16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final asset = visible[index];
                            return ListTile(
                              selected: asset.id == selected?.id,
                              leading: Icon(
                                Icons.factory_outlined,
                                color:
                                    asset.isActive
                                        ? BafColors.assets
                                        : BafColors.textSecondary,
                              ),
                              title: Text(
                                asset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '#${asset.assetNumber} · ${asset.serviceState.label}',
                              ),
                              onTap:
                                  () => setState(
                                    () => _selectedAssetId = asset.id,
                                  ),
                            );
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _assetDetail(selected)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _assetDetail(AssetInstanceRecord? asset) {
    if (asset == null) {
      return const _EmptyHierarchy(
        icon: Icons.factory_outlined,
        title: 'No physical asset selected',
        message: 'Add an installed furnace, base, inner cover or cooler.',
      );
    }
    return _InstalledComponentList(
      asset: asset,
      busy: _busy,
      onEditAsset: () => _editAsset(asset),
      onToggleAsset: () => _toggleAsset(asset),
      onAddComponent: () => _createComponent(asset),
      onEditComponent: _editComponent,
      onReplaceComponent: (component) => _replaceComponent(asset, component),
      onHistoryComponent:
          (component) => _showComponentHistory(asset, component),
      onToggleComponent: _toggleComponent,
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.success),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTagAware(
    Future<void> Function(String? reviewedOwnerComponentId) action,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      await action(null);
    } on AssetTagCollisionException catch (collision) {
      if (!mounted) return;
      setState(() => _busy = false);
      final transfer = await _confirmTagTransfer(context, collision);
      if (!transfer || !mounted) return;
      setState(() => _busy = true);
      await action(collision.existingComponentInstanceId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.success),
    );
  }

  Future<void> _createAsset() async {
    final result = await showDialog<_AssetInstanceDialogResult>(
      context: context,
      builder: (_) => _AssetInstanceDialog(assetClass: widget.assetClass),
    );
    if (result == null) return;
    String? createdId;
    await _run(() async {
      createdId = await _repository.createAssetInstance(
        assetClass: widget.assetClass,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
      );
    }, 'Physical asset added.');
    if (createdId != null && mounted) {
      setState(() => _selectedAssetId = createdId);
    }
  }

  Future<void> _editAsset(AssetInstanceRecord before) async {
    final result = await showDialog<_AssetInstanceDialogResult>(
      context: context,
      builder:
          (_) => _AssetInstanceDialog(
            assetClass: widget.assetClass,
            existing: before,
          ),
    );
    if (result == null) return;
    await _run(
      () => _repository.updateAssetInstance(
        before: before,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
      ),
      'Physical asset updated.',
    );
  }

  Future<void> _toggleAsset(AssetInstanceRecord before) async {
    final reason = await _reasonDialog(
      context,
      title:
          before.isActive ? 'Retire physical asset' : 'Restore physical asset',
      message:
          before.isActive
              ? 'Installed components must be retired first. Historical work remains linked.'
              : 'Restoring makes this physical asset available for new work.',
    );
    if (reason == null) return;
    await _run(
      () => _repository.setAssetInstanceStatus(
        before: before,
        status:
            before.isActive
                ? AssetHierarchyStatus.retired
                : AssetHierarchyStatus.active,
        actor: widget.actor,
        reason: reason,
      ),
      before.isActive ? 'Physical asset retired.' : 'Physical asset restored.',
    );
  }

  Future<void> _createComponent(AssetInstanceRecord asset) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(asset.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final result = await showDialog<_InstalledComponentDialogResult>(
      context: context,
      builder:
          (_) => _InstalledComponentDialog(
            definitions:
                nodes
                    .where(
                      (node) =>
                          node.isActive &&
                          (node.nodeType == AssetHierarchyNodeType.component ||
                              node.nodeType ==
                                  AssetHierarchyNodeType.subcomponent),
                    )
                    .toList(),
          ),
    );
    if (result == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.createInstalledComponent(
        asset: asset,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      'Installed component added.',
    );
  }

  Future<void> _editComponent(InstalledComponentRecord before) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(before.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final result = await showDialog<_InstalledComponentDialogResult>(
      context: context,
      builder:
          (_) => _InstalledComponentDialog(
            existing: before,
            definitions: nodes.where((node) => node.isActive).toList(),
          ),
    );
    if (result == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.updateInstalledComponent(
        before: before,
        draft: result.draft,
        actor: widget.actor,
        reason: result.reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      'Installed component updated.',
    );
  }

  Future<void> _replaceComponent(
    AssetInstanceRecord asset,
    InstalledComponentRecord before,
  ) async {
    final nodes =
        ref.read(assetHierarchyNodesProvider(before.assetClassId)).value ??
        const <AssetHierarchyNode>[];
    final definitions =
        nodes.where((node) => node.id == before.definitionNodeId).toList();
    if (definitions.length != 1 || !definitions.single.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The governed component definition is unavailable. Restore or reconcile it before replacement.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    final evidenceOptions = await _replacementEvidenceOptions(asset, before);
    if (!mounted) return;
    final result = await showDialog<_InstalledComponentDialogResult>(
      context: context,
      builder:
          (_) => _InstalledComponentDialog(
            replacementFor: before,
            definitions: definitions,
            evidenceOptions: evidenceOptions,
          ),
    );
    if (result == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.replaceInstalledComponent(
        asset: asset,
        before: before,
        replacement: result.draft,
        actor: widget.actor,
        reason: result.reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
        evidenceReference: result.evidenceReference,
      ),
      'Component replaced and lifecycle history recorded.',
    );
  }

  Future<List<_ReplacementEvidenceOption>> _replacementEvidenceOptions(
    AssetInstanceRecord asset,
    InstalledComponentRecord component,
  ) async {
    try {
      final ticketsFuture = ref.read(adminTicketsStreamProvider.future);
      final executionsFuture = ref.read(adminExecutionsStreamProvider.future);
      final tickets = await ticketsFuture;
      final executions = await executionsFuture;
      final options = <_ReplacementEvidenceOption>[];
      for (final ticket in tickets) {
        final id = ticket.firestoreId;
        AssetHierarchyReference? hierarchy;
        try {
          hierarchy = ticket.assetHierarchyReference;
        } on Object {
          continue;
        }
        if (id == null ||
            ticket.isDeleted ||
            !ticket.isResolved ||
            ticket.status != TicketStatus.resolved ||
            ticket.endDate == null ||
            !_replacementReferenceMatches(hierarchy, asset, component)) {
          continue;
        }
        options.add(
          _ReplacementEvidenceOption(
            reference: ComponentReplacementEvidenceReference(
              sourceType: ComponentReplacementEvidenceSource.maintenanceIssue,
              sourceId: id,
              expectedVersion: ticket.version,
            ),
            title: 'Resolved issue · ${ticket.description}',
            subtitle:
                '${DateFormat('dd MMM yyyy').format(ticket.endDate!.toLocal())} · ${ticket.closedByName ?? 'Recorded closure'}',
            completedAt: ticket.endDate!,
          ),
        );
      }
      for (final execution in executions) {
        final id = execution.firestoreId;
        AssignmentPhysicalAssetIdentity? identity;
        AssetHierarchyReference? hierarchy;
        try {
          identity = execution.assignmentPhysicalAssetIdentity;
          hierarchy = execution.assignmentAssetHierarchyReference;
        } on Object {
          continue;
        }
        if (id == null ||
            execution.isDeleted ||
            !execution.isCompleted ||
            execution.isCancelled ||
            execution.completedAt == null ||
            identity == null ||
            identity.assetClassId != asset.assetClassId ||
            identity.assetInstanceId != asset.id ||
            identity.assetNumber != asset.assetNumber) {
          continue;
        }
        if (hierarchy != null &&
            (hierarchy.scope == AssetHierarchyReferenceScope.physicalAsset ||
                hierarchy.scope ==
                    AssetHierarchyReferenceScope.installedComponent) &&
            !_replacementReferenceMatches(hierarchy, asset, component)) {
          continue;
        }
        options.add(
          _ReplacementEvidenceOption(
            reference: ComponentReplacementEvidenceReference(
              sourceType: ComponentReplacementEvidenceSource.plannedJob,
              sourceId: id,
              expectedVersion: execution.version,
            ),
            title:
                'Completed planned work · ${execution.templateName ?? 'Job $id'}',
            subtitle:
                '${DateFormat('dd MMM yyyy').format(execution.completedAt!.toLocal())} · ${execution.completedByName ?? 'Recorded completion'}',
            completedAt: execution.completedAt!,
          ),
        );
      }
      options.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return options;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Closed-work evidence is unavailable. You can still record a governed manual replacement.',
            ),
          ),
        );
      }
      return const <_ReplacementEvidenceOption>[];
    }
  }

  bool _replacementReferenceMatches(
    AssetHierarchyReference? reference,
    AssetInstanceRecord asset,
    InstalledComponentRecord component,
  ) {
    if (reference == null ||
        reference.scope == AssetHierarchyReferenceScope.definition ||
        reference.assetClassId != asset.assetClassId ||
        reference.assetInstanceId != asset.id ||
        reference.assetNumber != asset.assetNumber) {
      return false;
    }
    return reference.scope != AssetHierarchyReferenceScope.installedComponent ||
        reference.componentInstanceId == component.id;
  }

  Future<void> _showComponentHistory(
    AssetInstanceRecord asset,
    InstalledComponentRecord component,
  ) => showDialog<void>(
    context: context,
    builder:
        (_) => _InstalledComponentHistoryDialog(
          asset: asset,
          component: component,
        ),
  );

  Future<void> _toggleComponent(InstalledComponentRecord before) async {
    final reason = await _reasonDialog(
      context,
      title:
          before.isActive
              ? 'Retire installed component'
              : 'Restore installed component',
      message:
          before.isActive
              ? 'The tag is released, while historical work retains its component snapshot.'
              : 'Restoring reclaims its tag; a collision will require explicit transfer.',
    );
    if (reason == null) return;
    await _runTagAware(
      (reviewedOwnerComponentId) => _repository.setInstalledComponentStatus(
        before: before,
        status:
            before.isActive
                ? AssetHierarchyStatus.retired
                : AssetHierarchyStatus.active,
        actor: widget.actor,
        reason: reason,
        allowTagTransfer: reviewedOwnerComponentId != null,
        expectedTagOwnerComponentId: reviewedOwnerComponentId,
      ),
      before.isActive
          ? 'Installed component retired.'
          : 'Installed component restored.',
    );
  }
}
