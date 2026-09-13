import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import Module, {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

// Actual filesystem bytes are measured. Only read-only Git observations and
// the --version child process are substituted; no install or Git mutation runs.
const require = createRequire(import.meta.url);
const collectorPath = fileURLToPath(new URL('./reviewedRulesRuntimeCollector.js', import.meta.url));
const collectorSource = fs.readFileSync(collectorPath, 'utf8');
const actual = require(collectorPath);
const commit = 'a'.repeat(40), tree = 'b'.repeat(40);
const sha = value => crypto.createHash('sha256').update(value).digest('hex').toUpperCase();
const write = (file, bytes) => { fs.mkdirSync(path.dirname(file), {recursive: true}); fs.writeFileSync(file, bytes); };
function temporary(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-runtime-collector-test-'));
  t.after(() => {
    const resolved = path.resolve(root), parent = path.resolve(os.tmpdir());
    assert.equal(path.dirname(resolved), parent);
    assert.ok(path.basename(resolved).startsWith('crm3-runtime-collector-test-'));
    fs.rmSync(resolved, {recursive: true, force: true});
  });
  return root;
}
function fixture(t) {
  const root = temporary(t), repoRoot = path.join(root, 'checkout');
  const inputs = {
    'tooling/firebase-cli/package.json': Buffer.from('{"dependencies":{"crm3_baf_ops":"file:../.."}}\n'),
    'tooling/firebase-cli/package-lock.json': Buffer.from('{"lockfileVersion":3}\n'),
    'tooling/firebase-cli/.npmrc': Buffer.from('install-links=true\n'),
  };
  for (const [file, bytes] of Object.entries(inputs)) write(path.join(repoRoot, file), bytes);
  const nodeExecutable = path.join(root, 'runtime', 'node.exe');
  const npmCliPath = path.join(root, 'runtime', 'npm', 'bin', 'npm-cli.js');
  write(nodeExecutable, 'actual fixture Node executable bytes');
  write(npmCliPath, 'require("../lib/cli.js");');
  write(path.join(root, 'runtime', 'npm', 'lib', 'cli.js'), 'module.exports = "fixture npm implementation";');
  write(path.join(root, 'runtime', 'npm', 'package.json'), '{"name":"npm","version":"10.9.2"}');
  const checkout = {commit, tree, originMain: commit, branch: 'main', governedWorktreeClean: true,
    materialChangeCount: 0, materialPathSha256: []};
  const state = {env: {}, checkout, inputs, version: 'v22.16.0\n', untracked: '', ignored: '', calls: [],
    fs: null, onExec: null, onCheckout: null, checkoutReads: 0};
  const loaded = new Module(collectorPath);
  loaded.filename = collectorPath;
  loaded.paths = Module._nodeModulePaths(path.dirname(collectorPath));
  loaded.require = spec => {
    if (spec === 'node:fs') return new Proxy(fs, {get: (target, key) => state.fs?.[key] ?? target[key]});
    if (spec === './collectFirestoreRulesIndexesReadback.js') return {collectSourceBinding: () => {
      state.checkoutReads++; state.onCheckout?.(state.checkoutReads); return structuredClone(state.checkout);
    }};
    if (spec === 'node:child_process') return {execFileSync: (executable, args, options) => {
      state.calls.push({executable, args, options});
      state.onExec?.(executable, args);
      if (executable === 'git') {
        assert.deepEqual(args.slice(0, 3), ['--no-replace-objects', '-C', repoRoot]);
        if (args[3] === 'rev-parse') return Buffer.from(tree + '\n');
        if (args[3] === 'show') {
          assert.ok(args[4].startsWith(commit + ':'));
          return Buffer.from(state.inputs[args[4].slice(41)]);
        }
        if (args[3] === 'ls-files') return Buffer.from(args.includes('--ignored') ? state.ignored : state.untracked);
        assert.fail('Unexpected Git operation');
      }
      assert.equal(executable, fs.realpathSync(nodeExecutable));
      assert.deepEqual(args, ['--no-global-search-paths', '--version']);
      assert.equal(options.windowsHide, true);
      return state.version;
    }};
    return require(spec);
  };
  // Each loaded module captures its own environment object; changes do not
  // alter the real test runner's environment or require global execution hooks.
  return {root, repoRoot, nodeExecutable, npmCliPath, inputs, state, load() {
    globalThis[Symbol.for('crm3.runtime.collector.fixture')] = {env: state.env};
    loaded._compile('const process = globalThis[Symbol.for("crm3.runtime.collector.fixture")];\n' + collectorSource, collectorPath);
    delete globalThis[Symbol.for('crm3.runtime.collector.fixture')];
    return loaded.exports;
  }, args: {repoRoot, sourceCommit: commit, sourceTree: tree, nodeExecutable, npmCliPath}, installTree() {
    const dir = path.join(repoRoot, 'tooling', 'firebase-cli', 'node_modules');
    write(path.join(dir, 'firebase-tools', 'lib', 'bin', 'firebase.js'), 'actual installed CLI bytes');
    write(path.join(dir, 'crm3_baf_ops', 'lib', 'copied-root.js'), 'local root package bytes');
    write(path.join(dir, '.bin', 'firebase.cmd'), 'windows shim bytes');
    return dir;
  }};
}
function orderedWindow(value) {
  assert.match(value.collectionStartedAtUtc, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
  assert.ok(Date.parse(value.collectionStartedAtUtc) <= Date.parse(value.capturedAtUtc));
  assert.ok(Date.parse(value.capturedAtUtc) <= Date.now());
}
function installedNpmFixture(f) {
  const container = path.join(f.root, 'runtime', 'node_modules');
  const npmCliPath = path.join(container, 'npm', 'bin', 'npm-cli.js');
  write(npmCliPath, 'require("../lib/cli.js");');
  write(path.join(container, 'npm', 'lib', 'cli.js'), 'npm implementation');
  write(path.join(container, 'npm', 'package.json'), '{"name":"npm","version":"10.9.2"}');
  write(path.join(container, 'corepack', 'dist', 'corepack.js'), 'sibling implementation');
  return {container, npmCliPath};
}

test('complete tree digest is deterministic across roots and creation order', t => {
  const root = temporary(t), a = path.join(root, 'a'), b = path.join(root, 'b');
  write(path.join(a, 'z', 'local.js'), 'local file bytes'); write(path.join(a, 'a.js'), 'alpha');
  write(path.join(b, 'a.js'), 'alpha'); write(path.join(b, 'z', 'local.js'), 'local file bytes');
  assert.deepEqual(actual.measureByteTree(a), actual.measureByteTree(b));
  assert.deepEqual(Object.keys(actual.measureByteTree(a)).sort(), ['byteCount', 'fileCount', 'sha256', 'symlinkCount']);
  assert.equal(actual.measureByteTree(a).fileCount, 2);
});
for (const change of ['bytes', 'extra file', 'rename', 'remove', 'empty directory']) {
  test(`complete tree commits ${change}`, t => {
    const root = temporary(t); write(path.join(root, 'file.js'), 'original');
    const before = actual.measureByteTree(root);
    if (change === 'bytes') write(path.join(root, 'file.js'), 'modified');
    if (change === 'extra file') write(path.join(root, 'extra.js'), 'extra');
    if (change === 'rename') fs.renameSync(path.join(root, 'file.js'), path.join(root, 'renamed.js'));
    if (change === 'remove') fs.unlinkSync(path.join(root, 'file.js'));
    if (change === 'empty directory') fs.mkdirSync(path.join(root, 'empty'));
    assert.notEqual(actual.measureByteTree(root).sha256, before.sha256);
  });
}
test('junction tree root and nested directory junction are rejected', t => {
  const root = temporary(t), target = path.join(root, 'target'); fs.mkdirSync(target);
  const linked = path.join(root, 'link'); fs.symlinkSync(target, linked, 'junction');
  assert.throws(() => actual.measureByteTree(linked), /real directory/);
  assert.throws(() => actual.measureByteTree(root), /only contained relative/);
});
for (const type of ['contained bin', 'outside bin', 'escaping bin', 'absolute bin']) {
  test(`file link policy: ${type}`, t => {
    const root = temporary(t), measured = path.join(root, 'tree');
    write(path.join(measured, 'pkg', 'cli.js'), 'cli'); write(path.join(root, 'outside.js'), 'outside');
    const linked = path.join(measured, type === 'outside bin' ? 'other' : '.bin', 'command');
    fs.mkdirSync(path.dirname(linked), {recursive: true});
    const target = type === 'escaping bin' ? '../../outside.js' : type === 'absolute bin'
      ? path.join(measured, 'pkg', 'cli.js') : '../pkg/cli.js';
    try { fs.symlinkSync(target, linked, 'file'); } catch (error) {
      if (process.platform === 'win32' && error.code === 'EPERM') { t.skip('Windows file symlink privilege unavailable'); return; }
      throw error;
    }
    if (type === 'contained bin') assert.equal(actual.measureByteTree(measured).symlinkCount, 1);
    else assert.throws(() => actual.measureByteTree(measured), /only contained relative/);
  });
}
test('source identity uses exact Git bytes and confirms local input bytes', t => {
  const f = fixture(t), api = f.load();
  assert.deepEqual(api.sourceIdentity(f.repoRoot, commit, tree, true), {
    commit, tree, cliPackageSha256: sha(f.inputs['tooling/firebase-cli/package.json']),
    cliLockSha256: sha(f.inputs['tooling/firebase-cli/package-lock.json']), npmrcSha256: sha(f.inputs['tooling/firebase-cli/.npmrc']),
  });
  write(path.join(f.repoRoot, 'tooling/firebase-cli/.npmrc'), 'install-links=false\n');
  assert.throws(() => api.sourceIdentity(f.repoRoot, commit, tree, true), /input bytes differ/);
});
test('fresh inputs carry timed exact checkout and path commitment without local path', t => {
  const f = fixture(t), result = f.load().inspectInstallInputs(f.args);
  orderedWindow(result); assert.equal(result.nodeModulesAbsent, true); assert.equal(result.untrackedInputsAbsent, true);
  assert.equal(result.source.executionRootSha256, sha(fs.realpathSync(f.repoRoot).replaceAll('\\', '/')));
  assert.equal(JSON.stringify(result).includes(f.repoRoot), false);
});
for (const kind of ['untracked', 'ignored']) {
  test(`fresh inputs reject ${kind} pack inputs`, t => {
    const f = fixture(t); f.state[kind] = 'unexpected.txt\0';
    assert.throws(() => f.load().inspectInstallInputs(f.args), /untracked or ignored/);
  });
}
for (const relative of ['tooling/firebase-cli/node_modules', 'tooling/node_modules', 'node_modules']) {
  test(`fresh inputs reject existing ${relative}`, t => {
    const f = fixture(t); fs.mkdirSync(path.join(f.repoRoot, relative), {recursive: true});
    assert.throws(() => f.load().inspectInstallInputs(f.args), /absent node_modules|unmeasured/);
  });
}
for (const code of ['EACCES', 'EPERM', 'ENOTDIR']) {
  test(`absence evidence never converts ${code} to missing`, t => {
    const f = fixture(t), blocked = path.join(f.repoRoot, 'tooling', 'node_modules');
    f.state.fs = {lstatSync(file, options) {
      if (file === blocked) throw Object.assign(new Error('denied fixture'), {code});
      return fs.lstatSync(file, options);
    }};
    assert.throws(() => f.load().inspectInstallInputs(f.args), error => error.code === code);
  });
}
for (const env of [{NODE_OPTIONS: ''}, {Node_Path: 'unmeasured'}]) {
  test(`rejects injected environment ${Object.keys(env)[0]}`, t => {
    const f = fixture(t); f.state.env = env;
    assert.throws(() => f.load().inspectInstallInputs(f.args), /injection environment/);
    assert.throws(() => f.load().measureRulesInstaller(f.args), /injection environment/);
  });
}
test('clean input inspection refuses checkout drift before returning evidence', t => {
  const f = fixture(t); f.state.onCheckout = count => { if (count === 2) f.state.checkout.branch = 'other'; };
  assert.throws(() => f.load().inspectInstallInputs(f.args), /exact clean main/);
});
test('installer independently measures exact Node and complete npm implementation', t => {
  const f = fixture(t), result = f.load().measureRulesInstaller(f.args);
  orderedWindow(result); assert.equal(result.schemaVersion, 1);
  assert.equal(result.node.sha256, sha(fs.readFileSync(f.nodeExecutable)));
  assert.equal(result.node.version, 'v22.16.0'); assert.equal(result.npm.version, '10.9.2');
  assert.equal(result.npm.treeScope, 'standalone-npm-package');
  assert.match(result.npm.treeRootPathSha256, /^[A-F0-9]{64}$/);
  assert.equal(result.npm.tree.fileCount, 3);
  assert.equal(JSON.stringify(result).includes(f.root), false);
  assert.equal(f.state.calls.length, 1);
});
test('conventional npm measures the complete installation container and sibling code changes', t => {
  const f = fixture(t), installation = installedNpmFixture(f), api = f.load();
  const args = {...f.args, npmCliPath: installation.npmCliPath};
  const before = api.measureRulesInstaller(args);
  assert.equal(before.npm.treeScope, 'installation-node-modules');
  assert.equal(before.npm.treeRootPathSha256, sha(fs.realpathSync(installation.container).replaceAll('\\', '/')));
  assert.deepEqual(before.npm.tree, actual.measureByteTree(installation.container));
  assert.equal(before.npm.tree.fileCount, 4);
  write(path.join(installation.container, 'corepack', 'dist', 'corepack.js'), 'changed sibling implementation');
  assert.notEqual(api.measureRulesInstaller(args).npm.tree.sha256, before.npm.tree.sha256);
});
test('conventional npm refuses unmeasured higher ancestor dependencies', t => {
  const f = fixture(t), installation = installedNpmFixture(f);
  write(path.join(f.root, 'node_modules', 'fallback', 'index.js'), 'higher ancestor fallback');
  assert.throws(() => f.load().measureRulesInstaller({...f.args, npmCliPath: installation.npmCliPath}), /npm ancestor node_modules/);
});
test('standalone npm refuses a containing lookup directory outside its measured package', t => {
  const f = fixture(t); write(path.join(f.root, 'runtime', 'node_modules', 'fallback', 'index.js'), 'outside npm');
  assert.throws(() => f.load().measureRulesInstaller(f.args), /npm ancestor node_modules/);
});
test('npm higher lookup permission errors cannot become absence', t => {
  const f = fixture(t), installation = installedNpmFixture(f);
  const denied = path.join(f.root, 'node_modules');
  f.state.fs = {lstatSync(file, options) {
    if (file === denied) throw Object.assign(new Error('denied npm lookup'), {code: 'EACCES'});
    return fs.lstatSync(file, options);
  }};
  assert.throws(() => f.load().measureRulesInstaller({...f.args, npmCliPath: installation.npmCliPath}), error => error.code === 'EACCES');
});
test('actual resolved Node launches with the guarded flag and measured executable bytes', t => {
  const f = fixture(t);
  // npm is a synthetic local package; it is measured but never executed.
  // The actual running Node executable and child --version invocation are real.
  const result = actual.measureRulesInstaller({nodeExecutable: process.execPath, npmCliPath: f.npmCliPath});
  const bytes = fs.readFileSync(fs.realpathSync(process.execPath));
  orderedWindow(result);
  assert.equal(result.node.sha256, sha(bytes));
  assert.equal(result.node.byteCount, bytes.length);
  assert.equal(result.node.version, process.version);
  assert.equal(result.npm.tree.fileCount, 3);
});
for (const version of ['v20.20.0\n', 'v22.11.0\n', 'v22.16.0-extra\n']) {
  test(`installer refuses unsupported or ambiguous Node ${version.trim()}`, t => {
    const f = fixture(t); f.state.version = version;
    assert.throws(() => f.load().measureRulesInstaller(f.args), /Node 22.12 or later/);
  });
}
test('installer detects Node changed during --version invocation', t => {
  const f = fixture(t); f.state.onExec = executable => {
    if (executable !== 'git') write(f.nodeExecutable, 'replaced binary');
  };
  assert.throws(() => f.load().measureRulesInstaller(f.args), /Node changed/);
});
test('installer refuses unresolved entry paths and fake npm identity', t => {
  const f = fixture(t), api = f.load();
  assert.throws(() => api.measureRulesInstaller({...f.args, nodeExecutable: 'node'}), /absolute Node/);
  write(path.join(path.dirname(path.dirname(f.npmCliPath)), 'package.json'), '{"name":"not-npm","version":"10.9.2"}');
  assert.throws(() => api.measureRulesInstaller(f.args), /npm package identity malformed/);
});
test('runtime includes copied local package bytes and stable identity only', t => {
  const f = fixture(t), directory = f.installTree(), api = f.load(), before = api.measureRulesRuntime(f.args);
  orderedWindow(before); assert.equal(before.schemaVersion, 1);
  assert.deepEqual(before.identity.installedTree, actual.measureByteTree(directory));
  assert.equal(before.identity.installedTree.fileCount, 3);
  assert.equal(before.identity.ancestorNodeModulesAbsent, true);
  assert.equal(before.identity.nodeOptionsAbsent, true); assert.equal(before.identity.nodePathAbsent, true);
  assert.deepEqual(Object.keys(before.identity).sort(), ['ancestorNodeModulesAbsent', 'installedTree', 'node', 'nodeOptionsAbsent', 'nodePathAbsent', 'npm', 'source']);
  write(path.join(directory, 'crm3_baf_ops', 'lib', 'copied-root.js'), 'changed local dependency');
  assert.notEqual(api.measureRulesRuntime(f.args).identity.installedTree.sha256, before.identity.installedTree.sha256);
});
test('runtime measurement refuses an npm implementation changed after initial measurement', t => {
  const f = fixture(t); f.installTree(); let versionCalls = 0;
  f.state.onExec = executable => {
    if (executable !== 'git' && ++versionCalls === 2) write(path.join(path.dirname(path.dirname(f.npmCliPath)), 'lib', 'cli.js'), 'replaced npm code');
  };
  assert.throws(() => f.load().measureRulesRuntime(f.args), /installer changed during runtime/);
});
test('full tree detects already-read file changed while a later file is read', t => {
  const f = fixture(t), directory = f.installTree(); let changed = false;
  const first = path.join(directory, '.bin', 'firebase.cmd');
  f.state.fs = {readFileSync(file, options) {
    const result = fs.readFileSync(file, options);
    if (!changed && file === path.join(directory, 'firebase-tools', 'lib', 'bin', 'firebase.js')) {
      changed = true; write(first, 'changed after prior read');
    }
    return result;
  }};
  assert.throws(() => f.load().measureByteTree(directory), /tree entry changed/);
});
test('full tree detects an extra file arriving during measurement', t => {
  const f = fixture(t), directory = f.installTree(); let changed = false;
  f.state.fs = {readFileSync(file, options) {
    const result = fs.readFileSync(file, options);
    if (!changed && file.startsWith(directory)) { changed = true; write(path.join(directory, 'injected.js'), 'late'); }
    return result;
  }};
  assert.throws(() => f.load().measureByteTree(directory), /directory changed/);
});
test('runtime rechecks exact checkout after all measurements', t => {
  const f = fixture(t); f.installTree();
  f.state.onCheckout = count => { if (count === 2) f.state.checkout.materialChangeCount = 1; };
  assert.throws(() => f.load().measureRulesRuntime(f.args), /exact clean main/);
});
for (const phase of ['second installer', 'final source observation']) {
  test(`runtime rejects installed CLI changed during ${phase}`, t => {
    const f = fixture(t), directory = f.installTree();
    const cliFile = path.join(directory, 'firebase-tools', 'lib', 'bin', 'firebase.js');
    const before = actual.measureByteTree(directory);
    let changed = false, versionCalls = 0;
    const mutate = () => { write(cliFile, 'altered CLI after initial installed-tree measurement'); changed = true; };
    if (phase === 'second installer') {
      f.state.onExec = executable => { if (executable !== 'git' && ++versionCalls === 2) mutate(); };
    } else {
      f.state.onCheckout = count => { if (count === 2) mutate(); };
    }
    assert.throws(() => f.load().measureRulesRuntime(f.args), /installed tree changed during runtime measurement/);
    assert.equal(changed, true);
    assert.notEqual(actual.measureByteTree(directory).sha256, before.sha256);
  });
}
