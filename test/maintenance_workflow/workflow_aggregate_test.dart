import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_lane.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_aggregate.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_models.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:flutter_test/flutter_test.dart';

JobLaneSnapshot lane(MaintenanceLaneId id, WorkflowLaneStatus status, {int progress = 0}) => JobLaneSnapshot(
  id: id.value,
  workflowId: 'wf',
  jobExecutionId: 'exec',
  lane: id,
  status: status,
  activationGeneration: 1,
  version: 1,
  progressRevision: progress,
  gatingComplianceRequestId: null,
  representedLaneKey: null,
  delegationBasis: null,
  acknowledgementDueAt: null,
);

void main() {
  test('no active lanes means pending classification', () {
    expect(
      WorkflowAggregateDeriver.derive(
        lanes: const <JobLaneSnapshot>[],
        openBlockingComplianceCount: 0,
        completed: false,
        cancelled: false,
      ),
      WorkflowStatus.pendingLaneClassification,
    );
  });

  test('all lanes closed means ready for closure, not completed', () {
    final result = WorkflowAggregateDeriver.derive(
      lanes: [
        lane(MaintenanceLaneId.electrical, WorkflowLaneStatus.closed),
        lane(MaintenanceLaneId.mechanical, WorkflowLaneStatus.closed),
      ],
      openBlockingComplianceCount: 0,
      completed: false,
      cancelled: false,
    );
    expect(result, WorkflowStatus.readyForClosure);
  });
}
