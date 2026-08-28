import '../../../core/serialization/persisted_data_reader.dart';

enum UvDetectorReplacementDisposition { newPart, repaired, revised }

enum UvDetectorLifecycleSourceType {
  maintenanceIssue,
  legacyPlannedJob,
  workflowPlannedJob,
}

final class UvDetectorLifecycleEvent {
  static const Set<String> _knownFields = <String>{
    'schemaVersion',
    'eventId',
    'eventType',
    'resultingCondition',
    'assetClassId',
    'assetClassCode',
    'assetClassName',
    'assetInstanceId',
    'assetInstanceName',
    'assetNumber',
    'hierarchyNodeId',
    'hierarchyNodeName',
    'hierarchyPath',
    'componentTag',
    'burnerPosition',
    'replacementDisposition',
    'installationDiscipline',
    'performedByName',
    'sourceType',
    'sourceId',
    'sourceModuleId',
    'sourceActionId',
    'sourceActionIndex',
    'actionPerformedAt',
    'completedAt',
    'completedByUid',
    'completedByName',
    'recordedAt',
    'version',
    'isDeleted',
  };

  static const Set<String> _currentKnownFields = <String>{
    ..._knownFields,
    'projectionSchemaVersion',
    'projectionId',
    'currentEventId',
  };

  const UvDetectorLifecycleEvent({
    required this.eventId,
    required this.assetClassId,
    required this.assetClassCode,
    required this.assetClassName,
    required this.assetInstanceId,
    required this.assetInstanceName,
    required this.assetNumber,
    required this.hierarchyNodeId,
    required this.hierarchyNodeName,
    required this.hierarchyPath,
    required this.componentTag,
    required this.burnerPosition,
    required this.replacementDisposition,
    required this.performedByName,
    required this.sourceType,
    required this.sourceId,
    required this.sourceModuleId,
    required this.sourceActionId,
    required this.sourceActionIndex,
    required this.actionPerformedAt,
    required this.completedAt,
    required this.completedByUid,
    required this.completedByName,
    required this.recordedAt,
    required this.version,
  });

  final String eventId;
  final String assetClassId;
  final String assetClassCode;
  final String assetClassName;
  final String assetInstanceId;
  final String assetInstanceName;
  final int assetNumber;
  final String? hierarchyNodeId;
  final String hierarchyNodeName;
  final List<String> hierarchyPath;
  final String? componentTag;
  final int burnerPosition;
  final UvDetectorReplacementDisposition replacementDisposition;
  final String performedByName;
  final UvDetectorLifecycleSourceType sourceType;
  final String sourceId;
  final String? sourceModuleId;
  final String? sourceActionId;
  final int sourceActionIndex;
  final DateTime actionPerformedAt;
  final DateTime completedAt;
  final String completedByUid;
  final String completedByName;
  final DateTime recordedAt;
  final int version;

  factory UvDetectorLifecycleEvent.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'uv_detector_lifecycle_events/$documentId';
    readBoundedPersistedExtensionBag(
      map,
      knownFields: _knownFields,
      allowedFields: const <String, PersistedExtensionValueKind>{},
      field: 'extensions',
      source: source,
    );
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1 ||
        map['eventType'] != 'replacement' ||
        map['resultingCondition'] != 'serviceable' ||
        map['installationDiscipline'] != 'instrumentation') {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported UV-detector lifecycle record',
      );
    }
    final eventId = readRequiredPersistedString(
      map['eventId'],
      field: 'eventId',
      source: source,
    );
    if (eventId != documentId) {
      throw PersistedDataFormatException(
        field: 'eventId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final assetNumber = readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    final burnerPosition = readRequiredPersistedInt(
      map['burnerPosition'],
      field: 'burnerPosition',
      source: source,
      minimum: 1,
    );
    if (assetNumber > 26 || burnerPosition > 8) {
      throw PersistedDataFormatException(
        field: assetNumber > 26 ? 'assetNumber' : 'burnerPosition',
        source: source,
        detail: 'is outside the governed Furnace range',
      );
    }
    final hierarchyPath = readOptionalPersistedStringList(
      map['hierarchyPath'],
      field: 'hierarchyPath',
      source: source,
    );
    if (hierarchyPath.isEmpty) {
      throw PersistedDataFormatException(
        field: 'hierarchyPath',
        source: source,
        detail: 'requires a governed Furnace path',
      );
    }
    final actionPerformedAt = readRequiredPersistedDateTime(
      map['actionPerformedAt'],
      field: 'actionPerformedAt',
      source: source,
    );
    final completedAt = readRequiredPersistedDateTime(
      map['completedAt'],
      field: 'completedAt',
      source: source,
    );
    final recordedAt = readRequiredPersistedDateTime(
      map['recordedAt'],
      field: 'recordedAt',
      source: source,
    );
    if (actionPerformedAt.isAfter(
          completedAt.add(const Duration(minutes: 5)),
        ) ||
        recordedAt != completedAt) {
      throw PersistedDataFormatException(
        field: 'completedAt',
        source: source,
        detail: 'does not preserve authoritative closure chronology',
      );
    }
    if (readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    )) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'UV lifecycle events are append-only',
      );
    }
    return UvDetectorLifecycleEvent(
      eventId: eventId,
      assetClassId: readRequiredPersistedString(
        map['assetClassId'],
        field: 'assetClassId',
        source: source,
      ),
      assetClassCode: readRequiredPersistedString(
        map['assetClassCode'],
        field: 'assetClassCode',
        source: source,
      ),
      assetClassName: readRequiredPersistedString(
        map['assetClassName'],
        field: 'assetClassName',
        source: source,
      ),
      assetInstanceId: readRequiredPersistedString(
        map['assetInstanceId'],
        field: 'assetInstanceId',
        source: source,
      ),
      assetInstanceName: readRequiredPersistedString(
        map['assetInstanceName'],
        field: 'assetInstanceName',
        source: source,
      ),
      assetNumber: assetNumber,
      hierarchyNodeId: readOptionalPersistedString(
        map['hierarchyNodeId'],
        field: 'hierarchyNodeId',
        source: source,
      ),
      hierarchyNodeName: readRequiredPersistedString(
        map['hierarchyNodeName'],
        field: 'hierarchyNodeName',
        source: source,
      ),
      hierarchyPath: List<String>.unmodifiable(hierarchyPath),
      componentTag: readOptionalPersistedString(
        map['componentTag'],
        field: 'componentTag',
        source: source,
      ),
      burnerPosition: burnerPosition,
      replacementDisposition: readRequiredPersistedEnum(
        UvDetectorReplacementDisposition.values,
        map['replacementDisposition'],
        field: 'replacementDisposition',
        source: source,
      ),
      performedByName: readRequiredPersistedString(
        map['performedByName'],
        field: 'performedByName',
        source: source,
      ),
      sourceType: readRequiredPersistedEnum(
        UvDetectorLifecycleSourceType.values,
        map['sourceType'],
        field: 'sourceType',
        source: source,
      ),
      sourceId: readRequiredPersistedString(
        map['sourceId'],
        field: 'sourceId',
        source: source,
      ),
      sourceModuleId: readOptionalPersistedString(
        map['sourceModuleId'],
        field: 'sourceModuleId',
        source: source,
      ),
      sourceActionId: readOptionalPersistedString(
        map['sourceActionId'],
        field: 'sourceActionId',
        source: source,
      ),
      sourceActionIndex: readRequiredPersistedInt(
        map['sourceActionIndex'],
        field: 'sourceActionIndex',
        source: source,
        minimum: 0,
      ),
      actionPerformedAt: actionPerformedAt,
      completedAt: completedAt,
      completedByUid: readRequiredPersistedString(
        map['completedByUid'],
        field: 'completedByUid',
        source: source,
      ),
      completedByName: readRequiredPersistedString(
        map['completedByName'],
        field: 'completedByName',
        source: source,
      ),
      recordedAt: recordedAt,
      version: readRequiredPersistedInt(
        map['version'],
        field: 'version',
        source: source,
        minimum: 1,
      ),
    );
  }

  factory UvDetectorLifecycleEvent.fromCurrentMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'uv_detector_lifecycle_current/$documentId';
    readBoundedPersistedExtensionBag(
      map,
      knownFields: _currentKnownFields,
      allowedFields: const <String, PersistedExtensionValueKind>{},
      field: 'extensions',
      source: source,
    );
    final projectionSchemaVersion = readRequiredPersistedInt(
      map['projectionSchemaVersion'],
      field: 'projectionSchemaVersion',
      source: source,
      minimum: 1,
    );
    final projectionId = readRequiredPersistedString(
      map['projectionId'],
      field: 'projectionId',
      source: source,
    );
    final currentEventId = readRequiredPersistedString(
      map['currentEventId'],
      field: 'currentEventId',
      source: source,
    );
    if (projectionSchemaVersion != 1 ||
        projectionId != documentId ||
        currentEventId != map['eventId']) {
      throw PersistedDataFormatException(
        field: 'projectionId',
        source: source,
        detail: 'current UV lifecycle identity is inconsistent',
      );
    }
    final eventMap =
        Map<String, dynamic>.from(map)
          ..remove('projectionSchemaVersion')
          ..remove('projectionId')
          ..remove('currentEventId');
    return UvDetectorLifecycleEvent.fromMap(eventMap, currentEventId);
  }
}
