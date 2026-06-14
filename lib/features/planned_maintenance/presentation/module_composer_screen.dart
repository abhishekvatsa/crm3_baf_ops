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
  final String actorUid;
  final String actorName;
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
    this.actorUid = '',
    this.actorName = '',
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
  TemplateVersion? _editingTemplateVersion;
  String? _editingTemplateDraftFingerprint;
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
}
