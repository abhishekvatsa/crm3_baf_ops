"use strict";
// Real pinned auth/Client/prepare/hash/upload, behind a fake physical HTTPS wire.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path");
const driver = require("./testdata/business31CliDeployDriver.cjs");
const { CANARIES } = require("./testdata/business31CliCredentialWire.cjs");
let run;
test.before(() => { run = driver.createRun("credential-refresh"); }, { timeout: 120000 });
test.after(() => { if (run) driver.assertPopulationUnchanged(run); });
function retainedTraceFiles(report) {
  const files = fs.readdirSync(report.root).filter(name => /\.(json|bin)$/.test(name)).map(name => path.join(report.root, name));
  files.push(path.join(report.root, "source/scratch/events.jsonl"));
  const visit = directory => {
    for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
      const file = path.join(directory, item.name);
      if (item.isDirectory()) visit(file);
      else if (/\.log$/.test(item.name)) files.push(file);
    }
  };
  visit(path.join(report.root, "source/scratch"));
  return files;
}
function encodingsInTrace(bytes, canary) {
  const found = new Set(), text = bytes.toString("utf8").replaceAll('\\"', '"');
  if (bytes.includes(Buffer.from(canary))) found.add("plaintext");
  for (const match of text.matchAll(/"data"\s*:\s*\[([\d,\s]+)\]/g)) {
    const values = match[1].split(",").map(Number);
    if (values.every(value => Number.isInteger(value) && value >= 0 && value <= 255)
        && Buffer.from(values).includes(Buffer.from(canary))) found.add("buffer-byte-array");
  }
  for (const match of text.matchAll(/[A-Za-z0-9+/]{32,}={0,2}/g)) {
    if (Buffer.from(match[0], "base64").includes(Buffer.from(canary))) found.add("base64");
  }
  return [...found];
}
function assertNoSecretTraces(report) {
  const files = retainedTraceFiles(report);
  for (const file of files) {
    const bytes = fs.readFileSync(file);
    for (const canary of CANARIES) assert.deepEqual(encodingsInTrace(bytes, canary), [], "credential leaked in retained trace " + file);
  }
}
test("credential trace scanner detects plain, numeric Buffer and base64 encodings in memory", () => {
  const canary = CANARIES[3];
  assert.deepEqual(encodingsInTrace(Buffer.from(canary), canary), ["plaintext"]);
  assert.deepEqual(encodingsInTrace(Buffer.from(JSON.stringify({ body: Buffer.from(canary) })), canary), ["buffer-byte-array"]);
  assert.deepEqual(encodingsInTrace(Buffer.from(Buffer.from(canary).toString("base64")), canary), ["base64"]);
});
test("real pinned auth physical refresh failure retains no plain or encoded credential trace", { timeout: 650000 }, () => {
  const report = driver.runSample(run, "callables", "existing-fleet", "failed-refresh");
  const detail = "Retained offline auth-module evidence: " + report.root;
  assertNoSecretTraces(report);
  assert.equal(report.status, 1, detail); assert.equal(report.signal, null, detail); assert.equal(report.error, null, detail);
  assert.equal(report.parseError, null, detail); assert.equal(report.validEventSequence, true, detail);
  assert.equal(report.finalRecordIsLast, true, detail);
  assert.equal(report.final.sentinel, "BUSINESS31_OFFLINE_EXPECTED_REFRESH_FAILURE", detail);
  assert.equal(report.final.effectiveExitCode, 1, detail);
  assert.equal(report.final.prepareEntries, 0, detail); assert.equal(report.final.releaseEntries, 0, detail);
  assert.equal(report.final.cleanupComplete, true, detail); assert.equal(report.final.guardHealthy, true, detail);
  for (const field of ["errors", "denials", "unmatched", "guardRejections"]) assert.deepEqual(report.final[field], [], detail);
  assert.equal(report.events.filter(row => row.kind === "REAL_AUTH_MODULE_REFRESH_START").length, 1);
  assert.equal(report.events.filter(row => row.kind === "OFFLINE_CREDENTIAL_TRANSPORT").length, 1);
  assert.equal(report.events.some(row => row.kind === "REAL_CLI_ENTRY_START"), false);
  const debug = fs.readFileSync(path.join(report.root, "source/scratch/credential-debug.log"));
  assert(debug.includes(Buffer.from("Authentication Error: Your credentials are no longer valid.")), detail);
  driver.write(path.join(report.root, "CREDENTIAL_FAILURE_SCOPE.json"), {
    realAuthAndClientInvoked: true, realCliEntryInvoked: false, originalPrepareInvoked: false,
    physicalTransportFailed: true, traceFilterVerified: true, productionAuthority: false, networkForwarded: false
  });
});
for (const [phase, scenario] of [["callables", "expired"], ["callables", "refresh-margin"],
  ["events", "later-phase"], ["fleet", "later-phase"]]) {
  test("real CLI " + phase + " " + scenario + " refresh persists and sends the verified ZIP offline", { timeout: 650000 }, () => {
    const report = driver.runSample(run, phase, "existing-fleet", scenario);
    const detail = "Retained offline evidence: " + report.root;
    assertNoSecretTraces(report);
    assert.equal(report.status, 1, detail); assert.equal(report.signal, null, detail); assert.equal(report.error, null, detail);
    assert.equal(report.parseError, null, detail); assert.equal(report.validEventSequence, true, detail);
    assert.equal(report.finalRecordIsLast, true, detail);
    const final = report.final;
    assert.equal(final.effectiveExitCode, 1, detail);
    assert.equal(final.sentinel, "BUSINESS31_OFFLINE_RELEASE_ENTRY_STOP", detail);
    assert.equal(final.prepareEntries, 1, detail); assert.equal(final.originalPrepareEntries, 1, detail);
    assert.equal(final.originalPrepareCompleted, 1, detail); assert.equal(final.releaseEntries, 1, detail);
    assert.equal(final.guardHealthy, true, detail); assert.equal(final.cleanupComplete, true, detail);
    for (const field of ["errors", "denials", "unmatched", "guardRejections"]) assert.deepEqual(final[field], [], detail);
    for (const kind of ["ORIGINAL_HASH_AND_ZIP_VERIFIED", "ACTUAL_SIGNED_UPLOAD_BODY_VERIFIED", "REAL_REFRESH_PERSISTENCE_VERIFIED"]) {
      const rows = report.events.filter(row => row.kind === kind);
      assert.equal(rows.length, 1, detail); assert.equal(rows[0].phase, phase, detail);
    }
    const refresh = report.events.filter(row => row.kind === "OFFLINE_CREDENTIAL_TRANSPORT");
    assert.equal(refresh.length, 1, detail);
    assert.deepEqual(Object.keys(refresh[0]).sort(), ["sequence", "kind", "method", "host", "path", "status"].sort());
    assert.equal(refresh[0].path, "/oauth2/v3/token"); assert.equal(refresh[0].status, 200);
    const entry = report.events.find(row => row.kind === "PREPARE_ENTRY");
    assert.equal(refresh[0].sequence > entry.sequence, scenario === "later-phase", detail);
    assert.equal(report.events.filter(row => row.kind === "EXPECTED_STOP").length, 1, detail);
    assert.equal(report.events.filter(row => row.kind === "SYNTHETIC_NPM_ADVISORY" && row.externalCommandExecuted === false).length, 1, detail);
    assert.equal(final.controllerInvoked, false); assert.equal(final.deploymentAuthorized, false);
    assert.equal(final.networkForwarded, false);
  });
}
