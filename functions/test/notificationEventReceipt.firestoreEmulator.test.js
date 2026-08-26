const admin = require("firebase-admin");
const {
  NOTIFICATION_RECEIPT_COLLECTION,
  executeIdempotentNotificationEvent,
  notificationEventReceiptId,
} = require("../lib/notificationEventReceipt");

jest.setTimeout(60000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  "crm3-baf-ops-b8638";
const appName = `notification-receipts-${process.pid}-${Date.now()}`;

const outcome = {
  attempted: 1,
  succeeded: 1,
  failed: 0,
  retryableFailures: 0,
  staleTokensCleared: 0,
  unknownAgencies: [],
};

describeWithEmulator("R-05 notification event receipts", () => {
  let app;
  let db;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: "DELETE"},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  function runtime() {
    return {
      db,
      serverTimestamp: () => admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  function execute(
    eventId,
    dispatch,
    prepare = async () => ({ready: true}),
    retryKnownFailure,
  ) {
    return executeIdempotentNotificationEvent({
      runtime: runtime(),
      triggerName: "onTicketCreated",
      cloudEventId: eventId,
      sourceDocumentPath: "maintenance_records/ticket-1",
      prepare,
      dispatch,
      retryKnownFailure,
    });
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

  beforeEach(clearFirestore);

  afterAll(async () => {
    if (app) await app.delete();
  });

  test("concurrent duplicate events perform one delivery", async () => {
    let dispatchCount = 0;
    const dispatch = async () => {
      dispatchCount += 1;
      await new Promise((resolve) => setTimeout(resolve, 25));
      return outcome;
    };

    const results = await Promise.all(
      Array.from({length: 12}, () => execute("cloud-concurrent", dispatch)),
    );

    expect(dispatchCount).toBe(1);
    expect(results.filter((result) => result.kind === "completed")).toHaveLength(1);
    expect(results.filter((result) => result.kind === "skipped")).toHaveLength(11);
    const receipt = await db
      .collection(NOTIFICATION_RECEIPT_COLLECTION)
      .doc(notificationEventReceiptId("onTicketCreated", "cloud-concurrent"))
      .get();
    expect(receipt.data()).toMatchObject({
      status: "completed",
      attemptCount: 1,
      recipientCount: 1,
      succeededCount: 1,
    });
  });

  test("completed receipt bypasses preparation and dispatch on replay", async () => {
    const dispatch = jest.fn(async () => outcome);
    const prepare = jest.fn(async () => ({ready: true}));

    await execute("cloud-replay", dispatch, prepare);
    const replay = await execute("cloud-replay", dispatch, prepare);

    expect(replay).toMatchObject({
      kind: "skipped",
      reason: "already-completed",
    });
    expect(prepare).toHaveBeenCalledTimes(1);
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  test("ambiguous dispatch is quarantined and never retried automatically", async () => {
    const dispatch = jest.fn(async () => {
      throw new Error("delivery acknowledgement unavailable");
    });

    await expect(execute("cloud-uncertain", dispatch))
      .rejects.toThrow("delivery acknowledgement unavailable");
    const replay = await execute("cloud-uncertain", dispatch);

    expect(replay).toMatchObject({
      kind: "skipped",
      reason: "delivery-uncertain",
    });
    expect(dispatch).toHaveBeenCalledTimes(1);
    const receipt = await db
      .collection(NOTIFICATION_RECEIPT_COLLECTION)
      .doc(notificationEventReceiptId("onTicketCreated", "cloud-uncertain"))
      .get();
    expect(receipt.data()).toMatchObject({
      status: "deliveryUncertain",
      attemptCount: 1,
      requiresAdjudication: true,
    });
  });

  test("known zero-success transient delivery can retry transactionally", async () => {
    const transient = {
      ...outcome,
      succeeded: 0,
      failed: 1,
      retryableFailures: 1,
    };
    const dispatch = jest.fn()
      .mockResolvedValueOnce(transient)
      .mockResolvedValueOnce(outcome);
    const retryKnownFailure = (_plan, result) =>
      result.succeeded === 0 && result.retryableFailures === 1;

    await expect(execute(
      "cloud-known-failure",
      dispatch,
      undefined,
      retryKnownFailure,
    )).rejects.toMatchObject({
      code: "notification-delivery-retryable-failure",
    });
    await expect(execute(
      "cloud-known-failure",
      dispatch,
      undefined,
      retryKnownFailure,
    )).resolves.toMatchObject({kind: "completed"});

    expect(dispatch).toHaveBeenCalledTimes(2);
    const receipt = await db
      .collection(NOTIFICATION_RECEIPT_COLLECTION)
      .doc(notificationEventReceiptId(
        "onTicketCreated",
        "cloud-known-failure",
      ))
      .get();
    expect(receipt.data()).toMatchObject({
      status: "completed",
      attemptCount: 2,
      succeededCount: 1,
      retryableFailureCount: 0,
      requiresAdjudication: false,
    });
  });
});
