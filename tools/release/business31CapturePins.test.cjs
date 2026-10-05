"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const fs = require("node:fs"), path = require("node:path"), os = require("node:os");
const sourceFile = path.join(__dirname, "business31CaptureSession.cjs");
const source = fs.readFileSync(sourceFile, "utf8");
const map = source.match(/const PINS = Object\.freeze\(\{([\s\S]*?)\n\}\);/);
assert.ok(map, "capture session keeps its finite literal dependency map");
const dependencies = [...map[1].matchAll(/"([^"\r\n]+\.cjs)": "[A-F0-9]{64}"/g)].map(row => row[1]);
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
  for (const dependency of [helper, "business31ToolchainIdentity.cjs"]) {
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
