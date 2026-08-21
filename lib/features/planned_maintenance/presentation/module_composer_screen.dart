import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
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

part 'module_composer_screen.builders.dart';
part 'module_composer_screen.actions.dart';
part 'module_composer_screen.support.dart';
part 'module_composer_screen.helpers.dart';
part 'module_composer_widgets.dart';
part 'module_composer_dialogs.dart';

const int _jsonPreviewMaxChars = 2200;

class ModuleComposerScreen extends ConsumerStatefulWidget {
  final String initialJobTemplateJson;
  final String initialModuleSnapshotsJson;
  final String initialFieldDefinitionsJson;
  final String initialChecklistJson;
  final String recoveryScopeId;
  final bool canSeedCloudKnowledge;
  final bool showSaveToPublisher;
  final TemplateVersion? initialTemplateVersion;
  final Future<BafKnowledgeBundle> Function()? knowledgeBundleLoader;

  const ModuleComposerScreen({
    super.key,
    required this.initialJobTemplateJson,
    required this.initialModuleSnapshotsJson,
    required this.initialFieldDefinitionsJson,
    required this.initialChecklistJson,
    this.recoveryScopeId = 'default',
    this.canSeedCloudKnowledge = false,
    this.showSaveToPublisher = true,
    this.initialTemplateVersion,
    this.knowledgeBundleLoader,
  });

  @override
  ConsumerState<ModuleComposerScreen> createState() =>
      _ModuleComposerScreenState();
}

class _ModuleComposerScreenState extends ConsumerState<ModuleComposerScreen> {
  late TemplateComposerDraft _draft;
  String? _initialPayloadError;
  TemplateVersion? _editingTemplateVersion;
  String? _editingTemplateDraftFingerprint;
  int _selectedModuleIndex = -1;
  final Set<int> _mergeSelection = <int>{};
  String _knowledgeQuery = '';
  String _seedQuery = '';
  ComposerReadiness? _readinessFilter;
  late final TextEditingController _titleController;
  final _tagController = TextEditingController();
  BafKnowledgeRepository? _knowledgeRepository;
  BafTagResolution? _lastTagResolution;
  bool _showJsonPreview = false;
  bool _isLoadingKnowledge = true;
  bool _isSeedingCloud = false;
  bool _suppressRecoverySave = false;
  String? _initializingForActorUid;
  String? _initializedForActorUid;
  String? _governedAssetClassId;
  String? _governedDefinitionNodeId;
  Timer? _recoverySaveDebounce;
  List<BafKnowledgeEntry> _knowledgeRows = BafKnowledgeLayer.entries;
  BafKnowledgeMatrixMeta _matrixMeta = BafKnowledgeMatrixMeta.staticFallback();

  @override
  void initState() {
    super.initState();
    try {
      _draft =
          _hasCanonicalFreshAuthoringSeed()
              ? TemplateComposerDraft.empty()
              : TemplateComposerDraft.fromAuthoringPayloads(
                jobTemplateSnapshotJson: widget.initialJobTemplateJson,
                moduleSnapshotsJson: widget.initialModuleSnapshotsJson,
                fieldDefinitionsJson: widget.initialFieldDefinitionsJson,
                checklistJson: widget.initialChecklistJson,
              );
    } on FormatException catch (error) {
      _initialPayloadError = error.message;
      _draft = TemplateComposerDraft.empty();
    }
    final hierarchyReference = _draft.assetHierarchyReference;
    _governedAssetClassId = hierarchyReference?.assetClassId;
    _governedDefinitionNodeId = hierarchyReference?.nodeId;
    _titleController = TextEditingController(text: _draft.title);
    _editingTemplateVersion = widget.initialTemplateVersion;
    _draft.localId =
        widget.initialTemplateVersion?.firestoreId ?? _stableDraftLocalId();
    _applyMatrixMetaToDraft();
    if (_editingTemplateVersion != null) {
      _editingTemplateDraftFingerprint =
          ModuleComposerJsonBuilder.semanticFingerprint(_draft);
    }
    if (_draft.modules.isNotEmpty) {
      _selectedModuleIndex = 0;
    }
  }

  bool _hasCanonicalFreshAuthoringSeed() {
    return widget.initialJobTemplateJson.trim() == '{}' &&
        widget.initialModuleSnapshotsJson.trim() == '[]' &&
        widget.initialFieldDefinitionsJson.trim() == '[]' &&
        widget.initialChecklistJson.trim() == '[]';
  }

  void _scheduleAuthorizedInitialization(String actorUid) {
    if (_initialPayloadError != null ||
        _initializedForActorUid == actorUid ||
        _initializingForActorUid == actorUid) {
      return;
    }
    _initializingForActorUid = actorUid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_hasLiveComposerAuthority(expectedUid: actorUid)) {
        _initializingForActorUid = null;
        return;
      }
      await _loadKnowledgeRows();
      if (!mounted || !_hasLiveComposerAuthority(expectedUid: actorUid)) {
        _initializingForActorUid = null;
        return;
      }
      _setStateWithoutRecoverySave(() {
        _initializedForActorUid = actorUid;
        _initializingForActorUid = null;
      });
      await _checkForRecoverableDraft();
    });
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
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return const _ComposerAuthorityState(
        message: 'Checking template-authoring access...',
        showProgress: true,
      );
    }
    if (actorAsync.hasError) {
      _initializedForActorUid = null;
      return const _ComposerAuthorityState(
        title: 'Authoring access could not be verified',
        message:
            'The live access profile is unavailable. The composer stayed closed.',
      );
    }
    final actor = actorAsync.asData?.value;
    if (actor == null || !actor.canManageTemplateGovernance) {
      _initializedForActorUid = null;
      return const _ComposerAuthorityState(
        title: 'Template authoring access required',
        message:
            'This workspace is available only to approved Admin and SI users.',
      );
    }

    final initialPayloadError = _initialPayloadError;
    if (initialPayloadError != null) {
      return Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Module composer',
            subtitle: 'Build governed work modules and evidence fields',
            icon: Icons.architecture_outlined,
            accent: BafColors.planned,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(BafSpacing.lg),
                child: PersistedDataIntegrityNotice(
                  title: 'Saved composer payload needs repair',
                  message:
                      'The saved template was left unchanged and authoring is blocked until its payload is repaired. $initialPayloadError',
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_initializedForActorUid != actor.uid) {
      _scheduleAuthorizedInitialization(actor.uid);
      return const _ComposerAuthorityState(
        message: 'Preparing the governed authoring workspace...',
        showProgress: true,
      );
    }
    final validation = ModuleComposerValidator.validate(_draft);
    final canManageRegistry = actor.canManageTemplateGovernance;
    final canPreparePublish = actor.canPublishTemplateVersion;
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0.4,
        title: const BafAppBarTitle(
          title: 'Module composer',
          subtitle: 'Build governed work modules and evidence fields',
          icon: Icons.architecture_outlined,
          accent: BafColors.planned,
        ),
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
}

class _ComposerAuthorityState extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;

  const _ComposerAuthorityState({
    this.title = 'Module Composer',
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showProgress) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Module composer',
        appBarSubtitle: 'Build governed work modules and evidence fields',
        appBarIcon: Icons.architecture_outlined,
        accent: BafColors.planned,
        label: message,
      );
    }
    return BafScreenStateScaffold.access(
      appBarTitle: 'Module composer',
      appBarSubtitle: 'Build governed work modules and evidence fields',
      appBarIcon: Icons.architecture_outlined,
      accent: BafColors.planned,
      title: title,
      message: message,
    );
  }
}
