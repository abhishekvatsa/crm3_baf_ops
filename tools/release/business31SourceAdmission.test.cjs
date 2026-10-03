"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const source = require("./business31SourceAdmission.cjs");
const {BASELINE, PROFILE, PROTECTED_ROOTS, DEPENDENCIES, canonical, digest,
  validateSourceInventory31, verifyBusiness31Source} = source;
const id = char => ({mode: "100644", oid: char.repeat(40)});
// These are deliberately synthetic structural fixtures. They are not Git,
// deployment or cloud proof; the production entry point obtains real snapshots.
function fixture() {
  const files = Object.fromEntries(DEPENDENCIES.map(p => [p, id("a")]));
  files["firestore.rules"] = id("b");
  files["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"] = id("c");
  const baselineSnapshot = {commit: BASELINE, tree: "d".repeat(40), files};
  const after = structuredClone(files);
  after["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"] = id("e");
  const sourceSnapshot = {commit: "f".repeat(40), tree: "1".repeat(40), files: after};
  const dependencySha256 = Object.fromEntries(DEPENDENCIES.map(p => [p, "A".repeat(64)]));
  const args = {baselineSnapshot, sourceSnapshot, dependencySha256};
  args.manifest = {schemaVersion: 1, documentType: "build31-business-source-inventory", profile: PROFILE,
    baseline: {}, source: {}, protectedRoots: [...PROTECTED_ROOTS], protectedDelta: [],
    dependencySha256: {...dependencySha256}};
  refreshMeasurement(args);
  return args;
}
function refreshMeasurement(args) {
  for (const [key, snapshot] of [["baseline", args.baselineSnapshot], ["source", args.sourceSnapshot]]) {
    const protectedFiles = Object.fromEntries(Object.entries(snapshot.files).filter(([p]) =>
      PROTECTED_ROOTS.some(root => p === root || p.startsWith(`${root}/`))));
    args.manifest[key] = {commit: snapshot.commit, tree: snapshot.tree,
      protectedPopulationSha256: digest(canonical(protectedFiles))};
  }
  const before = args.baselineSnapshot.files, after = args.sourceSnapshot.files;
  args.manifest.protectedDelta = [...new Set([...Object.keys(before), ...Object.keys(after)])].sort()
    .filter(p => !require("node:util").isDeepStrictEqual(before[p], after[p]))
    .map(p => ({path: p, before: before[p] ? {...before[p]} : null, after: after[p] ? {...after[p]} : null}));
  signFixture(args);
}
function signFixture(args) { args.trustedManifestSha256 = digest(canonical(args.manifest)); }
function fails(mutate, pattern, {remeasure = false, rehash = false} = {}) {
  const args = fixture(); mutate(args);
  if (remeasure) refreshMeasurement(args); else if (rehash) signFixture(args);
  assert.throws(() => validateSourceInventory31(args), pattern);
}
test("exact separately trusted source inventory gives measurement, never authority", () => {
  const args = fixture(), original = structuredClone(args);
  const proof = validateSourceInventory31(args);
  assert.equal(proof.profile, PROFILE);
  assert.deepEqual(proof.changedPaths, ["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"]);
  assert.equal(proof.deploymentAuthority, false);
  assert.equal(proof.credentialAccessAuthorized, false);
  assert.deepEqual(args, original);
});
test("changed manifest fails its independent digest", () => fails(a => a.manifest.source.tree = "2".repeat(40), /digest mismatch/));
test("extra manifest key is not admitted even after rehash", () => fails(a => a.manifest.approved = true, /exact keys/, {rehash: true}));
test("old grpc profile cannot be reinterpreted", () => fails(a => a.manifest.profile = "build31-exact-grpc-runtime-backend-v1", /Distinct business/, {rehash: true}));
test("baseline identity remains exact deployed F", () => fails(a => a.baselineSnapshot.commit = "2".repeat(40), /Wrong deployed/, {remeasure: true}));
test("source tree and complete population must match manifest", () => {
  fails(a => a.sourceSnapshot.tree = "2".repeat(40), /complete source population/);
  fails(a => a.sourceSnapshot.files["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"] = id("3"), /complete source population/);
});
for (const path of ["firestore.rules", "firestore.indexes.json", "firebase.json", ".firebaserc",
  "android/app/build.gradle.kts", "release/function-fleet-runtime-identity-policy.json",
  "functions/src/submissionRecovery.ts", "functions/src/newHiddenHandler.ts",
  "tooling/firebase-cli/newExecutable.js"]) {
  test(`out-of-scope ${path} fails even with coherent rehashed manifest`, () => fails(a => {
    a.sourceSnapshot.files[path] = id("4");
  }, /unadmitted source delta/, {remeasure: true}));
}
test("deleting even an admitted implementation fails", () => fails(a => {
  delete a.sourceSnapshot.files["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"];
}, /Deleting admitted/, {remeasure: true}));
test("new finite gate module may be admitted only with exact blob", () => {
  const a = fixture(); a.sourceSnapshot.files["functions/src/maintenanceWorkflow/inspectionAuthoringPolicy.ts"] = id("5");
  refreshMeasurement(a); assert.equal(validateSourceInventory31(a).changedPaths.length, 2);
  a.sourceSnapshot.files["functions/src/maintenanceWorkflow/inspectionAuthoringPolicy.ts"] = id("6");
  assert.throws(() => validateSourceInventory31(a), /complete source population/);
});
for (const mode of ["100755", "120000", "160000"]) test(`changed mode ${mode} refused`, () => fails(a => {
  a.sourceSnapshot.files["functions/src/maintenanceWorkflow/inspectionCampaignHandlers.ts"].mode = mode;
}, mode === "100755" ? /non-executable/ : /regular Git blob/, {remeasure: true}));
test("omitted declared change cannot hide actual difference", () => fails(a => {
  a.manifest.protectedDelta[0].after.oid = "4".repeat(40);
}, /Actual protected delta/, {rehash: true}));
test("repeated or unordered delta refused", () => fails(a => {
  a.manifest.protectedDelta.push(structuredClone(a.manifest.protectedDelta[0]));
}, /Unordered, repeated/, {rehash: true}));
test("wildcard protected population is refused", () => fails(a => {
  a.manifest.protectedRoots = ["functions/**"];
}, /population scope/, {rehash: true}));
test("dependency content is measured separately from Git blob identity", () => fails(a => {
  a.dependencySha256[DEPENDENCIES[0]] = "B".repeat(64);
}, /Dependency bytes differ/));
test("missing or extra dependency binding is refused", () => {
  fails(a => delete a.dependencySha256[DEPENDENCIES[0]], /exact keys/);
  fails(a => a.manifest.dependencySha256["unrelated.json"] = "C".repeat(64), /exact keys/, {rehash: true});
});
test("production entry refuses branch names before opening repository", () => {
  assert.throws(() => verifyBusiness31Source({sourceCommit: "main"}), /Exact source commit/);
});
