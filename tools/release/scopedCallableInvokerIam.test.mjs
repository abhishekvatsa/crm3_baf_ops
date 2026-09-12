import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import guard from "./scopedCallableInvokerIam.js";
import collector from "./collectScopedCallableInvokerIam.js";
import seals from "./collectProductionGlobalPullBackend.js";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const sourceCommit = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "HEAD"], {encoding: "utf8"}).trim();
const policy = JSON.parse(execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "show", `${sourceCommit}:release/function-fleet-runtime-identity-policy.json`], {encoding: "utf8"}));
const {PROJECT: project, REGION: region, NEW_FUNCTIONS: additions} = guard;
const service = (name, location = region) => `projects/${project}/locations/${location}/services/${name.toLowerCase()}`;
const account = (name) => `${policy.functionBindings[name].runtimeServiceAccountId}@${project}.iam.gserviceaccount.com`;
const approval = {approved: true, firebaseProjectId: project, region, sourceAuthority: {commit: sourceCommit},
  approvedDeployment: {preserveExistingIamRequired: true, existingDedicatedServiceAccountsRequired: true,
    appCheckEnforcement: false, newCallableInvokerPolicies: additions.map((functionName) => ({functionName,
      serviceResource: service(functionName), role: "roles/run.invoker", members: ["allUsers"]}))}};
const context = {repoRoot, approval, approvalSha256: guard.hash(JSON.stringify(approval)), sourceCommit};
const response = (url, value, method = "GET", httpStatus = 200) => ({url, method, httpStatus, bodyText: JSON.stringify(value)});
const onePage = (url, field, values) => [response(`${url}?pageSize=100`, {[field]: values})];
const publicPolicy = () => ({etag: "original-transport", version: 3, bindings: [{role: "roles/run.invoker", members: ["allUsers"]}]});
const changeBody = (row, change) => { const value = JSON.parse(row.bodyText); change(value); row.bodyText = JSON.stringify(value); };
function fixture(phase) {
  const names = Object.keys(policy.functionBindings).filter((name) => phase === "after" || !additions.includes(name));
  const emails = [...new Set(Object.keys(policy.functionBindings).map(account))];
  const functions = names.map((name) => ({name: `projects/${project}/locations/${region}/functions/${name}`,
    serviceConfig: {service: service(name), serviceAccountEmail: account(name)}}));
  const runServices = names.map((name) => ({name: service(name), uid: `uid-${name}`}));
  const unrelated = {name: service("unrelated-run", "us-central1"), uid: "unrelated-uid"};
  return {schemaVersion: 1, projectId: project, region, sourceCommit, approvalSha256: context.approvalSha256,
    startedAtUtc: `2026-09-13T0${phase === "before" ? 1 : 2}:00:00.000Z`,
    completedAtUtc: `2026-09-13T0${phase === "before" ? 1 : 2}:00:01.000Z`,
    project: response(`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`, {projectId: project, projectNumber: "123456789"}),
    functions: onePage(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/-/functions`, "functions", functions),
    runLocations: onePage(`https://run.googleapis.com/v1/projects/${project}/locations`, "locations", [{locationId: region}, {locationId: "us-central1"}]),
    runInventories: [{location: region, pages: onePage(`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services`, "services", runServices)},
      {location: "us-central1", pages: onePage(`https://run.googleapis.com/v2/projects/${project}/locations/us-central1/services`, "services", [unrelated])}],
    runIam: [...runServices, unrelated].map((row) => ({resource: row.name,
      response: response(`https://run.googleapis.com/v2/${row.name}:getIamPolicy?options.requestedPolicyVersion=3`, publicPolicy())})),
    accounts: onePage(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts`, "accounts", emails.map((email, index) => ({email, projectId: project, uniqueId: String(index + 100)}))),
    accountIam: emails.map((email) => ({email, response: response(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${email}:getIamPolicy?options.requestedPolicyVersion=3`, {etag: "account-etag"}, "POST")})),
    projectIam: response(`https://cloudresourcemanager.googleapis.com/v1/projects/${project}:getIamPolicy`, {version: 3, etag: "project-etag", bindings: [{role: "roles/viewer", members: ["group:operators@example.invalid"], condition: {title: "condition", expression: "true"}}], auditConfigs: [{service: "allServices", auditLogConfigs: [{logType: "ADMIN_READ"}]}]}, "POST"),
    absence: phase === "before" ? additions.map((functionName) => ({functionName, serviceResource: service(functionName),
      functionDescribe: response(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/${region}/functions/${functionName}`, {error: {code: 404, status: "NOT_FOUND"}}, "GET", 404),
      serviceDescribe: response(`https://run.googleapis.com/v2/${service(functionName)}`, {error: {code: 404, status: "NOT_FOUND"}}, "GET", 404)})) : []};
}
const capture = (phase, raw = fixture(phase), ctx = context) => guard.createCapture(ctx, raw, phase);

function restrictedRegion(raw) {
  const location = "me-central2";
  changeBody(raw.runLocations[0], (body) => body.locations.push({locationId: location}));
  const unavailable = response(`https://run.googleapis.com/v2/projects/${project}/locations/${location}/services?pageSize=100`, {
    error: {code: 403, status: "PERMISSION_DENIED", message: "Region access is unavailable.", details: [
      {"@type": "type.googleapis.com/google.rpc.ErrorInfo", reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com",
        metadata: {location, consumer: "projects/123456789", service: ""}},
      {"@type": "type.googleapis.com/google.rpc.Help", links: [{description: "Contact sales for region access."}]},
    ]},
  }, "GET", 403);
  raw.runInventories.push({location, unavailable});
  return raw;
}

function transport(raw, visited = new Set()) {
  const responses = new Map();
  const walk = (value) => { if (value?.url) responses.set(value.url, value);
    else if (value && typeof value === "object") Object.values(value).forEach(walk); };
  walk(raw);
  return async (url, method = "GET") => {
    const measured = responses.get(url); assert.ok(measured, `unexpected read: ${url}`);
    assert.equal(method, measured.method); visited.add(url); return measured;
  };
}

test("collector preserves the specific unavailable region as unknown, with identical before/after scope", async () => {
  const captures = [];
  for (const phase of ["before", "after"]) {
    const raw = restrictedRegion(fixture(phase)); const visited = new Set();
    const collected = await collector.collect(context, phase, transport(raw, visited));
    assert.deepEqual(collected.raw.runInventories.at(-1), raw.runInventories.at(-1));
    assert.equal(Object.hasOwn(collected.raw.runInventories.at(-1), "pages"), false);
    assert.equal(visited.has(raw.projectIam.url), true);
    assert.equal(visited.has(raw.accountIam.at(-1).response.url), true);
    assert.equal(visited.has(raw.runIam.at(-1).response.url), true);
    assert.deepEqual(collected.measurement.unavailableRunRegions, [{location: "me-central2", reason: "LOCATION_POLICY_VIOLATED",
      domain: "googleapis.com", consumer: "projects/123456789"}]);
    collected.raw.startedAtUtc = raw.startedAtUtc; collected.raw.completedAtUtc = raw.completedAtUtc;
    captures.push(capture(phase, collected.raw));
  }
  const proof = guard.createProof(context, ...captures);
  assert.equal(guard.validateProof({...context, proof}).ok, true);
  assert.match(proof.qualification, /coverage excludes me-central2/);
  assert.match(proof.qualification, /no absence or unchanged IAM is claimed/);
  assert.equal(proof.newServiceResources.length, 4);
  assert.deepEqual(proof.before.raw.runInventories.at(-1), captures[0].raw.runInventories.at(-1));
  assert.equal(Object.hasOwn(capture("before").measurement, "unavailableRunRegions"), false);
});

for (const [label, mutate] of [
  ["generic permission denial", (row) => changeBody(row.unavailable, (v) => { v.error.details = []; })],
  ["other reason", (row) => changeBody(row.unavailable, (v) => { v.error.details[0].reason = "IAM_PERMISSION_DENIED"; })],
  ["other domain", (row) => changeBody(row.unavailable, (v) => { v.error.details[0].domain = "other.googleapis.com"; })],
  ["other project", (row) => changeBody(row.unavailable, (v) => { v.error.details[0].metadata.consumer = "projects/999"; })],
  ["other location metadata", (row) => changeBody(row.unavailable, (v) => { v.error.details[0].metadata.location = "us-central1"; })],
  ["other service metadata", (row) => changeBody(row.unavailable, (v) => { v.error.details[0].metadata.service = "iam.googleapis.com"; })],
  ["ambiguous error reasons", (row) => changeBody(row.unavailable, (v) => { v.error.details.push({...v.error.details[0], reason: "IAM_PERMISSION_DENIED"}); })],
  ["404 is not restricted access", (row) => { row.unavailable.httpStatus = 404; }],
  ["mismatched error status", (row) => changeBody(row.unavailable, (v) => { v.error.status = "NOT_FOUND"; })],
  ["malformed body", (row) => { row.unavailable.bodyText = "{"; }],
  ["second-page refusal", (row) => { row.unavailable.url += "&pageToken=next"; }],
  ["different method", (row) => { row.unavailable.method = "POST"; }],
  ["pages plus exclusion", (row) => { row.pages = []; }],
  ["target region", (row, raw) => {
    row.location = region; row.unavailable.url = row.unavailable.url.replace("me-central2", region);
    changeBody(row.unavailable, (v) => { v.error.details[0].metadata.location = region; });
    raw.runInventories.splice(0, 1);
    changeBody(raw.runLocations[0], (v) => { v.locations = v.locations.filter((entry) => entry.locationId !== "me-central2"); });
  }],
  ["unreviewed non-target region", (row, raw) => {
    row.location = "me-central1"; row.unavailable.url = row.unavailable.url.replace("me-central2", "me-central1");
    changeBody(row.unavailable, (v) => { v.error.details[0].metadata.location = "me-central1"; });
    changeBody(raw.runLocations[0], (v) => { v.locations.at(-1).locationId = "me-central1"; });
  }],
]) test(`unavailable-region evidence refuses ${label}`, () => {
  const raw = restrictedRegion(fixture("before")); mutate(raw.runInventories.at(-1), raw);
  assert.throws(() => capture("before", raw), /Scoped invoker IAM/);
});

test("collector refuses general403 and a restricted403 after a successful first page", async () => {
  const denied = restrictedRegion(fixture("before"));
  changeBody(denied.runInventories.at(-1).unavailable, (v) => { v.error.details[0].reason = "IAM_PERMISSION_DENIED"; });
  await assert.rejects(collector.collect(context, "before", transport(denied)), /reason/);
  const partial = restrictedRegion(fixture("before")); const row = partial.runInventories.at(-1);
  const url = row.unavailable.url;
  row.unavailable.url += "&pageToken=next";
  row.pages = [response(url, {services: [], nextPageToken: "next"}), row.unavailable]; delete row.unavailable;
  await assert.rejects(collector.collect(context, "before", transport(partial)), /Cannot enumerate services: HTTP 403/);
});

test("a region becoming inaccessible or accessible between captures cannot pass", () => {
  const before = restrictedRegion(fixture("before")); const after = restrictedRegion(fixture("after"));
  const accessible = (raw) => { const row = raw.runInventories.at(-1);
    row.pages = [response(row.unavailable.url, {services: []})]; delete row.unavailable; return raw; };
  assert.throws(() => guard.createProof(context, capture("before", before), capture("after", accessible(structuredClone(after)))), /scope changed/);
  assert.throws(() => guard.createProof(context, capture("before", accessible(structuredClone(before))), capture("after", after)), /scope changed/);
});

test("an unavailable region never masks an accessible service IAM change", () => {
  const after = restrictedRegion(fixture("after"));
  changeBody(after.runIam.at(-1).response, (v) => { v.bindings[0].members = ["allAuthenticatedUsers"]; });
  assert.throws(() => guard.createProof(context, capture("before", restrictedRegion(fixture("before"))), capture("after", after)), /pre-existing service/);
});

test("real read-only collector produces replay-verifiable full before/after evidence", async () => {
  const collected = [];
  for (const phase of ["before", "after"]) {
    const raw = fixture(phase); const measured = new Map();
    function walk(value) { if (value?.url) measured.set(value.url, value); else if (value && typeof value === "object") Object.values(value).forEach(walk); }
    walk(raw); const visited = new Set();
    const result = await collector.collect(context, phase, async (url, method = "GET", data) => {
      const value = measured.get(url); assert.ok(value, `unexpected network read ${url}`);
      assert.equal(method, value.method); assert.ok(!visited.has(url)); visited.add(url);
      if (url.startsWith("https://iam.googleapis.com/") && url.includes(":getIamPolicy")) {
        assert.equal(method, "POST"); assert.equal(data, undefined);
      } else if (method === "POST") assert.deepEqual(data, {options: {requestedPolicyVersion: 3}});
      return value;
    });
    assert.equal(visited.size, measured.size); assert.equal(result.mutationBoundary.iamMutated, false);
    // Deterministic fixture collection times make the distinct observation windows explicit.
    result.raw.startedAtUtc = raw.startedAtUtc; result.raw.completedAtUtc = raw.completedAtUtc;
    collected.push(capture(phase, result.raw));
  }
  assert.deepEqual(guard.validateBeforeCapture({...context, capture: collected[0]}), {ok: true, decision: "PASS_NEW_CALLABLE_INVOKER_IAM_PREFLIGHT"});
  const proof = guard.createProof(context, ...collected);
  assert.deepEqual(guard.validateProof({...context, proof}), {ok: true, decision: "PASS_NEW_CALLABLE_INVOKER_IAM_ONLY"});
  assert.equal(proof.newServiceResources.length, 4);
});

for (const [label, mutate] of [
  ["403 function is not absence", (raw) => { raw.absence[0].functionDescribe.httpStatus = 403; }],
  ["404 permission response is not absence", (raw) => changeBody(raw.absence[0].serviceDescribe, (v) => { v.error.status = "PERMISSION_DENIED"; })],
  ["function missing but derived service exists", (raw) => { raw.absence[0].serviceDescribe = response(raw.absence[0].serviceDescribe.url, {name: raw.absence[0].serviceResource}); }],
  ["missing one paired absence read", (raw) => { raw.absence.pop(); }],
  ["wrong project absence request", (raw) => { raw.absence[0].functionDescribe.url = raw.absence[0].functionDescribe.url.replace(project, "different-project"); }],
  ["function page with unreachable region", (raw) => changeBody(raw.functions[0], (v) => { v.unreachable = ["us-east1"]; })],
  ["truncated function pagination", (raw) => changeBody(raw.functions[0], (v) => { v.nextPageToken = "another"; })],
  ["missing unrelated Run region", (raw) => { raw.runInventories.pop(); }],
  ["missing existing service policy", (raw) => { raw.runIam.pop(); }],
  ["missing runtime account policy", (raw) => { raw.accountIam.pop(); }],
  ["incorrect GET for service-account policy", (raw) => { raw.accountIam[0].response.method = "GET"; }],
  ["duplicate function inventory", (raw) => changeBody(raw.functions[0], (v) => { v.functions.push(v.functions[0]); })],
  ["invented approval hash", (raw) => { raw.approvalSha256 = "0".repeat(64); }],
  ["malformed response bytes", (raw) => { raw.projectIam.bodyText = "bad-json"; }],
]) test(`preflight refuses ${label}`, () => {
  const raw = fixture("before"); mutate(raw); assert.throws(() => capture("before", raw), /Scoped invoker IAM/);
});

for (const [label, mutate] of [
  ["only three additions", (approval) => approval.approvedDeployment.newCallableInvokerPolicies.pop()],
  ["extra authorized role", (approval) => { approval.approvedDeployment.newCallableInvokerPolicies[0].role = "roles/owner"; }],
  ["conditional approval", (approval) => { approval.approvedDeployment.newCallableInvokerPolicies[0].condition = {expression: "true"}; }],
  ["wrong service region", (approval) => { approval.approvedDeployment.newCallableInvokerPolicies[0].serviceResource = service(additions[0], "us-east1"); }],
  ["duplicated service approval", (approval) => { approval.approvedDeployment.newCallableInvokerPolicies[1].serviceResource = service(additions[0]); }],
  ["extra invoker member", (approval) => approval.approvedDeployment.newCallableInvokerPolicies[0].members.push("allAuthenticatedUsers")],
  ["missing preserved IAM requirement", (approval) => { delete approval.approvedDeployment.preserveExistingIamRequired; }],
]) test(`scope refuses ${label}`, () => {
  const altered = structuredClone(context); mutate(altered.approval);
  assert.throws(() => capture("before", fixture("before"), altered), /Scoped invoker IAM/);
});

for (const [label, mutate] of [
  ["changed project member", (raw) => changeBody(raw.projectIam, (v) => v.bindings[0].members.push("allUsers"))],
  ["changed project condition", (raw) => changeBody(raw.projectIam, (v) => { v.bindings[0].condition.expression = "false"; })],
  ["removed audit configuration", (raw) => changeBody(raw.projectIam, (v) => { delete v.auditConfigs; })],
  ["changed runtime account IAM", (raw) => changeBody(raw.accountIam[0].response, (v) => { v.bindings = [{role: "roles/iam.serviceAccountTokenCreator", members: ["allUsers"]}]; })],
  ["recreated account identity", (raw) => changeBody(raw.accounts[0], (v) => { v.accounts[0].uniqueId = "replacement-identity"; })],
  ["changed unrelated-region Run policy", (raw) => changeBody(raw.runIam.at(-1).response, (v) => { v.bindings[0].members = ["allAuthenticatedUsers"]; })],
  ["recreated old service identity", (raw) => changeBody(raw.runInventories[0].pages[0], (v) => { v.services.find((r) => r.name === service("mutateAssetHierarchy")).uid = "replacement"; })],
  ["extra new role", (raw) => changeBody(raw.runIam.find((r) => r.resource === service(additions[0])).response, (v) => v.bindings.push({role: "roles/owner", members: ["allUsers"]}))],
  ["new conditional public binding", (raw) => changeBody(raw.runIam.find((r) => r.resource === service(additions[0])).response, (v) => { v.bindings[0].condition = {expression: "true"}; })],
  ["new private policy", (raw) => changeBody(raw.runIam.find((r) => r.resource === service(additions[0])).response, (v) => { v.bindings[0].members = ["allAuthenticatedUsers"]; })],
  ["actual new function maps to another service", (raw) => changeBody(raw.functions[0], (v) => { v.functions.find((r) => r.name.endsWith(`/${additions[0]}`)).serviceConfig.service = service("mutateAssetHierarchy"); })],
  ["fifth new service", (raw) => {
    const resource = service("extra-unapproved");
    changeBody(raw.runInventories[0].pages[0], (v) => v.services.push({name: resource, uid: "fifth-service"}));
    raw.runIam.push({resource, response: response(`https://run.googleapis.com/v2/${resource}:getIamPolicy?options.requestedPolicyVersion=3`, publicPolicy())});
  }],
  ["deleted unrelated service", (raw) => {
    changeBody(raw.runInventories[1].pages[0], (v) => { v.services = []; });
    raw.runIam.pop();
  }],
  ["after timestamps predate preflight", (raw) => { raw.startedAtUtc = "2026-09-13T00:00:00.000Z"; }],
]) test(`final comparison refuses ${label}`, () => {
  const raw = fixture("after"); mutate(raw);
  assert.throws(() => guard.createProof(context, capture("before"), capture("after", raw)), /Scoped invoker IAM/);
});

test("policy ordering and etags do not invent IAM changes; raw bytes stay bound", () => {
  const raw = fixture("after");
  changeBody(raw.projectIam, (v) => { v.etag = "next"; v.bindings.reverse(); });
  for (const row of raw.runIam) changeBody(row.response, (v) => { v.etag = "new"; });
  const proof = guard.createProof(context, capture("before"), capture("after", raw));
  assert.equal(guard.validateProof({...context, proof}).ok, true);
  proof.after.raw.projectIam.bodyText += " ";
  assert.throws(() => guard.validateProof({...context, proof}), /seal|SHA|digest/i);
});

test("rehashed claim cannot conceal changed evidence or altered derived comparison", () => {
  const proof = guard.createProof(context, capture("before"), capture("after"));
  const {receiptSha256, ...body} = proof; body.after.measurement.projectIam.bindings = [];
  const {receiptSha256: inner, ...captureBody} = body.after; body.after = seals.sealReceipt(captureBody);
  assert.throws(() => guard.validateProof({...context, proof: seals.sealReceipt(body)}), /capture does not match/);
});

test("historical false path remains valid; unscoped true and false relabelling fail", () => {
  assert.deepEqual(guard.validateDeploymentIamBoundary({approval: {approvedDeployment: {}}, receipt: {controlBoundary: {iamMutated: false}}}), {ok: true, decision: "PASS_NO_IAM_MUTATION"});
  assert.throws(() => guard.validateDeploymentIamBoundary({approval: {}, receipt: {controlBoundary: {iamMutated: true}}}), /unscoped/);
  assert.throws(() => guard.validateDeploymentIamBoundary({...context, receipt: {controlBoundary: {iamMutated: false}}}), /explicitly declared/);
});

test("deployment boundary binds physical/canonical custody, approval and exact source", () => {
  fs.mkdirSync(path.join(repoRoot, "build"), {recursive: true});
  const directory = fs.mkdtempSync(path.join(repoRoot, "build", "scoped-iam-fixture-"));
  try {
    const proof = guard.createProof(context, capture("before"), capture("after"));
    const file = path.join(directory, "proof.json"); fs.writeFileSync(file, JSON.stringify(proof));
    const receipt = {sourceAuthority: {commit: sourceCommit}, approvalAuthority: {sha256: context.approvalSha256},
      controlBoundary: {iamMutated: true}, deployment: {
        startedAtUtc: "2026-09-13T01:05:00.1234567Z",
        lastDeploymentCommandCompletedAtUtc: "2026-09-13T01:59:59.999999999Z",
        newCallableInvokerIamEvidence: {
        file: path.relative(repoRoot, file).replaceAll("\\", "/"), physicalSha256: guard.hash(fs.readFileSync(file)), canonicalReceiptSha256: proof.receiptSha256}}};
    assert.equal(guard.validateDeploymentIamBoundary({...context, receipt}).ok, true);
    const approvalFile = path.join(directory, "approval.json"); const receiptFile = path.join(directory, "deployment.json");
    fs.writeFileSync(approvalFile, JSON.stringify(approval)); fs.writeFileSync(receiptFile, JSON.stringify(receipt));
    const cli = JSON.parse(execFileSync(process.execPath, [path.join(repoRoot, "tools/release/scopedCallableInvokerIam.js"),
      "verify-deployment", "--repository-root", repoRoot, "--approval", approvalFile,
      "--approval-sha256", context.approvalSha256, "--receipt", receiptFile], {encoding: "utf8", windowsHide: true}));
    assert.equal(cli.decision, "PASS_NEW_CALLABLE_INVOKER_IAM_ONLY");
    for (const mutate of [
      (r) => { r.deployment.newCallableInvokerIamEvidence.physicalSha256 = "0".repeat(64); },
      (r) => { r.deployment.newCallableInvokerIamEvidence.canonicalReceiptSha256 = "0".repeat(64); },
      (r) => { r.approvalAuthority.sha256 = "0".repeat(64); },
      (r) => { r.sourceAuthority.commit = "0".repeat(40); },
      (r) => { r.deployment.newCallableInvokerIamEvidence.file = "../proof.json"; },
      (r) => { r.deployment.startedAtUtc = "2026-09-13T00:59:59.9999999Z"; },
      (r) => { r.deployment.lastDeploymentCommandCompletedAtUtc = "2026-09-13T02:00:00.000000001Z"; },
      (r) => { r.deployment.lastDeploymentCommandCompletedAtUtc = "2026-09-13T01:05:00.1234566Z"; },
      (r) => { r.deployment.startedAtUtc = "2026-09-31T01:05:00.1234567Z"; },
      (r) => { r.deployment.startedAtUtc = "2026-09-13T01:05:00.1234567+00:00"; },
      (r) => { r.deployment.startedAtUtc = "2026-09-13T01:05:00.1234567890Z"; },
      (r) => { delete r.deployment.lastDeploymentCommandCompletedAtUtc; },
    ]) { const altered = structuredClone(receipt); mutate(altered); assert.throws(() => guard.validateDeploymentIamBoundary({...context, receipt: altered})); }
  } finally { assert.ok(directory.startsWith(path.join(repoRoot, "build") + path.sep)); fs.rmSync(directory, {recursive: true}); }
});
