'use strict';
// Actual public Git custody + actual protected entry with fake raw HTTPS only.
// All owner/platform data is synthetic; no credential, replay or grant claim.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const subject = require('./business31HostedClient.cjs');
const hosted = require('./fixtures/business31HostedFixture.cjs');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
let retained;
function fixture() { if (!retained) retained = createFixture(); return retained; }
async function scenario(run) {
  const g = fixture(); g.reset();
  const x = g.platformFixture(), input = g.clientInput();
  try { return await run({g, x, input}); } finally { g.reset(); }
}
function entry(x, input, options = {}, platformOptions = {}) {
  const host = hosted.platform(x, platformOptions);
  return {host, result: host.runConsumer({trust: x.trust, request: x.request},
    {clientInput: input, ...options})};
}
const long = {timeout: 1200000};

test('fixed seven helper population and measurement-only exports', () => {
  assert.equal(subject.PROFILE, 'build31-business-hosted-client-input-v1');
  assert.deepEqual([...subject.HELPERS].sort(), [
    'business31HostedClient.cjs', 'business31ClientCustody.cjs', 'business31ClientSemantics.cjs',
    'business31TrustedInput.cjs', 'business31PrivateDescriptor.cjs', 'privateEvidenceBundle31.cjs', 'business31ClientPolicy.cjs'
  ].map(name => 'tools/release/' + name).sort());
  assert.equal(Object.isFrozen(subject), true);
});

test('inherited array map/getter cannot execute during data cloning', () => {
  let touched = 0;
  const array = ['synthetic'];
  const prototype = Object.create(Array.prototype);
  Object.defineProperty(prototype, 'map', {get() { touched++; throw Error('callback executed'); }});
  Object.setPrototypeOf(array, prototype);
  assert.throws(() => subject.prepareBusinessHostedClient31({trust: {actorIds: array}, request: {}, input: {}}),
    /dense bounded data array/);
  assert.equal(touched, 0);
});

test('array holes, symbol members and own getters fail without callback execution', () => {
  let touched = 0;
  const getter = ['synthetic'];
  Object.defineProperty(getter, '0', {get() { touched++; throw Error('getter executed'); }});
  const symbol = ['synthetic']; symbol[Symbol('extra')] = true;
  for (const value of [new Array(1), symbol, getter, new Array(513)]) {
    assert.throws(() => subject.prepareBusinessHostedClient31({trust: {value}, request: {}, input: {}}),
      /dense bounded data array/);
  }
  assert.equal(touched, 0);
});

test('protected entry refuses absent, wrong or partial client digest before HTTPS', long, async () => {
  await scenario(async ({x, input}) => {
    for (const options of [{omitClientSha256: true}, {clientSha256: 'F'.repeat(64)},
      {extraClientArgs: ['--client-input-sha256', 'A'.repeat(64)]}]) {
      const run = entry(x, input, options);
      await assert.rejects(run.result);
      assert.equal(run.host.requests.length, 0);
    }
  });
});

for (const helper of subject.HELPERS) {
  test('protected entry rejects missing selected helper before HTTPS: ' + path.basename(helper), long, async () => {
    await scenario(async ({x, input}) => {
      const run = entry(x, input, {missingClientHelper: helper});
      await assert.rejects(run.result);
      assert.equal(run.host.requests.length, 0);
    });
  });
}

test('real Git and protected raw-platform consumer join schema3 without operational authority', long, async () => {
  await scenario(async ({x, input}) => {
    const run = entry(x, input);
    const result = await run.result;
    assert.equal(result.schemaVersion, 3);
    assert.equal(result.hostedRecordedReplayResultAuthenticated, true);
    assert.deepEqual(result.source, input.selected.source);
    assert.deepEqual(result.candidate, x.request.candidate);
    assert.deepEqual(result.descriptorPointer, input.selected.descriptor);
    assert.deepEqual(result.closurePointer, input.selected.backendClosure);
    assert.deepEqual(result.commitments, x.result.commitments);
    assert.equal(result.client.profile, 'build31-business-client-compatibility-v1');
    assert.equal(result.client.schemaVersion, 2);
    assert.equal(result.client.policy.appCheckSourcePolicyVerified, true);
    assert.deepEqual(subject.validateBusinessHostedClientMeasurement31({trust: x.trust, request: x.request,
      client: result.client}), result.client);
    assert.deepEqual(result.client.ownerPointer, input.selected.ownerPointer);
    assert.deepEqual(result.client.decisionPointer, input.selected.decisionPointer);
    assert.deepEqual(result.client.originalMessage, input.selected.originalMessage);
    for (const key of ['gitCustodyVerified', 'dedicatedOwnerDecisionDeltasVerified',
      'descriptorPreparationVerified', 'recordedSemanticsValidated', 'appCheckSourcePolicyVerified']) assert.equal(result.client[key], true, key);
    for (const key of ['independentlySelectedInputsAuthenticated',
      'executingHostAuthenticated', 'humanIdentityAuthenticated', 'trustedClockAuthenticated',
      'platformIdentityAuthenticated', 'credentialAccessAuthorized', 'backendDeploymentAuthorized',
      'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized']) assert.equal(result.client[key], false, key);
    for (const key of ['ownerIdentityAuthenticated', 'originalProcessExecutionAuthenticated',
      'deploymentAuthorized', 'constructionAuthorized', 'distributionAuthorized']) assert.equal(result[key], false, key);
    const api = 'https://api.github.com/repos/fixture/repository';
    const observation = [api, api + '/actions/runs/42',
      api + '/actions/runs/42/attempts/1/jobs?per_page=100', api + '/pulls/4'];
    assert.deepEqual(run.host.requests.map(record => record.url), [
      ...observation, api + '/actions/runs/42/artifacts?per_page=100',
      api + '/actions/artifacts/71/zip', 'https://fixture.blob.core.windows.net/result?sig=synthetic',
      ...observation, ...observation
    ], 'Three complete observation rounds and the artifact list, redirect and wire download');

    // Pure real Python sanitizer only, not launcher dispatch or hosted execution.
    const python = process.env.BUSINESS31_TEST_PYTHON ||
      (process.platform === 'win32' ? 'C:/Python313/python.exe' : 'python3');
    const script = [
      'import importlib.util, json, sys',
      's=importlib.util.spec_from_file_location("client_sanitizer",sys.argv[1])',
      'm=importlib.util.module_from_spec(s);s.loader.exec_module(m)',
      'd=json.loads(sys.stdin.buffer.read())',
      'raw=(json.dumps(d["value"],separators=(",",":"))+"\\n").encode()',
      'sys.stdout.buffer.write(m.sanitized_client_output(raw,d["trust"],d["request"],d["input"]))'
    ].join('\n');
    const env = {};
    for (const key of ['SystemRoot', 'WINDIR', 'PATH', 'HOME', 'USERPROFILE', 'TEMP', 'TMP']) {
      if (process.env[key] !== undefined) env[key] = process.env[key];
    }
    const sanitizer = value => spawnSync(python, ['-I', '-S', '-B', '-c', script,
      path.join(__dirname, 'business31HostedLauncher.py')], {env, input: JSON.stringify({
      value, trust: x.trust, request: x.request, input}), encoding: 'utf8', windowsHide: true,
      timeout: 15000, maxBuffer: 1024 * 1024});
    const checked = sanitizer(result);
    assert.equal(checked.error, undefined);
    assert.equal(checked.status, 0, checked.stderr);
    assert.deepEqual(JSON.parse(checked.stdout), result);
    const downgraded = {...result, schemaVersion: 2}; delete downgraded.client;
    const refused = sanitizer(downgraded);
    assert.equal(refused.error, undefined);
    assert.notEqual(refused.status, 0, 'Client caller must refuse projection2 downgrade');
  });
});

test('fresh measurement export needs no hosted claim and its closed contract refuses nested drift', long, async () => {
  await scenario(async ({x, input}) => {
    const client = subject.measureBusinessHostedClient31({trust: x.trust, request: x.request, input});
    assert.equal(client.schemaVersion, 2);
    assert.equal(Object.hasOwn(client, 'hostedRecordedReplayResultAuthenticated'), false);
    assert.deepEqual(subject.validateBusinessHostedClientMeasurement31({trust: x.trust, request: x.request, client}), client);
    for (const [keys, value] of [[['policy', 'constructionAuthorized'], true],
      [['policy', 'bindings', 'policy', 'commit'], 'e'.repeat(40)], [['policy', 'release', 'buildNumber'], '31'],
      [['policy', 'appCheck', 'serverEnforcementScopesAtBuild', 'identityCallableEnforced'], false],
      [['appCheckSourcePolicyVerified'], false], [['schemaVersion'], 1]]) {
      const changed = structuredClone(client); let target = changed;
      for (const key of keys.slice(0, -1)) target = target[key];
      target[keys.at(-1)] = value;
      assert.throws(() => subject.validateBusinessHostedClientMeasurement31({trust: x.trust, request: x.request, client: changed}));
    }
    assert.throws(() => subject.measureBusinessHostedClient31({trust: x.trust, request: x.request, input,
      hostedResult: {hostedRecordedReplayResultAuthenticated: true}}), /fields differ/);
  });
});

test('remote challenge-bound client artifact is consumed without private original-message access', long, async () => {
  await scenario(async ({g, x, input}) => {
    x.request.schemaVersion = 2;
    x.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
      requestedAtUtc: new Date(Date.parse(x.result.startedAtUtc) - 1000).toISOString(),
      expiresAtUtc: new Date(Date.now() + 3600000).toISOString(),
      requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
      clientSelectionSha256: 'C'.repeat(64), fileBindings: []};
    x.result = {...x.result, schemaVersion: 2, challenge: structuredClone(x.request.challenge),
      client: subject.measureBusinessHostedClient31({trust: x.trust, request: x.request, input})};
    // The private evidence was measured in the replay fixture. It is made
    // unavailable locally before the actual protected public consumer runs.
    fs.renameSync(g.originalMessageFile, g.originalMessageFile + '.private');
    try {
      const host = hosted.platform(x);
      const result = await host.runConsumer({trust: x.trust, request: x.request});
      assert.equal(result.schemaVersion, 3);
      assert.deepEqual(result.challenge, x.request.challenge);
      assert.deepEqual(result.client, x.result.client);
      assert.equal(result.hostedRecordedReplayResultAuthenticated, true);
      assert.equal(host.requests.length, 15);
    } finally { fs.renameSync(g.originalMessageFile + '.private', g.originalMessageFile); }
  });
});

test('remote challenge expiring during final observation refuses output', long, async () => {
  await scenario(async ({x, input}) => {
    x.request.schemaVersion = 2;
    x.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
      requestedAtUtc: new Date(Date.parse(x.result.startedAtUtc) - 1000).toISOString(),
      expiresAtUtc: new Date(Date.now() + 3600000).toISOString(),
      requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
      clientSelectionSha256: 'C'.repeat(64), fileBindings: []};
    x.result = {...x.result, schemaVersion: 2, challenge: structuredClone(x.request.challenge),
      client: subject.measureBusinessHostedClient31({trust: x.trust, request: x.request, input})};
    const originalNow = Date.now; let heads = 0;
    const host = hosted.platform(x, {mutate(record, reply) {
      if (record.url.endsWith('/pulls/4') && ++heads === 3)
        Date.now = () => Date.parse(x.request.challenge.expiresAtUtc) + 1;
      return reply;
    }});
    try {
      await assert.rejects(host.runConsumer({trust: x.trust, request: x.request}));
      assert.equal(heads, 3);
    } finally { Date.now = originalNow; }
  });
});

test('business M cannot be replaced with later candidate S', long, async () => {
  await scenario(async ({x, input}) => {
    input.selected.source = {commit: x.request.candidate.commit, tree: x.request.candidate.tree,
      functionsTree: input.selected.source.functionsTree};
    const run = entry(x, input); await assert.rejects(run.result);
    assert.equal(run.host.requests.length, 0);
  });
});

test('selected descriptor commit cannot be replaced while preserving its digest', long, async () => {
  await scenario(async ({x, input}) => {
    input.selected.descriptor.commit = input.selected.backendClosure.commit;
    const run = entry(x, input); await assert.rejects(run.result);
    assert.equal(run.host.requests.length, 0);
  });
});

test('hosted closure identity must join selected original Git custody', long, async () => {
  await scenario(async ({x, input}) => {
    x.result.closurePointer.commit = 'f'.repeat(40);
    const run = entry(x, input); await assert.rejects(run.result);
    assert.ok(run.host.requests.length > 0, 'Reached real raw-platform validation');
  });
});

test('hosted bundle commitments must match the original committed descriptor', long, async () => {
  await scenario(async ({x, input}) => {
    x.result.commitments.bundleSha256 = 'E'.repeat(64);
    x.result.commitments.membersSha256 = 'F'.repeat(64);
    x.result.commitments.relocationSha256 = '9'.repeat(64);
    const run = entry(x, input); await assert.rejects(run.result);
    assert.ok(run.host.requests.length > 0, 'Reached real raw-platform validation');
  });
});

test('initial wrong original-message bytes refuse before HTTPS', long, async () => {
  await scenario(async ({g, x, input}) => {
    fs.appendFileSync(g.originalMessageFile, ' ');
    const run = entry(x, input); await assert.rejects(run.result);
    assert.equal(run.host.requests.length, 0);
  });
});

test('original-message drift during awaited artifact reads is refused by final actual custody', long, async () => {
  await scenario(async ({g, x, input}) => {
    let changed = false;
    const run = entry(x, input, {}, {mutate(record, reply) {
      if (!changed && new URL(record.url).hostname === 'fixture.blob.core.windows.net') {
        changed = true; fs.appendFileSync(g.originalMessageFile, ' ');
      }
      return reply;
    }});
    await assert.rejects(run.result); assert.equal(changed, true);
  });
});

test('candidate ref drift during awaited artifact reads is refused by final actual custody', long, async () => {
  await scenario(async ({g, x, input}) => {
    let changed = false;
    const run = entry(x, input, {}, {mutate(record, reply) {
      if (!changed && new URL(record.url).hostname === 'fixture.blob.core.windows.net') {
        changed = true; g.setCandidate(g.sourceEdit);
      }
      return reply;
    }});
    await assert.rejects(run.result); assert.equal(changed, true);
  });
});

test('platform candidate head drift remains refused in client mode', long, async () => {
  await scenario(async ({x, input}) => {
    const changed = structuredClone(x.candidate); changed.head.sha = 'e'.repeat(40);
    const run = entry(x, input, {}, {afterFirstHead: changed});
    await assert.rejects(run.result);
  });
});

test('hosted artifact cannot grant construction to the client consumer', long, async () => {
  await scenario(async ({x, input}) => {
    x.result.limits.constructionAuthorized = true;
    const run = entry(x, input); await assert.rejects(run.result);
  });
});

test('head advancing only in the final post-custody observation refuses the joined result', long, async () => {
  await scenario(async ({x, input}) => {
    let heads = 0;
    const run = entry(x, input, {}, {mutate(record, reply) {
      if (record.url.endsWith('/pulls/4') && ++heads === 3) reply.body.head.sha = 'e'.repeat(40);
      return reply;
    }});
    await assert.rejects(run.result);
    assert.equal(heads, 3, 'Reached final observation after actual client custody');
  });
});
