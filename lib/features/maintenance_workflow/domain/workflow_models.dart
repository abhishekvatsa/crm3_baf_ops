import 'maintenance_lane.dart';
import 'workflow_types.dart';

class JobLaneSnapshot {
  final String id;
  final String workflowId;
  final String jobExecutionId;
  final MaintenanceLaneId lane;
  final WorkflowLaneStatus status;
  final int activationGeneration;
  final int version;
  final int progressRevision;
  final String? gatingComplianceRequestId;
  final String? representedLaneKey;
  final String? delegationBasis;
  final DateTime? acknowledgementDueAt;

  const JobLaneSnapshot({
    required this.id,
    required this.workflowId,
    required this.jobExecutionId,
    required this.lane,
    required this.status,
    required this.activationGeneration,
    required this.version,
    required this.progressRevision,
    required this.gatingComplianceRequestId,
    required this.representedLaneKey,
    required this.delegationBasis,
    required this.acknowledgementDueAt,
  });

  bool get isActive => status != WorkflowLaneStatus.removed && status != WorkflowLaneStatus.terminated;
  bool get isAcknowledged => status == WorkflowLaneStatus.acknowledged || status == WorkflowLaneStatus.closed;
  bool get isClosed => status == WorkflowLaneStatus.closed;
}

class MaintenanceWorkflowSnapshot {
  final String id;
  final String jobExecutionId;
  final String assetTypeKey;
  final int assetNumber;
  final WorkflowStatus status;
  final int version;
  final int laneSetVersion;
  final DateTime? laneSetFinalizedAt;
  final bool activeRedWork;
  final bool awaitingPreparation;
  final bool cancelled;
  final DateTime updatedAt;

  const MaintenanceWorkflowSnapshot({
    required this.id,
    required this.jobExecutionId,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.status,
    required this.version,
    required this.laneSetVersion,
    required this.laneSetFinalizedAt,
    required this.activeRedWork,
    required this.awaitingPreparation,
    required this.cancelled,
    required this.updatedAt,
  });

  bool get laneSetFinalized => laneSetFinalizedAt != null;
  bool get isFinal => status == WorkflowStatus.completed || status == WorkflowStatus.cancelled;
}

class WorkflowAggregateSnapshot {
  final MaintenanceWorkflowSnapshot workflow;
  final List<JobLaneSnapshot> lanes;
  final int openBlockingComplianceCount;

  const WorkflowAggregateSnapshot({
    required this.workflow,
    required this.lanes,
    required this.openBlockingComplianceCount,
  });

  Iterable<JobLaneSnapshot> get activeLanes => lanes.where((lane) => lane.isActive);
  bool get fullyAcknowledged => activeLanes.isNotEmpty && activeLanes.every((lane) => lane.isAcknowledged);
  bool get allLanesClosed => activeLanes.isNotEmpty && activeLanes.every((lane) => lane.isClosed);
}
