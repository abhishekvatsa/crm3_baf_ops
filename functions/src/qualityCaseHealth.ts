/**
 * One name for what is wrong with a quality case, derived from the refusal a
 * governed command already carries.
 *
 * Operators report that a case "cannot be closed"; the reason code alone says
 * which rule refused, not what kind of trouble the case is in. These categories
 * group the reason codes by the repair each one needs, so a refusal can be
 * triaged from a single log line, and so a later case inspector classifies a
 * record exactly as the handlers already classify their refusals.
 */
export type QualityCaseHealth =
  /** The same physical subject is recorded more than once. */
  | "repeatedSubjectReference"
  /** The warning and its charge abnormality describe different facts. */
  | "caseAndWarningDisagree"
  /** A stored record does not satisfy the contract its readers require. */
  | "recordUnreadable"
  /** The evidence a retry or decision would rest on is gone or altered. */
  | "evidenceUnavailable"
  /** The decision is closed, and the correction is material. */
  | "decisionClosed"
  /** A producer would have created a case no decision could act on. */
  | "caseNotCreatable";

const HEALTH_BY_REASON_CODE = new Map<string, QualityCaseHealth>([
  ["duplicate-asset-hierarchy-reference", "repeatedSubjectReference"],
  ["charge-quality-case-malformed", "caseAndWarningDisagree"],
  ["quality-warning-malformed", "recordUnreadable"],
  ["charge-quality-abnormality-malformed", "recordUnreadable"],
  ["abnormality-record-malformed", "recordUnreadable"],
  ["charge-quality-abnormality-missing", "evidenceUnavailable"],
  ["quality-replay-evidence-malformed", "evidenceUnavailable"],
  ["abnormality-replay-evidence-malformed", "evidenceUnavailable"],
  ["abnormality-replay-evidence-drift", "evidenceUnavailable"],
  ["quality-replay-accepted-linked-history-unavailable", "evidenceUnavailable"],
  ["charge-quality-decision-reopen-required", "decisionClosed"],
  ["charge-quality-case-postcondition-failed", "caseNotCreatable"],
  ["maintenance-ticket-quality-case-postcondition-failed", "caseNotCreatable"],
]);

/**
 * The category for a refusal's details, or null when the refusal says nothing
 * about the health of a case. The refusal's own reason classifies it; a handler
 * that wrapped another refusal without a category of its own is classified by
 * the cause it kept, so the specific condition survives the wrapping.
 */
export function qualityCaseHealth(details: unknown): QualityCaseHealth | null {
  if (details == null || typeof details !== "object" || Array.isArray(details)) {
    return null;
  }
  const {reasonCode, causeReasonCode} = details as {
    reasonCode?: unknown;
    causeReasonCode?: unknown;
  };
  for (const code of [reasonCode, causeReasonCode]) {
    if (typeof code !== "string") continue;
    const health = HEALTH_BY_REASON_CODE.get(code);
    if (health != null) return health;
  }
  return null;
}

/**
 * The same details with the category added, leaving them untouched when the
 * refusal is not about a case's health or already carries one.
 */
export function withQualityCaseHealth(details: unknown): unknown {
  const health = qualityCaseHealth(details);
  if (health == null) return details;
  const record = details as Record<string, unknown>;
  if (typeof record.caseHealth === "string") return details;
  return {...record, caseHealth: health};
}
