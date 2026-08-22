part of 'template_publisher_screen.dart';

extension _TemplatePublisherActions on _TemplatePublisherScreenState {
  Future<void> _prettyFormat(TextEditingController controller) async {
    try {
      controller.text = _normalizedJson(controller.text);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      _setPublisherState(() {});
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
    _setPublisherState(() {});
  }

  void _clearJson(TextEditingController controller, _JsonRoot root) {
    controller.text = root == _JsonRoot.object ? '{\n  \n}' : '[\n  \n]';
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    _setPublisherState(() {});
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
              canSeedCloudKnowledge: actor.canManageTemplateGovernance,
            ),
      ),
    );

    if (!mounted || output == null) return;

    final shouldReplace = await _confirmComposerPayloadReplace();
    if (!mounted || !shouldReplace) return;

    _setPublisherState(() {
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

  Future<void> _archivePublisherDraft(
    TemplateVersion version,
    AppUser actor,
  ) async {
    if (_isPublishing) return;
    if (version.isDeleted || !version.isDraft) {
      _showSnack(
        'Only active draft TemplateVersions can be archived.',
        BafColors.danger,
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ArchivePublisherDraftReasonDialog(version: version),
    );
    if (!mounted || reason == null) return;

    _setPublisherState(() => _isPublishing = true);
    try {
      final repository = ref.read(templateGovernanceRepositoryProvider);
      await repository.archiveDraftVersion(
        version,
        actor: actor,
        reason: reason,
      );

      final archivedWorkingDraft =
          _workingDraft?.firestoreId != null &&
          _workingDraft?.firestoreId == version.firestoreId;
      if (archivedWorkingDraft) {
        _setPublisherState(() {
          _workingDraft = null;
        });
      }

      final syncOutcome =
          version.isSynced
              ? SyncRequestOutcome.succeeded
              : await ref
                  .read(syncCoordinatorProvider)
                  .runFullSyncWithResult(
                    reason:
                        'template_governance_draft_archived_from_legacy_publisher',
                    force: true,
                  );

      if (!mounted) return;
      final archiveMessage = switch (syncOutcome) {
        SyncRequestOutcome.succeeded =>
          archivedWorkingDraft
              ? 'Draft archived and synchronized. Current editor content remains as an unsaved new-draft copy.'
              : 'Draft archived and synchronized.',
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
          'Draft archived on this device; governed synchronization is queued.',
        SyncRequestOutcome.failed =>
          'Draft archived on this device, but governed cloud synchronization needs attention.',
      };
      _showSnack(
        archiveMessage,
        syncOutcome == SyncRequestOutcome.failed
            ? BafColors.danger
            : BafColors.audit,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Draft archive failed: $error', BafColors.danger);
    } finally {
      if (mounted) _setPublisherState(() => _isPublishing = false);
    }
  }

  Future<void> _restorePublisherDraft(
    TemplateVersion version,
    AppUser actor,
  ) async {
    if (_isPublishing) return;
    if (!version.isArchivedDraft) {
      _showSnack(
        'Only archived draft TemplateVersions can be restored.',
        BafColors.danger,
      );
      return;
    }
    if (!version.isSynced) {
      _showSnack(
        'Wait for the archived draft lifecycle and audit to synchronize before restoring it.',
        BafColors.warning,
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RestorePublisherDraftReasonDialog(version: version),
    );
    if (!mounted || reason == null) return;

    _setPublisherState(() => _isPublishing = true);
    try {
      final repository = ref.read(templateGovernanceRepositoryProvider);
      await repository.restoreArchivedDraftVersion(
        version,
        actor: actor,
        reason: reason,
      );

      final syncOutcome =
          version.isSynced
              ? SyncRequestOutcome.succeeded
              : await ref
                  .read(syncCoordinatorProvider)
                  .runFullSyncWithResult(
                    reason:
                        'template_governance_draft_restored_from_legacy_publisher',
                    force: true,
                  );

      if (!mounted) return;
      final restoreMessage = switch (syncOutcome) {
        SyncRequestOutcome.succeeded =>
          'Archived draft restored and synchronized. It is available to resume.',
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled =>
          'Archived draft restored on this device; governed synchronization is queued.',
        SyncRequestOutcome.failed =>
          'Archived draft restored on this device, but governed cloud synchronization needs attention.',
      };
      _showSnack(
        restoreMessage,
        syncOutcome == SyncRequestOutcome.failed
            ? BafColors.danger
            : BafColors.audit,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Draft restore failed: $error', BafColors.danger);
    } finally {
      if (mounted) _setPublisherState(() => _isPublishing = false);
    }
  }

  Future<void> _saveDraft(AppUser actor) async {
    if (_isPublishing) return;
    final validation = _buildDraftSaveValidation();
    if (!validation.canSaveDraft) {
      _showValidationFailure(validation);
      return;
    }

    _setPublisherState(() => _isPublishing = true);
    try {
      final repo = ref.read(templateGovernanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final package = await _ensurePackageSaved(repo, actor);
      final nextVersionNumber =
          _workingDraft == null
              ? await _nextAvailableVersionNumber(repo, package)
              : null;
      final version = _buildDraftVersion(
        package,
        versionNumberOverride: nextVersionNumber,
      );
      await repo.saveVersion(version, actor: actor);
      _workingDraft = version;
      final syncOutcome =
          version.isSynced
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason: 'template_governance_draft_saved',
                force: true,
              );
      if (!mounted) return;
      final (message, color) = switch (syncOutcome) {
        SyncRequestOutcome.succeeded => (
          'Draft version saved and synchronized.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          'Draft version saved on this device; governed synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          'Draft version saved on this device, but governed cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };
      _showSnack(message, color);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Draft save failed: $e', BafColors.danger);
    } finally {
      if (mounted) _setPublisherState(() => _isPublishing = false);
    }
  }

  Future<void> _publish(AppUser actor) async {
    if (_isPublishing) return;
    final validation = _buildValidation();
    if (!validation.canPublish) {
      _showValidationFailure(validation);
      return;
    }

    _setPublisherState(() => _isPublishing = true);
    try {
      final repo = ref.read(templateGovernanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final package = await _ensurePackageSaved(repo, actor);
      final nextVersionNumber =
          _workingDraft == null
              ? await _nextAvailableVersionNumber(repo, package)
              : null;
      final version = _buildDraftVersion(
        package,
        versionNumberOverride: nextVersionNumber,
      );

      await repo.publishVersion(
        version,
        actor: actor,
        reason: _publishReasonController.text.trim(),
      );

      final syncOutcome =
          version.isSynced
              ? SyncRequestOutcome.succeeded
              : await syncCoordinator.runFullSyncWithResult(
                reason: 'template_governance_version_published',
                force: true,
              );

      if (!mounted) return;
      if (version.versionNumber > package.latestVersionNumber) {
        package.latestVersionNumber = version.versionNumber;
      }
      package.activeVersionFirestoreId = version.firestoreId;
      _selectedPackage = package;
      _selectedPackageId = package.firestoreId;
      final (message, color) = switch (syncOutcome) {
        SyncRequestOutcome.succeeded => (
          'Published and synchronized ${package.packageCode} v${version.versionNumber}.',
          BafColors.sync,
        ),
        SyncRequestOutcome.queued || SyncRequestOutcome.throttled => (
          '${package.packageCode} v${version.versionNumber} is saved as published on this device; governed synchronization is queued.',
          BafColors.warning,
        ),
        SyncRequestOutcome.failed => (
          '${package.packageCode} v${version.versionNumber} is saved as published on this device, but governed cloud synchronization needs attention.',
          BafColors.danger,
        ),
      };
      _showSnack(message, color);
      _workingDraft = null;
      _resetVersionPayloads(keepVersionLabel: false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Publish failed: $e', BafColors.danger);
    } finally {
      if (mounted) _setPublisherState(() => _isPublishing = false);
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

  Future<int> _nextAvailableVersionNumber(
    TemplateGovernanceRepository repo,
    TemplatePackage package,
  ) async {
    final packageId = package.firestoreId?.trim();
    if (packageId == null || packageId.isEmpty) {
      return 1;
    }
    final versions = await repo.getVersionsForPackage(packageId);
    var latest = package.latestVersionNumber;
    for (final version in versions) {
      if (!version.isDeleted && version.versionNumber > latest) {
        latest = version.versionNumber;
      }
    }
    return latest + 1;
  }

  TemplateVersion _buildDraftVersion(
    TemplatePackage package, {
    int? versionNumberOverride,
  }) {
    final version =
        _workingDraft == null
            ? TemplateVersion()
            : _cloneVersion(_workingDraft!);

    version
      ..packageFirestoreId = package.firestoreId
      ..versionNumber =
          _workingDraft != null && version.versionNumber > 0
              ? version.versionNumber
              : versionNumberOverride ??
                  _nextVersionNumber(packageOverride: package)
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
    final definitions =
        ref.read(maintenanceClassDefinitionsProvider).value ??
        const <MaintenanceClassDefinition>[];
    MaintenanceClassDefinition? selected;
    for (final definition in definitions) {
      if (definition.id == _selectedMaintenanceClassId) {
        selected = definition;
        break;
      }
    }
    return jsonEncode({
      'source': 'TemplatePublisherScreen',
      'disciplineScope': _selectedDisciplines.toList()..sort(),
      'packageCode': _packageCodeController.text.trim(),
      'assetType': _assetTypeController.text.trim(),
      'generatedAt': DateTime.now().toIso8601String(),
      if (selected != null)
        'maintenanceClassification': selected.frozen.toMap(),
    });
  }
}
