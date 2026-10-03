import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export const EXPECTED_FILES = Object.freeze({
  'index.js': '332ea07c7b006361aad12aa994ca75dc1db8e8382b884909e2f38f10b85c88a4',
  'LICENSE': '35bdd8a44339719441900fb50fbefc5e2dca1ca662cbaed7a687de842c8b70f2',
  'package.json': '7d74965c76cd3cb00f042e48d310409f30966d468d6d3a1e03e5f1494bbdc847',
  'lib/compile.js': '160de0ca6e58d82a7600055acd664a8732bcc0e65eaf00a00e9490d43d95a342',
  'lib/constants.js': 'f9fb688959232eee3e6ad7906a5b0e3234815db49ee857ef86983d65b917dc7c',
  'lib/expand.js': '18f1c70e36918f66457695187a43178a583650302150767654a0145d5fddd5fa',
  'lib/parse.js': '10fd6be4c5a092f8416bc7c5240aacc621ce71d76ead09c0e1d168022ff61bc8',
  'lib/stringify.js': '72cfac75fe36523a4e93555a413efd3fd5eca39e0bda90e521485b75bad1e68a',
  'lib/utils.js': 'b5a7596aa67730412b3c029ef09e84e6b67b8e445cffd35d1d295549c89066c7',
  'UPSTREAM_PROVENANCE.json': '4889f007adb0d781871a47321eed5931585d551b4a18a5c9195130d660a4e6cc',
});
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const inside = (base, target) => {
  const relative = path.relative(base, target);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
};

export function verifySource(packageDirectory) {
  const directory = fs.realpathSync(packageDirectory);
  for (const [relative, expected] of Object.entries(EXPECTED_FILES)) {
    const file = path.join(directory, relative);
    assert.ok(fs.lstatSync(file).isFile(), `Owned source must be a regular file: ${relative}`);
    assert.equal(sha(fs.readFileSync(file)), expected, `Owned source hash: ${relative}`);
  }
  const runtimeFiles = [];
  function walk(current, relative = '') {
    for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
      if (entry.name === 'node_modules') continue;
      const next = path.join(current, entry.name);
      const name = relative ? `${relative}/${entry.name}` : entry.name;
      assert.ok(!entry.isSymbolicLink(), `Unexpected source link: ${name}`);
      if (entry.isDirectory()) walk(next, name);
      else if (/\.(?:[cm]?js|json)$/.test(entry.name)) runtimeFiles.push(name);
    }
  }
  walk(directory);
  assert.deepEqual(runtimeFiles.sort(), Object.keys(EXPECTED_FILES).filter(x => x !== 'LICENSE').sort(), 'No unreviewed executable/package source');
  const metadata = readJson(path.join(directory, 'package.json'));
  assert.equal(metadata.name, '@crm3/braces-depth-guard');
  assert.equal(metadata.version, '1.0.0');
  assert.equal(metadata.private, true);
  return directory;
}

// Build a caller-supplied AST without using the guarded parser. Each invocation
// gets fresh objects because the released expand API mutates its AST.
export function nestedAst(depth) {
  const root = {type: 'root', nodes: []};
  let parent = root;
  for (let i = 0; i < depth; i++) {
    const child = {type: 'brace', nodes: [], parent, open: true, close: true, commas: 1, ranges: 0};
    parent.nodes.push(child);
    parent = child;
  }
  parent.nodes.push({type: 'text', value: 'a', parent});
  return root;
}

export function verifyDepthAndApi(entrypoint) {
  const require = createRequire(import.meta.url);
  const braces = require(entrypoint);
  const deep = n => '{'.repeat(n) + 'a,b' + '}'.repeat(n);
  const depthError = error => /depth/i.test(error.message) && !/call stack/i.test(error.message);
  for (const operation of ['parse', 'compile', 'expand', 'stringify']) {
    assert.equal(typeof braces[operation], 'function');
    for (const depth of [101, 1000, 4000, 4998]) assert.throws(() => braces[operation](deep(depth)), depthError);
    assert.throws(() => braces[operation]('('.repeat(101) + 'x' + ')'.repeat(101)), depthError);
    assert.doesNotThrow(() => braces[operation](deep(100)));
    for (const limit of [Infinity, NaN, 101, 10000, null, 'unlimited']) assert.throws(() => braces[operation](deep(101), {maxDepth: limit}), depthError);
    for (const limit of [0, 1, 1.5, 2.5]) assert.throws(() => braces[operation](deep(Math.floor(limit) + 1), {maxDepth: limit}), depthError);
    assert.throws(() => braces[operation]('literal', {maxDepth: -1}), /maxDepth must be non-negative/);
    assert.doesNotThrow(() => braces[operation]('literal', {maxDepth: 0}));
  }
  for (const operation of ['compile', 'expand', 'stringify']) {
    for (const depth of [101, 1000]) {
      assert.throws(() => braces[operation](nestedAst(depth)), depthError);
      const internal = require(path.join(path.dirname(entrypoint), 'lib', `${operation}.js`));
      assert.throws(() => internal(nestedAst(depth)), depthError);
    }
  }
  for (const fn of [braces, braces.create, input => braces(input, {expand: true})]) assert.throws(() => fn(deep(101)), depthError);
  assert.deepEqual(braces.expand('src/{alpha,beta}/**/*.js'), ['src/alpha/**/*.js', 'src/beta/**/*.js']);
  assert.deepEqual(braces(['a{b,c}', 'x{1..3}'], {expand: true}), ['ab', 'ac', 'x1', 'x2', 'x3']);
  assert.deepEqual(braces.expand('{a,a,,b}', {noempty: true, nodupes: true}), ['a', 'b']);
  assert.equal(braces.stringify('{{a}}', {escapeInvalid: true}), '{{a}}');
  assert.equal(braces.compile('a{b,c}d'), 'a(b|c)d');
  assert.equal(braces.stringify('a{b,c}d'), 'a{b,c}d');
  // These inherited short-input fast paths intentionally do not validate options.
  assert.deepEqual(braces('a', {maxDepth: -1}), ['a']);
  assert.deepEqual(braces.create('a', {maxDepth: -1}), ['a']);
}

export function verifyGraph(repository, directory) {
  const metadata = readJson(path.join(directory, 'package.json'));
  const lock = readJson(path.join(directory, 'package-lock.json'));
  assert.equal(metadata.overrides.braces, '$braces', 'Owned override is mandatory');
  const declared = metadata.devDependencies?.braces ?? metadata.dependencies?.braces;
  assert.ok(typeof declared === 'string' && declared.startsWith('file:'), 'Owned local dependency is mandatory');
  const direct = path.resolve(directory, declared.slice(5));
  assert.equal(fs.realpathSync(direct), fs.realpathSync(path.join(repository, 'tooling/braces-depth-guard')));
  const entries = Object.entries(lock.packages ?? {}).filter(([name, value]) => /(?:^|\/)node_modules\/braces$/.test(name) || value.name === 'braces' || value.name === '@crm3/braces-depth-guard');
  assert.ok(entries.length > 0, 'Lock must include owned braces resolution');
  for (const [name, value] of entries) {
    assert.ok(value.link === true || (value.name === '@crm3/braces-depth-guard' && value.version === '1.0.0'), `Unowned braces lock entry: ${name}`);
    const installed = path.resolve(directory, name);
    assert.ok(inside(repository, fs.realpathSync(installed)), 'Owned package must remain inside this repository/stage');
    verifySource(installed);
  }
}

export async function verifyWatcher(chokidar) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-braces-watch-'));
  assert.ok(inside(fs.realpathSync(os.tmpdir()), fs.realpathSync(temporary)));
  const events = [];
  let failure;
  // This is the pinned Firebase functions-emulator mixture, including the
  // **/ prefix used for configured ignores. The added brace ignore exercises
  // the existing glob capability instead of silently accepting chokidar 4.
  // The additional braced watch path exercises chokidar's own braces.expand call.
  const watcher = chokidar.watch([temporary, path.join(temporary, '{nested,other}')], {ignoreInitial: true, persistent: true, ignored: [
    /(^|[\/\\])\../, /.+\.log/, /.+?[\\/]node_modules[\\/].+?/, /.+?[\\/]venv[\\/].+?/,
    '**/skip-*', '**/*.{skip,tmp}',
  ]});
  watcher.on('all', (event, file) => events.push({event, file: path.relative(temporary, file).replaceAll('\\', '/')}));
  watcher.on('error', error => { failure = error; });
  const until = async (predicate, label) => {
    const expires = Date.now() + 5000;
    while (!predicate()) {
      if (failure) throw failure;
      assert.ok(Date.now() < expires, `Watcher timeout: ${label}`);
      await new Promise(resolve => setTimeout(resolve, 25));
    }
  };
  let ready = false;
  watcher.once('ready', () => { ready = true; });
  try {
    await until(() => ready, 'ready');
    fs.mkdirSync(path.join(temporary, 'nested'));
    const file = path.join(temporary, 'nested/keep.js');
    fs.writeFileSync(file, 'first');
    await until(() => events.some(x => x.event === 'add' && x.file === 'nested/keep.js'), 'add');
    fs.appendFileSync(file, 'second');
    await until(() => events.some(x => x.event === 'change' && x.file === 'nested/keep.js'), 'change');
    for (const name of ['skip-one.js', 'nested/hidden.skip', 'nested/hidden.tmp', 'nested/event.log', 'nested/.secret']) fs.writeFileSync(path.join(temporary, name), 'ignored');
    fs.unlinkSync(file);
    await until(() => events.some(x => x.event === 'unlink' && x.file === 'nested/keep.js'), 'unlink');
    await new Promise(resolve => setTimeout(resolve, 300));
    assert.deepEqual(events.filter(x => ['add', 'change', 'unlink'].includes(x.event) && x.file !== 'nested/keep.js'), [], 'Firebase ignore patterns must suppress ignored files');
    assert.ok(!failure);
  } finally {
    await watcher.close();
    assert.ok(inside(fs.realpathSync(os.tmpdir()), fs.realpathSync(temporary)));
    fs.rmSync(temporary, {recursive: true, force: true});
  }
}

export async function verifyInstalled(repository) {
  repository = fs.realpathSync(repository);
  verifySource(path.join(repository, 'tooling/braces-depth-guard'));
  const functions = path.join(repository, 'functions');
  const cli = path.join(repository, 'tooling/firebase-cli');
  verifyGraph(repository, functions);
  verifyGraph(repository, cli);
  const cliMetadata = readJson(path.join(cli, 'package.json'));
  assert.equal(cliMetadata.dependencies['firebase-tools'], '15.22.4');
  assert.equal(cliMetadata.overrides['basic-ftp'], '6.2.1');
  assert.equal(cliMetadata.overrides['@grpc/grpc-js'], '1.14.5');
  assert.equal(readJson(path.join(functions, 'package.json')).overrides['@grpc/grpc-js'], '1.14.5');
  const functionsRequire = createRequire(path.join(functions, 'package.json'));
  const cliRequire = createRequire(path.join(cli, 'package.json'));
  const firebaseFile = cliRequire.resolve('firebase-tools/package.json');
  assert.equal(readJson(firebaseFile).version, '15.22.4');
  const firebaseRequire = createRequire(firebaseFile);
  const micromatchFile = functionsRequire.resolve('micromatch/package.json');
  const chokidarFile = firebaseRequire.resolve('chokidar/package.json');
  assert.equal(readJson(micromatchFile).version, '4.0.8');
  assert.equal(readJson(chokidarFile).version, '3.6.0');
  for (const consumer of [micromatchFile, chokidarFile]) {
    const resolved = createRequire(consumer).resolve('braces');
    assert.ok(inside(repository, fs.realpathSync(resolved)));
    verifySource(path.dirname(resolved));
    const fillRange = createRequire(resolved).resolve('fill-range/package.json');
    assert.ok(inside(repository, fs.realpathSync(fillRange)), 'Owned runtime dependency must remain inside this repository/stage');
    assert.equal(readJson(fillRange).version, '7.1.1');
    const script = `import {verifyDepthAndApi} from ${JSON.stringify(import.meta.url)};verifyDepthAndApi(process.argv[1]);console.log('PASS_DEPTH_API');`;
    const output = execFileSync(process.execPath, ['--input-type=module', '-e', script, resolved], {encoding: 'utf8', timeout: 10000, windowsHide: true, maxBuffer: 1024 * 1024});
    assert.equal(output.trim(), 'PASS_DEPTH_API');
  }
  const micromatch = functionsRequire('micromatch');
  assert.deepEqual(micromatch(['src/a/x.js', 'src/b/y.js', 'src/c/z.js'], 'src/{a,b}/**/*.js'), ['src/a/x.js', 'src/b/y.js']);
  assert.deepEqual(micromatch.braces('src/{a,b}/**/*.js', {expand: true}), ['src/a/**/*.js', 'src/b/**/*.js']);
  assert.throws(() => micromatch.braces('{'.repeat(101) + 'a,b' + '}'.repeat(101)), /depth/);
  await verifyWatcher(firebaseRequire('chokidar'));
  return {status: 'passed installed source, bounded depth, micromatch and chokidar compatibility', npmAuditSubstitute: false};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const repository = process.argv[2] ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  console.log(JSON.stringify(await verifyInstalled(repository)));
}
