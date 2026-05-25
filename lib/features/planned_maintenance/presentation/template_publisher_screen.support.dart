part of 'template_publisher_screen.dart';

extension _TemplatePublisherSupport on _TemplatePublisherScreenState {
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
      _setPublisherState(apply);
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
    _setPublisherState(() {
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

  void _resetVersionPayloads({bool keepVersionLabel = true}) {
    _setPublisherState(() {
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
}
