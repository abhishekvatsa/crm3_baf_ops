'use strict';
// Discovery only: invoke the installed, lock-selected Jest CLI directly. No npm
// scripts, test bodies, emulator, credential or network operation is invoked.
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const crypto = require('node:crypto'), {spawnSync} = require('node:child_process');
const projectRoot = path.resolve(__dirname, '../..');
const current = require(path.join(projectRoot, 'jest.config.js'));
const lock = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package-lock.json'), 'utf8'));
const nodeModules = path.resolve(process.env.BUSINESS31_TEST_JEST_NODE_MODULES || path.join(projectRoot, 'node_modules'));
const entry = path.join(nodeModules, 'jest/bin/jest.js');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const boundNames = ['jest/package.json', 'jest/bin/jest.js', 'jest-cli/package.json', 'jest-cli/build/index.js',
  'jest-config/package.json', 'jest-config/build/index.js', 'jest-util/package.json', 'jest-util/build/index.js'];
function bindings() {
  return Object.fromEntries(boundNames.map(name => {
    const file = path.join(nodeModules, name), stat = fs.lstatSync(file);
    assert.ok(stat.isFile() && !stat.isSymbolicLink(), 'regular selected Jest member: ' + name);
    return [name, sha(fs.readFileSync(file))];
  }));
}
const before = bindings();
for (const name of ['jest', 'jest-cli', 'jest-config', 'jest-util']) {
  const metadata = JSON.parse(fs.readFileSync(path.join(nodeModules, name, 'package.json'), 'utf8'));
  assert.equal(metadata.version, lock.packages['node_modules/' + name].version, 'selected package version: ' + name);
}
const temporary = fs.mkdtempSync(path.join(fs.realpathSync(os.tmpdir()), 'business31-jest-discovery-'));
process.stdout.write('Retained inert Jest discovery fixtures: ' + temporary + '\n');
// Exact old configuration values, whose byte preimage is retained with the
// source change. The old absolute glob is exercised by real Jest, not emulated.
const old = {testEnvironment: 'node', testTimeout: 60000, testMatch: ['<rootDir>/test/**/*.test.js']};
const expected = ['test/nested/child.test.js', 'test/root.test.js'];
const members = [...expected, 'functions/test/excluded.test.js', 'tools/test/excluded.test.js',
  'outside.test.js', 'test/not-a-test.js', 'test/only.spec.js'];
function create(label, parent) {
  const root = path.join(temporary, ...parent, label); fs.mkdirSync(root, {recursive: true});
  const marker = path.join(root, 'TEST_BODY_EXECUTED');
  const body = 'require("node:fs").writeFileSync(' + JSON.stringify(marker) + ', "unexpected body execution");\n' +
    'throw new Error("Discovery must not execute any test body");\n';
  for (const member of members) {
    const file = path.join(root, member); fs.mkdirSync(path.dirname(file), {recursive: true});
    fs.writeFileSync(file, body, {flag: 'wx'});
  }
  fs.writeFileSync(path.join(root, 'package.json'), JSON.stringify({name: 'inert-discovery-fixture', private: true}) + '\n', {flag: 'wx'});
  for (const [name, config] of [['old', old], ['fixed', current]]) {
    fs.writeFileSync(path.join(root, name + '.config.cjs'), 'module.exports = ' + JSON.stringify(config) + ';\n', {flag: 'wx'});
  }
  // import-local in the real Jest entry must not choose a different ancestor
  // installation. The fixture has no dependencies or module-search override.
  for (let directory = root; ; directory = path.dirname(directory)) {
    assert.equal(fs.existsSync(path.join(directory, 'node_modules/jest')), false, 'unselected ancestor Jest refused');
    if (path.dirname(directory) === directory) break;
  }
  return {root, marker};
}
function discover(fixture, kind) {
  const owned = path.join(fixture.root, '.discovery-' + kind), home = path.join(owned, 'home'), temp = path.join(owned, 'temp');
  fs.mkdirSync(home, {recursive: true}); fs.mkdirSync(temp);
  const environment = {CI: 'true', NODE_ENV: 'test', PATH: path.dirname(process.execPath), LANG: 'C', LC_ALL: 'C', TZ: 'UTC',
    HOME: home, USERPROFILE: home, APPDATA: home, LOCALAPPDATA: home, XDG_CONFIG_HOME: home,
    TEMP: temp, TMP: temp, TMPDIR: temp};
  for (const name of ['SystemRoot', 'WINDIR']) if (process.env[name] !== undefined) environment[name] = process.env[name];
  const argv = [entry, '--config', path.join(fixture.root, kind + '.config.cjs'), '--listTests', '--json',
    '--runInBand', '--no-cache', '--cacheDirectory', path.join(owned, 'cache')];
  const result = spawnSync(process.execPath, argv, {cwd: fixture.root, env: environment,
    shell: false, windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024});
  fs.writeFileSync(path.join(owned, 'stdout.bin'), result.stdout || Buffer.alloc(0), {flag: 'wx'});
  fs.writeFileSync(path.join(owned, 'stderr.bin'), result.stderr || Buffer.alloc(0), {flag: 'wx'});
  fs.writeFileSync(path.join(owned, 'RESULT.json'), JSON.stringify({executable: process.execPath, argv,
    cwd: fixture.root, environmentKeys: Object.keys(environment).sort(), status: result.status,
    signal: result.signal, error: result.error ? String(result.error) : null,
    stdoutSha256: sha(result.stdout || Buffer.alloc(0)), stderrSha256: sha(result.stderr || Buffer.alloc(0))}, null, 2) + '\n', {flag: 'wx'});
  assert.equal(fs.existsSync(fixture.marker), false, 'list-only discovery did not execute test bodies');
  assert.equal(result.error, undefined); assert.equal(result.signal, null);
  assert.equal(result.status, 0, (result.stderr || Buffer.alloc(0)).toString('utf8'));
  const paths = JSON.parse(result.stdout.toString('utf8'));
  assert.ok(Array.isArray(paths) && paths.every(file => typeof file === 'string' && path.isAbsolute(file)));
  const relative = paths.map(file => path.relative(fixture.root, file).split(path.sep).join('/')).sort();
  assert.equal(new Set(relative).size, relative.length);
  return relative;
}

test('root rules configuration preserves scope, environment and timeout', () => {
  assert.deepEqual(current, {testEnvironment: 'node', testTimeout: 60000,
    roots: ['<rootDir>/test'], testMatch: ['**/*.test.js']});
});
for (const [label, parent] of [['plain', ['plain-parent']], ['spaces', ['space parent']], ['dot-ancestor', ['.codex']]]) {
  test('actual native ' + process.platform + ' Jest discovery: ' + label, () => {
    const fixture = create(label, parent);
    const original = discover(fixture, 'old');
    assert.deepEqual(original, process.platform === 'win32' && label === 'dot-ancestor' ? [] : expected,
      'old Windows dot-ancestor failure or native-platform baseline');
    assert.deepEqual(discover(fixture, 'fixed'), expected,
      'only root and nested .test.js files, never Functions/tools/spec/non-test files');
    assert.deepEqual(bindings(), before, 'selected installed Jest code remains unchanged');
  });
}
test.after(() => {
  assert.deepEqual(bindings(), before);
  fs.writeFileSync(path.join(temporary, 'SELECTED_JEST_BINDINGS.json'), JSON.stringify({platform: process.platform,
    nodeModules, files: before, completeDependencyPopulationAuthenticated: false,
    scope: 'Actual native-platform discovery only; no POSIX execution is claimed on Windows and no test bodies/emulator ran.'}, null, 2) + '\n', {flag: 'wx'});
});
