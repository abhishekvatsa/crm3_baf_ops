import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {execFileSync, spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import guard from "./scopedCallableInvokerIam.js";
import publication from "./scopedCallableInvokerIamPublic.js";
import controls from "./reviewedBackendControls.js";
import seals from "./collectProductionGlobalPullBackend.js";
import verifier from "./reviewedBackendVerifierAuthority.js";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const sourceCommit = execFileSync("git", ["--no-replace-objects", "-C", repoRoot, "rev-parse", "HEAD"], {encoding: "utf8"}).trim();
const opts = controls.sourceOptions(repoRoot, sourceCommit), policy = opts.policy;
const {PROJECT: project, REGION: region, NEW_FUNCTIONS: additions} = guard;
const service = (name, location = region) => `projects/${project}/locations/${location}/services/${name.toLowerCase()}`;
const account = (name) => `${policy.functionBindings[name].runtimeServiceAccountId}@${project}.iam.gserviceaccount.com`;
const approval = {approved: true, firebaseProjectId: project, region, sourceAuthority: {commit: sourceCommit},
  approvedDeployment: {preserveExistingIamRequired: true, existingDedicatedServiceAccountsRequired: true, appCheckEnforcement: false,
    newCallableInvokerPolicies: additions.map((functionName) => ({functionName, serviceResource: service(functionName), role: "roles/run.invoker", members: ["allUsers"]}))}};
const context = {repoRoot, approval, approvalSha256: guard.hash(JSON.stringify(approval)), sourceCommit};
const response = (url, value, method = "GET", httpStatus = 200) => ({url, method, httpStatus, bodyText: JSON.stringify(value)});
const pages = (url, field, values) => [response(`${url}?pageSize=100`, {[field]: values})];
const publicPolicy = () => ({version: 3, etag: "not-authority", bindings: [{role: "roles/run.invoker", members: ["allUsers"]}]});
const change = (row, mutate) => { const b = JSON.parse(row.bodyText); mutate(b); row.bodyText = JSON.stringify(b); };
const canaries = ["literal-secret-CANARY-123", "private-operator@example.invalid", "unrelated-private-service", `private-account@${project}.iam.gserviceaccount.com`];
function fixture(phase, unavailable = false) {
  const names = Object.keys(policy.functionBindings).filter((name) => phase === "after" || !additions.includes(name));
  const emails = [...new Set(Object.keys(policy.functionBindings).map(account)), canaries[3]];
  const functions = names.map((name) => ({name: `projects/${project}/locations/${region}/functions/${name}`,
    state: "ACTIVE", environment: "GEN_2", buildConfig: {runtime: opts.runtime, entryPoint: name},
    labels: {"firebase-functions-hash": "a".repeat(40)},
    serviceConfig: {service: service(name), serviceAccountEmail: account(name), ingressSettings: "ALLOW_ALL",
      environmentVariables: {CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK: "false", PRIVATE_SECRET: canaries[0],
        FUNCTION_TARGET: name, EVENTARC_CLOUD_EVENT_SOURCE: `projects/${project}/locations/${region}/services/${name}`,
        FUNCTION_SIGNATURE_TYPE: policy.functionBindings[name].workloadClass.startsWith("CALLABLE") ? "http" : "cloudevent", LOG_EXECUTION_ID: "true"},
      availableMemory: opts.mutating[name]?.availableMemory ?? "256Mi", timeoutSeconds: 60, maxInstanceRequestConcurrency: 20,
      availableCpu: "1", maxInstanceCount: additions.includes(name) ? 100 : 20, allTrafficOnLatestRevision: true},
    ...(policy.functionBindings[name].workloadClass.startsWith("FIRESTORE_") ? {eventTrigger: {serviceAccountEmail: account(name)}} : {})}));
  const runs = names.map((name) => ({name: service(name), uid: `uid-${name}`}));
  const unrelated = {name: service(canaries[2], "us-central1"), uid: "private-uid"};
  const raw = {schemaVersion: 1, projectId: project, region, sourceCommit, approvalSha256: context.approvalSha256,
    startedAtUtc: `2026-09-12T0${phase === "before" ? 1 : 2}:00:00.000Z`, completedAtUtc: `2026-09-12T0${phase === "before" ? 1 : 2}:00:01.000Z`,
    project: response(`https://cloudresourcemanager.googleapis.com/v1/projects/${project}`, {projectId: project, projectNumber: "123456789"}),
    functions: pages(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/-/functions`, "functions", functions),
    runLocations: pages(`https://run.googleapis.com/v1/projects/${project}/locations`, "locations", [{locationId: region}, {locationId: "us-central1"}]),
    runInventories: [{location: region, pages: pages(`https://run.googleapis.com/v2/projects/${project}/locations/${region}/services`, "services", runs)},
      {location: "us-central1", pages: pages(`https://run.googleapis.com/v2/projects/${project}/locations/us-central1/services`, "services", [unrelated])}],
    runIam: [...runs, unrelated].map((row) => ({resource: row.name,
      response: response(`https://run.googleapis.com/v2/${row.name}:getIamPolicy?options.requestedPolicyVersion=3`, publicPolicy())})),
    accounts: pages(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts`, "accounts", emails.map((email, i) => ({email, projectId: project, uniqueId: `${i + 100}`}))),
    accountIam: emails.map((email) => ({email, response: response(`https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${email}:getIamPolicy?options.requestedPolicyVersion=3`, {}, "POST")})),
    projectIam: response(`https://cloudresourcemanager.googleapis.com/v1/projects/${project}:getIamPolicy`,
      {bindings: [{role: "roles/viewer", members: [`user:${canaries[1]}`]}]}, "POST"),
    absence: phase === "before" ? additions.map((functionName) => ({functionName, serviceResource: service(functionName),
      functionDescribe: response(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/${region}/functions/${functionName}`, {error: {code: 404, status: "NOT_FOUND"}}, "GET", 404),
      serviceDescribe: response(`https://run.googleapis.com/v2/${service(functionName)}`, {error: {code: 404, status: "NOT_FOUND"}}, "GET", 404)})) : []};
  if (unavailable) {
    change(raw.runLocations[0], (b) => b.locations.push({locationId: "me-central2"}));
    raw.runInventories.push({location: "me-central2", unavailable: response(`https://run.googleapis.com/v2/projects/${project}/locations/me-central2/services?pageSize=100`,
      {error: {code: 403, status: "PERMISSION_DENIED", details: [{"@type": "type.googleapis.com/google.rpc.ErrorInfo", reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com",
        metadata: {location: "me-central2", consumer: "projects/123456789", service: ""}}]}}, "GET", 403)});
  }
  return raw;
}
function privateResult(bytes) {
  const bucket = "crm3-baf-ops-b8638-firestore-restore", prefix = `gs://${bucket}/release-custody/build-28/synthetic-publication-fixture`;
  const objectUri = `${prefix}/scoped-iam-comparison.json`, generation = "1234567891234567";
  return {schemaVersion: 1, provider: "gcs", purpose: "custodyRecord", buildNumber: 28, bucket, prefix,
    objectName: objectUri.slice(`gs://${bucket}/`.length), objectUri, generation, generationUri: `${objectUri}#${generation}`,
    bytes: bytes.length, sha256: guard.hash(bytes), downloadedBytes: bytes.length, downloadedSha256: guard.hash(bytes),
    createOnly: true, generationPinnedReadback: true, verified: true, verifiedAtUtc: "2026-09-12T02:05:02.1234567Z",
    approval: {commit: "e1db8eaa4b34c26254d3fd2a4cfc533747e187a4", file: "release/approvals/build28-private-cloud-custody-approval.json",
      sha256: "3DEB2A9E26FCFDBBAC20A591256ABB3A29FA3EBEF75D3A91FDACCEA2BA64FC88"},
    bucketControls: {bucket, location: "ASIA-SOUTH1", publicAccessPrevention: "enforced", uniformBucketLevelAccess: true,
      versioningEnabled: true, publicIamPrincipalsAbsent: true, retentionSeconds: 7776000, softDeleteSeconds: 604800, checkedAtUtc: "2026-09-12T02:05:00.1234567Z"}};
}
function inputs(unavailable = false, modifyAfter = () => {}, ctx = context) {
  const a = fixture("before", unavailable), b = fixture("after", unavailable); modifyAfter(b);
  a.approvalSha256 = ctx.approvalSha256; b.approvalSha256 = ctx.approvalSha256;
  const raw = guard.createProof(ctx, guard.createCapture(ctx, a, "before"), guard.createCapture(ctx, b, "after"));
  const rawProofBytes = Buffer.from(`${JSON.stringify(raw)}\n`);
  return {...ctx, rawProofBytes, privateCustody: privateResult(rawProofBytes), observedAtUtc: "2026-09-12T02:06:00.000Z"};
}
const goodInputs = inputs(), good = publication.createPublicProof(goodInputs);
const reseal = (value) => { const {receiptSha256, ...body} = value; return seals.sealReceipt(body); };

test("actual full raw/control validation publishes only allowlisted commitments and verified custody", () => {
  assert.equal(publication.validatePublicProof({...context, proof: good}).ok, true);
  const text = JSON.stringify(good);
  for (const secret of [...canaries, "PRIVATE_SECRET", "environmentVariables", "bodyText", "private-uid"]) assert.equal(text.includes(secret), false, secret);
  assert.equal(good.before.inventory.functionCount, 15); assert.equal(good.after.inventory.functionCount, 19);
  assert.equal(good.after.inventory.runServiceCount, good.before.inventory.runServiceCount + 4);
  assert.equal(good.privateCustody.sha256, guard.hash(goodInputs.rawProofBytes));
  assert.match(good.qualification, /does not re-read hidden raw responses/);
});

test("matched unavailable region remains explicitly outside observed IAM coverage", () => {
  const proof = publication.createPublicProof(inputs(true));
  assert.deepEqual(proof.unavailableRunRegions, [{location: "me-central2", reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com", consumer: "projects/123456789"}]);
  assert.match(proof.coverage, /no absence or unchanged IAM is claimed there/);
});

test("private raw proof cannot be replaced with a label, altered measurement, or changed IAM", () => {
  for (const rawProofBytes of [Buffer.from('{"decision":"PASS_NEW_CALLABLE_INVOKER_IAM_ONLY"}'), Buffer.from(`${goodInputs.rawProofBytes} `)]) {
    assert.throws(() => publication.createPublicProof({...goodInputs, rawProofBytes}));
  }
  assert.throws(() => inputs(false, (raw) => change(raw.projectIam, (b) => b.bindings[0].members.push("allUsers"))));
});

test("a valid raw IAM proof with changed environment still fails real backend-control validation", () => {
  const input = inputs(false, (raw) => change(raw.functions[0], (b) => { b.functions.find((f) => f.name.endsWith("/mutateAssetHierarchy")).serviceConfig.environmentVariables.PRIVATE_SECRET = "changed"; }));
  assert.throws(() => publication.createPublicProof(input), /verification failed/i);
});

test("existing source-default scaling reset needs its fresh explicit approval before publication", () => {
  const reset = (raw) => change(raw.functions[0], (b) => {
    b.functions.find((f) => f.name.endsWith("/mutateAssetHierarchy")).serviceConfig.maxInstanceCount = 100;
  });
  assert.throws(() => publication.createPublicProof(inputs(false, reset)), /verification failed/);
  const approved = structuredClone(approval);
  approved.approvedDeployment.existingMaxInstanceCountReset = {authorized: true, targetMaxInstanceCount: 100,
    sourceMaxInstancesOmitted: true, sourcePreserveExternalChangesOmitted: true};
  approved.approvedDeployment.sourceScalingAuthority = structuredClone(opts.sdkReset);
  const ctx = {...context, approval: approved, approvalSha256: guard.hash(JSON.stringify(approved))};
  const publicProof = publication.createPublicProof(inputs(false, reset, ctx));
  assert.equal(publication.validatePublicProof({...ctx, proof: publicProof}).ok, true);
  assert.notEqual(publicProof.controls.receiptSha256, good.controls.receiptSha256);
});

test("generation failures never expose malformed private payloads, URLs or environment canaries", () => {
  const malformed = Buffer.from(`{\"private\":\"${canaries[0]}\" invalid`);
  const badUrl = inputs(); const raw = JSON.parse(badUrl.rawProofBytes);
  raw.before.raw.accountIam.at(-1).response.url += "/wrong";
  raw.before.rawMeasurementSha256 = guard.hash(seals.canonicalJson(raw.before.raw));
  raw.before = reseal(raw.before);
  badUrl.rawProofBytes = Buffer.from(JSON.stringify(reseal(raw)));
  for (const input of [{...goodInputs, rawProofBytes: malformed}, badUrl,
    inputs(false, (raw) => change(raw.functions[0], (b) => { b.functions.find((f) => f.name.endsWith("/mutateAssetHierarchy")).serviceConfig.environmentVariables.PRIVATE_SECRET = "changed"; }))]) {
    assert.throws(() => publication.createPublicProof(input), (error) => {
      for (const value of canaries) assert.equal(error.message.includes(value), false);
      assert.equal(error.message.includes("PRIVATE_SECRET"), false); return true;
    });
  }
});

for (const [name, mutate] of [
  ["source download mismatch", (p) => { p.downloadedSha256 = "0".repeat(64); }],
  ["source size mismatch", (p) => { p.downloadedBytes++; }],
  ["unpinned download", (p) => { p.generationPinnedReadback = false; }],
  ["current-generation substitution", (p) => { p.generationUri = p.objectUri; }],
  ["overwrite upload", (p) => { p.createOnly = false; }],
  ["public bucket", (p) => { p.bucketControls.publicIamPrincipalsAbsent = false; }],
  ["disabled prevention", (p) => { p.bucketControls.publicAccessPrevention = "inherited"; }],
  ["wrong private authority", (p) => { p.approval.commit = "0".repeat(40); }],
  ["extra raw bucket policy", (p) => { p.bucketControls.bindings = [{members: [canaries[1]]}]; }],
  ["unexpected raw custody field", (p) => { p.raw = canaries[0]; }],
  ["unsafe object name", (p) => { p.objectUri += "/private-person"; }],
  ["custody before final measurement", (p) => { p.bucketControls.checkedAtUtc = "2026-09-12T00:00:00Z"; }],
]) test(`generation refuses ${name}`, () => {
  const privateCustody = structuredClone(goodInputs.privateCustody); mutate(privateCustody);
  assert.throws(() => publication.createPublicProof({...goodInputs, privateCustody}));
});

for (const [name, mutate] of [
  ["top-level raw data", (p) => { p.raw = canaries[0]; }],
  ["nested raw data", (p) => { p.before.raw = {env: canaries[0]}; }],
  ["control raw data", (p) => { p.controls.environmentVariables = {SECRET: canaries[0]}; }],
  ["false preserved hash", (p) => { p.after.commitments.projectIamSha256 = "0".repeat(64); }],
  ["incomplete before preservation", (p) => { p.before.commitments.runServicesSha256 = "0".repeat(64); }],
  ["fifth added resource", (p) => { p.after.inventory.runServiceCount++; }],
  ["changed complete account count", (p) => { p.after.inventory.serviceAccountCount++; }],
  ["wrong option source bytes", (p) => { p.controls.sourceOptionsFiles[0].sha256 = "0".repeat(64); }],
  ["erased control result", (p) => { p.controls.existingFunctionEnvironmentVariablesUnchanged = false; }],
  ["unapproved public member", (p) => { p.newInvokerPolicies[0].members.push("allAuthenticatedUsers"); }],
  ["target region excluded", (p) => { p.unavailableRunRegions = [{location: region, reason: "LOCATION_POLICY_VIOLATED", domain: "googleapis.com", consumer: "projects/123456789"}]; }],
  ["publication before custody", (p) => { p.observedAtUtc = "2026-09-12T02:05:02.1234566Z"; }],
  ["impossible UTC date", (p) => { p.observedAtUtc = "2026-09-31T02:06:00Z"; }],
  ["future observation", (p) => { p.observedAtUtc = "2099-09-13T02:06:00Z"; }],
  ["erased CI limitation", (p) => { p.qualification = "Fully revalidated in public CI"; }],
]) test(`offline verification refuses re-sealed ${name}`, () => {
  const changed = structuredClone(good); mutate(changed);
  assert.throws(() => publication.validatePublicProof({...context, proof: reseal(changed)}));
});

test("public deployment boundary works in checkout without node_modules and still brackets actual commands", () => {
  const base = path.join(repoRoot, "build"); fs.mkdirSync(base, {recursive: true});
  const directory = fs.mkdtempSync(path.join(base, "public-iam-offline-"));
  try {
    // Read-only Git-object access in a minimal offline release checkout. No
    // dependency installation, raw observations, or cloud credentials exist.
    const gitDir = execFileSync("git", ["-C", repoRoot, "rev-parse", "--absolute-git-dir"], {encoding: "utf8"}).trim();
    fs.writeFileSync(path.join(directory, ".git"), `gitdir: ${gitDir.replaceAll("\\", "/")}\n`);
    fs.mkdirSync(path.join(directory, "release", "approvals"), {recursive: true});
    const approvalFile = good.privateCustody.approval.file;
    fs.copyFileSync(path.join(repoRoot, approvalFile), path.join(directory, approvalFile));
    assert.equal(fs.existsSync(path.join(directory, "functions", "node_modules")), false);
    fs.writeFileSync(path.join(directory, "proof.json"), JSON.stringify(good));
    const receipt = {sourceAuthority: {commit: sourceCommit}, approvalAuthority: {sha256: context.approvalSha256}, controlBoundary: {iamMutated: true},
      deployment: {startedAtUtc: "2026-09-12T01:05:00.1234567Z", lastDeploymentCommandCompletedAtUtc: "2026-09-12T01:59:59.999999999Z",
        newCallableInvokerIamEvidence: {file: "proof.json", physicalSha256: guard.hash(fs.readFileSync(path.join(directory, "proof.json"))), canonicalReceiptSha256: good.receiptSha256}}};
    const offline = {...context, repoRoot: directory};
    assert.equal(guard.validateDeploymentIamBoundary({...offline, receipt}).ok, true);
    for (const change of [(r) => { r.controlBoundary.iamMutated = false; }, (r) => { r.deployment.startedAtUtc = "2026-09-12T00:59:59Z"; },
      (r) => { r.deployment.lastDeploymentCommandCompletedAtUtc = "2026-09-12T02:00:00.000000001Z"; },
      (r) => { r.deployment.newCallableInvokerIamEvidence.physicalSha256 = "0".repeat(64); }]) {
      const changed = structuredClone(receipt); change(changed);
      assert.throws(() => guard.validateDeploymentIamBoundary({...offline, receipt: changed}));
    }
  } finally { assert.ok(directory.startsWith(base + path.sep)); fs.rmSync(directory, {recursive: true}); }
});

test("actual public CLI rederives evidence, refuses overwrite and never prints private parse failures", () => {
  const base = path.join(repoRoot, "build"); fs.mkdirSync(base, {recursive: true});
  const directory = fs.mkdtempSync(path.join(base, "public-iam-cli-"));
  try {
    const file = (name) => path.join(directory, name);
    fs.writeFileSync(file("approval.json"), JSON.stringify(approval));
    fs.writeFileSync(file("raw.json"), goodInputs.rawProofBytes);
    fs.writeFileSync(file("custody.json"), JSON.stringify(goodInputs.privateCustody));
    const argv = [path.join(repoRoot, "tools/release/scopedCallableInvokerIamPublic.js"), "--repository-root", repoRoot,
      "--approval", file("approval.json"), "--approval-sha256", context.approvalSha256, "--source-commit", sourceCommit,
      "--private-proof", file("raw.json"), "--private-custody", file("custody.json"),
      "--observed-at-utc", goodInputs.observedAtUtc, "--output", file("public.json")];
    const run = () => spawnSync(process.execPath, argv, {encoding: "utf8", windowsHide: true});
    const first = run(); assert.equal(first.status, 0, first.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(file("public.json"), "utf8")), good);
    const original = fs.readFileSync(file("public.json"));
    assert.equal(run().status, 1); assert.deepEqual(fs.readFileSync(file("public.json")), original);
    fs.writeFileSync(file("raw.json"), `{malformed "private-secret":"${canaries[0]}"`);
    const failed = run(); assert.equal(failed.status, 1);
    for (const secret of canaries) assert.equal(`${failed.stdout}${failed.stderr}`.includes(secret), false);
    assert.deepEqual(fs.readFileSync(file("public.json")), original);
  } finally { assert.ok(directory.startsWith(base + path.sep)); fs.rmSync(directory, {recursive: true}); }
});

function verificationFixture() {
  const base = path.join(repoRoot, "build");
  const directory = fs.mkdtempSync(path.join(base, "public-observed-authority-"));
  const git = (args, options = {}) => execFileSync("git", ["--no-replace-objects", "-C", directory, ...args],
    {encoding: "utf8", windowsHide: true, ...options}).trim();
  git(["init", "--quiet"]);
  const objectPath = path.resolve(repoRoot, execFileSync("git", ["-C", repoRoot, "rev-parse", "--git-path", "objects"], {encoding: "utf8"}).trim());
  fs.writeFileSync(path.join(directory, ".git/objects/info/alternates"), `${objectPath.replaceAll("\\", "/")}\n`);
  git(["read-tree", sourceCommit]);
  const verifierFiles = verifier.VERIFIER_FILES.map((file) => {
    const bytes = fs.readFileSync(path.join(repoRoot, file));
    fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});fs.writeFileSync(path.join(directory, file), bytes);
    // Preserve actual module bytes in the fixture object, independently of the
    // workstation's attributes. Production generation must load exact Git bytes.
    const blob = git(["hash-object", "-w", "--stdin"], {input: bytes});
    git(["update-index", "--add", "--cacheinfo", `100644,${blob},${file}`]);
    return {file, sha256: guard.hash(bytes)};
  });
  const epoch = Math.floor(Date.now() / 1000) - 5;
  const commit = (tree, parent, seconds) => git(["commit-tree", tree, "-p", parent], {input: "Synthetic local verifier test fixture only\n",
    env: {...process.env, GIT_AUTHOR_NAME: "Test fixture", GIT_AUTHOR_EMAIL: "fixture@example.invalid", GIT_COMMITTER_NAME: "Test fixture",
      GIT_COMMITTER_EMAIL: "fixture@example.invalid", GIT_AUTHOR_DATE: `${seconds} +0000`, GIT_COMMITTER_DATE: `${seconds} +0000`}});
  const verifierCommit = commit(git(["write-tree"]), sourceCommit, epoch);
  const decision = {schemaVersion: 1, evidenceType: "reviewed-backend-verifier-authorization", approved: true,
    profile: verifier.PROFILE, sourceCommit, deploymentApprovalSha256: context.approvalSha256, verifierCommit, verifierFiles,
    decidedAtUtc: new Date((epoch + 1) * 1000).toISOString(), authorizationBasis: "Synthetic isolated test decision; no operational authority.", cloudMutationAuthorized: false};
  const decisionFile = "release/approvals/synthetic-observed-verifier.json", bytes = Buffer.from(JSON.stringify(decision));
  fs.mkdirSync(path.dirname(path.join(directory, decisionFile)), {recursive: true});fs.writeFileSync(path.join(directory, decisionFile), bytes);
  git(["add", "--", decisionFile]);const decisionCommit = commit(git(["write-tree"]), verifierCommit, epoch + 2);
  fs.mkdirSync(path.join(directory, "functions"), {recursive: true});
  fs.symlinkSync(path.join(repoRoot, "functions/node_modules"), path.join(directory, "functions/node_modules"), process.platform === "win32" ? "junction" : "dir");
  const custodyFile = good.privateCustody.approval.file;
  fs.copyFileSync(path.join(repoRoot, custodyFile), path.join(directory, custodyFile));
  return {directory, context: {...context, repoRoot: directory, controlMode: controls.OBSERVED_CONTROL_MODE,
    verificationAuthority: {schemaVersion: 1, profile: verifier.PROFILE, verifierCommit, verifierFiles,
      decision: {commit: decisionCommit, file: decisionFile, sha256: guard.hash(bytes)}}},
  observedAtUtc: new Date((epoch + 3) * 1000).toISOString(), cleanup() {
    fs.unlinkSync(path.join(directory, "functions/node_modules"));
    assert.ok(directory.startsWith(base + path.sep));fs.rmSync(directory, {recursive: true});
  }};
}
function observedInputs(f, mutateAfter = () => {}) {
  const a = fixture("before"), b = fixture("after");
  const changed = ["beginGlobalPullRun", "completePlannedJobExecution"];
  change(a.functions[0], (body) => { for (const row of body.functions) if (changed.some((name) => row.name.endsWith(`/${name}`))) delete row.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE; });
  change(b.functions[0], (body) => { for (const row of body.functions) {
    const name = row.buildConfig.entryPoint;
    if (additions.includes(name)) delete row.serviceConfig.maxInstanceCount;
    if ([additions[0], additions[3]].includes(name)) delete row.serviceConfig.environmentVariables.FUNCTION_SIGNATURE_TYPE;
    row.serviceConfig.revision = `${name.toLowerCase()}-00001-abc`;
  }});
  const functions = JSON.parse(b.functions[0].bodyText).functions;
  for (const raw of [a, b]) change(raw.runInventories[0].pages[0], (body) => {
    for (const [index, row] of body.services.entries()) {
      // Stable actual-shaped infrastructure IDs across both observations.
      row.uid = `00000000-0000-4000-8000-${String(Object.keys(policy.functionBindings).findIndex((n) => service(n) === row.name)).padStart(12, "0")}`;
      if (raw !== b) continue;
      const fn = functions.find((f) => f.serviceConfig.service === row.name), name = fn.buildConfig.entryPoint;
      if (!additions.includes(name) && !changed.includes(name)) continue;
      row.generation = "1";row.observedGeneration = "1";row.terminalCondition = {type: "Ready", state: "CONDITION_SUCCEEDED"};
      row.latestCreatedRevision = `${row.name}/revisions/${fn.serviceConfig.revision}`;row.latestReadyRevision = row.latestCreatedRevision;
      row.traffic = [{type: "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST", percent: 100}];row.trafficStatuses = structuredClone(row.traffic);
      row.scaling = {maxInstanceCount: 20};row.ingress = "INGRESS_TRAFFIC_ALL";
      row.template = {revision: fn.serviceConfig.revision, serviceAccount: fn.serviceConfig.serviceAccountEmail,
        annotations: {"cloudfunctions.googleapis.com/trigger-type": "HTTP_TRIGGER"},
        containers: [{env: Object.entries(fn.serviceConfig.environmentVariables).map(([name, value]) => ({name, value}))}]};
    }
  });
  mutateAfter(b);
  const raw = guard.createProof(f.context, guard.createCapture(f.context, a, "before"), guard.createCapture(f.context, b, "after"));
  const rawProofBytes = Buffer.from(`${JSON.stringify(raw)}\n`);
  return {...f.context, rawProofBytes, privateCustody: privateResult(rawProofBytes), observedAtUtc: f.observedAtUtc};
}
test("actual new generation binds immutable verifier authority and measured Run20 while preserving legacy proof", () => {
  const f = verificationFixture();
  try {
    const input = observedInputs(f);
    // The deployed source checkout is data/input authority, not the selected
    // verifier implementation. Its alternate local modules must not execute.
    for (const name of ["scopedCallableInvokerIam", "collectProductionGlobalPullBackend"])
      fs.writeFileSync(path.join(f.directory, `tools/release/${name}.js`), "throw new Error('Wrong execution-checkout verifier loaded');\n");
    const comparison = controls.compareReviewedBackendControls({...input, proof: JSON.parse(input.rawProofBytes)});
    assert.equal(comparison.schemaVersion, 2);
    const proof = publication.createPublicProof(input);
    assert.equal(proof.schemaVersion, 3);assert.equal(publication.validatePublicProof({...f.context, proof}).ok, true);
    assert.equal(Object.hasOwn(proof.controls, "existingFunctionEnvironmentVariablesUnchanged"), false);
    assert.equal(proof.controls.existingProjectEnvironmentVariablesUnchanged, true);
    assert.equal(proof.controls.newFunctionEffectiveInstanceCaps.every((row) => row.cloudFunctionsMaxInstanceCount === null && row.effectiveMaxInstanceCount === 20), true);
    assert.equal(proof.controls.reservedHttpSignatureObservations.filter((row) => row.disposition === "platform-http-added").length, 2);
    for (const secret of [...canaries, "PRIVATE_SECRET", "bodyText", "environmentVariables"]) assert.equal(JSON.stringify(proof).includes(secret), false);
    assert.equal(publication.validatePublicProof({...context, proof: good}).ok, true);
    // Offline historical validation must not need current Windows modules/deps.
    fs.unlinkSync(path.join(f.directory, "functions/node_modules"));fs.rmdirSync(path.join(f.directory, "functions"));
    fs.writeFileSync(path.join(f.directory, "tools/release/reviewedBackendControls.js"), "changed after historical publication\n");
    assert.equal(publication.validatePublicProof({...f.context, proof}).ok, true);
    const proofBytes = Buffer.from(JSON.stringify(proof));fs.writeFileSync(path.join(f.directory, "public-proof.json"), proofBytes);
    const receipt = {sourceAuthority: {commit: sourceCommit}, approvalAuthority: {sha256: context.approvalSha256}, controlBoundary: {iamMutated: true},
      deployment: {startedAtUtc: "2026-09-12T01:05:00.000Z", lastDeploymentCommandCompletedAtUtc: "2026-09-12T01:59:59.999999999Z",
        newCallableInvokerIamEvidence: {file: "public-proof.json", physicalSha256: guard.hash(proofBytes), canonicalReceiptSha256: proof.receiptSha256}}};
    assert.equal(guard.validateDeploymentIamBoundary({...f.context, receipt}).ok, true);
    fs.mkdirSync(path.join(f.directory, "functions"));fs.symlinkSync(path.join(repoRoot, "functions/node_modules"), path.join(f.directory, "functions/node_modules"), process.platform === "win32" ? "junction" : "dir");
    for (const [label, mutate] of [
      ["legacy-schema downgrade", (p) => { p.schemaVersion = 2; }],
      ["untrue full-environment claim", (p) => { p.controls.existingFunctionEnvironmentVariablesUnchanged = true; }],
      ["missing measured cap", (p) => { p.controls.newFunctionEffectiveInstanceCaps[0].runServiceMaxInstanceCount = null; }],
      ["excessive measured cap", (p) => { p.controls.newFunctionEffectiveInstanceCaps[0].runServiceMaxInstanceCount = 101; }],
      ["wrong service", (p) => { p.controls.newFunctionEffectiveInstanceCaps[0].serviceResource += "-other"; }],
      ["wrong serving revision", (p) => { p.controls.newFunctionEffectiveInstanceCaps[0].revision = "other-00001-abc"; }],
      ["fabricated omitted GCF value", (p) => { p.controls.newFunctionEffectiveInstanceCaps[0].cloudFunctionsMaxInstanceCount = 100; }],
      ["missing HTTP observations", (p) => { p.controls.reservedHttpSignatureObservations = []; }],
      ["HTTP metadata attributed to event source", (p) => { p.controls.reservedHttpSignatureObservations.find((row) => row.name === "beginGlobalPullRun").name = "onTicketCreated";p.controls.reservedHttpSignatureObservations.sort((a,b) => a.name.localeCompare(b.name)); }],
      ["missing authority", (p) => { delete p.verificationAuthority; }],
      ["changed verifier bytes", (p) => { p.verificationAuthority.verifierFiles[0].sha256 = "0".repeat(64); }],
    ]) { const bad = structuredClone(proof);mutate(bad);assert.throws(() => publication.validatePublicProof({...f.context, proof: reseal(bad)}), undefined, label); }
    const missing = {...input};delete missing.verificationAuthority;
    assert.throws(() => publication.createPublicProof(missing), /verification failed/);
  } finally { f.cleanup(); }
});
test("new public generation refuses coherently sealed serving-control drift without exposing raw values", () => {
  const f = verificationFixture();
  try {
    assert.equal(publication.createPublicProof(observedInputs(f)).schemaVersion, 3);
    for (const mutate of [
      (raw) => change(raw.runInventories[0].pages[0], (b) => { b.services.find((r) => r.name === service(additions[0])).scaling.maxInstanceCount = 101; }),
      (raw) => change(raw.runInventories[0].pages[0], (b) => { b.services.find((r) => r.name === service(additions[0])).trafficStatuses[0].percent = 50; }),
      (raw) => change(raw.functions[0], (b) => { b.functions.find((r) => r.name.endsWith(`/${additions[0]}`)).serviceConfig.environmentVariables.PRIVATE_SECRET = canaries[1]; }),
    ]) assert.throws(() => publication.createPublicProof(observedInputs(f, mutate)), (error) => {
      assert.match(error.message, /verification failed/);for (const secret of canaries) assert.equal(error.message.includes(secret), false);return true;
    });
  } finally { f.cleanup(); }
});
