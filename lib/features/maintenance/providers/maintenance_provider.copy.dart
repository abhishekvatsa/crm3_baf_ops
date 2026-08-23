part of 'maintenance_provider.dart';

void _overwriteLocalMaintenanceRecord(
  MaintenanceRecord local,
  MaintenanceRecord remote,
) {
  local
    ..version = remote.version
    ..assetType = remote.assetType
    ..assetNumber = remote.assetNumber
    ..component = remote.component
    ..subsystem = remote.subsystem
    ..tag = remote.tag
    ..hierarchyPath = remote.hierarchyPath
    ..assetHierarchyRefJson = remote.assetHierarchyRefJson
    ..maintenanceType = remote.maintenanceType
    ..classification = remote.classification
    ..description = remote.description
    ..routedTo = remote.routedTo
    ..otherDepartment = remote.otherDepartment
    ..status = remote.status
    ..isResolved = remote.isResolved
    ..workflowDeferred = remote.workflowDeferred
    ..workflowQueueState = remote.workflowQueueState
    ..workflowAggregateId = remote.workflowAggregateId
    ..workflowComplianceId = remote.workflowComplianceId
    ..workflowOriginLaneKey = remote.workflowOriginLaneKey
    ..workflowTargetLaneKey = remote.workflowTargetLaneKey
    ..workflowConditionTypeKey = remote.workflowConditionTypeKey
    ..workflowConditionRef = remote.workflowConditionRef
    ..workflowDeferredAt = remote.workflowDeferredAt
    ..workflowDeferredByUid = remote.workflowDeferredByUid
    ..workflowDeferredByName = remote.workflowDeferredByName
    ..workflowReactivatedAt = remote.workflowReactivatedAt
    ..workflowReactivatedByUid = remote.workflowReactivatedByUid
    ..workflowReactivatedByName = remote.workflowReactivatedByName
    ..workflowReleasedAt = remote.workflowReleasedAt
    ..workflowReleasedByUid = remote.workflowReleasedByUid
    ..workflowReleasedByName = remote.workflowReleasedByName
    ..workflowCorrectionReason = remote.workflowCorrectionReason
    ..workflowUpdatedAt = remote.workflowUpdatedAt
    ..operationalEventIssueLinkIds = List<String>.of(
      remote.operationalEventIssueLinkIds,
    )
    ..isCritical = remote.isCritical
    ..loggedByUid = remote.loggedByUid
    ..loggedByName = remote.loggedByName
    ..reportedBy = remote.reportedBy
    ..acknowledgedByUid = remote.acknowledgedByUid
    ..acknowledgedByName = remote.acknowledgedByName
    ..acknowledgedAt = remote.acknowledgedAt
    ..closedByUid = remote.closedByUid
    ..closedByName = remote.closedByName
    ..teamsInvolved = remote.teamsInvolved
    ..performedBy = remote.performedBy
    ..remarks = remote.remarks
    ..startDate = remote.startDate
    ..endDate = remote.endDate
    ..downtimeHours = remote.downtimeHours
    ..chargeNoAtEvent = remote.chargeNoAtEvent
    ..metadataJson = remote.metadataJson
    ..actionsJson = remote.actionsJson
    ..resolutionHistoryJson = remote.resolutionHistoryJson
    ..isDeleted = remote.isDeleted
    ..deletedAt = remote.deletedAt
    ..deletedByUid = remote.deletedByUid
    ..deletedByName = remote.deletedByName
    ..deleteReason = remote.deleteReason
    ..createdAt = remote.createdAt
    ..updatedAt = remote.updatedAt
    ..isSynced = true;
}
