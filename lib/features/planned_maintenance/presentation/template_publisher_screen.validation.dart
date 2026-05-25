part of 'template_publisher_screen.dart';

extension _TemplatePublisherValidation on _TemplatePublisherScreenState {
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
}
