"use strict";
// Credential-free source measurement. Trust in the selected manifest must be
// established by the immutable controller before this module is called.
const crypto = require("node:crypto");
const {isDeepStrictEqual} = require("node:util");
const PROFILE = "build31-exact-business-backend-v1";
const BASELINE = "2aa30de56cfdb960da3eeefd8956d8cbbae57b46";
const PROTECTED_ROOTS = Object.freeze([
  "functions", "tooling", "firebase.json", ".firebaserc", "firestore.rules",
  "firestore.indexes.json", "android",
  "release/function-fleet-runtime-identity-policy.json",
  "release/lr03-lr06-functions-live-readback-policy.json",
]);
const DEPENDENCIES = Object.freeze([
  "functions/package.json", "functions/package-lock.json",
  "tooling/firebase-cli/package.json", "tooling/firebase-cli/package-lock.json",
]);
// This is a finite source scope, not a wildcard permission to change Functions.
// Every actual change additionally needs its exact before/after mode and blob
// in the separately trusted manifest. No manifest or approval is generated here.
const ADMITTED_DELTA_PATHS = Object.freeze([
  ...DEPENDENCIES,
  "functions/src/maintenanceWorkflow/commandAuthority.ts",
  "functions/src/maintenanceWorkflow/dispatcher.ts",
  "functions/src/maintenanceWorkflow/innerCoverConcernDisposition.ts",
  "functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts",
  "functions/src/maintenanceWorkflow/inspectionReadingContract.ts",
  "functions/src/maintenanceWorkflow/inspectionAuthoringPolicy.ts",
  "functions/src/maintenanceWorkflow/types.ts",
  "functions/src/originBoundCallableProtocol.ts",
  "functions/test/innerCoverConcernDisposition.test.js",
  "functions/test/inspectionFindingIntegrity.firestoreEmulator.test.js",
  "functions/test/inspectionReadingContract.test.js",
  "functions/test/inspectionAuthoringPolicy.test.js",
  "tooling/brace-expansion-compat/README.md",
  "tooling/brace-expansion-compat/package.json",
  "tooling/braces-depth-guard/LICENSE",
  "tooling/braces-depth-guard/README.md",
  "tooling/braces-depth-guard/UPSTREAM_PROVENANCE.json",
  "tooling/braces-depth-guard/index.js",
  "tooling/braces-depth-guard/lib/compile.js",
  "tooling/braces-depth-guard/lib/constants.js",
  "tooling/braces-depth-guard/lib/expand.js",
  "tooling/braces-depth-guard/lib/parse.js",
  "tooling/braces-depth-guard/lib/stringify.js",
  "tooling/braces-depth-guard/lib/utils.js",
  "tooling/braces-depth-guard/package.json",
  "tooling/stream-json-compat/README.md",
  "tooling/stream-json-compat/package.json",
]);
const admitted = new Set(ADMITTED_DELTA_PATHS);
function requireValue(ok, message) { if (!ok) throw new Error(message); }
function object(value, label) {
  requireValue(value !== null && typeof value === "object" && !Array.isArray(value)
    && [Object.prototype, null].includes(Object.getPrototypeOf(value)), `${label}: plain object required`);
}
function exactKeys(value, keys, label) {
  object(value, label);
  requireValue(isDeepStrictEqual(Object.keys(value).sort(), [...keys].sort()), `${label}: exact keys required`);
}
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    object(value, "canonical value");
    return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(",")}}`;
  }
  requireValue(["string", "boolean", "number"].includes(typeof value) || value === null,
    "Unsupported canonical value");
  if (typeof value === "number") requireValue(Number.isFinite(value), "Non-finite canonical number");
  return JSON.stringify(value);
}
function digest(value) { return crypto.createHash("sha256").update(value).digest("hex").toUpperCase(); }
function hex(value, length) { return typeof value === "string" && new RegExp(`^[a-f0-9]{${length}}$`, "i").test(value); }
function protectedPath(name) { return PROTECTED_ROOTS.some(root => name === root || name.startsWith(`${root}/`)); }
function fileIdentity(value, label) {
  exactKeys(value, ["mode", "oid"], label);
  requireValue(["100644", "100755"].includes(value.mode) && hex(value.oid, 40), `${label}: regular Git blob required`);
}
function population(snapshot) {
  requireValue(hex(snapshot.commit, 40) && hex(snapshot.tree, 40), "Exact snapshot identity required");
  object(snapshot.files, "snapshot files");
  const result = {};
  for (const name of Object.keys(snapshot.files).sort()) {
    if (!protectedPath(name)) continue;
    fileIdentity(snapshot.files[name], name);
    result[name] = snapshot.files[name];
  }
  requireValue(Object.keys(result).length > 0, "Empty protected population refused");
  return result;
}
function measuredDelta(before, after) {
  return [...new Set([...Object.keys(before), ...Object.keys(after)])].sort()
    .filter(name => !isDeepStrictEqual(before[name], after[name]))
    .map(name => ({path: name, before: before[name] ?? null, after: after[name] ?? null}));
}
// Pure structural validator, also used by negative regression fixtures. Actual
// ancestry and Git bytes are always checked by verifyBusiness31Source below.
function validateSourceInventory31({baselineSnapshot, sourceSnapshot, manifest,
  trustedManifestSha256, dependencySha256}) {
  requireValue(hex(trustedManifestSha256, 64), "Trusted manifest digest required");
  requireValue(digest(canonical(manifest)) === trustedManifestSha256.toUpperCase(), "Trusted manifest digest mismatch");
  exactKeys(manifest, ["schemaVersion", "documentType", "profile", "baseline", "source",
    "protectedRoots", "protectedDelta", "dependencySha256"], "source manifest");
  requireValue(manifest.schemaVersion === 1 && manifest.documentType === "build31-business-source-inventory"
    && manifest.profile === PROFILE, "Distinct business source manifest required");
  requireValue(baselineSnapshot.commit === BASELINE, "Wrong deployed baseline");
  requireValue(sourceSnapshot.commit !== BASELINE, "Successor source required");
  requireValue(isDeepStrictEqual(manifest.protectedRoots, PROTECTED_ROOTS), "Protected population scope differs");
  const before = population(baselineSnapshot), after = population(sourceSnapshot);
  for (const [label, snapshot, files] of [["baseline", baselineSnapshot, before], ["source", sourceSnapshot, after]]) {
    exactKeys(manifest[label], ["commit", "tree", "protectedPopulationSha256"], label);
    requireValue(isDeepStrictEqual(manifest[label], {commit: snapshot.commit, tree: snapshot.tree,
      protectedPopulationSha256: digest(canonical(files))}), `${label}: exact complete source population differs`);
  }
  requireValue(Array.isArray(manifest.protectedDelta) && manifest.protectedDelta.length > 0
    && manifest.protectedDelta.length <= ADMITTED_DELTA_PATHS.length, "Bounded nonempty delta required");
  let previous = "";
  for (const entry of manifest.protectedDelta) {
    exactKeys(entry, ["path", "before", "after"], "delta entry");
    requireValue(typeof entry.path === "string" && entry.path > previous && admitted.has(entry.path),
      "Unordered, repeated or unadmitted source delta");
    previous = entry.path;
    if (entry.before !== null) fileIdentity(entry.before, "before");
    requireValue(entry.after !== null, "Deleting admitted source is not authorized");
    fileIdentity(entry.after, "after");
    requireValue(entry.after.mode === "100644" && (entry.before === null || entry.before.mode === "100644"),
      "Admitted changes must retain ordinary non-executable files");
  }
  const delta = measuredDelta(before, after);
  requireValue(isDeepStrictEqual(delta, manifest.protectedDelta), "Actual protected delta differs from reviewed manifest");
  exactKeys(manifest.dependencySha256, DEPENDENCIES, "manifest dependencies");
  exactKeys(dependencySha256, DEPENDENCIES, "measured dependencies");
  for (const name of DEPENDENCIES) requireValue(hex(manifest.dependencySha256[name], 64)
    && manifest.dependencySha256[name] === dependencySha256[name], `Dependency bytes differ: ${name}`);
  return Object.freeze({schemaVersion: 1, documentType: "build31-business-source-measurement",
    profile: PROFILE, baseline: Object.freeze({...manifest.baseline}), source: Object.freeze({...manifest.source}),
    trustedManifestSha256: trustedManifestSha256.toUpperCase(), protectedFileCount: Object.keys(after).length,
    changedPaths: Object.freeze(delta.map(entry => entry.path)), deploymentAuthority: false, credentialAccessAuthorized: false});
}
function verifyBusiness31Source({repositoryRoot, gitExecutable, gitSha256,
  sourceCommit, manifest, trustedManifestSha256}) {
  requireValue(hex(sourceCommit, 40), "Exact source commit required");
  const {openTrustedGitRepository31} = require("./business31TrustedInput.cjs");
  const repository = openTrustedGitRepository31({repositoryRoot, gitExecutable, gitSha256});
  repository.requireAncestor(BASELINE, sourceCommit);
  const baselineSnapshot = repository.snapshot(BASELINE), sourceSnapshot = repository.snapshot(sourceCommit);
  const dependencySha256 = Object.fromEntries(DEPENDENCIES.map(name =>
    [name, digest(repository.readBlob(sourceCommit, name, 2 * 1024 * 1024))]));
  return validateSourceInventory31({baselineSnapshot, sourceSnapshot, manifest,
    trustedManifestSha256, dependencySha256});
}
module.exports = {PROFILE, BASELINE, PROTECTED_ROOTS, DEPENDENCIES, ADMITTED_DELTA_PATHS,
  canonical, digest, validateSourceInventory31, verifyBusiness31Source};
