import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/global_pull_protocol.dart';
import '../domain/baf_knowledge_layer.dart';

const _frequencyValues = <String>{
  'everyCharge',
  'weekly',
  'monthly',
  'everyThreeMonths',
  'biyearly',
  'annually',
  'everyTwoYears',
  'conditionBased',
  'eventBased',
  'troubleshootingOnly',
  'unknown',
};

const _disciplineValues = <String>{
  'mechanical',
  'electrical',
  'instrumentation',
  'operations',
  'emd',
  'refractory',
  'shiftInCharge',
  'safety',
  'admin',
  'shared',
  'others',
};

const _readinessValues = <String>{
  'readyPreset',
  'needsReview',
  'consultRequired',
  'tagOnly',
  'troubleshootingOnly',
  'futureIntegration',
  'referenceOnly',
};

const _confidenceValues = <String>{
  'confirmedManual',
  'confirmedUserRatified',
  'inferred',
  'inferredNeedsReview',
  'plantInactiveFuturePreset',
  'consultUser',
};

const _lifecycleValues = <String>{'active', 'retired', 'archived'};
const _closureValues = <String>{'yes', 'no', 'consult'};

class RemoteBafKnowledgeRowData {
  final String rowCode;
  final String sourceManual;
  final String sourcePage;
  final String sourceType;
  final String assetFamily;
  final String functionalSection;
  final String componentGroup;
  final String taskType;
  final String taskText;
  final String frequency;
  final String discipline;
  final List<String> ownerDisciplines;
  final List<String> safetyClasses;
  final List<String> procedureRefs;
  final List<String> partRefs;
  final List<String> deviceTags;
  final List<String> targetRefs;
  final List<String> suggestedFields;
  final String requiredForClosure;
  final String moduleCandidateCode;
  final String resolverImpact;
  final String composerReadiness;
  final String confidence;
  final String consultQuestion;
  final String lifecycleStatus;
  final String matrixVersion;
  final int schemaVersion;
  final int version;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final String updatedByUid;
  final String updatedByName;
  final DateTime updatedAt;
  final String changeSummary;
  final Map<String, dynamic> rawMap;
  final bool isDeleted;

  const RemoteBafKnowledgeRowData({
    required this.rowCode,
    required this.sourceManual,
    required this.sourcePage,
    required this.sourceType,
    required this.assetFamily,
    required this.functionalSection,
    required this.componentGroup,
    required this.taskType,
    required this.taskText,
    required this.frequency,
    required this.discipline,
    required this.ownerDisciplines,
    required this.safetyClasses,
    required this.procedureRefs,
    required this.partRefs,
    required this.deviceTags,
    required this.targetRefs,
    required this.suggestedFields,
    required this.requiredForClosure,
    required this.moduleCandidateCode,
    required this.resolverImpact,
    required this.composerReadiness,
    required this.confidence,
    required this.consultQuestion,
    required this.lifecycleStatus,
    required this.matrixVersion,
    required this.schemaVersion,
    required this.version,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.updatedByUid,
    required this.updatedByName,
    required this.updatedAt,
    required this.changeSummary,
    required this.rawMap,
    required this.isDeleted,
  });
}

class RemoteBafKnowledgeMetaData {
  final String matrixVersion;
  final String sourceLabel;
  final String source;
  final String maintenanceManualRef;
  final String safetyOperationsManualRef;
  final int knowledgeRowCount;
  final int tagRowCount;
  final DateTime updatedAt;
  final String updatedByUid;
  final String updatedByName;
  final String changeSummary;
  final String note;
  final int schemaVersion;
  final int version;
  final bool isDeleted;

  const RemoteBafKnowledgeMetaData({
    required this.matrixVersion,
    required this.sourceLabel,
    required this.source,
    required this.maintenanceManualRef,
    required this.safetyOperationsManualRef,
    required this.knowledgeRowCount,
    required this.tagRowCount,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
    required this.changeSummary,
    required this.note,
    required this.schemaVersion,
    required this.version,
    required this.isDeleted,
  });
}

RemoteBafKnowledgeRowData readRemoteBafKnowledgeRow(
  Map<String, dynamic> map,
  String documentId,
) {
  final source = 'knowledge_base/$documentId';
  final rowCode = readRequiredPersistedString(
    map['rowCode'],
    field: 'rowCode',
    source: source,
  );
  if (rowCode != documentId ||
      !RegExp(r'^[A-Za-z0-9._-]{2,64}$').hasMatch(rowCode)) {
    throw PersistedDataFormatException(
      field: 'rowCode',
      source: source,
      detail: 'must match the document ID and use the governed code format',
    );
  }

  final taskText = readRequiredPersistedString(
    map['taskText'],
    field: 'taskText',
    source: source,
  );
  final moduleCandidateCode = readRequiredPersistedString(
    map['moduleCandidateCode'],
    field: 'moduleCandidateCode',
    source: source,
  );
  final ownerDisciplines = readOptionalPersistedStringList(
    map['ownerDisciplines'],
    field: 'ownerDisciplines',
    source: source,
  );
  final safetyClasses = _readCanonicalOrLegacyStringList(
    map,
    canonicalField: 'safetyClasses',
    legacyField: 'safetyClass',
    source: source,
  );
  final procedureRefs = readOptionalPersistedStringList(
    map['procedureRefs'],
    field: 'procedureRefs',
    source: source,
  );
  final partRefs = readOptionalPersistedStringList(
    map['partRefs'],
    field: 'partRefs',
    source: source,
  );
  final deviceTags = readOptionalPersistedStringList(
    map['deviceTags'],
    field: 'deviceTags',
    source: source,
  ).map((tag) => tag.toUpperCase()).toList(growable: false);
  final targetRefs = readOptionalPersistedStringList(
    map['targetRefs'],
    field: 'targetRefs',
    source: source,
  );
  final suggestedFields = _readSuggestedFieldLabels(map, source: source);
  final suggestedFieldPresets = readBafKnowledgeSuggestedFieldPresets(
    _canonicalOrLegacy(
      map,
      canonicalField: 'suggestedFieldPresets',
      legacyFields: const <String>['fieldPresets', 'suggestedFieldDefinitions'],
    ),
    field:
        map.containsKey('suggestedFieldPresets')
            ? 'suggestedFieldPresets'
            : map.containsKey('fieldPresets')
            ? 'fieldPresets'
            : 'suggestedFieldDefinitions',
    source: source,
  );
  final normalizedPresets =
      suggestedFieldPresets.isNotEmpty
          ? suggestedFieldPresets
          : _presetsFromLabels(suggestedFields);

  final schemaVersion = readRequiredPersistedInt(
    map['schemaVersion'],
    field: 'schemaVersion',
    source: source,
    minimum: 1,
  );
  if (schemaVersion != 1) {
    throw PersistedDataFormatException(
      field: 'schemaVersion',
      source: source,
      detail: 'unsupported schema version $schemaVersion',
    );
  }
  final version = readRequiredPersistedInt(
    map['version'],
    field: 'version',
    source: source,
    minimum: 1,
  );
  final createdAt = readRequiredPersistedDateTime(
    map['createdAt'],
    field: 'createdAt',
    source: source,
  );
  final updatedAt = readRequiredPersistedDateTime(
    map['updatedAt'],
    field: 'updatedAt',
    source: source,
  );
  if (updatedAt.isBefore(createdAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }

  final changeSummary = readRequiredPersistedString(
    map['changeSummary'],
    field: 'changeSummary',
    source: source,
  );
  if (changeSummary.length < 15) {
    throw PersistedDataFormatException(
      field: 'changeSummary',
      source: source,
      detail: 'must contain at least 15 characters',
    );
  }

  final normalizedRaw = strictJsonSafeBafKnowledgeMap(<String, dynamic>{
    for (final entry in map.entries)
      if (entry.key != globalPullServerUpdatedAtField) entry.key: entry.value,
    'rowCode': rowCode,
    'moduleCandidateCode': moduleCandidateCode,
    'safetyClass': safetyClasses,
    'safetyClasses': safetyClasses,
    'suggestedFields': suggestedFields,
    'suggestedFieldPresets': normalizedPresets,
  }, source: source);

  return RemoteBafKnowledgeRowData(
    rowCode: rowCode,
    sourceManual: _readOptionalString(map, 'sourceManual', source),
    sourcePage: _readOptionalString(map, 'sourcePage', source),
    sourceType: _readOptionalString(map, 'sourceType', source),
    assetFamily: _readOptionalString(map, 'assetFamily', source),
    functionalSection: _readOptionalString(map, 'functionalSection', source),
    componentGroup: _readOptionalString(map, 'componentGroup', source),
    taskType: _readOptionalString(map, 'taskType', source),
    taskText: taskText,
    frequency: _readOptionalLiteral(
      map['frequency'],
      field: 'frequency',
      source: source,
      values: _frequencyValues,
      fallback: 'unknown',
    ),
    discipline: _readOptionalLiteral(
      map['discipline'],
      field: 'discipline',
      source: source,
      values: _disciplineValues,
      fallback: 'mechanical',
    ),
    ownerDisciplines: ownerDisciplines,
    safetyClasses: safetyClasses,
    procedureRefs: procedureRefs,
    partRefs: partRefs,
    deviceTags: deviceTags,
    targetRefs: targetRefs,
    suggestedFields: suggestedFields,
    requiredForClosure: _readOptionalLiteral(
      map['requiredForClosure'],
      field: 'requiredForClosure',
      source: source,
      values: _closureValues,
      fallback: 'consult',
    ),
    moduleCandidateCode: moduleCandidateCode,
    resolverImpact: _readOptionalString(map, 'resolverImpact', source),
    composerReadiness: _readRequiredLiteral(
      map['composerReadiness'],
      field: 'composerReadiness',
      source: source,
      values: _readinessValues,
    ),
    confidence: _readRequiredLiteral(
      map['confidence'],
      field: 'confidence',
      source: source,
      values: _confidenceValues,
    ),
    consultQuestion: _readOptionalString(map, 'consultQuestion', source),
    lifecycleStatus: _readRequiredLiteral(
      map['lifecycleStatus'],
      field: 'lifecycleStatus',
      source: source,
      values: _lifecycleValues,
    ),
    matrixVersion: readRequiredPersistedString(
      map['matrixVersion'],
      field: 'matrixVersion',
      source: source,
    ),
    schemaVersion: schemaVersion,
    version: version,
    createdByUid: readRequiredPersistedString(
      map['createdByUid'],
      field: 'createdByUid',
      source: source,
    ),
    createdByName: _readOptionalString(map, 'createdByName', source),
    createdAt: createdAt,
    updatedByUid: readRequiredPersistedString(
      map['updatedByUid'],
      field: 'updatedByUid',
      source: source,
    ),
    updatedByName: _readOptionalString(map, 'updatedByName', source),
    updatedAt: updatedAt,
    changeSummary: changeSummary,
    rawMap: normalizedRaw,
    isDeleted: readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    ),
  );
}

RemoteBafKnowledgeMetaData readRemoteBafKnowledgeMeta(
  Map<String, dynamic> map,
) {
  const source = 'knowledge_base_meta/current';
  final schemaVersion = readRequiredPersistedInt(
    map['schemaVersion'],
    field: 'schemaVersion',
    source: source,
    minimum: 1,
  );
  if (schemaVersion != 1) {
    throw PersistedDataFormatException(
      field: 'schemaVersion',
      source: source,
      detail: 'unsupported schema version $schemaVersion',
    );
  }
  final rowCount = readRequiredPersistedInt(
    map['knowledgeRowCount'],
    field: 'knowledgeRowCount',
    source: source,
    minimum: 0,
  );
  final tagCount = readRequiredPersistedInt(
    map['tagRowCount'],
    field: 'tagRowCount',
    source: source,
    minimum: 0,
  );
  if (tagCount > rowCount) {
    throw PersistedDataFormatException(
      field: 'tagRowCount',
      source: source,
      detail: 'cannot exceed knowledgeRowCount',
    );
  }
  final changeSummary = readRequiredPersistedString(
    map['changeSummary'],
    field: 'changeSummary',
    source: source,
  );
  if (changeSummary.length < 15) {
    throw PersistedDataFormatException(
      field: 'changeSummary',
      source: source,
      detail: 'must contain at least 15 characters',
    );
  }
  return RemoteBafKnowledgeMetaData(
    matrixVersion: readRequiredPersistedString(
      map['matrixVersion'],
      field: 'matrixVersion',
      source: source,
    ),
    sourceLabel: readRequiredPersistedString(
      map['sourceLabel'],
      field: 'sourceLabel',
      source: source,
    ),
    source: _readOptionalString(map, 'source', source, fallback: 'cloud'),
    maintenanceManualRef: _readOptionalString(
      map,
      'maintenanceManualRef',
      source,
      fallback: BafKnowledgeLayer.maintenanceManualRef,
    ),
    safetyOperationsManualRef: _readOptionalString(
      map,
      'safetyOperationsManualRef',
      source,
      fallback: BafKnowledgeLayer.safetyOperationsManualRef,
    ),
    knowledgeRowCount: rowCount,
    tagRowCount: tagCount,
    updatedAt: readRequiredPersistedDateTime(
      map['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    updatedByUid: readRequiredPersistedString(
      map['updatedByUid'],
      field: 'updatedByUid',
      source: source,
    ),
    updatedByName: _readOptionalString(map, 'updatedByName', source),
    changeSummary: changeSummary,
    note: _readOptionalString(map, 'note', source),
    schemaVersion: schemaVersion,
    version: readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    ),
    isDeleted:
        map.containsKey('isDeleted')
            ? readRequiredPersistedBool(
              map['isDeleted'],
              field: 'isDeleted',
              source: source,
            )
            : false,
  );
}

Map<String, dynamic> readBafKnowledgeRawJson(
  String rawJson, {
  required String source,
}) {
  if (rawJson.trim().isEmpty) {
    throw PersistedDataFormatException(
      field: 'rawJson',
      source: source,
      detail: 'required JSON object',
    );
  }
  return readRequiredJsonObject(rawJson, field: 'rawJson', source: source);
}

List<Map<String, dynamic>> readBafKnowledgeSuggestedFieldPresets(
  Object? value, {
  required String field,
  required String source,
}) {
  if (value == null) return const <Map<String, dynamic>>[];
  dynamic decoded = value;
  if (value is String) {
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'malformed JSON',
      );
    }
  }
  if (decoded is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an array (${decoded.runtimeType})',
    );
  }
  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is! Map) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'expected an object (${entry.runtimeType})',
      );
    }
    Map<String, dynamic> typed;
    try {
      typed = Map<String, dynamic>.from(entry);
    } on TypeError {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'object keys must be strings',
      );
    }
    result.add(
      strictJsonSafeBafKnowledgeMap(
        typed,
        source: source,
        field: '$field[$index]',
      ),
    );
  }
  return List<Map<String, dynamic>>.unmodifiable(result);
}

Map<String, dynamic> strictJsonSafeBafKnowledgeMap(
  Map<String, dynamic> map, {
  required String source,
  String field = 'rawJson',
}) {
  return <String, dynamic>{
    for (final entry in map.entries)
      entry.key: _strictJsonSafeValue(
        entry.value,
        source: source,
        field: '$field.${entry.key}',
      ),
  };
}

Object? _strictJsonSafeValue(
  Object? value, {
  required String source,
  required String field,
}) {
  if (value == null || value is bool || value is String) return value;
  if (value is num) {
    if (value.isFinite) return value;
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'non-finite numbers are not supported',
    );
  }
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw PersistedDataFormatException(
          field: field,
          source: source,
          detail: 'object keys must be strings',
        );
      }
      final key = entry.key as String;
      result[key] = _strictJsonSafeValue(
        entry.value,
        source: source,
        field: '$field.$key',
      );
    }
    return result;
  }
  if (value is Iterable) {
    return <Object?>[
      for (var index = 0; index < value.length; index++)
        _strictJsonSafeValue(
          value.elementAt(index),
          source: source,
          field: '$field[$index]',
        ),
    ];
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unsupported persisted value (${value.runtimeType})',
  );
}

String _readOptionalString(
  Map<String, dynamic> map,
  String field,
  String source, {
  String fallback = '',
}) {
  return readOptionalPersistedString(
        map[field],
        field: field,
        source: source,
      ) ??
      fallback;
}

String _readRequiredLiteral(
  Object? value, {
  required String field,
  required String source,
  required Set<String> values,
}) {
  final text = readRequiredPersistedString(value, field: field, source: source);
  if (values.contains(text)) return text;
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown value "$text"',
  );
}

String _readOptionalLiteral(
  Object? value, {
  required String field,
  required String source,
  required Set<String> values,
  required String fallback,
}) {
  if (value == null) return fallback;
  return _readRequiredLiteral(
    value,
    field: field,
    source: source,
    values: values,
  );
}

List<String> _readCanonicalOrLegacyStringList(
  Map<String, dynamic> map, {
  required String canonicalField,
  required String legacyField,
  required String source,
}) {
  if (map.containsKey(canonicalField)) {
    return readOptionalPersistedStringList(
      map[canonicalField],
      field: canonicalField,
      source: source,
    );
  }
  return readOptionalPersistedStringList(
    map[legacyField],
    field: legacyField,
    source: source,
  );
}

Object? _canonicalOrLegacy(
  Map<String, dynamic> map, {
  required String canonicalField,
  required List<String> legacyFields,
}) {
  if (map.containsKey(canonicalField)) return map[canonicalField];
  for (final field in legacyFields) {
    if (map.containsKey(field)) return map[field];
  }
  return null;
}

List<String> _readSuggestedFieldLabels(
  Map<String, dynamic> map, {
  required String source,
}) {
  if (map.containsKey('suggestedFields')) {
    final value = map['suggestedFields'];
    if (value is! List) {
      throw PersistedDataFormatException(
        field: 'suggestedFields',
        source: source,
        detail: 'expected an array (${value.runtimeType})',
      );
    }
    if (value.isEmpty) return const <String>[];
    final allStrings = value.every((entry) => entry is String);
    final allMaps = value.every((entry) => entry is Map);
    if (!allStrings && !allMaps) {
      throw PersistedDataFormatException(
        field: 'suggestedFields',
        source: source,
        detail: 'entries must use one consistent string or object shape',
      );
    }
    if (allStrings) {
      return readOptionalPersistedStringList(
        value,
        field: 'suggestedFields',
        source: source,
      );
    }
    final labels = <String>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index] as Map;
      final labelValue =
          entry.containsKey('label')
              ? entry['label']
              : entry.containsKey('title')
              ? entry['title']
              : entry['name'];
      labels.add(
        readRequiredPersistedString(
          labelValue,
          field: 'suggestedFields[$index].label',
          source: source,
        ),
      );
    }
    return List<String>.unmodifiable(labels);
  }

  final presets = readBafKnowledgeSuggestedFieldPresets(
    _canonicalOrLegacy(
      map,
      canonicalField: 'suggestedFieldPresets',
      legacyFields: const <String>['fieldPresets', 'suggestedFieldDefinitions'],
    ),
    field:
        map.containsKey('suggestedFieldPresets')
            ? 'suggestedFieldPresets'
            : map.containsKey('fieldPresets')
            ? 'fieldPresets'
            : 'suggestedFieldDefinitions',
    source: source,
  );
  return <String>[
    for (var index = 0; index < presets.length; index++)
      readRequiredPersistedString(
        presets[index].containsKey('label')
            ? presets[index]['label']
            : presets[index].containsKey('title')
            ? presets[index]['title']
            : presets[index]['name'],
        field: 'suggestedFieldPresets[$index].label',
        source: source,
      ),
  ];
}

List<Map<String, dynamic>> _presetsFromLabels(List<String> labels) {
  return <Map<String, dynamic>>[
    for (final label in labels)
      <String, dynamic>{
        'key': label
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), ''),
        'label': label,
        'type': 'text',
        'sourceText': label,
      },
  ];
}
