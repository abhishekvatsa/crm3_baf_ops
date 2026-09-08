import assert from "node:assert/strict";
import {test} from "node:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {execFileSync} from "node:child_process";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {verifyStagedPromotionSourceAuthority} = require("./stagedPromotionSourceAuthority.js");
const {sealReceipt: sealUnsealedReceipt} = require("./collectProductionGlobalPullBackend.js");
const sealReceipt = ({receiptSha256, ...body}) => sealUnsealedReceipt(body);
const PROJECT = "crm3-baf-ops-b8638";
const PASS = "PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK";
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readMeasured = (file) => JSON.parse(fs.readFileSync(path.join(repositoryRoot, file), 'utf8'));

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
  fs.mkdirSync(path.join(root, 'functions/src'), {recursive: true});
  fs.writeFileSync(path.join(root, 'functions/src/index.ts'), '// fixture backend\n');
  for (const file of ['release/function-fleet-runtime-identity-policy.json', 'release/lr03-lr06-functions-live-readback-policy.json']) {
    fs.mkdirSync(path.dirname(path.join(root, file)), {recursive: true});
    fs.copyFileSync(path.join(repositoryRoot, file), path.join(root, file));
  }
  for (const file of ['firestore.rules', 'firestore.indexes.json', 'functions/src/index.ts',
    'functions/package.json', 'functions/package-lock.json']) {
    const raw = execFileSync('git', ['-C', repositoryRoot, 'show', `2ab554d143bd778cfa1b4d9ab2ed3c35cf62b056:${file}`]);
    fs.writeFileSync(path.join(root, file), raw);
  }
  git("add", ".");
  git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
    "commit", "--quiet", "-m", "deployed fixture");
  const objects = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'],
    {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(root, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(root, '.git/objects/info/alternates'), `${objects.replace(/\\/g, '/')}\n`);
  const commit = '2ab554d143bd778cfa1b4d9ab2ed3c35cf62b056';
  const tree = git('rev-parse', `${commit}^{tree}`);
  const functionTree = git('rev-parse', `${commit}:functions`);
  function write(file, value) {
    const location = path.join(root, file);
    fs.mkdirSync(path.dirname(location), {recursive: true});
    const bytes = `${JSON.stringify(value, null, 2)}\n`;
    fs.writeFileSync(location, bytes);
    return sha(bytes);
  }
  const approvalPath = "release/approvals/build27-backend-deployment-approval.json";
  const backendPath = "release/backend.json";
  const versionPath = "release/version.json";
  const approval = readMeasured('release/approvals/build27-backend-deployment-approval.json');
  Object.assign(approval.sourceAuthority, {commit, tree, functionTree});
  const receipt = readMeasured('release/evidence/build27-backend-deployment-closure.json');
  Object.assign(receipt.sourceAuthority, {commit, tree, functionsGitObjectId: functionTree});
  receipt.approvalAuthority.file = approvalPath;
  receipt.cleanMainLiveReadbacks = {};
  const children = {};
  for (const key of ["functionFleet", "iamDependencies", "firestoreRulesAndIndexes"]) {
    const file = {functionFleet: 'build27-function-fleet-runtime-identity-readback.json',
      iamDependencies: 'build27-functions-iam-dependencies-readback.json',
      firestoreRulesAndIndexes: 'build27-firestore-rules-indexes-live-readback.json'}[key];
    const child = readMeasured(`release/evidence/${file}`);
    for (const point of ['before', 'after']) Object.assign(child.source[point], {commit, tree, originMain: commit});
    children[key] = sealReceipt(child);
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

test("supports the deployed-source fallback without relabeling its admitted pull request", (t) => {
  const f = fixture(t);
  delete f.version.requiredSource.exactFunctionFleetDeploymentSourceCommit;
  f.persist();
  assert.equal(f.verify().ok, true);
  delete f.version.requiredSource.exactFunctionFleetDeploymentPullRequest;
  f.receipt.sourceAuthority.pullRequestNumber = 265;
  f.approval.sourceAuthority.pullRequestNumber = 265;
  f.persist();
  assert.equal(f.verify().ok, false);
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

test("allows distinct current and historical receipts for the same admitted approval", (t) => {
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

test('a different current source requires its own admitted immutable approval custody', (t) => {
  const f = fixture(t);
  const commit = f.git('rev-parse', 'HEAD');
  const tree = f.git('rev-parse', 'HEAD^{tree}');
  const functionTree = f.git('rev-parse', 'HEAD:functions');
  const approval = structuredClone(f.approval);
  Object.assign(approval.sourceAuthority, {commit, tree, functionTree});
  const receipt = structuredClone(f.receipt);
  Object.assign(receipt.sourceAuthority, {commit, tree, functionsGitObjectId: functionTree});
  f.deployed.functionFleetSourceCommit = commit;
  f.deployed.deploymentApprovalFile = 'release/approvals/unadmitted-current-source.json';
  f.deployed.deploymentApprovalSha256 = f.write(f.deployed.deploymentApprovalFile, approval);
  receipt.approvalAuthority = {file: f.deployed.deploymentApprovalFile, sha256: f.deployed.deploymentApprovalSha256};
  f.deployed.functionFleetEvidenceFile = 'release/current-backend.json';
  f.deployed.functionFleetEvidenceSha256 = f.write(f.deployed.functionFleetEvidenceFile, receipt);
  f.write('release/current-successor-state.json', f.state);
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /source has no separately admitted immutable owner approval/);
});

test('deployment approval binds its entire source, authorization and deployment scope', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.approval);
  const fields = [
    'schemaVersion', 'documentType', 'region', 'sourceAuthority.tree', 'sourceAuthority.functionTree',
    'sourceAuthority.pullRequestNumber', 'sourceAuthority.requiredPostMergeReleaseGateRunId',
    'approvedAtUtc', 'approvalEvidence.authorityType', 'approvalEvidence.messageReceivedAtUtc',
    'approvedDeployment.functionCount',
    'approvedDeployment.existingDedicatedServiceAccountsRequired',
    'approvedDeployment.scheduledFunctionDeploymentAuthorized',
    'approvedDeployment.scheduledFunctionManualInvocationAuthorized',
    'approvedDeployment.firestoreRulesSha256', 'approvedDeployment.firestoreRulesMutationAuthorized',
    'approvedDeployment.firestoreIndexCount', 'approvedDeployment.firestoreIndexSetSha256',
    'approvedDeployment.firestoreIndexMutationAuthorized', 'approvedDeployment.strictLiveReadbackRequired',
    'approvedDeployment.postMergeReleaseGateMustPassBeforeDeployment',
  ];
  for (const field of fields) {
    const parts = field.split('.');
    const get = () => parts.slice(0, -1).reduce((value, part) => value[part], f.approval);
    const expected = get()[parts.at(-1)];
    const wrong = typeof expected === 'boolean' ? !expected : typeof expected === 'number' ? expected + 1 : 'wrong';
    for (const value of [wrong, null, undefined, [expected]]) {
      Object.assign(f.approval, structuredClone(original));
      if (value === undefined) delete get()[parts.at(-1)]; else get()[parts.at(-1)] = value;
      f.persist();
      assert.equal(f.verify().ok, false, `${field}: ${JSON.stringify(value)}`);
    }
  }
});

test('coherently rebound owner evidence cannot replace the admitted deployment instruction', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.approval);
  for (const [field, value] of [
    ['approverName', 'Different owner'],
    ['approvalEvidence.codexTaskId', 'different-task'],
    ['approvalEvidence.codexTurnId', 'different-turn'],
    ['approvalEvidence.codexMessageId', 'different-message'],
    ['approvalEvidence.codexClientMessageId', 'different-client-message'],
    ['approvalEvidence.instructionVerbatim', 'Do not deploy anything. No backend deployment is authorized.'],
    ['approvalEvidence.instructionSummary', 'Deployment is prohibited.'],
    ['approvalEvidence.scopeInterpretation', 'Authorize unrestricted distribution and IAM mutation.'],
  ]) {
    Object.assign(f.approval, structuredClone(original));
    const parts = field.split('.');
    const target = parts.slice(0, -1).reduce((value, part) => value[part], f.approval);
    target[parts.at(-1)] = value;
    f.persist();
    const result = f.verify();
    assert.equal(result.ok, false, field);
    assert.match(result.reasons[0], /approval.*custody/i);
  }
});

test('coherently resealed fleet and IAM children must still contain passing source-bound evidence', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  for (const key of ['functionFleet', 'iamDependencies']) {
    const original = structuredClone(f.children[key]);
    const cases = [
      (child) => { child.decision = 'HOLD'; },
      (child) => { child.failedChecks = ['sourceStable']; },
      (child) => { delete child.failedChecks; },
      (child) => { child.checks = {}; },
      (child) => { child.checks.sourceStable = false; },
      (child) => { child.source.before.commit = '0'.repeat(40); },
      (child) => { child.source.after.tree = '0'.repeat(40); },
      (child) => { child.source.after.governedWorktreeClean = 'true'; },
      (child) => { child.outputs.functions[0].state = 'FAILED'; },
      (child) => { child.mutationBoundary.iamMutated = true; },
      (child) => { child.privacyBoundary.userIdentityRetained = true; },
      (child) => { child.posture.deployedFunctionCount = '15'; },
      (child) => { child.checks.exactProjectAndRegion = [true]; },
      (child) => { child.outputs.functions[0].updateTime = '2020-01-01T00:00:00Z'; },
      (child) => { child.outputs.functions[0].firebaseFunctionsHash = '0'.repeat(40); },
      ...(key === 'iamDependencies' ? [
        (child) => {
          child.outputs.currentSourceDependencies.dependencyInventorySha256 = '0'.repeat(64);
          for (const fn of child.outputs.functions) fn.dependencies.dependencyInventorySha256 = '0'.repeat(64);
        },
      ] : []),
    ];
    for (const [index, mutate] of cases.entries()) {
      const child = structuredClone(original);
      mutate(child);
      const sealed = sealReceipt(child);
      f.receipt.cleanMainLiveReadbacks[key].canonicalReceiptSha256 = sealed.receiptSha256;
      f.receipt.cleanMainLiveReadbacks[key].physicalSha256 = f.write(`release/${key}.json`, sealed);
      f.persist();
      assert.equal(f.verify().ok, false, `${key} coherent case ${index}`);
    }
    f.children[key] = original;
    f.receipt.cleanMainLiveReadbacks[key].canonicalReceiptSha256 = original.receiptSha256;
    f.receipt.cleanMainLiveReadbacks[key].physicalSha256 = f.write(`release/${key}.json`, original);
    f.persist();
  }
});

test('a separate current backend must satisfy each child decision after coherent resealing', (t) => {
  const f = fixture(t);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const original = structuredClone(f.receipt);
  f.deployed.functionFleetEvidenceFile = 'release/current-backend.json';
  for (const key of ['functionFleet', 'iamDependencies', 'firestoreRulesAndIndexes']) {
    const current = structuredClone(original);
    const child = structuredClone(f.children[key]);
    if (key === 'firestoreRulesAndIndexes') child.outputs.indexes.apiCount -= 1;
    else child.outputs.functions[0].state = 'FAILED';
    const sealed = sealReceipt(child);
    current.cleanMainLiveReadbacks[key] = {...current.cleanMainLiveReadbacks[key],
      file: `release/current-${key}.json`, canonicalReceiptSha256: sealed.receiptSha256,
      physicalSha256: f.write(`release/current-${key}.json`, sealed)};
    f.deployed.functionFleetEvidenceSha256 = f.write(f.deployed.functionFleetEvidenceFile, current);
    f.write('release/current-successor-state.json', f.state);
    const result = f.verify();
    assert.equal(result.ok, false, `${key} current decision`);
    assert.match(result.reasons[0], new RegExp(`${key}: decision`));
  }
});

test('deployment authority timestamps reject arrays, invalid dates and reversed nanoseconds', (t) => {
  const f = fixture(t);
  const original = structuredClone(f.receipt.authorityChronology);
  for (const mutate of [
    (value) => { value.ownerInstructionReceivedAtUtc = [value.ownerInstructionReceivedAtUtc]; },
    (value) => { value.earliestFunctionUpdateTime = '2026-09-08T00:50:50.123456789Z'; value.latestFunctionUpdateTime = '2026-09-08T00:50:50.123456788Z'; },
    (value) => { value.earliestFunctionUpdateTime = '2026-02-30T00:50:50Z'; },
  ]) {
    f.receipt.authorityChronology = structuredClone(original);
    mutate(f.receipt.authorityChronology);
    f.persist();
    assert.equal(f.verify().ok, false);
  }
});

test('a separate historical backend cannot omit its approval digest', (t) => {
  const f = fixture(t);
  const current = structuredClone(f.receipt);
  const currentFile = 'release/current-backend.json';
  const currentHash = f.write(currentFile, current);
  delete f.receipt.approvalAuthority.sha256;
  const historicalHash = f.write('release/backend.json', f.receipt);
  f.version.requiredSource.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = historicalHash;
  f.policy.versionPolicy.sourceDocumentSha256 = f.write('release/version.json', f.version);
  f.deployed.functionFleetEvidenceFile = currentFile;
  f.deployed.functionFleetEvidenceSha256 = currentHash;
  f.write('release/current-successor-state.json', f.state);
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /Historical backend approval: physical SHA-256/);
});

test('promotion governance remains bound to the recorded Git tree and complete CI evidence in both receipts', (t) => {
  const f = fixture(t);
  const promotion = readMeasured('release/evidence/build-27-staged-controlled-pilot-authorization.json');
  const device = readMeasured(promotion.admittedEvidence.deviceAcceptance.receipt);
  f.write(promotion.ownerApproval.receipt, readMeasured(promotion.ownerApproval.receipt));
  const originalPromotion = structuredClone(promotion);
  const originalDevice = structuredClone(device);
  f.policy.postBuildPromotion = {status: 'completed-staged-controlled-pilot-only',
    promotionReceiptFile: 'release/promotion.json'};
  const persist = () => {
    promotion.admittedEvidence.deviceAcceptance.sha256 = f.write(promotion.admittedEvidence.deviceAcceptance.receipt, device);
    f.policy.postBuildPromotion.promotionReceiptSha256 = f.write('release/promotion.json', promotion);
  };
  persist();
  // No foreign Git objects: even otherwise matching receipts must fail closed.
  fs.unlinkSync(path.join(f.root, '.git/objects/info/alternates'));
  assert.equal(f.verify().ok, false);
  const objects = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'],
    {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(f.root, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(f.root, '.git/objects/info/alternates'), `${objects.replace(/\\/g, '/')}\n`);
  assert.equal(f.verify().ok, true, f.verify().reasons.join('; '));
  const policyFile = 'release/test-policy.json';
  f.write(policyFile, f.policy);
  const script = path.join(repositoryRoot, 'tools/release/stagedPromotionSourceAuthority.js');
  const cli = () => execFileSync(process.execPath, [script, f.root, path.join(f.root, policyFile)],
    {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
  assert.equal(JSON.parse(cli()).ok, true);
  for (const mutate of [
    () => { promotion.sourceAuthority.governanceMainCommit = device.sourceAndCiAuthority.governanceMainCommit = '0'.repeat(40); },
    () => { promotion.sourceAuthority.governanceMainTree = device.sourceAndCiAuthority.governanceMainTree = '0'.repeat(40); },
    () => { promotion.sourceAuthority.postMergeCi.runId = device.sourceAndCiAuthority.postMergeReleaseGateRunId = 1; },
    () => { delete promotion.sourceAuthority.postMergeCi.requiredJobCount; },
    () => { delete device.sourceAndCiAuthority.requiredJobCount; },
    () => { device.sourceAndCiAuthority.allRequiredJobsPassed = [true]; },
  ]) {
    Object.assign(promotion, structuredClone(originalPromotion));
    Object.assign(device, structuredClone(originalDevice));
    mutate();
    persist();
    const result = f.verify();
    assert.equal(result.ok, false);
    assert.match(result.reasons[0], /Promotion governance/);
  }
  for (const field of ['instructionVerbatim', 'codexThreadId', 'instructionContext', 'scopeInterpretation']) {
    Object.assign(promotion, structuredClone(originalPromotion));
    Object.assign(device, structuredClone(originalDevice));
    const pilotApproval = readMeasured(promotion.ownerApproval.receipt);
    pilotApproval.authority[field] = 'No pilot distribution is authorized by this owner instruction.';
    promotion.ownerApproval.sha256 = f.write(promotion.ownerApproval.receipt, pilotApproval);
    persist();
    const result = f.verify();
    assert.equal(result.ok, false, field);
    assert.match(result.reasons[0], /Pilot owner: approval.*custody/);
  }
  f.write(policyFile, f.policy);
  assert.throws(cli, /Command failed/);
});

test('mutable Git replacement refs cannot replace the admitted approval custody', (t) => {
  const f = fixture(t);
  f.approval.approverName = 'Different owner';
  f.approval.approvalEvidence.instructionVerbatim = 'Do not deploy anything.';
  f.persist();
  f.git('add', '.');
  f.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
    'commit', '--quiet', '-m', 'Unadmitted replacement custody');
  f.git('replace', '41adfaecd7974f3f48b9f023a90890c860ab44af', f.git('rev-parse', 'HEAD'));
  const result = f.verify();
  assert.equal(result.ok, false);
  assert.match(result.reasons[0], /approval.*custody/);
});
