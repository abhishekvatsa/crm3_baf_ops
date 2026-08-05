part of 'module_composer_screen.dart';

extension _ModuleComposerActions on _ModuleComposerScreenState {
  void _addManualModule() {
    setState(() {
      final module = ComposerModuleDraft.manual(assetType: _draft.assetType);
      module.moduleCode = _uniqueModuleCode(module.moduleCode);
      _draft.modules.add(module);
      _selectedModuleIndex = _draft.modules.length - 1;
    });
  }

  Future<void> _seedCloudKnowledgeBaseline() async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (!widget.canSeedCloudKnowledge ||
        actor == null ||
        !actor.canManageTemplateGovernance) {
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
            actorUid: actor.uid,
            actorName: actor.name,
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

  Future<void> _openSavedTemplateDrafts() async {
    final actor = ref.read(currentAppUserProvider).value;
    if (actor == null || !actor.canPublishTemplateVersion) {
      _showSnack(
        'Only Admin/SI users can manage governed TemplateVersion drafts.',
        BafColors.danger,
      );
      return;
    }

    final repository = ref.read(templateGovernanceRepositoryProvider);
    final entries = <_SavedTemplateDraftEntry>[];
    try {
      final packages = await repository.getAllPackages();
      for (final package in packages) {
        final packageId = package.firestoreId?.trim();
        if (packageId == null ||
            packageId.isEmpty ||
            package.isDeleted ||
            package.lifecycleStatus != TemplatePackageLifecycleStatus.active) {
          continue;
        }
        final versions = await repository.getVersionsForPackage(packageId);
        for (final version in versions) {
          if (!version.isDeleted &&
              (version.isDraft || version.isArchivedDraft)) {
            entries.add(
              _SavedTemplateDraftEntry(package: package, version: version),
            );
          }
        }
      }
    } on Object catch (error) {
      if (mounted) {
        _showSnack('Unable to load governed drafts: $error', BafColors.danger);
      }
      return;
    }

    entries.sort((a, b) => b.version.updatedAt.compareTo(a.version.updatedAt));
    if (!mounted) {
      return;
    }

    final pickerResult = await showDialog<_SavedTemplateDraftPickerResult>(
      context: context,
      builder: (_) => _SavedTemplateDraftPickerDialog(entries: entries),
    );
    if (!mounted || pickerResult == null) {
      return;
    }

    final selected = pickerResult.entry;
    if (pickerResult.action == _SavedTemplateDraftAction.restore) {
      if (!selected.canAttemptRestore) {
        _showSnack(selected.restoreGuidance, BafColors.warning);
        return;
      }

      final reason = await showDialog<String>(
        context: context,
        builder: (_) => _RestoreTemplateDraftReasonDialog(entry: selected),
      );
      if (!mounted || reason == null) {
        return;
      }

      try {
        await repository.restoreArchivedDraftVersion(
          selected.version,
          actor: actor,
          reason: reason,
        );
        if (!mounted) {
          return;
        }

        _triggerTemplateGovernanceSync(
          'template_governance_draft_restored_from_composer',
        );
        _showSnack(
          selected.version.isSynced
              ? 'Archived draft restored under the same governed identity and remotely confirmed.'
              : 'Archived draft restored locally under the same governed identity and queued for sync. Reopen it after restore sync completes.',
          BafColors.audit,
        );
      } on Object catch (error) {
        if (mounted) {
          _showSnack('Draft restore failed: $error', BafColors.danger);
        }
      }
      return;
    }

    if (pickerResult.action == _SavedTemplateDraftAction.archive) {
      final reason = await showDialog<String>(
        context: context,
        builder: (_) => _ArchiveTemplateDraftReasonDialog(entry: selected),
      );
      if (!mounted || reason == null) {
        return;
      }

      final currentVersionId = _editingTemplateVersion?.firestoreId;
      final archivedCurrentDraft =
          currentVersionId != null &&
          currentVersionId == selected.version.firestoreId;

      try {
        await repository.archiveDraftVersion(
          selected.version,
          actor: actor,
          reason: reason,
        );
        if (!mounted) {
          return;
        }

        if (archivedCurrentDraft) {
          setState(() {
            _editingTemplateVersion = null;
            _editingTemplateDraftFingerprint = null;
            _draft.localId = _stableDraftLocalId();
          });
        }

        _triggerTemplateGovernanceSync(
          'template_governance_draft_archived_from_composer',
        );
        _showSnack(
          archivedCurrentDraft
              ? 'Draft archived. Current Composer content is retained as an unsaved detached copy.'
              : 'Draft archived locally and queued for governed sync.',
          BafColors.audit,
        );
      } on Object catch (error) {
        if (mounted) {
          _showSnack('Draft archive failed: $error', BafColors.danger);
        }
      }
      return;
    }

    final currentVersionId = _editingTemplateVersion?.firestoreId;
    if (currentVersionId != selected.version.firestoreId &&
        _draft.modules.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Replace current composer draft?'),
              content: const Text(
                'Opening the saved TemplateVersion draft will replace the current composer working state. Unsaved changes in the current composer will be discarded.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Open saved draft'),
                ),
              ],
            ),
      );
      if (!mounted || replace != true) {
        return;
      }
    }

    late final TemplateComposerDraft selectedDraft;
    try {
      selectedDraft = TemplateComposerDraft.fromPayloads(
        jobTemplateSnapshotJson: selected.version.jobTemplateSnapshotJson,
        moduleSnapshotsJson: selected.version.moduleSnapshotsJson,
        fieldDefinitionsJson: selected.version.fieldDefinitionsJson,
        checklistJson: selected.version.checklistJson,
      );
    } on FormatException catch (error) {
      _showSnack(
        'Saved draft needs repair and was not opened: ${error.message}',
        BafColors.danger,
      );
      return;
    }

    await _clearRecoveryDraft();
    if (!mounted) return;

    _suppressRecoverySave = true;
    try {
      setState(() {
        _editingTemplateVersion = selected.version;
        _draft = selectedDraft;
        _draft.localId = selected.version.firestoreId ?? _stableDraftLocalId();
        _applyMatrixMetaToDraft();
        _synchronizeTitleControllerFromDraft();
        _editingTemplateDraftFingerprint =
            ModuleComposerJsonBuilder.semanticFingerprint(_draft);
        _selectedModuleIndex = _draft.modules.isEmpty ? -1 : 0;
        _mergeSelection.clear();
      });
    } finally {
      _suppressRecoverySave = false;
    }

    _showSnack(
      'Resumed ${selected.package.packageCode} v${selected.version.versionNumber}.',
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

    final result = await PublishMetadataDialog.show(
      context,
      actor: actor,
      draft: _draft,
      existingPackages: activePackages,
      initialPackageCode: _suggestPublishPackageCode(),
      initialPackageTitle: _draft.title,
      initialPackageFirestoreId: _editingTemplateVersion?.packageFirestoreId,
      initialVersion: _editingTemplateVersion,
      hasUnsavedComposerChanges:
          _editingTemplateVersion != null &&
          _editingTemplateDraftFingerprint !=
              ModuleComposerJsonBuilder.semanticFingerprint(_draft),
      actions: PublishMetadataDialogActions(
        savePackage: (package, actionActor) {
          return repository.savePackage(package, actor: actionActor);
        },
        saveVersionDraft: (version, actionActor) {
          return saveAndRefreshComposerTemplateVersionDraft(
            version: version,
            persistLocal: () async {
              await repository.saveVersion(version, actor: actionActor);
              await _clearRecoveryDraft();
            },
            runSync:
                () => ref
                    .read(syncCoordinatorProvider)
                    .runFullSyncWithResult(
                      reason: 'template_governance_draft_saved_from_composer',
                      force: true,
                    ),
            reloadLocal: repository.getVersionByFirestoreId,
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
          return version;
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

    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _editingTemplateVersion = result.published ? null : result.version;
      if (result.published) {
        _editingTemplateDraftFingerprint = null;
      } else {
        _draft.localId = result.version.firestoreId ?? _draft.localId;
        _editingTemplateDraftFingerprint =
            ModuleComposerJsonBuilder.semanticFingerprint(_draft);
      }
    });
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
              draftModules: _draft.modules
                  .map(cloneComposerModuleDraft)
                  .toList(growable: false),
              loadDraftRevisions: repository.getDraftRevisions,
              loadPublishedSources: repository.getPublishedSources,
              createDraft: (liveActor, module, reason) {
                return repository.createDraftFromModule(
                  module: module,
                  actor: liveActor,
                  sourceType: 'moduleComposerDraft',
                  lineage: <String, dynamic>{
                    'sourceModuleCode': module.moduleCode,
                    'sourceLocalId': module.localId,
                    'createdFromRegistryAuthoringUi': true,
                  },
                  reason: reason,
                );
              },
              updateDraft: (liveActor, revision, module, reason) {
                return repository.updateDraftRevision(
                  revision: revision,
                  module: module,
                  actor: liveActor,
                  sourceType: 'moduleComposerDraft',
                  lineage: <String, dynamic>{
                    'sourceModuleCode': module.moduleCode,
                    'sourceLocalId': module.localId,
                    'updatedFromRegistryAuthoringUi': true,
                  },
                  reason: reason,
                );
              },
              publishDraft: (liveActor, revision, reason) {
                return repository.publishDraftRevision(
                  registryModuleId: revision.registryModuleId,
                  revisionId: revision.revisionId,
                  actor: liveActor,
                  reason: reason,
                );
              },
              retireRevision: (liveActor, revision, reason) {
                return repository.retirePublishedRevision(
                  revision: revision,
                  actor: liveActor,
                  reason: reason,
                );
              },
              retireFamily: (liveActor, family, reason) {
                return repository.retireFamily(
                  family: family,
                  actor: liveActor,
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
    final needsGovernedJustification =
        field.isSafetyCriticalPreset ||
        field.evidenceRole != ComposerEvidenceRole.none;
    if (needsGovernedJustification) {
      final reason = await _askSafetyJustification(field);
      if (!mounted || reason == null || reason.trim().isEmpty) {
        return;
      }
      _draft.safetyJustifications.add(
        SafetyJustificationDraft(fieldKey: field.key, reason: reason.trim()),
      );
    } else {
      final confirmed = await _confirmComposerDelete(
        title: 'Delete field?',
        message:
            'Delete "${field.label}" from module ${module.moduleCode}? '
            'This removes the field from the current Composer draft.',
      );
      if (!mounted || !confirmed) {
        return;
      }
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
      builder: (context) => ComposerFieldEditorDialog(field: field),
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
      field.validation = Map<String, dynamic>.from(edited.validation);
      field.meta = Map<String, dynamic>.from(edited.meta);
      field.isSafetyCriticalPreset = edited.isSafetyCriticalPreset;
      field.sourcePresetId = edited.sourcePresetId;
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

  Future<bool> _confirmComposerDelete({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('composer-confirm-delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return confirmed == true;
  }

  Future<void> _removeChecklistItem(
    ComposerModuleDraft module,
    ComposerChecklistItemDraft item,
  ) async {
    final confirmed = await _confirmComposerDelete(
      title: 'Delete checklist item?',
      message:
          'Delete "${item.title}" from module ${module.moduleCode}? '
          'This removes the item from the current Composer draft.',
    );
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => module.checklistItems.remove(item));
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
}
