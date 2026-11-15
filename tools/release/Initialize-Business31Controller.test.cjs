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
const yaml = require('js-yaml');
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

function selectTransportV2(c) {
  c.schemaVersion=2; c.profile='build31-business-prerequisite-controller-v2';
  Object.assign(c.replayTrust,{schemaVersion:2,profile:'build31-business-hosted-recorded-replay-v2',
    source:{commit:'1'.repeat(40),tree:'2'.repeat(40)},coreVerifier:{commit:'1'.repeat(40),tree:'2'.repeat(40),files:{}}});
}
test('v2 bootstrap preserves separately enrolled outer and recorded verifier identities',()=>{
  const result=invoke({config:selectTransportV2});assert.equal(result.status,0,result.stderr);
  const out=JSON.parse(result.stdout),saved=JSON.parse(fs.readFileSync(out.BUSINESS31_CONTROLLER_CONFIG,'utf8'));
  assert.equal(saved.replayTrust.coreVerifier.commit,'1'.repeat(40));
  assert.equal(saved.replayTrust.verifier.commit,fixture.config.replayTrust.verifier.commit);
  assert.notEqual(saved.replayTrust.coreVerifier.commit,saved.replayTrust.verifier.commit);
});
for(const [label,change]of[
 ['mixed controller profile',c=>{c.profile='build31-business-prerequisite-controller-v1';}],
 ['legacy trust in v2',c=>{c.replayTrust.schemaVersion=1;}],
 ['recorded source changed',c=>{c.replayTrust.coreVerifier.commit='3'.repeat(40);}]
])test('v2 bootstrap refuses '+label,()=>refused({config:c=>{selectTransportV2(c);change(c);}},/unsupported|selection differs/));

test('legacy bootstrap rejects successor trust even before full controller admission',()=>{
 refused({config:c=>{selectTransportV2(c);c.schemaVersion=1;c.profile='build31-business-prerequisite-controller-v1';}},/Legacy controller enrollment/);
});

// Execute the checked-in workflow step, rather than a rewritten decoder or a
// regex asserting that it contains a hash call. All child work stays in the
// existing synthetic Git fixture and uses the actual pinned initializer.
function workflowBootstrap(name) {
  const file = path.resolve(__dirname, '../../.github/workflows', name);
  const parsed = yaml.load(fs.readFileSync(file, 'utf8'), {schema: yaml.JSON_SCHEMA});
  const steps = Object.values(parsed.jobs).flatMap(job => job.steps || []).filter(step =>
    step.name === 'Prepare independently enrolled business verifier');
  assert.equal(steps.length, 1, 'Exactly one public enrollment bootstrap');
  assert.equal(steps[0].shell, 'pwsh');
  for (const [alias, variable] of [['BUSINESS31_CONFIG_JSON', 'BUSINESS31_CONTROLLER_CONFIG_JSON'],
    ['BUSINESS31_CONFIG_JSON_PART_2', 'BUSINESS31_CONTROLLER_CONFIG_JSON_PART_2'],
    ['BUSINESS31_CONFIG_JSON_PART_3', 'BUSINESS31_CONTROLLER_CONFIG_JSON_PART_3']])
    assert.equal(steps[0].env[alias], '${{ vars.' + variable + ' }}');
  return steps[0].run;
}
function workflowInvoke(name, options = {}) {
  const dir = path.join(fixture.temporary, 'workflow-' + ++sequence); fs.mkdirSync(dir);
  const config = structuredClone(fixture.config);
  if (!options.legacy) {
    selectTransportV2(config);
    // Complete maps for this small synthetic fixture, not real M204/V enrollment.
    config.replayTrust.verifier.files = {...config.controller.files};
    config.replayTrust.coreVerifier.files = {...config.controller.files};
  }
  options.config?.(config);
  const ordinary = JSON.stringify(config);
  let text = options.raw ?? (options.expanded ? ordinary.slice(0, 1) + ' '.repeat(60000) + ordinary.slice(1) : ordinary);
  if (options.arrayRoot) text = '[' + text + ']';
  const width = Math.ceil(text.length / 3);
  const parts = options.chunked ? [text.slice(0, width), text.slice(width, width * 2), text.slice(width * 2)] : [text, '', ''];
  options.parts?.(parts);
  const whole = parts.join('');
  const environmentFile = path.join(dir, 'github-env.txt'); fs.writeFileSync(environmentFile, 'PREEXISTING=value\n');
  const policyFile = path.join(fixture.root, 'release/production-release-policy.json');
  fs.mkdirSync(path.dirname(policyFile), {recursive: true});
  fs.writeFileSync(policyFile, JSON.stringify(options.noBusiness ? {} : {businessBackendPrivateReplay: {profile: 'synthetic-business-route'}}));
  const script = path.join(dir, 'workflow.ps1'); fs.writeFileSync(script, workflowBootstrap(name));
  const env = {};
  for (const key of ['SystemRoot', 'WINDIR', 'COMSPEC', 'PATHEXT', 'LANG', 'LC_ALL'])
    if (process.env[key] !== undefined) env[key] = process.env[key];
  Object.assign(env, {PATH: [path.dirname(process.execPath), path.dirname(gitExecutable), process.env.PATH].join(path.delimiter),
    HOME: dir, USERPROFILE: dir, TMP: dir, TEMP: dir, GITHUB_ACTIONS: 'true', GITHUB_ENV: environmentFile,
    BUSINESS31_CONFIG_JSON: parts[0], BUSINESS31_CONFIG_JSON_PART_2: parts[1], BUSINESS31_CONFIG_JSON_PART_3: parts[2],
    BUSINESS31_CONFIG_SHA256: options.hash || sha(Buffer.from(whole)),
    BUSINESS31_REQUEST_JSON: '{"schemaVersion":2,"syntheticPublicLocator":true}'});
  const result = spawnSync(pwsh, ['-NoProfile', '-File', script], {cwd: fixture.root, env,
    encoding: 'utf8', windowsHide: true, timeout: 90000, maxBuffer: 2 * 1024 * 1024});
  fs.writeFileSync(path.join(dir, 'stdout.txt'), result.stdout || '');
  fs.writeFileSync(path.join(dir, 'stderr.txt'), result.stderr || '');
  assert.equal(result.error, undefined);
  const lines = fs.readFileSync(environmentFile, 'utf8').trimEnd().split('\n');
  const exported = Object.fromEntries(lines.slice(1).map(line => [line.slice(0, line.indexOf('=')), line.slice(line.indexOf('=') + 1)]));
  return {...result, dir, text: whole, config, environmentFile, exported};
}
function workflowRefuses(name, options, error) {
  const run = workflowInvoke(name, options);
  assert.notEqual(run.status, 0, 'The real workflow bootstrap must refuse');
  assert.match(run.stderr, error);
  assert.equal(fs.readFileSync(run.environmentFile, 'utf8'), 'PREEXISTING=value\n');
}
for (const name of ['production-artifact.yml', 'release-gate.yml']) {
  test(name + ' executes its actual raw v1 and raw v2 bootstrap paths', () => {
    for (const legacy of [true, false]) {
      const run = workflowInvoke(name, {legacy}); assert.equal(run.status, 0, run.stderr);
      const file = run.exported.BUSINESS31_CONTROLLER_CONFIG;
      assert.equal(fs.readFileSync(file, 'utf8'), run.text);
      assert.equal(sha(fs.readFileSync(file)), run.exported.BUSINESS31_CONTROLLER_CONFIG_SHA256);
      assert.deepEqual(fs.readFileSync(path.join(run.exported.BUSINESS31_VERIFIER_ROOT, payloadName)), fixture.files[payloadName]);
    }
  });
  test(name + ' executes >48KB v2 chunk reconstruction with exact whole bytes and actual Git export', () => {
    const run = workflowInvoke(name, {chunked: true, expanded: true}); assert.equal(run.status, 0, run.stderr);
    assert.ok(Buffer.byteLength(run.text) > 48000, 'Whitespace-expanded transport fixture, not operational enrollment');
    const saved = fs.readFileSync(run.exported.BUSINESS31_CONTROLLER_CONFIG);
    assert.deepEqual(saved, Buffer.from(run.text));
    assert.equal(sha(saved), run.exported.BUSINESS31_CONTROLLER_CONFIG_SHA256);
    assert.deepEqual(JSON.parse(saved).replayTrust.verifier.files, run.config.replayTrust.verifier.files);
    assert.deepEqual(JSON.parse(saved).replayTrust.coreVerifier.files, run.config.replayTrust.coreVerifier.files);
    assert.equal(fs.existsSync(path.join(run.exported.BUSINESS31_VERIFIER_ROOT, 'unselected.txt')), false);
  });
  test(name + ' actual chunk bootstrap rejects missing/oversized parts, hash and malformed documents', () => {
    const incomplete = /chunked controller enrollment is incomplete or exceeds/;
    const profile = /enrollment transport\/profile combination differs/;
    for (const options of [
      {parts: p => {p[0] = '';}}, {parts: p => {p[1] = '';}}, {parts: p => {p[2] = '';}},
      // 16,001 Unicode characters are 48,003 UTF-8 bytes; tests bytes, not UTF-16 Length.
      {parts: p => {p[1] = '\u6f22'.repeat(16001);}}
    ]) workflowRefuses(name, {chunked: true, ...options}, incomplete);
    workflowRefuses(name, {chunked: true, hash: '0'.repeat(64)}, /enrollment is missing or changed/);
    workflowRefuses(name, {chunked: true, legacy: true}, profile);
    workflowRefuses(name, {chunked: true, arrayRoot: true}, profile);
    workflowRefuses(name, {chunked: true, raw: '[null,{}]'}, profile);
    workflowRefuses(name, {chunked: true, config: c => {c.schemaVersion = [2];}}, profile);
    workflowRefuses(name, {chunked: true, config: c => {c.profile = ['build31-business-prerequisite-controller-v2'];}}, profile);
    workflowRefuses(name, {raw: ''}, /enrollment is missing or changed/);
    workflowRefuses(name, {chunked: true, raw: '{"schemaVersion":2,'}, /ConvertFrom-Json|JSON/);
    workflowRefuses(name, {chunked: true, raw: '{"schemaVersion":2,"schemaVersion":'}, /ConvertFrom-Json|JSON/);
  });
  test(name + ' actual transported path still enforces source pin and original initializer guards', () => {
    workflowRefuses(name, {chunked: true, config: c => {c.controller.files[entryName] = '0'.repeat(64);}}, /initializer differs from independent enrollment/);
    workflowRefuses(name, {chunked: true, config: c => {c.controller.nodeSha256 = '0'.repeat(64);}}, /Controller runtime differs/);
    workflowRefuses(name, {chunked: true, config: c => {c.replayTrust.coreVerifier.commit = '3'.repeat(40);}}, /outer and recorded verifier selection differs/);
    const run = workflowInvoke(name, {noBusiness: true, chunked: true, parts: p => {p[1] = '';}, hash: '0'.repeat(64)});
    assert.equal(run.status, 0, run.stderr);
    assert.equal(fs.readFileSync(run.environmentFile, 'utf8'), 'PREEXISTING=value\n');
  });
}

test('only Flutter controller consumers align with the fixed Ubuntu24 role', () => {
  const file = path.resolve(__dirname, '../../.github/workflows/release-gate.yml');
  const release = yaml.load(fs.readFileSync(file, 'utf8'), {schema: yaml.JSON_SCHEMA});
  assert.equal(release.jobs['flutter-gates']['runs-on'], 'ubuntu-24.04');
  for (const name of ['android-package', 'android-emulator', 'firestore-rules', 'functions'])
    assert.equal(release.jobs[name]['runs-on'], 'ubuntu-latest');
  const steps = release.jobs['flutter-gates'].steps;
  const node = steps.findIndex(s => s.with?.['node-version'] === '22.23.1');
  const bootstrap = steps.findIndex(s => s.name === 'Prepare independently enrolled business verifier');
  assert.ok(node >= 0 && node < bootstrap, 'Pinned Node setup precedes public controller bootstrap');
});
