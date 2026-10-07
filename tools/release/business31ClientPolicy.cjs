'use strict';
// Committed policy measurements only. The protected caller separately performs
// actual client custody and hosted replay before and after awaited platform reads.
// This export accepts no callback, cached PASS or operational authority.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {isDeepStrictEqual: equal, TextDecoder} = require('node:util');
const PROFILE = 'build31-business-client-policy-v1';
const FILES = Object.freeze({
  policy: 'release/production-release-policy.json',
  versionApproval: 'release/approvals/version-policy-approval.json',
  successorApproval: 'release/approvals/build-number-31-successor-approval.json',
  currentSuccessor: 'release/current-successor-state.json',
  appCheckApproval: 'release/approvals/build31-app-check-client-approval.json',
  pubspec: 'pubspec.yaml',
  identitySource: 'functions/src/stage2dSecurityConfig.ts'
});
const HELPERS = Object.freeze(['business31ClientPolicy.cjs', 'business31TrustedInput.cjs',
  'business31HostedProtocol.cjs'].map(name => 'tools/release/' + name));
const IDENTITY_SHA256 = '1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F';
const RULES_READBACK = Object.freeze({file: 'release/evidence/build30-current-source-firestore-rules-indexes-live-readback.json',
  sha256: '62A707AC10A76B6C9D6D1466987D558E8C9186602B57E0E75EB760A5F4160CEC',
  sourceCommit: '2aa30de56cfdb960da3eeefd8956d8cbbae57b46'});
const FALSE_FLAGS = Object.freeze(['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated',
  'humanIdentityAuthenticated', 'trustedClockAuthenticated', 'platformIdentityAuthenticated',
  'privateReplayVerified', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
  'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized']);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const digest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
const oid = value => typeof value === 'string' && /^[a-f0-9]{40}$/.test(value);
function need(ok, label) { if (!ok) throw Error('Business client policy: ' + label); }
function same(a, b, label) { need(equal(a, b), label + ' differs'); }
function exact(value, keys, label) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    Reflect.ownKeys(value).every(key => typeof key === 'string') &&
    equal(Reflect.ownKeys(value).sort(), [...keys].sort()) &&
    Object.values(Object.getOwnPropertyDescriptors(value)).every(d => 'value' in d), label + ' fields differ');
}
function dataCopy(value) {
  let nodes = 0;
  function copy(item, depth) {
    need(++nodes <= 20000 && depth <= 32, 'plain input complexity exceeds bound');
    if (item === null || typeof item === 'boolean' ||
      (typeof item === 'number' && Number.isFinite(item))) return item;
    if (typeof item === 'string') { need(item.length <= 8192, 'input string exceeds bound'); return item; }
    need(item && typeof item === 'object', 'plain data required');
    if (Array.isArray(item)) {
      need(Object.getPrototypeOf(item) === Array.prototype && item.length <= 1024,
        'plain bounded array required');
      const keys = Reflect.ownKeys(item), wanted = ['length', ...Array.from({length: item.length}, (_, i) => String(i))];
      need(keys.every(key => typeof key === 'string') && equal(keys.sort(), wanted.sort()) &&
        Object.values(Object.getOwnPropertyDescriptors(item)).every(d => 'value' in d), 'dense data array required');
      return Array.prototype.map.call(item, child => copy(child, depth + 1));
    }
    const keys = Reflect.ownKeys(item);
    need(keys.length <= 1024, 'input object exceeds bound');
    exact(item, keys, 'input object');
    return Object.fromEntries(keys.map(key => [key, copy(Object.getOwnPropertyDescriptor(item, key).value, depth + 1)]));
  }
  return copy(value, 0);
}
function freeze(value) {
  if (value && typeof value === 'object') { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
}
function bindHelpers(bindings) {
  for (const file of HELPERS) {
    need(bindings && Object.hasOwn(bindings, file) && digest(bindings[file]), 'fixed helper missing: ' + file);
    const local = path.resolve(__dirname, path.basename(file));
    let current = path.parse(local).root;
    for (const part of local.slice(current.length).split(path.sep).filter(Boolean)) {
      current = path.join(current, part);
      need(!fs.lstatSync(current).isSymbolicLink(), 'redirected helper refused');
    }
    const stat = fs.lstatSync(local);
    need(stat.isFile() && stat.size > 0 && stat.size <= 2 * 1024 * 1024 &&
      sha(fs.readFileSync(local)) === bindings[file], 'helper bytes differ: ' + file);
  }
}
function text(value, label) {
  need(typeof value === 'string' && value === value.trim() && value.length > 0 && value.length <= 4000 &&
    !/[\x00-\x1f\x7f]/.test(value), label + ' invalid');
}
function accountable(value, label) {
  text(value, label);
  let normalized = value.normalize('NFKD').replace(/[\p{Default_Ignorable_Code_Point}\p{Mark}]/gu, '')
    .replace(/[\p{Punctuation}\p{Symbol}\s]/gu, ' ').trim();
  for (const marker of ['TODOAPPROVER', 'TODOREFERENCE', 'FIXTUREAPPROVER', 'FIXTUREREFERENCE',
    'REPLACEAPPROVER', 'REPLACEREFERENCE', 'TODO', 'FIXTURE', 'REPLACE']) {
    normalized = normalized.replace(new RegExp('^' + [...marker].join('\\s*'), 'i'), marker);
  }
  need(normalized.length > 0 && !/^(TODO|FIXTURE|REPLACE)($|[^\p{L}\p{N}]|\d|APPROVER|REFERENCE)/iu.test(normalized),
    label + ' is an unfinished identity');
}
function utc(value, label) {
  const match = typeof value === 'string' && /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.\d{1,9})?Z$/.exec(value);
  const time = match && Date.parse(value);
  need(match && !value.startsWith('0000-') && Number.isFinite(time) &&
    new Date(time).toISOString().slice(0, 19) === match[1] && time <= Date.now(), label + ' UTC invalid');
  return time;
}
// Reconstruct the subtree from actual regular-file Git identities already read
// by snapshot; no caller-supplied Functions tree can replace this measurement.
function functionsTree(files) {
  const root = new Map();
  for (const [file, identity] of Object.entries(files)) {
    if (!file.startsWith('functions/')) continue;
    const parts = file.slice(10).split('/'); let node = root;
    for (const part of parts.slice(0, -1)) {
      if (!node.has(part)) node.set(part, new Map());
      need(node.get(part) instanceof Map, 'Functions tree collision'); node = node.get(part);
    }
    need(!node.has(parts.at(-1)), 'Functions tree duplicate'); node.set(parts.at(-1), identity);
  }
  need(root.size > 0, 'Functions subtree absent');
  function tree(node) {
    const names = [...node.keys()].sort((a, b) => Buffer.compare(Buffer.from(a + (node.get(a) instanceof Map ? '/' : '')),
      Buffer.from(b + (node.get(b) instanceof Map ? '/' : ''))));
    const bytes = Buffer.concat(names.map(name => {
      const item = node.get(name), directory = item instanceof Map;
      return Buffer.concat([Buffer.from(`${directory ? '40000' : item.mode} ${name}\0`),
        Buffer.from(directory ? tree(item) : item.oid, 'hex')]);
    }));
    return crypto.createHash('sha1').update(Buffer.from(`tree ${bytes.length}\0`)).update(bytes).digest('hex');
  }
  return tree(root);
}
function verifyBusinessClientPolicy31(args) {
  exact(args, ['trust', 'request', 'input'], 'arguments');
  const {trust, request, input} = dataCopy(args);
  exact(input, ['schemaVersion', 'profile', 'repositoryRoot', 'gitExecutable', 'selected', 'originalMessageFile'], 'client input');
  need(input.schemaVersion === 1 && input.profile === 'build31-business-hosted-client-input-v1', 'input profile differs');
  bindHelpers(trust?.verifier?.files);
  const protocol = require('./business31HostedProtocol.cjs');
  protocol.validateTrust31(trust); protocol.validateRequest31(request);
  const selected = input.selected;
  exact(selected, ['source', 'sourceManifestSha256', 'backendApproval', 'backendClosure', 'descriptor',
    'ownerPointer', 'decisionPointer', 'originalMessage', 'appCheck'], 'selected');
  same(selected.source, trust.source, 'selected M');
  same(selected.sourceManifestSha256, trust.sourceManifestSha256, 'source manifest');
  same(selected.descriptor, request.descriptorPointer, 'descriptor');
  const pointerPaths = {
    backendApproval: 'release/approvals/build31-business-backend-deployment-approval.json',
    backendClosure: 'release/evidence/build31-business-backend-deployment-closure.json',
    descriptor: 'release/evidence/build31-business-private-replay.json',
    ownerPointer: 'release/approvals/build31-business-client-owner-authorization.json',
    decisionPointer: 'release/approvals/build31-business-client-compatibility-approval.json'
  };
  for (const [name, file] of Object.entries(pointerPaths)) {
    exact(selected[name], ['commit', 'file', 'sha256'], name);
    need(oid(selected[name].commit) && selected[name].file === file && digest(selected[name].sha256), name + ' invalid');
  }
  const trusted = require('./business31TrustedInput.cjs');
  const repository = trusted.openTrustedGitRepository31({repositoryRoot: input.repositoryRoot,
    gitExecutable: input.gitExecutable, gitSha256: trust.gitSha256});
  const ref = 'refs/heads/business31-admitted-' + request.candidate.commit;
  need(repository.readRef(ref) === request.candidate.commit, 'admitted S reference differs');
  const M = repository.snapshot(trust.source.commit), S = repository.snapshot(request.candidate.commit);
  same(M.tree, trust.source.tree, 'M tree'); same(S.tree, request.candidate.tree, 'S tree');
  same(functionsTree(M.files), trust.source.functionsTree, 'actual M Functions tree');
  repository.requireAncestor(M.commit, S.commit);
  for (const file of new Set([...Object.keys(M.files), ...Object.keys(S.files)])) {
    if (!equal(M.files[file], S.files[file])) need(S.files[file]?.mode === '100644' &&
      (!M.files[file] || M.files[file].mode === '100644') &&
      (file === FILES.pubspec || trusted.METADATA_PATHS.includes(file)), 'executable/source delta after M: ' + file);
  }
  const bindings = {};
  function read(snapshot, file, name) {
    need(snapshot.files[file]?.mode === '100644', 'regular committed member missing: ' + file);
    const bytes = repository.readBlob(snapshot.commit, file, 256 * 1024);
    need(bytes.length > 0, 'empty committed member: ' + file);
    if (name) bindings[name] = {commit: snapshot.commit, file, sha256: sha(bytes)};
    return bytes;
  }
  function json(snapshot, file, name) {
    return dataCopy(JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(read(snapshot, file, name))));
  }
  for (const name of Object.keys(pointerPaths)) {
    const p = selected[name];
    repository.requireAncestor(p.commit, S.commit);
    need(sha(repository.readBlob(p.commit, p.file, 256 * 1024)) === p.sha256 &&
      sha(read(S, p.file)) === p.sha256, 'committed selected pointer differs: ' + name);
  }
  const policy = json(S, FILES.policy, 'policy'), version = json(S, FILES.versionApproval, 'versionApproval');
  const successor = json(S, FILES.successorApproval, 'successorApproval');
  const current = json(S, FILES.currentSuccessor, 'currentSuccessor');
  const approval = json(S, FILES.appCheckApproval, 'appCheckApproval');
  const baselinePolicy = json(M, FILES.policy, 'backendPolicy');
  need(policy.schemaVersion === 3 && policy.release?.buildNumber === 31 && policy.versionPolicy?.buildNumber === 31,
    'both policy builds must be numeric 31');
  need(policy.firebaseProjectId === 'crm3-baf-ops-b8638' &&
    policy.permanentApplicationId === 'in.co.sail.bsl.crm3.bafops' &&
    policy.namespace === policy.permanentApplicationId, 'policy application/project identity differs');
  need(!Object.hasOwn(policy, 'runtimeBackendPrivateReplay'), 'legacy runtime route mixed with business');
  same(policy.clientBackendCompatibility, {...selected.decisionPointer, profile: 'build31-business-client-compatibility-v1'}, 'policy client decision');
  same(policy.businessBackendPrivateReplay, {...selected.descriptor, profile: 'build31-exact-business-backend-v1'}, 'policy descriptor');
  const v = policy.versionPolicy, r = policy.release;
  need(v.approved === true && v.scheme === 'semver2' && v.buildNumberPolicy === 'positive-int32-strictly-monotonic-never-reuse' &&
    v.failedOrWithdrawnBuildConsumesNumber === true && v.ledgerFile === 'release/build-number-ledger.json', 'version policy contract differs');
  need(v.approvalReceiptFile === FILES.versionApproval && v.sourceDocumentFile === FILES.successorApproval &&
    v.sourceDocumentSha256 === bindings.successorApproval.sha256, 'version source pointer differs');
  text(r.releaseId, 'releaseId'); text(v.reservationId, 'reservationId'); text(r.releaseTag, 'releaseTag');
  need(r.releaseChannel === 'production-candidate', 'release channel differs');
  need(typeof r.versionName === 'string' && /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$/.test(r.versionName) &&
    r.versionName === v.versionName && v.remoteReservationTag === 'crm3-build-reserved/31' &&
    v.remoteBuiltTag === 'crm3-build-built/31', 'version or build tag differs');
  need(version.schemaVersion === 1 && version.receiptType === 'version-and-build-policy' &&
    version.policy === 'strictly-monotonic-never-reuse', 'version receipt contract differs');
  for (const field of ['versionName', 'buildNumber', 'reservationId', 'remoteReservationTag', 'remoteBuiltTag', 'sourceDocumentFile', 'sourceDocumentSha256'])
    same(version[field], v[field], 'version receipt ' + field);
  need(successor.schemaVersion === 1 && successor.documentType === 'governed-build-number-rollover-approval' &&
    successor.approved === true, 'successor decision missing');
  same(successor.sourceBaseline, {commit: M.commit, tree: M.tree}, 'successor source baseline');
  accountable(successor.approverName, 'successor approver'); accountable(successor.approvalReference, 'successor reference');
  same(version.reference, successor.approvalReference, 'version approval reference');
  need(utc(successor.approvedAtUtc, 'successor approval') <= utc(version.recordedAtUtc, 'version receipt'), 'version chronology differs');
  for (const field of ['buildNumber', 'versionName', 'releaseId', 'releaseTag', 'releaseChannel'])
    same(successor.nextBuild?.[field], r[field], 'successor nextBuild ' + field);
  for (const field of ['reservationId', 'remoteReservationTag', 'remoteBuiltTag'])
    same(successor.nextBuild?.[field], v[field], 'successor nextBuild ' + field);
  const pubspec = new TextDecoder('utf-8', {fatal: true}).decode(read(S, FILES.pubspec, 'pubspec'));
  const oldPubspec = new TextDecoder('utf-8', {fatal: true}).decode(read(M, FILES.pubspec));
  const lines = pubspec.match(/^version:[^\r\n]*$/gm), oldLines = oldPubspec.match(/^version:[^\r\n]*$/gm);
  need(lines?.length === 1 && oldLines?.length === 1 && lines[0].trim() === 'version: ' + r.versionName + '+31' &&
    pubspec.replace(lines[0], 'version: MEASURED') === oldPubspec.replace(oldLines[0], 'version: MEASURED'), 'pubspec version/source differs');
  same(policy.finalization?.exactFunctionFleetDeploymentReceiptFile, selected.backendClosure.file, 'policy closure file');
  same(policy.finalization?.exactFunctionFleetDeploymentReceiptSha256, selected.backendClosure.sha256, 'policy closure digest');
  const rules = policy.finalization?.exactFirestoreRulesIndexesLiveReadback;
  same(rules, baselinePolicy.finalization?.exactFirestoreRulesIndexesLiveReadback, 'preserved Rules/index readback');
  need(rules && rules.verified === true && rules.allIndexesReady === true && rules.redundantDeploymentPerformed === false &&
    rules.receiptFile === RULES_READBACK.file && rules.receiptFileSha256 === RULES_READBACK.sha256 &&
    rules.sourceCommit === RULES_READBACK.sourceCommit, 'Rules/index readback contract differs');
  need(sha(read(M, rules.receiptFile, 'rulesReadback')) === rules.receiptFileSha256 &&
    sha(read(S, rules.receiptFile)) === rules.receiptFileSha256, 'Rules readback bytes differ');
  const deployed = current.authorityPlanes?.deployedBackend;
  need(current.schemaVersion === 2 && deployed, 'current successor backend plane missing');
  for (const [field, value] of Object.entries({deploymentApprovalFile: selected.backendApproval.file,
    deploymentApprovalSha256: selected.backendApproval.sha256, functionFleetEvidenceFile: selected.backendClosure.file,
    functionFleetEvidenceSha256: selected.backendClosure.sha256, functionFleetSourceCommit: M.commit,
    rulesAndIndexesEvidenceFile: rules.receiptFile, rulesAndIndexesEvidenceSha256: rules.receiptFileSha256,
    rulesAndIndexesSourceCommit: rules.sourceCommit,
    functionFleetReadbackDecision: 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    currentSourceFunctionDeployment: 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    rulesAndIndexesReadbackDecision: 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
    currentSourceRulesAndIndexesDeployment: 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK', productionBackendRuntimeAuthorized: true}))
    same(deployed[field], value, 'deployed backend ' + field);
  const currentSource = current.authorityPlanes.currentSource;
  need(currentSource?.packageVersion === r.versionName + '+31' && currentSource.sameBuildNumberReuseProhibited === true &&
    currentSource.distributionAuthority === false, 'current source version/distribution plane differs');
  same(policy.appCheckBuild, {clientEnabled: true, androidProvider: 'playIntegrity', approvalFile: FILES.appCheckApproval,
    approvalSha256: bindings.appCheckApproval.sha256}, 'policy AppCheck selection');
  need(approval.schemaVersion === 1 && approval.documentType === 'governed-app-check-client-build-approval' &&
    approval.approved === true && approval.intendedBuildNumber === 31 && approval.releaseId === r.releaseId &&
    approval.reservationId === v.reservationId && approval.firebaseProjectId === 'crm3-baf-ops-b8638' &&
    approval.applicationId === 'in.co.sail.bsl.crm3.bafops' && approval.clientEnabled === true &&
    approval.androidProvider === 'playIntegrity' && approval.enforcementChangeAuthorized === false &&
    approval.serverEnforcementAtBuild === false && approval.backendSourceCommit === M.commit &&
    approval.backendReceiptSha256 === selected.backendClosure.sha256, 'AppCheck approval/source joins differ');
  accountable(approval.approverName, 'AppCheck approver'); accountable(approval.approvalReference, 'AppCheck reference');
  utc(approval.approvedAtUtc, 'AppCheck approval');
  const scopes = {defaultMutatingEnforced: false, identityCallable: 'getBackendReleaseIdentity', identityCallableEnforced: true,
    identitySourceFile: FILES.identitySource, identitySourceSha256: IDENTITY_SHA256};
  same(approval.serverEnforcementScopesAtBuild, scopes, 'AppCheck server scopes');
  need(sha(read(M, FILES.identitySource, 'identitySource')) === IDENTITY_SHA256 &&
    equal(M.files[FILES.identitySource], S.files[FILES.identitySource]), 'actual M identity source differs');
  same(selected.appCheck, {releaseId: r.releaseId, reservationId: v.reservationId, clientEnabled: true,
    androidProvider: 'playIntegrity', mutatingDefaultEnforced: false,
    identityCallable: {name: scopes.identityCallable, enforced: true, sourceFile: FILES.identitySource, sourceSha256: IDENTITY_SHA256}},
  'recorded client AppCheck choice');
  need(repository.readRef(ref) === S.commit && repository.snapshot(M.commit).tree === M.tree &&
    repository.snapshot(S.commit).tree === S.tree, 'Git source/ref changed during measurement');
  bindHelpers(trust.verifier.files);
  return freeze({schemaVersion: 1, profile: PROFILE,
    verifier: {commit: trust.verifier.commit, tree: trust.verifier.tree}, source: trust.source,
    candidate: request.candidate, sourceManifestSha256: trust.sourceManifestSha256, bindings,
    descriptorPointer: selected.descriptor, closurePointer: selected.backendClosure, decisionPointer: selected.decisionPointer,
    release: {releaseId: r.releaseId, reservationId: v.reservationId, buildNumber: 31, versionName: r.versionName,
      reservationTag: v.remoteReservationTag, builtTag: v.remoteBuiltTag},
    appCheck: {clientEnabled: true, androidProvider: 'playIntegrity', dartDefine: 'true', approvalFile: FILES.appCheckApproval,
      approvalSha256: bindings.appCheckApproval.sha256, backendReceiptFile: selected.backendClosure.file,
      backendReceiptSha256: selected.backendClosure.sha256, serverEnforcementAtBuild: false, enforcementChangedByBuild: false,
      tokenValidationEvidence: 'not-proved-by-artifact-construction', serverEnforcementScopesAtBuild: scopes},
    policySourceVerified: true, appCheckSourcePolicyVerified: true,
    ...Object.fromEntries(FALSE_FLAGS.map(name => [name, false]))});
}
module.exports = Object.freeze({PROFILE, FILES, HELPERS, IDENTITY_SHA256, FALSE_FLAGS, verifyBusinessClientPolicy31});
