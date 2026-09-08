import {createHash} from "crypto";

import {AssetHierarchyMutationError} from "./assetHierarchyMutation";
import {persistedInstantMillis} from "./persistedInstant";
import {validateQualityWarningRecord} from "./qualityMutation";
import {stableJson} from "./stableJson";
import {
  canonicalApprovedUserAuthority,
  normalizeCanonicalUserRoles,
} from "./userAuthority";

type JsonMap = {[key: string]: unknown};

type MorningReviewOperation =
  | "START_MORNING_REVIEW"
  | "JOIN_MORNING_REVIEW"
  | "ADD_MORNING_REVIEW_ENTRY"
  | "CREATE_MORNING_REVIEW_ACTION"
  | "ACCEPT_MORNING_REVIEW_ACTION"
  | "COMPLETE_MORNING_REVIEW_ACTION"
  | "TAKE_OVER_MORNING_REVIEW"
  | "FINALIZE_MORNING_REVIEW"
  | "RECORD_MORNING_REVIEW_NOT_HELD"
  | "CREATE_MORNING_REVIEW_STANDING_CONCERN"
  | "RESOLVE_MORNING_REVIEW_STANDING_CONCERN"
  | "CHECK_MORNING_REVIEW_STANDING_CONCERN"
  | "ADD_MORNING_REVIEW_ADDENDUM";

type MorningReviewSection =
  | "safety"
  | "furnace"
  | "base"
  | "forcedCooler"
  | "otherAsset"
  | "plantWide";

type MorningReviewEntryKind =
  | "update"
  | "observation"
  | "plan"
  | "blocker"
  | "decision"
  | "idea"
  | "currentCompliance"
  | "remainingCompliance"
  | "maintenanceUpdate"
  | "conclusion"
  | "safetyConcern"
  | "standingConcernCheck"
  | "addendum";

type SnapshotLike = {
  readonly exists: boolean;
  readonly id: string;
  data: () => JsonMap | undefined;
};

type QuerySnapshotLike = {readonly docs: ReadonlyArray<SnapshotLike>};

type DocumentRefLike = {
  readonly id: string;
  readonly path?: string;
  get: () => Promise<SnapshotLike>;
};

type QueryLike = {
  where: (field: string, op: string, value: unknown) => QueryLike;
  orderBy: (field: string) => QueryLike;
  startAfter: (snapshot: SnapshotLike) => QueryLike;
  limit: (value: number) => QueryLike;
  get: () => Promise<QuerySnapshotLike>;
};

type CollectionLike = QueryLike & {
  doc: (id: string) => DocumentRefLike;
};

type TransactionLike = {
  get: (
    ref: DocumentRefLike | QueryLike,
  ) => Promise<SnapshotLike | QuerySnapshotLike>;
  set: (ref: DocumentRefLike, data: JsonMap, options?: JsonMap) => void;
  delete: (ref: DocumentRefLike) => void;
};

export type MorningReviewFirestoreLike = {
  collection: (name: string) => CollectionLike;
  runTransaction: <T>(fn: (transaction: TransactionLike) => Promise<T>) =>
    Promise<T>;
};

interface MorningReviewEntryDraft {
  section: MorningReviewSection;
  kind: MorningReviewEntryKind;
  text: string;
  assetClassId: string | null;
  assetClassName: string | null;
  assetInstanceId: string | null;
  assetNumber: string | null;
  sourceReferences: ReadonlyArray<string>;
}

interface MorningReviewActionDraft {
  section: MorningReviewSection;
  text: string;
  assigneeUid: string | null;
  assigneeRole: string | null;
  assetClassId: string | null;
  assetClassName: string | null;
  assetInstanceId: string | null;
  assetNumber: string | null;
  dueAtIso: string | null;
}

interface StandingConcernDraft {
  title: string;
  detail: string;
  criticality: "standing" | "safety";
}

interface ParsedRequest {
  requestId: string;
  operation: MorningReviewOperation;
  sessionId: string | null;
  expectedVersion: number | null;
  actionId: string | null;
  concernId: string | null;
  reason: string | null;
  summary: string | null;
  checkState: "complied" | "exception" | null;
  entryDraft: MorningReviewEntryDraft | null;
  actionDraft: MorningReviewActionDraft | null;
  concernDraft: StandingConcernDraft | null;
  fingerprint: string;
}

export interface MorningReviewMutationResult {
  readonly ok: true;
  readonly requestId: string;
  readonly operation: MorningReviewOperation;
  readonly sessionId: string | null;
  readonly entityId: string;
  readonly status: string;
  readonly version: number;
  readonly committedAt: string;
  readonly idempotentReplay: boolean;
}

export interface MorningReviewSourceFact {
  readonly factId: string;
  readonly section: MorningReviewSection;
  readonly sourceType: string;
  readonly sourceCollection: string;
  readonly sourceDocumentId: string;
  readonly title: string;
  readonly summary: string;
  readonly status: string;
  readonly assetClassId: string | null;
  readonly assetClassName: string | null;
  readonly assetInstanceId: string | null;
  readonly assetNumber: string | null;
  readonly observedAtIso: string | null;
}

export interface MorningReviewSourceCapture {
  readonly facts: ReadonlyArray<MorningReviewSourceFact>;
  readonly sourceCollectionsAtLimit: ReadonlyArray<string>;
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PLANT_DAY = /^\d{4}-\d{2}-\d{2}$/;
const RETENTION_DAYS = 14;
const INDIA_OFFSET_MINUTES = 330;
const START_MINUTE = 8 * 60;
const END_MINUTE = 10 * 60;
const MAX_SOURCE_FACTS = 220;
const SOURCE_SCAN_PAGE_SIZE = 300;
const MAX_SOURCE_SCAN_PAGES = 10;
const MAX_SOURCE_COLLECTION_MARKERS = 10;
const MAX_SESSION_ENTRIES = 180;
const MAX_SESSION_ACTIONS = 100;
const MAX_SESSION_PARTICIPANTS = 100;
const MAX_STANDING_CONCERNS = 250;
const MAX_SOURCE_REFERENCES = 12;
const MAX_FROZEN_DOCUMENT_BYTES = 800 * 1024;
const MAX_COMMAND_REASON_LENGTH = 1600;
// Firebase Auth UID bound and the canonical user name bound in Firestore rules.
const MAX_ACTION_ACTOR_UID_LENGTH = 128;
const MAX_ACTION_ACTOR_NAME_LENGTH = 160;
const ACTIVE_SOURCE_STATUSES = new Set([
  "open", "raised", "supportconfirmed", "acknowledged", "accepted",
  "inprogress", "active", "deferred", "actionable", "awaitingconfirmation",
  "down", "unfit", "unavailable", "stuckup", "temporarilyblocked", "due",
  "overdue", "closurerequested", "correctiveactionlinked",
  "awaitingverification", "closedwithoutresolutionstillrelevant",
]);
const INSPECTION_FINDING_STATUSES = new Set([
  "open", "correctiveActionLinked", "awaitingVerification",
  "verifiedResolved", "acceptedCondition", "invalidated",
]);
const TERMINAL_INSPECTION_FINDING_STATUSES = new Set([
  "verifiedResolved", "acceptedCondition", "invalidated",
]);
const INSPECTION_COMPARISON_OUTCOMES = new Set([
  "improved", "unchanged", "deteriorated", "resolved", "recurred",
  "notComparable",
]);
const SOURCE_MUTATION_TIME_FIELDS = [
  "updatedAt", "createdAt", "raisedAt", "openedAt", "reportedAt",
  "startedAt", "resolvedAt", "restoredAt", "completedAt", "cancelledAt",
  "closedAt", "withdrawnAt", "reopenedAt", "closureRequestedAt",
  "latestObservedAt", "morningReviewObservedAt",
] as const;
const START_ROLES = new Set(["admin", "si"]);
const MAINTENANCE_UPDATE_ROLES = new Set([
  "admin", "si", "contractSupervisor", "shiftSupervisor",
  "seniorElectrical", "seniorMechanical", "seniorInstrumentation",
  "seniorRefractory",
]);
const ACTION_ROLES = new Set([
  "admin", "si", "contractSupervisor", "shiftSupervisor",
  "seniorElectrical", "seniorMechanical", "seniorInstrumentation",
  "seniorRefractory", "refractory", "operations",
]);

const OPERATIONS = new Set<MorningReviewOperation>([
  "START_MORNING_REVIEW",
  "JOIN_MORNING_REVIEW",
  "ADD_MORNING_REVIEW_ENTRY",
  "CREATE_MORNING_REVIEW_ACTION",
  "ACCEPT_MORNING_REVIEW_ACTION",
  "COMPLETE_MORNING_REVIEW_ACTION",
  "TAKE_OVER_MORNING_REVIEW",
  "FINALIZE_MORNING_REVIEW",
  "RECORD_MORNING_REVIEW_NOT_HELD",
  "CREATE_MORNING_REVIEW_STANDING_CONCERN",
  "RESOLVE_MORNING_REVIEW_STANDING_CONCERN",
  "CHECK_MORNING_REVIEW_STANDING_CONCERN",
  "ADD_MORNING_REVIEW_ADDENDUM",
]);

const SECTIONS = new Set<MorningReviewSection>([
  "safety", "furnace", "base", "forcedCooler", "otherAsset", "plantWide",
]);
const ENTRY_KINDS = new Set<MorningReviewEntryKind>([
  "update", "observation", "plan", "blocker", "decision", "idea",
  "currentCompliance", "remainingCompliance", "maintenanceUpdate",
  "conclusion", "safetyConcern", "standingConcernCheck", "addendum",
]);

const ENTRY_DRAFT_KEYS = new Set([
  "section", "kind", "text", "assetClassId", "assetClassName",
  "assetInstanceId", "assetNumber", "sourceReferences",
]);
const ACTION_DRAFT_KEYS = new Set([
  "section", "text", "assigneeUid", "assigneeRole", "assetClassId",
  "assetClassName", "assetInstanceId", "assetNumber", "dueAt",
]);
const CONCERN_DRAFT_KEYS = new Set(["title", "detail", "criticality"]);

const ALLOWED_KEYS: Readonly<Record<MorningReviewOperation, ReadonlySet<string>>> =
  Object.freeze({
    START_MORNING_REVIEW: new Set(["requestId", "operation"]),
    JOIN_MORNING_REVIEW: new Set(["requestId", "operation", "sessionId"]),
    ADD_MORNING_REVIEW_ENTRY: new Set([
      "requestId", "operation", "sessionId", "entryDraft",
    ]),
    CREATE_MORNING_REVIEW_ACTION: new Set([
      "requestId", "operation", "sessionId", "actionDraft",
    ]),
    ACCEPT_MORNING_REVIEW_ACTION: new Set([
      "requestId", "operation", "sessionId", "actionId", "expectedVersion",
    ]),
    COMPLETE_MORNING_REVIEW_ACTION: new Set([
      "requestId", "operation", "sessionId", "actionId", "expectedVersion",
      "reason",
    ]),
    TAKE_OVER_MORNING_REVIEW: new Set([
      "requestId", "operation", "sessionId", "expectedVersion", "reason",
    ]),
    FINALIZE_MORNING_REVIEW: new Set([
      "requestId", "operation", "sessionId", "expectedVersion", "summary",
    ]),
    RECORD_MORNING_REVIEW_NOT_HELD: new Set([
      "requestId", "operation", "reason",
    ]),
    CREATE_MORNING_REVIEW_STANDING_CONCERN: new Set([
      "requestId", "operation", "sessionId", "concernDraft",
    ]),
    RESOLVE_MORNING_REVIEW_STANDING_CONCERN: new Set([
      "requestId", "operation", "sessionId", "concernId", "expectedVersion",
      "reason",
    ]),
    CHECK_MORNING_REVIEW_STANDING_CONCERN: new Set([
      "requestId", "operation", "sessionId", "concernId", "checkState",
      "reason",
    ]),
    ADD_MORNING_REVIEW_ADDENDUM: new Set([
      "requestId", "operation", "sessionId", "entryDraft", "reason",
    ]),
  });

export function morningReviewCommandContractSnapshot(): {
  operations: Readonly<Record<string, ReadonlyArray<string>>>;
  entryDraftFields: ReadonlyArray<string>;
  actionDraftFields: ReadonlyArray<string>;
  concernDraftFields: ReadonlyArray<string>;
} {
  const sorted = (values: ReadonlySet<string>) => [...values].sort();
  return {
    operations: Object.fromEntries(
      [...OPERATIONS].sort().map((operation) => [
        operation,
        sorted(ALLOWED_KEYS[operation]),
      ]),
    ),
    entryDraftFields: sorted(ENTRY_DRAFT_KEYS),
    actionDraftFields: sorted(ACTION_DRAFT_KEYS),
    concernDraftFields: sorted(CONCERN_DRAFT_KEYS),
  };
}

function invalid(field: string, detail: string): never {
  throw new AssetHierarchyMutationError(
    "invalid-argument",
    `Morning Review ${field} ${detail}.`,
    {reasonCode: "morning-review-request-invalid", field},
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

function optionalString(
  value: unknown,
  field: string,
  maximum: number,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string") invalid(field, "must be a string or null");
  const cleaned = (value as string).trim();
  if (cleaned.length === 0) return null;
  if (cleaned.length > maximum) invalid(field, `must not exceed ${maximum} characters`);
  return cleaned;
}

function requiredVersion(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 1) {
    invalid("expectedVersion", "must be a positive integer");
  }
  return value as number;
}

function exactObject(value: unknown, field: string): JsonMap {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    invalid(field, "must be an object");
  }
  return value as JsonMap;
}

function exactKeys(value: JsonMap, allowed: ReadonlySet<string>, field: string): void {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) invalid(`${field}.${key}`, "is unsupported");
  }
}

function optionalId(value: unknown, field: string): string | null {
  const parsed = optionalString(value, field, 180);
  if (parsed != null && !/^[A-Za-z0-9][A-Za-z0-9_.:-]{0,179}$/.test(parsed)) {
    invalid(field, "contains unsupported characters");
  }
  return parsed;
}

function optionalSourceReferences(value: unknown): ReadonlyArray<string> {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > MAX_SOURCE_REFERENCES) {
    invalid("entryDraft.sourceReferences", `must contain at most ${MAX_SOURCE_REFERENCES} items`);
  }
  const result = value.map((item, index) =>
    requiredString(item, `entryDraft.sourceReferences[${index}]`, 240));
  if (new Set(result).size !== result.length) {
    invalid("entryDraft.sourceReferences", "must not contain duplicates");
  }
  return result;
}

function parseEntryDraft(value: unknown): MorningReviewEntryDraft {
  const draft = exactObject(value, "entryDraft");
  exactKeys(draft, ENTRY_DRAFT_KEYS, "entryDraft");
  if (!SECTIONS.has(draft.section as MorningReviewSection)) {
    invalid("entryDraft.section", "is unsupported");
  }
  if (!ENTRY_KINDS.has(draft.kind as MorningReviewEntryKind)) {
    invalid("entryDraft.kind", "is unsupported");
  }
  const assetClassId = optionalId(draft.assetClassId, "entryDraft.assetClassId");
  const assetClassName = optionalString(
    draft.assetClassName,
    "entryDraft.assetClassName",
    120,
  );
  const assetInstanceId = optionalId(
    draft.assetInstanceId,
    "entryDraft.assetInstanceId",
  );
  const assetNumber = optionalString(
    draft.assetNumber,
    "entryDraft.assetNumber",
    40,
  );
  if ((assetClassId == null) !== (assetClassName == null) ||
      (assetInstanceId == null) !== (assetNumber == null) ||
      (assetInstanceId != null && assetClassId == null)) {
    invalid("entryDraft.asset", "requires complete class and instance identity pairs");
  }
  return {
    section: draft.section as MorningReviewSection,
    kind: draft.kind as MorningReviewEntryKind,
    text: requiredString(draft.text, "entryDraft.text", 2000),
    assetClassId,
    assetClassName,
    assetInstanceId,
    assetNumber,
    sourceReferences: optionalSourceReferences(draft.sourceReferences),
  };
}

function parseActionDraft(value: unknown): MorningReviewActionDraft {
  const draft = exactObject(value, "actionDraft");
  exactKeys(draft, ACTION_DRAFT_KEYS, "actionDraft");
  if (!SECTIONS.has(draft.section as MorningReviewSection)) {
    invalid("actionDraft.section", "is unsupported");
  }
  const assigneeUid = optionalId(draft.assigneeUid, "actionDraft.assigneeUid");
  const assigneeRole = optionalString(
    draft.assigneeRole,
    "actionDraft.assigneeRole",
    80,
  );
  if ((assigneeUid == null) === (assigneeRole == null)) {
    invalid("actionDraft.assignee", "must select exactly one user or role");
  }
  if (assigneeRole != null && !ACTION_ROLES.has(assigneeRole)) {
    invalid("actionDraft.assigneeRole", "is not a canonical application role");
  }
  const assetClassId = optionalId(draft.assetClassId, "actionDraft.assetClassId");
  const assetClassName = optionalString(
    draft.assetClassName,
    "actionDraft.assetClassName",
    120,
  );
  const assetInstanceId = optionalId(
    draft.assetInstanceId,
    "actionDraft.assetInstanceId",
  );
  const assetNumber = optionalString(
    draft.assetNumber,
    "actionDraft.assetNumber",
    40,
  );
  if ((assetClassId == null) !== (assetClassName == null) ||
      (assetInstanceId == null) !== (assetNumber == null) ||
      (assetInstanceId != null && assetClassId == null)) {
    invalid("actionDraft.asset", "requires complete class and instance identity pairs");
  }
  const dueAtIso = optionalString(draft.dueAt, "actionDraft.dueAt", 40);
  if (dueAtIso != null) {
    const dueAt = new Date(dueAtIso);
    if (Number.isNaN(dueAt.valueOf()) || dueAt.toISOString() !== dueAtIso) {
      invalid("actionDraft.dueAt", "must be a canonical UTC instant");
    }
  }
  return {
    section: draft.section as MorningReviewSection,
    text: requiredString(draft.text, "actionDraft.text", 1200),
    assigneeUid,
    assigneeRole,
    assetClassId,
    assetClassName,
    assetInstanceId,
    assetNumber,
    dueAtIso,
  };
}

function parseConcernDraft(value: unknown): StandingConcernDraft {
  const draft = exactObject(value, "concernDraft");
  exactKeys(draft, CONCERN_DRAFT_KEYS, "concernDraft");
  if (draft.criticality !== "standing" && draft.criticality !== "safety") {
    invalid("concernDraft.criticality", "must be standing or safety");
  }
  return {
    title: requiredString(draft.title, "concernDraft.title", 160),
    detail: requiredString(draft.detail, "concernDraft.detail", 1600),
    criticality: draft.criticality,
  };
}

export function parseMorningReviewMutationRequest(value: unknown): ParsedRequest {
  const data = exactObject(value, "request");
  const operation = requiredString(data.operation, "operation", 80) as
    MorningReviewOperation;
  if (!OPERATIONS.has(operation)) invalid("operation", "is unsupported");
  exactKeys(data, ALLOWED_KEYS[operation], "request");
  const requestId = requiredString(data.requestId, "requestId", 80);
  if (!UUID.test(requestId)) invalid("requestId", "must be a UUID");

  const needsSession = ![
    "START_MORNING_REVIEW",
    "RECORD_MORNING_REVIEW_NOT_HELD",
  ].includes(operation);
  const sessionId = needsSession ?
    requiredString(data.sessionId, "sessionId", 10) : null;
  if (sessionId != null && !PLANT_DAY.test(sessionId)) {
    invalid("sessionId", "must be an ISO plant day");
  }
  const needsVersion = [
    "ACCEPT_MORNING_REVIEW_ACTION",
    "COMPLETE_MORNING_REVIEW_ACTION",
    "TAKE_OVER_MORNING_REVIEW",
    "FINALIZE_MORNING_REVIEW",
    "RESOLVE_MORNING_REVIEW_STANDING_CONCERN",
  ].includes(operation);
  const expectedVersion = needsVersion ? requiredVersion(data.expectedVersion) : null;
  const actionId = operation.includes("_ACTION") &&
      operation !== "CREATE_MORNING_REVIEW_ACTION" ?
    optionalId(data.actionId, "actionId") : null;
  if (operation.includes("_ACTION") &&
      operation !== "CREATE_MORNING_REVIEW_ACTION" && actionId == null) {
    invalid("actionId", "is required");
  }
  const concernId = operation.includes("STANDING_CONCERN") &&
      operation !== "CREATE_MORNING_REVIEW_STANDING_CONCERN" ?
    optionalId(data.concernId, "concernId") : null;
  if (operation.includes("STANDING_CONCERN") &&
      operation !== "CREATE_MORNING_REVIEW_STANDING_CONCERN" &&
      concernId == null) {
    invalid("concernId", "is required");
  }
  const reason = data.reason == null ? null :
    requiredString(data.reason, "reason", MAX_COMMAND_REASON_LENGTH);
  if ([
    "COMPLETE_MORNING_REVIEW_ACTION",
    "TAKE_OVER_MORNING_REVIEW",
    "RECORD_MORNING_REVIEW_NOT_HELD",
    "RESOLVE_MORNING_REVIEW_STANDING_CONCERN",
    "CHECK_MORNING_REVIEW_STANDING_CONCERN",
    "ADD_MORNING_REVIEW_ADDENDUM",
  ].includes(operation) && reason == null) invalid("reason", "is required");
  const summary = operation === "FINALIZE_MORNING_REVIEW" ?
    requiredString(data.summary, "summary", 2000) : null;
  const checkState = operation === "CHECK_MORNING_REVIEW_STANDING_CONCERN" ?
    data.checkState as "complied" | "exception" : null;
  if (operation === "CHECK_MORNING_REVIEW_STANDING_CONCERN" &&
      checkState !== "complied" && checkState !== "exception") {
    invalid("checkState", "must be complied or exception");
  }
  const entryDraft = [
    "ADD_MORNING_REVIEW_ENTRY", "ADD_MORNING_REVIEW_ADDENDUM",
  ].includes(operation) ? parseEntryDraft(data.entryDraft) : null;
  if (operation === "ADD_MORNING_REVIEW_ADDENDUM" &&
      entryDraft?.kind !== "addendum") {
    invalid("entryDraft.kind", "must be addendum after finalization");
  }
  if (operation === "ADD_MORNING_REVIEW_ENTRY" &&
      entryDraft?.kind === "addendum") {
    invalid("entryDraft.kind", "is reserved for a finalized-session addendum");
  }
  const actionDraft = operation === "CREATE_MORNING_REVIEW_ACTION" ?
    parseActionDraft(data.actionDraft) : null;
  const concernDraft = operation ===
      "CREATE_MORNING_REVIEW_STANDING_CONCERN" ?
    parseConcernDraft(data.concernDraft) : null;
  const canonical = {
    requestId,
    operation,
    sessionId,
    expectedVersion,
    actionId,
    concernId,
    reason,
    summary,
    checkState,
    entryDraft,
    actionDraft,
    concernDraft,
  };
  return {
    ...canonical,
    fingerprint: `morningreview1-sha256:${
      createHash("sha256").update(stableJson(canonical), "utf8").digest("hex")
    }`,
  };
}

function approvedAuthority(value: unknown) {
  const authority = canonicalApprovedUserAuthority(value);
  if (authority == null) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "An approved user profile is required for Morning Review.",
      {reasonCode: "morning-review-authority-invalid"},
    );
  }
  return authority;
}

function hasAnyRole(roles: ReadonlySet<string>, allowed: ReadonlySet<string>): boolean {
  return [...roles].some((role) => allowed.has(role));
}

export function userCanMutateMorningReview(
  value: unknown,
  operation: unknown,
): boolean {
  const authority = canonicalApprovedUserAuthority(value);
  if (authority == null || typeof operation !== "string" ||
      !OPERATIONS.has(operation as MorningReviewOperation)) return false;
  if ([
    "START_MORNING_REVIEW",
    "TAKE_OVER_MORNING_REVIEW",
    "FINALIZE_MORNING_REVIEW",
    "RECORD_MORNING_REVIEW_NOT_HELD",
  ].includes(operation)) return hasAnyRole(authority.roles, START_ROLES);
  return true;
}

export function isMorningReviewOperation(value: unknown): value is MorningReviewOperation {
  return typeof value === "string" && OPERATIONS.has(value as MorningReviewOperation);
}

function actorName(data: JsonMap, uid: string): string {
  const stored = typeof data.name === "string" ? data.name.trim() : "";
  return stored.length > 0 ? stored : uid;
}

function indiaParts(now: Date): {plantDay: string; minuteOfDay: number} {
  const shifted = new Date(now.valueOf() + INDIA_OFFSET_MINUTES * 60_000);
  const year = shifted.getUTCFullYear();
  const month = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const day = String(shifted.getUTCDate()).padStart(2, "0");
  return {
    plantDay: `${year}-${month}-${day}`,
    minuteOfDay: shifted.getUTCHours() * 60 + shifted.getUTCMinutes(),
  };
}

export function morningReviewPlantClock(now: Date): {
  plantDay: string;
  minuteOfDay: number;
  canStart: boolean;
  windowMissed: boolean;
} {
  const parts = indiaParts(now);
  return {
    ...parts,
    canStart: parts.minuteOfDay >= START_MINUTE && parts.minuteOfDay <= END_MINUTE,
    windowMissed: parts.minuteOfDay > END_MINUTE,
  };
}

function addDays(value: Date, days: number): Date {
  return new Date(value.valueOf() + days * 24 * 60 * 60 * 1000);
}

function dayBoundsUtc(plantDay: string): {start: Date; end: Date} {
  const [year, month, day] = plantDay.split("-").map(Number);
  const start = new Date(
    Date.UTC(year, month - 1, day) - INDIA_OFFSET_MINUTES * 60_000,
  );
  return {start, end: addDays(start, 1)};
}

function priorPlantDay(plantDay: string): string {
  const current = dayBoundsUtc(plantDay).start;
  return indiaParts(new Date(current.valueOf() - 1)).plantDay;
}

function timestampDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (Object.prototype.toString.call(value) === "[object Date]") {
    const milliseconds = (value as {valueOf: () => number}).valueOf();
    return Number.isFinite(milliseconds) ? new Date(milliseconds) : null;
  }
  if (typeof value === "string") {
    const milliseconds = persistedInstantMillis(value);
    return Number.isFinite(milliseconds) ? new Date(milliseconds) : null;
  }
  if (value == null || typeof value !== "object") return null;
  const candidate = value as {
    toDate?: () => Date;
    toMillis?: () => number;
    seconds?: unknown;
    nanoseconds?: unknown;
  };
  if (typeof candidate.toDate === "function") return candidate.toDate();
  if (typeof candidate.toMillis === "function") {
    return new Date(candidate.toMillis());
  }
  if (Number.isSafeInteger(candidate.seconds) &&
      Number.isSafeInteger(candidate.nanoseconds)) {
    return new Date(
      (candidate.seconds as number) * 1000 +
      (candidate.nanoseconds as number) / 1_000_000,
    );
  }
  return null;
}

function boundedDisplay(value: unknown, maximum: number): string | null {
  if (typeof value !== "string") return null;
  const cleaned = value.replace(/\s+/g, " ").trim();
  if (cleaned.length === 0) return null;
  return cleaned.length <= maximum ? cleaned : `${cleaned.slice(0, maximum - 3)}...`;
}

function firstText(data: JsonMap, fields: ReadonlyArray<string>, maximum = 400): string | null {
  for (const field of fields) {
    const value = boundedDisplay(data[field], maximum);
    if (value != null) return value;
  }
  return null;
}

function firstTimestamp(data: JsonMap, fields: ReadonlyArray<string>): Date | null {
  for (const field of fields) {
    const value = timestampDate(data[field]);
    if (value != null) return value;
  }
  return null;
}

function touchedDuring(
  data: JsonMap,
  fields: ReadonlyArray<string>,
  start: Date,
  end: Date,
): boolean {
  return fields.some((field) => {
    const value = timestampDate(data[field]);
    return value != null && value >= start && value < end;
  });
}

type SourceAssetIdentity = {
  assetClassId: string | null;
  assetClassName: string | null;
  assetInstanceId: string | null;
  assetNumber: string | null;
};

function parsedObject(value: unknown): JsonMap | null {
  if (value != null && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonMap;
  }
  if (typeof value !== "string" || value.trim().length === 0) return null;
  try {
    const decoded: unknown = JSON.parse(value);
    return decoded != null && typeof decoded === "object" &&
      !Array.isArray(decoded) ? decoded as JsonMap : null;
  } catch {
    return null;
  }
}

function normalizedStatusKey(value: unknown): string {
  return typeof value === "string" ?
    value.replace(/[^a-z]/gi, "").toLowerCase() : "";
}

function nonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function optionalNonEmptyString(value: unknown): boolean {
  return value == null || nonEmptyString(value);
}

function qualityAssetLabel(asset: JsonMap): string {
  const type = boundedDisplay(asset.assetType, 40) ?? "Asset";
  const normalizedType = normalizedStatusKey(type);
  const label = ({
    base: "Base",
    furnace: "Furnace",
    forcecooler: "Forced Cooler",
    innercover: "Inner Cover",
    governedcustom: "Asset",
  } as Record<string, string>)[normalizedType] ?? type;
  return `${label} ${String(asset.assetNumber)}`;
}

function qualityWarningSourceProjection(
  snapshot: SnapshotLike,
): JsonMap | null {
  let data: JsonMap;
  try {
    data = validateQualityWarningRecord(
      snapshot.data() ?? {},
      snapshot.id,
    );
  } catch (_) {
    return null;
  }
  const affectedAssets = data.affectedAssets as JsonMap[];
  const affectedLabels = affectedAssets.map(qualityAssetLabel);
  const linkedCharges = data.linkedReannealingChargeNos as number[];
  const details = [
    boundedDisplay(data.sourceSummary, 180),
    boundedDisplay(data.warningReason, 180),
    boundedDisplay(data.component, 100),
    affectedLabels.length === 0 ? null :
      `Affected: ${affectedLabels.join(", ")}`,
    boundedDisplay(data.closureRequestReason, 160),
    boundedDisplay(data.decisionReason, 160),
    linkedCharges.length === 0 ? null :
      `Linked RA charges: ${linkedCharges.join(", ")}`,
  ].filter((value): value is string => value != null);
  const singleAsset = affectedAssets.length === 1 ? affectedAssets[0] : null;
  const status = data.status as string;
  return {
    ...data,
    morningReviewTitle: `Quality warning · Charge ${data.sourceChargeNo}`,
    morningReviewSummary: boundedDisplay(details.join(" · "), 420),
    morningReviewObservedAt: status === "closed" ? data.closedAt :
      status === "closureRequested" ? data.closureRequestedAt : data.updatedAt,
    ...(singleAsset == null ? {} : {
      assetType: singleAsset.assetType,
      assetNumber: singleAsset.assetNumber,
      assetHierarchyRef: singleAsset.assetHierarchyRef ?? null,
    }),
  };
}

function inspectionFindingIsValid(
  data: JsonMap,
  documentId: string,
): boolean {
  const requiredStrings = [
    data.campaignId,
    data.targetKey,
    data.assetTypeKey,
    data.assetClassId,
    data.assetInstanceId,
    data.firstObservationId,
    data.currentObservationId,
  ];
  const optionalStrings = [
    data.subjectSerialNumber,
    data.componentNodeId,
    data.componentName,
    data.physicalPosition,
    data.linkedTicketId,
  ];
  const positiveIntegers = [
    data.version,
    data.assetNumber,
    data.recurrenceCount,
  ];
  if (data.schemaVersion !== 1 || data.findingId !== documentId ||
      requiredStrings.some((value) => !nonEmptyString(value)) ||
      optionalStrings.some((value) => !optionalNonEmptyString(value)) ||
      positiveIntegers.some((value) =>
        !Number.isSafeInteger(value) || (value as number) < 1) ||
      !Number.isSafeInteger(data.verificationCount) ||
      (data.verificationCount as number) < 0 ||
      !INSPECTION_FINDING_STATUSES.has(String(data.status)) ||
      timestampDate(data.firstObservedAt) == null ||
      timestampDate(data.latestObservedAt) == null ||
      timestampDate(data.updatedAt) == null ||
      (data.lastVerificationOutcome != null &&
        !INSPECTION_COMPARISON_OUTCOMES.has(
          String(data.lastVerificationOutcome),
        ))) {
    return false;
  }
  const hostAssetNumber = data.hostAssetNumber;
  if (hostAssetNumber != null &&
      (!Number.isSafeInteger(hostAssetNumber) ||
        (hostAssetNumber as number) < 1)) {
    return false;
  }
  const hasHost = hostAssetNumber != null;
  const hasSubject = data.subjectSerialNumber != null;
  return hasHost === hasSubject && (!hasHost ||
    (data.assetTypeKey === "innerCover" &&
      data.assetNumber === hostAssetNumber));
}

function inspectionFindingSourceProjection(
  snapshot: SnapshotLike,
): JsonMap | null {
  const data = snapshot.data() ?? {};
  if (!inspectionFindingIsValid(data, snapshot.id)) return null;
  const hostAssetNumber = data.hostAssetNumber as number | null | undefined;
  const subjectSerialNumber = boundedDisplay(data.subjectSerialNumber, 40);
  const isInstalledInnerCover = hostAssetNumber != null &&
    subjectSerialNumber != null;
  const rawAssetNumber = data.assetNumber as number;
  const displayAssetNumber = isInstalledInnerCover ?
    subjectSerialNumber : rawAssetNumber;
  const assetTypeKey = data.assetTypeKey as string;
  const identityLabel = isInstalledInnerCover ?
    `Inner Cover ${subjectSerialNumber} installed at Base ${hostAssetNumber}` :
    qualityAssetLabel({
      assetType: assetTypeKey,
      assetNumber: rawAssetNumber,
    });
  const component = boundedDisplay(data.componentName, 120) ??
    boundedDisplay(data.physicalPosition, 120);
  const details = [
    identityLabel,
    data.physicalPosition == null ? null :
      `Position: ${boundedDisplay(data.physicalPosition, 100)}`,
    (data.recurrenceCount as number) > 1 ?
      `Observed ${data.recurrenceCount} times` : null,
    data.linkedTicketId == null ? null :
      `Corrective ticket: ${boundedDisplay(data.linkedTicketId, 100)}`,
  ].filter((value): value is string => value != null);
  const terminal = TERMINAL_INSPECTION_FINDING_STATUSES.has(
    data.status as string,
  );
  return {
    ...data,
    assetType: assetTypeKey,
    assetNumber: displayAssetNumber,
    morningReviewTitle: component == null ? "Inspection finding" :
      `Inspection finding · ${component}`,
    morningReviewSummary: boundedDisplay(details.join(" · "), 420),
    morningReviewObservedAt: terminal ? data.updatedAt : data.latestObservedAt,
  };
}

function morningReviewSourceProjection(
  collection: string,
  snapshot: SnapshotLike,
): JsonMap | null {
  if (collection === "quality_warnings") {
    return qualityWarningSourceProjection(snapshot);
  }
  if (collection === "inspection_findings") {
    return inspectionFindingSourceProjection(snapshot);
  }
  return snapshot.data() ?? {};
}

function sourceHierarchyReference(data: JsonMap): JsonMap | null {
  const direct = parsedObject(data.assetHierarchyRefJson) ??
    parsedObject(data.assetHierarchyRef);
  if (direct != null) return direct;
  const metadata = parsedObject(data.metadataJson);
  if (metadata == null) return null;
  const snapshot = parsedObject(metadata.jobTemplateSnapshot);
  return snapshot == null ? null :
    parsedObject(snapshot.assetHierarchyRefJson) ??
    parsedObject(snapshot.assetHierarchyRef);
}

function sourceAssetIdentity(data: JsonMap): SourceAssetIdentity {
  const hierarchy = sourceHierarchyReference(data);
  const metadata = parsedObject(data.metadataJson);
  const assignment = metadata == null ? null :
    parsedObject(metadata.assignmentAssetIdentity);
  const rawNumber = hierarchy?.assetNumber ?? assignment?.assetNumber ??
    data.assetNumber ?? data.baseNumber ?? data.furnaceNumber;
  const assetNumber = typeof rawNumber === "number" && Number.isFinite(rawNumber) ?
    String(rawNumber) : boundedDisplay(rawNumber, 40);
  const rawAssetClassName = firstText({
    hierarchyClassName: hierarchy?.assetClassName,
    assignmentClassName: assignment?.assetClassName,
    assetClassName: data.assetClassName,
    assetType: data.assetType,
    assetTypeKey: data.assetTypeKey,
    assetFamily: data.assetFamily,
    className: data.className,
  }, [
    "hierarchyClassName", "assignmentClassName", "assetClassName",
    "assetType", "assetTypeKey", "assetFamily", "className",
  ], 120);
  if (rawAssetClassName == null) {
    return {
      assetClassId: null,
      assetClassName: null,
      assetInstanceId: null,
      assetNumber: null,
    };
  }
  const normalizedClassName = rawAssetClassName.replace(/[^a-z0-9]/gi, "")
    .toLowerCase();
  const assetClassName = ({
    furnace: "Furnace",
    base: "Base",
    innercover: "Inner Cover",
    forcecooler: "Forced Cooler",
    forcedcooler: "Forced Cooler",
  } as Record<string, string>)[normalizedClassName] ?? rawAssetClassName;
  const assetClassId = optionalSnapshotText(
    hierarchy?.assetClassId ?? assignment?.assetClassId ?? data.assetClassId,
    180,
  );
  const candidateInstanceId = optionalSnapshotText(
    hierarchy?.assetInstanceId ?? assignment?.assetInstanceId ??
      data.assetInstanceId,
    180,
  );
  const assetInstanceId = candidateInstanceId != null &&
      assetClassId != null && assetNumber != null ? candidateInstanceId : null;
  return {
    assetClassId,
    assetClassName,
    assetInstanceId,
    assetNumber,
  };
}

function sourceLifecycleStatus(collection: string, data: JsonMap): string {
  const explicit = firstText(data, [
    "status", "availabilityState", "condition", "workflowQueueState",
  ], 80);
  if (collection === "asset_operational_conditions" && data.active === false) {
    return "restored";
  }
  if (collection === "maintenance_records" &&
      explicit === "closedWithoutResolution") {
    return data.issueClosureDisposition === "stillRelevant" ?
      "closed without resolution · still relevant" :
      data.issueClosureDisposition === "relevanceEnded" ?
        "closed without resolution · relevance ended" : explicit;
  }
  if (collection === "maintenance_burner_closures") return "resolved";
  if (collection === "job_executions") {
    if (data.isCancelled === true) return "cancelled";
    if (data.isCompleted === true) return "completed";
    return "open";
  }
  return explicit ?? "recorded";
}

function sourceSection(
  data: JsonMap,
  identity: SourceAssetIdentity = sourceAssetIdentity(data),
): MorningReviewSection {
  if (typeof data.section === "string" &&
      SECTIONS.has(data.section as MorningReviewSection)) {
    return data.section as MorningReviewSection;
  }
  const type = (identity.assetClassName ?? "").toLowerCase();
  if (type.includes("furnace")) return "furnace";
  if (type.includes("base") || type.includes("innercover") ||
      type.includes("inner cover")) return "base";
  if (type.includes("cooler")) return "forcedCooler";
  return type.length > 0 ? "otherAsset" : "plantWide";
}

function sourceFact(args: {
  collection: string;
  sourceType: string;
  snapshot: SnapshotLike;
  section?: MorningReviewSection;
}): MorningReviewSourceFact {
  const data = args.snapshot.data() ?? {};
  const identity = sourceAssetIdentity(data);
  const status = sourceLifecycleStatus(args.collection, data);
  const activeIssue = args.collection === "maintenance_records" &&
    data.isDeleted !== true && (data.isResolved !== true ||
      (data.status === "closedWithoutResolution" &&
        data.issueClosureDisposition === "stillRelevant"));
  const issueCondition = activeIssue &&
      ["unfit", "unavailable"].includes(data.plantConditionEffect as string) ?
    data.plantConditionEffect as string :
    activeIssue && data.classification === "furnaceStuckup" ? "stuckUp" : null;
  const title = firstText(data, [
    "morningReviewTitle", "alarmTypeName", "title", "description", "name",
    "templateName", "resolutionSummary", "reason", "text",
  ], 180) ?? boundedDisplay(
    `${args.sourceType} ${args.snapshot.id}`,
    180,
  )!;
  const detail = firstText(data, [
    "morningReviewSummary", "component", "subsystem", "resolutionNote",
    "completionNote", "remarks", "currentCompliance", "reason", "details",
    "description",
  ], 420);
  const closureReason = args.collection === "maintenance_records" &&
      data.status === "closedWithoutResolution" ?
    boundedDisplay(data.issueClosureReason, 420) : null;
  const summaryDetails = [...new Set([detail, closureReason]
    .filter((value): value is string => value != null && value !== title))];
  const summary = boundedDisplay(
    summaryDetails.length === 0 ?
      status : `${status}: ${summaryDetails.join(" · ")}`,
    500,
  )!;
  const observedAt = firstTimestamp(data,
    args.collection === "morning_review_actions" ?
      ["completedAt", "acceptedAt", "updatedAt", "createdAt"] : [
        "morningReviewObservedAt",
        "resolvedAt", "restoredAt", "endDate", "completedAt", "cancelledAt",
        "closedAt", "withdrawnAt", "updatedAt", "raisedAt", "createdAt",
        "startedAt",
      ]);
  return {
    factId: `${args.collection}/${args.snapshot.id}`,
    section: args.section ?? sourceSection(data, identity),
    sourceType: issueCondition == null ? args.sourceType :
      `${args.sourceType}:${issueCondition}`,
    sourceCollection: args.collection,
    sourceDocumentId: args.snapshot.id,
    title,
    summary,
    status,
    assetClassId: identity.assetClassId,
    assetClassName: identity.assetClassName,
    assetInstanceId: identity.assetInstanceId,
    assetNumber: identity.assetNumber,
    observedAtIso: observedAt?.toISOString() ?? null,
  };
}

function optionalSnapshotText(value: unknown, maximum: number): string | null {
  return boundedDisplay(value, maximum);
}

function sourceRecordRelevant(args: {
  collection: string;
  data: JsonMap;
  priorStart: Date;
  captureEnd: Date;
}): boolean {
  if (args.data.isDeleted === true) return false;
  const normalizedStatus = normalizedStatusKey(firstText(args.data, [
    "status", "availabilityState", "condition", "workflowQueueState",
  ], 80));
  if (args.collection === "quality_warnings") {
    if (normalizedStatus === "open" ||
        normalizedStatus === "closurerequested") {
      return true;
    }
    return normalizedStatus === "closed" && touchedDuring(
      args.data,
      ["closedAt"],
      args.priorStart,
      args.captureEnd,
    );
  }
  if (args.collection === "inspection_findings") {
    if ([
      "open", "correctiveactionlinked", "awaitingverification",
    ].includes(normalizedStatus)) {
      return true;
    }
    return [
      "verifiedresolved", "acceptedcondition", "invalidated",
    ].includes(normalizedStatus) && touchedDuring(
      args.data,
      ["updatedAt"],
      args.priorStart,
      args.captureEnd,
    );
  }
  if (args.collection === "maintenance_records") {
    if (normalizedStatus === "closedwithoutresolution") {
      if (args.data.issueClosureDisposition === "stillRelevant") return true;
      return touchedDuring(args.data, [
        "endDate", "closedAt", "issueClosureRelevanceEndedAt", "updatedAt",
      ], args.priorStart, args.captureEnd);
    }
    if (args.data.isResolved === false || [
      "open", "raised", "supportconfirmed", "acknowledged", "accepted",
      "inprogress", "deferred", "actionable", "awaitingconfirmation",
    ].includes(normalizedStatus)) return true;
    return touchedDuring(args.data, [
      "resolvedAt", "endDate", "closedAt",
    ], args.priorStart, args.captureEnd);
  }
  if (args.collection === "maintenance_burner_closures") {
    return touchedDuring(
      args.data,
      ["updatedAt"],
      args.priorStart,
      args.captureEnd,
    );
  }
  if (args.collection === "job_executions") {
    return (args.data.isCompleted !== true && args.data.isCancelled !== true) ||
      touchedDuring(
        args.data,
        ["completedAt", "cancelledAt", "endDate"],
        args.priorStart,
        args.captureEnd,
      );
  }
  if (args.collection === "asset_operational_conditions") {
    const condition = normalizedStatus;
    return (args.data.active === true && [
      "down", "unfit", "unavailable", "stuckup",
    ].includes(condition)) ||
      (args.data.active === false && touchedDuring(
        args.data,
        ["restoredAt"],
        args.priorStart,
        args.captureEnd,
      ));
  }
  if (args.collection === "asset_availability_current") {
    // A generic projection update does not prove when a clear state was
    // restored. Only the active blocking projection is safe meeting evidence.
    return normalizedStatus === "temporarilyblocked";
  }
  const active = ACTIVE_SOURCE_STATUSES.has(normalizedStatus);
  if (active || args.data.isResolved === false) return true;
  return touchedDuring(args.data, [
    "resolvedAt", "endDate", "completedAt", "closedAt", "withdrawnAt",
  ], args.priorStart, args.captureEnd);
}

function sourceRecordChangedAfterCapture(
  data: JsonMap,
  captureEnd: Date,
): boolean {
  return SOURCE_MUTATION_TIME_FIELDS.some((field) => {
    const value = timestampDate(data[field]);
    return value != null && value > captureEnd;
  });
}

function compareAssetNumbers(left: string | null, right: string | null): number {
  const leftNumber = left == null ? Number.NaN : Number(left);
  const rightNumber = right == null ? Number.NaN : Number(right);
  if (Number.isFinite(leftNumber) && Number.isFinite(rightNumber)) {
    return leftNumber - rightNumber;
  }
  if (Number.isFinite(leftNumber)) return -1;
  if (Number.isFinite(rightNumber)) return 1;
  return (left ?? "").localeCompare(right ?? "");
}

function sourceFactIsActive(fact: MorningReviewSourceFact): boolean {
  return ACTIVE_SOURCE_STATUSES.has(normalizedStatusKey(fact.status));
}

function boundedSourceCollectionMarkers(
  values: Iterable<string>,
): ReadonlyArray<string> {
  const markers = [...new Set(values)].sort();
  if (markers.length <= MAX_SOURCE_COLLECTION_MARKERS) return markers;
  return [
    ...markers.slice(0, MAX_SOURCE_COLLECTION_MARKERS - 1),
    "additional_source_collections",
  ];
}

async function scanMorningReviewSourceCollection(
  collection: CollectionLike,
): Promise<{docs: ReadonlyArray<SnapshotLike>; exhausted: boolean}> {
  const docs: SnapshotLike[] = [];
  let cursor: SnapshotLike | null = null;
  for (let pageIndex = 0; pageIndex < MAX_SOURCE_SCAN_PAGES; pageIndex += 1) {
    let query = collection.orderBy("__name__");
    if (cursor != null) query = query.startAfter(cursor);
    const page = await query.limit(SOURCE_SCAN_PAGE_SIZE + 1).get();
    const accepted = page.docs.slice(0, SOURCE_SCAN_PAGE_SIZE);
    docs.push(...accepted);
    if (page.docs.length <= SOURCE_SCAN_PAGE_SIZE) {
      return {docs, exhausted: true};
    }
    cursor = accepted[accepted.length - 1] ?? null;
    if (cursor == null) return {docs, exhausted: true};
  }
  return {docs, exhausted: false};
}

export async function collectMorningReviewSourceFacts(args: {
  db: MorningReviewFirestoreLike;
  plantDay: string;
  capturedAt: Date;
}): Promise<MorningReviewSourceCapture> {
  if (Number.isNaN(args.capturedAt.valueOf()) ||
      morningReviewPlantClock(args.capturedAt).plantDay !== args.plantDay) {
    throw new AssetHierarchyMutationError(
      "invalid-argument",
      "Morning Review source capture time does not belong to its plant day.",
      {reasonCode: "morning-review-source-capture-day-mismatch"},
    );
  }
  const captureEnd = args.capturedAt;
  const priorStart = dayBoundsUtc(priorPlantDay(args.plantDay)).start;
  const specs = [
    ["critical_alarms", "criticalAlarm", "safety"],
    ["maintenance_records", "maintenanceIssue", null],
    ["maintenance_burner_closures", "burnerLockout", "furnace"],
    ["job_executions", "plannedMaintenance", null],
    ["asset_operational_conditions", "assetCondition", null],
    ["asset_availability_current", "plantCondition", null],
    ["quality_warnings", "qualityWarning", null],
    ["inspection_findings", "inspectionFinding", null],
    ["operational_events", "plantDisruption", "plantWide"],
    ["directives", "directive", "plantWide"],
    ["morning_review_actions", "carriedAction", null],
  ] as const;
  const snapshots = await Promise.all(specs.map(async ([collection]) => ({
    collection,
    scan: await scanMorningReviewSourceCollection(
      args.db.collection(collection),
    ),
  })));
  const maintenanceRecords = new Map(
    snapshots
      .find(({collection}) => collection === "maintenance_records")!
      .scan.docs.map((snapshot) => [snapshot.id, snapshot] as const),
  );
  const representedMaintenanceIds = new Set<string>();
  for (const snapshot of snapshots
    .find(({collection}) => collection === "maintenance_burner_closures")!
    .scan.docs) {
    const closure = snapshot.data() ?? {};
    if (!sourceRecordRelevant({
      collection: "maintenance_burner_closures",
      data: closure,
      priorStart,
      captureEnd,
    })) continue;
    const sourceMaintenanceId = typeof closure.sourceMaintenanceId === "string" ?
      closure.sourceMaintenanceId.trim() : "";
    const parent = maintenanceRecords.get(sourceMaintenanceId)?.data() ?? null;
    // A closure replaces its parent only while it is evidence for the parent's
    // current terminal version. A later reopen must remain visible as open work.
    if (sourceMaintenanceId.length > 0 && parent != null &&
        parent.status === "resolved" && parent.isResolved === true &&
        Number.isSafeInteger(parent.version) &&
        closure.sourceVersion === parent.version) {
      representedMaintenanceIds.add(sourceMaintenanceId);
    }
  }
  const facts: MorningReviewSourceFact[] = [];
  const incompleteSourceCollections = new Set<string>();
  for (const {collection, scan} of snapshots) {
    const spec = specs.find(([name]) => name === collection)!;
    for (const snapshot of scan.docs) {
      const factId = `${collection}/${snapshot.id}`;
      if (snapshot.id.trim().length === 0 || snapshot.id.length > 240 ||
          factId.length > 300) {
        incompleteSourceCollections.add(collection);
        continue;
      }
      const data = morningReviewSourceProjection(collection, snapshot);
      if (data == null) {
        incompleteSourceCollections.add(collection);
        continue;
      }
      if (sourceRecordChangedAfterCapture(data, captureEnd)) {
        incompleteSourceCollections.add(collection);
        continue;
      }
      if (!sourceRecordRelevant({collection, data, priorStart, captureEnd})) {
        continue;
      }
      if (collection === "maintenance_records" &&
          representedMaintenanceIds.has(snapshot.id)) {
        continue;
      }
      const linkedMaintenance = collection === "maintenance_burner_closures" &&
        typeof data.sourceMaintenanceId === "string" ?
        maintenanceRecords.get(data.sourceMaintenanceId) : null;
      const factSnapshot = {
        exists: true,
        id: snapshot.id,
        data: () => linkedMaintenance == null ? data :
          ({...(linkedMaintenance.data() ?? {}), ...data}),
      };
      facts.push(sourceFact({
        collection,
        sourceType: spec[1],
        snapshot: factSnapshot,
        section: spec[2] as MorningReviewSection | undefined,
      }));
    }
  }
  const sectionRank: Record<MorningReviewSection, number> = {
    safety: 0,
    furnace: 1,
    base: 2,
    forcedCooler: 3,
    otherAsset: 4,
    plantWide: 5,
  };
  facts.sort((left, right) =>
    Number(sourceFactIsActive(right)) - Number(sourceFactIsActive(left)) ||
    sectionRank[left.section] - sectionRank[right.section] ||
    compareAssetNumbers(left.assetNumber, right.assetNumber) ||
    left.title.localeCompare(right.title));
  const sourceCollectionsAtLimit = new Set<string>(snapshots
    .filter(({scan}) => !scan.exhausted)
    .map(({collection}) => collection));
  incompleteSourceCollections.forEach((collection) =>
    sourceCollectionsAtLimit.add(collection));
  if (facts.length > MAX_SOURCE_FACTS) {
    sourceCollectionsAtLimit.add("morning_review_compiled_source_facts");
  }
  return {
    facts: facts.slice(0, MAX_SOURCE_FACTS),
    sourceCollectionsAtLimit: boundedSourceCollectionMarkers(
      sourceCollectionsAtLimit,
    ),
  };
}

function asSnapshot(value: SnapshotLike | QuerySnapshotLike, label: string): SnapshotLike {
  if (!("exists" in value)) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a query page.`);
  }
  return value;
}

function asQuerySnapshot(
  value: SnapshotLike | QuerySnapshotLike,
  label: string,
): QuerySnapshotLike {
  if (!("docs" in value)) {
    throw new AssetHierarchyMutationError("internal", `${label} returned a document.`);
  }
  return value;
}

function sessionVersion(data: JsonMap, sessionId: string): number {
  if (data.schemaVersion !== 1 || data.sessionId !== sessionId ||
      data.plantDay !== sessionId || !Number.isSafeInteger(data.version) ||
      (data.version as number) < 1 ||
      !["open", "finalized", "notHeld"].includes(data.status as string)) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The Morning Review session is malformed.",
      {reasonCode: "morning-review-session-malformed", sessionId},
    );
  }
  return data.version as number;
}

function ensureSessionDay(sessionId: string, plantDay: string): void {
  if (sessionId !== plantDay) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Only today's Morning Review can be changed.",
      {reasonCode: "morning-review-not-current-day", sessionId, plantDay},
    );
  }
}

function ensureJoined(
  snapshot: SnapshotLike,
  sessionId: string,
  actorUid: string,
): JsonMap {
  const data = snapshot.data() ?? {};
  if (!snapshot.exists || data.schemaVersion !== 1 ||
      data.sessionId !== sessionId || data.userUid !== actorUid ||
      data.state !== "joined") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Join the Morning Review before contributing.",
      {reasonCode: "morning-review-participant-not-joined"},
    );
  }
  return data;
}

function resultFromReceipt(
  request: ParsedRequest,
  actorUid: string,
  data: JsonMap,
): MorningReviewMutationResult {
  const result = data.result;
  if (data.schemaVersion !== 1 || data.actorUid !== actorUid ||
      data.fingerprint !== request.fingerprint ||
      result == null || typeof result !== "object" || Array.isArray(result)) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The Morning Review replay receipt is malformed or mismatched.",
      {reasonCode: "morning-review-receipt-mismatch"},
    );
  }
  const map = result as JsonMap;
  const expectedResultKeys = new Set([
    "requestId", "operation", "sessionId", "entityId", "status", "version",
    "committedAt",
  ]);
  const actualResultKeys = Object.keys(map);
  const committedAt = typeof map.committedAt === "string" ?
    new Date(map.committedAt) : null;
  if (map.requestId !== request.requestId || map.operation !== request.operation ||
      actualResultKeys.length !== expectedResultKeys.size ||
      actualResultKeys.some((key) => !expectedResultKeys.has(key)) ||
      typeof map.sessionId !== "string" || !PLANT_DAY.test(map.sessionId) ||
      (request.sessionId != null && map.sessionId !== request.sessionId) ||
      typeof map.entityId !== "string" || map.entityId.trim().length === 0 ||
      map.entityId.length > 256 ||
      typeof map.status !== "string" || map.status.trim().length === 0 ||
      map.status.length > 80 ||
      !resultStatusMatchesOperation(request.operation, map.status as string) ||
      !Number.isSafeInteger(map.version) || (map.version as number) < 1 ||
      committedAt == null || Number.isNaN(committedAt.valueOf()) ||
      committedAt.toISOString() !== map.committedAt) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The Morning Review replay result is incomplete.",
      {reasonCode: "morning-review-receipt-result-malformed"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    operation: request.operation,
    sessionId: map.sessionId as string,
    entityId: map.entityId as string,
    status: map.status as string,
    version: map.version as number,
    committedAt: map.committedAt as string,
    idempotentReplay: true,
  };
}

function resultStatusMatchesOperation(
  operation: MorningReviewOperation,
  status: string,
): boolean {
  switch (operation) {
  case "START_MORNING_REVIEW":
  case "CREATE_MORNING_REVIEW_ACTION":
  case "TAKE_OVER_MORNING_REVIEW":
    return status === "open";
  case "JOIN_MORNING_REVIEW":
    return status === "joined";
  case "ADD_MORNING_REVIEW_ENTRY":
    return status === "recorded";
  case "ACCEPT_MORNING_REVIEW_ACTION":
    return status === "accepted";
  case "COMPLETE_MORNING_REVIEW_ACTION":
    return status === "completed";
  case "FINALIZE_MORNING_REVIEW":
    return status === "finalized";
  case "RECORD_MORNING_REVIEW_NOT_HELD":
    return status === "notHeld";
  case "CREATE_MORNING_REVIEW_STANDING_CONCERN":
    return status === "active";
  case "RESOLVE_MORNING_REVIEW_STANDING_CONCERN":
    return status === "resolved";
  case "CHECK_MORNING_REVIEW_STANDING_CONCERN":
    return status === "complied" || status === "exception";
  case "ADD_MORNING_REVIEW_ADDENDUM":
    return status === "addendum";
  }
}

function result(args: {
  request: ParsedRequest;
  sessionId: string | null;
  entityId: string;
  status: string;
  version: number;
  committed: Date;
}): MorningReviewMutationResult {
  return {
    ok: true,
    requestId: args.request.requestId,
    operation: args.request.operation,
    sessionId: args.sessionId,
    entityId: args.entityId,
    status: args.status,
    version: args.version,
    committedAt: args.committed.toISOString(),
    idempotentReplay: false,
  };
}

function persistedResult(value: MorningReviewMutationResult): JsonMap {
  return {
    requestId: value.requestId,
    operation: value.operation,
    sessionId: value.sessionId,
    entityId: value.entityId,
    status: value.status,
    version: value.version,
    committedAt: value.committedAt,
  };
}

async function sessionPopulation(args: {
  db: MorningReviewFirestoreLike;
  transaction: TransactionLike;
  sessionId: string;
  committed: Date;
}): Promise<{
  entries: ReadonlyArray<SnapshotLike>;
  actions: ReadonlyArray<SnapshotLike>;
  participants: ReadonlyArray<SnapshotLike>;
  standingConcerns: ReadonlyArray<SnapshotLike>;
  concernChecks: ReadonlyArray<SnapshotLike>;
}> {
  const query = async (collection: string, limit: number) =>
    asQuerySnapshot(
      await args.transaction.get(
        args.db.collection(collection)
          .where("sessionId", "==", args.sessionId)
          .limit(limit),
      ),
      `Morning Review ${collection} finalization lookup`,
    ).docs;
  const [entries, actions, participants, standingConcerns, concernChecks] =
    await Promise.all([
      query("morning_review_entries", MAX_SESSION_ENTRIES + 1),
      query("morning_review_actions", MAX_SESSION_ACTIONS + 1),
      query("morning_review_participants", MAX_SESSION_PARTICIPANTS + 1),
      args.transaction.get(
        args.db.collection("morning_review_standing_concerns"),
      ).then((page) => asQuerySnapshot(
        page,
        "Morning Review standing concern finalization lookup",
      ).docs),
      query("morning_review_concern_checks", MAX_SESSION_ENTRIES + 1),
    ]);
  const retainedConcerns = standingConcerns.filter((snapshot) => {
    const data = snapshot.data() ?? {};
    if (data.status === "active") return true;
    if (data.status !== "resolved") {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "A retained Morning Review standing concern has an invalid status.",
        {reasonCode: "morning-review-standing-concern-status-invalid"},
      );
    }
    const retainedUntil = timestampDate(data.expiresAt);
    if (retainedUntil == null) {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "A resolved Morning Review standing concern has no retention deadline.",
        {reasonCode: "morning-review-standing-concern-retention-invalid"},
      );
    }
    return retainedUntil > args.committed;
  });
  if (entries.length > MAX_SESSION_ENTRIES ||
      actions.length > MAX_SESSION_ACTIONS ||
      participants.length > MAX_SESSION_PARTICIPANTS ||
      retainedConcerns.length > MAX_STANDING_CONCERNS ||
      concernChecks.length > MAX_SESSION_ENTRIES) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "The Morning Review has exceeded its governed finalization capacity.",
      {reasonCode: "morning-review-finalization-capacity-exceeded"},
    );
  }
  return {
    entries,
    actions,
    participants,
    standingConcerns: retainedConcerns,
    concernChecks,
  };
}

function dataList(
  values: ReadonlyArray<SnapshotLike>,
  chronologyField: string,
): ReadonlyArray<JsonMap> {
  return [...values]
    .sort((left, right) => {
      const leftAt = timestampDate(left.data()?.[chronologyField])?.valueOf() ?? 0;
      const rightAt = timestampDate(right.data()?.[chronologyField])?.valueOf() ?? 0;
      return leftAt - rightAt || left.id.localeCompare(right.id);
    })
    .map((value) => ({documentId: value.id, ...(value.data() ?? {})}));
}

type SessionPopulation = Awaited<ReturnType<typeof sessionPopulation>>;
type PendingReviewWrite = {
  ref: DocumentRefLike;
  data?: JsonMap;
  options?: JsonMap;
};

function frozenDocumentContent(
  session: JsonMap,
  population: SessionPopulation,
  finalFields: JsonMap,
): JsonMap {
  return {
    schemaVersion: 1,
    sessionId: session.sessionId,
    plantDay: session.plantDay,
    status: "finalized",
    title: "BAF Morning Review",
    facilitatorUid: session.facilitatorUid,
    facilitatorName: session.facilitatorName,
    sourceCapturedAt: session.sourceCapturedAt,
    sourceCaptureState: session.sourceCaptureState,
    sourceCollectionsAtLimit: session.sourceCollectionsAtLimit,
    sourceFactDigest: session.sourceFactDigest,
    sourceFacts: session.sourceFacts,
    facilitatorHistory: session.facilitatorHistory,
    entries: dataList(population.entries, "createdAt"),
    actions: dataList(population.actions, "createdAt"),
    participants: dataList(population.participants, "joinedAt"),
    standingConcerns: dataList(population.standingConcerns, "createdAt"),
    standingConcernChecks: dataList(population.concernChecks, "checkedAt"),
    ...finalFields,
  };
}

function projectedRecords(
  collection: string,
  records: ReadonlyArray<SnapshotLike>,
  writes: ReadonlyArray<PendingReviewWrite>,
  sessionId: string,
): ReadonlyArray<SnapshotLike> {
  const projected = new Map(records.map((record) => [record.id, record.data()!]));
  for (const write of writes) {
    if (write.ref.path !== `${collection}/${write.ref.id}`) continue;
    if (write.data == null) {
      projected.delete(write.ref.id);
      continue;
    }
    const data = write.options?.merge === true ?
      {...projected.get(write.ref.id), ...write.data} : write.data;
    if (data.sessionId === sessionId ||
        collection === "morning_review_standing_concerns") {
      projected.set(write.ref.id, data);
    }
  }
  return [...projected].map(([id, data]) => ({id, exists: true, data: () => data}));
}

function reserveActionLifecycleContent(
  actions: ReadonlyArray<SnapshotLike>,
  at: unknown,
  expiresAt: unknown,
): ReadonlyArray<SnapshotLike> {
  return actions.map((snapshot) => {
    const action = snapshot.data() ?? {};
    if (action.status !== "open" && action.status !== "accepted") return snapshot;
    const future: JsonMap = {
      status: "completed",
      version: Number.MAX_SAFE_INTEGER,
      completedAt: at,
      completedByUid: "\u0000".repeat(MAX_ACTION_ACTOR_UID_LENGTH),
      completedByName: "\u0000".repeat(MAX_ACTION_ACTOR_NAME_LENGTH),
      completionNote: "\u0000".repeat(MAX_COMMAND_REASON_LENGTH),
      updatedAt: at,
      updatedByUid: "\u0000".repeat(MAX_ACTION_ACTOR_UID_LENGTH),
      updatedByName: "\u0000".repeat(MAX_ACTION_ACTOR_NAME_LENGTH),
      expiresAt,
      lastMutationId: "00000000-0000-4000-8000-000000000000",
      ...(action.status === "open" ? {
        acceptedAt: at,
        acceptedByUid: "\u0000".repeat(MAX_ACTION_ACTOR_UID_LENGTH),
        acceptedByName: "\u0000".repeat(MAX_ACTION_ACTOR_NAME_LENGTH),
      } : {}),
    };
    const reserved = {...action};
    for (const [field, value] of Object.entries(future)) {
      // Existing evidence is never made smaller to manufacture spare capacity.
      if (!(field in action) ||
          Buffer.byteLength(stableJson(action[field]), "utf8") <
          Buffer.byteLength(stableJson(value), "utf8")) reserved[field] = value;
    }
    return {...snapshot, data: () => reserved};
  });
}

async function ensureAdmittedContentCanFinalize(args: {
  db: MorningReviewFirestoreLike;
  transaction: TransactionLike;
  writes: ReadonlyArray<PendingReviewWrite>;
  sessionId: string;
  committed: Date;
  at: unknown;
  expiresAt: unknown;
  timestampFromDate: (date: Date) => unknown;
}): Promise<void> {
  const sessionRef = args.db.collection("morning_review_sessions")
    .doc(args.sessionId);
  const before = asSnapshot(await args.transaction.get(sessionRef),
    "Morning Review content admission session lookup");
  const sessions = projectedRecords("morning_review_sessions",
    before.exists ? [before] : [], args.writes, args.sessionId);
  const session = sessions.find((value) => value.id === args.sessionId)?.data();
  if (session?.status !== "open") return;
  const beforePopulation = await sessionPopulation(args);
  const project = (collection: string, records: ReadonlyArray<SnapshotLike>) =>
    projectedRecords(collection, records, args.writes, args.sessionId);
  const population: SessionPopulation = {
    entries: project("morning_review_entries", beforePopulation.entries),
    actions: project("morning_review_actions", beforePopulation.actions),
    participants: project("morning_review_participants", beforePopulation.participants),
    standingConcerns: project("morning_review_standing_concerns", beforePopulation.standingConcerns),
    concernChecks: project("morning_review_concern_checks", beforePopulation.concernChecks),
  };
  // Reserve the full permitted final summary and finalizer identities, including
  // six-byte JSON escaping. No admitted prose has to be removed at finalization.
  const finalFields = {
    finalSummary: "\u0000".repeat(2000),
    finalizedByUid: "\u0000".repeat(256),
    finalizedByName: "\u0000".repeat(256),
    finalizedAt: args.at,
    expiresAt: args.expiresAt,
    documentDigest: `morningreviewdocument1-sha256:${"0".repeat(64)}`,
  };
  const actualDocument = frozenDocumentContent(session, population, finalFields);
  if (before.exists && stableJson(actualDocument) === stableJson(
    frozenDocumentContent(before.data()!, beforePopulation, finalFields),
  )) return;
  // An admitted current-day action must still fit after its legal acceptance
  // and completion, including full escaped reason/name fields. Millisecond 999
  // reserves the widest normal Firestore Timestamp nanosecond representation.
  const lifecycleInstant = new Date(args.committed.valueOf());
  lifecycleInstant.setUTCMilliseconds(999);
  const document = frozenDocumentContent(session, {
    ...population,
    actions: reserveActionLifecycleContent(population.actions,
      args.timestampFromDate(lifecycleInstant),
      args.timestampFromDate(addDays(lifecycleInstant, RETENTION_DAYS))),
  }, finalFields);
  if (population.entries.length > MAX_SESSION_ENTRIES ||
      population.actions.length > MAX_SESSION_ACTIONS ||
      population.participants.length > MAX_SESSION_PARTICIPANTS ||
      population.standingConcerns.length > MAX_STANDING_CONCERNS ||
      population.concernChecks.length > MAX_SESSION_ENTRIES ||
      Buffer.byteLength(stableJson(document), "utf8") + 512 >
        MAX_FROZEN_DOCUMENT_BYTES) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "This contribution would exceed the review's document capacity. " +
        "Shorten it or finalize the current review before continuing.",
      {reasonCode: "morning-review-content-capacity-reached"},
    );
  }
}

function ensureSourceReferences(
  session: JsonMap,
  references: ReadonlyArray<string>,
): void {
  const sourceFacts = session.sourceFacts;
  if (!Array.isArray(sourceFacts)) {
    throw new AssetHierarchyMutationError(
      "data-loss",
      "The Morning Review source snapshot is malformed.",
      {reasonCode: "morning-review-source-snapshot-malformed"},
    );
  }
  const allowed = new Set<string>();
  for (const value of sourceFacts) {
    if (value == null || typeof value !== "object" || Array.isArray(value) ||
        typeof (value as JsonMap).factId !== "string") {
      throw new AssetHierarchyMutationError(
        "data-loss",
        "The Morning Review source snapshot is malformed.",
        {reasonCode: "morning-review-source-snapshot-malformed"},
      );
    }
    allowed.add((value as JsonMap).factId as string);
  }
  const unknown = references.find((reference) => !allowed.has(reference));
  if (unknown != null) {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "A selected source fact is not part of this Morning Review snapshot.",
      {
        reasonCode: "morning-review-source-reference-not-captured",
        sourceReference: unknown,
      },
    );
  }
}

async function mutateMorningReviewActionLifecycle(args: {
  db: MorningReviewFirestoreLike;
  transaction: TransactionLike;
  sessions: CollectionLike;
  participants: CollectionLike;
  entries: CollectionLike;
  actions: CollectionLike;
  request: ParsedRequest;
  sessionId: string;
  currentPlantDay: string;
  actorUid: string;
  actorName: string;
  actorRoles: ReadonlySet<string>;
  committed: Date;
  timestampFromDate: (date: Date) => unknown;
  completedExpiresAt: unknown;
}): Promise<MorningReviewMutationResult> {
  const actionRef = args.actions.doc(args.request.actionId!);
  const actionSnapshot = asSnapshot(
    await args.transaction.get(actionRef),
    "Morning Review action lookup",
  );
  if (!actionSnapshot.exists) {
    throw new AssetHierarchyMutationError(
      "not-found",
      "The Morning Review action was not found.",
    );
  }
  const action = actionSnapshot.data() ?? {};
  if (action.schemaVersion !== 1 ||
      action.actionId !== args.request.actionId ||
      action.sessionId !== args.sessionId ||
      !Number.isSafeInteger(action.version) ||
      action.version !== args.request.expectedVersion) {
    throw new AssetHierarchyMutationError(
      "aborted",
      "The Morning Review action changed before this command committed.",
      {reasonCode: "morning-review-action-version-mismatch"},
    );
  }
  const assignedToActor = action.assigneeUid === args.actorUid ||
    (typeof action.assigneeRole === "string" &&
      args.actorRoles.has(action.assigneeRole));
  if (!assignedToActor && !args.actorRoles.has("admin") &&
      !args.actorRoles.has("si")) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Only the assignee, Admin, or SI can change this action.",
    );
  }
  const nextVersion = (action.version as number) + 1;
  const at = args.timestampFromDate(args.committed);
  const accepting = args.request.operation === "ACCEPT_MORNING_REVIEW_ACTION";
  if (accepting && action.status !== "open") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Only an open Morning Review action can be accepted.",
    );
  }
  if (!accepting && action.status !== "open" && action.status !== "accepted") {
    throw new AssetHierarchyMutationError(
      "failed-precondition",
      "Only an open or accepted Morning Review action can be completed.",
    );
  }

  let carriedEntryRef: DocumentRefLike | null = null;
  let carriedEntry: JsonMap | null = null;
  let currentSessionRef: DocumentRefLike | null = null;
  let currentSessionVersion: number | null = null;
  if (args.sessionId !== args.currentPlantDay) {
    const candidateSessionRef = args.sessions.doc(args.currentPlantDay);
    const candidateSessionSnapshot = asSnapshot(
      await args.transaction.get(candidateSessionRef),
      "Current Morning Review session lookup for carried action",
    );
    const candidateSession = candidateSessionSnapshot.data() ?? {};
    if (candidateSessionSnapshot.exists && candidateSession.status === "open") {
      const candidateParticipantSnapshot = asSnapshot(
        await args.transaction.get(
          args.participants.doc(`${args.currentPlantDay}_${args.actorUid}`),
        ),
        "Current Morning Review participant lookup for carried action",
      );
      const candidateEntryPage = asQuerySnapshot(
        await args.transaction.get(
          args.entries.where("sessionId", "==", args.currentPlantDay)
            .limit(MAX_SESSION_ENTRIES + 1),
        ),
        "Current Morning Review entry capacity lookup for carried action",
      );
      if (candidateParticipantSnapshot.exists &&
          candidateParticipantSnapshot.data()?.state === "joined" &&
          candidateParticipantSnapshot.data()?.userUid === args.actorUid &&
          candidateEntryPage.docs.length < MAX_SESSION_ENTRIES) {
        const sourceFactId = `morning_review_actions/${actionRef.id}`;
        const capturedSource = Array.isArray(candidateSession.sourceFacts) &&
          candidateSession.sourceFacts.some((value) =>
            value != null && typeof value === "object" && !Array.isArray(value) &&
            (value as JsonMap).factId === sourceFactId &&
            (value as JsonMap).sourceType === "carriedAction" &&
            (value as JsonMap).sourceCollection === "morning_review_actions" &&
            (value as JsonMap).sourceDocumentId === actionRef.id);
        // Keep schema-one entry fields readable by installed clients. Only this
        // native transition may allocate the reserved, versioned completion ID.
        const entryId = !accepting && capturedSource ?
          `action-completed-v${nextVersion}-${args.request.requestId}` :
          args.request.requestId;
        const candidateEntryRef = args.entries.doc(entryId);
        const candidateEntrySnapshot = asSnapshot(
          await args.transaction.get(candidateEntryRef),
          "Carried action review entry lookup",
        );
        if (candidateEntrySnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "data-loss",
            "A carried-action meeting entry exists without its mutation receipt.",
          );
        }
        const identity = sourceAssetIdentity(action);
        const actionText = boundedDisplay(action.text, 1100) ??
          `Morning Review action ${actionRef.id}`;
        const transitionText = accepting ?
          `Action ${actionRef.id} accepted: ${actionText}` :
          `Action ${actionRef.id} completed: ${actionText}. Evidence: ${args.request.reason}`;
        carriedEntryRef = candidateEntryRef;
        carriedEntry = {
          schemaVersion: 1,
          entryId,
          sessionId: args.currentPlantDay,
          plantDay: args.currentPlantDay,
          section: SECTIONS.has(action.section as MorningReviewSection) ?
            action.section : "plantWide",
          kind: accepting ? "update" : "currentCompliance",
          text: boundedDisplay(transitionText, 2000),
          assetClassId: identity.assetClassId,
          assetClassName: identity.assetClassName,
          assetInstanceId: identity.assetInstanceId,
          assetNumber: identity.assetNumber,
          sourceReferences: capturedSource ? [sourceFactId] : [],
          authorUid: args.actorUid,
          authorName: args.actorName,
          authorRoleKeys: normalizeCanonicalUserRoles(args.actorRoles),
          createdAt: at,
          addendumReason: null,
          expiresAt: args.completedExpiresAt,
        };
        currentSessionRef = candidateSessionRef;
        currentSessionVersion = sessionVersion(
          candidateSession,
          args.currentPlantDay,
        );
      }
    }
  }

  if (carriedEntryRef != null && carriedEntry != null &&
      currentSessionRef != null && currentSessionVersion != null) {
    try {
      await ensureAdmittedContentCanFinalize({
        db: args.db,
        transaction: args.transaction,
        writes: [
          {ref: carriedEntryRef, data: carriedEntry},
          {ref: currentSessionRef, data: {
            version: currentSessionVersion + 1, updatedAt: at,
            updatedByUid: args.actorUid, updatedByName: args.actorName,
            expiresAt: args.completedExpiresAt, lastMutationId: args.request.requestId,
          }, options: {merge: true}},
        ],
        sessionId: args.currentPlantDay,
        committed: args.committed,
        at,
        expiresAt: args.completedExpiresAt,
        timestampFromDate: args.timestampFromDate,
      });
    } catch (error) {
      if (!(error instanceof AssetHierarchyMutationError) ||
          error.code !== "failed-precondition" ||
          (error.details as JsonMap | undefined)?.reasonCode !==
            "morning-review-content-capacity-reached") throw error;
      // This meeting entry is optional. Capacity cannot cancel the native
      // carried action or its receipt, nor consume a meeting version by itself.
      carriedEntryRef = null;
      carriedEntry = null;
      currentSessionRef = null;
      currentSessionVersion = null;
    }
  }

  if (args.request.operation === "ACCEPT_MORNING_REVIEW_ACTION") {
    args.transaction.set(actionRef, {
      status: "accepted",
      version: nextVersion,
      acceptedAt: at,
      acceptedByUid: args.actorUid,
      acceptedByName: args.actorName,
      updatedAt: at,
      updatedByUid: args.actorUid,
      updatedByName: args.actorName,
      lastMutationId: args.request.requestId,
    }, {merge: true});
  } else {
    args.transaction.set(actionRef, {
      status: "completed",
      version: nextVersion,
      completedAt: at,
      completedByUid: args.actorUid,
      completedByName: args.actorName,
      completionNote: args.request.reason,
      updatedAt: at,
      updatedByUid: args.actorUid,
      updatedByName: args.actorName,
      expiresAt: args.completedExpiresAt,
      lastMutationId: args.request.requestId,
    }, {merge: true});
  }
  if (carriedEntryRef != null && carriedEntry != null &&
      currentSessionRef != null && currentSessionVersion != null) {
    args.transaction.set(carriedEntryRef, carriedEntry);
    args.transaction.set(currentSessionRef, {
      version: currentSessionVersion + 1,
      updatedAt: at,
      updatedByUid: args.actorUid,
      updatedByName: args.actorName,
      expiresAt: args.completedExpiresAt,
      lastMutationId: args.request.requestId,
    }, {merge: true});
  }
  return result({
    request: args.request,
    sessionId: args.sessionId,
    entityId: actionRef.id,
    status: accepting ? "accepted" : "completed",
    version: nextVersion,
    committed: args.committed,
  });
}

export async function mutateMorningReviewWithDb(args: {
  db: MorningReviewFirestoreLike;
  authUid: string | null;
  data: JsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
}): Promise<MorningReviewMutationResult> {
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new AssetHierarchyMutationError(
      "unauthenticated",
      "Sign in before changing Morning Review.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseMorningReviewMutationRequest(args.data);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);
  const committed = now();
  const clock = morningReviewPlantClock(committed);
  const sessionId = request.sessionId ?? clock.plantDay;
  const expiresAtDate = addDays(committed, RETENTION_DAYS);
  const expiresAt = timestampFromDate(expiresAtDate);
  const users = args.db.collection("users");
  const sessions = args.db.collection("morning_review_sessions");
  const participants = args.db.collection("morning_review_participants");
  const entries = args.db.collection("morning_review_entries");
  const actions = args.db.collection("morning_review_actions");
  const concerns = args.db.collection("morning_review_standing_concerns");
  const concernChecks = args.db.collection("morning_review_concern_checks");
  const documents = args.db.collection("morning_review_documents");
  const receipts = args.db.collection("morning_review_mutation_receipts");
  const preflightActor = await users.doc(actorUid).get();
  const preflightAuthority = approvedAuthority(preflightActor.data());
  if (!userCanMutateMorningReview(
    preflightActor.data(),
    request.operation,
  )) {
    throw new AssetHierarchyMutationError(
      "permission-denied",
      "Your approved role cannot perform this Morning Review operation.",
      {reasonCode: "morning-review-operation-role-denied"},
    );
  }
  const preflightReceipt = await receipts.doc(request.requestId).get();
  if (request.operation === "START_MORNING_REVIEW" &&
      !preflightReceipt.exists) {
    if (!clock.canStart && !preflightAuthority.roles.has("admin")) {
      throw new AssetHierarchyMutationError(
        "failed-precondition",
        "SI can start Morning Review only from 08:00 through 10:00 India time.",
        {reasonCode: "morning-review-start-window-closed", ...clock},
      );
    }
    if ((await sessions.doc(sessionId).get()).exists) {
      throw new AssetHierarchyMutationError(
        "already-exists",
        "Today's Morning Review has already been created.",
        {reasonCode: "morning-review-day-already-claimed", sessionId},
      );
    }
  }
  const sourceCapture = request.operation === "START_MORNING_REVIEW" &&
      !preflightReceipt.exists ?
    await collectMorningReviewSourceFacts({
      db: args.db,
      plantDay: sessionId,
      capturedAt: committed,
    }) :
    {facts: [], sourceCollectionsAtLimit: []};
  return args.db.runTransaction(async (nativeTransaction) => {
    // Delay writes until all capacity reads and checks have succeeded. Firestore
    // requires every transaction read to precede its first write.
    const pendingWrites: PendingReviewWrite[] = [];
    const transaction: TransactionLike = {
      get: (ref) => nativeTransaction.get(ref),
      set: (ref, data, options) => pendingWrites.push({ref, data, options}),
      delete: (ref) => pendingWrites.push({ref}),
    };
    const actorSnapshot = asSnapshot(
      await transaction.get(users.doc(actorUid)),
      "Morning Review actor lookup",
    );
    const authority = approvedAuthority(actorSnapshot.data());
    const roles = normalizeCanonicalUserRoles(authority.roles);
    const name = actorName(authority.data, actorUid);
    const receiptRef = receipts.doc(request.requestId);
    const receiptSnapshot = asSnapshot(
      await transaction.get(receiptRef),
      "Morning Review receipt lookup",
    );
    if (receiptSnapshot.exists) {
      return resultFromReceipt(
        request,
        actorUid,
        receiptSnapshot.data() ?? {},
      );
    }

    const sessionRef = sessions.doc(sessionId);
    const sessionSnapshot = asSnapshot(
      await transaction.get(sessionRef),
      "Morning Review session lookup",
    );
    const session = sessionSnapshot.data() ?? {};
    let mutationResult: MorningReviewMutationResult;
    const actionLifecycleOperation =
      request.operation === "ACCEPT_MORNING_REVIEW_ACTION" ||
      request.operation === "COMPLETE_MORNING_REVIEW_ACTION";

    if (actionLifecycleOperation && !sessionSnapshot.exists) {
      mutationResult = await mutateMorningReviewActionLifecycle({
        db: args.db,
        transaction,
        sessions,
        participants,
        entries,
        actions,
        request,
        sessionId,
        currentPlantDay: clock.plantDay,
        actorUid,
        actorName: name,
        actorRoles: authority.roles,
        committed,
        timestampFromDate,
        completedExpiresAt: expiresAt,
      });
    } else if (request.operation === "START_MORNING_REVIEW") {
      if (!hasAnyRole(authority.roles, START_ROLES)) {
        throw new AssetHierarchyMutationError(
          "permission-denied",
          "Only Admin or SI can start the Morning Review.",
        );
      }
      if (!clock.canStart && !authority.roles.has("admin")) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "SI can start Morning Review only from 08:00 through 10:00 India time.",
          {reasonCode: "morning-review-start-window-closed", ...clock},
        );
      }
      if (sessionSnapshot.exists) {
        throw new AssetHierarchyMutationError(
          "already-exists",
          "Today's Morning Review has already been created.",
          {reasonCode: "morning-review-day-already-claimed", sessionId},
        );
      }
      const committedAt = timestampFromDate(committed);
      const sourceFactDigest = `morningreviewsource1-sha256:${
        createHash("sha256").update(stableJson(sourceCapture.facts), "utf8").digest("hex")
      }`;
      transaction.set(sessionRef, {
        schemaVersion: 1,
        sessionId,
        plantDay: sessionId,
        status: "open",
        version: 1,
        openedAt: committedAt,
        openedByUid: actorUid,
        openedByName: name,
        facilitatorUid: actorUid,
        facilitatorName: name,
        facilitatorRoleKeys: roles,
        facilitatorHistory: [],
        sourceCapturedAt: committedAt,
        sourceFacts: sourceCapture.facts,
        sourceFactDigest,
        sourceFactCount: sourceCapture.facts.length,
        sourceCaptureState: sourceCapture.sourceCollectionsAtLimit.length === 0 ?
          "complete" : "bounded",
        sourceCollectionsAtLimit: sourceCapture.sourceCollectionsAtLimit,
        finalizedAt: null,
        finalizedByUid: null,
        finalizedByName: null,
        finalSummary: null,
        documentDigest: null,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: name,
        expiresAt,
        lastMutationId: request.requestId,
      });
      transaction.set(participants.doc(`${sessionId}_${actorUid}`), {
        schemaVersion: 1,
        participantId: `${sessionId}_${actorUid}`,
        sessionId,
        userUid: actorUid,
        userName: name,
        roleKeys: roles,
        state: "joined",
        joinedAt: committedAt,
        joinedByRequestId: request.requestId,
        expiresAt,
      });
      mutationResult = result({
        request,
        sessionId,
        entityId: sessionId,
        status: "open",
        version: 1,
        committed,
      });
    } else if (request.operation === "RECORD_MORNING_REVIEW_NOT_HELD") {
      if (!hasAnyRole(authority.roles, START_ROLES)) {
        throw new AssetHierarchyMutationError(
          "permission-denied",
          "Only Admin or SI can record that the Morning Review was not held.",
        );
      }
      if (!clock.windowMissed) {
        throw new AssetHierarchyMutationError(
          "failed-precondition",
          "A not-held record is available only after 10:00 India time.",
          {reasonCode: "morning-review-window-not-yet-missed", ...clock},
        );
      }
      if (sessionSnapshot.exists) {
        throw new AssetHierarchyMutationError(
          "already-exists",
          "Today's Morning Review already has a record.",
        );
      }
      const committedAt = timestampFromDate(committed);
      transaction.set(sessionRef, {
        schemaVersion: 1,
        sessionId,
        plantDay: sessionId,
        status: "notHeld",
        version: 1,
        openedAt: null,
        openedByUid: null,
        openedByName: null,
        facilitatorUid: actorUid,
        facilitatorName: name,
        facilitatorRoleKeys: roles,
        facilitatorHistory: [],
        sourceCapturedAt: null,
        sourceCaptureState: "notApplicable",
        sourceCollectionsAtLimit: [],
        sourceFacts: [],
        sourceFactDigest: null,
        sourceFactCount: 0,
        finalizedAt: committedAt,
        finalizedByUid: actorUid,
        finalizedByName: name,
        finalSummary: request.reason,
        documentDigest: null,
        updatedAt: committedAt,
        updatedByUid: actorUid,
        updatedByName: name,
        expiresAt,
        lastMutationId: request.requestId,
      });
      transaction.set(documents.doc(sessionId), {
        schemaVersion: 1,
        sessionId,
        plantDay: sessionId,
        status: "notHeld",
        title: "BAF Morning Review",
        finalSummary: request.reason,
        facilitatorUid: actorUid,
        facilitatorName: name,
        sourceCapturedAt: null,
        sourceCaptureState: "notApplicable",
        sourceCollectionsAtLimit: [],
        sourceFactDigest: null,
        documentDigest: null,
        sourceFacts: [],
        facilitatorHistory: [],
        entries: [],
        actions: [],
        participants: [],
        standingConcerns: [],
        standingConcernChecks: [],
        finalizedAt: committedAt,
        finalizedByUid: actorUid,
        finalizedByName: name,
        expiresAt,
      });
      mutationResult = result({
        request,
        sessionId,
        entityId: sessionId,
        status: "notHeld",
        version: 1,
        committed,
      });
    } else {
      if (!sessionSnapshot.exists) {
        throw new AssetHierarchyMutationError(
          "not-found",
          "The Morning Review session was not found.",
        );
      }
      const currentVersion = sessionVersion(session, sessionId);
      const status = session.status as string;
      const facilitatorUid = session.facilitatorUid;
      const isFacilitator = facilitatorUid === actorUid;
      const isAdmin = authority.roles.has("admin");

      if (request.operation === "ADD_MORNING_REVIEW_ADDENDUM") {
        const retainedUntil = timestampDate(session.expiresAt);
        if (retainedUntil == null || retainedUntil.valueOf() <= committed.valueOf()) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "The retained Morning Review period has ended; an addendum can no longer be appended.",
            {reasonCode: "morning-review-retention-ended"},
          );
        }
      }

      if (request.operation !== "ADD_MORNING_REVIEW_ADDENDUM" &&
          !actionLifecycleOperation) {
        ensureSessionDay(sessionId, clock.plantDay);
      }
      const participantRef = participants.doc(`${sessionId}_${actorUid}`);
      const participantSnapshot = asSnapshot(
        await transaction.get(participantRef),
        "Morning Review participant lookup",
      );

      if (request.operation === "JOIN_MORNING_REVIEW") {
        if (status !== "open") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Only an open Morning Review can be joined.",
            {reasonCode: "morning-review-session-not-open"},
          );
        }
        if (participantSnapshot.exists) {
          const current = participantSnapshot.data() ?? {};
          if (current.sessionId !== sessionId || current.userUid !== actorUid ||
              current.state !== "joined") {
            throw new AssetHierarchyMutationError(
              "data-loss",
              "The existing Morning Review attendance evidence is malformed.",
            );
          }
          mutationResult = result({
            request,
            sessionId,
            entityId: participantRef.id,
            status: "joined",
            version: currentVersion,
            committed,
          });
        } else {
          const participantPage = asQuerySnapshot(
            await transaction.get(
              participants.where("sessionId", "==", sessionId)
                .limit(MAX_SESSION_PARTICIPANTS + 1),
            ),
            "Morning Review participant capacity lookup",
          );
          if (participantPage.docs.length >= MAX_SESSION_PARTICIPANTS) {
            throw new AssetHierarchyMutationError(
              "failed-precondition",
              "This Morning Review already contains the maximum participant count.",
              {reasonCode: "morning-review-participant-capacity-reached"},
            );
          }
          transaction.set(participantRef, {
            schemaVersion: 1,
            participantId: participantRef.id,
            sessionId,
            userUid: actorUid,
            userName: name,
            roleKeys: roles,
            state: "joined",
            joinedAt: timestampFromDate(committed),
            joinedByRequestId: request.requestId,
            expiresAt,
          });
          const version = currentVersion + 1;
          transaction.set(sessionRef, {
            version,
            updatedAt: timestampFromDate(committed),
            updatedByUid: actorUid,
            updatedByName: name,
            expiresAt,
            lastMutationId: request.requestId,
          }, {merge: true});
          mutationResult = result({
            request,
            sessionId,
            entityId: participantRef.id,
            status: "joined",
            version,
            committed,
          });
        }
      } else if (request.operation === "ADD_MORNING_REVIEW_ENTRY" ||
          request.operation === "ADD_MORNING_REVIEW_ADDENDUM") {
        const isAddendum = request.operation === "ADD_MORNING_REVIEW_ADDENDUM";
        if ((!isAddendum && status !== "open") ||
            (isAddendum && status !== "finalized")) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            isAddendum ?
              "Addenda require a finalized Morning Review." :
              "Entries require an open Morning Review.",
          );
        }
        if (isAddendum) {
          if (!hasAnyRole(authority.roles, START_ROLES)) {
            throw new AssetHierarchyMutationError(
              "permission-denied",
              "Only Admin or SI can append a post-finalization addendum.",
            );
          }
        } else {
          ensureJoined(participantSnapshot, sessionId, actorUid);
        }
        const draft = request.entryDraft!;
        if (["maintenanceUpdate", "currentCompliance"].includes(draft.kind) &&
            !hasAnyRole(authority.roles, MAINTENANCE_UPDATE_ROLES)) {
          throw new AssetHierarchyMutationError(
            "permission-denied",
            "Only an approved maintenance supervisor or senior role can record a maintenance update.",
            {reasonCode: "morning-review-maintenance-update-role-required"},
          );
        }
        ensureSourceReferences(session, draft.sourceReferences);
        const entryRef = entries.doc(request.requestId);
        const entrySnapshot = asSnapshot(
          await transaction.get(entryRef),
          "Morning Review entry lookup",
        );
        if (entrySnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "data-loss",
            "A Morning Review entry exists without its mutation receipt.",
          );
        }
        const entryPage = asQuerySnapshot(
          await transaction.get(
            entries.where("sessionId", "==", sessionId)
              .limit(MAX_SESSION_ENTRIES + 1),
          ),
          "Morning Review entry capacity lookup",
        );
        if (entryPage.docs.length >= MAX_SESSION_ENTRIES) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "This Morning Review already contains the maximum entry count.",
            {reasonCode: "morning-review-entry-capacity-reached"},
          );
        }
        if (draft.kind === "conclusion" && !isFacilitator && !isAdmin) {
          throw new AssetHierarchyMutationError(
            "permission-denied",
            "Only the facilitator or Admin can record the room conclusion.",
          );
        }
        const createdAt = timestampFromDate(committed);
        const retainedExpiresAt = isAddendum ? session.expiresAt : expiresAt;
        transaction.set(entryRef, {
          schemaVersion: 1,
          entryId: request.requestId,
          sessionId,
          plantDay: sessionId,
          section: draft.section,
          kind: draft.kind,
          text: draft.text,
          assetClassId: draft.assetClassId,
          assetClassName: draft.assetClassName,
          assetInstanceId: draft.assetInstanceId,
          assetNumber: draft.assetNumber,
          sourceReferences: draft.sourceReferences,
          authorUid: actorUid,
          authorName: name,
          authorRoleKeys: roles,
          createdAt,
          addendumReason: isAddendum ? request.reason : null,
          expiresAt: retainedExpiresAt,
        });
        const version = currentVersion + 1;
        transaction.set(sessionRef, {
          version,
          updatedAt: createdAt,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt: retainedExpiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        mutationResult = result({
          request,
          sessionId,
          entityId: entryRef.id,
          status: isAddendum ? "addendum" : "recorded",
          version,
          committed,
        });
      } else if (request.operation === "CREATE_MORNING_REVIEW_ACTION") {
        if (status !== "open") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Actions can be created only during an open Morning Review.",
          );
        }
        ensureJoined(participantSnapshot, sessionId, actorUid);
        const sessionActionPage = asQuerySnapshot(
          await transaction.get(
            actions.where("sessionId", "==", sessionId)
              .limit(MAX_SESSION_ACTIONS + 1),
          ),
          "Morning Review session action capacity lookup",
        );
        if (sessionActionPage.docs.length >= MAX_SESSION_ACTIONS) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "This Morning Review already contains the maximum action count.",
            {reasonCode: "morning-review-action-capacity-reached"},
          );
        }
        const draft = request.actionDraft!;
        let assigneeName: string | null = null;
        if (draft.assigneeUid != null) {
          const target = asSnapshot(
            await transaction.get(users.doc(draft.assigneeUid)),
            "Morning Review action assignee lookup",
          );
          const targetAuthority = approvedAuthority(target.data());
          assigneeName = actorName(targetAuthority.data, draft.assigneeUid);
        }
        const actionRef = actions.doc(request.requestId);
        const actionSnapshot = asSnapshot(
          await transaction.get(actionRef),
          "Morning Review action lookup",
        );
        if (actionSnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "data-loss",
            "A Morning Review action exists without its mutation receipt.",
          );
        }
        const createdAt = timestampFromDate(committed);
        transaction.set(actionRef, {
          schemaVersion: 1,
          actionId: request.requestId,
          sessionId,
          originPlantDay: sessionId,
          section: draft.section,
          text: draft.text,
          assetClassId: draft.assetClassId,
          assetClassName: draft.assetClassName,
          assetInstanceId: draft.assetInstanceId,
          assetNumber: draft.assetNumber,
          assigneeUid: draft.assigneeUid,
          assigneeName,
          assigneeRole: draft.assigneeRole,
          dueAt: draft.dueAtIso == null ? null :
            timestampFromDate(new Date(draft.dueAtIso)),
          status: "open",
          version: 1,
          acceptedAt: null,
          acceptedByUid: null,
          acceptedByName: null,
          completedAt: null,
          completedByUid: null,
          completedByName: null,
          completionNote: null,
          createdAt,
          createdByUid: actorUid,
          createdByName: name,
          updatedAt: createdAt,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt: null,
          lastMutationId: request.requestId,
        });
        const version = currentVersion + 1;
        transaction.set(sessionRef, {
          version,
          updatedAt: createdAt,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        mutationResult = result({
          request,
          sessionId,
          entityId: actionRef.id,
          status: "open",
          version: 1,
          committed,
        });
      } else if (request.operation === "ACCEPT_MORNING_REVIEW_ACTION" ||
          request.operation === "COMPLETE_MORNING_REVIEW_ACTION") {
        mutationResult = await mutateMorningReviewActionLifecycle({
          db: args.db,
          transaction,
          sessions,
          participants,
          entries,
          actions,
          request,
          sessionId,
          currentPlantDay: clock.plantDay,
          actorUid,
          actorName: name,
          actorRoles: authority.roles,
          committed,
          timestampFromDate,
          completedExpiresAt: expiresAt,
        });
        if (status === "open" && sessionId === clock.plantDay) {
          const at = timestampFromDate(committed);
          transaction.set(sessionRef, {
            version: currentVersion + 1,
            updatedAt: at,
            updatedByUid: actorUid,
            updatedByName: name,
            expiresAt,
            lastMutationId: request.requestId,
          }, {merge: true});
        }
      } else if (request.operation === "TAKE_OVER_MORNING_REVIEW") {
        if (!hasAnyRole(authority.roles, START_ROLES)) {
          throw new AssetHierarchyMutationError(
            "permission-denied",
            "Only Admin or SI can take over facilitation.",
          );
        }
        if (status !== "open" || currentVersion !== request.expectedVersion) {
          throw new AssetHierarchyMutationError(
            "aborted",
            "The Morning Review changed before takeover committed.",
          );
        }
        if (isFacilitator) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "You already facilitate this Morning Review.",
          );
        }
        ensureJoined(participantSnapshot, sessionId, actorUid);
        const previousHistory = Array.isArray(session.facilitatorHistory) ?
          session.facilitatorHistory : [];
        if (previousHistory.length >= 20) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "The facilitator history limit has been reached.",
          );
        }
        const at = timestampFromDate(committed);
        const version = currentVersion + 1;
        transaction.set(sessionRef, {
          facilitatorUid: actorUid,
          facilitatorName: name,
          facilitatorRoleKeys: roles,
          facilitatorHistory: [...previousHistory, {
            previousFacilitatorUid: facilitatorUid,
            previousFacilitatorName: session.facilitatorName,
            takenOverAt: at,
            takenOverByUid: actorUid,
            takenOverByName: name,
            reason: request.reason,
          }],
          version,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        mutationResult = result({
          request,
          sessionId,
          entityId: sessionId,
          status: "open",
          version,
          committed,
        });
      } else if (request.operation === "CREATE_MORNING_REVIEW_STANDING_CONCERN") {
        if (status !== "open") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Standing concerns can be created only during an open review.",
          );
        }
        ensureJoined(participantSnapshot, sessionId, actorUid);
        const concernRef = concerns.doc(request.requestId);
        const concernSnapshot = asSnapshot(
          await transaction.get(concernRef),
          "Morning Review standing concern lookup",
        );
        if (concernSnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "data-loss",
            "A standing concern exists without its mutation receipt.",
          );
        }
        const activeConcernPage = asQuerySnapshot(
          await transaction.get(
            concerns.where("status", "==", "active")
              .limit(MAX_STANDING_CONCERNS + 1),
          ),
          "Morning Review active standing concern capacity lookup",
        );
        if (activeConcernPage.docs.length >= MAX_STANDING_CONCERNS) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Resolve an active standing concern before adding another.",
            {reasonCode: "morning-review-standing-concern-capacity-reached"},
          );
        }
        const draft = request.concernDraft!;
        const at = timestampFromDate(committed);
        transaction.set(concernRef, {
          schemaVersion: 1,
          concernId: request.requestId,
          originSessionId: sessionId,
          title: draft.title,
          detail: draft.detail,
          criticality: draft.criticality,
          status: "active",
          version: 1,
          createdAt: at,
          createdByUid: actorUid,
          createdByName: name,
          resolvedAt: null,
          resolvedByUid: null,
          resolvedByName: null,
          resolutionReason: null,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt: null,
          lastMutationId: request.requestId,
        });
        const version = currentVersion + 1;
        transaction.set(sessionRef, {
          version,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        mutationResult = result({
          request,
          sessionId,
          entityId: concernRef.id,
          status: "active",
          version: 1,
          committed,
        });
      } else if (request.operation === "RESOLVE_MORNING_REVIEW_STANDING_CONCERN") {
        if (!hasAnyRole(authority.roles, START_ROLES)) {
          throw new AssetHierarchyMutationError(
            "permission-denied",
            "Only Admin or SI can close a standing concern.",
          );
        }
        const concernRef = concerns.doc(request.concernId!);
        const concernSnapshot = asSnapshot(
          await transaction.get(concernRef),
          "Morning Review standing concern lookup",
        );
        if (!concernSnapshot.exists) {
          throw new AssetHierarchyMutationError("not-found", "The standing concern was not found.");
        }
        const concern = concernSnapshot.data() ?? {};
        if (concern.schemaVersion !== 1 || concern.concernId !== request.concernId ||
            concern.status !== "active" || concern.version !== request.expectedVersion) {
          throw new AssetHierarchyMutationError(
            "aborted",
            "The standing concern changed before closure committed.",
          );
        }
        const version = (concern.version as number) + 1;
        const at = timestampFromDate(committed);
        transaction.set(concernRef, {
          status: "resolved",
          version,
          resolvedAt: at,
          resolvedByUid: actorUid,
          resolvedByName: name,
          resolutionReason: request.reason,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        if (status === "open") {
          transaction.set(sessionRef, {
            version: currentVersion + 1,
            updatedAt: at,
            updatedByUid: actorUid,
            updatedByName: name,
            expiresAt,
            lastMutationId: request.requestId,
          }, {merge: true});
        }
        mutationResult = result({
          request,
          sessionId,
          entityId: concernRef.id,
          status: "resolved",
          version,
          committed,
        });
      } else if (request.operation === "CHECK_MORNING_REVIEW_STANDING_CONCERN") {
        if (status !== "open") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Standing concerns can be checked only during an open review.",
          );
        }
        ensureJoined(participantSnapshot, sessionId, actorUid);
        const concernRef = concerns.doc(request.concernId!);
        const concernSnapshot = asSnapshot(
          await transaction.get(concernRef),
          "Morning Review standing concern lookup",
        );
        const concern = concernSnapshot.data() ?? {};
        if (!concernSnapshot.exists || concern.schemaVersion !== 1 ||
            concern.concernId !== request.concernId || concern.status !== "active") {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "Only an active standing concern can be checked.",
          );
        }
        const checkRef = concernChecks.doc(`${sessionId}_${request.concernId}`);
        const checkSnapshot = asSnapshot(
          await transaction.get(checkRef),
          "Morning Review standing concern check lookup",
        );
        if (checkSnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "already-exists",
            "This standing concern has already been checked today.",
          );
        }
        const at = timestampFromDate(committed);
        transaction.set(checkRef, {
          schemaVersion: 1,
          checkId: checkRef.id,
          sessionId,
          concernId: request.concernId,
          concernTitle: concern.title,
          state: request.checkState,
          note: request.reason,
          checkedAt: at,
          checkedByUid: actorUid,
          checkedByName: name,
          expiresAt,
        });
        const version = currentVersion + 1;
        transaction.set(sessionRef, {
          version,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        mutationResult = result({
          request,
          sessionId,
          entityId: checkRef.id,
          status: request.checkState!,
          version,
          committed,
        });
      } else if (request.operation === "FINALIZE_MORNING_REVIEW") {
        if ((!isFacilitator && !isAdmin) || status !== "open") {
          throw new AssetHierarchyMutationError(
            "permission-denied",
            "Only the facilitator or Admin can finalize an open Morning Review.",
          );
        }
        if (currentVersion !== request.expectedVersion) {
          throw new AssetHierarchyMutationError(
            "aborted",
            "The Morning Review changed before finalization.",
            {reasonCode: "morning-review-session-version-mismatch"},
          );
        }
        const documentRef = documents.doc(sessionId);
        const documentSnapshot = asSnapshot(
          await transaction.get(documentRef),
          "Morning Review document lookup",
        );
        if (documentSnapshot.exists) {
          throw new AssetHierarchyMutationError(
            "data-loss",
            "A frozen Morning Review document already exists without a receipt.",
          );
        }
        const frozen = await sessionPopulation({
          db: args.db,
          transaction,
          sessionId,
          committed,
        });
        const at = timestampFromDate(committed);
        const version = currentVersion + 1;
        const document = frozenDocumentContent(session, frozen, {
          finalSummary: request.summary,
          finalizedAt: at,
          finalizedByUid: actorUid,
          finalizedByName: name,
          expiresAt,
        });
        const documentJson = stableJson(document);
        if (Buffer.byteLength(documentJson, "utf8") > MAX_FROZEN_DOCUMENT_BYTES) {
          throw new AssetHierarchyMutationError(
            "failed-precondition",
            "The Morning Review is too large to freeze into one governed document.",
            {reasonCode: "morning-review-finalization-document-too-large"},
          );
        }
        const documentDigest = `morningreviewdocument1-sha256:${
          createHash("sha256").update(documentJson, "utf8").digest("hex")
        }`;
        transaction.set(documentRef, {...document, documentDigest});
        transaction.set(sessionRef, {
          status: "finalized",
          version,
          finalizedAt: at,
          finalizedByUid: actorUid,
          finalizedByName: name,
          finalSummary: request.summary,
          documentDigest,
          updatedAt: at,
          updatedByUid: actorUid,
          updatedByName: name,
          expiresAt,
          lastMutationId: request.requestId,
        }, {merge: true});
        for (const snapshot of frozen.entries) {
          transaction.set(entries.doc(snapshot.id), {expiresAt}, {merge: true});
        }
        for (const snapshot of frozen.participants) {
          transaction.set(
            participants.doc(snapshot.id),
            {expiresAt},
            {merge: true},
          );
        }
        for (const snapshot of frozen.concernChecks) {
          transaction.set(
            concernChecks.doc(snapshot.id),
            {expiresAt},
            {merge: true},
          );
        }
        mutationResult = result({
          request,
          sessionId,
          entityId: documentRef.id,
          status: "finalized",
          version,
          committed,
        });
      } else {
        throw new AssetHierarchyMutationError(
          "internal",
          "The Morning Review operation was not dispatched.",
        );
      }
    }

    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      fingerprint: request.fingerprint,
      result: persistedResult(mutationResult),
      committedAt: timestampFromDate(committed),
      expiresAt,
    });
    await ensureAdmittedContentCanFinalize({
      db: args.db,
      transaction,
      writes: pendingWrites,
      sessionId: clock.plantDay,
      committed,
      at: timestampFromDate(committed),
      expiresAt,
      timestampFromDate,
    });
    for (const write of pendingWrites) {
      if (write.data == null) nativeTransaction.delete(write.ref);
      else nativeTransaction.set(write.ref, write.data, write.options);
    }
    return mutationResult;
  });
}
