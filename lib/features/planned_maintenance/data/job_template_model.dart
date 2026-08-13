// FILE: lib/features/planned_maintenance/data/job_template_model.dart

import 'dart:convert';
import 'package:isar/isar.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/utils/asset_validator.dart';
import '../models/component_action_model.dart';
import 'remote_job_timestamps.dart';

part 'job_template_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
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
  final cleaned =
      value
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

const _fieldKeyAliases = <String>['key', 'fieldKey', 'fieldId', 'id', 'name'];
const _responseKeyAliases = <String>[
  'key',
  'fieldId',
  'fieldKey',
  'id',
  'name',
];

String _normalisePayloadKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

String _readAliasedRequiredText(
  Map<String, dynamic> map,
  List<String> aliases, {
  required String field,
  String? source,
}) {
  for (final alias in aliases) {
    final value = map[alias];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'required non-empty string (${aliases.join('/')})',
  );
}

String? _readAliasedOptionalText(
  Map<String, dynamic> map,
  List<String> aliases, {
  required String field,
  String? source,
}) {
  for (final alias in aliases) {
    if (!map.containsKey(alias) || map[alias] == null) continue;
    return readOptionalPersistedString(
      map[alias],
      field: '$field.$alias',
      source: source,
    );
  }
  return null;
}

FieldType _readPersistedFieldType(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return FieldType.text;
  if (value is! String || value.trim().isEmpty) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a supported field type',
    );
  }

  switch (_normalisePayloadKey(value)) {
    case 'text':
    case 'string':
    case 'plaintext':
      return FieldType.text;
    case 'longtext':
    case 'textarea':
      return FieldType.longText;
    case 'number':
    case 'numeric':
    case 'numericwithunit':
      return FieldType.number;
    case 'boolean':
    case 'yesno':
    case 'passfail':
      return FieldType.yesNo;
    case 'checkbox':
      return FieldType.checkbox;
    case 'enum':
    case 'dropdown':
    case 'devicetagpicklist':
    case 'procedureref':
    case 'targetrule':
      return FieldType.dropdown;
    case 'multiselect':
    case 'multitag':
      return FieldType.multiSelect;
    case 'datetime':
    case 'date':
      return FieldType.dateTime;
    case 'sectionheader':
      return FieldType.sectionHeader;
    case 'instruction':
    case 'safetygate':
    case 'safetyconfirmation':
      return FieldType.instruction;
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown field type "$value"',
  );
}

void _validateFieldDefinition(
  Map<String, dynamic> map, {
  required String field,
  String? source,
}) {
  _readAliasedRequiredText(
    map,
    _fieldKeyAliases,
    field: '$field.key',
    source: source,
  );
  for (final key in const ['label', 'title']) {
    if (map.containsKey(key)) {
      readOptionalPersistedString(
        map[key],
        field: '$field.$key',
        source: source,
      );
    }
  }
  for (final key in const ['type', 'fieldType']) {
    if (map[key] != null) {
      _readPersistedFieldType(map[key], field: '$field.$key', source: source);
    }
  }
  for (final key in const ['required', 'isRequired']) {
    if (map[key] != null && map[key] is! bool) {
      throw PersistedDataFormatException(
        field: '$field.$key',
        source: source,
        detail: 'expected a boolean or null',
      );
    }
  }
  if (map['required'] is bool &&
      map['isRequired'] is bool &&
      map['required'] != map['isRequired']) {
    throw PersistedDataFormatException(
      field: '$field.required',
      source: source,
      detail: 'conflicts with isRequired',
    );
  }
  for (final key in const ['unit', 'instructionText']) {
    if (map.containsKey(key)) {
      readOptionalPersistedString(
        map[key],
        field: '$field.$key',
        source: source,
      );
    }
  }
  if (map.containsKey('options')) {
    readNullablePersistedStringList(
      map['options'],
      field: '$field.options',
      source: source,
    );
  }
  for (final key in const ['validation', 'meta']) {
    if (map.containsKey(key)) {
      readOptionalJsonObject(map[key], field: '$field.$key', source: source);
    }
  }
  if (map.containsKey('validationJson')) {
    readOptionalJsonObject(
      map['validationJson'],
      field: '$field.validationJson',
      source: source,
    );
  }
  if (map['order'] != null && map['order'] is! int) {
    throw PersistedDataFormatException(
      field: '$field.order',
      source: source,
      detail: 'expected an integer or null',
    );
  }
  if (map['version'] != null &&
      (map['version'] is! int || (map['version'] as int) < 1)) {
    throw PersistedDataFormatException(
      field: '$field.version',
      source: source,
      detail: 'expected an integer >= 1 or null',
    );
  }
}

class FieldDefinitionReadResult {
  final List<Map<String, dynamic>> entries;
  final FormatException? error;

  const FieldDefinitionReadResult._({
    required this.entries,
    required this.error,
  });

  bool get isValid => error == null;
}

class PersistedFieldDefinitionPayload {
  static List<Map<String, dynamic>> decode(
    String? jsonStr, {
    String? source,
    String field = 'fieldDefinitionsJson',
  }) {
    if (jsonStr == null) {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'required JSON array (Null)',
      );
    }
    final rows = readRequiredJsonObjectList(
      jsonStr,
      field: field,
      source: source,
    );
    final keys = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final entryField = '$field[$index]';
      _validateFieldDefinition(rows[index], field: entryField, source: source);
      final key = _readAliasedRequiredText(
        rows[index],
        _fieldKeyAliases,
        field: '$entryField.key',
        source: source,
      );
      if (!keys.add(_normalisePayloadKey(key))) {
        throw PersistedDataFormatException(
          field: '$entryField.key',
          source: source,
          detail: 'duplicate key $key',
        );
      }
    }
    return rows;
  }

  static FieldDefinitionReadResult tryDecode(
    String? jsonStr, {
    String? source,
    String field = 'fieldDefinitionsJson',
  }) {
    try {
      return FieldDefinitionReadResult._(
        entries: decode(jsonStr, source: source, field: field),
        error: null,
      );
    } on FormatException catch (error) {
      return FieldDefinitionReadResult._(
        entries: const <Map<String, dynamic>>[],
        error: error,
      );
    }
  }

  static String readEncodedPayload(
    dynamic value, {
    required String field,
    String? source,
    bool allowMissing = false,
  }) {
    if (value == null && allowMissing) return '[]';
    if (value is String) return value;
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a JSON string (${value.runtimeType})',
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TEMPLATE FIELD
// ─────────────────────────────────────────────────────────────

class TemplateFieldReadResult {
  final List<TemplateField> entries;
  final FormatException? error;

  const TemplateFieldReadResult._({required this.entries, required this.error});

  bool get isValid => error == null;
}

class TemplateField {
  static const _knownFields = <String>{
    'key',
    'fieldKey',
    'fieldId',
    'id',
    'name',
    'label',
    'title',
    'type',
    'fieldType',
    'required',
    'isRequired',
    'unit',
    'options',
    'version',
    'validation',
    'validationJson',
    'instructionText',
    'order',
    'meta',
  };

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
  Map<String, dynamic> extensions = <String, dynamic>{};

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
    Map<String, dynamic>? extensions,
  }) {
    this.key = key ?? '';
    this.label = label ?? '';
    this.type = type ?? FieldType.text;
    this.extensions = Map<String, dynamic>.from(
      extensions ?? const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() => {
    ...extensions,
    'key': key,
    'label': label,
    'type': type.name,
    'isRequired': isRequired,
    'unit': unit,
    'options': options,
    'version': version,
    'validationJson':
        validationJson ?? (validation != null ? jsonEncode(validation) : null),
    'instructionText': instructionText,
    'order': order,
    'meta': meta,
  };

  factory TemplateField.fromMap(Map<String, dynamic> map, {String? source}) {
    _validateFieldDefinition(map, field: 'field', source: source);
    final structuredValidation =
        map.containsKey('validation')
            ? readOptionalJsonObject(
              map['validation'],
              field: 'field.validation',
              source: source,
            )
            : null;
    final encodedValidation =
        map.containsKey('validationJson')
            ? readOptionalJsonObject(
              map['validationJson'],
              field: 'field.validationJson',
              source: source,
            )
            : null;
    final validation = structuredValidation ?? encodedValidation;
    final extensions = <String, dynamic>{
      for (final entry in map.entries)
        if (!_knownFields.contains(entry.key)) entry.key: entry.value,
    };
    return TemplateField(
      key: _readAliasedRequiredText(
        map,
        _fieldKeyAliases,
        field: 'field.key',
        source: source,
      ),
      label:
          _readAliasedOptionalText(
            map,
            const ['label', 'title'],
            field: 'field.label',
            source: source,
          ) ??
          _readAliasedRequiredText(
            map,
            _fieldKeyAliases,
            field: 'field.key',
            source: source,
          ),
      type: _readPersistedFieldType(
        map['type'] ?? map['fieldType'],
        field: 'field.type',
        source: source,
      ),
      isRequired:
          (map['isRequired'] as bool?) ?? (map['required'] as bool?) ?? false,
      unit: readOptionalPersistedString(
        map['unit'],
        field: 'field.unit',
        source: source,
      ),
      options: readNullablePersistedStringList(
        map['options'],
        field: 'field.options',
        source: source,
      ),
      version: map['version'] as int? ?? 1,
      validation: validation,
      validationJson: validation == null ? null : jsonEncode(validation),
      instructionText: readOptionalPersistedString(
        map['instructionText'],
        field: 'field.instructionText',
        source: source,
      ),
      order: map['order'] as int? ?? 0,
      meta:
          map.containsKey('meta')
              ? readOptionalJsonObject(
                map['meta'],
                field: 'field.meta',
                source: source,
              )
              : null,
      extensions: extensions,
    );
  }

  static List<TemplateField> decode(String? jsonStr, {String? source}) {
    final rows = PersistedFieldDefinitionPayload.decode(
      jsonStr,
      source: source,
      field: 'fieldsJson',
    );
    return <TemplateField>[
      for (var index = 0; index < rows.length; index++)
        TemplateField.fromMap(
          rows[index],
          source:
              source == null
                  ? 'fieldsJson[$index]'
                  : '$source fieldsJson[$index]',
        ),
    ];
  }

  static TemplateFieldReadResult tryDecode(String? jsonStr, {String? source}) {
    try {
      return TemplateFieldReadResult._(
        entries: decode(jsonStr, source: source),
        error: null,
      );
    } on FormatException catch (error) {
      return TemplateFieldReadResult._(
        entries: const <TemplateField>[],
        error: error,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// FIELD RESPONSE
// ─────────────────────────────────────────────────────────────

class FieldResponseReadResult {
  final List<FieldResponse> entries;
  final FormatException? error;

  const FieldResponseReadResult._({required this.entries, required this.error});

  bool get isValid => error == null;
}

class FieldResponse {
  static const _knownFields = <String>{
    'key',
    'fieldId',
    'fieldKey',
    'id',
    'name',
    'fieldLabel',
    'label',
    'title',
    'fieldType',
    'type',
    'value',
    'answer',
  };

  final String key;
  final String fieldLabel;
  final FieldType fieldType;
  final dynamic value;
  final Map<String, dynamic> extensions;

  FieldResponse({
    required this.key,
    required this.fieldLabel,
    required this.fieldType,
    required this.value,
    Map<String, dynamic>? extensions,
  }) : extensions = Map<String, dynamic>.unmodifiable(
         extensions ?? const <String, dynamic>{},
       );

  Map<String, dynamic> toMap() => {
    ...extensions,
    'key': key,
    'fieldLabel': fieldLabel,
    'fieldType': fieldType.name,
    'value': value,
  };

  factory FieldResponse.fromMap(Map<String, dynamic> map, {String? source}) {
    final key = _readAliasedRequiredText(
      map,
      _responseKeyAliases,
      field: 'key',
      source: source,
    );
    if (!map.containsKey('value') && !map.containsKey('answer')) {
      throw PersistedDataFormatException(
        field: 'value',
        source: source,
        detail: 'required value/answer field',
      );
    }
    final value = map.containsKey('value') ? map['value'] : map['answer'];
    try {
      jsonEncode(value);
    } on JsonUnsupportedObjectError {
      throw PersistedDataFormatException(
        field: 'value',
        source: source,
        detail: 'value is not JSON serializable',
      );
    }
    final extensions = <String, dynamic>{
      for (final entry in map.entries)
        if (!_knownFields.contains(entry.key)) entry.key: entry.value,
    };
    return FieldResponse(
      key: key,
      fieldLabel:
          _readAliasedOptionalText(
            map,
            const ['fieldLabel', 'label', 'title'],
            field: 'fieldLabel',
            source: source,
          ) ??
          key,
      fieldType: _readPersistedFieldType(
        map['fieldType'] ?? map['type'],
        field: 'fieldType',
        source: source,
      ),
      value: value,
      extensions: extensions,
    );
  }

  static String encode(List<FieldResponse> responses) =>
      jsonEncode(responses.map((response) => response.toMap()).toList());

  static List<FieldResponse> decode(String? jsonStr, {String? source}) {
    if (jsonStr == null) {
      throw PersistedDataFormatException(
        field: 'responsesJson',
        source: source,
        detail: 'required JSON array (Null)',
      );
    }
    final rows = readRequiredJsonObjectList(
      jsonStr,
      field: 'responsesJson',
      source: source,
    );
    final keys = <String>{};
    return <FieldResponse>[
      for (var index = 0; index < rows.length; index++)
        _decodeRow(rows[index], index, keys, source),
    ];
  }

  static FieldResponse _decodeRow(
    Map<String, dynamic> row,
    int index,
    Set<String> keys,
    String? source,
  ) {
    final response = FieldResponse.fromMap(
      row,
      source:
          source == null
              ? 'responsesJson[$index]'
              : '$source responsesJson[$index]',
    );
    if (!keys.add(_normalisePayloadKey(response.key))) {
      throw PersistedDataFormatException(
        field: 'responsesJson[$index].key',
        source: source,
        detail: 'duplicate key ${response.key}',
      );
    }
    return response;
  }

  static FieldResponseReadResult tryDecode(String? jsonStr, {String? source}) {
    try {
      return FieldResponseReadResult._(
        entries: decode(jsonStr, source: source),
        error: null,
      );
    } on FormatException catch (error) {
      return FieldResponseReadResult._(
        entries: const <FieldResponse>[],
        error: error,
      );
    }
  }

  static String readEncodedPayload(
    dynamic value, {
    required String field,
    String? source,
    bool allowMissing = false,
  }) {
    if (value == null && allowMissing) return '[]';
    if (value is String) return value;
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a JSON string (${value.runtimeType})',
    );
  }

  static String encodeLegacyPayload(dynamic value, {String? source}) {
    if (value is! List) {
      throw PersistedDataFormatException(
        field: 'responses',
        source: source,
        detail: 'expected an array (${value.runtimeType})',
      );
    }
    final responses = <FieldResponse>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is! Map) {
        throw PersistedDataFormatException(
          field: 'responses[$index]',
          source: source,
          detail: 'expected an object (${entry.runtimeType})',
        );
      }
      responses.add(
        FieldResponse.fromMap(
          Map<String, dynamic>.from(entry),
          source: '$source responses[$index]',
        ),
      );
    }
    return encode(responses);
  }
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
  String? assetHierarchyRefJson;

  @ignore
  AssetHierarchyReference? get assetHierarchyReference =>
      assetHierarchyRefJson == null
          ? null
          : AssetHierarchyReference.decode(
              assetHierarchyRefJson!,
              source: _fieldSourceLabel,
            );

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
    fields = TemplateField.decode(fieldsJson, source: _fieldSourceLabel);
    return fields;
  }

  @ignore
  TemplateFieldReadResult get fieldsReadResult {
    if (fields.isNotEmpty) {
      return TemplateFieldReadResult._(entries: fields, error: null);
    }
    return TemplateField.tryDecode(fieldsJson, source: _fieldSourceLabel);
  }

  String get _fieldSourceLabel =>
      firestoreId == null
          ? 'local job template $id'
          : 'job template $firestoreId';

  void setFields(List<TemplateField> newFields) {
    for (int i = 0; i < newFields.length; i++) {
      newFields[i].order = i;
    }
    final encoded = jsonEncode(newFields.map((f) => f.toMap()).toList());
    TemplateField.decode(encoded, source: _fieldSourceLabel);
    fields = newFields;
    fieldsJson = encoded;
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
      'assetHierarchyRefJson': _cleanOptionalText(assetHierarchyRefJson),
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
    final source = 'job template $documentId';
    final timestamps = readRemoteJobTemplateTimestamps(map, source: source);
    if (map['isDeleted'] == true && timestamps.deletedAt == null) {
      requireRemoteTombstoneDeletedAt(
        timestamps.deletedAt,
        entityLabel: 'job template',
        firestoreId: documentId,
      );
    }
    final embeddedId = readRequiredPersistedString(
      map['firestoreId'],
      field: 'firestoreId',
      source: source,
    );
    if (embeddedId != documentId) {
      throw PersistedDataFormatException(
        field: 'firestoreId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final template =
        JobTemplate()
          ..firestoreId = embeddedId
          ..jobName = readRequiredPersistedString(
            map['jobName'],
            field: 'jobName',
            source: source,
          )
          ..description = readOptionalPersistedString(
            map['description'],
            field: 'description',
            source: source,
            emptyAsNull: false,
          )
          ..applicableAssetType = readRequiredPersistedEnum(
            AssetType.values,
            map['applicableAssetType'],
            field: 'applicableAssetType',
            source: source,
          )
          ..assignedAgencies = readOptionalPersistedStringList(
            map['assignedAgencies'],
            field: 'assignedAgencies',
            source: source,
          )
          ..component = readOptionalPersistedString(
            map['component'],
            field: 'component',
            source: source,
          )
          ..subsystem = readOptionalPersistedString(
            map['subsystem'],
            field: 'subsystem',
            source: source,
          )
          ..hierarchyPath = readNullablePersistedStringList(
            map['hierarchyPath'],
            field: 'hierarchyPath',
            source: source,
          )
          ..assetHierarchyRefJson = readOptionalAssetHierarchyReferenceJson(
            map['assetHierarchyRefJson'],
            field: 'assetHierarchyRefJson',
            source: source,
          )
          ..createdByUid = readOptionalPersistedString(
            map['createdByUid'],
            field: 'createdByUid',
            source: source,
          )
          ..createdByName = readOptionalPersistedString(
            map['createdByName'],
            field: 'createdByName',
            source: source,
          )
          ..isActive = readRequiredPersistedBool(
            map['isActive'],
            field: 'isActive',
            source: source,
          )
          ..isDeprecated = readRequiredPersistedBool(
            map['isDeprecated'],
            field: 'isDeprecated',
            source: source,
          )
          ..isDeleted = readRequiredPersistedBool(
            map['isDeleted'],
            field: 'isDeleted',
            source: source,
          )
          ..deletedAt = timestamps.deletedAt
          ..deletedByUid = readOptionalPersistedString(
            map['deletedByUid'],
            field: 'deletedByUid',
            source: source,
          )
          ..deletedByName = readOptionalPersistedString(
            map['deletedByName'],
            field: 'deletedByName',
            source: source,
          )
          ..deleteReason = readOptionalPersistedString(
            map['deleteReason'],
            field: 'deleteReason',
            source: source,
          )
          ..version = readRequiredPersistedInt(
            map['version'],
            field: 'version',
            source: source,
            minimum: 1,
          )
          ..createdAt = timestamps.createdAt
          ..updatedAt = timestamps.updatedAt
          ..metadataJson = readOptionalPersistedString(
            map['metadataJson'],
            field: 'metadataJson',
            source: source,
            emptyAsNull: false,
          )
          ..isSynced = true;

    // Structured fields are canonical when present. A malformed canonical
    // field set must never fall through to a different legacy payload.
    if (map.containsKey('fields')) {
      final rawFields = map['fields'];
      if (rawFields is! List) {
        throw PersistedDataFormatException(
          field: 'fields',
          source: source,
          detail: 'expected an array (${rawFields.runtimeType})',
        );
      }
      final encoded = jsonEncode(rawFields);
      template.setFields(TemplateField.decode(encoded, source: source));
    } else if (map.containsKey('fieldsJson')) {
      final rawFieldsJson = map['fieldsJson'];
      if (rawFieldsJson is! String) {
        throw PersistedDataFormatException(
          field: 'fieldsJson',
          source: source,
          detail: 'expected a JSON string (${rawFieldsJson.runtimeType})',
        );
      }
      template.setFields(TemplateField.decode(rawFieldsJson, source: source));
    } else {
      template.setFields(const <TemplateField>[]);
    }

    if (template.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        template.deletedAt,
        entityLabel: 'job template',
        firestoreId: template.firestoreId,
      );
    } else if (template.deletedAt != null ||
        template.deletedByUid != null ||
        template.deletedByName != null ||
        template.deleteReason != null) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'active templates cannot carry deletion state',
      );
    }

    if (template.updatedAt.isBefore(template.createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'cannot precede createdAt',
      );
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
  RoutedTo get assignedAgency =>
      assignedAgencies.isNotEmpty
          ? _enumByNameOr(
            RoutedTo.values,
            assignedAgencies.first,
            RoutedTo.mechanical,
          )
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
  List<FieldResponse> get responses => FieldResponse.decode(
    responsesJson,
    source:
        firestoreId == null
            ? 'local job execution $id'
            : 'job execution $firestoreId',
  );

  @ignore
  FieldResponseReadResult get responsesReadResult => FieldResponse.tryDecode(
    responsesJson,
    source:
        firestoreId == null
            ? 'local job execution $id'
            : 'job execution $firestoreId',
  );

  set responses(List<FieldResponse> value) {
    responsesJson = FieldResponse.encode(value);
  }

  dynamic getResponse(String key) {
    for (final response in responses) {
      if (response.key == key) return response.value;
    }
    return null;
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
  Map<String, dynamic> toMap() => {
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
    'responsesJson': responsesJson,
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
    final source = 'job execution $documentId';
    final timestamps = readRemoteJobExecutionTimestamps(map, source: source);
    if (map['isDeleted'] == true && timestamps.deletedAt == null) {
      requireRemoteTombstoneDeletedAt(
        timestamps.deletedAt,
        entityLabel: 'job execution',
        firestoreId: documentId,
      );
    }
    final embeddedId = readRequiredPersistedString(
      map['firestoreId'],
      field: 'firestoreId',
      source: source,
    );
    if (embeddedId != documentId) {
      throw PersistedDataFormatException(
        field: 'firestoreId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final assetType = readRequiredPersistedEnum(
      AssetType.values,
      map['assetType'],
      field: 'assetType',
      source: source,
    );
    final assetNumber = readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    if (!AssetValidator.isValid(assetType, assetNumber)) {
      throw PersistedDataFormatException(
        field: 'assetNumber',
        source: source,
        detail: 'outside the governed range for ${assetType.name}',
      );
    }
    final isCompleted = readRequiredPersistedBool(
      map['isCompleted'],
      field: 'isCompleted',
      source: source,
    );
    final isCancelled =
        readOptionalPersistedBool(
          map['isCancelled'],
          field: 'isCancelled',
          source: source,
        ) ??
        false;
    final isDeleted = readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    );
    final actionsJson = ComponentAction.readEncodedPayload(
      map['actionsJson'],
      field: 'actionsJson',
      source: source,
      allowMissing: !map.containsKey('actionsJson'),
    );
    ComponentAction.decode(actionsJson, source: source);
    final execution =
        JobExecution()
          ..firestoreId = embeddedId
          ..templateFirestoreId = readRequiredPersistedString(
            map['templateFirestoreId'],
            field: 'templateFirestoreId',
            source: source,
          )
          ..templateName = _readOptionalExecutionString(
            map,
            'templateName',
            source,
          )
          ..templatePackageId = _readOptionalExecutionString(
            map,
            'templatePackageId',
            source,
          )
          ..templateVersionId = _readOptionalExecutionString(
            map,
            'templateVersionId',
            source,
          )
          ..templateVersionNumber = readOptionalPersistedInt(
            map['templateVersionNumber'],
            field: 'templateVersionNumber',
            source: source,
            minimum: 1,
          )
          ..templateVersionLabel = _readOptionalExecutionString(
            map,
            'templateVersionLabel',
            source,
          )
          ..templateContentHash = _readOptionalExecutionString(
            map,
            'templateContentHash',
            source,
          )
          ..templatePackageCode = _readOptionalExecutionString(
            map,
            'templatePackageCode',
            source,
          )
          ..assetType = assetType
          ..assetNumber = assetNumber
          ..isCompleted = isCompleted
          ..isCancelled = isCancelled
          ..cancelledAt = timestamps.cancelledAt
          ..cancelledByUid = _readOptionalExecutionString(
            map,
            'cancelledByUid',
            source,
          )
          ..cancelledByName = _readOptionalExecutionString(
            map,
            'cancelledByName',
            source,
          )
          ..cancellationReason = _readOptionalExecutionString(
            map,
            'cancellationReason',
            source,
          )
          ..assignedByUid = readRequiredPersistedString(
            map['assignedByUid'],
            field: 'assignedByUid',
            source: source,
          )
          ..assignedByName = _readOptionalExecutionString(
            map,
            'assignedByName',
            source,
          )
          ..assignedAgencies = readOptionalPersistedStringList(
            map['assignedAgencies'],
            field: 'assignedAgencies',
            source: source,
          )
          ..workflowSchemaVersion =
              readOptionalPersistedInt(
                map['workflowSchemaVersion'],
                field: 'workflowSchemaVersion',
                source: source,
                minimum: 0,
              ) ??
              0
          ..laneSetVersion =
              readOptionalPersistedInt(
                map['laneSetVersion'],
                field: 'laneSetVersion',
                source: source,
                minimum: 0,
              ) ??
              0
          ..laneSetFinalizedAt = timestamps.laneSetFinalizedAt
          ..laneSetFinalizedByUid = _readOptionalExecutionString(
            map,
            'laneSetFinalizedByUid',
            source,
          )
          ..laneSetFinalizedByName = _readOptionalExecutionString(
            map,
            'laneSetFinalizedByName',
            source,
          )
          ..laneMappingReview =
              readOptionalPersistedBool(
                map['laneMappingReview'],
                field: 'laneMappingReview',
                source: source,
              ) ??
              false
          ..parentExecutionFirestoreId = _readOptionalExecutionString(
            map,
            'parentExecutionFirestoreId',
            source,
          )
          ..spawnedRedExecutionFirestoreId = _readOptionalExecutionString(
            map,
            'spawnedRedExecutionFirestoreId',
            source,
          )
          ..redAnswerJson = _readOptionalExecutionString(
            map,
            'redAnswerJson',
            source,
            emptyAsNull: false,
          )
          ..completedByUid = _readOptionalExecutionString(
            map,
            'completedByUid',
            source,
          )
          ..completedByName = _readOptionalExecutionString(
            map,
            'completedByName',
            source,
          )
          ..remarks = _readOptionalExecutionString(
            map,
            'remarks',
            source,
            emptyAsNull: false,
          )
          ..teamsInvolved = readOptionalPersistedStringList(
            map['teamsInvolved'],
            field: 'teamsInvolved',
            source: source,
          )
          ..chargeNoAtEvent = readOptionalPersistedInt(
            map['chargeNoAtEvent'],
            field: 'chargeNoAtEvent',
            source: source,
            minimum: 1,
          )
          ..actionsJson = actionsJson
          ..version = readRequiredPersistedInt(
            map['version'],
            field: 'version',
            source: source,
            minimum: 1,
          )
          ..metadataJson = _readOptionalExecutionString(
            map,
            'metadataJson',
            source,
            emptyAsNull: false,
          )
          ..isDeleted = isDeleted
          ..deletedAt = timestamps.deletedAt
          ..deletedByUid = _readOptionalExecutionString(
            map,
            'deletedByUid',
            source,
          )
          ..deletedByName = _readOptionalExecutionString(
            map,
            'deletedByName',
            source,
          )
          ..deleteReason = _readOptionalExecutionString(
            map,
            'deleteReason',
            source,
          )
          ..createdAt = timestamps.createdAt
          ..completedAt = timestamps.completedAt
          ..updatedAt = timestamps.updatedAt
          ..isSynced = true;

    // responsesJson is canonical. Only fall back to the legacy structured
    // 'responses' array for old records that do not contain responsesJson.
    if (map.containsKey('responsesJson')) {
      execution.responsesJson = FieldResponse.readEncodedPayload(
        map['responsesJson'],
        field: 'responsesJson',
        source: source,
      );
    } else {
      final rawResponses = map['responses'];
      if (rawResponses is List) {
        execution.responsesJson = FieldResponse.encodeLegacyPayload(
          rawResponses,
          source: source,
        );
      } else if (rawResponses == null) {
        execution.responsesJson = '[]';
      } else {
        throw PersistedDataFormatException(
          field: 'responses',
          source: source,
          detail: 'expected a legacy array (${rawResponses.runtimeType})',
        );
      }
    }

    if (execution.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        execution.deletedAt,
        entityLabel: 'job execution',
        firestoreId: execution.firestoreId,
      );
    } else if (execution.deletedAt != null ||
        execution.deletedByUid != null ||
        execution.deletedByName != null ||
        execution.deleteReason != null) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'active executions cannot carry deletion state',
      );
    }
    if (execution.isCompleted && execution.isCancelled) {
      throw PersistedDataFormatException(
        field: 'isCancelled',
        source: source,
        detail: 'execution cannot be completed and cancelled together',
      );
    }
    if (execution.isCompleted != (execution.completedAt != null)) {
      throw PersistedDataFormatException(
        field: 'completedAt',
        source: source,
        detail: 'completion flag and timestamp must be present together',
      );
    }
    if (execution.isCancelled != (execution.cancelledAt != null)) {
      throw PersistedDataFormatException(
        field: 'cancelledAt',
        source: source,
        detail: 'cancellation flag and timestamp must be present together',
      );
    }
    if (execution.updatedAt.isBefore(execution.createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'cannot precede createdAt',
      );
    }

    return execution;
  }
}

String? _readOptionalExecutionString(
  Map<String, dynamic> map,
  String field,
  String source, {
  bool emptyAsNull = true,
}) => readOptionalPersistedString(
  map[field],
  field: field,
  source: source,
  emptyAsNull: emptyAsNull,
);
