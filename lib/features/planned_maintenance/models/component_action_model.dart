import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../assets/data/asset_hierarchy_model.dart';

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
  static const int payloadSchemaVersion = 1;
  static const Map<String, PersistedExtensionValueKind> _allowedExtensions =
      <String, PersistedExtensionValueKind>{};
  static const Set<String> _knownFields = <String>{
    'id',
    'asset',
    'component',
    'hierarchyPath',
    'assetHierarchyRef',
    'system',
    'subsystem',
    'subComponent',
    'tag',
    'instance',
    'actionType',
    'action',
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
    'attendanceSessionId',
    'burnerPosition',
    'burnerActionCode',
    'burnerOutcome',
    'burnerMicroampReading',
    'schemaVersion',
  };

  final String? id;
  final String asset;
  final String component;
  final List<String>? hierarchyPath;
  final AssetHierarchyReference? assetHierarchyRef;
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
  final String? attendanceSessionId;
  final int? burnerPosition;
  final String? burnerActionCode;
  final String? burnerOutcome;
  final double? burnerMicroampReading;

  /// Only explicitly registered, bounded non-authority extensions are retained.
  final Map<String, dynamic> extensions;

  ComponentAction({
    this.id,
    required this.asset,
    required this.component,
    this.hierarchyPath,
    this.assetHierarchyRef,
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
    String? metadataJson,
    String? attendanceSessionId,
    int? burnerPosition,
    String? burnerActionCode,
    String? burnerOutcome,
    double? burnerMicroampReading,
    Map<String, dynamic>? extensions,
  }) : createdAt = createdAt ?? DateTime.now(),
       metadataJson = _readOptionalJsonObjectText(
         metadataJson,
         field: 'metadataJson',
         source: 'ComponentAction constructor',
       ),
       attendanceSessionId = readOptionalPersistedString(
         attendanceSessionId,
         field: 'attendanceSessionId',
         source: 'ComponentAction constructor',
       ),
       burnerPosition = _readBurnerPosition(
         burnerPosition,
         source: 'ComponentAction constructor',
       ),
       burnerActionCode = readOptionalPersistedString(
         burnerActionCode,
         field: 'burnerActionCode',
         source: 'ComponentAction constructor',
       ),
       burnerOutcome = readOptionalPersistedString(
         burnerOutcome,
         field: 'burnerOutcome',
         source: 'ComponentAction constructor',
       ),
       burnerMicroampReading = _readBurnerMicroampReading(
         burnerMicroampReading,
         source: 'ComponentAction constructor',
       ),
       extensions = validateBoundedPersistedExtensionBag(
         extensions ?? const <String, dynamic>{},
         allowedFields: _allowedExtensions,
         field: 'extensions',
         source: 'ComponentAction constructor',
       ) {
    _validateCompleteBurnerEvidence(
      attendanceSessionId: this.attendanceSessionId,
      burnerPosition: this.burnerPosition,
      burnerActionCode: this.burnerActionCode,
      burnerOutcome: this.burnerOutcome,
      burnerMicroampReading: this.burnerMicroampReading,
      source: 'ComponentAction constructor',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    ...extensions,
    'schemaVersion': payloadSchemaVersion,
    'id': id,
    'asset': asset,
    'component': component,
    'hierarchyPath': hierarchyPath,
    'assetHierarchyRef': assetHierarchyRef?.toMap(),
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
    'attendanceSessionId': attendanceSessionId,
    'burnerPosition': burnerPosition,
    'burnerActionCode': burnerActionCode,
    'burnerOutcome': burnerOutcome,
    'burnerMicroampReading': burnerMicroampReading,
  };

  factory ComponentAction.fromMap(Map<String, dynamic> map, {String? source}) {
    readPersistedPayloadSchemaVersion(
      map,
      field: 'schemaVersion',
      source: source,
      currentVersion: payloadSchemaVersion,
    );
    final extensions = readBoundedPersistedExtensionBag(
      map,
      knownFields: _knownFields,
      allowedFields: _allowedExtensions,
      field: 'extensions',
      source: source,
    );

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
      assetHierarchyRef: _readAssetHierarchyReference(
        map['assetHierarchyRef'],
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
      actionType: _readActionType(map, source: source),
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
      metadataJson: _readOptionalJsonObjectText(
        map['metadataJson'],
        field: 'metadataJson',
        source: source,
      ),
      attendanceSessionId: readOptionalPersistedString(
        map['attendanceSessionId'],
        field: 'attendanceSessionId',
        source: source,
      ),
      burnerPosition: _readBurnerPosition(
        map['burnerPosition'],
        source: source,
      ),
      burnerActionCode: readOptionalPersistedString(
        map['burnerActionCode'],
        field: 'burnerActionCode',
        source: source,
      ),
      burnerOutcome: readOptionalPersistedString(
        map['burnerOutcome'],
        field: 'burnerOutcome',
        source: source,
      ),
      burnerMicroampReading: _readBurnerMicroampReading(
        map['burnerMicroampReading'],
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

ActionType _readActionType(Map<String, dynamic> map, {String? source}) {
  dynamic normalize(dynamic value) => value == 'inspect' ? 'inspection' : value;

  final actionType = map['actionType'];
  final legacyAction = map['action'];
  if (actionType != null &&
      legacyAction != null &&
      normalize(actionType) != normalize(legacyAction)) {
    throw PersistedDataFormatException(
      field: 'actionType',
      source: source,
      detail: 'conflicts with legacy action alias',
    );
  }
  final raw = normalize(actionType ?? legacyAction);
  return readRequiredPersistedEnum(
    ActionType.values,
    raw,
    field: 'actionType',
    source: source,
  );
}

int? _readBurnerPosition(dynamic value, {String? source}) {
  final position = readOptionalPersistedInt(
    value,
    field: 'burnerPosition',
    source: source,
    minimum: 1,
  );
  if (position != null && position > 8) {
    throw PersistedDataFormatException(
      field: 'burnerPosition',
      source: source,
      detail: 'burner position must be between 1 and 8',
    );
  }
  return position;
}

double? _readBurnerMicroampReading(dynamic value, {String? source}) {
  final reading = readOptionalPersistedDouble(
    value,
    field: 'burnerMicroampReading',
    source: source,
  );
  if (reading != null && (reading < 0 || reading > 1000000)) {
    throw PersistedDataFormatException(
      field: 'burnerMicroampReading',
      source: source,
      detail: 'microamp reading must be between 0 and 1000000',
    );
  }
  return reading;
}

void _validateCompleteBurnerEvidence({
  required String? attendanceSessionId,
  required int? burnerPosition,
  required String? burnerActionCode,
  required String? burnerOutcome,
  required double? burnerMicroampReading,
  required String source,
}) {
  final anyPresent =
      attendanceSessionId != null ||
      burnerPosition != null ||
      burnerActionCode != null ||
      burnerOutcome != null ||
      burnerMicroampReading != null;
  if (!anyPresent) return;
  if (attendanceSessionId == null ||
      burnerPosition == null ||
      burnerActionCode == null ||
      burnerOutcome == null) {
    throw PersistedDataFormatException(
      field: 'burnerEvidence',
      source: source,
      detail:
          'burner evidence requires attendanceSessionId, burnerPosition, burnerActionCode and burnerOutcome together',
    );
  }
}

String? _readOptionalJsonObjectText(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a JSON object string (${value.runtimeType})',
    );
  }
  if (value.trim().isEmpty) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a non-empty JSON object string',
    );
  }
  readOptionalBoundedJsonObject(value, field: field, source: source);
  return value;
}

AssetHierarchyReference? _readAssetHierarchyReference(
  dynamic value, {
  String? source,
}) {
  if (value == null) return null;
  if (value is! Map) {
    throw PersistedDataFormatException(
      field: 'assetHierarchyRef',
      source: source,
      detail: 'expected an object (${value.runtimeType})',
    );
  }
  return AssetHierarchyReference.fromMap(
    Map<String, dynamic>.from(value),
    source: source,
  );
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
