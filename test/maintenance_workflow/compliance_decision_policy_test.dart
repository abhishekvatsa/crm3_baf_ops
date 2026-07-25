import 'package:crm3_baf_ops/features/maintenance_workflow/domain/compliance_decision_policy.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/compliance_models.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_lane.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:flutter_test/flutter_test.dart';

ComplianceRequestSnapshot request({
  ComplianceStatus status = ComplianceStatus.acknowledged,
  int counterDepth = 0,
  CounterConditionProposal? proposal,
}) => ComplianceRequestSnapshot(
  id: 'c1',
  workflowId: 'wf',
  originLane: MaintenanceLaneId.electrical,
  targetLane: MaintenanceLaneId.operations,
  title: 'Prepare furnace',
  description: 'Place on stand',
  status: status,
  conditionType: ComplianceConditionType.manual,
  version: 1,
  counterDepth: counterDepth,
  counterProposal: proposal,
  supersededById: null,
  correctionCount: 0,
  linkedMaintenanceId: 'm1',
  gatesLaneId: null,
  becameDueAt: null,
);

void main() {
  const policy = ComplianceDecisionPolicy();

  test('only one counter-condition is allowed', () {
    expect(policy.mayProposeCounter(request()), isTrue);
    expect(policy.mayProposeCounter(request(counterDepth: 1)), isFalse);
  });

  test('return for correction returns complied request to acknowledged', () {
    expect(
      policy.statusAfterReturnForCorrection(request(status: ComplianceStatus.complied)),
      ComplianceStatus.acknowledged,
    );
  });

  test('accepted counter supersedes original and creates successor', () {
    expect(policy.originalStatusAfterCounterDecision(CounterDecision.accept), ComplianceStatus.superseded);
    expect(policy.shouldCreateSuccessor(CounterDecision.accept), isTrue);
  });
}
