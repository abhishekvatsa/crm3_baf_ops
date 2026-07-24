import 'package:crm3_baf_ops/features/maintenance_workflow/domain/lane_progress_evidence.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_lane.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_workflow_engine.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_actor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = MaintenanceWorkflowPreviewEngine();

  test('Admin can finalise lane set', () {
    expect(
      () => engine.assertMayFinalizeLaneSet(
        actor: WorkflowActorContext(uid: 'a', displayName: 'A', roleKeys: const ['admin']),
        lanes: const [MaintenanceLaneId.electrical],
      ),
      returnsNormally,
    );
  });

  test('acknowledged untouched lane may be removed', () {
    expect(
      () => engine.assertMayRemoveLane(
        actor: WorkflowActorContext(uid: 'a', displayName: 'A', roleKeys: const ['admin']),
        evidence: const LaneProgressEvidence(acknowledged: true),
      ),
      returnsNormally,
    );
  });
}
