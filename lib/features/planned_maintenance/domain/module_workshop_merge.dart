import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import 'module_composer_models.dart';
import 'module_workshop_actions.dart';

const String mergeConflictWorkspaceMetadataKey = 'mergeConflictWorkspace';

bool hasUnresolvedMergeConflicts(ComposerModuleDraft module) {
  final workspace = module.metadata[mergeConflictWorkspaceMetadataKey];
  return workspace is Map && workspace['status'] == 'unresolved';
}

int unresolvedMergeConflictCount(ComposerModuleDraft module) {
  final workspace = module.metadata[mergeConflictWorkspaceMetadataKey];
  if (workspace is! Map) {
    return 0;
  }
  final conflicts = workspace['conflicts'];
  return conflicts is List && workspace['status'] == 'unresolved'
      ? conflicts.length
      : 0;
}

List<String> unresolvedMergeConflictSummaries(ComposerModuleDraft module) {
  final workspace = module.metadata[mergeConflictWorkspaceMetadataKey];
  if (workspace is! Map || workspace['status'] != 'unresolved') {
    return const <String>[];
  }
  final conflicts = workspace['conflicts'];
  if (conflicts is! List) {
    return const <String>[];
  }
  return conflicts
      .whereType<Map>()
      .map((conflict) => (conflict['summary'] ?? '').toString().trim())
      .where((summary) => summary.isNotEmpty)
      .toList(growable: false);
}

List<String> mergeFieldRenameSummaries(ComposerModuleDraft module) {
  final summaries = <String>[];
  for (final field in module.fields) {
    final meta = field.meta;
    if (meta['mergeConflictStagedKey'] != true) {
      continue;
    }
    final sourceModuleCode =
        (meta['mergeSourceModuleCode'] ?? '').toString().trim();
    final originalFieldKey =
        (meta['mergeOriginalFieldKey'] ?? '').toString().trim();
    final stagedFieldKey = field.key.trim();
    if (originalFieldKey.isEmpty || stagedFieldKey.isEmpty) {
      continue;
    }
    final sourcePrefix = sourceModuleCode.isEmpty ? '' : '$sourceModuleCode: ';
    summaries.add('$sourcePrefix$originalFieldKey → $stagedFieldKey');
  }
  return summaries;
}

void markMergeConflictsResolved(
  ComposerModuleDraft module, {
  DateTime? resolvedAt,
  String? note,
}) {
  final workspace = module.metadata[mergeConflictWorkspaceMetadataKey];
  if (workspace is! Map) {
    return;
  }
  module.metadata[mergeConflictWorkspaceMetadataKey] = <String, dynamic>{
    ..._cloneMap(workspace.cast<String, dynamic>()),
    'status': 'resolved',
    'resolvedAt': (resolvedAt ?? DateTime.now()).toIso8601String(),
    if (note != null && note.trim().isNotEmpty) 'resolutionNote': note.trim(),
  };
}

ComposerModuleDraft mergeComposerModulesWithConflictWorkspace({
  required List<ComposerModuleDraft> sources,
  required Iterable<ComposerModuleDraft> existingModules,
  DateTime? now,
}) {
  if (sources.length < 2) {
    throw ArgumentError.value(
      sources.length,
      'sources.length',
      'Merge requires at least two modules.',
    );
  }

  final mergedAt = now ?? DateTime.now();
  final primary = sources.first;
  final newModuleCode = _uniqueModuleCode(
    _mergeModuleCodeBase(primary.moduleCode),
    existingModules.map((module) => module.moduleCode),
  );
  final sourceSummaries = <Map<String, dynamic>>[
    for (var i = 0; i < sources.length; i++)
      <String, dynamic>{
        'mergeOrder': i + 1,
        'localId': sources[i].localId,
        'moduleCode': sources[i].moduleCode,
        'title': sources[i].title,
        'requiredForClosure': sources[i].requiredForClosure,
        'discipline': sources[i].discipline.name,
      },
  ];
  final conflicts = <Map<String, dynamic>>[];

  final ownerDisciplines = _unionStrings(
    sources.expand((module) => module.ownerDisciplines),
  );
  final safetyClasses = _unionStrings(
    sources.expand((module) => module.safetyClasses),
  );
  final targetRefs = _unionStrings(
    sources.expand((module) => module.targetRefs),
  );
  final deviceTagRefs = _unionStrings(
    sources.expand((module) => module.deviceTagRefs),
  );
  final procedureRefs = _unionStrings(
    sources.expand((module) => module.procedureRefs),
  );
  final partRefs = _unionStrings(sources.expand((module) => module.partRefs));
  final preconditions = _unionStrings(
    sources.expand((module) => module.operationalStatePreconditions),
  );

  final discipline = _mergeDiscipline(
    sources.map((module) => module.discipline),
  );
  final primaryOwner = _sameCleanValue(
    sources.map((module) => module.primaryOwner),
  );
  final assetType = _sameValueOrPrimary<AssetType>(
    values: sources.map((module) => module.assetType),
    primary: primary.assetType,
    conflictType: 'assetTypeConflict',
    label: 'Asset type differs across source modules.',
    conflicts: conflicts,
  );
  final useMode = _sameValueOrPrimary<JobModuleUseMode>(
    values: sources.map((module) => module.useMode),
    primary: primary.useMode,
    conflictType: 'useModeConflict',
    label: 'Use mode differs across source modules.',
    conflicts: conflicts,
  );
  final frequency = _sameValueOrUnknownFrequency(
    sources.map((module) => module.frequency),
    conflicts,
  );
  final functionalSection = _sameStringOrPrimary(
    values: sources.map((module) => module.functionalSection),
    primary: primary.functionalSection,
    conflictType: 'functionalSectionConflict',
    label: 'Functional section differs across source modules.',
    conflicts: conflicts,
  );
  final componentGroup = _sameStringOrPrimary(
    values: sources.map((module) => module.componentGroup),
    primary: primary.componentGroup,
    conflictType: 'componentGroupConflict',
    label: 'Component group differs across source modules.',
    conflicts: conflicts,
  );
  final subsystem = _sameStringOrPrimary(
    values: sources.map((module) => module.subsystem),
    primary: primary.subsystem,
    conflictType: 'subsystemConflict',
    label: 'Subsystem differs across source modules.',
    conflicts: conflicts,
  );

  final fieldMerge = _mergeFields(sources: sources, conflicts: conflicts);
  final checklistItems = _mergeChecklistItems(
    sources: sources,
    newModuleCode: newModuleCode,
    fieldKeyRemapBySource: fieldMerge.fieldKeyRemapBySource,
  );

  return ComposerModuleDraft(
    localId: 'module-merge-${mergedAt.microsecondsSinceEpoch}',
    moduleCode: newModuleCode,
    title: _mergedTitle(sources),
    description: _mergedDescription(sources),
    assetType: assetType,
    discipline: discipline,
    ownerDisciplines:
        ownerDisciplines.isEmpty ? <String>['shared'] : ownerDisciplines,
    primaryOwner: primaryOwner,
    requiresJointReview:
        sources.any((module) => module.requiresJointReview) ||
        ownerDisciplines.length > 1 ||
        discipline == JobModuleDiscipline.shared,
    useMode: useMode,
    functionalSection: functionalSection,
    componentGroup: componentGroup,
    subsystem: subsystem,
    safetyClasses: safetyClasses.isEmpty ? <String>['normal'] : safetyClasses,
    targetRefs: targetRefs,
    deviceTagRefs: deviceTagRefs,
    procedureRefs: procedureRefs,
    partRefs: partRefs,
    operationalStatePreconditions: preconditions,
    requiredForClosure: sources.any((module) => module.requiredForClosure),
    frequency: frequency,
    fields: fieldMerge.fields,
    checklistItems: checklistItems,
    sourceReadiness: ComposerReadiness.needsReview,
    confidence: KnowledgeConfidence.inferredNeedsReview,
    authoringNotes: _mergedAuthoringNotes(sources),
    metadata: <String, dynamic>{
      'source': 'moduleWorkshopMerge',
      'mergedAt': mergedAt.toIso8601String(),
      'mergedFromModuleCodes': [
        for (final module in sources) module.moduleCode,
      ],
      mergeConflictWorkspaceMetadataKey: <String, dynamic>{
        'status': conflicts.isEmpty ? 'clean' : 'unresolved',
        'createdAt': mergedAt.toIso8601String(),
        'sourceModules': sourceSummaries,
        'conflicts': conflicts,
      },
    },
  );
}

_FieldMergeResult _mergeFields({
  required List<ComposerModuleDraft> sources,
  required List<Map<String, dynamic>> conflicts,
}) {
  final fields = <ComposerFieldDraft>[];
  final usedKeys = <String>{};
  final keyOwners = <String, List<String>>{};
  final fieldKeyRemapBySource = <String, Map<String, String>>{};

  for (final module in sources) {
    final sourceMap = fieldKeyRemapBySource.putIfAbsent(
      module.localId,
      () => <String, String>{},
    );
    for (final sourceField in module.fields) {
      final originalKey =
          sourceField.key.trim().isEmpty ? 'field' : sourceField.key.trim();
      final normalized = originalKey.toLowerCase();
      var newKey = originalKey;
      if (usedKeys.contains(normalized)) {
        newKey = _uniqueValue(
          '$originalKey-merge-${_slug(module.moduleCode)}',
          usedKeys,
        );
        conflicts.add(<String, dynamic>{
          'type': 'fieldKeyConflict',
          'summary':
              'Field key "$originalKey" appeared in multiple source modules and was staged as "$newKey".',
          'fieldKey': originalKey,
          'stagedFieldKey': newKey,
          'sourceModuleCode': module.moduleCode,
          'otherSourceModuleCodes': keyOwners[normalized] ?? const <String>[],
        });
      }
      usedKeys.add(newKey.toLowerCase());
      keyOwners
          .putIfAbsent(normalized, () => <String>[])
          .add(module.moduleCode);
      sourceMap[originalKey] = newKey;
      final copy = cloneComposerFieldDraft(sourceField);
      copy.key = newKey;
      copy.order = fields.length + 1;
      copy.meta = <String, dynamic>{
        ...cloneComposerMetadata(copy.meta),
        'mergeSourceModuleCode': module.moduleCode,
        'mergeOriginalFieldKey': originalKey,
        if (newKey != originalKey) 'mergeConflictStagedKey': true,
      };
      fields.add(copy);
    }
  }
  return _FieldMergeResult(
    fields: fields,
    fieldKeyRemapBySource: fieldKeyRemapBySource,
  );
}

List<ComposerChecklistItemDraft> _mergeChecklistItems({
  required List<ComposerModuleDraft> sources,
  required String newModuleCode,
  required Map<String, Map<String, String>> fieldKeyRemapBySource,
}) {
  final items = <ComposerChecklistItemDraft>[];
  final usedIds = <String>{};
  for (final module in sources) {
    final fieldMap =
        fieldKeyRemapBySource[module.localId] ?? const <String, String>{};
    for (final sourceItem in module.checklistItems) {
      final copy = cloneComposerChecklistItemDraft(sourceItem);
      final originalId =
          copy.id.trim().isEmpty ? 'item-${items.length + 1}' : copy.id.trim();
      copy.id = _uniqueValue(
        '$newModuleCode-${_slug(module.moduleCode)}-${_slug(originalId)}',
        usedIds,
      );
      usedIds.add(copy.id.toLowerCase());
      copy.order = items.length + 1;
      final linked = copy.linkedFieldKey?.trim();
      if (linked != null && linked.isNotEmpty && fieldMap.containsKey(linked)) {
        copy.linkedFieldKey = fieldMap[linked];
      }
      copy.metadata = <String, dynamic>{
        ...cloneComposerMetadata(copy.metadata),
        'mergeSourceModuleCode': module.moduleCode,
        'mergeOriginalChecklistItemId': sourceItem.id,
      };
      items.add(copy);
    }
  }
  return items;
}

class _FieldMergeResult {
  final List<ComposerFieldDraft> fields;
  final Map<String, Map<String, String>> fieldKeyRemapBySource;

  const _FieldMergeResult({
    required this.fields,
    required this.fieldKeyRemapBySource,
  });
}

JobModuleDiscipline _mergeDiscipline(Iterable<JobModuleDiscipline> values) {
  final unique = values.map((value) => value.name).toSet();
  if (unique.length == 1 && unique.single != JobModuleDiscipline.shared.name) {
    return values.first;
  }
  return JobModuleDiscipline.shared;
}

T _sameValueOrPrimary<T>({
  required Iterable<T> values,
  required T primary,
  required String conflictType,
  required String label,
  required List<Map<String, dynamic>> conflicts,
}) {
  final list = values.toList(growable: false);
  if (list.toSet().length <= 1) {
    return primary;
  }
  conflicts.add(<String, dynamic>{
    'type': conflictType,
    'summary': '$label Primary source value was kept as the staged default.',
    'primaryDefault': primary.toString(),
    'values': [for (final value in list) value.toString()],
  });
  return primary;
}

MaintenanceFrequency _sameValueOrUnknownFrequency(
  Iterable<MaintenanceFrequency> values,
  List<Map<String, dynamic>> conflicts,
) {
  final list = values.toList(growable: false);
  if (list.toSet().length <= 1) {
    return list.first;
  }
  conflicts.add(<String, dynamic>{
    'type': 'frequencyConflict',
    'summary':
        'Frequency differs across source modules and was staged as unknown.',
    'values': [for (final value in list) value.name],
  });
  return MaintenanceFrequency.unknown;
}

String _sameStringOrPrimary({
  required Iterable<String> values,
  required String primary,
  required String conflictType,
  required String label,
  required List<Map<String, dynamic>> conflicts,
}) {
  final cleaned = values.map((value) => value.trim()).toList(growable: false);
  final nonEmpty = cleaned.where((value) => value.isNotEmpty).toSet();
  if (nonEmpty.length <= 1) {
    return nonEmpty.isEmpty ? primary.trim() : nonEmpty.first;
  }
  conflicts.add(<String, dynamic>{
    'type': conflictType,
    'summary': '$label Primary source value was kept as the staged default.',
    'primaryDefault': primary.trim(),
    'values': nonEmpty.toList(growable: false),
  });
  return primary.trim();
}

String? _sameCleanValue(Iterable<String?> values) {
  final cleaned =
      values
          .map((value) => value?.trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet();
  return cleaned.length == 1 ? cleaned.single : null;
}

List<String> _unionStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (seen.add(trimmed.toLowerCase())) {
      result.add(trimmed);
    }
  }
  return result;
}

String _mergedTitle(List<ComposerModuleDraft> sources) {
  final primaryTitle =
      sources.first.title.trim().isEmpty
          ? sources.first.moduleCode
          : sources.first.title.trim();
  return 'Merged $primaryTitle + ${sources.length - 1} module${sources.length == 2 ? '' : 's'}';
}

String _mergedDescription(List<ComposerModuleDraft> sources) {
  return [
    'Merged draft module created from:',
    for (final source in sources) '- ${source.moduleCode}: ${source.title}',
  ].join('\n');
}

String _mergedAuthoringNotes(List<ComposerModuleDraft> sources) {
  return 'Review merge conflict workspace before publishing. Sources: ${sources.map((module) => module.moduleCode).join(', ')}.';
}

String _mergeModuleCodeBase(String moduleCode) {
  final trimmed = moduleCode.trim().isEmpty ? 'MODULE' : moduleCode.trim();
  return '${trimmed.toUpperCase()}-MERGED';
}

String _uniqueModuleCode(String base, Iterable<String> existingModuleCodes) {
  final existing =
      existingModuleCodes.map((code) => code.toLowerCase()).toSet();
  var candidate = base;
  var suffix = 2;
  while (existing.contains(candidate.toLowerCase())) {
    candidate = '$base-$suffix';
    suffix++;
  }
  return candidate;
}

String _uniqueValue(String base, Set<String> existingLowerCaseValues) {
  final trimmed = base.trim().isEmpty ? 'value' : base.trim();
  var candidate = trimmed;
  var suffix = 2;
  while (existingLowerCaseValues.contains(candidate.toLowerCase())) {
    candidate = '$trimmed-$suffix';
    suffix++;
  }
  return candidate;
}

String _slug(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  final compact = normalized
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return compact.isEmpty ? 'source' : compact;
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
  return cloneComposerMetadata(source);
}
