'use strict';
// All instructions, identities, pointers and custody facts below are synthetic.
// Passing these tests is not evidence of human consent, Git custody or release authority.
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const subject = require('./business31ClientSemantics.cjs');
const validate = subject.validateBusinessClientSemantics31;
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const bytes = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const clone = value => structuredClone(value);
const hash = char => char.repeat(64);
const commit = char => char.repeat(40);
const at = second => `2026-10-06T00:00:${String(second).padStart(2, '0')}Z`;
function fixture() {
  const selected = {
    source: {commit: commit('1'), tree: commit('a'), functionsTree: commit('b')},
    sourceManifestSha256: hash('A'),
    backendApproval: {commit: commit('2'), file: subject.FILES.backendApproval, sha256: hash('B')},
    backendClosure: {commit: commit('3'), file: subject.FILES.backendClosure, sha256: hash('C')},
    descriptor: {commit: commit('4'), file: subject.FILES.descriptor, sha256: hash('D')},
    ownerPointer: {commit: commit('5'), file: subject.FILES.ownerPointer, sha256: hash('E')},
    originalMessage: {sha256: hash('F'), bytes: 1},
    appCheck: {
      releaseId: 'synthetic-build31', reservationId: 'synthetic-reservation31',
      clientEnabled: true, androidProvider: 'playIntegrity', mutatingDefaultEnforced: false,
      identityCallable: {name: 'getBackendReleaseIdentity', enforced: true,
        sourceFile: 'functions/src/stage2dSecurityConfig.ts', sourceSha256: hash('9')}
    },
    closureRecordedAtUtc: at(1)
  };
  const common = {
    schemaVersion: 1, profile: subject.PROFILE, source: clone(selected.source),
    sourceManifestSha256: selected.sourceManifestSha256,
    backendApproval: clone(selected.backendApproval), backendClosure: clone(selected.backendClosure),
    descriptor: clone(selected.descriptor), scope: clone(subject.SCOPE), appCheck: clone(selected.appCheck),
    ownerReference: 'SYNTHETIC-OWNER-NOT-AUTHENTICATED'
  };
  const original = {...clone(common), documentType: 'retained-direct-human-business-client-instruction',
    question: subject.ownerQuestion31(selected, common.ownerReference),
    answer: 'Approve exact-source client construction only',
    messageId: 'synthetic-message', conversationId: 'synthetic-conversation', receivedAtUtc: at(2),
    provenance: 'operator-retained-direct-human-message', humanIdentityMachineAuthenticated: false};
  const owner = {...clone(common), documentType: 'build31-business-client-owner-authorization',
    authorizedAtUtc: at(2), recordedAtUtc: at(3), originalMessage: clone(selected.originalMessage)};
  const decision = {...clone(common), documentType: 'build31-business-client-compatibility-decision',
    ownerAuthorization: clone(selected.ownerPointer), decidedAtUtc: at(4), recordedAtUtc: at(5)};
  const input = {ownerBytes: null, decisionBytes: null, originalMessageBytes: null,
    selected, measured: {ownerPointer: clone(selected.ownerPointer),
      decisionPointer: {commit: commit('6'), file: subject.FILES.decisionPointer, sha256: hash('7')}},
    custody: {owner: {commit: commit('5'), parentCommit: commit('4')},
      decision: {commit: commit('6'), parentCommit: commit('5')}}, nowUtc: at(6)};
  return rebind({original, owner, decision, input});
}
// Semantic negatives deliberately update raw hashes after changing a record:
// they must fail its content joins, not merely stale fixture digests.
function rebind(f) {
  const {input, owner, original, decision} = f;
  input.originalMessageBytes = bytes(original);
  input.selected.originalMessage = {sha256: sha(input.originalMessageBytes), bytes: input.originalMessageBytes.length};
  owner.originalMessage = clone(input.selected.originalMessage);
  input.ownerBytes = bytes(owner);
  input.measured.ownerPointer.sha256 = sha(input.ownerBytes);
  input.selected.ownerPointer = clone(input.measured.ownerPointer);
  decision.ownerAuthorization = clone(input.measured.ownerPointer);
  input.decisionBytes = bytes(decision);
  input.measured.decisionPointer.sha256 = sha(input.decisionBytes);
  return f;
}
function rejectRecord(name, change, expected) {
  test(name, () => {const f = fixture(); change(f); rebind(f); assert.throws(() => validate(f.input), expected);});
}
function rejectInput(name, change, expected) {
  test(name, () => {const f = fixture(); change(f); assert.throws(() => validate(f.input), expected);});
}

test('synthetic original records validate semantics but no authentication or operational permission', () => {
  const f = fixture();
  const before = clone(f.input);
  const result = validate(f.input);
  assert.equal(result.recordedSemanticsValidated, true);
  for (const name of ['independentlySelectedInputsAuthenticated', 'humanIdentityAuthenticated',
    'gitCustodyVerified', 'trustedClockAuthenticated', 'platformIdentityAuthenticated',
    'hostedRecordedReplayAuthenticated', 'backendDeploymentAuthorized', 'constructionAuthorized',
    'signingAuthorized', 'distributionAuthorized']) assert.equal(result[name], false, name);
  assert.deepEqual(result.ownerPointer, f.input.selected.ownerPointer);
  assert.deepEqual(result.decisionPointer, f.input.measured.decisionPointer);
  assert.deepEqual(clone(f.input), before, 'validation does not mutate inputs');
  f.input.selected.source.commit = commit('f');
  assert.equal(result.source.commit, commit('1'), 'returned commitments are detached');
  assert.throws(() => {result.source.commit = commit('f');}, TypeError);
});
test('nanosecond precision and equal chronological boundaries remain valid', () => {
  const f = fixture();
  const t = '2026-10-06T00:00:01.000000001Z';
  f.input.selected.closureRecordedAtUtc = t;
  f.original.receivedAtUtc = f.owner.authorizedAtUtc = f.owner.recordedAtUtc = t;
  f.decision.decidedAtUtc = f.decision.recordedAtUtc = f.input.nowUtc = t;
  rebind(f);
  assert.equal(validate(f.input).recordedSemanticsValidated, true);
});
test('JSON whitespace is accepted only when the actual raw bytes are selected', () => {
  const f = fixture();
  f.input.originalMessageBytes = Buffer.from(JSON.stringify(f.original));
  f.input.selected.originalMessage = {sha256: sha(f.input.originalMessageBytes), bytes: f.input.originalMessageBytes.length};
  f.owner.originalMessage = clone(f.input.selected.originalMessage);
  f.input.ownerBytes = bytes(f.owner);
  f.input.measured.ownerPointer.sha256 = sha(f.input.ownerBytes);
  f.input.selected.ownerPointer = clone(f.input.measured.ownerPointer);
  f.decision.ownerAuthorization = clone(f.input.selected.ownerPointer);
  f.input.decisionBytes = bytes(f.decision);
  f.input.measured.decisionPointer.sha256 = sha(f.input.decisionBytes);
  assert.equal(validate(f.input).recordedSemanticsValidated, true);
});

for (const [record, field] of [['owner', 'ownerBytes'], ['decision', 'decisionBytes'], ['original message', 'originalMessageBytes']]) {
  rejectInput(`${record} unchanged parsed content with unbound whitespace is refused`, f => {
    f.input[field] = Buffer.concat([f.input[field], Buffer.from(' ')]);
  }, /original digest differs/);
}
rejectInput('owner cannot nominate a replacement selected pointer', f => {
  f.input.selected.ownerPointer.sha256 = hash('8');
}, /selected\/measured owner pointer differs/);
rejectInput('separate original message length is required', f => {f.input.selected.originalMessage.bytes++;}, /byte count differs/);
rejectInput('selected original message digest is required', f => {f.input.selected.originalMessage.sha256 = hash('8');}, /original digest differs/);
test('rebound decision cannot replace owner commit while retaining its selected SHA', () => {
  const f = fixture();
  f.decision.ownerAuthorization.commit = commit('f');
  f.input.decisionBytes = bytes(f.decision);
  f.input.measured.decisionPointer.sha256 = sha(f.input.decisionBytes);
  assert.throws(() => validate(f.input), /decision\/selected owner pointer differs/);
});
for (const field of ['bytes', 'sha256']) {
  test(`rebound owner cannot replace original message ${field}`, () => {
    const f = fixture();
    f.owner.originalMessage[field] = field === 'bytes' ? f.owner.originalMessage.bytes + 1 : hash('8');
    f.input.ownerBytes = bytes(f.owner);
    f.input.measured.ownerPointer.sha256 = sha(f.input.ownerBytes);
    f.input.selected.ownerPointer = clone(f.input.measured.ownerPointer);
    f.decision.ownerAuthorization = clone(f.input.measured.ownerPointer);
    f.input.decisionBytes = bytes(f.decision);
    f.input.measured.decisionPointer.sha256 = sha(f.input.decisionBytes);
    assert.throws(() => validate(f.input), /owner\/selected original message differs/);
  });
}
rejectInput('selected owner cannot be omitted', f => {delete f.input.selected.ownerPointer;}, /selected inputs fields differ/);
rejectInput('a supplied authentication callback is not an input', f => {f.input.authority = () => true;}, /input fields differ/);
rejectInput('unknown selected fields cannot carry authority', f => {f.input.selected.authenticated = true;}, /selected inputs fields differ/);
rejectInput('accessor selected identity is refused without invocation', f => {
  Object.defineProperty(f.input.selected, 'source', {enumerable: true, get() {assert.fail('getter invoked');}});
}, /selected inputs fields differ/);

for (const field of ['source', 'sourceManifestSha256', 'backendApproval', 'backendClosure', 'descriptor', 'appCheck']) {
  rejectRecord(`rebound decision with different ${field} is refused`, f => {
    if (field === 'source') f.decision.source.functionsTree = commit('c');
    else if (field === 'sourceManifestSha256') f.decision[field] = hash('0');
    else if (field === 'appCheck') f.decision.appCheck.reservationId = 'another-reservation';
    else f.decision[field].sha256 = hash('0');
  }, new RegExp(field + ' differs'));
}
rejectRecord('original message cannot approve different source', f => {f.original.source.commit = commit('c');}, /source differs/);
rejectRecord('original instruction cannot be a broader approval', f => {f.original.answer = 'Approve everything';}, /original instruction differs/);
rejectRecord('original exact-source question must match commitments', f => {f.original.question += ' Also sign.';}, /original instruction differs/);
rejectRecord('synthetic original cannot claim machine-authenticated human identity', f => {f.original.humanIdentityMachineAuthenticated = true;}, /original instruction differs/);
rejectRecord('owner reference must be identical across all three records', f => {f.original.ownerReference = 'another-owner';}, /owner reference differs/);
rejectRecord('unknown owner fields are refused even when rebound', f => {f.owner.approved = true;}, /owner fields differ/);
rejectRecord('unknown nested source fields are refused', f => {f.owner.source.extra = true;}, /source differs/);
rejectRecord('signing cannot be added to construction scope', f => {f.owner.scope.signing = true;}, /construction-only requested scope differs/);
rejectRecord('distribution cannot be added to construction scope', f => {f.decision.scope.distribution = true;}, /construction-only requested scope differs/);
rejectRecord('legacy profile cannot enter business semantics', f => {f.decision.profile = 'build31-exact-grpc-backend-v1';}, /record schema\/profile differs/);
rejectRecord('string schema number is not accepted', f => {f.owner.schemaVersion = '1';}, /record schema\/profile differs/);

for (const name of ['backendApproval', 'backendClosure', 'descriptor', 'ownerPointer']) {
  rejectInput(`selected ${name} requires its exact fixed file`, f => {f.input.selected[name].file = 'release/../other.json';}, new RegExp(name + ' invalid'));
}
rejectInput('measured decision pointer has its own fixed file', f => {f.input.measured.decisionPointer.file = subject.FILES.ownerPointer;}, /decisionPointer invalid/);
rejectInput('lowercase selected SHA is not canonical', f => {f.input.selected.sourceManifestSha256 = 'a'.repeat(64);}, /source manifest digest invalid/);
rejectInput('default AppCheck enforcement cannot erase the identity exception', f => {f.input.selected.appCheck.identityCallable.enforced = false;}, /identity callable scope differs/);
rejectInput('mutating default enforcement remains false', f => {f.input.selected.appCheck.mutatingDefaultEnforced = true;}, /AppCheck client\/default scope differs/);
rejectInput('Play Integrity remains enabled', f => {f.input.selected.appCheck.clientEnabled = false;}, /AppCheck client\/default scope differs/);
rejectInput('identity callable source file cannot be substituted', f => {f.input.selected.appCheck.identityCallable.sourceFile = 'functions/src/index.ts';}, /identity callable scope differs/);

for (const [label, change] of [
  ['owner predates closure by one nanosecond', f => {f.input.selected.closureRecordedAtUtc = '2026-10-06T00:00:02.000000001Z';}],
  ['original receipt and authorization differ', f => {f.owner.authorizedAtUtc = at(3);}],
  ['owner record precedes authorization', f => {f.owner.recordedAtUtc = at(1);}],
  ['decision precedes owner record', f => {f.decision.decidedAtUtc = at(2);}],
  ['decision recording precedes decision', f => {f.decision.recordedAtUtc = at(3);}],
  ['decision is recorded in the future', f => {f.input.nowUtc = at(4);}]
]) rejectRecord(label, change, /record chronology differs/);
for (const invalid of ['2026-02-30T00:00:00Z', '2026-10-06T00:00:06+00:00',
  '2026-10-06T00:00:06.1234567890Z', '0000-01-01T00:00:00Z', '2026-10-06T00:00:60Z']) {
  rejectInput(`malformed date ${invalid} is refused`, f => {f.input.nowUtc = invalid;}, /UTC/);
}
rejectInput('O must name B as its supplied immediate parent', f => {f.input.custody.owner.parentCommit = commit('3');}, /custody links differ/);
rejectInput('D must name O as its supplied immediate parent', f => {f.input.custody.decision.parentCommit = commit('4');}, /custody links differ/);
rejectInput('custody cannot substitute an unrelated owner commit', f => {f.input.custody.owner.commit = commit('f');}, /custody links differ/);
rejectInput('PASS booleans are not measured custody fields', f => {f.input.custody.gitVerified = true;}, /custody fields differ/);
rejectInput('final S is intentionally outside the pure parent-link schema', f => {f.input.custody.candidate = {commit: commit('f'), parents: [commit('6'), commit('e')]};}, /custody fields differ/);
rejectRecord('dedicated owner and descriptor cannot share a commit', f => {
  f.input.measured.ownerPointer.commit = f.input.selected.descriptor.commit;
  f.input.custody.owner.commit = f.input.selected.descriptor.commit;
  f.input.custody.decision.parentCommit = f.input.selected.descriptor.commit;
}, /custody commits must be distinct/);

rejectInput('metadata byte bound is enforced before parsing', f => {f.input.ownerBytes = Buffer.alloc(128 * 1024 + 1);}, /owner byte bound differs/);
rejectInput('UTF-8 errors are rejected after exact raw digest binding', f => {
  f.input.decisionBytes = Buffer.from([0x7b, 0x22, 0x78, 0x22, 0x3a, 0x22, 0xc3, 0x28, 0x22, 0x7d]);
  f.input.measured.decisionPointer.sha256 = sha(f.input.decisionBytes);
}, /encoded data|encoding/i);
rejectInput('deeply nested JSON is bounded', f => {
  f.input.decisionBytes = Buffer.from('{"nested":' + '['.repeat(14) + '0' + ']'.repeat(14) + '}');
  f.input.measured.decisionPointer.sha256 = sha(f.input.decisionBytes);
}, /complexity bound differs/);
