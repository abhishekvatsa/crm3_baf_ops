import {WorkflowError} from "./errors";
import {JsonMap} from "./types";

export const workflowPath = (id: string): string => `maintenance_workflows/${id}`;
export const lanePath = (workflowId: string, laneKey: string, generation = 1): string =>
  `job_lanes/${workflowId}_${laneKey}_${generation}`;
export const compliancePath = (id: string): string => `compliance_requests/${id}`;
export const complianceAttemptPath = (complianceId: string, attemptNumber: number): string =>
  `compliance_attempts/${complianceId}_${attemptNumber}`;
export interface EquipmentIdentity {
  readonly assetTypeKey: string;
  readonly assetNumber: number;
  readonly assetClassId: string | null;
  readonly assetInstanceId: string | null;
}

const identityText = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const cleaned = value.trim();
  if (cleaned.length === 0 || cleaned === "." || cleaned === ".." || cleaned.includes("/")) {
    return null;
  }
  return cleaned;
};

export const equipmentIdentity = (
  assetTypeKey: string,
  assetNumber: number,
  assetClassId: unknown = null,
  assetInstanceId: unknown = null,
): EquipmentIdentity => {
  const custom = assetTypeKey === "governedCustom";
  const parsedClassId = identityText(assetClassId);
  const parsedInstanceId = identityText(assetInstanceId);
  if ((parsedClassId == null) !== (parsedInstanceId == null)) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Equipment registry identity is incomplete.",
      {reasonCode: "equipment-registry-identity-incomplete"},
    );
  }
  if (custom && parsedClassId == null) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Governed custom equipment identity is incomplete.",
      {reasonCode: "custom-equipment-identity-incomplete"},
    );
  }
  return {
    assetTypeKey,
    assetNumber,
    assetClassId: parsedClassId,
    assetInstanceId: parsedInstanceId,
  };
};

export const equipmentIdentityFromWorkflow = (
  workflow: JsonMap,
): EquipmentIdentity => {
  const assetTypeKey = identityText(workflow.assetTypeKey);
  const assetNumber = workflow.assetNumber;
  if (assetTypeKey == null || !Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "Workflow asset identity is invalid.",
      {reasonCode: "workflow-equipment-identity-invalid"},
    );
  }
  return equipmentIdentity(
    assetTypeKey,
    assetNumber as number,
    workflow.assetClassId,
    workflow.assetInstanceId,
  );
};

export const equipmentDocumentIdForIdentity = (identity: EquipmentIdentity): string =>
  identity.assetTypeKey === "governedCustom"
    ? `governedCustom_${identity.assetClassId}_${identity.assetInstanceId}`
    : `${identity.assetTypeKey}_${identity.assetNumber}`;

export const equipmentPathForIdentity = (identity: EquipmentIdentity): string =>
  `equipment_status/${equipmentDocumentIdForIdentity(identity)}`;

export const equipmentPath = (
  assetTypeKey: string,
  assetNumber: number,
  assetClassId: unknown = null,
  assetInstanceId: unknown = null,
): string => equipmentPathForIdentity(
  equipmentIdentity(assetTypeKey, assetNumber, assetClassId, assetInstanceId),
);
export const maintenancePath = (id: string): string => `maintenance_records/${id}`;
export const executionPath = (id: string): string => `job_executions/${id}`;
