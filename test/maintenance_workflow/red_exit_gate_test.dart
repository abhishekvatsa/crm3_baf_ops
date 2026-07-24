import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_lane.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/red_exit_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = RedExitGatePolicy();

  RedExitGateInput input(String asset, {bool? red, bool? prep}) => RedExitGateInput(
    isSubmissionThatWouldCompleteParent: true,
    activeLaneIds: <MaintenanceLaneId>{MaintenanceLaneId.electrical},
    equipmentTypeKey: asset,
    redWorkRequired: red,
    preparationRequired: prep,
  );

  test('force cooler and inner cover never receive RED prompt', () {
    expect(policy.evaluate(input('forceCooler')).action, RedExitGateAction.continueWithoutPrompt);
    expect(policy.evaluate(input('innerCover')).action, RedExitGateAction.continueWithoutPrompt);
  });

  test('base creates in-situ RED successor without preparation', () {
    final result = policy.evaluate(input('base', red: true, prep: true));
    expect(result.action, RedExitGateAction.closeParentCreateRedSuccessor);
    expect(result.createPreparationCompliance, isFalse);
  });

  test('furnace may enter awaiting preparation', () {
    final result = policy.evaluate(input('furnace', red: true, prep: true));
    expect(result.action, RedExitGateAction.closeParentCreateRedSuccessorWithPreparationCompliance);
  });
}
