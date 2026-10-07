'use strict';
// Only the protected launcher may invoke this operational entry in a new Node.
// This check retires library use; it is not a sandbox for an already hostile VM.
if (require.main !== module || process.execArgv.length !== 1 || process.execArgv[0] !== '--no-global-search-paths' ||
    [
        'NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES'
    ].some(k => process.env[k]) ||
    Object.keys(require.cache).some(file => file !== __filename))
    throw Error('BUSINESS_HOSTED_FRESH_ENTRY_REQUIRED');
// The independently protected launcher verifies this distribution and its trust
// file digest before starting an approved Node with no preloads/global search.
// Request data cannot choose the verifier, modules, endpoints or credential scope.
const fs = require('node:fs'), path = require('node:path'), p = require('./business31HostedProtocol.cjs');
const SOURCE_ROOT = path.resolve(__dirname, '../..');
function measureClient31(options) {
    const {trust, request, repositoryRoot, gitExecutable, clientInputFile, clientInputSha256} = options;
    p.need(request.schemaVersion === 2 && /^[A-F0-9]{64}$/.test(clientInputSha256), 'CLIENT_INPUT_COMMITMENT');
    p.verifyClientHelpers31(trust);
    const file = p.regular(clientInputFile);
    p.need(fs.statSync(file).size > 0 && fs.statSync(file).size <= 128 * 1024, 'CLIENT_INPUT_BOUND');
    const raw = fs.readFileSync(file);
    p.need(p.sha(raw) === clientInputSha256, 'CLIENT_INPUT_COMMITMENT');
    const input = p.json(raw, 128 * 1024);
    p.same(input.repositoryRoot, repositoryRoot, 'CLIENT_REPOSITORY');
    p.same(input.gitExecutable, gitExecutable, 'CLIENT_GIT');
    const canonical = require('./business31SourceAdmission.cjs').canonical;
    p.need(p.sha(Buffer.from(canonical(input.selected))) === request.challenge.clientSelectionSha256,
        'CLIENT_SELECTED_COMMITMENT');
    return require('./business31HostedClient.cjs').measureBusinessHostedClient31({trust, request, input});
}
function admit31({ trust, request, repositoryRoot, gitExecutable, sourceManifest }) {
    p.validateTrust31(trust);
    p.validateRequest31(request);
    p.verifyExecuting31(trust, SOURCE_ROOT);
    p.verifyReplayHelpers31(trust);
    p.need(p.sha(fs.readFileSync(p.regular(gitExecutable))) === trust.gitSha256, 'GIT_IDENTITY');
    const source = require('./business31SourceAdmission.cjs');
    p.need(p.sha(source.canonical(sourceManifest)) === trust.sourceManifestSha256, 'SOURCE_MANIFEST');
    const envelope = {
        schemaVersion: 1, profile: 'build31-business-trusted-input-v1', verifier: trust.verifier,
        source: {
            commit: trust.source.commit, tree: trust.source.tree
        }, candidate: {
            commit: request.candidate.commit, tree: request.candidate.tree, ref: 'refs/heads/business31-admitted-' + request.candidate.commit
        }
    };
    const api = require('./business31PrivateDescriptor.cjs');
    const proof = api.verifyBusiness31DescriptorPreparation({
        repositoryRoot, gitExecutable, gitSha256: trust.gitSha256, envelope,
        descriptorPointer: request.descriptorPointer, expectedSourceManifestSha256: trust.sourceManifestSha256
    });
    const repo = require('./business31TrustedInput.cjs').openTrustedGitRepository31({
        repositoryRoot, gitExecutable, gitSha256: trust.gitSha256
    });
    const descriptor = api.validateBusiness31PrivateDescriptor(api.json(repo.readBlob(request.descriptorPointer.commit, request.descriptorPointer.file)));
    p.same(descriptor.source, trust.source, 'ADMITTED_SOURCE');
    p.same(descriptor.verifier, {
        commit: trust.verifier.commit, tree: trust.verifier.tree
    }, 'ADMITTED_VERIFIER');
    p.same(descriptor.producerBindings, trust.verifier.files, 'ADMITTED_PRODUCERS');
    p.need(proof.inputBoundaryVerified === true, 'INPUT_BOUNDARY');
    return {
        envelope, descriptor
    };
}
async function githubOidc31(trust, request) {
    const u = new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL || 'https://invalid.invalid/');
    p.need(u.protocol === 'https:' && !u.username && !u.password && !u.port && /^[a-z0-9-]+\.actions\.githubusercontent\.com$/.test(u.hostname), 'OIDC_REQUEST_ORIGIN');
    u.searchParams.set('audience', trust.wifAudience);
    const body = p.json((await p.request31(u.href, {
        headers: {
            Authorization: 'Bearer ' + p.token(process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN)
        }, maxBytes: 32768
    })).bytes, 32768);
    p.exact(body, ['value'], 'OIDC_RESPONSE');
    const jwks = p.json((await p.request31(p.ISSUER + '/.well-known/jwks', {
        maxBytes: 128 * 1024
    })).bytes, 128 * 1024);
    p.verifyOidc31(body.value, jwks, trust, request);
    return body.value;
}
async function exchangeReadOnly31(trust, subjectToken) {
    const body = Buffer.from(new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange', audience: trust.wifAudience,
        requested_token_type: 'urn:ietf:params:oauth:token-type:access_token', subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
        scope: 'https://www.googleapis.com/auth/devstorage.read_only', subject_token: subjectToken
    }).toString());
    const v = p.json((await p.request31('https://sts.googleapis.com/v1/token', {
        method: 'POST', headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        }, body, maxBytes: 32768
    })).bytes, 32768);
    p.need(v.token_type === 'Bearer' && v.issued_token_type === 'urn:ietf:params:oauth:token-type:access_token' && Number.isInteger(v.expires_in) && v.expires_in > 0 && v.expires_in <= 3600, 'STS_RESULT');
    return p.token(v.access_token);
}
async function replayHosted31(options) {
    p.exact(options, [
        'trust', 'request', 'repositoryRoot', 'gitExecutable', 'sourceManifest', 'privateParent',
        ...(options.request?.schemaVersion === 2 ? ['clientInputFile', 'clientInputSha256'] : [])
    ], 'CALLER_OPTIONS');
    options = p.json(Buffer.from(JSON.stringify(options)));
    const { trust, request, repositoryRoot, gitExecutable, sourceManifest, privateParent } = options;
    const startedAtUtc = new Date().toISOString();
    const first = admit31(options);
    const client = request.schemaVersion === 2 ? measureClient31(options) : null;
    if (client) p.need(Date.parse(request.challenge.requestedAtUtc) <= Date.now() &&
        Date.now() < Date.parse(request.challenge.expiresAtUtc), 'CHALLENGE_CURRENT');
    // All imports above are fixed V code. Private credentials are requested only
    // after complete Git/source/descriptor admission and fresh platform checks.
    await p.observe31(trust, request, process.env.GITHUB_TOKEN, false);
    let oidc = await githubOidc31(trust, request), accessToken = null, bundle = null, owned = null;
    try {
        const second = admit31(options);
        p.same(second, first, 'ADMISSION_CHANGED');
        accessToken = await exchangeReadOnly31(trust, oidc);
        oidc = null;
        bundle = await require('./privateEvidenceBundle31.cjs').downloadExactGeneration31(first.descriptor, accessToken, 'business');
        accessToken = null;
        const parent = p.regular(privateParent, true);
        owned = fs.mkdtempSync(path.join(parent, 'business31-hosted-'));
        fs.chmodSync(owned, 0o700);
        const replay = require('./business31OriginalPathReplay.cjs').verifyBusiness31OriginalPathReplay({
            repositoryRoot, gitExecutable, gitSha256: trust.gitSha256,
            envelope: first.envelope, descriptorPointer: request.descriptorPointer, sourceManifest, expectedSourceManifestSha256: trust.sourceManifestSha256,
            bundleBytes: bundle, extractionRoot: path.join(owned, 'evidence'), nowUtc: new Date().toISOString()
        });
        p.need(replay.recordedSemanticsReplayed === true && replay.originalPathsUnavailable === true, 'REPLAY_INCOMPLETE');
        p.same(replay.source, trust.source, 'REPLAY_SOURCE');
        p.need(replay.descriptorSha256 === request.descriptorPointer.sha256, 'REPLAY_DESCRIPTOR');
        p.same(replay.closure.closurePointer, first.descriptor.closurePointer, 'REPLAY_CLOSURE');
        p.same(admit31(options), first, 'FINAL_ADMISSION_CHANGED');
        if (client) p.same(measureClient31(options), client, 'CLIENT_MEASUREMENT_CHANGED');
        await p.observe31(trust, request, process.env.GITHUB_TOKEN, false);
        if (client) p.same(measureClient31(options), client, 'FINAL_CLIENT_MEASUREMENT_CHANGED');
        const result = {
            schemaVersion: request.schemaVersion, documentType: 'build31-business-hosted-result', profile: p.PROFILE,
            verifier: {
                commit: trust.verifier.commit, tree: trust.verifier.tree
            }, source: trust.source, candidate: request.candidate, descriptorPointer: request.descriptorPointer,
            closurePointer: first.descriptor.closurePointer, commitments: {
                bundleSha256: first.descriptor.custody.sha256, membersSha256: replay.membersSha256,
                relocationSha256: replay.relocationSha256, sourceManifestSha256: trust.sourceManifestSha256
            },
            platform: {
                repositoryId: trust.repository.id, workflowId: trust.workflow.id, workflowCommit: trust.verifier.commit, runId: request.runId, runAttempt: request.runAttempt, environment: trust.workflow.environment
            },
            startedAtUtc, completedAtUtc: new Date().toISOString(), recordedSemanticsReplayed: true,
            limits: {
                ownerIdentityAuthenticated: false, originalProcessExecutionAuthenticated: false, deploymentAuthorized: false, constructionAuthorized: false, distributionAuthorized: false
            }, ...(client ? {challenge: request.challenge, client} : {})
        };
        return p.validateResult31(result, trust, request);
    }
    finally {
        oidc = null;
        accessToken = null;
        if (bundle)
            bundle.fill(0);
        // Only the exclusive mkdtemp directory created above is removed. Abrupt
        // process/host death requires destruction of the protected ephemeral job.
        if (owned) {
            p.need(path.dirname(owned) === path.resolve(privateParent) && path.basename(owned).startsWith('business31-hosted-'), 'CLEANUP_OWNERSHIP');
            p.regular(owned, true);
            fs.rmSync(owned, {
                recursive: true, force: false
            });
        }
    }
}
async function main() {
    const clientMode = process.argv.length === 14;
    p.need((process.argv.length === 10 || clientMode) && process.argv[2] === '--trust' && process.argv[4] === '--trust-sha256' && process.argv[6] === '--request' && process.argv[8] === '--output' &&
        (!clientMode || (process.argv[10] === '--client-input' && process.argv[12] === '--client-input-sha256')), 'CLI');
    const trust = p.readTrustedConfiguration31(process.argv[3], process.argv[5]);
    const input = p.json(fs.readFileSync(p.regular(process.argv[7])));
    p.exact(input, [
        'request', 'repositoryRoot', 'gitExecutable', 'sourceManifest', 'privateParent'
    ], 'LOCAL_INPUT');
    p.need(clientMode === (input.request?.schemaVersion === 2), 'CLIENT_REQUEST_MODE');
    const output = path.resolve(process.argv[9]);
    p.need(path.basename(output) === p.RESULT_NAME && !fs.existsSync(output), 'RESULT_DESTINATION');
    p.regular(path.dirname(output), true);
    const result = await replayHosted31({
        trust, ...input, ...(clientMode ? {clientInputFile: process.argv[11], clientInputSha256: process.argv[13]} : {})
    });
    fs.writeFileSync(output, JSON.stringify(result) + '\n', {
        flag: 'wx', mode: 0o600
    });
}
if (require.main === module)
    main().catch(() => { process.stderr.write('Business hosted replay failed; no result is admissible.\n'); process.exitCode = 1; });
