"use strict";
// These assertions cover two read-selection branches, not controller admission or a successful deployment rehearsal.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path");
const driver = require("./testdata/business31CliDeployDriver.cjs");
let run;
test.before(() => { run = driver.createRun("pre-release"); });
test.after(() => { if (run) driver.assertPopulationUnchanged(run); });
const computeRead = request => request.urlPrefix === "https://compute.googleapis.com";
const numericIamRead = request => request.urlPrefix === "https://cloudresourcemanager.googleapis.com"
  && request.apiVersion === "v1" && request.method === "POST"
  && request.path.replace(/^\//, "") === "projects/123456789:getIamPolicy";
function sample(phase, variant = "existing-fleet") {
  const report = driver.runSample(run, phase, variant), message = "Retained scoped read-branch sample: " + report.root;
  assert.equal(report.error, null, message); assert.equal(report.signal, null, message); assert.equal(report.status, 1, message);
  assert.equal(report.parseError, null, message); assert.equal(report.validEventSequence, true, message);
  assert.equal(report.finalRecordIsLast, true, message); assert.equal(report.final.effectiveExitCode, 1, message);
  assert.equal(report.final.originalPrepareEntries, 1, message);
  assert.equal(report.final.originalPrepareCompleted, 1, message);
  assert.equal(report.final.releaseEntries, 0, message); assert.equal(report.final.guardHealthy, true, message);
  assert.equal(report.final.cleanupComplete, true, message); assert.deepEqual(report.final.unmatched, [], message);
  assert.deepEqual(report.final.errors, [], message);
  // The unchanged pre-comparison upload refusal must still stop every sample.
  assert(report.final.guardRejections.some(row => row.message.includes("No cloud write before exact prepared-input comparison")
    && row.request.path.endsWith("/functions:generateUploadUrl")), message);
  const entry = report.events.filter(row => row.kind === "PREPARE_ENTRY");
  assert.equal(entry.length, 1, message);
  const names = phase === "fleet" ? run.cohorts.schedulers : run.cohorts[phase];
  assert.deepEqual(entry[0].names, names, message);
  assert.equal(entry[0].only, names.map(name => "functions:" + name).join(","), message);
  const completed = report.events.filter(row => row.kind === "ORIGINAL_PREPARE_COMPLETED");
  assert.equal(completed.length, 1, message); assert.equal(completed[0].fleetVariant, variant, message);
  const selection = JSON.parse(fs.readFileSync(path.join(report.root, "source/CASE.json"), "utf8"));
  driver.write(path.join(report.root, "READ_BRANCH_SCOPE.json"), {
    scope: "Synthetic fleet read-selection only; all other denials remain failures in the full rehearsal.",
    variant, originalPrepareCompleted: 1, releaseEntries: 0, fullRehearsalPassed: false,
    guardRejections: report.final.guardRejections, denials: report.final.denials, errors: report.final.errors });
  return { report, selection, completed: completed[0],
    attempts: report.events.filter(row => row.kind === "GUARDED_API_REQUEST_ATTEMPT").map(row => row.request) };
}
for (const phase of driver.PHASES) test("real CLI " + phase + " existing-fleet fixture avoids Compute and numeric IAM reads; upload remains refused", () => {
  const { report, selection, completed, attempts } = sample(phase);
  assert(attempts.length > 0);
  assert.equal(attempts.filter(computeRead).length, 0);
  assert.equal(attempts.filter(numericIamRead).length, 0);
  assert.equal(selection.fleet.existingFunctions.length, 19);
  const want = completed.backends.flatMap(row => row.want), have = completed.backends.flatMap(row => row.have);
  assert.equal(want.length, 19); assert.equal(have.length, 19);
  for (const name of run.cohorts.fleet) {
    const declared = selection.fleet.manifest.endpoints[name];
    for (const rows of [want, have]) {
      const endpoint = rows.find(row => row.id === name); assert(endpoint);
      assert.equal(endpoint.serviceAccount, declared.serviceAccount);
      assert.equal(endpoint.eventType, declared.eventTrigger?.eventType ?? null);
      assert.deepEqual(endpoint.secretEnvironmentVariables, []);
    }
  }
  assert.equal(report.final.guardRejections.filter(row => computeRead(row.request) || numericIamRead(row.request)).length, 0);
});
test("missing wanted runtime SA exercises the real default-Compute lookup and retains its strict refusal", () => {
  const { report, selection, attempts } = sample("callables", "missing-runtime-sa");
  assert.equal(Object.hasOwn(selection.fleet.manifest.endpoints.getBackendReleaseIdentity, "serviceAccount"), false);
  assert(attempts.some(computeRead));
  assert(report.final.guardRejections.some(row => computeRead(row.request) && row.message.includes("Unreviewed API host")));
});
test("absent existing event service exercises real numeric-project IAM lookup and retains its strict refusal", () => {
  const { report, selection, attempts } = sample("events", "no-existing-event-service");
  assert.equal(selection.fleet.existingFunctions.length, 14);
  assert(run.cohorts.events.every(name => selection.fleet.manifest.endpoints[name].eventTrigger.retry === false));
  assert(attempts.some(computeRead)); assert(attempts.some(numericIamRead));
  assert(report.final.guardRejections.some(row => computeRead(row.request) && row.message.includes("Unreviewed API host")));
  assert(report.final.guardRejections.some(row => numericIamRead(row.request) && row.message.includes("Read-only method required")));
});
