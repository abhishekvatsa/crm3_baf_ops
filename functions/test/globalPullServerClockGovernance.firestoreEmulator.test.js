const {mkdtemp, readFile, rm} = require("node:fs/promises");
const {tmpdir} = require("node:os");
const {join, resolve} = require("node:path");
const {spawnSync} = require("node:child_process");
const admin = require("firebase-admin");

jest.setTimeout(120000);

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
const describeWithEmulator = emulatorHost ? describe : describe.skip;
const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  "crm3-baf-ops-b8638";
const sourceCommit = "a".repeat(40);
const appName = `global-pull-governance-${process.pid}-${Date.now()}`;
const toolPath = resolve(
  __dirname,
  "..",
  "tools",
  "global-pull-server-clock.mjs",
);

describeWithEmulator("R-01/R-02 global pull governance", () => {
  let app;
  let db;
  let evidenceDirectory;

  async function clearFirestore() {
    const response = await fetch(
      `http://${emulatorHost}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
      {method: "DELETE"},
    );
    if (!response.ok) {
      throw new Error(`${response.status} ${await response.text()}`);
    }
  }

  function runTool(args) {
    return spawnSync(process.execPath, [toolPath, ...args], {
      encoding: "utf8",
      env: {
        ...process.env,
        FIRESTORE_EMULATOR_HOST: emulatorHost,
        GCLOUD_PROJECT: projectId,
      },
      timeout: 90000,
    });
  }

  beforeAll(async () => {
    app = admin.initializeApp({projectId}, appName);
    db = admin.firestore(app);
  });

  beforeEach(async () => {
    await clearFirestore();
    evidenceDirectory = await mkdtemp(
      join(tmpdir(), "crm3-global-pull-governance-"),
    );
  });

  afterEach(async () => {
    await rm(evidenceDirectory, {recursive: true, force: true});
  });

  afterAll(async () => {
    if (app) await app.delete();
  });

  test("inventory evidence is privacy-safe unless IDs are explicit", async () => {
    const missingId = "sensitive-missing-record";
    const malformedId = "sensitive-malformed-record";
    await db.collection("directives").doc(missingId).set({isDeleted: false});
    await db.collection("directives").doc(malformedId).set({
      _globalPullServerUpdatedAt: "client-authored",
    });

    const safePath = join(evidenceDirectory, "inventory-safe.json");
    const safe = runTool([
      "--project",
      projectId,
      "--mode",
      "inventory",
      "--output",
      safePath,
    ]);
    expect(safe.status).toBe(0);
    expect(safe.stdout).not.toContain(missingId);
    expect(safe.stdout).not.toContain(malformedId);
    const safeText = await readFile(safePath, "utf8");
    expect(safeText).not.toContain(missingId);
    expect(safeText).not.toContain(malformedId);
    const safeReceipt = JSON.parse(safeText);
    expect(safeReceipt.privacy).toEqual({
      documentIdsRetained: false,
      maximumExampleIdsPerCollection: 0,
      consoleContainsDocumentIds: false,
    });
    const safeDirectives = safeReceipt.inventory.collections.find(
      ({collectionId}) => collectionId === "directives",
    );
    expect(safeDirectives).toMatchObject({missing: 1, malformed: 1});
    expect(safeDirectives).not.toHaveProperty("missingExamples");
    expect(safeDirectives).not.toHaveProperty("malformedExamples");

    const diagnosticPath = join(evidenceDirectory, "inventory-diagnostic.json");
    const diagnostic = runTool([
      "--project",
      projectId,
      "--mode",
      "inventory",
      "--include-document-ids",
      "--output",
      diagnosticPath,
    ]);
    expect(diagnostic.status).toBe(0);
    expect(diagnostic.stdout).not.toContain(missingId);
    expect(diagnostic.stdout).not.toContain(malformedId);
    const diagnosticReceipt = JSON.parse(
      await readFile(diagnosticPath, "utf8"),
    );
    expect(diagnosticReceipt.privacy.documentIdsRetained).toBe(true);
    const diagnosticDirectives = diagnosticReceipt.inventory.collections.find(
      ({collectionId}) => collectionId === "directives",
    );
    expect(diagnosticDirectives.missingExamples).toContain(missingId);
    expect(diagnosticDirectives.malformedExamples).toContain(malformedId);
  });

  test("write modes reject document-ID diagnostics", () => {
    const result = runTool([
      "--project",
      projectId,
      "--confirm-project",
      projectId,
      "--mode",
      "backfill",
      "--operator",
      "emulator-test",
      "--source-commit",
      sourceCommit,
      "--include-document-ids",
      "--output",
      join(evidenceDirectory, "should-not-exist.json"),
    ]);

    expect(result.status).not.toBe(0);
    expect(result.stderr).toContain(
      "--include-document-ids is valid only for inventory",
    );
  });

  test("verified backfill precedes immutable protocol activation", async () => {
    await db.collection("directives").doc("legacy-missing").set({
      isDeleted: false,
      updatedAt: admin.firestore.Timestamp.fromDate(
        new Date("2026-07-27T18:00:00.000Z"),
      ),
    });
    await db.collection("maintenance_records").doc("already-stamped").set({
      _globalPullServerUpdatedAt: admin.firestore.Timestamp.fromDate(
        new Date("2026-07-27T18:01:00.000Z"),
      ),
    });

    const backfillPath = join(evidenceDirectory, "backfill.json");
    const backfill = runTool([
      "--project",
      projectId,
      "--confirm-project",
      projectId,
      "--mode",
      "backfill",
      "--operator",
      "emulator-test",
      "--source-commit",
      sourceCommit,
      "--output",
      backfillPath,
    ]);
    expect(backfill.status).toBe(0);
    const backfillReceipt = JSON.parse(await readFile(backfillPath, "utf8"));
    expect(backfillReceipt).toMatchObject({
      receiptType: "GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED",
      projectId,
      sourceCommit,
      updated: 1,
      before: {missing: 1, malformed: 0},
      after: {missing: 0, malformed: 0},
    });
    expect(backfillReceipt.receiptSha256).toMatch(/^[0-9a-f]{64}$/);

    const stamped = await db
      .collection("directives")
      .doc("legacy-missing")
      .get();
    expect(stamped.get("_globalPullServerUpdatedAt")).toBeInstanceOf(
      admin.firestore.Timestamp,
    );

    const activationPath = join(evidenceDirectory, "activation.json");
    const activation = runTool([
      "--project",
      projectId,
      "--confirm-project",
      projectId,
      "--mode",
      "activate",
      "--operator",
      "emulator-test",
      "--source-commit",
      sourceCommit,
      "--backfill-receipt",
      backfillPath,
      "--output",
      activationPath,
    ]);
    expect(activation.status).toBe(0);

    const contract = (
      await db.doc("runtime_contracts/global_pull_v1").get()
    ).data();
    expect(contract).toMatchObject({
      state: "ACTIVE",
      protocolVersion: 1,
      writerVersion: "global-pull-server-stamp-v1",
      serverStampField: "_globalPullServerUpdatedAt",
      sourceCommit,
      backfillReceiptSha256: backfillReceipt.receiptSha256,
    });
    expect(contract.activatedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  test("malformed stamps fail before any backfill write", async () => {
    await db.collection("directives").doc("malformed").set({
      _globalPullServerUpdatedAt: "client-authored",
    });
    await db.collection("maintenance_records").doc("still-missing").set({
      updatedAt: admin.firestore.Timestamp.now(),
    });

    const result = runTool([
      "--project",
      projectId,
      "--confirm-project",
      projectId,
      "--mode",
      "backfill",
      "--operator",
      "emulator-test",
      "--source-commit",
      sourceCommit,
      "--output",
      join(evidenceDirectory, "should-not-exist.json"),
    ]);

    expect(result.status).not.toBe(0);
    expect(result.stderr).toContain(
      "malformed server stamps require adjudication",
    );
    const untouched = await db
      .collection("maintenance_records")
      .doc("still-missing")
      .get();
    expect(untouched.get("_globalPullServerUpdatedAt")).toBeUndefined();
  });
});
