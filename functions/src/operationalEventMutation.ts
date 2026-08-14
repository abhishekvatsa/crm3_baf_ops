import {createHash} from "crypto";

import {
  AssetHierarchyMutationError,
  AssetHierarchyMutationFirestoreLike,
} from "./assetHierarchyMutation";
import {stableJson} from "./stableJson";
import {canonicalApprovedUserAuthority} from "./userAuthority";

type JsonMap = {[key: string]: unknown};
type SnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => JsonMap | undefined;
};
type DocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<SnapshotLike>;
};
type QuerySnapshotLike = {docs: SnapshotLike[]};
type TransactionLike = {
  get: (ref: unknown) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap) => void;
};

export type OperationalEventOperation =
  | "CREATE_OPERATIONAL_EVENT"
  | "UPDATE_OPERATIONAL_EVENT"
  | "RESOLVE_OPERATIONAL_EVENT"
  | "REOPEN_OPERATIONAL_EVENT";

type EventType =
  | "water"
  | "nitrogen"
  | "mixedGas"
  | "hydrogen"
  | "powerTrip"
  | "crane"
  | "transferCar"
  | "other";
type Severity = "advisory" | "significant" | "critical";
type Scope = "plantWide" | "assetClasses" | "assets";
type CompletedInterval = {
  startedAt: unknown;
  resolvedAt: unknown;
};

interface EventDraft {
  eventType: EventType;
  title: string;
  description: string;
  severity: Severity;
  scope: Scope;
  affectedAssetClassIds: ReadonlyArray<string>;
  affectedAssetInstanceIds: ReadonlyArray<string>;
  startedAtIso: string;
}

interface ParsedRequest {
  requestId: string;
  operation: OperationalEventOperation;
  eventId: string;
  expectedVersion: number;
  reason: string;
  eventDraft: EventDraft | null;
  resolutionNote: string | null;
  fingerprint: string;
}

export interface OperationalEventMutationResult {
  ok: true;
  requestId: string;
  operation: OperationalEventOperation;
  eventId: string;
  status: "open" | "resolved";
  version: number;
  auditId: string;
  committedAt: string;
  idempotentReplay: boolean;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPERATIONS = new Set<OperationalEventOperation>([
  "CREATE_OPERATIONAL_EVENT",
  "UPDATE_OPERATIONAL_EVENT",
  "RESOLVE_OPERATIONAL_EVENT",
  "REOPEN_OPERATIONAL_EVENT",
]);
const EVENT_TYPES = new Set<EventType>([
  "water", "nitrogen", "mixedGas", "hydrogen", "powerTrip", "crane",
  "transferCar", "other",
]);
const SEVERITIES = new Set<Severity>([
  "advisory", "significant", "critical",
]);
const SCOPES = new Set<Scope>(["plantWide", "assetClasses", "assets"]);
const MAX_COMPLETED_INTERVALS = 100;
const WRITE_ROLES = new Set([
  "admin", "si", "shiftSupervisor", "operations", "contractSupervisor",
]);
const RESOLUTION_ROLES = new Set([
  "admin", "si", "shiftSupervisor", "operations",
]);

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `${field} ${detail}.`,
    {reasonCode: "invalid-operational-event-request", field},
  );
}

function requiredString(value: unknown, field: string, maximum: number): string {
  if (typeof value !== "string") invalid(field, "must be a string");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0 || cleaned.length > maximum) {
    invalid(field, `must contain 1-${maximum} characters`);
  }
  return cleaned;
}

function documentId(value: unknown, field: string): string {
  const id = requiredString(value, field, 128);
  if (id === "." || id === ".." || id.includes("/")) {
    invalid(field, "is invalid");
  }
  return id;
}

function stringSet(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length > maximum) {
    invalid(field, `must be a list of at most ${maximum} values`);
  }
  const output = value.map((item) => documentId(item, field));
  if (new Set(output).size !== output.length) {
    invalid(field, "must not contain duplicates");
  }
  return output.sort();
}

function canonicalIso(value: unknown, field: string): string {
  const text = requiredString(value, field, 40);
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString() !== text) {
    invalid(field, "must be a canonical UTC instant");
  }
  return text;
}

function parseDraft(value: unknown): EventDraft {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid("eventDraft", "must be an object");
  }
  const raw = value as JsonMap;
  const allowed = new Set([
    "eventType", "title", "description", "severity", "scope",
    "affectedAssetClassIds", "affectedAssetInstanceIds", "startedAt",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(`eventDraft.${key}`, "is unsupported");
  }
  const eventType = requiredString(
    raw.eventType,
    "eventDraft.eventType",
    24,
  ) as EventType;
  const severity = requiredString(
    raw.severity,
    "eventDraft.severity",
    16,
  ) as Severity;
  const scope = requiredString(raw.scope, "eventDraft.scope", 20) as Scope;
  if (!EVENT_TYPES.has(eventType)) {
    invalid("eventDraft.eventType", "is unsupported");
  }
  if (!SEVERITIES.has(severity)) {
    invalid("eventDraft.severity", "is unsupported");
  }
  if (!SCOPES.has(scope)) invalid("eventDraft.scope", "is unsupported");
  const assetClassIds = stringSet(
    raw.affectedAssetClassIds,
    "eventDraft.affectedAssetClassIds",
    20,
  );
  const assetInstanceIds = stringSet(
    raw.affectedAssetInstanceIds,
    "eventDraft.affectedAssetInstanceIds",
    50,
  );
  if (scope === "plantWide" &&
      (assetClassIds.length > 0 || assetInstanceIds.length > 0)) {
    invalid("eventDraft.scope", "plant-wide scope cannot name specific assets");
  }
  if (scope === "assetClasses" &&
      (assetClassIds.length === 0 || assetInstanceIds.length > 0)) {
    invalid("eventDraft.scope", "asset-class scope requires only class IDs");
  }
  if (scope === "assets" && assetInstanceIds.length === 0) {
    invalid("eventDraft.scope", "asset scope requires asset IDs");
  }
  return {
    eventType,
    title: requiredString(raw.title, "eventDraft.title", 120),
    description: requiredString(
      raw.description,
      "eventDraft.description",
      2000,
    ),
    severity,
    scope,
    affectedAssetClassIds: assetClassIds,
    affectedAssetInstanceIds: assetInstanceIds,
    startedAtIso: canonicalIso(raw.startedAt, "eventDraft.startedAt"),
  };
}

export function isOperationalEventOperation(
  value: unknown,
): value is OperationalEventOperation {
  return typeof value === "string" &&
    OPERATIONS.has(value as OperationalEventOperation);
}

export function parseOperationalEventMutationRequest(raw: JsonMap): ParsedRequest {
  const allowed = new Set([
    "requestId", "operation", "eventId", "expectedVersion", "reason",
    "eventDraft", "resolutionNote",
  ]);
  for (const key of Object.keys(raw)) {
    if (!allowed.has(key)) invalid(key, "is unsupported");
  }
  const requestId = requiredString(raw.requestId, "requestId", 64);
  if (!UUID.test(requestId)) invalid("requestId", "must be a canonical UUID");
  const eventId = requiredString(raw.eventId, "eventId", 64);
  if (!UUID.test(eventId)) invalid("eventId", "must be a canonical UUID");
  const operation = requiredString(
    raw.operation,
    "operation",
    40,
  ) as OperationalEventOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  if (!Number.isSafeInteger(raw.expectedVersion) ||
      (raw.expectedVersion as number) < 0) {
    invalid("expectedVersion", "must be a non-negative integer");
  }
  const reason = requiredString(raw.reason, "reason", 1000);
  if (reason.length < 8) invalid("reason", "must contain at least 8 characters");
  const hasDraft = operation === "CREATE_OPERATIONAL_EVENT" ||
    operation === "UPDATE_OPERATIONAL_EVENT";
  const eventDraft = hasDraft ? parseDraft(raw.eventDraft) : null;
  const resolutionNote = operation === "RESOLVE_OPERATIONAL_EVENT" ?
    requiredString(raw.resolutionNote, "resolutionNote", 1000) : null;
  if (operation === "RESOLVE_OPERATIONAL_EVENT" &&
      resolutionNote!.length < 8) {
    invalid("resolutionNote", "must contain at least 8 characters");
  }
  if (!hasDraft && raw.eventDraft != null) {
    invalid("eventDraft", "is not allowed for this operation");
  }
  if (operation !== "RESOLVE_OPERATIONAL_EVENT" &&
      raw.resolutionNote != null) {
    invalid("resolutionNote", "is not allowed for this operation");
  }
  if (operation === "CREATE_OPERATIONAL_EVENT" && raw.expectedVersion !== 0) {
    invalid("expectedVersion", "must be zero when creating an event");
  }
  const request = {
    requestId,
    operation,
    eventId,
    expectedVersion: raw.expectedVersion as number,
    reason,
    eventDraft,
    resolutionNote,
  };
  const fingerprint = `operationalevent1-sha256:${createHash("sha256")
    .update(stableJson(request), "utf8").digest("hex")}`;
  return {...request, fingerprint};
}

export function userCanMutateOperationalEvent(
  data: JsonMap,
  operation: OperationalEventOperation,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  if (authority == null) return false;
  const allowed = operation === "RESOLVE_OPERATIONAL_EVENT" ||
    operation === "REOPEN_OPERATIONAL_EVENT" ?
    RESOLUTION_ROLES : WRITE_ROLES;
  return [...authority.roles].some((role) => allowed.has(role));
}

function asSnapshot(value: SnapshotLike | QuerySnapshotLike, label: string): SnapshotLike {
  if ("docs" in value) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a query.`);
  }
  return value;
}

function record(value: SnapshotLike, label: string): JsonMap {
  const data = value.data();
  if (!value.exists || data == null) {
    throw new AssetHierarchyMutationError("not-found", `${label} was not found.`);
  }
  return data;
}

function actor(
  value: SnapshotLike,
  operation: OperationalEventOperation,
): JsonMap {
  const data = record(value, "Operational-event actor");
  if (!userCanMutateOperationalEvent(data, operation)) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      operation === "RESOLVE_OPERATIONAL_EVENT" ||
        operation === "REOPEN_OPERATIONAL_EVENT" ?
        "Only approved Operations, Shift Supervisor, SI, or Admin users can change event closure." :
        "Only approved operational or supervisory users can record an operational event.",
    );
  }
  return data;
}

function actorName(data: JsonMap): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : "Approved user";
}

function timestampDate(value: unknown): Date | null {
  if (value != null && typeof value === "object" &&
      Object.prototype.toString.call(value) === "[object Date]") {
    try {
      const date = value as Date;
      return Number.isNaN(Date.prototype.getTime.call(date)) ? null : date;
    } catch {
      return null;
    }
  }
  if (value == null || typeof value !== "object" || Array.isArray(value) ||
      typeof (value as {toDate?: unknown}).toDate !== "function") return null;
  try {
    const date = (value as {toDate: () => unknown}).toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  } catch {
    return null;
  }
}

function isTimestampLike(value: unknown): boolean {
  return timestampDate(value) != null;
}

function requireCompletedIntervals(value: unknown): CompletedInterval[] {
  if (!Array.isArray(value) || value.length > MAX_COMPLETED_INTERVALS) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The operational event has malformed completed intervals.",
      {reasonCode: "operational-event-projection-malformed", field: "completedIntervals"},
    );
  }
  let previousResolvedAt: Date | null = null;
  return value.map((entry, index) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "The operational event has malformed completed intervals.",
        {reasonCode: "operational-event-projection-malformed", field: `completedIntervals[${index}]`},
      );
    }
    const interval = entry as JsonMap;
    const keys = Object.keys(interval);
    const startedAt = timestampDate(interval.startedAt);
    const resolvedAt = timestampDate(interval.resolvedAt);
    if (keys.length !== 2 || !keys.includes("startedAt") ||
        !keys.includes("resolvedAt") || startedAt == null || resolvedAt == null ||
        resolvedAt.getTime() < startedAt.getTime() ||
        (previousResolvedAt != null &&
          startedAt.getTime() < previousResolvedAt.getTime())) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "The operational event has malformed completed intervals.",
        {reasonCode: "operational-event-projection-malformed", field: `completedIntervals[${index}]`},
      );
    }
    previousResolvedAt = resolvedAt;
    return {
      startedAt: interval.startedAt,
      resolvedAt: interval.resolvedAt,
    };
  });
}

function requireStringList(
  value: unknown,
  field: string,
  maximum: number,
): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length > maximum ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.length > 128 ||
        item === "." || item === ".." || item.includes("/")) ||
      new Set(value).size !== value.length) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `The operational event has malformed ${field}.`,
      {reasonCode: "operational-event-projection-malformed", field},
    );
  }
  return value as string[];
}

function validateCurrentEvent(data: JsonMap | null, eventId: string): number {
  if (data == null) return 0;
  const completedIntervals = requireCompletedIntervals(data.completedIntervals);
  const classIds = requireStringList(
    data.affectedAssetClassIds,
    "affectedAssetClassIds",
    20,
  );
  const assetIds = requireStringList(
    data.affectedAssetInstanceIds,
    "affectedAssetInstanceIds",
    50,
  );
  const resolvedValues = [
    data.resolvedAt,
    data.resolvedByUid,
    data.resolvedByName,
    data.resolutionNote,
  ];
  const resolutionAbsent = resolvedValues.every((value) => value == null);
  const startedAt = timestampDate(data.startedAt);
  const resolvedAt = timestampDate(data.resolvedAt);
  const resolutionComplete = resolvedAt != null &&
    typeof data.resolvedByUid === "string" && data.resolvedByUid.length > 0 &&
    typeof data.resolvedByName === "string" && data.resolvedByName.length > 0 &&
    typeof data.resolutionNote === "string" && data.resolutionNote.length >= 8;
  const scopeValid = data.scope === "plantWide" ?
    classIds.length === 0 && assetIds.length === 0 :
    data.scope === "assetClasses" ?
      classIds.length > 0 && assetIds.length === 0 :
      data.scope === "assets" && assetIds.length > 0;
  const statusValid = data.status === "open" ? resolutionAbsent :
    data.status === "resolved" && resolutionComplete;
  const latestCompleted = completedIntervals.at(-1);
  const latestCompletedAt = latestCompleted == null ? null :
    timestampDate(latestCompleted.resolvedAt);
  const chronologyValid = startedAt != null &&
    (resolvedAt == null || resolvedAt.getTime() >= startedAt.getTime()) &&
    (latestCompletedAt == null ||
      startedAt.getTime() >= latestCompletedAt.getTime());
  if (data.schemaVersion !== 1 || data.eventId !== eventId ||
      !EVENT_TYPES.has(data.eventType as EventType) ||
      typeof data.title !== "string" || data.title.trim().length === 0 ||
      data.title.length > 120 || typeof data.description !== "string" ||
      data.description.trim().length === 0 || data.description.length > 2000 ||
      !SEVERITIES.has(data.severity as Severity) || !scopeValid || !statusValid ||
      !chronologyValid || !isTimestampLike(data.createdAt) ||
      typeof data.createdByUid !== "string" || data.createdByUid.length === 0 ||
      data.createdByUid.length > 128 || typeof data.createdByName !== "string" ||
      data.createdByName.length === 0 || data.createdByName.length > 200 ||
      !isTimestampLike(data.updatedAt) || typeof data.updatedByUid !== "string" ||
      data.updatedByUid.length === 0 || data.updatedByUid.length > 128 ||
      typeof data.updatedByName !== "string" || data.updatedByName.length === 0 ||
      data.updatedByName.length > 200 || !Number.isSafeInteger(data.version) ||
      (data.version as number) < 1 || typeof data.lastMutationId !== "string" ||
      !UUID.test(data.lastMutationId) ||
      (data.status === "resolved" &&
        ((data.resolvedByUid as string).length > 128 ||
          (data.resolvedByName as string).length > 200 ||
          (data.resolutionNote as string).length > 1000))) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The existing operational-event projection is incomplete or malformed.",
      {reasonCode: "operational-event-projection-malformed"},
    );
  }
  return data.version as number;
}

function eventSnapshot(data: JsonMap | null): JsonMap | null {
  if (data == null) return null;
  return {
    eventId: data.eventId,
    eventType: data.eventType,
    title: data.title,
    description: data.description,
    severity: data.severity,
    scope: data.scope,
    affectedAssetClassIds: data.affectedAssetClassIds,
    affectedAssetInstanceIds: data.affectedAssetInstanceIds,
    completedIntervals: data.completedIntervals,
    startedAt: data.startedAt,
    status: data.status,
    resolvedAt: data.resolvedAt,
    resolvedByUid: data.resolvedByUid,
    resolvedByName: data.resolvedByName,
    resolutionNote: data.resolutionNote,
    updatedAt: data.updatedAt,
    updatedByUid: data.updatedByUid,
    updatedByName: data.updatedByName,
    version: data.version,
    lastMutationId: data.lastMutationId,
  };
}

function verifyClass(data: JsonMap, classId: string): void {
  if (data.schemaVersion !== 1 || data.assetClassId !== classId ||
      data.status !== "active" || typeof data.name !== "string" ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Affected asset class ${classId} is malformed or retired.`,
      {reasonCode: "operational-event-asset-class-invalid", classId},
    );
  }
}

function verifyAsset(data: JsonMap, assetId: string): string {
  if (data.schemaVersion !== 1 || data.assetInstanceId !== assetId ||
      data.status !== "active" || typeof data.assetClassId !== "string" ||
      typeof data.name !== "string" || !Number.isSafeInteger(data.assetNumber) ||
      !Number.isSafeInteger(data.version) || (data.version as number) < 1) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      `Affected asset ${assetId} is malformed or retired.`,
      {reasonCode: "operational-event-asset-invalid", assetId},
    );
  }
  return data.assetClassId as string;
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): OperationalEventMutationResult {
  if (data.actorUid !== actorUid || data.fingerprint !== request.fingerprint ||
      data.operation !== request.operation || data.eventId !== request.eventId ||
      !Number.isSafeInteger(data.version) ||
      !["open", "resolved"].includes(data.status as string) ||
      typeof data.auditId !== "string" || typeof data.committedAtIso !== "string") {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The operational-event receipt is malformed or mismatched.",
      {reasonCode: "operational-event-receipt-mismatch"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    eventId: request.eventId,
    status: data.status as "open" | "resolved",
    version: data.version as number,
    auditId: data.auditId as string,
    committedAt: data.committedAtIso as string,
    idempotentReplay: true,
  };
}

export async function mutateOperationalEventWithDb(args: {
  db: AssetHierarchyMutationFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<OperationalEventMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before changing an operational event.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseOperationalEventMutationRequest(args.data);
  const db = args.db;
  const users = db.collection("users");
  const events = db.collection("operational_events");
  const audits = db.collection("operational_event_audits");
  const receipts = db.collection("operational_event_receipts");
  const classes = db.collection("asset_classes");
  const assets = db.collection("asset_instances");
  const actorRef = users.doc(actorUid);
  const eventRef = events.doc(request.eventId);
  const auditId = `operational_event_${request.requestId}`;
  const auditRef = audits.doc(auditId);
  const receiptRef = receipts.doc(request.requestId);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  actor(await actorRef.get(), request.operation);

  return db.runTransaction(async (rawTransaction) => {
    const transaction = rawTransaction as unknown as TransactionLike;
    const receiptValue = asSnapshot(
      await transaction.get(receiptRef),
      "Operational-event receipt lookup",
    );
    const auditValue = asSnapshot(
      await transaction.get(auditRef),
      "Operational-event audit lookup",
    );
    const actorData = actor(
      asSnapshot(await transaction.get(actorRef), "Operational-event actor lookup"),
      request.operation,
    );
    const eventValue = asSnapshot(
      await transaction.get(eventRef),
      "Operational-event lookup",
    );
    const current = eventValue.exists ? eventValue.data() ?? {} : null;
    const currentVersion = validateCurrentEvent(current, request.eventId);

    if (receiptValue.exists) {
      const replay = resultFromReceipt(request, actorUid, receiptValue.data() ?? {});
      const auditData = record(auditValue, "Recorded operational-event audit");
      if (current == null || current.version !== replay.version ||
          current.lastMutationId !== request.requestId ||
          auditData.requestId !== request.requestId ||
          auditData.performedByUid !== actorUid ||
          auditData.eventId !== request.eventId) {
        throw new AssetHierarchyMutationError(
          "data-loss",
          "The operational-event receipt no longer matches its state and audit evidence.",
          {reasonCode: "operational-event-replay-evidence-drift"},
        );
      }
      return replay;
    }
    if (auditValue.exists) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "An operational-event audit exists without its request receipt.",
        {reasonCode: "operational-event-orphan-audit"},
      );
    }
    if (request.operation === "CREATE_OPERATIONAL_EVENT" && current != null) {
      throw new AssetHierarchyMutationError(
        "already-exists",
        "An operational event already exists with this identity.",
      );
    }
    if (request.operation !== "CREATE_OPERATIONAL_EVENT" && current == null) {
      throw new AssetHierarchyMutationError(
        "not-found",
        "The operational event was not found.",
      );
    }
    if (currentVersion !== request.expectedVersion) {
      throw new AssetHierarchyMutationError(
        "aborted",
        "The operational event changed before this command was committed.",
        {reasonCode: "operational-event-version-mismatch", currentVersion},
      );
    }
    if (request.operation === "UPDATE_OPERATIONAL_EVENT" &&
        current?.status !== "open") {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "Resolve history cannot be edited. Reopen the event before updating it.",
        {reasonCode: "operational-event-not-open"},
      );
    }
    if (request.operation === "RESOLVE_OPERATIONAL_EVENT" &&
        current?.status !== "open") {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "Only an open operational event can be resolved.",
        {reasonCode: "operational-event-not-open"},
      );
    }
    if (request.operation === "REOPEN_OPERATIONAL_EVENT" &&
        current?.status !== "resolved") {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "Only a resolved operational event can be reopened.",
        {reasonCode: "operational-event-not-resolved"},
      );
    }
    if (request.operation === "REOPEN_OPERATIONAL_EVENT" &&
        (current?.completedIntervals as unknown[]).length >= MAX_COMPLETED_INTERVALS) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "This event has reached its recurrence-history limit; record a new event.",
        {reasonCode: "operational-event-recurrence-history-full"},
      );
    }

    const draft = request.eventDraft;
    if (draft != null) {
      const classIds = new Set(draft.affectedAssetClassIds);
      for (const classId of draft.affectedAssetClassIds) {
        const value = asSnapshot(
          await transaction.get(classes.doc(classId)),
          `Affected asset class ${classId} lookup`,
        );
        verifyClass(record(value, `Affected asset class ${classId}`), classId);
      }
      for (const assetId of draft.affectedAssetInstanceIds) {
        const value = asSnapshot(
          await transaction.get(assets.doc(assetId)),
          `Affected asset ${assetId} lookup`,
        );
        const classId = verifyAsset(record(value, `Affected asset ${assetId}`), assetId);
        if (classIds.size > 0 && !classIds.has(classId)) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            `Affected asset ${assetId} is outside the selected asset classes.`,
            {reasonCode: "operational-event-asset-class-mismatch", assetId},
          );
        }
      }
    }

    const committed = now();
    const committedAt = timestampFromDate(committed);
    const requestedStart = draft == null ? null : new Date(draft.startedAtIso);
    const existingStart = current == null ? null : timestampDate(current.startedAt);
    if ((requestedStart != null && requestedStart.getTime() > committed.getTime()) ||
        (draft == null && existingStart != null &&
          existingStart.getTime() > committed.getTime())) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "An operational event cannot start after the current server time.",
        {reasonCode: "operational-event-started-at-future"},
      );
    }
    const version = currentVersion + 1;
    let next: JsonMap;
    if (draft != null) {
      next = {
        schemaVersion: 1,
        eventId: request.eventId,
        eventType: draft.eventType,
        title: draft.title,
        description: draft.description,
        severity: draft.severity,
        scope: draft.scope,
        affectedAssetClassIds: draft.affectedAssetClassIds,
        affectedAssetInstanceIds: draft.affectedAssetInstanceIds,
        completedIntervals: current?.completedIntervals ?? [],
        startedAt: timestampFromDate(new Date(draft.startedAtIso)),
        status: current?.status ?? "open",
        createdAt: current?.createdAt ?? committedAt,
        createdByUid: current?.createdByUid ?? actorUid,
        createdByName: current?.createdByName ?? actorName(actorData),
        resolvedAt: current?.resolvedAt ?? null,
        resolvedByUid: current?.resolvedByUid ?? null,
        resolvedByName: current?.resolvedByName ?? null,
        resolutionNote: current?.resolutionNote ?? null,
        version,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName(actorData),
        lastMutationId: request.requestId,
      };
    } else if (request.operation === "RESOLVE_OPERATIONAL_EVENT") {
      next = {
        ...current!,
        status: "resolved",
        resolvedAt: committedAt,
        resolvedByUid: actorUid,
        resolvedByName: actorName(actorData),
        resolutionNote: request.resolutionNote,
        version,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName(actorData),
        lastMutationId: request.requestId,
      };
    } else {
      next = {
        ...current!,
        status: "open",
        completedIntervals: [
          ...(current!.completedIntervals as CompletedInterval[]),
          {startedAt: current!.startedAt, resolvedAt: current!.resolvedAt},
        ],
        startedAt: committedAt,
        resolvedAt: null,
        resolvedByUid: null,
        resolvedByName: null,
        resolutionNote: null,
        version,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: actorName(actorData),
        lastMutationId: request.requestId,
      };
    }
    validateCurrentEvent(next, request.eventId);
    const audit: JsonMap = {
      schemaVersion: 1,
      auditId,
      requestId: request.requestId,
      operation: request.operation,
      eventId: request.eventId,
      before: eventSnapshot(current),
      after: eventSnapshot(next),
      performedAt: committedAt,
      performedByUid: actorUid,
      performedByName: actorName(actorData),
      reason: request.reason,
      resolutionNote: request.resolutionNote,
    };
    const receipt: JsonMap = {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      operation: request.operation,
      eventId: request.eventId,
      status: next.status,
      version,
      auditId,
      committedAt,
      committedAtIso: committed.toISOString(),
    };
    transaction.set(eventRef as unknown as DocumentRefLike, next);
    transaction.set(auditRef as unknown as DocumentRefLike, audit);
    transaction.set(receiptRef as unknown as DocumentRefLike, receipt);
    return {
      ok: true,
      requestId: request.requestId,
      operation: request.operation,
      eventId: request.eventId,
      status: next.status as "open" | "resolved",
      version,
      auditId,
      committedAt: committed.toISOString(),
      idempotentReplay: false,
    };
  });
}
