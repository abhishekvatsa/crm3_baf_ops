// FILE: lib/features/planned_maintenance/domain/template_version_snapshot_contract.dart

import 'dart:convert';

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
  }) {
    return TemplateVersionSnapshotBundle(
      jobSnapshot: _decodeObject(
        jobTemplateSnapshotJson,
        label: 'jobTemplateSnapshotJson',
      ),
      moduleSnapshots: _decodeObjectList(
        moduleSnapshotsJson,
        label: 'moduleSnapshotsJson',
      ),
      fieldDefinitions: _decodeObjectList(
        fieldDefinitionsJson,
        label: 'fieldDefinitionsJson',
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

    for (var i = 0; i < moduleSnapshots.length; i++) {
      final module = moduleSnapshots[i];
      final code = moduleCode(module);
      final display = code?.trim().isNotEmpty == true ? code! : 'module #${i + 1}';
      if (code == null || code.trim().isEmpty) {
        errors.add('Module #${i + 1} is missing moduleCode/code. Assignment cannot safely link fields.');
        continue;
      }

      final normalizedCode = normalizeKey(code);
      if (moduleCodeByNormalizedCode.containsKey(normalizedCode)) {
        errors.add('Duplicate module code "$code". Module codes must be unique before publishing.');
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
      if (discipline == 'shared' && owners.length < 2) {
        warnings.add('Shared module $display has fewer than two owner disciplines.');
      }
    }

    for (var i = 0; i < fieldDefinitions.length; i++) {
      final field = fieldDefinitions[i];
      final key = fieldKey(field);
      final label = stringFrom(field, const ['label', 'title', 'name']);
      final linkedModuleCode = fieldModuleCode(field);

      if (key == null || key.trim().isEmpty) {
        errors.add('Field definition #${i + 1} is missing key.');
      }
      if (label == null || label.trim().isEmpty) {
        errors.add('Field definition #${i + 1} is missing label.');
      }
      if (linkedModuleCode == null || linkedModuleCode.trim().isEmpty) {
        errors.add('Field ${key ?? '#${i + 1}'} is missing moduleCode. Publisher cannot safely assign it.');
        continue;
      }

      final normalizedModuleCode = normalizeKey(linkedModuleCode);
      final fieldKeys = fieldKeysByModuleCode[normalizedModuleCode];
      if (fieldKeys == null) {
        errors.add('Field ${key ?? '#${i + 1}'} points to unknown moduleCode "$linkedModuleCode".');
        continue;
      }

      if (key != null && key.trim().isNotEmpty) {
        final normalizedFieldKey = normalizeKey(key);
        if (!fieldKeys.add(normalizedFieldKey)) {
          errors.add('Duplicate field key "$key" inside module ${moduleCodeByNormalizedCode[normalizedModuleCode]}.');
        }
      }
    }

    for (var i = 0; i < checklistItems.length; i++) {
      final item = checklistItems[i];
      final title = stringFrom(item, const ['title', 'label', 'name']);
      final linkedModuleCode = fieldModuleCode(item);
      final linkedFieldKey = stringFrom(item, const ['linkedFieldKey', 'fieldKey', 'fieldId']);
      final label = title?.trim().isNotEmpty == true ? title! : 'checklist item #${i + 1}';

      if (linkedModuleCode == null || linkedModuleCode.trim().isEmpty) {
        warnings.add('Checklist item "$label" has no moduleCode and will be treated as global/reference-only.');
        continue;
      }

      final normalizedModuleCode = normalizeKey(linkedModuleCode);
      final knownFields = fieldKeysByModuleCode[normalizedModuleCode];
      if (knownFields == null) {
        errors.add('Checklist item "$label" points to unknown moduleCode "$linkedModuleCode".');
        continue;
      }

      if (linkedFieldKey != null && linkedFieldKey.trim().isNotEmpty) {
        final normalizedFieldKey = normalizeKey(linkedFieldKey);
        if (!knownFields.contains(normalizedFieldKey)) {
          errors.add('Checklist item "$label" links to missing field "$linkedFieldKey" in module $linkedModuleCode.');
        }
      }
    }

    for (final entry in fieldKeysByModuleCode.entries) {
      if (entry.value.isEmpty) {
        warnings.add('Module ${moduleCodeByNormalizedCode[entry.key]} has no linked field definitions.');
      }
    }

    if (requireClosureReviewForClosureCritical) {
      final declaredClosureCount = intValue(jobSnapshot['closureCriticalCount']) ?? 0;
      if ((closureCriticalModuleCount > 0 || declaredClosureCount > 0) &&
          !closureReviewConfirmed) {
        errors.add('Closure-critical modules require Admin/SI closure review confirmation in composer metadata before publish.');
      }
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
    final composer = mapFrom(jobSnapshot['composer']);
    return dateTimeValue(composer['closureReviewConfirmedAt']);
  }

  List<Map<String, dynamic>> fieldsForModule(Map<String, dynamic> module) {
    final code = moduleCode(module);

    for (final key in const ['fields', 'fieldDefinitions', 'fieldDefinitionsJson']) {
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
      final filtered = fieldDefinitions.where((field) {
        final fieldModule = fieldModuleCode(field);
        return normalizeKey(fieldModule) == normalizedCode;
      }).toList();
      if (filtered.isNotEmpty) return filtered;
    }

    return hasModuleLinkedGlobalFields ? <Map<String, dynamic>>[] : fieldDefinitions;
  }

  static String? moduleCode(Map<String, dynamic> module) {
    return stringFrom(module, const ['moduleCode', 'code', 'moduleId', 'id']);
  }

  static String? moduleTitleOrNull(Map<String, dynamic> module) {
    return stringFrom(module, const ['moduleTitle', 'title', 'name', 'displayTitle', 'label']);
  }

  static String moduleTitle(Map<String, dynamic> module, int index) {
    return moduleTitleOrNull(module) ?? moduleCode(module) ?? 'Module ${index + 1}';
  }

  static bool moduleRequiredForClosure(Map<String, dynamic> module) {
    return boolFrom(
      module,
      const ['requiredForClosure', 'requiredForCloseout', 'required', 'isRequired'],
      fallback: false,
    );
  }

  static String? fieldKey(Map<String, dynamic> field) {
    return stringFrom(field, const ['key', 'fieldKey', 'fieldId', 'id']);
  }

  static String? fieldModuleCode(Map<String, dynamic> field) {
    return stringFrom(field, const ['moduleCode', 'moduleId', 'templateModuleId', 'parentModuleCode']);
  }
}

Map<String, dynamic> _decodeObject(
  String raw, {
  required String label,
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
    throw TemplateVersionSnapshotException('$label must contain at least one item.');
  }
  return objects;
}

Map<String, dynamic> mapFrom(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
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
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num || value is bool) return value.toString();
  return null;
}

int? intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
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
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 'yes' || normalized == 'required') return true;
    if (normalized == 'false' || normalized == 'no' || normalized == 'optional') return false;
  }
  return null;
}

DateTime? dateTimeValue(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

List<String> stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return <String>[];
}

String normalizeKey(String? value) {
  return value
          ?.trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
      '';
}

String encodeSnapshotObject(Map<String, dynamic> value) => _snapshotJsonIndent.convert(value);

String encodeSnapshotList(List<Map<String, dynamic>> value) => _snapshotJsonIndent.convert(value);
