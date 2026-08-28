import '../../../core/serialization/persisted_data_reader.dart';

enum BurnerBlockLifecycleSupplyMode { sailRed, purchased }

enum BurnerBlockReplacementDisposition { newPart, repaired, revised }

enum BurnerBlockLifecycleSourceType {
  maintenanceIssue,
  legacyPlannedJob,
  workflowPlannedJob,
}

class BurnerBlockLifecycleEvent {
  static const Set<String> _knownFields = <String>{
    'schemaVersion',
    'eventId',
    'eventType',
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
    'supplyMode',
    'supplierName',
    'purchaseOrderNumber',
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

  const BurnerBlockLifecycleEvent({
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
    required this.supplyMode,
    required this.supplierName,
    required this.purchaseOrderNumber,
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
  final String hierarchyNodeId;
  final String hierarchyNodeName;
  final List<String> hierarchyPath;
  final String? componentTag;
  final int burnerPosition;
  final BurnerBlockReplacementDisposition replacementDisposition;
  final BurnerBlockLifecycleSupplyMode supplyMode;
  final String? supplierName;
  final String? purchaseOrderNumber;
  final String performedByName;
  final BurnerBlockLifecycleSourceType sourceType;
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

  factory BurnerBlockLifecycleEvent.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'burner_block_lifecycle_events/$documentId';
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
    if (schemaVersion != 1 || map['eventType'] != 'replacement') {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported burner-block lifecycle record',
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
    final supplyMode = readRequiredPersistedEnum(
      BurnerBlockLifecycleSupplyMode.values,
      map['supplyMode'],
      field: 'supplyMode',
      source: source,
    );
    final supplierName = readOptionalPersistedString(
      map['supplierName'],
      field: 'supplierName',
      source: source,
    );
    final purchaseOrderNumber = readOptionalPersistedString(
      map['purchaseOrderNumber'],
      field: 'purchaseOrderNumber',
      source: source,
    );
    if (supplyMode != BurnerBlockLifecycleSupplyMode.purchased &&
        (supplierName != null || purchaseOrderNumber != null)) {
      throw PersistedDataFormatException(
        field: 'supplyMode',
        source: source,
        detail: 'supplier and PO evidence requires purchased mode',
      );
    }
    if (map['installationDiscipline'] != 'mechanical') {
      throw PersistedDataFormatException(
        field: 'installationDiscipline',
        source: source,
        detail: 'burner-block installation must be Mechanical',
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
        detail: 'does not preserve the authoritative closure chronology',
      );
    }
    final isDeleted = readRequiredPersistedBool(
      map['isDeleted'],
      field: 'isDeleted',
      source: source,
    );
    if (isDeleted) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'lifecycle events are append-only',
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
        detail: 'requires at least one governed hierarchy segment',
      );
    }
    return BurnerBlockLifecycleEvent(
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
      hierarchyNodeId: readRequiredPersistedString(
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
        BurnerBlockReplacementDisposition.values,
        map['replacementDisposition'],
        field: 'replacementDisposition',
        source: source,
      ),
      supplyMode: supplyMode,
      supplierName: supplierName,
      purchaseOrderNumber: purchaseOrderNumber,
      performedByName: readRequiredPersistedString(
        map['performedByName'],
        field: 'performedByName',
        source: source,
      ),
      sourceType: readRequiredPersistedEnum(
        BurnerBlockLifecycleSourceType.values,
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

  factory BurnerBlockLifecycleEvent.fromCurrentMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    const collection = 'burner_block_lifecycle_current';
    final source = '$collection/$documentId';
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
        detail: 'current lifecycle identity is inconsistent',
      );
    }
    final eventMap =
        Map<String, dynamic>.from(map)
          ..remove('projectionSchemaVersion')
          ..remove('projectionId')
          ..remove('currentEventId');
    return BurnerBlockLifecycleEvent.fromMap(eventMap, currentEventId);
  }
}
