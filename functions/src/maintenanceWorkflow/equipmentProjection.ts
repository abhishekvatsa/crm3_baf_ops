import {EquipmentState, JsonMap} from "./types";
import {WorkflowError} from "./errors";

export interface EquipmentFacts {
  readonly activeNonRedMaintenanceCount: number;
  readonly activeRedWorkCount: number;
  readonly awaitingPreparationCount: number;
  readonly operationsDeployed: boolean;
}

export interface EquipmentProjection {
  readonly state: EquipmentState;
  readonly conflicts: readonly string[];
  readonly counts: JsonMap;
}

export const deriveEquipmentState = (facts: EquipmentFacts): EquipmentProjection => {
  const conflicts: string[] = [];
  if (facts.operationsDeployed &&
      (facts.activeNonRedMaintenanceCount > 0 || facts.activeRedWorkCount > 0 || facts.awaitingPreparationCount > 0)) {
    conflicts.push("deployed-with-open-work");
  }
  let state: EquipmentState;
  if (facts.activeRedWorkCount > 0) state = "underRED";
  else if (facts.awaitingPreparationCount > 0) state = "awaitingPreparation";
  else if (facts.activeNonRedMaintenanceCount > 0) state = "underMaintenance";
  else state = facts.operationsDeployed ? "inService" : "available";
  return {state, conflicts, counts: {
    activeNonRedMaintenanceCount: facts.activeNonRedMaintenanceCount,
    activeRedWorkCount: facts.activeRedWorkCount,
    awaitingPreparationCount: facts.awaitingPreparationCount,
  }};
};

export const assertEquipmentProjectionConsistent = (projection: EquipmentProjection): void => {
  if (projection.conflicts.length > 0) {
    throw new WorkflowError("equipment-state-conflict", "Equipment workflow facts are contradictory.", {
      conflicts: projection.conflicts,
    });
  }
};
