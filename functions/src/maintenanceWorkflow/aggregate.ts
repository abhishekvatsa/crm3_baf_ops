import {LaneDoc, WorkflowStatus} from "./types";

export const deriveWorkflowStatus = (
  lanes: readonly LaneDoc[],
  openBlockingComplianceCount: number,
  completed: boolean,
  cancelled: boolean,
): WorkflowStatus => {
  if (cancelled) return "cancelled";
  if (completed) return "completed";
  const active = lanes.filter((l) => l.status !== "removed" && l.status !== "terminated");
  if (active.length === 0) return "pendingLaneClassification";
  const ack = active.filter((l) => l.status === "acknowledged" || l.status === "closed");
  const closed = active.filter((l) => l.status === "closed");
  if (ack.length === 0) return "assigned";
  if (ack.length < active.length) return "partiallyAcknowledged";
  if (openBlockingComplianceCount > 0) return "awaitingCompliance";
  if (closed.length === active.length) return "readyForClosure";
  const progress = active.some((l) => (l.progressRevision ?? 0) > 0);
  return progress ? "inProgress" : "fullyAcknowledged";
};
