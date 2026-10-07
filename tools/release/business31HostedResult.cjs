'use strict';
// Only the protected launcher may invoke this operational entry in a new Node.
// This check retires library use; it is not a sandbox for an already hostile VM.
if (require.main !== module || process.execArgv.length !== 1 || process.execArgv[0] !== '--no-global-search-paths' ||
    [
        'NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES'
    ].some(k => process.env[k]) ||
    Object.keys(require.cache).some(file => file !== __filename))
    throw Error('BUSINESS_HOSTED_FRESH_ENTRY_REQUIRED');
// Public consumer: platform-authenticated artifact only, never a local PASS file.
const fs = require('node:fs'), path = require('node:path'), p = require('./business31HostedProtocol.cjs');
async function consumeHostedResult31({ trust, request }) {
    ({
        trust, request
    } = p.json(Buffer.from(JSON.stringify({
        trust, request
    }))));
    p.validateTrust31(trust);
    p.validateRequest31(request);
    const {value, artifactId, resultSha256} = await p.retrieveResult31(trust, request, process.env.GITHUB_TOKEN);
    // Legacy artifact1 projects to consumer2. Challenge-bound artifact2 carries
    // the measured client directly; no private original message is read here.
    return Object.freeze({
        schemaVersion: request.schemaVersion === 2 ? 3 : 2, profile: p.PROFILE,
        verifier: structuredClone(value.verifier), source: structuredClone(value.source),
        candidate: structuredClone(value.candidate), descriptorPointer: structuredClone(value.descriptorPointer),
        closurePointer: structuredClone(value.closurePointer), commitments: structuredClone(value.commitments),
        runId: request.runId, runAttempt: request.runAttempt, artifactId, resultSha256,
        hostedRecordedReplayResultAuthenticated: true, ownerIdentityAuthenticated: false, originalProcessExecutionAuthenticated: false,
        deploymentAuthorized: false, constructionAuthorized: false, distributionAuthorized: false,
        ...(request.schemaVersion === 2 ? {challenge: structuredClone(value.challenge), client: structuredClone(value.client)} : {})
    });
}
// The protected parent independently selects both client-input arguments. They
// must never be populated from a candidate policy, request, or local PASS file.
const CLIENT_HELPERS = Object.freeze([
    'business31HostedClient.cjs', 'business31ClientCustody.cjs',
    'business31ClientSemantics.cjs', 'business31TrustedInput.cjs',
    'business31PrivateDescriptor.cjs', 'privateEvidenceBundle31.cjs', 'business31ClientPolicy.cjs'
]);
function clientInput31(file, expectedSha256) {
    p.need(typeof expectedSha256 === 'string' && /^[A-F0-9]{64}$/.test(expectedSha256), 'CLIENT_INPUT_COMMITMENT');
    const regular = p.regular(file);
    p.need(fs.statSync(regular).size > 0 && fs.statSync(regular).size <= 128 * 1024, 'CLIENT_INPUT_BOUND');
    const bytes = fs.readFileSync(regular);
    p.need(p.sha(bytes) === expectedSha256, 'CLIENT_INPUT_COMMITMENT');
    return p.json(bytes, 128 * 1024);
}
async function main() {
    const clientMode = process.argv.length === 12;
    p.need((process.argv.length === 8 || clientMode) && process.argv[2] === '--trust' &&
        process.argv[4] === '--trust-sha256' && process.argv[6] === '--request' &&
        (!clientMode || (process.argv[8] === '--client-input' && process.argv[10] === '--client-input-sha256')), 'CLI');
    const trust = p.readTrustedConfiguration31(process.argv[3], process.argv[5]);
    p.verifyExecuting31(trust, path.resolve(__dirname, '../..'));
    const request = p.validateRequest31(p.json(fs.readFileSync(p.regular(process.argv[7]))));
    p.need(!clientMode || request.schemaVersion === 1, 'CLIENT_INPUT_ROUTE');
    let client;
    if (clientMode) {
        // Verify mandatory membership AND local bytes before importing any
        // client helper. A self-selected subset cannot omit this boundary.
        for (const name of CLIENT_HELPERS) {
            const key = 'tools/release/' + name;
            p.need(Object.hasOwn(trust.verifier.files, key) &&
                p.sha(fs.readFileSync(p.regular(path.join(__dirname, name)))) === trust.verifier.files[key],
            'CLIENT_PRODUCER');
        }
        const input = clientInput31(process.argv[9], process.argv[11]);
        client = require('./business31HostedClient.cjs');
        client.prepareBusinessHostedClient31({trust, request, input});
    }
    const hostedResult = await consumeHostedResult31({trust, request});
    // Re-measure custody and bound input after awaited network reads. No
    // callback, cached approval, or supplied authenticated result is accepted.
    if (clientMode) p.verifyExecuting31(trust, path.resolve(__dirname, '../..'));
    const result = clientMode ? {...hostedResult, schemaVersion: 3,
        client: client.finishBusinessHostedClient31({trust, request,
            input: clientInput31(process.argv[9], process.argv[11]), hostedResult})} : hostedResult;
    if (clientMode || request.schemaVersion === 2) {
        // Custody performs real Git reads. Observe the remote again after that
        // work so a head change during those reads cannot publish a stale join.
        await p.observe31(trust, request, process.env.GITHUB_TOKEN, true);
        p.verifyExecuting31(trust, path.resolve(__dirname, '../..'));
        if (request.schemaVersion === 2)
            p.need(Date.now() <= Date.parse(request.challenge.expiresAtUtc), 'CLIENT_CHALLENGE_TIME');
    }
    process.stdout.write(JSON.stringify(result) + '\n');
}
if (require.main === module)
    main().catch(() => { process.stderr.write('No authenticated exact-head business replay result is available.\n'); process.exitCode = 1; });
