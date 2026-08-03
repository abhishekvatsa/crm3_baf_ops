import assert from "node:assert/strict";
import {createRequire} from "node:module";
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
  trackedPathManifest,
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

test("merged promotion binds exact source files and sealed restore authority", () => {
  const result = validatePromotion(
    process.cwd(),
    "release/approvals/build-8-f4-production-backend-activation-promotion.json",
  );
  assert.equal(Object.values(result.checks).every(Boolean), true);
  assert.equal(Object.values(result.fileChecks).every(Boolean), true);
  assert.deepEqual(trackedPathManifest(process.cwd(), "functions"), {
    fileCount: 112,
    sha256: "E5ADD15B6732ADDCF059D8992EE0F7CE4DBC7F558CCD505A3AF3EE2BF0E0DCAC",
  });
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
