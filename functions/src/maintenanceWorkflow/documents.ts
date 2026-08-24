import {WorkflowTransaction} from "./store";
import {ComplianceDoc, LaneDoc, WorkflowDoc} from "./types";
import {compliancePath, executionPath} from "./paths";
import {WorkflowError} from "./errors";
import {workflowPath} from "./paths";

export const requireWorkflow = async (tx: WorkflowTransaction, id: string): Promise<WorkflowDoc> => {
  const snap = await tx.get<WorkflowDoc>(workflowPath(id));
  if (!snap.exists || snap.data == null) throw new WorkflowError("not-found", `Workflow ${id} was not found.`);
  return snap.data;
};

export const assertExpectedVersion = (doc: {readonly version?: number}, expected: number): number => {
  const version = typeof doc.version === "number" ? doc.version : 0;
  if (version !== expected) {
    throw new WorkflowError("workflow-version-conflict", "The workflow changed before this command was applied.", {
      expectedVersion: expected,
      actualVersion: version,
    });
  }
  return version;
};

export const activeLanes = async (tx: WorkflowTransaction, workflowId: string): Promise<readonly LaneDoc[]> => {
  const rows = await tx.query<LaneDoc>("job_lanes", [{field: "workflowId", op: "==", value: workflowId}]);
  return rows.map((r) => r.data).filter((d): d is LaneDoc => d != null && d.status !== "removed" && d.status !== "terminated");
};

export const openBlockingCompliance = async (tx: WorkflowTransaction, workflowId: string): Promise<readonly ComplianceDoc[]> => {
  const rows = await tx.query<ComplianceDoc>("compliance_requests", [{field: "linkedWorkflowId", op: "==", value: workflowId}]);
  return rows.map((r) => r.data).filter((d): d is ComplianceDoc => {
    if (d == null || d.gatesLaneFirestoreId == null) return false;
    return d.status !== "confirmedClosed" && d.status !== "cancelled" && d.status !== "superseded";
  });
};


export const assertWorkflowMutable = (workflow: WorkflowDoc): void => {
  if (workflow.status === "completed" || workflow.completedAt != null) {
    throw new WorkflowError("failed-precondition", "Completed workflow is immutable.");
  }
  if (workflow.status === "cancelled" || workflow.cancelled === true) {
    throw new WorkflowError("failed-precondition", "Cancelled workflow is immutable.");
  }
};

export const requireMutableWorkflow = async (
  tx: WorkflowTransaction,
  id: string,
): Promise<WorkflowDoc> => {
  const workflow = await requireWorkflow(tx, id);
  assertWorkflowMutable(workflow);
  if (workflow.workflowKind !== "issueCoordination") {
    const executionId = typeof workflow.jobExecutionId === "string" &&
        workflow.jobExecutionId.trim().length > 0 ?
      workflow.jobExecutionId.trim() :
      id;
    const execution = await tx.get(executionPath(executionId));
    if (!execution.exists || execution.data == null) {
      throw new WorkflowError(
        "not-found",
        "The workflow parent job execution was not found.",
        {reasonCode: "parent-execution-missing", executionId},
      );
    }
    if (execution.data.isDeleted === true) {
      throw new WorkflowError(
        "failed-precondition",
        "Deleted parent job execution cannot accept workflow mutations.",
        {reasonCode: "parent-execution-deleted", executionId},
      );
    }
    if (execution.data.isCompleted === true) {
      throw new WorkflowError(
        "failed-precondition",
        "Completed parent execution conflicts with a mutable workflow.",
        {reasonCode: "parent-execution-completed-workflow-open", executionId},
      );
    }
    if (execution.data.isCancelled === true) {
      throw new WorkflowError(
        "failed-precondition",
        "Cancelled parent execution conflicts with a mutable workflow.",
        {reasonCode: "parent-execution-cancelled-workflow-open", executionId},
      );
    }
  }
  return workflow;
};

export const requireComplianceForWorkflow = async (
  tx: WorkflowTransaction,
  complianceId: string,
  workflowId: string,
): Promise<ComplianceDoc> => {
  const snap = await tx.get<ComplianceDoc>(compliancePath(complianceId));
  if (!snap.exists || snap.data == null) {
    throw new WorkflowError("not-found", `Compliance request ${complianceId} was not found.`);
  }
  if (snap.data.linkedWorkflowId !== workflowId) {
    throw new WorkflowError(
      "failed-precondition",
      "Compliance request does not belong to the command workflow.",
      {complianceId, workflowId, linkedWorkflowId: snap.data.linkedWorkflowId ?? null},
    );
  }
  return snap.data;
};

export const workflowDocumentPath = (
  collection: string,
  value: unknown,
  field: string,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError("invalid-argument", `${field} must be a document id or path.`);
  }
  const cleaned = value.trim();
  if (!cleaned.includes("/")) return `${collection}/${cleaned}`;
  const parts = cleaned.split("/").filter((part) => part.length > 0);
  if (parts.length !== 2 || parts[0] !== collection) {
    throw new WorkflowError("invalid-argument", `${field} must reference ${collection}.`, {value: cleaned});
  }
  return `${parts[0]}/${parts[1]}`;
};

export const requireLaneReferenceForWorkflow = async (
  tx: WorkflowTransaction,
  reference: unknown,
  field: string,
  workflowId: string,
  expectedLaneKey?: string,
): Promise<{path: string; data: LaneDoc}> => {
  const path = workflowDocumentPath("job_lanes", reference, field);
  if (path == null) {
    throw new WorkflowError("invalid-argument", `${field} is required.`);
  }
  const snap = await tx.get<LaneDoc>(path);
  if (!snap.exists || snap.data == null) {
    throw new WorkflowError("not-found", `${field} lane was not found.`, {path});
  }
  if (snap.data.workflowId !== workflowId) {
    throw new WorkflowError("failed-precondition", `${field} belongs to another workflow.`, {
      path,
      workflowId,
      linkedWorkflowId: snap.data.workflowId ?? null,
    });
  }
  if (expectedLaneKey != null && snap.data.laneKey !== expectedLaneKey) {
    throw new WorkflowError("failed-precondition", `${field} lane key does not match the command.`, {
      path,
      expectedLaneKey,
      actualLaneKey: snap.data.laneKey ?? null,
    });
  }
  if (snap.data.status === "removed" || snap.data.status === "terminated") {
    throw new WorkflowError("failed-precondition", `${field} lane is not active.`, {path, status: snap.data.status});
  }
  return {path, data: snap.data};
};


export const requireActiveLaneForWorkflow = async (
  tx: WorkflowTransaction,
  workflowId: string,
  laneKey: string,
  field: string,
): Promise<{path: string; data: LaneDoc}> => {
  const rows = await tx.query<LaneDoc>("job_lanes", [
    {field: "workflowId", op: "==", value: workflowId},
    {field: "laneKey", op: "==", value: laneKey},
  ]);
  const active = rows.filter((row) =>
    row.data != null && row.data.status !== "removed" && row.data.status !== "terminated",
  );
  if (active.length === 0 || active[0].data == null) {
    throw new WorkflowError("not-found", `${field} active lane was not found.`, {workflowId, laneKey});
  }
  if (active.length > 1) {
    throw new WorkflowError("failed-precondition", `${field} has multiple active lane generations.`, {
      workflowId,
      laneKey,
      paths: active.map((row) => row.path),
    });
  }
  return {path: active[0].path, data: active[0].data};
};
