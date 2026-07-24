import 'maintenance_lane.dart';
import 'workflow_types.dart';

class CounterConditionProposal {
  final String revisedDescription;
  final String proposedByUid;
  final String proposedByName;
  final DateTime proposedAt;

  const CounterConditionProposal({
    required this.revisedDescription,
    required this.proposedByUid,
    required this.proposedByName,
    required this.proposedAt,
  });
}

class ComplianceRequestSnapshot {
  final String id;
  final String workflowId;
  final MaintenanceLaneId? originLane;
  final MaintenanceLaneId targetLane;
  final String title;
  final String description;
  final ComplianceStatus status;
  final ComplianceConditionType conditionType;
  final int version;
  final int counterDepth;
  final CounterConditionProposal? counterProposal;
  final String? supersededById;
  final int correctionCount;
  final String? linkedMaintenanceId;
  final String? gatesLaneId;
  final DateTime? becameDueAt;

  const ComplianceRequestSnapshot({
    required this.id,
    required this.workflowId,
    required this.originLane,
    required this.targetLane,
    required this.title,
    required this.description,
    required this.status,
    required this.conditionType,
    required this.version,
    required this.counterDepth,
    required this.counterProposal,
    required this.supersededById,
    required this.correctionCount,
    required this.linkedMaintenanceId,
    required this.gatesLaneId,
    required this.becameDueAt,
  });

  bool get isOpen => status != ComplianceStatus.confirmedClosed && status != ComplianceStatus.superseded && status != ComplianceStatus.cancelled;
}
