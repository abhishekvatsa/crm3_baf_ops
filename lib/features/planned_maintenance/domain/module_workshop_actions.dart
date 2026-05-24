import 'module_composer_models.dart';

/// Returns a deep working copy of a composer module without changing identity.
///
/// Issue 65B uses this for the focused editor so Cancel can discard local
/// edits and Save can return the edited copy to the composer. This helper is
/// still UI/domain-only and does not persist, sync, publish, or mutate the
/// source module.
ComposerModuleDraft cloneComposerModuleDraft(ComposerModuleDraft source) {
  return ComposerModuleDraft(
    localId: source.localId,
    moduleCode: source.moduleCode,
    title: source.title,
    description: source.description,
    assetType: source.assetType,
    discipline: source.discipline,
    ownerDisciplines: List<String>.from(source.ownerDisciplines),
    primaryOwner: source.primaryOwner,
    requiresJointReview: source.requiresJointReview,
    useMode: source.useMode,
    functionalSection: source.functionalSection,
    componentGroup: source.componentGroup,
    subsystem: source.subsystem,
    safetyClasses: List<String>.from(source.safetyClasses),
    targetRefs: List<String>.from(source.targetRefs),
    deviceTagRefs: List<String>.from(source.deviceTagRefs),
    procedureRefs: List<String>.from(source.procedureRefs),
    partRefs: List<String>.from(source.partRefs),
    operationalStatePreconditions: List<String>.from(
      source.operationalStatePreconditions,
    ),
    requiredForClosure: source.requiredForClosure,
    frequency: source.frequency,
    fields: source.fields.map(cloneComposerFieldDraft).toList(),
    checklistItems:
        source.checklistItems.map(cloneComposerChecklistItemDraft).toList(),
    sourceManualRef: source.sourceManualRef,
    sourceKnowledgeId: source.sourceKnowledgeId,
    sourceSeedCode: source.sourceSeedCode,
    sourceReadiness: source.sourceReadiness,
    confidence: source.confidence,
    authoringNotes: source.authoringNotes,
    metadata: _cloneStringKeyedMap(source.metadata),
  );
}

ComposerFieldDraft cloneComposerFieldDraft(ComposerFieldDraft source) {
  return ComposerFieldDraft(
    key: source.key,
    label: source.label,
    type: source.type,
    isRequired: source.isRequired,
    order: source.order,
    unit: source.unit,
    options: List<String>.from(source.options),
    instructionText: source.instructionText,
    validation: _cloneStringKeyedMap(source.validation),
    meta: _cloneStringKeyedMap(source.meta),
    isSafetyCriticalPreset: source.isSafetyCriticalPreset,
    sourcePresetId: source.sourcePresetId,
  );
}

ComposerChecklistItemDraft cloneComposerChecklistItemDraft(
  ComposerChecklistItemDraft source,
) {
  return ComposerChecklistItemDraft(
    id: source.id,
    title: source.title,
    description: source.description,
    isRequired: source.isRequired,
    order: source.order,
    linkedFieldKey: source.linkedFieldKey,
    safetyClasses: List<String>.from(source.safetyClasses),
    metadata: _cloneStringKeyedMap(source.metadata),
  );
}

Map<String, dynamic> cloneComposerMetadata(Map<String, dynamic> source) {
  return _cloneStringKeyedMap(source);
}

/// Pure Module Workshop draft actions.
///
/// Issue 65A deliberately keeps this helper local/domain-only: it does not
/// persist, sync, publish, or mutate the source module. Registry, Firestore,
/// and TemplateVersion behavior remain outside this foundation phase.
ComposerModuleDraft duplicateComposerModule({
  required ComposerModuleDraft source,
  required Iterable<ComposerModuleDraft> existingModules,
  DateTime? now,
}) {
  final duplicatedAt = now ?? DateTime.now();
  final oldModuleCode = source.moduleCode.trim();
  final newModuleCode = _uniqueModuleCode(
    _copyModuleCodeBase(oldModuleCode),
    existingModules.map((module) => module.moduleCode),
  );

  final fields = <ComposerFieldDraft>[
    for (final field in source.fields) _duplicateField(field),
  ];

  final usedChecklistIds = <String>{};
  final checklistItems = <ComposerChecklistItemDraft>[
    for (var i = 0; i < source.checklistItems.length; i++)
      _duplicateChecklistItem(
        source.checklistItems[i],
        oldModuleCode: oldModuleCode,
        newModuleCode: newModuleCode,
        order:
            source.checklistItems[i].order > 0
                ? source.checklistItems[i].order
                : i + 1,
        usedIds: usedChecklistIds,
      ),
  ];

  return ComposerModuleDraft(
    localId: 'module-copy-${duplicatedAt.microsecondsSinceEpoch}',
    moduleCode: newModuleCode,
    title: _copyTitle(source.title),
    description: source.description,
    assetType: source.assetType,
    discipline: source.discipline,
    ownerDisciplines: List<String>.from(source.ownerDisciplines),
    primaryOwner: source.primaryOwner,
    requiresJointReview: source.requiresJointReview,
    useMode: source.useMode,
    functionalSection: source.functionalSection,
    componentGroup: source.componentGroup,
    subsystem: source.subsystem,
    safetyClasses: List<String>.from(source.safetyClasses),
    targetRefs: List<String>.from(source.targetRefs),
    deviceTagRefs: List<String>.from(source.deviceTagRefs),
    procedureRefs: List<String>.from(source.procedureRefs),
    partRefs: List<String>.from(source.partRefs),
    operationalStatePreconditions: List<String>.from(
      source.operationalStatePreconditions,
    ),
    requiredForClosure: source.requiredForClosure,
    frequency: source.frequency,
    fields: fields,
    checklistItems: checklistItems,
    sourceManualRef: source.sourceManualRef,
    sourceKnowledgeId: source.sourceKnowledgeId,
    sourceSeedCode: source.sourceSeedCode,
    sourceReadiness: source.sourceReadiness,
    confidence: source.confidence,
    authoringNotes: source.authoringNotes,
    metadata: <String, dynamic>{
      ..._cloneStringKeyedMap(source.metadata),
      'duplicatedFromModuleCode': source.moduleCode,
      'duplicatedFromLocalId': source.localId,
      'duplicatedAt': duplicatedAt.toIso8601String(),
    },
  );
}

ComposerFieldDraft _duplicateField(ComposerFieldDraft source) {
  return ComposerFieldDraft(
    key: source.key,
    label: source.label,
    type: source.type,
    isRequired: source.isRequired,
    order: source.order,
    unit: source.unit,
    options: List<String>.from(source.options),
    instructionText: source.instructionText,
    validation: _cloneStringKeyedMap(source.validation),
    meta: _cloneStringKeyedMap(source.meta),
    isSafetyCriticalPreset: source.isSafetyCriticalPreset,
    sourcePresetId: source.sourcePresetId,
  );
}

ComposerChecklistItemDraft _duplicateChecklistItem(
  ComposerChecklistItemDraft source, {
  required String oldModuleCode,
  required String newModuleCode,
  required int order,
  required Set<String> usedIds,
}) {
  final baseId = _candidateChecklistId(
    source.id,
    oldModuleCode: oldModuleCode,
    newModuleCode: newModuleCode,
    order: order,
  );
  final id = _uniqueValue(baseId, usedIds);
  usedIds.add(id.toLowerCase());

  return ComposerChecklistItemDraft(
    id: id,
    title: source.title,
    description: source.description,
    isRequired: source.isRequired,
    order: order,
    linkedFieldKey: source.linkedFieldKey,
    safetyClasses: List<String>.from(source.safetyClasses),
    metadata: <String, dynamic>{
      ..._cloneStringKeyedMap(source.metadata),
      'duplicatedFromChecklistItemId': source.id,
    },
  );
}

String _copyTitle(String title) {
  final trimmed = title.trim();
  final base = trimmed.isEmpty ? 'Untitled module' : trimmed;
  return base.toLowerCase().endsWith('(copy)') ? base : '$base (copy)';
}

String _copyModuleCodeBase(String moduleCode) {
  final trimmed = moduleCode.trim();
  final base = trimmed.isEmpty ? 'MODULE' : trimmed;
  return base.toUpperCase().endsWith('-COPY') ? base : '$base-COPY';
}

String _uniqueModuleCode(String base, Iterable<String> existingModuleCodes) {
  final existing =
      existingModuleCodes
          .map((code) => code.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet();
  var code = base.trim().isEmpty ? 'MODULE-COPY' : base.trim();
  if (!existing.contains(code.toLowerCase())) {
    return code;
  }

  var suffix = 2;
  while (existing.contains('$code-$suffix'.toLowerCase())) {
    suffix += 1;
  }
  return '$code-$suffix';
}

String _candidateChecklistId(
  String sourceId, {
  required String oldModuleCode,
  required String newModuleCode,
  required int order,
}) {
  final trimmed = sourceId.trim();
  if (trimmed.isEmpty) {
    return '$newModuleCode-item-$order';
  }
  if (oldModuleCode.isNotEmpty &&
      trimmed.toLowerCase().startsWith(oldModuleCode.toLowerCase())) {
    return '$newModuleCode${trimmed.substring(oldModuleCode.length)}';
  }
  return trimmed;
}

String _uniqueValue(String base, Set<String> existingLowerCaseValues) {
  var value = base.trim().isEmpty ? 'item' : base.trim();
  if (!existingLowerCaseValues.contains(value.toLowerCase())) {
    return value;
  }

  var suffix = 2;
  while (existingLowerCaseValues.contains('$value-$suffix'.toLowerCase())) {
    suffix += 1;
  }
  return '$value-$suffix';
}

Map<String, dynamic> _cloneStringKeyedMap(Map<String, dynamic> source) {
  return source.map((key, value) => MapEntry(key, _cloneJsonLikeValue(value)));
}

dynamic _cloneJsonLikeValue(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _cloneJsonLikeValue(entry.value),
    };
  }
  if (value is List) {
    return value.map(_cloneJsonLikeValue).toList();
  }
  if (value is Set) {
    return value.map(_cloneJsonLikeValue).toList();
  }
  return value;
}
