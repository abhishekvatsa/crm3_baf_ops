"use strict";
// Exercise the executable facade, not its different ordinary-require branch.
// All authority and CLI data below are private synthetic fixtures, never deployment evidence.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const crypto = require("node:crypto"), cp = require("node:child_process"), Module = require("node:module");
const { createCaptureFixture31 } = require("./business31CaptureFixture.cjs");
const hash = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const CAPTURE = "captureBusiness31PreparedInputs.cjs", BOOTSTRAP = "business31CaptureBootstrap.cjs";
const HOOK = "captureBusiness31PreparedHook.cjs", SESSION = "business31CaptureSession.cjs";
const CONTROLLER = "business31OperationalController.cjs";
const out = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "business31-capture-entry-"));
function save(file, value) {
  const bytes = Buffer.from(JSON.stringify(value, null, 2) + "\n");
  fs.writeFileSync(file, bytes, { flag: "wx" });
  return { file: path.basename(file), sha256: hash(bytes), bytes: bytes.length };
}
function inventory(root) {
  const result = {};
  function walk(directory) {
    for (const name of fs.readdirSync(directory).sort()) {
      const file = path.join(directory, name), stat = fs.lstatSync(file);
      assert.equal(stat.isSymbolicLink(), false);
      if (stat.isDirectory()) walk(file);
      else {
        assert.equal(stat.isFile(), true);
        result[path.relative(root, file).split(path.sep).join("/")] = hash(fs.readFileSync(file));
      }
    }
  }
  walk(root);
  return result;
}
function environment(directory) {
  const result = {};
  for (const [name, value] of Object.entries(process.env))
    if (["SYSTEMROOT", "WINDIR", "COMSPEC", "PATHEXT", "PATH", "LANG", "LC_ALL"].includes(name.toUpperCase())) result[name] = value;
  for (const name of ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "TEMP", "TMP"]) {
    result[name] = path.join(directory, name);
    fs.mkdirSync(result[name]);
  }
  return result;
}

// This function is serialized into a private replacement controller. The actual
// facade/bootstrap, recorder, hook and session remain byte copies of the selected source.
async function fixturePhase({ configuration }) {
  const assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path");
  const crypto = require("node:crypto"), Module = require("node:module"), cp = require("node:child_process");
  const hash = bytes => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
  const fixture = configuration.syntheticFixture;
  const bootstrap = require("./business31CaptureBootstrap.cjs");
  bootstrap.assertOperational31();
  assert.equal(require.main.filename, path.join(__dirname, "captureBusiness31PreparedInputs.cjs"));
  assert.deepEqual(process.argv.slice(2), ["--config", fixture.contextFile]);
  const facade = require.main, facadeExports = Object.getOwnPropertyDescriptor(facade, "exports");
  assert.deepEqual(Object.keys(facade.exports), []);

  let blockedCalls = 0, gitReads = 0;
  const blocked = () => { blockedCalls++; throw Error("EXTERNAL OPERATION FORBIDDEN"); };
  const execFileSync = cp.execFileSync;
  cp.execFileSync = (file, args, options) => {
    assert.equal(file, "git");
    const at = args.indexOf("-C");
    assert.equal(args[at + 1], fixture.repository);
    assert.deepEqual(args.slice(at + 2, at + 3), ["rev-parse"]);
    assert.ok(["HEAD", fixture.source.commit + "^{tree}", fixture.source.commit + ":functions"].includes(args.at(-1)));
    assert.equal(args.length, at + 4);
    gitReads++;
    return execFileSync(file, args, { ...options, timeout: 30000, maxBuffer: 1024 * 1024 });
  };
  for (const name of ["spawn", "spawnSync", "exec", "execSync", "execFile", "fork"]) cp[name] = blocked;
  const transport = [
    [require("node:http"), "request"], [require("node:http"), "get"],
    [require("node:https"), "request"], [require("node:https"), "get"],
    [require("node:net").Socket.prototype, "connect"], [require("node:tls"), "connect"],
    [require("node:dgram"), "createSocket"], [require("node:dns"), "lookup"],
    [require("node:dns"), "resolve"], [globalThis, "fetch"]
  ];
  for (const [object, name] of transport) object[name] = blocked;

  const recorder = require("./business31CaptureRecorder.cjs");
  const outer = recorder.installCliLoadBoundary31(fixture.runtime);
  let session = null, prepared = null;
  try {
    const envelopeBytes = Buffer.from(fixture.envelopeBase64, "base64");
    const admission = { repoRoot: fixture.repository, source: fixture.source,
      approvalPointer: fixture.approvalPointer, cohorts: fixture.cohorts,
      projectId: "crm3-baf-ops-b8638", region: "asia-south1", runtime: fixture.runtime };
    // Start with the same direct hook initialization that failed in the real
    // phase, so the original-source red case preserves that exact failure.
    const hookModule = require("./captureBusiness31PreparedHook.cjs");
    const directWriter = new recorder.BusinessCapture31({ evidenceDirectory: fixture.directEvidenceDirectory,
      source: fixture.source, approvalPointer: fixture.approvalPointer, cohorts: fixture.cohorts });
    prepared = hookModule.installBusinessPreparedHook31({ writer: directWriter, phase: "callables", admission,
      envelopeBytes, archiveExpectedFiles: {}, guardInputs: {} });
    assert.equal(prepared.state(), "installed");
    prepared.restore();
    prepared = null;
    outer.assertHealthy();
    const { BusinessCaptureSession31 } = require("./business31CaptureSession.cjs");
    session = new BusinessCaptureSession31({ evidenceDirectory: fixture.evidenceDirectory,
      source: fixture.source, approvalPointer: fixture.approvalPointer, cohorts: fixture.cohorts,
      admission, envelopeBytes, archiveExpectedFiles: {}, guardInputs: {}, observeLive: blocked });
    assert.equal(session.writerModule, recorder);
    session.cliLoadLease.assertHealthy();
    prepared = require("./captureBusiness31PreparedHook.cjs").installBusinessPreparedHook31({
      writer: session.writer, phase: "callables", admission, envelopeBytes,
      archiveExpectedFiles: {}, guardInputs: {}
    });
    assert.equal(prepared.state(), "installed");
    assert.equal(gitReads, 6);
    // Release the real hook lease, then the real session lease, then the owner.
    prepared.restore();
    prepared = null;
    session.cliLoadLease.assertOwned();
    session.cliLoadLease.assertHealthy();
    const sessionLease = session.cliLoadLease;
    session.dispose(); // A measurement-only fixture deliberately starts no cohort.
    assert.equal(session.state, "disposed");
    assert.equal(session.cleanupIncomplete, false);
    assert.equal(sessionLease.isReleased(), true);
    assert.equal(session.cliLoadLease, null);
    session = null;
    outer.assertOwned();
    outer.assertHealthy();
    assert.equal(blockedCalls, 0);
    for (const [object, name] of transport) assert.equal(object[name], blocked);
    assert.deepEqual(Object.getOwnPropertyDescriptor(facade, "exports"), facadeExports);
    assert.deepEqual(Object.keys(facade.exports), []);
    for (const name of Object.keys(require.cache)) {
      assert.ok(!/[/\\](?:auth|prepare|backend)\.js$/.test(name), "no credential or deployment module loaded");
      assert.notEqual(name, fixture.runtime.cliEntrypoint, "CLI entry is never imported");
    }
  } finally {
    if (prepared) prepared.restore();
    if (session) session.dispose();
    outer.release();
  }
  assert.equal(outer.isReleased(), true);
  // Registered after runOperationalPhaseMain31 installs its exit cleanup. The
  // result is written only after the real guard restores Node's original hooks.
  setImmediate(() => process.once("exit", () => {
    assert.equal(hash(Function.prototype.toString.call(Module._load)), fixture.pristineLoadSha256);
    assert.equal(hash(Function.prototype.toString.call(Module.registerHooks)), fixture.pristineRegisterSha256);
    assert.deepEqual(Object.getOwnPropertyDescriptor(facade, "exports"), facadeExports);
    fs.writeFileSync(fixture.resultFile, JSON.stringify({ syntheticLocalFixture: true,
      actualDeploymentEvidence: false, realCaptureMain: true, facadeExportsUnchanged: true,
      sessionAndHookInstalled: true, nestedLeasesReleased: true, freshGuardRestored: true,
      gitReadCount: gitReads, externalOperationCount: blockedCalls }) + "\n", { flag: "wx" });
  }));
}

function fixture(variant) {
  const directory = fs.mkdtempSync(path.join(out, variant + "-"));
  const sourceRoot = path.join(directory, "release"), evidenceDirectory = path.join(directory, "evidence");
  fs.cpSync(__dirname, sourceRoot, { recursive: true, errorOnExist: true, force: false });
  fs.mkdirSync(evidenceDirectory);
  const sourceBefore = inventory(__dirname), sourceAfterCopy = inventory(sourceRoot);
  assert.deepEqual(sourceAfterCopy, sourceBefore, "start from the exact selected helper population");
  let session = fs.readFileSync(path.join(sourceRoot, SESSION), "utf8");
  const pins = [...session.matchAll(/^  "([^"]+)": "([A-F0-9]{64})"/gm)];
  assert.equal(pins.length, 44);
  for (const [, name, sha256] of pins) assert.equal(sourceBefore[name], sha256, "original pin: " + name);
  const originalFacadeImport = 'require("./captureBusiness31PreparedInputs.cjs")';
  const recorderImport = 'require("./business31CaptureRecorder.cjs")';
  if (variant === "old-hook") {
    const file = path.join(sourceRoot, HOOK), original = fs.readFileSync(file, "utf8");
    assert.equal(original.split(recorderImport).length + original.split(originalFacadeImport).length, 3);
    fs.writeFileSync(file, original.replace(recorderImport, originalFacadeImport));
  } else if (variant === "old-session") {
    assert.equal(session.split(recorderImport).length + session.split(originalFacadeImport).length, 3);
    session = session.replace(recorderImport, originalFacadeImport);
  } else assert.equal(variant, "current");
  fs.writeFileSync(path.join(sourceRoot, CONTROLLER), '"use strict";\nmodule.exports={runPhaseChild31:' + fixturePhase.toString() + '};\n');
  // Only private-fixture replacements get new private pins. Production pins above
  // were independently checked against their actual selected source bytes.
  for (const name of [HOOK, CONTROLLER]) {
    const old = pins.find(row => row[1] === name)[2];
    session = session.replace('"' + name + '": "' + old + '"', '"' + name + '": "' + hash(fs.readFileSync(path.join(sourceRoot, name))) + '"');
  }
  fs.writeFileSync(path.join(sourceRoot, SESSION), session);
  assert.equal(hash(fs.readFileSync(path.join(sourceRoot, CAPTURE))), sourceBefore[CAPTURE]);
  assert.equal(hash(fs.readFileSync(path.join(sourceRoot, BOOTSTRAP))), sourceBefore[BOOTSTRAP]);
  assert.equal(hash(fs.readFileSync(path.join(sourceRoot, "business31CaptureRecorder.cjs"))), sourceBefore["business31CaptureRecorder.cjs"]);
  const base = createCaptureFixture31(directory);
  const cliRoot = path.join(directory, "cli/node_modules"), library = path.join(cliRoot, "firebase-tools/lib");
  const cliSources = {
    "apiv2.js": '"use strict";exports.Client=class Client{request(){throw Error("SYNTHETIC API MUST NOT RUN");}};\n',
    "deploy/functions/cache/applyHash.js": '"use strict";exports.applyBackendHashToBackends=function(){throw Error("SYNTHETIC HASH MUST NOT RUN");};\n',
    "deploy/functions/prepare.js": 'throw Error("PREPARE MUST NOT LOAD");\n',
    "deploy/functions/backend.js": 'throw Error("BACKEND MUST NOT LOAD");\n',
    "bin/firebase.js": 'throw Error("CLI ENTRY MUST NOT LOAD");\n'
  };
  for (const [name, text] of Object.entries(cliSources)) {
    const file = path.join(library, name);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, text, { flag: "wx" });
  }
  const cliMapFile = path.join(directory, "cli-file-bindings.json"), cliMap = save(cliMapFile, inventory(cliRoot));
  const runtime = { cliEntrypoint: path.join(library, "bin/firebase.js"),
    cliFileBindings: { path: cliMapFile, sha256: cliMap.sha256 },
    instrumentationProducerSha256: Object.fromEntries(Object.entries({ api: "apiv2.js", apply: "deploy/functions/cache/applyHash.js",
      prepare: "deploy/functions/prepare.js", backend: "deploy/functions/backend.js" }).map(([name, file]) => [name, hash(Buffer.from(cliSources[file]))])) };
  const retain = (name, value) => save(path.join(evidenceDirectory, name), value);
  const now = Date.now(), time = offset => new Date(now + offset).toISOString();
  const proof = retain("runtime-proof.json", { syntheticLocalFixture: true, actualDeploymentEvidence: false });
  const intent = retain("intent.json", { schemaVersion: 1, documentType: "firebase-cli-approved-intended-hash-inputs",
    codebase: "default", source: base.source, sourceBefore: base.source, sourceAfter: base.source, completedAtUtc: time(-3000) });
  const contract = retain("contract.json", { schemaVersion: 1, documentType: "build31-business-execution-contract",
    profile: "build31-exact-business-backend-v1", source: base.source, sourceManifestSha256: "A".repeat(64),
    runtimeProof: proof, preparedAtUtc: time(-2000), intendedHashInputs: intent });
  const decision = retain("decision.json", { schemaVersion: 2, documentType: "build31-business-backend-deployment-decision",
    profile: "build31-exact-business-backend-v1", source: base.source, sourceManifestSha256: "A".repeat(64),
    runtimeProof: proof, decidedAtUtc: time(-1000), executionContract: contract,
    executionWindow: { notBeforeUtc: time(-500), notAfterUtc: time(3600000) } });
  const envelope = Buffer.from(JSON.stringify({ schemaVersion: 1, documentType: "build31-business-private-record-custody",
    recordKind: "decision", source: base.source, privateRecord: decision }));
  const directEvidenceDirectory = path.join(directory, "hook-evidence");
  fs.mkdirSync(directEvidenceDirectory);
  for (const name of ["runtime-proof.json", "intent.json", "contract.json", "decision.json"])
    fs.copyFileSync(path.join(evidenceDirectory, name), path.join(directEvidenceDirectory, name), fs.constants.COPYFILE_EXCL);
  const cohorts = { callables: Array.from({ length: 13 }, (_, i) => "callable" + String(i).padStart(2, "0")),
    events: Array.from({ length: 5 }, (_, i) => "event" + i), schedulers: ["scheduler"] };
  cohorts.fleet = [...cohorts.callables, ...cohorts.events, ...cohorts.schedulers].sort();
  const selectedEnvironment = environment(directory), contextFile = path.join(directory, "context.json");
  const resultFile = path.join(directory, "entry-result.json");
  const configuration = { execution: { sourceRoot, helperFiles: inventory(sourceRoot), environment: selectedEnvironment,
    nodeExecutable: { path: process.execPath, sha256: hash(fs.readFileSync(process.execPath)) } },
    syntheticFixture: { repository: base.repository, source: base.source, evidenceDirectory, directEvidenceDirectory, cohorts, runtime,
      approvalPointer: { commit: "c".repeat(40), file: "release/approvals/build31-business-backend-deployment-approval.json", sha256: hash(envelope) },
      envelopeBase64: envelope.toString("base64"), contextFile, resultFile,
      pristineLoadSha256: hash(Function.prototype.toString.call(Module._load)),
      pristineRegisterSha256: hash(Function.prototype.toString.call(Module.registerHooks)) } };
  const config = retain("configuration.json", configuration);
  const context = save(contextFile, { evidenceDirectory, configuration: config });
  const argv = ["--no-global-search-paths", path.join(sourceRoot, CAPTURE), "--config", contextFile];
  const result = cp.spawnSync(process.execPath, argv, { cwd: directory,
    env: { ...selectedEnvironment, BUSINESS31_PHASE_CONTEXT_SHA256: context.sha256 },
    windowsHide: true, timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
  fs.writeFileSync(path.join(directory, "stdout.bin"), result.stdout ?? Buffer.alloc(0), { flag: "wx" });
  fs.writeFileSync(path.join(directory, "stderr.bin"), result.stderr ?? Buffer.alloc(0), { flag: "wx" });
  save(path.join(directory, "process-result.json"), { argv, status: result.status, signal: result.signal,
    error: result.error?.code ?? null, syntheticLocalFixture: true, actualDeploymentEvidence: false });
  assert.deepEqual(inventory(__dirname), sourceBefore, "selected source is preserved");
  assert.deepEqual(inventory(sourceRoot), configuration.execution.helperFiles, "private bound sources remain unchanged");
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  return { result, resultFile };
}

test("actual CAPTURE main loads real recorder consumers and closes nested leases and fresh guard", () => {
  const { result, resultFile } = fixture("current");
  assert.equal(result.status, 0, result.stderr.toString("utf8"));
  assert.equal(result.stderr.length, 0);
  assert.deepEqual(JSON.parse(fs.readFileSync(resultFile)), { syntheticLocalFixture: true, actualDeploymentEvidence: false,
    realCaptureMain: true, facadeExportsUnchanged: true, sessionAndHookInstalled: true, nestedLeasesReleased: true,
    freshGuardRestored: true, gitReadCount: 6, externalOperationCount: 0 });
});
for (const variant of ["old-hook", "old-session"]) test("actual CAPTURE main reproduces the cached-facade failure for " + variant, () => {
  const { result, resultFile } = fixture(variant);
  assert.equal(result.status, 1);
  assert.match(result.stderr.toString("utf8"), /(?:this\.)?writerModule\.installCliLoadBoundary31 is not a function/);
  assert.equal(fs.existsSync(resultFile), false);
});
