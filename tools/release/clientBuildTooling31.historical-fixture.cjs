"use strict";

// Test data only. This is the last published development-only candidate, before
// the runtime gRPC repair. Current verifier implementations still execute in the
// tests; a later runtime dependency must not silently redefine their valid input.
const {execFileSync} = require("node:child_process");
const HISTORICAL_DEVELOPMENT_COMMIT = "297bb704aa4e55ede5d075110a5bc94314902761";
const HISTORICAL_DEVELOPMENT_FILES = Object.freeze([
  "package.json", "package-lock.json", "functions/package-lock.json",
  "tooling/brace-expansion-compat/package.json",
  "tooling/firebase-cli/package.json", "tooling/firebase-cli/package-lock.json",
]);

function readHistoricalDevelopmentFile(repoRoot, file) {
  if (!HISTORICAL_DEVELOPMENT_FILES.includes(file)) {
    throw new Error("Unsupported historical development-only fixture file");
  }
  return execFileSync("git", ["--no-replace-objects", "-C", repoRoot,
    "show", `${HISTORICAL_DEVELOPMENT_COMMIT}:${file}`], {windowsHide: true});
}

module.exports = {HISTORICAL_DEVELOPMENT_COMMIT, HISTORICAL_DEVELOPMENT_FILES,
  readHistoricalDevelopmentFile};
