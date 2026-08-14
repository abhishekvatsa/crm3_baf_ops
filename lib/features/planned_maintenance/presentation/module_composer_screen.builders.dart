part of 'module_composer_screen.dart';

extension _ModuleComposerBuilders on _ModuleComposerScreenState {
  List<Widget> _buildAppBarActions({
    required BuildContext context,
    required ModuleComposerValidationResult validation,
    required bool canManageRegistry,
    required bool canPreparePublish,
  }) {
    // Keep the composer AppBar compact on all surfaces. The composer has grown
    // into a module-first authoring hub, so secondary actions live in a single
    // overflow menu rather than competing for toolbar width on phones/tablets.
    return [
      PopupMenuButton<_ComposerAppBarAction>(
        tooltip: 'More composer actions',
        onSelected: (action) => _handleAppBarAction(action, validation),
        itemBuilder:
            (context) => [
              if (canPreparePublish)
                const PopupMenuItem(
                  value: _ComposerAppBarAction.openSavedTemplateDrafts,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.history_rounded),
                    title: Text('Manage Template Drafts'),
                  ),
                ),
              const PopupMenuItem(
                value: _ComposerAppBarAction.openWorkshop,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.dashboard_customize_rounded),
                  title: Text('Open Module Workshop'),
                ),
              ),
              if (canManageRegistry)
                const PopupMenuItem(
                  value: _ComposerAppBarAction.openRegistryAuthoring,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.workspace_premium_rounded),
                    title: Text('Open Registry Authoring'),
                  ),
                ),
              if (canPreparePublish)
                PopupMenuItem(
                  value: _ComposerAppBarAction.preparePublish,
                  enabled: validation.canSave,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.fact_check_rounded),
                    title: Text('Prepare Publish'),
                  ),
                ),
              PopupMenuItem(
                value: _ComposerAppBarAction.toggleJsonPreview,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.data_object_rounded),
                  title: Text(
                    _showJsonPreview ? 'Hide JSON preview' : 'Preview JSON',
                  ),
                ),
              ),
              if (widget.showSaveToPublisher)
                PopupMenuItem(
                  value: _ComposerAppBarAction.saveToPublisher,
                  enabled: validation.canSave,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.send_rounded),
                    title: Text('Save to Publisher'),
                  ),
                ),
            ],
      ),
      const SizedBox(width: BafSpacing.xs),
    ];
  }

  void _handleAppBarAction(
    _ComposerAppBarAction action,
    ModuleComposerValidationResult validation,
  ) {
    switch (action) {
      case _ComposerAppBarAction.openSavedTemplateDrafts:
        _openSavedTemplateDrafts();
        break;
      case _ComposerAppBarAction.openWorkshop:
        _openModuleWorkshop();
        break;
      case _ComposerAppBarAction.openRegistryAuthoring:
        _openRegistryAuthoring();
        break;
      case _ComposerAppBarAction.preparePublish:
        if (validation.canSave) {
          _openPublishMetadataDialog();
        }
        break;
      case _ComposerAppBarAction.toggleJsonPreview:
        setState(() => _showJsonPreview = !_showJsonPreview);
        break;
      case _ComposerAppBarAction.saveToPublisher:
        if (validation.canSave) {
          _saveToPublisher();
        }
        break;
    }
  }

  Widget _buildLeftRail(ModuleComposerValidationResult validation) {
    return Container(
      color: BafColors.background,
      child: ListView(
        padding: const EdgeInsets.all(BafSpacing.md),
        children: [
          _buildHeaderCard(validation),
          const SizedBox(height: BafSpacing.md),
          _buildModuleList(),
          const SizedBox(height: BafSpacing.md),
          _buildKnowledgePicker(),
          const SizedBox(height: BafSpacing.md),
          _buildSeedClonePicker(),
        ],
      ),
    );
  }

  Widget _buildRightRail(
    ModuleComposerValidationResult validation, {
    bool embedded = false,
  }) {
    final children = [
      _buildValidationCard(validation),
      const SizedBox(height: BafSpacing.md),
      _buildTagResolverCard(),
      if (_showJsonPreview) ...[
        const SizedBox(height: BafSpacing.md),
        _buildJsonPreviewCard(),
      ],
    ];
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Container(
      color: BafColors.background,
      child: ListView(
        padding: const EdgeInsets.all(BafSpacing.md),
        children: children,
      ),
    );
  }

  Widget _buildHeaderCard(ModuleComposerValidationResult validation) {
    final errorColor =
        validation.errors.isNotEmpty ? BafColors.danger : BafColors.success;
    return _ComposerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BafColors.planned.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: BafColors.planned,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              const Expanded(
                child: Text(
                  'Intelligent Module Composer',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'Build governed TemplateVersion JSON from the full BAF Knowledge Matrix, seed/manual presets, field definitions, tag context and safety review.',
            style: TextStyle(color: BafColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: '${_knowledgeRows.length} knowledge rows',
                color: BafColors.admin,
              ),
              _MiniBadge(
                label: _matrixMeta.source,
                color:
                    _matrixMeta.isStaticFallback
                        ? BafColors.warning
                        : BafColors.sync,
              ),
              _MiniBadge(
                label: '${_draft.modules.length} modules',
                color: BafColors.planned,
              ),
              if (_editingTemplateVersion != null)
                _MiniBadge(
                  label:
                      'Editing saved v${_editingTemplateVersion!.versionNumber}',
                  color: BafColors.sync,
                ),
              _MiniBadge(
                label: '${validation.errors.length} errors',
                color: errorColor,
              ),
              _MiniBadge(
                label: '${validation.warnings.length} warnings',
                color: BafColors.warning,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          TextFormField(
            key: const Key('module-composer-template-title'),
            controller: _titleController,
            decoration: _inputDecoration('Template title', Icons.title_rounded),
            onChanged: (value) => setState(() => _draft.title = value),
          ),
          const SizedBox(height: BafSpacing.sm),
          DropdownButtonFormField<AssetType>(
            isExpanded: true,
            initialValue: _draft.assetType,
            decoration: _inputDecoration(
              'Default asset type',
              Icons.precision_manufacturing_rounded,
            ),
            items:
                AssetType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_assetLabel(type)),
                      ),
                    )
                    .toList(),
            onChanged:
                (value) => _setComposerAssetType(value ?? _draft.assetType),
          ),
          if (_draft.assetType == AssetType.governedCustom) ...[
            const SizedBox(height: BafSpacing.sm),
            _buildGovernedHierarchyScope(),
          ],
          CheckboxListTile(
            value: _draft.closureReviewConfirmed,
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Admin/SI closure-critical review confirmed'),
            subtitle: const Text(
              'Required when modules are marked requiredForClosure.',
            ),
            onChanged:
                (value) =>
                    setState(() => _setClosureReviewConfirmed(value ?? false)),
          ),
        ],
      ),
    );
  }

  void _setComposerAssetType(AssetType value) {
    setState(() {
      if (_draft.assetType != value) {
        _draft.assetHierarchyRefJson = null;
        _governedAssetClassId = null;
        _governedDefinitionNodeId = null;
      }
      _draft.assetType = value;
    });
  }

  Widget _buildGovernedHierarchyScope() {
    final classesAsync = ref.watch(assetClassesProvider);
    if (classesAsync.isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    if (classesAsync.hasError) {
      return Text(
        'Governed asset classes are unavailable: ${classesAsync.error}',
        style: const TextStyle(color: BafColors.danger),
      );
    }

    final classes =
        classesAsync.requireValue
            .where((item) => item.isActive && item.legacyAssetTypeKey == null)
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final selectedClass =
        classes.where((item) => item.id == _governedAssetClassId).firstOrNull;
    final nodesAsync =
        selectedClass == null
            ? null
            : ref.watch(assetHierarchyNodesProvider(selectedClass.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('composer-asset-class-${_governedAssetClassId ?? ''}'),
          initialValue: selectedClass?.id,
          isExpanded: true,
          decoration: _inputDecoration(
            'Governed asset class',
            Icons.account_tree_rounded,
          ),
          items:
              classes
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        '${item.code} · ${item.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            setState(() {
              _governedAssetClassId = value;
              _governedDefinitionNodeId = null;
              _draft.assetHierarchyRefJson = null;
            });
          },
        ),
        if (_governedAssetClassId != null && selectedClass == null) ...[
          const SizedBox(height: BafSpacing.xs),
          const Text(
            'The previously selected asset class is no longer active. Select an active class before publishing.',
            style: TextStyle(color: BafColors.danger, fontSize: 12),
          ),
        ],
        if (selectedClass != null) ...[
          const SizedBox(height: BafSpacing.sm),
          if (nodesAsync!.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (nodesAsync.hasError)
            Text(
              'Hierarchy definitions are unavailable: ${nodesAsync.error}',
              style: const TextStyle(color: BafColors.danger),
            )
          else
            _buildGovernedDefinitionSelector(
              selectedClass,
              nodesAsync.requireValue,
            ),
        ],
      ],
    );
  }

  Widget _buildGovernedDefinitionSelector(
    AssetClassRecord assetClass,
    List<AssetHierarchyNode> sourceNodes,
  ) {
    final nodes =
        sourceNodes.where((item) => item.isActive).toList()
          ..sort((left, right) {
            final path = left.hierarchyPath
                .join(' / ')
                .compareTo(right.hierarchyPath.join(' / '));
            return path != 0 ? path : left.name.compareTo(right.name);
          });
    final selectedNode =
        nodes.where((item) => item.id == _governedDefinitionNodeId).firstOrNull;
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'composer-hierarchy-definition-${assetClass.id}-${_governedDefinitionNodeId ?? ''}',
      ),
      initialValue: selectedNode?.id,
      isExpanded: true,
      decoration: _inputDecoration(
        'Hierarchy definition',
        Icons.precision_manufacturing_outlined,
      ),
      items:
          nodes
              .map(
                (node) => DropdownMenuItem<String>(
                  value: node.id,
                  child: Text(
                    node.hierarchyPath.join(' › '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
      onChanged: (value) {
        final node = nodes.where((item) => item.id == value).firstOrNull;
        setState(() {
          _governedDefinitionNodeId = node?.id;
          _draft.assetHierarchyRefJson =
              node == null
                  ? null
                  : AssetHierarchyReference(
                    scope: AssetHierarchyReferenceScope.definition,
                    assetClassId: assetClass.id,
                    assetClassCode: assetClass.code,
                    assetClassName: assetClass.name,
                    nodeId: node.id,
                    nodeVersion: node.version,
                    nodeName: node.name,
                    componentTag: node.componentTag,
                    hierarchyPath: node.hierarchyPath,
                    ownershipStatus: node.ownershipStatus,
                    ownerDiscipline: node.ownerDiscipline,
                    accountableRoleKeys: node.accountableRoleKeys,
                  ).encode();
        });
      },
    );
  }

  Widget _buildModuleList() {
    return _ComposerCard(
      title: 'Modules',
      trailing: IconButton(
        tooltip: 'Add blank module',
        onPressed: _addManualModule,
        icon: const Icon(Icons.add_circle_rounded, color: BafColors.planned),
      ),
      child: Column(
        children: [
          if (_draft.modules.isNotEmpty) _buildMergeSelectionBar(),
          if (_draft.modules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(BafSpacing.md),
              child: Text(
                'No modules yet. Clone from the knowledge matrix or add a manual module.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          for (var i = 0; i < _draft.modules.length; i++)
            _ModuleTile(
              module: _draft.modules[i],
              selected: i == _selectedModuleIndex,
              selectedForMerge: _mergeSelection.contains(i),
              onTap: () => setState(() => _selectedModuleIndex = i),
              onToggleMerge: () => _toggleMergeSelection(i),
              onOpenEditor: () => _openFocusedModuleEditor(i),
              onDuplicate: () => _duplicateModule(i),
              onDelete: () => _removeModule(i),
            ),
        ],
      ),
    );
  }

  Widget _buildMergeSelectionBar() {
    final selectedCount = _mergeSelection.length;
    final canMerge = selectedCount >= 2;
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.planned.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.merge_type_rounded, color: BafColors.planned),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              selectedCount == 0
                  ? 'Select two or more modules to merge into a new draft.'
                  : '$selectedCount module${selectedCount == 1 ? '' : 's'} selected for merge.',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed:
                selectedCount == 0
                    ? null
                    : () => setState(() => _mergeSelection.clear()),
            child: const Text('Clear'),
          ),
          const SizedBox(width: BafSpacing.sm),
          FilledButton.icon(
            onPressed: canMerge ? _mergeSelectedModules : null,
            icon: const Icon(Icons.call_merge_rounded),
            label: const Text('Merge selected'),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgePicker() {
    final allMatches = _searchKnowledgeRows(_knowledgeQuery);
    final rows =
        allMatches
            .where((entry) {
              return _readinessFilter == null ||
                  entry.composerReadiness == _readinessFilter;
            })
            .take(120)
            .toList();

    return _ComposerCard(
      title: 'Knowledge Picker',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingKnowledge) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: BafSpacing.sm),
          ],
          _KnowledgeSourceBanner(
            meta: _matrixMeta,
            onSeedCloud:
                widget.canSeedCloudKnowledge && _hasLiveComposerAuthority()
                    ? _seedCloudKnowledgeBaseline
                    : null,
            isSeeding: _isSeedingCloud,
          ),
          const SizedBox(height: BafSpacing.sm),
          TextField(
            decoration: _inputDecoration(
              'Search asset, tag, task, procedure',
              Icons.search_rounded,
            ),
            onChanged: (value) => setState(() => _knowledgeQuery = value),
          ),
          const SizedBox(height: BafSpacing.sm),
          DropdownButtonFormField<ComposerReadiness?>(
            isExpanded: true,
            initialValue: _readinessFilter,
            decoration: _inputDecoration(
              'Readiness filter',
              Icons.fact_check_rounded,
            ),
            items: [
              const DropdownMenuItem<ComposerReadiness?>(
                value: null,
                child: Text('All readiness states'),
              ),
              ...ComposerReadiness.values.map(
                (value) => DropdownMenuItem<ComposerReadiness?>(
                  value: value,
                  child: Text(_readinessLabel(value)),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _readinessFilter = value),
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            'Showing ${rows.length} of ${allMatches.length} matching rows. ${_matrixMeta.sourceLabel} / ${_matrixMeta.matrixVersion}.',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          for (final entry in rows)
            _KnowledgeTile(
              entry: entry,
              onClone:
                  entry.isCloneable ? () => _cloneKnowledgeEntry(entry) : null,
            ),
        ],
      ),
    );
  }

  Widget _buildSeedClonePicker() {
    final query = _seedQuery.trim().toLowerCase();
    final modules = BafModuleCatalogueSeed.modules
        .where((seed) {
          if (query.isEmpty) {
            return true;
          }
          final haystack =
              [
                seed.moduleCode,
                seed.moduleTitle,
                seed.catalogueArea,
                seed.functionalSection,
                seed.componentGroup,
                seed.defaultDiscipline.name,
                seed.defaultSafetyClass.name,
                seed.defaultUseMode.name,
                ...seed.procedureRefs,
                ...seed.operationalStatePreconditions,
                ...seed.safetyConfirmations,
                ...seed.addAsYouGoTriggers,
              ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .take(60)
        .toList(growable: false);

    return _ComposerCard(
      title: 'Seed Catalogue Clone',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: _inputDecoration(
              'Search seed module/code/component',
              Icons.manage_search_rounded,
            ),
            onChanged: (value) => setState(() => _seedQuery = value),
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            'Showing ${modules.length} of ${BafModuleCatalogueSeed.modules.length} seed modules. Clone creates an editable draft; seed constants are not changed.',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          for (final seed in modules)
            _SeedModuleTile(seed: seed, onClone: () => _cloneSeedModule(seed)),
        ],
      ),
    );
  }

  Widget _buildEditorPane(
    ModuleComposerValidationResult validation, {
    bool embedded = false,
  }) {
    final module = _selectedModule;
    if (module == null) {
      final emptyState = _ComposerCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_add_rounded,
              size: 44,
              color: BafColors.planned,
            ),
            const SizedBox(height: BafSpacing.md),
            const Text(
              'Select or clone a module to begin authoring.',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: BafColors.textPrimary,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            FilledButton.icon(
              onPressed: _addManualModule,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Manual Module'),
            ),
          ],
        ),
      );
      return embedded ? emptyState : Center(child: emptyState);
    }

    final children = [
      _ComposerCard(
        title: 'Module Details',
        trailing: TextButton.icon(
          onPressed: () => _openFocusedModuleEditor(_selectedModuleIndex),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open focused editor'),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: module.moduleCode,
                    decoration: _inputDecoration(
                      'Module code',
                      Icons.tag_rounded,
                    ),
                    onChanged:
                        (value) =>
                            setState(() => module.moduleCode = value.trim()),
                  ),
                ),
                const SizedBox(width: BafSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: module.title,
                    decoration: _inputDecoration('Title', Icons.title_rounded),
                    onChanged: (value) => setState(() => module.title = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              initialValue: module.description,
              minLines: 2,
              maxLines: 4,
              decoration: _inputDecoration(
                'Description / task basis',
                Icons.notes_rounded,
              ),
              onChanged: (value) => setState(() => module.description = value),
            ),
            const SizedBox(height: BafSpacing.md),
            Row(
              children: [
                Expanded(child: _assetDropdown(module)),
                const SizedBox(width: BafSpacing.md),
                Expanded(child: _disciplineDropdown(module)),
                const SizedBox(width: BafSpacing.md),
                Expanded(child: _useModeDropdown(module)),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: module.functionalSection,
                    decoration: _inputDecoration(
                      'Functional section',
                      Icons.account_tree_rounded,
                    ),
                    onChanged:
                        (value) =>
                            setState(() => module.functionalSection = value),
                  ),
                ),
                const SizedBox(width: BafSpacing.md),
                Expanded(
                  child: TextFormField(
                    initialValue: module.componentGroup,
                    decoration: _inputDecoration(
                      'Component group',
                      Icons.category_rounded,
                    ),
                    onChanged:
                        (value) =>
                            setState(() => module.componentGroup = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: module.requiredForClosure,
              title: const Text('Required for closure'),
              subtitle: const Text(
                'Suggested contextually; Admin/SI confirms before publishing.',
              ),
              onChanged:
                  (value) => setState(() {
                    module.requiredForClosure = value ?? false;
                    if (module.requiredForClosure) {
                      _setClosureReviewConfirmed(false);
                    }
                  }),
            ),
          ],
        ),
      ),
      const SizedBox(height: BafSpacing.md),
      _buildOwnershipCard(module),
      const SizedBox(height: BafSpacing.md),
      _buildRefsCard(module),
      const SizedBox(height: BafSpacing.md),
      _buildFieldsCard(module),
      const SizedBox(height: BafSpacing.md),
      _buildChecklistCard(module),
    ];
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(BafSpacing.md),
      children: children,
    );
  }

  Widget _assetDropdown(ComposerModuleDraft module) {
    return DropdownButtonFormField<AssetType>(
      isExpanded: true,
      initialValue: module.assetType,
      decoration: _inputDecoration(
        'Asset type',
        Icons.precision_manufacturing_rounded,
      ),
      items:
          AssetType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(_assetLabel(type)),
                ),
              )
              .toList(),
      onChanged:
          (value) =>
              setState(() => module.assetType = value ?? module.assetType),
    );
  }

  Widget _disciplineDropdown(ComposerModuleDraft module) {
    return DropdownButtonFormField<JobModuleDiscipline>(
      isExpanded: true,
      initialValue: module.discipline,
      decoration: _inputDecoration('Discipline', Icons.groups_rounded),
      items:
          JobModuleDiscipline.values
              .map(
                (discipline) => DropdownMenuItem(
                  value: discipline,
                  child: Text(_disciplineLabel(discipline)),
                ),
              )
              .toList(),
      onChanged:
          (value) => setState(() {
            module.discipline = value ?? module.discipline;
            if (module.discipline == JobModuleDiscipline.shared &&
                module.ownerDisciplines.length < 2) {
              module.requiresJointReview = true;
            }
          }),
    );
  }

  Widget _useModeDropdown(ComposerModuleDraft module) {
    return DropdownButtonFormField<JobModuleUseMode>(
      isExpanded: true,
      initialValue: module.useMode,
      decoration: _inputDecoration('Use mode', Icons.work_history_rounded),
      items:
          JobModuleUseMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(_enumLabel(mode.name)),
                ),
              )
              .toList(),
      onChanged:
          (value) => setState(() => module.useMode = value ?? module.useMode),
    );
  }

  Widget _buildOwnershipCard(ComposerModuleDraft module) {
    const owners = [
      'mechanical',
      'instrumentation',
      'electrical',
      'operations',
      'refractory',
    ];
    return _ComposerCard(
      title: 'Shared ownership and safety',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owner disciplines',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: BafSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final owner in owners)
                FilterChip(
                  label: Text(_enumLabel(owner)),
                  selected: module.ownerDisciplines.contains(owner),
                  onSelected:
                      (selected) => setState(() {
                        if (selected) {
                          module.ownerDisciplines =
                              {...module.ownerDisciplines, owner}.toList()
                                ..sort();
                        } else {
                          module.ownerDisciplines =
                              module.ownerDisciplines
                                  .where((item) => item != owner)
                                  .toList();
                        }
                        module.requiresJointReview =
                            module.ownerDisciplines.length > 1;
                        if (module.ownerDisciplines.length > 1) {
                          module.discipline = JobModuleDiscipline.shared;
                        }
                      }),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: module.requiresJointReview,
            title: const Text('Requires joint review'),
            subtitle: const Text(
              'Shared modules remain supervisor/Admin/SI submission only.',
            ),
            onChanged:
                (value) => setState(() => module.requiresJointReview = value),
          ),
          TextFormField(
            initialValue: module.safetyClasses.join(', '),
            decoration: _inputDecoration(
              'Safety classes',
              Icons.health_and_safety_rounded,
            ),
            onChanged:
                (value) =>
                    setState(() => module.safetyClasses = _splitComma(value)),
          ),
        ],
      ),
    );
  }

  Widget _buildRefsCard(ComposerModuleDraft module) {
    return _ComposerCard(
      title: 'Tags, procedures and target refs',
      child: Column(
        children: [
          TextFormField(
            initialValue: module.deviceTagRefs.join(', '),
            decoration: _inputDecoration('Device tags', Icons.sensors_rounded),
            onChanged:
                (value) => setState(
                  () =>
                      module.deviceTagRefs =
                          _splitComma(
                            value,
                          ).map((tag) => tag.toUpperCase()).toList(),
                ),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            initialValue: module.targetRefs.join(', '),
            decoration: _inputDecoration(
              'Target refs',
              Icons.account_tree_rounded,
            ),
            onChanged:
                (value) =>
                    setState(() => module.targetRefs = _splitComma(value)),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            initialValue: module.procedureRefs.join(', '),
            decoration: _inputDecoration(
              'Procedure refs',
              Icons.description_rounded,
            ),
            onChanged:
                (value) =>
                    setState(() => module.procedureRefs = _splitComma(value)),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            initialValue: module.operationalStatePreconditions.join(', '),
            decoration: _inputDecoration(
              'Operational preconditions',
              Icons.rule_rounded,
            ),
            onChanged:
                (value) => setState(
                  () =>
                      module.operationalStatePreconditions = _splitComma(value),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsCard(ComposerModuleDraft module) {
    final sortedFields = [...module.fields]
      ..sort((a, b) => a.order.compareTo(b.order));
    return _ComposerCard(
      title: 'Field definitions',
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Add yes/no field',
            icon: const Icon(Icons.check_box_rounded, color: BafColors.sync),
            onPressed: () => _addField(module, ComposerFieldType.yesNo),
          ),
          IconButton(
            tooltip: 'Add numeric evidence field',
            icon: const Icon(Icons.speed_rounded, color: BafColors.planned),
            onPressed:
                () => _addField(module, ComposerFieldType.numericWithUnit),
          ),
          IconButton(
            tooltip: 'Add observation field',
            icon: const Icon(Icons.add_rounded, color: BafColors.planned),
            onPressed: () => _addField(module, ComposerFieldType.longText),
          ),
        ],
      ),
      child: Column(
        children: [
          if (module.fields.isEmpty)
            const Padding(
              padding: EdgeInsets.all(BafSpacing.sm),
              child: Text(
                'No fields yet.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          for (
            var displayIndex = 0;
            displayIndex < sortedFields.length;
            displayIndex++
          )
            ComposerFieldCard(
              key: ObjectKey(sortedFields[displayIndex]),
              field: sortedFields[displayIndex],
              onRequiredChanged:
                  (value) => setState(
                    () => sortedFields[displayIndex].isRequired = value,
                  ),
              onEdit: () => _editField(sortedFields[displayIndex]),
              onDuplicate:
                  () => _duplicateField(module, sortedFields[displayIndex]),
              onMoveUp:
                  displayIndex == 0
                      ? null
                      : () =>
                          _moveField(module, sortedFields[displayIndex], -1),
              onMoveDown:
                  displayIndex == sortedFields.length - 1
                      ? null
                      : () => _moveField(module, sortedFields[displayIndex], 1),
              onDelete:
                  () => _removeField(
                    module,
                    module.fields.indexOf(sortedFields[displayIndex]),
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(ComposerModuleDraft module) {
    final sortedItems = [...module.checklistItems]
      ..sort((a, b) => a.order.compareTo(b.order));
    return _ComposerCard(
      title: 'Checklist / task items',
      trailing: IconButton(
        tooltip: 'Add checklist item',
        icon: const Icon(Icons.add_task_rounded, color: BafColors.planned),
        onPressed: () => _addChecklistItem(module),
      ),
      child: Column(
        children: [
          if (sortedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(BafSpacing.sm),
              child: Text(
                'No checklist items yet.',
                style: TextStyle(color: BafColors.textSecondary),
              ),
            ),
          for (
            var displayIndex = 0;
            displayIndex < sortedItems.length;
            displayIndex++
          )
            ComposerChecklistCard(
              key: ObjectKey(sortedItems[displayIndex]),
              item: sortedItems[displayIndex],
              onEdit: () => _editChecklistItem(sortedItems[displayIndex]),
              onDuplicate:
                  () => _duplicateChecklistItem(
                    module,
                    sortedItems[displayIndex],
                  ),
              onMoveUp:
                  displayIndex == 0
                      ? null
                      : () => _moveChecklistItem(
                        module,
                        sortedItems[displayIndex],
                        -1,
                      ),
              onMoveDown:
                  displayIndex == sortedItems.length - 1
                      ? null
                      : () => _moveChecklistItem(
                        module,
                        sortedItems[displayIndex],
                        1,
                      ),
              onDelete:
                  () => _removeChecklistItem(module, sortedItems[displayIndex]),
            ),
        ],
      ),
    );
  }

  Widget _buildValidationCard(ModuleComposerValidationResult validation) {
    return _ComposerCard(
      title: 'Validation and governance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (validation.errors.isEmpty &&
              validation.warnings.isEmpty &&
              validation.justificationsRequired.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_rounded, color: BafColors.success),
              title: Text('Ready to save to publisher'),
              subtitle: Text(
                'Generated JSON will still be validated by Template Publisher.',
              ),
            ),
          for (final error in validation.errors)
            _ValidationLine(
              icon: Icons.error_rounded,
              color: BafColors.danger,
              text: error,
            ),
          for (final item in validation.justificationsRequired)
            _ValidationLine(
              icon: Icons.gpp_maybe_rounded,
              color: BafColors.warning,
              text: item,
            ),
          for (final warning in validation.warnings)
            _ValidationLine(
              icon: Icons.warning_amber_rounded,
              color: BafColors.warning,
              text: warning,
            ),
          if (_draft.safetyJustifications.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Safety justifications captured',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: BafSpacing.xs),
            for (final item in _draft.safetyJustifications)
              _ValidationLine(
                icon: Icons.assignment_turned_in_rounded,
                color: BafColors.audit,
                text: '${item.fieldKey}: ${item.reason}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagResolverCard() {
    final module = _selectedModule;
    return _ComposerCard(
      title: 'Dynamic Tag Resolver v1',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _tagController,
            decoration: _inputDecoration(
              'Resolve tag, e.g. PSL-13 / VT07',
              Icons.sensors_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          FilledButton.icon(
            onPressed:
                module == null ? null : () => _resolveTagIntoModule(module),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Resolve into selected module'),
          ),
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'Resolver uses exact manual-backed knowledge first, then approved/version metadata later, then deterministic prefix inference.',
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (_lastTagResolution != null) ...[
            const SizedBox(height: BafSpacing.sm),
            _TagResolutionSummary(result: _lastTagResolution!),
            if (_lastTagResolution!.requiresReview)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _approveLastTagCorrection,
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text(
                    'Approve correction for this TemplateVersion',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonPreviewCard() {
    final output = ModuleComposerJsonBuilder.build(_draft);
    return _ComposerCard(
      title: 'Generated JSON preview',
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: BafColors.textPrimary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'jobTemplateSnapshotJson',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SelectableText(_compactPreview(output.jobTemplateSnapshotJson)),
            const Divider(),
            const Text(
              'moduleSnapshotsJson',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SelectableText(_compactPreview(output.moduleSnapshotsJson)),
            const Divider(),
            const Text(
              'fieldDefinitionsJson',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SelectableText(_compactPreview(output.fieldDefinitionsJson)),
            const Divider(),
            const Text(
              'checklistJson',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SelectableText(_compactPreview(output.checklistJson)),
          ],
        ),
      ),
    );
  }
}
