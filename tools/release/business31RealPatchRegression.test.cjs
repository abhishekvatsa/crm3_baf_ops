"use strict";
// Real saved SDK/CLI inputs from the failed 5 November attempt and the sole
// preserve-only experiment. This suite never imports the CLI or opens transport.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const guardApi = require("./runtimeDeploymentTransportGuard31.cjs");
const {helpers} = require("./backendRuntimeAdmission31.cjs");
const {preserveFunctionRequest31} = require("./business31PreservedControls31.cjs");

const hash = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const SOURCE = "49cd181eed60010cc6438ef8a9b769bdde62c4b4";
const PREFIX = "projects/crm3-baf-ops-b8638/locations/asia-south1/functions/";
const FIXTURES = {
  original: {
    file: "business31RealPatchOriginal.json",
    sha256: "9BB8EEE2F5AC7A330D7595FE355EDA1CB169FD6F7D7DD104F7DF28AAFE60A0F1",
    recorded: "74BA730A8DE7CC041CB705E9A79C8278A1E8D68CBC0B9E550DE7BDC80FD7C549",
    manifest: "51AD5B3D0923753F089AEC7FC1D0A45438A48056FFDEFE2B406D3CCE1240975D",
  },
  "preserve-only": {
    file: "business31RealPatchPreserve.json",
    sha256: "9EF4DCF8AA2E96358423FF03146DD53C1AB54E094214FC9067B191CA013C6DE3",
    recorded: "C497C22EC1BF6B9495E803432632D712FDFA9BB261E564367A607D3A6B1DE19C",
    manifest: "BC642BE51C6CE71F5E487921074CF036A3EF019435C7DFA9F1473092FD71E160",
  },
};
const policy = JSON.parse(fs.readFileSync(path.join(__dirname, "../../release/function-fleet-runtime-identity-policy.json")));
const names = Object.keys(policy.functionBindings).sort();
assert.equal(names.length, 19);
const original = loadFixture("original"), preserved = loadFixture("preserve-only");
const client = {opts: {urlPrefix: "https://cloudfunctions.googleapis.com", apiVersion: "v2"}};

function loadFixture(variant) {
  const selected = FIXTURES[variant], raw = fs.readFileSync(path.join(__dirname, "testdata", selected.file));
  assert.equal(hash(raw), selected.sha256, "Published real-data fixture bytes changed");
  const value = JSON.parse(raw);
  validateFixture(value, variant);
  return value;
}
function validateFixture(value, variant) {
  const selected = FIXTURES[variant];
  assert.equal(value.schemaVersion, 1);
  assert.equal(value.kind, "build31-real-manifest-patch-regression");
  assert.equal(value.variant, variant);
  assert.equal(value.source.commit, SOURCE);
  assert.equal(value.provenance.recordedFixture.sha256, selected.recorded);
  assert.equal(value.provenance.manifestSha256, selected.manifest);
  assert.equal(hash(Buffer.from(JSON.stringify(value.manifest, null, 2) + "\n")), selected.manifest);
  assert.equal(value.provenance.cliVersion, "15.22.4");
  assert.equal(value.provenance.sdkVersion, "7.2.5");
  assert.deepEqual(Object.keys(value.manifest.endpoints).sort(), names);
  assert.deepEqual(value.requestRows.map(row => row.function).sort(), names);
  assert.deepEqual(value.liveFunctions.map(row => row.name.slice(PREFIX.length)).sort(), names);
  assert(value.liveFunctions.every(row => row.name.startsWith(PREFIX)));
  assert.equal(hash(Buffer.from(JSON.stringify(value.liveFunctions))), "F347CCADE71F00CC554DA477F59DCEE9D4D30FBC923B47E9BC298CC7C9BD8654");
  assert.deepEqual(Object.keys(value.prepared.endpointRuntimeHashes).sort(), names);
  assert.deepEqual(value.parameters, {CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK: "false"});
  for (const row of value.requestRows) {
    assert.equal(row.method, "PATCH");
    assert.equal(row.host, "cloudfunctions.googleapis.com");
    assert.equal(row.path, "/v2/" + PREFIX + row.function);
    assert.equal(row.body.name, PREFIX + row.function);
    assert.deepEqual(row.undefinedOwnLeaves, ["buildConfig.sourceToken"]);
    assert.equal(hash(Buffer.from(JSON.stringify(row.body))), row.wireBodySha256);
    assert.equal(row.body.labels["firebase-functions-hash"], value.prepared.endpointRuntimeHashes[row.function]);
    assert.deepEqual(row.body.buildConfig.source.storageSource, value.sourceSelector);
    assert.equal(new Set(row.updateMask.split(",")).size, row.updateMask.split(",").length);
  }
  assert.equal(value.provenance.retainedInputs.find(row => row.role === "after4").sha256,
    "FCBBE7AFF58C02189E8D72DA8D4EA9C01C2E2B649FC3BC95BC286BCA837CB9B1");
  if (variant === "preserve-only") {
    const generation = value.provenance.preserveOnlyGeneration;
    assert.equal(generation.manifestSha256, selected.manifest);
    assert.equal(generation.sourceInsertion,
      'import {setGlobalOptions} from "firebase-functions/v2";\nsetGlobalOptions({preserveExternalChanges:true});\n');
    assert.equal(generation.baselineExecutableJsMatch, true);
    assert.equal(generation.compilerVersion, "5.9.3");
  }
}
function baseline(fixture) {
  return Object.fromEntries(fixture.liveFunctions.map(value => [value.name.slice(PREFIX.length), structuredClone(value)]));
}
function requestOf(row) {
  const body = structuredClone(row.body);
  // JSON omits own undefined values, but the real CLI includes this property
  // while constructing updateMask. Preserve that distinction in every replay.
  assert.deepEqual(row.undefinedOwnLeaves, ["buildConfig.sourceToken"]);
  assert(!Object.hasOwn(body.buildConfig, "sourceToken"));
  body.buildConfig.sourceToken = undefined;
  assert.equal(hash(Buffer.from(JSON.stringify(body))), row.wireBodySha256);
  return {method: row.method, path: row.path.slice("/v2/".length), body, queryParams: {updateMask: row.updateMask}};
}
function freshGuard(fixture, selectedNames = names) {
  const guard = new guardApi.RuntimeDeploymentTransportGuard31({
    names: selectedNames, allNames: names, baselineFunctions: baseline(fixture),
    baselineScheduler: {}, ...fixture.prepared, phase: "offline-real-fixture", projectNumber: "894346496105",
  });
  guard.preparedMatches(fixture.prepared);
  guard.sourceLocations.push(structuredClone(fixture.sourceSelector));
  return guard;
}

// Use the production guard's exact comparison block and equality function.
// The observer collects each thrown equality failure instead of stopping at
// the first; guard.before below independently exercises the unmodified boundary.
const guardSource = fs.readFileSync(path.join(__dirname, "runtimeDeploymentTransportGuard31.cjs"), "utf8").replace(/\r\n/g, "\n");
const loopStart = guardSource.indexOf("      const changed=new Set(['buildConfig.source.storageSource.bucket'");
const loopEnd = guardSource.indexOf("      this.mutations.add(name);return", loopStart);
assert(loopStart > 0 && loopEnd > loopStart);
const comparisonSource = guardSource.slice(loopStart, loopEnd);
assert.equal(hash(Buffer.from(comparisonSource)), "70DF8B4C4CFBF383D5CABA1435D336CCD15EA688C8EBC9B0380B74BFB6211ACE");
const compare = new Function("proposed", "before", "request", "leaves", "at", "eq", "need", comparisonSource);
const at = (value, field) => field.split(".").reduce((current, key) => current?.[key], value);
const present = value => value === undefined ? {presence: "undefined"} : {presence: "value", value};
function mismatches(request, before, functionName) {
  const result = [];
  const observe = (proposed, live, message) => {
    try { helpers.eq(proposed, live, message); }
    catch { result.push({function: functionName, message, proposed: present(proposed), live: present(live)}); }
  };
  compare(request.body, before, request, guardApi.leaves, at, observe, helpers.need);
  return result;
}
function allMismatches(fixture) {
  const live = baseline(fixture);
  return fixture.requestRows.flatMap(row => mismatches(requestOf(row), live[row.function], row.function));
}
function mismatchKey(row) { return JSON.stringify(row); }
function countByField(rows) {
  return rows.reduce((counts, row) => {
    const field = row.message.split(": ").slice(1).join(": ");
    counts[field] = (counts[field] ?? 0) + 1;
    return counts;
  }, {});
}
function effectiveRequest(row, fixture = preserved) {
  const request = requestOf(row);
  const result = preserveFunctionRequest31({client, request, names, baselineFunctions: baseline(fixture)});
  assert(result && result.request, "Real Function request must use the preservation path");
  return {original: request, ...result};
}

test("real fixture provenance retains the exact 19-Function SDK manifests and read-4 baseline", () => {
  assert.deepEqual(original.source, preserved.source);
  assert.deepEqual(original.liveFunctions, preserved.liveFunctions);
  assert.deepEqual(original.prepared, preserved.prepared);
  assert.deepEqual(original.parameters, preserved.parameters);
  assert.equal(Object.values(original.manifest.endpoints).filter(row => row.callableTrigger).length, 13);
  assert.equal(Object.values(original.manifest.endpoints).filter(row => row.eventTrigger).length, 5);
  assert.equal(Object.values(original.manifest.endpoints).filter(row => row.scheduleTrigger).length, 1);
  let removals = 0;
  const removedFields = {};
  const expected = structuredClone(original.manifest);
  for (const [name, endpoint] of Object.entries(expected.endpoints)) {
    for (const key of Object.keys(endpoint)) {
      if (!Object.hasOwn(preserved.manifest.endpoints[name], key)) {
        assert.equal(endpoint[key], null, "Only actual reset nulls disappeared");
        removedFields[key] = (removedFields[key] ?? 0) + 1;
        delete endpoint[key]; removals++;
      }
    }
  }
  assert.equal(removals, 73);
  assert.deepEqual(removedFields, {ingressSettings: 19, minInstances: 19, vpc: 19, availableMemoryMb: 5, timeoutSeconds: 5, concurrency: 6});
  assert.deepEqual(expected, preserved.manifest, "No additional manifest mutation is hidden by the projection");
});

test("unchanged guard exposes all 251 original comparisons, with ingress first for every real Function", () => {
  const failures = allMismatches(original);
  assert.equal(failures.length, 251);
  assert.equal(failures.filter(row => row.message.startsWith("Unapproved")).length, 120);
  assert.equal(failures.filter(row => row.message.startsWith("Update mask")).length, 131);
  assert.deepEqual(countByField(failures), {
    "serviceConfig.ingressSettings": 38,
    "serviceConfig.minInstanceCount": 38,
    "serviceConfig.vpcConnector": 38,
    "serviceConfig.vpcConnectorEgressSettings": 38,
    "serviceConfig.directVpcNetworkInterface": 38,
    "serviceConfig.directVpcEgress": 38,
    "serviceConfig.environmentVariables": 11,
    "serviceConfig.timeoutSeconds": 10,
    "eventTrigger.eventFilters": 2,
  });
  for (const row of original.requestRows) {
    assert.equal(row.expectedFirstRefusal, "Unapproved Function control mutation: serviceConfig.ingressSettings");
    assert.throws(() => freshGuard(original).before(client, requestOf(row)), {message: row.expectedFirstRefusal});
  }
});

test("real preserve-only fixture removes 238 comparisons, retains 13, and adds none", () => {
  const before = allMismatches(original), after = allMismatches(preserved);
  const oldSet = new Set(before.map(mismatchKey)), newSet = new Set(after.map(mismatchKey));
  assert.equal(after.length, 13);
  assert.equal(before.filter(row => !newSet.has(mismatchKey(row))).length, 238);
  assert.equal(after.filter(row => !oldSet.has(mismatchKey(row))).length, 0);
  assert.deepEqual(countByField(after), {"serviceConfig.environmentVariables": 11, "eventTrigger.eventFilters": 2});
  let admitted = 0, refused = 0;
  for (const row of preserved.requestRows) {
    if (row.expectedFirstRefusal === null) {
      assert.equal(freshGuard(preserved).before(client, requestOf(row)).kind, "function-update"); admitted++;
    } else {
      assert.throws(() => freshGuard(preserved).before(client, requestOf(row)), {message: row.expectedFirstRefusal}); refused++;
    }
  }
  assert.equal(admitted, 7); assert.equal(refused, 12);
});

test("complete preservation reaches zero leaf/mask differences and all 76 resource values match live", () => {
  const live = baseline(preserved);
  let resourceValues = 0, environmentRestorations = 0, filterReorders = 0;
  for (const row of preserved.requestRows) {
    const {original: request, request: effective} = effectiveRequest(row);
    assert.deepEqual(mismatches(effective, live[row.function], row.function), []);
    assert.equal(freshGuard(preserved).before(client, effective).kind, "function-update");
    assert.equal(hash(Buffer.from(JSON.stringify(request.body))), row.wireBodySha256, "Original candidate remains unchanged");
    assert.deepEqual(effective.queryParams, request.queryParams, "Preservation cannot modify updateMask");
    const expected = structuredClone(request.body);
    const missingSignature = !Object.hasOwn(expected.serviceConfig.environmentVariables, "FUNCTION_SIGNATURE_TYPE") &&
      live[row.function].serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE === "http";
    if (missingSignature) {
      expected.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE = "http"; environmentRestorations++;
    }
    if (expected.eventTrigger && !require("node:util").isDeepStrictEqual(expected.eventTrigger.eventFilters, live[row.function].eventTrigger.eventFilters)) {
      expected.eventTrigger.eventFilters = structuredClone(live[row.function].eventTrigger.eventFilters); filterReorders++;
    }
    assert.deepEqual(effective.body, expected, "No other effective body change is admitted");
    for (const field of ["availableMemory", "availableCpu", "maxInstanceRequestConcurrency", "timeoutSeconds"]) {
      assert.deepEqual(effective.body.serviceConfig[field], live[row.function].serviceConfig[field], row.function + ": " + field);
      resourceValues++;
    }
  }
  assert.equal(resourceValues, 76);
  assert.equal(environmentRestorations, 11);
  assert.equal(filterReorders, 1);
});

test("preservation alone cannot make the original reset-null fixture pass the strict guard", () => {
  for (const row of original.requestRows) {
    assert.throws(() => {
      const {request} = effectiveRequest(row, original);
      return freshGuard(original).before(client, request);
    });
  }
});

for (const [label, change] of [
  ["one missing request", value => value.requestRows.pop()],
  ["one duplicated request", value => value.requestRows[0] = structuredClone(value.requestRows[1])],
  ["substituted live definition", value => value.liveFunctions[0].serviceConfig.ingressSettings = "ALLOW_INTERNAL_ONLY"],
  ["invented manifest", value => value.manifest.endpoints[Object.keys(value.manifest.endpoints)[0]].minInstances = 0],
  ["wrong retained baseline", value => value.provenance.retainedInputs.find(row => row.role === "after4").sha256 = "0".repeat(64)],
  ["lost own undefined property", value => value.requestRows[0].undefinedOwnLeaves = []],
  ["wrong wire-body binding", value => value.requestRows[0].wireBodySha256 = "0".repeat(64)],
]) test("real fixture admission rejects " + label, () => {
  const value = structuredClone(preserved); change(value);
  assert.throws(() => validateFixture(value, "preserve-only"));
});

for (const [label, functionName, change] of [
  ["wrong HTTP signature", "assignPublishedTemplateVersion", request => {request.body.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE = "cloudevent";}],
  ["unrelated environment addition", "assignPublishedTemplateVersion", request => {request.body.serviceConfig.environmentVariables.UNREVIEWED = "value";}],
  ["unrelated environment removal", "assignPublishedTemplateVersion", request => {delete request.body.serviceConfig.environmentVariables.FUNCTION_TARGET;}],
  ["changed filter", "onTicketResolved", request => {request.body.eventTrigger.eventFilters[0].value = "other";}],
  ["duplicate filter", "onTicketResolved", request => {request.body.eventTrigger.eventFilters[0] = structuredClone(request.body.eventTrigger.eventFilters[1]);}],
  ["removed filter", "onTicketResolved", request => {request.body.eventTrigger.eventFilters.pop();}],
  ["nondefault ingress mutation", "beginGlobalPullRun", request => {request.body.serviceConfig.ingressSettings = "ALLOW_INTERNAL_ONLY";}],
  ["minimum-instance mutation", "beginGlobalPullRun", request => {request.body.serviceConfig.minInstanceCount = 1;}],
  ["unapproved source selector", "beginGlobalPullRun", request => {request.body.buildConfig.source.storageSource.object += ".other";}],
  ["wrong endpoint hash", "beginGlobalPullRun", request => {request.body.labels["firebase-functions-hash"] = "0".repeat(40);}],
  ["wrong Function identity", "beginGlobalPullRun", request => {request.body.name = PREFIX + "different";}],
  ["wildcard mask", "beginGlobalPullRun", request => {request.queryParams.updateMask = "*";}],
]) test("complete real-fixture path still refuses " + label, () => {
  const row = preserved.requestRows.find(value => value.function === functionName), request = requestOf(row);
  change(request);
  assert.throws(() => {
    const result = preserveFunctionRequest31({client, request, names, baselineFunctions: baseline(preserved)});
    assert(result?.request);
    return freshGuard(preserved).before(client, result.request);
  });
});
