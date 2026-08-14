import {WorkflowError} from "./errors";
import {HandlerArgs, HandlerResult} from "./handlerTypes";
import {maintenancePath} from "./paths";
import {
  Actor,
  JsonMap,
  WorkflowCommand,
  WorkflowCommandReceipt,
} from "./types";
import {cleanText, iso, stableJson} from "./utils";
import {WorkflowTransaction} from "./store";

const ROUTES = new Set([
  "operations", "electrical", "mechanical", "instrumentation",
  "refractory", "emd", "shiftInCharge", "others",
]);
const MAINTENANCE_TYPES = new Set([
  "scheduled", "breakdown", "performance", "inspection", "overhaul",
]);
const STATUSES = new Set(["open", "acknowledged", "inProgress", "resolved"]);
const CORRECTABLE_FIELDS = new Set([
  "description", "routedTo", "maintenanceType", "isCritical", "component",
  "subsystem", "tag", "classification", "otherDepartment", "remarks",
]);

const auditId = (commandId: string): string =>
  `server_maintenance_ticket_${commandId}`;
const auditPath = (commandId: string): string =>
  `audit_logs/${auditId(commandId)}`;

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "maintenance-ticket-command-shape-invalid", field},
    );
  }
};

const record = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be an object.`);
  }
  return value as JsonMap;
};

const optionalText = (
  value: unknown,
  field: string,
  max: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
  }
  const cleaned = value.trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > max) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be at most ${max} characters.`,
    );
  }
  return cleaned;
};

const boundedText = (
  value: unknown,
  field: string,
  min: number,
  max: number,
): string => {
  const cleaned = cleanText(value, field);
  if (cleaned.length < min || cleaned.length > max) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must be between ${min} and ${max} characters.`,
    );
  }
  return cleaned;
};

const instantText = (value: unknown): string | null => {
  if (value == null) return null;
  if (typeof value === "string") return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "object" &&
      "toDate" in value &&
      typeof (value as {toDate?: unknown}).toDate === "function") {
    return (value as {toDate: () => Date}).toDate().toISOString();
  }
  throw new WorkflowError(
    "failed-precondition",
    "Maintenance ticket timestamp evidence is malformed.",
    {reasonCode: "maintenance-ticket-timestamp-invalid"},
  );
};

const ticketSnapshot = (ticket: JsonMap): JsonMap => ({
  firestoreId: ticket.firestoreId ?? null,
  version: ticket.version ?? null,
  assetType: ticket.assetType ?? null,
  assetNumber: ticket.assetNumber ?? null,
  maintenanceType: ticket.maintenanceType ?? null,
  description: ticket.description ?? null,
  routedTo: ticket.routedTo ?? null,
  status: ticket.status ?? null,
  isResolved: ticket.isResolved ?? null,
  isCritical: ticket.isCritical ?? null,
  component: ticket.component ?? null,
  subsystem: ticket.subsystem ?? null,
  tag: ticket.tag ?? null,
  classification: ticket.classification ?? null,
  otherDepartment: ticket.otherDepartment ?? null,
  remarks: ticket.remarks ?? null,
  acknowledgedByUid: ticket.acknowledgedByUid ?? null,
  acknowledgedByName: ticket.acknowledgedByName ?? null,
  acknowledgedAt: instantText(ticket.acknowledgedAt),
  workflowDeferred: ticket.workflowDeferred ?? false,
  isDeleted: ticket.isDeleted ?? null,
});

const requireTicket = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
): Promise<{ticket: JsonMap; version: number}> => {
  const snapshot = await tx.get(maintenancePath(command.aggregateId));
  if (!snapshot.exists || snapshot.data == null) {
    throw new WorkflowError(
      "not-found",
      "Maintenance ticket was not found.",
      {reasonCode: "maintenance-ticket-not-found"},
    );
  }
  const ticket = snapshot.data;
  const version = ticket.version;
  if (!Number.isSafeInteger(version) || (version as number) < 1 ||
      ticket.firestoreId !== command.aggregateId ||
      typeof ticket.isDeleted !== "boolean" ||
      typeof ticket.isResolved !== "boolean" ||
      (ticket.workflowDeferred != null &&
        typeof ticket.workflowDeferred !== "boolean") ||
      typeof ticket.status !== "string" || !STATUSES.has(ticket.status) ||
      ((ticket.status === "resolved") !== ticket.isResolved)) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket lifecycle evidence is malformed.",
      {reasonCode: "maintenance-ticket-evidence-invalid"},
    );
  }
  if (ticket.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Deleted maintenance tickets cannot be changed.",
      {reasonCode: "maintenance-ticket-deleted"},
    );
  }
  if (ticket.workflowDeferred === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Use the linked compliance request before changing this deferred ticket.",
      {reasonCode: "maintenance-ticket-workflow-deferred"},
    );
  }
  if (version !== command.expectedVersion) {
    throw new WorkflowError(
      "workflow-version-conflict",
      "Maintenance ticket changed before this command was applied.",
      {
        reasonCode: "maintenance-ticket-version-conflict",
        expectedVersion: command.expectedVersion,
        actualVersion: version,
      },
    );
  }
  return {ticket, version: version as number};
};

const requireVacantAudit = async (
  tx: WorkflowTransaction,
  commandId: string,
): Promise<void> => {
  const existing = await tx.get(auditPath(commandId));
  if (existing.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket audit identity is already occupied.",
      {reasonCode: "maintenance-ticket-audit-collision"},
    );
  }
};

const writeAudit = (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  at: Date;
  reason: string;
  summary: string;
  severity: "low" | "medium";
  before: JsonMap;
  after: JsonMap;
  resultVersion: number;
}): string => {
  const id = auditId(args.command.commandId);
  args.tx.create(auditPath(args.command.commandId), {
    schemaVersion: 1,
    auditId: id,
    entityType: "maintenance",
    entityId: args.command.aggregateId,
    action: "update",
    operation: args.command.commandType,
    performedByUid: args.actor.uid,
    performedByName: args.actor.name,
    timestamp: iso(args.at),
    reason: args.command.commandType === "correctMaintenanceTicket" ?
      "manualOverride" : "other",
    reasonNotes: args.reason,
    summary: args.summary,
    severity: args.severity,
    beforeJson: stableJson(args.before),
    afterJson: stableJson(args.after),
    requestId: args.command.commandId,
    resultVersion: args.resultVersion,
  });
  return id;
};

export const acknowledgeMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, [], "payload");
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  if (ticket.status !== "open" ||
      ticket.acknowledgedByUid != null ||
      ticket.acknowledgedByName != null ||
      ticket.acknowledgedAt != null) {
    throw new WorkflowError(
      "failed-precondition",
      "Only a clean open maintenance ticket can be acknowledged.",
      {reasonCode: "maintenance-ticket-not-open-for-acknowledgement"},
    );
  }
  const nextVersion = version + 1;
  const update: JsonMap = {
    status: "acknowledged",
    acknowledgedByUid: context.actor.uid,
    acknowledgedByName: context.actor.name,
    acknowledgedAt: iso(context.serverNow),
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason: "Maintenance ticket acknowledged by the accountable receiving authority.",
    summary: "Maintenance ticket acknowledged",
    severity: "low",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-acknowledged",
    aggregateVersion: nextVersion,
    result: {ticketId: command.aggregateId, auditId: id},
  };
};

const normalizeCorrections = (
  raw: JsonMap,
): Readonly<Record<string, string | boolean | null>> => {
  const keys = Object.keys(raw);
  if (keys.length === 0 || keys.some((key) => !CORRECTABLE_FIELDS.has(key))) {
    throw new WorkflowError(
      "invalid-argument",
      "Corrections must contain at least one supported maintenance field.",
      {reasonCode: "maintenance-ticket-corrections-invalid"},
    );
  }
  const corrections: {[key: string]: string | boolean | null} = {};
  for (const key of keys) {
    const value = raw[key];
    switch (key) {
    case "description":
      corrections[key] = boundedText(value, key, 5, 2000);
      break;
    case "routedTo": {
      const route = cleanText(value, key);
      if (!ROUTES.has(route)) {
        throw new WorkflowError("invalid-argument", "routedTo is unsupported.");
      }
      corrections[key] = route;
      break;
    }
    case "maintenanceType": {
      const type = cleanText(value, key);
      if (!MAINTENANCE_TYPES.has(type)) {
        throw new WorkflowError(
          "invalid-argument",
          "maintenanceType is unsupported.",
        );
      }
      corrections[key] = type;
      break;
    }
    case "isCritical":
      if (typeof value !== "boolean") {
        throw new WorkflowError("invalid-argument", "isCritical must be boolean.");
      }
      corrections[key] = value;
      break;
    case "component":
      corrections[key] = boundedText(value, key, 2, 120);
      break;
    case "tag": {
      const text = optionalText(value, key, 80);
      corrections[key] = text?.toUpperCase() ?? null;
      break;
    }
    case "otherDepartment":
      corrections[key] = optionalText(value, key, 80);
      break;
    case "remarks":
      corrections[key] = optionalText(value, key, 4000);
      break;
    default:
      corrections[key] = optionalText(value, key, 1000);
    }
  }
  return corrections;
};

export const correctMaintenanceTicket = async ({
  tx,
  command,
  context,
}: HandlerArgs): Promise<HandlerResult> => {
  exactKeys(command.payload, ["corrections", "reason"], "payload");
  const reason = boundedText(command.payload.reason, "reason", 12, 2000);
  const corrections = normalizeCorrections(
    record(command.payload.corrections, "corrections"),
  );
  const {ticket, version} = await requireTicket(tx, command);
  await requireVacantAudit(tx, command.commandId);
  const changed: {[key: string]: string | boolean | null} = {};
  for (const [key, value] of Object.entries(corrections)) {
    if ((ticket[key] ?? null) !== value) changed[key] = value;
  }
  const effectiveRoute = changed.routedTo ?? ticket.routedTo;
  const effectiveOtherDepartment = Object.prototype.hasOwnProperty.call(
    changed,
    "otherDepartment",
  ) ? changed.otherDepartment : ticket.otherDepartment ?? null;
  const validOtherDepartment = typeof effectiveOtherDepartment === "string" &&
    effectiveOtherDepartment.trim().length >= 2 &&
    effectiveOtherDepartment.length <= 80;
  if (typeof effectiveRoute !== "string" || !ROUTES.has(effectiveRoute) ||
      (effectiveRoute === "others" ?
        !validOtherDepartment : effectiveOtherDepartment != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Other department is required only when the ticket route is Others.",
      {reasonCode: "maintenance-ticket-route-department-invalid"},
    );
  }
  if (Object.keys(changed).length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The requested correction does not change the maintenance ticket.",
      {reasonCode: "maintenance-ticket-correction-noop"},
    );
  }
  const nextVersion = version + 1;
  const update: JsonMap = {
    ...changed,
    updatedAt: iso(context.serverNow),
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
    version: nextVersion,
  };
  const before = ticketSnapshot(ticket);
  const after = ticketSnapshot({...ticket, ...update});
  const id = writeAudit({
    tx,
    command,
    actor: context.actor,
    at: context.serverNow,
    reason,
    summary: `Maintenance ticket corrected: ${Object.keys(changed).sort().join(", ")}`,
    severity: "medium",
    before,
    after,
    resultVersion: nextVersion,
  });
  tx.update(maintenancePath(command.aggregateId), update);
  return {
    resultKey: "maintenance-ticket-corrected",
    aggregateVersion: nextVersion,
    result: {
      ticketId: command.aggregateId,
      auditId: id,
      correctedFields: Object.keys(changed).sort(),
    },
  };
};

const parsedAuditObject = (value: unknown): JsonMap | null => {
  if (typeof value !== "string") return null;
  try {
    const decoded = JSON.parse(value) as unknown;
    return decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    return null;
  }
};

export const verifyMaintenanceTicketAudit = async (args: {
  tx: WorkflowTransaction;
  command: WorkflowCommand;
  actor: Actor;
  receipt: WorkflowCommandReceipt;
}): Promise<void> => {
  if (args.command.commandType !== "acknowledgeMaintenanceTicket" &&
      args.command.commandType !== "correctMaintenanceTicket") return;
  const id = auditId(args.command.commandId);
  const audit = await args.tx.get(auditPath(args.command.commandId));
  const data = audit.data;
  if (!audit.exists || data == null ||
      data.schemaVersion !== 1 || data.auditId !== id ||
      data.entityType !== "maintenance" ||
      data.entityId !== args.command.aggregateId ||
      data.operation !== args.command.commandType ||
      data.requestId !== args.command.commandId ||
      data.performedByUid !== args.actor.uid ||
      data.resultVersion !== args.receipt.aggregateVersion ||
      args.receipt.result.auditId !== id ||
      parsedAuditObject(data.beforeJson) == null ||
      parsedAuditObject(data.afterJson) == null) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance ticket receipt no longer matches its immutable audit.",
      {reasonCode: "maintenance-ticket-replay-audit-invalid"},
    );
  }
};
