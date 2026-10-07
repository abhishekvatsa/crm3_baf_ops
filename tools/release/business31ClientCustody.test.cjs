'use strict';
// Synthetic original-message/owner records in an actual self-contained Git
// repository. No real human consent, private replay, credential or grant.
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const crypto = require('node:crypto'), zlib = require('node:zlib');
const {execFileSync} = require('node:child_process');
const subject = require('./business31ClientCustody.cjs');
const semantics = require('./business31ClientSemantics.cjs');
const descriptor = require('./business31PrivateDescriptor.cjs');
const trusted = require('./business31TrustedInput.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const raw = value => Buffer.from(JSON.stringify(value) + '\n');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-client-custody-'));
process.stdout.write('Retained synthetic client custody fixture: ' + temporary + '\n');
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
for (const file of [...new Set([...descriptor.CORE, ...subject.HELPERS])]) {
  files[file] = fs.readFileSync(path.join(__dirname, path.basename(file))); bindings[file] = sha(files[file]);
}
files['tools/v4/v4_2_r1_canonical_audit.py'] = Buffer.from('# synthetic nonloaded audit fixture\n');
bindings['tools/v4/v4_2_r1_canonical_audit.py'] = sha(files['tools/v4/v4_2_r1_canonical_audit.py']);
files[descriptor.HISTORICAL.file] = fs.readFileSync(path.resolve(__dirname, '../..', descriptor.HISTORICAL.file));
files['functions/index.js'] = Buffer.from('// never executed fixture source A\n');
files['functions/src/stage2dSecurityConfig.ts'] = Buffer.from('// synthetic identity source; policy not evaluated\n');
files['pubspec.yaml'] = Buffer.from('name: fixture\nversion: 1.0.0+30\n');
const V = commit(files);
const left = add(V, 'README.md', Buffer.from('Synthetic source main\n'));
const right = add(V, 'functions/index.js', Buffer.from('// never executed fixture source B\n'));
const M = commit({...left.files, 'functions/index.js': right.files['functions/index.js']}, [left, right]);
const source = {commit: M.commit, tree: M.tree,
  functionsTree: tree(Object.fromEntries(Object.entries(M.files).filter(([name]) => name.startsWith('functions/')).map(([name, bytes]) => [name.slice(10), bytes])))};
const approvalBytes = raw({synthetic: true, operationalAuthority: false});
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
const metadata = add(D, 'pubspec.yaml', Buffer.from('name: fixture\nversion: 1.0.1+31\n'));
const mainMetadata = add(B, 'README.md', Buffer.from('Synthetic allowed main metadata\n'));
const S = commit({...metadata.files, 'README.md': mainMetadata.files['README.md']}, [mainMetadata, metadata]);
const wrongParent = add(O, subject.FILES.decisionPointer, decisionBytes, {}, [B]);
const extraOwner = add(B, subject.FILES.ownerPointer, ownerBytes, {'README.md': Buffer.from('Extra owner edit\n')});
const extraOwnerD = add(extraOwner, subject.FILES.decisionPointer, decisionBytes);
const changedOwner = add(S, subject.FILES.ownerPointer, raw({...JSON.parse(ownerBytes), ownerReference: 'changed-after-custody'}));
const sourceEdit = add(S, 'functions/index.js', Buffer.from('// forbidden after decision\n'));
const reboundDecisionBytes = raw({...decision, ownerAuthorization: {...ownerPointer, commit: B.commit}});
const reboundDecision = add(O, subject.FILES.decisionPointer, reboundDecisionBytes);
pack(); ref('main', M); ref('candidate', S);

function input(candidate = S) {
  return {repositoryRoot: root, gitExecutable, gitSha256,
    envelope: {schemaVersion: 1, profile: trusted.PROFILE,
      verifier: {commit: V.commit, tree: V.tree, files: {...bindings}}, source: {commit: M.commit, tree: M.tree},
      candidate: {commit: candidate.commit, tree: candidate.tree, ref: 'refs/heads/candidate'}},
    selected: {source: {...source}, sourceManifestSha256: 'A'.repeat(64), backendApproval: {...approval},
      backendClosure: {...closure}, descriptor: {...descriptorPointer}, ownerPointer: {...ownerPointer},
      decisionPointer: {...decisionPointer}, originalMessage: {...originalMessage}, appCheck: structuredClone(appCheck)},
    originalMessageBytes: Buffer.from(originalMessageBytes), nowUtc: '2026-01-01T00:00:05Z'};
}
const verify = args => subject.verifyBusinessClientCustody31(args);
function selectedCandidate(candidate, change) {
  ref('candidate', candidate);
  const args = input(candidate); if (change) change(args); return args;
}
test('actual normal-merge S joins full descriptor preparation and B-to-O-to-D original bytes without granting authority', {timeout: 1200000}, () => {
  const result = verify(selectedCandidate(S));
  assert.equal(result.gitCustodyVerified, true); assert.equal(result.descriptorPreparationVerified, true);
  assert.equal(result.dedicatedOwnerDecisionDeltasVerified, true); assert.equal(result.recordedSemanticsValidated, true);
  assert.deepEqual(result.candidate.parents, [mainMetadata.commit, metadata.commit]);
  assert.deepEqual(result.changedAfterDecision, ['README.md', 'pubspec.yaml']);
  assert.deepEqual(result.ownerPointer, ownerPointer); assert.deepEqual(result.decisionPointer, decisionPointer);
  assert.equal(result.publicClosureRecordedAtUtc, '2026-01-01T00:00:00Z');
  for (const key of ['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated', 'humanIdentityAuthenticated',
    'trustedClockAuthenticated', 'platformIdentityAuthenticated', 'appCheckSourcePolicyVerified', 'privateClosureSemanticsVerified',
    'privateReplayVerified', 'hostedRecordedReplayAuthenticated', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
    'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized']) assert.equal(result[key], false, key);
  assert.ok(Object.isFrozen(result) && Object.isFrozen(result.candidate.parents));
  fs.writeFileSync(path.join(temporary, 'ACTUAL_GIT_POSITIVE_RESULT.json'), JSON.stringify(result, null, 2) + '\n', {flag: 'wx'});
});
for (const [name, change, error] of [
  ['raw original digest', a => a.originalMessageBytes[0] ^= 1, /original message bytes/],
  ['raw original count', a => a.selected.originalMessage.bytes++, /original message bytes/],
  ['raw input path instead of bytes', a => a.originalMessageBytes = '/never-follow-this-path', /byte bound/],
  ['oversized original', a => a.originalMessageBytes = Buffer.alloc(128 * 1024 + 1), /byte bound/],
  ['extra callback', a => a.verify = () => true, /input fields/],
  ['accessor selection', a => Object.defineProperty(a.selected, 'source', {get() {throw Error('must not invoke accessor');}}), /fields differ/],
  ['foreign owner path', a => a.selected.ownerPointer.file = 'release/approvals/foreign.json', /ownerPointer invalid/],
  ['nonexact owner commit', a => a.selected.ownerPointer.commit = 'HEAD', /ownerPointer invalid/],
  ['different selected source', a => a.selected.source.tree = '0'.repeat(40), /source\/envelope/],
  ['unknown selected field', a => a.selected.authenticated = true, /selected fields/]
]) test('refuses before Git: ' + name, () => {const args = input(); args.repositoryRoot = 'not-a-real-repository'; change(args); assert.throws(() => verify(args), error);});
for (const helper of subject.HELPERS) test('pre-import binding refuses missing or changed ' + path.basename(helper), () => {
  for (const missing of [true, false]) {
    const args = input(); args.repositoryRoot = 'not-a-real-repository';
    if (missing) delete args.envelope.verifier.files[helper]; else args.envelope.verifier.files[helper] = '0'.repeat(64);
    assert.throws(() => verify(args), /fixed helper selection absent|selected local helper differs/);
  }
});
test('actual Git refuses decision with wrong dedicated parent', () => {
  const args = selectedCandidate(wrongParent, a => a.selected.decisionPointer.commit = wrongParent.commit);
  assert.throws(() => verify(args), /parent links differ/);
});
test('actual Git refuses extra source change in owner-only commit', () => {
  const args = selectedCandidate(extraOwnerD, a => {
    a.selected.ownerPointer.commit = extraOwner.commit; a.selected.decisionPointer.commit = extraOwnerD.commit;
  });
  assert.throws(() => verify(args), /dedicated owner\/decision delta/);
});
test('actual Git refuses selected owner bytes changed after custody', () => {
  assert.throws(() => verify(selectedCandidate(changedOwner)), /selected pointer changed/);
});
test('actual Git refuses non-metadata source changes after decision', () => {
  assert.throws(() => verify(selectedCandidate(sourceEdit)), /non-metadata change after decision/);
});
test('actual Git refuses reserialized decision naming the wrong owner commit with the same digest', () => {
  const args = selectedCandidate(reboundDecision, a => {
    a.selected.decisionPointer.commit = reboundDecision.commit; a.selected.decisionPointer.sha256 = sha(reboundDecisionBytes);
  });
  assert.throws(() => verify(args), /decision\/selected owner pointer/);
});
test('actual Git refuses stale candidate reference before record interpretation', () => {
  ref('candidate', M); assert.throws(() => verify(input()), /candidate reference differs/);
});
test.after(() => {ref('candidate', S); process.stdout.write('Synthetic originals and repository retained: ' + temporary + '\n');});
