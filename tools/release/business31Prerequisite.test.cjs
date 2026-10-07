'use strict';
// Actual entry source, public Git custody and wire protocol with synthetic raw
// HTTPS only. The entry facade supplies fresh process/module context; it is not
// an OS isolation or real platform/private-replay/owner-authentication proof.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const crypto = require('node:crypto');
const hosted = require('./fixtures/business31HostedFixture.cjs');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
const controller = require('./business31Controller.cjs');
const client = require('./business31HostedClient.cjs');
const source = require('./business31SourceAdmission.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const retained = fs.mkdtempSync(path.join(os.tmpdir(), 'business31-prerequisite-retained-'));
process.stdout.write('Retained prerequisite entry fixtures: ' + retained + '\n');
const long = {timeout: 1200000};
let fixture, measured, initialConstruction;
function setup() {
  if (!fixture) {
    fixture = createFixture({extraProducers: [...controller.REQUIRED,
      'tools/release/business31OriginalPathReplay.cjs'].filter(file => /^tools\/release\/business31/.test(file))});
    const x = fixture.platformFixture();
    x.request.candidate = {...x.request.candidate, kind: 'main', ref: 'refs/heads/main', pullRequest: null};
    x.result.candidate = x.request.candidate;
    measured = {x, input: fixture.clientInput()};
    fs.mkdirSync(path.join(fixture.root, 'release'), {recursive: true});
    fs.writeFileSync(path.join(fixture.root, 'release/production-release-policy.json'),
      fixture.S.files['release/production-release-policy.json']);
  }
  fixture.reset();
  return fixture;
}
function clientMeasurement() {
  setup();
  if (!measured.client) measured.client = client.measureBusinessHostedClient31({
    trust: measured.x.trust, request: measured.x.request, input: measured.input});
  return measured.client;
}
function write(file, value) {
  fs.writeFileSync(file, Buffer.isBuffer(value) ? value : JSON.stringify(value) + '\n', {flag: 'wx'});
}
// Source text is unmodified. This mirrors HostedFixture's fresh-entry harness,
// adding output notification after the real exclusive filesystem write.
function invoke(file, argv, env, protocol, directory, {preload = false, library = false} = {}) {
  const filename = path.join(__dirname, file), m = {exports: {}}, imports = [];
  const output = argv[argv.indexOf('--output') + 1];
  const cache = {[filename]: m}; if (preload) cache['unselected.cjs'] = {exports: {}};
  let settle;
  const result = new Promise((resolve, reject) => {settle = {resolve, reject};});
  const filesystem = {...fs, writeFileSync(...args) {
    fs.writeFileSync(...args);
    if (args[0] === output) settle.resolve(JSON.parse(fs.readFileSync(output, 'utf8')));
  }};
  const req = name => {
    imports.push(name);
    if (name === 'node:fs') return filesystem;
    if (name === './business31HostedProtocol.cjs') return protocol;
    return require(name.startsWith('./') ? path.resolve(__dirname, name) : name);
  };
  req.main = library ? {} : m; req.cache = cache;
  const proc = {execPath: process.execPath, execArgv: ['--no-global-search-paths'],
    argv: [process.execPath, filename, ...argv], env, exitCode: 0,
    stdout: {write(text) {fs.appendFileSync(path.join(directory, 'entry.stdout'), text);}},
    stderr: {write(text) {fs.appendFileSync(path.join(directory, 'entry.stderr'), text); settle.reject(Error(String(text).trim()));}}};
  try {
    new Function('require', 'module', 'exports', '__dirname', '__filename', 'process',
      fs.readFileSync(filename, 'utf8'))(req, m, m.exports, __dirname, filename, proc);
  } catch (error) {settle.reject(error);}
  return {result, imports};
}
async function runController({purpose = 'construction', mutate, before, entryOptions = {}, resume, mutateResume} = {}) {
  const g = setup(), x = structuredClone(measured.x), directory = fs.mkdtempSync(path.join(retained, 'controller-'));
  const input = {schemaVersion: 1, purpose, repositoryRoot: g.root, gitExecutable: measured.input.gitExecutable,
    sourceArchivePath: null, manifestPath: null, packagePaths: []};
  if (purpose === 'package-verification') {
    for (const [key, name] of [['sourceArchivePath', 'source.zip'], ['manifestPath', 'manifest.json']]) {
      input[key] = path.join(directory, name); write(input[key], {synthetic: name});
    }
    input.packagePaths = ['app.apk', 'app.aab'].map(name => {const file = path.join(directory, name); write(file, {synthetic: name}); return file;});
  }
  const config = {schemaVersion: 1, profile: controller.PROFILE, replayTrust: x.trust,
    controller: {nodeSha256: sha(fs.readFileSync(process.execPath)), gitSha256: x.trust.gitSha256, files: x.trust.verifier.files},
    selected: {candidate: x.request.candidate, descriptorPointer: x.request.descriptorPointer,
      clientSelectionSha256: sha(Buffer.from(source.canonical(measured.input.selected)))},
    requester: {workflowId: '77', path: '.github/workflows/production-artifact.yml', jobName: 'Production fixture', actorIds: ['9']},
    maximumWaitSeconds: 9000};
  const env = {GITHUB_TOKEN: 'synthetic-never-a-real-token', GITHUB_ACTIONS: 'true',
    GITHUB_RUN_ID: '88', GITHUB_RUN_ATTEMPT: '2', GITHUB_REPOSITORY: x.trust.repository.name,
    GITHUB_SHA: x.request.candidate.commit, GITHUB_REF: 'refs/heads/main',
    GITHUB_WORKFLOW_REF: x.trust.repository.name + '/.github/workflows/production-artifact.yml@refs/heads/main'};
  const configFile = path.join(directory, 'config.json'), inputFile = path.join(directory, 'input.json'), output = path.join(directory, 'result.json');
  if (before) before({config, input, env});
  write(configFile, config); write(inputFile, input);
  const configSha256 = sha(fs.readFileSync(configFile)), resumeFile = path.join(directory, 'resume.json');
  if (resume) {
    const locator = {schemaVersion: 1, profile: 'build31-business-prerequisite-resume-v1',
      controllerConfigSha256: resume.configSha256, request: structuredClone({...resume.dispatched, runId: '42', runAttempt: '1'})};
    if (mutateResume) mutateResume(locator);
    write(resumeFile, locator);
    x.result = structuredClone(resume.remoteResult); x.job = structuredClone(resume.remoteJob);
  }
  let dispatched = null, raw = null, artifact = null, heads = 0;
  const parent = {id: 88, run_attempt: 2, workflow_id: 77, path: config.requester.path,
    head_sha: x.request.candidate.commit, event: 'workflow_dispatch', head_branch: 'main',
    repository: {id: 1}, head_repository: {id: 1}, actor: {id: 9}, triggering_actor: {id: 9},
    status: 'in_progress', conclusion: null};
  const fake = hosted.loadFakePlatform(record => {
    const url = new URL(record.url), suffix = url.pathname.replace('/repos/fixture/repository', '');
    let reply;
    if (record.method === 'POST') {
      assert.equal(suffix, '/actions/workflows/7/dispatches');
      assert.equal(record.headers['X-GitHub-Api-Version'], '2026-03-10');
      const body = JSON.parse(record.body); assert.equal(body.ref, 'verifier-fixture');
      assert.equal(dispatched, null, 'No implicit retry or second dispatch');
      dispatched = JSON.parse(body.inputs.request_json);
      assert.equal(dispatched.schemaVersion, 2);
      const request = {...dispatched, runId: '42', runAttempt: '1'};
      const at = new Date().toISOString();
      x.job.started_at = dispatched.challenge.requestedAtUtc; x.job.completed_at = at;
      x.result = {...x.result, schemaVersion: 2, candidate: request.candidate,
        startedAtUtc: dispatched.challenge.requestedAtUtc, completedAtUtc: at,
        challenge: structuredClone(dispatched.challenge), client: structuredClone(clientMeasurement())};
      reply = {body: {workflow_run_id: 42, run_url: 'https://api.github.com/repos/fixture/repository/actions/runs/42',
        html_url: 'https://github.com/fixture/repository/actions/runs/42'}};
    } else if (url.hostname === 'fixture.blob.core.windows.net') {
      assert.equal(record.headers?.Authorization, undefined, 'No GitHub credential reaches artifact storage');
      reply = {body: raw};
    } else if (suffix === '') reply = {body: x.repository};
    else if (suffix === '/actions/runs/88') reply = {body: structuredClone(parent)};
    else if (suffix === '/actions/runs/88/attempts/2/jobs') reply = {body: {total_count: 1, jobs: [{
      id: 89, name: config.requester.jobName, run_id: 88, run_attempt: 2,
      head_sha: x.request.candidate.commit, status: 'in_progress', conclusion: null}]}};
    else if (suffix === '/git/ref/heads/main') {heads++; reply = {body: {ref: 'refs/heads/main', object: {sha: x.request.candidate.commit, type: 'commit'}}};}
    else if (suffix === '/actions/runs/42') reply = {body: structuredClone(x.run)};
    else if (suffix === '/actions/runs/42/attempts/1/jobs') reply = {body: {total_count: 1, jobs: [x.job]}};
    else if (suffix === '/actions/runs/42/artifacts') {
      raw = hosted.zip(x.result);
      artifact = {id: 71, name: 'business31-hosted-' + x.request.candidate.commit + '-42-1', expired: false,
        size_in_bytes: raw.length, digest: 'sha256:' + sha(raw).toLowerCase(),
        workflow_run: {id: 42, repository_id: 1, head_repository_id: 1, head_sha: x.trust.verifier.commit},
        created_at: x.job.completed_at, expires_at: new Date(Date.now() + 3600000).toISOString()};
      reply = {body: {total_count: 1, artifacts: [artifact]}};
    } else if (suffix === '/actions/artifacts/71/zip') reply = {status: 302,
      headers: {location: 'https://fixture.blob.core.windows.net/result?sig=synthetic'}, body: Buffer.alloc(0)};
    else throw Error('Unplanned synthetic request: ' + record.url);
    if (mutate) mutate({record, reply, x, input, configFile, inputFile, heads, dispatched});
    return reply;
  });
  const argv = ['--config', configFile, '--config-sha256', configSha256, '--input', inputFile, '--output', output];
  if (resume) argv.push('--resume-request', resumeFile);
  const run = invoke('business31Prerequisite.cjs', argv, env, fake.protocol, directory, entryOptions);
  let value, error;
  try {value = await run.result;} catch (caught) {error = caught;}
  write(path.join(directory, 'trace.json'), {requests: fake.requests.map(r => ({url: r.url, method: r.method,
    body: r.body?.toString('utf8') ?? null})), imports: run.imports, error: error?.message ?? null});
  // Restore only the fixture's own intentionally mutable policy between cases.
  fs.writeFileSync(path.join(g.root, 'release/production-release-policy.json'), g.S.files['release/production-release-policy.json']);
  return {value, error, requests: fake.requests, dispatched, output, directory, configSha256,
    remoteResult: x.result, remoteJob: x.job};
}
for (const purpose of ['construction', 'package-verification', 'policy']) {
  test('actual prerequisite entry accepts exact synthetic dispatch/result/Git joins for ' + purpose, long, async () => {
    const run = await runController({purpose});
    assert.equal(run.error, undefined, run.error?.stack);
    assert.equal(run.value.purpose, purpose); assert.equal(run.value.freshHostedReplayVerified, true);
    assert.equal(run.value.replayMode, 'fresh-dispatch');
    assert.deepEqual(run.value.limits, {deploymentAuthorized: false, constructionAuthorized: false,
      signingAuthorized: false, distributionAuthorized: false});
    assert.equal(run.value.client.humanIdentityAuthenticated, false);
    assert.equal(run.value.client.appCheckSourcePolicyVerified, true);
    assert.deepEqual(run.value.challenge, run.dispatched.challenge);
    assert.equal(run.value.challenge.fileBindings.length, purpose === 'package-verification' ? 4 : 0);
    assert.equal(run.requests.filter(r => r.method === 'POST').length, 1);
    assert.equal(run.requests.filter(r => r.url.endsWith('/git/ref/heads/main')).length, 4);
    if (purpose === 'construction') initialConstruction = run;
  });
}
test('same still-live parent reauthenticates original construction child with zero dispatches', long, async () => {
  assert.ok(initialConstruction?.value, 'Uses the previously authenticated original fixture result');
  const run = await runController({resume: initialConstruction});
  assert.equal(run.error, undefined, run.error?.stack);
  assert.equal(run.value.replayMode, 'same-parent-reauthentication');
  assert.deepEqual(run.value.challenge, initialConstruction.value.challenge);
  assert.equal(run.value.resultSha256, initialConstruction.value.resultSha256);
  assert.equal(run.value.limits.constructionAuthorized, false);
  assert.equal(run.requests.filter(r => r.method === 'POST').length, 0);
  assert.equal(run.requests.filter(r => r.url.endsWith('/git/ref/heads/main')).length, 4);
  assert.equal(run.requests.filter(r => new URL(r.url).hostname === 'fixture.blob.core.windows.net').length, 1);
});
for (const [name, options] of [
  ['different parent run', {mutateResume: r => {r.request.challenge.requester.runId = '87';}}],
  ['different parent attempt', {mutateResume: r => {r.request.challenge.requester.runAttempt = '1';}}],
  ['expired original challenge', {mutateResume: r => {
    r.request.challenge.requestedAtUtc = new Date(Date.now() - 120000).toISOString();
    r.request.challenge.expiresAtUtc = new Date(Date.now() - 60000).toISOString();
  }}],
  ['changed external config digest', {mutateResume: r => {r.controllerConfigSha256 = 'F'.repeat(64);}}],
  ['package purpose', {purpose: 'package-verification'}],
  ['local process context', {before: ({env}) => {delete env.GITHUB_ACTIONS;}}]
]) test('resume refuses ' + name + ' before HTTPS', long, async () => {
  const run = await runController({resume: initialConstruction, ...options});
  assert.ok(run.error); assert.equal(run.requests.length, 0); assert.equal(fs.existsSync(run.output), false);
});
for (const [name, options] of [
  ['library entry', {entryOptions: {library: true}}],
  ['prior helper cache', {entryOptions: {preload: true}}],
  ['loader environment', {before: ({env}) => {env.NODE_OPTIONS = '--require=not-executed';}}],
  ['missing Actions context', {before: ({env}) => {delete env.GITHUB_ACTIONS;}}],
  ['wrong selected Git executable digest', {before: ({config}) => {config.controller.gitSha256 = 'F'.repeat(64);}}]
]) test('actual entry refuses ' + name + ' before any HTTPS', long, async () => {
  const run = await runController(options); assert.ok(run.error); assert.equal(run.requests.length, 0);
  assert.equal(fs.existsSync(run.output), false);
});
for (const [name, mutate] of [
  ['ambiguous dispatch response', ({record, reply}) => {if (record.method === 'POST') reply.body = {};}],
  ['different dispatched run identity', ({record, reply}) => {if (record.url.endsWith('/actions/runs/42')) reply.body.id = 43;}],
  ['nonce substitution', ({record, x}) => {if (record.method === 'POST') x.result.challenge.nonce = 'f'.repeat(64);}],
  ['purpose substitution', ({record, x}) => {if (record.method === 'POST') x.result.challenge.purpose = 'policy';}],
  ['client grant injection', ({record, x}) => {if (record.method === 'POST') x.result.client.signingAuthorized = true;}],
  ['head advances on final observation', ({record, reply, heads}) => {
    if (record.url.endsWith('/git/ref/heads/main') && heads === 4) reply.body.object.sha = 'f'.repeat(40);
  }],
  ['working policy changes during artifact read', ({record, input}) => {
    if (new URL(record.url).hostname === 'fixture.blob.core.windows.net')
      fs.appendFileSync(path.join(input.repositoryRoot, 'release/production-release-policy.json'), ' ');
  }],
  ['input changes during final observation', ({record, inputFile, heads}) => {
    if (record.url.endsWith('/git/ref/heads/main') && heads === 4) fs.appendFileSync(inputFile, ' ');
  }]
]) test('post-dispatch refusal: ' + name, long, async () => {
  const run = await runController({mutate}); assert.ok(run.error);
  assert.equal(run.requests.filter(r => r.method === 'POST').length, 1);
  assert.equal(fs.existsSync(run.output), false);
});

async function runReplay({missingHelper, invalidChallenge = false, omitPair = false}) {
  setup(); const x = structuredClone(measured.x), directory = fs.mkdtempSync(path.join(retained, 'replay-'));
  x.request.schemaVersion = 2;
  x.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
    requestedAtUtc: new Date().toISOString(), expiresAtUtc: new Date(Date.now() + 60000).toISOString(),
    requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
    clientSelectionSha256: sha(Buffer.from(source.canonical(measured.input.selected))), fileBindings: []};
  if (invalidChallenge) x.request.challenge.nonce = 'not-a-nonce';
  if (missingHelper) delete x.trust.verifier.files['tools/release/' + missingHelper];
  x.trust.nodeSha256 = sha(fs.readFileSync(process.execPath));
  const trustFile = path.join(directory, 'trust.json'), inputFile = path.join(directory, 'input.json');
  const clientFile = path.join(directory, 'client.json'), output = path.join(directory, 'business31-hosted-result.json');
  write(trustFile, x.trust); write(clientFile, measured.input);
  write(inputFile, {request: x.request, repositoryRoot: fixture.root, gitExecutable: measured.input.gitExecutable,
    sourceManifest: {}, privateParent: directory});
  const fake = hosted.loadFakePlatform(() => {throw Error('Replay must refuse before HTTPS/credentials');});
  const argv = ['--trust', trustFile, '--trust-sha256', sha(fs.readFileSync(trustFile)), '--request', inputFile, '--output', output];
  if (!omitPair) argv.push('--client-input', clientFile, '--client-input-sha256', sha(fs.readFileSync(clientFile)));
  const run = invoke('business31HostedReplay.cjs', argv, {GITHUB_TOKEN: 'synthetic-never-a-real-token'}, fake.protocol, directory);
  await assert.rejects(run.result);
  assert.equal(fake.requests.length, 0); assert.equal(fs.existsSync(output), false);
  assert.equal(run.imports.some(name => ['./business31SourceAdmission.cjs', './business31PrivateDescriptor.cjs',
    './business31OriginalPathReplay.cjs', './privateEvidenceBundle31.cjs'].includes(name)), false,
  'No unbound direct helper import may precede refusal');
  write(path.join(directory, 'trace.json'), {imports: run.imports, requests: fake.requests});
}
for (const helper of ['business31SourceAdmission.cjs', 'business31PrivateDescriptor.cjs',
  'business31TrustedInput.cjs', 'privateEvidenceBundle31.cjs', 'business31OriginalPathReplay.cjs']) {
  test('actual replay2 refuses missing pre-import binding: ' + helper, long, () => runReplay({missingHelper: helper}));
}
test('actual replay2 refuses malformed challenge before helper or credentials', long, () => runReplay({invalidChallenge: true}));
test('actual replay2 refuses absent paired client input before helper or credentials', long, () => runReplay({omitPair: true}));
