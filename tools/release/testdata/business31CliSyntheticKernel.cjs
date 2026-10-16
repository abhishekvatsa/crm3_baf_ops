"use strict";
// Test-only virtual metadata. No request below reads the host /proc filesystem.
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const assert = require("node:assert/strict");
const KERNEL_TEXT = "Linux version 6.8.0-offline-fixture (synthetic; no host metadata)\n";
const KERNEL_RELATIVE = "kernel-metadata/proc-version.txt";
const expectedBytes = Buffer.byteLength(KERNEL_TEXT);
const digest = raw => crypto.createHash("sha256").update(raw).digest("hex").toUpperCase();
const expectedSha256 = digest(Buffer.from(KERNEL_TEXT));
function verifySyntheticKernelFixture({ readFileSync, fixture, scratch }) {
  assert.deepEqual(Object.keys(fixture).sort(), ["bytes", "path", "sha256"]);
  assert.equal(fixture.path, path.join(scratch, KERNEL_RELATIVE));
  assert.equal(fixture.bytes, expectedBytes);
  assert.equal(fixture.sha256, expectedSha256);
  assert(expectedBytes > 0 && expectedBytes <= 1024);
  const st = fs.lstatSync(fixture.path);
  assert(st.isFile() && !st.isSymbolicLink(), "synthetic kernel metadata must be a regular file");
  assert.equal(st.size, expectedBytes, "synthetic kernel metadata size changed");
  // The supplied reader is the already-installed fence, including its ancestor-link checks.
  const raw = readFileSync.call(fs, fixture.path);
  assert(Buffer.isBuffer(raw));
  assert.equal(raw.length, expectedBytes, "synthetic kernel metadata read size changed");
  assert.equal(digest(raw), expectedSha256, "synthetic kernel metadata bytes changed");
  return raw;
}
function createSyntheticKernelReader({ readFileSync, fixture, scratch, event }) {
  return function (file, ...args) {
    if (arguments.length === 2 && file === "/proc/version" && args[0] === "utf8") {
      const raw = verifySyntheticKernelFixture({ readFileSync, fixture, scratch });
      event({ kind: "SYNTHETIC_KERNEL_METADATA_READ", requestedPath: "/proc/version",
        encoding: "utf8", fixture, actualOsFileRead: false });
      return raw.toString("utf8");
    }
    return readFileSync.apply(this, arguments);
  };
}
module.exports = { KERNEL_TEXT, KERNEL_RELATIVE, createSyntheticKernelReader, verifySyntheticKernelFixture };
