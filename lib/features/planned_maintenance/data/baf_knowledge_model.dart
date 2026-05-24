// FILE: lib/features/planned_maintenance/data/baf_knowledge_model.dart

import 'dart:convert';

import 'package:isar/isar.dart';

import '../domain/baf_knowledge_layer.dart';
import '../domain/module_composer_models.dart';

part 'baf_knowledge_model.g.dart';

/// Local Isar cache row for the governed BAF Knowledge Base.
///
/// Firestore remains the cloud authority. Isar is the offline-first local
/// mirror used by the Module Composer and Tag Resolver. The embedded
/// [BafKnowledgeLayer] remains the safety fallback when both cloud and local
/// cache are unavailable or empty.
@collection
class BafKnowledgeRow {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String rowCode;

  late String sourceManual;
  late String sourcePage;
  late String sourceType;
  late String assetFamily;
  late String functionalSection;
  late String componentGroup;
  late String taskType;
  late String taskText;
  late String frequency;
  late String discipline;
  late List<String> ownerDisciplines;
  late List<String> safetyClasses;
  late List<String> procedureRefs;
  late List<String> partRefs;
  late List<String> deviceTags;
  late List<String> targetRefs;
  late List<String> suggestedFields;
  late String requiredForClosure;
  late String moduleCandidateCode;
  late String resolverImpact;
  late String composerReadiness;
  late String confidence;
  late String consultQuestion;
  late String lifecycleStatus;
  late String matrixVersion;
  late int schemaVersion;
  late int version;
  late String createdByUid;
  late String createdByName;
  late DateTime createdAt;
  late String updatedByUid;
  late String updatedByName;
  late DateTime updatedAt;
  late String changeSummary;
  late String rawJson;
  late bool isSynced;
  late bool isDeleted;

  BafKnowledgeRow();

  factory BafKnowledgeRow.fromEntry(
    BafKnowledgeEntry entry, {
    required String actorUid,
    required String actorName,
    required DateTime now,
    required String changeSummary,
    bool isSynced = true,
  }) {
    final row = BafKnowledgeRow();
    row.rowCode = entry.id;
    row.sourceManual = entry.sourceManual;
    row.sourcePage = entry.sourcePage;
    row.sourceType = entry.sourceType;
    row.assetFamily = entry.assetFamilyKey;
    row.functionalSection = entry.functionalSection;
    row.componentGroup = entry.componentGroup;
    row.taskType = entry.taskType;
    row.taskText = entry.taskText;
    row.frequency = entry.frequency.name;
    row.discipline = entry.discipline.name;
    row.ownerDisciplines = List<String>.from(entry.ownerDisciplines);
    row.safetyClasses = List<String>.from(entry.safetyClasses);
    row.procedureRefs = List<String>.from(entry.procedureRefs);
    row.partRefs = List<String>.from(entry.partRefs);
    row.deviceTags = List<String>.from(entry.deviceTags);
    row.targetRefs = List<String>.from(entry.targetRefs);
    row.suggestedFields = entry.suggestedFields.map((field) => field.label).toList();
    row.requiredForClosure = entry.requiredForClosureSuggestion == null
        ? 'consult'
        : entry.requiredForClosureSuggestion == true
            ? 'yes'
            : 'no';
    row.moduleCandidateCode = entry.moduleCandidateCode;
    row.resolverImpact = entry.resolverImpact;
    row.composerReadiness = entry.composerReadiness.name;
    row.confidence = entry.confidence.name;
    row.consultQuestion = entry.consultQuestion;
    row.lifecycleStatus = 'active';
    row.matrixVersion = BafKnowledgeLayer.matrixVersion;
    row.schemaVersion = 1;
    row.version = 1;
    row.createdByUid = actorUid;
    row.createdByName = actorName;
    row.createdAt = now;
    row.updatedByUid = actorUid;
    row.updatedByName = actorName;
    row.updatedAt = now;
    row.changeSummary = changeSummary;
    row.rawJson = jsonEncode(<String, dynamic>{
      ...entry.raw,
      'suggestedFieldPresets': entry.suggestedFields
          .map((field) => field.toMap())
          .toList(),
    });
    row.isSynced = isSynced;
    row.isDeleted = false;
    return row;
  }

  factory BafKnowledgeRow.fromCloudMap(
    Map<String, dynamic> map,
    String docId, {
    int? localId,
  }) {
    final now = DateTime.now();
    final row = BafKnowledgeRow();
    if (localId != null) row.id = localId;
    row.rowCode = _clean(map['rowCode']).isEmpty ? docId : _clean(map['rowCode']);
    row.sourceManual = _clean(map['sourceManual']);
    row.sourcePage = _clean(map['sourcePage']);
    row.sourceType = _clean(map['sourceType']);
    row.assetFamily = _clean(map['assetFamily']);
    row.functionalSection = _clean(map['functionalSection']);
    row.componentGroup = _clean(map['componentGroup']);
    row.taskType = _clean(map['taskType']);
    row.taskText = _clean(map['taskText']);
    row.frequency = _clean(map['frequency']).isEmpty ? 'unknown' : _clean(map['frequency']);
    row.discipline = _clean(map['discipline']).isEmpty ? 'mechanical' : _clean(map['discipline']);
    row.ownerDisciplines = _stringList(map['ownerDisciplines']);
    row.safetyClasses = _stringList(map['safetyClasses'] ?? map['safetyClass']);
    row.procedureRefs = _stringList(map['procedureRefs']);
    row.partRefs = _stringList(map['partRefs']);
    row.deviceTags = _stringList(map['deviceTags']).map((tag) => tag.toUpperCase()).toList();
    row.targetRefs = _stringList(map['targetRefs']);
    row.suggestedFields = _suggestedFieldLabels(map);
    row.requiredForClosure = _clean(map['requiredForClosure']).isEmpty ? 'consult' : _clean(map['requiredForClosure']);
    row.moduleCandidateCode = _clean(map['moduleCandidateCode']).isEmpty ? row.rowCode : _clean(map['moduleCandidateCode']);
    row.resolverImpact = _clean(map['resolverImpact']);
    row.composerReadiness = _clean(map['composerReadiness']).isEmpty ? 'needsReview' : _clean(map['composerReadiness']);
    row.confidence = _clean(map['confidence']).isEmpty ? 'inferredNeedsReview' : _clean(map['confidence']);
    row.consultQuestion = _clean(map['consultQuestion']);
    row.lifecycleStatus = _clean(map['lifecycleStatus']).isEmpty ? 'active' : _clean(map['lifecycleStatus']);
    row.matrixVersion = _clean(map['matrixVersion']).isEmpty ? BafKnowledgeLayer.matrixVersion : _clean(map['matrixVersion']);
    row.schemaVersion = _int(map['schemaVersion'], 1);
    row.version = _int(map['version'], 1);
    row.createdByUid = _clean(map['createdByUid']);
    row.createdByName = _clean(map['createdByName']);
    row.createdAt = _date(map['createdAt']) ?? now;
    row.updatedByUid = _clean(map['updatedByUid']);
    row.updatedByName = _clean(map['updatedByName']);
    row.updatedAt = _date(map['updatedAt']) ?? now;
    row.changeSummary = _clean(map['changeSummary']);
    row.rawJson = jsonEncode(_entryMapFromCloud(map, row.rowCode));
    row.isSynced = true;
    row.isDeleted = map['isDeleted'] == true;
    return row;
  }

  BafKnowledgeEntry toEntry(int index) {
    return BafKnowledgeEntry.fromMap(toEntryMap(), index);
  }

  Map<String, dynamic> toEntryMap() {
    final decoded = _decodeRaw(rawJson);
    return <String, dynamic>{
      ...decoded,
      'rowCode': rowCode,
      'moduleCandidateCode': moduleCandidateCode,
      'sourceManual': sourceManual,
      'sourcePage': sourcePage,
      'sourceType': sourceType,
      'assetFamily': assetFamily,
      'functionalSection': functionalSection,
      'componentGroup': componentGroup,
      'taskType': taskType,
      'taskText': taskText,
      'frequency': frequency,
      'discipline': discipline,
      'ownerDisciplines': ownerDisciplines,
      'safetyClass': safetyClasses,
      'safetyClasses': safetyClasses,
      'procedureRefs': procedureRefs,
      'partRefs': partRefs,
      'deviceTags': deviceTags,
      'targetRefs': targetRefs,
      'suggestedFields': suggestedFields,
      'suggestedFieldPresets': _suggestedFieldPresetsFromRaw(
        decoded,
        fallbackLabels: suggestedFields,
      ),
      'requiredForClosure': requiredForClosure,
      'resolverImpact': resolverImpact,
      'composerReadiness': composerReadiness,
      'confidence': confidence,
      'consultQuestion': consultQuestion,
    };
  }

  Map<String, dynamic> toCloudMap({bool serverTimestamps = false}) {
    final map = <String, dynamic>{
      ...toEntryMap(),
      'rowCode': rowCode,
      'lifecycleStatus': lifecycleStatus,
      'matrixVersion': matrixVersion,
      'schemaVersion': schemaVersion,
      'version': version,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
      'updatedAt': updatedAt,
      'changeSummary': changeSummary,
      'isDeleted': isDeleted,
    };
    return map;
  }
}

@collection
class BafKnowledgeMatrixMetaStore {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String metaKey;

  late String matrixVersion;
  late String sourceLabel;
  late String source;
  late String maintenanceManualRef;
  late String safetyOperationsManualRef;
  late int knowledgeRowCount;
  late int tagRowCount;
  late DateTime? cloudUpdatedAt;
  late DateTime? localCachedAt;
  late DateTime updatedAt;
  late String updatedByUid;
  late String updatedByName;
  late String changeSummary;
  late String note;
  late int schemaVersion;
  late int version;
  late bool isSynced;
  late bool isDeleted;

  BafKnowledgeMatrixMetaStore();

  factory BafKnowledgeMatrixMetaStore.staticFallback() {
    final now = DateTime.now();
    final meta = BafKnowledgeMatrixMetaStore();
    meta.metaKey = 'current';
    meta.matrixVersion = BafKnowledgeLayer.matrixVersion;
    meta.sourceLabel = BafKnowledgeLayer.sourceLabel;
    meta.source = 'staticFallback';
    meta.maintenanceManualRef = BafKnowledgeLayer.maintenanceManualRef;
    meta.safetyOperationsManualRef = BafKnowledgeLayer.safetyOperationsManualRef;
    meta.knowledgeRowCount = BafKnowledgeLayer.knowledgeRowCount;
    meta.tagRowCount = BafKnowledgeLayer.tagRowCount;
    meta.cloudUpdatedAt = null;
    meta.localCachedAt = now;
    meta.updatedAt = now;
    meta.updatedByUid = 'staticFallback';
    meta.updatedByName = 'Embedded safety baseline';
    meta.changeSummary = 'Embedded BAF Knowledge Matrix safety baseline.';
    meta.note = 'Static fallback seeded into local Isar cache.';
    meta.schemaVersion = 1;
    meta.version = 1;
    meta.isSynced = true;
    meta.isDeleted = false;
    return meta;
  }

  factory BafKnowledgeMatrixMetaStore.fromCloudMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    final meta = BafKnowledgeMatrixMetaStore();
    meta.metaKey = 'current';
    meta.matrixVersion = _clean(map['matrixVersion']).isEmpty ? BafKnowledgeLayer.matrixVersion : _clean(map['matrixVersion']);
    meta.sourceLabel = _clean(map['sourceLabel']).isEmpty ? 'Cloud Knowledge Base' : _clean(map['sourceLabel']);
    meta.source = _clean(map['source']).isEmpty ? 'cloud' : _clean(map['source']);
    meta.maintenanceManualRef = _clean(map['maintenanceManualRef']).isEmpty ? BafKnowledgeLayer.maintenanceManualRef : _clean(map['maintenanceManualRef']);
    meta.safetyOperationsManualRef = _clean(map['safetyOperationsManualRef']).isEmpty ? BafKnowledgeLayer.safetyOperationsManualRef : _clean(map['safetyOperationsManualRef']);
    meta.knowledgeRowCount = _int(map['knowledgeRowCount'], BafKnowledgeLayer.knowledgeRowCount);
    meta.tagRowCount = _int(map['tagRowCount'], BafKnowledgeLayer.tagRowCount);
    meta.cloudUpdatedAt = _date(map['updatedAt'] ?? map['cloudUpdatedAt']);
    meta.localCachedAt = now;
    meta.updatedAt = _date(map['updatedAt']) ?? now;
    meta.updatedByUid = _clean(map['updatedByUid']);
    meta.updatedByName = _clean(map['updatedByName']);
    meta.changeSummary = _clean(map['changeSummary']);
    meta.note = _clean(map['note']);
    meta.schemaVersion = _int(map['schemaVersion'], 1);
    meta.version = _int(map['version'], 1);
    meta.isSynced = true;
    meta.isDeleted = map['isDeleted'] == true;
    return meta;
  }
}

String _clean(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_clean(value)) ?? fallback;
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final dynamic maybeTimestamp = value;
    final dynamic converted = maybeTimestamp.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // Not a Firestore timestamp-like object.
  }
  return DateTime.tryParse(_clean(value));
}

List<String> _stringList(Object? value) {
  if (value == null) return <String>[];
  if (value is Iterable) {
    return value.map((item) => _clean(item)).where((item) => item.isNotEmpty).toList();
  }
  final text = _clean(value);
  if (text.isEmpty) return <String>[];
  return text.split(RegExp(r'[;,]')).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
}

List<String> _suggestedFieldLabels(Map<String, dynamic> map) {
  final suggestedFields = map['suggestedFields'];
  if (suggestedFields is Iterable && suggestedFields.any((item) => item is Map)) {
    final labels = suggestedFields
        .whereType<Map>()
        .map((item) => _clean(item['label'] ?? item['title'] ?? item['name']))
        .where((item) => item.isNotEmpty)
        .toList();
    if (labels.isNotEmpty) return labels;
  }
  final legacy = _stringList(suggestedFields);
  if (legacy.isNotEmpty) return legacy;
  final presets = _suggestedFieldPresetMaps(
    map['suggestedFieldPresets'] ?? map['fieldPresets'] ?? map['suggestedFieldDefinitions'],
  );
  return presets
      .map((item) => _clean(item['label'] ?? item['title'] ?? item['name']))
      .where((item) => item.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _suggestedFieldPresetsFromRaw(
  Map<String, dynamic> decoded, {
  List<String> fallbackLabels = const <String>[],
}) {
  final presets = _suggestedFieldPresetMaps(
    decoded['suggestedFieldPresets'] ?? decoded['fieldPresets'] ?? decoded['suggestedFieldDefinitions'],
  );
  if (presets.isNotEmpty) return presets;
  final labels = _stringList(decoded['suggestedFields']).isNotEmpty
      ? _stringList(decoded['suggestedFields'])
      : fallbackLabels;
  return [
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

List<Map<String, dynamic>> _suggestedFieldPresetMaps(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Iterable) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    } catch (_) {
      // Legacy suggestedFields may be a comma-separated string; keep label fallback.
    }
  }
  return <Map<String, dynamic>>[];
}

Map<String, dynamic> _decodeRaw(String rawJson) {
  if (rawJson.trim().isEmpty) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    // Ignore corrupt local raw payload and rebuild from indexed fields.
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _entryMapFromCloud(Map<String, dynamic> map, String rowCode) {
  return <String, dynamic>{
    ...map,
    'rowCode': rowCode,
    'moduleCandidateCode': _clean(map['moduleCandidateCode']).isEmpty ? rowCode : _clean(map['moduleCandidateCode']),
    'safetyClass': _stringList(map['safetyClasses'] ?? map['safetyClass']),
    'suggestedFields': _suggestedFieldLabels(map),
    'suggestedFieldPresets': _suggestedFieldPresetMaps(map['suggestedFieldPresets'] ?? map['fieldPresets']),
  };
}
