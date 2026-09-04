import {COMMAND_AUTHORITY_ROLES, LANE_POLICY} from "./policy.generated";
import type {SendOutcome} from "../notifications";

export const isNotifiableCriticalAlarmStatus = (status: unknown): boolean =>
  status === "raised";

export const isCriticalAlarmEventType = (eventType: unknown): boolean =>
  typeof eventType === "string" && eventType.startsWith("criticalAlarm.");

export const samePersistedNotificationInstant = (
  left: unknown,
  right: unknown,
): boolean => {
  const millis = (value: unknown): number | null => {
    const candidate = value as {toMillis?: unknown} | null;
    if (candidate == null || typeof candidate.toMillis !== "function") {
      return null;
    }
    try {
      const parsed = (candidate.toMillis as () => unknown)();
      return Number.isSafeInteger(parsed) && (parsed as number) >= 0 ?
        parsed as number : null;
    } catch {
      return null;
    }
  };
  const leftMillis = millis(left);
  return leftMillis != null && leftMillis === millis(right);
};

export const shouldRetryKnownWorkflowNotificationFailure = (
  eventType: unknown,
  outcome: SendOutcome,
): boolean => {
  if (eventType === "deviceRecovery.requested") {
    return outcome.attempted === 1 && outcome.succeeded === 0 &&
      outcome.failed === 1 && outcome.retryableFailures === 1;
  }
  return false;
};

export const shouldRetryCriticalAlarmRecipientFailure = (
  outcome: SendOutcome,
): boolean =>
  outcome.attempted === 1 && outcome.succeeded === 0 &&
  outcome.failed === 1 && outcome.retryableFailures === 1;

const escalationRoles = (
  laneKey: string | null,
  tier: number,
): string[] => {
  if (tier >= 3) return ["admin"];
  if (tier >= 2) return ["shiftSupervisor", "si"];

  if (laneKey == null) return ["si"];
  const lane = LANE_POLICY[laneKey];
  if (lane == null) return ["si"];

  // Tier 1 is the lane's senior tier. Admin/SI are deliberately excluded
  // here because the ratified ladder reaches SI at Tier 2 and Admin at Tier 3.
  const senior = lane.closeRoles.filter(
    (role) => role !== "admin" && role !== "si",
  );
  return senior.length > 0 ? [...new Set(senior)] : ["si"];
};

/**
 * Resolves workflow notification recipients from the same generated lane
 * authority policy used by command handling. Ordinary workflow events go to
 * the relevant action roles. Escalation events follow the ratified tier
 * ladder instead of notifying every supervisory role at the first overdue
 * sweep.
 */
export const workflowRecipientRoles = (
  eventType: string,
  laneKey: string | null,
  escalationTier?: number | null,
): string[] => {
  const isEscalation = eventType.endsWith("Escalated") ||
    eventType === "lane.escalated";
  if (isEscalation) {
    return escalationRoles(laneKey, Math.max(1, Number(escalationTier ?? 1)));
  }

  const roles = new Set<string>(["admin", "si"]);

  if (eventType.startsWith("equipment.")) {
    roles.add("shiftSupervisor");
    roles.add("operations");
    return [...roles];
  }

  if (laneKey != null) {
    const lane = LANE_POLICY[laneKey];
    if (lane != null) {
      for (const role of lane.ackRoles) roles.add(role);
      for (const role of lane.workRoles) roles.add(role);
      for (const role of lane.closeRoles) roles.add(role);
    }
  }
  return [...roles];
};

export const complianceHandoverSide = (eventType: string): "origin" | "target" | null => {
  switch (eventType) {
    case "issue.coordinationStarted":
    case "compliance.raised":
    case "compliance.returnedForCorrection":
    case "compliance.counterAccepted":
    case "compliance.confirmedClosed":
    case "red.preparationConfirmed":
      return "target";
    case "compliance.acknowledged":
    case "compliance.complied":
    case "compliance.conditionConfirmedAndWorkReactivated":
    case "compliance.counterProposed":
      return "origin";
    default:
      return null;
  }
};

/** Audit lane identifies the actor's side; handover recipients come from the bound request. */
export const complianceHandoverRecipientRoles = (
  eventType: string,
  aggregateId: string,
  compliance: Readonly<Record<string, unknown>> | null,
): string[] | null => {
  const side = complianceHandoverSide(eventType);
  if (side == null || compliance == null || compliance.isDeleted === true ||
      compliance.linkedWorkflowId !== aggregateId) return null;
  const lane = side === "origin" ? compliance.originLaneKey : compliance.targetLaneKey;
  if (lane != null && (typeof lane !== "string" ||
      !Object.prototype.hasOwnProperty.call(LANE_POLICY, lane))) return null;
  if (side === "target" && lane == null) return null;
  const roles = new Set(workflowRecipientRoles(eventType, typeof lane === "string" ? lane : null));
  if (side === "origin" && lane != null && compliance.raisedUnderCoordination === true) {
    for (const role of COMMAND_AUTHORITY_ROLES.raiseComplianceCoordination) roles.add(role);
  }
  return [...roles];
};
