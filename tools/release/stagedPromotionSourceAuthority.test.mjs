import assert from "node:assert/strict";
import {test} from "node:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {verifyStagedPromotionSourceAuthority} = require("./stagedPromotionSourceAuthority.js");
const {sealReceipt} = require("./collectProductionGlobalPullBackend.js");
const PROJECT = "crm3-baf-ops-b8638";
const PASS = "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK";
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "crm3-staged-source-test-"));
  t.after(() => {
    const resolved = fs.realpathSync(root);
    assert.equal(path.dirname(resolved), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(resolved), /^crm3-staged-source-test-/);
    fs.rmSync(resolved, {recursive: true, force: true});
  });
  const git = (...args) => execFileSync("git", ["-C", root, ...args],
    {encoding: "utf8", windowsHide: true, stdio: ["ignore", "pipe", "pipe"]}).trim();
  git("init", "--quiet");
  fs.writeFileSync(path.join(root, "backend.txt"), "deployed backend\n");
  git("add", "backend.txt");
  git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
    "commit", "--quiet", "-m", "deployed fixture");
  const commit = git("rev-parse", "HEAD");
  const tree = git("rev-parse", "HEAD^{tree}");
  function write(file, value) {
    const location = path.join(root, file);
    fs.mkdirSync(path.dirname(location), {recursive: true});
    const bytes = `${JSON.stringify(value, null, 2)}\n`;
    fs.writeFileSync(location, bytes);
    return sha(bytes);
  }
  const approvalPath = "release/approval.json";
  const backendPath = "release/backend.json";
  const versionPath = "release/version.json";
  const approval = {approved: true, firebaseProjectId: PROJECT,
    sourceAuthority: {commit}, approvedDeployment: {
      preserveExistingIamRequired: true, appCheckEnforcement: false}};
  const receipt = {firebaseProjectId: PROJECT, decision: PASS,
    sourceAuthority: {commit, tree, pullRequestNumber: 355},
    approvalAuthority: {file: approvalPath}, deployment: {functionCount: 15,
      allFunctionsExactSourceVerified: true, finalRuntimeIdentityReadbackPassed: true,
      finalIamDependencyReadbackPassed: true, existingIamPreservationEnforced: true,
      appCheckEnforcement: false}, controlBoundary: {iamMutated: false,
      productionBusinessDataMutated: false, artifactConstructed: false, distributionPerformed: false},
    cleanMainLiveReadbacks: {}};
  const children = {};
  for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
    children[key] = sealReceipt({fixture: key, passed: true});
    receipt.cleanMainLiveReadbacks[key] = {file: `release/${key}.json`,
      physicalSha256: write(`release/${key}.json`, children[key]),
      canonicalReceiptSha256: children[key].receiptSha256.toUpperCase()};
  }
  const version = {sourceBaseline: {commit}, requiredSource: {
    exactFunctionFleetDeploymentSourceCommit: commit,
    exactFunctionFleetDeploymentPullRequest: 355,
    exactFunctionFleetDeploymentReceiptFile: backendPath}};
  const policy = {firebaseProjectId: PROJECT,
    versionPolicy: {sourceDocumentFile: versionPath},
    finalization: {exactFunctionFleetDeploymentReceiptFile: backendPath}};
  const deployed = {functionFleetEvidenceFile: backendPath,
    functionFleetSourceCommit: commit, deploymentApprovalFile: approvalPath};
  const state = {authorityPlanes: {deployedBackend: deployed}};
  function persist() {
    deployed.deploymentApprovalSha256 = write(approvalPath, approval);
    receipt.approvalAuthority.sha256 = deployed.deploymentApprovalSha256;
    deployed.functionFleetEvidenceSha256 = write(backendPath, receipt);
    version.requiredSource.exactFunctionFleetDeploymentReceiptSha256 = deployed.functionFleetEvidenceSha256;
    policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = deployed.functionFleetEvidenceSha256;
    policy.versionPolicy.sourceDocumentSha256 = write(versionPath, version);
    write("release/current-successor-state.json", state);
  }
  persist();
  return {root, git, commit, tree, write, approval, receipt, children, version, policy,
    deployed, state, persist, verify: () => verifyStagedPromotionSourceAuthority({repoRoot: root, releasePolicy: policy})};
}

test("verifies and returns exact historical/current receipt identities", (t) => {
  const f = fixture(t);
  assert.deepEqual(f.verify(), {ok: true, reasons: [],
    historicalBackendReceiptFile: "release/backend.json",
    historicalBackendReceiptSha256: f.deployed.functionFleetEvidenceSha256,
    currentBackendReceiptFile: "release/backend.json",
    currentBackendReceiptSha256: f.deployed.functionFleetEvidenceSha256});
});

test("permits successor app/backend source pending at HEAD", (t) => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, "backend.txt"), "successor backend pending deployment\n");
  f.git("add", "backend.txt");
  f.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
    "commit", "--quiet", "-m", "pending successor fixture");
  assert.notEqual(f.git("rev-parse", "HEAD"), f.commit);
  f.state.authorityPlanes.currentSource = {backendDeploymentStatus: "PENDING"};
  f.deployed.currentSourceFunctionDeployment = "PENDING_SUCCESSOR_DEPLOYMENT";
  f.policy.finalization.sourceCommit = f.git("rev-parse", "HEAD");
  f.persist();
  assert.equal(f.verify().ok, true);
});

test("supports legacy deployed-source and pull-request fallbacks", (t) => {
  const f = fixture(t);
  delete f.version.requiredSource.exactFunctionFleetDeploymentSourceCommit;
  delete f.version.requiredSource.exactFunctionFleetDeploymentPullRequest;
  f.receipt.sourceAuthority.pullRequestNumber = 265;
  f.persist();
  assert.equal(f.verify().ok, true);
});

test("rejects coherently rehashed backend source with the wrong Git tree", (t) => {
  const f = fixture(t);
  f.receipt.sourceAuthority.tree = "a".repeat(40);
  f.persist();
  assert.equal(f.verify().ok, false);
  assert.match(f.verify().reasons[0], /Git tree/);
});

test("rejects coherent receipt/approval source changes outside the version authority", (t) => {
  const f = fixture(t);
  f.receipt.sourceAuthority.commit = "b".repeat(40);
  f.approval.sourceAuthority.commit = "b".repeat(40);
  f.deployed.functionFleetSourceCommit = "b".repeat(40);
  f.persist();
  assert.equal(f.verify().ok, false);
  assert.match(f.verify().reasons[0], /version authority/);
});

for (const change of ["approved", "project", "iam", "appCheck", "source", "binding"]) {
  test(`rejects coherently rehashed invalid backend approval: ${change}`, (t) => {
    const f = fixture(t);
    if (change === "approved") f.approval.approved = false;
    if (change === "project") f.approval.firebaseProjectId = "other-project";
    if (change === "iam") f.approval.approvedDeployment.preserveExistingIamRequired = false;
    if (change === "appCheck") f.approval.approvedDeployment.appCheckEnforcement = true;
    if (change === "source") f.approval.sourceAuthority.commit = "c".repeat(40);
    if (change === "binding") f.receipt.approvalAuthority.file = "release/other-approval.json";
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /approval/);
  });
}

for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
  test(`rejects rehashed ${key} child whose canonical seal is invalid`, (t) => {
    const f = fixture(t);
    f.children[key].passed = false;
    f.receipt.cleanMainLiveReadbacks[key].physicalSha256 =
      f.write(`release/${key}.json`, f.children[key]);
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /seal does not match/);
  });
}

test("rejects physical child tampering and canonical parent alias mismatch", (t) => {
  const f = fixture(t);
  f.write("release/functionFleet.json", sealReceipt({fixture: "tampered"}));
  assert.match(f.verify().reasons[0], /physical SHA-256/);
  f.receipt.cleanMainLiveReadbacks.functionFleet.physicalSha256 =
    f.write("release/functionFleet.json", f.children.functionFleet);
  f.receipt.cleanMainLiveReadbacks.functionFleet.canonicalReceiptSha256 = "d".repeat(64);
  f.persist();
  assert.match(f.verify().reasons[0], /canonical seal differs/);
});

for (const escaped of ["../outside.json", "release/../../outside.json", "C:\\outside.json", "/outside.json"]) {
  test(`rejects repository child path escape: ${escaped}`, (t) => {
    const f = fixture(t);
    f.receipt.cleanMainLiveReadbacks.functionFleet.file = escaped;
    f.persist();
    assert.equal(f.verify().ok, false);
    assert.match(f.verify().reasons[0], /path/);
  });
}

test("validates a full commit before invoking git", (t) => {
  const f = fixture(t);
  f.version.requiredSource.exactFunctionFleetDeploymentSourceCommit = "HEAD^{tree}";
  f.persist();
  assert.match(f.verify().reasons[0], /exactly 40 hexadecimal/);
});

test("allows a separately approved current deployment beyond historical finalization", (t) => {
  const f = fixture(t);
  const current = structuredClone(f.receipt);
  const currentPath = "release/new-current-backend.json";
  current.recordedAtUtc = "2026-09-09T00:00:00.000Z";
  f.deployed.functionFleetEvidenceFile = currentPath;
  f.deployed.functionFleetEvidenceSha256 = f.write(currentPath, current);
  f.write("release/current-successor-state.json", f.state);
  const result = f.verify();
  assert.equal(result.ok, true);
  assert.equal(result.historicalBackendReceiptFile, "release/backend.json");
  assert.equal(result.currentBackendReceiptFile, currentPath);
  assert.notEqual(result.historicalBackendReceiptSha256, result.currentBackendReceiptSha256);
});
