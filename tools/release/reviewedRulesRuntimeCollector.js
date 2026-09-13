"use strict";

// Read-only measurements. This module neither installs packages nor authorizes
// or performs a deployment. Returned path identities contain hashes, not paths.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const {execFileSync} = require("node:child_process");
const {isDeepStrictEqual} = require("node:util");
const {collectSourceBinding} = require("./collectFirestoreRulesIndexesReadback.js");

const CLI = "tooling/firebase-cli";
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const oid = (value) => typeof value === "string" && /^[a-f0-9]{40}$/.test(value);
const need = (condition, label) => { if (!condition) throw new Error(`Rules runtime proof: ${label}.`); };
const same = (actual, expected, label) => need(isDeepStrictEqual(actual, expected), label);
const pathDigest = (value) => sha(fs.realpathSync(value).replaceAll("\\", "/"));
const within = (root, file) => {
  const relative = path.relative(root, file);
  return relative !== ".." && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
};
const signature = (stat) => ({dev: stat.dev, ino: stat.ino, mode: stat.mode,
  size: stat.size, mtimeNs: stat.mtimeNs, ctimeNs: stat.ctimeNs});

function readStable(file) {
  const before = fs.lstatSync(file, {bigint: true});
  need(before.isFile() && !before.isSymbolicLink(), "regular file required");
  const bytes = fs.readFileSync(file), after = fs.lstatSync(file, {bigint: true});
  same(signature(after), signature(before), "file changed during measurement");
  need(BigInt(bytes.length) === after.size, "file length changed during measurement");
  return bytes;
}

/** Hash every actual file, directory and permitted link in sorted path order.
 * Full contents (including copied local packages) contribute to the digest.
 * Recheck entry metadata after the walk so a changed already-read file cannot
 * be concealed by an unchanged directory listing. No escaping links are read. */
function measureByteTree(directory) {
  const initial = fs.lstatSync(directory, {bigint: true});
  need(initial.isDirectory() && !initial.isSymbolicLink(), "tree root must be a real directory");
  const root = fs.realpathSync(directory), records = [], observed = [];
  let fileCount = 0, byteCount = 0, symlinkCount = 0;
  function walk(current) {
    const before = fs.lstatSync(current, {bigint: true});
    need(before.isDirectory() && !before.isSymbolicLink(), "directory changed into a link");
    observed.push({file: current, signature: signature(before)});
    const names = fs.readdirSync(current).sort();
    for (const name of names) {
      const file = path.join(current, name), relative = path.relative(root, file).replaceAll("\\", "/");
      const stat = fs.lstatSync(file, {bigint: true});
      if (stat.isSymbolicLink()) {
        const target = fs.readlinkSync(file);
        need(path.basename(current) === ".bin" && !path.isAbsolute(target) &&
          !path.win32.isAbsolute(target) && !/^[A-Za-z]:/.test(target) &&
          within(root, fs.realpathSync(file)) && fs.statSync(file).isFile(),
        "only contained relative .bin file links are permitted");
        records.push({path: relative, type: "link", target: target.replaceAll("\\", "/")});
        observed.push({file, signature: signature(stat), target}); symlinkCount++;
      } else if (stat.isDirectory()) {
        records.push({path: relative, type: "directory"}); walk(file);
      } else {
        need(stat.isFile(), "unsupported filesystem entry");
        const bytes = readStable(file);
        records.push({path: relative, type: "file", byteCount: bytes.length, sha256: sha(bytes)});
        observed.push({file, signature: signature(stat)});
        fileCount++; byteCount += bytes.length;
        need(Number.isSafeInteger(byteCount), "tree byte count exceeds exact integer range");
      }
    }
    same(fs.readdirSync(current).sort(), names, "directory changed during measurement");
  }
  walk(root);
  for (const entry of observed) {
    same(signature(fs.lstatSync(entry.file, {bigint: true})), entry.signature, "tree entry changed during measurement");
    if (entry.target !== undefined) same(fs.readlinkSync(entry.file), entry.target, "link changed during measurement");
  }
  records.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  return {sha256: sha(JSON.stringify(records)), fileCount, byteCount, symlinkCount};
}

function git(root, arguments_) {
  return execFileSync("git", ["--no-replace-objects", "-C", root, ...arguments_],
    {windowsHide: true, stdio: ["ignore", "pipe", "pipe"]});
}

function sourceIdentity(repoRoot, sourceCommit, sourceTree, compareDisk = false) {
  need(oid(sourceCommit) && oid(sourceTree), "exact source required");
  need(git(repoRoot, ["rev-parse", `${sourceCommit}^{tree}`]).toString().trim() === sourceTree, "source tree differs");
  const source = {commit: sourceCommit, tree: sourceTree};
  for (const [key, file] of [["cliPackageSha256", `${CLI}/package.json`],
    ["cliLockSha256", `${CLI}/package-lock.json`], ["npmrcSha256", `${CLI}/.npmrc`]]) {
    const bytes = git(repoRoot, ["show", `${sourceCommit}:${file}`]);
    if (compareDisk) same(readStable(path.join(repoRoot, file)), bytes, "installed input bytes differ from exact source");
    source[key] = sha(bytes);
  }
  // The exact complete Git tree binds the local root package and compatibility
  // adapters; fresh-input checks and checkout observations bind their disk state.
  return source;
}

function exactCheckout(checkout, source) {
  need(checkout?.commit === source.commit && checkout.tree === source.tree &&
    checkout.originMain === source.commit && checkout.branch === "main" &&
    checkout.governedWorktreeClean === true && checkout.materialChangeCount === 0 &&
    Array.isArray(checkout.materialPathSha256) && checkout.materialPathSha256.length === 0,
  "exact clean main checkout required");
}

function requireCleanEnvironment() {
  for (const name of Object.keys(process.env)) {
    need(!["NODE_OPTIONS", "NODE_PATH"].includes(name.toUpperCase()), "Node injection environment must be absent");
  }
}

function requireAbsent(file, label) {
  try { fs.lstatSync(file); } catch (error) {
    // existsSync would turn EACCES/EPERM into false and invent absence.
    if (error?.code === "ENOENT") return;
    throw error;
  }
  need(false, label);
}

function requireAbsentAncestors(repoRoot) {
  let current = path.join(fs.realpathSync(repoRoot), "tooling");
  for (;;) {
    requireAbsent(path.join(current, "node_modules"), "ancestor node_modules is unmeasured");
    const parent = path.dirname(current); if (parent === current) break; current = parent;
  }
}

function measureNpmInstallation(npmRoot) {
  const parent = path.dirname(npmRoot), bundled = path.basename(parent) === "node_modules";
  const directory = bundled ? parent : npmRoot;
  const start = bundled ? path.dirname(parent) : parent;
  function requireNoOutsideLookup() {
    let current = start;
    for (;;) {
      const candidate = path.join(current, "node_modules");
      // The containing installation directory is measured in full, including
      // siblings such as corepack. Every higher lookup must actually be absent.
      if (candidate !== directory) requireAbsent(candidate, "npm ancestor node_modules is unmeasured");
      const above = path.dirname(current); if (above === current) break; current = above;
    }
  }
  requireNoOutsideLookup();
  const result = {treeScope: bundled ? "installation-node-modules" : "standalone-npm-package",
    treeRootPathSha256: pathDigest(directory), tree: measureByteTree(directory)};
  requireNoOutsideLookup();
  return result;
}

function requireFreshInputs(repoRoot) {
  requireAbsent(path.join(repoRoot, CLI, "node_modules"), "clean install requires absent node_modules");
  const untracked = git(repoRoot, ["ls-files", "--others", "--exclude-standard", "-z"]);
  const ignored = git(repoRoot, ["ls-files", "--others", "--ignored", "--exclude-standard", "-z"]);
  need(untracked.length === 0 && ignored.length === 0, "fresh install source contains untracked or ignored inputs");
}

function inspectInstallInputs({repoRoot, sourceCommit, sourceTree}) {
  const collectionStartedAtUtc = new Date().toISOString();
  requireCleanEnvironment(); requireAbsentAncestors(repoRoot);
  const source = sourceIdentity(repoRoot, sourceCommit, sourceTree, true);
  const checkout = collectSourceBinding(repoRoot); exactCheckout(checkout, source);
  requireFreshInputs(repoRoot);
  const after = collectSourceBinding(repoRoot); exactCheckout(after, source);
  requireAbsentAncestors(repoRoot); requireFreshInputs(repoRoot);
  return {source: {...source, executionRootSha256: pathDigest(repoRoot)}, checkout,
    nodeModulesAbsent: true, untrackedInputsAbsent: true, collectionStartedAtUtc,
    capturedAtUtc: new Date().toISOString()};
}

function measureRulesInstaller({nodeExecutable, npmCliPath}) {
  const collectionStartedAtUtc = new Date().toISOString();
  requireCleanEnvironment();
  need(typeof nodeExecutable === "string" && typeof npmCliPath === "string" &&
    path.isAbsolute(nodeExecutable) && path.isAbsolute(npmCliPath), "resolved absolute Node/npm paths required");
  const node = fs.realpathSync(nodeExecutable), nodeBytes = readStable(node);
  // A successful version invocation also establishes support for the actual
  // no-global-search-paths launch option; no Node hooks are accepted from env.
  const version = execFileSync(node, ["--no-global-search-paths", "--version"],
    {windowsHide: true, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]}).trim();
  const parsed = /^v(\d+)\.(\d+)\.(\d+)$/.exec(version);
  need(parsed != null && (+parsed[1] > 22 || (+parsed[1] === 22 && +parsed[2] >= 12)),
    "Node 22.12 or later is required by the installed CLI adapters");
  const npm = fs.realpathSync(npmCliPath), npmRoot = path.dirname(path.dirname(npm));
  need(path.basename(npm) === "npm-cli.js" && path.basename(path.dirname(npm)) === "bin", "npm entry point differs");
  const packagePath = path.join(npmRoot, "package.json"), packageBytes = readStable(packagePath);
  const npmPackage = JSON.parse(packageBytes);
  need(npmPackage.name === "npm" && typeof npmPackage.version === "string" &&
    /^\d+\.\d+\.\d+$/.test(npmPackage.version), "npm package identity malformed");
  const result = {
    node: {pathSha256: pathDigest(node), sha256: sha(nodeBytes), byteCount: nodeBytes.length, version},
    npm: {pathSha256: pathDigest(npm), version: npmPackage.version, ...measureNpmInstallation(npmRoot)},
  };
  same(readStable(node), nodeBytes, "Node changed during measurement");
  same(readStable(packagePath), packageBytes, "npm package identity changed during measurement");
  return {schemaVersion: 1, collectionStartedAtUtc, capturedAtUtc: new Date().toISOString(), ...result};
}

function measureRulesRuntime({repoRoot, sourceCommit, sourceTree, nodeExecutable, npmCliPath}) {
  const collectionStartedAtUtc = new Date().toISOString();
  requireCleanEnvironment(); requireAbsentAncestors(repoRoot);
  const source = sourceIdentity(repoRoot, sourceCommit, sourceTree, true);
  exactCheckout(collectSourceBinding(repoRoot), source);
  const measuredInstaller = measureRulesInstaller({nodeExecutable, npmCliPath});
  const installer = {node: measuredInstaller.node, npm: measuredInstaller.npm};
  const installedTree = measureByteTree(path.join(repoRoot, CLI, "node_modules"));
  const installerAfter = measureRulesInstaller({nodeExecutable, npmCliPath});
  same({node: installerAfter.node, npm: installerAfter.npm}, installer, "installer changed during runtime measurement");
  sourceIdentity(repoRoot, sourceCommit, sourceTree, true);
  exactCheckout(collectSourceBinding(repoRoot), source);
  requireCleanEnvironment(); requireAbsentAncestors(repoRoot);
  return {schemaVersion: 1, collectionStartedAtUtc, capturedAtUtc: new Date().toISOString(), identity: {
    source: {...source, executionRootSha256: pathDigest(repoRoot)}, ...installer, installedTree,
    ancestorNodeModulesAbsent: true, nodeOptionsAbsent: true, nodePathAbsent: true,
  }};
}

module.exports = {measureByteTree, sourceIdentity, inspectInstallInputs, measureRulesInstaller, measureRulesRuntime};
