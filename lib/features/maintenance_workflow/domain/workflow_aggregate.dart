import 'workflow_models.dart';
import 'workflow_types.dart';

abstract final class WorkflowAggregateDeriver {
  static WorkflowStatus derive({
    required Iterable<JobLaneSnapshot> lanes,
    required int openBlockingComplianceCount,
    required bool completed,
    required bool cancelled,
  }) {
    if (cancelled) return WorkflowStatus.cancelled;
    if (completed) return WorkflowStatus.completed;
    final active = lanes.where((lane) => lane.isActive).toList(growable: false);
    if (active.isEmpty) return WorkflowStatus.pendingLaneClassification;
    final acknowledged = active.where((lane) => lane.isAcknowledged).length;
    final closed = active.where((lane) => lane.isClosed).length;
    if (acknowledged == 0) return WorkflowStatus.assigned;
    if (acknowledged < active.length) return WorkflowStatus.partiallyAcknowledged;
    if (openBlockingComplianceCount > 0) return WorkflowStatus.awaitingCompliance;
    if (closed == active.length) return WorkflowStatus.readyForClosure;
    if (active.any((lane) => lane.progressRevision > 0)) return WorkflowStatus.inProgress;
    return WorkflowStatus.fullyAcknowledged;
  }
}
