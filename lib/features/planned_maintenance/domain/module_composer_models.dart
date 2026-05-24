// FILE: lib/features/planned_maintenance/domain/module_composer_models.dart

import 'dart:convert';

import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';

// ─────────────────────────────────────────────────────────────
// MODULE COMPOSER ENUMS
// ─────────────────────────────────────────────────────────────

enum MaintenanceFrequency {
  everyCharge,
  weekly,
  monthly,
  everyThreeMonths,
  biyearly,
  annually,
  everyTwoYears,
  conditionBased,
  eventBased,
  troubleshootingOnly,
  unknown,
}

enum ComposerReadiness {
  readyPreset,
  needsReview,
  consultRequired,
  tagOnly,
  troubleshootingOnly,
  futureIntegration,
  referenceOnly,
}

enum KnowledgeConfidence {
  confirmedManual,
  confirmedUserRatified,
  inferred,
  inferredNeedsReview,
  plantInactiveFuturePreset,
  consultUser,
}

enum ComposerFieldType {
  yesNo,
  text,
  longText,
  number,
  numericWithUnit,
  dropdown,
  multiSelect,
  passFail,
  dateTime,
}

// ─────────────────────────────────────────────────────────────
// OUTPUT CONTRACT
// ─────────────────────────────────────────────────────────────

class TemplateComposerOutput {
  final String jobTemplateSnapshotJson;
  final String moduleSnapshotsJson;
  final String fieldDefinitionsJson;
  final String checklistJson;

  const TemplateComposerOutput({
    required this.jobTemplateSnapshotJson,
    required this.moduleSnapshotsJson,
    required this.fieldDefinitionsJson,
    required this.checklistJson,
  });
}

// ─────────────────────────────────────────────────────────────
// KNOWLEDGE ENTRY MODEL
// ─────────────────────────────────────────────────────────────

class KnowledgeFieldPreset {
  final String key;
  final String label;
  final ComposerFieldType type;
  final bool isRequired;
  final String? unit;
  final List<String> options;
  final bool isSafetyCriticalPreset;
  final String sourceText;

  const KnowledgeFieldPreset({
    required this.key,
    required this.label,
    required this.type,
    required this.sourceText,
    this.isRequired = false,
    this.unit,
    this.options = const <String>[],
    this.isSafetyCriticalPreset = false,
  });

  factory KnowledgeFieldPreset.fromMap(
    Map<String, dynamic> map, {
    required bool defaultRequired,
    required bool defaultSafetyCritical,
  }) {
    final label =
        _stringFrom(map, const ['label', 'title', 'name']) ??
        _cleanString(map['sourceText']);
    final sourceText =
        _stringFrom(map, const [
          'sourceText',
          'instructionText',
          'sourcePreset',
          'hint',
        ]) ??
        label;
    final key =
        _stringFrom(map, const ['key', 'fieldKey', 'id']) ??
        _fieldKey(label.isEmpty ? sourceText : label);
    final meta = _mapFrom(map['meta']);
    return KnowledgeFieldPreset(
      key: key,
      label: label.isEmpty ? _fieldLabel(key) : label,
      type: _parseFieldType(_stringFrom(map, const ['type', 'fieldType'])),
      isRequired:
          _boolFrom(map['isRequired']) ??
          _boolFrom(map['required']) ??
          defaultRequired,
      unit: _cleanOptionalString(map['unit']),
      options: _stringList(map['options']),
      isSafetyCriticalPreset:
          _boolFrom(map['isSafetyCriticalPreset']) ??
          _boolFrom(meta['isSafetyCriticalPreset']) ??
          defaultSafetyCritical,
      sourceText: sourceText.isEmpty ? label : sourceText,
    );
  }

  Map<String, dynamic> toMap({String? moduleCode, int order = 0}) =>
      <String, dynamic>{
        if (moduleCode != null) 'moduleCode': moduleCode,
        'key': key,
        'label': label,
        'type': _fieldTypeName(type),
        'isRequired': isRequired,
        'order': order,
        'unit': unit,
        'options': options,
        'instructionText': sourceText,
        'meta': <String, dynamic>{
          'isSafetyCriticalPreset': isSafetyCriticalPreset,
          'sourcePreset': sourceText,
        },
      };
}

class BafKnowledgeEntry {
  final String id;
  final String sourceManual;
  final String sourcePage;
  final String sourceType;
  final String assetFamilyKey;
  final AssetType? assetType;
  final String functionalSection;
  final String componentGroup;
  final String taskType;
  final String taskText;
  final MaintenanceFrequency frequency;
  final JobModuleDiscipline discipline;
  final List<String> ownerDisciplines;
  final List<String> safetyClasses;
  final List<String> procedureRefs;
  final List<String> partRefs;
  final List<String> deviceTags;
  final List<String> targetRefs;
  final List<KnowledgeFieldPreset> suggestedFields;
  final bool? requiredForClosureSuggestion;
  final String moduleCandidateCode;
  final String resolverImpact;
  final ComposerReadiness composerReadiness;
  final KnowledgeConfidence confidence;
  final String consultQuestion;
  final Map<String, dynamic> raw;

  const BafKnowledgeEntry({
    required this.id,
    required this.sourceManual,
    required this.sourcePage,
    required this.sourceType,
    required this.assetFamilyKey,
    required this.assetType,
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
    required this.requiredForClosureSuggestion,
    required this.moduleCandidateCode,
    required this.resolverImpact,
    required this.composerReadiness,
    required this.confidence,
    required this.consultQuestion,
    required this.raw,
  });

  factory BafKnowledgeEntry.fromMap(Map<String, dynamic> map, int index) {
    final taskText = _cleanString(map['taskText']);
    final component = _cleanString(map['componentGroup']);
    final assetKey = _normaliseText(
      map['assetFamily'] ?? map['assetFamilyKey'],
    );
    var safetyClasses = _splitClasses(map['safetyClasses']);
    if (safetyClasses.isEmpty) {
      safetyClasses = _splitClasses(map['safetyClass']);
    }
    final discipline = _parseDiscipline(map['discipline'], safetyClasses);
    final ownerDisciplines = _ownerDisciplines(
      map['discipline'],
      discipline,
      component,
      safetyClasses,
    );
    final confidence = _parseConfidence(
      map['confidence'],
      map['consultQuestion'],
    );
    final explicitReadiness = _parseReadiness(map['composerReadiness']);
    final readiness =
        explicitReadiness == ComposerReadiness.referenceOnly &&
                map['composerReadiness'] == null
            ? _inferReadiness(map, confidence)
            : explicitReadiness;
    final requiredForClosure = _parseRequiredForClosure(
      map['requiredForClosure'],
    );
    final rawDeviceTags = _stringList(map['deviceTags']);
    final deviceTags = rawDeviceTags.map((tag) => tag.toUpperCase()).toList();
    final explicitTargetRefs = _stringList(map['targetRefs']);
    final fields = _fieldPresetsFromMap(
      map,
      safetyClasses: safetyClasses,
      defaultRequired: requiredForClosure == true,
    );
    final sourcePage = _cleanString(map['sourcePage']);
    final code =
        _cleanString(map['moduleCandidateCode']).isNotEmpty
            ? _cleanString(map['moduleCandidateCode'])
            : _fallbackModuleCode(assetKey, index);

    return BafKnowledgeEntry(
      id: _entryId(map, index),
      sourceManual: _cleanString(map['sourceManual']),
      sourcePage: sourcePage,
      sourceType: _cleanString(map['sourceType']),
      assetFamilyKey: assetKey,
      assetType: _parseAssetType(assetKey),
      functionalSection: _cleanString(map['functionalSection']),
      componentGroup: component,
      taskType: _cleanString(map['taskType']),
      taskText: taskText,
      frequency: _parseFrequency(map['frequency']),
      discipline: discipline,
      ownerDisciplines: ownerDisciplines,
      safetyClasses: safetyClasses,
      procedureRefs: _stringList(map['procedureRefs']),
      partRefs: _stringList(map['partRefs']),
      deviceTags: deviceTags,
      targetRefs:
          explicitTargetRefs.isNotEmpty
              ? explicitTargetRefs
              : _targetRefs(assetKey, component, rawDeviceTags),
      suggestedFields: fields,
      requiredForClosureSuggestion: requiredForClosure,
      moduleCandidateCode: code,
      resolverImpact: _cleanString(map['resolverImpact']).toLowerCase(),
      composerReadiness: readiness,
      confidence: confidence,
      consultQuestion: _cleanString(map['consultQuestion']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  String get displayTitle {
    final base = componentGroup.isNotEmpty ? componentGroup : functionalSection;
    if (base.isEmpty) {
      return taskText;
    }
    return '${_titleCase(base)} — $taskText';
  }

  String get sourceLabel {
    final manual = sourceManual.isEmpty ? 'Manual' : sourceManual;
    return sourcePage.isEmpty ? manual : '$manual $sourcePage';
  }

  bool get isCloneable =>
      composerReadiness == ComposerReadiness.readyPreset ||
      composerReadiness == ComposerReadiness.needsReview ||
      composerReadiness == ComposerReadiness.futureIntegration ||
      composerReadiness == ComposerReadiness.troubleshootingOnly;

  bool get needsReviewBeforeUse =>
      composerReadiness == ComposerReadiness.needsReview ||
      composerReadiness == ComposerReadiness.consultRequired ||
      composerReadiness == ComposerReadiness.futureIntegration ||
      confidence == KnowledgeConfidence.inferredNeedsReview ||
      confidence == KnowledgeConfidence.consultUser;
}

// ─────────────────────────────────────────────────────────────
// COMPOSER DRAFT MODELS
// ─────────────────────────────────────────────────────────────

class TemplateComposerDraft {
  String localId;
  String title;
  AssetType assetType;
  final List<ComposerModuleDraft> modules;
  final List<TagResolverCorrectionDraft> tagResolverCorrections;
  final List<SafetyJustificationDraft> safetyJustifications;
  final Map<String, dynamic> metadata;
  bool closureReviewConfirmed;

  TemplateComposerDraft({
    String? localId,
    required this.title,
    required this.assetType,
    List<ComposerModuleDraft>? modules,
    List<TagResolverCorrectionDraft>? tagResolverCorrections,
    List<SafetyJustificationDraft>? safetyJustifications,
    Map<String, dynamic>? metadata,
    this.closureReviewConfirmed = false,
  }) : localId = localId ?? 'draft-${DateTime.now().microsecondsSinceEpoch}',
       modules = modules ?? <ComposerModuleDraft>[],
       tagResolverCorrections =
           tagResolverCorrections ?? <TagResolverCorrectionDraft>[],
       safetyJustifications =
           safetyJustifications ?? <SafetyJustificationDraft>[],
       metadata = metadata ?? <String, dynamic>{};

  factory TemplateComposerDraft.empty({String? title, AssetType? assetType}) {
    return TemplateComposerDraft(
      title:
          _cleanString(title).isEmpty
              ? 'BAF governed template'
              : _cleanString(title),
      assetType: assetType ?? AssetType.base,
    );
  }

  factory TemplateComposerDraft.fromPayloads({
    required String jobTemplateSnapshotJson,
    required String moduleSnapshotsJson,
    required String fieldDefinitionsJson,
    required String checklistJson,
  }) {
    final jobSnapshot = _decodeObject(jobTemplateSnapshotJson);
    final moduleSnapshots = _decodeObjectList(moduleSnapshotsJson);
    final fieldDefinitions = _decodeObjectList(fieldDefinitionsJson);
    final checklistItems = _decodeObjectList(checklistJson);
    final title =
        _stringFrom(jobSnapshot, const [
          'title',
          'templateName',
          'jobName',
          'name',
        ]) ??
        'BAF governed template';
    final assetType =
        _parseAssetType(
          _stringFrom(jobSnapshot, const ['assetType', 'applicableAssetType']),
        ) ??
        AssetType.base;
    final composerMeta = _mapFrom(jobSnapshot['composer']);

    final modules = <ComposerModuleDraft>[];
    for (var i = 0; i < moduleSnapshots.length; i++) {
      final snapshot = moduleSnapshots[i];
      final code = _moduleCodeFromSnapshot(snapshot) ?? 'M-${i + 1}';
      final fields =
          fieldDefinitions
              .where((field) => _moduleReferenceMatches(field, code))
              .map((field) => ComposerFieldDraft.fromMap(field))
              .toList();
      final checklist =
          checklistItems
              .where((item) => _moduleReferenceMatches(item, code))
              .map((item) => ComposerChecklistItemDraft.fromMap(item))
              .toList();
      modules.add(
        ComposerModuleDraft.fromSnapshot(
          snapshot,
          displayOrder: i,
          fields: fields,
          checklistItems: checklist,
        ),
      );
    }

    return TemplateComposerDraft(
      localId:
          _cleanString(composerMeta['draftLocalId']).isEmpty
              ? null
              : _cleanString(composerMeta['draftLocalId']),
      title: title,
      assetType: assetType,
      modules: modules,
      metadata: <String, dynamic>{
        'source': 'existingPublisherPayload',
        'loadedAt': DateTime.now().toIso8601String(),
        'closureReviewConfirmedAt': composerMeta['closureReviewConfirmedAt'],
        'closureReviewConfirmedByUid':
            composerMeta['closureReviewConfirmedByUid'],
        'closureReviewConfirmedByName':
            composerMeta['closureReviewConfirmedByName'],
      },
      closureReviewConfirmed:
          _boolFrom(composerMeta['closureReviewConfirmed']) ?? modules.isEmpty,
    );
  }
}

class ComposerModuleDraft {
  String localId;
  String moduleCode;
  String title;
  String description;
  AssetType assetType;
  JobModuleDiscipline discipline;
  List<String> ownerDisciplines;
  String? primaryOwner;
  bool requiresJointReview;
  JobModuleUseMode useMode;
  String functionalSection;
  String componentGroup;
  String subsystem;
  List<String> safetyClasses;
  List<String> targetRefs;
  List<String> deviceTagRefs;
  List<String> procedureRefs;
  List<String> partRefs;
  List<String> operationalStatePreconditions;
  bool requiredForClosure;
  MaintenanceFrequency frequency;
  List<ComposerFieldDraft> fields;
  List<ComposerChecklistItemDraft> checklistItems;
  String? sourceManualRef;
  String? sourceKnowledgeId;
  String? sourceSeedCode;
  ComposerReadiness sourceReadiness;
  KnowledgeConfidence confidence;
  String authoringNotes;
  Map<String, dynamic> metadata;

  ComposerModuleDraft({
    required this.localId,
    required this.moduleCode,
    required this.title,
    required this.description,
    required this.assetType,
    required this.discipline,
    required this.ownerDisciplines,
    required this.primaryOwner,
    required this.requiresJointReview,
    required this.useMode,
    required this.functionalSection,
    required this.componentGroup,
    required this.subsystem,
    required this.safetyClasses,
    required this.targetRefs,
    required this.deviceTagRefs,
    required this.procedureRefs,
    required this.partRefs,
    required this.operationalStatePreconditions,
    required this.requiredForClosure,
    required this.frequency,
    required this.fields,
    required this.checklistItems,
    required this.sourceReadiness,
    required this.confidence,
    this.sourceManualRef,
    this.sourceKnowledgeId,
    this.sourceSeedCode,
    this.authoringNotes = '',
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? <String, dynamic>{};

  factory ComposerModuleDraft.manual({AssetType assetType = AssetType.base}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return ComposerModuleDraft(
      localId: id,
      moduleCode: 'M-$id',
      title: 'New BAF module',
      description: '',
      assetType: assetType,
      discipline: JobModuleDiscipline.mechanical,
      ownerDisciplines: const <String>['mechanical'],
      primaryOwner: 'mechanical',
      requiresJointReview: false,
      useMode: JobModuleUseMode.scheduledPM,
      functionalSection: '',
      componentGroup: '',
      subsystem: '',
      safetyClasses: const <String>['normal'],
      targetRefs: const <String>[],
      deviceTagRefs: const <String>[],
      procedureRefs: const <String>[],
      partRefs: const <String>[],
      operationalStatePreconditions: const <String>[],
      requiredForClosure: false,
      frequency: MaintenanceFrequency.unknown,
      fields: <ComposerFieldDraft>[],
      checklistItems: <ComposerChecklistItemDraft>[],
      sourceReadiness: ComposerReadiness.referenceOnly,
      confidence: KnowledgeConfidence.inferredNeedsReview,
      metadata: <String, dynamic>{'source': 'manualComposerEntry'},
    );
  }

  factory ComposerModuleDraft.fromKnowledge(BafKnowledgeEntry entry) {
    final fields = <ComposerFieldDraft>[];
    for (var i = 0; i < entry.suggestedFields.length; i++) {
      fields.add(
        ComposerFieldDraft.fromPreset(entry.suggestedFields[i], order: i + 1),
      );
    }
    final checklist = <ComposerChecklistItemDraft>[
      ComposerChecklistItemDraft(
        id: '${entry.moduleCandidateCode}-task-1',
        title: entry.taskText,
        description: entry.sourceLabel,
        isRequired: entry.requiredForClosureSuggestion == true,
        order: 1,
        safetyClasses: List<String>.from(entry.safetyClasses),
        metadata: <String, dynamic>{
          'sourceKnowledgeId': entry.id,
          'sourceManualRef': entry.sourceLabel,
        },
      ),
    ];

    return ComposerModuleDraft(
      localId: entry.id,
      moduleCode: entry.moduleCandidateCode,
      title: _titleCase(
        entry.componentGroup.isEmpty ? entry.taskType : entry.componentGroup,
      ),
      description: entry.taskText,
      assetType: entry.assetType ?? AssetType.base,
      discipline:
          entry.ownerDisciplines.length > 1
              ? JobModuleDiscipline.shared
              : entry.discipline,
      ownerDisciplines: List<String>.from(entry.ownerDisciplines),
      primaryOwner:
          entry.ownerDisciplines.isNotEmpty
              ? entry.ownerDisciplines.first
              : null,
      requiresJointReview: entry.ownerDisciplines.length > 1,
      useMode:
          entry.composerReadiness == ComposerReadiness.troubleshootingOnly
              ? JobModuleUseMode.troubleshooting
              : JobModuleUseMode.scheduledPM,
      functionalSection: entry.functionalSection,
      componentGroup: entry.componentGroup,
      subsystem: entry.assetFamilyKey,
      safetyClasses: List<String>.from(entry.safetyClasses),
      targetRefs: List<String>.from(entry.targetRefs),
      deviceTagRefs: List<String>.from(entry.deviceTags),
      procedureRefs: List<String>.from(entry.procedureRefs),
      partRefs: List<String>.from(entry.partRefs),
      operationalStatePreconditions: _preconditionsFrom(entry),
      requiredForClosure: entry.requiredForClosureSuggestion ?? false,
      frequency: entry.frequency,
      fields: fields,
      checklistItems: checklist,
      sourceManualRef: entry.sourceLabel,
      sourceKnowledgeId: entry.id,
      sourceReadiness: entry.composerReadiness,
      confidence: entry.confidence,
      authoringNotes: entry.consultQuestion,
      metadata: <String, dynamic>{
        'source': 'bafKnowledgeMatrixV0_1',
        'sourceKnowledgeId': entry.id,
        'sourceReadiness': entry.composerReadiness.name,
        'confidence': entry.confidence.name,
        'sourceManualRef': entry.sourceLabel,
        'resolverImpact': entry.resolverImpact,
        'consultQuestion': entry.consultQuestion,
      },
    );
  }

  factory ComposerModuleDraft.fromSnapshot(
    Map<String, dynamic> snapshot, {
    required int displayOrder,
    required List<ComposerFieldDraft> fields,
    required List<ComposerChecklistItemDraft> checklistItems,
  }) {
    final metadata = _mapFrom(snapshot['metadata']);
    final code = _moduleCodeFromSnapshot(snapshot) ?? 'M-${displayOrder + 1}';
    final safetyClasses =
        _stringList(metadata['safetyClasses']).isNotEmpty
            ? _stringList(metadata['safetyClasses'])
            : _splitClasses(
              _stringFrom(snapshot, const [
                'safetyClass',
                'defaultSafetyClass',
              ]),
            );
    return ComposerModuleDraft(
      localId: code,
      moduleCode: code,
      title:
          _stringFrom(snapshot, const ['moduleTitle', 'title', 'name']) ?? code,
      description:
          _stringFrom(snapshot, const ['moduleDescription', 'description']) ??
          '',
      assetType:
          _parseAssetType(_stringFrom(snapshot, const ['assetType'])) ??
          AssetType.base,
      discipline: _parseDiscipline(
        _stringFrom(snapshot, const ['discipline', 'defaultDiscipline']),
        safetyClasses,
      ),
      ownerDisciplines: _stringList(metadata['ownerDisciplines']),
      primaryOwner: _cleanOptionalString(metadata['primaryOwner']),
      requiresJointReview: metadata['requiresJointReview'] == true,
      useMode: _parseUseMode(
        _stringFrom(snapshot, const ['useMode', 'defaultUseMode']),
      ),
      functionalSection:
          _stringFrom(snapshot, const ['functionalSection']) ?? '',
      componentGroup: _stringFrom(snapshot, const ['componentGroup']) ?? '',
      subsystem: _stringFrom(snapshot, const ['subsystem']) ?? '',
      safetyClasses: safetyClasses.isEmpty ? <String>['normal'] : safetyClasses,
      targetRefs: _stringList(snapshot['targetRefs']),
      deviceTagRefs: _stringList(snapshot['deviceTagRefs']),
      procedureRefs: _stringList(snapshot['procedureRefs']),
      partRefs: _stringList(metadata['partRefs']),
      operationalStatePreconditions: _stringList(
        snapshot['operationalStatePreconditions'],
      ),
      requiredForClosure: _boolFrom(snapshot['requiredForClosure']) ?? false,
      frequency: _parseFrequency(metadata['frequency']),
      fields: fields,
      checklistItems: checklistItems,
      sourceManualRef: _cleanOptionalString(metadata['sourceManualRef']),
      sourceKnowledgeId: _cleanOptionalString(metadata['sourceKnowledgeId']),
      sourceSeedCode: _cleanOptionalString(metadata['sourceSeedCode']),
      sourceReadiness: _parseReadiness(metadata['sourceReadiness']),
      confidence: _parseConfidence(metadata['confidence'], null),
      authoringNotes: _cleanString(metadata['authoringNotes']),
      metadata: metadata,
    );
  }

  JobModuleSafetyClass get primarySafetyClass =>
      _primarySafetyClass(safetyClasses);
}

class ComposerFieldDraft {
  String key;
  String label;
  ComposerFieldType type;
  bool isRequired;
  int order;
  String? unit;
  List<String> options;
  String instructionText;
  Map<String, dynamic> validation;
  Map<String, dynamic> meta;
  bool isSafetyCriticalPreset;
  String? sourcePresetId;

  ComposerFieldDraft({
    required this.key,
    required this.label,
    required this.type,
    required this.isRequired,
    required this.order,
    this.unit,
    List<String>? options,
    this.instructionText = '',
    Map<String, dynamic>? validation,
    Map<String, dynamic>? meta,
    this.isSafetyCriticalPreset = false,
    this.sourcePresetId,
  }) : options = options ?? <String>[],
       validation = validation ?? <String, dynamic>{},
       meta = meta ?? <String, dynamic>{};

  factory ComposerFieldDraft.fromPreset(
    KnowledgeFieldPreset preset, {
    required int order,
  }) {
    return ComposerFieldDraft(
      key: preset.key,
      label: preset.label,
      type: preset.type,
      isRequired: preset.isRequired,
      order: order,
      unit: preset.unit,
      options: List<String>.from(preset.options),
      instructionText: preset.sourceText,
      isSafetyCriticalPreset: preset.isSafetyCriticalPreset,
      sourcePresetId: preset.sourceText,
      meta: <String, dynamic>{
        'isSafetyCriticalPreset': preset.isSafetyCriticalPreset,
        'sourcePreset': preset.sourceText,
      },
    );
  }

  factory ComposerFieldDraft.fromMap(Map<String, dynamic> map) {
    final meta = _mapFrom(map['meta']);
    return ComposerFieldDraft(
      key: _stringFrom(map, const ['key', 'fieldId', 'id']) ?? 'field',
      label: _stringFrom(map, const ['label', 'title', 'name']) ?? 'Field',
      type: _parseFieldType(_stringFrom(map, const ['type'])),
      isRequired:
          _boolFrom(map['isRequired']) ?? _boolFrom(map['required']) ?? false,
      order: _intFrom(map['order']) ?? 0,
      unit: _cleanOptionalString(map['unit']),
      options: _stringList(map['options']),
      instructionText:
          _stringFrom(map, const ['instructionText', 'hint']) ?? '',
      validation: _mapFrom(map['validation']),
      meta: meta,
      isSafetyCriticalPreset: meta['isSafetyCriticalPreset'] == true,
      sourcePresetId: _cleanOptionalString(
        meta['sourcePresetId'] ?? meta['sourcePreset'],
      ),
    );
  }

  Map<String, dynamic> toMap({required String moduleCode}) => <String, dynamic>{
    'moduleCode': moduleCode,
    'key': key,
    'label': label,
    'type': _fieldTypeName(type),
    'isRequired': isRequired,
    'order': order,
    'unit': unit,
    'options': options,
    'instructionText': instructionText,
    'validation': validation,
    'meta': <String, dynamic>{
      ...meta,
      'isSafetyCriticalPreset': isSafetyCriticalPreset,
      if (sourcePresetId != null) 'sourcePresetId': sourcePresetId,
    },
  };
}

class ComposerChecklistItemDraft {
  String id;
  String title;
  String description;
  bool isRequired;
  int order;
  String? linkedFieldKey;
  List<String> safetyClasses;
  Map<String, dynamic> metadata;

  ComposerChecklistItemDraft({
    required this.id,
    required this.title,
    this.description = '',
    this.isRequired = false,
    this.order = 0,
    this.linkedFieldKey,
    List<String>? safetyClasses,
    Map<String, dynamic>? metadata,
  }) : safetyClasses = safetyClasses ?? <String>[],
       metadata = metadata ?? <String, dynamic>{};

  factory ComposerChecklistItemDraft.fromMap(Map<String, dynamic> map) {
    return ComposerChecklistItemDraft(
      id: _stringFrom(map, const ['id', 'itemId', 'key']) ?? 'item',
      title: _stringFrom(map, const ['title', 'label']) ?? 'Checklist item',
      description: _stringFrom(map, const ['description']) ?? '',
      isRequired:
          _boolFrom(map['isRequired']) ?? _boolFrom(map['required']) ?? false,
      order: _intFrom(map['order']) ?? 0,
      linkedFieldKey: _cleanOptionalString(map['linkedFieldKey']),
      safetyClasses: _stringList(map['safetyClasses']),
      metadata: _mapFrom(map['metadata']),
    );
  }

  Map<String, dynamic> toMap({required String moduleCode}) => <String, dynamic>{
    'moduleCode': moduleCode,
    'id': id,
    'title': title,
    'description': description,
    'isRequired': isRequired,
    'order': order,
    'linkedFieldKey': linkedFieldKey,
    'safetyClasses': safetyClasses,
    'metadata': metadata,
  };
}

class TagResolverCorrectionDraft {
  final String rawInput;
  final String normalizedTag;
  final String resolvedComponent;
  final String status;

  const TagResolverCorrectionDraft({
    required this.rawInput,
    required this.normalizedTag,
    required this.resolvedComponent,
    this.status = 'approvedForThisVersion',
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'rawInput': rawInput,
    'normalizedTag': normalizedTag,
    'resolvedComponent': resolvedComponent,
    'status': status,
  };
}

class SafetyJustificationDraft {
  final String fieldKey;
  final String reason;
  final DateTime at;

  SafetyJustificationDraft({
    required this.fieldKey,
    required this.reason,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toMap() => <String, dynamic>{
    'fieldKey': fieldKey,
    'reason': reason,
    'at': at.toIso8601String(),
  };
}

class BafTagResolution {
  final String rawInput;
  final String normalizedTag;
  final String? displayName;
  final AssetType? assetType;
  final String? functionalSection;
  final String? componentGroup;
  final String? subsystem;
  final JobModuleDiscipline? discipline;
  final List<String> ownerDisciplines;
  final List<String> safetyClasses;
  final List<String> hierarchyPath;
  final List<String> procedureRefs;
  final List<String> sourceManualRefs;
  final double confidence;
  final bool requiresReview;
  final String resolutionSource;

  const BafTagResolution({
    required this.rawInput,
    required this.normalizedTag,
    this.displayName,
    this.assetType,
    this.functionalSection,
    this.componentGroup,
    this.subsystem,
    this.discipline,
    this.ownerDisciplines = const <String>[],
    this.safetyClasses = const <String>[],
    this.hierarchyPath = const <String>[],
    this.procedureRefs = const <String>[],
    this.sourceManualRefs = const <String>[],
    required this.confidence,
    required this.requiresReview,
    required this.resolutionSource,
  });
}

// ─────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────

String _entryId(Map<String, dynamic> map, int index) {
  final code = _cleanString(map['moduleCandidateCode']);
  if (code.isNotEmpty) {
    return _slug(code);
  }
  final tags = _stringList(map['deviceTags']);
  if (tags.isNotEmpty) {
    return _slug(tags.join('_'));
  }
  return 'knowledge_${index + 1}_${_slug(_cleanString(map['componentGroup']))}';
}

String _fallbackModuleCode(String assetKey, int index) {
  final prefix = switch (assetKey) {
    'base' => 'B',
    'furnace' => 'F',
    'forcedcooler' => 'FC',
    'innercover' => 'IC',
    'automation' => 'AUTO',
    'atmosphere' => 'ATM',
    'motorcontrol' => 'MCC',
    _ => 'BAF',
  };
  return '$prefix-K-${(index + 1).toString().padLeft(3, '0')}';
}

List<String> _preconditionsFrom(BafKnowledgeEntry entry) {
  final conditions = <String>[];
  if (entry.safetyClasses.any((item) => item.toLowerCase().contains('loto'))) {
    conditions.add(
      'LOTO / isolation confirmation where physical/electrical work is involved',
    );
  }
  if (entry.safetyClasses.any((item) => item.toLowerCase().contains('gas'))) {
    conditions.add('Gas-risk work condition reviewed');
  }
  if (entry.safetyClasses.any(
    (item) => item.toLowerCase().contains('hydrogen'),
  )) {
    conditions.add('Hydrogen / nitrogen purge implication reviewed');
  }
  return conditions;
}

List<KnowledgeFieldPreset> _fieldPresetsFromMap(
  Map<String, dynamic> map, {
  required List<String> safetyClasses,
  required bool defaultRequired,
}) {
  final isSafetyCritical = _isSafetyCritical(safetyClasses);
  final structured = _structuredFieldPresetMaps(
    map['suggestedFieldPresets'] ??
        map['fieldPresets'] ??
        map['suggestedFieldDefinitions'],
  );
  if (structured.isNotEmpty) {
    final parsed = <KnowledgeFieldPreset>[];
    for (final item in structured) {
      final preset = KnowledgeFieldPreset.fromMap(
        item,
        defaultRequired: defaultRequired && isSafetyCritical,
        defaultSafetyCritical: isSafetyCritical,
      );
      if (preset.key.trim().isNotEmpty && preset.label.trim().isNotEmpty) {
        parsed.add(preset);
      }
    }
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  final suggestedFields = map['suggestedFields'];
  if (suggestedFields is Iterable &&
      suggestedFields.any((item) => item is Map)) {
    final parsed = <KnowledgeFieldPreset>[];
    for (final item in suggestedFields) {
      if (item is! Map) {
        continue;
      }
      final preset = KnowledgeFieldPreset.fromMap(
        Map<String, dynamic>.from(item),
        defaultRequired: defaultRequired && isSafetyCritical,
        defaultSafetyCritical: isSafetyCritical,
      );
      if (preset.key.trim().isNotEmpty && preset.label.trim().isNotEmpty) {
        parsed.add(preset);
      }
    }
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  return _fieldPresets(
    _stringList(suggestedFields),
    safetyClasses: safetyClasses,
    defaultRequired: defaultRequired,
  );
}

List<Map<String, dynamic>> _structuredFieldPresetMaps(dynamic value) {
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
      // Fall back to legacy string suggestedFields parsing below.
    }
  }
  return <Map<String, dynamic>>[];
}

List<KnowledgeFieldPreset> _fieldPresets(
  List<String> rawFields, {
  required List<String> safetyClasses,
  required bool defaultRequired,
}) {
  final isSafetyCritical = _isSafetyCritical(safetyClasses);
  final fields = <KnowledgeFieldPreset>[];
  for (final raw in rawFields) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      continue;
    }
    final key = _fieldKey(cleaned);
    fields.add(
      KnowledgeFieldPreset(
        key: key,
        label: _fieldLabel(cleaned),
        type: _inferFieldType(cleaned),
        unit: _inferUnit(cleaned),
        options: _inferOptions(cleaned),
        isRequired: defaultRequired && isSafetyCritical,
        isSafetyCriticalPreset: isSafetyCritical,
        sourceText: cleaned,
      ),
    );
  }
  if (fields.isEmpty) {
    fields.add(
      KnowledgeFieldPreset(
        key: 'observation',
        label: 'Observation',
        type: ComposerFieldType.longText,
        isRequired: defaultRequired,
        isSafetyCriticalPreset: isSafetyCritical,
        sourceText: 'Generated observation field',
      ),
    );
  }
  return fields;
}

bool _isSafetyCritical(List<String> safetyClasses) {
  final joined = safetyClasses.join(' ').toLowerCase();
  return joined.contains('gas') ||
      joined.contains('hydrogen') ||
      joined.contains('explosion') ||
      joined.contains('loto') ||
      joined.contains('interlock') ||
      joined.contains('hydraulic') ||
      joined.contains('waterflow') ||
      joined.contains('combustion');
}

String _fieldKey(String raw) {
  final beforeParen = raw.split('(').first;
  return _slug(beforeParen)
      .replaceAll('-', '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _fieldLabel(String raw) {
  final beforeParen = raw.split('(').first.replaceAll('_', ' ').trim();
  return _titleCase(beforeParen);
}

ComposerFieldType _inferFieldType(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('numeric') ||
      lower.contains('value') ||
      lower.contains('reading')) {
    return lower.contains('unit')
        ? ComposerFieldType.numericWithUnit
        : ComposerFieldType.number;
  }
  if (lower.contains('dropdown') || lower.contains('enum')) {
    return ComposerFieldType.dropdown;
  }
  if (lower.contains('multi')) {
    return ComposerFieldType.multiSelect;
  }
  if (lower.contains('pass') || lower.contains('fail')) {
    return ComposerFieldType.passFail;
  }
  if (lower.contains('yes_no') ||
      lower.contains('yes/no') ||
      lower.endsWith('_yes_no')) {
    return ComposerFieldType.yesNo;
  }
  if (lower.contains('long_text') ||
      lower.contains('remarks') ||
      lower.contains('action')) {
    return ComposerFieldType.longText;
  }
  return ComposerFieldType.text;
}

String? _inferUnit(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('temperature') || lower.contains('te')) {
    return '°C';
  }
  if (lower.contains('pressure')) {
    return 'as shown';
  }
  if (lower.contains('vibration') || lower.contains('vt')) {
    return 'HMI unit';
  }
  if (lower.contains('flow')) {
    return 'HMI unit';
  }
  return null;
}

List<String> _inferOptions(String raw) {
  final match = RegExp(r'\(([^)]+)\)').firstMatch(raw);
  if (match != null) {
    return match
        .group(1)!
        .split(RegExp(r'[/,;|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final lower = raw.toLowerCase();
  if (lower.contains('condition') ||
      lower.contains('dropdown') ||
      lower.contains('enum')) {
    return const <String>['Good', 'Fair', 'Poor', 'Damaged', 'Not checked'];
  }
  if (lower.contains('pass') || lower.contains('fail')) {
    return const <String>['Pass', 'Fail', 'Not done'];
  }
  return const <String>[];
}

ComposerReadiness _inferReadiness(
  Map<String, dynamic> map,
  KnowledgeConfidence confidence,
) {
  final sourceType = _cleanString(map['sourceType']).toLowerCase();
  final consult = _cleanString(map['consultQuestion']);
  final required = _cleanString(map['requiredForClosure']).toLowerCase();
  final taskType = _cleanString(map['taskType']).toLowerCase();
  final tags = _stringList(map['deviceTags']);
  if (confidence == KnowledgeConfidence.plantInactiveFuturePreset) {
    return ComposerReadiness.futureIntegration;
  }
  if (consult.isNotEmpty ||
      required == 'consult' ||
      confidence == KnowledgeConfidence.consultUser) {
    return ComposerReadiness.consultRequired;
  }
  if (sourceType.contains('troubleshooting') ||
      taskType.contains('troubleshoot')) {
    return ComposerReadiness.troubleshootingOnly;
  }
  if (tags.isNotEmpty && _cleanString(map['taskText']).isEmpty) {
    return ComposerReadiness.tagOnly;
  }
  if (confidence == KnowledgeConfidence.inferred ||
      confidence == KnowledgeConfidence.inferredNeedsReview) {
    return ComposerReadiness.needsReview;
  }
  return ComposerReadiness.readyPreset;
}

KnowledgeConfidence _parseConfidence(dynamic value, dynamic consultQuestion) {
  final key = _normaliseText(value);
  final consult = _cleanString(consultQuestion);
  if (consult.isNotEmpty) {
    return KnowledgeConfidence.consultUser;
  }
  if (key.contains('ratified')) {
    return KnowledgeConfidence.confirmedUserRatified;
  }
  if (key.contains('future') || key.contains('inactive')) {
    return KnowledgeConfidence.plantInactiveFuturePreset;
  }
  if (key.contains('inferredneedsreview') || key.contains('needsreview')) {
    return KnowledgeConfidence.inferredNeedsReview;
  }
  if (key.contains('infer')) {
    return KnowledgeConfidence.inferred;
  }
  if (key.contains('consult')) {
    return KnowledgeConfidence.consultUser;
  }
  return KnowledgeConfidence.confirmedManual;
}

ComposerReadiness _parseReadiness(dynamic value) {
  final key = _normaliseText(value);
  for (final readiness in ComposerReadiness.values) {
    if (_normaliseText(readiness.name) == key) {
      return readiness;
    }
  }
  return ComposerReadiness.referenceOnly;
}

MaintenanceFrequency _parseFrequency(dynamic value) {
  final key = _normaliseText(value);
  switch (key) {
    case 'everycharge':
      return MaintenanceFrequency.everyCharge;
    case 'weekly':
      return MaintenanceFrequency.weekly;
    case 'monthly':
      return MaintenanceFrequency.monthly;
    case 'everythreemonths':
    case 'threemonthly':
      return MaintenanceFrequency.everyThreeMonths;
    case 'biyearly':
    case 'biannual':
      return MaintenanceFrequency.biyearly;
    case 'annually':
    case 'annual':
      return MaintenanceFrequency.annually;
    case 'everytwoyears':
      return MaintenanceFrequency.everyTwoYears;
    case 'conditionbased':
      return MaintenanceFrequency.conditionBased;
    case 'eventbased':
      return MaintenanceFrequency.eventBased;
    case 'troubleshootingonly':
      return MaintenanceFrequency.troubleshootingOnly;
    default:
      return MaintenanceFrequency.unknown;
  }
}

AssetType? _parseAssetType(String? value) {
  final key = _normaliseText(value);
  switch (key) {
    case 'base':
      return AssetType.base;
    case 'furnace':
      return AssetType.furnace;
    case 'forcedcooler':
    case 'forcecooler':
    case 'cooler':
      return AssetType.forceCooler;
    case 'innercover':
      return AssetType.innerCover;
  }
  return null;
}

JobModuleDiscipline _parseDiscipline(
  dynamic value,
  List<String> safetyClasses,
) {
  final key = _normaliseText(value);
  if (key.contains('shared')) {
    return JobModuleDiscipline.shared;
  }
  if (key.contains('mechanical') &&
      (key.contains('instrument') || key.contains('electrical'))) {
    return JobModuleDiscipline.shared;
  }
  switch (key) {
    case 'mechanical':
      return JobModuleDiscipline.mechanical;
    case 'electrical':
      return JobModuleDiscipline.electrical;
    case 'instrumentation':
    case 'ia':
    case 'ianda':
      return JobModuleDiscipline.instrumentation;
    case 'operations':
      return JobModuleDiscipline.operations;
    case 'safety':
      return JobModuleDiscipline.safety;
    case 'admin':
      return JobModuleDiscipline.admin;
    case 'refractory':
      return JobModuleDiscipline.others;
  }
  return _isSafetyCritical(safetyClasses)
      ? JobModuleDiscipline.shared
      : JobModuleDiscipline.mechanical;
}

JobModuleUseMode _parseUseMode(String? value) {
  final key = _normaliseText(value);
  for (final mode in JobModuleUseMode.values) {
    if (_normaliseText(mode.name) == key) {
      return mode;
    }
  }
  return JobModuleUseMode.scheduledPM;
}

ComposerFieldType _parseFieldType(String? value) {
  final key = _normaliseText(value);
  for (final type in ComposerFieldType.values) {
    if (_normaliseText(type.name) == key) {
      return type;
    }
  }
  if (key == 'boolean' || key == 'yesno') {
    return ComposerFieldType.yesNo;
  }
  if (key == 'enum') {
    return ComposerFieldType.dropdown;
  }
  if (key == 'numericwithunit') {
    return ComposerFieldType.numericWithUnit;
  }
  return ComposerFieldType.text;
}

List<String> _ownerDisciplines(
  dynamic value,
  JobModuleDiscipline discipline,
  String component,
  List<String> safetyClasses,
) {
  final raw = _cleanString(value).toLowerCase();
  final owners = <String>{};
  void addIf(String needle, String owner) {
    if (raw.contains(needle)) {
      owners.add(owner);
    }
  }

  addIf('mechanical', 'mechanical');
  addIf('electrical', 'electrical');
  addIf('instrument', 'instrumentation');
  addIf('i&a', 'instrumentation');
  addIf('ia', 'instrumentation');
  addIf('operation', 'operations');
  addIf('refractory', 'refractory');
  final safety = safetyClasses.join(' ').toLowerCase();
  final comp = component.toLowerCase();
  if (comp.contains('hydraulic') && comp.contains('clamp')) {
    owners.addAll(['mechanical', 'instrumentation']);
  }
  if (safety.contains('gas') || safety.contains('combustion')) {
    owners.addAll(['mechanical', 'instrumentation', 'electrical']);
  }
  if (safety.contains('electric')) {
    owners.add('electrical');
  }
  if (safety.contains('interlock')) {
    owners.add('instrumentation');
  }
  if (owners.isEmpty) {
    switch (discipline) {
      case JobModuleDiscipline.mechanical:
        owners.add('mechanical');
        break;
      case JobModuleDiscipline.electrical:
        owners.add('electrical');
        break;
      case JobModuleDiscipline.instrumentation:
        owners.add('instrumentation');
        break;
      case JobModuleDiscipline.operations:
        owners.add('operations');
        break;
      case JobModuleDiscipline.others:
        owners.add('refractory');
        break;
      case JobModuleDiscipline.shared:
      case JobModuleDiscipline.shiftInCharge:
      case JobModuleDiscipline.safety:
      case JobModuleDiscipline.admin:
        owners.add('mechanical');
        break;
    }
  }
  return owners.toList()..sort();
}

List<String> _targetRefs(String assetKey, String component, List<String> tags) {
  final refs = <String>{};
  if (assetKey.isNotEmpty) {
    refs.add(assetKey);
  }
  for (final part in component.split(RegExp(r'[/,;|\s]+'))) {
    final slug = _slug(part);
    if (slug.isNotEmpty) {
      refs.add(slug);
    }
  }
  refs.addAll(tags.map((tag) => tag.toUpperCase()));
  return refs.toList();
}

bool? _parseRequiredForClosure(dynamic value) {
  final key = _normaliseText(value);
  if (key == 'yes' || key == 'true' || key == 'required') {
    return true;
  }
  if (key == 'no' || key == 'false' || key == 'optional') {
    return false;
  }
  return null;
}

JobModuleSafetyClass _primarySafetyClass(List<String> safetyClasses) {
  final joined = safetyClasses.join(' ').toLowerCase();
  if (joined.contains('loto')) {
    return JobModuleSafetyClass.lotoRequired;
  }
  if (joined.contains('gas') ||
      joined.contains('hydrogen') ||
      joined.contains('explosion')) {
    return JobModuleSafetyClass.gasRisk;
  }
  if (joined.contains('hot') || joined.contains('burn')) {
    return JobModuleSafetyClass.hotSurface;
  }
  if (joined.contains('electrical') || joined.contains('electric')) {
    return JobModuleSafetyClass.electricalPanel;
  }
  if (joined.contains('lifting')) {
    return JobModuleSafetyClass.liftingRisk;
  }
  if (joined.contains('pressure') ||
      joined.contains('hydraulic') ||
      joined.contains('water')) {
    return JobModuleSafetyClass.pressureTest;
  }
  if (joined.contains('combustion')) {
    return JobModuleSafetyClass.combustionSpecialist;
  }
  if (joined.contains('configuration') || joined.contains('plc')) {
    return JobModuleSafetyClass.configurationControl;
  }
  return JobModuleSafetyClass.normal;
}

List<String> _splitClasses(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return _cleanString(value)
      .split(RegExp(r'[;,/|]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is List) {
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

Map<String, dynamic> _mapFrom(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

String? _cleanOptionalString(dynamic value) {
  final cleaned = _cleanString(value);
  return cleaned.isEmpty ? null : cleaned;
}

String _cleanString(dynamic value) => value?.toString().trim() ?? '';

String _normaliseText(dynamic value) => _cleanString(
  value,
).toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), '');

String? _moduleCodeFromSnapshot(Map<String, dynamic> snapshot) {
  return _stringFrom(snapshot, const ['moduleCode', 'code', 'moduleId', 'id']);
}

/// Resolve a field/checklist reference TO a module.
///
/// `templateModuleId` and `parentModuleCode` are reference aliases only; they
/// are intentionally not accepted as a module's own identity key.
bool _moduleReferenceMatches(Map<String, dynamic> payload, String moduleCode) {
  final reference = _stringFrom(payload, const [
    'moduleCode',
    'moduleId',
    'templateModuleId',
    'parentModuleCode',
  ]);
  if (reference == null) {
    return false;
  }
  return _normaliseText(reference) == _normaliseText(moduleCode);
}

String _slug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .map(
        (word) =>
            word.length == 1
                ? word.toUpperCase()
                : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _fieldTypeName(ComposerFieldType type) {
  switch (type) {
    case ComposerFieldType.yesNo:
      return 'yesNo';
    case ComposerFieldType.text:
      return 'text';
    case ComposerFieldType.longText:
      return 'longText';
    case ComposerFieldType.number:
      return 'number';
    case ComposerFieldType.numericWithUnit:
      return 'numericWithUnit';
    case ComposerFieldType.dropdown:
      return 'dropdown';
    case ComposerFieldType.multiSelect:
      return 'multiSelect';
    case ComposerFieldType.passFail:
      return 'passFail';
    case ComposerFieldType.dateTime:
      return 'dateTime';
  }
}

Map<String, dynamic> _decodeObject(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _decodeObjectList(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
  } catch (_) {}
  return <Map<String, dynamic>>[];
}

String? _stringFrom(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString();
    }
  }
  return null;
}

int? _intFrom(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool? _boolFrom(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final key = value.trim().toLowerCase();
    if (key == 'true' || key == 'yes' || key == 'required') {
      return true;
    }
    if (key == 'false' || key == 'no' || key == 'optional') {
      return false;
    }
  }
  return null;
}
