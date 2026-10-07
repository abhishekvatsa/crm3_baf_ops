'use strict';
// Actual Git/custody/policy measurement feeds the pure PowerShell compiler join.
// The surrounding adapter envelope is synthetic data: it authenticates neither
// a hosted run nor a person and cannot authorize construction or distribution.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const clientHelper = require('./business31HostedClient.cjs');
const policyHelper = require('./business31ClientPolicy.cjs');
const {createFixture} = require('./fixtures/business31ClientPolicyFixture.cjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
const noAuthority = ['independentlySelectedInputsAuthenticated', 'executingHostAuthenticated',
  'humanIdentityAuthenticated', 'trustedClockAuthenticated', 'credentialAccessAuthorized',
  'backendDeploymentAuthorized', 'constructionAuthorized', 'signingAuthorized', 'distributionAuthorized'];

function runJoin(input, directory, name) {
  const data = path.join(directory, name + '.json'), script = path.join(directory, name + '.ps1');
  fs.writeFileSync(data, JSON.stringify(input), {flag: 'wx'});
  const quote = value => "'" + value.replaceAll("'", "''") + "'";
  fs.writeFileSync(script, `Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. ${quote(path.join(__dirname, 'Production-AppCheckPolicy.ps1'))}
$f = Get-Content -LiteralPath ${quote(data)} -Raw | ConvertFrom-Json -Depth 100
$result = Get-ProductionAppCheckBuildEvidence -Policy $f.policy -Approval $f.approval -BackendReceipt $f.backend -ApprovalSha256 $f.hash -BackendReceiptSha256 $f.backendHash -Business31Proof $f.businessProof
$result | ConvertTo-Json -Depth 30 -Compress
`, {flag: 'wx'});
  return spawnSync(process.env.BUSINESS31_TEST_PWSH || 'pwsh', ['-NoProfile', '-File', script],
    {encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024});
}

test('AppCheck compiler join accepts actual client2 policy measurement and refuses measurement drift', () => {
  const fixture = createFixture(), platform = fixture.platformFixture(), selected = fixture.clientInput().selected;
  const measured = clientHelper.measureBusinessHostedClient31({trust: platform.trust,
    request: platform.request, input: fixture.clientInput()});
  assert.equal(measured.schemaVersion, 2);
  assert.equal(Object.hasOwn(measured, 'source'), false);
  assert.equal(measured.policy.source.commit, fixture.M.commit);
  assert.equal(measured.policy.candidate.commit, fixture.S.commit);
  assert.equal(measured.appCheckSourcePolicyVerified, true);
  assert.equal(measured.policy.bindings.identitySource.sha256, policyHelper.IDENTITY_SHA256);
  assert.deepEqual(clientHelper.validateBusinessHostedClientMeasurement31({trust: platform.trust,
    request: platform.request, client: measured}), measured);
  for (const field of noAuthority) {
    assert.equal(measured[field], false, field);
    assert.equal(measured.policy[field], false, field);
  }
  assert.equal(measured.platformIdentityAuthenticated, false);
  assert.equal(measured.policy.platformIdentityAuthenticated, false);
  assert.equal(measured.policy.privateReplayVerified, false);
  const approvalBytes = fixture.S.files[policyHelper.FILES.appCheckApproval];
  const backendBytes = fixture.S.files[selected.backendClosure.file];
  const backend = JSON.parse(backendBytes);
  const syntheticPolicyEnvelope = {schemaVersion: 1, profile: 'build31-business-policy-result-v1',
    purpose: 'policy', source: measured.policy.source, descriptorPointer: selected.descriptor,
    closurePointer: selected.backendClosure, client: measured, policyMeasurementVerified: true,
    originalProcessExecutionAuthenticated: false, ...Object.fromEntries(noAuthority.map(field => [field, false]))};
  const input = {policy: fixture.records.policy, approval: JSON.parse(approvalBytes), backend,
    hash: sha(approvalBytes), backendHash: sha(backendBytes), businessProof: {ok: true,
      route: 'business-backend31', businessBackend31: {source: measured.policy.source,
        descriptorPointer: selected.descriptor, closurePointer: selected.backendClosure,
        clientPointer: selected.decisionPointer, currentBackend: backend, policyResult: syntheticPolicyEnvelope}}};
  assert.equal(input.hash, measured.policy.bindings.appCheckApproval.sha256);
  assert.equal(input.backendHash, measured.policy.closurePointer.sha256);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'b31-appcheck-measured-'));
  // Retain exact inputs and subprocess scripts alongside the fixture for review.
  process.stdout.write('Retained synthetic AppCheck measurement inputs: ' + directory + '\n');
  const result = runJoin(input, directory, 'actual-client2');
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), measured.policy.appCheck);
  for (const [name, mutate] of [
    ['old-client-schema', client => {client.schemaVersion = 1;}],
    ['compiler-choice-drift', client => {client.policy.appCheck.dartDefine = 'false';}],
    ['platform-authority-claim', client => {client.platformIdentityAuthenticated = true;}],
  ]) {
    const changed = structuredClone(input);
    mutate(changed.businessProof.businessBackend31.policyResult.client);
    const refused = runJoin(changed, directory, name);
    assert.equal(refused.error, undefined);
    assert.notEqual(refused.status, 0, name + ': unbound measurement must be refused');
    assert.match(refused.stderr, /App Check business31|Business31 replayed App Check/);
  }
});
