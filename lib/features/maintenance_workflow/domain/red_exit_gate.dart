import 'maintenance_lane.dart';
import 'workflow_error.dart';
import 'workflow_policy.dart';

enum RedExitGateAction {
  continueWithoutPrompt,
  promptRedRequirement,
  promptPreparationRequirement,
  closeParentWithoutRed,
  closeParentCreateRedSuccessor,
  closeParentCreateRedSuccessorWithPreparationCompliance,
}

class RedExitGateInput {
  final bool isSubmissionThatWouldCompleteParent;
  final Set<MaintenanceLaneId> activeLaneIds;
  final String equipmentTypeKey;
  final bool? redWorkRequired;
  final bool? preparationRequired;

  RedExitGateInput({
    required this.isSubmissionThatWouldCompleteParent,
    required Iterable<MaintenanceLaneId> activeLaneIds,
    required String equipmentTypeKey,
    required this.redWorkRequired,
    required this.preparationRequired,
  }) : activeLaneIds = Set.unmodifiable(activeLaneIds),
       equipmentTypeKey = equipmentTypeKey.trim();
}

class RedExitGateDecision {
  final RedExitGateAction action;
  final bool createRedSuccessor;
  final bool createPreparationCompliance;

  const RedExitGateDecision({
    required this.action,
    required this.createRedSuccessor,
    required this.createPreparationCompliance,
  });
}

class RedExitGatePolicy {
  const RedExitGatePolicy();

  RedExitGateDecision evaluate(RedExitGateInput input) {
    if (input.redWorkRequired == false && input.preparationRequired == true) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'Preparation cannot be required when RED work is not required.',
      );
    }
    if (!input.isSubmissionThatWouldCompleteParent) {
      return const RedExitGateDecision(
        action: RedExitGateAction.continueWithoutPrompt,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    if (!WorkflowPolicy.isRedApplicable(input.equipmentTypeKey)) {
      return const RedExitGateDecision(
        action: RedExitGateAction.continueWithoutPrompt,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    if (input.activeLaneIds.contains(MaintenanceLaneId.refractory)) {
      return const RedExitGateDecision(
        action: RedExitGateAction.continueWithoutPrompt,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    if (input.redWorkRequired == null) {
      return const RedExitGateDecision(
        action: RedExitGateAction.promptRedRequirement,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    if (input.redWorkRequired == false) {
      return const RedExitGateDecision(
        action: RedExitGateAction.closeParentWithoutRed,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    final standQuestion = WorkflowPolicy.requiresStandPreparationQuestion(input.equipmentTypeKey);
    if (standQuestion && input.preparationRequired == null) {
      return const RedExitGateDecision(
        action: RedExitGateAction.promptPreparationRequirement,
        createRedSuccessor: false,
        createPreparationCompliance: false,
      );
    }
    if (standQuestion && input.preparationRequired == true) {
      return const RedExitGateDecision(
        action: RedExitGateAction.closeParentCreateRedSuccessorWithPreparationCompliance,
        createRedSuccessor: true,
        createPreparationCompliance: true,
      );
    }
    return const RedExitGateDecision(
      action: RedExitGateAction.closeParentCreateRedSuccessor,
      createRedSuccessor: true,
      createPreparationCompliance: false,
    );
  }
}
