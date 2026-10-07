import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {execFileSync, spawnSync} from 'node:child_process';
import {verifySource, verifyGraph, verifyInstalled, verifyWatcher, EXPECTED_FILES} from './verify_braces_depth_guard.mjs';

const source = process.env.CRM3_BRACES_GUARD_TEST_SOURCE ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../tooling/braces-depth-guard');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-braces-guard-test-'));
  t.after(() => {
    assert.equal(path.dirname(root), fs.realpathSync(os.tmpdir()));
    fs.rmSync(root, {recursive: true, force: true});
  });
  const vendor = path.join(root, 'tooling/braces-depth-guard');
  fs.mkdirSync(vendor, {recursive: true});
  for (const name of Object.keys(EXPECTED_FILES)) {
    const destination = path.join(vendor, name);
    fs.mkdirSync(path.dirname(destination), {recursive: true});
    fs.copyFileSync(path.join(source, name), destination);
  }
  return {root, vendor};
}
function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  fs.writeFileSync(file, JSON.stringify(value));
}
function graph(root, relative, dependencyPath) {
  const directory = path.join(root, relative);
  writeJson(path.join(directory, 'package.json'), {name: 'fixture', dependencies: {braces: `file:${dependencyPath}`, 'firebase-tools':'15.22.4'}, overrides: {braces: '$braces', 'basic-ftp':'6.2.1', '@grpc/grpc-js':'1.14.5'}});
  fs.cpSync(path.join(root, 'tooling/braces-depth-guard'), path.join(directory, 'node_modules/braces'), {recursive: true});
  writeJson(path.join(directory, 'package-lock.json'), {packages: {'node_modules/braces': {name: '@crm3/braces-depth-guard', version: '1.0.0'}}});
  return directory;
}

test('exact reviewed source is admitted', t => {const f = fixture(t); assert.equal(verifySource(f.vendor), fs.realpathSync(f.vendor));});
for (const file of ['lib/parse.js', 'lib/compile.js', 'lib/expand.js', 'lib/stringify.js', 'lib/utils.js', 'lib/constants.js', 'index.js']) {
  test(`tampered runtime file rejected: ${file}`, t => {const f = fixture(t); fs.appendFileSync(path.join(f.vendor, file), '\n// tampered\n'); assert.throws(() => verifySource(f.vendor), /Owned source hash/);});
}
test('owned identity cannot be relabelled upstream', t => {const f = fixture(t); const file = path.join(f.vendor, 'package.json'); const p = JSON.parse(fs.readFileSync(file)); p.name = 'braces'; p.version = '3.0.4'; writeJson(file, p); assert.throws(() => verifySource(f.vendor), /Owned source hash/);});
test('unreviewed nested executable is refused', t => {const f = fixture(t); fs.writeFileSync(path.join(f.vendor, 'lib/extra.cjs'), 'module.exports=1;'); assert.throws(() => verifySource(f.vendor), /No unreviewed/);});
test('provenance cannot be changed independently', t => {const f = fixture(t); fs.appendFileSync(path.join(f.vendor, 'UPSTREAM_PROVENANCE.json'), ' '); assert.throws(() => verifySource(f.vendor), /Owned source hash/);});
test('nested vulnerable braces lock copy is refused', t => {
  const f = fixture(t); const directory = graph(f.root, 'functions', '../tooling/braces-depth-guard');
  const file = path.join(directory, 'package-lock.json'); const lock = JSON.parse(fs.readFileSync(file));
  lock.packages['node_modules/other/node_modules/braces'] = {version: '3.0.3'};
  writeJson(file, lock); assert.throws(() => verifyGraph(f.root, directory), /Unowned braces lock entry/);
});
test('locked owned name cannot hide wrong installed bytes', t => {
  const f = fixture(t); const directory = graph(f.root, 'functions', '../tooling/braces-depth-guard');
  fs.appendFileSync(path.join(directory, 'node_modules/braces/lib/parse.js'), '//bad');
  assert.throws(() => verifyGraph(f.root, directory), /Owned source hash/);
});
test('actual consumer resolving an unowned nested copy is refused before behavior execution', async t => {
  const f = fixture(t); const functions = graph(f.root, 'functions', '../tooling/braces-depth-guard');
  const cli = graph(f.root, 'tooling/firebase-cli', '../braces-depth-guard');
  const micromatch = path.join(functions, 'node_modules/micromatch');
  writeJson(path.join(micromatch, 'package.json'), {name:'micromatch',version:'4.0.8'});
  writeJson(path.join(cli, 'node_modules/firebase-tools/package.json'), {name:'firebase-tools',version:'15.22.4'});
  writeJson(path.join(cli, 'node_modules/chokidar/package.json'), {name:'chokidar',version:'3.6.0'});
  const bad = path.join(micromatch, 'node_modules/braces');
  writeJson(path.join(bad, 'package.json'), {name:'braces',version:'3.0.3',main:'index.js'});
  fs.writeFileSync(path.join(bad, 'index.js'), 'throw new Error("must not execute unverified package");');
  await assert.rejects(verifyInstalled(f.root), /Owned source hash|ENOENT/);
});
test('public and internal walkers have bounded depth and preserve normal API behavior', () => {
  const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const functionsRequire = createRequire(path.join(repository, 'functions/package.json'));
  const consumer = functionsRequire.resolve('micromatch/package.json');
  const installedEntry = createRequire(consumer).resolve('braces');
  verifySource(path.dirname(installedEntry));
  const moduleUrl = new URL('./verify_braces_depth_guard.mjs', import.meta.url).href;
  const expression = `import {verifyDepthAndApi} from ${JSON.stringify(moduleUrl)};verifyDepthAndApi(process.argv[1]);console.log('PASS_DEPTH_API');`;
  const output = execFileSync(process.execPath, ['--input-type=module','-e',expression,installedEntry], {encoding:'utf8',timeout:10000,windowsHide:true,maxBuffer:1024*1024});
  assert.equal(output.trim(),'PASS_DEPTH_API');
});


test('public compile AST overload returns exact escaped values without stdout or stderr', () => {
  const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
  const functionsRequire = createRequire(path.join(repository, 'functions/package.json'));
  const consumer = functionsRequire.resolve('micromatch/package.json');
  const installedEntry = createRequire(consumer).resolve('braces');
  verifySource(path.dirname(installedEntry));
  const expression = "const b=require(process.argv[1]);process.stdout.write(JSON.stringify([b.compile({type:'close',isClose:true,value:'}'}),b.compile({type:'close',isClose:true,value:'}'},{escapeInvalid:true})]));";
  const result = spawnSync(process.execPath, ['-e', expression, installedEntry], {
    encoding: 'utf8', timeout: 10000, windowsHide: true, maxBuffer: 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0);
  assert.equal(result.stderr, '');
  assert.equal(result.stdout, JSON.stringify(['}', '\\}']));
});

for (const ancestor of ['ordinary', '.hidden', 'runner.log', 'node_modules/runner']) {
  test(`real watcher preserves events and ignores beneath ${ancestor}`, {timeout: 20000}, async t => {
    const f = fixture(t);
    const parent = path.join(f.root, ancestor);
    fs.mkdirSync(parent, {recursive: true});
    const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
    const cliRequire = createRequire(path.join(repository, 'tooling/firebase-cli/package.json'));
    const firebaseRequire = createRequire(cliRequire.resolve('firebase-tools/package.json'));
    const chokidarFile = firebaseRequire.resolve('chokidar/package.json');
    assert.equal(JSON.parse(fs.readFileSync(chokidarFile, 'utf8')).version, '3.6.0');
    const chokidar = firebaseRequire('chokidar');
    let watchCalls = 0;
    await verifyWatcher({watch(paths, options) {
      watchCalls++;
      assert.equal(path.dirname(fs.realpathSync(paths[0])), fs.realpathSync(parent),
        'Regression must exercise the requested ancestor');
      return chokidar.watch(paths, options);
    }}, parent);
    assert.equal(watchCalls, 1);
    assert.deepEqual(fs.readdirSync(parent), [], 'Watcher fixture must be cleaned after close');
  });
}
