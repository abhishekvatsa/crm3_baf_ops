export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonMap | readonly JsonValue[];
export interface JsonMap {readonly [key: string]: JsonValue | undefined;}

export type LaneKey = "elec" | "mech" | "inst" | "oprn" | "emd" | "red" | "shared";
export type RoleKey =
  | "admin" | "si" | "contractSupervisor" | "shiftSupervisor"
  | "operations" | "seniorElectrical" | "seniorMechanical"
  | "seniorInstrumentation" | "refractory" | "seniorRefractory";
export type AssetTypeKey = "base" | "furnace" | "forceCooler" | "innerCover" | string;
export type LaneStatus = "pending" | "acknowledged" | "closed" | "removed" | "terminated";
export type WorkflowStatus =
  | "pendingLaneClassification" | "assigned" | "partiallyAcknowledged"
  | "fullyAcknowledged" | "inProgress" | "awaitingCompliance"
  | "readyForClosure" | "completed" | "cancelled";
export type ComplianceStatus =
  | "raised" | "acknowledged" | "complied" | "confirmedClosed"
  | "superseded" | "cancelled";
export type EquipmentState =
  | "inService" | "underMaintenance" | "awaitingPreparation"
  | "underRED" | "available";
export type ComplianceConditionType = "manual" | "chargeComplete" | "activityRef";

export interface Actor {
  readonly uid: string;
  readonly name: string;
  readonly roles: ReadonlySet<RoleKey>;
}

export interface WorkflowCommand {
  readonly commandId: string;
  readonly commandType: WorkflowCommandType;
  readonly aggregateId: string;
  readonly expectedVersion: number;
  readonly payload: JsonMap;
}

export type WorkflowCommandType =
  | "createLegacyWorkflowJob"
  | "finalizeLaneSet" | "acknowledgeLane" | "addLane" | "removeLane"
  | "terminateLane" | "closeLane" | "cancelWorkflow"
  | "raiseCompliance" | "acknowledgeCompliance"
  | "confirmConditionAndReactivate" | "markComplianceComplied"
  | "returnComplianceForCorrection" | "confirmComplianceClosed"
  | "proposeCounterCondition" | "decideCounterCondition"
  | "prepareRedLane" | "reopenWorkflowModule" | "finalizeJob" | "deployEquipment" | "reconcileEquipment";

export interface WorkflowCommandReceipt {
  readonly commandId: string;
  readonly payloadHash: string;
  readonly resultKey: string;
  readonly aggregateVersion: number;
  readonly result: JsonMap;
  readonly appliedAt: string;
}

export interface WorkflowDoc extends JsonMap {
  readonly jobExecutionId?: string;
  readonly status?: WorkflowStatus;
  readonly version?: number;
  readonly assetTypeKey?: string;
  readonly assetNumber?: number;
  readonly laneSetFinalizedAt?: string | null;
  readonly cancelled?: boolean;
  readonly completedAt?: string | null;
  readonly activeRedWork?: boolean;
  readonly awaitingPreparation?: boolean;
  readonly laneSetVersion?: number;
}

export interface LaneDoc extends JsonMap {
  readonly workflowId?: string;
  readonly jobExecutionId?: string;
  readonly laneKey?: LaneKey;
  readonly status?: LaneStatus;
  readonly version?: number;
  readonly activationGeneration?: number;
  readonly progressRevision?: number;
  readonly gatingComplianceRequestId?: string | null;
}

export interface ComplianceDoc extends JsonMap {
  readonly status?: ComplianceStatus;
  readonly version?: number;
  readonly originLaneKey?: LaneKey | null;
  readonly targetLaneKey?: LaneKey;
  readonly conditionTypeKey?: ComplianceConditionType;
  readonly linkedMaintenanceFirestoreId?: string | null;
  readonly linkedExecutionFirestoreId?: string | null;
  readonly linkedLaneFirestoreId?: string | null;
  readonly gatesLaneFirestoreId?: string | null;
  readonly counterDepth?: number;
  readonly counterProposal?: JsonMap | null;
  readonly currentAttemptId?: string | null;
  readonly attemptCount?: number;
  readonly linkedWorkflowId?: string | null;
  readonly correctionCount?: number;
  readonly escalationTier?: number;
}

export interface CommandContext {
  readonly actor: Actor;
  readonly serverNow: Date;
}
