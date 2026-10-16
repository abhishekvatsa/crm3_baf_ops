import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const cliRequire = createRequire(path.join(root, 'tooling/firebase-cli/package.json'));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const adapters = [
  {module: 'stream-json', file: 'index.cjs', named: 'parser'},
  {module: 'stream-json/filters/Pick', file: 'filters/Pick.cjs', named: 'pick'},
  {module: 'stream-json/filters/Filter', file: 'filters/Filter.cjs', named: 'filter'},
  {module: 'stream-json/streamers/StreamArray', file: 'streamers/StreamArray.cjs', named: 'streamArray'},
  {module: 'stream-json/streamers/StreamObject', file: 'streamers/StreamObject.cjs', named: 'streamObject'},
];
const factories = adapters.flatMap(adapter => [
  {module: adapter.module, key: null},
  {module: adapter.module, key: adapter.named},
  ...(adapter.named === 'parser' ? [] : [{module: adapter.module, key: 'withParser'}]),
]);

function scan(directory) {
  const files = {};
  const walk = current => {
    for (const entry of fs.readdirSync(current, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
      const file = path.join(current, entry.name);
      const stat = fs.lstatSync(file);
      assert.equal(stat.isSymbolicLink(), false, 'fixture populations cannot contain redirects');
      if (stat.isDirectory()) walk(file);
      else {
        assert.equal(stat.isFile(), true);
        files[path.relative(directory, file).split(path.sep).join('/')] = hash(fs.readFileSync(file));
      }
    }
  };
  walk(directory);
  return files;
}

function copyRegularTree(source, destination) {
  fs.mkdirSync(destination);
  for (const entry of fs.readdirSync(source, {withFileTypes: true})) {
    const input = path.join(source, entry.name);
    const output = path.join(destination, entry.name);
    const stat = fs.lstatSync(input);
    assert.equal(stat.isSymbolicLink(), false, 'upstream fixture must use regular source files');
    if (stat.isDirectory()) copyRegularTree(input, output);
    else {
      assert.equal(stat.isFile(), true);
      fs.copyFileSync(input, output, fs.constants.COPYFILE_EXCL);
    }
  }
}

// Serialized into a private, hash-bound component suite. It has no closure over
// the test runner, installed modules, ambient credentials, or production data.
function guardedCase() {
  const assert = require('node:assert/strict');
  const fs = require('node:fs');
  const path = require('node:path');
  const Module = require('node:module');
  const cp = require('node:child_process');
  const denied = [];
  const deny = name => function forbiddenExternalCall() {
    denied.push(name);
    throw Error('OFFLINE_ADAPTER_EXTERNAL_ACCESS: ' + name);
  };
  for (const name of ['exec', 'execSync', 'execFile', 'execFileSync', 'spawn', 'spawnSync', 'fork']) {
    cp[name] = deny('child_process.' + name);
  }
  for (const name of ['node:http', 'node:https']) {
    const api = require(name);
    api.request = deny(name + '.request');
    api.get = deny(name + '.get');
  }
  const net = require('node:net');
  net.Socket.prototype.connect = deny('net.Socket.connect');
  net.connect = net.createConnection = deny('net.connect');
  require('node:tls').connect = deny('tls.connect');
  for (const name of ['lookup', 'lookupService', 'resolve', 'resolve4', 'resolve6', 'reverse']) {
    require('node:dns')[name] = deny('dns.' + name);
    require('node:dns').promises[name] = deny('dns.promises.' + name);
  }
  require('node:dgram').createSocket = deny('dgram.createSocket');
  require('node:http2').connect = deny('http2.connect');
  require('node:worker_threads').Worker = deny('worker_threads.Worker');
  globalThis.fetch = deny('fetch');
  if ('WebSocket' in globalThis) globalThis.WebSocket = deny('WebSocket');
  Module.syncBuiltinESMExports();

  const bootstrap = require('./business31CaptureBootstrap.cjs');
  assert.equal(bootstrap.isComponentChild31('capture-pins'), true);
  assert.throws(() => bootstrap.assertOperational31(), /cannot authorize operational dispatch/);
  const lease = bootstrap.installCliLoadBoundary31(runtime);
  const fixtureRequire = Module.createRequire(runtime.cliEntrypoint);
  const loaded = new Map();
  let refusal = null;
  try {
    for (const adapter of adapterCases) {
      const value = fixtureRequire(adapter.module);
      assert.equal(typeof value, 'function');
      assert.equal(value.length, 1);
      assert.equal(typeof value[adapter.named], 'function');
      assert.equal(value[adapter.named].length, 1);
      assert.notEqual(value, value[adapter.named], 'default and named factories remain distinct functions');
      const keys = adapter.named === 'parser' ? [adapter.named] : [adapter.named, 'withParser'];
      assert.deepEqual(Object.keys(value), keys);
      if (adapter.named !== 'parser') assert.equal(value.withParser.length, 1);
      loaded.set(adapter.module, value);
    }
    // A swallowed optional ESM load would leave this real guard failed.
    lease.assertHealthy();
    assert.equal(Object.keys(require.cache).some(file =>
      file.startsWith(path.join(cliPopulation, 'stream-json-modern') + path.sep)), false);
    if (factoryCase !== null) {
      const value = loaded.get(factoryCase.module);
      const factory = factoryCase.key === null ? value : value[factoryCase.key];
      assert.throws(() => factory(Object.freeze({})), error => {
        assert.equal(error.code, 'BUSINESS_CLI_LOAD_INTEGRITY');
        assert.match(error.message, /unsupported module format(?:\/import)?/);
        refusal = {code: error.code, message: error.message};
        return true;
      });
      assert.throws(() => lease.assertHealthy(), {code: 'BUSINESS_CLI_LOAD_INTEGRITY'});
    }
    assert.deepEqual(denied, [], 'no external call may be swallowed as an optional dependency failure');
  } finally {
    if (!lease.isReleased()) lease.release();
  }
  process.stdout.write(JSON.stringify({
    mode: factoryCase === null ? 'cold-import' : 'factory-refused',
    importedAdapters: loaded.size,
    factory: factoryCase,
    refusal,
    deniedCalls: denied.length,
    operationalAuthority: false,
  }) + '\n');
}

test('five JSON adapters cold-import and all 14 factories retain strict format refusal', () => {
  const scratch = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'crm3-json-guard-'));
  try {
    const cliPopulation = path.join(scratch, 'cli', 'node_modules');
    fs.mkdirSync(cliPopulation, {recursive: true});
    const adapterRoot = path.join(cliPopulation, 'stream-json');
    fs.mkdirSync(adapterRoot);
    for (const file of ['package.json', ...adapters.map(adapter => adapter.file)]) {
      const input = path.join(root, 'tooling/stream-json-compat', file);
      assert.equal(fs.lstatSync(input).isFile(), true);
      const output = path.join(adapterRoot, file);
      fs.mkdirSync(path.dirname(output), {recursive: true});
      fs.copyFileSync(input, output, fs.constants.COPYFILE_EXCL);
    }
    const modernEntry = fs.realpathSync(cliRequire.resolve('stream-json-modern'));
    const modernRoot = path.resolve(path.dirname(modernEntry), '..');
    const modernPackage = JSON.parse(fs.readFileSync(path.join(modernRoot, 'package.json'), 'utf8'));
    assert.equal(modernPackage.name, 'stream-json');
    assert.equal(modernPackage.version, '3.6.0');
    assert.equal(modernPackage.type, 'module');
    const upstreamBefore = scan(modernRoot);
    const upstreamCopy = path.join(cliPopulation, 'stream-json-modern');
    copyRegularTree(modernRoot, upstreamCopy);
    assert.deepEqual(scan(upstreamCopy), upstreamBefore);
    const entry = path.join(cliPopulation, 'firebase-tools', 'lib', 'bin', 'firebase.js');
    fs.mkdirSync(path.dirname(entry), {recursive: true});
    fs.writeFileSync(entry, 'throw Error("ADAPTER_FIXTURE_MUST_NOT_RUN_CLI");\n', {flag: 'wx'});
    const cliFiles = scan(cliPopulation);
    const mapPath = path.join(scratch, 'cli-map.json');
    const mapBytes = Buffer.from(JSON.stringify(cliFiles));
    fs.writeFileSync(mapPath, mapBytes, {flag: 'wx'});
    const runtime = {cliEntrypoint: entry, cliFileBindings: {path: mapPath, sha256: hash(mapBytes)}};
    const bootstrapInput = path.join(root, 'tools/release/business31CaptureBootstrap.cjs');
    const bootstrapBytes = fs.readFileSync(bootstrapInput);
    const nodeSha256 = hash(fs.readFileSync(process.execPath));

    function run(factoryCase, ordinal) {
      const directory = path.join(scratch, 'case-' + ordinal);
      const tools = path.join(directory, 'tools');
      const profile = path.join(directory, 'profile');
      fs.mkdirSync(tools, {recursive: true});
      fs.mkdirSync(profile);
      const bootstrapFile = path.join(tools, 'business31CaptureBootstrap.cjs');
      fs.writeFileSync(bootstrapFile, bootstrapBytes, {flag: 'wx'});
      assert.equal(hash(fs.readFileSync(bootstrapFile)), hash(bootstrapBytes));
      // Reuse only the fixed non-operational component dispatch. This private
      // suite is not the repository's capture-pins test or a deployment proof.
      const suite = 'const runtime = ' + JSON.stringify(runtime) + ';\n' +
        'const cliPopulation = ' + JSON.stringify(cliPopulation) + ';\n' +
        'const adapterCases = ' + JSON.stringify(adapters) + ';\n' +
        'const factoryCase = ' + JSON.stringify(factoryCase) + ';\n' +
        '(' + guardedCase.toString() + ')();\n';
      fs.writeFileSync(path.join(tools, 'business31CapturePins.test.cjs'), suite, {flag: 'wx'});
      const request = {
        schemaVersion: 1, operation: 'component-test', suite: 'capture-pins', caseId: null,
        componentData: null, sourceRoot: tools, sourceFiles: scan(tools),
        nodeExecutable: fs.realpathSync(process.execPath), nodeSha256,
        gitExecutable: null, nonOperational: true,
      };
      const requestBytes = Buffer.from(JSON.stringify(request));
      const requestPath = path.join(directory, 'REQUEST.json');
      fs.writeFileSync(requestPath, requestBytes, {flag: 'wx'});
      const env = {PATH: path.dirname(process.execPath), CI: 'true', NO_COLOR: '1',
        FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true'};
      for (const key of ['SystemRoot', 'WINDIR']) if (process.env[key] !== undefined) env[key] = process.env[key];
      for (const key of ['HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'TEMP', 'TMP']) {
        const value = path.join(profile, key);
        fs.mkdirSync(value);
        env[key] = value;
      }
      const argv = [bootstrapFile, '--component-child', requestPath, hash(requestBytes)];
      fs.writeFileSync(path.join(directory, 'ENVIRONMENT.json'), JSON.stringify(env, null, 2) + '\n', {flag: 'wx'});
      const startedAtUtc = new Date().toISOString();
      const child = spawnSync(process.execPath, argv, {
        cwd: directory, env, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
        timeout: 60000, maxBuffer: 1024 * 1024,
      });
      const completedAtUtc = new Date().toISOString();
      const retainedStreams = {};
      for (const stream of ['stdout', 'stderr']) {
        const bytes = child[stream] ?? Buffer.alloc(0);
        const file = path.join(directory, stream + '.bin');
        fs.writeFileSync(file, bytes, {flag: 'wx'});
        retainedStreams[stream] = {path: file, sha256: hash(bytes), bytes: bytes.length};
      }
      fs.writeFileSync(path.join(directory, 'RESULT.json'), JSON.stringify({
        startedAtUtc, completedAtUtc, executable: process.execPath, arguments: argv,
        cwd: directory, environment: env, stdin: 'closed', timeoutMilliseconds: 60000,
        maxBufferBytes: 1024 * 1024, pid: child.pid ?? null, status: child.status,
        signal: child.signal, error: child.error ? {
          name: child.error.name, code: child.error.code ?? null, message: child.error.message,
        } : null, streams: retainedStreams, fixtureOnly: true, operationalAuthority: false,
      }, null, 2) + '\n', {flag: 'wx'});
      assert.equal(child.error, undefined);
      assert.equal(child.signal, null);
      assert.equal(child.status, 0, child.stderr.toString('utf8'));
      const observation = JSON.parse(child.stdout.toString('utf8').trim());
      assert.equal(observation.importedAdapters, 5);
      assert.equal(observation.mode, factoryCase === null ? 'cold-import' : 'factory-refused');
      assert.deepEqual(observation.factory, factoryCase);
      assert.equal(observation.deniedCalls, 0);
      assert.equal(observation.operationalAuthority, false);
      if (factoryCase === null) assert.equal(observation.refusal, null);
      else assert.equal(observation.refusal.code, 'BUSINESS_CLI_LOAD_INTEGRITY');
      return observation;
    }

    run(null, 0);
    for (const [index, factory] of factories.entries()) run(factory, index + 1);
    assert.equal(factories.length, 14);
    assert.deepEqual(scan(cliPopulation), cliFiles);
    assert.deepEqual(scan(modernRoot), upstreamBefore);
    assert.equal(hash(fs.readFileSync(bootstrapInput)), hash(bootstrapBytes));
    fs.writeFileSync(path.join(scratch, 'COMPLETE.json'), JSON.stringify({
      completedAtUtc: new Date().toISOString(), fixtureOnly: true, coldImports: 5,
      refusedFactories: factories.length, processCases: factories.length + 1,
      operationalAuthority: false,
    }, null, 2) + '\n', {flag: 'wx'});
  } catch (error) {
    fs.writeFileSync(path.join(scratch, 'FAILURE.json'), JSON.stringify({
      recordedAtUtc: new Date().toISOString(), name: error.name, message: error.message,
      stack: error.stack, fixtureOnly: true, operationalAuthority: false,
    }, null, 2) + '\n', {flag: 'wx'});
    throw error;
  } finally {
    // Retain requests and returned bytes on success and failure. The caller can
    // preserve a failed case before diagnosis; this test never deletes them.
    process.stderr.write('Adapter guard fixture evidence retained: ' + scratch + '\n');
  }
});
