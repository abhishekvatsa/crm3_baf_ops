'use strict';
// Real controller/Git/projection validators and entry bytes. Only HTTPS and the
// fresh-entry process frame are synthetic; these tests prove no hosted authority.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const hosted = require('./fixtures/business31HostedFixture.cjs');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
const client = require('./business31HostedClient.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const entry = path.join(__dirname, 'business31PolicyResult.cjs');
const message = /No authenticated exact-source business policy measurement is available/;
const token = 'synthetic-read-only-token-never-a-real-credential';
let valid, base;
test.before(() => {
  valid = createFixture({extraProducers: ['tools/release/business31Controller.cjs',
    'tools/release/business31Prerequisite.cjs', 'tools/release/business31PolicyResult.cjs']});
  base = valid.platformFixture();
  base.request.schemaVersion = 2;
  base.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
    requestedAtUtc: new Date(Date.parse(base.result.startedAtUtc) - 1000).toISOString(),
    expiresAtUtc: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
    requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
    clientSelectionSha256: sha(Buffer.from(JSON.stringify(valid.clientInput().selected))), fileBindings: []};
  base.result.schemaVersion = 2;
  base.result.challenge = structuredClone(base.request.challenge);
  base.result.client = client.measureBusinessHostedClient31({trust: base.trust,
    request: base.request, input: valid.clientInput()});
});
test.beforeEach(() => valid.reset());
function configuration(f) {
  return {schemaVersion: 1, profile: 'build31-business-prerequisite-controller-v1',
    replayTrust: structuredClone(f.trust), controller: {
      nodeSha256: sha(fs.readFileSync(process.execPath)), gitSha256: f.trust.gitSha256,
      files: {...f.trust.verifier.files}},
    selected: {candidate: structuredClone(f.request.candidate),
      descriptorPointer: structuredClone(f.request.descriptorPointer),
      clientSelectionSha256: f.request.challenge.clientSelectionSha256},
    requester: {workflowId: '91', path: '.github/workflows/production-artifact.yml',
      jobName: 'Governed production APK', actorIds: ['9']}, maximumWaitSeconds: 9000};
}
function input(f) {
  return {schemaVersion: 1, profile: 'build31-business-policy-result-input-v1',
    repositoryRoot: valid.root, gitExecutable: valid.clientInput().gitExecutable,
    request: structuredClone(f.request)};
}
async function run(f, options = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-policy-'));
  const configFile = path.join(root, 'controller.json'), inputFile = path.join(root, 'input.json');
  const config = configuration(f), data = input(f);
  options.config?.(config); options.input?.(data);
  fs.writeFileSync(configFile, JSON.stringify(config), {flag: 'wx'});
  fs.writeFileSync(inputFile, JSON.stringify(data), {flag: 'wx'});
  const configSha = sha(fs.readFileSync(configFile));
  const context = {root, configFile, inputFile};
  const host = hosted.platform(f, {mutate: options.mutate &&
    ((request, response) => options.mutate(request, response, context))});
  try {
    const result = await new Promise((resolve, reject) => {
      const m = {exports: {}};
      const requireEntry = name => name === './business31HostedProtocol.cjs' ? host.protocol :
        require(name.startsWith('./') ? path.resolve(__dirname, name) : name);
      requireEntry.main = m; requireEntry.cache = {[entry]: m};
      if (options.preload) requireEntry.cache['unselected-cache.cjs'] = {exports: {}};
      const proc = {execPath: process.execPath, execArgv: ['--no-global-search-paths'],
        argv: [process.execPath, entry, '--controller-config', configFile,
          '--controller-config-sha256', options.configSha ?? configSha, '--input', inputFile],
        env: {GITHUB_TOKEN: token, ...(options.env || {})}, exitCode: 0,
        stdout: {write(text) {try {resolve(JSON.parse(text));} catch (error) {reject(error);}}},
        stderr: {write(text) {reject(Error(String(text).trim()));}}};
      options.frame?.(proc);
      try {
        new Function('require', 'module', 'exports', '__dirname', '__filename', 'process',
          fs.readFileSync(entry, 'utf8'))(requireEntry, m, m.exports, __dirname, entry, proc);
      } catch (error) {reject(error);}
    });
    return {result, requests: host.requests};
  } catch (error) {
    error.requests = host.requests;
    throw error;
  } finally {
    // Only the exact mkdtemp directory owned by this invocation is removed.
    fs.rmSync(root, {recursive: true, force: true});
  }
}
function fixture() { return structuredClone(base); }
async function refuses(f, options, expected = message, count) {
  await assert.rejects(run(f, options), error => {
    assert.match(error.message, expected);
    if (count !== undefined) assert.equal(error.requests.length, count);
    assert.equal(error.message.includes(valid.temporary), false);
    assert.equal(error.message.includes(token), false);
    return true;
  });
}
test('authenticates exact policy replay, real committed Git bindings and final head using GET only', async () => {
  const f = fixture(), {result, requests} = await run(f);
  assert.equal(result.schemaVersion, 1);
  assert.equal(result.profile, 'build31-business-policy-result-v1');
  assert.equal(result.purpose, 'policy');
  assert.equal(result.policyMeasurementVerified, true);
  assert.deepEqual(result.candidate, f.request.candidate);
  assert.deepEqual(result.client, f.result.client);
  assert.equal(result.client.policy.bindings.policy.commit, valid.S.commit);
  assert.equal(result.client.policy.bindings.policy.sha256,
    sha(valid.S.files['release/production-release-policy.json']));
  const round = ['https://api.github.com/repos/fixture/repository',
    'https://api.github.com/repos/fixture/repository/actions/runs/42',
    'https://api.github.com/repos/fixture/repository/actions/runs/42/attempts/1/jobs?per_page=100',
    'https://api.github.com/repos/fixture/repository/pulls/4'];
  assert.deepEqual(requests.map(row => row.url), [...round,
    'https://api.github.com/repos/fixture/repository/actions/runs/42/artifacts?per_page=100',
    'https://api.github.com/repos/fixture/repository/actions/artifacts/71/zip',
    'https://fixture.blob.core.windows.net/result?sig=synthetic', ...round, ...round]);
  assert.ok(requests.every(row => row.method === 'GET'));
  assert.deepEqual(requests.find(row => row.url.startsWith('https://fixture.blob')).headers, {});
  for (const name of ['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated',
    'humanIdentityAuthenticated', 'trustedClockAuthenticated', 'originalProcessExecutionAuthenticated',
    'credentialAccessAuthorized', 'backendDeploymentAuthorized', 'constructionAuthorized',
    'signingAuthorized', 'distributionAuthorized']) assert.equal(result[name], false, name);
  const text = JSON.stringify(result);
  assert.equal(text.includes(valid.temporary), false);
  assert.equal(text.includes(valid.originalMessageBytes.toString('utf8')), false);
  assert.equal(text.includes(token), false);
});
test('public consumption needs no local original owner message and permits independently pinned controller Node', async () => {
  fs.unlinkSync(valid.originalMessageFile);
  const f = fixture();
  f.trust.nodeSha256 = 'F'.repeat(64); // Independent remote Linux selection, not local process identity.
  const {result} = await run(f);
  assert.equal(result.policyMeasurementVerified, true);
});
test('fresh entry rejects library import and inherited preload/cache without HTTP', async () => {
  assert.throws(() => require('./business31PolicyResult.cjs'), /FRESH_ENTRY_REQUIRED/);
  await refuses(fixture(), {preload: true}, /FRESH_ENTRY_REQUIRED/, 0);
  await refuses(fixture(), {env: {NODE_OPTIONS: '--require=unselected'}}, /FRESH_ENTRY_REQUIRED/, 0);
  await refuses(fixture(), {env: {LD_LIBRARY_PATH: '/unselected'}}, /FRESH_ENTRY_REQUIRED/, 0);
});
test('external config pin and mandatory helper membership fail before HTTP', async () => {
  await refuses(fixture(), {configSha: '0'.repeat(64)}, message, 0);
  await refuses(fixture(), {config: c => {delete c.controller.files['tools/release/business31Controller.cjs'];}}, message, 0);
});
test('wrong controller Node and changed producer bytes fail before HTTP', async () => {
  await refuses(fixture(), {config: c => {c.controller.nodeSha256 = '0'.repeat(64);}}, message, 0);
  await refuses(fixture(), {config: c => {
    c.controller.files['tools/release/business31PolicyResult.cjs'] = '0'.repeat(64);
    c.replayTrust.verifier.files['tools/release/business31PolicyResult.cjs'] = '0'.repeat(64);
  }}, message, 0);
});
test('unselected S, descriptor or client commitment fails before HTTP', async () => {
  for (const alter of [c => {c.selected.candidate.commit = 'f'.repeat(40);},
    c => {c.selected.descriptorPointer.sha256 = 'F'.repeat(64);},
    c => {c.selected.clientSelectionSha256 = 'F'.repeat(64);}]) {
    await refuses(fixture(), {config: alter}, message, 0);
  }
});
test('input must be a closed locator rather than a PASS or operational-purpose request', async () => {
  await refuses(fixture(), {input: value => {value.pass = true;}}, message, 0);
  await refuses(fixture(), {input: value => {value.request.challenge.purpose = 'construction';}}, message, 0);
  await refuses(fixture(), {input: value => {
    value.request = {schemaVersion: 1, candidate: value.request.candidate,
      descriptorPointer: value.request.descriptorPointer, runId: '42', runAttempt: '1'};
  }}, message, 0);
});
test('same-name foreign workflow and failed completed job are refused', async () => {
  await refuses(fixture(), {mutate: (r, v) => {
    if (r.url.endsWith('/actions/runs/42')) v.body.workflow_id = 99; return v;
  }});
  await refuses(fixture(), {mutate: (r, v) => {
    if (r.url.includes('/jobs?')) v.body.jobs[0].conclusion = 'failure'; return v;
  }});
});
test('artifact digest substitution and expanded artifact population are refused', async () => {
  await refuses(fixture(), {mutate: (r, v) => {
    if (r.url.includes('/artifacts?')) v.body.artifacts[0].digest = 'sha256:' + '0'.repeat(64); return v;
  }});
  await refuses(fixture(), {mutate: (r, v) => {
    if (r.url.includes('/artifacts?')) v.body.total_count = 2; return v;
  }});
});
test('downgraded client schema, changed challenge and authority elevation are refused', async () => {
  for (const alter of [f => {f.result.client.schemaVersion = 1;},
    f => {f.result.challenge.nonce = 'f'.repeat(64);},
    f => {f.result.client.constructionAuthorized = true;}]) {
    const f = fixture(); alter(f); await refuses(f);
  }
});
test('internally well-shaped artifact policy digest must match actual committed S bytes', async () => {
  const f = fixture(); f.result.client.policy.bindings.policy.sha256 = 'F'.repeat(64);
  await refuses(f, undefined, message, 11);
});
test('head movement in the third observation after real Git reads is refused', async () => {
  let heads = 0;
  await refuses(fixture(), {mutate: (r, v) => {
    if (r.url.endsWith('/pulls/4') && ++heads === 3) v.body.head.sha = 'f'.repeat(40); return v;
  }}, message, 15);
});
test('configuration or locator drift across network awaits cannot publish a result', async () => {
  for (const filename of ['configFile', 'inputFile']) {
    let changed = false;
    await refuses(fixture(), {mutate: (r, v, context) => {
      if (!changed) {changed = true; fs.appendFileSync(context[filename], '\n');} return v;
    }}, message, 15);
  }
});
test('a completed but expired policy challenge is not a reusable grant', async () => {
  const f = fixture();
  const end = new Date(Date.now() - 1000).toISOString();
  f.request.challenge.expiresAtUtc = end;
  f.result.challenge.expiresAtUtc = end;
  await refuses(f);
});
