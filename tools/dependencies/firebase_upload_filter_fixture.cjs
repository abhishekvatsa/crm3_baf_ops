'use strict';

// Offline test fixture for the exact pinned CLI component, not its entry point.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {createRequire} = require('node:module');

const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const FS_ASYNC_SHA256 = 'C8989264CFE50F902DFD1015A4C060FF36E114CBF24AC63DC5E254284A3AB3A2';
const PREPARE_SHA256 = 'DB73EEFA9DE70E77A0F8BB0F602E87E6A97C067FD8362F8931A54230803E07CB';

function loadPinnedFilter(cliRoot, minimatch, counts) {
  const cliRequire = createRequire(path.join(cliRoot, 'package.json'));
  assert.equal(cliRequire('firebase-tools/package.json').version, '15.22.4');
  const filename = cliRequire.resolve('firebase-tools/lib/fsAsync.js');
  const bytes = fs.readFileSync(filename);
  assert.equal(digest(bytes), FS_ASYNC_SHA256);
  assert.equal(typeof minimatch, 'function');
  const realFs = cliRequire('fs-extra');
  const allowed = new Map([
    ['fs-extra', {
      readdirSync(...args) {counts.readdir++; return realFs.readdirSync(...args);},
      statSync(...args) {counts.stat++; return realFs.statSync(...args);},
      readFileSync() {counts.contentReads++; throw new Error('File contents are outside this filter proof');},
    }],
    ['ignore', {default() {throw new Error('Gitignore handling is not selected');}}],
    ['lodash', cliRequire('lodash')],
    ['minimatch', minimatch],
    ['path', path],
    ['./logger', {logger: {debug() {throw new Error('Unexpected CLI logger call');}}}],
  ]);
  const module = {exports: {}};
  const component = new vm.Script(`(function(exports,require,module){${bytes.toString('utf8')}\n})`, {filename})
    .runInNewContext(Object.create(null), {timeout: 1000});
  component(module.exports, name => {
    assert.ok(allowed.has(name), `Unselected fsAsync dependency: ${name}`);
    return allowed.get(name);
  }, module);
  assert.equal(typeof module.exports.readdirRecursive, 'function');
  return module.exports.readdirRecursive;
}

function uploadIgnoreStrings(repositoryRoot, cliRoot) {
  const configuration = JSON.parse(fs.readFileSync(path.join(repositoryRoot, 'firebase.json'), 'utf8'));
  const selected = configuration.functions.find(entry => entry.source === 'functions' && entry.codebase === 'default');
  const configured = ['node_modules', '.git', 'firebase-debug.log', 'firebase-debug.*.log', '.env.demo-*', '*.local'];
  assert.deepEqual(selected.ignore, configured);
  const cliRequire = createRequire(path.join(cliRoot, 'package.json'));
  const bytes = fs.readFileSync(cliRequire.resolve('firebase-tools/lib/deploy/functions/prepareFunctionsUpload.js'));
  assert.equal(digest(bytes), PREPARE_SHA256);
  const source = bytes.toString('utf8');
  const match = /^const CONFIG_DEST_FILE = "([^"]+)";$/m.exec(source);
  assert.ok(match, 'Actual pinned prepare component must define CONFIG_DEST_FILE');
  assert.equal(match[1], '.runtimeconfig.json');
  assert.ok(source.includes('ignore.push("firebase-debug.log", "firebase-debug.*.log", CONFIG_DEST_FILE);'));
  assert.ok(source.includes('fsAsync.readdirRecursive({ path: sourceDir, ignoreStrings: ignore })'));
  // The two debug strings pushed by prepare are already in firebase.json.
  return [...configured, match[1]];
}

async function listNativeFiles(filter, directory, ignoreStrings) {
  const files = await filter({path: directory, ignoreStrings});
  // Preserve native absolute paths, modes and traversal order. No normalization
  // is applied before the old/new comparisons.
  return Array.from(files, file => ({name: file.name, mode: file.mode}));
}

module.exports = {loadPinnedFilter, uploadIgnoreStrings, listNativeFiles,
  FS_ASYNC_SHA256, PREPARE_SHA256};
