import 'package:crm3_baf_ops/features/maintenance_workflow/domain/equipment_projection_policy.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = EquipmentProjectionPolicy();

  test('awaiting preparation is physically explicit', () {
    final result = policy.derive(const EquipmentProjectionFacts(
      activeNonRedMaintenanceCount: 0,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 1,
      operationsDeployed: false,
    ));
    expect(result.state, EquipmentWorkflowState.awaitingPreparation);
    expect(result.isConsistent, isTrue);
  });

  test('deployed with open work is flagged', () {
    final result = policy.derive(const EquipmentProjectionFacts(
      activeNonRedMaintenanceCount: 1,
      activeRedWorkCount: 0,
      awaitingPreparationCount: 0,
      operationsDeployed: true,
    ));
    expect(result.conflicts, contains('deployed-with-open-work'));
  });
}
