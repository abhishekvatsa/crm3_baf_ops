'use strict';
const test = require('node:test'), assert = require('node:assert/strict'), p = require('./business31HostedProtocol.cjs'), f = require('./fixtures/business31HostedFixture.cjs');
const key = f.keys();
test('synthetic signed GitHub token binds exact selected workflow V and run', () => { const x = f.fixture(); assert.equal(p.verifyOidc31(f.signed(x.claims, key), key.jwks, x.trust, x.request).run_id, '42'); });
for (const [name, alter] of [
    ['candidate-selected verifier', x => { x.claims.workflow_sha = 'a'.repeat(40); }], ['foreign repository', x => { x.claims.repository_id = '8'; }], ['wrong audience', x => { x.claims.aud += 'other'; }], ['unprotected environment', x => { delete x.claims.environment; }], ['pull request credential context', x => { x.claims.event_name = 'pull_request'; }], ['self hosted runner', x => { x.claims.runner_environment = 'self-hosted'; }], ['stale attempt', x => { x.claims.run_attempt = '2'; }], ['wrong actor', x => { x.claims.actor_id = '10'; }], ['expired credential', x => { x.claims.exp = Math.floor(Date.now() / 1000) - 1; }], ['future issuance', x => { x.claims.iat += 600; x.claims.nbf += 600; x.claims.exp += 600; }]
])
    test('signed token refuses ' + name, () => { const x = f.fixture(); alter(x); assert.throws(() => p.verifyOidc31(f.signed(x.claims, key), key.jwks, x.trust, x.request), /BUSINESS_HOSTED_OIDC_/); });
test('signature cannot be replaced by valid-looking claims', () => { const x = f.fixture(), other = f.keys(); assert.throws(() => p.verifyOidc31(f.signed(x.claims, other), key.jwks, x.trust, x.request), /OIDC_SIGNATURE/); });
test('exact run identity refuses same-name wrong workflow and non-completed result', () => { const x = f.fixture(); p.validateRun31(x.run, x.trust, x.request, true); x.run.workflow_id = 8; assert.throws(() => p.validateRun31(x.run, x.trust, x.request, true), /RUN_ORIGIN/); x.run.workflow_id = 7; x.run.status = 'in_progress'; assert.throws(() => p.validateRun31(x.run, x.trust, x.request, true), /RUN_STATE/); });
test('fixed job population refuses missing extra failed or wrong-head jobs', () => {
    for (const which of [
        'missing', 'extra', 'failed', 'head'
    ]) {
        const x = f.fixture(), body = {
            total_count: 1, jobs: [x.job]
        };
        if (which === 'missing') {
            body.total_count = 0;
            body.jobs = [];
        }
        if (which === 'extra') {
            body.total_count = 2;
            body.jobs.push({
                ...x.job, id: 52
            });
        }
        if (which === 'failed')
            x.job.conclusion = 'failure';
        if (which === 'head')
            x.job.head_sha = 'a'.repeat(40);
        assert.throws(() => p.validateJobs31(body, x.trust, x.request, true), /JOB_/);
    }
});
test('candidate validation refuses forks and stale head', () => { const x = f.fixture(); x.candidate.head.repo.id = 2; assert.throws(() => p.validateCandidate31(x.candidate, x.trust, x.request), /STALE_OR_FORK/); x.candidate.head.repo.id = 1; x.candidate.head.sha = 'a'.repeat(40); assert.throws(() => p.validateCandidate31(x.candidate, x.trust, x.request), /STALE_OR_FORK/); });
for (const streamed of [false, true])
    test('single bounded result ZIP accepts ' + (streamed ? 'streamed' : 'normal') + ' raw archive', () => { const x = f.fixture(); assert.deepEqual(p.json(p.singleResultZip31(f.zip(x.result, {
        streamed
    }))), x.result); });
test('artifact ZIP rejects alternate name appended data and corruption', () => { const x = f.fixture(); assert.throws(() => p.singleResultZip31(f.zip(x.result, {
    name: '../result.json'
})), /ZIP_NAME/); assert.throws(() => p.singleResultZip31(Buffer.concat([f.zip(x.result), Buffer.from('x')])), /ZIP_DIRECTORY/); const raw = f.zip(x.result, {
    method: 0
}); raw[60] ^= 1; assert.throws(() => p.singleResultZip31(raw), /ZIP_CONTENT/); });
test('result excludes private data and authority additions', () => { const x = f.fixture(); p.validateResult31(x.result, x.trust, x.request); x.result.rawEvidence = 'private'; assert.throws(() => p.validateResult31(x.result, x.trust, x.request), /RESULT_FIELDS/); delete x.result.rawEvidence; x.result.limits.deploymentAuthorized = true; assert.throws(() => p.validateResult31(x.result, x.trust, x.request), /RESULT_LIMITS/); });
test('result bounds current time and exact candidate commitments', () => { const x = f.fixture(); x.result.completedAtUtc = new Date(Date.now() + 100000).toISOString(); assert.throws(() => p.validateResult31(x.result, x.trust, x.request), /RESULT_TIME/); x.result.completedAtUtc = new Date(Date.now() - 2000).toISOString(); x.result.candidate = {
    ...x.result.candidate, commit: 'a'.repeat(40)
}; assert.throws(() => p.validateResult31(x.result, x.trust, x.request), /RESULT_S/); });

// Transient transport faults are retried a bounded number of times; refusals and
// validation failures never are. Waits use the global setTimeout, so these tests
// drive them with mocked timers instead of sleeping.
const TOKEN = 'synthetic-token-never-a-real-credential';
const fault = code => Object.assign(Error('synthetic transport fault'), { code });
async function settle(t, promise) {
    let settled = false;
    promise.then(() => { settled = true; }, () => { settled = true; });
    for (let i = 0; !settled && i < 100000; i++) {
        await new Promise(resolve => setImmediate(resolve));
        t.mock.timers.tick(1000);
    }
    return promise;
}
test('request31 marks only transport faults and HTTP 429/5xx as transient', async () => {
    const replies = [{ status: 502, body: {} }, { status: 429, body: {} }, { status: 503, body: {} }, { status: 404, body: {} },
        { status: 403, body: {} }, { status: 401, body: {} }, fault('ECONNRESET'), fault('EAI_AGAIN'), fault('ETIMEDOUT'),
        Error('Unplanned synthetic request')];
    const host = f.loadFakePlatform((record, n) => { const reply = replies[n - 1]; if (reply instanceof Error) throw reply; return reply; });
    const seen = [];
    for (let i = 0; i < replies.length; i++)
        await assert.rejects(host.protocol.request31('https://api.github.com/repos/fixture/repository'), error => {
            seen.push([error.message, error.status ?? null, error.transient]); return true; });
    assert.deepEqual(seen, [
        ['BUSINESS_HOSTED_HTTP_STATUS', 502, true], ['BUSINESS_HOSTED_HTTP_STATUS', 429, true],
        ['BUSINESS_HOSTED_HTTP_STATUS', 503, true], ['BUSINESS_HOSTED_HTTP_STATUS', 404, false],
        ['BUSINESS_HOSTED_HTTP_STATUS', 403, false], ['BUSINESS_HOSTED_HTTP_STATUS', 401, false],
        ['BUSINESS_HOSTED_HTTP_REQUEST', null, true], ['BUSINESS_HOSTED_HTTP_REQUEST', null, true],
        ['BUSINESS_HOSTED_HTTP_REQUEST', null, true], ['BUSINESS_HOSTED_HTTP_REQUEST', null, false]]);
});
test('a body cut short by the peer is retried; an encoded body is refused at once', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const x = f.fixture();
    const cut = f.loadFakePlatform((record, n) => n === 1 ? { complete: false, body: { partial: true } } : { body: x.repository });
    assert.deepEqual(await settle(t, cut.protocol.github31(x.trust, '', TOKEN)), x.repository);
    assert.equal(cut.requests.length, 2);
    const once = f.loadFakePlatform(() => ({ complete: false, body: {} }));
    await assert.rejects(once.protocol.request31('https://api.github.com/repos/fixture/repository'),
        e => e.message === 'BUSINESS_HOSTED_HTTP_INCOMPLETE' && e.transient === true);
    for (const complete of [true, false]) {
        const encoded = f.loadFakePlatform(() => ({ complete, headers: { 'content-encoding': 'gzip' }, body: x.repository }));
        await assert.rejects(settle(t, encoded.protocol.github31(x.trust, '', TOKEN)),
            e => e.message === 'BUSINESS_HOSTED_HTTP_INCOMPLETE' && e.transient === undefined);
        assert.equal(encoded.requests.length, 1);
    }
});
test('retry31 repeats only transient faults and stops after its bounded schedule', async () => {
    let calls = 0;
    const transient = () => { calls++; throw Object.assign(Error('BUSINESS_HOSTED_HTTP_STATUS'), { status: 503, transient: true }); };
    await assert.rejects(p.retry31(transient, [0, 0, 0]), /BUSINESS_HOSTED_HTTP_STATUS/);
    assert.equal(calls, 4);
    calls = 0;
    await assert.rejects(p.retry31(() => { calls++; throw Object.assign(Error('BUSINESS_HOSTED_HTTP_STATUS'), { status: 404, transient: false }); }, [0, 0, 0]),
        /BUSINESS_HOSTED_HTTP_STATUS/);
    assert.equal(calls, 1);
    calls = 0;
    await assert.rejects(p.retry31(() => { calls++; throw Error('BUSINESS_HOSTED_RUN_ORIGIN'); }, [0, 0, 0]), /RUN_ORIGIN/);
    assert.equal(calls, 1);
    calls = 0;
    assert.equal(await p.retry31(() => { if (++calls < 3) throw Object.assign(Error('x'), { transient: true }); return 'ok'; }, [0, 0, 0]), 'ok');
    assert.equal(calls, 3);
    assert.deepEqual(p.RETRY_DELAYS_MS, [2000, 5000, 10000, 20000, 30000]);
    assert.equal(Object.isFrozen(p.RETRY_DELAYS_MS), true);
});
test('github31 repeats an identical GET after a 502 and a reset connection, then returns the reply', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const x = f.fixture();
    const host = f.loadFakePlatform((record, n) => {
        if (n === 1) return { status: 502, body: { message: 'synthetic bad gateway' } };
        if (n === 2) throw fault('ECONNRESET');
        return { body: x.repository };
    });
    assert.deepEqual(await settle(t, host.protocol.github31(x.trust, '', TOKEN)), x.repository);
    assert.equal(host.requests.length, 3);
    assert.ok(host.requests.every(r => r.method === 'GET' && r.url === host.requests[0].url &&
        r.headers.Authorization === 'Bearer ' + TOKEN));
});
test('github31 never repeats a refusal and gives up after its bounded schedule', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const x = f.fixture();
    for (const status of [400, 401, 403, 404, 422]) {
        const host = f.loadFakePlatform(() => ({ status, body: {} }));
        await assert.rejects(settle(t, host.protocol.github31(x.trust, '', TOKEN)), e => e.status === status && e.transient === false);
        assert.equal(host.requests.length, 1, String(status));
    }
    const unavailable = f.loadFakePlatform(() => ({ status: 503, body: {} }));
    await assert.rejects(settle(t, unavailable.protocol.github31(x.trust, '', TOKEN)), e => e.status === 503 && e.transient === true);
    assert.equal(unavailable.requests.length, 1 + p.RETRY_DELAYS_MS.length);
    const unplanned = f.loadFakePlatform(() => { throw Error('Unplanned synthetic request'); });
    await assert.rejects(settle(t, unplanned.protocol.github31(x.trust, '', TOKEN)), /BUSINESS_HOSTED_HTTP_REQUEST/);
    assert.equal(unplanned.requests.length, 1);
});
test('a POST is repeated only where its caller wraps it, and a 2xx other than 200 is never accepted', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const once = f.loadFakePlatform(() => ({ status: 503, body: {} }));
    await assert.rejects(once.protocol.request31('https://sts.googleapis.com/v1/token', { method: 'POST', body: Buffer.from('a=b') }), e => e.status === 503);
    assert.equal(once.requests.length, 1);
    const wrapped = f.loadFakePlatform((record, n) => n === 1 ? { status: 503, body: {} } : { body: { ok: true } });
    const reply = await settle(t, wrapped.protocol.retry31(() => wrapped.protocol.request31('https://sts.googleapis.com/v1/token', { method: 'POST', body: Buffer.from('a=b') })));
    assert.deepEqual(JSON.parse(reply.bytes), { ok: true });
    assert.deepEqual(wrapped.requests.map(r => r.method), ['POST', 'POST']);
    const created = f.loadFakePlatform(() => ({ status: 201, body: {} }));
    await assert.rejects(settle(t, created.protocol.retry31(() => created.protocol.request31('https://api.github.com/x'))), e => e.status === 201 && e.transient === false);
    assert.equal(created.requests.length, 1);
});
test('an empty artifact listing right after completion is re-read briefly; population checks are unchanged', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const x = f.fixture();
    let listings = 0;
    const host = f.platform(x, { mutate: (r, v) => {
        if (r.url.includes('/artifacts?') && ++listings === 1) v.body = { total_count: 0, artifacts: [] };
        return v;
    } });
    const out = await settle(t, host.protocol.retrieveResult31(x.trust, x.request, TOKEN));
    assert.equal(out.artifactId, '71');
    assert.equal(listings, 2);
    assert.equal(host.requests.length, 12);
    const y = f.fixture();
    const empty = f.platform(y, { mutate: (r, v) => { if (r.url.includes('/artifacts?')) v.body = { total_count: 0, artifacts: [] }; return v; } });
    await assert.rejects(settle(t, empty.protocol.retrieveResult31(y.trust, y.request, TOKEN)), /ARTIFACT_POPULATION/);
    assert.equal(empty.requests.filter(r => r.url.includes('/artifacts?')).length, 1 + p.ARTIFACT_LISTING_DELAYS_MS.length);
    const z = f.fixture();
    const two = f.platform(z, { mutate: (r, v) => { if (r.url.includes('/artifacts?')) v.body.total_count = 2; return v; } });
    await assert.rejects(settle(t, two.protocol.retrieveResult31(z.trust, z.request, TOKEN)), /ARTIFACT_POPULATION/);
    assert.equal(two.requests.filter(r => r.url.includes('/artifacts?')).length, 1);
});
test('a failed artifact download asks GitHub for a fresh signed location; a refusal is not repeated', async t => {
    t.mock.timers.enable({ apis: ['setTimeout'] });
    const blob = r => r.url.startsWith('https://fixture.blob.core.windows.net/');
    const x = f.fixture();
    let blobs = 0;
    const host = f.platform(x, { mutate: (r, v) => (blob(r) && ++blobs === 1) ? { status: 503, body: {} } : v });
    const out = await settle(t, host.protocol.retrieveResult31(x.trust, x.request, TOKEN));
    assert.equal(out.artifactId, '71');
    assert.equal(host.requests.filter(r => r.url.endsWith('/actions/artifacts/71/zip')).length, 2);
    assert.equal(blobs, 2);
    assert.ok(host.requests.filter(blob).every(r => r.headers.Authorization === undefined));
    const y = f.fixture();
    const denied = f.platform(y, { mutate: (r, v) => blob(r) ? { status: 403, body: {} } : v });
    await assert.rejects(settle(t, denied.protocol.retrieveResult31(y.trust, y.request, TOKEN)), e => e.status === 403);
    assert.equal(denied.requests.filter(r => r.url.endsWith('/actions/artifacts/71/zip')).length, 1);
    const z = f.fixture();
    const foreign = f.platform(z, { mutate: (r, v) => {
        if (r.url.endsWith('/zip')) v.headers = { location: 'https://storage.example.invalid/result?sig=synthetic' };
        return v;
    } });
    await assert.rejects(settle(t, foreign.protocol.retrieveResult31(z.trust, z.request, TOKEN)), /ARTIFACT_STORAGE_ORIGIN/);
    assert.equal(foreign.requests.filter(r => r.url.endsWith('/zip')).length, 1);
});
