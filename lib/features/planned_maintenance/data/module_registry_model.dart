import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import 'job_module_model.dart';
import '../domain/module_composer_models.dart';
import '../domain/module_registry_content_hash.dart';
import '../domain/module_workshop_actions.dart';

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  try {
    final dynamic maybeTimestamp = value;
    final converted = maybeTimestamp.toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // Fall through to null.
  }
  return null;
}

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
  if (value is! String) {
    return fallback;
  }
  for (final item in values) {
    if (item.name == value) {
      return item;
    }
  }
  return fallback;
}

String? _cleanOptionalText(dynamic value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _cleanRequiredText(dynamic value, String fallback) {
  return _cleanOptionalText(value) ?? fallback;
}

String? _cleanAliasText(dynamic value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _firstAliasText(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _cleanAliasText(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String _normaliseModuleReference(dynamic value) =>
    _cleanAliasText(value)
        ?.toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
    '';

/// Resolve a module's own identity from a registry/composer snapshot.
///
/// `templateModuleId` is deliberately excluded here because it is a reference
/// alias used by fields/checklist items, not a module identity field.
String? _moduleCodeFromSnapshot(Map<String, dynamic> snapshot) {
  return _firstAliasText(snapshot, const [
    'moduleCode',
    'code',
    'moduleId',
    'id',
  ]);
}

/// Resolve a field/checklist reference TO a module.
bool _moduleReferenceMatches(Map<String, dynamic> payload, String moduleCode) {
  final reference = _firstAliasText(payload, const [
    'moduleCode',
    'moduleId',
    'templateModuleId',
    'parentModuleCode',
  ]);
  if (reference == null) {
    return false;
  }
  return _normaliseModuleReference(reference) ==
      _normaliseModuleReference(moduleCode);
}

List<String> _cleanStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> _decodeJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Invalid registry snapshots are not cloneable.
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _decodeJsonObjectList(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  } catch (_) {
    // Invalid registry snapshots are not cloneable.
  }
  return const <Map<String, dynamic>>[];
}

enum ModuleRegistryFamilyStatus { active, retired }

enum ModuleRegistryRevisionStatus { draft, published, retired }

enum ModuleRegistryAuditAction {
  draftCreated,
  draftUpdated,
  revisionPublished,
  revisionRetired,
  familyRetired,
}

String moduleRegistryIdForModule(ComposerModuleDraft module) {
  final code = module.moduleCode.trim().toLowerCase();
  final slug = code
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'baf.module.${slug.isEmpty ? 'untitled' : slug}';
}

class ModuleRegistryFamily {
  ModuleRegistryFamily({
    required this.registryModuleId,
    required this.moduleCode,
    required this.canonicalTitle,
    this.status = ModuleRegistryFamilyStatus.active,
    required this.discipline,
    required this.ownerDisciplines,
    required this.assetType,
    required this.functionalSection,
    required this.componentGroup,
    required this.targetRefs,
    required this.deviceTagRefs,
    required this.safetyClasses,
    required this.requiredForClosure,
    this.latestPublishedRevisionNumber = 0,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedByUid,
    this.updatedByName,
    this.updatedAt,
    this.retiredByUid,
    this.retiredByName,
    this.retiredAt,
    this.retireReason,
    this.version = 1,
    this.schemaVersion = 1,
    this.isDeleted = false,
  });

  final String registryModuleId;
  String moduleCode;
  String canonicalTitle;
  ModuleRegistryFamilyStatus status;
  JobModuleDiscipline discipline;
  List<String> ownerDisciplines;
  AssetType assetType;
  String functionalSection;
  String componentGroup;
  List<String> targetRefs;
  List<String> deviceTagRefs;
  List<String> safetyClasses;
  bool requiredForClosure;
  int latestPublishedRevisionNumber;
  String? createdByUid;
  String? createdByName;
  DateTime? createdAt;
  String? updatedByUid;
  String? updatedByName;
  DateTime? updatedAt;
  String? retiredByUid;
  String? retiredByName;
  DateTime? retiredAt;
  String? retireReason;
  int version;
  int schemaVersion;
  bool isDeleted;

  bool get isActive =>
      status == ModuleRegistryFamilyStatus.active && !isDeleted;
  bool get isRetired => status == ModuleRegistryFamilyStatus.retired;

  factory ModuleRegistryFamily.fromModule({
    required ComposerModuleDraft module,
    required AppUser actor,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return ModuleRegistryFamily(
      registryModuleId: moduleRegistryIdForModule(module),
      moduleCode: module.moduleCode.trim(),
      canonicalTitle:
          module.title.trim().isEmpty
              ? module.moduleCode.trim()
              : module.title.trim(),
      discipline: module.discipline,
      ownerDisciplines: List<String>.from(module.ownerDisciplines),
      assetType: module.assetType,
      functionalSection: module.functionalSection.trim(),
      componentGroup: module.componentGroup.trim(),
      targetRefs: List<String>.from(module.targetRefs),
      deviceTagRefs: List<String>.from(module.deviceTagRefs),
      safetyClasses: List<String>.from(module.safetyClasses),
      requiredForClosure: module.requiredForClosure,
      createdByUid: actor.uid,
      createdByName: actor.name,
      createdAt: timestamp,
      updatedByUid: actor.uid,
      updatedByName: actor.name,
      updatedAt: timestamp,
    );
  }

  factory ModuleRegistryFamily.fromMap(Map<String, dynamic> map, String docId) {
    return ModuleRegistryFamily(
      registryModuleId: _cleanRequiredText(map['registryModuleId'], docId),
      moduleCode: _cleanRequiredText(map['moduleCode'], 'MODULE'),
      canonicalTitle: _cleanRequiredText(
        map['canonicalTitle'],
        'Registry module',
      ),
      status: _enumByNameOr(
        ModuleRegistryFamilyStatus.values,
        map['status'],
        ModuleRegistryFamilyStatus.active,
      ),
      discipline: _enumByNameOr(
        JobModuleDiscipline.values,
        map['discipline'],
        JobModuleDiscipline.shared,
      ),
      ownerDisciplines: _cleanStringList(map['ownerDisciplines']),
      assetType: _enumByNameOr(
        AssetType.values,
        map['assetType'],
        AssetType.base,
      ),
      functionalSection: _cleanRequiredText(map['functionalSection'], ''),
      componentGroup: _cleanRequiredText(map['componentGroup'], ''),
      targetRefs: _cleanStringList(map['targetRefs']),
      deviceTagRefs: _cleanStringList(map['deviceTagRefs']),
      safetyClasses: _cleanStringList(map['safetyClasses']),
      requiredForClosure: map['requiredForClosure'] == true,
      latestPublishedRevisionNumber:
          map['latestPublishedRevisionNumber'] is int
              ? map['latestPublishedRevisionNumber'] as int
              : 0,
      createdByUid: _cleanOptionalText(map['createdByUid']),
      createdByName: _cleanOptionalText(map['createdByName']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedByUid: _cleanOptionalText(map['updatedByUid']),
      updatedByName: _cleanOptionalText(map['updatedByName']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      retiredByUid: _cleanOptionalText(map['retiredByUid']),
      retiredByName: _cleanOptionalText(map['retiredByName']),
      retiredAt: _parseTimestamp(map['retiredAt']),
      retireReason: _cleanOptionalText(map['retireReason']),
      version: map['version'] is int ? map['version'] as int : 1,
      schemaVersion:
          map['schemaVersion'] is int ? map['schemaVersion'] as int : 1,
      isDeleted: map['isDeleted'] == true,
    );
  }

  void refreshFromModule(
    ComposerModuleDraft module,
    AppUser actor, {
    DateTime? now,
  }) {
    moduleCode = module.moduleCode.trim();
    canonicalTitle =
        module.title.trim().isEmpty
            ? module.moduleCode.trim()
            : module.title.trim();
    discipline = module.discipline;
    ownerDisciplines = List<String>.from(module.ownerDisciplines);
    assetType = module.assetType;
    functionalSection = module.functionalSection.trim();
    componentGroup = module.componentGroup.trim();
    targetRefs = List<String>.from(module.targetRefs);
    deviceTagRefs = List<String>.from(module.deviceTagRefs);
    safetyClasses = List<String>.from(module.safetyClasses);
    requiredForClosure = module.requiredForClosure;
    updatedByUid = actor.uid;
    updatedByName = actor.name;
    updatedAt = now ?? DateTime.now();
    version += 1;
  }

  void retire({required AppUser actor, required String reason, DateTime? now}) {
    if (!isActive) {
      throw StateError('Only active registry families can be retired.');
    }
    status = ModuleRegistryFamilyStatus.retired;
    retiredByUid = actor.uid;
    retiredByName = actor.name;
    retiredAt = now ?? DateTime.now();
    retireReason = reason.trim();
    updatedByUid = actor.uid;
    updatedByName = actor.name;
    updatedAt = retiredAt;
    version += 1;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'registryModuleId': registryModuleId,
    'moduleCode': moduleCode,
    'canonicalTitle': canonicalTitle,
    'status': status.name,
    'discipline': discipline.name,
    'ownerDisciplines': ownerDisciplines,
    'assetType': assetType.name,
    'functionalSection': functionalSection,
    'componentGroup': componentGroup,
    'targetRefs': targetRefs,
    'deviceTagRefs': deviceTagRefs,
    'safetyClasses': safetyClasses,
    'requiredForClosure': requiredForClosure,
    'latestPublishedRevisionNumber': latestPublishedRevisionNumber,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'createdAt': createdAt?.toIso8601String(),
    'updatedByUid': updatedByUid,
    'updatedByName': updatedByName,
    'updatedAt': updatedAt?.toIso8601String(),
    'retiredByUid': retiredByUid,
    'retiredByName': retiredByName,
    'retiredAt': retiredAt?.toIso8601String(),
    'retireReason': retireReason,
    'version': version,
    'schemaVersion': schemaVersion,
    'isDeleted': isDeleted,
  };
}

class ModuleRegistryRevision {
  ModuleRegistryRevision({
    required this.registryModuleId,
    required this.revisionId,
    required this.revisionNumber,
    required this.revisionStatus,
    required this.moduleSnapshotJson,
    required this.fieldDefinitionsJson,
    required this.checklistJson,
    required this.contentHash,
    required this.lineageJson,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedByUid,
    this.updatedByName,
    this.updatedAt,
    this.publishedByUid,
    this.publishedByName,
    this.publishedAt,
    this.retiredByUid,
    this.retiredByName,
    this.retiredAt,
    this.retireReason,
    this.version = 1,
    this.schemaVersion = 1,
    this.isDeleted = false,
  });

  final String registryModuleId;
  final String revisionId;
  int revisionNumber;
  ModuleRegistryRevisionStatus revisionStatus;
  String moduleSnapshotJson;
  String fieldDefinitionsJson;
  String checklistJson;
  String contentHash;
  String lineageJson;
  String? createdByUid;
  String? createdByName;
  DateTime? createdAt;
  String? updatedByUid;
  String? updatedByName;
  DateTime? updatedAt;
  String? publishedByUid;
  String? publishedByName;
  DateTime? publishedAt;
  String? retiredByUid;
  String? retiredByName;
  DateTime? retiredAt;
  String? retireReason;
  int version;
  int schemaVersion;
  bool isDeleted;

  bool get isDraft => revisionStatus == ModuleRegistryRevisionStatus.draft;
  bool get isPublished =>
      revisionStatus == ModuleRegistryRevisionStatus.published;
  bool get isRetired => revisionStatus == ModuleRegistryRevisionStatus.retired;

  factory ModuleRegistryRevision.draftFromModule({
    required String registryModuleId,
    required String revisionId,
    required ComposerModuleDraft module,
    required AppUser actor,
    required Map<String, dynamic> lineage,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final snapshot = moduleRegistrySnapshotFromDraft(module);
    return ModuleRegistryRevision(
      registryModuleId: registryModuleId,
      revisionId: revisionId,
      revisionNumber: 0,
      revisionStatus: ModuleRegistryRevisionStatus.draft,
      moduleSnapshotJson: snapshot.moduleSnapshotJson,
      fieldDefinitionsJson: snapshot.fieldDefinitionsJson,
      checklistJson: snapshot.checklistJson,
      contentHash: snapshot.contentHash,
      lineageJson: _prettyJson.convert(lineage),
      createdByUid: actor.uid,
      createdByName: actor.name,
      createdAt: timestamp,
      updatedByUid: actor.uid,
      updatedByName: actor.name,
      updatedAt: timestamp,
    );
  }

  factory ModuleRegistryRevision.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    return ModuleRegistryRevision(
      registryModuleId: _cleanRequiredText(map['registryModuleId'], ''),
      revisionId: _cleanRequiredText(map['revisionId'], docId),
      revisionNumber:
          map['revisionNumber'] is int ? map['revisionNumber'] as int : 0,
      revisionStatus: _enumByNameOr(
        ModuleRegistryRevisionStatus.values,
        map['revisionStatus'],
        ModuleRegistryRevisionStatus.draft,
      ),
      moduleSnapshotJson: _cleanRequiredText(map['moduleSnapshotJson'], '{}'),
      fieldDefinitionsJson: _cleanRequiredText(
        map['fieldDefinitionsJson'],
        '[]',
      ),
      checklistJson: _cleanRequiredText(map['checklistJson'], '[]'),
      contentHash: _cleanRequiredText(map['contentHash'], ''),
      lineageJson: _cleanRequiredText(map['lineageJson'], '{}'),
      createdByUid: _cleanOptionalText(map['createdByUid']),
      createdByName: _cleanOptionalText(map['createdByName']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedByUid: _cleanOptionalText(map['updatedByUid']),
      updatedByName: _cleanOptionalText(map['updatedByName']),
      updatedAt: _parseTimestamp(map['updatedAt']),
      publishedByUid: _cleanOptionalText(map['publishedByUid']),
      publishedByName: _cleanOptionalText(map['publishedByName']),
      publishedAt: _parseTimestamp(map['publishedAt']),
      retiredByUid: _cleanOptionalText(map['retiredByUid']),
      retiredByName: _cleanOptionalText(map['retiredByName']),
      retiredAt: _parseTimestamp(map['retiredAt']),
      retireReason: _cleanOptionalText(map['retireReason']),
      version: map['version'] is int ? map['version'] as int : 1,
      schemaVersion:
          map['schemaVersion'] is int ? map['schemaVersion'] as int : 1,
      isDeleted: map['isDeleted'] == true,
    );
  }

  void refreshDraftFromModule({
    required ComposerModuleDraft module,
    required AppUser actor,
    required Map<String, dynamic> lineage,
  }) {
    if (!isDraft) {
      throw StateError('Only draft registry revisions are editable.');
    }
    final snapshot = moduleRegistrySnapshotFromDraft(module);
    moduleSnapshotJson = snapshot.moduleSnapshotJson;
    fieldDefinitionsJson = snapshot.fieldDefinitionsJson;
    checklistJson = snapshot.checklistJson;
    contentHash = snapshot.contentHash;
    lineageJson = _prettyJson.convert(lineage);
    updatedByUid = actor.uid;
    updatedByName = actor.name;
    updatedAt = DateTime.now();
    version += 1;
  }

  void publish({
    required AppUser actor,
    required int revisionNumber,
    DateTime? now,
  }) {
    if (!isDraft) {
      throw StateError('Only draft registry revisions can be published.');
    }
    _assertPublishableSnapshotIntegrity();
    revisionStatus = ModuleRegistryRevisionStatus.published;
    this.revisionNumber = revisionNumber;
    publishedByUid = actor.uid;
    publishedByName = actor.name;
    publishedAt = now ?? DateTime.now();
    updatedByUid = actor.uid;
    updatedByName = actor.name;
    updatedAt = publishedAt;
    version += 1;
  }

  void retire({required AppUser actor, required String reason, DateTime? now}) {
    if (!isPublished) {
      throw StateError('Only published registry revisions can be retired.');
    }
    revisionStatus = ModuleRegistryRevisionStatus.retired;
    retiredByUid = actor.uid;
    retiredByName = actor.name;
    retiredAt = now ?? DateTime.now();
    retireReason = reason.trim();
    updatedByUid = actor.uid;
    updatedByName = actor.name;
    updatedAt = retiredAt;
    version += 1;
  }

  void _assertPublishableSnapshotIntegrity() {
    try {
      validateModuleRegistrySnapshotPayload(
        moduleSnapshotJson: moduleSnapshotJson,
        fieldDefinitionsJson: fieldDefinitionsJson,
        checklistJson: checklistJson,
        expectedContentHash: contentHash,
      );
    } on FormatException catch (error) {
      throw StateError(
        'Registry revision payload is not publishable: ${error.message}',
      );
    }
  }

  ComposerModuleDraft toComposerModuleDraft() {
    final snapshot = _decodeJsonObject(moduleSnapshotJson);
    final code = _moduleCodeFromSnapshot(snapshot) ?? 'REGISTRY-MODULE';
    final fields = _decodeJsonObjectList(fieldDefinitionsJson)
        .where((field) => _moduleReferenceMatches(field, code))
        .map((field) => ComposerFieldDraft.fromMap(field))
        .toList(growable: false);
    final checklist = _decodeJsonObjectList(checklistJson)
        .where((item) => _moduleReferenceMatches(item, code))
        .map((item) => ComposerChecklistItemDraft.fromMap(item))
        .toList(growable: false);
    return ComposerModuleDraft.fromSnapshot(
      snapshot,
      displayOrder: 0,
      fields: fields,
      checklistItems: checklist,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'registryModuleId': registryModuleId,
    'revisionId': revisionId,
    'revisionNumber': revisionNumber,
    'revisionStatus': revisionStatus.name,
    'moduleSnapshotJson': moduleSnapshotJson,
    'fieldDefinitionsJson': fieldDefinitionsJson,
    'checklistJson': checklistJson,
    'contentHash': contentHash,
    'lineageJson': lineageJson,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'createdAt': createdAt?.toIso8601String(),
    'updatedByUid': updatedByUid,
    'updatedByName': updatedByName,
    'updatedAt': updatedAt?.toIso8601String(),
    'publishedByUid': publishedByUid,
    'publishedByName': publishedByName,
    'publishedAt': publishedAt?.toIso8601String(),
    'retiredByUid': retiredByUid,
    'retiredByName': retiredByName,
    'retiredAt': retiredAt?.toIso8601String(),
    'retireReason': retireReason,
    'version': version,
    'schemaVersion': schemaVersion,
    'isDeleted': isDeleted,
  };
}

class ModuleRegistryAudit {
  ModuleRegistryAudit({
    required this.firestoreId,
    required this.registryModuleId,
    this.revisionId,
    this.revisionNumber,
    required this.action,
    required this.performedByUid,
    this.performedByName,
    this.performedAt,
    this.reasonNotes,
    this.beforeHash,
    this.afterHash,
    this.lineageSummaryJson,
    this.version = 1,
    this.isDeleted = false,
  });

  final String firestoreId;
  final String registryModuleId;
  final String? revisionId;
  final int? revisionNumber;
  final ModuleRegistryAuditAction action;
  final String performedByUid;
  final String? performedByName;
  final DateTime? performedAt;
  final String? reasonNotes;
  final String? beforeHash;
  final String? afterHash;
  final String? lineageSummaryJson;
  final int version;
  final bool isDeleted;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'firestoreId': firestoreId,
    'registryModuleId': registryModuleId,
    'revisionId': revisionId,
    'revisionNumber': revisionNumber,
    'action': action.name,
    'performedByUid': performedByUid,
    'performedByName': performedByName,
    'performedAt': performedAt?.toIso8601String(),
    'reasonNotes': reasonNotes,
    'beforeHash': beforeHash,
    'afterHash': afterHash,
    'lineageSummaryJson': lineageSummaryJson,
    'version': version,
    'isDeleted': isDeleted,
  };
}

class PublishedRegistryModuleSource {
  PublishedRegistryModuleSource({required this.family, required this.revision})
    : module = revision.toComposerModuleDraft();

  final ModuleRegistryFamily? family;
  final ModuleRegistryRevision revision;
  final ComposerModuleDraft module;

  String get sourceLabel {
    final familyCode = family?.moduleCode.trim();
    final code =
        familyCode?.isNotEmpty == true ? familyCode! : module.moduleCode;
    return '$code · registry rev ${revision.revisionNumber}';
  }
}

ComposerModuleDraft cloneRegistryModuleIntoDraft({
  required PublishedRegistryModuleSource source,
  required Iterable<ComposerModuleDraft> existingModules,
  DateTime? now,
  bool sourceWasCached = false,
}) {
  final copy = duplicateComposerModule(
    source: source.module,
    existingModules: existingModules,
    now: now,
  );
  copy.metadata = <String, dynamic>{
    ...cloneComposerMetadata(copy.metadata),
    'source':
        sourceWasCached
            ? 'cachedPublishedRegistryRevision'
            : 'publishedRegistryRevision',
    'sourceRegistryModuleId': source.revision.registryModuleId,
    'sourceRegistryRevisionId': source.revision.revisionId,
    'sourceRegistryRevisionNumber': source.revision.revisionNumber,
    'sourceRegistryContentHash': source.revision.contentHash,
    'sourceModuleCode': source.module.moduleCode,
  };
  copy.authoringNotes = _appendLineageNote(
    copy.authoringNotes,
    'Cloned from governed registry ${source.sourceLabel}. Review before publish.',
  );
  return copy;
}

String _appendLineageNote(String existing, String note) {
  final trimmed = existing.trim();
  if (trimmed.isEmpty) {
    return note;
  }
  if (trimmed.contains(note)) {
    return trimmed;
  }
  return '$trimmed\n$note';
}
