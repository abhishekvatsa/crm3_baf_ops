import {createHash} from "crypto";
import type {Firestore, Transaction} from "firebase-admin/firestore";

import {stableJson} from "./stableJson";
import {
  canonicalApprovedUserAuthority,
  canonicalUserAuthorityCapsule,
} from "./userAuthority";

type JsonMap = {[key: string]: unknown};

const INSTALLATION_ID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const DEVICE_REQUESTS = "device_recovery_requests";
const DEVICE_RECEIPTS = "device_recovery_receipts";
const INSTALLATIONS = "notification_installations";
const MAX_INSTALLATIONS = 8;
const REQUEST_LIFETIME_MS = 24 * 60 * 60 * 1000;
const SUPPORTED_INSTALLATION_PLATFORMS: readonly string[] = [
  "android", "ios", "macos", "windows", "linux", "fuchsia",
];

const OPERATIONS = new Set([
  "DEVICE_RECOVERY_LIST",
  "DEVICE_RECOVERY_REQUEST",
  "DEVICE_RECOVERY_POLL",
  "DEVICE_RECOVERY_CLAIM",
  "DEVICE_RECOVERY_COMPLETE",
  "DEVICE_RECOVERY_FAIL",
  "DEVICE_RECOVERY_CANCEL",
]);

const ADMIN_OPERATIONS = new Set([
  "DEVICE_RECOVERY_LIST",
  "DEVICE_RECOVERY_REQUEST",
  "DEVICE_RECOVERY_CANCEL",
]);

const CLAIMED_RECOVERY_FIELDS: Readonly<Record<string, readonly string[]>> = {
  DEVICE_RECOVERY_POLL: ["operation", "installationId"],
  DEVICE_RECOVERY_CLAIM: ["operation", "requestId", "installationId"],
  DEVICE_RECOVERY_COMPLETE: [
    "operation", "requestId", "installationId", "backupFileCount",
    "clearedCursorCount", "backedUpUnsyncedRows",
  ],
  DEVICE_RECOVERY_FAIL: [
    "operation", "requestId", "installationId", "failureCode",
  ],
};

export class DeviceRecoveryMutationError extends Error {
  constructor(
    readonly code:
      | "invalid-argument"
      | "unauthenticated"
      | "permission-denied"
      | "not-found"
      | "failed-precondition"
      | "aborted"
      | "data-loss",
    message: string,
    readonly details?: JsonMap,
  ) {
    super(message);
    this.name = "DeviceRecoveryMutationError";
  }
}

export interface DeviceRecoveryMutationResult {
  readonly ok: true;
  readonly operation: string;
  readonly [key: string]: unknown;
}

interface DeviceRecoveryArgs {
  readonly db: Firestore;
  readonly authUid: string | null;
  readonly data: JsonMap;
  readonly timestampFromDate: (date: Date) => unknown;
  readonly now?: () => Date;
}

export function isDeviceRecoveryOperation(value: unknown): boolean {
  return typeof value === "string" && OPERATIONS.has(value);
}

export function userCanMutateDeviceRecovery(
  data: JsonMap,
  operation: unknown,
): boolean {
  const authority = canonicalApprovedUserAuthority(data);
  return authority != null && isDeviceRecoveryOperation(operation) &&
    (!ADMIN_OPERATIONS.has(operation as string) ||
      authority.roles.has("admin"));
}

function requiredText(value: unknown, field: string, maximum: number): string {
  if (typeof value !== "string" || value.trim() !== value ||
      value.length === 0 || value.length > maximum) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      `${field} must be a nonempty canonical string.`,
      {reasonCode: "device-recovery-invalid-field", field},
    );
  }
  return value;
}

function requiredUuid(value: unknown, field: string): string {
  const result = requiredText(value, field, 36);
  if (!INSTALLATION_ID.test(result)) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      `${field} must be a lowercase UUID v4.`,
      {reasonCode: "device-recovery-invalid-identity", field},
    );
  }
  return result;
}

function exactFields(data: JsonMap, fields: readonly string[]): void {
  const actual = Object.keys(data).sort();
  const expected = [...fields].sort();
  if (actual.length !== expected.length ||
      actual.some((key, index) => key !== expected[index])) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      "The device-recovery request contains missing or unexpected fields.",
      {reasonCode: "device-recovery-request-shape-invalid"},
    );
  }
}

function nonNegativeInteger(value: unknown, field: string): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0 ||
      (value as number) > 1_000_000) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      `${field} must be a bounded non-negative integer.`,
      {reasonCode: "device-recovery-invalid-count", field},
    );
  }
  return value as number;
}

export function deviceRecoveryStateDocumentId(
  uid: string,
  installationId: string,
): string {
  return createHash("sha256")
    .update(`${uid}:${installationId}`, "utf8")
    .digest("hex");
}

function toIso(value: unknown, field: string): string {
  const candidate = value as {
    toDate?: () => Date;
    getTime?: () => number;
  } | null;
  const date = value instanceof Date ? value :
    candidate != null && typeof candidate.toDate === "function" ?
      candidate.toDate() :
      candidate != null && typeof candidate.getTime === "function" ?
        new Date(candidate.getTime()) : null;
  if (date == null || !Number.isFinite(date.getTime())) {
    throw new DeviceRecoveryMutationError(
      "data-loss",
      `Persisted device-recovery ${field} is invalid.`,
      {reasonCode: "device-recovery-persisted-timestamp-invalid", field},
    );
  }
  return date.toISOString();
}

function canonicalInstallation(data: JsonMap | undefined): boolean {
  if (data == null) return false;
  const expected = ["platform", "schemaVersion", "token", "updatedAt"];
  const actual = Object.keys(data).sort();
  if (actual.length !== expected.length ||
      actual.some((value, index) => value !== expected[index]) ||
      data.schemaVersion !== 1 || typeof data.token !== "string" ||
      data.token.length === 0 || data.token.length > 4096 ||
      typeof data.platform !== "string" ||
      !SUPPORTED_INSTALLATION_PLATFORMS.includes(data.platform)) {
    return false;
  }
  try {
    toIso(data.updatedAt, "updatedAt");
    return true;
  } catch (_) {
    return false;
  }
}

export const canonicalDeviceInstallationForTest = canonicalInstallation;

async function authoritativeActor(
  transaction: Transaction,
  db: Firestore,
  uid: string,
  requireAdmin: boolean,
): Promise<JsonMap> {
  const snapshot = await transaction.get(db.collection("users").doc(uid));
  const authority = canonicalApprovedUserAuthority(snapshot.data());
  if (!snapshot.exists || authority == null ||
      (requireAdmin && !authority.roles.has("admin"))) {
    throw new DeviceRecoveryMutationError(
      "permission-denied",
      requireAdmin ? "Fresh administrator authority is required." :
        "An approved signed-in user is required.",
      {reasonCode: "device-recovery-authority-denied"},
    );
  }
  return authority.data;
}

interface RecoveryActor {
  readonly data: JsonMap;
  readonly approved: boolean;
}

async function authoritativeRecoveryActor(
  transaction: Transaction,
  db: Firestore,
  uid: string,
): Promise<RecoveryActor> {
  const snapshot = await transaction.get(db.collection("users").doc(uid));
  const data = snapshot.data() as JsonMap | undefined;
  const authority = canonicalUserAuthorityCapsule(data);
  if (!snapshot.exists || data == null || authority == null) {
    throw new DeviceRecoveryMutationError(
      "permission-denied",
      "A valid signed-in recovery account is required.",
      {reasonCode: "device-recovery-authority-denied"},
    );
  }
  return {data, approved: authority.isApproved};
}

function exactRecoveryAudit(
  value: JsonMap | undefined,
  requestId: string,
  actorUid: string,
): boolean {
  return value != null && value.entityType === "deviceRecovery" &&
    value.entityId === requestId && value.performedByUid === actorUid &&
    value.action === "update";
}

function rejectedRevokedRecovery(): DeviceRecoveryMutationError {
  return new DeviceRecoveryMutationError(
    "permission-denied",
    "A revoked account may resume only its exact previously claimed reset.",
    {reasonCode: "device-recovery-claim-authority-denied"},
  );
}

function actorName(data: JsonMap, uid: string): string {
  return typeof data.name === "string" && data.name.trim().length > 0 ?
    data.name.trim() : uid;
}

function auditRecord(args: {
  uid: string;
  name: string;
  requestId: string;
  action: "create" | "update";
  reason: string;
  summary: string;
  before: JsonMap | null;
  after: JsonMap;
  timestamp: unknown;
}): JsonMap {
  return {
    entityType: "deviceRecovery",
    entityId: args.requestId,
    action: args.action,
    performedByUid: args.uid,
    performedByName: args.name,
    timestamp: args.timestamp,
    reason: "manualOverride",
    reasonNotes: args.reason,
    summary: args.summary,
    severity: "high",
    beforeJson: args.before == null ? null : stableJson(args.before),
    afterJson: stableJson(args.after),
  };
}

function publicRequest(data: JsonMap): JsonMap {
  return {
    requestId: data.requestId,
    targetUid: data.targetUid,
    installationId: data.installationId,
    requestedByUid: data.requestedByUid,
    requestedByName: data.requestedByName,
    reason: data.reason,
    requestedAt: toIso(data.requestedAt, "requestedAt"),
    expiresAt: toIso(data.expiresAt, "expiresAt"),
    status: data.status,
  };
}

function validatePendingState(
  state: JsonMap | undefined,
  uid: string,
  installationId: string,
  requestId?: string,
): JsonMap {
  if (state == null || state.schemaVersion !== 1 ||
      state.targetUid !== uid || state.installationId !== installationId ||
      typeof state.requestId !== "string" ||
      !INSTALLATION_ID.test(state.requestId) ||
      typeof state.requestedByUid !== "string" ||
      typeof state.requestedByName !== "string" ||
      typeof state.reason !== "string" ||
      (requestId != null && state.requestId !== requestId)) {
    throw new DeviceRecoveryMutationError(
      "data-loss",
      "The saved device-recovery request does not match this installation.",
      {reasonCode: "device-recovery-state-identity-invalid"},
    );
  }
  toIso(state.requestedAt, "requestedAt");
  toIso(state.expiresAt, "expiresAt");
  return state;
}

export async function userCanResumeClaimedDeviceRecovery(args: {
  db: Firestore;
  actorUid: string | null;
  actorData: JsonMap;
  data: JsonMap;
}): Promise<boolean> {
  const actorUid = args.actorUid?.trim() ?? "";
  const authority = canonicalUserAuthorityCapsule(args.actorData);
  const operation = args.data.operation;
  if (actorUid.length === 0 || authority == null || authority.isApproved ||
      typeof operation !== "string") {
    return false;
  }
  const fields = CLAIMED_RECOVERY_FIELDS[operation];
  if (fields == null) return false;

  try {
    exactFields(args.data, fields);
    const installationId = requiredUuid(
      args.data.installationId,
      "installationId",
    );
    const requestId = operation === "DEVICE_RECOVERY_POLL" ? undefined :
      requiredUuid(args.data.requestId, "requestId");
    let backupFileCount: number | null = null;
    let clearedCursorCount: number | null = null;
    let backedUpUnsyncedRows: number | null = null;
    let failureCode: string | null = null;
    if (operation === "DEVICE_RECOVERY_COMPLETE") {
      backupFileCount = nonNegativeInteger(
        args.data.backupFileCount,
        "backupFileCount",
      );
      clearedCursorCount = nonNegativeInteger(
        args.data.clearedCursorCount,
        "clearedCursorCount",
      );
      backedUpUnsyncedRows = nonNegativeInteger(
        args.data.backedUpUnsyncedRows,
        "backedUpUnsyncedRows",
      );
      if (backupFileCount === 0) return false;
    } else if (operation === "DEVICE_RECOVERY_FAIL") {
      failureCode = requiredText(args.data.failureCode, "failureCode", 80);
    }

    const stateSnapshot = await args.db.collection(DEVICE_REQUESTS)
      .doc(deviceRecoveryStateDocumentId(actorUid, installationId))
      .get();
    if (!stateSnapshot.exists) return false;
    const state = validatePendingState(
      stateSnapshot.data(),
      actorUid,
      installationId,
      requestId,
    );
    if (state.startedByUid !== actorUid) return false;
    const status = state.status;
    const terminalStatus = operation === "DEVICE_RECOVERY_COMPLETE" ?
      "completed" : operation === "DEVICE_RECOVERY_FAIL" ? "failed" : null;
    if (status !== "in_progress" &&
        (terminalStatus == null || status !== terminalStatus)) {
      return false;
    }
    if (status === "completed" &&
        (state.backupFileCount !== backupFileCount ||
          state.clearedCursorCount !== clearedCursorCount ||
          state.backedUpUnsyncedRows !== backedUpUnsyncedRows)) {
      return false;
    }
    if (status === "failed" && state.failureCode !== failureCode) return false;

    const claimedRequestId = state.requestId as string;
    const [receipt, claimAudit] = await Promise.all([
      args.db.collection(DEVICE_RECEIPTS).doc(claimedRequestId).get(),
      args.db.collection("audit_logs")
        .doc(`server_authority_device_recovery_${claimedRequestId}_claimed`)
        .get(),
    ]);
    const evidence = receipt.data() as JsonMap | undefined;
    if (!receipt.exists || evidence == null || evidence.schemaVersion !== 1 ||
        evidence.requestId !== claimedRequestId ||
        evidence.actorUid !== state.requestedByUid ||
        evidence.targetUid !== actorUid ||
        evidence.installationId !== installationId ||
        evidence.reason !== state.reason || !claimAudit.exists ||
        !exactRecoveryAudit(claimAudit.data(), claimedRequestId, actorUid)) {
      return false;
    }
    if (status !== "in_progress") {
      const finalAudit = await args.db.collection("audit_logs")
        .doc(`server_authority_device_recovery_${claimedRequestId}_${status}`)
        .get();
      if (!finalAudit.exists ||
          !exactRecoveryAudit(finalAudit.data(), claimedRequestId, actorUid)) {
        return false;
      }
    }
    return true;
  } catch (error) {
    if (error instanceof DeviceRecoveryMutationError) return false;
    throw error;
  }
}

async function listInstallations(
  args: DeviceRecoveryArgs,
  actorUid: string,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(args.data, ["operation", "targetUid"]);
  const targetUid = requiredText(args.data.targetUid, "targetUid", 128);
  const actorSnapshot = await args.db.collection("users").doc(actorUid).get();
  const actor = canonicalApprovedUserAuthority(actorSnapshot.data());
  if (actor == null || !actor.roles.has("admin")) {
    throw new DeviceRecoveryMutationError(
      "permission-denied",
      "Fresh administrator authority is required.",
      {reasonCode: "device-recovery-authority-denied"},
    );
  }
  const targetRef = args.db.collection("users").doc(targetUid);
  const target = await targetRef.get();
  if (!target.exists ||
      canonicalApprovedUserAuthority(target.data()) == null) {
    throw new DeviceRecoveryMutationError(
      "not-found",
      "An approved target user was not found.",
      {reasonCode: "device-recovery-target-not-found"},
    );
  }

  const snapshots = await targetRef.collection(INSTALLATIONS)
    .where("platform", "in", SUPPORTED_INSTALLATION_PLATFORMS)
    .orderBy("updatedAt", "desc")
    .limit(MAX_INSTALLATIONS)
    .get();
  const installations: JsonMap[] = [];
  const eligibleSnapshots = snapshots.docs
    .filter((installation) =>
      INSTALLATION_ID.test(installation.id) &&
      canonicalInstallation(installation.data() as JsonMap)
    )
    .sort((left, right) =>
      Date.parse(toIso(right.data().updatedAt, "updatedAt")) -
      Date.parse(toIso(left.data().updatedAt, "updatedAt"))
    );
  for (const installation of eligibleSnapshots) {
    const data = installation.data() as JsonMap;
    const stateSnapshot = await args.db.collection(DEVICE_REQUESTS)
      .doc(deviceRecoveryStateDocumentId(targetUid, installation.id))
      .get();
    const state = stateSnapshot.data() as JsonMap | undefined;
    const result: JsonMap = {
      installationId: installation.id,
      platform: data.platform,
      updatedAt: toIso(data.updatedAt, "updatedAt"),
      recoveryStatus: "none",
      recoveryRequestId: null,
      recoveryUpdatedAt: null,
    };
    if (state != null && state.targetUid === targetUid &&
        state.installationId === installation.id) {
      result.recoveryStatus = typeof state.status === "string" ?
        state.status : "invalid";
      result.recoveryRequestId = typeof state.requestId === "string" ?
        state.requestId : null;
      const updatedAt = state.completedAt ?? state.failedAt ??
        state.cancelledAt ?? state.startedAt ?? state.requestedAt;
      if (updatedAt != null) {
        result.recoveryUpdatedAt = toIso(updatedAt, "recoveryUpdatedAt");
      }
    }
    installations.push(result);
  }
  return {
    ok: true,
    operation: "DEVICE_RECOVERY_LIST",
    targetUid,
    installations,
  };
}

async function requestReset(
  args: DeviceRecoveryArgs,
  actorUid: string,
  now: Date,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(args.data, [
    "operation", "requestId", "targetUid", "installationId", "reason",
  ]);
  const requestId = requiredUuid(args.data.requestId, "requestId");
  const targetUid = requiredText(args.data.targetUid, "targetUid", 128);
  const installationId = requiredUuid(
    args.data.installationId,
    "installationId",
  );
  const reason = requiredText(args.data.reason, "reason", 500);
  if (reason.length < 12) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      "A meaningful administrator reason of at least 12 characters is required.",
      {reasonCode: "device-recovery-reason-too-short"},
    );
  }
  const stateRef = args.db.collection(DEVICE_REQUESTS)
    .doc(deviceRecoveryStateDocumentId(targetUid, installationId));
  const receiptRef = args.db.collection(DEVICE_RECEIPTS).doc(requestId);
  const timestamp = args.timestampFromDate(now);
  const expires = args.timestampFromDate(
    new Date(now.getTime() + REQUEST_LIFETIME_MS),
  );

  const result = await args.db.runTransaction(async (transaction) => {
    const actor = await authoritativeActor(transaction, args.db, actorUid, true);
    const targetRef = args.db.collection("users").doc(targetUid);
    const target = await transaction.get(targetRef);
    const installation = await transaction.get(
      targetRef.collection(INSTALLATIONS).doc(installationId),
    );
    const existing = await transaction.get(stateRef);
    const receipt = await transaction.get(receiptRef);

    if (!target.exists ||
        canonicalApprovedUserAuthority(target.data()) == null) {
      throw new DeviceRecoveryMutationError(
        "not-found",
        "An approved target user was not found.",
        {reasonCode: "device-recovery-target-not-found"},
      );
    }
    if (!installation.exists ||
        !canonicalInstallation(installation.data())) {
      throw new DeviceRecoveryMutationError(
        "not-found",
        "The selected phone is not currently registered for that user.",
        {reasonCode: "device-recovery-installation-not-found"},
      );
    }
    if (receipt.exists) {
      const saved = receipt.data() as JsonMap;
      if (saved.actorUid !== actorUid || saved.targetUid !== targetUid ||
          saved.installationId !== installationId || saved.reason !== reason) {
        throw new DeviceRecoveryMutationError(
          "aborted",
          "This device-recovery request identity is already occupied.",
          {reasonCode: "device-recovery-request-replay-conflict"},
        );
      }
      return {idempotentReplay: true};
    }
    const existingData = existing.data() as JsonMap | undefined;
    if (existingData?.status === "in_progress") {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "That phone already has an active device-recovery request.",
        {reasonCode: "device-recovery-already-in-progress"},
      );
    }
    if (existingData?.status === "pending" &&
        new Date(toIso(existingData.expiresAt, "expiresAt")).getTime() >
          now.getTime()) {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "That phone already has a pending administrator recovery request.",
        {reasonCode: "device-recovery-already-pending"},
      );
    }

    const state: JsonMap = {
      schemaVersion: 1,
      requestId,
      targetUid,
      installationId,
      requestedByUid: actorUid,
      requestedByName: actorName(actor, actorUid),
      reason,
      requestedAt: timestamp,
      expiresAt: expires,
      status: "pending",
    };
    transaction.set(stateRef, state);
    transaction.create(receiptRef, {
      schemaVersion: 1,
      requestId,
      actorUid,
      targetUid,
      installationId,
      reason,
      requestedAt: timestamp,
    });
    transaction.create(
      args.db.collection("maintenance_workflow_events")
        .doc(`device_recovery_${requestId}`),
      {
        aggregateId: requestId,
        eventType: "deviceRecovery.requested",
        actorUid,
        actorName: actorName(actor, actorUid),
        actorRoles: [...(canonicalApprovedUserAuthority(actor)?.roles ?? [])]
          .sort(),
        laneKey: null,
        representedLaneKey: null,
        delegationBasis: null,
        commandId: requestId,
        occurredAt: timestamp,
        payload: {deviceRecoveryRequestId: requestId},
      },
    );
    transaction.create(
      args.db.collection("audit_logs")
        .doc(`server_authority_device_recovery_${requestId}_requested`),
      auditRecord({
        uid: actorUid,
        name: actorName(actor, actorUid),
        requestId,
        action: "create",
        reason,
        summary: "Administrator requested a protected device-local data reset.",
        before: null,
        after: {targetUid, installationId, status: "pending"},
        timestamp,
      }),
    );
    return {idempotentReplay: false};
  });

  return {
    ok: true,
    operation: "DEVICE_RECOVERY_REQUEST",
    requestId,
    targetUid,
    installationId,
    status: "pending",
    notificationQueued: true,
    idempotentReplay: result.idempotentReplay,
  };
}

async function pollReset(
  args: DeviceRecoveryArgs,
  actorUid: string,
  now: Date,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(args.data, ["operation", "installationId"]);
  const installationId = requiredUuid(
    args.data.installationId,
    "installationId",
  );

  const request = await args.db.runTransaction(async (transaction) => {
    const actor = await authoritativeRecoveryActor(
      transaction,
      args.db,
      actorUid,
    );
    const userRef = args.db.collection("users").doc(actorUid);
    const installation = await transaction.get(
      userRef.collection(INSTALLATIONS).doc(installationId),
    );
    const stateSnapshot = await transaction.get(
      args.db.collection(DEVICE_REQUESTS)
        .doc(deviceRecoveryStateDocumentId(actorUid, installationId)),
    );
    const registrationCurrent = installation.exists &&
      canonicalInstallation(installation.data());
    if (!stateSnapshot.exists) {
      if (!registrationCurrent) {
        throw new DeviceRecoveryMutationError(
          "failed-precondition",
          "The current phone no longer has a valid device registration.",
          {reasonCode: "device-recovery-installation-not-current"},
        );
      }
      if (!actor.approved) throw rejectedRevokedRecovery();
      return null;
    }
    const state = validatePendingState(
      stateSnapshot.data(),
      actorUid,
      installationId,
    );
    if (!registrationCurrent && state.status !== "in_progress") {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "The current phone no longer has a valid device registration.",
        {reasonCode: "device-recovery-installation-not-current"},
      );
    }
    if (!actor.approved && state.status !== "in_progress") {
      throw rejectedRevokedRecovery();
    }
    if ((state.status !== "pending" && state.status !== "in_progress") ||
        (state.status === "pending" &&
          new Date(toIso(state.expiresAt, "expiresAt")).getTime() <=
            now.getTime())) {
      return null;
    }
    if (state.status === "pending") {
      const issuer = await transaction.get(
        args.db.collection("users")
          .doc(state.requestedByUid as string),
      );
      const issuerAuthority = canonicalApprovedUserAuthority(issuer.data());
      if (issuerAuthority == null || !issuerAuthority.roles.has("admin")) {
        return null;
      }
    }
    const receipt = await transaction.get(
      args.db.collection(DEVICE_RECEIPTS)
        .doc(state.requestId as string),
    );
    const evidence = receipt.data() as JsonMap | undefined;
    if (!receipt.exists || evidence == null ||
        evidence.actorUid !== state.requestedByUid ||
        evidence.targetUid !== actorUid ||
        evidence.installationId !== installationId ||
        evidence.reason !== state.reason) {
      throw new DeviceRecoveryMutationError(
        "data-loss",
        "The administrator device-recovery receipt is missing or inconsistent.",
        {reasonCode: "device-recovery-receipt-invalid"},
      );
    }
    if (!actor.approved || !registrationCurrent) {
      const claimAudit = await transaction.get(
        args.db.collection("audit_logs")
          .doc(`server_authority_device_recovery_${state.requestId}_claimed`),
      );
      if (state.startedByUid !== actorUid || !claimAudit.exists ||
          !exactRecoveryAudit(
            claimAudit.data(),
            state.requestId as string,
            actorUid,
          )) {
        throw rejectedRevokedRecovery();
      }
    }
    return publicRequest(state);
  });

  return {
    ok: true,
    operation: "DEVICE_RECOVERY_POLL",
    installationId,
    request,
  };
}

async function claimReset(
  args: DeviceRecoveryArgs,
  actorUid: string,
  now: Date,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(args.data, ["operation", "requestId", "installationId"]);
  const requestId = requiredUuid(args.data.requestId, "requestId");
  const installationId = requiredUuid(
    args.data.installationId,
    "installationId",
  );
  const stateRef = args.db.collection(DEVICE_REQUESTS)
    .doc(deviceRecoveryStateDocumentId(actorUid, installationId));
  const receiptRef = args.db.collection(DEVICE_RECEIPTS).doc(requestId);
  const auditRef = args.db.collection("audit_logs")
    .doc(`server_authority_device_recovery_${requestId}_claimed`);
  const timestamp = args.timestampFromDate(now);

  const replay = await args.db.runTransaction(async (transaction) => {
    const actor = await authoritativeRecoveryActor(
      transaction,
      args.db,
      actorUid,
    );
    const installation = await transaction.get(
      args.db.collection("users").doc(actorUid)
        .collection(INSTALLATIONS).doc(installationId),
    );
    const snapshot = await transaction.get(stateRef);
    const receipt = await transaction.get(receiptRef);
    const audit = await transaction.get(auditRef);
    if (!snapshot.exists) {
      throw new DeviceRecoveryMutationError(
        "not-found",
        "The requested device recovery no longer exists.",
        {reasonCode: "device-recovery-state-missing"},
      );
    }
    const state = validatePendingState(
      snapshot.data(),
      actorUid,
      installationId,
      requestId,
    );
    const evidence = receipt.data() as JsonMap | undefined;
    if (!receipt.exists || evidence == null ||
        evidence.requestId !== requestId ||
        evidence.actorUid !== state.requestedByUid ||
        evidence.targetUid !== actorUid ||
        evidence.installationId !== installationId ||
        evidence.reason !== state.reason) {
      throw new DeviceRecoveryMutationError(
        "data-loss",
        "The administrator device-recovery receipt is missing or inconsistent.",
        {reasonCode: "device-recovery-receipt-invalid"},
      );
    }
    if (state.status === "in_progress" && audit.exists) {
      if (state.startedByUid !== actorUid) {
        throw new DeviceRecoveryMutationError(
          "aborted",
          "The recovery claim is owned by another account.",
          {reasonCode: "device-recovery-claim-owner-mismatch"},
        );
      }
      if (!exactRecoveryAudit(audit.data(), requestId, actorUid)) {
        throw new DeviceRecoveryMutationError(
          "data-loss",
          "The existing recovery claim audit is inconsistent.",
          {reasonCode: "device-recovery-claim-audit-invalid"},
        );
      }
      return true;
    }
    if (!installation.exists ||
        !canonicalInstallation(installation.data())) {
      throw new DeviceRecoveryMutationError(
        "permission-denied",
        "Only the registered target phone may claim its reset.",
        {reasonCode: "device-recovery-installation-not-current"},
      );
    }
    if (!actor.approved) throw rejectedRevokedRecovery();
    if (state.status !== "pending" || audit.exists) {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "Only a pending device-recovery request can be claimed.",
        {reasonCode: "device-recovery-state-not-pending"},
      );
    }
    const issuer = await transaction.get(
      args.db.collection("users").doc(state.requestedByUid as string),
    );
    const issuerAuthority = canonicalApprovedUserAuthority(issuer.data());
    if (issuerAuthority == null || !issuerAuthority.roles.has("admin")) {
      throw new DeviceRecoveryMutationError(
        "permission-denied",
        "The issuing administrator no longer authorizes this reset.",
        {reasonCode: "device-recovery-issuer-authority-denied"},
      );
    }
    if (new Date(toIso(state.expiresAt, "expiresAt")).getTime() <=
        now.getTime()) {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "The administrator device-recovery request has expired.",
        {reasonCode: "device-recovery-request-expired"},
      );
    }
    transaction.update(stateRef, {
      status: "in_progress",
      startedAt: timestamp,
      startedByUid: actorUid,
    });
    transaction.create(
      auditRef,
      auditRecord({
        uid: actorUid,
        name: actorName(actor.data, actorUid),
        requestId,
        action: "update",
        reason: state.reason as string,
        summary: "Target phone claimed the administrator-authorized local reset.",
        before: {status: "pending"},
        after: {status: "in_progress", installationId},
        timestamp,
      }),
    );
    return false;
  });

  return {
    ok: true,
    operation: "DEVICE_RECOVERY_CLAIM",
    requestId,
    targetUid: actorUid,
    installationId,
    status: "in_progress",
    idempotentReplay: replay,
  };
}

async function finishReset(
  args: DeviceRecoveryArgs,
  actorUid: string,
  now: Date,
  failed: boolean,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(
    args.data,
    failed ? ["operation", "requestId", "installationId", "failureCode"] :
      [
        "operation", "requestId", "installationId", "backupFileCount",
        "clearedCursorCount", "backedUpUnsyncedRows",
      ],
  );
  const requestId = requiredUuid(args.data.requestId, "requestId");
  const installationId = requiredUuid(
    args.data.installationId,
    "installationId",
  );
  const failureCode = failed ?
    requiredText(args.data.failureCode, "failureCode", 80) : null;
  const backupFileCount = failed ? null :
    nonNegativeInteger(args.data.backupFileCount, "backupFileCount");
  const clearedCursorCount = failed ? null :
    nonNegativeInteger(args.data.clearedCursorCount, "clearedCursorCount");
  const backedUpUnsyncedRows = failed ? null :
    nonNegativeInteger(
      args.data.backedUpUnsyncedRows,
      "backedUpUnsyncedRows",
    );
  if (!failed && backupFileCount === 0) {
    throw new DeviceRecoveryMutationError(
      "failed-precondition",
      "A completed device reset requires a retained local backup.",
      {reasonCode: "device-recovery-backup-evidence-missing"},
    );
  }
  const stateRef = args.db.collection(DEVICE_REQUESTS)
    .doc(deviceRecoveryStateDocumentId(actorUid, installationId));
  const timestamp = args.timestampFromDate(now);
  const status = failed ? "failed" : "completed";

  const replay = await args.db.runTransaction(async (transaction) => {
    const actor = await authoritativeRecoveryActor(
      transaction,
      args.db,
      actorUid,
    );
    const snapshot = await transaction.get(stateRef);
    const receipt = await transaction.get(
      args.db.collection(DEVICE_RECEIPTS).doc(requestId),
    );
    const claimAudit = await transaction.get(
      args.db.collection("audit_logs")
        .doc(`server_authority_device_recovery_${requestId}_claimed`),
    );
    const auditRef = args.db.collection("audit_logs")
      .doc(`server_authority_device_recovery_${requestId}_${status}`);
    const audit = await transaction.get(auditRef);
    if (!snapshot.exists) {
      throw new DeviceRecoveryMutationError(
        "not-found",
        "The requested device recovery no longer exists.",
        {reasonCode: "device-recovery-state-missing"},
      );
    }
    const state = validatePendingState(
      snapshot.data(),
      actorUid,
      installationId,
      requestId,
    );
    const evidence = receipt.data() as JsonMap | undefined;
    if (!receipt.exists || evidence == null || evidence.schemaVersion !== 1 ||
        evidence.requestId !== requestId ||
        evidence.actorUid !== state.requestedByUid ||
        evidence.targetUid !== actorUid ||
        evidence.installationId !== installationId ||
        evidence.reason !== state.reason) {
      throw new DeviceRecoveryMutationError(
        "data-loss",
        "The administrator device-recovery receipt is missing or inconsistent.",
        {reasonCode: "device-recovery-receipt-invalid"},
      );
    }
    if (state.startedByUid !== actorUid || !claimAudit.exists ||
        !exactRecoveryAudit(claimAudit.data(), requestId, actorUid)) {
      if (!actor.approved) throw rejectedRevokedRecovery();
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "The device-recovery request has not been claimed by this phone.",
        {reasonCode: "device-recovery-state-not-claimed"},
      );
    }
    if (state.status === status && audit.exists) {
      const evidenceMatches = failed ?
        state.failureCode === failureCode :
        state.backupFileCount === backupFileCount &&
        state.clearedCursorCount === clearedCursorCount &&
        state.backedUpUnsyncedRows === backedUpUnsyncedRows;
      if (!evidenceMatches) {
        throw new DeviceRecoveryMutationError(
          "aborted",
          "The recovery replay does not match its recorded evidence.",
          {reasonCode: "device-recovery-replay-evidence-mismatch"},
        );
      }
      return true;
    }
    if (state.status !== "in_progress" || state.startedByUid !== actorUid ||
        !claimAudit.exists ||
        !exactRecoveryAudit(claimAudit.data(), requestId, actorUid) ||
        audit.exists) {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "The device-recovery request has not been claimed by this phone.",
        {reasonCode: "device-recovery-state-not-claimed"},
      );
    }
    const changes: JsonMap = failed ?
      {status, failedAt: timestamp, failureCode} :
      {
        status,
        completedAt: timestamp,
        backupFileCount,
        clearedCursorCount,
        backedUpUnsyncedRows,
      };
    transaction.update(stateRef, changes);
    transaction.create(
      auditRef,
      auditRecord({
        uid: actorUid,
        name: actorName(actor.data, actorUid),
        requestId,
        action: "update",
        reason: state.reason as string,
        summary: failed ?
          "Target phone refused the administrator device-local reset." :
          "Target phone backed up and cleared its local application database.",
        before: {status: "in_progress"},
        after: {
          status,
          installationId,
          ...(failed ? {failureCode} : {
            backupFileCount,
            clearedCursorCount,
            backedUpUnsyncedRows,
          }),
        },
        timestamp,
      }),
    );
    return false;
  });

  return {
    ok: true,
    operation: failed ? "DEVICE_RECOVERY_FAIL" : "DEVICE_RECOVERY_COMPLETE",
    requestId,
    installationId,
    status,
    idempotentReplay: replay,
  };
}

async function cancelReset(
  args: DeviceRecoveryArgs,
  actorUid: string,
  now: Date,
): Promise<DeviceRecoveryMutationResult> {
  exactFields(args.data, [
    "operation", "requestId", "targetUid", "installationId", "reason",
  ]);
  const requestId = requiredUuid(args.data.requestId, "requestId");
  const targetUid = requiredText(args.data.targetUid, "targetUid", 128);
  const installationId = requiredUuid(
    args.data.installationId,
    "installationId",
  );
  const reason = requiredText(args.data.reason, "reason", 500);
  const stateRef = args.db.collection(DEVICE_REQUESTS)
    .doc(deviceRecoveryStateDocumentId(targetUid, installationId));
  const timestamp = args.timestampFromDate(now);

  await args.db.runTransaction(async (transaction) => {
    const actor = await authoritativeActor(transaction, args.db, actorUid, true);
    const snapshot = await transaction.get(stateRef);
    const auditRef = args.db.collection("audit_logs")
      .doc(`server_authority_device_recovery_${requestId}_cancelled`);
    const audit = await transaction.get(auditRef);
    if (!snapshot.exists) {
      throw new DeviceRecoveryMutationError(
        "not-found",
        "The requested device recovery no longer exists.",
        {reasonCode: "device-recovery-state-missing"},
      );
    }
    const state = validatePendingState(
      snapshot.data(),
      targetUid,
      installationId,
      requestId,
    );
    if (state.status === "cancelled" && audit.exists) {
      if (state.cancelledByUid !== actorUid ||
          state.cancellationReason !== reason) {
        throw new DeviceRecoveryMutationError(
          "aborted",
          "The cancellation replay does not match its recorded evidence.",
          {reasonCode: "device-recovery-cancellation-evidence-mismatch"},
        );
      }
      return;
    }
    if (state.status !== "pending" || audit.exists) {
      throw new DeviceRecoveryMutationError(
        "failed-precondition",
        "Only a pending device-recovery request can be cancelled.",
        {reasonCode: "device-recovery-state-not-pending"},
      );
    }
    transaction.update(stateRef, {
      status: "cancelled",
      cancelledAt: timestamp,
      cancelledByUid: actorUid,
      cancellationReason: reason,
    });
    transaction.create(
      auditRef,
      auditRecord({
        uid: actorUid,
        name: actorName(actor, actorUid),
        requestId,
        action: "update",
        reason,
        summary: "Administrator cancelled a pending device-local reset.",
        before: {status: "pending"},
        after: {status: "cancelled", targetUid, installationId},
        timestamp,
      }),
    );
  });

  return {
    ok: true,
    operation: "DEVICE_RECOVERY_CANCEL",
    requestId,
    targetUid,
    installationId,
    status: "cancelled",
  };
}

export async function mutateDeviceRecoveryWithDb(
  args: DeviceRecoveryArgs,
): Promise<DeviceRecoveryMutationResult> {
  const actorUid = args.authUid;
  if (actorUid == null || actorUid.trim() !== actorUid ||
      actorUid.length === 0) {
    throw new DeviceRecoveryMutationError(
      "unauthenticated",
      "Sign in is required for device recovery.",
      {reasonCode: "device-recovery-unauthenticated"},
    );
  }
  const operation = args.data.operation;
  if (!isDeviceRecoveryOperation(operation)) {
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      "The device-recovery operation is not supported.",
      {reasonCode: "device-recovery-operation-unsupported"},
    );
  }
  const now = (args.now ?? (() => new Date()))();
  switch (operation) {
  case "DEVICE_RECOVERY_LIST":
    return listInstallations(args, actorUid);
  case "DEVICE_RECOVERY_REQUEST":
    return requestReset(args, actorUid, now);
  case "DEVICE_RECOVERY_POLL":
    return pollReset(args, actorUid, now);
  case "DEVICE_RECOVERY_CLAIM":
    return claimReset(args, actorUid, now);
  case "DEVICE_RECOVERY_COMPLETE":
    return finishReset(args, actorUid, now, false);
  case "DEVICE_RECOVERY_FAIL":
    return finishReset(args, actorUid, now, true);
  case "DEVICE_RECOVERY_CANCEL":
    return cancelReset(args, actorUid, now);
  default:
    throw new DeviceRecoveryMutationError(
      "invalid-argument",
      "The device-recovery operation is not supported.",
    );
  }
}
