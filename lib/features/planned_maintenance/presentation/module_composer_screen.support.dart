part of 'module_composer_screen.dart';

/// Persists a Composer TemplateVersion draft, waits for a full sync, and then
/// re-reads the same governed record from the local repository.
///
/// The helper deliberately returns only a remotely confirmed draft. A locally
/// saved but still-unsynced record remains preserved and retryable, but it is
/// not presented to the Composer as publish-eligible.
Future<TemplateVersion> saveAndRefreshComposerTemplateVersionDraft({
  required TemplateVersion version,
  required Future<void> Function() persistLocal,
  required Future<SyncRequestOutcome> Function() runSync,
  required Future<TemplateVersion?> Function(String firestoreId) reloadLocal,
}) async {
  await persistLocal();

  final firestoreId = version.firestoreId?.trim();
  if (firestoreId == null || firestoreId.isEmpty) {
    throw StateError(
      'Draft was saved locally but has no stable Firestore identity.',
    );
  }
  final expectedLocalId = version.id;
  final expectedPackageFirestoreId = version.packageFirestoreId?.trim();
  final expectedVersionNumber = version.versionNumber;
  final expectedRecordVersion = version.version;
  final expectedCreatedAt = version.createdAt;
  final expectedHash = version.contentHash?.trim();
  final expectedVersionLabel = version.versionLabel?.trim();
  final expectedReleaseNotes = version.releaseNotes?.trim();
  final expectedChangeSummary = version.changeSummary?.trim();
  final expectedMinAppVersion = version.minAppVersion?.trim();
  final expectedMetadataJson = version.metadataJson?.trim();

  final syncOutcome = await runSync();
  final refreshed = await reloadLocal(firestoreId);
  if (refreshed == null) {
    throw StateError(
      'Draft $firestoreId was saved locally but could not be reloaded after sync.',
    );
  }
  if (refreshed.firestoreId != firestoreId) {
    throw StateError(
      'Draft identity changed during save/sync refresh. Expected '
      '$firestoreId, found ${refreshed.firestoreId}.',
    );
  }
  if (refreshed.id != expectedLocalId) {
    throw StateError(
      'Draft local identity changed during save/sync refresh. Expected '
      '$expectedLocalId, found ${refreshed.id}.',
    );
  }
  if (refreshed.packageFirestoreId?.trim() != expectedPackageFirestoreId) {
    throw StateError(
      'Draft $firestoreId changed package identity during save/sync refresh.',
    );
  }
  if (refreshed.versionNumber != expectedVersionNumber) {
    throw StateError(
      'Draft $firestoreId changed version number during save/sync refresh. '
      'Expected $expectedVersionNumber, found ${refreshed.versionNumber}.',
    );
  }
  if (refreshed.version != expectedRecordVersion) {
    throw StateError(
      'Draft $firestoreId changed record version during save/sync refresh. '
      'Expected $expectedRecordVersion, found ${refreshed.version}.',
    );
  }
  if (!refreshed.createdAt.isAtSameMomentAs(expectedCreatedAt)) {
    throw StateError(
      'Draft $firestoreId changed creation metadata during save/sync refresh.',
    );
  }
  if (refreshed.versionLabel?.trim() != expectedVersionLabel ||
      refreshed.releaseNotes?.trim() != expectedReleaseNotes ||
      refreshed.changeSummary?.trim() != expectedChangeSummary ||
      refreshed.minAppVersion?.trim() != expectedMinAppVersion ||
      refreshed.metadataJson?.trim() != expectedMetadataJson) {
    throw StateError(
      'Draft $firestoreId authoring metadata changed during save/sync refresh.',
    );
  }
  if (!refreshed.isDraft) {
    throw StateError(
      'Draft $firestoreId changed lifecycle state during save/sync refresh.',
    );
  }

  final refreshedHash = refreshed.contentHash?.trim();
  if (expectedHash != null &&
      expectedHash.isNotEmpty &&
      refreshedHash != expectedHash) {
    throw StateError(
      'Draft $firestoreId payload changed during save/sync refresh.',
    );
  }

  if (!refreshed.isSynced) {
    final syncDetail = switch (syncOutcome) {
      SyncRequestOutcome.succeeded =>
        'Sync completed without a confirmed draft acknowledgement.',
      SyncRequestOutcome.failed => 'Sync failed before confirmation.',
      SyncRequestOutcome.queued =>
        'Sync is queued behind the run already in progress.',
      SyncRequestOutcome.throttled =>
        'Sync was throttled because another run completed recently.',
    };
    throw StateError(
      'Draft $firestoreId is saved locally and remains retryable, but '
      'Firestore has not confirmed it. $syncDetail',
    );
  }

  return refreshed;
}

extension _ModuleComposerSupport on _ModuleComposerScreenState {
  ComposerModuleDraft? get _selectedModule {
    if (_selectedModuleIndex < 0 ||
        _selectedModuleIndex >= _draft.modules.length) {
      return null;
    }
    return _draft.modules[_selectedModuleIndex];
  }

  String get _recoveryKey {
    final liveActor = ref.read(currentAppUserProvider).asData?.value;
    final actor = _safeKeySegment(
      liveActor?.canManageTemplateGovernance == true
          ? liveActor!.uid
          : 'unverified_actor',
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

  void _synchronizeTitleControllerFromDraft() {
    final nextTitle = _draft.title;
    if (_titleController.text == nextTitle) {
      return;
    }
    _titleController.value = TextEditingValue(
      text: nextTitle,
      selection: TextSelection.collapsed(offset: nextTitle.length),
    );
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

  bool _hasLiveComposerAuthority({String? expectedUid}) {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    return actor != null &&
        actor.canManageTemplateGovernance &&
        (expectedUid == null || actor.uid == expectedUid);
  }

  Future<void> _loadKnowledgeRows() async {
    if (!_hasLiveComposerAuthority()) {
      return;
    }
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
    if (!mounted || !_hasLiveComposerAuthority()) {
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
    final actor = ref.read(currentAppUserProvider).asData?.value;
    final canConfirm = actor?.canManageTemplateGovernance == true;
    _draft.closureReviewConfirmed = value && canConfirm;
    if (value && canConfirm) {
      _draft.metadata['closureReviewConfirmedAt'] =
          DateTime.now().toIso8601String();
      _draft.metadata['closureReviewConfirmedByUid'] = actor!.uid;
      _draft.metadata['closureReviewConfirmedByName'] = actor.name;
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
    if (!mounted || !_hasLiveComposerAuthority() || _draft.modules.isEmpty) {
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
    if (!_hasLiveComposerAuthority()) {
      return;
    }
    _recoverySaveDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recoveryKey);
  }

  Future<void> _checkForRecoverableDraft() async {
    if (!_hasLiveComposerAuthority()) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recoveryKey);
    if (raw == null ||
        raw.trim().isEmpty ||
        !mounted ||
        !_hasLiveComposerAuthority()) {
      return;
    }
    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      _showSnack(
        'Saved recovery draft needs repair and was left untouched.',
        BafColors.danger,
      );
      return;
    }
    final savedAt = decoded['savedAt']?.toString() ?? 'unknown time';
    if (!mounted || !_hasLiveComposerAuthority()) {
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
    if (!mounted || !_hasLiveComposerAuthority()) {
      return;
    }
    if (restore != true) {
      await prefs.remove(_recoveryKey);
      return;
    }
    late final TemplateComposerDraft recoveredDraft;
    try {
      recoveredDraft = TemplateComposerDraft.fromPayloads(
        jobTemplateSnapshotJson: _requiredRecoveryPayload(
          decoded,
          'jobTemplateSnapshotJson',
        ),
        moduleSnapshotsJson: _requiredRecoveryPayload(
          decoded,
          'moduleSnapshotsJson',
        ),
        fieldDefinitionsJson: _requiredRecoveryPayload(
          decoded,
          'fieldDefinitionsJson',
        ),
        checklistJson: _requiredRecoveryPayload(decoded, 'checklistJson'),
      );
    } on FormatException catch (error) {
      _showSnack(
        'Saved recovery draft needs repair and was left untouched: ${error.message}',
        BafColors.danger,
      );
      return;
    }

    _suppressRecoverySave = true;
    try {
      setState(() {
        _draft = recoveredDraft;
        if (_draft.localId.trim().isEmpty) {
          _draft.localId = _stableDraftLocalId();
        }
        _applyMatrixMetaToDraft();
        _synchronizeTitleControllerFromDraft();
        _selectedModuleIndex = _draft.modules.isEmpty ? -1 : 0;
      });
    } finally {
      _suppressRecoverySave = false;
    }
    _showSnack('Recovered unsaved Module Composer draft.', BafColors.sync);
  }

  String _requiredRecoveryPayload(Map<String, dynamic> payload, String field) {
    final value = payload[field];
    if (value is String) return value;
    throw PersistedDataFormatException(
      field: field,
      source: 'Module Composer recovery draft',
      detail: 'required JSON string (${value.runtimeType})',
    );
  }
}
