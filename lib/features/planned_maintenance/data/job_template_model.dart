// FILE: lib/features/planned_maintenance/data/job_template_model.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:isar/isar.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../models/component_action_model.dart';

part 'job_template_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

/// Tolerant timestamp parser for Firestore-shaped maps. Accepts ISO-8601
/// strings (the format we write), Firestore Timestamps (written by the
/// Firebase console, Cloud Functions, or serverTimestamp()), and DateTime
/// instances (defensive). Returns null for anything else.
DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);

  // Defensive fallback for Firestore-like timestamp objects that expose
  // toDate() but are not statically typed as Timestamp.
  try {
    final dynamic maybeTimestamp = value;
    final converted = maybeTimestamp.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // Fall through to null.
  }

  return null;
}

T _enumByNameOr<T extends Enum>(
    List<T> values,
    dynamic value,
    T fallback,
    ) {
  if (value is! String) return fallback;
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String>? _cleanOptionalStringList(dynamic value) {
  if (value == null) return null;
  if (value is! List) return null;
  final cleaned = value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return cleaned.isEmpty ? null : cleaned;
}

// ─────────────────────────────────────────────────────────────
// FIELD TYPES
// ─────────────────────────────────────────────────────────────

enum FieldType {
  text,
  longText,
  number,
  yesNo,
  checkbox,
  dropdown,
  multiSelect,
  dateTime,
  sectionHeader,
  instruction,
}

// ─────────────────────────────────────────────────────────────
// TEMPLATE FIELD
// ─────────────────────────────────────────────────────────────

class TemplateField {
  late String key;
  late String label;
  late FieldType type;

  bool isRequired = false;

  String? unit;
  List<String>? options;

  int version = 1;

  Map<String, dynamic>? validation;
  String? validationJson;
  String? instructionText;
  int order = 0;
  Map<String, dynamic>? meta;

  TemplateField({
    String? key,
    String? label,
    FieldType? type,
    this.isRequired = false,
    this.unit,
    this.options,
    this.version = 1,
    this.validation,
    this.validationJson,
    this.instructionText,
    this.order = 0,
    this.meta,
  }) {
    this.key = key ?? '';
    this.label = label ?? '';
    this.type = type ?? FieldType.text;
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'type': type.name,
    'isRequired': isRequired,
    'unit': unit,
    'options': options,
    'version': version,
    'validationJson': validationJson ?? (validation != null ? jsonEncode(validation) : null),
    'instructionText': instructionText,
    'order': order,
    'meta': meta,
  };

  static TemplateField fromMap(Map<String, dynamic> map) {
    final rawValidation = map['validationJson'];
    Map<String, dynamic>? parsedValidation;
    if (rawValidation != null) {
      try {
        parsedValidation = jsonDecode(rawValidation);
      } catch (_) {}
    }
    return TemplateField()
      ..key = map['key'] ?? ''
      ..label = map['label'] ?? ''
      ..type = _enumByNameOr(FieldType.values, map['type'], FieldType.text)
      ..isRequired = map['isRequired'] ?? false
      ..unit = map['unit']
      ..options = map['options'] != null ? List<String>.from(map['options']) : null
      ..version = map['version'] ?? 1
      ..validationJson = rawValidation
      ..validation = parsedValidation
      ..instructionText = map['instructionText']
      ..order = map['order'] ?? 0
      ..meta = map['meta'] != null ? Map<String, dynamic>.from(map['meta']) : null;
  }
}

// ─────────────────────────────────────────────────────────────
// FIELD RESPONSE
// ─────────────────────────────────────────────────────────────

class FieldResponse {
  final String key;
  final String fieldLabel;
  final FieldType fieldType;
  final dynamic value;

  FieldResponse({
    required this.key,
    required this.fieldLabel,
    required this.fieldType,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
    'key': key,
    'fieldLabel': fieldLabel,
    'fieldType': fieldType.name,
    'value': value,
  };

  static FieldResponse fromMap(Map<String, dynamic> map) => FieldResponse(
    key: map['key'] ?? '',
    fieldLabel: map['fieldLabel'] ?? '',
    fieldType: _enumByNameOr(FieldType.values, map['fieldType'], FieldType.text),
    value: map['value'],
  );
}

// ─────────────────────────────────────────────────────────────
// JOB TEMPLATE
// ─────────────────────────────────────────────────────────────

@Collection()
class JobTemplate {
  // 🔥 Explicit empty constructor for Isar
  JobTemplate();

  Id id = Isar.autoIncrement;

  @Index()
  String? firestoreId;

  @Index()
  bool isSynced = false;

  // ── Tombstone fields ───────────────────────────────────────
  bool isDeleted = false;
  DateTime? deletedAt;

  // 🔥 AUDIT FIELDS (who deleted, why)
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  int version = 1;

  late String jobName;
  String? description;

  @Enumerated(EnumType.name)
  late AssetType applicableAssetType;

  List<String> assignedAgencies = [];

  String? component;
  String? subsystem;
  List<String>? hierarchyPath;

  String fieldsJson = '[]';

  @ignore
  List<TemplateField> fields = [];

  String? createdByUid;
  String? createdByName;

  bool isActive = true;
  bool isDeprecated = false;

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  String? metadataJson;

  @ignore
  List<TemplateField> get parsedFields {
    if (fields.isNotEmpty) return fields;
    try {
      final decoded = jsonDecode(fieldsJson);
      if (decoded is List) {
        fields = decoded
            .whereType<Map>()
            .map((e) => TemplateField.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        fields = [];
      }
    } catch (_) {
      fields = [];
    }
    return fields;
  }

  void setFields(List<TemplateField> newFields) {
    fields = newFields;
    for (int i = 0; i < fields.length; i++) {
      fields[i].order = i;
    }
    fieldsJson = jsonEncode(newFields.map((f) => f.toMap()).toList());
  }

  bool get hasComponentScope =>
      _cleanOptionalText(component) != null ||
          _cleanOptionalStringList(hierarchyPath) != null;

  String get debugLabel => '$jobName (${applicableAssetType.name})';

  // ─── AUDIT SNAPSHOT ──────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'jobName': jobName,
    'applicableAssetType': applicableAssetType.name,
    'isActive': isActive,
    'isDeprecated': isDeprecated,
    'isDeleted': isDeleted,
  };

  // 🔥 toMap for Firestore serialization.
  // Writes BOTH 'fields' (structured array, queryable, console-readable) and
  // 'fieldsJson' (legacy string blob). fromMap reads either; this preserves
  // compatibility with both v1 clients and historical v2 documents.
  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> fieldsArray =
    parsedFields.map((f) => f.toMap()).toList();
    return {
      'firestoreId': firestoreId,
      'jobName': jobName,
      'description': _cleanOptionalText(description),
      'applicableAssetType': applicableAssetType.name,
      'assignedAgencies': assignedAgencies,
      'component': _cleanOptionalText(component),
      'subsystem': _cleanOptionalText(subsystem),
      'hierarchyPath': _cleanOptionalStringList(hierarchyPath),
      'fields': fieldsArray,
      'fieldsJson': jsonEncode(fieldsArray),
      'createdByUid': _cleanOptionalText(createdByUid),
      'createdByName': _cleanOptionalText(createdByName),
      'isActive': isActive,
      'isDeprecated': isDeprecated,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': _cleanOptionalText(deletedByUid),
      'deletedByName': _cleanOptionalText(deletedByName),
      'deleteReason': _cleanOptionalText(deleteReason),
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadataJson': _cleanOptionalText(metadataJson),
    };
  }

  // 🔥 fromMap factory.
  // Reads 'fields' (structured) preferentially, falls back to 'fieldsJson'
  // (legacy). Tolerates both ISO-8601 strings and Firestore Timestamp instances
  // for all date fields.
  factory JobTemplate.fromMap(Map<String, dynamic> map, String documentId) {
    final template = JobTemplate()
      ..firestoreId = documentId
      ..jobName = map['jobName'] ?? ''
      ..description = _cleanOptionalText(map['description'])
      ..applicableAssetType = _enumByNameOr(AssetType.values, map['applicableAssetType'], AssetType.base)
      ..assignedAgencies = List<String>.from(map['assignedAgencies'] ?? [])
      ..component = _cleanOptionalText(map['component'])
      ..subsystem = _cleanOptionalText(map['subsystem'])
      ..hierarchyPath = _cleanOptionalStringList(map['hierarchyPath'])
      ..createdByUid = _cleanOptionalText(map['createdByUid'])
      ..createdByName = _cleanOptionalText(map['createdByName'])
      ..isActive = map['isActive'] ?? true
      ..isDeprecated = map['isDeprecated'] ?? false
      ..isDeleted = map['isDeleted'] ?? false
      ..deletedAt = _parseTimestamp(map['deletedAt'])
      ..deletedByUid = _cleanOptionalText(map['deletedByUid'])
      ..deletedByName = _cleanOptionalText(map['deletedByName'])
      ..deleteReason = _cleanOptionalText(map['deleteReason'])
      ..version = map['version'] ?? 1
      ..createdAt = _parseTimestamp(map['createdAt']) ?? DateTime.now()
      ..updatedAt = _parseTimestamp(map['updatedAt']) ??
          _parseTimestamp(map['createdAt']) ??
          DateTime.now()
      ..metadataJson = _cleanOptionalText(map['metadataJson']);

    // Prefer structured 'fields' array if present; else fall back to
    // 'fieldsJson' string. setFields() (re)builds fieldsJson from fields,
    // so the in-memory representation is always coherent.
    final rawFields = map['fields'];
    if (rawFields is List) {
      try {
        template.setFields(
          rawFields
              .whereType<Map>()
              .map((e) => TemplateField.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
        );
      } catch (_) {
        template.fieldsJson = (map['fieldsJson'] is String) ? map['fieldsJson'] : '[]';
      }
    } else {
      template.fieldsJson = (map['fieldsJson'] is String) ? map['fieldsJson'] : '[]';
    }

    return template;
  }
}

// ─────────────────────────────────────────────────────────────
// JOB EXECUTION
// ─────────────────────────────────────────────────────────────

@Collection()
class JobExecution {
  // 🔥 Explicit empty constructor for Isar
  JobExecution();

  Id id = Isar.autoIncrement;

  @Index()
  String? firestoreId;

  @Index()
  late String templateFirestoreId;

  String? templateName;

  // ── Governance source identity ─────────────────────────────
  // Populated when the job is assigned from a published TemplateVersion.
  // Legacy JobTemplate assignments keep these fields null and continue to use
  // templateFirestoreId/templateName exactly as before.
  @Index()
  String? templatePackageId;

  @Index()
  String? templateVersionId;

  int? templateVersionNumber;
  String? templateVersionLabel;
  String? templateContentHash;
  String? templatePackageCode;

  @ignore
  bool get isGovernedTemplateAssignment =>
      templateVersionId != null && templateVersionId!.trim().isNotEmpty;

  @Enumerated(EnumType.name)
  late AssetType assetType;

  @Index()
  late int assetNumber;

  @Index()
  bool isCompleted = false;

  /// Server-owned terminal cancellation state. Cancelled executions remain
  /// visible for history but are excluded from open-work views.
  @Index()
  bool isCancelled = false;
  DateTime? cancelledAt;
  String? cancelledByUid;
  String? cancelledByName;
  String? cancellationReason;

  String? assignedByUid;
  String? assignedByName;

  List<String> assignedAgencies = [];

  // ── Maintenance workflow control-plane identity ──────────
  // Zero means legacy/no proven workflow aggregate. Governed creation paths
  // set this server-owned field to 1 only when the aggregate is created.
  int workflowSchemaVersion = 0;
  int laneSetVersion = 0;
  DateTime? laneSetFinalizedAt;
  String? laneSetFinalizedByUid;
  String? laneSetFinalizedByName;
  @Index()
  bool laneMappingReview = false;
  @Index()
  String? parentExecutionFirestoreId;
  String? spawnedRedExecutionFirestoreId;
  String? redAnswerJson;

  @ignore
  RoutedTo get assignedAgency => assignedAgencies.isNotEmpty
      ? _enumByNameOr(RoutedTo.values, assignedAgencies.first, RoutedTo.mechanical)
      : RoutedTo.mechanical;

  set assignedAgency(RoutedTo value) {
    assignedAgencies = [value.name];
  }

  String? completedByUid;
  String? completedByName;
  String? remarks;

  List<String> teamsInvolved = [];

  int? chargeNoAtEvent;

  String responsesJson = '[]';

  @ignore
  List<FieldResponse> get responses {
    try {
      final list = jsonDecode(responsesJson) as List;
      return list
          .map((e) => FieldResponse.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  set responses(List<FieldResponse> value) {
    responsesJson = jsonEncode(value.map((r) => r.toMap()).toList());
  }

  dynamic getResponse(String key) {
    try {
      return responses.firstWhere((r) => r.key == key).value;
    } catch (_) {
      return null;
    }
  }

  String actionsJson = '[]';

  @ignore
  List<ComponentAction> get actions => ComponentAction.decode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local job execution $id'
            : 'job execution $firestoreId',
  );

  @ignore
  ComponentActionReadResult get actionsReadResult => ComponentAction.tryDecode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local job execution $id'
            : 'job execution $firestoreId',
  );

  set actions(List<ComponentAction> value) {
    actionsJson = ComponentAction.encode(value);
  }

  @ignore
  bool get hasActions => actions.isNotEmpty;

  int version = 1;
  String? metadataJson;

  // ── Tombstone fields ───────────────────────────────────────
  bool isDeleted = false;
  DateTime? deletedAt;

  // 🔥 AUDIT FIELDS (who deleted, why)
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  @Index()
  late DateTime createdAt;

  DateTime? completedAt;

  late DateTime updatedAt;

  @Index()
  bool isSynced = false;

  // ─── AUDIT SNAPSHOT ──────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'templateName': templateName,
    'templatePackageId': templatePackageId,
    'templateVersionId': templateVersionId,
    'templateVersionNumber': templateVersionNumber,
    'templateContentHash': templateContentHash,
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'isCompleted': isCompleted,
    'isCancelled': isCancelled,
    'workflowSchemaVersion': workflowSchemaVersion,
    'laneSetVersion': laneSetVersion,
    'laneMappingReview': laneMappingReview,
    'parentExecutionFirestoreId': parentExecutionFirestoreId,
    'spawnedRedExecutionFirestoreId': spawnedRedExecutionFirestoreId,
    'isDeleted': isDeleted,
  };

  // 🔥 toMap for Firestore serialization.
  // responsesJson is the canonical Firestore payload. Do not also write the
  // legacy structured 'responses' array.
  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> responsesArray =
    responses.map((r) => r.toMap()).toList();
    return {
      'firestoreId': firestoreId,
      'templateFirestoreId': templateFirestoreId,
      'templateName': templateName,
      'templatePackageId': _cleanOptionalText(templatePackageId),
      'templateVersionId': _cleanOptionalText(templateVersionId),
      'templateVersionNumber': templateVersionNumber,
      'templateVersionLabel': _cleanOptionalText(templateVersionLabel),
      'templateContentHash': _cleanOptionalText(templateContentHash),
      'templatePackageCode': _cleanOptionalText(templatePackageCode),
      'assetType': assetType.name,
      'assetNumber': assetNumber,
      'isCompleted': isCompleted,
      'isCancelled': isCancelled,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'cancelledByUid': cancelledByUid,
      'cancelledByName': cancelledByName,
      'cancellationReason': cancellationReason,
      'assignedByUid': assignedByUid,
      'assignedByName': assignedByName,
      'assignedAgencies': assignedAgencies,
      'workflowSchemaVersion': workflowSchemaVersion,
      'laneSetVersion': laneSetVersion,
      'laneSetFinalizedAt': laneSetFinalizedAt?.toIso8601String(),
      'laneSetFinalizedByUid': laneSetFinalizedByUid,
      'laneSetFinalizedByName': laneSetFinalizedByName,
      'laneMappingReview': laneMappingReview,
      'parentExecutionFirestoreId': parentExecutionFirestoreId,
      'spawnedRedExecutionFirestoreId': spawnedRedExecutionFirestoreId,
      'redAnswerJson': redAnswerJson,
      'completedByUid': completedByUid,
      'completedByName': completedByName,
      'remarks': remarks,
      'teamsInvolved': teamsInvolved,
      'chargeNoAtEvent': chargeNoAtEvent,
      'responsesJson': jsonEncode(responsesArray),
      'actionsJson': actionsJson,
      'version': version,
      'metadataJson': metadataJson,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deleteReason': deleteReason,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Client-originated Firestore shape. Server-owned workflow fields are
  /// deliberately omitted so merge writes cannot overwrite lane, RED or
  /// completion authority established by Cloud Functions.
  Map<String, dynamic> toClientWritableMap() {
    final map = Map<String, dynamic>.from(toMap());
    map.remove('laneSetVersion');
    map.remove('laneSetFinalizedAt');
    map.remove('laneSetFinalizedByUid');
    map.remove('laneSetFinalizedByName');
    map.remove('laneMappingReview');
    map.remove('parentExecutionFirestoreId');
    map.remove('spawnedRedExecutionFirestoreId');
    map.remove('redAnswerJson');
    map.remove('workflowSchemaVersion');
    map.remove('isCancelled');
    map.remove('cancelledAt');
    map.remove('cancelledByUid');
    map.remove('cancelledByName');
    map.remove('cancellationReason');
    return map;
  }

  // 🔥 fromMap factory.
  // Reads 'responses' (structured) preferentially, falls back to
  // 'responsesJson' (legacy). Tolerates both ISO-8601 strings and Firestore
  // Timestamp instances for all date fields.
  factory JobExecution.fromMap(Map<String, dynamic> map, String documentId) {
    final execution = JobExecution()
      ..firestoreId = documentId
      ..templateFirestoreId = map['templateFirestoreId'] ?? ''
      ..templateName = _cleanOptionalText(map['templateName'])
      ..templatePackageId = _cleanOptionalText(map['templatePackageId'])
      ..templateVersionId = _cleanOptionalText(map['templateVersionId'])
      ..templateVersionNumber = map['templateVersionNumber'] is int
          ? map['templateVersionNumber'] as int
          : null
      ..templateVersionLabel = _cleanOptionalText(map['templateVersionLabel'])
      ..templateContentHash = _cleanOptionalText(map['templateContentHash'])
      ..templatePackageCode = _cleanOptionalText(map['templatePackageCode'])
      ..assetType = _enumByNameOr(AssetType.values, map['assetType'], AssetType.base)
      ..assetNumber = map['assetNumber'] ?? 0
      ..isCompleted = map['isCompleted'] ?? false
      ..isCancelled = map['isCancelled'] == true
      ..cancelledAt = _parseTimestamp(map['cancelledAt'])
      ..cancelledByUid = _cleanOptionalText(map['cancelledByUid'])
      ..cancelledByName = _cleanOptionalText(map['cancelledByName'])
      ..cancellationReason = _cleanOptionalText(map['cancellationReason'])
      ..assignedByUid = map['assignedByUid']
      ..assignedByName = map['assignedByName']
      ..assignedAgencies = List<String>.from(map['assignedAgencies'] ?? [])
      ..workflowSchemaVersion = map['workflowSchemaVersion'] is int
          ? map['workflowSchemaVersion'] as int
          : 0
      ..laneSetVersion = map['laneSetVersion'] is int
          ? map['laneSetVersion'] as int
          : 0
      ..laneSetFinalizedAt = _parseTimestamp(map['laneSetFinalizedAt'])
      ..laneSetFinalizedByUid = _cleanOptionalText(map['laneSetFinalizedByUid'])
      ..laneSetFinalizedByName = _cleanOptionalText(map['laneSetFinalizedByName'])
      ..laneMappingReview = map['laneMappingReview'] == true
      ..parentExecutionFirestoreId = _cleanOptionalText(map['parentExecutionFirestoreId'])
      ..spawnedRedExecutionFirestoreId = _cleanOptionalText(map['spawnedRedExecutionFirestoreId'])
      ..redAnswerJson = _cleanOptionalText(map['redAnswerJson'])
      ..completedByUid = map['completedByUid']
      ..completedByName = map['completedByName']
      ..remarks = map['remarks']
      ..teamsInvolved = List<String>.from(map['teamsInvolved'] ?? [])
      ..chargeNoAtEvent = map['chargeNoAtEvent']
      ..actionsJson = ComponentAction.readEncodedPayload(
        map['actionsJson'],
        field: 'actionsJson',
        source: 'job execution $documentId',
      )
      ..version = map['version'] ?? 1
      ..metadataJson = map['metadataJson']
      ..isDeleted = map['isDeleted'] ?? false
      ..deletedAt = _parseTimestamp(map['deletedAt'])
      ..deletedByUid = map['deletedByUid']
      ..deletedByName = map['deletedByName']
      ..deleteReason = map['deleteReason']
      ..createdAt = _parseTimestamp(map['createdAt']) ?? DateTime.now()
      ..completedAt = _parseTimestamp(map['completedAt'])
      ..updatedAt = _parseTimestamp(map['updatedAt']) ??
          _parseTimestamp(map['createdAt']) ??
          DateTime.now();

    // responsesJson is canonical. Only fall back to the legacy structured
    // 'responses' array for old records that do not contain responsesJson.
    final rawCanonicalResponsesJson = map['responsesJson'];
    if (rawCanonicalResponsesJson is String &&
        rawCanonicalResponsesJson.trim().isNotEmpty) {
      execution.responsesJson = rawCanonicalResponsesJson;
    } else {
      final rawResponses = map['responses'];
      if (rawResponses is List) {
        try {
          execution.responses = rawResponses
              .whereType<Map>()
              .map((e) => FieldResponse.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        } catch (_) {
          execution.responsesJson = '[]';
        }
      } else {
        execution.responsesJson = '[]';
      }
    }

    return execution;
  }
}
