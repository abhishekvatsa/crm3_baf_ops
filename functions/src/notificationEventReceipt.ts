import {createHash, randomUUID} from "node:crypto";

export const NOTIFICATION_RECEIPT_COLLECTION =
  "notification_event_receipts";
export const NOTIFICATION_RECEIPT_SCHEMA_VERSION = 1;
export const NOTIFICATION_RECEIPT_LEASE_MS = 5 * 60 * 1000;

export type NotificationReceiptStatus =
  | "preparing"
  | "dispatching"
  | "completed"
  | "suppressed"
  | "failedBeforeDispatch"
  | "retryableDeliveryFailed"
  | "deliveryUncertain";

export interface ReceiptSnapshotLike {
  readonly exists: boolean;
  data(): Record<string, unknown> | undefined;
}

export interface ReceiptDocumentRefLike {
  readonly path?: string;
}

export interface ReceiptCollectionRefLike {
  doc(id: string): ReceiptDocumentRefLike;
}

export interface ReceiptTransactionLike {
  get(ref: ReceiptDocumentRefLike): Promise<ReceiptSnapshotLike>;
  set(
    ref: ReceiptDocumentRefLike,
    data: Record<string, unknown>,
    options?: {merge: boolean},
  ): void;
}

export interface NotificationReceiptFirestoreLike {
  collection(name: string): ReceiptCollectionRefLike;
  runTransaction<T>(
    fn: (transaction: ReceiptTransactionLike) => Promise<T>,
  ): Promise<T>;
}

export interface NotificationDeliveryOutcome {
  attempted: number;
  succeeded: number;
  failed: number;
  retryableFailures: number;
  staleTokensCleared: number;
  unknownAgencies: ReadonlyArray<string>;
}

export interface NotificationReceiptRuntime {
  db: NotificationReceiptFirestoreLike;
  serverTimestamp(): unknown;
  nowMillis?(): number;
  createAttemptId?(): string;
  leaseMillis?: number;
  reportDeliveryUncertain?(
    signal: NotificationDeliveryUncertainSignal,
  ): void | Promise<void>;
}

export interface NotificationDeliveryUncertainSignal {
  receiptId: string;
  triggerName: string;
  cloudEventId: string;
  sourceDocumentPath: string;
  attemptId: string;
  phase: "dispatch-outcome-unknown" | "completion-recording-failed";
}

export type NotificationEventExecutionResult =
  | {
      kind: "completed";
      receiptId: string;
      outcome: NotificationDeliveryOutcome;
    }
  | {kind: "suppressed"; receiptId: string}
  | {
      kind: "skipped";
      receiptId: string;
      reason:
        | "already-completed"
        | "already-suppressed"
        | "preparation-in-progress"
        | "delivery-uncertain";
    };

export class NotificationReceiptIntegrityError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "NotificationReceiptIntegrityError";
    this.code = code;
  }
}

export class NotificationRetryableDeliveryError extends Error {
  readonly code = "notification-delivery-retryable-failure";

  constructor() {
    super("Notification delivery failed with a known retryable outcome.");
    this.name = "NotificationRetryableDeliveryError";
  }
}

interface ReceiptIdentity {
  triggerName: string;
  cloudEventId: string;
  sourceDocumentPath: string;
}

interface ReceiptState extends ReceiptIdentity {
  status: NotificationReceiptStatus;
  attemptId: string;
  attemptCount: number;
  leaseExpiresAtEpochMs: number | null;
}

interface AcquiredReceipt {
  kind: "acquired";
  receiptId: string;
  attemptId: string;
}

type ReceiptAcquisition = AcquiredReceipt | NotificationEventExecutionResult;

const RECEIPT_STATUSES = new Set<NotificationReceiptStatus>([
  "preparing",
  "dispatching",
  "completed",
  "suppressed",
  "failedBeforeDispatch",
  "retryableDeliveryFailed",
  "deliveryUncertain",
]);

function requireNonEmpty(value: string, field: string): void {
  if (value.trim().length === 0) {
    throw new NotificationReceiptIntegrityError(
      "notification-event-identity-malformed",
      `${field} must be non-empty.`,
    );
  }
}

export function notificationEventReceiptId(
  triggerName: string,
  cloudEventId: string,
): string {
  requireNonEmpty(triggerName, "triggerName");
  requireNonEmpty(cloudEventId, "cloudEventId");
  return createHash("sha256")
    .update("notification-event-receipt-v1\0")
    .update(triggerName)
    .update("\0")
    .update(cloudEventId)
    .digest("hex");
}

function parseReceipt(
  data: Record<string, unknown> | undefined,
  identity: ReceiptIdentity,
): ReceiptState {
  if (data == null ||
      data.schemaVersion !== NOTIFICATION_RECEIPT_SCHEMA_VERSION ||
      data.triggerName !== identity.triggerName ||
      data.cloudEventId !== identity.cloudEventId ||
      data.sourceDocumentPath !== identity.sourceDocumentPath) {
    throw new NotificationReceiptIntegrityError(
      "notification-event-receipt-identity-mismatch",
      "Notification receipt schema or immutable identity is malformed.",
    );
  }

  if (typeof data.status !== "string" ||
      !RECEIPT_STATUSES.has(data.status as NotificationReceiptStatus) ||
      typeof data.attemptId !== "string" ||
      data.attemptId.length === 0 ||
      !Number.isSafeInteger(data.attemptCount) ||
      (data.attemptCount as number) < 1) {
    throw new NotificationReceiptIntegrityError(
      "notification-event-receipt-state-malformed",
      "Notification receipt state is malformed.",
    );
  }

  const status = data.status as NotificationReceiptStatus;
  const lease = data.leaseExpiresAtEpochMs;
  if (status === "preparing" &&
      (!Number.isSafeInteger(lease) || (lease as number) < 0)) {
    throw new NotificationReceiptIntegrityError(
      "notification-event-receipt-lease-malformed",
      "A preparing notification receipt must carry a valid lease.",
    );
  }
  if (status !== "preparing" && lease !== null) {
    throw new NotificationReceiptIntegrityError(
      "notification-event-receipt-lease-malformed",
      "A non-preparing notification receipt cannot carry a lease.",
    );
  }

  return {
    ...identity,
    status,
    attemptId: data.attemptId,
    attemptCount: data.attemptCount as number,
    leaseExpiresAtEpochMs: lease as number | null,
  };
}

function errorText(error: unknown): string {
  const value = error instanceof Error ? error.message : String(error);
  return value.slice(0, 500);
}

async function acquireReceipt(
  runtime: NotificationReceiptRuntime,
  identity: ReceiptIdentity,
): Promise<ReceiptAcquisition> {
  const now = (runtime.nowMillis ?? Date.now)();
  const leaseMillis = runtime.leaseMillis ?? NOTIFICATION_RECEIPT_LEASE_MS;
  if (!Number.isSafeInteger(now) || now < 0 ||
      !Number.isSafeInteger(leaseMillis) || leaseMillis <= 0 ||
      !Number.isSafeInteger(now + leaseMillis)) {
    throw new Error("Notification receipt clock and lease must be safe integers.");
  }
  const attemptId = (runtime.createAttemptId ?? randomUUID)();
  requireNonEmpty(attemptId, "attemptId");
  const receiptId = notificationEventReceiptId(
    identity.triggerName,
    identity.cloudEventId,
  );
  const ref = runtime.db
    .collection(NOTIFICATION_RECEIPT_COLLECTION)
    .doc(receiptId);

  return runtime.db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    let attemptCount = 1;
    if (snapshot.exists) {
      const existing = parseReceipt(snapshot.data(), identity);
      if (existing.status === "completed") {
        return {
          kind: "skipped",
          receiptId,
          reason: "already-completed",
        };
      }
      if (existing.status === "suppressed") {
        return {
          kind: "skipped",
          receiptId,
          reason: "already-suppressed",
        };
      }
      if (existing.status === "dispatching" ||
          existing.status === "deliveryUncertain") {
        return {
          kind: "skipped",
          receiptId,
          reason: "delivery-uncertain",
        };
      }
      if (existing.status === "preparing" &&
          existing.leaseExpiresAtEpochMs != null &&
          existing.leaseExpiresAtEpochMs > now) {
        return {
          kind: "skipped",
          receiptId,
          reason: "preparation-in-progress",
        };
      }
      if (existing.attemptCount === Number.MAX_SAFE_INTEGER) {
        throw new NotificationReceiptIntegrityError(
          "notification-event-receipt-attempt-exhausted",
          "Notification receipt attempt counter is exhausted.",
        );
      }
      attemptCount = existing.attemptCount + 1;
    }

    transaction.set(
      ref,
      {
        schemaVersion: NOTIFICATION_RECEIPT_SCHEMA_VERSION,
        ...identity,
        status: "preparing",
        attemptId,
        attemptCount,
        leaseExpiresAtEpochMs: now + leaseMillis,
        ...(!snapshot.exists ? {createdAt: runtime.serverTimestamp()} : {}),
        lastError: null,
        requiresAdjudication: false,
        lastAttemptedAt: runtime.serverTimestamp(),
        updatedAt: runtime.serverTimestamp(),
      },
      {merge: true},
    );
    return {kind: "acquired", receiptId, attemptId};
  });
}

async function reportDeliveryUncertain(args: {
  runtime: NotificationReceiptRuntime;
  identity: ReceiptIdentity;
  receiptId: string;
  attemptId: string;
  phase: NotificationDeliveryUncertainSignal["phase"];
}): Promise<void> {
  try {
    await args.runtime.reportDeliveryUncertain?.({
      receiptId: args.receiptId,
      ...args.identity,
      attemptId: args.attemptId,
      phase: args.phase,
    });
  } catch {
    // Observability must not weaken the receipt's fail-closed state.
  }
}

async function transitionReceipt(args: {
  runtime: NotificationReceiptRuntime;
  identity: ReceiptIdentity;
  receiptId: string;
  attemptId: string;
  expectedStatus: NotificationReceiptStatus;
  patch: Record<string, unknown>;
  allowAlreadyFinal?: boolean;
}): Promise<void> {
  const ref = args.runtime.db
    .collection(NOTIFICATION_RECEIPT_COLLECTION)
    .doc(args.receiptId);
  await args.runtime.db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw new NotificationReceiptIntegrityError(
        "notification-event-receipt-disappeared",
        "Notification receipt disappeared during processing.",
      );
    }
    const current = parseReceipt(snapshot.data(), args.identity);
    if (args.allowAlreadyFinal &&
        (current.status === "completed" ||
          current.status === "suppressed" ||
          current.status === "deliveryUncertain")) {
      return;
    }
    if (current.attemptId !== args.attemptId) {
      throw new NotificationReceiptIntegrityError(
        "notification-event-receipt-attempt-mismatch",
        "A stale notification attempt cannot mutate the active receipt.",
      );
    }
    if (current.status !== args.expectedStatus) {
      throw new NotificationReceiptIntegrityError(
        "notification-event-receipt-transition-invalid",
        `Cannot transition notification receipt from ${current.status}.`,
      );
    }
    transaction.set(
      ref,
      {
        ...args.patch,
        updatedAt: args.runtime.serverTimestamp(),
      },
      {merge: true},
    );
  });
}

export async function executeIdempotentNotificationEvent<T>(args: {
  runtime: NotificationReceiptRuntime;
  triggerName: string;
  cloudEventId: string;
  sourceDocumentPath: string;
  prepare(): Promise<T | null>;
  dispatch(plan: T): Promise<NotificationDeliveryOutcome>;
  retryKnownFailure?(
    plan: T,
    outcome: NotificationDeliveryOutcome,
  ): boolean;
}): Promise<NotificationEventExecutionResult> {
  const identity: ReceiptIdentity = {
    triggerName: args.triggerName,
    cloudEventId: args.cloudEventId,
    sourceDocumentPath: args.sourceDocumentPath,
  };
  requireNonEmpty(identity.triggerName, "triggerName");
  requireNonEmpty(identity.cloudEventId, "cloudEventId");
  requireNonEmpty(identity.sourceDocumentPath, "sourceDocumentPath");

  const acquisition = await acquireReceipt(args.runtime, identity);
  if (acquisition.kind !== "acquired") return acquisition;
  const transition = (
    expectedStatus: NotificationReceiptStatus,
    patch: Record<string, unknown>,
    allowAlreadyFinal = false,
  ) => transitionReceipt({
    runtime: args.runtime,
    identity,
    receiptId: acquisition.receiptId,
    attemptId: acquisition.attemptId,
    expectedStatus,
    patch,
    allowAlreadyFinal,
  });

  let plan: T | null;
  try {
    plan = await args.prepare();
  } catch (error) {
    await transition("preparing", {
      status: "failedBeforeDispatch",
      leaseExpiresAtEpochMs: null,
      failedBeforeDispatchAt: args.runtime.serverTimestamp(),
      lastError: errorText(error),
      requiresAdjudication: false,
    });
    throw error;
  }

  if (plan == null) {
    await transition("preparing", {
      status: "suppressed",
      leaseExpiresAtEpochMs: null,
      suppressedAt: args.runtime.serverTimestamp(),
      lastError: null,
      requiresAdjudication: false,
    });
    return {kind: "suppressed", receiptId: acquisition.receiptId};
  }

  await transition("preparing", {
    status: "dispatching",
    leaseExpiresAtEpochMs: null,
    dispatchStartedAt: args.runtime.serverTimestamp(),
    requiresAdjudication: true,
  });

  let outcome: NotificationDeliveryOutcome;
  try {
    outcome = await args.dispatch(plan);
  } catch (error) {
    try {
      await transition("dispatching", {
        status: "deliveryUncertain",
        leaseExpiresAtEpochMs: null,
        deliveryUncertainAt: args.runtime.serverTimestamp(),
        lastError: errorText(error),
        requiresAdjudication: true,
      }, true);
    } catch {
      // A replay still sees `dispatching` and cannot automatically resend.
    }
    await reportDeliveryUncertain({
      runtime: args.runtime,
      identity,
      receiptId: acquisition.receiptId,
      attemptId: acquisition.attemptId,
      phase: "dispatch-outcome-unknown",
    });
    throw error;
  }

  if (args.retryKnownFailure?.(plan, outcome) === true) {
    await transition("dispatching", {
      status: "retryableDeliveryFailed",
      leaseExpiresAtEpochMs: null,
      retryableDeliveryFailedAt: args.runtime.serverTimestamp(),
      recipientCount: outcome.attempted,
      succeededCount: outcome.succeeded,
      failedCount: outcome.failed,
      retryableFailureCount: outcome.retryableFailures,
      staleTokensCleared: outcome.staleTokensCleared,
      unknownAgencies: [...outcome.unknownAgencies],
      lastError: "Known retryable delivery failure.",
      requiresAdjudication: false,
    });
    throw new NotificationRetryableDeliveryError();
  }

  try {
    await transition("dispatching", {
      status: "completed",
      leaseExpiresAtEpochMs: null,
      completedAt: args.runtime.serverTimestamp(),
      recipientCount: outcome.attempted,
      succeededCount: outcome.succeeded,
      failedCount: outcome.failed,
      retryableFailureCount: outcome.retryableFailures,
      staleTokensCleared: outcome.staleTokensCleared,
      unknownAgencies: [...outcome.unknownAgencies],
      lastError: null,
      requiresAdjudication: false,
    });
  } catch (error) {
    try {
      await transition("dispatching", {
        status: "deliveryUncertain",
        leaseExpiresAtEpochMs: null,
        deliveryUncertainAt: args.runtime.serverTimestamp(),
        lastError: errorText(error),
        requiresAdjudication: true,
      }, true);
    } catch {
      // Fail closed: `dispatching` is itself a non-replayable state.
    }
    await reportDeliveryUncertain({
      runtime: args.runtime,
      identity,
      receiptId: acquisition.receiptId,
      attemptId: acquisition.attemptId,
      phase: "completion-recording-failed",
    });
    throw error;
  }

  return {kind: "completed", receiptId: acquisition.receiptId, outcome};
}
