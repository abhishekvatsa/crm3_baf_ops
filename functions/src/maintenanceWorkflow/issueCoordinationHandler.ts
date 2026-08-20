import {assertMayRaiseCompliance, mayWorkLane} from "./authority";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {maintenanceProjectionForRaise} from "./maintenanceBridge";
import {
  compliancePath,
  maintenancePath,
  workflowPath,
} from "./paths";
import {WORKFLOW_CLOCKS_MINUTES} from "./policy.generated";
import {JsonMap, LaneKey} from "./types";
import {cleanText, iso, plusMinutes} from "./utils";
import {isFiveDigitChargeNumber} from "../chargeNumber";

const PURPOSES = new Set(["deferment", "operationsSupport"]);
const DEFERMENT_BASES = new Set([
  "ongoingCycle", "equipmentRequired", "operationalCompliance",
  "safetyConstraint", "qualityConstraint", "other",
]);
const SUPPORT_TYPES = new Set([
  "craneMovement", "assetRelocation", "isolation", "processPreparation",
  "utilitySupport", "accessOrPermit", "other",
]);
const SUPPORT_RESOURCES = new Set([
  "crane", "transferCar", "operationsCrew", "utilities", "other",
]);
const PRIORITIES = new Set(["low", "medium", "high", "critical"]);
const PAYLOAD_FIELDS = [
  "ticketId", "expectedTicketVersion", "complianceId", "requestPurposeKey",
  "conditionTypeKey", "conditionRef", "conditionChargeNo",
  "defermentBasisKey", "operationsSupportTypeKey",
  "operationsResourceKey", "requestedLocation", "title", "description",
  "priorityKey",
] as const;

const exactKeys = (value: JsonMap): void => {
  const actual = Object.keys(value).sort();
  const expected = [...PAYLOAD_FIELDS].sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new WorkflowError(
      "invalid-argument",
      "Issue coordination has unsupported or missing fields.",
      {reasonCode: "issue-coordination-command-shape-invalid"},
    );
  }
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." ||
      parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const boundedText = (
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): string => {
  const parsed = cleanText(value, field);
  if (parsed.length < minimum || parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must contain ${minimum}-${maximum} characters.`,
    );
  }
  return parsed;
};

const optionalText = (
  value: unknown,
  field: string,
  maximum: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
  }
  const parsed = value.trim();
  if (parsed.length === 0) return null;
  if (parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} cannot exceed ${maximum} characters.`,
    );
  }
  return parsed;
};

const choice = (
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string => {
  const parsed = cleanText(value, field);
  if (!allowed.has(parsed)) {
    throw new WorkflowError("invalid-argument", `${field} is unsupported.`);
  }
  return parsed;
};

const optionalChoice = (
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string | null => value == null ? null : choice(value, field, allowed);

const positiveVersion = (value: unknown, field: string): number => {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be a positive integer.`,
    );
  }
  return value as number;
};

const routeLane = (route: unknown): LaneKey => {
  const value = cleanText(route, "routedTo");
  if (value === "electrical") return "elec";
  if (value === "mechanical") return "mech";
  if (value === "instrumentation") return "inst";
  if (value === "refractory") return "red";
  if (value === "emd") return "emd";
  if (value === "others") return "shared";
  if (value === "operations" || value === "shiftInCharge") return "oprn";
  throw new WorkflowError(
    "failed-precondition",
    "Maintenance ticket routing is malformed.",
    {reasonCode: "maintenance-ticket-route-invalid", routedTo: value},
  );
};

export const startIssueCoordination: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload);
  if (command.expectedVersion !== 0) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "New issue coordination must start at version zero.",
    );
  }
  const ticketId = documentId(command.payload.ticketId, "ticketId");
  const complianceId = documentId(
    command.payload.complianceId,
    "complianceId",
  );
  const expectedTicketVersion = positiveVersion(
    command.payload.expectedTicketVersion,
    "expectedTicketVersion",
  );
  if (command.aggregateId.length > 160 || command.aggregateId.includes("/") ||
      command.aggregateId === ticketId || command.aggregateId === complianceId) {
    throw new WorkflowError(
      "invalid-argument",
      "Issue coordination identities are invalid.",
      {reasonCode: "issue-coordination-identity-invalid"},
    );
  }

  const purpose = choice(
    command.payload.requestPurposeKey,
    "requestPurposeKey",
    PURPOSES,
  );
  const conditionType = choice(
    command.payload.conditionTypeKey,
    "conditionTypeKey",
    new Set(["manual", "chargeComplete", "activityRef"]),
  );
  const title = boundedText(command.payload.title, "title", 3, 160);
  const description = boundedText(
    command.payload.description,
    "description",
    5,
    2000,
  );
  const priority = choice(command.payload.priorityKey, "priorityKey", PRIORITIES);
  const defermentBasis = optionalChoice(
    command.payload.defermentBasisKey,
    "defermentBasisKey",
    DEFERMENT_BASES,
  );
  const supportType = optionalChoice(
    command.payload.operationsSupportTypeKey,
    "operationsSupportTypeKey",
    SUPPORT_TYPES,
  );
  const supportResource = optionalChoice(
    command.payload.operationsResourceKey,
    "operationsResourceKey",
    SUPPORT_RESOURCES,
  );
  const requestedLocation = optionalText(
    command.payload.requestedLocation,
    "requestedLocation",
    300,
  );
  let conditionRef = optionalText(
    command.payload.conditionRef,
    "conditionRef",
    300,
  );
  const conditionChargeNo = command.payload.conditionChargeNo;

  if (purpose === "deferment") {
    if (defermentBasis == null ||
        (conditionType !== "chargeComplete" && conditionType !== "activityRef")) {
      throw new WorkflowError(
        "invalid-argument",
        "Deferment requires a basis and a charge or activity release condition.",
      );
    }
    if (supportType != null || supportResource != null || requestedLocation != null) {
      throw new WorkflowError(
        "invalid-argument",
        "Operations-support details are not valid for deferment.",
      );
    }
    if (conditionType === "chargeComplete") {
      if (!isFiveDigitChargeNumber(conditionChargeNo)) {
        throw new WorkflowError(
          "invalid-argument",
          "Charge-complete deferment requires an exact five-digit charge number.",
          {reasonCode: "charge-number-invalid", field: "conditionChargeNo"},
        );
      }
      conditionRef = String(conditionChargeNo);
    } else if (conditionChargeNo != null || conditionRef == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Activity deferment requires an activity reference and no charge number.",
      );
    }
  } else {
    if (conditionType !== "manual" || conditionRef != null ||
        conditionChargeNo != null || defermentBasis != null ||
        supportType == null || supportResource == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Operations support must be an immediate typed request.",
      );
    }
    if ((supportType === "craneMovement" || supportType === "assetRelocation") &&
        requestedLocation == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Movement support requires a destination or work location.",
      );
    }
  }

  const [ticketSnapshot, workflowSnapshot, complianceSnapshot, activeRequests,
    eventSnapshot] = await Promise.all([
    tx.get(maintenancePath(ticketId)),
    tx.get(workflowPath(command.aggregateId)),
    tx.get(compliancePath(complianceId)),
    tx.query("compliance_requests", [
      {field: "linkedMaintenanceFirestoreId", op: "==", value: ticketId},
    ]),
    tx.get(`maintenance_workflow_events/${command.commandId}`),
  ]);
  const ticket = ticketSnapshot.data;
  if (!ticketSnapshot.exists || ticket == null) {
    throw new WorkflowError("not-found", "Maintenance ticket was not found.");
  }
  if (workflowSnapshot.exists || complianceSnapshot.exists || eventSnapshot.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Issue coordination evidence already exists without this command receipt.",
      {reasonCode: "issue-coordination-orphan-evidence"},
    );
  }
  if (ticket.firestoreId !== ticketId || ticket.version !== expectedTicketVersion) {
    throw new WorkflowError(
      "aborted",
      "The maintenance issue changed. Sync and review it before coordinating.",
      {reasonCode: "issue-coordination-ticket-version-changed"},
    );
  }
  if (ticket.isDeleted === true || ticket.isResolved === true ||
      (ticket.status !== "acknowledged" && ticket.status !== "inProgress") ||
      typeof ticket.acknowledgedByUid !== "string" ||
      typeof ticket.acknowledgedAt !== "string") {
    throw new WorkflowError(
      "failed-precondition",
      "The receiving maintenance side must acknowledge an open issue before requesting Operations coordination.",
      {reasonCode: "issue-coordination-ticket-not-acknowledged"},
    );
  }
  const queueState = typeof ticket.workflowQueueState === "string" ?
    ticket.workflowQueueState : "independent";
  if (queueState !== "independent" && queueState !== "released") {
    throw new WorkflowError(
      "failed-precondition",
      "This issue already has active workflow coordination.",
      {reasonCode: "issue-coordination-already-active"},
    );
  }
  const conflicting = activeRequests.find((row) =>
    !["confirmedClosed", "cancelled", "superseded"].includes(
      String(row.data?.status),
    ));
  if (conflicting != null) {
    throw new WorkflowError(
      "failed-precondition",
      "This issue already has an active Operations obligation.",
      {reasonCode: "issue-coordination-compliance-active"},
    );
  }
  const originLane = routeLane(ticket.routedTo);
  if (originLane === "oprn") {
    throw new WorkflowError(
      "failed-precondition",
      "An Operations-routed issue cannot request Operations coordination from itself.",
      {reasonCode: "issue-coordination-origin-target-same"},
    );
  }
  assertMayRaiseCompliance(context.actor, originLane);
  const assetTypeKey = cleanText(ticket.assetType, "assetType");
  const assetNumber = ticket.assetNumber;
  if (!Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1) {
    throw new WorkflowError(
      "failed-precondition",
      "The linked issue asset identity is malformed.",
      {reasonCode: "issue-coordination-asset-invalid"},
    );
  }
  const now = iso(context.serverNow);
  const immediate = conditionType === "manual";
  const raisedUnderCoordination = !mayWorkLane(context.actor, originLane);
  const actorUid = context.actor.uid;
  const actorName = context.actor.name;

  tx.create(workflowPath(command.aggregateId), {
    workflowSchemaVersion: 1,
    workflowKind: "issueCoordination",
    jobExecutionId: ticketId,
    linkedMaintenanceFirestoreId: ticketId,
    assetTypeKey,
    assetNumber,
    assetClassId: null,
    assetInstanceId: null,
    status: "awaitingCompliance",
    version: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    activeRedWork: false,
    awaitingPreparation: false,
    cancelled: false,
    completedAt: null,
    createdByUid: actorUid,
    createdByName: actorName,
    createdAt: now,
    updatedAt: now,
  });
  tx.create(compliancePath(complianceId), {
    linkedWorkflowId: command.aggregateId,
    linkedExecutionFirestoreId: null,
    linkedMaintenanceFirestoreId: ticketId,
    linkedLaneFirestoreId: null,
    linkedModuleFirestoreId: null,
    gatesLaneFirestoreId: null,
    title,
    description,
    originLaneKey: originLane,
    originLaneFirestoreId: null,
    targetLaneKey: "oprn",
    targetLaneFirestoreId: null,
    status: "raised",
    conditionTypeKey: conditionType,
    conditionRef,
    requestPurposeKey: purpose,
    defermentBasisKey: defermentBasis,
    operationsSupportTypeKey: supportType,
    operationsResourceKey: supportResource,
    requestedLocation,
    raisedUnderCoordination,
    coordinationBasis: raisedUnderCoordination ?
      "supervisory-workflow-coordination" : null,
    priorityKey: priority,
    assetTypeKey,
    assetNumber,
    chargeNoAtEvent: ticket.chargeNoAtEvent ?? null,
    becameDueAt: immediate ? now : null,
    acknowledgementDueAt: immediate ?
      plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
      ) : null,
    complianceDueAt: null,
    nextEscalationAt: immediate ?
      plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
      ) : null,
    raisedByUid: actorUid,
    raisedByName: actorName,
    raisedAt: now,
    counterDepth: 0,
    correctionCount: 0,
    escalationTier: 0,
    currentAttemptId: null,
    attemptCount: 0,
    metadata: {
      schemaVersion: 1,
      workItemKind: "issueCoordination",
      ticketId,
      conditionChargeNo: conditionType === "chargeComplete" ?
        conditionChargeNo as number : null,
    },
    isDeleted: false,
    deletedAt: null,
    deletedByUid: null,
    deletedByName: null,
    deleteReason: null,
    version: 1,
    createdAt: now,
    updatedAt: now,
  });
  tx.update(maintenancePath(ticketId), maintenanceProjectionForRaise({
    maintenance: ticket,
    workflowId: command.aggregateId,
    complianceId,
    originLaneKey: originLane,
    targetLaneKey: "oprn",
    conditionTypeKey: conditionType,
    conditionRef,
    actorUid,
    actorName,
    at: context.serverNow,
    forceDeferred: true,
  }));
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "issue.coordinationStarted",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: originLane,
    payload: {
      ticketId,
      complianceId,
      requestPurposeKey: purpose,
      conditionTypeKey: conditionType,
      conditionRef,
      defermentBasisKey: defermentBasis,
      operationsSupportTypeKey: supportType,
      operationsResourceKey: supportResource,
      requestedLocation,
      raisedUnderCoordination,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "issue-coordination-started",
    aggregateVersion: 1,
    result: {
      workflowId: command.aggregateId,
      ticketId,
      complianceId,
      requestPurposeKey: purpose,
    },
  };
};
