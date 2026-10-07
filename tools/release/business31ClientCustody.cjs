'use strict';
// Public, credential-free custody measurements. The caller must independently
// select V, the owner and original message. This module does not authenticate
// that selection, the host, a human, a platform run or the private closure.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {isDeepStrictEqual: equal} = require('node:util');

const PROFILE = 'build31-business-client-custody-v1';
const HELPERS = Object.freeze([
  'business31ClientCustody.cjs', 'business31ClientSemantics.cjs',
  'business31TrustedInput.cjs', 'business31PrivateDescriptor.cjs',
  'privateEvidenceBundle31.cjs'
].map(name => 'tools/release/' + name));
const FILES = Object.freeze({
  backendApproval: 'release/approvals/build31-business-backend-deployment-approval.json',
  backendClosure: 'release/evidence/build31-business-backend-deployment-closure.json',
  descriptor: 'release/evidence/build31-business-private-replay.json',
  ownerPointer: 'release/approvals/build31-business-client-owner-authorization.json',
  decisionPointer: 'release/approvals/build31-business-client-compatibility-approval.json'
});
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const oid = value => typeof value === 'string' && /^[a-f0-9]{40}$/.test(value);
const digest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
function need(ok, message) { if (!ok) throw Error('Business client custody: ' + message); }
function exact(value, keys, label) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    Reflect.ownKeys(value).every(key => typeof key === 'string') &&
    equal(Reflect.ownKeys(value).sort(), [...keys].sort()) &&
    Object.values(Object.getOwnPropertyDescriptors(value)).every(d => 'value' in d),
  label + ' fields differ');
}
function dataCopy(value) {
  let nodes = 0;
  function copy(item, depth) {
    need(++nodes <= 10000 && depth <= 16, 'input complexity exceeds bound');
    if (item === null || typeof item === 'boolean' ||
      (typeof item === 'number' && Number.isFinite(item))) return item;
    if (typeof item === 'string') { need(item.length <= 4096, 'input text exceeds bound'); return item; }
    need(item && typeof item === 'object' && !Array.isArray(item), 'plain data input required');
    const keys = Reflect.ownKeys(item);
    need(keys.length <= 512, 'input object exceeds bound');
    exact(item, keys, 'input object');
    const result = Object.create(null);
    for (const key of keys) {
      need(typeof key === 'string' && key.length <= 1024, 'input key invalid');
      result[key] = copy(Object.getOwnPropertyDescriptor(item, key).value, depth + 1);
    }
    // Ordinary detached objects keep equality with parsed original JSON exact.
    return Object.fromEntries(Object.entries(result));
  }
  return copy(value, 0);
}
function pointer(value, name) {
  exact(value, ['commit', 'file', 'sha256'], name);
  need(oid(value.commit) && value.file === FILES[name] && digest(value.sha256), name + ' invalid');
}
function bindHelpers(bindings) {
  for (const file of HELPERS) {
    need(Object.hasOwn(bindings, file) && digest(bindings[file]), 'fixed helper selection absent: ' + file);
    const local = path.join(__dirname, path.basename(file));
    let current = path.parse(local).root;
    for (const part of local.slice(current.length).split(path.sep).filter(Boolean)) {
      current = path.join(current, part);
      need(!fs.lstatSync(current).isSymbolicLink(), 'redirected local helper refused');
    }
    const stat = fs.lstatSync(local);
    need(stat.isFile() && stat.size > 0 && stat.size <= 2 * 1024 * 1024,
      'bounded regular helper required');
    need(sha(fs.readFileSync(local)) === bindings[file], 'selected local helper differs: ' + file);
  }
}
function delta(before, after) {
  return [...new Set([...Object.keys(before.files), ...Object.keys(after.files)])]
    .filter(file => !equal(before.files[file], after.files[file])).sort();
}
function freeze(value) {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

function verifyBusinessClientCustody31(input) {
  exact(input, ['repositoryRoot', 'gitExecutable', 'gitSha256', 'envelope', 'selected',
    'originalMessageBytes', 'nowUtc'], 'input');
  need(Buffer.isBuffer(input.originalMessageBytes) && input.originalMessageBytes.length > 0 &&
    input.originalMessageBytes.length <= 128 * 1024, 'original message byte bound differs');
  const originalMessageBytes = Buffer.from(input.originalMessageBytes);
  const {repositoryRoot, gitExecutable, gitSha256, envelope, selected, nowUtc} = dataCopy({
    repositoryRoot: input.repositoryRoot, gitExecutable: input.gitExecutable,
    gitSha256: input.gitSha256, envelope: input.envelope, selected: input.selected, nowUtc: input.nowUtc
  });
  exact(selected, ['source', 'sourceManifestSha256', 'backendApproval', 'backendClosure',
    'descriptor', 'ownerPointer', 'decisionPointer', 'originalMessage', 'appCheck'], 'selected');
  exact(selected.source, ['commit', 'tree', 'functionsTree'], 'selected source');
  need(Object.values(selected.source).every(oid) && digest(selected.sourceManifestSha256), 'selected source invalid');
  for (const name of Object.keys(FILES)) pointer(selected[name], name);
  exact(selected.originalMessage, ['sha256', 'bytes'], 'selected original message');
  need(digest(selected.originalMessage.sha256) && selected.originalMessage.bytes === originalMessageBytes.length &&
    sha(originalMessageBytes) === selected.originalMessage.sha256, 'selected original message bytes differ');
  exact(envelope, ['schemaVersion', 'profile', 'verifier', 'source', 'candidate'], 'envelope');
  exact(envelope.verifier, ['commit', 'tree', 'files'], 'verifier');
  exact(envelope.source, ['commit', 'tree'], 'source');
  exact(envelope.candidate, ['commit', 'tree', 'ref'], 'candidate');
  need(envelope.schemaVersion === 1 && envelope.profile === 'build31-business-trusted-input-v1' &&
    [envelope.verifier.commit, envelope.verifier.tree, envelope.source.commit, envelope.source.tree,
      envelope.candidate.commit, envelope.candidate.tree].every(oid), 'envelope identity invalid');
  need(equal(envelope.source, {commit: selected.source.commit, tree: selected.source.tree}), 'selected source/envelope differs');
  need(envelope.verifier.files && typeof envelope.verifier.files === 'object' &&
    Object.keys(envelope.verifier.files).length <= 256, 'finite selected helper population required');
  // These fixed local imports precede no credential use or candidate-code load.
  // The later full verifier proves this selected population against real V/M/S.
  bindHelpers(envelope.verifier.files);
  const semantics = require('./business31ClientSemantics.cjs');
  const trusted = require('./business31TrustedInput.cjs');
  const descriptor = require('./business31PrivateDescriptor.cjs');
  const repository = trusted.openTrustedGitRepository31({repositoryRoot, gitExecutable, gitSha256});
  need(repository.readRef(envelope.candidate.ref) === envelope.candidate.commit, 'candidate reference differs');
  const snapshots = new Map();
  function at(commit) {
    if (!snapshots.has(commit)) snapshots.set(commit, repository.snapshot(commit));
    return snapshots.get(commit);
  }
  const M = at(selected.source.commit), S = at(envelope.candidate.commit);
  need(M.tree === selected.source.tree && S.tree === envelope.candidate.tree, 'selected complete tree differs');
  const B = at(selected.descriptor.commit), O = at(selected.ownerPointer.commit), D = at(selected.decisionPointer.commit);
  need(equal(O.parents, [B.commit]) && equal(D.parents, [O.commit]), 'dedicated B-to-O-to-D parent links differ');
  need(equal(delta(B, O), [FILES.ownerPointer]) && equal(delta(O, D), [FILES.decisionPointer]),
    'dedicated owner/decision delta differs');
  repository.requireAncestor(D.commit, S.commit);
  const changedAfterDecision = delta(D, S);
  for (const file of changedAfterDecision) {
    need(S.files[file]?.mode === '100644' && (!D.files[file] || D.files[file].mode === '100644') &&
      (file === 'pubspec.yaml' || trusted.METADATA_PATHS.includes(file)), 'non-metadata change after decision');
  }
  function committed(p, maxBytes = 2 * 1024 * 1024) {
    const snapshot = at(p.commit);
    need(snapshot.files[p.file]?.mode === '100644' && equal(snapshot.files[p.file], S.files[p.file]),
      'selected pointer changed or absent in candidate: ' + p.file);
    const bytes = repository.readBlob(p.commit, p.file, maxBytes);
    need(sha(bytes) === p.sha256, 'selected pointer digest differs: ' + p.file);
    return bytes;
  }
  const ownerBytes = committed(selected.ownerPointer, 128 * 1024);
  const decisionBytes = committed(selected.decisionPointer, 128 * 1024);
  const closure = descriptor.json(committed(selected.backendClosure));
  exact(closure, ['schemaVersion', 'documentType', 'recordKind', 'source', 'recordedAtUtc', 'privateRecord'], 'public closure');
  need(closure.schemaVersion === 1 && closure.documentType === 'build31-business-private-record-custody' &&
    closure.recordKind === 'closure' && equal(closure.source, selected.source), 'public closure envelope differs');
  exact(closure.privateRecord, ['file', 'sha256', 'bytes'], 'private record pointer');
  need(typeof closure.privateRecord.file === 'string' && closure.privateRecord.file.length > 0 &&
    digest(closure.privateRecord.sha256) && Number.isSafeInteger(closure.privateRecord.bytes) &&
    closure.privateRecord.bytes > 0 && closure.privateRecord.bytes <= 64 * 1024 * 1024, 'private record commitment invalid');
  const measured = {ownerPointer: selected.ownerPointer, decisionPointer: selected.decisionPointer};
  const recorded = semantics.validateBusinessClientSemantics31({
    ownerBytes, decisionBytes, originalMessageBytes, measured,
    selected: {source: selected.source, sourceManifestSha256: selected.sourceManifestSha256,
      backendApproval: selected.backendApproval, backendClosure: selected.backendClosure,
      descriptor: selected.descriptor, ownerPointer: selected.ownerPointer,
      originalMessage: selected.originalMessage, appCheck: selected.appCheck,
      closureRecordedAtUtc: closure.recordedAtUtc},
    custody: {owner: {commit: O.commit, parentCommit: B.commit},
      decision: {commit: D.commit, parentCommit: O.commit}}, nowUtc
  });
  // Every success runs the complete existing descriptor/Git preparation check.
  // No callback or caller-provided PASS can substitute for these measurements.
  const prepared = descriptor.verifyBusiness31DescriptorPreparation({
    repositoryRoot, gitExecutable, gitSha256, envelope,
    descriptorPointer: selected.descriptor, expectedSourceManifestSha256: selected.sourceManifestSha256
  });
  need(equal(prepared.source, selected.source) && prepared.descriptorSha256 === selected.descriptor.sha256 &&
    prepared.pointerDigests.approvalPointer.sha256 === selected.backendApproval.sha256 &&
    prepared.pointerDigests.closurePointer.sha256 === selected.backendClosure.sha256,
  'prepared backend commitments differ');
  // The original descriptor must also name the exact selected commits, not
  // merely records with equal byte digests at some other custody point.
  const descriptorRecord = descriptor.json(committed(selected.descriptor));
  need(equal(descriptorRecord.approvalPointer, selected.backendApproval) &&
    equal(descriptorRecord.closurePointer, selected.backendClosure), 'prepared backend pointer identity differs');
  need(repository.readRef(envelope.candidate.ref) === S.commit &&
    repository.snapshot(M.commit).tree === M.tree && repository.snapshot(S.commit).tree === S.tree,
  'source/candidate changed during custody checks');
  bindHelpers(envelope.verifier.files);
  return freeze({
    schemaVersion: 1, documentType: 'build31-business-client-public-custody', profile: PROFILE,
    source: selected.source, sourceManifestSha256: selected.sourceManifestSha256, appCheck: selected.appCheck,
    verifier: {commit: envelope.verifier.commit, tree: envelope.verifier.tree},
    candidate: {commit: S.commit, tree: S.tree, parents: [...S.parents]},
    ownerPointer: selected.ownerPointer, decisionPointer: selected.decisionPointer,
    descriptor: selected.descriptor, backendApproval: selected.backendApproval, backendClosure: selected.backendClosure,
    originalMessage: recorded.originalMessage, publicClosureRecordedAtUtc: closure.recordedAtUtc,
    changedAfterDecision, gitCustodyVerified: true, dedicatedOwnerDecisionDeltasVerified: true,
    descriptorPreparationVerified: true, recordedSemanticsValidated: true,
    independentlySelectedInputsAuthenticated: false, executingHostAuthenticated: false,
    humanIdentityAuthenticated: false, trustedClockAuthenticated: false, platformIdentityAuthenticated: false,
    appCheckSourcePolicyVerified: false, privateClosureSemanticsVerified: false, privateReplayVerified: false,
    hostedRecordedReplayAuthenticated: false, credentialAccessAuthorized: false,
    backendDeploymentAuthorized: false, constructionAuthorized: false, signingAuthorized: false, distributionAuthorized: false
  });
}

module.exports = Object.freeze({PROFILE, HELPERS, FILES, verifyBusinessClientCustody31});
