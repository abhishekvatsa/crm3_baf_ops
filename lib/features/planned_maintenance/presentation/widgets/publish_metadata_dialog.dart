import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../auth/data/user_model.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../data/template_governance_model.dart';
import '../../domain/module_composer_models.dart';
import '../../domain/publish_metadata_builder.dart';
import '../../domain/template_version_snapshot_contract.dart';

class PublishMetadataDialogActions {
  final Future<void> Function(TemplatePackage package, AppUser actor)
  savePackage;
  final Future<TemplateVersion> Function(TemplateVersion version, AppUser actor)
  saveVersionDraft;
  final Future<TemplateVersion> Function(
    TemplateVersion version,
    AppUser actor,
    String reason,
  )
  publishVersion;
  final Future<int> Function(TemplatePackage package) nextVersionNumberFor;

  const PublishMetadataDialogActions({
    required this.savePackage,
    required this.saveVersionDraft,
    required this.publishVersion,
    required this.nextVersionNumberFor,
  });
}

class PublishMetadataDialogResult {
  final TemplateVersion version;
  final bool published;

  const PublishMetadataDialogResult._({
    required this.version,
    required this.published,
  });

  const PublishMetadataDialogResult.saved(TemplateVersion version)
    : this._(version: version, published: false);

  const PublishMetadataDialogResult.published(TemplateVersion version)
    : this._(version: version, published: true);
}

class PublishMetadataDialog extends StatefulWidget {
  final AppUser actor;
  final TemplateComposerDraft draft;
  final List<TemplatePackage> existingPackages;
  final PublishMetadataDialogActions actions;
  final String? initialPackageCode;
  final String? initialPackageTitle;
  final String? initialPackageFirestoreId;
  final TemplateVersion? initialVersion;
  final bool hasUnsavedComposerChanges;

  const PublishMetadataDialog({
    super.key,
    required this.actor,
    required this.draft,
    required this.existingPackages,
    required this.actions,
    this.initialPackageCode,
    this.initialPackageTitle,
    this.initialPackageFirestoreId,
    this.initialVersion,
    this.hasUnsavedComposerChanges = false,
  });

  static Future<PublishMetadataDialogResult?> show(
    BuildContext context, {
    required AppUser actor,
    required TemplateComposerDraft draft,
    required List<TemplatePackage> existingPackages,
    required PublishMetadataDialogActions actions,
    String? initialPackageCode,
    String? initialPackageTitle,
    String? initialPackageFirestoreId,
    TemplateVersion? initialVersion,
    bool hasUnsavedComposerChanges = false,
  }) {
    return showDialog<PublishMetadataDialogResult>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => PublishMetadataDialog(
            actor: actor,
            draft: draft,
            existingPackages: existingPackages,
            actions: actions,
            initialPackageCode: initialPackageCode,
            initialPackageTitle: initialPackageTitle,
            initialPackageFirestoreId: initialPackageFirestoreId,
            initialVersion: initialVersion,
            hasUnsavedComposerChanges: hasUnsavedComposerChanges,
          ),
    );
  }

  @override
  State<PublishMetadataDialog> createState() => _PublishMetadataDialogState();
}

class _PublishMetadataDialogState extends State<PublishMetadataDialog> {
  static const List<String> _disciplineOptions = <String>[
    'mechanical',
    'electrical',
    'instrumentation',
    'operations',
    'safety',
    'shared',
  ];

  late final TextEditingController _packageCodeController;
  late final TextEditingController _packageTitleController;
  late final TextEditingController _packageDescriptionController;
  late final TextEditingController _assetScopeController;
  late final TextEditingController _versionLabelController;
  late final TextEditingController _releaseNotesController;
  late final TextEditingController _changeSummaryController;
  late final TextEditingController _minAppVersionController;
  late final TextEditingController _publishReasonController;

  bool _createNewPackage = false;
  bool _busy = false;
  bool _invalidInitialVersion = false;
  String? _error;
  TemplatePackage? _selectedPackage;
  late AssetType _assetType;
  final Set<String> _selectedDisciplines = <String>{};

  @override
  void initState() {
    super.initState();
    _assetType = widget.draft.assetType;
    _packageCodeController = TextEditingController(
      text: widget.initialPackageCode ?? '',
    );
    _packageTitleController = TextEditingController(
      text: widget.initialPackageTitle ?? widget.draft.title,
    );
    _packageDescriptionController = TextEditingController();
    _assetScopeController = TextEditingController();
    _versionLabelController = TextEditingController();
    _releaseNotesController = TextEditingController();
    _changeSummaryController = TextEditingController();
    _minAppVersionController = TextEditingController();
    _publishReasonController = TextEditingController();

    if (widget.existingPackages.isEmpty) {
      _createNewPackage = true;
      _selectedDisciplines.addAll(_disciplineDefaultsFromDraft());
    } else {
      final requestedPackageId = widget.initialPackageFirestoreId?.trim();
      _selectedPackage = widget.existingPackages.firstWhere(
        (package) =>
            requestedPackageId != null &&
            requestedPackageId.isNotEmpty &&
            package.firestoreId == requestedPackageId,
        orElse: () => widget.existingPackages.first,
      );
      _hydrateFromSelectedPackage();
    }

    _hydrateFromInitialVersion();

    for (final controller in <TextEditingController>[
      _packageCodeController,
      _packageTitleController,
      _packageDescriptionController,
      _assetScopeController,
      _versionLabelController,
      _releaseNotesController,
      _changeSummaryController,
      _minAppVersionController,
      _publishReasonController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _packageCodeController,
      _packageTitleController,
      _packageDescriptionController,
      _assetScopeController,
      _versionLabelController,
      _releaseNotesController,
      _changeSummaryController,
      _minAppVersionController,
      _publishReasonController,
    ]) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (mounted) {
      setState(() {});
    }
  }

  void _hydrateFromSelectedPackage() {
    final package = _selectedPackage;
    if (package == null) {
      return;
    }
    _packageCodeController.text = package.packageCode;
    _packageTitleController.text = package.title;
    _packageDescriptionController.text = package.description ?? '';
    _assetScopeController.text = package.assetNumberScope ?? '';
    _selectedDisciplines
      ..clear()
      ..addAll(
        (package.disciplineScope ?? '')
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    if (_selectedDisciplines.isEmpty) {
      _selectedDisciplines.addAll(_disciplineDefaultsFromDraft());
    }
    final asset = _parseAssetType(package.assetType);
    if (asset != null) {
      _assetType = asset;
    }
  }

  void _hydrateFromInitialVersion() {
    final version = widget.initialVersion;
    if (version == null) {
      return;
    }
    if (!version.isDraft) {
      _invalidInitialVersion = true;
      _error = 'Only draft TemplateVersions can be resumed.';
      return;
    }
    _versionLabelController.text = version.versionLabel ?? '';
    _releaseNotesController.text = version.releaseNotes ?? '';
    _changeSummaryController.text = version.changeSummary ?? '';
    _minAppVersionController.text = version.minAppVersion ?? '';
    _publishReasonController.clear();
  }

  Set<String> _disciplineDefaultsFromDraft() {
    final values = <String>{};
    for (final module in widget.draft.modules) {
      if (module.discipline.name.trim().isNotEmpty) {
        values.add(module.discipline.name);
      }
      values.addAll(module.ownerDisciplines.map((item) => item.trim()));
    }
    values.removeWhere((item) => item.isEmpty);
    return values.isEmpty ? <String>{'mechanical'} : values;
  }

  AssetType? _parseAssetType(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    for (final item in AssetType.values) {
      if (item.name.toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  PublishMetadataInput _input() {
    return PublishMetadataInput(
      packageCode: _packageCodeController.text,
      packageTitle: _packageTitleController.text,
      packageDescription: _packageDescriptionController.text,
      assetType: _assetType,
      assetNumberScope: _assetScopeController.text,
      disciplineScope: Set<String>.from(_selectedDisciplines),
      versionLabel: _versionLabelController.text,
      releaseNotes: _releaseNotesController.text,
      changeSummary: _changeSummaryController.text,
      minAppVersion: _minAppVersionController.text,
      publishReason: _publishReasonController.text,
    );
  }

  PublishMetadataValidation _validation() {
    return validatePublishMetadata(input: _input(), draft: widget.draft);
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<TemplatePackage> _ensurePackage() async {
    final package =
        _createNewPackage
            ? buildTemplatePackageForPublish(
              input: _input(),
              actor: widget.actor,
            )
            : _selectedPackage!;
    final resumedPackageId = widget.initialVersion?.packageFirestoreId?.trim();
    if (resumedPackageId != null &&
        resumedPackageId.isNotEmpty &&
        package.firestoreId != resumedPackageId) {
      throw StateError(
        'A resumed TemplateVersion draft cannot be moved to another package.',
      );
    }
    if (_createNewPackage || package.firestoreId == null) {
      await widget.actions.savePackage(package, widget.actor);
    }
    return package;
  }

  Future<void> _saveDraft() async {
    if (_invalidInitialVersion) {
      return;
    }
    final validation = _validation();
    if (!validation.canSaveDraft) {
      setState(() => _error = validation.errors.join('\n'));
      return;
    }
    await _run(() async {
      final package = await _ensurePackage();
      final version = buildTemplateVersionForPublish(
        input: _input(),
        draft: widget.draft,
        package: package,
        nextVersionNumber: await widget.actions.nextVersionNumberFor(package),
        existingVersion: widget.initialVersion,
        actor: widget.actor,
      );
      final saved = await widget.actions.saveVersionDraft(
        version,
        widget.actor,
      );
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'Draft saved and sync-confirmed for ${package.packageCode}. You can prepare publish again without reopening the saved draft.',
            ),
          ),
        );
        Navigator.pop(context, PublishMetadataDialogResult.saved(saved));
      }
    });
  }

  Future<void> _publish() async {
    if (_invalidInitialVersion) {
      return;
    }
    if (widget.initialVersion != null && !widget.initialVersion!.isSynced) {
      setState(() {
        _error =
            'This saved draft has not been confirmed by sync. Use Save Draft to retry the same record and refresh publish eligibility after Firestore confirms it.';
      });
      return;
    }
    if (widget.initialVersion != null && widget.hasUnsavedComposerChanges) {
      setState(() {
        _error =
            'This resumed draft has unsaved Composer changes. Save Draft to synchronize the same record before publishing.';
      });
      return;
    }
    final validation = _validation();
    if (!validation.canPublish) {
      final reason = _publishReasonController.text.trim();
      setState(() {
        _error = <String>[
          ...validation.errors,
          if (reason.length < kPublishReasonMinLength)
            'Publish reason is required.',
        ].join('\n');
      });
      return;
    }
    await _run(() async {
      final package = await _ensurePackage();
      final version = buildTemplateVersionForPublish(
        input: _input(),
        draft: widget.draft,
        package: package,
        nextVersionNumber: await widget.actions.nextVersionNumberFor(package),
        existingVersion: widget.initialVersion,
        preserveExistingPayload: widget.initialVersion != null,
        actor: widget.actor,
      );
      final published = await widget.actions.publishVersion(
        version,
        widget.actor,
        _publishReasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'Published and sync-confirmed for ${package.packageCode}.',
            ),
          ),
        );
        Navigator.pop(
          context,
          PublishMetadataDialogResult.published(published),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGovern = widget.actor.canPublishTemplateVersion;
    final validation = _validation();
    final snapshot = validation.snapshot;

    return AlertDialog(
      title: const Text('Publish metadata'),
      content: SizedBox(
        width: 920,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryCard(
                moduleCount: widget.draft.modules.length,
                closureCriticalCount: snapshot?.closureCriticalModuleCount ?? 0,
                canGovern: canGovern,
              ),
              const SizedBox(height: BafSpacing.md),
              _PackageSection(
                createNewPackage: _createNewPackage,
                packages: widget.existingPackages,
                selectedPackage: _selectedPackage,
                packageCodeController: _packageCodeController,
                packageTitleController: _packageTitleController,
                packageDescriptionController: _packageDescriptionController,
                assetScopeController: _assetScopeController,
                assetType: _assetType,
                selectedDisciplines: _selectedDisciplines,
                disciplineOptions: _disciplineOptions,
                onCreateModeChanged: (value) {
                  setState(() {
                    _createNewPackage = value;
                    if (!value && widget.existingPackages.isNotEmpty) {
                      _selectedPackage ??= widget.existingPackages.first;
                      _hydrateFromSelectedPackage();
                    }
                  });
                },
                onPackageChanged: (package) {
                  setState(() {
                    _selectedPackage = package;
                    _hydrateFromSelectedPackage();
                  });
                },
                onAssetTypeChanged:
                    (asset) => setState(() => _assetType = asset),
                onDisciplineToggled: (discipline, selected) {
                  setState(() {
                    if (selected) {
                      _selectedDisciplines.add(discipline);
                    } else {
                      _selectedDisciplines.remove(discipline);
                    }
                  });
                },
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                key: const Key('publish-version-label'),
                controller: _versionLabelController,
                decoration: const InputDecoration(
                  labelText: 'Version label (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _releaseNotesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Release notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _changeSummaryController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Change summary',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                key: const Key('publish-reason'),
                controller: _publishReasonController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Publish reason',
                  helperText:
                      'Required for Publish. Not required for Save Draft.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              _PreviewCard(snapshot: snapshot),
              if (validation.errors.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                _MessagePanel(
                  color: BafColors.danger,
                  title: 'Publish blocked',
                  messages: validation.errors,
                ),
              ],
              if (validation.warnings.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                _MessagePanel(
                  color: BafColors.warning,
                  title: 'Warnings',
                  messages: validation.warnings,
                ),
              ],
              if (widget.initialVersion != null &&
                  !widget.initialVersion!.isSynced) ...[
                const SizedBox(height: BafSpacing.md),
                const _SingleMessagePanel(
                  color: BafColors.warning,
                  message:
                      'This draft is still pending sync. Use Save Draft to retry the same record; publish becomes eligible after Firestore confirmation.',
                ),
              ],
              if (widget.initialVersion != null &&
                  widget.hasUnsavedComposerChanges) ...[
                const SizedBox(height: BafSpacing.md),
                const _SingleMessagePanel(
                  color: BafColors.warning,
                  message:
                      'Publish uses the exact last-saved governed payload. Save Draft to synchronize these Composer changes before publishing.',
                ),
              ],
              if (!canGovern) ...[
                const SizedBox(height: BafSpacing.md),
                const _SingleMessagePanel(
                  color: BafColors.danger,
                  message: 'Only Admin/SI may publish TemplateVersions.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: BafSpacing.md),
                _SingleMessagePanel(color: BafColors.danger, message: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          key: const Key('publish-save-draft'),
          onPressed:
              _busy ||
                      _invalidInitialVersion ||
                      !canGovern ||
                      !validation.canSaveDraft
                  ? null
                  : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Draft'),
        ),
        FilledButton.icon(
          key: const Key('publish-publish'),
          onPressed:
              _busy ||
                      _invalidInitialVersion ||
                      !canGovern ||
                      (widget.initialVersion != null &&
                          !widget.initialVersion!.isSynced) ||
                      (widget.initialVersion != null &&
                          widget.hasUnsavedComposerChanges) ||
                      !validation.canPublish
                  ? null
                  : _publish,
          icon: const Icon(Icons.rocket_launch_rounded),
          label: const Text('Publish'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int moduleCount;
  final int closureCriticalCount;
  final bool canGovern;

  const _SummaryCard({
    required this.moduleCount,
    required this.closureCriticalCount,
    required this.canGovern,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Module-first publish path',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            '$moduleCount module(s), $closureCriticalCount closure-critical module(s). '
            'TemplateVersion snapshots remain frozen after publish.',
          ),
          if (!canGovern) ...[
            const SizedBox(height: BafSpacing.xs),
            const Text(
              'Current actor is not authorised to publish.',
              style: TextStyle(color: BafColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackageSection extends StatelessWidget {
  final bool createNewPackage;
  final List<TemplatePackage> packages;
  final TemplatePackage? selectedPackage;
  final TextEditingController packageCodeController;
  final TextEditingController packageTitleController;
  final TextEditingController packageDescriptionController;
  final TextEditingController assetScopeController;
  final AssetType assetType;
  final Set<String> selectedDisciplines;
  final List<String> disciplineOptions;
  final ValueChanged<bool> onCreateModeChanged;
  final ValueChanged<TemplatePackage?> onPackageChanged;
  final ValueChanged<AssetType> onAssetTypeChanged;
  final void Function(String discipline, bool selected) onDisciplineToggled;

  const _PackageSection({
    required this.createNewPackage,
    required this.packages,
    required this.selectedPackage,
    required this.packageCodeController,
    required this.packageTitleController,
    required this.packageDescriptionController,
    required this.assetScopeController,
    required this.assetType,
    required this.selectedDisciplines,
    required this.disciplineOptions,
    required this.onCreateModeChanged,
    required this.onPackageChanged,
    required this.onAssetTypeChanged,
    required this.onDisciplineToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Package', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: BafSpacing.sm),
        BafHorizontalControlRail(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Use existing'),
                icon: Icon(Icons.folder_open_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Create new'),
                icon: Icon(Icons.create_new_folder_rounded),
              ),
            ],
            selected: <bool>{createNewPackage},
            onSelectionChanged:
                packages.isEmpty
                    ? null
                    : (value) => onCreateModeChanged(value.first),
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        if (!createNewPackage && packages.isNotEmpty)
          DropdownButtonFormField<TemplatePackage>(
            key: const Key('publish-package-picker'),
            isExpanded: true,
            initialValue: selectedPackage,
            decoration: const InputDecoration(
              labelText: 'Existing package',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final package in packages)
                DropdownMenuItem<TemplatePackage>(
                  value: package,
                  child: Text('${package.packageCode} · ${package.title}'),
                ),
            ],
            onChanged: onPackageChanged,
          )
        else ...[
          TextFormField(
            key: const Key('publish-new-package-code'),
            controller: packageCodeController,
            decoration: const InputDecoration(
              labelText: 'Package code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            key: const Key('publish-new-package-title'),
            controller: packageTitleController,
            decoration: const InputDecoration(
              labelText: 'Package title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            controller: packageDescriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Package description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          TextFormField(
            controller: assetScopeController,
            decoration: const InputDecoration(
              labelText: 'Asset-number scope',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          DropdownButtonFormField<AssetType>(
            isExpanded: true,
            initialValue: assetType,
            decoration: const InputDecoration(
              labelText: 'Asset type',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in AssetType.values)
                DropdownMenuItem<AssetType>(
                  value: value,
                  child: Text(value.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onAssetTypeChanged(value);
              }
            },
          ),
        ],
        const SizedBox(height: BafSpacing.md),
        const Text(
          'Discipline scope',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: BafSpacing.xs),
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.xs,
          children: [
            for (final discipline in disciplineOptions)
              FilterChip(
                key: Key('publish-discipline-$discipline'),
                label: Text(discipline),
                selected: selectedDisciplines.contains(discipline),
                onSelected:
                    (selected) => onDisciplineToggled(discipline, selected),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final TemplateVersionSnapshotBundle? snapshot;

  const _PreviewCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final bundle = snapshot;
    if (bundle == null) {
      return const _SingleMessagePanel(
        color: BafColors.warning,
        message: 'Snapshot preview is unavailable until metadata is valid.',
      );
    }
    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Snapshot preview'),
      subtitle: Text(
        '${bundle.moduleSnapshots.length} module(s), '
        '${bundle.fieldDefinitions.length} field(s), '
        '${bundle.checklistItems.length} checklist item(s).',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(BafSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Closure review confirmed: ${bundle.closureReviewConfirmed}\n'
              'Closure-critical modules: ${bundle.closureCriticalModuleCount}',
            ),
          ),
        ),
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final Color color;
  final String title;
  final List<String> messages;

  const _MessagePanel({
    required this.color,
    required this.title,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: BafSpacing.xs),
          for (final message in messages) Text('• $message'),
        ],
      ),
    );
  }
}

class _SingleMessagePanel extends StatelessWidget {
  final Color color;
  final String message;

  const _SingleMessagePanel({required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(message),
    );
  }
}
