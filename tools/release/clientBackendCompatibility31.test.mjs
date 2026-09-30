import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';

const require = createRequire(import.meta.url);
const {verifyBuild31ClientCompatibility, verifyClientBackendSourceAuthority: verifyStagedPromotionSourceAuthority} = require('./clientBackendCompatibility31.js');
const {sealReceipt} = require('./collectProductionGlobalPullBackend.js');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const baseline = '7ed87824447f1349cb0481c448e0b21c3fa5856f';
const backendFile = 'release/evidence/build30-current-source-backend-deployment-closure.json';
const backendSha256 = '3F7065A8540E66B9D879F157861C6DA722A16EFAC21EB9D2FEB9735D71573C45';
const backendCommit = '2aa30de56cfdb960da3eeefd8956d8cbbae57b46';
const decisionFile = 'release/approvals/build31-client-backend-compatibility-approval.json';
const ownerFile = 'release/approvals/build31-client-owner-authorization.json';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const releaseJobs = ['Flutter host analysis + tests + no-loss contracts',
  'Android release package + cold-start proof (non-production)',
  'Android emulator shell + business integration (not physical-device evidence)',
  'Firestore Rules + governed callable emulator', 'Cloud Functions host build + non-emulator tests'];
const securityJobs = ['CodeQL (actions)', 'CodeQL (java-kotlin)', 'CodeQL (javascript-typescript)', 'CodeQL (python)'];

// Synthetic Git/CI/readbacks test the protocol. They are never production authority.
function fixture(t, options = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-client31-'));
  t.after(() => {
    const actual = fs.realpathSync(directory);
    assert.equal(path.dirname(actual), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(actual), /^crm3-client31-/);
    fs.rmSync(actual, {recursive: true});
  });
  const git = (...args) => execFileSync('git', ['--no-replace-objects', '-C', directory, ...args],
    {encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']}).trim();
  git('init', '--quiet');
  const objects = execFileSync('git', ['-C', root, 'rev-parse', '--path-format=absolute', '--git-path', 'objects'], {encoding: 'utf8'}).trim();
  fs.mkdirSync(path.join(directory, '.git/objects/info'), {recursive: true});
  fs.writeFileSync(path.join(directory, '.git/objects/info/alternates'), `${objects.replaceAll('\\', '/')}\n`);
  const now = Date.now(), instant = delta => new Date(now + delta).toISOString();
  const commit = (parent, delta) => execFileSync('git', ['-C', directory, 'commit-tree', git('write-tree'), '-p', parent, '-m', 'Synthetic client31 fixture'],
    {encoding: 'utf8', windowsHide: true, env: {...process.env,
      GIT_AUTHOR_NAME: 'Synthetic Fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
      GIT_COMMITTER_NAME: 'Synthetic Fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid',
      GIT_AUTHOR_DATE: instant(delta), GIT_COMMITTER_DATE: instant(delta)}}).trim();
  const write = (file, value) => {
    const bytes = `${JSON.stringify(value, null, 2)}\n`;
    fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});
    fs.writeFileSync(path.join(directory, file), bytes);
    git('add', '--', file); return {file, sha256: sha(bytes)};
  };
  git('read-tree', baseline);
  write(options.drift ?? 'lib/synthetic_client31_fixture.json', {synthetic: true});
  const sourceCommit = commit(options.unrelatedSource ? backendCommit : baseline, -120000);
  const source = {commit: sourceCommit, tree: git('rev-parse', `${sourceCommit}^{tree}`),
    functionsGitObjectId: git('rev-parse', `${sourceCommit}:functions`), pullRequestNumber: 999,
    postMergeReleaseGateRunId: 1001, postMergeSecurityRunId: 1002};
  const scope = {clientConstructionOnly: true, backendDeploymentAuthorized: false,
    backendSourceChanged: false, firestoreRulesOrIndexesChanged: false,
    iamOrEnforcementChangeAuthorized: false, distributionAuthorized: false};
  const originalBytes = fs.readFileSync(path.join(root, backendFile));
  assert.equal(sha(originalBytes), backendSha256);
  fs.mkdirSync(path.dirname(path.join(directory, backendFile)), {recursive: true});
  fs.writeFileSync(path.join(directory, backendFile), originalBytes); git('add', '--', backendFile);
  const backend = JSON.parse(originalBytes);
  const existingBackend = {file: backendFile, sha256: backendSha256, sourceCommit: backendCommit};
  const owner = {schemaVersion: 1, documentType: 'source-specific-client-existing-backend-owner-authorization',
    approved: true, intendedBuildNumber: 31, firebaseProjectId: 'crm3-baf-ops-b8638',
    sourceCommit, sourceTree: source.tree, existingBackend, scope, ownerInstruction: 'Synthetic test only: authorize this exact client source over the unchanged backend.',
    ownerReference: 'synthetic-test-only', recordedBy: 'Synthetic Fixture', authorizedAtUtc: instant(-45000), recordedAtUtc: instant(-40000)};
  const decision = {schemaVersion: 1, documentType: 'governed-client-existing-backend-compatibility-approval',
    approved: true, intendedBuildNumber: 31, firebaseProjectId: 'crm3-baf-ops-b8638',
    approverName: 'Codex acting under project-owner delegation', approvedAtUtc: instant(-10000),
    sourceAuthority: source, existingBackend, scope,
    approvalEvidence: {authorityType: 'owner-delegated agent decision',
      delegationPolicyId: 'BUILD31-CLIENT-EXISTING-BACKEND-COMPATIBILITY',
      delegatedDecisionAtUtc: instant(-10000), recordedAtUtc: instant(-9000),
      ownerReference: owner.ownerReference, instructionExcerpts: [owner.ownerInstruction]}, liveBackendReadbacks: {}};
  const ci = {};
  for (const [key, file, evidenceType, workflow, names, id] of [
    ['mainCi', 'release/evidence/build31-client-source-main-ci.json', 'github-exact-main-release-gate', '.github/workflows/release-gate.yml', releaseJobs, 1001],
    ['securityCi', 'release/evidence/build31-client-source-main-security.json', 'github-exact-main-codeql', '.github/workflows/codeql.yml', securityJobs, 1002],
  ]) {
    ci[key] = {schemaVersion: 1, evidenceType, repository: 'abhishekvatsa/crm3_baf_ops', sourceCommit, sourceTree: source.tree,
      capturedAtUtc: instant(-55000), pullRequest: {number: 999, merged: true, merge_commit_sha: sourceCommit,
        merged_at: instant(-115000), base: {ref: 'main', repo: {full_name: 'abhishekvatsa/crm3_baf_ops'}}},
      run: {id, repository: {full_name: 'abhishekvatsa/crm3_baf_ops'}, head_sha: sourceCommit, head_branch: 'main',
        event: 'push', path: workflow, status: 'completed', conclusion: 'success', created_at: instant(-110000), updated_at: instant(-60000)},
      jobs: {total_count: names.length, jobs: names.map((name, index) => ({id: id * 100 + index, name, run_id: id,
        head_sha: sourceCommit, status: 'completed', conclusion: 'success', completed_at: instant(-65000)}))}};
    source[key] = {file};
  }
  const readbacks = {};
  for (const key of ['functionFleet', 'iamDependencies', 'firestoreRulesAndIndexes']) {
    readbacks[key] = JSON.parse(fs.readFileSync(path.join(root, backend.cleanMainLiveReadbacks[key].file), 'utf8'));
    for (const point of ['before', 'after']) Object.assign(readbacks[key].source[point], {commit: sourceCommit, tree: source.tree, originMain: sourceCommit});
    readbacks[key].capturedAtUtc = instant(-30000);
    if (key === 'functionFleet') readbacks[key].outputs.schedulerBacklog.observedAtUtc = instant(-35000);
    if (Object.hasOwn(readbacks[key], 'collectionStartedAtUtc')) readbacks[key].collectionStartedAtUtc = instant(-35000);
  }
  const policy = {firebaseProjectId: 'crm3-baf-ops-b8638', release: {buildNumber: 31}, versionPolicy: {buildNumber: 31},
    finalization: {exactFunctionFleetDeploymentReceiptFile: backendFile, exactFunctionFleetDeploymentReceiptSha256: backendSha256}};
  const version = {sourceBaseline: {commit: sourceCommit, tree: source.tree}, requiredSource: {}};
  const persist = () => {
    for (const key of ['mainCi', 'securityCi']) source[key] = write(source[key].file, ci[key]);
    for (const key of Object.keys(readbacks)) {
      const {receiptSha256, ...body} = readbacks[key];
      decision.liveBackendReadbacks[key] = write(`release/evidence/build31-client-compatibility-${key}.json`, sealReceipt(body));
    }
    decision.approvalEvidence.ownerAuthorization = write(ownerFile, owner);
    const pointer = write(decisionFile, decision);
    pointer.commit = commit(options.unrelatedCustody ? baseline : sourceCommit, -5000);
    git('update-ref', 'refs/heads/fixture', pointer.commit);
    git('symbolic-ref', 'HEAD', 'refs/heads/fixture');
    policy.clientBackendCompatibility = pointer;
    version.requiredSource.clientBackendCompatibility = structuredClone(pointer);
  };
  persist();
  return {directory, policy, version, backend, source, owner, decision, ci, readbacks, persist,
    verify: () => verifyBuild31ClientCompatibility({repoRoot: directory, releasePolicy: policy, version, backendReceipt: backend})};
}

test('Build31 admits a fresh exact client decision over the original unchanged backend without redeployment', t => {
  const f = fixture(t);
  const result = f.verify();
  assert.equal(result.sourceCommit, f.source.commit);
  assert.equal(result.file, decisionFile);
  assert.equal(f.backend.sourceAuthority.commit, backendCommit);
  assert.equal(f.decision.scope.backendDeploymentAuthorized, false);
});

for (const [label, mutate] of [
  ['relabelled Build30 approval', f => { f.decision.intendedBuildNumber = 30; }],
  ['unadmitted Build32', f => { f.policy.release.buildNumber = f.policy.versionPolicy.buildNumber = 32; }],
  ['deployment permission', f => { f.decision.scope.backendDeploymentAuthorized = true; }],
  ['public distribution permission', f => { f.decision.scope.distributionAuthorized = true; }],
  ['invented owner event', f => { f.decision.approvalEvidence.messageReceivedAtUtc = f.decision.approvedAtUtc; }],
  ['wrong source baseline', f => { f.version.sourceBaseline.commit = baseline; }],
  ['old owner source', f => { f.owner.sourceCommit = baseline; }],
  ['owner decision after agent decision', f => { f.owner.recordedAtUtc = '2999-01-01T00:00:00Z'; }],
  ['different backend reference', f => { f.decision.existingBackend.sourceCommit = baseline; }],
  ['relabelled backend file', f => { f.decision.existingBackend.file = 'release/evidence/build31-deployment.json'; }],
  ['failed release job', f => { f.ci.mainCi.jobs.jobs[0].conclusion = 'failure'; }],
  ['failed security job', f => { f.ci.securityCi.jobs.jobs[0].conclusion = 'failure'; }],
  ['incomplete security jobs', f => { f.ci.securityCi.jobs.jobs.pop(); }],
  ['duplicate security job', f => { f.ci.securityCi.jobs.jobs[0] = structuredClone(f.ci.securityCi.jobs.jobs[1]); }],
  ['old security head', f => { f.ci.securityCi.run.head_sha = baseline; }],
  ['PR rather than main security', f => { f.ci.securityCi.run.event = 'pull_request'; }],
  ['wrong security workflow', f => { f.ci.securityCi.run.path = '.github/workflows/other.yml'; }],
  ['future CI capture', f => { f.ci.mainCi.capturedAtUtc = '2999-01-01T00:00:00Z'; }],
  ['old backend readback', f => { f.readbacks.functionFleet.capturedAtUtc = '2026-09-01T00:00:00Z'; }],
  ['stale measurement under new capture time', f => { f.readbacks.functionFleet.outputs.schedulerBacklog.observedAtUtc = '2026-09-01T00:00:00Z'; }],
  ['stale Rules collection under new capture time', f => { f.readbacks.firestoreRulesAndIndexes.collectionStartedAtUtc = '2026-09-01T00:00:00Z'; }],
  ['old readback source', f => { f.readbacks.functionFleet.source.before.commit = backendCommit; }],
  ['altered live runtime hash', f => { f.readbacks.functionFleet.outputs.functions[0].firebaseFunctionsHash = '0'.repeat(40); }],
  ['altered live Rules result', f => { f.readbacks.firestoreRulesAndIndexes.outputs.rules.sourceSha256 = '0'.repeat(64); }],
  ['mutated IAM readback', f => { f.readbacks.iamDependencies.checks = {}; }],
]) {
  test(`Build31 rejects coherently rehashed ${label}`, t => {
    const f = fixture(t); mutate(f); f.persist();
    assert.throws(f.verify);
  });
}
for (const [label, options] of [
  ['Functions drift', {drift: 'functions/synthetic-change.json'}],
  ['Rules drift', {drift: 'firestore.rules'}],
  ['index drift', {drift: 'firestore.indexes.json'}],
  ['unrelated client source', {unrelatedSource: true}],
  ['custody not after source', {unrelatedCustody: true}],
]) {
  test(`Build31 rejects ${label} in actual Git objects`, t => {
    const f = fixture(t, options); assert.throws(f.verify);
  });
}
test('Build31 rejects missing original closure and mutable decision bytes', t => {
  const f = fixture(t);
  fs.unlinkSync(path.join(f.directory, backendFile)); assert.throws(f.verify);
  fs.copyFileSync(path.join(root, backendFile), path.join(f.directory, backendFile));
  fs.appendFileSync(path.join(f.directory, decisionFile), ' '); assert.throws(f.verify);
});

test('complete Build31 authority also validates original Build30 deployment and historical Build27 custody', t => {
  const f = fixture(t);
  fs.cpSync(path.join(root, 'release'), path.join(f.directory, 'release'), {recursive: true});
  const method = JSON.parse(fs.readFileSync(path.join(root, 'release/approvals/build30-rules-observed-state-method-approval.json'), 'utf8'));
  for (const file of Object.keys(method.reviewedVerifier.files)) {
    fs.mkdirSync(path.dirname(path.join(f.directory, file)), {recursive: true});
    fs.copyFileSync(path.join(root, file), path.join(f.directory, file));
  }
  const actualPolicy = JSON.parse(fs.readFileSync(path.join(root, 'release/production-release-policy.json'), 'utf8'));
  const actualVersion = JSON.parse(fs.readFileSync(path.join(root, actualPolicy.versionPolicy.sourceDocumentFile), 'utf8'));
  Object.assign(f.policy, actualPolicy);
  f.policy.release.buildNumber = f.policy.versionPolicy.buildNumber = 31;
  Object.assign(f.version, actualVersion);
  f.version.sourceBaseline = {commit: f.source.commit, tree: f.source.tree};
  f.persist();
  f.policy.versionPolicy.sourceDocumentFile = 'release/approvals/synthetic-build31-version.json';
  const versionBytes = `${JSON.stringify(f.version, null, 2)}\n`;
  fs.writeFileSync(path.join(f.directory, f.policy.versionPolicy.sourceDocumentFile), versionBytes);
  f.policy.versionPolicy.sourceDocumentSha256 = sha(versionBytes);
  const verify = () => verifyStagedPromotionSourceAuthority({repoRoot: f.directory, releasePolicy: f.policy});
  const distributionVerify = () => require('./collectDistributionInstallationReadback.js')
    .verifyDistributionSourceAuthority({repoRoot: f.directory, releasePolicy: f.policy});
  const passed = verify();
  assert.equal(passed.ok, true, JSON.stringify(passed));
  assert.equal(passed.currentBackendReceiptSha256, backendSha256);
  assert.equal(passed.clientBackendCompatibility.sourceCommit, f.source.commit);
  assert.equal(distributionVerify().ok, true, 'distribution consumer must accept the complete independently admitted31 fixture');
  assert.equal(require('./stagedPromotionSourceAuthority.js').verifyStagedPromotionSourceAuthority({
    repoRoot: f.directory, releasePolicy: f.policy}).ok, false, 'historical verifier must never silently admit31');
  f.policy.versionPolicy.buildNumber = 30;
  assert.equal(verify().ok, false, 'release31 cannot borrow version30 dispatch');
  assert.equal(distributionVerify().ok, false, 'distribution release31 cannot borrow the otherwise valid historical30 backend');
  f.policy.release.buildNumber = 32;
  assert.equal(distributionVerify().ok, false, 'distribution release32 cannot borrow the otherwise valid historical30 backend');
  f.policy.release.buildNumber = 31;
  f.policy.versionPolicy.buildNumber = 31;
  f.policy.release.buildNumber = 30;
  assert.equal(verify().ok, false, 'version31 cannot borrow release30');
  f.policy.release.buildNumber = 31;
  const statePath = path.join(f.directory, 'release/current-successor-state.json');
  const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
  state.authorityPlanes.deployedBackend.functionFleetSourceCommit = baseline;
  fs.writeFileSync(statePath, JSON.stringify(state));
  assert.equal(verify().ok, false, 'changed actual deployed-backend authority must fail');
});
