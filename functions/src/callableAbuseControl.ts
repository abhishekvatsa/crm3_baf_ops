import {createHash} from "crypto";

export type MutatingCallableName =
  | "completePlannedJobExecution"
  | "assignPublishedTemplateVersion"
  | "mutateRuntimeJobModulePopulation"
  | "mutateUserAuthority"
  | "executeMaintenanceWorkflowCommand";

export type CallableAbuseErrorCode =
  | "unauthenticated"
  | "permission-denied"
  | "resource-exhausted"
  | "internal";

type JsonMap = {[key: string]: unknown};

type DocumentRefLike = {
  readonly id?: string;
  readonly path?: string;
  get: () => Promise<DocumentSnapshotLike>;
};

type DocumentSnapshotLike = {
  readonly exists: boolean;
  data: () => JsonMap | undefined;
};

type TransactionLike = {
  get: (ref: DocumentRefLike) => Promise<DocumentSnapshotLike>;
  set: (
    ref: DocumentRefLike,
    data: JsonMap,
    options?: JsonMap,
  ) => void;
};

export type CallableAbuseFirestoreLike = {
  collection: (name: string) => {
    doc: (id: string) => DocumentRefLike;
  };
  runTransaction: <T>(
    fn: (transaction: TransactionLike) => Promise<T>,
  ) => Promise<T>;
};

export type CallableAbusePolicy = Readonly<{
  burstWindowSeconds: number;
  burstRequestLimit: number;
  dailyRequestLimit: number;
  anomalyWindowSeconds: number;
  anomalyLimit: number;
}>;

export const CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION = 1;
export const CALLABLE_ABUSE_CONTROL_COLLECTION = "callable_abuse_controls";

const DAY_SECONDS = 24 * 60 * 60;
const MAX_STORED_COUNTER = 1_000_000_000;

export const CALLABLE_ABUSE_POLICIES: Readonly<
  Record<MutatingCallableName, CallableAbusePolicy>
> = Object.freeze({
  completePlannedJobExecution: Object.freeze({
    burstWindowSeconds: 60,
    burstRequestLimit: 12,
    dailyRequestLimit: 300,
    anomalyWindowSeconds: 15 * 60,
    anomalyLimit: 12,
  }),
  assignPublishedTemplateVersion: Object.freeze({
    burstWindowSeconds: 60,
    burstRequestLimit: 8,
    dailyRequestLimit: 100,
    anomalyWindowSeconds: 15 * 60,
    anomalyLimit: 8,
  }),
  mutateRuntimeJobModulePopulation: Object.freeze({
    burstWindowSeconds: 60,
    burstRequestLimit: 90,
    dailyRequestLimit: 2_000,
    anomalyWindowSeconds: 15 * 60,
    anomalyLimit: 30,
  }),
  mutateUserAuthority: Object.freeze({
    burstWindowSeconds: 5 * 60,
    burstRequestLimit: 6,
    dailyRequestLimit: 50,
    anomalyWindowSeconds: 30 * 60,
    anomalyLimit: 6,
  }),
  executeMaintenanceWorkflowCommand: Object.freeze({
    burstWindowSeconds: 60,
    burstRequestLimit: 90,
    dailyRequestLimit: 3_000,
    anomalyWindowSeconds: 15 * 60,
    anomalyLimit: 30,
  }),
});

const STATE_FIELDS = new Set([
  "schemaVersion",
  "callableName",
  "principalHash",
  "burstWindowStartedAtMs",
  "burstRequestCount",
  "dailyWindowStartedAtMs",
  "dailyRequestCount",
  "anomalyWindowStartedAtMs",
  "anomalyCount",
  "blockedRequestCount",
  "lastRequestAtMs",
  "lastBlockedAtMs",
  "lastAnomalyAtMs",
  "lastAnomalyCode",
]);

const CALLER_ANOMALY_CODES = new Set([
  "invalid-argument",
  "permission-denied",
  "not-found",
  "already-exists",
  "failed-precondition",
  "out-of-range",
  "unimplemented",
]);

type CallableAbuseState = {
  schemaVersion: number;
  callableName: MutatingCallableName;
  principalHash: string;
  burstWindowStartedAtMs: number;
  burstRequestCount: number;
  dailyWindowStartedAtMs: number;
  dailyRequestCount: number;
  anomalyWindowStartedAtMs: number;
  anomalyCount: number;
  blockedRequestCount: number;
  lastRequestAtMs: number;
  lastBlockedAtMs: number | null;
  lastAnomalyAtMs: number | null;
  lastAnomalyCode: string | null;
};

export class CallableAbuseControlError extends Error {
  readonly code: CallableAbuseErrorCode;
  readonly details: Readonly<Record<string, unknown>>;

  constructor(
    code: CallableAbuseErrorCode,
    message: string,
    details: Readonly<Record<string, unknown>>,
  ) {
    super(message);
    this.name = "CallableAbuseControlError";
    this.code = code;
    this.details = details;
  }
}

function boundaryError(
  code: "unauthenticated" | "permission-denied",
  message: string,
  callableName: MutatingCallableName,
  reasonCode: string,
): CallableAbuseControlError {
  return new CallableAbuseControlError(
    code,
    message,
    {reasonCode, callableName},
  );
}

function internalError(
  callableName: MutatingCallableName,
  reasonCode: string,
): CallableAbuseControlError {
  return new CallableAbuseControlError(
    "internal",
    "Callable abuse-control state is invalid.",
    {reasonCode, callableName},
  );
}

function principalHash(actorUid: string): string {
  return createHash("sha256").update(actorUid, "utf8").digest("hex");
}

function recordId(
  callableName: MutatingCallableName,
  actorUid: string,
): string {
  return createHash("sha256")
    .update(`${callableName}\n${actorUid}`, "utf8")
    .digest("hex");
}

function requireNonNegativeSafeInteger(
  value: unknown,
  callableName: MutatingCallableName,
  reasonCode: string,
): number {
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0
  ) {
    throw internalError(callableName, reasonCode);
  }
  return value;
}

function requireNullableNonNegativeSafeInteger(
  value: unknown,
  callableName: MutatingCallableName,
  reasonCode: string,
): number | null {
  if (value == null) return null;
  return requireNonNegativeSafeInteger(value, callableName, reasonCode);
}

function newState(
  callableName: MutatingCallableName,
  actorHash: string,
  nowMs: number,
): CallableAbuseState {
  return {
    schemaVersion: CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION,
    callableName,
    principalHash: actorHash,
    burstWindowStartedAtMs: nowMs,
    burstRequestCount: 0,
    dailyWindowStartedAtMs: nowMs,
    dailyRequestCount: 0,
    anomalyWindowStartedAtMs: nowMs,
    anomalyCount: 0,
    blockedRequestCount: 0,
    lastRequestAtMs: nowMs,
    lastBlockedAtMs: null,
    lastAnomalyAtMs: null,
    lastAnomalyCode: null,
  };
}

function parseState(
  data: JsonMap,
  callableName: MutatingCallableName,
  actorHash: string,
): CallableAbuseState {
  const keys = Object.keys(data);
  if (
    keys.length !== STATE_FIELDS.size ||
    keys.some((key) => !STATE_FIELDS.has(key))
  ) {
    throw internalError(callableName, "abuse-control-shape-invalid");
  }
  if (data.schemaVersion !== CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION) {
    throw internalError(callableName, "abuse-control-schema-invalid");
  }
  if (data.callableName !== callableName) {
    throw internalError(callableName, "abuse-control-callable-mismatch");
  }
  if (data.principalHash !== actorHash) {
    throw internalError(callableName, "abuse-control-principal-mismatch");
  }
  if (
    data.lastAnomalyCode != null &&
    (typeof data.lastAnomalyCode !== "string" ||
      !CALLER_ANOMALY_CODES.has(data.lastAnomalyCode))
  ) {
    throw internalError(callableName, "abuse-control-anomaly-code-invalid");
  }

  return {
    schemaVersion: CALLABLE_ABUSE_CONTROL_SCHEMA_VERSION,
    callableName,
    principalHash: actorHash,
    burstWindowStartedAtMs: requireNonNegativeSafeInteger(
      data.burstWindowStartedAtMs,
      callableName,
      "abuse-control-burst-window-invalid",
    ),
    burstRequestCount: requireNonNegativeSafeInteger(
      data.burstRequestCount,
      callableName,
      "abuse-control-burst-count-invalid",
    ),
    dailyWindowStartedAtMs: requireNonNegativeSafeInteger(
      data.dailyWindowStartedAtMs,
      callableName,
      "abuse-control-daily-window-invalid",
    ),
    dailyRequestCount: requireNonNegativeSafeInteger(
      data.dailyRequestCount,
      callableName,
      "abuse-control-daily-count-invalid",
    ),
    anomalyWindowStartedAtMs: requireNonNegativeSafeInteger(
      data.anomalyWindowStartedAtMs,
      callableName,
      "abuse-control-anomaly-window-invalid",
    ),
    anomalyCount: requireNonNegativeSafeInteger(
      data.anomalyCount,
      callableName,
      "abuse-control-anomaly-count-invalid",
    ),
    blockedRequestCount: requireNonNegativeSafeInteger(
      data.blockedRequestCount,
      callableName,
      "abuse-control-blocked-count-invalid",
    ),
    lastRequestAtMs: requireNonNegativeSafeInteger(
      data.lastRequestAtMs,
      callableName,
      "abuse-control-last-request-invalid",
    ),
    lastBlockedAtMs: requireNullableNonNegativeSafeInteger(
      data.lastBlockedAtMs,
      callableName,
      "abuse-control-last-blocked-invalid",
    ),
    lastAnomalyAtMs: requireNullableNonNegativeSafeInteger(
      data.lastAnomalyAtMs,
      callableName,
      "abuse-control-last-anomaly-invalid",
    ),
    lastAnomalyCode: data.lastAnomalyCode as string | null,
  };
}

function stateFromSnapshot(
  snapshot: DocumentSnapshotLike,
  callableName: MutatingCallableName,
  actorHash: string,
  nowMs: number,
): CallableAbuseState {
  if (!snapshot.exists) return newState(callableName, actorHash, nowMs);
  const data = snapshot.data();
  if (data == null) {
    throw internalError(callableName, "abuse-control-document-empty");
  }
  return parseState(data, callableName, actorHash);
}

function resetWindow(
  state: CallableAbuseState,
  startedAtField:
    | "burstWindowStartedAtMs"
    | "dailyWindowStartedAtMs"
    | "anomalyWindowStartedAtMs",
  countField:
    | "burstRequestCount"
    | "dailyRequestCount"
    | "anomalyCount",
  windowMs: number,
  nowMs: number,
): void {
  const startedAtMs = state[startedAtField];
  if (nowMs < startedAtMs) {
    throw internalError(state.callableName, "abuse-control-clock-regressed");
  }
  if (nowMs - startedAtMs >= windowMs) {
    state[startedAtField] = nowMs;
    state[countField] = 0;
  }
}

function normalizedState(
  state: CallableAbuseState,
  policy: CallableAbusePolicy,
  nowMs: number,
): CallableAbuseState {
  const normalized = {...state};
  resetWindow(
    normalized,
    "burstWindowStartedAtMs",
    "burstRequestCount",
    policy.burstWindowSeconds * 1_000,
    nowMs,
  );
  resetWindow(
    normalized,
    "dailyWindowStartedAtMs",
    "dailyRequestCount",
    DAY_SECONDS * 1_000,
    nowMs,
  );
  resetWindow(
    normalized,
    "anomalyWindowStartedAtMs",
    "anomalyCount",
    policy.anomalyWindowSeconds * 1_000,
    nowMs,
  );
  return normalized;
}

function increment(value: number): number {
  return Math.min(value + 1, MAX_STORED_COUNTER);
}

function assertNow(
  now: () => Date,
  callableName: MutatingCallableName,
): number {
  const nowMs = now().getTime();
  if (!Number.isSafeInteger(nowMs) || nowMs < 0) {
    throw internalError(callableName, "abuse-control-server-clock-invalid");
  }
  return nowMs;
}

function anomalyCode(error: unknown): string | null {
  if (
    error == null ||
    typeof error !== "object" ||
    !("code" in error) ||
    typeof error.code !== "string"
  ) {
    return null;
  }
  return CALLER_ANOMALY_CODES.has(error.code) ? error.code : null;
}

async function admitRequest(args: {
  db: CallableAbuseFirestoreLike;
  actorUid: string;
  callableName: MutatingCallableName;
  now: () => Date;
}): Promise<void> {
  const {db, actorUid, callableName, now} = args;
  const policy = CALLABLE_ABUSE_POLICIES[callableName];
  const actorHash = principalHash(actorUid);
  const ref = db
    .collection(CALLABLE_ABUSE_CONTROL_COLLECTION)
    .doc(recordId(callableName, actorUid));
  const nowMs = assertNow(now, callableName);

  const decision = await db.runTransaction(async (transaction) => {
    const state = normalizedState(
      stateFromSnapshot(
        await transaction.get(ref),
        callableName,
        actorHash,
        nowMs,
      ),
      policy,
      nowMs,
    );
    const blockedWindows: Array<{reasonCode: string; retryAtMs: number}> = [];
    if (state.burstRequestCount >= policy.burstRequestLimit) {
      blockedWindows.push({
        reasonCode: "callable-burst-limit-exceeded",
        retryAtMs:
          state.burstWindowStartedAtMs +
          policy.burstWindowSeconds * 1_000,
      });
    }
    if (state.dailyRequestCount >= policy.dailyRequestLimit) {
      blockedWindows.push({
        reasonCode: "callable-daily-limit-exceeded",
        retryAtMs: state.dailyWindowStartedAtMs + DAY_SECONDS * 1_000,
      });
    }
    if (state.anomalyCount >= policy.anomalyLimit) {
      blockedWindows.push({
        reasonCode: "callable-anomaly-limit-exceeded",
        retryAtMs:
          state.anomalyWindowStartedAtMs +
          policy.anomalyWindowSeconds * 1_000,
      });
    }

    state.burstRequestCount = increment(state.burstRequestCount);
    state.dailyRequestCount = increment(state.dailyRequestCount);
    state.lastRequestAtMs = nowMs;
    if (blockedWindows.length > 0) {
      state.blockedRequestCount = increment(state.blockedRequestCount);
      state.lastBlockedAtMs = nowMs;
    }
    transaction.set(ref, state);

    if (blockedWindows.length === 0) return null;
    return {
      reasonCode: blockedWindows[0].reasonCode,
      retryAtMs: Math.max(...blockedWindows.map((item) => item.retryAtMs)),
    };
  });

  if (decision != null) {
    throw new CallableAbuseControlError(
      "resource-exhausted",
      "This mutation is temporarily rate limited.",
      {
        reasonCode: decision.reasonCode,
        callableName,
        retryAfterSeconds: Math.max(
          1,
          Math.ceil((decision.retryAtMs - nowMs) / 1_000),
        ),
      },
    );
  }
}

async function recordAnomaly(args: {
  db: CallableAbuseFirestoreLike;
  actorUid: string;
  callableName: MutatingCallableName;
  code: string;
  now: () => Date;
}): Promise<void> {
  const {db, actorUid, callableName, code, now} = args;
  const policy = CALLABLE_ABUSE_POLICIES[callableName];
  const actorHash = principalHash(actorUid);
  const ref = db
    .collection(CALLABLE_ABUSE_CONTROL_COLLECTION)
    .doc(recordId(callableName, actorUid));
  const nowMs = assertNow(now, callableName);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw internalError(callableName, "abuse-control-record-disappeared");
    }
    const state = normalizedState(
      stateFromSnapshot(snapshot, callableName, actorHash, nowMs),
      policy,
      nowMs,
    );
    state.anomalyCount = increment(state.anomalyCount);
    state.lastAnomalyAtMs = nowMs;
    state.lastAnomalyCode = code;
    transaction.set(ref, state);
  });
}

export async function executeWithCallableAbuseControl<T>(args: {
  db: CallableAbuseFirestoreLike;
  actorUid: string;
  callableName: MutatingCallableName;
  execute: () => Promise<T>;
  now?: () => Date;
}): Promise<T> {
  const actorUid = args.actorUid.trim();
  if (actorUid.length === 0) {
    throw internalError(args.callableName, "abuse-control-principal-empty");
  }
  const now = args.now ?? (() => new Date());
  await admitRequest({...args, actorUid, now});

  try {
    return await args.execute();
  } catch (error) {
    const code = anomalyCode(error);
    if (code != null) {
      try {
        await recordAnomaly({
          db: args.db,
          actorUid,
          callableName: args.callableName,
          code,
          now,
        });
      } catch (accountingError) {
        if (accountingError instanceof CallableAbuseControlError) {
          throw accountingError;
        }
        throw internalError(
          args.callableName,
          "abuse-control-anomaly-accounting-failed",
        );
      }
    }
    throw error;
  }
}

export async function executeAuthorizedMutationWithAbuseControl<T>(args: {
  db: CallableAbuseFirestoreLike;
  actorUid: string | null;
  callableName: MutatingCallableName;
  authorize: (userData: JsonMap) => boolean;
  execute: () => Promise<T>;
  now?: () => Date;
}): Promise<T> {
  const actorUid = args.actorUid?.trim() ?? "";
  if (actorUid.length === 0) {
    throw boundaryError(
      "unauthenticated",
      "Sign in is required.",
      args.callableName,
      "callable-preflight-unauthenticated",
    );
  }

  const actorSnapshot = await args.db
    .collection("users")
    .doc(actorUid)
    .get();
  const actorData = actorSnapshot.exists ? actorSnapshot.data() ?? {} : {};
  if (!args.authorize(actorData)) {
    throw boundaryError(
      "permission-denied",
      "This account is not authorized for the requested mutation.",
      args.callableName,
      "callable-preflight-authority-denied",
    );
  }

  return executeWithCallableAbuseControl({
    db: args.db,
    actorUid,
    callableName: args.callableName,
    execute: args.execute,
    now: args.now,
  });
}
