'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const zlib = require('node:zlib');
const {execFileSync} = require('node:child_process');
const subject = require('./business31TrustedInput.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const gitExecutable = process.env.BUSINESS31_TEST_GIT || (process.platform === 'win32' ? 'C:/Program Files/Git/mingw64/bin/git.exe' : '/usr/bin/git');
const gitSha256 = sha(fs.readFileSync(gitExecutable));
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-input-'));
const repositoryRoot = path.join(temporary, 'repository');
fs.mkdirSync(repositoryRoot);
const env = {...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
  GIT_AUTHOR_NAME: 'Local fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid', GIT_COMMITTER_NAME: 'Local fixture',
  GIT_COMMITTER_EMAIL: 'fixture@example.invalid', GIT_AUTHOR_DATE: '2026-01-01T00:00:00Z', GIT_COMMITTER_DATE: '2026-01-01T00:00:00Z'};
for (const key of Object.keys(env)) if (/^GIT_(?:CONFIG_COUNT|CONFIG_KEY_|CONFIG_VALUE_|DIR$|WORK_TREE$|INDEX_FILE$|OBJECT_DIRECTORY$|ALTERNATE_OBJECT_DIRECTORIES$)/i.test(key)) delete env[key];
function git(args, input) {
  return execFileSync(gitExecutable, ['-c', 'core.autocrlf=false', '-c', 'commit.gpgsign=false', '-c', `core.hooksPath=${path.join(temporary, 'no-hooks')}`,
    '-C', repositoryRoot, ...args], {env, input, timeout: 30000, windowsHide: true, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe']}).trim();
}
const bootstrap = fs.readFileSync(path.join(__dirname, 'business31TrustedInput.cjs'));
const bootstrapPath = 'tools/release/business31TrustedInput.cjs';
git(['init', '--initial-branch=main']);
function blob(bytes) { return git(['hash-object', '-w', '--stdin'], bytes); }
function put(file, bytes, mode = '100644') { git(['update-index', '--add', '--cacheinfo', `${mode},${blob(bytes)},${file}`]); }
function commit(parents = []) { return git(['commit-tree', git(['write-tree']), ...parents.flatMap(value => ['-p', value]), '-m', 'Private host fixture']); }
put(bootstrapPath, bootstrap);
put('functions/index.js', 'module.exports = 1;\n');
put('pubspec.yaml', 'name: fixture\nversion: 1.0.0+30\n');
put('README.md', 'Fixture\n');
const V = commit();
put('functions/index.js', 'module.exports = 2;\n');
const branch = commit([V]);
git(['read-tree', V]); put('client.txt', 'reviewed\n');
const mainParent = commit([V]);
put('functions/index.js', 'module.exports = 2;\n');
const M = commit([mainParent, branch]);
git(['update-ref', 'refs/heads/main', M]);
const options = {repositoryRoot, gitExecutable, gitSha256};
const tree = commitValue => git(['rev-parse', `${commitValue}^{tree}`]);
function candidate(changes = {}) {
  git(['read-tree', M]);
  for (const [file, value] of Object.entries(changes)) {
    if (value === null) git(['update-index', '--force-remove', file]);
    else if (typeof value === 'object' && !Buffer.isBuffer(value)) put(file, value.bytes, value.mode);
    else put(file, value);
  }
  const S = commit([M]); git(['update-ref', 'refs/heads/candidate', S]);
  return {schemaVersion: 1, profile: subject.PROFILE,
    verifier: {commit: V, tree: tree(V), files: {[bootstrapPath]: sha(bootstrap)}},
    source: {commit: M, tree: tree(M)}, candidate: {commit: S, tree: tree(S), ref: 'refs/heads/candidate'}};
}
const verify = envelope => subject.verifyBusiness31TrustedInput({...options, envelope});
test.after(() => {
  assert.equal(fs.realpathSync(temporary), path.resolve(temporary));
  assert.equal(path.dirname(temporary), fs.realpathSync(os.tmpdir()));
  fs.rmSync(temporary, {recursive: true, force: true});
});
test('real Git metadata boundary binds complete trees and grants no authority', () => {
  const envelope = candidate({'release/evidence/build31-business-private-replay.json': '{"untrusted":"data only"}\n', 'pubspec.yaml': 'name: fixture\nversion: 1.0.1-rc.1+31\n'});
  const result = verify(envelope);
  assert.equal(result.sourceCommit, M); assert.equal(result.fileCount, 6);
  assert.deepEqual(result.changedPaths, ['pubspec.yaml', 'release/evidence/build31-business-private-replay.json']);
  for (const key of ['metadataContentsValidated', 'platformIdentityAuthenticated', 'privateReplayVerified', 'deploymentAuthorized', 'constructionAuthorized']) assert.equal(result[key], false);
});
test('neutral API exposes only bounded read operations and exact parents', () => {
  candidate(); const repository = subject.openTrustedGitRepository31(options);
  assert.deepEqual(Object.keys(repository).sort(), ['readBlob', 'readRef', 'requireAncestor', 'snapshot']);
  const snapshot = repository.snapshot(M); assert.deepEqual(snapshot.parents, [mainParent, branch]);
  assert.equal(repository.readBlob(M, 'functions/index.js').toString(), 'module.exports = 2;\n');
  assert.throws(() => repository.readBlob(M, 'functions/index.js', 1), /exceeds bound/);
  assert.throws(() => repository.readBlob(M, '../config'), /Unsafe/);
  assert.throws(() => repository.snapshot('HEAD'), /Exact/);
  assert.throws(() => repository.readRef('--help'), /reference/);
  assert.throws(() => repository.requireAncestor(branch, mainParent), /ancestry absent/);
});
for (const file of ['functions/index.js', '.github/workflows/evil.yml', 'functions/package-lock.json', '.gitattributes', 'release/approvals/unlisted.json']) {
  test(`reject candidate-controlled source or unlisted metadata: ${file}`, () => assert.throws(() => verify(candidate({[file]: '{}\n'})), /Non-metadata/));
}
test('reject deleted metadata, executable metadata and a symlink Git blob', () => {
  assert.throws(() => verify(candidate({'README.md': null})), /deletion/);
  assert.throws(() => verify(candidate({'README.md': {bytes: 'changed\n', mode: '100755'}})), /mode/);
  assert.throws(() => verify(candidate({'linked': {bytes: '/outside', mode: '120000'}})), /regular files/);
});
test('reject gitlink and directory case collisions even when leaf paths differ', () => {
  let envelope = candidate(); git(['read-tree', M]); git(['update-index', '--add', '--cacheinfo', `160000,${V},module`]);
  const linked = commit([M]); git(['update-ref', 'refs/heads/candidate', linked]); envelope.candidate = {...envelope.candidate, commit: linked, tree: tree(linked)};
  assert.throws(() => verify(envelope), /regular files/);
  assert.throws(() => verify(candidate({'Case/one': '1', 'case/two': '2'})), /collision/);
});
test('reject wrong exact tree, moving input ref, wrong verifier bytes and non-merge M', () => {
  let envelope = candidate(); envelope.source.tree = '0'.repeat(40); assert.throws(() => verify(envelope), /tree differs/);
  envelope = candidate(); git(['update-ref', 'refs/heads/candidate', M]); assert.throws(() => verify(envelope), /reference differs/);
  envelope = candidate(); envelope.verifier.files[bootstrapPath] = '0'.repeat(64); assert.throws(() => verify(envelope), /digest differs/);
  envelope = candidate(); envelope.source = {commit: branch, tree: tree(branch)}; assert.throws(() => verify(envelope), /two-parent/);
});
test('reject modified trusted verifier code even though its path resembles release tooling', () => {
  assert.throws(() => verify(candidate({[bootstrapPath]: '// replaced\n'})), /verifier source changed/);
});
test('reject malformed/oversized/deep metadata and non-version pubspec changes', () => {
  const file = 'release/evidence/build31-business-private-replay.json';
  for (const value of ['[]', '{', '{"x":' + '['.repeat(33) + '0' + ']'.repeat(33) + '}']) assert.throws(() => verify(candidate({[file]: value})));
  assert.throws(() => verify(candidate({[file]: '{"x":"' + 'x'.repeat(2 * 1024 * 1024) + '"}'})), /exceeds bound/);
  assert.throws(() => verify(candidate({'pubspec.yaml': 'name: changed\nversion: 1.0.1+31\n'})), /version line/);
  assert.throws(() => verify(candidate({'pubspec.yaml': 'name: fixture\nversion: 1.0.1+32\n'})), /version line/);
});
test('reject inherited Git overrides and unknown local configuration before executing it', () => {
  candidate(); const config = path.join(repositoryRoot, '.git/config'), original = fs.readFileSync(config);
  for (const addition of ['\n[include]\n path = /tmp/other\n', '\n[core]\n fsmonitor = malicious-command\n', '\n[extensions]\n worktreeConfig = true\n']) {
    try { fs.writeFileSync(config, Buffer.concat([original, Buffer.from(addition)])); assert.throws(() => subject.openTrustedGitRepository31(options), /configuration/); }
    finally { fs.writeFileSync(config, original); }
  }
  const prior = process.env.GIT_DIR; process.env.GIT_DIR = '/nonexistent/untrusted';
  try { assert.equal(subject.openTrustedGitRepository31(options).snapshot(M).commit, M); }
  finally { if (prior === undefined) delete process.env.GIT_DIR; else process.env.GIT_DIR = prior; }
});
test('reject alternates, shallow state, worktree indirection and wrong Git executable bytes', () => {
  for (const file of ['objects/info/alternates', 'shallow']) {
    const target = path.join(repositoryRoot, '.git', file); fs.writeFileSync(target, '/outside\n');
    try { assert.throws(() => subject.openTrustedGitRepository31(options), /External or incomplete/); } finally { fs.unlinkSync(target); }
  }
  const fake = path.join(temporary, 'worktree'); fs.mkdirSync(fake); fs.writeFileSync(path.join(fake, '.git'), `gitdir: ${repositoryRoot}/.git\n`);
  assert.throws(() => subject.openTrustedGitRepository31({...options, repositoryRoot: fake}), /Regular directory/);
  assert.throws(() => subject.openTrustedGitRepository31({...options, gitSha256: '0'.repeat(64)}), /digest differs/);
});
test('configuration changes after opening a repository are refused', () => {
  const repository = subject.openTrustedGitRepository31(options), config = path.join(repositoryRoot, '.git/config'), original = fs.readFileSync(config);
  try { fs.appendFileSync(config, '\n# changed after binding\n'); assert.throws(() => repository.snapshot(M), /changed/); }
  finally { fs.writeFileSync(config, original); }
});

test('actual loose object corruption cannot hide behind the expected object filename', () => {
  const envelope = candidate({'README.md': 'original-object\n'});
  const repository = subject.openTrustedGitRepository31(options);
  const objectId = git(['rev-parse', `${envelope.candidate.commit}:README.md`]);
  const location = path.join(repositoryRoot, '.git/objects', objectId.slice(0, 2), objectId.slice(2));
  const original = fs.readFileSync(location);
  const content = Buffer.from('modified-object\n');
  const forged = zlib.deflateSync(Buffer.concat([Buffer.from(`blob ${content.length}\0`), content]));
  try {
    fs.chmodSync(location, 0o600); fs.writeFileSync(location, forged);
    assert.throws(() => repository.snapshot(envelope.candidate.commit), /fsck|hash mismatch|corrupt|missing/i);
    assert.throws(() => repository.readBlob(envelope.candidate.commit, 'README.md'), /content hash differs/);
  } finally { fs.writeFileSync(location, original); }
  assert.equal(repository.snapshot(envelope.candidate.commit).commit, envelope.candidate.commit);
});
