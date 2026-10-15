"use strict";
const assert = require("node:assert/strict"), fs = require("node:fs"), path = require("node:path");
const os = require("node:os"), cp = require("node:child_process"), crypto = require("node:crypto");
const { pathToFileURL } = require("node:url");
const kernel = require("./testdata/business31CliSyntheticKernel.cjs");
const { installOfflineFence } = require("./testdata/business31CliOfflineFence.cjs");
const sha = raw => crypto.createHash("sha256").update(raw).digest("hex").toUpperCase();
function child(root, mode) {
  const scratch = path.join(root, "scratch"), events = [], delegatedPaths = [];
  const rawWrite = fs.writeSync;
  let safety, report = { mode, complete: false };
  try {
    const fixturePath = path.join(scratch, kernel.KERNEL_RELATIVE);
    fs.mkdirSync(path.dirname(fixturePath), { recursive: true });
    fs.writeFileSync(fixturePath, kernel.KERNEL_TEXT, { flag: "wx" });
    const fixture = { path: fixturePath, sha256: sha(Buffer.from(kernel.KERNEL_TEXT)), bytes: Buffer.byteLength(kernel.KERNEL_TEXT) };
    const ordinaryPath = path.join(scratch, "ordinary.txt");
    fs.writeFileSync(ordinaryPath, "ordinary fixture", { flag: "wx" });
    safety = installOfflineFence({ scratch, source: path.join(root, "source"), cliRoot: path.join(root, "cli"),
      readFiles: [], event: row => events.push(row) });
    const fenced = fs.readFileSync;
    const delegated = function (file, ...args) { delegatedPaths.push(typeof file === "string" ? file : "<non-string>"); return fenced.apply(this, arguments); };
    fs.readFileSync = kernel.createSyntheticKernelReader({ readFileSync: delegated, fixture, scratch, event: row => events.push(row) });
    if (mode === "positive") {
      assert.equal(fs.readFileSync("/proc/version", "utf8"), kernel.KERNEL_TEXT);
      assert.equal(fs.readFileSync(ordinaryPath, "utf8"), "ordinary fixture");
      assert.deepEqual(delegatedPaths, [fixturePath, ordinaryPath]);
      assert.equal(events.filter(row => row.kind === "SYNTHETIC_KERNEL_METADATA_READ").length, 1);
      assert.deepEqual(safety.denials, []);
      kernel.verifySyntheticKernelFixture({ readFileSync: fenced, fixture, scratch });
      report = { ...report, complete: true, exactSyntheticReads: 1, ordinaryDelegationPassed: true };
    } else {
      assert.equal(mode, "negative");
      const cases = [
        ["/proc/version.extra", "utf8"], ["/proc/../proc/version", "utf8"], ["/proc/self/cgroup", "utf8"],
        [Buffer.from("/proc/version"), "utf8"], [pathToFileURL(path.resolve("/proc/version")), "utf8"],
        ["/proc/version", { encoding: "utf8" }], ["/proc/version", "utf-8"], ["/proc/version", "ascii"],
        ["/proc/version"], ["/proc/version", null], ["/proc/version", "utf8", undefined], [42, "utf8"]
      ];
      for (const args of cases) {
        assert.throws(() => fs.readFileSync(...args), error => error.code === "OFFLINE_BOUNDARY_DENIED");
      }
      assert.equal(safety.denials.length, cases.length);
      assert.equal(events.filter(row => row.kind === "DENIED").length, cases.length);
      assert.equal(events.filter(row => row.kind === "SYNTHETIC_KERNEL_METADATA_READ").length, 0);
      const count = safety.denials.length;
      fs.writeFileSync(fixturePath, kernel.KERNEL_TEXT.replace("Linux", "Lunix"));
      assert.throws(() => fs.readFileSync("/proc/version", "utf8"), /synthetic kernel metadata bytes changed/);
      fs.writeFileSync(fixturePath, "x".repeat(2048));
      assert.throws(() => fs.readFileSync("/proc/version", "utf8"), /synthetic kernel metadata size changed/);
      assert.equal(safety.denials.length, count, "fixture-integrity failures must not clear existing denials");
      assert.equal(events.filter(row => row.kind === "SYNTHETIC_KERNEL_METADATA_READ").length, 0);
      report = { ...report, complete: true, rejectedForms: cases.length, rejectedContentChanges: 2 };
    }
  } catch (error) {
    report.failure = { name: error.name, message: error.message, stack: error.stack };
    process.exitCode = 1;
  } finally {
    report.events = events; report.denials = safety?.denials ?? []; report.delegatedPaths = delegatedPaths;
    const bytes = Buffer.from(JSON.stringify(report, null, 2) + "\n");
    fs.writeFileSync(path.join(scratch, "REPORT.json"), bytes, { flag: "wx" });
    rawWrite(1, bytes);
  }
}
if (process.argv[2] === "--fixture-child") {
  child(process.argv[3], process.argv[4]);
} else {
  const test = require("node:test");
  for (const mode of ["positive", "negative"]) {
    test("synthetic kernel metadata exact read and strict fence: " + mode, () => {
      const root = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), "b31-kernel-fixture-"));
      for (const name of ["scratch", "source", "cli"]) fs.mkdirSync(path.join(root, name));
      const argv = [__filename, "--fixture-child", root, mode];
      fs.writeFileSync(path.join(root, "REQUEST.json"), JSON.stringify({ executable: process.execPath, argv,
        timeoutMs: 30000, maxBuffer: 1024 * 1024, stdin: "closed" }, null, 2) + "\n", { flag: "wx" });
      const result = cp.spawnSync(process.execPath, argv, { stdio: ["ignore", "pipe", "pipe"],
        windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024 });
      fs.writeFileSync(path.join(root, "stdout.bin"), result.stdout ?? Buffer.alloc(0), { flag: "wx" });
      fs.writeFileSync(path.join(root, "stderr.bin"), result.stderr ?? Buffer.alloc(0), { flag: "wx" });
      fs.writeFileSync(path.join(root, "NATIVE_RESULT.json"), JSON.stringify({ status: result.status, signal: result.signal,
        error: result.error ? { code: result.error.code, message: result.error.message } : null }, null, 2) + "\n", { flag: "wx" });
      const detail = "Retained kernel fixture: " + root + "\n" + (result.stdout ?? "").toString() + "\n" + (result.stderr ?? "").toString();
      assert.equal(result.error, undefined, detail); assert.equal(result.signal, null, detail); assert.equal(result.status, 0, detail);
      const report = JSON.parse(fs.readFileSync(path.join(root, "scratch/REPORT.json"), "utf8"));
      assert.equal(report.complete, true, detail);
      assert.equal(report.failure, undefined, detail);
      assert.equal(report.denials.length, mode === "positive" ? 0 : 12, detail);
      if (mode === "positive") assert.equal(report.exactSyntheticReads, 1, detail);
      else { assert.equal(report.rejectedForms, 12, detail); assert.equal(report.rejectedContentChanges, 2, detail); }
    });
  }
}
