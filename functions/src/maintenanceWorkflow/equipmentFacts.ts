import {EquipmentFacts, EquipmentProjection, assertEquipmentProjectionConsistent, deriveEquipmentState} from "./equipmentProjection";
import {WorkflowError} from "./errors";
import {JsonMap} from "./types";
import {WorkflowTransaction} from "./store";
import {EquipmentIdentity, equipmentIdentity} from "./paths";

const workflowIdFromPath = (path: string): string => path.split("/").pop() ?? path;

export interface LoadedEquipmentFacts extends Omit<EquipmentFacts, "operationsDeployed"> {}
export type WorkflowContribution = "none" | "nonRed" | "red" | "awaitingPreparation";

const equipmentProjectionCounterFields: readonly (keyof LoadedEquipmentFacts)[] = [
  "activeNonRedMaintenanceCount",
  "activeRedWorkCount",
  "awaitingPreparationCount",
];

export const assertEquipmentProjectionIdentity = (
  current: JsonMap,
  identity: EquipmentIdentity,
): void => {
  if (identity.assetTypeKey === "governedCustom" &&
      (current.assetClassId !== identity.assetClassId ||
       current.assetInstanceId !== identity.assetInstanceId)) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "The governed equipment projection belongs to another physical asset.",
      {
        reasonCode: "equipment-projection-identity-mismatch",
        expectedAssetClassId: identity.assetClassId,
        expectedAssetInstanceId: identity.assetInstanceId,
        actualAssetClassId: current.assetClassId ?? null,
        actualAssetInstanceId: current.assetInstanceId ?? null,
      },
    );
  }
};

const projectionCounter = (
  current: JsonMap,
  field: keyof LoadedEquipmentFacts,
): number => {
  const value = current[field];
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
    return value;
  }
  throw new WorkflowError(
    "equipment-state-conflict",
    `Equipment projection counter ${field} is invalid.`,
    {reasonCode: "equipment-projection-counter-invalid", field, value},
  );
};

export const equipmentFactsFromProjection = (
  current: JsonMap | null,
  identity?: EquipmentIdentity,
): LoadedEquipmentFacts => {
  if (current == null) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Equipment projection is missing. Reconcile it before mutating workflows.",
      {reasonCode: "equipment-projection-missing"},
    );
  }
  const missingFields = equipmentProjectionCounterFields.filter(
    (field) => !Object.prototype.hasOwnProperty.call(current, field),
  );
  if (missingFields.length > 0) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Equipment projection counter set is incomplete. Reconcile it before mutating workflows.",
      {
        reasonCode: "equipment-projection-counter-set-incomplete",
        missingFields,
      },
    );
  }
  if (identity != null) assertEquipmentProjectionIdentity(current, identity);
  return {
    activeNonRedMaintenanceCount: projectionCounter(
      current,
      "activeNonRedMaintenanceCount",
    ),
    activeRedWorkCount: projectionCounter(current, "activeRedWorkCount"),
    awaitingPreparationCount: projectionCounter(
      current,
      "awaitingPreparationCount",
    ),
  };
};

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
  identity: EquipmentIdentity,
  excludedWorkflowIds: readonly string[] = [],
): Promise<LoadedEquipmentFacts> => {
  const excluded = new Set(excludedWorkflowIds);
  const workflows = await tx.query("maintenance_workflows", [
    {field: "assetTypeKey", op: "==", value: identity.assetTypeKey},
    {field: "assetNumber", op: "==", value: identity.assetNumber},
  ]);
  let activeNonRedMaintenanceCount = 0;
  let activeRedWorkCount = 0;
  let awaitingPreparationCount = 0;
  for (const row of workflows) {
    if (excluded.has(workflowIdFromPath(row.path))) continue;
    const data = row.data ?? {};
    if (identity.assetTypeKey === "governedCustom") {
      const assetClassId = typeof data.assetClassId === "string" && data.assetClassId.trim().length > 0
        ? data.assetClassId.trim()
        : null;
      const assetInstanceId = typeof data.assetInstanceId === "string" && data.assetInstanceId.trim().length > 0
        ? data.assetInstanceId.trim()
        : null;
      if (assetClassId == null || assetInstanceId == null) {
        throw new WorkflowError(
          "equipment-state-conflict",
          "A governed custom workflow has no physical asset identity.",
          {
            reasonCode: "custom-workflow-identity-incomplete",
            workflowId: workflowIdFromPath(row.path),
          },
        );
      }
      if (assetClassId !== identity.assetClassId || assetInstanceId !== identity.assetInstanceId) {
        continue;
      }
    }
    if (data.status === "completed" || data.status === "cancelled" || data.cancelled === true) continue;
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
    readonly assetClassId?: string | null;
    readonly assetInstanceId?: string | null;
    readonly trigger: string;
    readonly at: string;
    readonly actorUid: string;
    readonly actorName: string;
  },
): JsonMap => {
  const identity = equipmentIdentity(
    metadata.assetTypeKey,
    metadata.assetNumber,
    metadata.assetClassId,
    metadata.assetInstanceId,
  );
  if (current != null) assertEquipmentProjectionIdentity(current, identity);
  return {
    assetTypeKey: identity.assetTypeKey,
    assetNumber: identity.assetNumber,
    ...(identity.assetTypeKey === "governedCustom" ? {
      assetClassId: identity.assetClassId,
      assetInstanceId: identity.assetInstanceId,
    } : {}),
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
  };
};
