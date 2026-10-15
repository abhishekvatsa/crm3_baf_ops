'use strict';
// Real, small, self-contained local Git fixtures only. No npm/Python/Java child,
// installation, network, credential or operational qualification is performed.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const crypto = require('node:crypto'), cp = require('node:child_process'), vm = require('node:vm');
const {createRequire} = require('node:module');
const subject = require('./business31TrustedInput.cjs');
const sourceFile = path.join(__dirname, 'business31TrustedInput.cjs');
const gitExecutable = process.env.BUSINESS31_TEST_GIT || (process.platform === 'win32' ? 'C:/Program Files/Git/mingw64/bin/git.exe' : '/usr/bin/git');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const gitSha256 = sha(fs.readFileSync(gitExecutable));
const blobOid = bytes => crypto.createHash('sha1').update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest('hex');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-git-batch-'));
process.stdout.write('Retained batch fixtures: ' + temporary + '\n');
const env = {GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
  GIT_TERMINAL_PROMPT: '0', GIT_NO_LAZY_FETCH: '1', GIT_AUTHOR_NAME: 'Synthetic fixture',
  GIT_AUTHOR_EMAIL: 'fixture@example.invalid', GIT_COMMITTER_NAME: 'Synthetic fixture',
  GIT_COMMITTER_EMAIL: 'fixture@example.invalid'};
for (const name of ['SystemRoot', 'WINDIR', 'PATH', 'TEMP', 'TMP']) if (process.env[name] !== undefined) env[name] = process.env[name];
function git(root, args, input) {
  return cp.execFileSync(gitExecutable, ['-c', 'core.autocrlf=false', '-c', 'commit.gpgsign=false',
    '-c', 'protocol.allow=never', '-c', 'core.hooksPath=' + path.join(temporary, 'absent-hooks'),
    '-C', root, ...args], {env, input, windowsHide: true, timeout: 30000, stdio: ['pipe', 'pipe', 'pipe']});
}
function fixture(label, rows) {
  const repositoryRoot = path.join(temporary, label); fs.mkdirSync(repositoryRoot);
  git(repositoryRoot, ['init', '--initial-branch=main']);
  const message = 'Synthetic bounded batch fixture only\n';
  const parts = [Buffer.from('commit refs/heads/main\ncommitter Fixture <fixture@example.invalid> 1767225600 +0000\ndata ' + Buffer.byteLength(message) + '\n' + message)];
  for (const [name, bytes, mode = '100644'] of rows) {
    parts.push(Buffer.from(`M ${mode} inline ${name}\ndata ${bytes.length}\n`), bytes, Buffer.from('\n'));
  }
  parts.push(Buffer.from('\ndone\n'));
  git(repositoryRoot, ['fast-import', '--quiet', '--done'], Buffer.concat(parts));
  const commit = git(repositoryRoot, ['rev-parse', 'HEAD']).toString('utf8').trim();
  return {repositoryRoot, gitExecutable, gitSha256, commit};
}
const rows = Array.from({length: 15}, (_, i) => [`file-${String(i).padStart(2, '0')}`,
  i === 0 ? Buffer.alloc(0) : i === 1 ? Buffer.from([0, 10, 255, 13, 10, 128]) : Buffer.from(`unique body ${i}\n`),
  i === 14 ? '100755' : '100644']);
rows.push(['same-bytes', Buffer.from(rows[1][1]), '100644']);
const small = fixture('small', rows);

// Instrument only this test's module instance. All successful transport calls
// still execute the selected real Git. Corruption is confined to returned test
// buffers; no executable, installed runtime or repository object is corrupted.
function instrument({afterGit, readFile} = {}) {
  const calls = [];
  const localRequire = createRequire(sourceFile);
  const replacement = name => {
    if (name === 'node:child_process') return {execFileSync(executable, args, options) {
      calls.push({executable, args: [...args], options});
      const result = cp.execFileSync(executable, args, options);
      return afterGit ? afterGit(result, args, options, calls) : result;
    }};
    if (name === 'node:fs' && readFile) return {...fs, readFileSync(...args) {return readFile(args, () => fs.readFileSync(...args));}};
    return localRequire(name);
  };
  const module = {exports: {}};
  vm.runInThisContext('(function(require,module,exports,__filename,__dirname){\n' + fs.readFileSync(sourceFile, 'utf8') + '\n})',
    {filename: sourceFile})(replacement, module, module.exports, sourceFile, __dirname);
  return {api: module.exports, calls};
}
const isBatch = args => args.slice(-2).join(' ') === 'cat-file --batch';
function framed(bytes, oid = blobOid(bytes)) {return Buffer.concat([Buffer.from(`${oid} blob ${bytes.length}\n`), bytes, Buffer.from('\n')]);}


// Each individual read remains fresh and keeps maxBytes + 1024 transport allocation.
test('individual blob reads preserve independent real Git bytes with two guarded commands', () => {
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(small);
  for (const [name, expected] of rows) {
    tracked.calls.length = 0;
    const actual = repository.readBlob(small.commit, name);
    assert.deepEqual(actual, expected);
    assert.deepEqual(actual, git(small.repositoryRoot, ['cat-file', 'blob', small.commit + ':' + name]));
    assert.equal(tracked.calls.length, 2);
    assert.deepEqual(tracked.calls[0].args.slice(-3), ['rev-parse', '--verify', small.commit + ':' + name]);
    const call = tracked.calls[1]; assert.ok(isBatch(call.args));
    assert.equal(call.options.input.toString('ascii'), blobOid(expected) + '\n');
    assert.equal(call.options.maxBuffer, 2 * 1024 * 1024 + 1024);
    assert.equal(call.options.timeout, 30000); assert.deepEqual(call.options.stdio, ['pipe', 'pipe', 'pipe']);
  }
  repository.readBlob(small.commit, 'file-01').fill(42);
  assert.deepEqual(repository.readBlob(small.commit, 'same-bytes'), rows[1][1], 'fresh aliases are detached');
});
test('individual maxBytes remains a hard body limit and preserves its transport allocation cap', () => {
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(small), expected = rows[1][1];
  tracked.calls.length = 0;
  assert.deepEqual(repository.readBlob(small.commit, 'file-01', expected.length), expected);
  assert.equal(tracked.calls.length, 2); assert.equal(tracked.calls[1].options.maxBuffer, expected.length + 1024);
  let returned; assert.throws(() => { returned = repository.readBlob(small.commit, 'file-01', expected.length - 1); }, /exceeds bound/);
  assert.equal(returned, undefined);
  const f = fixture('individual-small-cap', [['large-for-caller', Buffer.alloc(2048, 1)]]);
  const limited = instrument(), reader = limited.api.openTrustedGitRepository31(f); limited.calls.length = 0;
  assert.throws(() => reader.readBlob(f.commit, 'large-for-caller', 64), error => error.code === 'ENOBUFS');
  assert.equal(limited.calls.length, 2); assert.equal(limited.calls[1].options.maxBuffer, 1088);
  for (const value of [0, -1, 2 * 1024 * 1024 + 1, NaN, Infinity, '6', null, {}]) {
    tracked.calls.length = 0; assert.throws(() => repository.readBlob(small.commit, 'file-01', value), /limit outside fixed bound/);
    assert.equal(tracked.calls.length, 0, 'invalid limits launch no child');
  }
});
test('individual transport rejects malformed type size OID hash and output without returned bytes', () => {
  const source = rows[1][1], oid = blobOid(source);
  const corruptions = [output => Buffer.from(oid + ' missing\n'), output => Buffer.from(oid + ' tree 6\n'),
    output => framed(source, '0'.repeat(40)), output => framed(Buffer.from(source).fill(42), oid),
    output => Buffer.from(oid + ' blob 7\n'), output => Buffer.from(oid + ' blob 06\n'),
    output => Buffer.from(oid + ' blob 9007199254740993\n'), output => Buffer.concat([output, Buffer.from('trailing')]),
    output => output.subarray(0, output.length - 1), output => Buffer.alloc(source.length + 1025)];
  for (const corrupt of corruptions) {
    const tracked = instrument({afterGit(output, args) { return isBatch(args) ? corrupt(output) : output; }});
    const repository = tracked.api.openTrustedGitRepository31(small); tracked.calls.length = 0; let returned;
    assert.throws(() => { returned = repository.readBlob(small.commit, 'file-01', source.length); },
      /identity\/type\/order|content hash|exceeds bound|Trailing|truncated/);
    assert.equal(returned, undefined); assert.equal(tracked.calls.length, 2);
  }
});
test('explicit parser bounds and foreign accessor Proxy or sparse OID arrays refuse without traps', () => {
  const source = rows[1][1], oid = blobOid(source), output = framed(source);
  assert.deepEqual(subject.parseBlobBatch31(output, [oid], source.length, source.length + 1024).get(oid), source);
  assert.throws(() => subject.parseBlobBatch31(output, [oid], source.length - 1, source.length + 1024), /exceeds bound/);
  for (const limit of [0, -1, NaN, Infinity, '6', null, {}, 2 * 1024 * 1024 + 1])
    assert.throws(() => subject.parseBlobBatch31(output, [oid], limit), /limit outside fixed bound/);
  for (const limit of [0, -1, NaN, Infinity, '64', null, {}, 16 * 1024 * 1024 + 1])
    assert.throws(() => subject.parseBlobBatch31(output, [oid], source.length, limit), /output limit outside fixed bound/);
  let touched = 0;
  const accessor = [oid]; Object.defineProperty(accessor, '0', {get() { touched++; return oid; }});
  const symbol = [oid]; symbol[Symbol('extra')] = true;
  const inherited = [oid]; Object.setPrototypeOf(inherited, {get every() { touched++; throw Error('inherited callback'); }});
  const proxy = new Proxy([oid], {get() { touched++; throw Error('get trap'); }, ownKeys() { touched++; throw Error('keys trap'); },
    getPrototypeOf() { touched++; throw Error('prototype trap'); }, getOwnPropertyDescriptor() { touched++; throw Error('descriptor trap'); }});
  const revoked = Proxy.revocable([oid], {}); revoked.revoke();
  for (const list of [accessor, symbol, inherited, proxy, revoked.proxy, vm.runInNewContext('["' + oid + '"]'), new Array(1), [oid, oid]])
    assert.throws(() => subject.parseBlobBatch31(output, list), /bounded batch OIDs/);
  assert.throws(() => subject.parseBlobBatch31(new Proxy(output, {get() { touched++; throw Error('buffer trap'); }}), [oid]), /output exceeds bound/);
  assert.equal(touched, 0);
});
test('individual read keeps post-batch configuration and selected executable drift checks', () => {
  const config = path.join(small.repositoryRoot, '.git/config'), original = fs.readFileSync(config);
  const changed = instrument({afterGit(output, args) { if (isBatch(args)) fs.appendFileSync(config, '\n[include]\n path = /untrusted\n'); return output; }});
  const repository = changed.api.openTrustedGitRepository31(small);
  try { assert.throws(() => repository.readBlob(small.commit, 'file-01'), /configuration/); }
  finally { fs.writeFileSync(config, original); }
  let drift = false;
  const executable = instrument({afterGit(output, args) { if (isBatch(args)) drift = true; return output; },
    readFile(args, actual) { const b = actual(); return drift && path.resolve(args[0]) === path.resolve(gitExecutable) ? Buffer.concat([b, Buffer.from('changed')]) : b; }});
  const fresh = executable.api.openTrustedGitRepository31(small);
  assert.throws(() => fresh.readBlob(small.commit, 'file-01'), /runtime changed during batch/);
});

// Fresh selected verifier populations use the same real guarded batch transport.
// All existing full-snapshot/scalar/parser tests below remain unchanged.
const selectedPaths31 = ['file-00', 'file-01', 'same-bytes', 'file-02', 'file-03',
  'file-04', 'file-05', 'file-06', 'file-07'];
test('selected real Git batches return exactly scalar subset bytes with bounded fewer commands', () => {
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(small);
  const snapshot = repository.snapshot(small.commit);
  tracked.calls.length = 0;
  const scalar = new Map([...selectedPaths31].sort().map(name => [name, repository.readBlob(small.commit, name)]));
  assert.equal(tracked.calls.length, selectedPaths31.length * 2);
  tracked.calls.length = 0;
  const selected = repository.readSnapshotBlobs(snapshot, selectedPaths31);
  assert.deepEqual(selected, scalar);
  assert.deepEqual([...selected.keys()], [...selectedPaths31].sort());
  assert.equal(tracked.calls.length, 2);
  assert.deepEqual(tracked.calls.map(c => c.options.input.length / 41), [7, 1]);
  for (const c of tracked.calls) {
    assert.ok(isBatch(c.args)); assert.equal(c.options.timeout, 30000);
    assert.equal(c.options.maxBuffer, 16 * 1024 * 1024);
    assert.deepEqual(c.options.stdio, ['pipe', 'pipe', 'pipe']);
  }
  selected.get('same-bytes')[0] = 42;
  assert.equal(selected.get('file-01')[0], 0, 'selected alias paths must have detached buffers');
});

test('selected path data refuses malformed populations and Proxy traps before any batch child', () => {
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(small);
  const snapshot = repository.snapshot(small.commit);
  const other = subject.openTrustedGitRepository31(small), foreign = other.snapshot(small.commit);
  let touched = 0;
  const accessor = ['file-00']; Object.defineProperty(accessor, '0', {get() { touched++; return 'file-00'; }});
  const symbol = ['file-00']; symbol[Symbol('extra')] = true;
  const inherited = ['file-00']; Object.setPrototypeOf(inherited, {get map() { touched++; return () => []; }});
  const proxy = new Proxy(['file-00'], {
    getPrototypeOf() { touched++; throw Error('prototype trap ran'); },
    ownKeys() { touched++; throw Error('keys trap ran'); },
    getOwnPropertyDescriptor() { touched++; throw Error('descriptor trap ran'); },
    get() { touched++; throw Error('value trap ran'); }
  });
  const revoked = Proxy.revocable(['file-00'], {}); revoked.revoke();
  tracked.calls.length = 0;
  for (const value of [null, 'file-00', [], new Array(1), Array(257).fill('file-00'),
    ['file-00', 'file-00'], ['absent'], ['file-14'], ['../escape'], ['/absolute'],
    ['file-00\n'], [() => 'file-00'], accessor, symbol, inherited, proxy, revoked.proxy]) {
    assert.throws(() => repository.readSnapshotBlobs(snapshot, value), /Selected blob|Unsafe Git path/);
  }
  for (const value of [foreign, structuredClone(snapshot), {}]) {
    assert.throws(() => repository.readSnapshotBlobs(value, ['file-00']), /not issued/);
  }
  assert.equal(touched, 0, 'Proxy reflection/getter/inherited callbacks must not execute');
  assert.equal(tracked.calls.length, 0, 'malformed selection must not launch a batch child');
});

test('selected scope never reads an unrelated oversized member and default full scope still refuses it', () => {
  const f = fixture('selected-oversize-scope', [['in-scope', Buffer.from('selected\n')],
    ['out-of-scope', Buffer.alloc(2 * 1024 * 1024 + 1, 1)]]);
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(f);
  const snapshot = repository.snapshot(f.commit);
  tracked.calls.length = 0;
  assert.deepEqual(repository.readSnapshotBlobs(snapshot, ['in-scope']), new Map([['in-scope', Buffer.from('selected\n')]]));
  assert.equal(tracked.calls.length, 1);
  assert.equal(tracked.calls[0].options.input.toString('ascii'), snapshot.files['in-scope'].oid + '\n');
  assert.throws(() => repository.readSnapshotBlobs(snapshot), /exceeds bound/);
});

test('selected transport preserves malformed binary output refusals with no returned map', () => {
  const source = Buffer.from(rows[1][1]);
  const corruptions = [
    output => Buffer.from(`${blobOid(source)} missing\n`),
    output => Buffer.from(output.toString('latin1').replace(' blob ', ' tree '), 'latin1'),
    output => framed(source, '0'.repeat(40)),
    output => framed(Buffer.from(source).fill(42), blobOid(source)),
    output => Buffer.concat([output, Buffer.from('trailing')]),
    output => output.subarray(0, output.length - 1)
  ];
  for (const corrupt of corruptions) {
    const tracked = instrument({afterGit(output, args) { return isBatch(args) ? corrupt(output) : output; }});
    const repository = tracked.api.openTrustedGitRepository31(small), snapshot = repository.snapshot(small.commit);
    tracked.calls.length = 0; let returned;
    assert.throws(() => { returned = repository.readSnapshotBlobs(snapshot, ['file-01']); },
      /identity\/type\/order|content hash|Trailing|truncated/);
    assert.equal(returned, undefined); assert.equal(tracked.calls.length, 1);
  }
});

test('selected second-chunk failure does not expose the valid first chunk', () => {
  let count = 0;
  const tracked = instrument({afterGit(output, args) { return isBatch(args) && ++count === 2 ? Buffer.from('missing\n') : output; }});
  const repository = tracked.api.openTrustedGitRepository31(small), snapshot = repository.snapshot(small.commit);
  let returned;
  assert.throws(() => { returned = repository.readSnapshotBlobs(snapshot, selectedPaths31); }, /identity\/type\/order/);
  assert.equal(returned, undefined); assert.equal(count, 2);
});

test('actual Git batch matches unchanged scalar bytes, modes and complete population with fewer commands', () => {
  const tracked = instrument(), repository = tracked.api.openTrustedGitRepository31(small);
  const snapshot = repository.snapshot(small.commit);
  assert.equal(snapshot.files['file-14'].mode, '100755');
  assert.ok(Object.isFrozen(snapshot) && Object.isFrozen(snapshot.files) && Object.isFrozen(snapshot.files['file-00']));
  tracked.calls.length = 0;
  const scalarStart = process.hrtime.bigint();
  const scalar = new Map(Object.keys(snapshot.files).sort().map(name => [name, repository.readBlob(small.commit, name)]));
  const scalarMs = Number(process.hrtime.bigint() - scalarStart) / 1e6, scalarCommands = tracked.calls.length;
  tracked.calls.length = 0;
  const batchStart = process.hrtime.bigint();
  const batch = repository.readSnapshotBlobs(snapshot);
  const batchMs = Number(process.hrtime.bigint() - batchStart) / 1e6, batchCommands = tracked.calls.length;
  assert.deepEqual(batch, scalar);
  assert.equal(scalarCommands, 16 * 2); assert.equal(batchCommands, 3);
  assert.deepEqual(tracked.calls.map(c => c.options.input.length / 41), [7, 7, 1]);
  for (const call of tracked.calls) {
    assert.equal(call.executable, path.resolve(gitExecutable)); assert.ok(isBatch(call.args));
    assert.equal(call.options.maxBuffer, 16 * 1024 * 1024); assert.equal(call.options.timeout, 30000);
    assert.deepEqual(call.options.stdio, ['pipe', 'pipe', 'pipe']);
    assert.match(call.options.input.toString('ascii'), /^(?:[0-9a-f]{40}\n){1,7}$/);
    assert.ok(!call.args.some(a => ['--filters', '--textconv', '--follow-symlinks', '--batch-all-objects'].includes(a)));
  }
  batch.get('same-bytes')[0] = 42;
  assert.equal(batch.get('file-01')[0], 0, 'equal OIDs have detached path buffers');
  assert.equal(repository.readBlob(small.commit, 'file-01')[0], 0);
  const measurement = {scope: 'Tiny synthetic 16-path/15-unique-blob fixture only; not a full collector timing or speedup claim',
    sourceFiles: 16, uniqueBlobs: 15, scalarCommands, batchCommands, scalarMs, batchMs};
  fs.writeFileSync(path.join(temporary, 'MEASURED_COMPARISON.json'), JSON.stringify(measurement, null, 2) + '\n', {flag: 'wx'});
  process.stdout.write('Fixture comparison: ' + JSON.stringify(measurement) + '\n');
});
test('snapshots must originate from this exact repository instance', () => {
  const first = subject.openTrustedGitRepository31(small), second = subject.openTrustedGitRepository31(small);
  const snapshot = first.snapshot(small.commit);
  for (const foreign of [null, {}, Object.freeze({files: {}}), structuredClone(snapshot), second.snapshot(small.commit)]) {
    assert.throws(() => first.readSnapshotBlobs(foreign), /not issued/);
  }
  assert.throws(() => {snapshot.files['file-00'].oid = '0'.repeat(40);}, TypeError);
});
test('empty snapshot remains a complete bounded map and still checks drift', () => {
  const empty = fixture('empty', []), repository = subject.openTrustedGitRepository31(empty), snapshot = repository.snapshot(empty.commit);
  assert.deepEqual([...repository.readSnapshotBlobs(snapshot)], []);
  const config = path.join(empty.repositoryRoot, '.git/config'), original = fs.readFileSync(config);
  try {fs.appendFileSync(config, '\n[include]\n path = /untrusted\n'); assert.throws(() => repository.readSnapshotBlobs(snapshot), /configuration/);}
  finally {fs.writeFileSync(config, original);}
});
test('a failed second chunk never returns the already-read prefix', () => {
  let count = 0;
  const tracked = instrument({afterGit(output, args) {return isBatch(args) && ++count === 2 ? Buffer.from('missing\n') : output;}});
  const repository = tracked.api.openTrustedGitRepository31(small), snapshot = repository.snapshot(small.commit);
  let returned;
  assert.throws(() => {returned = repository.readSnapshotBlobs(snapshot);}, /identity\/type\/order/);
  assert.equal(returned, undefined); assert.equal(count, 2);
});
test('configuration change after real batch execution refuses returned bytes', () => {
  const config = path.join(small.repositoryRoot, '.git/config'), original = fs.readFileSync(config);
  const tracked = instrument({afterGit(output, args) {if (isBatch(args)) fs.appendFileSync(config, '\n[include]\n path = /untrusted\n'); return output;}});
  const repository = tracked.api.openTrustedGitRepository31(small), snapshot = repository.snapshot(small.commit);
  try {assert.throws(() => repository.readSnapshotBlobs(snapshot), /configuration/);}
  finally {fs.writeFileSync(config, original);}
});
test('selected executable mismatch refuses before any Git child', () => {
  const tracked = instrument();
  assert.throws(() => tracked.api.openTrustedGitRepository31({...small, gitSha256: '0'.repeat(64)}), /executable digest/);
  assert.equal(tracked.calls.length, 0);
});
test('executable bytes are rechecked after the real batch returns', () => {
  let drift = false;
  const tracked = instrument({afterGit(output, args) {if (isBatch(args)) drift = true; return output;},
    readFile(args, actual) {const raw = actual(); return drift && path.resolve(args[0]) === path.resolve(gitExecutable) ? Buffer.concat([raw, Buffer.from('changed')]) : raw;}});
  const repository = tracked.api.openTrustedGitRepository31(small), snapshot = repository.snapshot(small.commit);
  assert.throws(() => repository.readSnapshotBlobs(snapshot), /runtime changed during batch/);
});
test('actual repository indirection and unsupported tree modes remain refused', () => {
  const bad = fixture('symlink-mode', [['link', Buffer.from('elsewhere'), '120000']]);
  assert.throws(() => subject.openTrustedGitRepository31(bad).snapshot(bad.commit), /regular files/);
  const redirected = path.join(temporary, 'redirected-root');
  fs.symlinkSync(small.repositoryRoot, redirected, process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => subject.openTrustedGitRepository31({...small, repositoryRoot: redirected}), /Redirected/);
  const alternate = path.join(small.repositoryRoot, '.git/objects/info/alternates');
  try {fs.writeFileSync(alternate, '/untrusted\n', {flag: 'wx'}); assert.throws(() => subject.openTrustedGitRepository31(small), /External or incomplete/);}
  finally {fs.unlinkSync(alternate);}
});
test('actual oversized blob is refused by scalar and batch readers', () => {
  const large = fixture('oversize', [['oversized', Buffer.alloc(2 * 1024 * 1024 + 1, 1)]]);
  const repository = subject.openTrustedGitRepository31(large), snapshot = repository.snapshot(large.commit);
  assert.throws(() => repository.readBlob(large.commit, 'oversized'), /exceeds bound/);
  assert.throws(() => repository.readSnapshotBlobs(snapshot), /exceeds bound/);
});

const body = Buffer.from([0, 10, 255, 128]), oid = blobOid(body), correct = framed(body);
test('binary parser accepts exact empty and binary bodies without text decoding', () => {
  const empty = Buffer.alloc(0), emptyOid = blobOid(empty);
  const actual = subject.parseBlobBatch31(Buffer.concat([framed(empty), correct]), [emptyOid, oid]);
  assert.deepEqual(actual.get(emptyOid), empty); assert.deepEqual(actual.get(oid), body);
});
for (const [name, bytes, requested, error] of [
  ['missing response', Buffer.from(`${oid} missing\n`), [oid], /identity\/type\/order/],
  ['wrong type', Buffer.from(`${oid} tree 4\n`), [oid], /identity\/type\/order/],
  ['wrong OID', framed(body, '0'.repeat(40)), [oid], /identity\/type\/order/],
  ['wrong order', Buffer.concat([framed(Buffer.alloc(0)), correct]), [oid, blobOid(Buffer.alloc(0))], /identity\/type\/order/],
  ['wrong hash', Buffer.concat([Buffer.from(`${oid} blob 4\n`), Buffer.from('evil'), Buffer.from('\n')]), [oid], /content hash/],
  ['leading-zero size', Buffer.from(`${oid} blob 04\n`), [oid], /identity\/type\/order/],
  ['negative size', Buffer.from(`${oid} blob -1\n`), [oid], /identity\/type\/order/],
  ['oversize', Buffer.from(`${oid} blob 2097153\n`), [oid], /exceeds bound/],
  ['unsafe integer', Buffer.from(`${oid} blob 9007199254740993\n`), [oid], /exceeds bound/],
  ['truncated body', correct.subarray(0, correct.length - 3), [oid], /truncated/],
  ['missing final LF', correct.subarray(0, correct.length - 1), [oid], /truncated/],
  ['wrong separator', Buffer.concat([correct.subarray(0, correct.length - 1), Buffer.from('\r')]), [oid], /truncated/],
  ['trailing bytes', Buffer.concat([correct, Buffer.from('extra')]), [oid], /Trailing/],
  ['overlong header', Buffer.from('a'.repeat(65) + '\n'), [oid], /header/],
  ['high-bit masked ASCII', Buffer.concat([Buffer.from([correct[0] | 128]), correct.subarray(1)]), [oid], /ASCII/],
  ['CRLF header', Buffer.concat([Buffer.from(`${oid} blob 4\r\n`), body, Buffer.from('\n')]), [oid], /ASCII/],
  ['duplicate requests', correct, [oid, oid], /bounded batch OIDs/],
  ['short request', correct, ['HEAD'], /bounded batch OIDs/],
  ['empty request', Buffer.alloc(0), [], /bounded batch OIDs/],
  ['output cap', Buffer.alloc(16 * 1024 * 1024 + 1), [oid], /output exceeds/]
]) test('binary parser refuses ' + name, () => assert.throws(() => subject.parseBlobBatch31(bytes, requested), error));

test('actual synthetic collector preflight gets the complete original source without launching runtime commands',
  {skip: process.platform !== 'win32' ? 'Windows preflight contract; portable Git and parser cases still execute' : !process.env.BUSINESS31_COLLECTOR_TEST_HOST_CONFIG ? 'Explicit selected local support paths required for Windows preflight' : false,
    timeout: 180000}, () => {
    const {createFixture, regularMap, binding} = require('./fixtures/business31CollectorFixture.cjs');
    const host = JSON.parse(fs.readFileSync(process.env.BUSINESS31_COLLECTOR_TEST_HOST_CONFIG, 'utf8'));
    const f = createFixture({parent: temporary, name: 'preflight-only', toolsDirectory: __dirname, gitExecutable: host.gitExecutable});
    const config = {schemaVersion: 1, repositoryRoot: f.repositoryRoot, gitExecutable: host.gitExecutable,
      gitSha256: f.gitSha256, source: f.source, runtime: f.runtime, attemptRoot: f.attemptRoot,
      afterCi: new Date(Date.now() - 60000).toISOString(),
      python: {schemaVersion: 2, root: host.pythonRoot, executable: binding(path.join(host.pythonRoot, 'python.exe')), files: regularMap(host.pythonRoot)},
      windows: {systemRoot: host.systemRoot, commandProcessor: binding(path.join(host.systemRoot, 'System32/cmd.exe')), java: null, firestoreJar: null},
      limits: {commandSeconds: 20, cleanupSeconds: 5, outputBytes: 1024 * 1024}};
    const collector = require('./collectBusinessRuntime31.cjs');
    const result = collector.preflightBusinessRuntime31(config);
    assert.deepEqual([...result.sourceBytes.keys()], Object.keys(result.snapshot.files).sort());
    for (const [name, bytes] of result.sourceBytes) assert.deepEqual(bytes, fs.readFileSync(path.join(f.repositoryRoot, name)), name);
    // Scalar/batch equivalence is established for every byte of the small
    // binary/empty/shared fixture above. Recheck two selected producer joins
    // here without repeating four Git launches for every preflight source file.
    for (const name of ['tools/release/collectBusinessRuntime31.cjs', 'tools/release/business31TrustedInput.cjs']) {
      assert.deepEqual(result.sourceBytes.get(name), result.repository.readBlob(f.source.commit, name), name);
    }
    assert.equal(fs.existsSync(f.attemptRoot), false, 'preflight must not launch runtime commands or create collection evidence');
    assert.equal(result.requiresEmulator, false); f.assertOriginalsUnchanged();
  });
