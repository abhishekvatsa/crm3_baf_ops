"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), cp = require("node:child_process"), crypto = require("node:crypto");
const subject = require("./business31ReadOnlyPrelaunch.cjs");
const bootstrap = require("./business31CaptureBootstrap.cjs");
const driver = require("./testdata/business31CliDeployDriver.cjs");
const fleet = require("./testdata/business31CliFleetFixture.cjs"), kernel = require("./testdata/business31CliSyntheticKernel.cjs");
const CANARIES = require("./testdata/business31ReadOnlyPrelaunchFixture.cjs").CANARIES;
const sha = b => crypto.createHash("sha256").update(b).digest("hex").toUpperCase();
const names = Array.from({ length: 19 }, (_, i) => "testFunction" + i);
let run;
function write(p, value) { const b = Buffer.isBuffer(value) ? value : Buffer.from(typeof value === "string" ? value : JSON.stringify(value) + "\n");
  fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, b, { flag: "wx" }); return { path: p, sha256: sha(b) }; }

test("refresh eligibility matches the pinned strict fifteen-minute margin", () => {
  const now = 1800000000000;
  assert.equal(subject.refreshEligible31(now - 1, now), true);
  assert.equal(subject.refreshEligible31(now + 14 * 60000, now), true);
  assert.equal(subject.refreshEligible31(now + 15 * 60000, now), false);
  assert.equal(subject.refreshEligible31(now + 16 * 60000, now), false);
  assert.throws(() => subject.refreshEligible31("0", now), /INVALID_TOKEN_EXPIRY/);
});
test("selected environment preserves POSIX case and rejects conflicting Windows aliases", () => {
  assert.deepEqual(subject.normalizeEnv31({ HOME: "a", home: "b" }, "linux"), { HOME: "a", home: "b" });
  assert.deepEqual(subject.normalizeEnv31({ SystemRoot: "C:/Windows", SYSTEMROOT: "C:/Windows" }, "win32"), { SYSTEMROOT: "C:/Windows" });
  assert.throws(() => subject.normalizeEnv31({ SystemRoot: "a", SYSTEMROOT: "b" }, "win32"), /CONFLICTING_ENVIRONMENT_ALIASES/);
});

for (const [method, url] of [["POST", "https://serviceusage.googleapis.com/v1beta1/projects/123/services/pubsub.googleapis.com:generateServiceIdentity"],
  ["POST", "https://cloudfunctions.googleapis.com/v2/projects/crm3-baf-ops-b8638/locations/asia-south1/functions:generateUploadUrl"],
  ["PATCH", "https://cloudfunctions.googleapis.com/v2/projects/crm3-baf-ops-b8638/locations/asia-south1/functions/testFunction0"],
  ["GET", "https://firebase-public.firebaseio.com/other.json"], ["GET", subject.V1 + "?pageToken=unknown"],
  ["GET", subject.V2 + "&pageToken=unknown"], ["POST", "https://www.googleapis.com/oauth2/v4/token"],
  ["GET", "http://localhost:8000/__/health"]]) {
  test("read-only scope refuses " + method + " " + new URL(url).pathname, () => {
    const g = new subject.ReadOnlyPrelaunchGuard31(names);
    assert.throws(() => g.read(new URL(url), method)); assert.equal(g.failed, true);
    assert.throws(() => g.read(new URL(subject.V1), "GET"), /STICKY_READ_ONLY_REFUSAL/);
    assert.equal(g.events.every(row => Object.keys(row).every(k => ["kind", "method", "host", "path", "status"].includes(k))), true);
  });
}
test("permission POST has only the exact read-only permission set and project", () => {
  const client = { opts: { urlPrefix: "https://cloudresourcemanager.googleapis.com", apiVersion: "v1", auth: true } };
  const request = { method: "POST", path: "/projects/crm3-baf-ops-b8638:testIamPermissions", body: { permissions: subject.PERMISSIONS }, headers: { "x-goog-user-project": subject.PROJECT } };
  const g = new subject.ReadOnlyPrelaunchGuard31(names);
  assert.equal(g.before(client, request).route, "permissions");
  const bad = new subject.ReadOnlyPrelaunchGuard31(names);
  assert.throws(() => bad.before(client, { ...request, body: { permissions: ["cloudfunctions.functions.update"] } }), /EXACT_READ_PERMISSIONS_REQUIRED/);
  assert.equal(bad.failed, true);
});
test("the primitive cannot start in an ordinary shared process", async () => {
  await assert.rejects(subject.runReadOnlyPrelaunch31({}), /fixed fresh bootstrap/);
});

test.before(() => {
  const scratch = path.resolve(__dirname, "../../.dart_tool/read-only-prelaunch-fixtures"); fs.mkdirSync(scratch, { recursive: true });
  const original = Object.fromEntries(["TMP", "TEMP", "TMPDIR"].map(k => [k, process.env[k]]));
  for (const key of Object.keys(original)) process.env[key] = scratch;
  try { run = driver.createRun("credential-refresh"); }
  finally { for (const [key, value] of Object.entries(original)) { if (value === undefined) delete process.env[key]; else process.env[key] = value; } }
});
test.after(() => { if (run) driver.assertPopulationUnchanged(run); });

function sample(scenario) {
  const root = path.join(run.root, "read-only-" + scenario), source = path.join(root, "source"), scratch = path.join(source, "scratch");
  fs.mkdirSync(scratch, { recursive: true });
  for (const name of ["business31CaptureBootstrap.cjs", "runtimeDeploymentTransportGuard31.cjs", "business31ReadOnlyPrelaunch.cjs", "backendRuntimeAdmission31.cjs", "backendRuntimeEvidenceAccess31.cjs"])
    fs.copyFileSync(path.join(__dirname, name), path.join(source, name));
  for (const name of ["business31ReadOnlyPrelaunchFixture.cjs", "business31CliOfflineFence.cjs", "business31CliSyntheticKernel.cjs"])
    fs.copyFileSync(path.join(__dirname, "testdata", name), path.join(source, name));
  write(path.join(source, "business31CaptureBootstrap.test.cjs"), '"use strict"; module.exports = require("./business31ReadOnlyPrelaunchFixture.cjs");\n');
  const cwd = path.join(scratch, "project"); write(path.join(cwd, "firebase.json"), {}); write(path.join(cwd, ".firebaserc"), { projects: {} });
  const environment = { SystemRoot: process.env.SystemRoot ?? "C:/Windows", WINDIR: process.env.WINDIR ?? "C:/Windows",
    COMSPEC: process.env.COMSPEC ?? "C:/Windows/System32/cmd.exe", PATH: path.dirname(process.execPath),
    HOME: scratch, USERPROFILE: scratch, APPDATA: path.join(scratch, "APPDATA"), LOCALAPPDATA: path.join(scratch, "LOCALAPPDATA"),
    XDG_CONFIG_HOME: path.join(scratch, ".config"), GH_CONFIG_DIR: path.join(scratch, "GH_CONFIG_DIR"),
    TEMP: scratch, TMP: scratch, CI: "true", NO_COLOR: "1" };
  if (scenario === "not-ci") environment.CI = "false";
  if (scenario === "controller-environment") {
    // Match the protected controller's per-key NoDot profile pattern, without
    // reading any live profile. HOME and USERPROFILE intentionally differ.
    for (const key of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "GH_CONFIG_DIR", "TEMP", "TMP"])
      environment[key] = path.join(scratch, "profile", key);
    environment.TMPDIR = environment.TEMP;
    assert.notEqual(environment.HOME, environment.USERPROFILE);
  }
  for (const key of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "GH_CONFIG_DIR", "TEMP", "TMP"])
    fs.mkdirSync(environment[key], { recursive: true });
  const selectedFleet = fleet.createFleetFixture(run.cohorts, run.runtimeIdentityPolicy);
  write(path.join(source, "CASE.json"), { scenario, scratch, cwd, environment,
    account: { email: "offline-prelaunch@example.invalid", firebaseConfigPath: path.join(environment.XDG_CONFIG_HOME, "configstore/firebase-tools.json") },
    node: { path: process.execPath, sha256: run.nodeSha256 }, names: run.cohorts.fleet, functions: selectedFleet.existingFunctions,
    kernel: write(path.join(scratch, kernel.KERNEL_RELATIVE), kernel.KERNEL_TEXT) });
  const sourceFiles = bootstrap.sourceMap(source);
  const request = write(path.join(root, "REQUEST.json"), { schemaVersion: 1, operation: "component-test", suite: "bootstrap-regressions", caseId: "installed-positive",
    componentData: { runtime: run.runtime }, sourceRoot: source, sourceFiles, nodeExecutable: process.execPath, nodeSha256: run.nodeSha256,
    gitExecutable: null, nonOperational: true });
  const argv = [path.join(source, "business31CaptureBootstrap.cjs"), "--component-child", request.path, request.sha256];
  let native, owned = null;
  if (process.platform === "win32") {
    const launch = path.join(root, "launcher"); fs.mkdirSync(launch);
    for (const name of ["runtime_process_runner.py", "runtime_supervisor.py"]) fs.copyFileSync(path.join(__dirname, name), path.join(launch, name));
    const python = process.env.BUSINESS31_TEST_PYTHON || "C:/Python313/python.exe";
    const request = write(path.join(root, "OWNED_REQUEST.json"), { schemaVersion: 1, parentPid: process.pid,
      supervisorSha256: sha(fs.readFileSync(path.join(launch, "runtime_supervisor.py"))), executable: process.execPath,
      arguments: argv, cwd, environment, outputDirectory: path.join(root, "owned"), timeoutSeconds: 120,
      maxOutputBytes: 8 * 1024 * 1024, cleanupSeconds: 5 });
    native = cp.spawnSync(python, ["-I", "-S", "-B", path.join(launch, "runtime_process_runner.py"), "--python-root", path.dirname(python), request.path],
      { cwd, windowsHide: true, env: environment, stdio: ["ignore", "pipe", "pipe"], timeout: 150000, maxBuffer: 8 * 1024 * 1024 });
    write(path.join(root, "runner.stdout.bin"), native.stdout ?? Buffer.alloc(0)); write(path.join(root, "runner.stderr.bin"), native.stderr ?? Buffer.alloc(0));
    owned = JSON.parse(fs.readFileSync(path.join(root, "owned/result.json"), "utf8"));
    assert.equal(owned.treeComplete, true); assert.equal(owned.outputComplete, true); assert.equal(owned.activeProcesses, 0);
    assert.deepEqual(owned.cleanupErrors, []); assert.equal(owned.terminationRequested, false);
    native = { ...native, stdout: fs.readFileSync(path.join(root, "owned/stdout.bin")), stderr: fs.readFileSync(path.join(root, "owned/stderr.bin")) };
  } else native = cp.spawnSync(process.execPath, argv, { cwd, env: environment, windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"], timeout: 180000, maxBuffer: 8 * 1024 * 1024 });
  write(path.join(root, "stdout.bin"), native.stdout ?? Buffer.alloc(0)); write(path.join(root, "stderr.bin"), native.stderr ?? Buffer.alloc(0));
  write(path.join(root, "NATIVE_RESULT.json"), { status: native.status, signal: native.signal,
    error: native.error ? { code: native.error.code } : null, sourceRequest: request, ownedWindowsResult: owned,
    liveCheck: false, productionMutation: false });
  const bytes = fs.readFileSync(path.join(scratch, "events.jsonl")), events = bytes.toString().trim().split("\n").filter(Boolean).map(JSON.parse);
  for (const canary of CANARIES) for (const b of [native.stdout ?? Buffer.alloc(0), native.stderr ?? Buffer.alloc(0), bytes]) assert.equal(b.includes(Buffer.from(canary)), false, "Credential canary leaked in trace");
  assert.equal(native.error, undefined); assert.equal(native.signal, null);
  assert(events.every((r, i) => r.sequence === i + 1));
  const exit = events.find(e => e.kind === "FIXTURE_EXIT"); assert(exit); assert.deepEqual(exit.offlineDenials, []);
  if (!scenario.startsWith("late-exit-")) assert.equal(events.at(-1).kind, "FIXTURE_EXIT");
  return { root, native, events };
}

for (const scenario of ["expired", "refresh-margin", "controller-environment"]) test("actual read-only CLI " + scenario + " refresh persists, MOTD initializes and nineteen Functions return", { timeout: 200000 }, () => {
  const r = sample(scenario), detail = fs.readFileSync(path.join(r.root, "stderr.bin"), "utf8");
  assert.equal(r.native.status, 0, detail);
  const result = r.events.find(e => e.kind === "READ_ONLY_SESSION_RESULT");
  assert.equal(result.status, "READ_ONLY_REAL_CLI_REFRESH_AND_LIST_CONFIRMED"); assert.equal(result.cleanupComplete, true);
  assert.equal(result.tokenPersisted, true); assert.equal(result.functionsObserved, 19); assert.equal(result.refusalCount, 0);
  assert.equal(result.afterMotd.minVersion, "3.0.5"); assert.equal(result.afterMotd.minVersionAccepted, true);
  assert.equal(r.events.at(-1).cleanupObserved, true);
  const post = r.events.find(e => e.kind === "FIXTURE_POST_CLI_ENVIRONMENT_KEYS");
  assert.deepEqual(post.missing, []); assert.deepEqual(post.extra, []);
  assert.deepEqual(post.changed, scenario === "controller-environment" && process.platform === "win32" ? ["HOME"] : []);
  const wire = r.events.filter(e => e.kind === "OFFLINE_PHYSICAL_READ"); assert.equal(wire.length, 5);
  assert.equal(wire.filter(e => e.path === "/oauth2/v3/token").length, 1);
  assert.equal(wire.some(e => /generateServiceIdentity|upload|\/functions\//.test(e.path)), false);
});
for (const scenario of ["not-due", "not-ci", "cached-high", "cached-malformed", "fetched-high", "permission-refusal", "cohort-mismatch", "foreign-api", "foreign-loader", "unexpected-home"])
  test("actual read-only CLI refuses " + scenario + " without a deployment claim", { timeout: 200000 }, () => {
    const r = sample(scenario); assert.notEqual(r.native.status, 0);
    const env = r.events.find(e => e.kind === "FIXTURE_SELECTED_ENVIRONMENT_KEYS"); assert.deepEqual(env.missing, []); assert.deepEqual(env.extra, []); assert.deepEqual(env.changed, []);
    assert.equal(r.events.some(e => e.kind === "READ_ONLY_SESSION_RESULT"), false);
    assert.equal(r.events.at(-1).sessionReturned, false);
    if (scenario === "not-due") assert.equal(r.events.at(-1).sessionError, "WAIT_FOR_GENUINE_REFRESH_MARGIN");
    if (scenario === "not-ci") {
      assert.equal(r.events.at(-1).sessionError, "FIXED_NONINTERACTIVE_ENVIRONMENT_REQUIRED");
      assert.equal(r.events.filter(e => e.kind === "OFFLINE_PHYSICAL_READ").length, 0);
      assert.equal(r.events.some(e => e.kind === "read-only-cli-exit-intent"), false);
    }
    if (scenario.startsWith("cached-")) assert.equal(r.events.at(-1).sessionError, "MOTD_VERSION_REFUSED");
    if (scenario === "unexpected-home") assert.equal(r.events.at(-1).sessionError, "CLI_CHANGED_SELECTED_ENVIRONMENT");
    if (scenario.startsWith("foreign-")) {
      assert.equal(r.events.at(-1).sessionError, "READ_ONLY_CLEANUP_FAILED");
      assert.equal(r.events.find(e => e.kind === "FOREIGN_FIXTURE_HOOK_PRESERVED").preserved, true);
      assert.equal(r.events.find(e => e.kind === "read-only-prelaunch-cleanup").cleanupComplete, false);
    }
    assert.equal(r.events.filter(e => e.kind === "OFFLINE_PHYSICAL_READ").some(e => /generateServiceIdentity|upload|\/functions\//.test(e.path)), false);
  });
test("a caught late exit callback request stays fenced and invalidates earlier success", { timeout: 200000 }, () => {
  const r = sample("late-exit-read"); assert.notEqual(r.native.status, 0);
  const result = r.events.find(e => e.kind === "READ_ONLY_SESSION_RESULT"); assert(result);
  assert.equal(r.events.at(-1).kind, "LATE_EXIT_REQUEST_BLOCKED"); assert.equal(r.events.at(-1).blocked, true);
  assert(r.events.some(e => e.kind === "read-only-refused" && e.sequence > result.sequence));
  assert.equal(r.events.filter(e => e.kind === "OFFLINE_PHYSICAL_READ").length, 5);
});

test("a late Client API token request stays fenced and invalidates earlier success", { timeout: 200000 }, () => {
  const r = sample("late-exit-api"); assert.notEqual(r.native.status, 0);
  const result = r.events.find(e => e.kind === "READ_ONLY_SESSION_RESULT"); assert(result);
  assert.equal(r.events.at(-1).kind, "LATE_EXIT_API_REQUEST_ATTEMPTED");
  assert(r.events.some(e => e.kind === "read-only-refused" && e.sequence > result.sequence));
  assert.equal(r.events.filter(e => e.kind === "OFFLINE_PHYSICAL_READ").length, 5);
});
