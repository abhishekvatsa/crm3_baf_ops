'use strict';
// Synthetic local bootstrap only: real Git archive and byte commitments, no
// workflow, network, private evidence, credential or operational authority.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync, spawnSync} = require('node:child_process');
const entry = path.join(__dirname, 'Initialize-Business31Controller.ps1');
const entryName = 'tools/release/Initialize-Business31Controller.ps1';
const payloadName = 'tools/release/selected-bootstrap-payload.cjs';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const gitExecutable = process.env.BUSINESS31_TEST_GIT ||
  (process.platform === 'win32' ? 'C:/Program Files/Git/mingw64/bin/git.exe' : '/usr/bin/git');
const pwsh = process.env.BUSINESS31_TEST_PWSH || 'pwsh';
let fixture, sequence = 0;
function makeFixture() {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-bootstrap-test-'));
  const root = path.join(temporary, 'repository'), template = path.join(temporary, 'empty-template');
  fs.mkdirSync(root); fs.mkdirSync(template);
  const env = {...process.env, GIT_CONFIG_NOSYSTEM: '1',
    GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
    GIT_TERMINAL_PROMPT: '0', GIT_NO_LAZY_FETCH: '1',
    GIT_AUTHOR_NAME: 'Synthetic bootstrap', GIT_AUTHOR_EMAIL: 'bootstrap@example.invalid',
    GIT_COMMITTER_NAME: 'Synthetic bootstrap', GIT_COMMITTER_EMAIL: 'bootstrap@example.invalid'};
  for (const name of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_CONFIG_COUNT', 'GIT_CONFIG_PARAMETERS',
    'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES']) delete env[name];
  function git(args, input) {
    return execFileSync(gitExecutable, ['-c', 'protocol.allow=never', '-c', 'credential.helper=',
      '-c', 'core.autocrlf=false', '-C', root, ...args], {env, input, encoding: 'utf8',
      timeout: 30000, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe']}).trim();
  }
  git(['init', '--initial-branch=main', '--template=' + template]);
  const files = {[entryName]: fs.readFileSync(entry),
    [payloadName]: Buffer.from('// Selected synthetic bytes; never executed.\n'),
    'unselected.txt': Buffer.from('This member must not be materialized.\n')};
  for (const [name, bytes] of Object.entries(files)) {
    const destination = path.join(root, ...name.split('/'));
    fs.mkdirSync(path.dirname(destination), {recursive: true}); fs.writeFileSync(destination, bytes);
  }
  git(['add', '--', ...Object.keys(files)]);
  const tree = git(['write-tree']), commit = git(['commit-tree', tree], 'Synthetic bootstrap source\n');
  const config = {schemaVersion: 1, profile: 'build31-business-prerequisite-controller-v1',
    replayTrust: {verifier: {commit, tree}}, controller: {
      nodeSha256: sha(fs.readFileSync(process.execPath)), gitSha256: sha(fs.readFileSync(gitExecutable)),
      files: {[entryName]: sha(files[entryName]), [payloadName]: sha(files[payloadName])}}};
  const configFile = path.join(root, '.git/config'), originalConfig = fs.readFileSync(configFile);
  // The initializer must read V, rather than copying ambient checkout contents.
  fs.writeFileSync(path.join(root, payloadName), 'Ambient uncommitted replacement.\n');
  process.stdout.write('Retained synthetic initializer fixture: ' + temporary + '\n');
  return {temporary, root, files, config, configFile, originalConfig};
}
test.before(() => {fixture = makeFixture();});
test.beforeEach(() => fs.writeFileSync(fixture.configFile, fixture.originalConfig));
function invoke(options = {}) {
  const dir = path.join(fixture.temporary, 'invocation-' + ++sequence); fs.mkdirSync(dir);
  const config = structuredClone(fixture.config); options.config?.(config);
  const configJson = JSON.stringify(config), data = {RepositoryRoot: options.repositoryRoot || fixture.root,
    ConfigJson: configJson, ConfigSha256: options.configSha256 || sha(Buffer.from(configJson))};
  if (options.locator !== undefined) data.PolicyRequestJson = options.locator;
  if (options.export) data.ExportGitHubEnvironment = true;
  fs.writeFileSync(path.join(dir, 'input.json'), JSON.stringify(data));
  const quote = value => "'" + value.replaceAll("'", "''") + "'";
  const script = path.join(dir, 'invoke.ps1');
  fs.writeFileSync(script, `Set-StrictMode -Version Latest\n$ErrorActionPreference = 'Stop'\n$p = Get-Content -LiteralPath ${quote(path.join(dir, 'input.json'))} -Raw | ConvertFrom-Json -AsHashtable -Depth 100\n& ${quote(entry)} @p | ConvertTo-Json -Depth 30 -Compress\n`);
  const env = {...process.env, PATH: [path.dirname(process.execPath), path.dirname(gitExecutable), process.env.PATH].join(path.delimiter),
    GITHUB_ACTIONS: options.actions ? 'true' : 'false', GITHUB_ENV: path.join(dir, 'github-env.txt')};
  fs.writeFileSync(env.GITHUB_ENV, 'PREEXISTING=value\n');
  for (const name of ['NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES']) delete env[name];
  const result = spawnSync(pwsh, ['-NoProfile', '-File', script], {env, encoding: 'utf8',
    windowsHide: true, timeout: 90000, maxBuffer: 2 * 1024 * 1024});
  fs.writeFileSync(path.join(dir, 'stdout.txt'), result.stdout || '');
  fs.writeFileSync(path.join(dir, 'stderr.txt'), result.stderr || '');
  assert.equal(result.error, undefined);
  return {...result, dir, configJson, environmentFile: env.GITHUB_ENV};
}
function refused(options, message) {
  const result = invoke(options);
  assert.notEqual(result.status, 0, 'Initializer must refuse this input');
  assert.match(result.stderr, message);
  assert.equal(fs.readFileSync(result.environmentFile, 'utf8'), 'PREEXISTING=value\n');
}
test('materializes only selected V bytes and preserves exact enrollment without executing the selected payload', () => {
  const result = invoke(); assert.equal(result.status, 0, result.stderr);
  const out = JSON.parse(result.stdout);
  assert.deepEqual(Object.keys(out).sort(), ['BUSINESS31_CONTROLLER_CONFIG', 'BUSINESS31_CONTROLLER_CONFIG_SHA256',
    'BUSINESS31_CONTROLLER_GIT', 'BUSINESS31_CONTROLLER_NODE', 'BUSINESS31_VERIFIER_ROOT']);
  assert.equal(fs.readFileSync(out.BUSINESS31_CONTROLLER_CONFIG, 'utf8'), result.configJson);
  assert.equal(sha(fs.readFileSync(out.BUSINESS31_CONTROLLER_CONFIG)), out.BUSINESS31_CONTROLLER_CONFIG_SHA256);
  assert.equal(fs.realpathSync(out.BUSINESS31_CONTROLLER_NODE), fs.realpathSync(process.execPath));
  assert.equal(fs.realpathSync(out.BUSINESS31_CONTROLLER_GIT), fs.realpathSync(gitExecutable));
  for (const name of [entryName, payloadName]) assert.deepEqual(fs.readFileSync(path.join(out.BUSINESS31_VERIFIER_ROOT, name)), fixture.files[name]);
  assert.equal(fs.existsSync(path.join(out.BUSINESS31_VERIFIER_ROOT, 'unselected.txt')), false);
});
test('exports an exact public schema2 locator only into the owned Actions environment file', () => {
  const locator = '{ "schemaVersion": 2, "syntheticPublicLocator": true }\n';
  const result = invoke({locator, export: true, actions: true}); assert.equal(result.status, 0, result.stderr);
  const out = JSON.parse(result.stdout);
  assert.equal(fs.readFileSync(out.BUSINESS31_POLICY_REQUEST, 'utf8'), locator);
  const lines = fs.readFileSync(result.environmentFile, 'utf8').trimEnd().split('\n');
  assert.equal(lines[0], 'PREEXISTING=value'); assert.equal(lines.length, 7);
  for (const [key, value] of Object.entries(out)) assert.ok(lines.includes(key + '=' + value));
});
test('rejects mismatched enrollment bytes and own source pin before materialization', () => {
  refused({configSha256: '0'.repeat(64)}, /Controller enrollment bytes differ/);
  refused({config: c => {c.controller.files[entryName] = '0'.repeat(64);}}, /Bootstrap source differs/);
});
test('rejects independently selected Node or Git runtime byte drift', () => {
  for (const name of ['nodeSha256', 'gitSha256']) refused({config: c => {c.controller[name] = '0'.repeat(64);}}, /Controller runtime differs/);
});
test('rejects wrong selected Git tree', () => {
  refused({config: c => {c.replayTrust.verifier.tree = '0'.repeat(40);}}, /Verifier Git identity differs/);
});
test('rejects absent and mismatched selected members', () => {
  refused({config: c => {c.controller.files[payloadName] = '0'.repeat(64);}}, /Verifier source member bytes differ/);
  refused({config: c => {c.controller.files['absent.cjs'] = 'A'.repeat(64);}}, /Verifier source member is absent or invalid/);
});
test('rejects path traversal and case-colliding selectors', () => {
  refused({config: c => {c.controller.files['../escape.cjs'] = 'A'.repeat(64);}}, /Verifier file selector is invalid/);
  refused({config: c => {c.controller.files[payloadName.toUpperCase()] = 'A'.repeat(64);}}, /Verifier file selector is invalid/);
});
test('rejects relative repository paths and shallow Git custody', () => {
  refused({repositoryRoot: '.'}, /Controller path must be absolute/);
  const marker = path.join(fixture.root, '.git/shallow'); fs.writeFileSync(marker, fixture.config.replayTrust.verifier.commit + '\n');
  try {refused({}, /complete self-contained Git custody/);} finally {fs.unlinkSync(marker);}
});
test('rejects included executable config and partial-clone declarations without contacting a remote', () => {
  for (const declaration of ['\n[include]\npath = absent-file\n', '\n[remote "synthetic"]\npromisor = true\n',
    '\n[extensions]\npartialClone = synthetic\n', '\n[remote "synthetic"]\npartialCloneFilter = blob:none\n']) {
    fs.writeFileSync(fixture.configFile, Buffer.concat([fixture.originalConfig, Buffer.from(declaration)]));
    refused({}, /External or executable Git configuration|partial|promisor/i);
  }
});
test('rejects a promisor pack marker even with a complete local object population', () => {
  const directory = path.join(fixture.root, '.git/objects/pack'); fs.mkdirSync(directory, {recursive: true});
  const marker = path.join(directory, 'pack-' + '0'.repeat(40) + '.promisor'); fs.writeFileSync(marker, '');
  try {refused({}, /promisor|partial/i);} finally {fs.unlinkSync(marker);}
});
test('rejects obsolete or oversized locator and refuses Actions export outside Actions', () => {
  refused({locator: '{"schemaVersion":1}'}, /challenged policy result locator/);
  refused({locator: JSON.stringify({schemaVersion: 2, excess: 'x'.repeat(131072)})}, /exceeds its bound/);
  refused({export: true}, /GitHub environment export requires Actions/);
});
