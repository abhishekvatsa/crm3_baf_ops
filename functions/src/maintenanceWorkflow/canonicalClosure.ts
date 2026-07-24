import {
  assertClosureReady,
  buildClosureAttestation,
  ClosureValidationError,
  executionAuditMap,
  mergeAttestationIntoMetadata,
  modulePopulationVersionFromExecution,
  JsonMap as ClosureJsonMap,
} from "../plannedJobClosure";
import {WorkflowError, WorkflowErrorCode} from "./errors";
import {WorkflowTransaction} from "./store";
import {Actor, JsonMap} from "./types";

export interface CanonicalClosurePlan {
  readonly modules: readonly ClosureJsonMap[];
  readonly attestationHash: string;
  readonly executionUpdate: JsonMap;
  readonly auditPath: string;
  readonly auditData: JsonMap;
}

const moduleIdFromPath = (path: string): string => path.split("/").at(-1) ?? path;

const closureCode = (code: string): WorkflowErrorCode => {
  switch (code) {
  case "unauthenticated":
  case "permission-denied":
  case "invalid-argument":
  case "not-found":
  case "already-exists":
  case "failed-precondition":
  case "aborted":
    return code;
  default:
    return "failed-precondition";
  }
};

const asWorkflowError = (error: unknown): never => {
  if (error instanceof ClosureValidationError) {
    throw new WorkflowError(
      closureCode(error.code),
      error.message,
      (error.details ?? {}) as JsonMap,
    );
  }
  throw error;
};


export const assertCanonicalLaneClosureReady = async (args: {
  tx: WorkflowTransaction;
  executionId: string;
  workflowLaneFirestoreId: string;
}): Promise<{moduleCount: number}> => {
  const rows = await args.tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: args.executionId},
    {field: "workflowLaneFirestoreId", op: "==", value: args.workflowLaneFirestoreId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  const modules: ClosureJsonMap[] = rows
    .filter((row) => row.data != null)
    .map((row) => ({
      ...(row.data as unknown as ClosureJsonMap),
      firestoreId: typeof row.data?.firestoreId === "string"
        ? row.data.firestoreId
        : moduleIdFromPath(row.path),
    }));
  const open = modules.filter((module) => module.isOpenForWork === true);
  if (open.length > 0) {
    throw new WorkflowError("lane-not-ready-to-close", "Lane still has open modules.", {
      moduleFirestoreIds: open
        .map((module) => module.firestoreId)
        .filter((value): value is string => typeof value === "string"),
    });
  }
  try {
    assertClosureReady(modules);
  } catch (error) {
    return asWorkflowError(error);
  }
  return {moduleCount: modules.length};
};

export const buildCanonicalClosurePlan = async (args: {
  tx: WorkflowTransaction;
  executionId: string;
  workflowAggregateId: string;
  execution: JsonMap;
  actor: Actor;
  completedAt: string;
  nextExecutionVersion: number;
  remarks?: string | null;
  teamsInvolved?: readonly string[];
  responsesJson?: string;
  actionsJson?: string;
}): Promise<CanonicalClosurePlan> => {
  const rows = await args.tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: args.executionId},
    {field: "isDeleted", op: "==", value: false},
  ]);
  const modules: ClosureJsonMap[] = rows
    .filter((row) => row.data != null)
    .map((row) => ({
      ...(row.data as unknown as ClosureJsonMap),
      firestoreId: typeof row.data?.firestoreId === "string"
        ? row.data.firestoreId
        : moduleIdFromPath(row.path),
    }));

  try {
    const guardIssueCounts = assertClosureReady(modules);
    const modulePopulationVersion = modulePopulationVersionFromExecution(
      args.execution as unknown as ClosureJsonMap,
    );
    const attestation = buildClosureAttestation({
      executionFirestoreId: args.executionId,
      modules,
      completedByUid: args.actor.uid,
      completedByName: args.actor.name,
      completedAt: args.completedAt,
      executionVersionAtCompletion: args.nextExecutionVersion,
      modulePopulationVersionAtCompletion: modulePopulationVersion,
      guardIssueCounts,
    });
    const metadataJson = mergeAttestationIntoMetadata(
      args.execution.metadataJson,
      attestation,
    );
    const executionUpdate: JsonMap = {
      isCompleted: true,
      completedAt: args.completedAt,
      completedByUid: args.actor.uid,
      completedByName: args.actor.name,
      metadataJson,
      updatedAt: args.completedAt,
      version: args.nextExecutionVersion,
      modulePopulationVersion,
      modulePopulationSchemaVersion: 1,
      ...(args.remarks !== undefined ? {remarks: args.remarks} : {}),
      ...(args.teamsInvolved !== undefined ? {teamsInvolved: args.teamsInvolved} : {}),
      ...(args.responsesJson !== undefined ? {responsesJson: args.responsesJson} : {}),
      ...(args.actionsJson !== undefined ? {actionsJson: args.actionsJson} : {}),
    };
    const beforeAudit = executionAuditMap(
      args.execution as unknown as ClosureJsonMap,
      args.executionId,
    );
    const afterAudit = executionAuditMap(
      {...args.execution, ...executionUpdate} as unknown as ClosureJsonMap,
      args.executionId,
      attestation.hash,
    );
    return {
      modules,
      attestationHash: attestation.hash,
      executionUpdate,
      auditPath: `audit_logs/server_closure_${args.executionId}_${args.nextExecutionVersion}`,
      auditData: {
        entityType: "execution",
        entityId: args.executionId,
        action: "resolve",
        performedByUid: args.actor.uid,
        performedByName: args.actor.name,
        timestamp: args.completedAt,
        reason: null,
        reasonNotes: "Unified workflow closure validated all canonical remote modules and workflow gates.",
        summary: "Planned job completed by unified workflow closure enforcement",
        severity: "medium",
        beforeJson: JSON.stringify(beforeAudit),
        afterJson: JSON.stringify(afterAudit),
        workflowAggregateId: args.workflowAggregateId,
        closureAttestationHash: attestation.hash,
      },
    };
  } catch (error) {
    return asWorkflowError(error);
  }
};
