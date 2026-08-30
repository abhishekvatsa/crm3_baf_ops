import {WorkflowError} from "./errors";
import {JsonMap, LaneKey} from "./types";

export const TICKET_LANE_FIELDS = [
  "issueLaneSchemaVersion",
  "issueLaneRevision",
  "issueAssignedLanes",
  "issueAcknowledgedLanes",
  "issueCompletedLanes",
] as const;

const ROUTES = new Set([
  "operations", "electrical", "mechanical", "instrumentation",
  "refractory", "emd", "shiftInCharge", "others",
]);

export interface TicketLanePlan {
  readonly revision: number;
  readonly assigned: readonly string[];
  readonly acknowledged: readonly string[];
  readonly completed: readonly string[];
  readonly completionEvidence: Readonly<Record<string, TicketLaneCompletion>>;
}

export interface TicketLaneCompletion extends JsonMap {
  readonly completedAt: string;
  readonly completedByUid: string;
  readonly completedByName: string;
}

const laneList = (
  value: unknown,
  field: string,
  allowEmpty: boolean,
  code: "invalid-argument" | "failed-precondition",
): readonly string[] => {
  if (!Array.isArray(value) || (!allowEmpty && value.length === 0) ||
      value.length > ROUTES.size ||
      value.some((lane) => typeof lane !== "string" || !ROUTES.has(lane)) ||
      new Set(value).size !== value.length) {
    throw new WorkflowError(
      code,
      `${field} must be a unique supported lane list.`,
      {reasonCode: "maintenance-ticket-lane-plan-invalid", field},
    );
  }
  return [...value] as string[];
};

export const requestedTicketLanes = (value: unknown): readonly string[] =>
  laneList(value, "lanes", false, "invalid-argument");

const parseFields = (
  source: JsonMap,
  code: "invalid-argument" | "failed-precondition",
): TicketLanePlan => {
  if (source.issueLaneSchemaVersion !== 1 ||
      !Number.isSafeInteger(source.issueLaneRevision) ||
      (source.issueLaneRevision as number) < 1) {
    throw new WorkflowError(
      code,
      "The maintenance issue lane schema is invalid.",
      {reasonCode: "maintenance-ticket-lane-plan-invalid"},
    );
  }
  const assigned = laneList(
    source.issueAssignedLanes,
    "issueAssignedLanes",
    false,
    code,
  );
  const acknowledged = laneList(
    source.issueAcknowledgedLanes,
    "issueAcknowledgedLanes",
    true,
    code,
  );
  const completed = laneList(
    source.issueCompletedLanes,
    "issueCompletedLanes",
    true,
    code,
  );
  const assignedSet = new Set(assigned);
  const acknowledgedSet = new Set(acknowledged);
  if (acknowledged.some((lane) => !assignedSet.has(lane)) ||
      completed.some((lane) => !acknowledgedSet.has(lane))) {
    throw new WorkflowError(
      code,
      "Issue lane progress must belong to the active lane set.",
      {reasonCode: "maintenance-ticket-lane-plan-invalid"},
    );
  }
  const completionEvidence = parseCompletionEvidence(
    source.issueLaneCompletionEvidence,
    completed,
    code,
  );
  return {
    revision: source.issueLaneRevision as number,
    assigned,
    acknowledged,
    completed,
    completionEvidence,
  };
};

const parseCompletionEvidence = (
  value: unknown,
  completed: readonly string[],
  code: "invalid-argument" | "failed-precondition",
): Readonly<Record<string, TicketLaneCompletion>> => {
  if (value == null) return {};
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError(
      code,
      "Issue lane completion evidence must be an object.",
      {reasonCode: "maintenance-ticket-lane-completion-evidence-invalid"},
    );
  }
  const raw = value as JsonMap;
  const lanes = Object.keys(raw);
  if (lanes.length > ROUTES.size ||
      lanes.some((lane) => !completed.includes(lane))) {
    throw new WorkflowError(
      code,
      "Issue lane completion evidence must belong to completed lanes.",
      {reasonCode: "maintenance-ticket-lane-completion-evidence-invalid"},
    );
  }
  const evidence: Record<string, TicketLaneCompletion> = {};
  for (const lane of lanes) {
    const entry = raw[lane];
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new WorkflowError(
        code,
        "Issue lane completion evidence entry is malformed.",
        {reasonCode: "maintenance-ticket-lane-completion-evidence-invalid"},
      );
    }
    const map = entry as JsonMap;
    const keys = Object.keys(map).sort();
    if (JSON.stringify(keys) !== JSON.stringify([
      "completedAt", "completedByName", "completedByUid",
    ]) || typeof map.completedAt !== "string" ||
        !Number.isFinite(Date.parse(map.completedAt)) ||
        typeof map.completedByUid !== "string" ||
        map.completedByUid.trim().length === 0 ||
        map.completedByUid.length > 160 ||
        typeof map.completedByName !== "string" ||
        map.completedByName.trim().length === 0 ||
        map.completedByName.length > 160) {
      throw new WorkflowError(
        code,
        "Issue lane completion actor or time evidence is malformed.",
        {reasonCode: "maintenance-ticket-lane-completion-evidence-invalid"},
      );
    }
    evidence[lane] = {
      completedAt: map.completedAt,
      completedByUid: map.completedByUid.trim(),
      completedByName: map.completedByName.trim(),
    };
  }
  return evidence;
};

const presentLaneFields = (source: JsonMap): readonly string[] =>
  TICKET_LANE_FIELDS.filter((field) =>
    Object.prototype.hasOwnProperty.call(source, field));

const hasCompletionEvidenceField = (source: JsonMap): boolean =>
  Object.prototype.hasOwnProperty.call(
    source,
    "issueLaneCompletionEvidence",
  );

export const hasCompleteTicketLaneFields = (source: JsonMap): boolean => {
  const present = presentLaneFields(source);
  if (present.length === 0 && hasCompletionEvidenceField(source)) {
    throw new WorkflowError(
      "failed-precondition",
      "Issue lane completion evidence requires the complete lane field set.",
      {reasonCode: "maintenance-ticket-lane-plan-partial"},
    );
  }
  if (present.length !== 0 && present.length !== TICKET_LANE_FIELDS.length) {
    throw new WorkflowError(
      "failed-precondition",
      "Issue lane fields must be present together.",
      {reasonCode: "maintenance-ticket-lane-plan-partial"},
    );
  }
  return present.length === TICKET_LANE_FIELDS.length;
};

export const createTicketLanePlan = (
  input: JsonMap,
  routedTo: string,
): TicketLanePlan => {
  const present = presentLaneFields(input);
  if (present.length === 0 && hasCompletionEvidenceField(input)) {
    throw new WorkflowError(
      "invalid-argument",
      "Issue lane completion evidence requires the complete lane field set.",
      {reasonCode: "maintenance-ticket-lane-plan-partial"},
    );
  }
  if (present.length === 0) {
    return {
      revision: 1,
      assigned: [routedTo],
      acknowledged: [],
      completed: [],
      completionEvidence: {},
    };
  }
  if (present.length !== TICKET_LANE_FIELDS.length) {
    throw new WorkflowError(
      "invalid-argument",
      "Issue lane fields must be supplied together.",
      {reasonCode: "maintenance-ticket-lane-plan-partial"},
    );
  }
  const plan = parseFields(input, "invalid-argument");
  if (plan.revision !== 1 || plan.assigned[0] !== routedTo ||
      plan.acknowledged.length !== 0 || plan.completed.length !== 0) {
    throw new WorkflowError(
      "invalid-argument",
      "A new issue requires a clean revision-one lane plan led by routedTo.",
      {reasonCode: "maintenance-ticket-lane-create-invalid"},
    );
  }
  return plan;
};

export const ticketLanePlan = (
  ticket: JsonMap,
  options: {readonly allowOtherDepartmentRepair?: boolean} = {},
): TicketLanePlan => {
  const hasFields = hasCompleteTicketLaneFields(ticket);
  const route = ticket.routedTo;
  if (typeof route !== "string" || !ROUTES.has(route)) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket routing is malformed.",
      {reasonCode: "maintenance-ticket-route-invalid"},
    );
  }
  const status = ticket.status;
  const plan = hasFields ? parseFields(ticket, "failed-precondition") : {
    revision: 1,
    assigned: [route],
    acknowledged: status === "acknowledged" || status === "inProgress" ||
      status === "resolved" ? [route] : [],
    completed: status === "resolved" ? [route] : [],
    completionEvidence: {},
  };
  const otherDepartment = typeof ticket.otherDepartment === "string" ?
    ticket.otherDepartment.trim() : null;
  const hasValidOtherDepartment = otherDepartment != null &&
    otherDepartment.trim().length >= 1 && otherDepartment.length <= 80;
  const otherDepartmentMatches = plan.assigned.includes("others") ?
    hasValidOtherDepartment : ticket.otherDepartment == null;
  if (plan.assigned[0] !== route ||
      (!options.allowOtherDepartmentRepair &&
        !otherDepartmentMatches)) {
    throw new WorkflowError(
      "failed-precondition",
      "Ticket routing does not match its accountable lane plan.",
      {reasonCode: "maintenance-ticket-lane-route-inconsistent"},
    );
  }
  if (hasFields) {
    const statusHasWork = status === "acknowledged" || status === "inProgress";
    if ((status === "open" &&
          (plan.acknowledged.length > 0 || plan.completed.length > 0)) ||
        (statusHasWork && plan.acknowledged.length === 0) ||
        (status === "acknowledged" &&
          (plan.acknowledged.length !== plan.assigned.length ||
            plan.completed.length > 0)) ||
        (status === "resolved" && !ticketLanePlanComplete(plan))) {
      throw new WorkflowError(
        "failed-precondition",
        "Ticket status does not match lane progress.",
        {reasonCode: "maintenance-ticket-lane-status-inconsistent"},
      );
    }
  }
  const hasAcknowledgement = plan.acknowledged.length > 0;
  const acknowledgementComplete =
    typeof ticket.acknowledgedByUid === "string" &&
    typeof ticket.acknowledgedByName === "string" &&
    ticket.acknowledgedAt != null;
  const acknowledgementAbsent = ticket.acknowledgedByUid == null &&
    ticket.acknowledgedByName == null && ticket.acknowledgedAt == null;
  const legacyResolvedWithoutAcknowledgement =
    !hasFields && status === "resolved" && acknowledgementAbsent;
  if (!legacyResolvedWithoutAcknowledgement &&
      ((hasAcknowledgement && !acknowledgementComplete) ||
        (!hasAcknowledgement && !acknowledgementAbsent))) {
    throw new WorkflowError(
      "failed-precondition",
      "Ticket lane acknowledgement evidence is incomplete.",
      {reasonCode: "maintenance-ticket-lane-acknowledgement-incomplete"},
    );
  }
  return plan;
};

export const ticketLaneProjection = (plan: TicketLanePlan): JsonMap => ({
  issueLaneSchemaVersion: 1,
  issueLaneRevision: plan.revision,
  issueAssignedLanes: [...plan.assigned],
  issueAcknowledgedLanes: [...plan.acknowledged],
  issueCompletedLanes: [...plan.completed],
  issueLaneCompletionEvidence: {...plan.completionEvidence},
});

export const ticketLanePlanComplete = (plan: TicketLanePlan): boolean =>
  plan.assigned.every((lane) => plan.completed.includes(lane));

export const ticketLaneStatus = (plan: TicketLanePlan): string =>
  plan.completed.length > 0 ? "inProgress" :
    plan.acknowledged.length > 0 ?
      (plan.acknowledged.length === plan.assigned.length ?
        "acknowledged" : "inProgress") : "open";

export const ticketRouteLane = (route: unknown): LaneKey => {
  if (route === "electrical") return "elec";
  if (route === "mechanical") return "mech";
  if (route === "instrumentation") return "inst";
  if (route === "refractory") return "red";
  if (route === "emd") return "emd";
  if (route === "others") return "shared";
  if (route === "operations" || route === "shiftInCharge") return "oprn";
  throw new WorkflowError(
    "failed-precondition",
    "Maintenance ticket routing is malformed.",
    {reasonCode: "maintenance-ticket-route-invalid", routedTo: String(route)},
  );
};
