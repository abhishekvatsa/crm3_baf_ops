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
export type WorkflowKind = "plannedMaintenance" | "issueCoordination";
export type ComplianceStatus =
  | "raised" | "acknowledged" | "complied" | "confirmedClosed"
  | "superseded" | "cancelled";
export type EquipmentState =
  | "inService" | "underMaintenance" | "awaitingPreparation"
  | "underRED" | "available";
export type ComplianceConditionType = "manual" | "chargeComplete" | "activityRef";
export type CompliancePurpose = "assurance" | "deferment" | "operationsSupport";
export type DefermentBasis =
  | "ongoingCycle" | "equipmentRequired" | "operationalCompliance"
  | "safetyConstraint" | "qualityConstraint" | "other";
export type OperationsSupportType =
  | "craneMovement" | "assetRelocation" | "isolation"
  | "processPreparation" | "utilitySupport" | "accessOrPermit" | "other";
export type OperationsResource =
  | "crane" | "transferCar" | "operationsCrew" | "utilities" | "other";

export interface Actor {
  readonly uid: string;
  readonly name: string;
  readonly roles: ReadonlySet<RoleKey>;
}

export interface CommandActorIdentity {
  readonly uid: string;
  readonly name: string;
}

export interface WorkflowCommand {
  readonly commandId: string;
  readonly commandType: WorkflowCommandType;
  readonly aggregateId: string;
  readonly expectedVersion: number;
  readonly payload: JsonMap;
}

export type WorkflowAuthorityCapability =
  | "lane.acknowledge" | "lane.work" | "lane.close"
  | "compliance.raise"
  | "ticket.create" | "ticket.acknowledge" | "ticket.complete"
  | "ticket.lanes.manage" | "ticket.reopen" | "ticket.correct"
  | "laneSet.finalize" | "lanePopulation.manage" | "workflow.cancel"
  | "condition.markDue" | "redLane.prepare" | "workflowModule.reopen"
  | "job.finalize" | "equipment.deploy" | "equipment.reconcile"
  | "compliance.unscoped.manage"
  | "issueDefinition.manage"
  | "maintenanceClass.manage" | "maintenance.classify" | "maintenancePlan.manage"
  | "maintenanceHistory.record"
  | "inspectionDefinition.manage" | "inspectionCampaign.manage"
  | "inspection.observe" | "inspectionIssue.link"
  | "inspectionFinding.adjudicate"
  | "integrity.supervise" | "integrity.adjudicate";

export interface WorkflowAuthorityScope extends JsonMap {
  readonly schemaVersion: 1;
  readonly capability: WorkflowAuthorityCapability;
  readonly laneKey?: LaneKey;
}

export type WorkflowCommandType =
  | "createLegacyWorkflowJob" | "createMaintenanceTicket"
  | "startIssueCoordination"
  | "upsertFrequentIssueDefinition" | "setFrequentIssueDefinitionStatus"
  | "upsertMaintenanceClassDefinition" | "setMaintenanceClassDefinitionStatus"
  | "classifyMaintenanceExecution" | "classifyMaintenanceTicket"
  | "recordHistoricalMaintenance"
  | "upsertMaintenancePlan" | "setMaintenancePlanStatus" | "completeMaintenancePlan"
  | "upsertInspectionDefinition" | "setInspectionDefinitionStatus"
  | "createInspectionCampaign" | "setInspectionCampaignStatus"
  | "addInspectionCampaignTargets" | "setInspectionTargetDisposition"
  | "recordInspectionObservation" | "linkInspectionObservationIssue"
  | "verifyInspectionFinding" | "adjudicateInspectionFinding"
  | "finalizeLaneSet" | "acknowledgeLane" | "addLane" | "removeLane"
  | "terminateLane" | "closeLane" | "cancelWorkflow"
  | "raiseCompliance" | "acknowledgeCompliance"
  | "confirmConditionAndReactivate" | "markComplianceComplied"
  | "returnComplianceForCorrection" | "confirmComplianceClosed"
  | "proposeCounterCondition" | "decideCounterCondition"
  | "prepareRedLane" | "reopenWorkflowModule" | "finalizeJob"
  | "deployEquipment" | "reconcileEquipment"
  | "acknowledgeMaintenanceTicket" | "completeMaintenanceTicketLane"
  | "reconfigureMaintenanceTicketLanes" | "resolveMaintenanceTicket"
  | "reopenMaintenanceTicket"
  | "correctMaintenanceTicket"
  | "releaseFurnaceStuckup" | "adjudicateFurnaceStuckup";

export interface WorkflowCommandReceipt {
  readonly commandId: string;
  readonly resultKey: string;
  readonly aggregateVersion: number;
  readonly result: JsonMap;
  readonly appliedAt: string;
}

export interface StoredWorkflowCommandReceipt extends JsonMap {
  readonly receiptSchemaVersion: 2;
  readonly commandId: string;
  readonly commandType: WorkflowCommandType;
  readonly aggregateId: string;
  readonly actorUid: string;
  readonly authorityScope: WorkflowAuthorityScope;
  readonly payloadFingerprint: string;
  readonly resultKey: string;
  readonly aggregateVersion: number;
  readonly result: JsonMap;
  readonly appliedAt: string;
}

export interface WorkflowDoc extends JsonMap {
  readonly jobExecutionId?: string;
  readonly workflowKind?: WorkflowKind;
  readonly status?: WorkflowStatus;
  readonly version?: number;
  readonly assetTypeKey?: string;
  readonly assetNumber?: number;
  readonly assetClassId?: string;
  readonly assetInstanceId?: string;
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
  readonly requestPurposeKey?: CompliancePurpose;
  readonly defermentBasisKey?: DefermentBasis | null;
  readonly operationsSupportTypeKey?: OperationsSupportType | null;
  readonly operationsResourceKey?: OperationsResource | null;
  readonly requestedLocation?: string | null;
  readonly raisedUnderCoordination?: boolean;
  readonly coordinationBasis?: string | null;
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

export interface CommandInvocationContext {
  readonly actor: CommandActorIdentity;
  readonly serverNow: Date;
}
