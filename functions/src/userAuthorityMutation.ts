import {createHash} from "crypto";

import {
  canonicalApprovedUserAuthority,
  canonicalUserAuthorityCapsule,
  canonicalUserAuthorityDigest,
  normalizeCanonicalUserRoles,
  UserAuthorityJsonMap,
} from "./userAuthority";
import {stableJson} from "./stableJson";

export type UserAuthorityMutationHttpsErrorCode =
  | "invalid-argument"
  | "unauthenticated"
  | "permission-denied"
  | "not-found"
  | "failed-precondition"
  | "aborted"
  | "data-loss"
  | "internal";

export type UserAuthorityMutationOperation =
  | "APPROVE"
  | "REVOKE"
  | "REPLACE_ROLES";

export type UserAuthorityMutationFirestoreLike = {
  collection: (name: string) => UserAuthorityMutationCollectionLike;
  runTransaction: <T>(
    fn: (transaction: UserAuthorityMutationTransactionLike) => Promise<T>,
  ) => Promise<T>;
};

type UserAuthorityMutationCollectionLike = {
  doc: (id?: string) => UserAuthorityMutationDocumentRefLike;
  where: (
    field: string,
    op: string,
    value: unknown,
  ) => UserAuthorityMutationQueryLike;
};

type UserAuthorityMutationQueryLike = {
  where: (
    field: string,
    op: string,
    value: unknown,
  ) => UserAuthorityMutationQueryLike;
};

type UserAuthorityMutationDocumentRefLike = {
  id?: string;
  path?: string;
  get: () => Promise<UserAuthorityMutationDocumentSnapshotLike>;
};

type UserAuthorityMutationDocumentSnapshotLike = {
  exists: boolean;
  id?: string;
  data: () => UserAuthorityJsonMap | undefined;
};

type UserAuthorityMutationQuerySnapshotLike = {
  docs: UserAuthorityMutationDocumentSnapshotLike[];
};

type UserAuthorityMutationTransactionLike = {
  get: (
    refOrQuery:
      | UserAuthorityMutationDocumentRefLike
      | UserAuthorityMutationQueryLike,
  ) => Promise<
    | UserAuthorityMutationDocumentSnapshotLike
    | UserAuthorityMutationQuerySnapshotLike
  >;
  set: (
    ref: UserAuthorityMutationDocumentRefLike,
    data: UserAuthorityJsonMap,
    options?: UserAuthorityJsonMap,
  ) => void;
};

interface ParsedUserAuthorityMutationRequest {
  readonly requestId: string;
  readonly targetUid: string;
  readonly operation: UserAuthorityMutationOperation;
  readonly expectedAuthorityDigest: string;
  readonly expectedAuthorityRevision: number | null;
  readonly roles: ReadonlyArray<string> | null;
  readonly reason: string;
  readonly payloadFingerprint: string;
  readonly legacyPayloadFingerprint: string;
}

interface UserAuthorityMutationFingerprintPayload {
  readonly requestId: string;
  readonly targetUid: string;
  readonly operation: UserAuthorityMutationOperation;
  readonly expectedAuthorityDigest: string;
  readonly expectedAuthorityRevision?: number;
  readonly roles: ReadonlyArray<string> | null;
  readonly reason: string;
}

export interface UserAuthorityMutationResult {
  readonly ok: true;
  readonly requestId: string;
  readonly targetUid: string;
  readonly operation: UserAuthorityMutationOperation;
  readonly isApproved: boolean;
  readonly roles: ReadonlyArray<string>;
  readonly authorityDigest: string;
  /** Monotonic authority decision revision produced by this mutation. */
  readonly authorityRevision: number;
  /// The target's authority as it stands now. Equal to [authorityDigest]
  /// unless a later governed change has moved it on.
  readonly currentAuthorityDigest: string | null;
  readonly currentAuthorityStatus: "available" | "unavailable" | "not-disclosed";
  /** The target's current monotonic authority decision revision. */
  readonly currentAuthorityRevision: number | null;
  /// Whether a later governed change replaced the authority this request
  /// produced. The outcome above is still what this request committed.
  readonly supersededByLaterChange: boolean;
  readonly auditId: string;
  readonly committedAt: string;
  readonly idempotentReplay: boolean;
}

const REQUEST_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const AUTHORITY_DIGEST_PATTERN = /^auth1-sha256:[0-9a-f]{64}$/;
const OPERATIONS = new Set<UserAuthorityMutationOperation>([
  "APPROVE",
  "REVOKE",
  "REPLACE_ROLES",
]);
const ALLOWED_REQUEST_FIELDS = new Set([
  "requestId",
  "targetUid",
  "operation",
  "expectedAuthorityDigest",
  "expectedAuthorityRevision",
  "roles",
  "reason",
]);
const MAX_REASON_LENGTH = 500;
const MIN_REASON_LENGTH = 1;

function parseAuthorityRevision(value: unknown): number | null {
  if (value == null) return null;
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "expectedAuthorityRevision must be a non-negative integer.",
      {reasonCode: "invalid-authority-revision"},
    );
  }
  return value;
}

function storedAuthorityRevision(value: unknown): number {
  if (value == null) return 0;
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The user authority revision is malformed.",
      {reasonCode: "authority-revision-malformed"},
    );
  }
  return value;
}

export class UserAuthorityMutationError extends Error {
  readonly code: UserAuthorityMutationHttpsErrorCode;
  readonly details?: unknown;

  constructor(
    code: UserAuthorityMutationHttpsErrorCode,
    message: string,
    details?: unknown,
  ) {
    super(message);
    this.name = "UserAuthorityMutationError";
    this.code = code;
    this.details = details;
  }
}

function cleanRequiredString(
  value: unknown,
  field: string,
  maxLength: number,
): string {
  if (typeof value !== "string") {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      `${field} must be a string.`,
      {reasonCode: "invalid-field-type", field},
    );
  }
  const cleaned = value.trim();
  if (cleaned.length === 0 || cleaned.length > maxLength) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      `${field} must contain between 1 and ${maxLength} characters.`,
      {reasonCode: "invalid-field-length", field, maxLength},
    );
  }
  return cleaned;
}

function cleanDocumentId(value: unknown, field: string): string {
  const id = cleanRequiredString(value, field, 512);
  if (id === "." || id === ".." || id.includes("/")) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      `${field} is not a valid Firestore document identity.`,
      {reasonCode: "invalid-document-id", field},
    );
  }
  return id;
}

function parseCanonicalRoles(value: unknown): ReadonlyArray<string> {
  if (!Array.isArray(value) || value.length === 0) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "roles must be a non-empty canonical role list.",
      {reasonCode: "invalid-authority-roles"},
    );
  }
  if (value.some((role) => typeof role !== "string")) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "roles must contain only canonical role strings.",
      {reasonCode: "invalid-authority-roles"},
    );
  }
  try {
    return normalizeCanonicalUserRoles(value as string[]);
  } catch {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "roles contains an unknown or invalid canonical role.",
      {reasonCode: "invalid-authority-roles"},
    );
  }
}

export function userAuthorityMutationFingerprintV2(
  value: unknown,
): string {
  return `authreq2-sha256:${
    createHash("sha256")
      .update(stableJson(value), "utf8")
      .digest("hex")
  }`;
}

export function legacyUserAuthorityMutationFingerprintV1(
  value: UserAuthorityMutationFingerprintPayload,
): string {
  const legacyPayload = {
    requestId: value.requestId,
    targetUid: value.targetUid,
    operation: value.operation,
    expectedAuthorityDigest: value.expectedAuthorityDigest,
    roles: value.roles,
    reason: value.reason,
  };
  if (value.expectedAuthorityRevision != null) {
    Object.assign(legacyPayload, {
      expectedAuthorityRevision: value.expectedAuthorityRevision,
    });
  }
  return `authreq1-sha256:${
    createHash("sha256")
      .update(JSON.stringify(legacyPayload), "utf8")
      .digest("hex")
  }`;
}

export function parseUserAuthorityMutationRequest(
  raw: UserAuthorityJsonMap,
): ParsedUserAuthorityMutationRequest {
  for (const key of Object.keys(raw)) {
    if (!ALLOWED_REQUEST_FIELDS.has(key)) {
      throw new UserAuthorityMutationError(
        "invalid-argument",
        "Authority mutation request contains an unsupported field.",
        {reasonCode: "unsupported-request-field", field: key},
      );
    }
  }

  const requestId = cleanRequiredString(raw.requestId, "requestId", 64);
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "requestId must be a canonical UUID.",
      {reasonCode: "invalid-request-id"},
    );
  }
  const targetUid = cleanDocumentId(raw.targetUid, "targetUid");
  const operationRaw = cleanRequiredString(raw.operation, "operation", 32);
  if (!OPERATIONS.has(operationRaw as UserAuthorityMutationOperation)) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "operation is not supported.",
      {reasonCode: "unsupported-authority-operation"},
    );
  }
  const operation = operationRaw as UserAuthorityMutationOperation;
  const expectedAuthorityDigest = cleanRequiredString(
    raw.expectedAuthorityDigest,
    "expectedAuthorityDigest",
    80,
  ).toLowerCase();
  if (!AUTHORITY_DIGEST_PATTERN.test(expectedAuthorityDigest)) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "expectedAuthorityDigest is invalid.",
      {reasonCode: "invalid-authority-digest"},
    );
  }
  const expectedAuthorityRevision = parseAuthorityRevision(
    raw.expectedAuthorityRevision,
  );
  const reason = cleanRequiredString(raw.reason, "reason", MAX_REASON_LENGTH);
  if (reason.length < MIN_REASON_LENGTH) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "reason is required.",
      {reasonCode: "authority-reason-too-short"},
    );
  }

  let roles: ReadonlyArray<string> | null = null;
  if (operation === "REPLACE_ROLES") {
    roles = parseCanonicalRoles(raw.roles);
  } else if (raw.roles != null) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      "roles is supported only for REPLACE_ROLES.",
      {reasonCode: "unexpected-authority-roles"},
    );
  }

  const canonicalPayload: UserAuthorityMutationFingerprintPayload = {
    requestId,
    targetUid,
    operation,
    expectedAuthorityDigest,
    roles,
    reason,
    ...(expectedAuthorityRevision == null ? {} : {expectedAuthorityRevision}),
  };
  return {
    ...canonicalPayload,
    expectedAuthorityRevision,
    payloadFingerprint: userAuthorityMutationFingerprintV2(canonicalPayload),
    legacyPayloadFingerprint:
      legacyUserAuthorityMutationFingerprintV1(canonicalPayload),
  };
}

function documentSnapshot(
  value:
    | UserAuthorityMutationDocumentSnapshotLike
    | UserAuthorityMutationQuerySnapshotLike,
  context: string,
): UserAuthorityMutationDocumentSnapshotLike {
  if ("docs" in value) {
    throw new UserAuthorityMutationError(
      "internal",
      `${context} returned a query snapshot unexpectedly.`,
    );
  }
  return value;
}

function querySnapshot(
  value:
    | UserAuthorityMutationDocumentSnapshotLike
    | UserAuthorityMutationQuerySnapshotLike,
  context: string,
): UserAuthorityMutationQuerySnapshotLike {
  if (!("docs" in value)) {
    throw new UserAuthorityMutationError(
      "internal",
      `${context} returned a document snapshot unexpectedly.`,
    );
  }
  return value;
}

export function userCanMutateUserAuthority(
  data: UserAuthorityJsonMap | null | undefined,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null && authority.roles.has("admin");
}

/**
 * A narrowly scoped preflight exception for recovering an already accepted
 * command after the original Admin has demoted or revoked themselves. This
 * only opens the idempotent replay path; resultFromReceipt still binds the
 * request to its original actor, target, fingerprint and immutable audit.
 */
export async function userCanReplayUserAuthority(args: {
  db: UserAuthorityMutationFirestoreLike;
  authUid: string | null;
  data: UserAuthorityJsonMap;
}): Promise<boolean> {
  const actorUid = args.authUid?.trim() ?? "";
  if (actorUid.length === 0) return false;
  try {
    const request = parseUserAuthorityMutationRequest(args.data);
    const receipt = await args.db
      .collection("user_authority_mutation_receipts")
      .doc(request.requestId)
      .get();
    const receiptData = receipt.exists ? receipt.data() ?? {} : {};
    return receipt.exists &&
      receiptData.actorUid === actorUid &&
      receiptData.targetUid === request.targetUid;
  } catch {
    return false;
  }
}

/** Validate the frozen origin before middleware or business admission. */
export function userAuthorityCallableEnvelope(raw: UserAuthorityJsonMap, authUid: string | null): {
  data: UserAuthorityJsonMap; confirmationOnly: boolean;
} {
  if (!Object.prototype.hasOwnProperty.call(raw, "protocolVersion")) {
    return {data: raw, confirmationOnly: false};
  }
  const lookup = Object.prototype.hasOwnProperty.call(raw, "receiptLookup");
  const key = lookup ? "receiptLookup" : "request";
  const payload = raw[key];
  if (Object.keys(raw).sort().join(",") !== ["protocolVersion", "originActorUid", key].sort().join(",") ||
      raw.protocolVersion !== 2 || typeof raw.originActorUid !== "string" ||
      raw.originActorUid.length === 0 || payload == null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new UserAuthorityMutationError("invalid-argument", "The saved authority envelope is invalid.");
  }
  if (raw.originActorUid !== authUid) {
    throw new UserAuthorityMutationError("permission-denied", "Return to the originating account to check this decision.",
      {reasonCode: "origin-bound-actor-mismatch"});
  }
  return {data: payload as UserAuthorityJsonMap, confirmationOnly: lookup};
}

function decisionEvidenceDigest(audit: UserAuthorityJsonMap): string {
  const {decisionEvidenceDigest: _digest, timestamp, ...fields} = audit;
  return "authevidence1-sha256:" + createHash("sha256").update(stableJson({
    ...fields, timestampMillis: persistedTimestampMillis(timestamp),
  }), "utf8").digest("hex");
}

function actorAuthority(
  snapshot: UserAuthorityMutationDocumentSnapshotLike,
): {data: UserAuthorityJsonMap; name: string} {
  const data = snapshot.exists ? snapshot.data() ?? {} : {};
  const authority = canonicalApprovedUserAuthority(data);
  if (!userCanMutateUserAuthority(data) || authority == null) {
    throw new UserAuthorityMutationError(
      "permission-denied",
      "Approved Admin authority is required.",
      {reasonCode: "approved-admin-required"},
    );
  }
  const name =
    typeof data.name === "string" && data.name.trim().length > 0 ?
      data.name.trim() :
      "Admin";
  return {data: authority.data, name};
}

function resultingCapsule(
  operation: UserAuthorityMutationOperation,
  current: {isApproved: boolean; roles: ReadonlySet<string>},
  requestedRoles: ReadonlyArray<string> | null,
): {isApproved: boolean; roles: ReadonlyArray<string>} {
  const currentRoles = normalizeCanonicalUserRoles(current.roles);
  switch (operation) {
  case "APPROVE":
    if (current.isApproved) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "The target user is already approved.",
        {reasonCode: "authority-no-op"},
      );
    }
    return {isApproved: true, roles: currentRoles};
  case "REVOKE":
    if (!current.isApproved) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "The target user is already unapproved.",
        {reasonCode: "authority-no-op"},
      );
    }
    return {isApproved: false, roles: currentRoles};
  case "REPLACE_ROLES": {
    const roles = requestedRoles ?? [];
    if (
      roles.length === currentRoles.length &&
      roles.every((role, index) => role === currentRoles[index])
    ) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "The requested role set is already current.",
        {reasonCode: "authority-no-op"},
      );
    }
    return {isApproved: current.isApproved, roles};
  }
  }
}

/** The authority capsule an audit recorded as this mutation's outcome. */
function auditSnapshotCapsule(value: unknown): UserAuthorityJsonMap | null {
  if (typeof value !== "string") return null;
  try {
    const parsed: unknown = JSON.parse(value);
    return parsed != null && typeof parsed === "object" &&
      !Array.isArray(parsed) ? parsed as UserAuthorityJsonMap : null;
  } catch {
    return null;
  }
}

function persistedTimestampMillis(value: unknown): number | null {
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") {
    const millis = Date.parse(value);
    return Number.isNaN(millis) ? null : millis;
  }
  if (value == null || typeof value !== "object") return null;
  const candidate = value as {
    toMillis?: () => number;
    seconds?: number;
    nanoseconds?: number;
  };
  if (typeof candidate.toMillis === "function") {
    const millis = candidate.toMillis();
    return Number.isFinite(millis) ? millis : null;
  }
  if (
    typeof candidate.seconds === "number" &&
    typeof candidate.nanoseconds === "number"
  ) {
    return candidate.seconds * 1000 + candidate.nanoseconds / 1e6;
  }
  return null;
}

function resultFromReceipt(
  request: ParsedUserAuthorityMutationRequest,
  actorUid: string,
  receipt: UserAuthorityJsonMap,
  target: UserAuthorityJsonMap | null,
  audit: UserAuthorityJsonMap | null,
  expectedAuditId: string,
  discloseCurrent: boolean,
): UserAuthorityMutationResult {
  if (
    receipt.actorUid !== actorUid ||
    receipt.targetUid !== request.targetUid
  ) {
    throw new UserAuthorityMutationError(
      "aborted",
      "requestId is already bound to a different authority mutation.",
      {reasonCode: "authority-request-id-conflict"},
    );
  }
  const expectedFingerprint =
    receipt.schemaVersion === 2 &&
      typeof receipt.payloadFingerprint === "string" &&
      receipt.payloadFingerprint.startsWith("authreq2-sha256:") ?
      request.payloadFingerprint :
      receipt.schemaVersion === 1 &&
        typeof receipt.payloadFingerprint === "string" &&
        receipt.payloadFingerprint.startsWith("authreq1-sha256:") ?
        request.legacyPayloadFingerprint :
        null;
  if (expectedFingerprint == null) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The authority mutation receipt fingerprint version is unsupported.",
      {reasonCode: "authority-receipt-fingerprint-version-unsupported"},
    );
  }
  if (receipt.payloadFingerprint !== expectedFingerprint) {
    throw new UserAuthorityMutationError(
      "aborted",
      "requestId is already bound to a different authority mutation.",
      {reasonCode: "authority-request-id-conflict"},
    );
  }
  if (audit == null) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The authority mutation receipt exists without its immutable audit.",
      {reasonCode: "authority-audit-missing"},
    );
  }
  const targetCapsule = canonicalUserAuthorityCapsule(target);
  let currentAuthorityRevision: number | null = null;
  try {
    if (targetCapsule != null && discloseCurrent) {
      currentAuthorityRevision = storedAuthorityRevision(target?.authorityRevision);
    }
  } catch { /* Historical proof survives an unreadable current projection. */ }
  const currentAvailable = targetCapsule != null && currentAuthorityRevision != null;
  const currentAuthorityStatus = !discloseCurrent ? "not-disclosed" :
    currentAvailable ? "available" : "unavailable";
  // What this request committed is settled by its own immutable pair - the
  // receipt and the audit written in the same transaction - and not by what
  // the target's authority says now. Somebody else legitimately changing that
  // authority afterwards is ordinary, and it used to make the earlier
  // acceptance unrecoverable: support could not tell an accepted command from
  // a failed one using the original request. The historical outcome is
  // returned as itself, and the current state is reported beside it rather
  // than folded into it.
  const acceptedSnapshot = auditSnapshotCapsule(audit.afterJson);
  const acceptedCapsule = acceptedSnapshot == null ?
    null : canonicalUserAuthorityCapsule(acceptedSnapshot);
  if (acceptedCapsule == null) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The recorded authority mutation outcome is malformed.",
      {reasonCode: "authority-replay-evidence-malformed"},
    );
  }
  const acceptedDigest = canonicalUserAuthorityDigest(acceptedCapsule);
  const acceptedRevision = storedAuthorityRevision(
    receipt.authorityRevision ??
      (acceptedSnapshot as UserAuthorityJsonMap).authorityRevision,
  );
  const currentDigest = currentAvailable && discloseCurrent ? canonicalUserAuthorityDigest(targetCapsule!) : null;
  const acceptedBeforeSnapshot = auditSnapshotCapsule(audit.beforeJson);
  const acceptedBeforeCapsule = acceptedBeforeSnapshot == null ?
    null : canonicalUserAuthorityCapsule(acceptedBeforeSnapshot);
  const acceptedBeforeDigest = acceptedBeforeCapsule == null ?
    null : canonicalUserAuthorityDigest(acceptedBeforeCapsule);
  const acceptedRoles = normalizeCanonicalUserRoles(acceptedCapsule.roles);
  const operationOutcomeMatches =
    (request.operation === "APPROVE" && acceptedCapsule.isApproved) ||
    (request.operation === "REVOKE" && !acceptedCapsule.isApproved) ||
    (request.operation === "REPLACE_ROLES" &&
      request.roles != null &&
      request.roles.length === acceptedRoles.length &&
      request.roles.every((role, index) => role === acceptedRoles[index]));
  const auditTimestampMillis = persistedTimestampMillis(audit.timestamp);
  if (receipt.authorityDigest !== acceptedDigest) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The authority mutation receipt and its immutable audit disagree.",
      {reasonCode: "authority-replay-evidence-malformed"},
    );
  }
  const roles = normalizeCanonicalUserRoles(acceptedCapsule.roles);
  const operation = receipt.operation;
  const committedAt = receipt.committedAtIso;
  const auditId = receipt.auditId;
  if (
    operation !== request.operation ||
    typeof committedAt !== "string" ||
    Number.isNaN(Date.parse(committedAt)) ||
    auditId !== expectedAuditId ||
    receipt.expectedAuthorityDigest !== request.expectedAuthorityDigest ||
    (request.expectedAuthorityRevision != null &&
      receipt.expectedAuthorityRevision !== request.expectedAuthorityRevision) ||
    audit.requestId !== request.requestId ||
    audit.performedByUid !== actorUid ||
    audit.entityId !== request.targetUid ||
    audit.operation !== request.operation ||
    audit.authorityDigest !== acceptedDigest ||
    audit.reasonNotes !== request.reason ||
    acceptedBeforeCapsule == null ||
    acceptedBeforeDigest !== request.expectedAuthorityDigest ||
    !operationOutcomeMatches ||
    (receipt.decisionEvidenceDigest != null &&
      (receipt.decisionEvidenceDigest !== audit.decisionEvidenceDigest ||
       receipt.decisionEvidenceDigest !== decisionEvidenceDigest(audit))) ||
    (request.expectedAuthorityRevision != null &&
      (acceptedRevision !== request.expectedAuthorityRevision + 1 ||
       acceptedBeforeSnapshot?.authorityRevision !== request.expectedAuthorityRevision ||
       acceptedSnapshot?.authorityRevision !== acceptedRevision ||
       audit.authorityRevision !== acceptedRevision)) ||
    auditTimestampMillis == null ||
    auditTimestampMillis !== Date.parse(committedAt) ||
    (audit.committedAtIso != null && audit.committedAtIso !== committedAt)
  ) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The authority mutation receipt or audit is malformed.",
      {reasonCode: "authority-replay-evidence-malformed"},
    );
  }
  return {
    ok: true,
    requestId: request.requestId,
    targetUid: request.targetUid,
    operation: operation as UserAuthorityMutationOperation,
    isApproved: acceptedCapsule.isApproved,
    roles,
    authorityDigest: acceptedDigest,
    authorityRevision: acceptedRevision,
    currentAuthorityDigest: currentDigest,
    currentAuthorityStatus,
    currentAuthorityRevision,
    supersededByLaterChange:
      currentAvailable && (currentDigest !== acceptedDigest ||
      currentAuthorityRevision !== acceptedRevision),
    auditId,
    committedAt,
    idempotentReplay: true,
  };
}

export async function mutateUserAuthorityWithDb(args: {
  db: UserAuthorityMutationFirestoreLike;
  authUid: string | null;
  data: UserAuthorityJsonMap;
  now?: () => Date;
  timestampFromDate?: (date: Date) => unknown;
  confirmationOnly?: boolean;
  beforeTransactionForTest?: () => Promise<void>;
}): Promise<UserAuthorityMutationResult> {
  const {db, data} = args;
  if (args.authUid == null || args.authUid.trim().length === 0) {
    throw new UserAuthorityMutationError(
      "unauthenticated",
      "Sign in before managing user authority.",
    );
  }
  const actorUid = args.authUid.trim();
  const request = parseUserAuthorityMutationRequest(data);
  const now = args.now ?? (() => new Date());
  const timestampFromDate = args.timestampFromDate ?? ((date: Date) => date);

  const users = db.collection("users");
  const actorRef = users.doc(actorUid);
  const targetRef = users.doc(request.targetUid);
  const receiptRef = db
    .collection("user_authority_mutation_receipts")
    .doc(request.requestId);
  const auditId = `server_authority_${request.requestId}`;
  const auditRef = db.collection("audit_logs").doc(auditId);
  const approvedAdminQuery = users.where("roles", "array-contains", "admin");

  if (args.beforeTransactionForTest != null) {
    await args.beforeTransactionForTest();
  }

  return db.runTransaction(async (transaction) => {
    const receiptSnapshot = documentSnapshot(
      await transaction.get(receiptRef),
      "Authority receipt lookup",
    );
    const actorSnapshot = documentSnapshot(
      await transaction.get(actorRef),
      "Authority actor lookup",
    );

    const targetSnapshot = documentSnapshot(
      await transaction.get(targetRef),
      "Authority target lookup",
    );
    const targetData = targetSnapshot.exists ? targetSnapshot.data() ?? {} : null;
    const auditSnapshot = documentSnapshot(
      await transaction.get(auditRef),
      "Authority audit lookup",
    );

    if (receiptSnapshot.exists) {
      return resultFromReceipt(
        request,
        actorUid,
        receiptSnapshot.data() ?? {},
        targetData,
        auditSnapshot.exists ? auditSnapshot.data() ?? {} : null,
        auditId,
        userCanMutateUserAuthority(actorSnapshot.data()),
      );
    }
    if (args.confirmationOnly) {
      throw new UserAuthorityMutationError("failed-precondition",
        "No accepted receipt was found. The original decision remains saved; this check did not execute it.",
        {reasonCode: "authority-outcome-not-established"});
    }
    if (targetData == null) {
      throw new UserAuthorityMutationError("not-found", "The target user record was not found.",
        {reasonCode: "authority-target-not-found"});
    }
    const targetHasAuthorityRevision = Object.prototype.hasOwnProperty.call(targetData, "authorityRevision");
    const currentAuthorityRevision = storedAuthorityRevision(targetData.authorityRevision);
    if (auditSnapshot.exists) {
      throw new UserAuthorityMutationError(
        "aborted",
        "The immutable authority audit identity is already occupied.",
        {reasonCode: "authority-audit-collision", auditId},
      );
    }

    actorAuthority(actorSnapshot);

    const currentCapsule = canonicalUserAuthorityCapsule(targetData);
    if (currentCapsule == null) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "The target authority capsule is malformed.",
        {reasonCode: "authority-target-malformed"},
      );
    }
    const currentDigest = canonicalUserAuthorityDigest(currentCapsule);
    if (
      request.expectedAuthorityRevision == null &&
      targetHasAuthorityRevision
    ) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "This authority record requires a revision-aware client before a new change can be accepted.",
        {reasonCode: "authority-revision-required"},
      );
    }
    if (
      request.expectedAuthorityRevision != null &&
      request.expectedAuthorityRevision !== currentAuthorityRevision
    ) {
      throw new UserAuthorityMutationError(
        "aborted",
        "The target authority changed before this command was committed.",
        {
          reasonCode: "authority-revision-mismatch",
          currentAuthorityRevision,
        },
      );
    }
    if (currentDigest !== request.expectedAuthorityDigest) {
      throw new UserAuthorityMutationError(
        "aborted",
        "The target authority changed before this command was committed.",
        {
          reasonCode: "authority-preimage-mismatch",
          currentAuthorityDigest: currentDigest,
        },
      );
    }

    const resulting = resultingCapsule(
      request.operation,
      currentCapsule,
      request.roles,
    );
    const resultingDigest = canonicalUserAuthorityDigest({
      isApproved: resulting.isApproved,
      roles: new Set(resulting.roles),
    });
    if (currentAuthorityRevision >= Number.MAX_SAFE_INTEGER) {
      throw new UserAuthorityMutationError("failed-precondition", "Authority revision is exhausted; reviewed repair is required.");
    }
    const resultingAuthorityRevision = currentAuthorityRevision + 1;
    // Only reductions of a valid approved Admin need the roster invariant.
    // Unrelated damaged rows cannot prevent containment of ordinary accounts.
    if (currentCapsule.isApproved && currentCapsule.roles.has("admin") &&
        !(resulting.isApproved && resulting.roles.includes("admin"))) {
      const adminSnapshot = querySnapshot(await transaction.get(approvedAdminQuery), "Approved Admin roster lookup");

      const approvedAdminIds = new Set<string>();
      for (const snapshot of adminSnapshot.docs) {
        const rosterData = snapshot.exists ? snapshot.data() ?? {} : {};
        const authority = canonicalUserAuthorityCapsule(
          rosterData,
        );
        if (authority == null) {
          // An inactive damaged historical row is not an approved Admin and
          // must not block an unrelated containment action. An unreadable
          // approved row remains a hard stop because it cannot safely count
          // toward the last-Admin invariant.
          if (rosterData.isApproved !== true) continue;
          throw new UserAuthorityMutationError(
            "failed-precondition",
            "The approved Admin roster contains a malformed authority capsule.",
            {
              reasonCode: "authority-admin-roster-malformed",
              targetUid: snapshot.id,
            },
          );
        }
        if (authority.isApproved && authority.roles.has("admin")) {
          const id = snapshot.id?.trim();
          if (id == null || id.length === 0) {
            throw new UserAuthorityMutationError(
              "internal",
              "The approved Admin roster returned a missing user identity.",
            );
          }
          approvedAdminIds.add(id);
        }
      }
      if (resulting.isApproved && resulting.roles.includes("admin")) {
        approvedAdminIds.add(request.targetUid);
      } else {
        approvedAdminIds.delete(request.targetUid);
      }
      if (approvedAdminIds.size === 0) {
        throw new UserAuthorityMutationError(
          "failed-precondition",
          "At least one approved Admin must remain.",
          {reasonCode: "last-approved-admin-required"},
        );
      }

    }

    const committedAtDate = now();
    const committedAtIso = committedAtDate.toISOString();
    const committedAt = timestampFromDate(committedAtDate);
    const before = {
      isApproved: currentCapsule.isApproved,
      roles: normalizeCanonicalUserRoles(currentCapsule.roles),
      authorityDigest: currentDigest,
      authorityRevision: currentAuthorityRevision,
    };
    const after = {
      isApproved: resulting.isApproved,
      roles: resulting.roles,
      authorityDigest: resultingDigest,
      authorityRevision: resultingAuthorityRevision,
    };
    const actorData = actorSnapshot.data() ?? {};
    const actorName =
      typeof actorData.name === "string" && actorData.name.trim().length > 0 ?
        actorData.name.trim() :
        actorUid;
    const targetName =
      typeof targetData.name === "string" && targetData.name.trim().length > 0 ?
        targetData.name.trim() :
        request.targetUid;
    const summary =
      request.operation === "APPROVE" ?
        `Approved user ${targetName}` :
        request.operation === "REVOKE" ?
          `Revoked user ${targetName}` :
          `Updated roles for ${targetName}`;

    transaction.set(targetRef, {
      isApproved: resulting.isApproved,
      roles: resulting.roles,
      authorityRevision: resultingAuthorityRevision,
      accessDisposition: resulting.isApproved ? "approved" :
        request.operation === "REVOKE" ? "revoked" :
        targetData.accessDisposition === "pending" || targetData.accessDisposition === "revoked" ?
          targetData.accessDisposition : "unknown",
      lastAuthorityDecision: {requestId: request.requestId, operation: request.operation,
        reason: request.reason, actorUid, committedAtIso, authorityRevision: resultingAuthorityRevision},
    }, {merge: true});
    const auditData: UserAuthorityJsonMap = {
      schemaVersion: 1,
      eventType: "userAuthorityMutation",
      entityType: "user",
      entityId: request.targetUid,
      action: "update",
      severity: "high",
      performedByUid: actorUid,
      performedByName: actorName,
      timestamp: committedAt,
      reason: "manualOverride",
      reasonNotes: request.reason,
      committedAtIso,
      summary,
      beforeJson: JSON.stringify(before),
      afterJson: JSON.stringify(after),
      requestId: request.requestId,
      operation: request.operation,
      expectedAuthorityDigest: request.expectedAuthorityDigest,
      expectedAuthorityRevision: request.expectedAuthorityRevision,
      authorityDigest: resultingDigest,
      authorityRevision: resultingAuthorityRevision,
    };
    const evidenceDigest = decisionEvidenceDigest(auditData);
    transaction.set(auditRef, {...auditData, decisionEvidenceDigest: evidenceDigest});
    transaction.set(receiptRef, {
      decisionEvidenceDigest: evidenceDigest,
      schemaVersion: 2,
      requestId: request.requestId,
      actorUid,
      targetUid: request.targetUid,
      operation: request.operation,
      payloadFingerprint: request.payloadFingerprint,
      expectedAuthorityDigest: request.expectedAuthorityDigest,
      expectedAuthorityRevision: request.expectedAuthorityRevision,
      authorityDigest: resultingDigest,
      authorityRevision: resultingAuthorityRevision,
      isApproved: resulting.isApproved,
      roles: resulting.roles,
      auditId,
      committedAt,
      committedAtIso,
    });

    return {
      ok: true,
      requestId: request.requestId,
      targetUid: request.targetUid,
      operation: request.operation,
      isApproved: resulting.isApproved,
      roles: resulting.roles,
      authorityDigest: resultingDigest,
      authorityRevision: resultingAuthorityRevision,
      currentAuthorityDigest: resultingDigest,
      currentAuthorityStatus: "available",
      currentAuthorityRevision: resultingAuthorityRevision,
      supersededByLaterChange: false,
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
