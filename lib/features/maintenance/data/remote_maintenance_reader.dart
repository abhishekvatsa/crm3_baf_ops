import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/validation/charge_number.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../utils/asset_validator.dart';
import 'maintenance_model.dart';
import '../../quality/domain/issue_quality_intent.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/frequent_issue_selection.dart';
import 'remote_maintenance_timestamps.dart';

const _workflowQueueStates = <String>{
  'independent',
  'deferred',
  'actionable',
  'awaitingConfirmation',
  'correctionRequired',
  'released',
};

MaintenanceRecord readRemoteMaintenanceRecord(
  Map<String, dynamic> map, {
  required String documentId,
}) {
  final source = 'maintenance_records/$documentId';
  final qualityIntent = IssueQualityIntent.readOptionalSynchronizedFields(
    map,
    source: source,
  );
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

  final timestamps = readRemoteMaintenanceTimestamps(map, source: source);
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
  final assetHierarchyRefJson = readOptionalPersistedString(
    map['assetHierarchyRefJson'],
    field: 'assetHierarchyRefJson',
    source: source,
    emptyAsNull: false,
  );
  final assetHierarchyReference =
      assetHierarchyRefJson == null
          ? null
          : AssetHierarchyReference.decode(
            assetHierarchyRefJson,
            source: source,
          );
  final hasGovernedAssetIdentity =
      assetHierarchyReference != null &&
      assetHierarchyReference.scope != AssetHierarchyReferenceScope.definition;
  if (hasGovernedAssetIdentity &&
      assetHierarchyReference.assetNumber != assetNumber) {
    throw PersistedDataFormatException(
      field: 'assetHierarchyRefJson',
      source: source,
      detail: 'governed asset number must match assetNumber',
    );
  }
  if (assetNumber > 9999 ||
      (!hasGovernedAssetIdentity &&
          !AssetValidator.isValid(assetType, assetNumber))) {
    throw PersistedDataFormatException(
      field: 'assetNumber',
      source: source,
      detail: 'outside the governed range for ${assetType.name}',
    );
  }

  final status = readRequiredPersistedEnum(
    TicketStatus.values,
    map['status'],
    field: 'status',
    source: source,
  );
  final isResolved = readRequiredPersistedBool(
    map['isResolved'],
    field: 'isResolved',
    source: source,
  );
  if ((status == TicketStatus.resolved) != isResolved) {
    throw PersistedDataFormatException(
      field: 'isResolved',
      source: source,
      detail: 'must agree with status ${status.name}',
    );
  }
  final classification = _optionalString(map, 'classification', source);
  final burnerLockout = BurnerLockoutCase.readOptionalSynchronizedFields(
    map,
    source: source,
  );
  final furnaceStuckup = FurnaceStuckupCase.readOptionalSynchronizedFields(
    map,
    source: source,
  );
  final frequentIssueSelection =
      FrequentIssueSelection.readOptionalSynchronizedFields(
        map,
        source: source,
      );
  final isBurnerLockout = classification == burnerLockoutClassification;
  if (isBurnerLockout != (burnerLockout != null)) {
    throw PersistedDataFormatException(
      field: 'classification',
      source: source,
      detail:
          'burner-lockout classification and structured fields must be present together',
    );
  }
  if (burnerLockout != null &&
      (assetType != AssetType.furnace ||
          map['routedTo'] != RoutedTo.instrumentation.name ||
          map['component'] != 'Burner system')) {
    throw PersistedDataFormatException(
      field: 'classification',
      source: source,
      detail: 'burner lockout must belong to a Furnace and route to I&A',
    );
  }
  final isFurnaceStuckup = classification == furnaceStuckupClassification;
  if (isFurnaceStuckup != (furnaceStuckup != null)) {
    throw PersistedDataFormatException(
      field: 'classification',
      source: source,
      detail:
          'Furnace stuck-up classification and structured fields must be present together',
    );
  }
  if (furnaceStuckup != null &&
      (assetType != AssetType.furnace ||
          map['component'] != 'Furnace / Inner Cover interface' ||
          map['maintenanceType'] != MaintenanceType.breakdown.name)) {
    throw PersistedDataFormatException(
      field: 'classification',
      source: source,
      detail: 'Furnace stuck-up evidence requires its specialized issue route',
    );
  }
  final actionsJson = ComponentAction.readEncodedPayload(
    map['actionsJson'],
    field: 'actionsJson',
    source: source,
    allowMissing: !map.containsKey('actionsJson'),
  );
  final actions = ComponentAction.decode(actionsJson, source: source);
  if (burnerLockout != null &&
      (burnerLockout.isResolutionComplete != isResolved ||
          (burnerLockout.hasRedHotObservation && map['isCritical'] != true))) {
    throw PersistedDataFormatException(
      field: 'burnerResolutionEvidence',
      source: source,
      detail:
          'burner closure evidence and red-hot criticality must match ticket state',
    );
  }
  if (burnerLockout != null && isResolved) {
    try {
      validatePersistedBurnerResolutionEvidence(
        lockout: burnerLockout,
        actions: actions,
      );
    } on FormatException catch (error) {
      throw PersistedDataFormatException(
        field: 'burnerResolutionEvidence',
        source: source,
        detail: error.message,
      );
    }
  }

  final workflow = _readWorkflowProjection(map, source: source);
  if (workflow.aggregateId != null && timestamps.workflowUpdatedAt == null) {
    throw PersistedDataFormatException(
      field: 'workflowUpdatedAt',
      source: source,
      detail: 'linked workflow projection requires its update timestamp',
    );
  }
  final resolutionHistoryJson = readEncodedResolutionHistoryPayload(
    map['resolutionHistoryJson'],
    source: source,
  );
  final isDeleted = readRequiredPersistedBool(
    map['isDeleted'],
    field: 'isDeleted',
    source: source,
  );

  _requireTimeline(timestamps: timestamps, source: source);
  _requireDeletionLifecycle(
    map: map,
    isDeleted: isDeleted,
    deletedAt: timestamps.deletedAt,
    firestoreId: embeddedId,
    source: source,
  );

  return MaintenanceRecord()
    ..firestoreId = embeddedId
    ..version = readRequiredPersistedInt(
      map['version'],
      field: 'version',
      source: source,
      minimum: 1,
    )
    ..assetType = assetType
    ..assetNumber = assetNumber
    ..component = _optionalString(map, 'component', source)
    ..subsystem = _optionalString(map, 'subsystem', source)
    ..tag = _optionalString(map, 'tag', source)
    ..hierarchyPath = readNullablePersistedStringList(
      map['hierarchyPath'],
      field: 'hierarchyPath',
      source: source,
    )
    ..assetHierarchyRefJson = assetHierarchyRefJson
    ..maintenanceType = readRequiredPersistedEnum(
      MaintenanceType.values,
      map['maintenanceType'],
      field: 'maintenanceType',
      source: source,
    )
    ..classification = classification
    ..description = readRequiredPersistedString(
      map['description'],
      field: 'description',
      source: source,
    )
    ..routedTo = readRequiredPersistedEnum(
      RoutedTo.values,
      map['routedTo'],
      field: 'routedTo',
      source: source,
    )
    ..otherDepartment = _optionalString(map, 'otherDepartment', source)
    ..status = status
    ..isResolved = isResolved
    ..workflowDeferred = workflow.deferred
    ..workflowQueueState = workflow.queueState
    ..workflowAggregateId = workflow.aggregateId
    ..workflowComplianceId = workflow.complianceId
    ..workflowOriginLaneKey = workflow.originLaneKey
    ..workflowTargetLaneKey = workflow.targetLaneKey
    ..workflowConditionTypeKey = workflow.conditionTypeKey
    ..workflowConditionRef = workflow.conditionRef
    ..workflowDeferredAt = timestamps.workflowDeferredAt
    ..workflowDeferredByUid = _optionalString(
      map,
      'workflowDeferredByUid',
      source,
    )
    ..workflowDeferredByName = _optionalString(
      map,
      'workflowDeferredByName',
      source,
    )
    ..workflowReactivatedAt = timestamps.workflowReactivatedAt
    ..workflowReactivatedByUid = _optionalString(
      map,
      'workflowReactivatedByUid',
      source,
    )
    ..workflowReactivatedByName = _optionalString(
      map,
      'workflowReactivatedByName',
      source,
    )
    ..workflowReleasedAt = timestamps.workflowReleasedAt
    ..workflowReleasedByUid = _optionalString(
      map,
      'workflowReleasedByUid',
      source,
    )
    ..workflowReleasedByName = _optionalString(
      map,
      'workflowReleasedByName',
      source,
    )
    ..workflowCorrectionReason = _optionalString(
      map,
      'workflowCorrectionReason',
      source,
    )
    ..workflowUpdatedAt = timestamps.workflowUpdatedAt
    ..operationalEventIssueLinkIds = _readOperationalEventIssueLinkIds(
      map,
      source,
    )
    ..isCritical = readRequiredPersistedBool(
      map['isCritical'],
      field: 'isCritical',
      source: source,
    )
    ..loggedByUid = readRequiredPersistedString(
      map['loggedByUid'],
      field: 'loggedByUid',
      source: source,
    )
    ..loggedByName = _optionalString(map, 'loggedByName', source)
    ..reportedBy = _optionalString(map, 'reportedBy', source)
    ..acknowledgedByUid = _optionalString(map, 'acknowledgedByUid', source)
    ..acknowledgedByName = _optionalString(map, 'acknowledgedByName', source)
    ..acknowledgedAt = timestamps.acknowledgedAt
    ..closedByUid = _optionalString(map, 'closedByUid', source)
    ..closedByName = _optionalString(map, 'closedByName', source)
    ..teamsInvolved = readOptionalPersistedStringList(
      map['teamsInvolved'],
      field: 'teamsInvolved',
      source: source,
    )
    ..performedBy = _optionalString(map, 'performedBy', source)
    ..remarks = _optionalString(map, 'remarks', source, emptyAsNull: false)
    ..startDate = timestamps.startDate
    ..endDate = timestamps.endDate
    ..downtimeHours = readOptionalPersistedDouble(
      map['downtimeHours'],
      field: 'downtimeHours',
      source: source,
    )
    ..chargeNoAtEvent = readOptionalPersistedChargeNumber(
      map['chargeNoAtEvent'],
      field: 'chargeNoAtEvent',
      source: source,
    )
    ..createdAt = timestamps.createdAt
    ..updatedAt = timestamps.updatedAt
    ..metadataJson = mergeFrequentIssueSelectionIntoMaintenanceMetadata(
      mergeFurnaceStuckupIntoMaintenanceMetadata(
        qualityIntent != null || burnerLockout != null
            ? mergeMaintenanceMetadataEnvelopes(
              existing: _optionalString(
                map,
                'metadataJson',
                source,
                emptyAsNull: false,
              ),
              qualityIntent: qualityIntent?.toMap(),
              burnerLockout: burnerLockout,
            )
            : _optionalString(map, 'metadataJson', source, emptyAsNull: false),
        furnaceStuckup,
      ),
      frequentIssueSelection,
    )
    ..actionsJson = actionsJson
    ..resolutionHistoryJson = resolutionHistoryJson
    ..isDeleted = isDeleted
    ..deletedAt = timestamps.deletedAt
    ..deletedByUid = _optionalString(map, 'deletedByUid', source)
    ..deletedByName = _optionalString(map, 'deletedByName', source)
    ..deleteReason = _optionalString(map, 'deleteReason', source)
    ..isSynced = true;
}

class _WorkflowProjection {
  const _WorkflowProjection({
    required this.deferred,
    required this.queueState,
    this.aggregateId,
    this.complianceId,
    this.originLaneKey,
    this.targetLaneKey,
    this.conditionTypeKey,
    this.conditionRef,
  });

  final bool deferred;
  final String queueState;
  final String? aggregateId;
  final String? complianceId;
  final String? originLaneKey;
  final String? targetLaneKey;
  final String? conditionTypeKey;
  final String? conditionRef;
}

_WorkflowProjection _readWorkflowProjection(
  Map<String, dynamic> map, {
  required String source,
}) {
  const coreFields = <String>{
    'workflowDeferred',
    'workflowQueueState',
    'workflowAggregateId',
    'workflowComplianceId',
    'workflowOriginLaneKey',
    'workflowTargetLaneKey',
    'workflowConditionTypeKey',
    'workflowUpdatedAt',
  };
  final present = coreFields.where(map.containsKey).toSet();
  if (present.isEmpty) {
    return const _WorkflowProjection(
      deferred: false,
      queueState: 'independent',
    );
  }
  if (present.length != coreFields.length) {
    throw PersistedDataFormatException(
      field: 'workflowQueueState',
      source: source,
      detail: 'workflow projection core fields must be present together',
    );
  }

  final deferred = readRequiredPersistedBool(
    map['workflowDeferred'],
    field: 'workflowDeferred',
    source: source,
  );
  final queueState = readRequiredPersistedString(
    map['workflowQueueState'],
    field: 'workflowQueueState',
    source: source,
  );
  if (!_workflowQueueStates.contains(queueState)) {
    throw PersistedDataFormatException(
      field: 'workflowQueueState',
      source: source,
      detail: 'unknown queue state "$queueState"',
    );
  }
  final mustBeDeferred =
      queueState == 'deferred' || queueState == 'correctionRequired';
  if (deferred != mustBeDeferred) {
    throw PersistedDataFormatException(
      field: 'workflowDeferred',
      source: source,
      detail: 'must agree with workflowQueueState $queueState',
    );
  }

  return _WorkflowProjection(
    deferred: deferred,
    queueState: queueState,
    aggregateId: readRequiredPersistedString(
      map['workflowAggregateId'],
      field: 'workflowAggregateId',
      source: source,
    ),
    complianceId: readRequiredPersistedString(
      map['workflowComplianceId'],
      field: 'workflowComplianceId',
      source: source,
    ),
    originLaneKey: readRequiredPersistedString(
      map['workflowOriginLaneKey'],
      field: 'workflowOriginLaneKey',
      source: source,
    ),
    targetLaneKey: readRequiredPersistedString(
      map['workflowTargetLaneKey'],
      field: 'workflowTargetLaneKey',
      source: source,
    ),
    conditionTypeKey: readRequiredPersistedString(
      map['workflowConditionTypeKey'],
      field: 'workflowConditionTypeKey',
      source: source,
    ),
    conditionRef: _optionalString(map, 'workflowConditionRef', source),
  );
}

String? _optionalString(
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

List<String> _readOperationalEventIssueLinkIds(
  Map<String, dynamic> map,
  String source,
) {
  if (!map.containsKey('operationalEventIssueLinkIds')) return <String>[];
  if (map['operationalEventIssueLinkIds'] is! List) {
    throw PersistedDataFormatException(
      field: 'operationalEventIssueLinkIds',
      source: source,
      detail: 'must be a complete list when present',
    );
  }
  final ids = readOptionalPersistedStringList(
    map['operationalEventIssueLinkIds'],
    field: 'operationalEventIssueLinkIds',
    source: source,
  );
  if (ids.length > 50 || ids.toSet().length != ids.length) {
    throw PersistedDataFormatException(
      field: 'operationalEventIssueLinkIds',
      source: source,
      detail: 'exceeds 50 links or contains duplicates',
    );
  }
  return List<String>.unmodifiable(ids);
}

void _requireTimeline({
  required RemoteMaintenanceTimestamps timestamps,
  required String source,
}) {
  if (timestamps.updatedAt.isBefore(timestamps.createdAt)) {
    throw PersistedDataFormatException(
      field: 'updatedAt',
      source: source,
      detail: 'cannot precede createdAt',
    );
  }
  final endDate = timestamps.endDate;
  if (endDate != null && endDate.isBefore(timestamps.startDate)) {
    throw PersistedDataFormatException(
      field: 'endDate',
      source: source,
      detail: 'cannot precede startDate',
    );
  }
}

void _requireDeletionLifecycle({
  required Map<String, dynamic> map,
  required bool isDeleted,
  required DateTime? deletedAt,
  required String firestoreId,
  required String source,
}) {
  final deletedByUid = _optionalString(map, 'deletedByUid', source);
  final deletedByName = _optionalString(map, 'deletedByName', source);
  final deleteReason = _optionalString(map, 'deleteReason', source);
  if (isDeleted) {
    requireRemoteTombstoneDeletedAt(
      deletedAt,
      entityLabel: 'maintenance ticket',
      firestoreId: firestoreId,
    );
    if (deletedByUid == null) {
      throw PersistedDataFormatException(
        field: 'deletedByUid',
        source: source,
        detail: 'deleted maintenance requires deletion authority',
      );
    }
  } else if (deletedAt != null ||
      deletedByUid != null ||
      deletedByName != null ||
      deleteReason != null) {
    throw PersistedDataFormatException(
      field: 'isDeleted',
      source: source,
      detail: 'active maintenance cannot carry deletion state',
    );
  }
}
