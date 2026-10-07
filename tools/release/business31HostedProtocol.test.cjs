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
