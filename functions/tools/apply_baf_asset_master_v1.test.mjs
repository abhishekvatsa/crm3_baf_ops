import assert from "node:assert/strict";
import {createRequire} from "node:module";
import fs from "node:fs/promises";
import test from "node:test";
import {
  assertGovernedApplyManifest,
  buildPlan,
  deterministicUuid,
  loadManifest,
  validateReceiptAndAudit,
} from "./apply_baf_asset_master_v1.mjs";
import "./apply_baf_inner_cover_baseline_v1.test.mjs";

const require = createRequire(import.meta.url);
const {parseAssetHierarchyMutationRequest} = require("../lib/assetHierarchyMutation.js");
const {parseAssetRegistryMutationRequest} = require("../lib/assetRegistryMutation.js");

const governedManifestPath = new URL(
  "../../tools/assets/baf_asset_master_v1.json",
  import.meta.url,
);

test("production apply accepts only the exact governed manifest", async () => {
  const manifestBytes = await fs.readFile(governedManifestPath);
  const manifest = JSON.parse(manifestBytes.toString("utf8"));
  assert.doesNotThrow(() => assertGovernedApplyManifest({
    apply: true,
    manifest,
    manifestBytes,
  }));
  const altered = Buffer.from(manifestBytes);
  altered[altered.length - 2] = altered[altered.length - 2] === 10 ? 32 : 10;
  assert.throws(
    () => assertGovernedApplyManifest({apply: true, manifest, manifestBytes: altered}),
    /exact approved BAF asset-master manifest bytes/,
  );
  assert.doesNotThrow(() => assertGovernedApplyManifest({
    apply: false,
    manifest: {...manifest, manifestId: "dry-run-candidate"},
    manifestBytes: altered,
  }));
});

function timestamp(iso) {
  return {toDate: () => new Date(iso)};
}

function fixtureForEntry(entry, fingerprint = `${entry.entityType}-fingerprint`) {
  const {entityType} = entry;
  const prefix = entityType === "asset" ? "asset_registry" : "asset_hierarchy";
  const auditId = `${prefix}_${entry.requestId}`;
  const committedAtIso = "2026-08-18T09:00:00.000Z";
  const afterIdField = entityType === "class" ? "assetClassId" :
    entityType === "node" ? "nodeId" : "assetInstanceId";
  const after = {
    [afterIdField]: entry.entityId,
    assetClassId: entry.data.assetClassId,
    lastMutationId: entry.requestId,
    version: 1,
    updatedByUid: "admin-uid",
  };
  return {
    entry,
    receipt: {
      schemaVersion: 1,
      requestId: entry.requestId,
      actorUid: "admin-uid",
      fingerprint,
      operation: entry.data.operation,
      assetClassId: entry.data.assetClassId,
      nodeId: entityType === "node" ? entry.entityId : null,
      entityId: entry.entityId,
      version: 1,
      auditId,
      committedAt: timestamp(committedAtIso),
      committedAtIso,
    },
    audit: {
      schemaVersion: 1,
      auditId,
      entityType: entityType === "class" ? "asset_class" :
        entityType === "node" ? "hierarchy_node" : "asset_instance",
      entityId: entry.entityId,
      assetClassId: entry.data.assetClassId,
      action: "create",
      reason: entry.data.reason,
      beforeJson: null,
      afterJson: JSON.stringify(after),
      performedByUid: "admin-uid",
      performedByName: "Admin",
      performedAt: timestamp(committedAtIso),
      requestId: entry.requestId,
      tagTransferApproved: false,
    },
  };
}

function fixture(entityType) {
  const ids = {
    class: "class-id",
    node: "node-id",
    asset: "asset-id",
  };
  const entry = {
    entityType,
    entityId: ids[entityType],
    requestId: `${entityType}-request`,
    data: {
      requestId: `${entityType}-request`,
      operation: entityType === "class" ? "CREATE_CLASS" :
        entityType === "node" ? "CREATE_NODE" : "CREATE_ASSET_INSTANCE",
      assetClassId: entityType === "class" ? "class-id" : "owner-class-id",
      reason: "Approved governed population.",
    },
  };
  return fixtureForEntry(entry);
}

for (const entityType of ["class", "node", "asset"]) {
  test(`validates ${entityType} receipt and audit contents`, () => {
    const value = fixture(entityType);
    assert.doesNotThrow(() => validateReceiptAndAudit({
      ...value,
      actorUid: "admin-uid",
      parseHierarchyRequest: () => ({fingerprint: `${entityType}-fingerprint`}),
      parseRegistryRequest: () => ({fingerprint: `${entityType}-fingerprint`}),
    }));
  });
}

test("rejects foreign or malformed production evidence", () => {
  const value = fixture("asset");
  value.receipt.fingerprint = "foreign-fingerprint";
  assert.throws(() => validateReceiptAndAudit({
    ...value,
    actorUid: "admin-uid",
    parseHierarchyRequest: () => ({fingerprint: "asset-fingerprint"}),
    parseRegistryRequest: () => ({fingerprint: "asset-fingerprint"}),
  }));
});

test("binds canonical plan evidence to real mutation fingerprints", async () => {
  const plan = buildPlan(await loadManifest());
  for (const entry of [plan.classes[0], plan.nodes[0], plan.assets[0]]) {
    const parsed = entry.entityType === "asset" ?
      parseAssetRegistryMutationRequest(entry.data) :
      parseAssetHierarchyMutationRequest(entry.data);
    assert.doesNotThrow(() => validateReceiptAndAudit({
      ...fixtureForEntry(entry, parsed.fingerprint),
      actorUid: "admin-uid",
      parseHierarchyRequest: parseAssetHierarchyMutationRequest,
      parseRegistryRequest: parseAssetRegistryMutationRequest,
    }));
  }
});

test("BAF asset-master plan is exact, deterministic and serial-safe", async () => {
  const plan = buildPlan(await loadManifest());
  assert.equal(plan.classes.length, 4);
  assert.ok(plan.nodes.length > 0);
  assert.equal(plan.assets.length, 98);
  assert.equal(plan.assets.filter((entry) => entry.classKey === "base").length, 47);
  assert.equal(plan.assets.filter((entry) => entry.classKey === "furnace").length, 26);
  assert.equal(plan.assets.filter((entry) => entry.classKey === "forceCooler").length, 25);
  assert.equal(plan.pendingInnerCoverIntake.length, 44);
  assert.ok(plan.pendingInnerCoverIntake.every(
    (entry) => entry.serialNumber == null && entry.createsOperationalIdentity === false,
  ));
  assert.ok(plan.assets.every((entry) => entry.data.assetDraft.serialNumber == null));

  const allEntries = [...plan.classes, ...plan.nodes, ...plan.assets];
  assert.equal(new Set(allEntries.map((entry) => entry.entityId)).size, allEntries.length);
  assert.equal(new Set(allEntries.map((entry) => entry.requestId)).size, allEntries.length);
  assert.equal(
    deterministicUuid("asset", "BASE:101"),
    deterministicUuid("asset", "BASE:101"),
  );
  assert.notEqual(
    deterministicUuid("asset", "BASE:101"),
    deterministicUuid("asset", "BASE:102"),
  );

  for (const entry of [...plan.classes, ...plan.nodes]) {
    assert.doesNotThrow(() => parseAssetHierarchyMutationRequest(entry.data));
  }
  for (const entry of plan.assets) {
    assert.doesNotThrow(() => parseAssetRegistryMutationRequest(entry.data));
  }
});

test("asset display identities preserve the approved plant numbering", async () => {
  const plan = buildPlan(await loadManifest());
  const bases = plan.assets.filter((entry) => entry.classKey === "base");
  const furnaces = plan.assets.filter((entry) => entry.classKey === "furnace");
  const coolers = plan.assets.filter((entry) => entry.classKey === "forceCooler");

  assert.deepEqual(
    bases.map((entry) => entry.data.assetDraft.assetNumber),
    [...Array.from({length: 24}, (_, index) => 101 + index), ...Array.from({length: 23}, (_, index) => 201 + index)],
  );
  assert.deepEqual(
    furnaces.map((entry) => entry.data.assetDraft.name),
    Array.from({length: 26}, (_, index) => `Furnace ${String(index + 1).padStart(2, "0")}`),
  );
  assert.deepEqual(
    coolers.map((entry) => entry.data.assetDraft.name),
    Array.from({length: 25}, (_, index) => `Forced Cooler ${index + 1}`),
  );
});
