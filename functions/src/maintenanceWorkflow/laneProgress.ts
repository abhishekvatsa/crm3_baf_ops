import {WorkflowTransaction} from "./store";

export interface LaneProgressEvidence {
  readonly acknowledged: boolean;
  readonly moduleWork: boolean;
  readonly diary: boolean;
  readonly attachment: boolean;
  readonly evidence: boolean;
  readonly substantiveNote: boolean;
  readonly complianceLink: boolean;
  readonly carryForward: boolean;
  readonly closureHistory: boolean;
}

export const hasProtectedProgress = (e: LaneProgressEvidence): boolean =>
  e.moduleWork || e.diary || e.attachment || e.evidence || e.substantiveNote ||
  e.complianceLink || e.carryForward || e.closureHistory;

export const collectLaneProgressEvidence = async (
  tx: WorkflowTransaction,
  executionId: string,
  laneKey: string,
  acknowledged: boolean,
): Promise<LaneProgressEvidence> => {
  const modules = await tx.query("job_modules", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "laneKey", op: "==", value: laneKey},
  ]);
  const diary = await tx.query("job_diary_entries", [
    {field: "jobExecutionFirestoreId", op: "==", value: executionId},
    {field: "laneKey", op: "==", value: laneKey},
  ]);
  const compliance = await tx.query("compliance_requests", [
    {field: "linkedExecutionFirestoreId", op: "==", value: executionId},
    {field: "targetLaneKey", op: "==", value: laneKey},
  ]);
  const moduleWork = modules.some((m) => {
    const d = m.data ?? {};
    return d.status !== "notStarted" || d.responsesJson !== "[]" || d.actionsJson !== "[]" || d.hasEvidence === true;
  });
  return {
    acknowledged,
    moduleWork,
    diary: diary.length > 0,
    attachment: modules.some((m) => m.data?.hasAttachment === true),
    evidence: modules.some((m) => m.data?.hasEvidence === true),
    substantiveNote: modules.some((m) => typeof m.data?.remarks === "string" && (m.data?.remarks as string).trim().length > 0),
    complianceLink: compliance.length > 0,
    carryForward: compliance.some((c) => c.data?.linkedMaintenanceFirestoreId != null),
    closureHistory: false,
  };
};
