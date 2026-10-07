'use strict';
// Synthetic original-message/owner records in an actual self-contained Git
// repository. No real human consent, private replay, credential or grant.

const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const crypto = require('node:crypto'), zlib = require('node:zlib');
const {execFileSync} = require('node:child_process');
const subject = require('../business31ClientCustody.cjs');
const semantics = require('../business31ClientSemantics.cjs');
const descriptor = require('../business31PrivateDescriptor.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const raw = value => Buffer.from(JSON.stringify(value) + '\n');
const hostedClient = require('../business31HostedClient.cjs');
const policySubject = require('../business31ClientPolicy.cjs');
const hostedFixture = require('./business31HostedFixture.cjs');
const releaseRoot = path.resolve(__dirname, '..');
function createFixture({mutations = [], identityBytes, extraProducers = [], publicApprovalEnvelope = false} = {}) {
if (typeof publicApprovalEnvelope !== 'boolean') throw Error('publicApprovalEnvelope must be a boolean');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-client-policy-'));
process.stdout.write('Retained synthetic client policy fixture: ' + temporary + '\n');
const root = path.join(temporary, 'repository'); fs.mkdirSync(root);
const gitExecutable = process.env.BUSINESS31_TEST_GIT ||
  (process.platform === 'win32' ? 'C:/Program Files/Git/mingw64/bin/git.exe' : '/usr/bin/git');
const gitSha256 = sha(fs.readFileSync(gitExecutable));
const env = {GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
  GIT_TERMINAL_PROMPT: '0', GIT_NO_LAZY_FETCH: '1'};
for (const key of ['SystemRoot', 'WINDIR', 'PATH', 'TEMP', 'TMP']) if (process.env[key] !== undefined) env[key] = process.env[key];
function git(args, input) {
  return execFileSync(gitExecutable, ['-c', 'protocol.allow=never', '-c', 'core.autocrlf=false',
    '-c', 'core.hooksPath=' + path.join(temporary, 'absent-hooks'), '-C', root, ...args],
  {env, input, timeout: 30000, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe']});
}
git(['init', '--initial-branch=main']);

// Build ordinary Git objects directly, then let real Git index-pack/fsck and
// the unchanged trusted reader validate them. No fake repository API is used.
const objects = new Map();
function object(type, bytes) {
  bytes = Buffer.from(bytes);
  const oid = crypto.createHash('sha1').update(Buffer.from(`${type} ${bytes.length}\0`)).update(bytes).digest('hex');
  objects.set(oid, {type, bytes}); return oid;
}
function tree(files) {
  const entries = new Map();
  for (const [name, bytes] of Object.entries(files)) {
    let node = entries; const parts = name.split('/');
    for (const part of parts.slice(0, -1)) {if (!node.has(part)) node.set(part, new Map()); node = node.get(part);}
    node.set(parts.at(-1), object('blob', bytes));
  }
  function write(node) {
    const names = [...node.keys()].sort((a, b) => Buffer.compare(Buffer.from(a + (node.get(a) instanceof Map ? '/' : '')),
      Buffer.from(b + (node.get(b) instanceof Map ? '/' : ''))));
    return object('tree', Buffer.concat(names.map(name => {
      const entry = node.get(name), directory = entry instanceof Map;
      return Buffer.concat([Buffer.from(`${directory ? '40000' : '100644'} ${name}\0`), Buffer.from(directory ? write(entry) : entry, 'hex')]);
    })));
  }
  return write(entries);
}
let sequence = 0;
function commit(files, parents = []) {
  const treeOid = tree(files), text = `tree ${treeOid}\n` + parents.map(p => `parent ${p.commit}\n`).join('') +
    `author Synthetic Fixture <fixture@example.invalid> 1767225600 +0000\ncommitter Synthetic Fixture <fixture@example.invalid> 1767225600 +0000\n\nSynthetic client custody ${++sequence}\n`;
  return {commit: object('commit', Buffer.from(text)), tree: treeOid, files: {...files}};
}
function add(parent, name, bytes, extra = {}, parents = [parent]) {
  return commit({...parent.files, [name]: bytes, ...extra}, parents);
}
function pack() {
  const parts = [Buffer.from('PACK'), Buffer.from([0, 0, 0, 2]), Buffer.alloc(4)];
  parts[2].writeUInt32BE(objects.size);
  for (const {type, bytes} of objects.values()) {
    let size = bytes.length; const header = [(({commit: 1, tree: 2, blob: 3}[type]) << 4) | (size & 15)];
    size = Math.floor(size / 16);
    while (size) {header[header.length - 1] |= 128; header.push(size & 127); size = Math.floor(size / 128);}
    parts.push(Buffer.from(header), zlib.deflateSync(bytes));
  }
  const body = Buffer.concat(parts); git(['index-pack', '--stdin'], Buffer.concat([body, crypto.createHash('sha1').update(body).digest()]));
}
function ref(name, value) {fs.writeFileSync(path.join(root, '.git/refs/heads', name), value.commit + '\n');}
const files = {}, bindings = {};
const pilotProducers = new Set(['runtimePilotAuthority31', 'stagedPromotionSourceAuthority',
  'collectProductionGlobalPullBackend', 'collectFunctionFleetRuntimeIdentityReadback',
  'collectFunctionsIamDependenciesReadback', 'collectFirestoreRulesIndexesReadback',
  'deploymentFleetContract', 'scopedCallableInvokerIam', 'scopedCallableInvokerIamPublic',
  'reviewedFirestoreRulesDeployment', 'reviewedRulesRuntime', 'reviewedRulesRuntimeCollector',
  'reviewedRulesReconciliation', 'reviewedBackendControls', 'reviewedBackendVerifierAuthority']
  .map(name => 'tools/release/' + name + (name === 'runtimePilotAuthority31' ? '.cjs' : '.js')));
if (!Array.isArray(extraProducers) || extraProducers.length > 32 ||
    extraProducers.some(file => typeof file !== 'string' ||
      (!/^tools\/release\/business31[A-Za-z]+\.(?:cjs|py)$/.test(file) && !pilotProducers.has(file))))
  throw Error('Only bounded literal local producer filenames are admitted in this test fixture');
for (const file of [...new Set([...descriptor.CORE, ...subject.HELPERS, ...hostedClient.HELPERS, ...policySubject.HELPERS, ...extraProducers])]) {
  files[file] = fs.readFileSync(path.join(releaseRoot, path.basename(file))); bindings[file] = sha(files[file]);
}
files['tools/v4/v4_2_r1_canonical_audit.py'] = fs.readFileSync(
  path.resolve(releaseRoot, '../..', 'tools/v4/v4_2_r1_canonical_audit.py'));
bindings['tools/v4/v4_2_r1_canonical_audit.py'] = sha(files['tools/v4/v4_2_r1_canonical_audit.py']);
files[descriptor.HISTORICAL.file] = fs.readFileSync(path.resolve(releaseRoot, '../..', descriptor.HISTORICAL.file));
files['functions/index.js'] = Buffer.from('// never executed fixture source A\n');
files['functions/src/stage2dSecurityConfig.ts'] = identityBytes || fs.readFileSync(
  path.resolve(releaseRoot, '../..', policySubject.FILES.identitySource));
const baselinePolicy = JSON.parse(fs.readFileSync(path.resolve(releaseRoot, '../..', policySubject.FILES.policy)));
const rules = baselinePolicy.finalization.exactFirestoreRulesIndexesLiveReadback;
files[policySubject.FILES.policy] = raw(baselinePolicy);
files[rules.receiptFile] = fs.readFileSync(path.resolve(releaseRoot, '../..', rules.receiptFile));
files['pubspec.yaml'] = Buffer.from('name: fixture\nversion: 1.0.0+30\n');
const V = commit(files);
const left = add(V, 'README.md', Buffer.from('Synthetic source main\n'));
const right = add(V, 'functions/index.js', Buffer.from('// never executed fixture source B\n'));
const M = commit({...left.files, 'functions/index.js': right.files['functions/index.js']}, [left, right]);
const source = {commit: M.commit, tree: M.tree,
  functionsTree: tree(Object.fromEntries(Object.entries(M.files).filter(([name]) => name.startsWith('functions/')).map(([name, bytes]) => [name.slice(10), bytes])))};
const approvalBytes = raw(publicApprovalEnvelope ? {schemaVersion: 1,
  documentType: 'build31-business-private-record-custody', recordKind: 'decision', source,
  recordedAtUtc: '2026-01-01T00:00:00Z', privateRecord: {file: 'synthetic/private-approval.json',
    sha256: 'E'.repeat(64), bytes: 1}} : {synthetic: true, operationalAuthority: false});
const A = add(M, subject.FILES.backendApproval, approvalBytes);
const approval = {commit: A.commit, file: subject.FILES.backendApproval, sha256: sha(approvalBytes)};
const closureBytes = raw({schemaVersion: 1, documentType: 'build31-business-private-record-custody', recordKind: 'closure',
  source, recordedAtUtc: '2026-01-01T00:00:00Z', privateRecord: {file: 'synthetic/private-closure.json', sha256: 'C'.repeat(64), bytes: 1}});
const C = add(A, subject.FILES.backendClosure, closureBytes);
const closure = {commit: C.commit, file: subject.FILES.backendClosure, sha256: sha(closureBytes)};
const descriptorBytes = raw({schemaVersion: 2, documentType: 'build31-business-backend-private-replay', profile: descriptor.PROFILE,
  verifier: {commit: V.commit, tree: V.tree}, source, sourceManifestSha256: 'A'.repeat(64),
  approvalPointer: approval, closurePointer: closure,
  custody: {provider: 'gcs', bucket: 'crm3-baf-ops-b8638-firestore-restore',
    objectName: 'release-custody/build-31/business-backend/' + M.commit + '/synthetic/private-replay-bundle.json',
    generation: '1', bytes: 1, sha256: 'B'.repeat(64)}, bundleEncoding: 'gzip-members-v1', expandedBytes: 1,
  membersSha256: 'C'.repeat(64), relocationSha256: 'D'.repeat(64), producerBindings: bindings, historicalBaseline: descriptor.HISTORICAL});
const B = add(C, subject.FILES.descriptor, descriptorBytes);
const descriptorPointer = {commit: B.commit, file: subject.FILES.descriptor, sha256: sha(descriptorBytes)};
const appCheck = {releaseId: 'synthetic-release', reservationId: 'synthetic-reservation', clientEnabled: true,
  androidProvider: 'playIntegrity', mutatingDefaultEnforced: false,
  identityCallable: {name: 'getBackendReleaseIdentity', enforced: true,
    sourceFile: 'functions/src/stage2dSecurityConfig.ts', sourceSha256: sha(M.files['functions/src/stage2dSecurityConfig.ts'])}};
const common = {schemaVersion: 1, profile: semantics.PROFILE, source, sourceManifestSha256: 'A'.repeat(64),
  backendApproval: approval, backendClosure: closure, descriptor: descriptorPointer, scope: semantics.SCOPE,
  appCheck, ownerReference: 'SYNTHETIC-NOT-A-HUMAN-AUTHORIZATION'};
const originalMessageBytes = raw({...common, documentType: 'retained-direct-human-business-client-instruction',
  question: semantics.ownerQuestion31(common, common.ownerReference), answer: 'Approve exact-source client construction only',
  messageId: 'synthetic-message', conversationId: 'synthetic-conversation', receivedAtUtc: '2026-01-01T00:00:01Z',
  provenance: 'operator-retained-direct-human-message', humanIdentityMachineAuthenticated: false});
const originalMessage = {sha256: sha(originalMessageBytes), bytes: originalMessageBytes.length};
const ownerBytes = raw({...common, documentType: 'build31-business-client-owner-authorization',
  authorizedAtUtc: '2026-01-01T00:00:01Z', recordedAtUtc: '2026-01-01T00:00:02Z', originalMessage});
const O = add(B, subject.FILES.ownerPointer, ownerBytes);
const ownerPointer = {commit: O.commit, file: subject.FILES.ownerPointer, sha256: sha(ownerBytes)};
const decision = {...common, documentType: 'build31-business-client-compatibility-decision', ownerAuthorization: ownerPointer,
  decidedAtUtc: '2026-01-01T00:00:03Z', recordedAtUtc: '2026-01-01T00:00:04Z'};
const decisionBytes = raw(decision), D = add(O, subject.FILES.decisionPointer, decisionBytes);
const decisionPointer = {commit: D.commit, file: subject.FILES.decisionPointer, sha256: sha(decisionBytes)};
const release = {buildNumber: 31, versionName: '1.0.1', releaseId: appCheck.releaseId,
  releaseTag: 'synthetic-release-tag', releaseChannel: 'production-candidate'};
const successorApproval = {schemaVersion: 1, documentType: 'governed-build-number-rollover-approval',
  approved: true, approvedAtUtc: '2026-01-01T00:00:05Z', approverName: 'Synthetic Test Operator',
  approvalReference: 'SYNTHETIC-ROLLOVER-ONLY', sourceBaseline: {commit: M.commit, tree: M.tree},
  nextBuild: {...release, reservationId: appCheck.reservationId,
    remoteReservationTag: 'crm3-build-reserved/31', remoteBuiltTag: 'crm3-build-built/31'}};
const versionPolicy = {approved: true, scheme: 'semver2', versionName: release.versionName, buildNumber: 31,
  buildNumberPolicy: 'positive-int32-strictly-monotonic-never-reuse', reservationId: appCheck.reservationId,
  ledgerFile: 'release/build-number-ledger.json', approvalReceiptFile: policySubject.FILES.versionApproval,
  sourceDocumentFile: policySubject.FILES.successorApproval, sourceDocumentSha256: sha(raw(successorApproval)),
  remoteReservationTag: 'crm3-build-reserved/31', remoteBuiltTag: 'crm3-build-built/31',
  failedOrWithdrawnBuildConsumesNumber: true};
const versionApproval = {schemaVersion: 1, receiptType: 'version-and-build-policy',
  reference: successorApproval.approvalReference, recordedAtUtc: '2026-01-01T00:00:06Z',
  policy: 'strictly-monotonic-never-reuse', ...Object.fromEntries(['versionName', 'buildNumber', 'reservationId',
    'remoteReservationTag', 'remoteBuiltTag', 'sourceDocumentFile', 'sourceDocumentSha256'].map(key => [key, versionPolicy[key]]))};
const appCheckApproval = {schemaVersion: 1, documentType: 'governed-app-check-client-build-approval',
  approved: true, approvedAtUtc: '2026-01-01T00:00:05Z', approverName: 'Synthetic Test Operator',
  approvalReference: 'SYNTHETIC-APP-CHECK-ONLY', intendedBuildNumber: 31,
  releaseId: release.releaseId, reservationId: appCheck.reservationId,
  firebaseProjectId: 'crm3-baf-ops-b8638', applicationId: 'in.co.sail.bsl.crm3.bafops',
  clientEnabled: true, androidProvider: 'playIntegrity', enforcementChangeAuthorized: false,
  serverEnforcementAtBuild: false, backendSourceCommit: M.commit, backendReceiptSha256: closure.sha256,
  serverEnforcementScopesAtBuild: {defaultMutatingEnforced: false, identityCallable: 'getBackendReleaseIdentity',
    identityCallableEnforced: true, identitySourceFile: policySubject.FILES.identitySource,
    identitySourceSha256: policySubject.IDENTITY_SHA256}};
const currentSuccessor = {schemaVersion: 2, authorityPlanes: {
  currentSource: {packageVersion: '1.0.1+31', sameBuildNumberReuseProhibited: true, distributionAuthority: false},
  deployedBackend: {deploymentApprovalFile: approval.file, deploymentApprovalSha256: approval.sha256,
    functionFleetEvidenceFile: closure.file, functionFleetEvidenceSha256: closure.sha256, functionFleetSourceCommit: M.commit,
    rulesAndIndexesEvidenceFile: rules.receiptFile, rulesAndIndexesEvidenceSha256: rules.receiptFileSha256,
    rulesAndIndexesSourceCommit: rules.sourceCommit,
    functionFleetReadbackDecision: 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    currentSourceFunctionDeployment: 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK',
    rulesAndIndexesReadbackDecision: 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK',
    currentSourceRulesAndIndexesDeployment: 'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK', productionBackendRuntimeAuthorized: true}}};
const policy = {...baselinePolicy, release, versionPolicy,
  clientBackendCompatibility: {...decisionPointer, profile: 'build31-business-client-compatibility-v1'},
  businessBackendPrivateReplay: {...descriptorPointer, profile: 'build31-exact-business-backend-v1'},
  finalization: {...baselinePolicy.finalization, exactFunctionFleetDeploymentReceiptFile: closure.file,
    exactFunctionFleetDeploymentReceiptSha256: closure.sha256},
  appCheckBuild: {clientEnabled: true, androidProvider: 'playIntegrity', approvalFile: policySubject.FILES.appCheckApproval,
    approvalSha256: sha(raw(appCheckApproval))}};
const records = {policy, versionApproval, successorApproval, currentSuccessor, appCheckApproval};
// Mutation instructions are test data. They alter committed fixture records,
// never the verifier or the independently chosen real toolchain.
for (const mutation of mutations) {
  let target = records[mutation.record];
  if (!target || !Array.isArray(mutation.path) || mutation.path.length === 0) throw Error('Invalid fixture mutation');
  for (const part of mutation.path.slice(0, -1)) target = target[part];
  if (mutation.remove) delete target[mutation.path.at(-1)];
  else target[mutation.path.at(-1)] = mutation.value;
}
// Keep hash pointers coherent when testing record semantics, so a refusal is
// not merely an accidental stale digest from construction of a negative case.
if (mutations.some(m => m.record === 'appCheckApproval'))
  policy.appCheckBuild.approvalSha256 = sha(raw(appCheckApproval));
if (mutations.some(m => m.record === 'successorApproval')) {
  policy.versionPolicy.sourceDocumentSha256 = sha(raw(successorApproval));
  versionApproval.sourceDocumentSha256 = policy.versionPolicy.sourceDocumentSha256;
}
const metadataFiles = Object.fromEntries(Object.entries(records).map(([name, value]) => [policySubject.FILES[name], raw(value)]));
const metadata = add(D, 'pubspec.yaml', Buffer.from('name: fixture\nversion: 1.0.1+31\n'), metadataFiles);
const mainMetadata = add(B, 'README.md', Buffer.from('Synthetic allowed main metadata\n'));
const S = commit({...metadata.files, 'README.md': mainMetadata.files['README.md']}, [mainMetadata, metadata]);
const sourceEdit = add(S, 'functions/index.js', Buffer.from('// forbidden after decision\n'));
pack(); ref('main', M); ref('candidate', S);

const originalMessageFile = path.join(temporary, 'original-message.json');
fs.writeFileSync(originalMessageFile, originalMessageBytes, {flag: 'wx'});
function setCandidate(candidate = S) {
  const directory = path.join(root, '.git/refs/heads');
  fs.mkdirSync(directory, {recursive: true});
  fs.writeFileSync(path.join(directory, 'business31-admitted-' + S.commit), candidate.commit + '\n');
}
function clientInput() {
  return {schemaVersion: 1, profile: hostedClient.PROFILE, repositoryRoot: root, gitExecutable,
    selected: {source: {...source}, sourceManifestSha256: 'A'.repeat(64), backendApproval: {...approval},
      backendClosure: {...closure}, descriptor: {...descriptorPointer}, ownerPointer: {...ownerPointer},
      decisionPointer: {...decisionPointer}, originalMessage: {...originalMessage}, appCheck: structuredClone(appCheck)},
    originalMessageFile};
}
function platformFixture() {
  const f = hostedFixture.fixture();
  f.trust.verifier = {commit: V.commit, tree: V.tree, files: {...bindings}};
  f.trust.source = {...source}; f.trust.gitSha256 = gitSha256;
  f.trust.launcherSha256 = bindings['tools/release/business31HostedLauncher.py'];
  f.request.candidate = {...f.request.candidate, commit: S.commit, tree: S.tree};
  f.request.descriptorPointer = {...descriptorPointer};
  f.run.head_sha = V.commit; f.job.head_sha = V.commit; f.candidate.head.sha = S.commit;
  f.result = {...f.result, verifier: {commit: V.commit, tree: V.tree}, source: {...source},
    candidate: structuredClone(f.request.candidate), descriptorPointer: {...descriptorPointer},
    closurePointer: {...closure}, commitments: {bundleSha256: 'B'.repeat(64), membersSha256: 'C'.repeat(64),
      relocationSha256: 'D'.repeat(64), sourceManifestSha256: 'A'.repeat(64)},
    platform: {...f.result.platform, workflowCommit: V.commit}};
  return f;
}
function reset() { setCandidate(S); fs.writeFileSync(originalMessageFile, originalMessageBytes); }
reset();
return {root, temporary, originalMessageFile, originalMessageBytes, clientInput, platformFixture,
  setCandidate, reset, S, M, records, sourceEdit};
}
module.exports = Object.freeze({createFixture});
