"use strict";
// Explicit diagnostics: a refused controller component entry and three independent real CLI samples.
// A stopped or rejected sample never establishes an admitted controller traversal or release success.
const fs = require("node:fs"), path = require("node:path"), cp = require("node:child_process");
const crypto = require("node:crypto"), assert = require("node:assert/strict");
const driver = require("./testdata/business31CliDeployDriver.cjs");
const bootstrap = require("./business31CaptureBootstrap.cjs");
const sha = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const STOP_RELEASE = "BUSINESS31_OFFLINE_RELEASE_ENTRY_STOP";
const CONTROLLER_REFUSAL = "component entry cannot authorize operational dispatch";
const FAILURE_KINDS = new Set(["DENIED", "UNMATCHED_FIXTURE_REQUEST", "TRANSPORT_GUARD_REJECTION",
  "FIXTURE_OR_ENTRY_ERROR", "CLEANUP_ERROR", "UNCAUGHT_ERROR", "ORIGINAL_PREPARE_ERROR"]);

// Serialized into the exclusive source-bound component fixture; never called in the parent.
async function controllerAdmissionCase(caseId, data) {
  const fs = require("node:fs"), path = require("node:path"), assert = require("node:assert/strict");
  assert.equal(caseId, "environment-positive"); assert.equal(data, null);
  const selection = JSON.parse(fs.readFileSync(path.join(__dirname, "ADMISSION_CASE.json"), "utf8"));
  const rawWrite = fs.writeSync, fd = fs.openSync(path.join(selection.scratch, "events.jsonl"), "wx");
  let sequence = 0, controllerEntries = 0, expectedRefusal = false;
  const errors = [];
  const event = value => {
    const bytes = Buffer.from(JSON.stringify({ sequence: ++sequence, ...value }) + "\n");
    if (sequence > 1024 || bytes.length > 65536 || rawWrite(fd, bytes) !== bytes.length) throw Error("OFFLINE_EVENT_BOUND_OR_WRITE");
  };
  const safety = require("./testdata/business31CliOfflineFence.cjs").installOfflineFence({
    scratch: selection.scratch, source: __dirname, cliRoot: __dirname, readFiles: [process.execPath], event
  });
  process.on("uncaughtExceptionMonitor", error => {
    errors.push({ message: error.message, stack: error.stack });
    event({ kind: "UNCAUGHT_ERROR", message: error.message, stack: error.stack });
  });
  process.once("exit", code => {
    if (safety.denials.length || errors.length || !expectedRefusal) process.exitCode = 1;
    event({ kind: "PROCESS_EXIT", code, effectiveExitCode: process.exitCode ?? code, controllerEntries,
      expectedRefusal, denials: safety.denials, errors, operationalDispatchAdmitted: false,
      phaseLaunchCount: expectedRefusal ? 0 : null, realCliInvoked: false, networkForwarded: false });
    // Leave the descriptor open: late exit callbacks must still be recorded before EOF.
  });
  try {
    const controller = require("./business31OperationalController.cjs");
    controllerEntries++;
    event({ kind: "CONTROLLER_ENTRY", entry: "runController31", componentEntry: true });
    // No decision, credentials, source authority, custody or prior phase is fabricated.
    await controller.runController31({});
    throw Error("UNEXPECTED_CONTROLLER_DISPATCH_RETURNED");
  } catch (error) {
    expectedRefusal = error.message === "component entry cannot authorize operational dispatch";
    if (!expectedRefusal) errors.push({ message: error.message, stack: error.stack });
    event({ kind: expectedRefusal ? "CONTROLLER_ADMISSION_REFUSED" : "CONTROLLER_ERROR",
      message: error.message, stack: error.stack });
    throw error;
  }
}

function runControllerAdmissionSample(run) {
  const root = path.join(run.root, "controller-admission");
  fs.mkdirSync(root);
  const source = path.join(root, "source"), scratch = path.join(root, "scratch");
  fs.mkdirSync(scratch);
  const originalFiles = bootstrap.sourceMap(__dirname);
  fs.cpSync(__dirname, source, { recursive: true, dereference: false, verbatimSymlinks: true,
    force: false, errorOnExist: true });
  assert.deepEqual(bootstrap.sourceMap(source), originalFiles);
  driver.write(path.join(root, "ORIGINAL_HELPER_FILES.json"), originalFiles);
  const suiteFile = path.join(source, "business31CaptureBootstrap.test.cjs");
  driver.write(path.join(root, "ORIGINAL_BOOTSTRAP_TEST.cjs"), fs.readFileSync(suiteFile));
  // Only the private component test dispatch is replaced; bootstrap/controller/producers are unchanged.
  fs.writeFileSync(suiteFile, '"use strict";\nmodule.exports = { runCase: ' + controllerAdmissionCase.toString() + ' };\n');
  driver.write(path.join(source, "ADMISSION_CASE.json"), { scratch });
  const selectedFiles = bootstrap.sourceMap(source);
  const modified = Object.keys(originalFiles).filter(name => originalFiles[name] !== selectedFiles[name]);
  assert.deepEqual(modified, ["business31CaptureBootstrap.test.cjs"]);
  assert.deepEqual(Object.keys(selectedFiles).filter(name => !Object.hasOwn(originalFiles, name)), ["ADMISSION_CASE.json"]);
  const request = driver.write(path.join(root, "REQUEST.json"), {
    schemaVersion: 1, operation: "component-test", suite: "bootstrap-regressions", caseId: "environment-positive",
    componentData: null, sourceRoot: source, sourceFiles: selectedFiles,
    nodeExecutable: process.execPath, nodeSha256: sha(fs.readFileSync(process.execPath)), gitExecutable: null, nonOperational: true
  });
  const env = {};
  for (const key of ["SystemRoot", "SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT"]) {
    if (process.env[key] !== undefined) env[key] = process.env[key];
  }
  for (const key of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CLOUDSDK_CONFIG", "TEMP", "TMP"]) {
    env[key] = path.join(scratch, key); fs.mkdirSync(env[key]);
  }
  Object.assign(env, { PATH: path.dirname(process.execPath), CI: "true", NO_COLOR: "1", NO_UPDATE_NOTIFIER: "1" });
  const argv = [path.join(source, "business31CaptureBootstrap.cjs"), "--component-child", request.path, request.sha256];
  driver.write(path.join(root, "LAUNCH.json"), { executable: process.execPath, argv, cwd: scratch, environment: env,
    timeoutMs: 600000, maxBuffer: 64 * 1024 * 1024, stdin: "closed", windowsHide: true });
  const startedAtUtc = new Date().toISOString();
  const native = cp.spawnSync(process.execPath, argv, { cwd: scratch, env, windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"], timeout: 600000, killSignal: "SIGKILL", maxBuffer: 64 * 1024 * 1024 });
  const stdout = driver.write(path.join(root, "stdout.bin"), native.stdout ?? Buffer.alloc(0));
  const stderr = driver.write(path.join(root, "stderr.bin"), native.stderr ?? Buffer.alloc(0));
  const result = { startedAtUtc, completedAtUtc: new Date().toISOString(), status: native.status, signal: native.signal,
    error: native.error ? { code: native.error.code, message: native.error.message } : null, stdout, stderr, request };
  driver.write(path.join(root, "NATIVE_RESULT.json"), result);
  let events = [], parseError = null;
  try { events = fs.readFileSync(path.join(scratch, "events.jsonl"), "utf8").trim().split("\n").filter(Boolean).map(line => JSON.parse(line)); }
  catch (error) { parseError = error.message; }
  const exits = events.filter(event => event.kind === "PROCESS_EXIT"), final = exits.length === 1 ? exits[0] : null;
  const text = fs.readFileSync(stdout.path, "utf8") + fs.readFileSync(stderr.path, "utf8");
  const expectedAdmissionRefusal = native.status === 1 && !native.error && !native.signal && !parseError
    && events.every((event, i) => event.sequence === i + 1) && final && final === events.at(-1)
    && final.effectiveExitCode === native.status && final.controllerEntries === 1 && final.expectedRefusal
    && final.phaseLaunchCount === 0 && final.realCliInvoked === false && !final.denials.length && !final.errors.length
    && events.filter(event => event.kind === "CONTROLLER_ENTRY").length === 1
    && events.filter(event => event.kind === "CONTROLLER_ADMISSION_REFUSED" && event.message === CONTROLLER_REFUSAL).length === 1
    && !events.some(event => ["DENIED", "UNCAUGHT_ERROR", "CONTROLLER_ERROR"].includes(event.kind))
    && text.includes(CONTROLLER_REFUSAL) && !/AggregateError|cleanup failed|OFFLINE_BOUNDARY_DENIED/.test(text);
  const report = { ...result, root, events, parseError, expectedAdmissionRefusal: !!expectedAdmissionRefusal,
    controllerInvoked: events.some(event => event.kind === "CONTROLLER_ENTRY"), componentEntry: true,
    operationalDispatchAdmitted: false, controllerTraversalSucceeded: false, productionAuthority: false,
    phaseLaunchCount: expectedAdmissionRefusal ? 0 : null, realCliInvoked: false,
    scope: "Actual unchanged controller refuses the non-operational component entry; full controller traversal remains blocked." };
  driver.write(path.join(root, "CASE_REPORT.json"), report);
  return report;
}

function assessPreReleaseSample(report) {
  const final = report.final, failureEvents = report.events.filter(event => FAILURE_KINDS.has(event.kind));
  const completeThroughReleaseEntry = report.status === 1 && !report.error && !report.signal && !report.parseError
    && report.validEventSequence && report.finalRecordIsLast && final?.effectiveExitCode === report.status
    && final.sentinel === STOP_RELEASE && final.prepareEntries === 1 && final.originalPrepareEntries === 1
    && final.originalPrepareCompleted === 1 && final.releaseEntries === 1 && final.guardHealthy && final.cleanupComplete
    && !final.errors.length && !final.denials.length && !final.unmatched.length && !final.guardRejections.length
    && failureEvents.length === 0
    && report.events.filter(event => event.kind === "PREPARE_ENTRY").length === 1
    && report.events.filter(event => event.kind === "ORIGINAL_PREPARE_COMPLETED").length === 1
    && report.events.filter(event => event.kind === "EXPECTED_STOP" && event.marker === STOP_RELEASE).length === 1;
  return { phase: report.phase, report: path.join(report.root, "CASE_REPORT.json"), nativeStatus: report.status,
    error: report.error, signal: report.signal, parseError: report.parseError,
    prepareEntries: final?.prepareEntries ?? 0, originalPrepareEntries: final?.originalPrepareEntries ?? 0,
    originalPrepareCompleted: final?.originalPrepareCompleted ?? 0, releaseEntries: final?.releaseEntries ?? 0,
    guardHealthy: final?.guardHealthy ?? false, cleanupComplete: final?.cleanupComplete ?? false,
    guardRejections: final?.guardRejections ?? [], denied: final?.denials ?? [], unmatched: final?.unmatched ?? [],
    errors: final?.errors ?? [], failureEvents, sentinel: final?.sentinel ?? null,
    completeThroughReleaseEntry: !!completeThroughReleaseEntry, productionAuthority: false };
}
function main() {
  if (process.argv.length !== 3 || process.argv[2] !== "--offline") throw Error("Use --offline only");
  const run = driver.createRun("pre-release"), phases = [];
  let controllerAdmission;
  try { controllerAdmission = runControllerAdmissionSample(run); }
  catch (error) { controllerAdmission = { expectedAdmissionRefusal: false, setupFailure: { message: error.message, stack: error.stack } }; }
  for (const phase of driver.PHASES) {
    try { phases.push(assessPreReleaseSample(driver.runSample(run, phase))); }
    catch (error) { phases.push({ phase, completeThroughReleaseEntry: false, setupFailure: { message: error.message, stack: error.stack } }); }
  }
  let preservationError = null;
  try { driver.assertPopulationUnchanged(run); } catch (error) { preservationError = error.message; }
  const samplesReachedReleaseEntry = !preservationError && phases.length === 3 && phases.every(row => row.completeThroughReleaseEntry);
  const summary = { status: "OFFLINE_REHEARSAL_BLOCKED", controllerAdmission, phases, samplesReachedReleaseEntry,
    preservationError, root: run.root, controllerInvoked: controllerAdmission.controllerInvoked ?? false,
    controllerTraversalSucceeded: false, productionAuthority: false, syntheticDiscoveryManifest: true,
    syntheticReadResponses: true, actualSdkDiscoveryExecuted: false, productionControlOrCustodyAdmissionClaimed: false,
    preparedComparisonFabricated: false, originalReleaseInvoked: false, automaticRetry: false,
    limitation: "The actual controller refuses a fenced component entry. Independent CLI phase samples are not a successful controller traversal." };
  driver.write(path.join(run.root, "REHEARSAL.json"), summary);
  process.stdout.write(JSON.stringify(summary, null, 2) + "\n");
  process.exitCode = 1;
}
if (require.main === module) main();