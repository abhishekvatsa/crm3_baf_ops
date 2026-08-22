import assert from "node:assert/strict";
import test from "node:test";

import {
  buildPlan,
  loadManifest,
} from "./apply_baf_inner_cover_baseline_v1.mjs";

test("builds the exact owner-supplied Inner Cover baseline", async () => {
  const plan = buildPlan(await loadManifest());
  assert.equal(plan.records.length, 38);
  assert.deepEqual(plan.originCounts, {
    ownerDeclaredFabricated: 14,
    ownerDeclaredNew: 8,
    legacyUndocumented: 16,
  });
  assert.equal(new Set(plan.records.map((record) => record.baseNumber)).size, 38);
  assert.equal(new Set(plan.records.map((record) => record.serialNumber)).size, 38);
  const gr15 = plan.records.find((record) => record.serialNumber === "GR15");
  assert.equal(gr15.baseNumber, 117);
  assert.equal(gr15.incorporatedOn, "2026-07-14T12:00:00.000Z");
  assert.equal(gr15.fabricationSections.length, 4);
  assert.ok(gr15.fabricationSections.every((section) =>
    section.materialSource === "reusedUnknownLegacyDonor"));
  const n16 = plan.records.find((record) => record.serialNumber === "N16");
  assert.equal(n16.sourceType, "legacyExisting");
  assert.equal(n16.declaredOrigin, "ownerDeclaredNew");
  assert.equal(n16.expectedTraceabilityGrade, "T1");
  const g95 = plan.records.find((record) => record.serialNumber === "G95");
  assert.equal(g95.sourceSerialText, "G 95");
  assert.equal(g95.expectedTraceabilityGrade, "T0");
});

test("rejects duplicate identity, bad prefix classification and future dates", async () => {
  const manifest = await loadManifest();
  const duplicate = structuredClone(manifest);
  duplicate.records[3].serialNumber = duplicate.records[0].serialNumber;
  assert.throws(() => buildPlan(duplicate), /Duplicate serial/);
  const badOrigin = structuredClone(manifest);
  badOrigin.records[0].declaredOrigin = "ownerDeclaredNew";
  assert.throws(() => buildPlan(badOrigin), /ownerDeclaredFabricated/);
  const future = structuredClone(manifest);
  future.records[0].incorporatedOn = "2026-08-23";
  assert.throws(() => buildPlan(future), /cannot be in the future/);
});
