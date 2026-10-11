"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const sourceFile = path.join(__dirname, "business31CaptureSession.cjs");
const source = fs.readFileSync(sourceFile, "utf8");
const map = source.match(/const PINS = Object\.freeze\(\{([\s\S]*?)\n\}\);/);
assert.ok(map, "capture session keeps its finite literal dependency map");
const dependencies = [...map[1].matchAll(/"([^"\r\n]+\.(?:cjs|py|json))": "[A-F0-9]{64}"/g)].map(row => row[1]);
assert.ok(dependencies.length > 0);
const helper = "business31NpmBinMaterialization.cjs";
const scratch = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "business31-capture-pins-"));
function copy(label) {
  const root = path.join(scratch, label);
  fs.mkdirSync(root);
  for (const name of new Set(["business31CaptureSession.cjs", ...dependencies, helper]))
    fs.copyFileSync(path.join(__dirname, name), path.join(root, name));
  const subject = require(path.join(root, "business31CaptureSession.cjs"));
  return {root, subject, helperPath: path.join(root, helper)};
}
test("capture verifies the new preparation dependency before importing or installing hooks", () => {
  const good = copy("exact");
  assert.doesNotThrow(() => good.subject.verifyCopies());
  assert.equal(require.cache[good.helperPath], undefined);
  const slots = [[require("node:https"), "request"], [require("node:http"), "request"],
    [require("node:net").Socket.prototype, "connect"], [require("node:tls"), "connect"],
    [require("node:module"), "_load"], [globalThis, "fetch"]];
  const before = slots.map(([object, key]) => Object.getOwnPropertyDescriptor(object, key));
  for (const dependency of [helper, "business31ToolchainIdentity.cjs", "business31CaptureRecorder.cjs", "collectBusinessRuntime31.cjs", "runtime_process_runner.py", "runtime_supervisor.py", "runtime_contract_bindings.json", "business31ToolchainProfiles.json"]) {
    assert.ok(dependencies.includes(dependency), "new dependency is pinned before import");
    for (const label of ["modified", "missing"]) {
      const f = copy(dependency + "-" + label), target = path.join(f.root, dependency);
      if (label === "modified") fs.writeFileSync(target, "throw Error('UNVERIFIED_HELPER_EXECUTED');\n");
      else fs.unlinkSync(target);
      assert.throws(() => new f.subject.BusinessCaptureSession31({}),
        label === "modified" ? /frozen dependency differs/ : /ENOENT/);
      assert.equal(require.cache[target], undefined);
      assert.deepEqual(slots.map(([object, key]) => Object.getOwnPropertyDescriptor(object, key)), before);
    }
  }
});

// Validate actual checked-in producer bytes: copying a synthetic binding table
// alone can hide stale entries that the real preparation/collector entrypoints read.
test("runtime contract table binds every checked-in producer", () => {
  const crypto = require("node:crypto");
  const contracts = JSON.parse(fs.readFileSync(path.join(__dirname, "runtime_contract_bindings.json"), "utf8"));
  assert.equal(Object.keys(contracts).length, 14);
  for (const [name, expected] of Object.entries(contracts)) {
    assert.match(name, /^[A-Za-z0-9]+\.cjs$/);
    const actual = crypto.createHash("sha256").update(fs.readFileSync(path.join(__dirname, name))).digest("hex").toUpperCase();
    assert.equal(actual, expected, "runtime contract binding differs: " + name);
  }
});
test("real Windows preflights pass contract bindings before rejecting an untrusted Git executable", {
  skip: process.platform !== "win32" ? "Original preparation and collection preflights require Windows" : false
}, () => {
  const cp = require("node:child_process");
  const preparation = require("./prepareBusinessIntent31.cjs");
  const collection = require("./collectBusinessRuntime31.cjs");
  const attemptRoot = path.join(scratch, "must-remain-absent");
  const common = {
    schemaVersion: 1, repositoryRoot: __dirname, gitExecutable: process.execPath, gitSha256: "0".repeat(64),
    source: {commit: "1".repeat(40), tree: "2".repeat(40), functionsTree: "3".repeat(40)},
    attemptRoot, afterCi: "2020-01-01T00:00:00Z", python: null,
    limits: {commandSeconds: 1, cleanupSeconds: 1, outputBytes: 1024}
  };
  const options = [
    () => preparation.preflightBusinessIntent31({...common, evidenceDirectory: scratch, runtimeProof: null,
      projectConfigOriginal: null, parametersOriginal: null, systemRoot: null}),
    () => collection.preflightBusinessRuntime31({...common, runtime: {nodeVersion: "synthetic", npmVersion: "synthetic",
      toolchainProfileId: "synthetic", nodeExecutable: null, npmCliFile: null, npmPackageRoot: null}, windows: null})
  ];
  const methods = ["spawn", "spawnSync", "exec", "execSync", "execFile", "execFileSync", "fork"];
  const original = Object.fromEntries(methods.map(name => [name, cp[name]]));
  let childCalls = 0;
  try {
    for (const name of methods) cp[name] = () => { childCalls++; throw Error("Unexpected child process in read-only preflight regression"); };
    const errors = options.map(run => { try { run(); return null; } catch (error) { return error; } });
    assert.equal(childCalls, 0);
    assert.equal(fs.existsSync(attemptRoot), false);
    for (const error of errors) {
      assert.ok(error instanceof Error, "original preflight must reject the intentionally untrusted Git executable");
      assert.match(error.message, /Git executable digest differs/);
    }
  } finally {
    for (const name of methods) cp[name] = original[name];
  }
});
