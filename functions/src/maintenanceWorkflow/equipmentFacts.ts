import {EquipmentFacts, EquipmentProjection, assertEquipmentProjectionConsistent, deriveEquipmentState} from "./equipmentProjection";
import {WorkflowError} from "./errors";
import {JsonMap} from "./types";
import {WorkflowTransaction} from "./store";

const workflowIdFromPath = (path: string): string => path.split("/").pop() ?? path;

export interface LoadedEquipmentFacts extends Omit<EquipmentFacts, "operationsDeployed"> {}
export type WorkflowContribution = "none" | "nonRed" | "red" | "awaitingPreparation";

const projectionCounter = (
  current: JsonMap | null,
  field: keyof LoadedEquipmentFacts,
): number => {
  const value = current?.[field];
  if (value == null) return 0;
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
    return value;
  }
  throw new WorkflowError(
    "equipment-state-conflict",
    `Equipment projection counter ${field} is invalid.`,
    {field, value},
  );
};

export const equipmentFactsFromProjection = (
  current: JsonMap | null,
): LoadedEquipmentFacts => ({
  activeNonRedMaintenanceCount: projectionCounter(current, "activeNonRedMaintenanceCount"),
  activeRedWorkCount: projectionCounter(current, "activeRedWorkCount"),
  awaitingPreparationCount: projectionCounter(current, "awaitingPreparationCount"),
});

export const workflowContribution = (
  workflow: JsonMap,
): WorkflowContribution => {
  if (
    workflow.status === "completed" ||
    workflow.status === "cancelled" ||
    workflow.cancelled === true
  ) {
    return "none";
  }
  if (workflow.activeRedWork === true) return "red";
  if (workflow.awaitingPreparation === true) return "awaitingPreparation";
  return "nonRed";
};

export const withoutWorkflowContribution = (
  facts: LoadedEquipmentFacts,
  contribution: WorkflowContribution,
): LoadedEquipmentFacts => {
  if (contribution === "none") return facts;
  const field: keyof LoadedEquipmentFacts = contribution === "nonRed"
    ? "activeNonRedMaintenanceCount"
    : contribution === "red"
      ? "activeRedWorkCount"
      : "awaitingPreparationCount";
  if (facts[field] <= 0) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Equipment workflow counters are out of sync. Reconcile the equipment projection before retrying.",
      {field, facts},
    );
  }
  return {...facts, [field]: facts[field] - 1};
};

export const loadEquipmentFacts = async (
  tx: WorkflowTransaction,
  assetTypeKey: string,
  assetNumber: number,
  excludedWorkflowIds: readonly string[] = [],
): Promise<LoadedEquipmentFacts> => {
  const excluded = new Set(excludedWorkflowIds);
  const workflows = await tx.query("maintenance_workflows", [
    {field: "assetTypeKey", op: "==", value: assetTypeKey},
    {field: "assetNumber", op: "==", value: assetNumber},
  ]);
  let activeNonRedMaintenanceCount = 0;
  let activeRedWorkCount = 0;
  let awaitingPreparationCount = 0;
  for (const row of workflows) {
    if (excluded.has(workflowIdFromPath(row.path))) continue;
    const data = row.data ?? {};
    if (data.status === "completed" || data.status === "cancelled") continue;
    if (data.activeRedWork === true) activeRedWorkCount += 1;
    else if (data.awaitingPreparation === true) awaitingPreparationCount += 1;
    else activeNonRedMaintenanceCount += 1;
  }
  return {activeNonRedMaintenanceCount, activeRedWorkCount, awaitingPreparationCount};
};

export const withWorkflowContribution = (
  facts: LoadedEquipmentFacts,
  contribution: WorkflowContribution,
): LoadedEquipmentFacts => ({
  activeNonRedMaintenanceCount: facts.activeNonRedMaintenanceCount + (contribution === "nonRed" ? 1 : 0),
  activeRedWorkCount: facts.activeRedWorkCount + (contribution === "red" ? 1 : 0),
  awaitingPreparationCount: facts.awaitingPreparationCount + (contribution === "awaitingPreparation" ? 1 : 0),
});

export const projectEquipment = (
  facts: LoadedEquipmentFacts,
  operationsDeployed: boolean,
): EquipmentProjection => {
  const projection = deriveEquipmentState({...facts, operationsDeployed});
  assertEquipmentProjectionConsistent(projection);
  return projection;
};

export const equipmentProjectionWrite = (
  current: JsonMap | null,
  facts: LoadedEquipmentFacts,
  projection: EquipmentProjection,
  metadata: {
    readonly assetTypeKey: string;
    readonly assetNumber: number;
    readonly trigger: string;
    readonly at: string;
    readonly actorUid: string;
    readonly actorName: string;
  },
): JsonMap => ({
  assetTypeKey: metadata.assetTypeKey,
  assetNumber: metadata.assetNumber,
  previousState: current?.state ?? "inService",
  state: projection.state,
  activeNonRedMaintenanceCount: facts.activeNonRedMaintenanceCount,
  activeRedWorkCount: facts.activeRedWorkCount,
  awaitingPreparationCount: facts.awaitingPreparationCount,
  transitionTrigger: metadata.trigger,
  lastTransitionAt: metadata.at,
  lastTransitionByUid: metadata.actorUid,
  lastTransitionByName: metadata.actorName,
  availableSince: projection.state === "available" ? metadata.at : null,
  inServiceSince: projection.state === "inService" ? (current?.inServiceSince ?? metadata.at) : null,
  version: (typeof current?.version === "number" ? current.version : 0) + 1,
  updatedAt: metadata.at,
});
