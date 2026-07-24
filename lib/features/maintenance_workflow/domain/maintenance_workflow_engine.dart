import 'lane_progress_evidence.dart';
import 'maintenance_lane.dart';
import 'workflow_actor.dart';
import 'workflow_aggregate.dart';
import 'workflow_error.dart';
import 'workflow_models.dart';
import 'workflow_policy.dart';
import 'workflow_types.dart';

/// Pure client-side preview engine.
///
/// It does not author server truth. It is used to render guards and expected
/// outcomes before an online-only command is sent to the authoritative backend.
class MaintenanceWorkflowPreviewEngine {
  const MaintenanceWorkflowPreviewEngine();

  WorkflowStatus evaluate(WorkflowAggregateSnapshot aggregate) =>
      WorkflowAggregateDeriver.derive(
        lanes: aggregate.lanes,
        openBlockingComplianceCount: aggregate.openBlockingComplianceCount,
        completed: aggregate.workflow.status == WorkflowStatus.completed,
        cancelled: aggregate.workflow.cancelled,
      );

  void assertMayFinalizeLaneSet({
    required WorkflowActorContext actor,
    required Iterable<MaintenanceLaneId> lanes,
  }) {
    if (!WorkflowPolicy.mayFinalizeLaneSet(actor)) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Only Admin, SI or Contract Supervisor may finalise the lane set.',
      );
    }
    final unique = lanes.toSet();
    if (unique.isEmpty) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'At least one lane is required at finalisation.',
      );
    }
    if (unique.length != lanes.length) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'The lane set contains duplicates.',
      );
    }
  }

  void assertMayAcknowledge({
    required WorkflowActorContext actor,
    required MaintenanceLaneId lane,
  }) {
    if (!WorkflowPolicy.lane(lane).mayAcknowledge(actor)) {
      throw WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Actor is not authorised to acknowledge ${lane.value}.',
      );
    }
  }

  void assertMayRemoveLane({
    required WorkflowActorContext actor,
    required LaneProgressEvidence evidence,
  }) {
    if (!WorkflowPolicy.mayManageLanePopulation(actor)) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Actor cannot change the lane population.',
      );
    }
    if (!evidence.mayRemove) {
      throw const WorkflowException(
        WorkflowErrorCode.laneProgressOpen,
        'This lane has protected progress and must be terminated instead.',
      );
    }
  }

  void assertMayTerminateLane({
    required WorkflowActorContext actor,
    required String reason,
  }) {
    if (!WorkflowPolicy.mayManageLanePopulation(actor)) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Actor cannot terminate a lane.',
      );
    }
    if (reason.trim().isEmpty) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'A termination reason is required.',
      );
    }
  }

  void assertMayCloseLane({
    required WorkflowActorContext actor,
    required JobLaneSnapshot lane,
    required bool hasOpenModules,
    required bool hasOpenBlockingCompliance,
  }) {
    if (!WorkflowPolicy.lane(lane.lane).mayClose(actor)) {
      throw WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Actor is not authorised to close ${lane.lane.value}.',
      );
    }
    if (!lane.isAcknowledged) {
      throw const WorkflowException(
        WorkflowErrorCode.laneAcknowledgementRequired,
        'Lane must be acknowledged before closure.',
      );
    }
    if (hasOpenModules) {
      throw const WorkflowException(
        WorkflowErrorCode.laneNotReadyToClose,
        'Lane still contains open modules.',
      );
    }
    if (hasOpenBlockingCompliance) {
      throw const WorkflowException(
        WorkflowErrorCode.blockingComplianceOpen,
        'Lane has unresolved blocking compliance.',
      );
    }
  }
}
