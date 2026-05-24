part of 'module_composer_screen.dart';

extension _ModuleComposerSupport on _ModuleComposerScreenState {
  ComposerModuleDraft? get _selectedModule {
    if (_selectedModuleIndex < 0 ||
        _selectedModuleIndex >= _draft.modules.length) {
      return null;
    }
    return _draft.modules[_selectedModuleIndex];
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
}
