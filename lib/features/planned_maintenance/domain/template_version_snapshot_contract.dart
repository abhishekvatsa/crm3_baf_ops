// FILE: lib/features/planned_maintenance/domain/template_version_snapshot_contract.dart

import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../assets/data/asset_hierarchy_model.dart';

const JsonEncoder _snapshotJsonIndent = JsonEncoder.withIndent('  ');

class TemplateVersionSnapshotException implements Exception {
  final String message;

  const TemplateVersionSnapshotException(this.message);

  @override
  String toString() => message;
}

class TemplateVersionSnapshotValidationResult {
  final List<String> errors;
  final List<String> warnings;

  const TemplateVersionSnapshotValidationResult({
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });

  bool get isValid => errors.isEmpty;
}

class TemplateVersionSnapshotBundle {
  final Map<String, dynamic> jobSnapshot;
  final List<Map<String, dynamic>> moduleSnapshots;
  final List<Map<String, dynamic>> fieldDefinitions;
  final List<Map<String, dynamic>> checklistItems;

  const TemplateVersionSnapshotBundle({
    required this.jobSnapshot,
    required this.moduleSnapshots,
    required this.fieldDefinitions,
    required this.checklistItems,
  });

  factory TemplateVersionSnapshotBundle.fromRawJson({
    required String jobTemplateSnapshotJson,
    required String moduleSnapshotsJson,
    required String fieldDefinitionsJson,
    required String checklistJson,
    bool allowEmptyModules = false,
    bool allowEmptyFieldDefinitions = false,
  }) {
    return TemplateVersionSnapshotBundle(
      jobSnapshot: _decodeObject(
        jobTemplateSnapshotJson,
        label: 'jobTemplateSnapshotJson',
      ),
      moduleSnapshots: _decodeObjectList(
        moduleSnapshotsJson,
        label: 'moduleSnapshotsJson',
        allowEmpty: allowEmptyModules,
      ),
      fieldDefinitions: _decodeObjectList(
        fieldDefinitionsJson,
        label: 'fieldDefinitionsJson',
        allowEmpty: allowEmptyFieldDefinitions,
      ),
      checklistItems: _decodeObjectList(
        checklistJson,
        label: 'checklistJson',
        allowEmpty: true,
      ),
    );
  }

  TemplateVersionSnapshotValidationResult validate({
    bool requireClosureReviewForClosureCritical = true,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final moduleCodeByNormalizedCode = <String, String>{};
    final fieldKeysByModuleCode = <String, Set<String>>{};
    var closureCriticalModuleCount = 0;
    _validateRequiredStringAliases(
      jobSnapshot,
      const ['title', 'templateName', 'jobName', 'name'],
      label: 'Job template title',
      errors: errors,
    );
    _validateRequiredEnumAliases(
      jobSnapshot,
      const ['assetType', 'applicableAssetType', 'asset_type'],
      label: 'Job template asset type',
      allowed: const {
        'base',
        'furnace',
        'baffurnace',
        'forcedcooler',
        'forcecooler',
        'cooler',
        'forcedcoolers',
        'innercover',
        'innercovers',
        'governedcustom',
      },
      errors: errors,
    );
    final normalizedAssetType = normalizeKey(
      stringFrom(jobSnapshot, const [
        'assetType',
        'applicableAssetType',
        'asset_type',
      ]),
    );
    final hierarchyReferenceJson = jobSnapshot['assetHierarchyRefJson'];
    if (normalizedAssetType == 'governedcustom') {
      if (hierarchyReferenceJson is! String ||
          hierarchyReferenceJson.trim().isEmpty) {
        errors.add(
          'Governed custom templates require an assetHierarchyRefJson reference.',
        );
      } else {
        try {
          AssetHierarchyReference.decode(
            hierarchyReferenceJson,
            source: 'TemplateVersion job snapshot',
          );
        } on Object catch (error) {
          errors.add('Governed asset hierarchy reference is invalid: $error');
        }
      }
    } else if (hierarchyReferenceJson != null) {
      if (hierarchyReferenceJson is! String ||
          hierarchyReferenceJson.trim().isEmpty) {
        errors.add('assetHierarchyRefJson must be a non-empty JSON string.');
      } else {
        try {
          AssetHierarchyReference.decode(
            hierarchyReferenceJson,
            source: 'TemplateVersion job snapshot',
          );
        } on Object catch (error) {
          errors.add('Asset hierarchy reference is invalid: $error');
        }
      }
    }
    final composer = mapFrom(jobSnapshot['composer']);
    boolValue(composer['closureReviewConfirmed']);
    stringValue(composer['closureReviewConfirmedByUid']);
    stringValue(composer['closureReviewConfirmedByName']);
    stringValue(composer['draftLocalId']);
    intValue(jobSnapshot['closureCriticalCount']);
    for (final key in const [
      'assignedAgencies',
      'agencies',
      'disciplines',
      'disciplineScope',
    ]) {
      if (jobSnapshot.containsKey(key)) stringList(jobSnapshot[key]);
    }

    for (var i = 0; i < moduleSnapshots.length; i++) {
      final module = moduleSnapshots[i];
      final code = moduleCode(module);
      final display =
          code?.trim().isNotEmpty == true ? code! : 'module #${i + 1}';
      if (code == null || code.trim().isEmpty) {
        errors.add(
          'Module #${i + 1} is missing moduleCode/code. Assignment cannot safely link fields.',
        );
        continue;
      }

      final normalizedCode = normalizeKey(code);
      if (moduleCodeByNormalizedCode.containsKey(normalizedCode)) {
        errors.add(
          'Duplicate module code "$code". Module codes must be unique before publishing.',
        );
      }
      moduleCodeByNormalizedCode[normalizedCode] = code.trim();
      fieldKeysByModuleCode.putIfAbsent(normalizedCode, () => <String>{});

      final title = moduleTitleOrNull(module);
      if (title == null || title.trim().isEmpty) {
        errors.add('Module $display is missing moduleTitle/title.');
      }

      if (moduleRequiredForClosure(module)) closureCriticalModuleCount += 1;

      final discipline = normalizeKey(
        stringFrom(module, const ['discipline', 'defaultDiscipline']),
      );
      final metadata = mapFrom(module['metadata']);
      final owners = stringList(metadata['ownerDisciplines']);
      _validateModuleTypes(module, metadata: metadata);
      if (discipline == 'shared' && owners.length < 2) {
        warnings.add(
          'Shared module $display has fewer than two owner disciplines.',
        );
      }
    }

    for (var i = 0; i < fieldDefinitions.length; i++) {
      final field = fieldDefinitions[i];
      final key = fieldKey(field);
      final label = stringFrom(field, const ['label', 'title', 'name']);
      final linkedModuleCode = fieldModuleCode(field);
      _validateFieldTypes(field);

      if (key == null || key.trim().isEmpty) {
        errors.add('Field definition #${i + 1} is missing key.');
      }
      if (label == null || label.trim().isEmpty) {
        errors.add('Field definition #${i + 1} is missing label.');
      }
      if (linkedModuleCode == null || linkedModuleCode.trim().isEmpty) {
        errors.add(
          'Field ${key ?? '#${i + 1}'} is missing moduleCode. Publisher cannot safely assign it.',
        );
        continue;
      }

      final normalizedModuleCode = normalizeKey(linkedModuleCode);
      final fieldKeys = fieldKeysByModuleCode[normalizedModuleCode];
      if (fieldKeys == null) {
        errors.add(
          'Field ${key ?? '#${i + 1}'} points to unknown moduleCode "$linkedModuleCode".',
        );
        continue;
      }

      if (key != null && key.trim().isNotEmpty) {
        final normalizedFieldKey = normalizeKey(key);
        if (!fieldKeys.add(normalizedFieldKey)) {
          errors.add(
            'Duplicate field key "$key" inside module ${moduleCodeByNormalizedCode[normalizedModuleCode]}.',
          );
        }
      }
    }

    for (var i = 0; i < checklistItems.length; i++) {
      final item = checklistItems[i];
      final title = stringFrom(item, const ['title', 'label', 'name']);
      final linkedModuleCode = fieldModuleCode(item);
      final linkedFieldKey = stringFrom(item, const [
        'linkedFieldKey',
        'fieldKey',
        'fieldId',
      ]);
      _validateChecklistTypes(item);
      final label =
          title?.trim().isNotEmpty == true
              ? title!
              : 'checklist item #${i + 1}';

      if (linkedModuleCode == null || linkedModuleCode.trim().isEmpty) {
        warnings.add(
          'Checklist item "$label" has no moduleCode and will be treated as global/reference-only.',
        );
        continue;
      }

      final normalizedModuleCode = normalizeKey(linkedModuleCode);
      final knownFields = fieldKeysByModuleCode[normalizedModuleCode];
      if (knownFields == null) {
        errors.add(
          'Checklist item "$label" points to unknown moduleCode "$linkedModuleCode".',
        );
        continue;
      }

      if (linkedFieldKey != null && linkedFieldKey.trim().isNotEmpty) {
        final normalizedFieldKey = normalizeKey(linkedFieldKey);
        if (!knownFields.contains(normalizedFieldKey)) {
          errors.add(
            'Checklist item "$label" links to missing field "$linkedFieldKey" in module $linkedModuleCode.',
          );
        }
      }
    }

    for (final entry in fieldKeysByModuleCode.entries) {
      if (entry.value.isEmpty) {
        warnings.add(
          'Module ${moduleCodeByNormalizedCode[entry.key]} has no linked field definitions.',
        );
      }
    }

    if (requireClosureReviewForClosureCritical) {
      final declaredClosureCount =
          intValue(jobSnapshot['closureCriticalCount']) ?? 0;
      if ((closureCriticalModuleCount > 0 || declaredClosureCount > 0) &&
          !closureReviewConfirmed) {
        errors.add(
          'Closure-critical modules require Admin/SI closure review confirmation in composer metadata before publish.',
        );
      }
    }

    try {
      _readClosureReviewConfirmedAt(composer);
    } on TemplateVersionSnapshotException catch (error) {
      errors.add(error.message);
    }

    return TemplateVersionSnapshotValidationResult(
      errors: errors.toSet().toList(),
      warnings: warnings.toSet().toList(),
    );
  }

  TemplateVersionSnapshotBundle requireValidForAssignment() {
    final validation = validate(requireClosureReviewForClosureCritical: false);
    if (validation.errors.isNotEmpty) {
      throw TemplateVersionSnapshotException(validation.errors.first);
    }
    return this;
  }

  int get closureCriticalModuleCount {
    var count = 0;
    for (final module in moduleSnapshots) {
      if (moduleRequiredForClosure(module)) count += 1;
    }
    return count;
  }

  bool get closureReviewConfirmed {
    final composer = mapFrom(jobSnapshot['composer']);
    return boolValue(composer['closureReviewConfirmed']) ?? false;
  }

  String? get closureReviewConfirmedByUid {
    final composer = mapFrom(jobSnapshot['composer']);
    return stringValue(composer['closureReviewConfirmedByUid']);
  }

  String? get closureReviewConfirmedByName {
    final composer = mapFrom(jobSnapshot['composer']);
    return stringValue(composer['closureReviewConfirmedByName']);
  }

  DateTime? get closureReviewConfirmedAt {
    return _readClosureReviewConfirmedAt(mapFrom(jobSnapshot['composer']));
  }

  List<Map<String, dynamic>> fieldsForModule(Map<String, dynamic> module) {
    final code = moduleCode(module);

    for (final key in const [
      'fields',
      'fieldDefinitions',
      'fieldDefinitionsJson',
    ]) {
      final value = module[key];
      if (value is String) {
        final parsed = _decodeObjectList(
          value,
          label: 'embedded $key for module ${code ?? 'unknown'}',
          allowEmpty: true,
        );
        if (parsed.isNotEmpty) return parsed;
      }
      if (value is List) {
        final parsed = <Map<String, dynamic>>[];
        for (var i = 0; i < value.length; i++) {
          final entry = value[i];
          if (entry is! Map) {
            throw TemplateVersionSnapshotException(
              'embedded $key item #${i + 1} for module ${code ?? 'unknown'} must be a JSON object.',
            );
          }
          parsed.add(Map<String, dynamic>.from(entry));
        }
        if (parsed.isNotEmpty) return parsed;
      }
    }

    final hasModuleLinkedGlobalFields = fieldDefinitions.any((field) {
      final fieldModule = fieldModuleCode(field);
      return fieldModule != null && fieldModule.trim().isNotEmpty;
    });

    if (code != null && code.trim().isNotEmpty) {
      final normalizedCode = normalizeKey(code);
      final filtered =
          fieldDefinitions.where((field) {
            final fieldModule = fieldModuleCode(field);
            return normalizeKey(fieldModule) == normalizedCode;
          }).toList();
      if (filtered.isNotEmpty) return filtered;
    }

    return hasModuleLinkedGlobalFields
        ? <Map<String, dynamic>>[]
        : fieldDefinitions;
  }

  static String? moduleCode(Map<String, dynamic> module) {
    return stringFrom(module, const ['moduleCode', 'code', 'moduleId', 'id']);
  }

  static String? moduleTitleOrNull(Map<String, dynamic> module) {
    return stringFrom(module, const [
      'moduleTitle',
      'title',
      'name',
      'displayTitle',
      'label',
    ]);
  }

  static String moduleTitle(Map<String, dynamic> module, int index) {
    return moduleTitleOrNull(module) ??
        moduleCode(module) ??
        'Module ${index + 1}';
  }

  static bool moduleRequiredForClosure(Map<String, dynamic> module) {
    return boolFrom(module, const [
      'requiredForClosure',
      'requiredForCloseout',
      'required',
      'isRequired',
    ], fallback: false);
  }

  static String? fieldKey(Map<String, dynamic> field) {
    return stringFrom(field, const ['key', 'fieldKey', 'fieldId', 'id']);
  }

  static String? fieldModuleCode(Map<String, dynamic> field) {
    return stringFrom(field, const [
      'moduleCode',
      'moduleId',
      'templateModuleId',
      'parentModuleCode',
    ]);
  }
}

void _validateModuleTypes(
  Map<String, dynamic> module, {
  required Map<String, dynamic> metadata,
}) {
  _validateStringAliases(module, const [
    'moduleCode',
    'code',
    'moduleId',
    'id',
    'moduleTitle',
    'title',
    'name',
    'displayTitle',
    'label',
    'moduleDescription',
    'description',
    'closedDossierOutput',
    'functionalSection',
    'section',
    'componentGroup',
    'component',
    'subsystem',
    'catalogueArea',
    'area',
    'templateModuleId',
    'key',
    'assignedDiscipline',
    'ownerDiscipline',
    'safetyClass',
    'defaultSafetyClass',
    'targetRef',
  ]);
  _validateOptionalEnumAliases(
    module,
    const ['assetType'],
    label: 'module asset type',
    allowed: const {
      'base',
      'furnace',
      'forcedcooler',
      'forcecooler',
      'cooler',
      'innercover',
      'governedcustom',
    },
  );
  _validateOptionalEnumAliases(
    module,
    const [
      'discipline',
      'defaultDiscipline',
      'assignedDiscipline',
      'ownerDiscipline',
    ],
    label: 'module discipline',
    allowed: const {
      'mechanical',
      'electrical',
      'instrumentation',
      'instrument',
      'ia',
      'ianda',
      'instrumentationautomation',
      'instrumentationandautomation',
      'operations',
      'operation',
      'emd',
      'refractory',
      'shiftincharge',
      'safety',
      'admin',
      'shared',
      'multi',
      'multidiscipline',
      'others',
      'other',
    },
  );
  _validateOptionalEnumAliases(
    module,
    const ['useMode', 'defaultUseMode'],
    label: 'module use mode',
    allowed: const {
      'scheduledpm',
      'scheduled',
      'pm',
      'conditional',
      'conditionbased',
      'troubleshooting',
      'correctivefollowup',
      'shutdownwork',
      'prestartverification',
      'postrepairverification',
      'futurepackage',
      'adhoc',
    },
  );
  _validateOptionalEnumAliases(
    module,
    const ['safetyClass', 'defaultSafetyClass'],
    label: 'module safety class',
    allowed: const {
      'normal',
      'lotorequired',
      'gasrisk',
      'hotsurface',
      'pressuretest',
      'liftingrisk',
      'electricalpanel',
      'combustionspecialist',
      'configurationcontrol',
    },
  );
  _validateBoolAliases(module, const [
    'requiredForClosure',
    'requiredForCloseout',
    'required',
    'isRequired',
  ]);
  for (final key in const ['displayOrder', 'order', 'sequence']) {
    if (module.containsKey(key)) intValue(module[key]);
  }
  for (final key in const [
    'targetRefs',
    'targets',
    'deviceTagRefs',
    'procedureRefs',
    'procedures',
    'safetyConfirmations',
    'tags',
    'operationalStatePreconditions',
    'preconditions',
  ]) {
    if (module.containsKey(key)) stringList(module[key]);
  }
  final pairedEquipment = module['pairedEquipmentJson'];
  if (pairedEquipment != null &&
      pairedEquipment is! String &&
      pairedEquipment is! Map &&
      pairedEquipment is! List) {
    throw const TemplateVersionSnapshotException(
      'pairedEquipmentJson must be a JSON string, object, or list.',
    );
  }
  for (final key in const [
    'primaryOwner',
    'sourceManualRef',
    'sourceKnowledgeId',
    'sourceSeedCode',
    'authoringNotes',
  ]) {
    if (metadata.containsKey(key)) stringValue(metadata[key]);
  }
  if (metadata.containsKey('ownerDisciplines')) {
    stringList(metadata['ownerDisciplines']);
  }
  if (metadata.containsKey('safetyClasses')) {
    stringList(metadata['safetyClasses']);
  }
  if (metadata.containsKey('partRefs')) stringList(metadata['partRefs']);
  if (metadata.containsKey('requiresJointReview')) {
    boolValue(metadata['requiresJointReview']);
  }
  _validateOptionalEnumAliases(
    metadata,
    const ['frequency'],
    label: 'module frequency',
    allowed: const {
      'everycharge',
      'weekly',
      'monthly',
      'everythreemonths',
      'threemonthly',
      'biyearly',
      'biannual',
      'annually',
      'annual',
      'everytwoyears',
      'conditionbased',
      'eventbased',
      'troubleshootingonly',
      'unknown',
    },
  );
  _validateOptionalEnumAliases(
    metadata,
    const ['sourceReadiness'],
    label: 'module source readiness',
    allowed: const {
      'readypreset',
      'needsreview',
      'consultrequired',
      'tagonly',
      'troubleshootingonly',
      'futureintegration',
      'referenceonly',
    },
  );
  _validateOptionalEnumAliases(
    metadata,
    const ['confidence'],
    label: 'module source confidence',
    allowed: const {
      'confirmedmanual',
      'confirmeduserratified',
      'inferred',
      'inferredneedsreview',
      'plantinactivefuturepreset',
      'consultuser',
    },
  );
}

void _validateFieldTypes(Map<String, dynamic> field) {
  _validateStringAliases(field, const [
    'key',
    'fieldKey',
    'fieldId',
    'id',
    'label',
    'title',
    'name',
    'moduleCode',
    'moduleId',
    'templateModuleId',
    'parentModuleCode',
    'instructionText',
    'hint',
    'unit',
  ]);
  _validateOptionalEnumAliases(
    field,
    const ['type', 'fieldType'],
    label: 'field type',
    allowed: const {
      'yesno',
      'boolean',
      'text',
      'longtext',
      'number',
      'numericwithunit',
      'dropdown',
      'enum',
      'multiselect',
      'passfail',
      'datetime',
    },
  );
  _validateBoolAliases(field, const ['isRequired', 'required']);
  if (field.containsKey('order')) intValue(field['order']);
  if (field.containsKey('options')) stringList(field['options']);
  final validation = mapFrom(field['validation']);
  final meta = mapFrom(field['meta']);
  if (field.containsKey('isSafetyCriticalPreset')) {
    boolValue(field['isSafetyCriticalPreset']);
  }
  if (meta.containsKey('isSafetyCriticalPreset')) {
    boolValue(meta['isSafetyCriticalPreset']);
  }
  if (meta.containsKey('sourcePresetId')) stringValue(meta['sourcePresetId']);
  if (meta.containsKey('sourcePreset')) stringValue(meta['sourcePreset']);
  if (field.containsKey('validation') && validation.isEmpty) {
    // A present empty validation object is valid. Calling mapFrom above is the
    // strict shape check; this branch keeps the read intentional.
  }
}

void _validateChecklistTypes(Map<String, dynamic> item) {
  _validateStringAliases(item, const [
    'id',
    'itemId',
    'key',
    'title',
    'label',
    'name',
    'description',
    'moduleCode',
    'moduleId',
    'templateModuleId',
    'parentModuleCode',
    'linkedFieldKey',
    'fieldKey',
    'fieldId',
  ]);
  _validateBoolAliases(item, const ['isRequired', 'required']);
  if (item.containsKey('order')) intValue(item['order']);
  if (item.containsKey('safetyClasses')) stringList(item['safetyClasses']);
  mapFrom(item['metadata']);
}

void _validateStringAliases(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source.containsKey(key)) stringValue(source[key]);
  }
}

void _validateBoolAliases(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    if (source.containsKey(key)) boolValue(source[key]);
  }
}

void _validateRequiredStringAliases(
  Map<String, dynamic> source,
  List<String> keys, {
  required String label,
  required List<String> errors,
}) {
  _validateStringAliases(source, keys);
  if (stringFrom(source, keys) == null) {
    errors.add('$label is missing.');
  }
}

void _validateRequiredEnumAliases(
  Map<String, dynamic> source,
  List<String> keys, {
  required String label,
  required Set<String> allowed,
  required List<String> errors,
}) {
  _validateStringAliases(source, keys);
  final value = stringFrom(source, keys);
  if (value == null) {
    errors.add('$label is missing.');
    return;
  }
  if (!allowed.contains(normalizeKey(value))) {
    errors.add('$label has unsupported value "$value".');
  }
}

void _validateOptionalEnumAliases(
  Map<String, dynamic> source,
  List<String> keys, {
  required String label,
  required Set<String> allowed,
}) {
  _validateStringAliases(source, keys);
  for (final key in keys) {
    if (!source.containsKey(key)) continue;
    final value = stringValue(source[key]);
    if (value == null || !allowed.contains(normalizeKey(value))) {
      throw TemplateVersionSnapshotException(
        '$label has unsupported value "${source[key]}".',
      );
    }
  }
}

Map<String, dynamic> _decodeObject(String raw, {required String label}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw TemplateVersionSnapshotException('$label is empty.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (error) {
    throw TemplateVersionSnapshotException(
      '$label is not valid JSON: ${error.message}',
    );
  }

  if (decoded is! Map) {
    throw TemplateVersionSnapshotException('$label must be a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

List<Map<String, dynamic>> _decodeObjectList(
  String raw, {
  required String label,
  bool allowEmpty = false,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw TemplateVersionSnapshotException('$label is empty.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (error) {
    throw TemplateVersionSnapshotException(
      '$label is not valid JSON: ${error.message}',
    );
  }

  if (decoded is! List) {
    throw TemplateVersionSnapshotException('$label must be a JSON list.');
  }

  final objects = <Map<String, dynamic>>[];
  for (var i = 0; i < decoded.length; i++) {
    final entry = decoded[i];
    if (entry is! Map) {
      throw TemplateVersionSnapshotException(
        '$label item #${i + 1} must be a JSON object.',
      );
    }
    objects.add(Map<String, dynamic>.from(entry));
  }

  if (objects.isEmpty && !allowEmpty) {
    throw TemplateVersionSnapshotException(
      '$label must contain at least one item.',
    );
  }
  return objects;
}

Map<String, dynamic> mapFrom(dynamic value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map) return Map<String, dynamic>.from(value);
  throw TemplateVersionSnapshotException(
    'Expected a JSON object but found ${value.runtimeType}.',
  );
}

String? stringFrom(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final parsed = stringValue(value);
    if (parsed != null) return parsed;
  }
  return null;
}

String? stringValue(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is String) return null;
  throw TemplateVersionSnapshotException(
    'Expected a string but found ${value.runtimeType}.',
  );
}

int? intValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  throw TemplateVersionSnapshotException(
    'Expected an integer but found ${value.runtimeType}.',
  );
}

bool boolFrom(
  Map<String, dynamic> map,
  List<String> keys, {
  required bool fallback,
}) {
  for (final key in keys) {
    final parsed = boolValue(map[key]);
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool? boolValue(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  throw TemplateVersionSnapshotException(
    'Expected a boolean but found ${value.runtimeType}.',
  );
}

DateTime? _readClosureReviewConfirmedAt(Map<String, dynamic> composer) {
  try {
    return readOptionalPersistedDateTime(
      composer['closureReviewConfirmedAt'],
      field: 'closureReviewConfirmedAt',
      source: 'template version snapshot composer',
    )?.toUtc();
  } on PersistedDataFormatException catch (error) {
    throw TemplateVersionSnapshotException(error.message);
  }
}

List<String> stringList(dynamic value) {
  if (value == null) return <String>[];
  if (value is Iterable) {
    final result = <String>[];
    var index = 0;
    for (final item in value) {
      if (item is! String || item.trim().isEmpty) {
        throw TemplateVersionSnapshotException(
          'Expected a non-empty string at list index $index.',
        );
      }
      result.add(item.trim());
      index += 1;
    }
    return result;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  throw TemplateVersionSnapshotException(
    'Expected a string list but found ${value.runtimeType}.',
  );
}

String normalizeKey(String? value) {
  return value
          ?.trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
      '';
}

String encodeSnapshotObject(Map<String, dynamic> value) =>
    _snapshotJsonIndent.convert(value);

String encodeSnapshotList(List<Map<String, dynamic>> value) =>
    _snapshotJsonIndent.convert(value);
