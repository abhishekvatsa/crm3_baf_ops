const fs = require("node:fs");
const path = require("node:path");
const {spawnSync} = require("node:child_process");

const root = path.resolve(__dirname, "../..");
const policy = JSON.parse(fs.readFileSync(
  path.join(root, "release/function-fleet-runtime-identity-policy.json"), "utf8",
));

describe("explicit fleet instance limits", () => {
  test("all 19 real SDK exports retain cap20 and their governed identities", () => {
    const exported = require("../lib/index");
    const endpoints = Object.entries(exported)
      .filter(([, value]) => value?.__endpoint != null);
    expect(endpoints.map(([name]) => name).sort())
      .toEqual(Object.keys(policy.functionBindings).sort());
    expect(endpoints).toHaveLength(19);
    let callableCount = 0;
    let eventCount = 0;
    let scheduleCount = 0;
    for (const [name, endpoint] of endpoints) {
      // Exercise actual installed SDK output, not text matching of the source.
      expect(endpoint.__endpoint.maxInstances).toBe(20);
      expect(JSON.parse(JSON.stringify(endpoint.__endpoint)).maxInstances).toBe(20);
      expect(endpoint.__endpoint.platform).toBe("gcfv2");
      expect(endpoint.__endpoint.region).toEqual(["asia-south1"]);
      expect(endpoint.__endpoint.serviceAccountEmail.toCEL()).toBe(
        `${policy.functionBindings[name].runtimeServiceAccountId}` +
        "@{{ params.PROJECT_ID }}.iam.gserviceaccount.com",
      );
      if (endpoint.__endpoint.callableTrigger) {
        callableCount++;
        expect(endpoint.__trigger.maxInstances).toBe(20);
      }
      if (endpoint.__endpoint.eventTrigger) eventCount++;
      if (endpoint.__endpoint.scheduleTrigger) scheduleCount++;
    }
    expect([callableCount, eventCount, scheduleCount]).toEqual([13, 5, 1]);
  });

  test("omitting the option would restore the SDK reset, not preserve cap20", () => {
    const {onCall} = require("firebase-functions/v2/https");
    const omitted = onCall({region: "asia-south1"}, async () => {});
    const explicit = onCall({region: "asia-south1", maxInstances: 20}, async () => {});
    expect(omitted.__endpoint.maxInstances.toJSON()).toBeNull();
    expect(JSON.parse(JSON.stringify(omitted.__endpoint)).maxInstances).toBeNull();
    expect(explicit.__endpoint.maxInstances).toBe(20);
  });

  test("workflow exports also carry cap20 when loaded before the main module", () => {
    // A fresh process excludes accidental reliance on the entrypoint setting
    // SDK globals before these independently imported definitions are created.
    const result = spawnSync(process.execPath, ["-e", `
      const assert = require('node:assert/strict');
      const workflow = require('./lib/maintenanceWorkflow/firebaseExports');
      assert.equal(Object.keys(workflow).length, 4);
      for (const endpoint of Object.values(workflow)) {
        assert.equal(endpoint.__endpoint.maxInstances, 20);
      }
      const main = require('./lib/index');
      assert.equal(Object.keys(main).length, 19);
      for (const endpoint of Object.values(main)) {
        assert.equal(endpoint.__endpoint.maxInstances, 20);
      }
    `], {cwd: path.join(root, "functions"), encoding: "utf8", timeout: 15000});
    expect({status: result.status, stderr: result.stderr})
      .toEqual({status: 0, stderr: ""});
  });
});
