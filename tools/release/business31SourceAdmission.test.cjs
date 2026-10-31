"use strict";
const test = require("node:test"), assert = require("node:assert/strict");
const path = require("node:path");
const {execFileSync} = require("node:child_process");
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
    .filter(p => PROTECTED_ROOTS.some(root => p === root || p.startsWith(`${root}/`)))
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

for (const file of ["tooling/stream-json-compat/README.md", "tooling/stream-json-compat/package.json"]) {
  test(`merged JSON adapter metadata ${file} still needs its exact reviewed blob`, () => {
    const a = fixture(); a.sourceSnapshot.files[file] = id("5"); refreshMeasurement(a);
    assert.ok(validateSourceInventory31(a).changedPaths.includes(file));
    a.sourceSnapshot.files[file] = id("6");
    assert.throws(() => validateSourceInventory31(a), /complete source population/);
  });
}
test("JSON adapter admission does not allow an unreviewed neighboring runtime file", () => fails(a => {
  a.sourceSnapshot.files["tooling/stream-json-compat/filters/Replace.cjs"] = id("4");
}, /unadmitted source delta/, {remeasure: true}));

// Exact reviewed delta records exercise the complete finite scope. These compact
// structural snapshots omit unchanged files and are not full Git/deployment proof.
const reviewedDelta = require("./testdata/business31ReviewedProtectedDelta.json");
const reviewedJsonRuntimePaths = Object.freeze([
  "tooling/stream-json-compat/index.cjs",
  "tooling/stream-json-compat/filters/Filter.cjs",
  "tooling/stream-json-compat/filters/Pick.cjs",
  "tooling/stream-json-compat/streamers/StreamArray.cjs",
  "tooling/stream-json-compat/streamers/StreamObject.cjs",
]);
const reviewedDeepmergePaths = Object.freeze([
  "tooling/deepmerge-prototype-guard/README.md",
  "tooling/deepmerge-prototype-guard/UPSTREAM.json",
  "tooling/deepmerge-prototype-guard/index.d.ts",
  "tooling/deepmerge-prototype-guard/index.js",
  "tooling/deepmerge-prototype-guard/license.txt",
  "tooling/deepmerge-prototype-guard/package.json",
  "tooling/deepmerge-prototype-guard/patches/EXACT_INVERSE_SUBSTITUTIONS.json",
  "tooling/deepmerge-prototype-guard/patches/EXACT_SUBSTITUTIONS.json",
  "tooling/deepmerge-prototype-guard/patches/forward.patch",
  "tooling/deepmerge-prototype-guard/patches/inverse.patch",
]);
function reviewedDeltaFixture() {
  const args = fixture(), before = {}, after = {};
  for (const entry of reviewedDelta.protectedDelta) {
    if (entry.before) before[entry.path] = {...entry.before};
    if (entry.after) after[entry.path] = {...entry.after};
  }
  args.baselineSnapshot.files = before;
  args.sourceSnapshot.files = after;
  args.sourceSnapshot.commit = reviewedDelta.reviewedSourceCommit;
  args.dependencySha256 = {...reviewedDelta.dependencySha256};
  args.manifest.dependencySha256 = {...reviewedDelta.dependencySha256};
  refreshMeasurement(args);
  return args;
}

test("all 46 reviewed protected changes, including exactly five JSON runtime files and ten deepmerge files, are admitted", () => {
  const args = reviewedDeltaFixture(), original = structuredClone(args);
  assert.equal(args.baselineSnapshot.commit, reviewedDelta.baselineCommit);
  assert.equal(reviewedDelta.protectedDelta.length, 46);
  assert.deepEqual(args.manifest.protectedDelta, reviewedDelta.protectedDelta);
  const proof = validateSourceInventory31(args);
  assert.deepEqual(proof.changedPaths, reviewedDelta.protectedDelta.map(entry => entry.path));
  assert.equal(reviewedJsonRuntimePaths.length, 5);
  assert.equal(proof.changedPaths.filter(p => !reviewedJsonRuntimePaths.includes(p)).length, 41);
  for (const name of reviewedJsonRuntimePaths) assert.ok(proof.changedPaths.includes(name), name);
  assert.deepEqual(proof.changedPaths.filter(p => p.startsWith("tooling/deepmerge-prototype-guard/")),
    reviewedDeepmergePaths);
  assert.equal(proof.deploymentAuthority, false);
  assert.equal(proof.credentialAccessAuthorized, false);
  assert.deepEqual(args, original);
});

for (const name of reviewedJsonRuntimePaths) test(`reviewed JSON runtime ${name} remains blob-bound`, () => {
  const args = reviewedDeltaFixture();
  args.sourceSnapshot.files[name].oid = "0".repeat(40);
  assert.throws(() => validateSourceInventory31(args), /complete source population/);
  const declared = reviewedDeltaFixture();
  declared.manifest.protectedDelta.find(entry => entry.path === name).after.oid = "0".repeat(40);
  signFixture(declared);
  assert.throws(() => validateSourceInventory31(declared), /Actual protected delta/);
});

test("the complete reviewed delta cannot substitute an unreviewed sibling with a coherent digest", () => {
  const args = reviewedDeltaFixture(), path = reviewedJsonRuntimePaths[0];
  args.sourceSnapshot.files[path] = {...args.baselineSnapshot.files[path]};
  args.sourceSnapshot.files["tooling/stream-json-compat/filters/Replace.cjs"] = id("4");
  refreshMeasurement(args);
  assert.equal(args.manifest.protectedDelta.length, 46);
  assert.throws(() => validateSourceInventory31(args), /unadmitted source delta/);
});

for (const name of reviewedDeepmergePaths) {
  test(`reviewed deepmerge ${name} is admitted with its exact added blob`, () => {
    const args = reviewedDeltaFixture();
    assert.equal(args.baselineSnapshot.files[name], undefined);
    assert.equal(args.sourceSnapshot.files[name].mode, "100644");
    assert.ok(validateSourceInventory31(args).changedPaths.includes(name));
    args.sourceSnapshot.files[name].oid = "0".repeat(40);
    assert.throws(() => validateSourceInventory31(args), /complete source population/);
    const declared = reviewedDeltaFixture();
    declared.manifest.protectedDelta.find(entry => entry.path === name).after.oid = "0".repeat(40);
    signFixture(declared);
    assert.throws(() => validateSourceInventory31(declared), /Actual protected delta/);
  });
  test(`reviewed deepmerge ${name} cannot be missing from the source or declared delta`, () => {
    const missing = reviewedDeltaFixture();
    delete missing.sourceSnapshot.files[name];
    assert.throws(() => validateSourceInventory31(missing), /complete source population/);
    const partial = reviewedDeltaFixture();
    partial.manifest.protectedDelta = partial.manifest.protectedDelta.filter(entry => entry.path !== name);
    signFixture(partial);
    assert.throws(() => validateSourceInventory31(partial), /Actual protected delta/);
  });
  test(`reviewed deepmerge ${name} does not admit deletion or a changed mode`, () => {
    // Synthetic deletion variant: even an admitted path present in the baseline
    // cannot be removed by coherently remeasuring and rehashing the manifest.
    const deleted = reviewedDeltaFixture();
    deleted.baselineSnapshot.files[name] = {...deleted.sourceSnapshot.files[name]};
    delete deleted.sourceSnapshot.files[name];
    refreshMeasurement(deleted);
    assert.throws(() => validateSourceInventory31(deleted), /Deleting admitted/);
    for (const mode of ["100755", "120000", "160000"]) {
      const changed = reviewedDeltaFixture();
      changed.sourceSnapshot.files[name].mode = mode;
      refreshMeasurement(changed);
      assert.throws(() => validateSourceInventory31(changed),
        mode === "100755" ? /non-executable/ : /regular Git blob/);
    }
  });
}
test("deepmerge admission cannot substitute an unlisted neighboring file with a coherent digest", () => {
  const args = reviewedDeltaFixture();
  delete args.sourceSnapshot.files[reviewedDeepmergePaths[0]];
  args.sourceSnapshot.files["tooling/deepmerge-prototype-guard/unreviewed.js"] = id("4");
  refreshMeasurement(args);
  assert.equal(args.manifest.protectedDelta.length, 46);
  assert.throws(() => validateSourceInventory31(args), /unadmitted source delta/);
});

// This regression measures complete trees and dependency blobs from local Git,
// not the compact fixture above. It exercises the structural validator over real
// Git data; it does not establish the production private-repository trust boundary.
// Full history is required (CI checks out fetch-depth: 0); no fetch or skip fallback.
function measuredGitFixtures() {
  const root = path.resolve(__dirname, "../..");
  const executable = process.env.BUSINESS31_TEST_GIT ||
    (process.platform === "win32" ? "C:/Program Files/Git/mingw64/bin/git.exe" : "/usr/bin/git");
  const env = {...process.env, GIT_CONFIG_NOSYSTEM: "1",
    GIT_CONFIG_GLOBAL: process.platform === "win32" ? "NUL" : "/dev/null", GIT_NO_REPLACE_OBJECTS: "1",
    GIT_NO_LAZY_FETCH: "1", GIT_TERMINAL_PROMPT: "0"};
  for (const key of Object.keys(env)) if (/^GIT_(?:CONFIG_COUNT|CONFIG_KEY_|CONFIG_VALUE_|DIR$|WORK_TREE$|INDEX_FILE$|OBJECT_DIRECTORY$|ALTERNATE_OBJECT_DIRECTORIES$)/i.test(key)) delete env[key];
  const git = args => execFileSync(executable, ["-c", "protocol.allow=never", "-C", root, ...args],
    {env, timeout: 30000, maxBuffer: 16 * 1024 * 1024, windowsHide: true, stdio: ["pipe", "pipe", "pipe"]});
  const exact = value => {
    const commit = value.toString("utf8").trim();
    assert.match(commit, /^[a-f0-9]{40}$/);
    return commit;
  };
  const snapshot = commit => {
    const files = {};
    for (const row of git(["ls-tree", "-r", "-z", "--full-tree", commit]).toString("utf8").split("\0")) {
      if (!row) continue;
      const match = /^([0-9]{6}) blob ([a-f0-9]{40})\t(.+)$/s.exec(row);
      assert.ok(match, `Regular Git blob row required: ${row}`);
      assert.ok(!Object.hasOwn(files, match[3]), `Repeated Git path: ${match[3]}`);
      files[match[3]] = {mode: match[1], oid: match[2]};
    }
    return {commit, tree: exact(git(["rev-parse", `${commit}^{tree}`])), files};
  };
  assert.equal(reviewedDelta.baselineCommit, BASELINE);
  const reviewedCommit = "15ff88f3e7bb1496405953a004a0f6b534960051";
  assert.equal(reviewedDelta.reviewedSourceCommit, reviewedCommit);
  const currentCommit = exact(git(["rev-parse", "HEAD^{commit}"]));
  git(["merge-base", "--is-ancestor", BASELINE, reviewedCommit]);
  git(["merge-base", "--is-ancestor", reviewedCommit, currentCommit]);
  const baselineSnapshot = snapshot(BASELINE);
  return [reviewedCommit, currentCommit].map(commit => {
    const args = fixture();
    args.baselineSnapshot = baselineSnapshot;
    args.sourceSnapshot = snapshot(commit);
    args.dependencySha256 = Object.fromEntries(DEPENDENCIES.map(name =>
      [name, digest(git(["cat-file", "blob", `${commit}:${name}`]))]));
    args.manifest.dependencySha256 = {...args.dependencySha256};
    refreshMeasurement(args);
    return args;
  });
}
test("full baseline-to-15ff and current HEAD Git populations expose every protected change", () => {
  const [reviewed, current] = measuredGitFixtures();
  for (const args of [reviewed, current]) {
    const original = structuredClone(args);
    assert.equal(Object.keys(args.baselineSnapshot.files).length > 335, true);
    assert.equal(Object.keys(args.sourceSnapshot.files).length > 362, true);
    assert.deepEqual(args.manifest.protectedDelta, reviewedDelta.protectedDelta);
    assert.deepEqual(args.dependencySha256, reviewedDelta.dependencySha256);
    const proof = validateSourceInventory31(args);
    assert.equal(proof.protectedFileCount, 362);
    assert.equal(proof.changedPaths.length, 46);
    assert.equal(proof.changedPaths.filter(p => reviewedJsonRuntimePaths.includes(p)).length, 5);
    assert.equal(proof.changedPaths.filter(p => !reviewedJsonRuntimePaths.includes(p)).length, 41);
    assert.deepEqual(proof.baseline, args.manifest.baseline);
    assert.deepEqual(proof.source, args.manifest.source);
    assert.equal(proof.deploymentAuthority, false);
    assert.equal(proof.credentialAccessAuthorized, false);
    assert.deepEqual(args, original);
    const partial = structuredClone(args);
    partial.manifest.protectedDelta = partial.manifest.protectedDelta.filter(entry =>
      !reviewedDeepmergePaths.includes(entry.path));
    assert.equal(partial.manifest.protectedDelta.length, 36);
    signFixture(partial);
    assert.throws(() => validateSourceInventory31(partial), /Actual protected delta/);
  }
});
