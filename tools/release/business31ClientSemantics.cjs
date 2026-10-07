'use strict';
// Pure preparation validator. Every selected pointer and custody fact is supplied
// by its caller. This module authenticates neither the caller nor a human, Git,
// platform, clock or hosted run, and grants no construction/signing permission.
// A future trusted adapter must measure Git parents/dedicated deltas and select
// owner/message commitments independently of candidate-controlled metadata.
const crypto = require('node:crypto');
const {isDeepStrictEqual: equal, TextDecoder} = require('node:util');

const PROFILE = 'build31-business-client-semantics-v1';
const FILES = Object.freeze({
  backendApproval: 'release/approvals/build31-business-backend-deployment-approval.json',
  backendClosure: 'release/evidence/build31-business-backend-deployment-closure.json',
  descriptor: 'release/evidence/build31-business-private-replay.json',
  ownerPointer: 'release/approvals/build31-business-client-owner-authorization.json',
  decisionPointer: 'release/approvals/build31-business-client-compatibility-approval.json'
});
const SCOPE = Object.freeze({
  buildNumber: 31, clientConstruction: true, backendDeployment: false,
  signing: false, distribution: false, iamMutation: false, enforcementMutation: false
});
const COMMON = Object.freeze(['schemaVersion', 'documentType', 'profile', 'source',
  'sourceManifestSha256', 'backendApproval', 'backendClosure', 'descriptor',
  'scope', 'appCheck', 'ownerReference']);
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
function need(ok, message) {
  if (!ok) throw new Error('Business client semantics: ' + message);
}
function exact(value, names, label) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    Reflect.ownKeys(value).every(key => typeof key === 'string') &&
    equal(Object.keys(value).sort(), [...names].sort()) &&
    Reflect.ownKeys(value).length === names.length &&
    Object.values(Object.getOwnPropertyDescriptors(value)).every(d => 'value' in d),
  label + ' fields differ');
}
function same(actual, expected, label) { need(equal(actual, expected), label + ' differs'); }
const oid = value => typeof value === 'string' && /^[a-f0-9]{40}$/.test(value);
const digest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
function text(value, label) {
  need(typeof value === 'string' && value.length > 0 && value.length <= 400 &&
    value === value.trim() && !/[\x00-\x1F\x7F]/.test(value), label + ' invalid');
}
function pointer(value, name) {
  exact(value, ['commit', 'file', 'sha256'], name);
  need(oid(value.commit) && value.file === FILES[name] && digest(value.sha256), name + ' invalid');
}
function bytePointer(value, label) {
  exact(value, ['sha256', 'bytes'], label);
  need(digest(value.sha256) && Number.isSafeInteger(value.bytes) &&
    value.bytes > 0 && value.bytes <= 128 * 1024, label + ' invalid');
}
function json(bytes, label) {
  need(Buffer.isBuffer(bytes) && bytes.length > 0 && bytes.length <= 128 * 1024,
    label + ' byte bound differs');
  const value = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes));
  const pending = [[value, 0]];
  let nodes = 0;
  while (pending.length) {
    const [item, depth] = pending.pop();
    need(++nodes <= 2000 && depth <= 12, label + ' complexity bound differs');
    if (item && typeof item === 'object') {
      for (const child of Object.values(item)) pending.push([child, depth + 1]);
    }
  }
  return value;
}
function instant(value) {
  const match = typeof value === 'string' &&
    /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.(\d{1,9}))?Z$/.exec(value);
  need(match && !match[1].startsWith('0000-'), 'explicit UTC required');
  const ms = Date.parse(match[1] + 'Z');
  need(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 19) === match[1],
    'invalid UTC calendar');
  return BigInt(ms) * 1000000n + BigInt((match[2] || '').padEnd(9, '0'));
}
function source(value) {
  exact(value, ['commit', 'tree', 'functionsTree'], 'source');
  need(Object.values(value).every(oid), 'source identity invalid');
}
function appCheck(value) {
  exact(value, ['releaseId', 'reservationId', 'clientEnabled', 'androidProvider',
    'mutatingDefaultEnforced', 'identityCallable'], 'AppCheck');
  text(value.releaseId, 'releaseId');
  text(value.reservationId, 'reservationId');
  need(value.clientEnabled === true && value.androidProvider === 'playIntegrity' &&
    value.mutatingDefaultEnforced === false, 'AppCheck client/default scope differs');
  exact(value.identityCallable, ['name', 'enforced', 'sourceFile', 'sourceSha256'], 'identity callable');
  need(value.identityCallable.name === 'getBackendReleaseIdentity' &&
    value.identityCallable.enforced === true &&
    value.identityCallable.sourceFile === 'functions/src/stage2dSecurityConfig.ts' &&
    digest(value.identityCallable.sourceSha256), 'identity callable scope differs');
}
function common(value, selected, documentType) {
  need(value.schemaVersion === 1 && value.documentType === documentType &&
    value.profile === PROFILE, 'record schema/profile differs');
  for (const name of ['source', 'sourceManifestSha256', 'backendApproval', 'backendClosure', 'descriptor', 'appCheck']) {
    same(value[name], selected[name], name);
  }
  same(value.scope, SCOPE, 'construction-only requested scope');
  text(value.ownerReference, 'ownerReference');
}
// The original text names every source/backend/descriptor commitment. Its exact
// bytes are retained separately, not regenerated as purported original evidence.
function ownerQuestion31(selected, ownerReference) {
  return `Authorize construction only of Build31 client for business source ${selected.source.commit}` +
    ` (tree ${selected.source.tree}, Functions tree ${selected.source.functionsTree}, source manifest ${selected.sourceManifestSha256}),` +
    ` backend approval ${selected.backendApproval.commit}/${selected.backendApproval.sha256},` +
    ` closure ${selected.backendClosure.commit}/${selected.backendClosure.sha256},` +
    ` descriptor ${selected.descriptor.commit}/${selected.descriptor.sha256},` +
    ` release ${selected.appCheck.releaseId}, reservation ${selected.appCheck.reservationId}, owner ${ownerReference},` +
    ` with enabled Play Integrity, unchanged mutating enforcement false and getBackendReleaseIdentity enforced true` +
    ` (source ${selected.appCheck.identityCallable.sourceSha256}), without backend deployment, signing, distribution, IAM or enforcement changes?`;
}
function freeze(value) {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

function validateBusinessClientSemantics31(input) {
  exact(input, ['ownerBytes', 'decisionBytes', 'originalMessageBytes', 'measured', 'selected', 'custody', 'nowUtc'], 'input');
  const {ownerBytes, decisionBytes, originalMessageBytes, measured, selected, custody, nowUtc} = input;
  exact(selected, ['source', 'sourceManifestSha256', 'backendApproval', 'backendClosure',
    'descriptor', 'ownerPointer', 'originalMessage', 'appCheck', 'closureRecordedAtUtc'], 'selected inputs');
  source(selected.source);
  need(digest(selected.sourceManifestSha256), 'source manifest digest invalid');
  for (const name of ['backendApproval', 'backendClosure', 'descriptor', 'ownerPointer']) pointer(selected[name], name);
  bytePointer(selected.originalMessage, 'selected original message');
  appCheck(selected.appCheck);
  exact(measured, ['ownerPointer', 'decisionPointer'], 'measured pointers');
  pointer(measured.ownerPointer, 'ownerPointer');
  pointer(measured.decisionPointer, 'decisionPointer');
  same(measured.ownerPointer, selected.ownerPointer, 'selected/measured owner pointer');
  // Hash raw bounded bytes before parsing any original record.
  for (const [bytes, expected, label] of [
    [ownerBytes, measured.ownerPointer, 'owner'],
    [decisionBytes, measured.decisionPointer, 'decision'],
    [originalMessageBytes, selected.originalMessage, 'original message']
  ]) {
    need(Buffer.isBuffer(bytes) && bytes.length > 0 && bytes.length <= 128 * 1024, label + ' byte bound differs');
    need(sha256(bytes) === expected.sha256, label + ' original digest differs');
  }
  need(originalMessageBytes.length === selected.originalMessage.bytes, 'original message byte count differs');
  const owner = json(ownerBytes, 'owner'), decision = json(decisionBytes, 'decision');
  const original = json(originalMessageBytes, 'original message');
  exact(owner, [...COMMON, 'authorizedAtUtc', 'recordedAtUtc', 'originalMessage'], 'owner');
  exact(decision, [...COMMON, 'ownerAuthorization', 'decidedAtUtc', 'recordedAtUtc'], 'decision');
  exact(original, [...COMMON, 'question', 'answer', 'messageId', 'conversationId',
    'receivedAtUtc', 'provenance', 'humanIdentityMachineAuthenticated'], 'original message');
  common(owner, selected, 'build31-business-client-owner-authorization');
  common(decision, selected, 'build31-business-client-compatibility-decision');
  common(original, selected, 'retained-direct-human-business-client-instruction');
  bytePointer(owner.originalMessage, 'owner original message');
  same(owner.originalMessage, selected.originalMessage, 'owner/selected original message');
  pointer(decision.ownerAuthorization, 'ownerPointer');
  same(decision.ownerAuthorization, selected.ownerPointer, 'decision/selected owner pointer');
  need(owner.ownerReference === decision.ownerReference && owner.ownerReference === original.ownerReference,
    'owner reference differs');
  text(original.messageId, 'messageId');
  text(original.conversationId, 'conversationId');
  need(original.question === ownerQuestion31(selected, owner.ownerReference) &&
    original.answer === 'Approve exact-source client construction only' &&
    original.provenance === 'operator-retained-direct-human-message' &&
    original.humanIdentityMachineAuthenticated === false, 'original instruction differs');

  const closure = instant(selected.closureRecordedAtUtc), received = instant(original.receivedAtUtc);
  const authorized = instant(owner.authorizedAtUtc), ownerRecorded = instant(owner.recordedAtUtc);
  const decided = instant(decision.decidedAtUtc), decisionRecorded = instant(decision.recordedAtUtc);
  need(closure <= received && received === authorized && authorized <= ownerRecorded &&
    ownerRecorded <= decided && decided <= decisionRecorded && decisionRecorded <= instant(nowUtc),
  'record chronology differs');

  // Internal consistency only: these are supplied facts, not verified Git data.
  // A later adapter must measure these parents and dedicated file deltas, then
  // verify D ancestry and the allowed metadata delta through candidate S.
  exact(custody, ['owner', 'decision'], 'custody');
  for (const [name, value] of Object.entries(custody)) {
    exact(value, ['commit', 'parentCommit'], name + ' custody');
    need(oid(value.commit) && oid(value.parentCommit), name + ' custody identity invalid');
  }
  need(custody.owner.commit === selected.ownerPointer.commit &&
    custody.owner.parentCommit === selected.descriptor.commit &&
    custody.decision.commit === measured.decisionPointer.commit &&
    custody.decision.parentCommit === selected.ownerPointer.commit, 'B-to-O-to-D custody links differ');
  const commits = [selected.source.commit, selected.backendApproval.commit, selected.backendClosure.commit,
    selected.descriptor.commit, selected.ownerPointer.commit, measured.decisionPointer.commit];
  need(new Set(commits).size === commits.length, 'custody commits must be distinct');

  return freeze({
    schemaVersion: 1, documentType: 'build31-business-client-record-semantics', profile: PROFILE,
    recordedSemanticsValidated: true,
    source: {...selected.source},
    ownerPointer: {...measured.ownerPointer}, decisionPointer: {...measured.decisionPointer},
    originalMessage: {...selected.originalMessage},
    independentlySelectedInputsAuthenticated: false, humanIdentityAuthenticated: false,
    gitCustodyVerified: false, trustedClockAuthenticated: false, platformIdentityAuthenticated: false,
    hostedRecordedReplayAuthenticated: false, backendDeploymentAuthorized: false,
    constructionAuthorized: false, signingAuthorized: false, distributionAuthorized: false
  });
}

module.exports = Object.freeze({PROFILE, FILES, SCOPE, ownerQuestion31, validateBusinessClientSemantics31});
