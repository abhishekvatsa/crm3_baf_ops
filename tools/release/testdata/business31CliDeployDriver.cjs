"use strict";
// Parent-only test driver. Every sample uses a fresh guarded Node process; failed artifacts are retained.
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const crypto = require("node:crypto"), cp = require("node:child_process"), assert = require("node:assert/strict");
const bootstrap = require("../business31CaptureBootstrap.cjs");
const execution = require("../backendRuntimeExecution31.cjs");
const kernel = require("./business31CliSyntheticKernel.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const PROJECT = "crm3-baf-ops-b8638";
const STOP_PREPARE = "BUSINESS31_OFFLINE_PREPARE_ENTRY_STOP";
function write(file, value) {
  const raw = Buffer.isBuffer(value) ? value : Buffer.from(typeof value === "string" ? value : JSON.stringify(value, null, 2) + "\n");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, raw, { flag: "wx" });
  return { path: file, sha256: sha(raw), bytes: raw.length };
}
function environment(scratch) {
  const env = {};
  for (const key of ["SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT"]) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  for (const key of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CLOUDSDK_CONFIG", "TEMP", "TMP"]) {
    env[key] = path.join(scratch, key); fs.mkdirSync(env[key]);
  }
  return { ...env, PATH: path.dirname(process.execPath), CI: "true", NO_COLOR: "1",
    NO_UPDATE_NOTIFIER: "1", FIREBASE_CLI_DISABLE_UPDATE_CHECK: "true" };
}
function createRun(mode) {
  assert(["prepare-entry", "pre-release"].includes(mode));
  const root = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "b31-cli-" + mode + "-"));
  const repo = path.resolve(__dirname, "../../..");
  const firebaseConfigurationPath = path.join(repo, "firebase.json");
  const firebaseConfigurationBytes = fs.readFileSync(firebaseConfigurationPath);
  const functionsConfiguration = JSON.parse(firebaseConfigurationBytes).functions;
  assert(Array.isArray(functionsConfiguration) && functionsConfiguration.length === 1);
  assert.equal(functionsConfiguration[0].source, "functions");
  assert.equal(functionsConfiguration[0].disallowLegacyRuntimeConfig, true);
  assert.equal(Object.hasOwn(functionsConfiguration[0], "runtime"), false);
  const sourceFirebaseConfiguration = { path: firebaseConfigurationPath, sha256: sha(firebaseConfigurationBytes), bytes: firebaseConfigurationBytes.length };
  const installed = path.join(repo, "tooling/firebase-cli/node_modules");
  let cliRoot = installed, files;
  // Reuse a complete regular tree read-only. POSIX npm .bin aliases are materialized only
  // in a private copy with the existing validator; the caller's installed tree is untouched.
  if (process.platform === "win32") files = bootstrap.sourceMap(installed);
  else {
    const materializer = require("../business31NpmBinMaterialization.cjs");
    const before = materializer.scan31(installed, true);
    const build = path.join(root, "cli-build");
    for (const rel of ["node_modules", "functions/node_modules", "tooling/firebase-cli"]) fs.mkdirSync(path.join(build, rel), { recursive: true });
    cliRoot = path.join(build, "tooling/firebase-cli/node_modules");
    fs.cpSync(installed, cliRoot, { recursive: true, dereference: false, verbatimSymlinks: true, force: false, errorOnExist: true });
    assert.deepEqual(materializer.scan31(cliRoot, true), before);
    const materialization = materializer.materializeNpmBins31({ buildRoot: build });
    write(path.join(root, "materialization.json"), materialization);
    assert.deepEqual(materializer.scan31(installed, true), before);
    files = materializer.scan31(cliRoot).files;
  }
  const map = write(path.join(root, "CLI_FILES.json"), files);
  const cliEntrypoint = path.join(cliRoot, "firebase-tools/lib/bin/firebase.js");
  const runtime = { cliEntrypoint, cliFileBindings: { path: map.path, sha256: map.sha256 } };
  const nodeSha256 = sha(fs.readFileSync(process.execPath));
  assert.equal(JSON.parse(fs.readFileSync(path.join(cliRoot, "firebase-tools/package.json"), "utf8")).version, "15.22.4");
  const cohorts = structuredClone(execution.EXPECTED_COHORTS);
  write(path.join(root, "RUN.json"), { mode, runtime, node: { path: process.execPath, sha256: nodeSha256 },
    cohorts, sourceFirebaseConfiguration, functionsConfiguration,
    childTimeoutMs: 600000, maxBuffer: 64 * 1024 * 1024, stdin: "closed", freshSamples: 3,
    controllerInvoked: false, fullControllerRehearsalClaimed: false, noProductionAuthority: true });
  return { root, mode, runtime, files, cliRoot, nodeSha256, cohorts, sourceFirebaseConfiguration, functionsConfiguration };
}
function syntheticProject(source, cohorts, functionsConfiguration) {
  const project = path.join(source, "project");
  write(path.join(project, "firebase.json"), { functions: structuredClone(functionsConfiguration) });
  write(path.join(project, ".firebaserc"), { projects: {} });
  write(path.join(project, "functions/package.json"), {
    name: "business31-offline-fixture", private: true, main: "index.js", engines: { node: "22" }, dependencies: { "firebase-functions": "7.0.0" }
  });
  write(path.join(project, "functions/index.js"), 'throw Error("OFFLINE_FUNCTIONS_SOURCE_MUST_NOT_EXECUTE");\n');
  // Discovery is a declared synthetic YAML fixture, not an SDK execution proof.
  write(path.join(project, "functions/node_modules/firebase-functions/package.json"), { name: "firebase-functions", version: "7.0.0", main: "index.js" });
  write(path.join(project, "functions/node_modules/firebase-functions/index.js"), 'throw Error("OFFLINE_SYNTHETIC_SDK_MUST_NOT_EXECUTE");\n');
  const endpoints = {};
  for (const name of cohorts.fleet) {
    const trigger = cohorts.callables.includes(name) ? { callableTrigger: {} } : cohorts.events.includes(name)
      ? { eventTrigger: { eventType: "google.cloud.firestore.document.v1.created", eventFilters: { database: "(default)" },
        eventFilterPathPatterns: { document: "offline/{id}" }, retry: false, region: "asia-south1" } }
      : { scheduleTrigger: { schedule: "every 24 hours", timeZone: "Etc/UTC" } };
    endpoints[name] = { platform: "gcfv2", region: ["asia-south1"], entryPoint: name, ...trigger };
  }
  write(path.join(project, "functions/functions.yaml"), { specVersion: "v1alpha1", endpoints, params: [], requiredAPIs: [] });
  return project;
}
function runSample(run, phase) {
  assert(execution.PHASES.includes(phase));
  const root = path.join(run.root, phase);
  fs.mkdirSync(root); const source = path.join(root, "source"), scratch = path.join(source, "scratch");
  fs.mkdirSync(source); fs.mkdirSync(scratch);
  for (const name of ["business31CaptureBootstrap.cjs", "runtimeDeploymentTransportGuard31.cjs", "business31ServiceIdentityCapture.cjs",
    "backendRuntimeAdmission31.cjs", "backendRuntimeEvidenceAccess31.cjs"]) {
    fs.copyFileSync(path.resolve(__dirname, "..", name), path.join(source, name), fs.constants.COPYFILE_EXCL);
  }
  for (const name of ["business31CliDeployFixture.cjs", "business31CliOfflineFence.cjs", "business31CliSyntheticKernel.cjs"]) {
    fs.copyFileSync(path.join(__dirname, name), path.join(source, name), fs.constants.COPYFILE_EXCL);
  }
  assert.equal(sha(fs.readFileSync(path.join(source, "business31CaptureBootstrap.cjs"))),
    sha(fs.readFileSync(path.resolve(__dirname, "../business31CaptureBootstrap.cjs"))));
  write(path.join(source, "business31CaptureBootstrap.test.cjs"), '"use strict";\nmodule.exports = require("./business31CliDeployFixture.cjs");\n');
  const project = syntheticProject(scratch, run.cohorts, run.functionsConfiguration), projectFiles = bootstrap.sourceMap(project);
  const kernelMetadata = write(path.join(scratch, kernel.KERNEL_RELATIVE), kernel.KERNEL_TEXT);
  const plan = execution.fixedCohortPlan({ ok: true, proposalOnly: true, deploymentAuthorized: false,
    cohorts: run.cohorts, projectId: PROJECT, region: "asia-south1",
    runtime: { nodeExecutable: process.execPath, cliEntrypoint: run.runtime.cliEntrypoint } }, phase);
  // The fixed bootstrap requires empty execArgv. The real CLI receives exactly the planner's deploy arguments.
  const cliArguments = plan.arguments.slice(2);
  const selection = { mode: run.mode, phase, scratch, project, projectFiles, kernelMetadata,
    functionsConfiguration: run.functionsConfiguration, sourceFirebaseConfiguration: run.sourceFirebaseConfiguration,
    names: plan.functionNames, cohorts: run.cohorts, cliArguments,
    permissionRoutes: [
      "POST https://cloudresourcemanager.googleapis.com/v1/projects/" + PROJECT + ":testIamPermissions",
      "POST https://iam.googleapis.com/v1/projects/" + PROJECT + "/serviceAccounts/" + PROJECT + "@appspot.gserviceaccount.com:testIamPermissions"
    ] };
  write(path.join(source, "CASE.json"), selection);
  const sourceFiles = bootstrap.sourceMap(source);
  const request = write(path.join(root, "REQUEST.json"), { schemaVersion: 1, operation: "component-test",
    suite: "bootstrap-regressions", caseId: "installed-positive", componentData: { runtime: run.runtime },
    sourceRoot: source, sourceFiles, nodeExecutable: process.execPath, nodeSha256: run.nodeSha256, gitExecutable: null, nonOperational: true });
  const env = environment(scratch), argv = [path.join(source, "business31CaptureBootstrap.cjs"), "--component-child", request.path, request.sha256];
  write(path.join(root, "LAUNCH.json"), { executable: process.execPath, argv, cwd: project, environment: env,
    timeoutMs: 600000, maxBuffer: 64 * 1024 * 1024, stdin: "closed", windowsHide: true });
  const started = new Date().toISOString();
  const native = cp.spawnSync(process.execPath, argv, { cwd: project, env, windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"], timeout: 600000, killSignal: "SIGKILL", maxBuffer: 64 * 1024 * 1024 });
  // Retain every native outcome before parsing or asserting anything about it.
  const stdout = write(path.join(root, "stdout.bin"), native.stdout ?? Buffer.alloc(0));
  const stderr = write(path.join(root, "stderr.bin"), native.stderr ?? Buffer.alloc(0));
  const result = { status: native.status, signal: native.signal, error: native.error ? { code: native.error.code, message: native.error.message } : null,
    startedAtUtc: started, completedAtUtc: new Date().toISOString(), stdout, stderr, request, phase, mode: run.mode };
  write(path.join(root, "NATIVE_RESULT.json"), result);
  const eventsFile = path.join(scratch, "events.jsonl");
  let events = [], parseError = null;
  try { events = fs.readFileSync(eventsFile, "utf8").trim().split("\n").filter(Boolean).map(line => JSON.parse(line)); }
  catch (caught) { parseError = caught.message; }
  const exits = events.filter(event => event.kind === "PROCESS_EXIT");
  const report = { ...result, root, events, parseError, final: exits.length === 1 ? exits[0] : null,
    validEventSequence: events.every((event, i) => event.sequence === i + 1), finalRecordIsLast: exits.length === 1 && events.at(-1) === exits[0],
    controllerInvoked: false, controllerTraversalSucceeded: false, originalReleaseInvoked: false };
  write(path.join(root, "CASE_REPORT.json"), report);
  return report;
}
function assertPrepareSample(report) {
  const message = "Retained CLI sample: " + report.root + "\nDenied boundary observations: "
    + JSON.stringify(report.events.filter(event => ["DENIED", "DENIED_FILESYSTEM_READ"].includes(event.kind)), null, 2);
  assert.equal(report.error, null, message); assert.equal(report.signal, null, message); assert.equal(report.status, 1, message);
  assert.equal(report.parseError, null, message); assert.equal(report.validEventSequence, true, message); assert.equal(report.finalRecordIsLast, true, message);
  const final = report.final; assert(final, message);
  assert.equal(final.effectiveExitCode, report.status, message);
  assert.equal(final.sentinel, STOP_PREPARE, message); assert.equal(final.prepareEntries, 1, message);
  assert.equal(final.originalPrepareEntries, 0, message); assert.equal(final.originalPrepareCompleted, 0, message); assert.equal(final.releaseEntries, 0, message);
  assert.equal(final.guardHealthy, true, message); assert.equal(final.cleanupComplete, true, message);
  for (const field of ["denials", "errors", "unmatched", "guardRejections"]) assert.deepEqual(final[field], [], message);
  assert.equal(final.fixtureCalls.length, 2, message);
  const failureKinds = new Set(["DENIED", "UNMATCHED_FIXTURE_REQUEST", "TRANSPORT_GUARD_REJECTION", "FIXTURE_OR_ENTRY_ERROR", "CLEANUP_ERROR", "UNCAUGHT_ERROR", "ORIGINAL_PREPARE_ERROR"]);
  assert.deepEqual(report.events.filter(event => failureKinds.has(event.kind)), [], message);
  assert.equal(report.events.filter(event => event.kind === "PREPARE_ENTRY").length, 1, message);
  assert.equal(report.events.filter(event => event.kind === "EXPECTED_STOP" && event.marker === STOP_PREPARE).length, 1, message);
  assert.equal(report.events.filter(event => event.kind === "FIXTURE_RESPONSE").length, 2, message);
  const combined = fs.readFileSync(report.stdout.path, "utf8") + fs.readFileSync(report.stderr.path, "utf8");
  assert.match(combined, new RegExp(STOP_PREPARE), message);
  assert(!/BUSINESS_CLI_LOAD_INTEGRITY|OFFLINE_BOUNDARY_DENIED|OFFLINE_UNMATCHED_FIXTURE_REQUEST|An unexpected error has occurred/.test(combined), message);
}
function assertPopulationUnchanged(run) {
  assert.deepEqual(bootstrap.sourceMap(run.cliRoot), run.files, "Installed CLI bytes changed; retained run " + run.root);
  assert.equal(sha(fs.readFileSync(run.sourceFirebaseConfiguration.path)), run.sourceFirebaseConfiguration.sha256,
    "Source Firebase configuration changed; retained run " + run.root);
}
module.exports = { createRun, runSample, assertPrepareSample, assertPopulationUnchanged, write, PHASES: execution.PHASES };