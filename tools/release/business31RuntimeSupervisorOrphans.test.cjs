"use strict";
// Portable measured-source loading plus real Windows private-job regressions.
// These fresh local fixtures carry no credential or production authority.
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path");
const { spawnSync } = require("node:child_process");

const python = process.env.BUSINESS31_TEST_PYTHON || (process.platform === "win32" ? "C:/Python313/python.exe" : "python3");
const evidence = path.resolve(__dirname, "../../.dart_tool/supervisor-regression-tests");
fs.mkdirSync(evidence, { recursive: true });
const root = fs.mkdtempSync(path.join(evidence, "run-"));
const env = {};
for (const key of ["SystemRoot", "WINDIR", "PATH"]) if (process.env[key] !== undefined) env[key] = process.env[key];
Object.assign(env, { HOME: root, USERPROFILE: root, TEMP: root, TMP: root,
  SUPERVISOR_SOURCE_TEST_ROOT: path.join(root, "source"),
  SUPERVISOR_ORPHAN_TEST_ROOT: path.join(root, "orphans") });
console.log("Retained supervisor regression fixtures: " + root);

for (const script of ["test_runtime_supervisor_source.py", "test_runtime_supervisor_orphans.py"]) {
  test("supervisor regression " + script, { timeout: 120000 }, () => {
    const argv = ["-I", "-S", "-B", path.join(__dirname, script)];
    const native = spawnSync(python, argv, { env, cwd: __dirname, windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"], timeout: 90000, maxBuffer: 8 * 1024 * 1024 });
    fs.writeFileSync(path.join(root, script + ".stdout.bin"), native.stdout || Buffer.alloc(0), { flag: "wx" });
    fs.writeFileSync(path.join(root, script + ".stderr.bin"), native.stderr || Buffer.alloc(0), { flag: "wx" });
    fs.writeFileSync(path.join(root, script + ".result.json"), JSON.stringify({
      executable: python, argv, status: native.status, signal: native.signal,
      error: native.error ? { code: native.error.code, message: native.error.message } : null,
      platform: process.platform, nativeWindowsJobCases: process.platform === "win32",
      providerOperation: false, credentialRead: false,
    }, null, 2) + "\n", { flag: "wx" });
    const detail = (native.stdout || "").toString() + (native.stderr || "").toString();
    assert.equal(native.error, undefined, detail);
    assert.equal(native.signal, null, detail);
    assert.equal(native.status, 0, detail);
    if (script.endsWith("orphans.py")) {
      assert.match(detail, /Ran 9 tests/);
      if (process.platform === "win32") {
        assert.match(detail, /\bOK\s*$/);
        assert.doesNotMatch(detail, /skipped=/);
      } else {
        assert.match(detail, /OK \(skipped=7\)/);
      }
    }
  });
}
