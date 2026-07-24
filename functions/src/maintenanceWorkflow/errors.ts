import {JsonMap} from "./types";

export type WorkflowErrorCode =
  | "unauthenticated" | "permission-denied" | "invalid-argument"
  | "not-found" | "already-exists" | "failed-precondition" | "aborted"
  | "workflow-version-conflict" | "command-idempotency-conflict"
  | "unsupported-workflow-command" | "lane-set-not-finalized"
  | "lane-ack-required" | "lane-progress-open" | "lane-not-ready-to-close"
  | "blocking-compliance-open" | "red-answer-required"
  | "red-lane-not-ready" | "red-preparation-incomplete" | "red-not-applicable"
  | "preparation-answer-required" | "red-successor-template-unconfigured"
  | "equipment-state-conflict" | "unauthorized-represented-lane";

export class WorkflowError extends Error {
  readonly code: WorkflowErrorCode;
  readonly details: JsonMap;

  constructor(code: WorkflowErrorCode, message: string, details: JsonMap = {}) {
    super(message);
    this.name = "WorkflowError";
    this.code = code;
    this.details = details;
  }
}

export const requireCondition = (
  condition: unknown,
  code: WorkflowErrorCode,
  message: string,
  details: JsonMap = {},
): asserts condition => {
  if (!condition) throw new WorkflowError(code, message, details);
};
