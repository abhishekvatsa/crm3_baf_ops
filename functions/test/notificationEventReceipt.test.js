const {
  NOTIFICATION_RECEIPT_COLLECTION,
  NOTIFICATION_RECEIPT_SCHEMA_VERSION,
  NotificationReceiptIntegrityError,
  executeIdempotentNotificationEvent,
  notificationEventReceiptId,
} = require("../lib/notificationEventReceipt");

function firestoreDouble() {
  const documents = new Map();
  let transactionTail = Promise.resolve();

  function ref(collection, id) {
    return {path: `${collection}/${id}`, collection, id};
  }

  const db = {
    collection(name) {
      return {doc: (id) => ref(name, id)};
    },
    runTransaction(callback) {
      const run = transactionTail.then(async () => {
        const writes = [];
        const transaction = {
          async get(documentRef) {
            const value = documents.get(documentRef.path);
            return {
              exists: value != null,
              data: () => value == null ? undefined : {...value},
            };
          },
          set(documentRef, value, options) {
            writes.push({documentRef, value: {...value}, options});
          },
        };
        const result = await callback(transaction);
        for (const write of writes) {
          const prior = documents.get(write.documentRef.path);
          documents.set(
            write.documentRef.path,
            write.options?.merge && prior != null
              ? {...prior, ...write.value}
              : {...write.value},
          );
        }
        return result;
      });
      transactionTail = run.catch(() => undefined);
      return run;
    },
  };

  return {
    db,
    documents,
    seed(collection, id, value) {
      documents.set(`${collection}/${id}`, {...value});
    },
    get(collection, id) {
      return documents.get(`${collection}/${id}`);
    },
  };
}

function harness({now = 1000, attemptIds = ["attempt-1"]} = {}) {
  const store = firestoreDouble();
  let currentNow = now;
  let timestampSequence = 0;
  const ids = [...attemptIds];
  const runtime = {
    db: store.db,
    nowMillis: () => currentNow,
    createAttemptId: () => ids.shift() ?? `attempt-${Date.now()}`,
    serverTimestamp: () => `server-time-${++timestampSequence}`,
    leaseMillis: 100,
  };
  return {
    ...store,
    runtime,
    setNow(value) { currentNow = value; },
  };
}

const identity = {
  triggerName: "onTicketCreated",
  cloudEventId: "cloud-event-1",
  sourceDocumentPath: "maintenance_records/ticket-1",
};

const outcome = {
  attempted: 2,
  succeeded: 2,
  failed: 0,
  staleTokensCleared: 0,
  unknownAgencies: [],
};

function execute(runtime, overrides = {}) {
  return executeIdempotentNotificationEvent({
    runtime,
    ...identity,
    prepare: async () => ({message: "ready"}),
    dispatch: async () => outcome,
    ...overrides,
  });
}

describe("notification event receipts", () => {
  test("receipt identity is deterministic and trigger-scoped", () => {
    const first = notificationEventReceiptId("onTicketCreated", "event-1");
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(notificationEventReceiptId("onTicketCreated", "event-1")).toBe(first);
    expect(notificationEventReceiptId("onTicketResolved", "event-1")).not.toBe(first);
  });

  test("completed replay never prepares or dispatches twice", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    const prepare = jest.fn(async () => ({message: "ready"}));
    const dispatch = jest.fn(async () => outcome);

    const first = await execute(h.runtime, {prepare, dispatch});
    const replay = await execute(h.runtime, {prepare, dispatch});

    expect(first).toMatchObject({kind: "completed", outcome});
    expect(replay).toMatchObject({
      kind: "skipped",
      reason: "already-completed",
    });
    expect(prepare).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledTimes(1);
    const receipt = h.get(
      NOTIFICATION_RECEIPT_COLLECTION,
      notificationEventReceiptId(identity.triggerName, identity.cloudEventId),
    );
    expect(receipt).toMatchObject({
      schemaVersion: NOTIFICATION_RECEIPT_SCHEMA_VERSION,
      status: "completed",
      attemptCount: 1,
      recipientCount: 2,
      succeededCount: 2,
    });
  });

  test("pre-dispatch failure is retryable without duplicate delivery", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    const prepare = jest.fn()
      .mockRejectedValueOnce(new Error("recipient lookup unavailable"))
      .mockResolvedValueOnce({message: "ready"});
    const dispatch = jest.fn(async () => outcome);

    await expect(execute(h.runtime, {prepare, dispatch}))
      .rejects.toThrow("recipient lookup unavailable");
    const recovered = await execute(h.runtime, {prepare, dispatch});

    expect(recovered.kind).toBe("completed");
    expect(dispatch).toHaveBeenCalledTimes(1);
    const receipt = h.get(
      NOTIFICATION_RECEIPT_COLLECTION,
      notificationEventReceiptId(identity.triggerName, identity.cloudEventId),
    );
    expect(receipt).toMatchObject({
      status: "completed",
      attemptCount: 2,
      lastError: null,
      requiresAdjudication: false,
    });
  });

  test("dispatch failure is surfaced, quarantined and cannot resend", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    const reportDeliveryUncertain = jest.fn();
    h.runtime.reportDeliveryUncertain = reportDeliveryUncertain;
    const prepare = jest.fn(async () => ({message: "ready"}));
    const dispatch = jest.fn(async () => {
      throw new Error("FCM outcome unknown");
    });

    await expect(execute(h.runtime, {prepare, dispatch}))
      .rejects.toThrow("FCM outcome unknown");
    const replay = await execute(h.runtime, {prepare, dispatch});

    expect(replay).toMatchObject({
      kind: "skipped",
      reason: "delivery-uncertain",
    });
    expect(prepare).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledTimes(1);
    expect(reportDeliveryUncertain).toHaveBeenCalledTimes(1);
    expect(reportDeliveryUncertain).toHaveBeenCalledWith({
      receiptId: notificationEventReceiptId(
        identity.triggerName,
        identity.cloudEventId,
      ),
      ...identity,
      attemptId: "attempt-1",
      phase: "dispatch-outcome-unknown",
    });
    const receipt = h.get(
      NOTIFICATION_RECEIPT_COLLECTION,
      notificationEventReceiptId(identity.triggerName, identity.cloudEventId),
    );
    expect(receipt).toMatchObject({
      status: "deliveryUncertain",
      requiresAdjudication: true,
    });
  });

  test("operator reporting failure cannot reopen ambiguous delivery", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    h.runtime.reportDeliveryUncertain = async () => {
      throw new Error("logging unavailable");
    };
    const dispatch = jest.fn(async () => {
      throw new Error("FCM outcome unknown");
    });

    await expect(execute(h.runtime, {dispatch}))
      .rejects.toThrow("FCM outcome unknown");
    await expect(execute(h.runtime, {dispatch})).resolves.toMatchObject({
      kind: "skipped",
      reason: "delivery-uncertain",
    });
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  test("active preparation lease blocks concurrent duplicate work", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    let releasePreparation;
    const preparationGate = new Promise((resolve) => {
      releasePreparation = resolve;
    });
    const dispatch = jest.fn(async () => outcome);
    const first = execute(h.runtime, {
      prepare: async () => {
        await preparationGate;
        return {message: "ready"};
      },
      dispatch,
    });
    await new Promise((resolve) => setImmediate(resolve));

    const concurrent = await execute(h.runtime, {dispatch});
    expect(concurrent).toMatchObject({
      kind: "skipped",
      reason: "preparation-in-progress",
    });
    releasePreparation();
    await expect(first).resolves.toMatchObject({kind: "completed"});
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  test("dispatching is durably marked for adjudication until completion", async () => {
    const h = harness();
    let releaseDispatch;
    const dispatchGate = new Promise((resolve) => {
      releaseDispatch = resolve;
    });
    const running = execute(h.runtime, {
      dispatch: async () => {
        await dispatchGate;
        return outcome;
      },
    });
    await new Promise((resolve) => setImmediate(resolve));

    const receiptId = notificationEventReceiptId(
      identity.triggerName,
      identity.cloudEventId,
    );
    expect(h.get(NOTIFICATION_RECEIPT_COLLECTION, receiptId)).toMatchObject({
      status: "dispatching",
      requiresAdjudication: true,
    });

    releaseDispatch();
    await expect(running).resolves.toMatchObject({kind: "completed"});
    expect(h.get(NOTIFICATION_RECEIPT_COLLECTION, receiptId)).toMatchObject({
      status: "completed",
      requiresAdjudication: false,
    });
  });

  test("expired preparation can be reclaimed but stale attempt cannot dispatch", async () => {
    const h = harness({
      now: 1000,
      attemptIds: ["attempt-1", "attempt-2"],
    });
    let releaseFirst;
    const firstGate = new Promise((resolve) => { releaseFirst = resolve; });
    const dispatch = jest.fn(async () => outcome);
    const first = execute(h.runtime, {
      prepare: async () => {
        await firstGate;
        return {message: "stale"};
      },
      dispatch,
    });
    await new Promise((resolve) => setImmediate(resolve));

    h.setNow(1200);
    const second = await execute(h.runtime, {dispatch});
    expect(second.kind).toBe("completed");
    releaseFirst();
    await expect(first).rejects.toMatchObject({
      code: "notification-event-receipt-attempt-mismatch",
    });
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  test("suppressed event is durably idempotent", async () => {
    const h = harness({attemptIds: ["attempt-1", "attempt-2"]});
    const dispatch = jest.fn(async () => outcome);

    expect(await execute(h.runtime, {
      prepare: async () => null,
      dispatch,
    })).toMatchObject({kind: "suppressed"});
    expect(await execute(h.runtime, {dispatch})).toMatchObject({
      kind: "skipped",
      reason: "already-suppressed",
    });
    expect(dispatch).not.toHaveBeenCalled();
  });

  test("malformed receipt fails closed before preparation", async () => {
    const h = harness();
    const receiptId = notificationEventReceiptId(
      identity.triggerName,
      identity.cloudEventId,
    );
    h.seed(NOTIFICATION_RECEIPT_COLLECTION, receiptId, {
      schemaVersion: NOTIFICATION_RECEIPT_SCHEMA_VERSION,
      ...identity,
      status: "completed",
      attemptId: "attempt-old",
      attemptCount: "one",
      leaseExpiresAtEpochMs: null,
    });
    const prepare = jest.fn(async () => ({message: "ready"}));

    await expect(execute(h.runtime, {prepare}))
      .rejects.toBeInstanceOf(NotificationReceiptIntegrityError);
    expect(prepare).not.toHaveBeenCalled();
  });

  test("exhausted attempt counter cannot wrap or reacquire", async () => {
    const h = harness({now: 1000});
    const receiptId = notificationEventReceiptId(
      identity.triggerName,
      identity.cloudEventId,
    );
    h.seed(NOTIFICATION_RECEIPT_COLLECTION, receiptId, {
      schemaVersion: NOTIFICATION_RECEIPT_SCHEMA_VERSION,
      ...identity,
      status: "failedBeforeDispatch",
      attemptId: "attempt-old",
      attemptCount: Number.MAX_SAFE_INTEGER,
      leaseExpiresAtEpochMs: null,
    });
    const dispatch = jest.fn(async () => outcome);

    await expect(execute(h.runtime, {dispatch})).rejects.toMatchObject({
      code: "notification-event-receipt-attempt-exhausted",
    });
    expect(dispatch).not.toHaveBeenCalled();
  });
});
