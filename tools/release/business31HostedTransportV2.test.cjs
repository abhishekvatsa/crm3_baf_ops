'use strict';
// Synthetic signed platform data and closed-schema checks only. No hosted authority.
const test = require('node:test');
const assert = require('node:assert/strict');
const p = require('./business31HostedProtocol.cjs');
const f = require('./fixtures/business31HostedFixture.cjs');
const fs = require('node:fs'), path = require('node:path');

function fixture() {
  const x = f.fixture();
  x.trust.schemaVersion = 2;
  x.trust.profile = p.PROFILE_V2;
  x.trust.coreVerifier = {commit: x.trust.source.commit, tree: x.trust.source.tree,
    files: Object.fromEntries(['business31BackendAuthority.cjs', 'business31BackendClosure.cjs',
      'backendRuntimeEvidenceAccess31.cjs'].map(name => ['tools/release/' + name, 'A'.repeat(64)]))};
  x.trust.sourceIntegration = {'tools/release/business31HostedProtocol.cjs':
    {mode: '100644', oid: '8'.repeat(40), sha256: 'B'.repeat(64)}};
  x.request.schemaVersion = 2;
  x.request.challenge = {schemaVersion: 1, nonce: 'a'.repeat(64), purpose: 'policy',
    requestedAtUtc: new Date(Date.parse(x.result.startedAtUtc) - 1000).toISOString(),
    expiresAtUtc: new Date(Date.now() + 3600000).toISOString(),
    requester: {kind: 'local', runId: null, runAttempt: null, invocationId: 'b'.repeat(64)},
    clientSelectionSha256: 'C'.repeat(64), fileBindings: []};
  x.result = {...x.result, schemaVersion: 2, profile: p.PROFILE_V2,
    coreVerifier: p.coreVerifierSummary31(x.trust), challenge: structuredClone(x.request.challenge), client: {},
    commitments: {...x.result.commitments, ...p.transportCommitments31(x.trust)}};
  return x;
}

test('closed v2 trust keeps outer and recorded core namespaces separate', () => {
  const x = fixture();
  assert.equal(p.validateTrust31(x.trust), x.trust);
  assert.notEqual(x.trust.verifier.commit, p.coreVerifierSummary31(x.trust).commit);
  assert.deepEqual(p.transportCommitments31(f.fixture().trust), {});
  assert.throws(() => p.coreVerifierSummary31(f.fixture().trust), /CORE_ROUTE/);
});

for (const [name, change] of [
  ['legacy profile with v2 fields', t => {t.profile = p.PROFILE;}],
  ['legacy version with v2 profile', t => {t.schemaVersion = 1;}],
  ['core from another source', t => {t.coreVerifier.commit = '0'.repeat(40);}],
  ['core tree drift', t => {t.coreVerifier.tree = '0'.repeat(40);}],
  ['outer relabelled as core', t => {t.verifier.commit = t.coreVerifier.commit;}],
  ['omitted frozen core helper', t => {delete t.coreVerifier.files['tools/release/business31BackendClosure.cjs'];}],
  ['empty integration', t => {t.sourceIntegration = {};}],
  ['integration mode change', t => {t.sourceIntegration[Object.keys(t.sourceIntegration)[0]].mode = '100755';}],
  ['integration hash omission', t => {delete t.sourceIntegration[Object.keys(t.sourceIntegration)[0]].sha256;}],
  ['integration traversal', t => {t.sourceIntegration['../escape.cjs'] = Object.values(t.sourceIntegration)[0];}]
]) test('v2 trust refuses ' + name, () => {
  const {trust} = fixture(); change(trust);
  assert.throws(() => p.validateTrust31(trust), /BUSINESS_HOSTED_(TRUST|CORE|SOURCE_INTEGRATION)/);
});

test('map commitments are canonical and commit both independent populations', () => {
  const {trust} = fixture(), before = p.transportCommitments31(trust);
  trust.coreVerifier.files = Object.fromEntries(Object.entries(trust.coreVerifier.files).reverse());
  assert.deepEqual(p.transportCommitments31(trust), before);
  trust.coreVerifier.files['tools/release/business31BackendClosure.cjs'] = 'D'.repeat(64);
  assert.notEqual(p.transportCommitments31(trust).coreProducerBindingsSha256, before.coreProducerBindingsSha256);
  trust.sourceIntegration[Object.keys(trust.sourceIntegration)[0]].oid = '9'.repeat(40);
  assert.notEqual(p.transportCommitments31(trust).sourceIntegrationSha256, before.sourceIntegrationSha256);
});

test('v2 imports require every new companion to be selected with its actual bytes', () => {
  const {trust} = fixture();
  const companions = ['business31TrustedInputV2.cjs', 'business31PrivateDescriptorV2.cjs',
    'business31OriginalPathReplayV2.cjs', 'business31CoreWorkerV2.cjs', 'privateEvidenceBundle31V2.cjs'];
  const common = ['business31SourceAdmission.cjs', 'business31PrivateDescriptor.cjs', 'business31TrustedInput.cjs',
    'privateEvidenceBundle31.cjs', 'business31OriginalPathReplay.cjs', 'business31HostedClient.cjs',
    'business31ClientPolicy.cjs', 'business31ClientCustody.cjs', 'business31ClientSemantics.cjs'];
  for (const name of [...common, ...companions])
    trust.verifier.files['tools/release/' + name] = p.sha(fs.readFileSync(path.join(__dirname, name)));
  p.verifyReplayHelpers31(trust); p.verifyClientHelpers31(trust);
  for (const name of companions) {
    const key = 'tools/release/' + name, expected = trust.verifier.files[key];
    delete trust.verifier.files[key];
    assert.throws(() => p.verifyReplayHelpers31(trust), /REPLAY_PRODUCER/);
    trust.verifier.files[key] = '0'.repeat(64);
    assert.throws(() => p.verifyReplayHelpers31(trust), /REPLAY_PRODUCER/);
    trust.verifier.files[key] = expected;
  }
});

for (const [name, change, refusal] of [
  ['missing core identity', x => {delete x.result.coreVerifier;}, /RESULT_FIELDS/],
  ['wrong core identity', x => {x.result.coreVerifier.commit = x.trust.verifier.commit;}, /RESULT_CORE_VERIFIER/],
  ['legacy artifact profile', x => {x.result.profile = p.PROFILE;}, /RESULT_PROFILE/],
  ['omitted core map commitment', x => {delete x.result.commitments.coreProducerBindingsSha256;}, /RESULT_COMMITMENTS/],
  ['wrong core map commitment', x => {x.result.commitments.coreProducerBindingsSha256 = '0'.repeat(64);}, /RESULT_TRANSPORT_COMMITMENT/],
  ['wrong integration commitment', x => {x.result.commitments.sourceIntegrationSha256 = '0'.repeat(64);}, /RESULT_TRANSPORT_COMMITMENT/],
  ['unchallenged request', x => {x.request.schemaVersion = 1;}, /V2_CHALLENGE_REQUIRED/]
]) test('v2 artifact refuses ' + name + ' before importing a client projection', () => {
  const x = fixture(); change(x);
  assert.throws(() => p.validateResult31(x.result, x.trust, x.request), refusal);
});

test('signed v2 workflow credentials bind outer revision and cannot use recorded M instead', () => {
  const x = fixture(), key = f.keys();
  assert.equal(p.verifyOidc31(f.signed(x.claims, key), key.jwks, x.trust, x.request).workflow_sha,
    x.trust.verifier.commit);
  x.claims.workflow_sha = x.trust.coreVerifier.commit;
  assert.throws(() => p.verifyOidc31(f.signed(x.claims, key), key.jwks, x.trust, x.request), /OIDC_CLAIM_WORKFLOW_SHA/);
});
