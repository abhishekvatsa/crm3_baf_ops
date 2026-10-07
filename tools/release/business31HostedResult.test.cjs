'use strict';
const test = require('node:test'), assert = require('node:assert/strict'), f = require('./fixtures/business31HostedFixture.cjs');
const path = require('node:path'), cp = require('node:child_process'), crypto = require('node:crypto');
process.env.GITHUB_TOKEN = 'synthetic-token-never-a-real-credential';
test('actual consumer joins fake raw platform run/job/artifact and fresh head with no validator substitution', async () => { const x = f.fixture(), host = f.platform(x, {
    zipOptions: {
        streamed: true
    }
}); const out = await host.runConsumer({
    trust: x.trust, request: x.request
}); assert.deepEqual(out, {
    schemaVersion: 2, profile: x.trust.profile,
    verifier: x.result.verifier, source: x.result.source, candidate: x.result.candidate,
    descriptorPointer: x.result.descriptorPointer, closurePointer: x.result.closurePointer,
    commitments: x.result.commitments, runId: x.request.runId, runAttempt: x.request.runAttempt,
    artifactId: '71', resultSha256: crypto.createHash('sha256').update(JSON.stringify(x.result)).digest('hex').toUpperCase(),
    hostedRecordedReplayResultAuthenticated: true, ownerIdentityAuthenticated: false,
    originalProcessExecutionAuthenticated: false, deploymentAuthorized: false,
    constructionAuthorized: false, distributionAuthorized: false
}); assert.equal(host.requests.length, 11); const storage = host.requests.find(r => r.url.startsWith('https://fixture.blob')); assert.deepEqual(storage.headers, {}); assert.equal(host.requests.filter(r => r.url.includes('/pulls/4')).length, 2); });
for (const [name, mutate, expected] of [
    ['same-name foreign workflow', (r, v) => {
            if (r.url.endsWith('/actions/runs/42'))
                v.body.workflow_id = 99;
            return v;
        }, /RUN_ORIGIN/],
    ['failed job', (r, v) => {
            if (r.url.includes('/jobs?'))
                v.body.jobs[0].conclusion = 'failure';
            return v;
        }, /JOB_STATE/],
    ['extra artifact', (r, v) => {
            if (r.url.includes('/artifacts?'))
                v.body.total_count = 2;
            return v;
        }, /ARTIFACT_POPULATION/],
    ['expired artifact', (r, v) => {
            if (r.url.includes('/artifacts?'))
                v.body.artifacts[0].expired = true;
            return v;
        }, /ARTIFACT_IDENTITY/],
    ['artifact from previous attempt', (r, v) => {
            if (r.url.includes('/artifacts?'))
                v.body.artifacts[0].created_at = '2000-01-01T00:00:00.000Z';
            return v;
        }, /ARTIFACT_TIME/],
    ['wrong artifact digest', (r, v) => {
            if (r.url.includes('/artifacts?'))
                v.body.artifacts[0].digest = 'sha256:' + '0'.repeat(64);
            return v;
        }, /ARTIFACT_DIGEST/],
    ['redirect to arbitrary host', (r, v) => {
            if (r.url.endsWith('/artifacts/71/zip'))
                v.headers.location = 'https://attacker.invalid/';
            return v;
        }, /ARTIFACT_STORAGE_ORIGIN/],
    ['truncated HTTP body', (r, v) => {
            if (r.url.includes('/artifacts?'))
                v.complete = false;
            return v;
        }, /HTTP_INCOMPLETE/]
])
    test('consumer refuses ' + name, async () => { const x = f.fixture(), host = f.platform(x, {
        mutate
    }); await assert.rejects(host.runConsumer({
        trust: x.trust, request: x.request
    }), /No authenticated exact-head business replay result is available/); assert.ok(host.requests.length > 0); });
test('head advancing after artifact read refuses the otherwise genuine result', async () => { const x = f.fixture(), head = structuredClone(x.candidate); head.head.sha = 'a'.repeat(40); const host = f.platform(x, {
    afterFirstHead: head
}); await assert.rejects(host.runConsumer({
    trust: x.trust, request: x.request
}), /No authenticated exact-head business replay result is available/); assert.equal(host.requests.filter(r => r.url.includes('/pulls/4')).length, 2); });
test('caller cannot mutate selected input across awaited platform reads', async () => {
    const x = f.fixture();
    let changed = false;
    const host = f.platform(x, {
        mutate: (r, v) => {
            if (!changed) {
                changed = true;
                x.request.runAttempt = '2';
            }
            return v;
        }
    });
    const out = await host.runConsumer({
        trust: x.trust, request: x.request
    });
    assert.equal(out.runAttempt, '1');
});
test('operational library import refuses before any platform request', () => { assert.throws(() => require('./business31HostedResult.cjs'), /FRESH_ENTRY_REQUIRED/); assert.throws(() => require('./business31HostedReplay.cjs'), /FRESH_ENTRY_REQUIRED/); });
test('operational entry refuses an inherited helper cache before any platform request', async () => { const x = f.fixture(), host = f.platform(x); await assert.rejects(host.runConsumer({
    trust: x.trust, request: x.request
}, {
    preload: true
}), /FRESH_ENTRY_REQUIRED/); assert.equal(host.requests.length, 0); });
test('protocol exports cannot replace live observation or HTTPS functions', () => { const host = f.platform(f.fixture()); assert.equal(Object.isFrozen(host.protocol), true); assert.throws(() => { host.protocol.observe31 = () => ({
    pass: true
}); }, TypeError); assert.throws(() => { host.protocol.request31 = () => ({
    pass: true
}); }, TypeError); });

for (const [name, alter] of [
    ['verifier tree', v => { v.verifier.tree = 'a'.repeat(40); }],
    ['source functions tree', v => { v.source.functionsTree = 'a'.repeat(40); }],
    ['candidate tree', v => { v.candidate.tree = 'a'.repeat(40); }],
    ['candidate route', v => { v.candidate.ref = 'refs/heads/main'; }],
    ['descriptor commit', v => { v.descriptorPointer.commit = 'a'.repeat(40); }],
    ['closure path', v => { v.closurePointer.file = 'release/evidence/unselected.json'; }],
    ['closure digest', v => { v.closurePointer.sha256 = 'invalid'; }],
    ['source manifest', v => { v.commitments.sourceManifestSha256 = 'B'.repeat(64); }],
    ['missing commitment', v => { delete v.commitments.membersSha256; }],
    ['extra commitment', v => { v.commitments.rawEvidence = 'private'; }],
    ['authority elevation', v => { v.limits.constructionAuthorized = true; }]
]) test('expanded projection refuses an artifact with wrong ' + name, async () => {
    const x = f.fixture();
    // The base fixture intentionally shares source/candidate objects with the
    // selected inputs. Detach the artifact so each negative changes one side.
    x.result = structuredClone(x.result);
    alter(x.result);
    const host = f.platform(x);
    await assert.rejects(host.runConsumer({trust: x.trust, request: x.request}),
        /No authenticated exact-head business replay result is available/);
    assert.ok(host.requests.some(r => r.url.startsWith('https://fixture.blob')));
});

test('actual fake-platform consumer projection passes the real Python sanitizer', async () => {
    const x = f.fixture();
    x.result = structuredClone(x.result);
    x.result.closurePointer.sha256 = 'E'.repeat(64);
    x.result.commitments.bundleSha256 = 'B'.repeat(64);
    x.result.commitments.membersSha256 = 'C'.repeat(64);
    x.result.commitments.relocationSha256 = 'D'.repeat(64);
    const out = await f.platform(x).runConsumer({trust: x.trust, request: x.request});
    assert.deepEqual(out.closurePointer, x.result.closurePointer);
    assert.deepEqual(out.commitments, x.result.commitments);
    const raw = Buffer.from(JSON.stringify(out) + '\n');
    const python = process.env.BUSINESS31_TEST_PYTHON ||
        (process.platform === 'win32' ? 'C:/Python313/python.exe' : 'python3');
    const env = {};
    for (const key of ['SystemRoot', 'WINDIR', 'PATH', 'HOME', 'USERPROFILE', 'TEMP', 'TMP']) {
        if (process.env[key] !== undefined) env[key] = process.env[key];
    }
    // Existing local Python only: import the source and call its pure sanitizer.
    // No launcher dispatch, network, credentials or hosted process qualification.
    const script = [
        'import importlib.util, json, sys',
        'spec = importlib.util.spec_from_file_location("projection_sanitizer", sys.argv[1])',
        'module = importlib.util.module_from_spec(spec)',
        'spec.loader.exec_module(module)',
        'data = json.loads(sys.stdin.buffer.read())',
        'raw = bytes.fromhex(data["projectionHex"])',
        'sys.stdout.buffer.write(module.sanitized_consumer_output(raw, data["trust"], data["request"]))'
    ].join('\n');
    const result = cp.spawnSync(python, ['-I', '-S', '-B', '-c', script,
        path.join(__dirname, 'business31HostedLauncher.py')], {
        input: JSON.stringify({projectionHex: raw.toString('hex'), trust: x.trust, request: x.request}),
        env, windowsHide: true, timeout: 15000, maxBuffer: 1024 * 1024
    });
    assert.ifError(result.error);
    assert.equal(result.signal, null);
    assert.equal(result.status, 0, result.stderr?.toString('utf8'));
    assert.equal(result.stderr.length, 0);
    assert.deepEqual(result.stdout, raw);
});
