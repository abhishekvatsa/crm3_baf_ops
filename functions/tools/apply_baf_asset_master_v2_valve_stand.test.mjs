import test from "node:test";
import assert from "node:assert/strict";
import {createRequire} from "node:module";

import {
  buildPlan,
  loadManifest,
} from "./apply_baf_asset_master_v2_valve_stand.mjs";

const require = createRequire(import.meta.url);
const {parseAssetHierarchyMutationRequest} = require("../lib/assetHierarchyMutation.js");

test("Valve Stand migration preserves identities and reparents the exact five nodes", async () => {
  const plan = await buildPlan(await loadManifest());
  assert.equal(plan.entries.length, 6);
  assert.equal(plan.entries[0].action, "create");
  assert.equal(plan.entries[0].data.nodeDraft.name, "Valve Stand assembly");
  assert.equal(plan.entries[0].data.nodeDraft.parentNodeId, plan.parentNodeId);
  assert.deepEqual(
    plan.entries.slice(1).map((entry) => entry.entityId),
    [
      "9cbc89e9-880b-502e-b026-ded675fb4180",
      "e1ce4731-1ac2-5e2f-8cbd-5c36f0722c57",
      "0dc03472-f16d-520b-a1b4-6492612d5a75",
      "51b02460-6692-5660-8fba-90ae51bb86e5",
      "45eaaac9-9343-5ad4-ac18-dfab303a60f0",
    ],
  );
  assert.ok(plan.entries.slice(1).every(
    (entry) => entry.data.nodeDraft.parentNodeId === plan.assemblyId &&
      entry.data.expectedVersion === 1,
  ));
  for (const entry of plan.entries) {
    assert.doesNotThrow(() => parseAssetHierarchyMutationRequest(entry.data));
  }
});
