import test from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";
import {
  buildPlan,
  deterministicUuid,
  loadManifest,
} from "./apply_baf_asset_master_v1.mjs";

const require = createRequire(import.meta.url);
const {parseAssetHierarchyMutationRequest} = require("../lib/assetHierarchyMutation.js");
const {parseAssetRegistryMutationRequest} = require("../lib/assetRegistryMutation.js");

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
