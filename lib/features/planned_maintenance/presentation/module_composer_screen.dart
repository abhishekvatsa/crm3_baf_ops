import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/baf_module_catalogue_seed.dart';
import '../data/job_module_model.dart';
import '../data/module_registry_model.dart';
import '../data/template_governance_model.dart';
import '../domain/baf_knowledge_layer.dart';
import '../domain/baf_knowledge_repository.dart';
import '../domain/baf_tag_resolver_v2.dart';
import '../domain/module_composer_json_builder.dart';
import '../domain/module_composer_models.dart';
import '../domain/module_composer_validator.dart';
import '../domain/module_workshop_actions.dart';
import '../domain/module_workshop_merge.dart';
import '../domain/module_workshop_published_sources.dart';
import '../providers/module_registry_provider.dart';
import '../providers/template_governance_provider.dart';
import 'module_editor_screen.dart';
import 'module_registry_authoring_screen.dart';
import 'module_workshop_screen.dart';
import 'widgets/publish_metadata_dialog.dart';

const int _jsonPreviewMaxChars = 2200;

class ModuleComposerScreen extends ConsumerStatefulWidget {
  final String initialJobTemplateJson;
  final String initialModuleSnapshotsJson;
  final String initialFieldDefinitionsJson;
  final String initialChecklistJson;
  final String recoveryScopeId;
  final String actorUid;
  final String actorName;
  final bool canSeedCloudKnowledge;
  final bool showSaveToPublisher;
  final Future<BafKnowledgeBundle> Function()? knowledgeBundleLoader;

  const ModuleComposerScreen({
    super.key,
    required this.initialJobTemplateJson,
    required this.initialModuleSnapshotsJson,
    required this.initialFieldDefinitionsJson,
    required this.initialChecklistJson,
    this.recoveryScopeId = 'default',
    this.actorUid = '',
    this.actorName = '',
    this.canSeedCloudKnowledge = false,
    this.showSaveToPublisher = true,
    this.knowledgeBundleLoader,
  });

  @override
  ConsumerState<ModuleComposerScreen> createState() =>
      _ModuleComposerScreenState();
}

class _ModuleComposerScreenState extends ConsumerState<ModuleComposerScreen> {
  late TemplateComposerDraft _draft;
  int _selectedModuleIndex = -1;
  final Set<int> _mergeSelection = <int>{};
  String _knowledgeQuery = '';
  String _seedQuery = '';
  ComposerReadiness? _readinessFilter;
  final _tagController = TextEditingController();
  BafKnowledgeRepository? _knowledgeRepository;
  BafTagResolution? _lastTagResolution;
  bool _showJsonPreview = false;
  bool _isLoadingKnowledge = true;
  bool _isSeedingCloud = false;
  bool _suppressRecoverySave = false;
  Timer? _recoverySaveDebounce;
  List<BafKnowledgeEntry> _knowledgeRows = BafKnowledgeLayer.entries;
  BafKnowledgeMatrixMeta _matrixMeta = BafKnowledgeMatrixMeta.staticFallback();

  @override
  void initState() {
    super.initState();
    _draft = TemplateComposerDraft.fromPayloads(
      jobTemplateSnapshotJson: widget.initialJobTemplateJson,
      moduleSnapshotsJson: widget.initialModuleSnapshotsJson,
      fieldDefinitionsJson: widget.initialFieldDefinitionsJson,
      checklistJson: widget.initialChecklistJson,
    );
    _draft.localId = _stableDraftLocalId();
    _applyMatrixMetaToDraft();
    if (_draft.modules.isNotEmpty) {
      _selectedModuleIndex = 0;
    }
    _loadKnowledgeRows();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkForRecoverableDraft(),
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_suppressRecoverySave && mounted) {
      _scheduleRecoverySave();
    }
  }

  void _setStateWithoutRecoverySave(VoidCallback fn) {
    final wasSuppressing = _suppressRecoverySave;
    _suppressRecoverySave = true;
    try {
      setState(fn);
    } finally {
      _suppressRecoverySave = wasSuppressing;
    }
  }

  @override
  void dispose() {
    _recoverySaveDebounce?.cancel();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validation = ModuleComposerValidator.validate(_draft);
    final actor = ref.watch(currentAppUserProvider).value;
    final canManageRegistry = actor?.canManageTemplateGovernance == true;
    final canPreparePublish = actor?.canPublishTemplateVersion == true;
    final compactAppBar = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0.4,
        title: Text(compactAppBar ? 'Module Composer' : 'BAF Module Composer'),
        actions: _buildAppBarActions(
          context: context,
          validation: validation,
          canManageRegistry: canManageRegistry,
          canPreparePublish: canPreparePublish,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: _buildLeftRail(validation)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildEditorPane(validation)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 360, child: _buildRightRail(validation)),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(BafSpacing.md),
              children: [
                _buildHeaderCard(validation),
                const SizedBox(height: BafSpacing.md),
                _buildModuleList(),
                const SizedBox(height: BafSpacing.md),
                _buildKnowledgePicker(),
                const SizedBox(height: BafSpacing.md),
                _buildSeedClonePicker(),
                const SizedBox(height: BafSpacing.md),
                _buildEditorPane(validation, embedded: true),
                const SizedBox(height: BafSpacing.md),
                _buildRightRail(validation, embedded: true),
              ],
            );
          },
        ),
      ),
    );
  }

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
            initialValue: _draft.title,
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
                (value) => setState(
                  () => _draft.assetType = value ?? _draft.assetType,
                ),
          ),
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
                widget.canSeedCloudKnowledge
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
            _FieldTile(
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
            _ChecklistTile(
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
                  () => setState(
                    () =>
                        module.checklistItems.remove(sortedItems[displayIndex]),
                  ),
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

  ComposerModuleDraft? get _selectedModule {
    if (_selectedModuleIndex < 0 ||
        _selectedModuleIndex >= _draft.modules.length) {
      return null;
    }
    return _draft.modules[_selectedModuleIndex];
  }

  void _addManualModule() {
    setState(() {
      final module = ComposerModuleDraft.manual(assetType: _draft.assetType);
      module.moduleCode = _uniqueModuleCode(module.moduleCode);
      _draft.modules.add(module);
      _selectedModuleIndex = _draft.modules.length - 1;
    });
  }

  String get _recoveryKey {
    final actor = _safeKeySegment(
      widget.actorUid.trim().isEmpty ? 'unknown_actor' : widget.actorUid,
    );
    final scope = _safeKeySegment(
      widget.recoveryScopeId.trim().isEmpty
          ? 'default_scope'
          : widget.recoveryScopeId,
    );
    final draftId = _safeKeySegment(
      _draft.localId.trim().isEmpty ? _stableDraftLocalId() : _draft.localId,
    );
    return 'RECOVERY::$actor::$scope::$draftId';
  }

  String _stableDraftLocalId() {
    final scope =
        widget.recoveryScopeId.trim().isEmpty
            ? 'default_scope'
            : widget.recoveryScopeId.trim();
    final seed = <String>[
      scope,
      widget.initialJobTemplateJson,
      widget.initialModuleSnapshotsJson,
      widget.initialFieldDefinitionsJson,
      widget.initialChecklistJson,
    ].join('|');
    return 'draft_${_safeKeySegment(scope)}_${_stableHash(seed)}';
  }

  String _safeKeySegment(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_\-]+'),
      '_',
    );
    return cleaned.isEmpty ? 'blank' : cleaned;
  }

  String _stableHash(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  Future<void> _loadKnowledgeRows() async {
    _setStateWithoutRecoverySave(() => _isLoadingKnowledge = true);
    BafKnowledgeBundle? bundle;
    Object? loadError;
    try {
      final loader = widget.knowledgeBundleLoader;
      if (loader != null) {
        bundle = await loader();
      } else {
        bundle =
            await (_knowledgeRepository ??= BafKnowledgeRepository()).load();
      }
    } catch (e) {
      loadError = e;
    }
    if (!mounted) {
      return;
    }

    final loadedBundle = bundle;
    final usingEmbeddedFallback =
        loadedBundle == null || loadedBundle.entries.isEmpty;
    _setStateWithoutRecoverySave(() {
      if (loadedBundle == null || loadedBundle.entries.isEmpty) {
        _knowledgeRows = BafKnowledgeLayer.entries;
        _matrixMeta = BafKnowledgeMatrixMeta.staticFallback(
          cloudUnavailable: true,
        );
      } else {
        _knowledgeRows = loadedBundle.entries;
        _matrixMeta = loadedBundle.meta;
      }
      _isLoadingKnowledge = false;
      _applyMatrixMetaToDraft();
    });

    if (usingEmbeddedFallback) {
      _showSnack(
        loadError == null
            ? 'Knowledge source returned no active rows; using embedded safety baseline.'
            : 'Knowledge source unavailable; using embedded safety baseline.',
        BafColors.warning,
      );
    }
  }

  void _applyMatrixMetaToDraft() {
    _draft.metadata['matrixVersion'] = _matrixMeta.matrixVersion;
    _draft.metadata['knowledgeSource'] = _matrixMeta.source;
    _draft.metadata['knowledgeSourceLabel'] = _matrixMeta.sourceLabel;
    _draft.metadata['knowledgeCloudUpdatedAt'] =
        _matrixMeta.cloudUpdatedAt?.toIso8601String();
    _draft.metadata['knowledgeLocalCachedAt'] =
        _matrixMeta.localCachedAt?.toIso8601String();
    _draft.metadata['knowledgeRowCount'] = _knowledgeRows.length;
    _draft.metadata['knowledgeTagRowCount'] =
        _knowledgeRows.where((entry) => entry.deviceTags.isNotEmpty).length;
    _draft.metadata['maintenanceManualRef'] = _matrixMeta.maintenanceManualRef;
    _draft.metadata['safetyOperationsManualRef'] =
        _matrixMeta.safetyOperationsManualRef;
  }

  void _setClosureReviewConfirmed(bool value) {
    _draft.closureReviewConfirmed = value;
    if (value) {
      _draft.metadata['closureReviewConfirmedAt'] =
          DateTime.now().toIso8601String();
      _draft.metadata['closureReviewConfirmedByUid'] = widget.actorUid;
      _draft.metadata['closureReviewConfirmedByName'] = widget.actorName;
    } else {
      _draft.metadata.remove('closureReviewConfirmedAt');
      _draft.metadata.remove('closureReviewConfirmedByUid');
      _draft.metadata.remove('closureReviewConfirmedByName');
    }
  }

  List<BafKnowledgeEntry> _searchKnowledgeRows(String query) {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) {
      return _knowledgeRows;
    }
    return _knowledgeRows
        .where((entry) {
          final haystack =
              <String>[
                entry.id,
                entry.moduleCandidateCode,
                entry.taskText,
                entry.assetFamilyKey,
                entry.functionalSection,
                entry.componentGroup,
                entry.taskType,
                entry.frequency.name,
                entry.discipline.name,
                entry.sourceLabel,
                entry.composerReadiness.name,
                entry.confidence.name,
                ...entry.ownerDisciplines,
                ...entry.safetyClasses,
                ...entry.procedureRefs,
                ...entry.partRefs,
                ...entry.deviceTags,
              ].join(' ').toLowerCase();
          return haystack.contains(key);
        })
        .toList(growable: false);
  }

  void _scheduleRecoverySave() {
    _recoverySaveDebounce?.cancel();
    _recoverySaveDebounce = Timer(
      const Duration(milliseconds: 900),
      _saveRecoveryDraft,
    );
  }

  Future<void> _saveRecoveryDraft() async {
    if (!mounted || _draft.modules.isEmpty) {
      return;
    }
    try {
      _applyMatrixMetaToDraft();
      final output = ModuleComposerJsonBuilder.build(_draft);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) {
        return;
      }
      await prefs.setString(
        _recoveryKey,
        jsonEncode(<String, dynamic>{
          'savedAt': DateTime.now().toIso8601String(),
          'matrixMeta': _matrixMeta.toMap(),
          'jobTemplateSnapshotJson': output.jobTemplateSnapshotJson,
          'moduleSnapshotsJson': output.moduleSnapshotsJson,
          'fieldDefinitionsJson': output.fieldDefinitionsJson,
          'checklistJson': output.checklistJson,
        }),
      );
    } catch (_) {
      // Recovery is best-effort only. It must never block authoring.
    }
  }

  Future<void> _clearRecoveryDraft() async {
    _recoverySaveDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recoveryKey);
  }

  Future<void> _checkForRecoverableDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recoveryKey);
    if (raw == null || raw.trim().isEmpty || !mounted) {
      return;
    }
    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await prefs.remove(_recoveryKey);
      return;
    }
    final savedAt = decoded['savedAt']?.toString() ?? 'unknown time';
    if (!mounted) {
      return;
    }
    final restore = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Recover unsaved composer draft?'),
            content: Text(
              'An unsaved Module Composer draft was found for this publisher context. Saved at: $savedAt. Restore it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Restore'),
              ),
            ],
          ),
    );
    if (!mounted) {
      return;
    }
    if (restore != true) {
      await prefs.remove(_recoveryKey);
      return;
    }
    _suppressRecoverySave = true;
    try {
      setState(() {
        _draft = TemplateComposerDraft.fromPayloads(
          jobTemplateSnapshotJson:
              decoded['jobTemplateSnapshotJson']?.toString() ?? '{}',
          moduleSnapshotsJson:
              decoded['moduleSnapshotsJson']?.toString() ?? '[]',
          fieldDefinitionsJson:
              decoded['fieldDefinitionsJson']?.toString() ?? '[]',
          checklistJson: decoded['checklistJson']?.toString() ?? '[]',
        );
        if (_draft.localId.trim().isEmpty) {
          _draft.localId = _stableDraftLocalId();
        }
        _applyMatrixMetaToDraft();
        _selectedModuleIndex = _draft.modules.isEmpty ? -1 : 0;
      });
    } finally {
      _suppressRecoverySave = false;
    }
    _showSnack('Recovered unsaved Module Composer draft.', BafColors.sync);
  }

  Future<void> _seedCloudKnowledgeBaseline() async {
    if (!widget.canSeedCloudKnowledge || widget.actorUid.trim().isEmpty) {
      _showSnack(
        'Only Admin/SI governance users can seed cloud knowledge.',
        BafColors.danger,
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _SeedCloudKnowledgeBaselineDialog(),
    );
    if (!mounted) {
      return;
    }
    if (reason == null ||
        reason.trim().length < BafKnowledgeRepository.changeReasonMinLength) {
      return;
    }

    setState(() => _isSeedingCloud = true);
    try {
      await (_knowledgeRepository ??= BafKnowledgeRepository())
          .seedCloudBaseline(
            actorUid: widget.actorUid,
            actorName: widget.actorName,
            changeSummary: reason.trim(),
          );
      await _loadKnowledgeRows();
      if (!mounted) {
        return;
      }
      _showSnack(
        'Cloud knowledge baseline seeded, audited, and reloaded.',
        BafColors.sync,
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Cloud knowledge seeding failed: $e', BafColors.danger);
      }
    } finally {
      if (mounted) {
        setState(() => _isSeedingCloud = false);
      }
    }
  }

  void _cloneKnowledgeEntry(BafKnowledgeEntry entry) {
    if (!entry.isCloneable) {
      return;
    }
    setState(() {
      final module = ComposerModuleDraft.fromKnowledge(entry);
      module.moduleCode = _uniqueModuleCode(module.moduleCode);
      _draft.modules.add(module);
      _selectedModuleIndex = _draft.modules.length - 1;
      _setClosureReviewConfirmed(false);
    });
    if (entry.needsReviewBeforeUse) {
      _showSnack(
        'Cloned with review flag: ${entry.composerReadiness.name}.',
        BafColors.warning,
      );
    }
  }

  void _cloneSeedModule(BafModuleSeed seed) {
    setState(() {
      final module = ComposerModuleDraft(
        localId:
            'seed-${seed.moduleCode}-${DateTime.now().microsecondsSinceEpoch}',
        moduleCode: _uniqueModuleCode(seed.moduleCode),
        title: seed.moduleTitle,
        description: seed.closedDossierOutput,
        assetType:
            seed.applicableAssetTypes.isNotEmpty
                ? seed.applicableAssetTypes.first
                : _draft.assetType,
        discipline: seed.defaultDiscipline,
        ownerDisciplines: [_ownerFromDiscipline(seed.defaultDiscipline)],
        primaryOwner: _ownerFromDiscipline(seed.defaultDiscipline),
        requiresJointReview:
            seed.defaultDiscipline == JobModuleDiscipline.shared,
        useMode: seed.defaultUseMode,
        functionalSection: seed.functionalSection,
        componentGroup: seed.componentGroup,
        subsystem: seed.catalogueArea,
        safetyClasses:
            {
              seed.defaultSafetyClass.name,
              ...seed.safetyConfirmations.map(_normaliseSafetyText),
            }.toList(),
        targetRefs:
            [
              seed.catalogueArea,
              seed.functionalSection,
              seed.componentGroup,
            ].where((value) => value.trim().isNotEmpty).toList(),
        deviceTagRefs: _extractTagsFromSeed(seed),
        procedureRefs: List<String>.from(seed.procedureRefs),
        partRefs: const <String>[],
        operationalStatePreconditions: List<String>.from(
          seed.operationalStatePreconditions,
        ),
        requiredForClosure: _seedSuggestsClosureCritical(seed),
        frequency: MaintenanceFrequency.unknown,
        fields: [
          for (var i = 0; i < seed.fields.length; i++)
            _fieldFromSeed(seed.fields[i], i + 1, seed),
        ],
        checklistItems: [
          for (var i = 0; i < seed.standardItems.length; i++)
            ComposerChecklistItemDraft(
              id: seed.standardItems[i].itemId,
              title: seed.standardItems[i].title,
              description: BafModuleCatalogueSeed.sourceLabel,
              isRequired: _seedSuggestsClosureCritical(seed),
              order: i + 1,
              safetyClasses: [seed.defaultSafetyClass.name],
              metadata: <String, dynamic>{
                'sourceSeedCode': seed.moduleCode,
                'seedVersion': BafModuleCatalogueSeed.seedVersion,
              },
            ),
        ],
        sourceSeedCode: seed.moduleCode,
        sourceManualRef: BafModuleCatalogueSeed.sourceLabel,
        sourceReadiness: ComposerReadiness.readyPreset,
        confidence: KnowledgeConfidence.confirmedManual,
        authoringNotes: 'Cloned from seed catalogue. Review before publish.',
        metadata: <String, dynamic>{
          'source': 'bafModuleCatalogueSeed',
          'sourceSeedCode': seed.moduleCode,
          'seedVersion': BafModuleCatalogueSeed.seedVersion,
          'addAsYouGoTriggers': seed.addAsYouGoTriggers,
          'safetyConfirmations': seed.safetyConfirmations,
        },
      );
      if (module.discipline == JobModuleDiscipline.shared &&
          module.ownerDisciplines.length < 2) {
        module.requiresJointReview = true;
      }
      _draft.modules.add(module);
      _selectedModuleIndex = _draft.modules.length - 1;
      _setClosureReviewConfirmed(false);
    });
    _showSnack(
      'Seed module ${seed.moduleCode} cloned into editable draft.',
      BafColors.sync,
    );
  }

  Future<void> _openPublishMetadataDialog() async {
    final validation = ModuleComposerValidator.validate(_draft);
    if (!validation.canSave) {
      _showSnack(
        'Resolve validation errors/justifications before publishing.',
        BafColors.danger,
      );
      return;
    }

    final actor = ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.canPublishTemplateVersion) {
      _showSnack(
        'Only Admin/SI users can prepare governed TemplateVersion publishing.',
        BafColors.danger,
      );
      return;
    }

    final repository = ref.read(templateGovernanceRepositoryProvider);
    late final List<TemplatePackage> activePackages;
    try {
      final packages = await repository.getAllPackages();
      activePackages = packages
        .where(
          (package) =>
              !package.isDeleted &&
              package.lifecycleStatus == TemplatePackageLifecycleStatus.active,
        )
        .toList(growable: false)..sort(
        (a, b) =>
            a.packageCode.toLowerCase().compareTo(b.packageCode.toLowerCase()),
      );
    } on Object catch (error) {
      _showSnack('Unable to load template packages: $error', BafColors.danger);
      return;
    }

    if (!mounted) {
      return;
    }

    await PublishMetadataDialog.show(
      context,
      actor: actor,
      draft: _draft,
      existingPackages: activePackages,
      initialPackageCode: _suggestPublishPackageCode(),
      initialPackageTitle: _draft.title,
      actions: PublishMetadataDialogActions(
        savePackage: (package, actionActor) {
          return repository.savePackage(package, actor: actionActor);
        },
        saveVersionDraft: (version, actionActor) async {
          await repository.saveVersion(version, actor: actionActor);
          await _clearRecoveryDraft();
          _triggerTemplateGovernanceSync(
            'template_governance_draft_saved_from_composer',
          );
        },
        publishVersion: (version, actionActor, reason) async {
          await repository.publishVersion(
            version,
            actor: actionActor,
            reason: reason,
          );
          await _clearRecoveryDraft();
          _triggerTemplateGovernanceSync(
            'template_governance_version_published_from_composer',
          );
        },
        nextVersionNumberFor: (package) async {
          final packageId = package.firestoreId;
          if (packageId == null || packageId.trim().isEmpty) {
            return 1;
          }
          final versions = await repository.getVersionsForPackage(packageId);
          var latest = package.latestVersionNumber;
          for (final version in versions) {
            if (version.isDeleted) {
              continue;
            }
            if (version.versionNumber > latest) {
              latest = version.versionNumber;
            }
          }
          return latest + 1;
        },
      ),
    );
  }

  void _triggerTemplateGovernanceSync(String reason) {
    unawaited(
      ref
          .read(syncCoordinatorProvider)
          .runFullSync(reason: reason, force: true),
    );
  }

  String _suggestPublishPackageCode() {
    final slug = _slugKey(_draft.title);
    if (slug.isEmpty) {
      return 'BAF-PM-${_draft.modules.length + 1}';
    }
    return slug.toUpperCase().replaceAll('_', '-');
  }

  Future<void> _openRegistryAuthoring() async {
    final actor = ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.canManageTemplateGovernance) {
      _showSnack('Registry authoring is Admin/SI-only.', BafColors.danger);
      return;
    }

    final repository = ref.read(moduleRegistryRepositoryProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => ModuleRegistryAuthoringScreen(
              actor: actor,
              draftModules: _draft.modules
                  .map(cloneComposerModuleDraft)
                  .toList(growable: false),
              loadDraftRevisions: repository.getDraftRevisions,
              loadPublishedSources: repository.getPublishedSources,
              createDraft: (module, reason) {
                return repository.createDraftFromModule(
                  module: module,
                  actor: actor,
                  sourceType: 'moduleComposerDraft',
                  lineage: <String, dynamic>{
                    'sourceModuleCode': module.moduleCode,
                    'sourceLocalId': module.localId,
                    'createdFromRegistryAuthoringUi': true,
                  },
                  reason: reason,
                );
              },
              updateDraft: (revision, module, reason) {
                return repository.updateDraftRevision(
                  revision: revision,
                  module: module,
                  actor: actor,
                  sourceType: 'moduleComposerDraft',
                  lineage: <String, dynamic>{
                    'sourceModuleCode': module.moduleCode,
                    'sourceLocalId': module.localId,
                    'updatedFromRegistryAuthoringUi': true,
                  },
                  reason: reason,
                );
              },
              publishDraft: (revision, reason) {
                return repository.publishDraftRevision(
                  registryModuleId: revision.registryModuleId,
                  revisionId: revision.revisionId,
                  actor: actor,
                  reason: reason,
                );
              },
              retireRevision: (revision, reason) {
                return repository.retirePublishedRevision(
                  revision: revision,
                  actor: actor,
                  reason: reason,
                );
              },
              retireFamily: (family, reason) {
                return repository.retireFamily(
                  family: family,
                  actor: actor,
                  reason: reason,
                );
              },
            ),
      ),
    );
    if (!mounted) {
      return;
    }
    ref.invalidate(registryDraftRevisionsProvider);
    ref.invalidate(publishedRegistryModuleSourcesProvider);
  }

  Future<void> _openModuleWorkshop() async {
    final publishedSources = await _loadPublishedModuleSourcesForWorkshop();
    final registrySources = await _loadRegistryModuleSourcesForWorkshop();
    if (!mounted) {
      return;
    }

    final result = await Navigator.of(context).push<ModuleWorkshopResult>(
      MaterialPageRoute(
        builder:
            (_) => ModuleWorkshopScreen(
              draftModules: _draft.modules
                  .map(cloneComposerModuleDraft)
                  .toList(growable: false),
              seedCatalogueCount: BafModuleCatalogueSeed.modules.length,
              knowledgeCatalogueCount: _knowledgeRows.length,
              publishedSourceCount: publishedSources.length,
              seedModules: BafModuleCatalogueSeed.modules,
              knowledgeRows: _knowledgeRows,
              publishedSources: publishedSources,
              registrySources: registrySources,
            ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }
    switch (result.action) {
      case ModuleWorkshopResultAction.selectDraft:
        if (result.moduleIndex < 0 ||
            result.moduleIndex >= _draft.modules.length) {
          return;
        }
        setState(() => _selectedModuleIndex = result.moduleIndex);
        _showSnack(
          'Selected module ${_draft.modules[result.moduleIndex].moduleCode}.',
          BafColors.sync,
        );
        return;
      case ModuleWorkshopResultAction.openFocusedEditor:
        if (result.moduleIndex < 0 ||
            result.moduleIndex >= _draft.modules.length) {
          return;
        }
        await _openFocusedModuleEditor(result.moduleIndex);
        return;
      case ModuleWorkshopResultAction.cloneSeed:
        if (result.sourceIndex < 0 ||
            result.sourceIndex >= BafModuleCatalogueSeed.modules.length) {
          return;
        }
        _cloneSeedModule(BafModuleCatalogueSeed.modules[result.sourceIndex]);
        return;
      case ModuleWorkshopResultAction.cloneKnowledge:
        if (result.sourceIndex < 0 ||
            result.sourceIndex >= _knowledgeRows.length) {
          return;
        }
        _cloneKnowledgeEntry(_knowledgeRows[result.sourceIndex]);
        return;
      case ModuleWorkshopResultAction.clonePublishedModule:
        if (result.sourceIndex < 0 ||
            result.sourceIndex >= publishedSources.length) {
          return;
        }
        _clonePublishedModuleSource(publishedSources[result.sourceIndex]);
        return;
      case ModuleWorkshopResultAction.cloneRegistryModule:
        if (result.sourceIndex < 0 ||
            result.sourceIndex >= registrySources.length) {
          return;
        }
        _cloneRegistryModuleSource(registrySources[result.sourceIndex]);
        return;
    }
  }

  Future<List<PublishedModuleSource>>
  _loadPublishedModuleSourcesForWorkshop() async {
    try {
      final repository = ref.read(templateGovernanceRepositoryProvider);
      final packages = await repository.getAllPackages();
      final activePackages = packages
          .where((package) => !package.isDeleted)
          .where(
            (package) =>
                package.lifecycleStatus ==
                TemplatePackageLifecycleStatus.active,
          )
          .where((package) => (package.firestoreId ?? '').trim().isNotEmpty)
          .toList(growable: false);

      final versions = <TemplateVersion>[];
      for (final package in activePackages) {
        versions.addAll(
          await repository.getVersionsForPackage(package.firestoreId!.trim()),
        );
      }

      return publishedModuleSourcesFromTemplateVersions(
        versions: versions,
        packages: activePackages,
      );
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Published template sources could not be loaded: $e',
          BafColors.warning,
        );
      }
      return const <PublishedModuleSource>[];
    }
  }

  Future<List<PublishedRegistryModuleSource>>
  _loadRegistryModuleSourcesForWorkshop() async {
    try {
      return await ref
          .read(moduleRegistryRepositoryProvider)
          .getPublishedSources();
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Governed registry sources could not be loaded: $e',
          BafColors.warning,
        );
      }
      return const <PublishedRegistryModuleSource>[];
    }
  }

  void _cloneRegistryModuleSource(PublishedRegistryModuleSource source) {
    late final ComposerModuleDraft copy;
    setState(() {
      copy = cloneRegistryModuleIntoDraft(
        source: source,
        existingModules: _draft.modules,
      );
      _draft.modules.add(copy);
      _selectedModuleIndex = _draft.modules.length - 1;
      if (copy.requiredForClosure) {
        _setClosureReviewConfirmed(false);
      }
    });
    _showSnack(
      'Cloned ${source.module.moduleCode} from ${source.sourceLabel} as ${copy.moduleCode}.',
      BafColors.sync,
    );
  }

  void _clonePublishedModuleSource(PublishedModuleSource source) {
    late final ComposerModuleDraft copy;
    setState(() {
      copy = clonePublishedModuleIntoDraft(
        source: source,
        existingModules: _draft.modules,
      );
      _draft.modules.add(copy);
      _selectedModuleIndex = _draft.modules.length - 1;
      if (copy.requiredForClosure) {
        _setClosureReviewConfirmed(false);
      }
    });
    _showSnack(
      'Cloned ${source.module.moduleCode} from ${source.sourceLabel} as ${copy.moduleCode}.',
      BafColors.sync,
    );
  }

  void _toggleMergeSelection(int index) {
    if (index < 0 || index >= _draft.modules.length) {
      return;
    }
    setState(() {
      if (!_mergeSelection.add(index)) {
        _mergeSelection.remove(index);
      }
    });
  }

  void _mergeSelectedModules() {
    final selectedIndexes = _mergeSelection.toList()..sort();
    if (selectedIndexes.length < 2) {
      _showSnack('Select at least two modules to merge.', BafColors.warning);
      return;
    }
    if (selectedIndexes.any(
      (index) => index < 0 || index >= _draft.modules.length,
    )) {
      _showSnack(
        'Merge selection is stale. Select modules again.',
        BafColors.warning,
      );
      setState(() => _mergeSelection.clear());
      return;
    }

    late final ComposerModuleDraft merged;
    setState(() {
      merged = mergeComposerModulesWithConflictWorkspace(
        sources: [for (final index in selectedIndexes) _draft.modules[index]],
        existingModules: _draft.modules,
      );
      _draft.modules.add(merged);
      _selectedModuleIndex = _draft.modules.length - 1;
      _mergeSelection.clear();
      if (merged.requiredForClosure) {
        _setClosureReviewConfirmed(false);
      }
    });

    final conflictCount = unresolvedMergeConflictCount(merged);
    _showSnack(
      conflictCount == 0
          ? 'Merged modules into ${merged.moduleCode}.'
          : 'Merged modules into ${merged.moduleCode}. Resolve $conflictCount merge conflict${conflictCount == 1 ? '' : 's'} before saving to publisher.',
      conflictCount == 0 ? BafColors.sync : BafColors.warning,
    );
  }

  void _duplicateModule(int sourceIndex) {
    if (sourceIndex < 0 || sourceIndex >= _draft.modules.length) {
      return;
    }
    final source = _draft.modules[sourceIndex];
    late final ComposerModuleDraft copy;
    setState(() {
      copy = duplicateComposerModule(
        source: source,
        existingModules: _draft.modules,
      );
      _draft.modules.insert(sourceIndex + 1, copy);
      _selectedModuleIndex = sourceIndex + 1;
      if (copy.requiredForClosure) {
        _setClosureReviewConfirmed(false);
      }
    });
    _showSnack(
      'Duplicated module ${source.moduleCode} as ${copy.moduleCode}.',
      BafColors.sync,
    );
  }

  Future<void> _openFocusedModuleEditor(int moduleIndex) async {
    if (moduleIndex < 0 || moduleIndex >= _draft.modules.length) {
      return;
    }
    setState(() => _selectedModuleIndex = moduleIndex);

    final edited = await Navigator.of(context).push<ComposerModuleDraft>(
      MaterialPageRoute(
        builder: (_) => ModuleEditorScreen(module: _draft.modules[moduleIndex]),
      ),
    );
    if (!mounted || edited == null) {
      return;
    }
    if (moduleIndex < 0 || moduleIndex >= _draft.modules.length) {
      _showSnack(
        'Module was removed while the editor was open.',
        BafColors.warning,
      );
      return;
    }

    final wasClosureCritical = _draft.modules[moduleIndex].requiredForClosure;
    setState(() {
      _draft.modules[moduleIndex] = edited;
      _selectedModuleIndex = moduleIndex;
      if (wasClosureCritical != edited.requiredForClosure ||
          edited.requiredForClosure) {
        _setClosureReviewConfirmed(false);
      }
    });
    _showSnack('Updated module ${edited.moduleCode}.', BafColors.sync);
  }

  void _removeModule(int index) {
    setState(() {
      _draft.modules.removeAt(index);
      final nextMergeSelection = <int>{};
      for (final selectedIndex in _mergeSelection) {
        if (selectedIndex == index) {
          continue;
        }
        nextMergeSelection.add(
          selectedIndex > index ? selectedIndex - 1 : selectedIndex,
        );
      }
      _mergeSelection
        ..clear()
        ..addAll(nextMergeSelection);
      if (_draft.modules.isEmpty) {
        _selectedModuleIndex = -1;
      } else if (_selectedModuleIndex >= _draft.modules.length) {
        _selectedModuleIndex = _draft.modules.length - 1;
      }
    });
  }

  Future<void> _removeField(ComposerModuleDraft module, int index) async {
    final field = module.fields[index];
    if (field.isSafetyCriticalPreset) {
      final reason = await _askSafetyJustification(field);
      if (!mounted || reason == null || reason.trim().isEmpty) {
        return;
      }
      _draft.safetyJustifications.add(
        SafetyJustificationDraft(fieldKey: field.key, reason: reason.trim()),
      );
    }
    setState(() => module.fields.removeAt(index));
  }

  Future<String?> _askSafetyJustification(ComposerFieldDraft field) {
    return showDialog<String>(
      context: context,
      builder: (context) => _SafetyCriticalFieldRemovalDialog(field: field),
    );
  }

  void _addField(ComposerModuleDraft module, ComposerFieldType type) {
    final next = module.fields.length + 1;
    final baseKey = switch (type) {
      ComposerFieldType.yesNo => 'confirmation_$next',
      ComposerFieldType.numericWithUnit => 'reading_$next',
      ComposerFieldType.dropdown => 'condition_$next',
      ComposerFieldType.passFail => 'pass_fail_$next',
      _ => 'observation_$next',
    };
    final field = ComposerFieldDraft(
      key: _uniqueFieldKey(module, baseKey),
      label: _enumLabel(baseKey.replaceAll('_', ' ')),
      type: type,
      isRequired:
          module.requiredForClosure && _moduleLooksSafetyCritical(module),
      order: next,
      unit: type == ComposerFieldType.numericWithUnit ? 'as shown' : null,
      options:
          type == ComposerFieldType.dropdown
              ? const <String>['Good', 'Fair', 'Poor', 'Not checked']
              : const <String>[],
      instructionText: 'Added in Module Composer.',
      isSafetyCriticalPreset: false,
    );
    setState(() => module.fields.add(field));
    _editField(field);
  }

  Future<void> _editField(ComposerFieldDraft field) async {
    final edited = await showDialog<ComposerFieldDraft>(
      context: context,
      builder: (context) => _FieldEditorDialog(field: field),
    );
    if (!mounted || edited == null) {
      return;
    }
    setState(() {
      field.key = edited.key;
      field.label = edited.label;
      field.type = edited.type;
      field.isRequired = edited.isRequired;
      field.unit = edited.unit;
      field.options = edited.options;
      field.instructionText = edited.instructionText;
      field.isSafetyCriticalPreset = edited.isSafetyCriticalPreset;
    });
  }

  void _duplicateField(ComposerModuleDraft module, ComposerFieldDraft field) {
    setState(() {
      module.fields.add(
        ComposerFieldDraft(
          key: _uniqueFieldKey(module, '${field.key}_copy'),
          label: '${field.label} Copy',
          type: field.type,
          isRequired: field.isRequired,
          order: module.fields.length + 1,
          unit: field.unit,
          options: List<String>.from(field.options),
          instructionText: field.instructionText,
          validation: Map<String, dynamic>.from(field.validation),
          meta: Map<String, dynamic>.from(field.meta),
          isSafetyCriticalPreset: field.isSafetyCriticalPreset,
          sourcePresetId: field.sourcePresetId,
        ),
      );
    });
  }

  void _moveField(
    ComposerModuleDraft module,
    ComposerFieldDraft field,
    int direction,
  ) {
    final sorted = [...module.fields]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = sorted.indexOf(field);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= sorted.length) {
      return;
    }
    final currentOrder = sorted[index].order;
    sorted[index].order = sorted[target].order;
    sorted[target].order = currentOrder;
    setState(() {});
  }

  void _addChecklistItem(ComposerModuleDraft module) {
    final item = ComposerChecklistItemDraft(
      id: _uniqueChecklistId(
        module,
        '${module.moduleCode}-item-${module.checklistItems.length + 1}',
      ),
      title: 'New checklist item',
      description: '',
      isRequired: module.requiredForClosure,
      order: module.checklistItems.length + 1,
      safetyClasses: List<String>.from(module.safetyClasses),
    );
    setState(() => module.checklistItems.add(item));
    _editChecklistItem(item);
  }

  void _duplicateChecklistItem(
    ComposerModuleDraft module,
    ComposerChecklistItemDraft item,
  ) {
    final copy = ComposerChecklistItemDraft(
      id: _uniqueChecklistId(module, '${item.id}_copy'),
      title: '${item.title} copy',
      description: item.description,
      isRequired: item.isRequired,
      order: module.checklistItems.length + 1,
      linkedFieldKey: item.linkedFieldKey,
      safetyClasses: List<String>.from(item.safetyClasses),
      metadata: <String, dynamic>{...item.metadata, 'duplicatedFrom': item.id},
    );
    setState(() => module.checklistItems.add(copy));
  }

  Future<void> _editChecklistItem(ComposerChecklistItemDraft item) async {
    final edited = await showDialog<ComposerChecklistItemDraft>(
      context: context,
      builder: (context) => _ChecklistEditorDialog(item: item),
    );
    if (!mounted || edited == null) {
      return;
    }
    setState(() {
      item.id = edited.id;
      item.title = edited.title;
      item.description = edited.description;
      item.isRequired = edited.isRequired;
      item.linkedFieldKey = edited.linkedFieldKey;
      item.safetyClasses = edited.safetyClasses;
    });
  }

  void _moveChecklistItem(
    ComposerModuleDraft module,
    ComposerChecklistItemDraft item,
    int direction,
  ) {
    final sorted = [...module.checklistItems]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = sorted.indexOf(item);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= sorted.length) {
      return;
    }
    final currentOrder = sorted[index].order;
    sorted[index].order = sorted[target].order;
    sorted[target].order = currentOrder;
    setState(() {});
  }

  void _resolveTagIntoModule(ComposerModuleDraft module) {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final result = BafTagResolverV2.resolve(
      raw,
      assetContext: module.assetType,
      entries: _knowledgeRows,
    );
    setState(() {
      _lastTagResolution = result;
      if (!module.deviceTagRefs.contains(result.normalizedTag)) {
        module.deviceTagRefs.add(result.normalizedTag);
      }
      module.targetRefs =
          {...module.targetRefs, ...result.hierarchyPath}.toList();
      module.procedureRefs =
          {...module.procedureRefs, ...result.procedureRefs}.toList();
      module.safetyClasses =
          {...module.safetyClasses, ...result.safetyClasses}.toList();
      if (result.ownerDisciplines.isNotEmpty) {
        module.ownerDisciplines =
            {...module.ownerDisciplines, ...result.ownerDisciplines}.toList()
              ..sort();
        if (module.ownerDisciplines.length > 1) {
          module.discipline = JobModuleDiscipline.shared;
        }
        module.requiresJointReview = module.ownerDisciplines.length > 1;
      }
      module.metadata['lastTagResolution'] = <String, dynamic>{
        'rawInput': result.rawInput,
        'normalizedTag': result.normalizedTag,
        'displayName': result.displayName,
        'confidence': result.confidence,
        'requiresReview': result.requiresReview,
        'resolutionSource': result.resolutionSource,
      };
    });
    _showSnack(
      result.requiresReview
          ? 'Resolved ${result.normalizedTag} with review required (${result.resolutionSource}).'
          : 'Resolved ${result.normalizedTag} (${result.resolutionSource}).',
      result.requiresReview ? BafColors.warning : BafColors.success,
    );
  }

  void _approveLastTagCorrection() {
    final result = _lastTagResolution;
    if (result == null) {
      return;
    }
    setState(() {
      _draft.tagResolverCorrections.add(
        TagResolverCorrectionDraft(
          rawInput: result.rawInput,
          normalizedTag: result.normalizedTag,
          resolvedComponent:
              result.displayName ??
              result.componentGroup ??
              'Reviewed tag resolution',
        ),
      );
    });
    _showSnack(
      'Tag correction stored in TemplateVersion metadata.',
      BafColors.audit,
    );
  }

  Future<void> _saveToPublisher() async {
    if (!widget.showSaveToPublisher) {
      _showSnack(
        'Use Prepare Publish when the composer is opened from Template Authoring.',
        BafColors.warning,
      );
      return;
    }

    final validation = ModuleComposerValidator.validate(_draft);
    if (!validation.canSave) {
      _showSnack(
        'Resolve validation errors/justifications before saving.',
        BafColors.danger,
      );
      return;
    }
    final output = ModuleComposerJsonBuilder.build(_draft);
    await _clearRecoveryDraft();
    if (!mounted) {
      return;
    }
    Navigator.pop(context, output);
  }

  String _uniqueModuleCode(String base) {
    final existing =
        _draft.modules.map((module) => module.moduleCode.toLowerCase()).toSet();
    var code =
        base.trim().isEmpty ? 'M-${_draft.modules.length + 1}' : base.trim();
    if (!existing.contains(code.toLowerCase())) {
      return code;
    }
    var suffix = 2;
    while (existing.contains('$code-$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '$code-$suffix';
  }

  String _uniqueFieldKey(ComposerModuleDraft module, String base) {
    final existing =
        module.fields.map((field) => field.key.toLowerCase()).toSet();
    var key = _slugKey(base);
    if (key.isEmpty) {
      key = 'field_${module.fields.length + 1}';
    }
    if (!existing.contains(key.toLowerCase())) {
      return key;
    }
    var suffix = 2;
    while (existing.contains('${key}_$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '${key}_$suffix';
  }

  String _uniqueChecklistId(ComposerModuleDraft module, String base) {
    final existing =
        module.checklistItems.map((item) => item.id.toLowerCase()).toSet();
    var id =
        base.trim().isEmpty
            ? '${module.moduleCode}-item-${module.checklistItems.length + 1}'
            : base.trim();
    if (!existing.contains(id.toLowerCase())) {
      return id;
    }
    var suffix = 2;
    while (existing.contains('$id-$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '$id-$suffix';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class _SeedCloudKnowledgeBaselineDialog extends StatefulWidget {
  const _SeedCloudKnowledgeBaselineDialog();

  @override
  State<_SeedCloudKnowledgeBaselineDialog> createState() =>
      _SeedCloudKnowledgeBaselineDialogState();
}

class _SeedCloudKnowledgeBaselineDialogState
    extends State<_SeedCloudKnowledgeBaselineDialog> {
  final _reasonController = TextEditingController();
  String _currentReason = '';

  bool get _canSeed =>
      _currentReason.trim().length >=
      BafKnowledgeRepository.changeReasonMinLength;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seed cloud knowledge baseline?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This writes the embedded BAF Knowledge Matrix safety baseline to the governed cloud knowledge_base collection. This is a governance/audit event.',
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reasonController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Change reason / audit justification',
                  hintText:
                      'Example: Initial governed seed of BAF Knowledge Matrix v0.1 after SI review.',
                  helperText:
                      'Minimum ${BafKnowledgeRepository.changeReasonMinLength} characters required.',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _currentReason = value),
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
          onPressed:
              _canSeed
                  ? () => Navigator.pop(context, _currentReason.trim())
                  : null,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Seed cloud'),
        ),
      ],
    );
  }
}

class _SafetyCriticalFieldRemovalDialog extends StatefulWidget {
  final ComposerFieldDraft field;

  const _SafetyCriticalFieldRemovalDialog({required this.field});

  @override
  State<_SafetyCriticalFieldRemovalDialog> createState() =>
      _SafetyCriticalFieldRemovalDialogState();
}

class _SafetyCriticalFieldRemovalDialogState
    extends State<_SafetyCriticalFieldRemovalDialog> {
  final _controller = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _reason.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Safety-critical field removal'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Field: ${widget.field.label}'),
              const SizedBox(height: BafSpacing.sm),
              const Text(
                'Reason is required before removing a safety-critical suggested field.',
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _controller,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Justification',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _reason = value),
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
              canContinue
                  ? () => Navigator.pop(context, _controller.text.trim())
                  : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _ComposerCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  const _ComposerCard({this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.large),
        side: const BorderSide(color: BafColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum _ComposerAppBarAction {
  openWorkshop,
  openRegistryAuthoring,
  preparePublish,
  toggleJsonPreview,
  saveToPublisher,
}

enum _ModuleTileAction { openEditor, duplicate, delete }

class _ModuleTile extends StatelessWidget {
  final ComposerModuleDraft module;
  final bool selected;
  final bool selectedForMerge;
  final VoidCallback onTap;
  final VoidCallback onToggleMerge;
  final VoidCallback onOpenEditor;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ModuleTile({
    required this.module,
    required this.selected,
    required this.selectedForMerge,
    required this.onTap,
    required this.onToggleMerge,
    required this.onOpenEditor,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color:
          selected ? BafColors.planned.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: BorderSide(
          color: selected ? BafColors.planned : BafColors.border,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showActions(context),
        dense: true,
        leading: Checkbox(
          value: selectedForMerge,
          onChanged: (_) => onToggleMerge(),
        ),
        title: Text(
          module.moduleCode,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          module.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_ModuleTileAction>(
          tooltip: 'Module actions',
          onSelected: _handleAction,
          itemBuilder:
              (context) => const [
                PopupMenuItem(
                  value: _ModuleTileAction.openEditor,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.open_in_new_rounded),
                    title: Text('Open focused editor'),
                  ),
                ),
                PopupMenuItem(
                  value: _ModuleTileAction.duplicate,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.copy_rounded),
                    title: Text('Duplicate'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _ModuleTileAction.delete,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: BafColors.danger,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: BafColors.danger),
                    ),
                  ),
                ),
              ],
        ),
      ),
    );
  }

  void _handleAction(_ModuleTileAction action) {
    switch (action) {
      case _ModuleTileAction.openEditor:
        onOpenEditor();
        return;
      case _ModuleTileAction.duplicate:
        onDuplicate();
        return;
      case _ModuleTileAction.delete:
        onDelete();
        return;
    }
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<_ModuleTileAction>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('Open focused editor'),
                  subtitle: Text(module.moduleCode),
                  onTap:
                      () =>
                          Navigator.pop(context, _ModuleTileAction.openEditor),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Duplicate'),
                  onTap:
                      () => Navigator.pop(context, _ModuleTileAction.duplicate),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: BafColors.danger,
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: BafColors.danger),
                  ),
                  onTap: () => Navigator.pop(context, _ModuleTileAction.delete),
                ),
              ],
            ),
          ),
    );
    if (action != null) {
      _handleAction(action);
    }
  }
}

class _KnowledgeTile extends StatelessWidget {
  final BafKnowledgeEntry entry;
  final VoidCallback? onClone;

  const _KnowledgeTile({required this.entry, required this.onClone});

  @override
  Widget build(BuildContext context) {
    final color = _readinessColor(entry.composerReadiness);
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          entry.moduleCandidateCode,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: BafColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.taskText, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _MiniBadge(
                  label: _readinessLabel(entry.composerReadiness),
                  color: color,
                ),
                if (entry.deviceTags.isNotEmpty)
                  _MiniBadge(
                    label: entry.deviceTags.join(','),
                    color: BafColors.sync,
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          tooltip:
              onClone == null ? 'Not directly cloneable' : 'Clone into draft',
          onPressed: onClone,
          icon: Icon(
            onClone == null
                ? Icons.info_outline_rounded
                : Icons.add_circle_outline_rounded,
          ),
        ),
      ),
    );
  }
}

class _SeedModuleTile extends StatelessWidget {
  final BafModuleSeed seed;
  final VoidCallback onClone;

  const _SeedModuleTile({required this.seed, required this.onClone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          seed.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${seed.catalogueArea} • ${seed.componentGroup} • '
          '${seed.fields.length} fields • ${seed.standardItems.length} checklist items',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Clone seed module',
          onPressed: onClone,
          icon: const Icon(Icons.copy_all_rounded, color: BafColors.planned),
        ),
      ),
    );
  }
}

class _TagResolutionSummary extends StatelessWidget {
  final BafTagResolution result;

  const _TagResolutionSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: (result.requiresReview ? BafColors.warning : BafColors.success)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color: (result.requiresReview ? BafColors.warning : BafColors.success)
              .withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.normalizedTag} — ${result.displayName ?? 'Unresolved'}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence ${(result.confidence * 100).toStringAsFixed(0)}% • ${result.resolutionSource}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (result.ownerDisciplines.isNotEmpty ||
              result.safetyClasses.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.xs),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final owner in result.ownerDisciplines)
                  _MiniBadge(
                    label: _enumLabel(owner),
                    color: BafColors.planned,
                  ),
                for (final safety in result.safetyClasses.take(4))
                  _MiniBadge(
                    label: _enumLabel(safety),
                    color: BafColors.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final ComposerFieldDraft field;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  const _FieldTile({
    required this.field,
    required this.onRequiredChanged,
    required this.onEdit,
    required this.onDuplicate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color:
              field.isSafetyCriticalPreset
                  ? BafColors.warning.withValues(alpha: 0.5)
                  : BafColors.border,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          field.isSafetyCriticalPreset
              ? Icons.health_and_safety_rounded
              : Icons.edit_note_rounded,
          color:
              field.isSafetyCriticalPreset
                  ? BafColors.warning
                  : BafColors.planned,
        ),
        title: Text(
          field.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${field.key} • ${field.type.name}${field.unit == null ? '' : ' • ${field.unit}'}',
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            const Text('Req'),
            Switch(value: field.isRequired, onChanged: onRequiredChanged),
            IconButton(
              tooltip: 'Move up',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: onMoveUp,
            ),
            IconButton(
              tooltip: 'Move down',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: onMoveDown,
            ),
            IconButton(
              tooltip: 'Edit field',
              icon: const Icon(Icons.edit_rounded, color: BafColors.planned),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Duplicate field',
              icon: const Icon(Icons.copy_rounded, color: BafColors.sync),
              onPressed: onDuplicate,
            ),
            IconButton(
              tooltip: 'Delete field',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: BafColors.danger,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ComposerChecklistItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  const _ChecklistTile({
    required this.item,
    required this.onEdit,
    required this.onDuplicate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          item.isRequired
              ? Icons.task_alt_rounded
              : Icons.check_circle_outline_rounded,
          color: BafColors.sync,
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          item.description.isEmpty ? 'No description' : item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: onMoveUp,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: onMoveDown,
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: BafColors.planned),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: BafColors.sync),
              onPressed: onDuplicate,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: BafColors.danger,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _ValidationLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeSourceBanner extends StatelessWidget {
  final BafKnowledgeMatrixMeta meta;
  final VoidCallback? onSeedCloud;
  final bool isSeeding;

  const _KnowledgeSourceBanner({
    required this.meta,
    required this.onSeedCloud,
    required this.isSeeding,
  });

  @override
  Widget build(BuildContext context) {
    final isFallback = meta.isStaticFallback || meta.source == 'staticFallback';
    final color = isFallback ? BafColors.warning : BafColors.sync;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFallback ? Icons.shield_rounded : Icons.cloud_done_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  '${meta.sourceLabel} • ${meta.matrixVersion}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${meta.source} source • ${meta.knowledgeRowCount} rows • ${meta.tagRowCount} tag rows',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          if (meta.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta.note,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
          if (onSeedCloud != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: isSeeding ? null : onSeedCloud,
                icon:
                    isSeeding
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.cloud_upload_rounded, size: 16),
                label: Text(isSeeding ? 'Seeding...' : 'Seed cloud baseline'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FieldEditorDialog extends StatefulWidget {
  final ComposerFieldDraft field;

  const _FieldEditorDialog({required this.field});

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late final TextEditingController _unitController;
  late final TextEditingController _optionsController;
  late final TextEditingController _instructionController;
  late ComposerFieldType _type;
  late bool _required;
  late bool _safetyCritical;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.field.key);
    _labelController = TextEditingController(text: widget.field.label);
    _unitController = TextEditingController(text: widget.field.unit ?? '');
    _optionsController = TextEditingController(
      text: widget.field.options.join(', '),
    );
    _instructionController = TextEditingController(
      text: widget.field.instructionText,
    );
    _type = widget.field.type;
    _required = widget.field.isRequired;
    _safetyCritical = widget.field.isSafetyCriticalPreset;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    _unitController.dispose();
    _optionsController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit field'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _keyController,
                decoration: const InputDecoration(labelText: 'Field key'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<ComposerFieldType>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Field type'),
                items:
                    ComposerFieldType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_enumLabel(type.name)),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit / source unit',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _optionsController,
                decoration: const InputDecoration(
                  labelText: 'Options, comma-separated',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _instructionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instruction / evidence guidance',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required field'),
                onChanged:
                    (value) => setState(() => _required = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _safetyCritical,
                title: const Text('Safety-critical preset / governed field'),
                subtitle: const Text(
                  'Deletion/material weakening should require justification.',
                ),
                onChanged:
                    (value) => setState(() => _safetyCritical = value ?? false),
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
            Navigator.pop(
              context,
              ComposerFieldDraft(
                key: _slugKey(_keyController.text),
                label:
                    _labelController.text.trim().isEmpty
                        ? 'Field'
                        : _labelController.text.trim(),
                type: _type,
                isRequired: _required,
                order: widget.field.order,
                unit:
                    _unitController.text.trim().isEmpty
                        ? null
                        : _unitController.text.trim(),
                options: _splitComma(_optionsController.text),
                instructionText: _instructionController.text.trim(),
                validation: Map<String, dynamic>.from(widget.field.validation),
                meta: Map<String, dynamic>.from(widget.field.meta),
                isSafetyCriticalPreset: _safetyCritical,
                sourcePresetId: widget.field.sourcePresetId,
              ),
            );
          },
          child: const Text('Save field'),
        ),
      ],
    );
  }
}

class _ChecklistEditorDialog extends StatefulWidget {
  final ComposerChecklistItemDraft item;

  const _ChecklistEditorDialog({required this.item});

  @override
  State<_ChecklistEditorDialog> createState() => _ChecklistEditorDialogState();
}

class _ChecklistEditorDialogState extends State<_ChecklistEditorDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkedFieldController;
  late final TextEditingController _safetyController;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.item.id);
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _linkedFieldController = TextEditingController(
      text: widget.item.linkedFieldKey ?? '',
    );
    _safetyController = TextEditingController(
      text: widget.item.safetyClasses.join(', '),
    );
    _required = widget.item.isRequired;
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _linkedFieldController.dispose();
    _safetyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit checklist item'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Item id'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description / instruction',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _linkedFieldController,
                decoration: const InputDecoration(
                  labelText: 'Linked field key, optional',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _safetyController,
                decoration: const InputDecoration(
                  labelText: 'Safety classes, comma-separated',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _required,
                title: const Text('Required checklist item'),
                onChanged:
                    (value) => setState(() => _required = value ?? false),
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
            Navigator.pop(
              context,
              ComposerChecklistItemDraft(
                id:
                    _idController.text.trim().isEmpty
                        ? widget.item.id
                        : _idController.text.trim(),
                title:
                    _titleController.text.trim().isEmpty
                        ? 'Checklist item'
                        : _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                isRequired: _required,
                order: widget.item.order,
                linkedFieldKey:
                    _linkedFieldController.text.trim().isEmpty
                        ? null
                        : _linkedFieldController.text.trim(),
                safetyClasses: _splitComma(_safetyController.text),
                metadata: Map<String, dynamic>.from(widget.item.metadata),
              ),
            );
          },
          child: const Text('Save item'),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: BafColors.textSecondary),
    filled: true,
    fillColor: BafColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
  );
}

List<String> _splitComma(String value) {
  return value
      .split(RegExp(r'[,;|]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _slugKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _ownerFromDiscipline(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return 'mechanical';
    case JobModuleDiscipline.electrical:
      return 'electrical';
    case JobModuleDiscipline.instrumentation:
      return 'instrumentation';
    case JobModuleDiscipline.operations:
      return 'operations';
    case JobModuleDiscipline.shared:
      return 'shared';
    default:
      return 'others';
  }
}

String _normaliseSafetyText(String value) =>
    _slugKey(value).replaceAll('_', '');

bool _moduleLooksSafetyCritical(ComposerModuleDraft module) {
  final text = module.safetyClasses.join(' ').toLowerCase();
  return text.contains('gas') ||
      text.contains('hydrogen') ||
      text.contains('explosion') ||
      text.contains('loto') ||
      text.contains('interlock') ||
      text.contains('hydraulic') ||
      text.contains('water') ||
      text.contains('combustion');
}

bool _seedSuggestsClosureCritical(BafModuleSeed seed) {
  final text =
      [
        seed.defaultSafetyClass.name,
        seed.componentGroup,
        seed.functionalSection,
        ...seed.safetyConfirmations,
      ].join(' ').toLowerCase();
  return text.contains('gas') ||
      text.contains('hydrogen') ||
      text.contains('pressure') ||
      text.contains('loto') ||
      text.contains('safety') ||
      text.contains('clamp') ||
      text.contains('water') ||
      text.contains('combustion');
}

List<String> _extractTagsFromSeed(BafModuleSeed seed) {
  final tags = <String>{};
  final pattern = RegExp(r'\b[A-Z]{1,5}\d{1,3}[A-Z]?\b');
  for (final text in [
    seed.moduleTitle,
    seed.functionalSection,
    seed.componentGroup,
    ...seed.fields.map((field) => field.fieldId),
    ...seed.fields.map((field) => field.label),
    ...seed.standardItems.map((item) => item.title),
  ]) {
    for (final match in pattern.allMatches(text.toUpperCase())) {
      tags.add(match.group(0)!);
    }
  }
  return tags.toList()..sort();
}

ComposerFieldDraft _fieldFromSeed(
  BafModuleFieldSeed seedField,
  int order,
  BafModuleSeed parent,
) {
  final type = switch (seedField.type.toLowerCase()) {
    'boolean' || 'bool' => ComposerFieldType.yesNo,
    'enum' => ComposerFieldType.dropdown,
    'numeric' => ComposerFieldType.number,
    'numericwithunit' => ComposerFieldType.numericWithUnit,
    'multiselect' => ComposerFieldType.multiSelect,
    'longtext' => ComposerFieldType.longText,
    _ => ComposerFieldType.text,
  };
  final safety = _seedSuggestsClosureCritical(parent);
  return ComposerFieldDraft(
    key: _slugKey(seedField.fieldId),
    label: seedField.label,
    type: type,
    isRequired: seedField.required || safety,
    order: order,
    unit: seedField.unit,
    options: List<String>.from(seedField.options),
    instructionText: 'Cloned from seed catalogue ${parent.moduleCode}.',
    isSafetyCriticalPreset: safety,
    sourcePresetId: '${parent.moduleCode}:${seedField.fieldId}',
    meta: <String, dynamic>{
      'sourceSeedCode': parent.moduleCode,
      'sourceFieldId': seedField.fieldId,
      'isSafetyCriticalPreset': safety,
    },
  );
}

String _assetLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Forced Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
  }
}

String _disciplineLabel(JobModuleDiscipline discipline) =>
    _enumLabel(discipline.name);

String _enumLabel(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => ' ${match.group(0)}',
  );
  return spaced
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            part.length == 1
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String _readinessLabel(ComposerReadiness readiness) =>
    _enumLabel(readiness.name);

Color _readinessColor(ComposerReadiness readiness) {
  switch (readiness) {
    case ComposerReadiness.readyPreset:
      return BafColors.success;
    case ComposerReadiness.needsReview:
      return BafColors.warning;
    case ComposerReadiness.consultRequired:
      return BafColors.danger;
    case ComposerReadiness.tagOnly:
      return BafColors.sync;
    case ComposerReadiness.troubleshootingOnly:
      return BafColors.maintenance;
    case ComposerReadiness.futureIntegration:
      return BafColors.planned;
    case ComposerReadiness.referenceOnly:
      return BafColors.textSecondary;
  }
}

String _compactPreview(String jsonText) {
  try {
    final decoded = jsonDecode(jsonText);
    final compact = const JsonEncoder.withIndent('  ').convert(decoded);
    return compact.length > _jsonPreviewMaxChars
        ? '${compact.substring(0, _jsonPreviewMaxChars)}\n…'
        : compact;
  } catch (_) {
    return jsonText.length > _jsonPreviewMaxChars
        ? '${jsonText.substring(0, _jsonPreviewMaxChars)}\n…'
        : jsonText;
  }
}
