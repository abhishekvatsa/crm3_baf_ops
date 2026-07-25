import 'workflow_types.dart';

class EquipmentProjectionFacts {
  final int activeNonRedMaintenanceCount;
  final int activeRedWorkCount;
  final int awaitingPreparationCount;
  final bool operationsDeployed;

  const EquipmentProjectionFacts({
    required this.activeNonRedMaintenanceCount,
    required this.activeRedWorkCount,
    required this.awaitingPreparationCount,
    required this.operationsDeployed,
  });
}

class EquipmentProjectionResult {
  final EquipmentWorkflowState state;
  final List<String> conflicts;

  const EquipmentProjectionResult({required this.state, required this.conflicts});

  bool get isConsistent => conflicts.isEmpty;
}

class EquipmentProjectionPolicy {
  const EquipmentProjectionPolicy();

  EquipmentProjectionResult derive(EquipmentProjectionFacts facts) {
    final conflicts = <String>[];
    if (facts.activeRedWorkCount > 0 && facts.awaitingPreparationCount > 0) {
      conflicts.add('red-active-and-awaiting-preparation');
    }
    if (facts.operationsDeployed &&
        (facts.activeNonRedMaintenanceCount > 0 ||
            facts.activeRedWorkCount > 0 ||
            facts.awaitingPreparationCount > 0)) {
      conflicts.add('deployed-with-open-work');
    }

    final EquipmentWorkflowState state;
    if (facts.awaitingPreparationCount > 0 && facts.activeRedWorkCount == 0) {
      state = EquipmentWorkflowState.awaitingPreparation;
    } else if (facts.activeRedWorkCount > 0) {
      state = EquipmentWorkflowState.underRED;
    } else if (facts.activeNonRedMaintenanceCount > 0) {
      state = EquipmentWorkflowState.underMaintenance;
    } else if (facts.operationsDeployed) {
      state = EquipmentWorkflowState.inService;
    } else {
      state = EquipmentWorkflowState.available;
    }

    return EquipmentProjectionResult(
      state: state,
      conflicts: List.unmodifiable(conflicts),
    );
  }
}
