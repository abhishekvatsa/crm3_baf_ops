"use strict";
const fs = require("fs");
const path = require("path");
const uv = require("./fixtures/uvDetectorLifecycleFixture");
const {prepareBurnerBlockLifecycleWritePlan, applyBurnerBlockLifecycleWritePlan} =
  require("../lib/maintenanceWorkflow/burnerBlockLifecycle");

// Actual producer output shared with both Dart history/current readers.
test("late-recorded lifecycle producer fixture remains exact for Flutter readers", async () => {
  const times = {
    completedAt: "2026-08-28T09:00:00.000Z",
    recordedAt: "2026-08-28T14:00:00.000Z",
  };
  const uvPlan = await uv.prepare(uv.seedStore(), uv.action(), times);
  const store = uv.seedStore();
  const ref = {...uv.reference(), nodeId: "node-burner-block",
    nodeName: "Burner blocks and firing tubes", ownerDiscipline: "RED",
    accountableRoleKeys: ["seniorRefractory"],
    hierarchyPath: ["Furnace", "Refractory system", "Burner blocks and firing tubes"]};
  store.seed(`asset_hierarchy_nodes/${ref.nodeId}`, {
    schemaVersion: 1, nodeId: ref.nodeId, assetClassId: ref.assetClassId,
    name: ref.nodeName, hierarchyPath: ref.hierarchyPath,
    nodeType: "component", componentTag: null, status: "active", version: 3,
  });
  const row = uv.action({id: "action-block-1", component: ref.nodeName,
    hierarchyPath: ref.hierarchyPath, assetHierarchyRef: ref,
    system: "Furnace", subsystem: "Refractory system",
    burnerBlockSupplyMode: "sailRed", performedBy: "Mechanical Technician One"});
  const burnerPlan = await store.runTransaction(async tx => {
    const plan = await prepareBurnerBlockLifecycleWritePlan({
      tx, sourceType: "workflowPlannedJob", sourceId: "execution-1",
      assetType: "furnace", assetNumber: 7, completedBy: uv.actor, ...times,
      actionSources: [{sourceModuleId: "module-1", discipline: "mechanical",
        actionsJson: JSON.stringify([row])}],
    });
    applyBurnerBlockLifecycleWritePlan(tx, plan);
    return plan;
  });
  expect(uvPlan.events).toHaveLength(1);
  expect(uvPlan.currentStates).toHaveLength(1);
  expect(burnerPlan.events).toHaveLength(1);
  expect(burnerPlan.currentStates).toHaveLength(1);
  const produced = JSON.parse(JSON.stringify({
    uvEvent: uvPlan.events[0], uvCurrent: uvPlan.currentStates[0],
    burnerEvent: burnerPlan.events[0], burnerCurrent: burnerPlan.currentStates[0],
  }));
  const fixture = path.join(__dirname, "fixtures/lifecycle_late_recording_actual_producer.json");
  if (process.env.UPDATE_LATE_LIFECYCLE_FIXTURE === "1") {
    fs.writeFileSync(fixture, `${JSON.stringify(produced, null, 2)}\n`);
  }
  expect(produced).toEqual(JSON.parse(fs.readFileSync(fixture, "utf8")));
});
