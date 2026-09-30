"use strict";
// Git evidence adapter. Actual CI, truthful decisions and deployed
// readbacks must be bound separately before any construction authority exists.
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
const {createHash} = require("node:crypto");
const {TextDecoder} = require("node:util");
const {
  DEPLOYED_BASELINE,
  verifyDevelopmentToolingSnapshots,
} = require("./clientBuildToolingCompatibility31.cjs");

const COMMIT = /^[a-f0-9]{40}$/;
const JSON_FILES = new Set([
  "package.json", "package-lock.json", "functions/package.json",
  "functions/package-lock.json", "tooling/brace-expansion-compat/package.json",
]);
const ADMITTED_JSON_DELTAS = new Set([
  "package.json", "package-lock.json", "functions/package-lock.json",
  "tooling/brace-expansion-compat/package.json",
]);
// Entire deployed source/native directories are enumerated from each tree.
// The adapter's documentation may explain new pins; executable/package bytes
// are protected here. No caller can supply a shortened inventory or path list.
const PROTECTED_PATHS = Object.freeze([
  "functions", "android", "firestore.rules", "firestore.indexes.json",
  "package.json", "package-lock.json", ".npmrc", "tooling/firebase-cli/.npmrc",
  "tooling/brace-expansion-compat/package.json",
  "tooling/brace-expansion-compat/index.cjs",
  "tooling/brace-expansion-compat/index.mjs",
]);
const REQUIRED_FILES = [
  ...PROTECTED_PATHS.filter(p => p !== "functions" && p !== "android"),
  "functions/.npmrc",
];
const decoder = new TextDecoder("utf-8", {fatal: true});
function must(value, message) { if (!value) throw new Error(message); }
function decode(bytes, label) {
  try { return decoder.decode(bytes); }
  catch { throw new Error(`${label}: invalid UTF-8`); }
}
function safePath(value) {
  return value.length > 0 && value.length <= 1024 &&
    !/[\\:\x00-\x1f\x7f]/.test(value) && !value.startsWith("/") &&
    value.split("/").every(part => part && part !== "." && part !== ".." && part.toLowerCase() !== ".git");
}
function git(repoRoot, args) {
  return execFileSync("git", ["--no-replace-objects", "-C", repoRoot, ...args], {
    windowsHide: true, timeout: 30000, stdio: ["ignore", "pipe", "pipe"], maxBuffer: 16 * 1024 * 1024,
  });
}
function gitText(repoRoot, args) { return decode(git(repoRoot, args), "Git response").trim(); }
function exactCommit(repoRoot, commit, label) {
  must(typeof commit === "string" && COMMIT.test(commit), `${label}: full lowercase commit SHA required`);
  must(gitText(repoRoot, ["cat-file", "-t", commit]) === "commit", `${label}: commit object required`);
  must(gitText(repoRoot, ["rev-parse", "--verify", `${commit}^{commit}`]) === commit,
    `${label}: exact commit resolution differs`);
}
function snapshot(repoRoot, commit) {
  const entries = Object.create(null);
  const folded = new Set();
  const raw = git(repoRoot, ["ls-tree", "-rz", "--full-tree", commit, "--", ...PROTECTED_PATHS]);
  let start = 0;
  for (let end = 0; end < raw.length; end++) {
    if (raw[end] !== 0) continue;
    const entry = decode(raw.subarray(start, end), "Git tree entry");
    start = end + 1;
    const match = /^(\d{6}) (\w+) ([a-f0-9]{40})\t(.+)$/.exec(entry);
    must(match, "Malformed Git tree entry");
    const [, mode, type, blob, file] = match;
    must(safePath(file), `Unsafe protected Git path: ${file}`);
    must(PROTECTED_PATHS.some(p => file === p || (p === "functions" || p === "android") && file.startsWith(p + "/")),
      `Unexpected protected Git path: ${file}`);
    must(type === "blob" && (mode === "100644" || mode === "100755"),
      `Symlink, gitlink or unsupported protected mode: ${file}`);
    must(!folded.has(file.toLowerCase()), `Ambiguous protected path case: ${file}`);
    folded.add(file.toLowerCase());
    entries[file] = {mode, blob};
  }
  must(start === raw.length && Object.keys(entries).length > 0 && Object.keys(entries).length <= 10000,
    "Incomplete or oversized protected Git inventory");
  for (const required of [...REQUIRED_FILES, "functions/package.json", "functions/package-lock.json", "functions/src/index.ts"]) {
    must(Object.hasOwn(entries, required), `Missing protected Git file: ${required}`);
  }
  must(Object.keys(entries).some(p => p.startsWith("android/")), "Missing complete Android tree");
  const values = Object.create(null);
  for (const [file, entry] of Object.entries(entries)) {
    // Comparing identities avoids corrupting binary assets through UTF-8 decode.
    values[file] = JSON_FILES.has(file)
      ? decode(git(repoRoot, ["cat-file", "blob", entry.blob]), file)
      : `git-blob:${entry.mode}:${entry.blob}`;
  }
  return {entries, values, tree: gitText(repoRoot, ["rev-parse", `${commit}^{tree}`])};
}
function verifyGitDevelopmentTooling({repoRoot, baselineCommit = DEPLOYED_BASELINE, candidateCommit}) {
  must(baselineCommit === DEPLOYED_BASELINE, "Wrong deployed backend baseline");
  must(typeof repoRoot === "string" && path.isAbsolute(repoRoot), "Absolute repository root required");
  const actualRoot = fs.realpathSync(repoRoot);
  const gitRoot = fs.realpathSync(gitText(actualRoot, ["rev-parse", "--show-toplevel"]));
  must(actualRoot === gitRoot, "Repository root must be the actual Git top-level directory");
  exactCommit(actualRoot, baselineCommit, "Deployed baseline");
  exactCommit(actualRoot, candidateCommit, "Candidate source");
  git(actualRoot, ["merge-base", "--is-ancestor", baselineCommit, candidateCommit]);
  const before = snapshot(actualRoot, baselineCommit);
  const after = snapshot(actualRoot, candidateCommit);
  const paths = Object.keys(before.entries).sort();
  must(JSON.stringify(paths) === JSON.stringify(Object.keys(after.entries).sort()), "Protected Git file set differs");
  for (const file of paths) {
    must(before.entries[file].mode === after.entries[file].mode, `Protected Git mode differs: ${file}`);
    if (!ADMITTED_JSON_DELTAS.has(file)) {
      must(before.entries[file].blob === after.entries[file].blob, `Protected Git blob differs: ${file}`);
    }
  }
  const result = verifyDevelopmentToolingSnapshots({baselineCommit, before: before.values, after: after.values});
  const inventory = paths.map(file => ({path: file, mode: before.entries[file].mode,
    baselineBlob: before.entries[file].blob, candidateBlob: after.entries[file].blob}));
  return {
    ...result, baselineCommit, baselineTree: before.tree, candidateCommit, candidateTree: after.tree,
    protectedFileCount: inventory.length,
    inventorySha256: createHash("sha256").update(JSON.stringify(inventory)).digest("hex").toUpperCase(),
    protectedFiles: inventory, constructionAuthority: false,
  };
}
module.exports = {verifyGitDevelopmentTooling};
