'use strict';
// Runs only from an independently selected, immutable, clean verifier process.
// This module validates platform messages; it cannot authenticate its own install.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), https = require('node:https'), zlib = require('node:zlib');
const { isDeepStrictEqual, TextDecoder } = require('node:util');
const PROFILE = 'build31-business-hosted-recorded-replay-v1';
const ISSUER = 'https://token.actions.githubusercontent.com';
const RESULT_NAME = 'business31-hosted-result.json';
const SELF = 'tools/release/business31HostedProtocol.cjs';
const SUPPORT_PRODUCERS = Object.freeze(['tools/release/runtime_process_runner.py','tools/release/runtime_supervisor.py','tools/release/business31HostedLauncher.py','tools/release/runtime_contract_bindings.json','tools/release/business31ToolchainProfiles.json']);
const ENTRIES = [SELF, 'tools/release/business31HostedReplay.cjs', 'tools/release/business31HostedResult.cjs'];
const sha = b => crypto.createHash('sha256').update(b).digest('hex').toUpperCase();
const need = (ok, code) => {
    if (!ok)
        throw Error('BUSINESS_HOSTED_' + code);
};
const same = (a, b, code) => need(isDeepStrictEqual(a, b), code);
function exact(o, keys, code) { need(o && typeof o === 'object' && !Array.isArray(o) && [Object.prototype, null].includes(Object.getPrototypeOf(o)), code); same(Object.keys(o).sort(), [...keys].sort(), code); }
const oid = v => typeof v === 'string' && /^[a-f0-9]{40}$/.test(v);
const digest = v => typeof v === 'string' && /^[A-F0-9]{64}$/.test(v);
const id = v => typeof v === 'string' && /^[1-9][0-9]{0,19}$/.test(v);
function json(raw, limit = 2 * 1024 * 1024) {
    need(Buffer.isBuffer(raw) && raw.length > 0 && raw.length <= limit, 'JSON_BOUND');
    const o = JSON.parse(new TextDecoder('utf-8', {
        fatal: true
    }).decode(raw));
    let n = 0;
    const pending = [[o, 0]];
    while (pending.length) {
        const [v, d] = pending.pop();
        need(++n <= 50000 && d <= 32, 'JSON_COMPLEXITY');
        if (v && typeof v === 'object')
            for (const item of Object.values(v))
                pending.push([item, d + 1]);
    }
    return o;
}
function regular(file, directory = false) {
    need(typeof file === 'string' && path.isAbsolute(file), 'ABSOLUTE_PATH');
    const p = path.resolve(file);
    let cursor = path.parse(p).root;
    for (const part of p.slice(cursor.length).split(path.sep).filter(Boolean)) {
        cursor = path.join(cursor, part);
        need(!fs.lstatSync(cursor).isSymbolicLink(), 'PATH_REDIRECT');
    }
    const s = fs.lstatSync(p);
    need(directory ? s.isDirectory() : s.isFile(), 'REGULAR_PATH');
    return p;
}
function source(v, functions = false) { exact(v, functions ? ['commit', 'tree', 'functionsTree'] : ['commit', 'tree'], 'SOURCE'); need(Object.values(v).every(oid), 'SOURCE_ID'); }
function pointer(v) { exact(v, ['commit', 'file', 'sha256'], 'DESCRIPTOR_POINTER'); need(oid(v.commit) && v.file === 'release/evidence/build31-business-private-replay.json' && digest(v.sha256), 'DESCRIPTOR_POINTER'); }
function validateTrust31(t) {
    exact(t, [
        'schemaVersion', 'profile', 'repository', 'workflow', 'verifier', 'source', 'sourceManifestSha256', 'nodeSha256', 'gitSha256', 'launcherSha256', 'pythonSha256', 'wifAudience', 'maximumResultAgeSeconds'
    ], 'TRUST_FIELDS');
    need(t.schemaVersion === 1 && t.profile === PROFILE, 'TRUST_PROFILE');
    exact(t.repository, ['name', 'id', 'ownerId'], 'REPOSITORY');
    need(/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(t.repository.name) && id(t.repository.id) && id(t.repository.ownerId), 'REPOSITORY');
    exact(t.workflow, [
        'id', 'path', 'ref', 'environment', 'jobName', 'actorIds'
    ], 'WORKFLOW');
    need(id(t.workflow.id) && /^\.github\/workflows\/[a-z0-9-]+\.yml$/.test(t.workflow.path) && /^refs\/(heads|tags)\/[A-Za-z0-9_./-]+$/.test(t.workflow.ref) && !t.workflow.ref.includes('..'), 'WORKFLOW_ID');
    need(/^[A-Za-z0-9_-]{1,80}$/.test(t.workflow.environment) && t.workflow.jobName === 'Business private replay' && Array.isArray(t.workflow.actorIds) && t.workflow.actorIds.length > 0 && t.workflow.actorIds.length <= 8 && t.workflow.actorIds.every(id) && new Set(t.workflow.actorIds).size === t.workflow.actorIds.length, 'WORKFLOW_AUTHORITY');
    exact(t.verifier, ['commit', 'tree', 'files'], 'VERIFIER');
    need(oid(t.verifier.commit) && oid(t.verifier.tree), 'VERIFIER');
    source(t.source, true);
    need(t.verifier.files && typeof t.verifier.files === 'object' && !Array.isArray(t.verifier.files) && Object.keys(t.verifier.files).length <= 256 && ENTRIES.every(f => Object.hasOwn(t.verifier.files, f)), 'VERIFIER_POPULATION');
    for (const [f, h] of Object.entries(t.verifier.files))
        need((/^tools\/release\/[A-Za-z0-9_+./-]+\.(js|cjs|ps1)$/.test(f) || f === 'tools/v4/v4_2_r1_canonical_audit.py' || SUPPORT_PRODUCERS.includes(f)) && f.split('/').every(p => p && p !== '.' && p !== '..') && digest(h), 'VERIFIER_MEMBER');
    need([
        t.sourceManifestSha256, t.nodeSha256, t.gitSha256, t.launcherSha256, t.pythonSha256
    ].every(digest), 'TRUST_DIGEST');
    need(/^\/\/iam\.googleapis\.com\/projects\/[1-9][0-9]+\/locations\/global\/workloadIdentityPools\/[a-z0-9-]+\/providers\/[a-z0-9-]+$/.test(t.wifAudience), 'WIF_AUDIENCE');
    need(Number.isInteger(t.maximumResultAgeSeconds) && t.maximumResultAgeSeconds >= 60 && t.maximumResultAgeSeconds <= 86400, 'RESULT_AGE');
    return t;
}
function readTrustedConfiguration31(file, expectedSha256) { need(digest(expectedSha256), 'EXTERNAL_CONFIG_COMMITMENT'); const bytes = fs.readFileSync(regular(file)); need(sha(bytes) === expectedSha256, 'CONFIG_DIGEST'); return validateTrust31(json(bytes)); }
function validateChallenge31(c, candidate) {
    exact(c, ['schemaVersion', 'nonce', 'purpose', 'requestedAtUtc', 'expiresAtUtc',
        'requester', 'clientSelectionSha256', 'fileBindings'], 'CHALLENGE');
    need(c.schemaVersion === 1 && /^[a-f0-9]{64}$/.test(c.nonce) &&
        ['policy', 'construction', 'package-verification'].includes(c.purpose) &&
        digest(c.clientSelectionSha256), 'CHALLENGE_IDENTITY');
    for (const value of [c.requestedAtUtc, c.expiresAtUtc])
        need(typeof value === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(value) &&
            Number.isFinite(Date.parse(value)), 'CHALLENGE_DATE');
    const duration = Date.parse(c.expiresAtUtc) - Date.parse(c.requestedAtUtc);
    need(duration > 0 && duration <= 150 * 60 * 1000, 'CHALLENGE_DURATION');
    exact(c.requester, ['kind', 'runId', 'runAttempt', 'invocationId'], 'CHALLENGE_REQUESTER');
    need(/^[a-f0-9]{64}$/.test(c.requester.invocationId), 'CHALLENGE_INVOCATION');
    if (c.requester.kind === 'github-actions')
        need(id(c.requester.runId) && id(c.requester.runAttempt), 'CHALLENGE_REQUESTER');
    else
        need(c.requester.kind === 'local' && c.requester.runId === null && c.requester.runAttempt === null,
            'CHALLENGE_REQUESTER');
    if (c.purpose === 'construction')
        need(candidate.kind === 'main' && c.requester.kind === 'github-actions', 'CONSTRUCTION_REQUESTER');
    need(Array.isArray(c.fileBindings) && c.fileBindings.length <= 10, 'CHALLENGE_FILES');
    for (const file of c.fileBindings) {
        exact(file, ['role', 'name', 'sha256', 'bytes'], 'CHALLENGE_FILE');
        need(['source-archive', 'manifest', 'package'].includes(file.role) &&
            typeof file.name === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,179}$/.test(file.name) &&
            !file.name.includes('..') && digest(file.sha256) && Number.isSafeInteger(file.bytes) &&
            file.bytes > 0 && file.bytes <= 4 * 1024 * 1024 * 1024, 'CHALLENGE_FILE');
    }
    need(new Set(c.fileBindings.map(f => f.name)).size === c.fileBindings.length, 'CHALLENGE_DUPLICATE_FILE');
    if (c.purpose === 'package-verification')
        need(candidate.kind === 'main' && c.fileBindings.filter(f => f.role === 'source-archive').length === 1 &&
            c.fileBindings.filter(f => f.role === 'manifest').length === 1 &&
            c.fileBindings.some(f => f.role === 'package'), 'CHALLENGE_PACKAGE_FILES');
    else need(c.fileBindings.length === 0, 'CHALLENGE_UNEXPECTED_FILES');
    return c;
}
function validateRequest31(r) {
    exact(r, [
        'schemaVersion', 'candidate', 'descriptorPointer', 'runId', 'runAttempt',
        ...(r?.schemaVersion === 2 ? ['challenge'] : [])
    ], 'REQUEST');
    need([1, 2].includes(r.schemaVersion) && id(r.runId) && id(r.runAttempt), 'REQUEST_ID');
    exact(r.candidate, [
        'commit', 'tree', 'ref', 'kind', 'pullRequest'
    ], 'CANDIDATE');
    need(oid(r.candidate.commit) && oid(r.candidate.tree), 'CANDIDATE_ID');
    if (r.candidate.kind === 'main')
        need(r.candidate.ref === 'refs/heads/main' && r.candidate.pullRequest === null, 'MAIN_REQUEST');
    else
        need(r.candidate.kind === 'pull_request' && Number.isSafeInteger(r.candidate.pullRequest) && r.candidate.pullRequest > 0 && r.candidate.ref === 'refs/pull/' + r.candidate.pullRequest + '/head', 'PR_REQUEST');
    pointer(r.descriptorPointer);
    if (r.schemaVersion === 2) validateChallenge31(r.challenge, r.candidate);
    return r;
}
function verifyExecuting31(t, root) {
    regular(root, true);
    need(sha(fs.readFileSync(regular(process.execPath))) === t.nodeSha256, 'NODE_IDENTITY');
    for (const [f, h] of Object.entries(t.verifier.files))
        need(sha(fs.readFileSync(regular(path.join(root, ...f.split('/'))))) === h, 'EXECUTING_PRODUCER');
    return true;
}
function validateRepository31(body, t) { need(body && String(body.id) === t.repository.id && body.full_name === t.repository.name && String(body.owner?.id) === t.repository.ownerId && body.private === false, 'LIVE_REPOSITORY'); }
function validateCandidate31(body, t, r) {
    if (r.candidate.kind === 'main') {
        need(body.ref === 'refs/heads/main' && body.object?.type === 'commit' && body.object.sha === r.candidate.commit, 'STALE_MAIN');
    }
    else {
        need(body.number === r.candidate.pullRequest && body.state === 'open' && body.head?.sha === r.candidate.commit && String(body.head.repo?.id) === t.repository.id && body.head.repo?.full_name === t.repository.name && body.base?.ref === 'main' && String(body.base.repo?.id) === t.repository.id, 'STALE_OR_FORK_PR');
    }
    return true;
}
function validateRun31(run, t, r, complete = false) {
    need(run && String(run.id) === r.runId && String(run.run_attempt) === r.runAttempt && String(run.workflow_id) === t.workflow.id && run.path === t.workflow.path && run.head_sha === t.verifier.commit && run.event === 'workflow_dispatch' && run.head_branch === t.workflow.ref.replace(/^refs\/(heads|tags)\//, '') && String(run.repository?.id) === t.repository.id && String(run.head_repository?.id) === t.repository.id, 'RUN_ORIGIN');
    need(t.workflow.actorIds.includes(String(run.actor?.id)) && String(run.triggering_actor?.id) === String(run.actor?.id), 'RUN_ACTOR');
    need(complete ? run.status === 'completed' && run.conclusion === 'success' : run.status === 'in_progress' && run.conclusion === null, 'RUN_STATE');
    return true;
}
function validateJobs31(body, t, r, complete = false) { need(body && body.total_count === 1 && Array.isArray(body.jobs) && body.jobs.length === 1, 'JOB_POPULATION'); const job = body.jobs[0]; need(job.name === t.workflow.jobName && String(job.run_id) === r.runId && (job.run_attempt === undefined || String(job.run_attempt) === r.runAttempt) && job.head_sha === t.verifier.commit && Number.isSafeInteger(job.id), 'JOB_IDENTITY'); need(complete ? job.status === 'completed' && job.conclusion === 'success' : job.status === 'in_progress' && job.conclusion === null, 'JOB_STATE'); return job; }
function verifyOidc31(token, jwks, t, r, nowSeconds = Math.floor(Date.now() / 1000)) {
    need(typeof token === 'string' && token.length <= 16384, 'OIDC_BOUND');
    const parts = token.split('.');
    need(parts.length === 3 && parts.every(p => /^[A-Za-z0-9_-]+$/.test(p)), 'OIDC_FORMAT');
    const head = json(Buffer.from(parts[0], 'base64url'), 4096), claims = json(Buffer.from(parts[1], 'base64url'), 12000);
    exact(head, Object.hasOwn(head, 'x5t') ? [
        'alg', 'kid', 'typ', 'x5t'
    ] : ['alg', 'kid', 'typ'], 'OIDC_HEADER');
    need(head.alg === 'RS256' && head.typ === 'JWT' && typeof head.kid === 'string' && (!Object.hasOwn(head, 'x5t') || /^[A-Za-z0-9_-]+$/.test(head.x5t)), 'OIDC_ALGORITHM');
    need(jwks && Array.isArray(jwks.keys) && jwks.keys.length > 0 && jwks.keys.length <= 16, 'OIDC_KEYS');
    const matched = jwks.keys.filter(k => k.kid === head.kid && k.kty === 'RSA' && k.use === 'sig' && k.alg === 'RS256');
    need(matched.length === 1, 'OIDC_KEY');
    const key = crypto.createPublicKey({
        key: matched[0], format: 'jwk'
    });
    need(crypto.verify('RSA-SHA256', Buffer.from(parts[0] + '.' + parts[1]), key, Buffer.from(parts[2], 'base64url')), 'OIDC_SIGNATURE');
    const expected = {
        iss: ISSUER, aud: t.wifAudience, repository: t.repository.name, repository_id: t.repository.id, repository_owner_id: t.repository.ownerId, repository_visibility: 'public', workflow_ref: t.repository.name + '/' + t.workflow.path + '@' + t.workflow.ref, workflow_sha: t.verifier.commit, sha: t.verifier.commit, ref: t.workflow.ref, event_name: 'workflow_dispatch', run_id: r.runId, run_attempt: r.runAttempt, runner_environment: 'github-hosted', environment: t.workflow.environment, sub: 'repo:' + t.repository.name + ':environment:' + t.workflow.environment
    };
    for (const [k, v] of Object.entries(expected))
        need(claims[k] === v, 'OIDC_CLAIM_' + k.toUpperCase());
    need(t.workflow.actorIds.includes(claims.actor_id), 'OIDC_ACTOR');
    need([claims.iat, claims.nbf, claims.exp].every(Number.isInteger) && claims.iat <= nowSeconds + 30 && claims.nbf <= nowSeconds + 30 && claims.exp > nowSeconds && claims.exp - claims.iat > 0 && claims.exp - claims.iat <= 600 && nowSeconds - claims.iat <= 600, 'OIDC_TIME');
    return claims;
}
function request31(url, { method = 'GET', headers = {}, body = null, maxBytes = 2 * 1024 * 1024, redirect = false } = {}) {
    const u = new URL(url);
    need(u.protocol === 'https:' && !u.username && !u.password && (!u.port || u.port === '443'), 'HTTPS_ENDPOINT');
    return new Promise((resolve, reject) => {
        const req = https.request(u, {
            method, headers, timeout: 30000
        }, res => {
            let count = 0;
            const chunks = [];
            res.on('data', b => {
                count += b.length;
                if (count > maxBytes) {
                    req.destroy();
                    reject(Error('BUSINESS_HOSTED_HTTP_BOUND'));
                }
                else
                    chunks.push(b);
            });
            res.on('aborted', () => reject(Error('BUSINESS_HOSTED_HTTP_TRUNCATED')));
            res.on('error', () => reject(Error('BUSINESS_HOSTED_HTTP_RESPONSE')));
            res.on('end', () => {
                if (!res.complete || res.headers['content-encoding'])
                    return reject(Error('BUSINESS_HOSTED_HTTP_INCOMPLETE'));
                if (res.statusCode !== 200 && !(redirect && res.statusCode === 302))
                    return reject(Error('BUSINESS_HOSTED_HTTP_STATUS'));
                resolve({
                    status: res.statusCode, headers: res.headers, bytes: Buffer.concat(chunks)
                });
            });
        });
        req.on('timeout', () => req.destroy(Error('BUSINESS_HOSTED_HTTP_TIMEOUT')));
        req.on('error', () => reject(Error('BUSINESS_HOSTED_HTTP_REQUEST')));
        if (body)
            req.end(body);
        else
            req.end();
    });
}
function token(v) { need(typeof v === 'string' && v.length >= 20 && v.length <= 16384 && !/[\r\n]/.test(v), 'TOKEN_UNAVAILABLE'); return v; }
async function github31(t, suffix, accessToken) {
    need((suffix === '' || suffix.startsWith('/')) && !suffix.includes('..'), 'GITHUB_PATH');
    return json((await request31('https://api.github.com/repos/' + t.repository.name + suffix, {
        headers: {
            Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'business31-trusted-replay', Authorization: 'Bearer ' + token(accessToken)
        }
    })).bytes);
}
async function observe31(t, r, accessToken, complete = false) { const repository = await github31(t, '', accessToken); validateRepository31(repository, t); const run = await github31(t, '/actions/runs/' + r.runId, accessToken); validateRun31(run, t, r, complete); const jobs = await github31(t, '/actions/runs/' + r.runId + '/attempts/' + r.runAttempt + '/jobs?per_page=100', accessToken); const job = validateJobs31(jobs, t, r, complete); const candidate = await github31(t, r.candidate.kind === 'main' ? '/git/ref/heads/main' : '/pulls/' + r.candidate.pullRequest, accessToken); validateCandidate31(candidate, t, r); return {
    run, job
}; }
function artifactName31(r) { return 'business31-hosted-' + r.candidate.commit + '-' + r.runId + '-' + r.runAttempt; }
// Shared read-only artifact authentication. Callers still own fresh-process,
// independent configuration and any operational prerequisite/authority checks.
async function retrieveResult31(trust, request, accessToken) {
    validateTrust31(trust); validateRequest31(request);
    const observed = await observe31(trust, request, accessToken, true);
    const rows = await github31(trust, '/actions/runs/' + request.runId + '/artifacts?per_page=100', accessToken);
    need(rows.total_count === 1 && Array.isArray(rows.artifacts) && rows.artifacts.length === 1, 'ARTIFACT_POPULATION');
    const a = rows.artifacts[0];
    need(Number.isSafeInteger(a.id) && a.name === artifactName31(request) && a.expired === false &&
        Number.isSafeInteger(a.size_in_bytes) && a.size_in_bytes > 0 && a.size_in_bytes <= 1024 * 1024 &&
        /^sha256:[a-f0-9]{64}$/.test(a.digest), 'ARTIFACT_IDENTITY');
    need(String(a.workflow_run?.id) === request.runId && String(a.workflow_run?.repository_id) === trust.repository.id &&
        String(a.workflow_run?.head_repository_id) === trust.repository.id && a.workflow_run?.head_sha === trust.verifier.commit,
        'ARTIFACT_RUN');
    need(Date.parse(a.created_at) >= Date.parse(observed.job.started_at) &&
        Date.parse(a.created_at) <= Date.parse(observed.job.completed_at) && Date.parse(a.expires_at) > Date.now(), 'ARTIFACT_TIME');
    const redirect = await request31('https://api.github.com/repos/' + trust.repository.name + '/actions/artifacts/' + a.id + '/zip', {
        headers: {Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'business31-trusted-result', Authorization: 'Bearer ' + token(accessToken)},
        redirect: true, maxBytes: 1024 * 1024
    });
    need(redirect.status === 302 && typeof redirect.headers.location === 'string', 'ARTIFACT_REDIRECT');
    const target = new URL(redirect.headers.location);
    need(target.protocol === 'https:' && !target.username && !target.password && !target.port &&
        /^[a-z0-9]+\.blob\.core\.windows\.net$/.test(target.hostname), 'ARTIFACT_STORAGE_ORIGIN');
    // The signed storage request never receives the GitHub credential.
    const raw = (await request31(target.href, {maxBytes: 1024 * 1024})).bytes;
    need(raw.length === a.size_in_bytes && 'sha256:' + sha(raw).toLowerCase() === a.digest, 'ARTIFACT_DIGEST');
    const resultBytes = singleResultZip31(raw);
    const value = validateResult31(json(resultBytes, 32768), trust, request);
    need(Date.parse(value.startedAtUtc) >= Date.parse(observed.job.started_at) &&
        Date.parse(value.completedAtUtc) <= Date.parse(observed.job.completed_at), 'RESULT_JOB_TIME');
    await observe31(trust, request, accessToken, true);
    return {value, artifactId: String(a.id), resultSha256: sha(resultBytes)};
}
function validateResult31(v, t, r, now = Date.now()) {
    exact(v, [
        'schemaVersion', 'documentType', 'profile', 'verifier', 'source', 'candidate', 'descriptorPointer', 'closurePointer', 'commitments', 'platform', 'startedAtUtc', 'completedAtUtc', 'recordedSemanticsReplayed', 'limits',
        ...(r.schemaVersion === 2 ? ['challenge', 'client'] : [])
    ], 'RESULT_FIELDS');
    need(v.schemaVersion === r.schemaVersion && v.documentType === 'build31-business-hosted-result' && v.profile === PROFILE && v.recordedSemanticsReplayed === true, 'RESULT_PROFILE');
    same(v.verifier, {
        commit: t.verifier.commit, tree: t.verifier.tree
    }, 'RESULT_V');
    same(v.source, t.source, 'RESULT_M');
    same(v.candidate, r.candidate, 'RESULT_S');
    same(v.descriptorPointer, r.descriptorPointer, 'RESULT_DESCRIPTOR');
    exact(v.closurePointer, ['commit', 'file', 'sha256'], 'RESULT_CLOSURE');
    need(oid(v.closurePointer.commit) && v.closurePointer.file === 'release/evidence/build31-business-backend-deployment-closure.json' && digest(v.closurePointer.sha256), 'RESULT_CLOSURE');
    exact(v.commitments, [
        'bundleSha256', 'membersSha256', 'relocationSha256', 'sourceManifestSha256'
    ], 'RESULT_COMMITMENTS');
    need(Object.values(v.commitments).every(digest) && v.commitments.sourceManifestSha256 === t.sourceManifestSha256, 'RESULT_COMMITMENTS');
    same(v.platform, {
        repositoryId: t.repository.id, workflowId: t.workflow.id, workflowCommit: t.verifier.commit, runId: r.runId, runAttempt: r.runAttempt, environment: t.workflow.environment
    }, 'RESULT_PLATFORM');
    for (const d of [v.startedAtUtc, v.completedAtUtc])
        need(typeof d === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(d) && Number.isFinite(Date.parse(d)), 'RESULT_DATE');
    need(Date.parse(v.startedAtUtc) <= Date.parse(v.completedAtUtc) && Date.parse(v.completedAtUtc) <= now && now - Date.parse(v.completedAtUtc) <= t.maximumResultAgeSeconds * 1000, 'RESULT_TIME');
    same(v.limits, {
        ownerIdentityAuthenticated: false, originalProcessExecutionAuthenticated: false, deploymentAuthorized: false, constructionAuthorized: false, distributionAuthorized: false
    }, 'RESULT_LIMITS');
    if (r.schemaVersion === 2) {
        validateChallenge31(v.challenge, r.candidate);
        same(v.challenge, r.challenge, 'RESULT_CHALLENGE');
        need(Date.parse(v.startedAtUtc) >= Date.parse(r.challenge.requestedAtUtc) &&
            Date.parse(v.completedAtUtc) <= Date.parse(r.challenge.expiresAtUtc) &&
            now <= Date.parse(r.challenge.expiresAtUtc), 'RESULT_CHALLENGE_TIME');
        // Every helper is independently selected before importing the closed
        // projection validator. It reads no private file and grants no action.
        verifyClientHelpers31(t);
        require('./business31HostedClient.cjs').validateBusinessHostedClientMeasurement31({trust: t, request: r, client: v.client});
        same(v.client.policy.closurePointer, v.closurePointer, 'RESULT_CLIENT_CLOSURE');
    }
    return v;
}
function verifyClientHelpers31(t) {
    for (const name of ['business31HostedClient.cjs', 'business31ClientPolicy.cjs',
        'business31ClientCustody.cjs', 'business31ClientSemantics.cjs', 'business31TrustedInput.cjs',
        'business31PrivateDescriptor.cjs', 'privateEvidenceBundle31.cjs']) {
        const key = 'tools/release/' + name;
        need(Object.hasOwn(t.verifier.files, key) && digest(t.verifier.files[key]) &&
            sha(fs.readFileSync(regular(path.join(__dirname, name)))) === t.verifier.files[key], 'CLIENT_PRODUCER');
    }
}
function verifyReplayHelpers31(t) {
    // These modules execute before descriptor preparation can establish the
    // complete Git producer population. An omitted digest must fail first.
    for (const name of ['business31SourceAdmission.cjs', 'business31PrivateDescriptor.cjs',
        'business31TrustedInput.cjs', 'privateEvidenceBundle31.cjs', 'business31OriginalPathReplay.cjs']) {
        const file = 'tools/release/' + name;
        need(Object.hasOwn(t.verifier.files, file) && digest(t.verifier.files[file]) &&
            sha(fs.readFileSync(regular(path.join(__dirname, name)))) === t.verifier.files[file], 'REPLAY_PRODUCER');
    }
}
function crc32(b) {
    let c = 0xffffffff;
    for (const x of b) {
        c ^= x;
        for (let i = 0; i < 8; i++)
            c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
    }
    return (c ^ 0xffffffff) >>> 0;
}
function singleResultZip31(raw) {
    need(Buffer.isBuffer(raw) && raw.length >= 22 && raw.length <= 1024 * 1024, 'ARTIFACT_BOUND');
    const e = raw.length - 22;
    need(raw.readUInt32LE(e) === 0x06054b50 && raw.readUInt16LE(e + 4) === 0 && raw.readUInt16LE(e + 6) === 0 && raw.readUInt16LE(e + 8) === 1 && raw.readUInt16LE(e + 10) === 1 && raw.readUInt16LE(e + 20) === 0, 'ZIP_DIRECTORY');
    const c = raw.readUInt32LE(e + 16), size = raw.readUInt32LE(e + 12);
    need(c + size === e && c + 46 <= e && raw.readUInt32LE(c) === 0x02014b50, 'ZIP_CENTRAL');
    const flags = raw.readUInt16LE(c + 8), method = raw.readUInt16LE(c + 10), crc = raw.readUInt32LE(c + 16), packed = raw.readUInt32LE(c + 20), expanded = raw.readUInt32LE(c + 24), nl = raw.readUInt16LE(c + 28), el = raw.readUInt16LE(c + 30), cl = raw.readUInt16LE(c + 32), offset = raw.readUInt32LE(c + 42);
    need([
        0, 8, 0x800, 0x808
    ].includes(flags), 'ZIP_FLAGS');
    const mode = raw.readUInt32LE(c + 38) >>> 16;
    need((method === 0 || method === 8) && expanded > 0 && expanded <= 32768 && packed <= 65536 && el === 0 && cl === 0 && offset === 0 && 46 + nl === size && raw.readUInt16LE(c + 34) === 0 && (mode === 0 || (mode & 0xf000) === 0x8000), 'ZIP_MEMBER');
    need(raw.subarray(c + 46, c + 46 + nl).toString('utf8') === RESULT_NAME, 'ZIP_NAME');
    need(raw.readUInt32LE(0) === 0x04034b50 && raw.readUInt16LE(6) === flags && raw.readUInt16LE(8) === method && raw.readUInt16LE(26) === nl && raw.readUInt16LE(28) === 0, 'ZIP_LOCAL');
    need(raw.subarray(30, 30 + nl).equals(raw.subarray(c + 46, c + 46 + nl)), 'ZIP_LOCAL_NAME');
    const end = 30 + nl + packed;
    if (flags & 8) {
        need(raw.readUInt32LE(14) === 0 && raw.readUInt32LE(18) === 0 && raw.readUInt32LE(22) === 0 && end + 16 === c && raw.readUInt32LE(end) === 0x08074b50 && raw.readUInt32LE(end + 4) === crc && raw.readUInt32LE(end + 8) === packed && raw.readUInt32LE(end + 12) === expanded, 'ZIP_DATA_DESCRIPTOR');
    }
    else
        need(raw.readUInt32LE(14) === crc && raw.readUInt32LE(18) === packed && raw.readUInt32LE(22) === expanded && end === c, 'ZIP_LOCAL_CONTENT');
    const payload = raw.subarray(30 + nl, end), bytes = method === 0 ? payload : zlib.inflateRawSync(payload, {
        maxOutputLength: 32768
    });
    need(bytes.length === expanded && crc32(bytes) === crc, 'ZIP_CONTENT');
    return bytes;
}
module.exports = Object.freeze({
    PROFILE, ISSUER, RESULT_NAME, SELF, ENTRIES, sha, need, same, exact, json, regular, validateTrust31, readTrustedConfiguration31, validateRequest31, validateChallenge31, verifyClientHelpers31, verifyReplayHelpers31, verifyExecuting31, validateRepository31, validateCandidate31, validateRun31, validateJobs31, verifyOidc31, request31, token, github31, observe31, artifactName31, retrieveResult31, validateResult31, singleResultZip31
});
