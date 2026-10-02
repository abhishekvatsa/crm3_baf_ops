"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const {execFileSync} = require("node:child_process");
const test = require("node:test");
const {verifyGitDevelopmentTooling} = require("./clientBuildToolingGitSnapshots31.cjs");
const {DEPLOYED_BASELINE} = require("./clientBuildToolingCompatibility31.cjs");
const {readHistoricalDevelopmentFile} = require("./clientBuildTooling31.historical-fixture.cjs");
const primary = execFileSync("git", ["-C", __dirname, "rev-parse", "--show-toplevel"],
  {encoding: "utf8", windowsHide: true}).trim();
const candidate = path.resolve(__dirname, "../..");
// Local object references avoid fetch/network and never mutate the source repo.
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-git-provenance-fixture-"));
const env = {...process.env, GIT_AUTHOR_NAME: "Private prototype fixture",
  GIT_AUTHOR_EMAIL: "fixture@example.invalid", GIT_COMMITTER_NAME: "Private prototype fixture",
  GIT_COMMITTER_EMAIL: "fixture@example.invalid"};
function git(args, options = {}) {
  return execFileSync("git", ["--no-replace-objects", "-C", fixture, ...args], {
    env, windowsHide: true, stdio: ["pipe", "pipe", "pipe"], encoding: "utf8", ...options,
  }).trim();
}
execFileSync("git", ["init", "--quiet", fixture], {windowsHide: true});
const objects = execFileSync("git", ["-C", primary, "rev-parse", "--git-path", "objects"], {encoding: "utf8"}).trim();
fs.mkdirSync(path.join(fixture, ".git/objects/info"), {recursive: true});
fs.writeFileSync(path.join(fixture, ".git/objects/info/alternates"), path.resolve(primary, objects).replaceAll("\\", "/") + "\n");
function blob(bytes) { return git(["hash-object", "-w", "--stdin"], {input: bytes}); }
function put(file, bytes, mode = "100644") { git(["update-index", "--add", "--cacheinfo", `${mode},${blob(bytes)},${file}`]); }
function omit(file) { git(["update-index", "--force-remove", "--", file]); }
function changedJson(file, mutate) {
  const value = JSON.parse(readHistoricalDevelopmentFile(primary, file));
  mutate(value); put(file, JSON.stringify(value));
}
const fixedFiles = ["package.json", "package-lock.json", "functions/package-lock.json", "tooling/brace-expansion-compat/package.json"];
function commit(mutate = () => {}, parents = [DEPLOYED_BASELINE]) {
  git(["read-tree", DEPLOYED_BASELINE]);
  for (const file of fixedFiles) put(file, readHistoricalDevelopmentFile(primary, file));
  mutate();
  const tree = git(["write-tree"]);
  return git(["commit-tree", tree, ...parents.flatMap(parent => ["-p", parent])], {input: "Private equivalence test fixture; creates no release authority.\n"});
}
const good = commit();
function verify(candidateCommit = good, extra = {}) {
  return verifyGitDevelopmentTooling({repoRoot: fixture, candidateCommit, ...extra});
}
const baselineBinary = git(["ls-tree", "-r", "--name-only", DEPLOYED_BASELINE, "--", "android"])
  .split("\n").find(file => file.endsWith(".png"));
assert.ok(baselineBinary, "Actual baseline includes a native binary asset");

test("real deployed F to exact private candidate Git delta binds every protected mode/blob", () => {
  const result = verify();
  fs.writeFileSync(path.join(fixture, "snapshot-proof.json"), JSON.stringify(result, null, 2) + "\n");
  assert.equal(result.ok, true);
  assert.equal(result.baselineCommit, DEPLOYED_BASELINE);
  assert.equal(result.candidateCommit, good);
  assert.equal(result.runtimeReachablePaths, 252);
  assert.equal(result.constructionAuthority, false);
  assert.ok(result.protectedFileCount > 250);
  assert.equal(result.protectedFiles.length, result.protectedFileCount);
  assert.match(result.inventorySha256, /^[A-F0-9]{64}$/);
  const binary = result.protectedFiles.find(file => file.path === baselineBinary);
  assert.equal(binary.baselineBlob, binary.candidateBlob);
  for (const required of [".npmrc", "functions/.npmrc", "tooling/firebase-cli/.npmrc"]) {
    const config = result.protectedFiles.find(file => file.path === required);
    assert.ok(config, `Required install configuration is included: ${required}`);
    assert.equal(config.baselineBlob, config.candidateBlob);
    assert.equal(config.mode, "100644");
  }
});
for (const [name, mutate, message] of [
  ["Functions source content", () => put("functions/src/index.ts", "different"), /blob differs/],
  ["Functions source omitted", () => omit("functions/src/index.ts"), /Missing protected/],
  ["ordinary Functions file omitted", () => omit("functions/tsconfig.json"), /file set differs/],
  ["unexpected Functions file", () => put("functions/src/unreviewed.ts", "new"), /file set differs/],
  ["root manifest omitted", () => omit("package.json"), /Missing protected/],
  ["install configuration changed: .npmrc", () => put(".npmrc", "install-links=false\n"), /blob differs/],
  ["install configuration omitted: .npmrc", () => omit(".npmrc"), /Missing protected/],
  ["install configuration changed: functions/.npmrc", () => put("functions/.npmrc", "install-links=false\n"), /blob differs/],
  ["install configuration omitted: functions/.npmrc", () => omit("functions/.npmrc"), /Missing protected/],
  ["install configuration changed: tooling/firebase-cli/.npmrc", () => put("tooling/firebase-cli/.npmrc", "install-links=false\n"), /blob differs/],
  ["install configuration omitted: tooling/firebase-cli/.npmrc", () => omit("tooling/firebase-cli/.npmrc"), /Missing protected/],
  ["binary native asset", () => put(baselineBinary, Buffer.from([0xff, 0xfe, 0, 255])), /blob differs/],
  ["native binary mode", () => put(baselineBinary, Buffer.from("same mode must be protected"), "100755"), /mode differs/],
  ["admitted JSON mode", () => put("functions/package-lock.json", fs.readFileSync(path.join(candidate, "functions/package-lock.json")), "100755"), /mode differs/],
  ["source symlink escape", () => put("functions/src/index.ts", "../../outside", "120000"), /Symlink/],
  ["native gitlink", () => git(["update-index", "--add", "--cacheinfo", `160000,${DEPLOYED_BASELINE},android/unreviewed-module`]), /gitlink/],
  ["adapter executable content", () => put("tooling/brace-expansion-compat/index.cjs", "module.exports = null;"), /blob differs/],
  ["Rules content", () => put("firestore.rules", "changed"), /blob differs/],
  ["root runtime dependency", () => changedJson("package.json", value => {value.dependencies = {unreviewed: "1"};}), /Root|root|delta|manifest|content/],
  ["root extra test script", () => changedJson("package.json", value => {value.scripts.unreviewed = "echo unknown";}), /Root|root|delta|manifest|content/],
  ["root engine field", () => changedJson("package.json", value => {value.engines = {node: "*"};}), /Root|root|delta|manifest|content/],
  ["unapproved development pin", () => changedJson("functions/package-lock.json", value => {value.packages["node_modules/typescript"].version = "9.9.9";}), /delta exceeds/],
  ["invalid UTF8 JSON", () => put("functions/package-lock.json", Buffer.from([0x7b, 0xff, 0x7d])), /invalid UTF-8/],
]) test(`rejects real Git mutation: ${name}`, () => assert.throws(() => verify(commit(mutate)), message));

test("rejects a source ref rather than a full immutable commit", () => assert.throws(() => verify("HEAD"), /full lowercase commit/));
test("rejects a nonexistent commit", () => assert.throws(() => verify("0".repeat(40))));
test("rejects a tree object used as a source commit", () => assert.throws(() => verify(git(["rev-parse", `${good}^{tree}`])), /commit object required/));
test("rejects a wrong deployed baseline", () => assert.throws(() => verify(good, {baselineCommit: good}), /Wrong deployed/));
test("rejects unrelated ancestry even with the same candidate tree", () => assert.throws(() => verify(commit(() => {}, []))));
test("rejects a nested directory instead of the repository root", () => {
  fs.mkdirSync(path.join(fixture, "nested"));
  assert.throws(() => verify(good, {repoRoot: path.join(fixture, "nested")}), /actual Git top-level/);
});
test("Git replacement refs cannot replace baseline source evidence", () => {
  const replacement = commit(() => put("functions/src/index.ts", "replacement"));
  git(["replace", DEPLOYED_BASELINE, replacement]);
  try { assert.equal(verify().ok, true); }
  finally { git(["replace", "-d", DEPLOYED_BASELINE]); }
});

function unsafeFunctionsPath(name) {
  const functionsTree = git(["rev-parse", `${good}:functions`]);
  const bytes = execFileSync("git", ["--no-replace-objects", "-C", fixture, "cat-file", "tree", functionsTree]);
  const injected = Buffer.concat([bytes, Buffer.from(`100644 ${name}\0`), Buffer.from(blob("adversarial path"), "hex")]);
  const unsafeTree = git(["hash-object", "--literally", "-w", "-t", "tree", "--stdin"], {input: injected});
  const root = execFileSync("git", ["--no-replace-objects", "-C", fixture, "cat-file", "tree", `${good}^{tree}`]);
  const index = root.indexOf(Buffer.from(functionsTree, "hex"));
  assert.ok(index >= 0);
  Buffer.from(unsafeTree, "hex").copy(root, index);
  const tree = git(["hash-object", "--literally", "-w", "-t", "tree", "--stdin"], {input: root});
  return git(["commit-tree", tree, "-p", DEPLOYED_BASELINE], {input: "Private unsafe-path negative fixture.\n"});
}
for (const name of ["../escape", "bad\\name.ts", "bad:name.ts"]) {
  test(`rejects unsafe path stored in a real Git object: ${name}`, () => {
    assert.throws(() => verify(unsafeFunctionsPath(name)), /Unsafe protected Git path/);
  });
}
