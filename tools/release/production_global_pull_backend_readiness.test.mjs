import assert from "node:assert/strict";
import {spawnSync} from "node:child_process";
import {createHash} from "node:crypto";
import fs from "node:fs";
import {createRequire} from "node:module";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const require = createRequire(import.meta.url);
const {
  backfillUpdateCountsValid,
  canonicalJson,
  decodeContract,
  indexSetsEqual,
  inventoryShapeValid,
  protocolReceiptChecks,
  sealReceipt,
  validatePromotion,
  verifyReceiptSeal,
} = require("./collectProductionGlobalPullBackend.js");

const protocolCollections = [
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
];

function gitOutput(args, encoding = "utf8") {
  const result = spawnSync("git", args, {
    cwd: process.cwd(),
    encoding,
    windowsHide: true,
  });
  assert.equal(result.status, 0, result.stderr?.toString() ?? "git failed");
  return result.stdout;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex").toUpperCase();
}

function gitBlob(commit, relativePath) {
  return gitOutput(["show", `${commit}:${relativePath}`], null);
}

function trackedPathManifestAtCommit(commit, pathspec) {
  const relativePaths = gitOutput([
    "ls-tree",
    "-r",
    "--name-only",
    commit,
    "--",
    pathspec,
  ])
    .split(/\r?\n/)
    .filter(Boolean)
    .sort();
  const entries = relativePaths.map((relativePath) => ({
    path: relativePath,
    sha256: sha256(gitBlob(commit, relativePath)),
  }));
  return {
    fileCount: entries.length,
    sha256: sha256(canonicalJson(entries)),
  };
}

test("canonical receipt seal is key-order independent and tamper evident", () => {
  const sealed = sealReceipt({
    receiptType: "GLOBAL_PULL_SERVER_CLOCK_INVENTORY",
    receiptVersion: 1,
    projectId: "crm3-baf-ops-b8638",
    readOnly: true,
    privacy: {
      documentIdsRetained: false,
      consoleContainsDocumentIds: false,
    },
    protocolVersion: 1,
    protocolFingerprint:
      "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321",
    writerVersion: "global-pull-server-stamp-v1",
    serverStampField: "_globalPullServerUpdatedAt",
    collections: [
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
    ],
  });

  assert.doesNotThrow(() => verifyReceiptSeal(sealed, "inventory"));
  assert.equal(
    protocolReceiptChecks(
      sealed,
      "GLOBAL_PULL_SERVER_CLOCK_INVENTORY",
      "crm3-baf-ops-b8638",
    ).valid,
    true,
  );
  assert.equal(
    canonicalJson({z: 1, nested: {b: 2, a: 1}}),
    canonicalJson({nested: {a: 1, b: 2}, z: 1}),
  );

  const tampered = {...sealed, projectId: "another-project"};
  assert.throws(
    () => verifyReceiptSeal(tampered, "inventory"),
    /seal does not match/,
  );
  const wrongCollections = sealReceipt({
    ...Object.fromEntries(
      Object.entries(sealed).filter(([key]) => key !== "receiptSha256"),
    ),
    collections: ["maintenance_records"],
  });
  assert.equal(
    protocolReceiptChecks(
      wrongCollections,
      "GLOBAL_PULL_SERVER_CLOCK_INVENTORY",
      "crm3-baf-ops-b8638",
    ).valid,
    false,
  );
});

test("receipt verification CLI avoids inline-script argument marshalling", () => {
  const directory = fs.mkdtempSync(
    path.join(os.tmpdir(), "crm3-production-receipt-verifier-"),
  );
  try {
    const receiptPath = path.join(directory, "receipt.json");
    const receipt = sealReceipt({receiptType: "WINDOWS_HANDOFF_TEST"});
    fs.writeFileSync(receiptPath, `${JSON.stringify(receipt)}\n`, "utf8");
    const result = spawnSync(
      process.execPath,
      [
        path.join(
          process.cwd(),
          "tools/release/collectProductionGlobalPullBackend.js",
        ),
        "--verify-receipt",
        receiptPath,
        "--label",
        "WINDOWS_HANDOFF_TEST",
      ],
      {encoding: "utf8", windowsHide: true},
    );
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {
      verified: true,
      label: "WINDOWS_HANDOFF_TEST",
      receiptSha256: receipt.receiptSha256,
    });
  } finally {
    fs.rmSync(directory, {recursive: true, force: true});
  }
});

test("index comparison ignores only the API-added document-name tiebreaker", () => {
  const source = [
    {
      collectionGroup: "maintenance_records",
      queryScope: "COLLECTION",
      fields: [
        {fieldPath: "isDeleted", order: "ASCENDING"},
        {fieldPath: "createdAt", order: "DESCENDING"},
      ],
    },
  ];
  const live = [
    {
      collectionGroup: "maintenance_records",
      queryScope: "COLLECTION",
      fields: [
        {fieldPath: "isDeleted", order: "ASCENDING"},
        {fieldPath: "createdAt", order: "DESCENDING"},
        {fieldPath: "__name__", order: "DESCENDING"},
      ],
      density: "SPARSE_ALL",
    },
  ];

  assert.equal(indexSetsEqual(source, live), true);
  assert.equal(
    indexSetsEqual(source, [
      {
        ...live[0],
        collectionGroup: undefined,
        name:
          "projects/crm3-baf-ops-b8638/databases/(default)/" +
          "collectionGroups/maintenance_records/indexes/CICAgExample",
      },
    ]),
    true,
  );
  assert.equal(
    indexSetsEqual(source, [
      {
        ...live[0],
        fields: [
          {fieldPath: "isDeleted", order: "ASCENDING"},
          {fieldPath: "createdAt", order: "ASCENDING"},
          {fieldPath: "__name__", order: "ASCENDING"},
        ],
      },
    ]),
    false,
  );
  assert.throws(
    () => indexSetsEqual(source, [{...live[0], collectionGroup: undefined}]),
    /missing its collection-group identity/,
  );
});

test("runtime contract decoding retains only governed shape evidence", () => {
  const decoded = decodeContract({
    fields: {
      state: {stringValue: "ACTIVE"},
      protocolVersion: {integerValue: "1"},
      protocolFingerprint: {
        stringValue:
          "cf9bf145de29799e188ebb37bd4a3c5c668ed9df96b2ba4066404e4d7bc48321",
      },
      writerVersion: {stringValue: "global-pull-server-stamp-v1"},
      serverStampField: {stringValue: "_globalPullServerUpdatedAt"},
      collections: {
        arrayValue: {
          values: [
            {stringValue: "maintenance_records"},
            {stringValue: "job_executions"},
          ],
        },
      },
      activatedAt: {timestampValue: "2026-08-03T19:00:00Z"},
      sourceCommit: {stringValue: "a".repeat(40)},
      backfillReceiptSha256: {stringValue: "b".repeat(64)},
    },
  });

  assert.equal(decoded.state, "ACTIVE");
  assert.equal(decoded.protocolVersion, 1);
  assert.deepEqual(decoded.collections, [
    "maintenance_records",
    "job_executions",
  ]);
  assert.equal(decoded.sourceCommit, "a".repeat(40));
  assert.equal(decoded.backfillReceiptSha256, "b".repeat(64));
  assert.deepEqual(decoded.fieldNames, [
    "activatedAt",
    "backfillReceiptSha256",
    "collections",
    "protocolFingerprint",
    "protocolVersion",
    "serverStampField",
    "sourceCommit",
    "state",
    "writerVersion",
  ]);
});

test("inventory and backfill arithmetic reject partial or inconsistent receipts", () => {
  const collections = protocolCollections.map((collectionId, index) => ({
    collectionId,
    total: index === 0 ? 1 : 0,
    stamped: 0,
    missing: index === 0 ? 1 : 0,
    malformed: 0,
  }));
  const inventory = {
    total: 1,
    stamped: 0,
    missing: 1,
    malformed: 0,
    collections,
  };
  assert.equal(inventoryShapeValid(inventory), true);
  assert.equal(
    inventoryShapeValid({...inventory, collections: collections.slice(0, -1)}),
    false,
  );
  assert.equal(
    inventoryShapeValid({
      ...inventory,
      collections: [{...collections[0], missing: 0}, ...collections.slice(1)],
    }),
    false,
  );

  const updatedByCollection = Object.fromEntries(
    protocolCollections.map((collectionId, index) => [
      collectionId,
      index === 0 ? 1 : 0,
    ]),
  );
  assert.equal(backfillUpdateCountsValid({updated: 1, updatedByCollection}), true);
  assert.equal(
    backfillUpdateCountsValid({updated: 0, updatedByCollection}),
    false,
  );
  assert.equal(
    backfillUpdateCountsValid({
      updated: 1,
      updatedByCollection: Object.fromEntries(
        Object.entries(updatedByCollection).slice(0, -1),
      ),
    }),
    false,
  );
});

test("merged promotion binds the exact deployed historical source", () => {
  const promotion = JSON.parse(
    fs.readFileSync(
      "release/approvals/build-8-f4-production-backend-activation-promotion.json",
      "utf8",
    ),
  );
  const backendEvidence = JSON.parse(
    fs.readFileSync(
      "release/evidence/build-8-f4-production-backend-readiness.json",
      "utf8",
    ),
  );
  const deploymentCommit = backendEvidence.sourceAuthority.deploymentCommit;
  assert.equal(
    deploymentCommit,
    "34dd01511ffd0ca4aba37735b6dfd710d2964b46",
  );
  assert.equal(
    gitOutput(["rev-parse", `${deploymentCommit}^{tree}`]).trim(),
    backendEvidence.sourceAuthority.deploymentTree,
  );
  assert.deepEqual(trackedPathManifestAtCommit(deploymentCommit, "functions"), {
    fileCount: 112,
    sha256: "E5ADD15B6732ADDCF059D8992EE0F7CE4DBC7F558CCD505A3AF3EE2BF0E0DCAC",
  });
  const boundFiles = promotion.sourceAuthority.deploymentFiles;
  assert.equal(boundFiles.length, 13);
  assert.equal(
    boundFiles.every(
      ({path: relativePath, sha256: expectedSha256}) =>
        sha256(gitBlob(deploymentCommit, relativePath)) === expectedSha256,
    ),
    true,
  );
  assert.equal(
    sha256(
      fs.readFileSync(
        "release/evidence/production-prelive-restore-pack-seal.json",
      ),
    ),
    promotion.restoreAuthority.sealReceiptSha256,
  );
  assert.throws(
    () =>
      validatePromotion(
        process.cwd(),
        path.join(
          process.cwd(),
          "release/evidence/production-prelive-restore-pack-seal.json",
        ),
      ),
    /Only the merged promotion/,
  );
});
