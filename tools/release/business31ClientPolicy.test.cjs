'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const subject = require('./business31ClientPolicy.cjs');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
let valid;
test.before(() => { valid = createFixture(); });
test.beforeEach(() => valid.reset());
function args(fixture = valid) {
  const {trust, request} = fixture.platformFixture();
  return {trust, request, input: fixture.clientInput()};
}
function mutated(record, field, value, extra = []) {
  return createFixture({mutations: [{record, path: field.split('.'), value}, ...extra]});
}
test('measures committed S policy and actual M AppCheck bytes without granting authority', () => {
  const result = subject.verifyBusinessClientPolicy31(args());
  assert.equal(result.schemaVersion, 1);
  assert.equal(result.profile, subject.PROFILE);
  assert.equal(result.policySourceVerified, true);
  assert.equal(result.appCheckSourcePolicyVerified, true);
  assert.equal(result.source.commit, valid.M.commit);
  assert.equal(result.candidate.commit, valid.S.commit);
  assert.notEqual(result.source.commit, result.candidate.commit);
  assert.deepEqual(Object.keys(result.bindings).sort(), ['appCheckApproval', 'backendPolicy', 'currentSuccessor',
    'identitySource', 'policy', 'pubspec', 'rulesReadback', 'successorApproval', 'versionApproval']);
  for (const name of ['policy', 'versionApproval', 'successorApproval', 'currentSuccessor', 'appCheckApproval', 'pubspec']) {
    assert.equal(result.bindings[name].commit, valid.S.commit);
    assert.equal(result.bindings[name].sha256, sha(valid.S.files[subject.FILES[name]]));
  }
  for (const name of ['backendPolicy', 'identitySource', 'rulesReadback']) assert.equal(result.bindings[name].commit, valid.M.commit);
  assert.equal(result.bindings.identitySource.sha256, subject.IDENTITY_SHA256);
  assert.equal(result.appCheck.dartDefine, 'true');
  assert.equal(result.appCheck.serverEnforcementScopesAtBuild.identityCallableEnforced, true);
  for (const flag of subject.FALSE_FLAGS) assert.equal(result[flag], false, flag);
  assert.equal(Object.isFrozen(result), true);
  assert.equal(Object.isFrozen(result.bindings.policy), true);
});
test('ambient uncommitted policy cannot replace the selected Git S policy', () => {
  fs.mkdirSync(path.join(valid.root, 'release'), {recursive: true});
  fs.writeFileSync(path.join(valid.root, subject.FILES.policy), '{"localPass":true}');
  assert.equal(subject.verifyBusinessClientPolicy31(args()).bindings.policy.sha256,
    sha(valid.S.files[subject.FILES.policy]));
});
test('refuses Build30 records even when a business selector is present', () => {
  const fixture = mutated('policy', 'release.buildNumber', 30);
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /both policy builds/);
});
test('refuses numeric-string version build and mixed legacy selector', () => {
  const fixture = mutated('policy', 'versionPolicy.buildNumber', '31');
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /both policy builds/);
  const mixed = mutated('policy', 'runtimeBackendPrivateReplay', {profile: 'legacy'});
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(mixed)), /legacy runtime route/);
});
test('refuses a different client decision pointer despite matching backend source', () => {
  const fixture = mutated('policy', 'clientBackendCompatibility.commit', 'f'.repeat(40));
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /policy client decision/);
});
test('refuses a different version reservation and reused build tag', () => {
  const fixture = mutated('versionApproval', 'reservationId', 'another-reservation');
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /version receipt reservationId/);
  const reused = mutated('policy', 'versionPolicy.remoteBuiltTag', 'crm3-build-built/30');
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(reused)), /version or build tag/);
});
test('refuses coherently rehashed successor approval for another M', () => {
  const fixture = mutated('successorApproval', 'sourceBaseline.commit', 'f'.repeat(40));
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /successor source baseline/);
});
test('refuses current-successor backend source drift and changed preserved Rules metadata', () => {
  const fixture = mutated('currentSuccessor', 'authorityPlanes.deployedBackend.functionFleetSourceCommit', 'f'.repeat(40));
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /deployed backend functionFleetSourceCommit/);
  const changed = mutated('policy', 'finalization.exactFirestoreRulesIndexesLiveReadback.rulesSha256', 'F'.repeat(64));
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(changed)), /preserved Rules\/index/);
});
test('refuses coherently rehashed AppCheck enforcement expansion and wrong backend digest', () => {
  const fixture = mutated('appCheckApproval', 'enforcementChangeAuthorized', true);
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /AppCheck approval\/source joins/);
  const changed = mutated('appCheckApproval', 'backendReceiptSha256', 'F'.repeat(64));
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(changed)), /AppCheck approval\/source joins/);
});
test('refuses forged identity scopes even with internally consistent approval digest', () => {
  const fixture = mutated('appCheckApproval', 'serverEnforcementScopesAtBuild.identityCallableEnforced', false);
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /AppCheck server scopes/);
});
test('refuses changed actual M identity bytes rather than trusting the recorded expected digest', () => {
  const fixture = createFixture({identityBytes: Buffer.from('// altered identity source, never executed\n')});
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /actual M identity source/);
});
test('refuses future chronology and disguised unfinished approval identities', () => {
  const fixture = mutated('appCheckApproval', 'approvedAtUtc', '2999-01-01T00:00:00Z');
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(fixture)), /AppCheck approval UTC/);
  const changed = mutated('appCheckApproval', 'approverName', 'T\u200bO-D O APPROVER');
  assert.throws(() => subject.verifyBusinessClientPolicy31(args(changed)), /unfinished identity/);
});
test('refuses an executable source edit after M and a moved admitted S reference', () => {
  const wrongTree = args();
  wrongTree.trust.source.functionsTree = 'f'.repeat(40);
  wrongTree.input.selected.source.functionsTree = 'f'.repeat(40);
  assert.throws(() => subject.verifyBusinessClientPolicy31(wrongTree), /actual M Functions tree/);
  const input = args();
  input.request.candidate.commit = valid.sourceEdit.commit;
  input.request.candidate.tree = valid.sourceEdit.tree;
  fs.writeFileSync(path.join(valid.root, '.git/refs/heads/business31-admitted-' + valid.sourceEdit.commit), valid.sourceEdit.commit + '\n');
  assert.throws(() => subject.verifyBusinessClientPolicy31(input), /executable\/source delta after M/);
  valid.setCandidate(valid.M);
  assert.throws(() => subject.verifyBusinessClientPolicy31(args()), /admitted S reference/);
});
test('refuses unbound helper bytes and missing fixed imports before loading or Git reads', () => {
  for (const file of subject.HELPERS) {
    const input = args(); delete input.trust.verifier.files[file];
    assert.throws(() => subject.verifyBusinessClientPolicy31(input), /fixed helper missing/);
  }
  const input = args(); input.trust.verifier.files[subject.HELPERS[0]] = 'F'.repeat(64);
  assert.throws(() => subject.verifyBusinessClientPolicy31(input), /helper bytes differ/);
});
test('accessors, callbacks and custom array maps are refused without execution', () => {
  let called = 0;
  const input = args(); Object.defineProperty(input.input, 'selected', {get() { called++; return {}; }});
  assert.throws(() => subject.verifyBusinessClientPolicy31(input), /fields differ/);
  const callback = args(); callback.input.originalMessageFile = () => { called++; };
  assert.throws(() => subject.verifyBusinessClientPolicy31(callback), /plain data required/);
  const inherited = args(), array = [];
  Object.setPrototypeOf(array, {get map() { called++; return () => []; }});
  inherited.input.selected.appCheck = array;
  assert.throws(() => subject.verifyBusinessClientPolicy31(inherited), /plain bounded array/);
  assert.equal(called, 0);
});
