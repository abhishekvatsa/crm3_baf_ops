import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

enum ActionType { issue, repair, replacement, inspection }

enum ReplacementType { newPart, repaired, revised }

enum ActionSeverity { low, medium, high, critical }

enum ActionStatus { issue, inProgress, resolved }

class ComponentActionReadResult {
  final List<ComponentAction> entries;
  final FormatException? error;

  const ComponentActionReadResult._({
    required this.entries,
    required this.error,
  });

  bool get isValid => error == null;
}

class ComponentAction {
  static const Set<String> _knownFields = <String>{
    'id',
    'asset',
    'component',
    'hierarchyPath',
    'system',
    'subsystem',
    'subComponent',
    'tag',
    'instance',
    'actionType',
    'replacement',
    'issue',
    'resolution',
    'remarks',
    'templateFieldKey',
    'isAutoResolved',
    'status',
    'createdAt',
    'severity',
    'performedBy',
    'updatedAt',
    'version',
    'metadataJson',
  };

  final String? id;
  final String asset;
  final String component;
  final List<String>? hierarchyPath;
  final String? system;
  final String? subsystem;
  final String? subComponent;
  final String? tag;
  final String? instance;
  final ActionType actionType;
  final ReplacementType? replacement;
  final String? issue;
  final String? resolution;
  final String? remarks;
  final String? templateFieldKey;
  final bool isAutoResolved;
  final ActionStatus? status;
  final DateTime createdAt;
  final ActionSeverity severity;
  final String? performedBy;
  final DateTime? updatedAt;
  final int version;
  final String? metadataJson;

  /// Unknown persisted keys are retained so a read/rewrite by this version does
  /// not erase extensions written by another governed version.
  final Map<String, dynamic> extensions;

  ComponentAction({
    this.id,
    required this.asset,
    required this.component,
    this.hierarchyPath,
    this.system,
    this.subsystem,
    this.subComponent,
    this.tag,
    this.instance,
    required this.actionType,
    this.replacement,
    this.issue,
    this.resolution,
    this.remarks,
    this.templateFieldKey,
    this.isAutoResolved = false,
    this.status,
    DateTime? createdAt,
    this.severity = ActionSeverity.medium,
    this.performedBy,
    this.updatedAt,
    this.version = 1,
    this.metadataJson,
    Map<String, dynamic>? extensions,
  }) : createdAt = createdAt ?? DateTime.now(),
       extensions = Map<String, dynamic>.unmodifiable(
         extensions ?? const <String, dynamic>{},
       );

  Map<String, dynamic> toMap() => <String, dynamic>{
    ...extensions,
    'id': id,
    'asset': asset,
    'component': component,
    'hierarchyPath': hierarchyPath,
    'system': system,
    'subsystem': subsystem,
    'subComponent': subComponent,
    'tag': tag,
    'instance': instance,
    'actionType': actionType.name,
    'replacement': replacement?.name,
    'issue': issue,
    'resolution': resolution,
    'remarks': remarks,
    'templateFieldKey': templateFieldKey,
    'isAutoResolved': isAutoResolved,
    'status': status?.name,
    'createdAt': createdAt.toIso8601String(),
    'severity': severity.name,
    'performedBy': performedBy,
    'updatedAt': updatedAt?.toIso8601String(),
    'version': version,
    'metadataJson': metadataJson,
  };

  factory ComponentAction.fromMap(Map<String, dynamic> map, {String? source}) {
    final extensions = <String, dynamic>{
      for (final entry in map.entries)
        if (!_knownFields.contains(entry.key)) entry.key: entry.value,
    };

    return ComponentAction(
      id: _readOptionalRawString(map['id'], field: 'id', source: source),
      asset: readRequiredPersistedString(
        map['asset'],
        field: 'asset',
        source: source,
      ),
      component: readRequiredPersistedString(
        map['component'],
        field: 'component',
        source: source,
      ),
      hierarchyPath: readNullablePersistedStringList(
        map['hierarchyPath'],
        field: 'hierarchyPath',
        source: source,
      ),
      system: _readOptionalRawString(
        map['system'],
        field: 'system',
        source: source,
      ),
      subsystem: _readOptionalRawString(
        map['subsystem'],
        field: 'subsystem',
        source: source,
      ),
      subComponent: _readOptionalRawString(
        map['subComponent'],
        field: 'subComponent',
        source: source,
      ),
      tag: _readOptionalRawString(map['tag'], field: 'tag', source: source),
      instance: _readOptionalRawString(
        map['instance'],
        field: 'instance',
        source: source,
      ),
      actionType: readRequiredPersistedEnum(
        ActionType.values,
        map['actionType'],
        field: 'actionType',
        source: source,
      ),
      replacement: readOptionalPersistedEnum(
        ReplacementType.values,
        map['replacement'],
        field: 'replacement',
        source: source,
      ),
      issue: _readOptionalRawString(
        map['issue'],
        field: 'issue',
        source: source,
      ),
      resolution: _readOptionalRawString(
        map['resolution'],
        field: 'resolution',
        source: source,
      ),
      remarks: _readOptionalRawString(
        map['remarks'],
        field: 'remarks',
        source: source,
      ),
      templateFieldKey: _readOptionalRawString(
        map['templateFieldKey'],
        field: 'templateFieldKey',
        source: source,
      ),
      isAutoResolved: readRequiredPersistedBool(
        map['isAutoResolved'],
        field: 'isAutoResolved',
        source: source,
      ),
      status: readOptionalPersistedEnum(
        ActionStatus.values,
        map['status'],
        field: 'status',
        source: source,
      ),
      createdAt: readRequiredPersistedDateTime(
        map['createdAt'],
        field: 'createdAt',
        source: source,
      ),
      severity: readRequiredPersistedEnum(
        ActionSeverity.values,
        map['severity'],
        field: 'severity',
        source: source,
      ),
      performedBy: _readOptionalRawString(
        map['performedBy'],
        field: 'performedBy',
        source: source,
      ),
      updatedAt: readOptionalPersistedDateTime(
        map['updatedAt'],
        field: 'updatedAt',
        source: source,
      ),
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
      metadataJson: _readOptionalRawString(
        map['metadataJson'],
        field: 'metadataJson',
        source: source,
      ),
      extensions: extensions,
    );
  }

  static String encode(List<ComponentAction> actions) =>
      jsonEncode(actions.map((action) => action.toMap()).toList());

  static List<ComponentAction> decode(String? jsonStr, {String? source}) {
    if (jsonStr == null) {
      throw PersistedDataFormatException(
        field: 'actionsJson',
        source: source,
        detail: 'required JSON array (Null)',
      );
    }
    final rows = readRequiredJsonObjectList(
      jsonStr,
      field: 'actionsJson',
      source: source,
    );
    return <ComponentAction>[
      for (var index = 0; index < rows.length; index++)
        ComponentAction.fromMap(
          rows[index],
          source:
              source == null
                  ? 'actionsJson[$index]'
                  : '$source actionsJson[$index]',
        ),
    ];
  }

  static ComponentActionReadResult tryDecode(
    String? jsonStr, {
    String? source,
  }) {
    try {
      return ComponentActionReadResult._(
        entries: decode(jsonStr, source: source),
        error: null,
      );
    } on FormatException catch (error) {
      return ComponentActionReadResult._(
        entries: const <ComponentAction>[],
        error: error,
      );
    }
  }

  /// Canonical action payloads are strings. Missing fields remain compatible
  /// with records created before actions were introduced, but wrong types are
  /// rejected instead of being silently rewritten as an empty list.
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

String? _readOptionalRawString(
  dynamic value, {
  required String field,
  String? source,
}) => readOptionalPersistedString(
  value,
  field: field,
  source: source,
  emptyAsNull: false,
  trim: false,
);
