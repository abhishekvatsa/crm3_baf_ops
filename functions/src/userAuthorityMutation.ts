import {createHash} from "crypto";

import {
  canonicalApprovedUserAuthority,
  canonicalUserAuthorityCapsule,
  canonicalUserAuthorityDigest,
  normalizeCanonicalUserRoles,
  UserAuthorityJsonMap,
} from "./userAuthority";

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
  readonly roles: ReadonlyArray<string> | null;
  readonly reason: string;
  readonly payloadFingerprint: string;
}

export interface UserAuthorityMutationResult {
  readonly ok: true;
  readonly requestId: string;
  readonly targetUid: string;
  readonly operation: UserAuthorityMutationOperation;
  readonly isApproved: boolean;
  readonly roles: ReadonlyArray<string>;
  readonly authorityDigest: string;
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
  "roles",
  "reason",
]);
const MAX_REASON_LENGTH = 500;
const MIN_REASON_LENGTH = 8;

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

function fingerprint(value: unknown): string {
  return `authreq1-sha256:${
    createHash("sha256")
      .update(JSON.stringify(value), "utf8")
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
  const reason = cleanRequiredString(raw.reason, "reason", MAX_REASON_LENGTH);
  if (reason.length < MIN_REASON_LENGTH) {
    throw new UserAuthorityMutationError(
      "invalid-argument",
      `reason must contain at least ${MIN_REASON_LENGTH} characters.`,
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

  const canonicalPayload = {
    requestId,
    targetUid,
    operation,
    expectedAuthorityDigest,
    roles,
    reason,
  };
  return {
    ...canonicalPayload,
    payloadFingerprint: fingerprint(canonicalPayload),
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

function resultFromReceipt(
  request: ParsedUserAuthorityMutationRequest,
  actorUid: string,
  receipt: UserAuthorityJsonMap,
  target: UserAuthorityJsonMap,
  audit: UserAuthorityJsonMap | null,
  expectedAuditId: string,
): UserAuthorityMutationResult {
  if (
    receipt.payloadFingerprint !== request.payloadFingerprint ||
    receipt.actorUid !== actorUid ||
    receipt.targetUid !== request.targetUid
  ) {
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
  if (targetCapsule == null) {
    throw new UserAuthorityMutationError(
      "data-loss",
      "The replay target authority capsule is malformed.",
      {reasonCode: "authority-replay-target-malformed"},
    );
  }
  const currentDigest = canonicalUserAuthorityDigest(targetCapsule);
  if (receipt.authorityDigest !== currentDigest) {
    throw new UserAuthorityMutationError(
      "aborted",
      "The target authority changed after the recorded mutation.",
      {reasonCode: "authority-replay-evidence-drift"},
    );
  }
  const roles = normalizeCanonicalUserRoles(targetCapsule.roles);
  const operation = receipt.operation;
  const committedAt = receipt.committedAtIso;
  const auditId = receipt.auditId;
  if (
    operation !== request.operation ||
    typeof committedAt !== "string" ||
    Number.isNaN(Date.parse(committedAt)) ||
    auditId !== expectedAuditId ||
    receipt.expectedAuthorityDigest !== request.expectedAuthorityDigest ||
    audit.requestId !== request.requestId ||
    audit.performedByUid !== actorUid ||
    audit.entityId !== request.targetUid ||
    audit.operation !== request.operation ||
    audit.authorityDigest !== currentDigest
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
    isApproved: targetCapsule.isApproved,
    roles,
    authorityDigest: currentDigest,
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

  actorAuthority(await actorRef.get());
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
    actorAuthority(actorSnapshot);

    const targetSnapshot = documentSnapshot(
      await transaction.get(targetRef),
      "Authority target lookup",
    );
    if (!targetSnapshot.exists) {
      throw new UserAuthorityMutationError(
        receiptSnapshot.exists ? "data-loss" : "not-found",
        receiptSnapshot.exists ?
          "The recorded authority mutation target is missing." :
          "The target user record was not found.",
        {
          reasonCode: receiptSnapshot.exists ?
            "authority-replay-target-missing" :
            "authority-target-not-found",
        },
      );
    }
    const targetData = targetSnapshot.data() ?? {};
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
      );
    }
    if (auditSnapshot.exists) {
      throw new UserAuthorityMutationError(
        "aborted",
        "The immutable authority audit identity is already occupied.",
        {reasonCode: "authority-audit-collision", auditId},
      );
    }

    const adminSnapshot = querySnapshot(
      await transaction.get(approvedAdminQuery),
      "Approved Admin roster lookup",
    );
    const currentCapsule = canonicalUserAuthorityCapsule(targetData);
    if (currentCapsule == null) {
      throw new UserAuthorityMutationError(
        "failed-precondition",
        "The target authority capsule is malformed.",
        {reasonCode: "authority-target-malformed"},
      );
    }
    const currentDigest = canonicalUserAuthorityDigest(currentCapsule);
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

    const approvedAdminIds = new Set<string>();
    for (const snapshot of adminSnapshot.docs) {
      const authority = canonicalUserAuthorityCapsule(
        snapshot.exists ? snapshot.data() ?? {} : {},
      );
      if (authority == null) {
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

    const committedAtDate = now();
    const committedAtIso = committedAtDate.toISOString();
    const committedAt = timestampFromDate(committedAtDate);
    const before = {
      isApproved: currentCapsule.isApproved,
      roles: normalizeCanonicalUserRoles(currentCapsule.roles),
      authorityDigest: currentDigest,
    };
    const after = {
      isApproved: resulting.isApproved,
      roles: resulting.roles,
      authorityDigest: resultingDigest,
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
    }, {merge: true});
    transaction.set(auditRef, {
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
      summary,
      beforeJson: JSON.stringify(before),
      afterJson: JSON.stringify(after),
      requestId: request.requestId,
      operation: request.operation,
      expectedAuthorityDigest: request.expectedAuthorityDigest,
      authorityDigest: resultingDigest,
    });
    transaction.set(receiptRef, {
      schemaVersion: 1,
      requestId: request.requestId,
      actorUid,
      targetUid: request.targetUid,
      operation: request.operation,
      payloadFingerprint: request.payloadFingerprint,
      expectedAuthorityDigest: request.expectedAuthorityDigest,
      authorityDigest: resultingDigest,
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
      auditId,
      committedAt: committedAtIso,
      idempotentReplay: false,
    };
  });
}
