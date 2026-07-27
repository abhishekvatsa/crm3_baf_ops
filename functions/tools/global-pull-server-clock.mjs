#!/usr/bin/env node

import {createHash} from "node:crypto";
import {mkdir, readFile, writeFile} from "node:fs/promises";
import {dirname, resolve} from "node:path";
import {applicationDefault, initializeApp} from "firebase-admin/app";
import {
  FieldPath,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";

const SERVER_STAMP_FIELD = "_globalPullServerUpdatedAt";
const PROTOCOL_VERSION = 1;
const PROTOCOL_FINGERPRINT =
  "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321";
const WRITER_VERSION = "global-pull-server-stamp-v1";
const CONTRACT_PATH = "runtime_contracts/global_pull_v1";
const PAGE_SIZE = 500;
const WRITE_BATCH_SIZE = 400;
const COLLECTIONS = Object.freeze([
  "abnormality_types",
  "charge_abnormalities",
  "directives",
  "job_diary_entries",
  "job_executions",
  "job_modules",
  "job_templates",
  "knowledge_base",
  "maintenance_records",
  "template_packages",
  "template_publish_audits",
  "template_versions",
]);

const MODES = new Set(["inventory", "backfill", "activate"]);
const SOURCE_COMMIT_PATTERN = /^[0-9a-f]{40}$/;

function usage() {
  return `
Usage:
  node functions/tools/global-pull-server-clock.mjs \
    --project <firebase-project-id> [--mode inventory] [--output <receipt.json>]

  node functions/tools/global-pull-server-clock.mjs \
    --project <firebase-project-id> --confirm-project <same-project-id> \
    --mode backfill --operator <identity> --source-commit <40-hex> \
    --output <receipt.json>

  node functions/tools/global-pull-server-clock.mjs \
    --project <firebase-project-id> --confirm-project <same-project-id> \
    --mode activate --operator <identity> --source-commit <40-hex> \
    --backfill-receipt <receipt.json> --output <activation.json>

Inventory is read-only and is the default mode. Backfill stamps only missing
fields and refuses to run when a malformed stamp exists. Activation performs a
fresh zero-gap inventory before writing the runtime contract.
`.trim();
}

function parseArgs(argv) {
  const values = new Map();
  const valueFlags = new Set([
    "--mode",
    "--project",
    "--confirm-project",
    "--operator",
    "--source-commit",
    "--backfill-receipt",
    "--output",
  ]);
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index];
    if (flag === "--help") return {help: true};
    if (!valueFlags.has(flag)) {
      throw new Error(`Unknown argument: ${flag}`);
    }
    if (values.has(flag)) {
      throw new Error(`Duplicate argument: ${flag}`);
    }
    const value = argv[index + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Missing value for ${flag}`);
    }
    values.set(flag, value);
    index += 1;
  }

  const mode = values.get("--mode") ?? "inventory";
  const projectId = values.get("--project");
  if (!MODES.has(mode)) throw new Error(`Unsupported mode: ${mode}`);
  if (!projectId || !/^[a-z0-9][a-z0-9-]{4,61}[a-z0-9]$/.test(projectId)) {
    throw new Error("--project must be an explicit Firebase project ID.");
  }

  const options = {
    help: false,
    mode,
    projectId,
    confirmProjectId: values.get("--confirm-project"),
    operator: values.get("--operator"),
    sourceCommit: values.get("--source-commit"),
    backfillReceiptPath: values.get("--backfill-receipt"),
    outputPath: values.get("--output"),
  };
  if (mode !== "inventory") {
    if (options.confirmProjectId !== projectId) {
      throw new Error(
        "--confirm-project must exactly match --project for a write mode.",
      );
    }
    if (!options.operator?.trim()) {
      throw new Error("--operator is required for a write mode.");
    }
    if (!SOURCE_COMMIT_PATTERN.test(options.sourceCommit ?? "")) {
      throw new Error("--source-commit must be exactly 40 lowercase hex.");
    }
    if (!options.outputPath) {
      throw new Error("--output is required for a write mode.");
    }
  }
  if (mode === "activate" && !options.backfillReceiptPath) {
    throw new Error("--backfill-receipt is required for activation.");
  }
  if (mode !== "activate" && options.backfillReceiptPath) {
    throw new Error("--backfill-receipt is valid only for activation.");
  }
  return options;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value != null && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])]),
    );
  }
  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

function sealReceipt(receipt) {
  return {
    ...receipt,
    receiptSha256: sha256(canonicalJson(receipt)),
  };
}

function verifyReceiptSeal(receipt) {
  if (
    receipt == null ||
    typeof receipt !== "object" ||
    Array.isArray(receipt) ||
    !/^[0-9a-f]{64}$/.test(receipt.receiptSha256 ?? "")
  ) {
    throw new Error("The backfill receipt has no valid SHA-256 seal.");
  }
  const {receiptSha256, ...body} = receipt;
  if (sha256(canonicalJson(body)) !== receiptSha256) {
    throw new Error("The backfill receipt SHA-256 seal does not match.");
  }
}

function protocolEvidence() {
  return {
    protocolVersion: PROTOCOL_VERSION,
    protocolFingerprint: PROTOCOL_FINGERPRINT,
    writerVersion: WRITER_VERSION,
    serverStampField: SERVER_STAMP_FIELD,
    collections: COLLECTIONS,
  };
}

function assertProtocolEvidence(value) {
  if (
    value.protocolVersion !== PROTOCOL_VERSION ||
    value.protocolFingerprint !== PROTOCOL_FINGERPRINT ||
    value.writerVersion !== WRITER_VERSION ||
    value.serverStampField !== SERVER_STAMP_FIELD ||
    canonicalJson(value.collections) !== canonicalJson(COLLECTIONS)
  ) {
    throw new Error("The receipt belongs to another global-pull protocol.");
  }
}

async function scanCollection(db, collectionId) {
  let lastDocument = null;
  let total = 0;
  let stamped = 0;
  let missing = 0;
  let malformed = 0;
  const missingExamples = [];
  const malformedExamples = [];

  while (true) {
    let query = db
      .collection(collectionId)
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDocument != null) query = query.startAfter(lastDocument);
    const snapshot = await query.get();
    for (const document of snapshot.docs) {
      total += 1;
      const value = document.get(SERVER_STAMP_FIELD);
      if (value == null) {
        missing += 1;
        if (missingExamples.length < 20) missingExamples.push(document.id);
      } else if (value instanceof Timestamp) {
        stamped += 1;
      } else {
        malformed += 1;
        if (malformedExamples.length < 20) malformedExamples.push(document.id);
      }
    }
    if (snapshot.size < PAGE_SIZE) break;
    lastDocument = snapshot.docs.at(-1);
  }

  return {
    collectionId,
    total,
    stamped,
    missing,
    malformed,
    missingExamples,
    malformedExamples,
  };
}

async function inventory(db) {
  const collections = [];
  for (const collectionId of COLLECTIONS) {
    collections.push(await scanCollection(db, collectionId));
  }
  return {
    total: collections.reduce((sum, item) => sum + item.total, 0),
    stamped: collections.reduce((sum, item) => sum + item.stamped, 0),
    missing: collections.reduce((sum, item) => sum + item.missing, 0),
    malformed: collections.reduce((sum, item) => sum + item.malformed, 0),
    collections,
  };
}

async function stampMissingDocuments(db, collectionId) {
  let lastDocument = null;
  let updated = 0;
  while (true) {
    let query = db
      .collection(collectionId)
      .orderBy(FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDocument != null) query = query.startAfter(lastDocument);
    const snapshot = await query.get();

    const missing = snapshot.docs.filter(
      (document) => document.get(SERVER_STAMP_FIELD) == null,
    );
    for (let offset = 0; offset < missing.length; offset += WRITE_BATCH_SIZE) {
      const batch = db.batch();
      const slice = missing.slice(offset, offset + WRITE_BATCH_SIZE);
      for (const document of slice) {
        batch.update(
          document.ref,
          {[SERVER_STAMP_FIELD]: FieldValue.serverTimestamp()},
          {lastUpdateTime: document.updateTime},
        );
      }
      await batch.commit();
      updated += slice.length;
    }

    if (snapshot.size < PAGE_SIZE) break;
    lastDocument = snapshot.docs.at(-1);
  }
  return updated;
}

function assertZeroGap(result, label) {
  if (result.missing !== 0 || result.malformed !== 0) {
    throw new Error(
      `${label} failed: missing=${result.missing}, malformed=${result.malformed}.`,
    );
  }
}

async function writeReceipt(path, receipt) {
  const target = resolve(path);
  await mkdir(dirname(target), {recursive: true});
  await writeFile(target, `${JSON.stringify(receipt, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  return target;
}

async function runInventory(db, options) {
  const observedAt = new Date().toISOString();
  const result = await inventory(db);
  const receipt = sealReceipt({
    receiptType: "GLOBAL_PULL_SERVER_CLOCK_INVENTORY",
    receiptVersion: 1,
    projectId: options.projectId,
    observedAt,
    readOnly: true,
    ...protocolEvidence(),
    inventory: result,
  });
  return {
    receipt,
    outputPath: options.outputPath
      ? await writeReceipt(options.outputPath, receipt)
      : null,
  };
}

async function runBackfill(db, options) {
  const startedAt = new Date().toISOString();
  const before = await inventory(db);
  if (before.malformed !== 0) {
    throw new Error(
      `Backfill refused: ${before.malformed} malformed server stamps require adjudication.`,
    );
  }

  const updatedByCollection = {};
  for (const collectionId of COLLECTIONS) {
    updatedByCollection[collectionId] = await stampMissingDocuments(
      db,
      collectionId,
    );
  }
  const after = await inventory(db);
  assertZeroGap(after, "Backfill verification");
  const updated = Object.values(updatedByCollection).reduce(
    (sum, count) => sum + count,
    0,
  );
  if (updated !== before.missing) {
    throw new Error(
      `Backfill count mismatch: expected ${before.missing}, wrote ${updated}.`,
    );
  }

  const receipt = sealReceipt({
    receiptType: "GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED",
    receiptVersion: 1,
    projectId: options.projectId,
    operator: options.operator.trim(),
    sourceCommit: options.sourceCommit,
    startedAt,
    completedAt: new Date().toISOString(),
    ...protocolEvidence(),
    before,
    updated,
    updatedByCollection,
    after,
  });
  return {
    receipt,
    outputPath: await writeReceipt(options.outputPath, receipt),
  };
}

async function readBackfillReceipt(options) {
  const source = resolve(options.backfillReceiptPath);
  const receipt = JSON.parse(await readFile(source, "utf8"));
  verifyReceiptSeal(receipt);
  if (
    receipt.receiptType !== "GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED" ||
    receipt.receiptVersion !== 1 ||
    receipt.projectId !== options.projectId ||
    receipt.sourceCommit !== options.sourceCommit
  ) {
    throw new Error(
      "The backfill receipt does not match this project and source commit.",
    );
  }
  assertProtocolEvidence(receipt);
  assertZeroGap(receipt.after, "Backfill receipt");
  return receipt;
}

async function runActivation(db, options) {
  const backfillReceipt = await readBackfillReceipt(options);
  const preActivation = await inventory(db);
  assertZeroGap(preActivation, "Pre-activation inventory");

  const contractRef = db.doc(CONTRACT_PATH);
  const existing = await contractRef.get();
  if (existing.exists) {
    throw new Error(
      `Activation refused: ${CONTRACT_PATH} already exists and is immutable through this tool.`,
    );
  }

  await contractRef.create({
    state: "ACTIVE",
    protocolVersion: PROTOCOL_VERSION,
    protocolFingerprint: PROTOCOL_FINGERPRINT,
    writerVersion: WRITER_VERSION,
    serverStampField: SERVER_STAMP_FIELD,
    collections: COLLECTIONS,
    activatedAt: FieldValue.serverTimestamp(),
    sourceCommit: options.sourceCommit,
    backfillReceiptSha256: backfillReceipt.receiptSha256,
  });
  const activated = await contractRef.get();
  const data = activated.data();
  if (
    !activated.exists ||
    data?.state !== "ACTIVE" ||
    !(data?.activatedAt instanceof Timestamp) ||
    data?.sourceCommit !== options.sourceCommit ||
    data?.backfillReceiptSha256 !== backfillReceipt.receiptSha256
  ) {
    throw new Error("The runtime contract failed exact activation readback.");
  }
  assertProtocolEvidence(data);

  const receipt = sealReceipt({
    receiptType: "GLOBAL_PULL_SERVER_CLOCK_ACTIVATION",
    receiptVersion: 1,
    projectId: options.projectId,
    operator: options.operator.trim(),
    sourceCommit: options.sourceCommit,
    activatedAt: data.activatedAt.toDate().toISOString(),
    contractPath: CONTRACT_PATH,
    backfillReceiptSha256: backfillReceipt.receiptSha256,
    ...protocolEvidence(),
    preActivation,
  });
  return {
    receipt,
    outputPath: await writeReceipt(options.outputPath, receipt),
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(`${usage()}\n`);
    return;
  }
  initializeApp(
    process.env.FIRESTORE_EMULATOR_HOST
      ? {projectId: options.projectId}
      : {
          credential: applicationDefault(),
          projectId: options.projectId,
        },
  );
  const db = getFirestore();
  const result =
    options.mode === "inventory"
      ? await runInventory(db, options)
      : options.mode === "backfill"
        ? await runBackfill(db, options)
        : await runActivation(db, options);
  process.stdout.write(
    `${JSON.stringify(
      {
        mode: options.mode,
        projectId: options.projectId,
        receiptSha256: result.receipt.receiptSha256,
        outputPath: result.outputPath,
        inventory:
          options.mode === "inventory" ? result.receipt.inventory : undefined,
      },
      null,
      2,
    )}\n`,
  );
}

main().catch((error) => {
  process.stderr.write(`GLOBAL_PULL_GOVERNANCE_FAILED: ${error.message}\n`);
  process.exitCode = 1;
});
