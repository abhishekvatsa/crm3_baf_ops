import '../domain/compliance_models.dart';
import '../domain/maintenance_lane.dart';
import '../domain/workflow_models.dart';
import '../domain/workflow_types.dart';
import 'compliance_request_record.dart';
import 'job_lane_record.dart';
import 'workflow_aggregate_record.dart';

WorkflowLaneStatus _laneStatus(String key) {
  switch (key) {
    case 'pending': return WorkflowLaneStatus.pending;
    case 'acknowledged': return WorkflowLaneStatus.acknowledged;
    case 'closed': return WorkflowLaneStatus.closed;
    case 'removed': return WorkflowLaneStatus.removed;
    case 'terminated': return WorkflowLaneStatus.terminated;
    default: return WorkflowLaneStatus.pending;
  }
}

WorkflowStatus _workflowStatus(String key) {
  return WorkflowStatus.values.firstWhere(
    (value) => value.name == key,
    orElse: () => WorkflowStatus.pendingLaneClassification,
  );
}

ComplianceStatus _complianceStatus(String key) {
  return ComplianceStatus.values.firstWhere(
    (value) => value.name == key,
    orElse: () => ComplianceStatus.raised,
  );
}

ComplianceConditionType _conditionType(String key) {
  return ComplianceConditionType.values.firstWhere(
    (value) => value.name == key,
    orElse: () => ComplianceConditionType.manual,
  );
}

extension JobLaneRecordSnapshot on JobLaneRecord {
  JobLaneSnapshot? toSnapshotOrNull() {
    final lane = MaintenanceLaneId.tryParse(laneKey);
    final remoteId = firestoreId;
    if (lane == null || remoteId == null || remoteId.isEmpty) return null;
    return JobLaneSnapshot(
      id: remoteId,
      workflowId: workflowFirestoreId,
      jobExecutionId: jobExecutionFirestoreId,
      lane: lane,
      status: _laneStatus(statusKey),
      activationGeneration: activationGeneration,
      version: version,
      progressRevision: progressRevision,
      gatingComplianceRequestId: gatingComplianceRequestId,
      representedLaneKey: representedLaneKey,
      delegationBasis: delegationBasis,
      acknowledgementDueAt: acknowledgementDueAt?.toUtc(),
    );
  }
}

extension WorkflowAggregateRecordSnapshot on WorkflowAggregateRecord {
  MaintenanceWorkflowSnapshot toSnapshot() => MaintenanceWorkflowSnapshot(
    id: firestoreId,
    jobExecutionId: jobExecutionFirestoreId,
    assetTypeKey: assetTypeKey,
    assetNumber: assetNumber,
    status: _workflowStatus(statusKey),
    version: version,
    laneSetVersion: laneSetVersion,
    laneSetFinalizedAt: laneSetFinalizedAt?.toUtc(),
    activeRedWork: activeRedWork,
    awaitingPreparation: awaitingPreparation,
    cancelled: cancelled,
    updatedAt: updatedAt.toUtc(),
  );
}

extension ComplianceRequestRecordSnapshot on ComplianceRequestRecord {
  ComplianceRequestSnapshot? toSnapshotOrNull() {
    final remoteId = firestoreId;
    final target = MaintenanceLaneId.tryParse(targetLaneKey);
    if (remoteId == null || target == null) return null;
    return ComplianceRequestSnapshot(
      id: remoteId,
      workflowId: linkedWorkflowId ?? linkedExecutionFirestoreId ?? '',
      originLane: MaintenanceLaneId.tryParse(originLaneKey),
      targetLane: target,
      title: title,
      description: description,
      status: _complianceStatus(statusKey),
      conditionType: _conditionType(conditionTypeKey),
      version: version,
      counterDepth: counterDepth,
      counterProposal: null,
      supersededById: supersededById,
      correctionCount: correctionCount,
      linkedMaintenanceId: linkedMaintenanceFirestoreId,
      gatesLaneId: gatesLaneFirestoreId,
      becameDueAt: becameDueAt?.toUtc(),
    );
  }
}
