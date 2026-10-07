'use strict';
// Joined public custody measurements for the independently selected protected
// HostedResult entry. These exports do not authenticate their own caller or a
// supplied hosted-result object; the fresh protected entry owns that boundary.
// No candidate executable, callback, credential or operational grant is used.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {isDeepStrictEqual: equal} = require('node:util');

const PROFILE = 'build31-business-hosted-client-input-v1';
const CLIENT_PROFILE = 'build31-business-client-compatibility-v1';
const HELPERS = Object.freeze([
  'business31HostedClient.cjs', 'business31ClientCustody.cjs',
  'business31ClientSemantics.cjs', 'business31TrustedInput.cjs',
  'business31PrivateDescriptor.cjs', 'privateEvidenceBundle31.cjs', 'business31ClientPolicy.cjs'
].map(name => 'tools/release/' + name));
const HOSTED_KEYS = Object.freeze([
  'schemaVersion', 'profile', 'verifier', 'source', 'candidate', 'descriptorPointer',
  'closurePointer', 'commitments', 'runId', 'runAttempt', 'artifactId', 'resultSha256',
  'hostedRecordedReplayResultAuthenticated', 'ownerIdentityAuthenticated',
  'originalProcessExecutionAuthenticated', 'deploymentAuthorized',
  'constructionAuthorized', 'distributionAuthorized'
]);
const FALSE_HOSTED = Object.freeze(['ownerIdentityAuthenticated',
  'originalProcessExecutionAuthenticated', 'deploymentAuthorized',
  'constructionAuthorized', 'distributionAuthorized']);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const digest = value => typeof value === 'string' && /^[A-F0-9]{64}$/.test(value);
const identifier = value => typeof value === 'string' && /^[1-9][0-9]{0,19}$/.test(value);
function need(ok, message) { if (!ok) throw Error('Business hosted client: ' + message); }
function exact(value, names, label) {
  need(value && typeof value === 'object' && !Array.isArray(value) &&
    [Object.prototype, null].includes(Object.getPrototypeOf(value)) &&
    equal(Reflect.ownKeys(value).sort(), [...names].sort()) &&
    Object.values(Object.getOwnPropertyDescriptors(value)).every(d => 'value' in d),
  label + ' fields differ');
}
function same(actual, expected, label) { need(equal(actual, expected), label + ' differs'); }
function copyData(value) {
  let nodes = 0;
  function copy(item, depth) {
    need(++nodes <= 20000 && depth <= 20, 'input complexity exceeds bound');
    if (item === null || typeof item === 'boolean' ||
      (typeof item === 'number' && Number.isFinite(item))) return item;
    if (typeof item === 'string') { need(item.length <= 4096, 'input text exceeds bound'); return item; }
    need(item && typeof item === 'object', 'plain data input required');
    if (Array.isArray(item)) {
      need(Object.getPrototypeOf(item) === Array.prototype && item.length <= 512,
        'dense bounded data array required');
      const keys = Reflect.ownKeys(item);
      const expected = ['length', ...Array.from({length: item.length}, (_, index) => String(index))];
      need(keys.every(key => typeof key === 'string') && equal(keys.sort(), expected.sort()) &&
        Object.values(Object.getOwnPropertyDescriptors(item)).every(d => 'value' in d),
      'dense bounded data array required');
      return Array.prototype.map.call(item, child => copy(child, depth + 1));
    }
    const keys = Reflect.ownKeys(item);
    need(keys.length <= 512 && keys.every(key => typeof key === 'string' && key.length <= 1024),
      'input object exceeds bound');
    exact(item, keys, 'input object');
    return Object.fromEntries(keys.map(key => [key, copy(item[key], depth + 1)]));
  }
  return copy(value, 0);
}
function freeze(value) {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}
function regular(file) {
  need(typeof file === 'string' && path.isAbsolute(file), 'absolute file required');
  file = path.resolve(file);
  let current = path.parse(file).root;
  for (const part of file.slice(current.length).split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    need(!fs.lstatSync(current).isSymbolicLink(), 'redirected file refused');
  }
  need(fs.lstatSync(file).isFile(), 'regular file required');
  return file;
}
function readOriginal(file) {
  file = regular(file);
  const before = fs.statSync(file, {bigint: true});
  need(before.size > 0n && before.size <= 128n * 1024n, 'original message byte bound differs');
  const bytes = fs.readFileSync(file);
  regular(file);
  const after = fs.statSync(file, {bigint: true});
  need(['size', 'ino', 'mtimeNs', 'ctimeNs'].every(key => before[key] === after[key]) &&
    BigInt(bytes.length) === after.size, 'original message changed during read');
  return bytes;
}
function bindHelpers(bindings) {
  need(bindings && typeof bindings === 'object' && !Array.isArray(bindings), 'helper bindings absent');
  // Protocol is already mandatory at the protected entry; check its bytes here
  // as well before invoking its structural validators through these exports.
  for (const file of [...HELPERS, 'tools/release/business31HostedProtocol.cjs']) {
    need(Object.hasOwn(bindings, file) && digest(bindings[file]), 'fixed helper selection absent: ' + file);
    const local = regular(path.join(__dirname, path.basename(file)));
    need(fs.statSync(local).size <= 2 * 1024 * 1024 && sha(fs.readFileSync(local)) === bindings[file],
      'selected local helper differs: ' + file);
  }
}
function selection(args) {
  exact(args, ['trust', 'request', 'input'], 'input arguments');
  const selected = copyData(args), {trust, request, input} = selected;
  exact(input, ['schemaVersion', 'profile', 'repositoryRoot', 'gitExecutable', 'selected',
    'originalMessageFile'], 'protected client input');
  need(input.schemaVersion === 1 && input.profile === PROFILE, 'client input schema/profile differs');
  bindHelpers(trust?.verifier?.files);
  const protocol = require('./business31HostedProtocol.cjs');
  protocol.validateTrust31(trust);
  protocol.validateRequest31(request);
  need(typeof input.repositoryRoot === 'string' && path.isAbsolute(input.repositoryRoot) &&
    typeof input.gitExecutable === 'string' && path.isAbsolute(input.gitExecutable), 'repository/Git paths invalid');
  need(input.selected && typeof input.selected === 'object', 'client selected inputs absent');
  same(input.selected.source, trust.source, 'independently selected business source M');
  same(input.selected.sourceManifestSha256, trust.sourceManifestSha256, 'selected source manifest');
  same(input.selected.descriptor, request.descriptorPointer, 'selected descriptor pointer');
  return selected;
}
function measure({trust, request, input}) {
  const custody = require('./business31ClientCustody.cjs');
  const trusted = require('./business31TrustedInput.cjs');
  const descriptor = require('./business31PrivateDescriptor.cjs');
  const originalMessageBytes = readOriginal(input.originalMessageFile);
  const admittedRef = 'refs/heads/business31-admitted-' + request.candidate.commit;
  const envelope = {schemaVersion: 1, profile: trusted.PROFILE,
    verifier: trust.verifier,
    source: {commit: trust.source.commit, tree: trust.source.tree},
    candidate: {commit: request.candidate.commit, tree: request.candidate.tree, ref: admittedRef}};
  // This always runs the actual Git/descriptor/semantics path. A prepared result
  // or caller-supplied PASS cannot replace it, including on the post-await pass.
  const measured = custody.verifyBusinessClientCustody31({
    repositoryRoot: input.repositoryRoot, gitExecutable: input.gitExecutable, gitSha256: trust.gitSha256,
    envelope, selected: input.selected, originalMessageBytes, nowUtc: new Date().toISOString()
  });
  const repository = trusted.openTrustedGitRepository31({
    repositoryRoot: input.repositoryRoot, gitExecutable: input.gitExecutable, gitSha256: trust.gitSha256
  });
  const pointer = input.selected.descriptor;
  const bytes = repository.readBlob(pointer.commit, pointer.file, 2 * 1024 * 1024);
  need(sha(bytes) === pointer.sha256, 'original descriptor bytes differ');
  const record = descriptor.validateBusiness31PrivateDescriptor(descriptor.json(bytes));
  same(record.source, trust.source, 'descriptor source M');
  same(record.verifier, {commit: trust.verifier.commit, tree: trust.verifier.tree}, 'descriptor verifier V');
  same(record.approvalPointer, input.selected.backendApproval, 'descriptor backend approval');
  same(record.closurePointer, input.selected.backendClosure, 'descriptor backend closure');
  same(record.sourceManifestSha256, trust.sourceManifestSha256, 'descriptor source manifest');
  const commitments = {bundleSha256: record.custody.sha256, membersSha256: record.membersSha256,
    relocationSha256: record.relocationSha256, sourceManifestSha256: record.sourceManifestSha256};
  const policy = require('./business31ClientPolicy.cjs').verifyBusinessClientPolicy31({trust, request, input});
  const again = readOriginal(input.originalMessageFile);
  need(again.equals(originalMessageBytes), 'original message changed during custody checks');
  need(repository.readRef(admittedRef) === request.candidate.commit,
    'candidate ref changed during client measurement');
  bindHelpers(trust.verifier.files);
  return freeze({schemaVersion: 1, profile: PROFILE, custody: measured, commitments, policy,
    originalMessage: {sha256: sha(again), bytes: again.length}});
}
function prepareBusinessHostedClient31(args) { return measure(selection(args)); }
// The private replay entry also needs the same measured client projection. It
// performs custody and policy itself and accepts no hosted authentication input.
function measureBusinessHostedClient31(args) { return clientProjection(measure(selection(args))); }
function finishBusinessHostedClient31(args) {
  exact(args, ['trust', 'request', 'input', 'hostedResult'], 'finish arguments');
  const {trust, request, input} = selection({trust: args.trust, request: args.request, input: args.input});
  const hosted = copyData(args.hostedResult);
  exact(hosted, HOSTED_KEYS, 'hosted consumer projection');
  need(hosted.schemaVersion === 2 && hosted.profile === trust.profile &&
    hosted.hostedRecordedReplayResultAuthenticated === true, 'hosted consumer schema/profile differs');
  same(hosted.verifier, {commit: trust.verifier.commit, tree: trust.verifier.tree}, 'hosted verifier V');
  same(hosted.source, trust.source, 'hosted source M');
  same(hosted.candidate, request.candidate, 'hosted candidate S');
  same(hosted.descriptorPointer, input.selected.descriptor, 'hosted descriptor pointer');
  same(hosted.closurePointer, input.selected.backendClosure, 'hosted closure pointer');
  need(hosted.runId === request.runId && hosted.runAttempt === request.runAttempt &&
    identifier(hosted.artifactId) && digest(hosted.resultSha256), 'hosted run/artifact identity differs');
  need(FALSE_HOSTED.every(key => hosted[key] === false), 'hosted authority scope differs');
  exact(hosted.commitments, ['bundleSha256', 'membersSha256', 'relocationSha256', 'sourceManifestSha256'],
    'hosted commitments');
  need(Object.values(hosted.commitments).every(digest), 'hosted commitment digest invalid');
  // Deliberately repeat original Git custody and message reads after all hosted
  // awaits. A successful preflight cannot admit a moved ref or changed message.
  const prepared = measure({trust, request, input});
  same(hosted.commitments, prepared.commitments, 'hosted/original descriptor commitments');
  return clientProjection(prepared);
}
function clientProjection(prepared) {
  const c = prepared.custody;
  // Only the protected caller can authenticate the hosted-result handoff. This
  // helper returns measured client data and never echoes its authentication bit.
  return freeze({
    schemaVersion: 2, profile: CLIENT_PROFILE,
    ownerPointer: c.ownerPointer, decisionPointer: c.decisionPointer,
    originalMessage: prepared.originalMessage, appCheck: c.appCheck,
    publicClosureRecordedAtUtc: c.publicClosureRecordedAtUtc, policy: prepared.policy,
    gitCustodyVerified: true, dedicatedOwnerDecisionDeltasVerified: true,
    descriptorPreparationVerified: true, recordedSemanticsValidated: true,
    appCheckSourcePolicyVerified: true, independentlySelectedInputsAuthenticated: false,
    executingHostAuthenticated: false, humanIdentityAuthenticated: false,
    trustedClockAuthenticated: false, platformIdentityAuthenticated: false,
    credentialAccessAuthorized: false, backendDeploymentAuthorized: false,
    constructionAuthorized: false, signingAuthorized: false, distributionAuthorized: false
  });
}

// Closed data contract shared by authenticated hosted-artifact consumption and
// its controller. This validates recorded measurements; it does not perform Git
// custody, replay, platform authentication or grant operational authority.
function validateBusinessHostedClientMeasurement31(args) {
  exact(args, ['trust', 'request', 'client'], 'measurement arguments');
  const {trust, request, client} = copyData(args);
  const verified = ['gitCustodyVerified', 'dedicatedOwnerDecisionDeltasVerified',
    'descriptorPreparationVerified', 'recordedSemanticsValidated', 'appCheckSourcePolicyVerified'];
  const unverified = ['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated',
    'humanIdentityAuthenticated', 'trustedClockAuthenticated', 'platformIdentityAuthenticated',
    'credentialAccessAuthorized', 'backendDeploymentAuthorized', 'constructionAuthorized',
    'signingAuthorized', 'distributionAuthorized'];
  exact(client, ['schemaVersion', 'profile', 'ownerPointer', 'decisionPointer', 'originalMessage',
    'appCheck', 'publicClosureRecordedAtUtc', 'policy', ...verified, ...unverified], 'client measurement');
  need(client.schemaVersion === 2 && client.profile === CLIENT_PROFILE, 'client measurement version differs');
  need(verified.every(key => client[key] === true) && unverified.every(key => client[key] === false),
    'client measurement scope differs');
  const oid = value => typeof value === 'string' && /^[a-f0-9]{40}$/.test(value);
  const text = value => typeof value === 'string' && value.length > 0 && value.length <= 400 &&
    value === value.trim() && !/[\x00-\x1f\x7f]/.test(value);
  function pointer(value, file, label) {
    exact(value, ['commit', 'file', 'sha256'], label);
    need(oid(value.commit) && value.file === file && digest(value.sha256), label + ' invalid');
  }
  pointer(client.ownerPointer, 'release/approvals/build31-business-client-owner-authorization.json', 'client owner');
  pointer(client.decisionPointer, 'release/approvals/build31-business-client-compatibility-approval.json', 'client decision');
  exact(client.originalMessage, ['sha256', 'bytes'], 'client original message');
  need(digest(client.originalMessage.sha256) && Number.isSafeInteger(client.originalMessage.bytes) &&
    client.originalMessage.bytes > 0 && client.originalMessage.bytes <= 128 * 1024, 'client message invalid');
  const time = client.publicClosureRecordedAtUtc;
  const match = typeof time === 'string' && /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.\d{1,9})?Z$/.exec(time);
  need(match && !time.startsWith('0000-') && Number.isFinite(Date.parse(time)) &&
    new Date(Date.parse(time)).toISOString().slice(0, 19) === match[1], 'client closure time invalid');
  const app = client.appCheck;
  exact(app, ['releaseId', 'reservationId', 'clientEnabled', 'androidProvider', 'mutatingDefaultEnforced', 'identityCallable'], 'client AppCheck');
  const identity = {name: 'getBackendReleaseIdentity', enforced: true,
    sourceFile: 'functions/src/stage2dSecurityConfig.ts',
    sourceSha256: '1D46E7CDC200BA730AAD1F3BD30EF1C8D8E8509FC5EB7CB619A734077792A79F'};
  need(text(app.releaseId) && text(app.reservationId) && app.clientEnabled === true &&
    app.androidProvider === 'playIntegrity' && app.mutatingDefaultEnforced === false, 'client AppCheck invalid');
  same(app.identityCallable, identity, 'client identity source');
  const policy = client.policy;
  const policyFalse = [...unverified, 'privateReplayVerified'];
  exact(policy, ['schemaVersion', 'profile', 'verifier', 'source', 'candidate', 'sourceManifestSha256', 'bindings',
    'descriptorPointer', 'closurePointer', 'decisionPointer', 'release', 'appCheck',
    'policySourceVerified', 'appCheckSourcePolicyVerified', ...policyFalse], 'client policy');
  need(policy.schemaVersion === 1 && policy.profile === 'build31-business-client-policy-v1' &&
    policy.policySourceVerified === true && policy.appCheckSourcePolicyVerified === true &&
    policyFalse.every(key => policy[key] === false), 'client policy scope differs');
  exact(policy.verifier, ['commit', 'tree'], 'policy verifier');
  exact(policy.source, ['commit', 'tree', 'functionsTree'], 'policy source');
  exact(policy.candidate, ['commit', 'tree', 'ref', 'kind', 'pullRequest'], 'policy candidate');
  need(Object.values(policy.verifier).every(oid) && Object.values(policy.source).every(oid) &&
    oid(policy.candidate.commit) && oid(policy.candidate.tree), 'policy Git identity invalid');
  same(policy.verifier, {commit: trust.verifier.commit, tree: trust.verifier.tree}, 'policy verifier join');
  same(policy.source, trust.source, 'policy source join'); same(policy.candidate, request.candidate, 'policy candidate join');
  need(digest(policy.sourceManifestSha256) && policy.sourceManifestSha256 === trust.sourceManifestSha256,
    'policy source manifest join differs');
  pointer(policy.descriptorPointer, 'release/evidence/build31-business-private-replay.json', 'policy descriptor');
  pointer(policy.closurePointer, 'release/evidence/build31-business-backend-deployment-closure.json', 'policy closure');
  pointer(policy.decisionPointer, 'release/approvals/build31-business-client-compatibility-approval.json', 'policy decision');
  same(policy.descriptorPointer, request.descriptorPointer, 'policy descriptor join');
  same(policy.decisionPointer, client.decisionPointer, 'policy decision join');
  const paths = {policy: 'release/production-release-policy.json', versionApproval: 'release/approvals/version-policy-approval.json',
    successorApproval: 'release/approvals/build-number-31-successor-approval.json', currentSuccessor: 'release/current-successor-state.json',
    appCheckApproval: 'release/approvals/build31-app-check-client-approval.json', pubspec: 'pubspec.yaml',
    backendPolicy: 'release/production-release-policy.json', identitySource: identity.sourceFile,
    rulesReadback: 'release/evidence/build30-current-source-firestore-rules-indexes-live-readback.json'};
  exact(policy.bindings, Object.keys(paths), 'policy bindings');
  for (const [name, file] of Object.entries(paths)) {
    pointer(policy.bindings[name], file, 'policy binding ' + name);
    same(policy.bindings[name].commit, ['backendPolicy', 'identitySource', 'rulesReadback'].includes(name)
      ? trust.source.commit : request.candidate.commit, 'policy binding source ' + name);
  }
  need(policy.bindings.identitySource.sha256 === identity.sourceSha256 &&
    policy.bindings.rulesReadback.sha256 === '62A707AC10A76B6C9D6D1466987D558E8C9186602B57E0E75EB760A5F4160CEC',
  'policy preserved source digest differs');
  exact(policy.release, ['releaseId', 'reservationId', 'buildNumber', 'versionName', 'reservationTag', 'builtTag'], 'policy release');
  const release = policy.release;
  need(release.buildNumber === 31 && release.releaseId === app.releaseId && release.reservationId === app.reservationId &&
    typeof release.versionName === 'string' && /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?$/.test(release.versionName) &&
    release.reservationTag === 'crm3-build-reserved/31' && release.builtTag === 'crm3-build-built/31', 'policy release join differs');
  same(policy.appCheck, {clientEnabled: true, androidProvider: 'playIntegrity', dartDefine: 'true',
    approvalFile: paths.appCheckApproval, approvalSha256: policy.bindings.appCheckApproval.sha256,
    backendReceiptFile: policy.closurePointer.file, backendReceiptSha256: policy.closurePointer.sha256,
    serverEnforcementAtBuild: false, enforcementChangedByBuild: false,
    tokenValidationEvidence: 'not-proved-by-artifact-construction', serverEnforcementScopesAtBuild: {
      defaultMutatingEnforced: false, identityCallable: identity.name, identityCallableEnforced: true,
      identitySourceFile: identity.sourceFile, identitySourceSha256: identity.sourceSha256}}, 'policy AppCheck join');
  return freeze(client);
}

module.exports = Object.freeze({PROFILE, CLIENT_PROFILE, HELPERS,
  prepareBusinessHostedClient31, finishBusinessHostedClient31, measureBusinessHostedClient31,
  validateBusinessHostedClientMeasurement31});
