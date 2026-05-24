// FILE: lib/features/planned_maintenance/presentation/template_publisher_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/template_governance_model.dart';
import '../providers/template_governance_provider.dart';
import '../domain/module_composer_models.dart';
import '../domain/template_version_snapshot_contract.dart';
import 'module_composer_screen.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

const _newPackageSentinel = '__new_template_package__';

class TemplatePublisherScreen extends ConsumerStatefulWidget {
  const TemplatePublisherScreen({super.key});

  @override
  ConsumerState<TemplatePublisherScreen> createState() =>
      _TemplatePublisherScreenState();
}

class _TemplatePublisherScreenState
    extends ConsumerState<TemplatePublisherScreen> {
  final _packageCodeController = TextEditingController();
  final _packageTitleController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _assetTypeController = TextEditingController(text: 'furnace');
  final _assetScopeController = TextEditingController();

  final _versionLabelController = TextEditingController(text: 'v1');
  final _releaseNotesController = TextEditingController();
  final _changeSummaryController = TextEditingController();
  final _minAppVersionController = TextEditingController();
  final _publishReasonController = TextEditingController(
    text: 'Initial governed BAF catalogue publish.',
  );

  final _jobTemplateJsonController = TextEditingController(text: '{\n  \n}');
  final _moduleSnapshotsJsonController = TextEditingController(
    text: '[\n  \n]',
  );
  final _fieldDefinitionsJsonController = TextEditingController(
    text: '[\n  \n]',
  );
  final _checklistJsonController = TextEditingController(text: '[\n  \n]');

  final _selectedDisciplines = <String>{'mechanical'};
  String? _selectedPackageId = _newPackageSentinel;
  TemplatePackage? _selectedPackage;
  TemplateVersion? _workingDraft;
  bool _isPublishing = false;
  bool _hasLoadedInitialPackage = false;

  final Map<String, _CachedJsonCheck> _jsonValidationCache =
      <String, _CachedJsonCheck>{};
  String? _lastHashInputFingerprint;
  String? _cachedPreviewHash;

  static const _disciplineOptions = <_DisciplineOption>[
    _DisciplineOption('mechanical', 'Mechanical', Icons.settings_rounded),
    _DisciplineOption(
      'electrical',
      'Electrical',
      Icons.electrical_services_rounded,
    ),
    _DisciplineOption('instrumentation', 'I&A', Icons.sensors_rounded),
    _DisciplineOption(
      'operations',
      'Operations',
      Icons.supervisor_account_rounded,
    ),
    _DisciplineOption(
      'refractory',
      'Refractory',
      Icons.local_fire_department_rounded,
    ),
    _DisciplineOption('safety', 'Safety', Icons.health_and_safety_rounded),
    _DisciplineOption('shared', 'Shared', Icons.hub_rounded),
  ];

  @override
  void dispose() {
    _packageCodeController.dispose();
    _packageTitleController.dispose();
    _packageDescriptionController.dispose();
    _assetTypeController.dispose();
    _assetScopeController.dispose();
    _versionLabelController.dispose();
    _releaseNotesController.dispose();
    _changeSummaryController.dispose();
    _minAppVersionController.dispose();
    _publishReasonController.dispose();
    _jobTemplateJsonController.dispose();
    _moduleSnapshotsJsonController.dispose();
    _fieldDefinitionsJsonController.dispose();
    _checklistJsonController.dispose();
    _jsonValidationCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);

    return userAsync.when(
      loading:
          () => const Scaffold(
            backgroundColor: BafColors.background,
            body: Center(child: CircularProgressIndicator()),
          ),
      error: (e, _) => _ErrorScaffold(message: 'User profile error: $e'),
      data: (actor) {
        if (actor == null || !actor.canManageTemplateGovernance) {
          return const _AccessDeniedScaffold();
        }

        final packagesAsync = ref.watch(templatePackagesProvider);
        return packagesAsync.when(
          loading:
              () => const Scaffold(
                backgroundColor: BafColors.background,
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (e, _) => _ErrorScaffold(message: 'Template package error: $e'),
          data: (packages) => _buildPublisher(context, actor, packages),
        );
      },
    );
  }

  Widget _buildPublisher(
    BuildContext context,
    AppUser actor,
    List<TemplatePackage> packages,
  ) {
    _hydrateInitialPackage(packages);

    final validation = _buildValidation();
    final selectedPackageId = _selectedPackage?.firestoreId;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Template Authoring'),
        centerTitle: false,
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0.4,
        actions: [
          IconButton(
            tooltip: 'Open Module Composer',
            onPressed: () => _openModuleComposer(actor),
            icon: const Icon(Icons.architecture_rounded),
          ),
          const Padding(
            padding: EdgeInsets.only(right: BafSpacing.md),
            child: StatusBadge(
              label: 'Admin/SI',
              color: BafColors.admin,
              icon: Icons.verified_user_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          // Scaffold already reserves body-space above bottomNavigationBar.
          // Adding viewPadding.bottom here was double-counting the system inset.
          padding: const EdgeInsets.all(BafSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PublisherHeader(validation: validation),
                    const SizedBox(height: BafSpacing.lg),
                    _ComposerQuickStartSection(
                      validation: validation,
                      onOpenComposer: () => _openModuleComposer(actor),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _PackageSection(
                      packages: packages,
                      selectedPackageId: _selectedPackageId,
                      packageCodeController: _packageCodeController,
                      packageTitleController: _packageTitleController,
                      descriptionController: _packageDescriptionController,
                      assetTypeController: _assetTypeController,
                      assetScopeController: _assetScopeController,
                      onPackageChanged: (id) => _selectPackage(id, packages),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _DisciplineSection(
                      selectedDisciplines: _selectedDisciplines,
                      options: _disciplineOptions,
                      onToggle: _toggleDiscipline,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _VersionSection(
                      nextVersionNumber: _nextVersionNumber(),
                      versionLabelController: _versionLabelController,
                      releaseNotesController: _releaseNotesController,
                      changeSummaryController: _changeSummaryController,
                      minAppVersionController: _minAppVersionController,
                      publishReasonController: _publishReasonController,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _JsonPayloadSection(
                      jobTemplateJsonController: _jobTemplateJsonController,
                      moduleSnapshotsJsonController:
                          _moduleSnapshotsJsonController,
                      fieldDefinitionsJsonController:
                          _fieldDefinitionsJsonController,
                      checklistJsonController: _checklistJsonController,
                      onChanged: () => setState(() {}),
                      onOpenComposer: () => _openModuleComposer(actor),
                      onPretty: _prettyFormat,
                      onPaste: _pasteFromClipboard,
                      onClear: _clearJson,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _ValidationSection(validation: validation),
                    if (selectedPackageId != null) ...[
                      const SizedBox(height: BafSpacing.lg),
                      _ExistingVersionsSection(
                        packageFirestoreId: selectedPackageId,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _PublishBar(
        validation: validation,
        isPublishing: _isPublishing,
        onOpenComposer: () => _openModuleComposer(actor),
        onSaveDraft: () => _saveDraft(actor),
        onPublish: () => _publish(actor),
        onReset: _resetVersionPayloads,
      ),
    );
  }

  void _hydrateInitialPackage(List<TemplatePackage> packages) {
    if (_hasLoadedInitialPackage) return;

    if (packages.isEmpty) return;
    final sorted =
        packages.where((package) => package.firestoreId != null).toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    if (sorted.isEmpty) return;
    _selectPackage(sorted.first.firestoreId, sorted, silent: true);
    _hasLoadedInitialPackage = true;
  }

  void _selectPackage(
    String? selectedId,
    List<TemplatePackage> packages, {
    bool silent = false,
  }) {
    final id = selectedId == _newPackageSentinel ? null : selectedId;
    final package = id == null ? null : _findPackageById(packages, id);

    void apply() {
      _selectedPackageId = id ?? _newPackageSentinel;
      _selectedPackage = package;
      _workingDraft = null;

      if (package == null) {
        _packageCodeController.clear();
        _packageTitleController.clear();
        _packageDescriptionController.clear();
        _assetTypeController.text = 'furnace';
        _assetScopeController.clear();
        _selectedDisciplines
          ..clear()
          ..add('mechanical');
        _versionLabelController.text = 'v1';
        return;
      }

      _packageCodeController.text = package.packageCode;
      _packageTitleController.text = package.title;
      _packageDescriptionController.text = package.description ?? '';
      _assetTypeController.text = package.assetType ?? 'furnace';
      _assetScopeController.text = package.assetNumberScope ?? '';
      _selectedDisciplines
        ..clear()
        ..addAll(_parseDisciplineScope(package.disciplineScope));
      if (_selectedDisciplines.isEmpty) _selectedDisciplines.add('mechanical');
      _versionLabelController.text =
          'v${_nextVersionNumber(packageOverride: package)}';
    }

    if (silent) {
      apply();
    } else {
      setState(apply);
    }
  }

  TemplatePackage? _findPackageById(List<TemplatePackage> packages, String id) {
    for (final package in packages) {
      if (package.firestoreId == id) return package;
    }
    return null;
  }

  Set<String> _parseDisciplineScope(String? value) {
    if (value == null || value.trim().isEmpty) return <String>{};
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  void _toggleDiscipline(String discipline) {
    setState(() {
      if (_selectedDisciplines.contains(discipline)) {
        if (_selectedDisciplines.length > 1) {
          _selectedDisciplines.remove(discipline);
        }
      } else {
        _selectedDisciplines.add(discipline);
      }
    });
  }

  int _nextVersionNumber({TemplatePackage? packageOverride}) {
    final package = packageOverride ?? _selectedPackage;
    final latest = package?.latestVersionNumber ?? 0;
    return latest + 1;
  }

  _ValidationResult _buildDraftSaveValidation() {
    final errors = <String>[];
    final warnings = <String>[];

    if (_packageCodeController.text.trim().isEmpty) {
      errors.add('Package code is required before saving a draft.');
    }
    if (_packageTitleController.text.trim().isEmpty) {
      errors.add('Package title is required before saving a draft.');
    }
    if (_selectedDisciplines.isEmpty) {
      errors.add(
        'At least one discipline must be assigned before saving a draft.',
      );
    }

    final jobTemplateCheck = _validateJsonCached(
      _jobTemplateJsonController.text,
      label: 'draft.jobTemplateSnapshotJson',
      expectedRoot: _JsonRoot.object,
      allowEmpty: true,
    );
    final moduleCheck = _validateJsonCached(
      _moduleSnapshotsJsonController.text,
      label: 'draft.moduleSnapshotsJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: true,
    );
    final fieldCheck = _validateJsonCached(
      _fieldDefinitionsJsonController.text,
      label: 'draft.fieldDefinitionsJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: true,
    );
    final checklistCheck = _validateJsonCached(
      _checklistJsonController.text,
      label: 'draft.checklistJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: true,
    );

    for (final check in [
      jobTemplateCheck,
      moduleCheck,
      fieldCheck,
      checklistCheck,
    ]) {
      if (check.error != null) errors.add(check.error!);
      if (check.warning != null) warnings.add(check.warning!);
    }

    if (errors.isEmpty && warnings.isEmpty) {
      warnings.add(
        'Draft saved without publish validation. Run full publisher validation before publishing.',
      );
    }

    return _ValidationResult(
      errors: errors,
      warnings: warnings,
      contentHash: _previewHashIfPossible(),
      moduleCount: moduleCheck.itemCount,
      fieldCount: fieldCheck.itemCount,
      checklistCount: checklistCheck.itemCount,
      canSaveDraftOverride: errors.isEmpty,
    );
  }

  _ValidationResult _buildValidation() {
    final errors = <String>[];
    final warnings = <String>[];

    if (_packageCodeController.text.trim().isEmpty) {
      errors.add('Package code is required.');
    }
    if (_packageTitleController.text.trim().isEmpty) {
      errors.add('Package title is required.');
    }
    if (_selectedDisciplines.isEmpty) {
      errors.add('At least one discipline must be assigned.');
    }
    if (_publishReasonController.text.trim().isEmpty) {
      warnings.add('Publish reason is empty. Audit trail will be less useful.');
    }

    final jobTemplateCheck = _validateJsonCached(
      _jobTemplateJsonController.text,
      label: 'jobTemplateSnapshotJson',
      expectedRoot: _JsonRoot.object,
      allowEmpty: false,
    );
    final moduleCheck = _validateJsonCached(
      _moduleSnapshotsJsonController.text,
      label: 'moduleSnapshotsJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: false,
    );
    final fieldCheck = _validateJsonCached(
      _fieldDefinitionsJsonController.text,
      label: 'fieldDefinitionsJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: false,
    );
    final checklistCheck = _validateJsonCached(
      _checklistJsonController.text,
      label: 'checklistJson',
      expectedRoot: _JsonRoot.list,
      allowEmpty: true,
    );

    for (final check in [
      jobTemplateCheck,
      moduleCheck,
      fieldCheck,
      checklistCheck,
    ]) {
      if (check.error != null) errors.add(check.error!);
      if (check.warning != null) warnings.add(check.warning!);
    }

    if (jobTemplateCheck.error == null &&
        moduleCheck.error == null &&
        fieldCheck.error == null &&
        checklistCheck.error == null) {
      final semanticValidation = _validatePublisherPayloadSemantics();
      errors.addAll(semanticValidation.errors);
      warnings.addAll(semanticValidation.warnings);
    }

    final hash = _previewHashIfPossible();
    return _ValidationResult(
      errors: errors,
      warnings: warnings,
      contentHash: hash,
      moduleCount: moduleCheck.itemCount,
      fieldCount: fieldCheck.itemCount,
      checklistCount: checklistCheck.itemCount,
    );
  }

  _JsonCheck _validateJsonCached(
    String raw, {
    required String label,
    required _JsonRoot expectedRoot,
    required bool allowEmpty,
  }) {
    final cached = _jsonValidationCache[label];
    if (cached != null &&
        cached.raw == raw &&
        cached.expectedRoot == expectedRoot &&
        cached.allowEmpty == allowEmpty) {
      return cached.result;
    }

    final result = _validateJson(
      raw,
      label: label,
      expectedRoot: expectedRoot,
      allowEmpty: allowEmpty,
    );
    _jsonValidationCache[label] = _CachedJsonCheck(
      raw: raw,
      expectedRoot: expectedRoot,
      allowEmpty: allowEmpty,
      result: result,
    );
    return result;
  }

  _JsonCheck _validateJson(
    String raw, {
    required String label,
    required _JsonRoot expectedRoot,
    required bool allowEmpty,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return _JsonCheck(error: '$label cannot be empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (e) {
      return _JsonCheck(error: '$label is not valid JSON: $e');
    }

    if (expectedRoot == _JsonRoot.object && decoded is! Map<String, dynamic>) {
      return _JsonCheck(error: '$label must be a JSON object.');
    }
    if (expectedRoot == _JsonRoot.list && decoded is! List) {
      return _JsonCheck(error: '$label must be a JSON array.');
    }

    final itemCount =
        decoded is List
            ? decoded.length
            : (decoded is Map ? decoded.length : 0);
    if (!allowEmpty && itemCount == 0) {
      return _JsonCheck(error: '$label must contain at least one item.');
    }
    if (decoded is List && decoded.any((item) => item is! Map)) {
      return _JsonCheck(error: '$label must contain JSON object entries only.');
    }

    final normalizedJson = const JsonEncoder.withIndent('  ').convert(decoded);

    if (label == 'fieldDefinitionsJson' && decoded is List) {
      final missingLabels =
          decoded.where((item) {
            if (item is! Map) return true;
            final key = item['key']?.toString().trim() ?? '';
            final label = item['label']?.toString().trim() ?? '';
            return key.isEmpty || label.isEmpty;
          }).length;
      if (missingLabels > 0) {
        return _JsonCheck(
          itemCount: itemCount,
          warning:
              '$missingLabels field definition(s) are missing key or label.',
          normalizedJson: normalizedJson,
        );
      }
    }

    return _JsonCheck(itemCount: itemCount, normalizedJson: normalizedJson);
  }

  _PublisherPayloadSemanticResult _validatePublisherPayloadSemantics() {
    try {
      final snapshotBundle = TemplateVersionSnapshotBundle.fromRawJson(
        jobTemplateSnapshotJson: _jobTemplateJsonController.text,
        moduleSnapshotsJson: _moduleSnapshotsJsonController.text,
        fieldDefinitionsJson: _fieldDefinitionsJsonController.text,
        checklistJson: _checklistJsonController.text,
      );
      final validation = snapshotBundle.validate();
      return _PublisherPayloadSemanticResult(
        errors: validation.errors,
        warnings: validation.warnings,
      );
    } on TemplateVersionSnapshotException catch (error) {
      return _PublisherPayloadSemanticResult(errors: <String>[error.message]);
    }
  }

  String? _previewHashIfPossible() {
    final orderedDisciplines = _selectedDisciplines.toList()..sort();
    final fingerprint = <String>[
      _jobTemplateJsonController.text,
      _moduleSnapshotsJsonController.text,
      _fieldDefinitionsJsonController.text,
      _checklistJsonController.text,
      orderedDisciplines.join(','),
      _packageCodeController.text.trim(),
      _assetTypeController.text.trim(),
    ].join('\u001f');

    if (_lastHashInputFingerprint == fingerprint) return _cachedPreviewHash;

    try {
      final version =
          TemplateVersion()
            ..jobTemplateSnapshotJson = _normalizedJsonForPreview(
              _jobTemplateJsonController.text,
              label: 'jobTemplateSnapshotJson',
              expectedRoot: _JsonRoot.object,
              allowEmpty: false,
            )
            ..moduleSnapshotsJson = _normalizedJsonForPreview(
              _moduleSnapshotsJsonController.text,
              label: 'moduleSnapshotsJson',
              expectedRoot: _JsonRoot.list,
              allowEmpty: false,
            )
            ..fieldDefinitionsJson = _normalizedJsonForPreview(
              _fieldDefinitionsJsonController.text,
              label: 'fieldDefinitionsJson',
              expectedRoot: _JsonRoot.list,
              allowEmpty: false,
            )
            ..checklistJson = _normalizedJsonForPreview(
              _checklistJsonController.text,
              label: 'checklistJson',
              expectedRoot: _JsonRoot.list,
              allowEmpty: true,
            )
            ..metadataJson = _buildVersionMetadataJson();
      _cachedPreviewHash = version.computeContentHash();
    } catch (_) {
      _cachedPreviewHash = null;
    }

    _lastHashInputFingerprint = fingerprint;
    return _cachedPreviewHash;
  }

  String _normalizedJsonForPreview(
    String raw, {
    required String label,
    required _JsonRoot expectedRoot,
    required bool allowEmpty,
  }) {
    final check = _validateJsonCached(
      raw,
      label: label,
      expectedRoot: expectedRoot,
      allowEmpty: allowEmpty,
    );
    if (check.error != null || check.normalizedJson == null) {
      throw FormatException(check.error ?? 'Invalid JSON payload for $label.');
    }
    return check.normalizedJson!;
  }

  String _normalizedJson(String raw) {
    final decoded = jsonDecode(raw.trim());
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  Future<void> _prettyFormat(TextEditingController controller) async {
    try {
      controller.text = _normalizedJson(controller.text);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      setState(() {});
      _showSnack('JSON formatted', BafColors.sync);
    } catch (e) {
      _showSnack('Cannot format JSON: $e', BafColors.danger);
    }
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      _showSnack('Clipboard is empty.', BafColors.warning);
      return;
    }
    controller.text = text;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {});
  }

  void _clearJson(TextEditingController controller, _JsonRoot root) {
    controller.text = root == _JsonRoot.object ? '{\n  \n}' : '[\n  \n]';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {});
  }

  Future<void> _openModuleComposer(AppUser actor) async {
    final output = await Navigator.of(context).push<TemplateComposerOutput>(
      MaterialPageRoute(
        builder:
            (_) => ModuleComposerScreen(
              initialJobTemplateJson: _jobTemplateJsonController.text,
              initialModuleSnapshotsJson: _moduleSnapshotsJsonController.text,
              initialFieldDefinitionsJson: _fieldDefinitionsJsonController.text,
              initialChecklistJson: _checklistJsonController.text,
              recoveryScopeId:
                  _selectedPackage?.firestoreId ??
                  _packageCodeController.text.trim(),
              actorUid: actor.uid,
              actorName: actor.name,
              canSeedCloudKnowledge: actor.canManageTemplateGovernance,
            ),
      ),
    );

    if (!mounted || output == null) return;

    final shouldReplace = await _confirmComposerPayloadReplace();
    if (!mounted || !shouldReplace) return;

    setState(() {
      _jobTemplateJsonController.text = output.jobTemplateSnapshotJson;
      _moduleSnapshotsJsonController.text = output.moduleSnapshotsJson;
      _fieldDefinitionsJsonController.text = output.fieldDefinitionsJson;
      _checklistJsonController.text = output.checklistJson;
    });
    _showSnack(
      'Composer payload copied into publisher JSON fields.',
      BafColors.sync,
    );
  }

  Future<bool> _confirmComposerPayloadReplace() async {
    if (!_hasMeaningfulPublisherPayload()) return true;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Replace publisher JSON?'),
            content: const Text(
              'The Module Composer will replace the current JSON payloads in this draft. Existing pasted JSON will not be deleted from any published version, but the current editor fields will be overwritten.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Replace JSON'),
              ),
            ],
          ),
    );
    return result == true;
  }

  bool _hasMeaningfulPublisherPayload() {
    bool meaningful(String value, String emptyObject, String emptyList) {
      final canonical = value.replaceAll(RegExp(r'\s+'), '');
      return canonical.isNotEmpty &&
          canonical != emptyObject &&
          canonical != emptyList;
    }

    return meaningful(_jobTemplateJsonController.text, '{}', '[]') ||
        meaningful(_moduleSnapshotsJsonController.text, '{}', '[]') ||
        meaningful(_fieldDefinitionsJsonController.text, '{}', '[]') ||
        meaningful(_checklistJsonController.text, '{}', '[]');
  }

  Future<void> _saveDraft(AppUser actor) async {
    if (_isPublishing) return;
    final validation = _buildDraftSaveValidation();
    if (!validation.canSaveDraft) {
      _showValidationFailure(validation);
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final repo = ref.read(templateGovernanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final package = await _ensurePackageSaved(repo, actor);
      final version = _buildDraftVersion(package);
      await repo.saveVersion(version, actor: actor);
      _workingDraft = version;
      unawaited(
        syncCoordinator.runFullSync(
          reason: 'template_governance_draft_saved',
          force: true,
        ),
      );
      if (!mounted) return;
      _showSnack('Draft version saved.', BafColors.sync);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Draft save failed: $e', BafColors.danger);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _publish(AppUser actor) async {
    if (_isPublishing) return;
    final validation = _buildValidation();
    if (!validation.canPublish) {
      _showValidationFailure(validation);
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final repo = ref.read(templateGovernanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final package = await _ensurePackageSaved(repo, actor);
      final version = _buildDraftVersion(
        package,
        allocateFreshVersionNumber: true,
      );

      await repo.publishVersion(
        version,
        actor: actor,
        reason: _publishReasonController.text.trim(),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'template_governance_version_published',
          force: true,
        ),
      );

      if (!mounted) return;
      if (version.versionNumber > package.latestVersionNumber) {
        package.latestVersionNumber = version.versionNumber;
      }
      package.activeVersionFirestoreId = version.firestoreId;
      _selectedPackage = package;
      _selectedPackageId = package.firestoreId;
      _showSnack(
        'Published ${package.packageCode} v${version.versionNumber}.',
        BafColors.sync,
      );
      _workingDraft = null;
      _resetVersionPayloads(keepVersionLabel: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Publish failed: $e', BafColors.danger);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<TemplatePackage> _ensurePackageSaved(
    TemplateGovernanceRepository repo,
    AppUser actor,
  ) async {
    final package =
        _selectedPackage == null
            ? TemplatePackage()
            : _clonePackage(_selectedPackage!);

    package
      ..packageCode = _packageCodeController.text.trim()
      ..title = _packageTitleController.text.trim()
      ..description = _cleanOptional(_packageDescriptionController.text)
      ..assetType = _cleanOptional(_assetTypeController.text)
      ..assetNumberScope = _cleanOptional(_assetScopeController.text)
      ..disciplineScope = _currentDisciplineScope()
      ..lifecycleStatus = TemplatePackageLifecycleStatus.active;

    final shouldSavePackage =
        _selectedPackage == null || _packageDetailsChanged(_selectedPackage!);
    if (shouldSavePackage || package.firestoreId == null) {
      await repo.savePackage(package, actor: actor);
      _selectedPackage = package;
      _selectedPackageId = package.firestoreId;
    }

    return package;
  }

  TemplateVersion _buildDraftVersion(
    TemplatePackage package, {
    bool allocateFreshVersionNumber = false,
  }) {
    final version =
        _workingDraft == null
            ? TemplateVersion()
            : _cloneVersion(_workingDraft!);

    version
      ..packageFirestoreId = package.firestoreId
      ..versionNumber =
          allocateFreshVersionNumber
              ? _nextVersionNumber(packageOverride: package)
              : version.versionNumber > 0
              ? version.versionNumber
              : _nextVersionNumber(packageOverride: package)
      ..versionLabel = _cleanOptional(_versionLabelController.text)
      ..status = TemplateVersionStatus.draft
      ..jobTemplateSnapshotJson = _normalizedJson(
        _jobTemplateJsonController.text,
      )
      ..moduleSnapshotsJson = _normalizedJson(
        _moduleSnapshotsJsonController.text,
      )
      ..fieldDefinitionsJson = _normalizedJson(
        _fieldDefinitionsJsonController.text,
      )
      ..checklistJson = _normalizedJson(_checklistJsonController.text)
      ..releaseNotes = _cleanOptional(_releaseNotesController.text)
      ..changeSummary = _cleanOptional(_changeSummaryController.text)
      ..minAppVersion = _cleanOptional(_minAppVersionController.text)
      ..metadataJson = _buildVersionMetadataJson();
    version.refreshClosureReviewStateFromSnapshots();
    return version;
  }

  String _buildVersionMetadataJson() {
    return jsonEncode({
      'source': 'TemplatePublisherScreen',
      'disciplineScope': _selectedDisciplines.toList()..sort(),
      'packageCode': _packageCodeController.text.trim(),
      'assetType': _assetTypeController.text.trim(),
      'generatedAt': DateTime.now().toIso8601String(),
    });
  }

  bool _packageDetailsChanged(TemplatePackage package) {
    return package.packageCode.trim() != _packageCodeController.text.trim() ||
        package.title.trim() != _packageTitleController.text.trim() ||
        (package.description ?? '') !=
            _packageDescriptionController.text.trim() ||
        (package.assetType ?? '') != _assetTypeController.text.trim() ||
        (package.assetNumberScope ?? '') != _assetScopeController.text.trim() ||
        (package.disciplineScope ?? '') != _currentDisciplineScope();
  }

  String _currentDisciplineScope() {
    final ordered = _selectedDisciplines.toList()..sort();
    return ordered.join(',');
  }

  TemplateVersion _cloneVersion(TemplateVersion source) {
    return TemplateVersion()
      ..id = source.id
      ..firestoreId = source.firestoreId
      ..packageFirestoreId = source.packageFirestoreId
      ..isSynced = source.isSynced
      ..version = source.version
      ..schemaVersion = source.schemaVersion
      ..versionNumber = source.versionNumber
      ..versionLabel = source.versionLabel
      ..status = source.status
      ..sourceVersionFirestoreId = source.sourceVersionFirestoreId
      ..contentHash = source.contentHash
      ..jobTemplateSnapshotJson = source.jobTemplateSnapshotJson
      ..moduleSnapshotsJson = source.moduleSnapshotsJson
      ..fieldDefinitionsJson = source.fieldDefinitionsJson
      ..checklistJson = source.checklistJson
      ..releaseNotes = source.releaseNotes
      ..changeSummary = source.changeSummary
      ..closureReviewConfirmed = source.closureReviewConfirmed
      ..closureCriticalModuleCount = source.closureCriticalModuleCount
      ..closureReviewConfirmedByUid = source.closureReviewConfirmedByUid
      ..closureReviewConfirmedByName = source.closureReviewConfirmedByName
      ..closureReviewConfirmedAt = source.closureReviewConfirmedAt
      ..createdByUid = source.createdByUid
      ..createdByName = source.createdByName
      ..updatedByUid = source.updatedByUid
      ..updatedByName = source.updatedByName
      ..publishedByUid = source.publishedByUid
      ..publishedByName = source.publishedByName
      ..publishedAt = source.publishedAt
      ..retiredByUid = source.retiredByUid
      ..retiredByName = source.retiredByName
      ..retiredAt = source.retiredAt
      ..retireReason = source.retireReason
      ..minAppVersion = source.minAppVersion
      ..isDeleted = source.isDeleted
      ..deletedAt = source.deletedAt
      ..deletedByUid = source.deletedByUid
      ..deletedByName = source.deletedByName
      ..deleteReason = source.deleteReason
      ..createdAt = source.createdAt
      ..updatedAt = source.updatedAt
      ..targetRefs = List<String>.from(source.targetRefs)
      ..deviceTagRefs = List<String>.from(source.deviceTagRefs)
      ..safetyClass = source.safetyClass
      ..safetyGatePolicyJson = source.safetyGatePolicyJson
      ..procedureRefs = List<String>.from(source.procedureRefs)
      ..operationalStatePreconditions = List<String>.from(
        source.operationalStatePreconditions,
      )
      ..metadataJson = source.metadataJson;
  }

  TemplatePackage _clonePackage(TemplatePackage source) {
    return TemplatePackage()
      ..id = source.id
      ..firestoreId = source.firestoreId
      ..isSynced = source.isSynced
      ..version = source.version
      ..schemaVersion = source.schemaVersion
      ..packageCode = source.packageCode
      ..title = source.title
      ..description = source.description
      ..assetType = source.assetType
      ..assetNumberScope = source.assetNumberScope
      ..disciplineScope = source.disciplineScope
      ..lifecycleStatus = source.lifecycleStatus
      ..activeVersionFirestoreId = source.activeVersionFirestoreId
      ..latestVersionNumber = source.latestVersionNumber
      ..createdByUid = source.createdByUid
      ..createdByName = source.createdByName
      ..updatedByUid = source.updatedByUid
      ..updatedByName = source.updatedByName
      ..retiredByUid = source.retiredByUid
      ..retiredByName = source.retiredByName
      ..retiredAt = source.retiredAt
      ..retireReason = source.retireReason
      ..isDeleted = source.isDeleted
      ..deletedAt = source.deletedAt
      ..deletedByUid = source.deletedByUid
      ..deletedByName = source.deletedByName
      ..deleteReason = source.deleteReason
      ..createdAt = source.createdAt
      ..updatedAt = source.updatedAt
      ..targetRefs = List<String>.from(source.targetRefs)
      ..deviceTagRefs = List<String>.from(source.deviceTagRefs)
      ..safetyClass = source.safetyClass
      ..safetyGatePolicyJson = source.safetyGatePolicyJson
      ..procedureRefs = List<String>.from(source.procedureRefs)
      ..operationalStatePreconditions = List<String>.from(
        source.operationalStatePreconditions,
      )
      ..metadataJson = source.metadataJson;
  }

  void _showValidationFailure(_ValidationResult validation) {
    final first =
        validation.errors.isNotEmpty
            ? validation.errors.first
            : validation.warnings.firstOrNull ?? 'Validation failed.';
    _showSnack(first, BafColors.danger);
  }

  void _resetVersionPayloads({bool keepVersionLabel = true}) {
    setState(() {
      _workingDraft = null;
      if (!keepVersionLabel) {
        _versionLabelController.text = 'v${_nextVersionNumber()}';
      }
      _releaseNotesController.clear();
      _changeSummaryController.clear();
      _minAppVersionController.clear();
      _publishReasonController.text = 'Governed BAF catalogue publish.';
      _jobTemplateJsonController.text = '{\n  \n}';
      _moduleSnapshotsJsonController.text = '[\n  \n]';
      _fieldDefinitionsJsonController.text = '[\n  \n]';
      _checklistJsonController.text = '[\n  \n]';
    });
  }

  String? _cleanOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class _PublisherHeader extends StatelessWidget {
  final _ValidationResult validation;

  const _PublisherHeader({required this.validation});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(
            icon: Icons.publish_rounded,
            color: BafColors.planned,
            size: 56,
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BAF Template Authoring',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                const Text(
                  'Build modules through the Composer and Workshop, validate frozen snapshots, and publish immutable governed TemplateVersions. Advanced JSON panels remain available as controlled fallback.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: [
                    StatusBadge(
                      label:
                          validation.canPublish
                              ? 'Ready to publish'
                              : 'Draft incomplete',
                      color:
                          validation.canPublish
                              ? BafColors.success
                              : BafColors.warning,
                      icon:
                          validation.canPublish
                              ? Icons.verified_rounded
                              : Icons.rule_rounded,
                    ),
                    StatusBadge(
                      label: '${validation.moduleCount} modules',
                      color: BafColors.assets,
                      icon: Icons.view_module_rounded,
                    ),
                    StatusBadge(
                      label: '${validation.fieldCount} fields',
                      color: BafColors.audit,
                      icon: Icons.checklist_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerQuickStartSection extends StatelessWidget {
  final _ValidationResult validation;
  final VoidCallback onOpenComposer;

  const _ComposerQuickStartSection({
    required this.validation,
    required this.onOpenComposer,
  });

  @override
  Widget build(BuildContext context) {
    final hasGeneratedPayload =
        validation.moduleCount > 0 || validation.fieldCount > 0;

    return _Panel(
      title:
          hasGeneratedPayload
              ? 'Primary authoring path'
              : 'Start here: Module Composer',
      subtitle:
          'Use the Module Composer and Workshop to build, reuse, merge, and review modules before publishing. The advanced JSON publisher remains available for inspection and controlled recovery.',
      icon: Icons.architecture_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasGeneratedPayload
                    ? 'Composer payload detected in this draft.'
                    : 'Open Module Composer before publishing a new governed TemplateVersion.',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              const Text(
                'The Composer and Workshop keep module-first authoring primary while preserving publisher validation and frozen snapshot review.',
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.xs,
                children: [
                  StatusBadge(
                    label: '${validation.moduleCount} module(s)',
                    color: BafColors.planned,
                    icon: Icons.view_module_rounded,
                  ),
                  StatusBadge(
                    label: '${validation.fieldCount} field(s)',
                    color: BafColors.audit,
                    icon: Icons.checklist_rounded,
                  ),
                  StatusBadge(
                    label:
                        validation.canPublish
                            ? 'publish-ready'
                            : 'publisher will validate',
                    color:
                        validation.canPublish
                            ? BafColors.success
                            : BafColors.warning,
                    icon:
                        validation.canPublish
                            ? Icons.verified_rounded
                            : Icons.rule_rounded,
                  ),
                ],
              ),
            ],
          );

          final action = FilledButton.icon(
            onPressed: onOpenComposer,
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.planned,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: BafSpacing.lg,
                vertical: BafSpacing.md,
              ),
            ),
            icon: const Icon(Icons.open_in_full_rounded),
            label: const Text('Open Module Composer'),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: BafSpacing.md),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: summary),
              const SizedBox(width: BafSpacing.lg),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  final List<TemplatePackage> packages;
  final String? selectedPackageId;
  final TextEditingController packageCodeController;
  final TextEditingController packageTitleController;
  final TextEditingController descriptionController;
  final TextEditingController assetTypeController;
  final TextEditingController assetScopeController;
  final ValueChanged<String?> onPackageChanged;

  const _PackageSection({
    required this.packages,
    required this.selectedPackageId,
    required this.packageCodeController,
    required this.packageTitleController,
    required this.descriptionController,
    required this.assetTypeController,
    required this.assetScopeController,
    required this.onPackageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted =
        packages.where((package) => package.firestoreId != null).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return _Panel(
      title: '1. Package',
      subtitle:
          'Select an existing governance package or create a new BAF catalogue package.',
      icon: Icons.inventory_2_rounded,
      child: Column(
        children: [
          DropdownButtonFormField<String?>(
            initialValue: selectedPackageId,
            decoration: _inputDecoration(
              label: 'Template package',
              icon: Icons.folder_copy_rounded,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: _newPackageSentinel,
                child: Text('Create new package'),
              ),
              ...sorted.map(
                (package) => DropdownMenuItem<String?>(
                  value: package.firestoreId,
                  child: Text('${package.packageCode} — ${package.title}'),
                ),
              ),
            ],
            onChanged: onPackageChanged,
          ),
          const SizedBox(height: BafSpacing.md),
          _ResponsiveTwoColumn(
            left: TextField(
              controller: packageCodeController,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDecoration(
                label: 'Package code',
                hint: 'FURNACE_FULL_PM',
                icon: Icons.tag_rounded,
              ),
            ),
            right: TextField(
              controller: packageTitleController,
              decoration: _inputDecoration(
                label: 'Package title',
                hint: 'Furnace Full Maintenance',
                icon: Icons.title_rounded,
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Description',
              hint: 'Scope, intended equipment and governance context',
              icon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          _ResponsiveTwoColumn(
            left: TextField(
              controller: assetTypeController,
              decoration: _inputDecoration(
                label: 'Asset type',
                hint: 'furnace / base / innerCover',
                icon: Icons.precision_manufacturing_rounded,
              ),
            ),
            right: TextField(
              controller: assetScopeController,
              decoration: _inputDecoration(
                label: 'Asset number scope',
                hint: 'Furnace 1-13 / all bases',
                icon: Icons.filter_alt_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineSection extends StatelessWidget {
  final Set<String> selectedDisciplines;
  final List<_DisciplineOption> options;
  final ValueChanged<String> onToggle;

  const _DisciplineSection({
    required this.selectedDisciplines,
    required this.options,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '2. Discipline scope',
      subtitle:
          'Assigned disciplines are stored on the package and version metadata for audit and future assignment filtering.',
      icon: Icons.groups_2_rounded,
      child: Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.sm,
        children:
            options.map((option) {
              final selected = selectedDisciplines.contains(option.value);
              return FilterChip(
                selected: selected,
                avatar: Icon(
                  option.icon,
                  size: 18,
                  color: selected ? Colors.white : BafColors.textSecondary,
                ),
                label: Text(option.label),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: BafColors.planned,
                checkmarkColor: Colors.white,
                backgroundColor: BafColors.card,
                side: BorderSide(
                  color: selected ? BafColors.planned : BafColors.border,
                ),
                onSelected: (_) => onToggle(option.value),
              );
            }).toList(),
      ),
    );
  }
}

class _VersionSection extends StatelessWidget {
  final int nextVersionNumber;
  final TextEditingController versionLabelController;
  final TextEditingController releaseNotesController;
  final TextEditingController changeSummaryController;
  final TextEditingController minAppVersionController;
  final TextEditingController publishReasonController;

  const _VersionSection({
    required this.nextVersionNumber,
    required this.versionLabelController,
    required this.releaseNotesController,
    required this.changeSummaryController,
    required this.minAppVersionController,
    required this.publishReasonController,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '3. Version notes',
      subtitle:
          'Prepare the draft version metadata that will become part of the publish audit trail.',
      icon: Icons.new_releases_rounded,
      child: Column(
        children: [
          _ResponsiveTwoColumn(
            left: TextField(
              controller: versionLabelController,
              decoration: _inputDecoration(
                label: 'Version label',
                hint: 'v$nextVersionNumber / BAF-H2-2026',
                icon: Icons.label_rounded,
              ),
            ),
            right: TextField(
              controller: minAppVersionController,
              decoration: _inputDecoration(
                label: 'Minimum app version',
                hint: 'optional',
                icon: Icons.system_update_rounded,
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: changeSummaryController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Change summary',
              hint: 'What changed in this catalogue version?',
              icon: Icons.compare_arrows_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: releaseNotesController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              label: 'Release notes',
              hint:
                  'Operational guidance for SI/Admin and future assignment users',
              icon: Icons.article_rounded,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: publishReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: _inputDecoration(
              label: 'Publish reason',
              hint: 'Why is this version being formally published?',
              icon: Icons.history_edu_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonPayloadSection extends StatelessWidget {
  final TextEditingController jobTemplateJsonController;
  final TextEditingController moduleSnapshotsJsonController;
  final TextEditingController fieldDefinitionsJsonController;
  final TextEditingController checklistJsonController;
  final VoidCallback onChanged;
  final VoidCallback onOpenComposer;
  final Future<void> Function(TextEditingController controller) onPretty;
  final Future<void> Function(TextEditingController controller) onPaste;
  final void Function(TextEditingController controller, _JsonRoot root) onClear;

  const _JsonPayloadSection({
    required this.jobTemplateJsonController,
    required this.moduleSnapshotsJsonController,
    required this.fieldDefinitionsJsonController,
    required this.checklistJsonController,
    required this.onChanged,
    required this.onOpenComposer,
    required this.onPretty,
    required this.onPaste,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '4. Advanced frozen JSON payloads / Composer output',
      subtitle:
          'Use the module-first Composer/Workshop path by default. These JSON panels remain available for advanced inspection, fallback, or controlled recovery; payloads are frozen after publish and copied into future runtime assignments.',
      icon: Icons.data_object_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: BafColors.planned.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.medium),
              side: BorderSide(
                color: BafColors.planned.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(BafSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final iconBox = Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.architecture_rounded,
                      color: BafColors.planned,
                    ),
                  );
                  const description = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module-first Composer / Workshop',
                        style: TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Author, reuse, merge, and review modules in the module-first workflow, then return generated frozen payloads here for advanced validation.',
                        style: TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  );
                  final openComposerButton = FilledButton.icon(
                    onPressed: onOpenComposer,
                    icon: const Icon(Icons.open_in_full_rounded),
                    label: const Text('Open Composer'),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconBox,
                            const SizedBox(width: BafSpacing.md),
                            const Expanded(child: description),
                          ],
                        ),
                        const SizedBox(height: BafSpacing.md),
                        openComposerButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      iconBox,
                      const SizedBox(width: BafSpacing.md),
                      const Expanded(child: description),
                      const SizedBox(width: BafSpacing.md),
                      openComposerButton,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'jobTemplateSnapshotJson',
            subtitle:
                'Single JSON object describing the high-level template snapshot.',
            controller: jobTemplateJsonController,
            expectedRoot: _JsonRoot.object,
            minLines: 8,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'moduleSnapshotsJson',
            subtitle:
                'JSON array of module snapshots. Required before publishing.',
            controller: moduleSnapshotsJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 10,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'fieldDefinitionsJson',
            subtitle:
                'JSON array of field definitions. This is the main BAF catalogue field payload.',
            controller: fieldDefinitionsJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 12,
            highlight: true,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
          const SizedBox(height: BafSpacing.md),
          _JsonPanel(
            title: 'checklistJson',
            subtitle: 'Optional checklist JSON array. Empty array is allowed.',
            controller: checklistJsonController,
            expectedRoot: _JsonRoot.list,
            minLines: 7,
            onChanged: onChanged,
            onPretty: onPretty,
            onPaste: onPaste,
            onClear: onClear,
          ),
        ],
      ),
    );
  }
}

class _JsonPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final _JsonRoot expectedRoot;
  final int minLines;
  final bool highlight;
  final VoidCallback onChanged;
  final Future<void> Function(TextEditingController controller) onPretty;
  final Future<void> Function(TextEditingController controller) onPaste;
  final void Function(TextEditingController controller, _JsonRoot root) onClear;

  const _JsonPanel({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.expectedRoot,
    required this.minLines,
    required this.onChanged,
    required this.onPretty,
    required this.onPaste,
    required this.onClear,
    this.highlight = false,
  });

  @override
  State<_JsonPanel> createState() => _JsonPanelState();
}

class _JsonPanelState extends State<_JsonPanel> {
  bool _isHoveringDrag = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.highlight
            ? BafColors.planned.withValues(alpha: 0.45)
            : BafColors.border;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isHoveringDrag = true);
        return details.data.trim().isNotEmpty;
      },
      onLeave: (_) => setState(() => _isHoveringDrag = false),
      onAcceptWithDetails: (details) {
        widget.controller.text = details.data;
        widget.controller.selection = TextSelection.collapsed(
          offset: widget.controller.text.length,
        );
        setState(() => _isHoveringDrag = false);
        widget.onChanged();
      },
      builder: (context, _, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color:
                _isHoveringDrag
                    ? BafColors.planned.withValues(alpha: 0.08)
                    : const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(
              color: _isHoveringDrag ? BafColors.planned : borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.xs,
                    children: [
                      _TinyActionButton(
                        label: 'Paste',
                        icon: Icons.content_paste_rounded,
                        onPressed: () => widget.onPaste(widget.controller),
                      ),
                      _TinyActionButton(
                        label: 'Pretty',
                        icon: Icons.auto_fix_high_rounded,
                        onPressed: () => widget.onPretty(widget.controller),
                      ),
                      _TinyActionButton(
                        label: 'Clear',
                        icon: Icons.clear_rounded,
                        onPressed:
                            () => widget.onClear(
                              widget.controller,
                              widget.expectedRoot,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: widget.controller,
                minLines: widget.minLines,
                maxLines: widget.minLines + 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText:
                      widget.expectedRoot == _JsonRoot.object
                          ? '{\n  "title": "..."\n}'
                          : '[\n  { "key": "..." }\n]',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    borderSide: const BorderSide(color: BafColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    borderSide: const BorderSide(color: BafColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    borderSide: const BorderSide(
                      color: BafColors.planned,
                      width: 1.4,
                    ),
                  ),
                ),
                onChanged: (_) => widget.onChanged(),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _compactContentHash(String? hash) {
  final value = hash?.trim();
  if (value == null || value.isEmpty) return 'hash pending';
  final separator = value.indexOf(':');
  if (separator <= 0 || value.length <= 28) return value;

  final prefix = value.substring(0, separator);
  final digest = value.substring(separator + 1);
  if (digest.length <= 16) return value;

  return '$prefix:${digest.substring(0, 8)}…${digest.substring(digest.length - 6)}';
}

class _ValidationSection extends StatelessWidget {
  final _ValidationResult validation;

  const _ValidationSection({required this.validation});

  @override
  Widget build(BuildContext context) {
    final color =
        validation.canPublish
            ? BafColors.success
            : validation.errors.isNotEmpty
            ? BafColors.danger
            : BafColors.warning;

    return _Panel(
      title: '5. Publish readiness',
      subtitle:
          'The screen validates client-side before calling the provider. Firestore rules remain the final authority.',
      icon: Icons.fact_check_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              StatusBadge(
                label: validation.canPublish ? 'Publishable' : 'Blocked',
                color: color,
                icon:
                    validation.canPublish
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
              ),
              Tooltip(
                message: validation.contentHash ?? 'hash pending',
                child: StatusBadge(
                  label: _compactContentHash(validation.contentHash),
                  color: BafColors.audit,
                  icon: Icons.fingerprint_rounded,
                ),
              ),
              StatusBadge(
                label: '${validation.checklistCount} checklist items',
                color: BafColors.assets,
                icon: Icons.playlist_add_check_rounded,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          if (validation.errors.isEmpty && validation.warnings.isEmpty)
            const _ValidationLine(
              text: 'All required package, discipline and JSON checks passed.',
              color: BafColors.success,
              icon: Icons.verified_rounded,
            )
          else ...[
            ...validation.errors.map(
              (error) => _ValidationLine(
                text: error,
                color: BafColors.danger,
                icon: Icons.error_outline_rounded,
              ),
            ),
            ...validation.warnings.map(
              (warning) => _ValidationLine(
                text: warning,
                color: BafColors.warning,
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExistingVersionsSection extends ConsumerWidget {
  final String packageFirestoreId;

  const _ExistingVersionsSection({required this.packageFirestoreId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(
      packageVersionsProvider(packageFirestoreId),
    );

    return _Panel(
      title: 'Existing package versions',
      subtitle:
          'Recent versions for the selected package. Published rows are immutable source records.',
      icon: Icons.history_rounded,
      child: versionsAsync.when(
        loading:
            () => const Padding(
              padding: EdgeInsets.all(BafSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (e, _) => Text(
              'Could not load versions: $e',
              style: const TextStyle(color: BafColors.danger),
            ),
        data: (versions) {
          if (versions.isEmpty) {
            return const Text(
              'No versions yet. The first publish will create v1.',
              style: TextStyle(color: BafColors.textSecondary),
            );
          }
          return Column(
            children:
                versions.take(6).map((version) {
                  final color = switch (version.status) {
                    TemplateVersionStatus.draft => BafColors.warning,
                    TemplateVersionStatus.published => BafColors.success,
                    TemplateVersionStatus.retired => BafColors.danger,
                    TemplateVersionStatus.archived => BafColors.admin,
                  };
                  return Container(
                    margin: const EdgeInsets.only(bottom: BafSpacing.sm),
                    padding: const EdgeInsets.all(BafSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                      border: Border.all(color: BafColors.border),
                    ),
                    child: Row(
                      children: [
                        _IconTile(
                          icon: Icons.new_releases_rounded,
                          color: color,
                          size: 42,
                        ),
                        const SizedBox(width: BafSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'v${version.versionNumber} ${version.versionLabel ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  color: BafColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: BafSpacing.xs),
                              Tooltip(
                                message: version.contentHash ?? 'No hash yet',
                                child: Text(
                                  _compactContentHash(version.contentHash),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: BafColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(label: version.status.name, color: color),
                      ],
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// _PublishBar
// ──────────────────────────────────────────────────────────────────────────
// Used as Scaffold.bottomNavigationBar.
//
// The Scaffold itself reserves space for this bar above the body and
// passes the system gesture inset down through MediaQuery — we let
// SafeArea(top: false) pick that up cleanly instead of computing
// viewPadding.bottom manually (which double-counted the inset and
// inflated the bar's height in mobile builds).
//
// Mobile (< 760dp) layout:
//   - status text (bounded to 2 lines, ellipsis)
//   - [optional] full-width "Open Module Composer" when the draft is empty
//   - row of [Reset | Save Draft] each Expanded for equal half-width
//   - full-width Publish New Version
//
// Wide (>= 760dp) layout: single row with Expanded status + buttons.
// ──────────────────────────────────────────────────────────────────────────
class _PublishBar extends StatelessWidget {
  final _ValidationResult validation;
  final bool isPublishing;
  final VoidCallback onOpenComposer;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onReset;

  const _PublishBar({
    required this.validation,
    required this.isPublishing,
    required this.onOpenComposer,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BafColors.card,
      elevation: 0,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: BafSpacing.sm),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: BafColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.md,
              BafSpacing.lg,
              BafSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 760;
                    final isEmptyDraft =
                        validation.moduleCount == 0 &&
                        validation.fieldCount == 0;

                    final statusMessage =
                        validation.canPublish
                            ? 'Ready: publish will create an immutable TemplateVersion and audit row.'
                            : isEmptyDraft
                            ? 'Start with Module Composer, then complete package/version metadata.'
                            : '${validation.errors.length} error(s), ${validation.warnings.length} warning(s)';

                    final statusText = Text(
                      statusMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            validation.canPublish
                                ? BafColors.success
                                : isEmptyDraft
                                ? BafColors.textPrimary
                                : BafColors.textSecondary,
                        fontSize: isNarrow ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    );

                    final composerButton = FilledButton.icon(
                      onPressed: isPublishing ? null : onOpenComposer,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BafSpacing.lg,
                          vertical: BafSpacing.md,
                        ),
                      ),
                      icon: const Icon(Icons.architecture_rounded, size: 18),
                      label: const Text('Open Module Composer'),
                    );

                    final resetButton = OutlinedButton.icon(
                      onPressed: isPublishing ? null : onReset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset'),
                    );
                    final draftButton = OutlinedButton.icon(
                      onPressed: isPublishing ? null : onSaveDraft,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Draft'),
                    );
                    final publishButton = FilledButton.icon(
                      onPressed:
                          isPublishing || !validation.canPublish
                              ? null
                              : onPublish,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BafSpacing.lg,
                          vertical: BafSpacing.md,
                        ),
                      ),
                      icon:
                          isPublishing
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.publish_rounded),
                      label: Text(
                        isPublishing ? 'Publishing…' : 'Publish New Version',
                      ),
                    );

                    if (isNarrow) {
                      // Mobile column: deterministic, no Wrap.
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusText,
                          if (isEmptyDraft) ...[
                            const SizedBox(height: BafSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: composerButton,
                            ),
                          ],
                          const SizedBox(height: BafSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: resetButton),
                              const SizedBox(width: BafSpacing.sm),
                              Expanded(child: draftButton),
                            ],
                          ),
                          const SizedBox(height: BafSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: publishButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: statusText),
                        const SizedBox(width: BafSpacing.md),
                        if (isEmptyDraft) ...[
                          composerButton,
                          const SizedBox(width: BafSpacing.sm),
                        ],
                        resetButton,
                        const SizedBox(width: BafSpacing.sm),
                        draftButton,
                        const SizedBox(width: BafSpacing.sm),
                        publishButton,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const _Panel({required this.child, this.title, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  _IconTile(icon: icon!, color: BafColors.planned, size: 44),
                  const SizedBox(width: BafSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: BafSpacing.xs),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
          ],
          child,
        ],
      ),
    );
  }
}

class _ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveTwoColumn({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [left, const SizedBox(height: BafSpacing.md), right],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: BafSpacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

class _TinyActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _TinyActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: BafSpacing.sm),
      ),
    );
  }
}

class _ValidationLine extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const _ValidationLine({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessDeniedScaffold extends StatelessWidget {
  const _AccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BafColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(BafSpacing.xl),
            child: _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: BafColors.danger, size: 54),
                  SizedBox(height: BafSpacing.md),
                  Text(
                    'Template governance access denied',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: BafSpacing.sm),
                  Text(
                    'Only approved Admin/SI users can create, save or publish governed template versions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;

  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.xl),
          child: _Panel(
            child: Text(
              message,
              style: const TextStyle(color: BafColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.planned, width: 1.4),
    ),
  );
}

class _PublisherPayloadSemanticResult {
  final List<String> errors;
  final List<String> warnings;

  const _PublisherPayloadSemanticResult({
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });
}

class _ValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final String? contentHash;
  final int moduleCount;
  final int fieldCount;
  final int checklistCount;
  final bool? canSaveDraftOverride;

  const _ValidationResult({
    required this.errors,
    required this.warnings,
    required this.contentHash,
    required this.moduleCount,
    required this.fieldCount,
    required this.checklistCount,
    this.canSaveDraftOverride,
  });

  bool get canSaveDraft => canSaveDraftOverride ?? errors.isEmpty;
  bool get canPublish => errors.isEmpty;
}

class _JsonCheck {
  final String? error;
  final String? warning;
  final int itemCount;
  final String? normalizedJson;

  const _JsonCheck({
    this.error,
    this.warning,
    this.itemCount = 0,
    this.normalizedJson,
  });
}

class _CachedJsonCheck {
  final String raw;
  final _JsonRoot expectedRoot;
  final bool allowEmpty;
  final _JsonCheck result;

  const _CachedJsonCheck({
    required this.raw,
    required this.expectedRoot,
    required this.allowEmpty,
    required this.result,
  });
}

enum _JsonRoot { object, list }

class _DisciplineOption {
  final String value;
  final String label;
  final IconData icon;

  const _DisciplineOption(this.value, this.label, this.icon);
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
