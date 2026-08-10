// FILE: lib/features/planned_maintenance/data/baf_knowledge_model.dart

import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../core/services/global_pull_protocol.dart';
import '../domain/baf_knowledge_layer.dart';
import '../domain/module_composer_models.dart';
import 'remote_baf_knowledge_reader.dart';

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
    row.suggestedFields =
        entry.suggestedFields.map((field) => field.label).toList();
    row.requiredForClosure =
        entry.requiredForClosureSuggestion == null
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
      'suggestedFieldPresets':
          entry.suggestedFields.map((field) => field.toMap()).toList(),
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
    final decoded = readRemoteBafKnowledgeRow(map, docId);
    final row = BafKnowledgeRow();
    if (localId != null) row.id = localId;
    row.rowCode = decoded.rowCode;
    row.sourceManual = decoded.sourceManual;
    row.sourcePage = decoded.sourcePage;
    row.sourceType = decoded.sourceType;
    row.assetFamily = decoded.assetFamily;
    row.functionalSection = decoded.functionalSection;
    row.componentGroup = decoded.componentGroup;
    row.taskType = decoded.taskType;
    row.taskText = decoded.taskText;
    row.frequency = decoded.frequency;
    row.discipline = decoded.discipline;
    row.ownerDisciplines = decoded.ownerDisciplines;
    row.safetyClasses = decoded.safetyClasses;
    row.procedureRefs = decoded.procedureRefs;
    row.partRefs = decoded.partRefs;
    row.deviceTags = decoded.deviceTags;
    row.targetRefs = decoded.targetRefs;
    row.suggestedFields = decoded.suggestedFields;
    row.requiredForClosure = decoded.requiredForClosure;
    row.moduleCandidateCode = decoded.moduleCandidateCode;
    row.resolverImpact = decoded.resolverImpact;
    row.composerReadiness = decoded.composerReadiness;
    row.confidence = decoded.confidence;
    row.consultQuestion = decoded.consultQuestion;
    row.lifecycleStatus = decoded.lifecycleStatus;
    row.matrixVersion = decoded.matrixVersion;
    row.schemaVersion = decoded.schemaVersion;
    row.version = decoded.version;
    row.createdByUid = decoded.createdByUid;
    row.createdByName = decoded.createdByName;
    row.createdAt = decoded.createdAt;
    row.updatedByUid = decoded.updatedByUid;
    row.updatedByName = decoded.updatedByName;
    row.updatedAt = decoded.updatedAt;
    row.changeSummary = decoded.changeSummary;
    row.rawJson = jsonEncode(decoded.rawMap);
    row.isSynced = true;
    row.isDeleted = decoded.isDeleted;
    return row;
  }

  BafKnowledgeEntry toEntry(int index) {
    return BafKnowledgeEntry.fromMap(toEntryMap(), index);
  }

  Map<String, dynamic> toEntryMap() {
    final decoded = readBafKnowledgeRawJson(
      rawJson,
      source: 'local knowledge_base/$rowCode',
    )..remove(globalPullServerUpdatedAtField);
    final map = <String, dynamic>{
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
    map.remove(globalPullServerUpdatedAtField);
    return map;
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
    map.remove(globalPullServerUpdatedAtField);
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
    meta.safetyOperationsManualRef =
        BafKnowledgeLayer.safetyOperationsManualRef;
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

  factory BafKnowledgeMatrixMetaStore.fromCloudMap(
    Map<String, dynamic> map, {
    required DateTime localCachedAt,
  }) {
    final decoded = readRemoteBafKnowledgeMeta(map);
    final meta = BafKnowledgeMatrixMetaStore();
    meta.metaKey = 'current';
    meta.matrixVersion = decoded.matrixVersion;
    meta.sourceLabel = decoded.sourceLabel;
    meta.source = decoded.source;
    meta.maintenanceManualRef = decoded.maintenanceManualRef;
    meta.safetyOperationsManualRef = decoded.safetyOperationsManualRef;
    meta.knowledgeRowCount = decoded.knowledgeRowCount;
    meta.tagRowCount = decoded.tagRowCount;
    meta.cloudUpdatedAt = decoded.updatedAt;
    meta.localCachedAt = localCachedAt;
    meta.updatedAt = decoded.updatedAt;
    meta.updatedByUid = decoded.updatedByUid;
    meta.updatedByName = decoded.updatedByName;
    meta.changeSummary = decoded.changeSummary;
    meta.note = decoded.note;
    meta.schemaVersion = decoded.schemaVersion;
    meta.version = decoded.version;
    meta.isSynced = true;
    meta.isDeleted = decoded.isDeleted;
    return meta;
  }
}

List<Map<String, dynamic>> _suggestedFieldPresetsFromRaw(
  Map<String, dynamic> decoded, {
  List<String> fallbackLabels = const <String>[],
}) {
  final field =
      decoded.containsKey('suggestedFieldPresets')
          ? 'suggestedFieldPresets'
          : decoded.containsKey('fieldPresets')
          ? 'fieldPresets'
          : 'suggestedFieldDefinitions';
  final presets = readBafKnowledgeSuggestedFieldPresets(
    decoded[field],
    field: field,
    source: 'local knowledge row rawJson',
  );
  if (presets.isNotEmpty) return presets;
  return [
    for (final label in fallbackLabels)
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
