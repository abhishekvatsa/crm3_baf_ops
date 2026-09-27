import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import test from 'node:test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const helper = path.join(root, 'tools/release/Production-AppCheckPolicy.ps1');
const hash = 'A'.repeat(64), backendHash = 'B'.repeat(64);
function fixture(enabled = true) {
  const policy = {release: {buildNumber: 30, releaseId: 'synthetic-build30'},
    versionPolicy: {reservationId: 'synthetic-reservation30'},
    finalization: {exactFunctionFleetDeploymentReceiptFile: 'release/evidence/synthetic-backend.json', exactFunctionFleetDeploymentReceiptSha256: backendHash},
    appCheckBuild: {clientEnabled: enabled, androidProvider: enabled ? 'playIntegrity' : 'disabled',
      approvalFile: 'release/approvals/build30-app-check-client-approval.json', approvalSha256: hash}};
  const backend = {sourceAuthority: {commit: 'c'.repeat(40)}, deployment: {appCheckEnforcement: false}};
  const approval = {schemaVersion: 1, documentType: 'governed-app-check-client-build-approval', approved: true,
    intendedBuildNumber: 30, releaseId: policy.release.releaseId, reservationId: policy.versionPolicy.reservationId,
    firebaseProjectId: 'crm3-baf-ops-b8638', applicationId: 'in.co.sail.bsl.crm3.bafops',
    clientEnabled: enabled, androidProvider: policy.appCheckBuild.androidProvider,
    approverName: 'Synthetic fixture', approvalReference: 'SYNTHETIC-ONLY', approvedAtUtc: '2026-09-01T00:00:00Z',
    enforcementChangeAuthorized: false, serverEnforcementAtBuild: false,
    backendReceiptSha256: backendHash, backendSourceCommit: backend.sourceAuthority.commit};
  return {policy, backend, approval, hash, backendHash};
}

function run(t, input, extra = '') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-app-check-test-'));
  t.after(() => { assert.equal(path.dirname(fs.realpathSync(dir)), fs.realpathSync(os.tmpdir())); fs.rmSync(dir, {recursive: true}); });
  const data = path.join(dir, 'input.json'), script = path.join(dir, 'test.ps1');
  fs.writeFileSync(data, JSON.stringify(input));
  const quote = (value) => `'${value.replaceAll("'", "''")}'`;
  fs.writeFileSync(script, `Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. ${quote(helper)}
$f = Get-Content -LiteralPath ${quote(data)} -Raw | ConvertFrom-Json
$result = Get-ProductionAppCheckBuildEvidence -Policy $f.policy -Approval $f.approval -BackendReceipt $f.backend -ApprovalSha256 $f.hash -BackendReceiptSha256 $f.backendHash
${extra}
$result | ConvertTo-Json -Depth 20 -Compress
`);
  return spawnSync('pwsh', ['-NoProfile', '-File', script], {encoding: 'utf8', windowsHide: true, timeout: 30000});
}

for (const enabled of [true, false]) {
  test(`explicit client App Check ${enabled} is approval-bound and does not assert enforcement/token proof`, (t) => {
    const result = run(t, fixture(enabled));
    assert.equal(result.status, 0, result.stderr);
    const value = JSON.parse(result.stdout);
    assert.equal(value.clientEnabled, enabled);
    assert.equal(value.dartDefine, String(enabled));
    assert.equal(value.enforcementChangedByBuild, false);
    assert.equal(value.tokenValidationEvidence, 'not-proved-by-artifact-construction');
  });
}

for (const [label, change] of [
  ['missing client decision', (f) => { delete f.policy.appCheckBuild; }],
  ['string bool', (f) => { f.policy.appCheckBuild.clientEnabled = 'true'; }],
  ['debug release provider', (f) => { f.policy.appCheckBuild.androidProvider = 'debug'; }],
  ['different approval bytes', (f) => { f.hash = 'D'.repeat(64); }],
  ['old build approval', (f) => { f.approval.intendedBuildNumber = 29; }],
  ['wrong reservation', (f) => { f.approval.reservationId = 'old-reservation'; }],
  ['unapproved choice', (f) => { f.approval.approved = false; }],
  ['wrong backend source', (f) => { f.approval.backendSourceCommit = 'd'.repeat(40); }],
  ['changed backend bytes', (f) => { f.backendHash = 'D'.repeat(64); }],
  ['enforcement mismatch', (f) => { f.backend.deployment.appCheckEnforcement = true; }],
  ['client disabled with enforced server', (f) => { f.policy.appCheckBuild.clientEnabled = f.approval.clientEnabled = false; f.policy.appCheckBuild.androidProvider = f.approval.androidProvider = 'disabled'; f.backend.deployment.appCheckEnforcement = f.approval.serverEnforcementAtBuild = true; }],
  ['enforcement authorization hidden in build', (f) => { f.approval.enforcementChangeAuthorized = true; }],
  ['future decision', (f) => { f.approval.approvedAtUtc = '2999-01-01T00:00:00Z'; }],
  ['future candidate generation', (f) => { f.policy.release.buildNumber = 31; }],
]) {
  test(`App Check construction refuses ${label}`, (t) => {
    const input = fixture(); change(input);
    const result = run(t, input);
    assert.notEqual(result.status, 0, result.stdout);
  });
}

test('historical builds retain their existing absent App Check contract', (t) => {
  for (const build of [28, 29]) {
    const f = fixture(); f.policy.release.buildNumber = build; delete f.policy.appCheckBuild;
    f.approval.approverName = 'TODO'; f.approval.approvalReference = 'fixture';
    const result = run(t, f);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(result.stdout), null);
  }
});

for (const field of ['approverName', 'approvalReference']) {
  test(`repository preflight refuses placeholder or malformed approval identities: ${field}`, (t) => {
    const input = {...fixture(), field, invalid: [
      'TODO', 'TODO: record the decision', 'TODO_APPROVER', 'TODO - record decision', 'REPLACE_APPROVER', 'REPLACE_REFERENCE', 'fixture',
      'TODOAPPROVER', 'TODO123', 'fixture approval', 'todoReference', 'TODOAPPROVER123', 'fixture: pending',
      '  TODO\u200BAPPROVER  ', 'ＴＯＤＯ１２３',
      'TO-DO APPROVER', 'T O D O 123', 'FIX-TURE approval', 'F I X T U R E approval',
      'TO—DO123', 'T☀O+D★O APPROVER', 'ＴＯ－ＤＯ APPROVER', 'R E P L A C E_APPROVER',
      '**TODO**', '“FIX-TURE approval”', 'TODOA P P R O V E R', 'T O D O R E F E R E N C E',
      '🛠️ T🛠O🛠D🛠O APPROVER 🛠️', '...---', ' ☀ + — ', '🛠️💡', '** \t **',
      ...['TODO', 'REPLACE', 'FIXTURE'].flatMap((stem) => [
        `${stem}123`, `${stem} 123`,
        ...['APPROVER', 'REFERENCE'].flatMap((suffix) => {
          const marker = stem + suffix;
          return [marker, `${marker}123`, `${marker}NAME`,
            marker.split('').join(' '), marker.split('').join('-'),
            `“${marker.toLowerCase()}”`, `**${marker}**`,
            [...marker].map((letter) => String.fromCharCode(letter.charCodeAt(0) + 0xfee0)).join('')];
        }),
      ]),
      '  TODO  ', '\tRePlAcE_APPROVER\n', ' Fixture ', 'ＴＯＤＯ', 'ｆｉｘｔｕｒｅ',
      '\u200BTODO', 'TO\u200BDO', 'REPLACE_\u2060APPROVER', 'fi\uFEFFxture',
      'T\uFE0FODO', 'TO\u{E0100}DO', 'TO\u034FDO', '\u{1BCA0}TODO', '\u{1D173}TODO',
      '\u200B', ' \u200B\uFE0F\u{E0100} ',
      '', ' \t\n', null, 123, false, ['Alice Smith'], {name: 'Alice Smith'}, 'A'.repeat(4001),
    ]};
    const result = run(t, input, `
$repo = Join-Path $PSScriptRoot 'repo'
$approvalPath = Join-Path $repo $f.policy.appCheckBuild.approvalFile
$backendPath = Join-Path $repo $f.policy.finalization.exactFunctionFleetDeploymentReceiptFile
New-Item -ItemType Directory -Path (Split-Path $approvalPath), (Split-Path $backendPath) -Force | Out-Null
$f.backend | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $backendPath -Encoding utf8
$f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = (Get-FileHash $backendPath).Hash
$f.approval.backendReceiptSha256 = $f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256
foreach ($value in $f.invalid) {
  $f.approval.($f.field) = $value
  $f.approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8
  # Rebind the actual file digest so a rejection cannot be a stale-hash false positive.
  $f.policy.appCheckBuild.approvalSha256 = (Get-FileHash $approvalPath).Hash
  $refused=$false
  try { Get-ProductionAppCheckRepositoryEvidence -RepositoryRoot $repo -Policy $f.policy | Out-Null }
  catch {
    if ($_.Exception.Message -notmatch 'App Check approval identity') { throw }
    $refused=$true
  }
  if (-not $refused) { throw "Unfinished or malformed approval identity accepted: $($f.field)" }
}
`);
    assert.equal(result.status, 0, result.stderr);
  });
}

test('genuine approval identities pass without rewriting the retained identity', (t) => {
  const input = {...fixture(), valid: [
    {approverName: 'Asha Devi', approvalReference: 'OWNER-2026-09-27-APP-CHECK'},
    {approverName: "María-José O'Connor", approvalReference: 'Release review / 2026-09-27'},
    {approverName: '李明', approvalReference: '授权-20260927-01'},
    {approverName: '  Alice Smith  ', approvalReference: ' Owner decision 30 '},
    {approverName: 'Todor Ivanov', approvalReference: 'Todoist release decision 30'},
    {approverName: 'Todorov Alexei', approvalReference: 'Todoist ticket 123'},
    {approverName: 'To-dor Ivanov', approvalReference: 'To-doist release review'},
    {approverName: 'Todor Ivanov', approvalReference: 'Replacement release review 30'},
    {approverName: 'علی\u200Cرضا', approvalReference: 'Owner decision 30 / 李\u{E0100}明'},
  ]};
  const result = run(t, input, `
foreach ($identity in $f.valid) {
  $f.approval.approverName = $identity.approverName
  $f.approval.approvalReference = $identity.approvalReference
  Get-ProductionAppCheckBuildEvidence -Policy $f.policy -Approval $f.approval -BackendReceipt $f.backend -ApprovalSha256 $f.hash -BackendReceiptSha256 $f.backendHash | Out-Null
  if ($f.approval.approverName -cne $identity.approverName -or $f.approval.approvalReference -cne $identity.approvalReference) {
    throw 'Approval identity was rewritten while validating it'
  }
}
`);
  assert.equal(result.status, 0, result.stderr);
});

test('independent package verifier accepts exact evidence and rejects compiler or manifest tampering', (t) => {
  const result = run(t, fixture(), `
$manifest = [pscustomobject]@{appIdentity=[pscustomobject]@{CRM3_APP_CHECK_ENABLED=$result.dartDefine};appCheckBuild=($result | ConvertTo-Json | ConvertFrom-Json)}
Assert-ProductionAppCheckManifest -Manifest $manifest -Expected $result
foreach ($field in @('dartDefine','androidProvider','approvalSha256','backendReceiptSha256','tokenValidationEvidence')) {
  $original=$manifest.appCheckBuild.$field
  $manifest.appCheckBuild.$field='tampered'
  $refused=$false
  try { Assert-ProductionAppCheckManifest -Manifest $manifest -Expected $result } catch { $refused=$true }
  if (-not $refused) { throw "Tampered field accepted: $field" }
  $manifest.appCheckBuild.$field=$original
}
$manifest.appIdentity.CRM3_APP_CHECK_ENABLED='false'
$refused=$false
try { Assert-ProductionAppCheckManifest -Manifest $manifest -Expected $result } catch { $refused=$true }
if (-not $refused) { throw 'Wrong compiler define accepted' }
`);
  assert.equal(result.status, 0, result.stderr);
});

test('actual builder supplies one governed choice to both artifacts and verifier validates archive-bound helper', () => {
  const builder = fs.readFileSync(path.join(root, 'tools/release/New-ProductionArtifact.ps1'), 'utf8');
  const verifier = fs.readFileSync(path.join(root, 'tools/release/Test-ProductionReleaseManifest.ps1'), 'utf8');
  assert.ok(builder.includes("$identityDefines['CRM3_APP_CHECK_ENABLED'] = $appCheckEvidence.dartDefine"));
  assert.match(builder, /flutter build apk --release[\s\S]*?@dartDefines/);
  assert.match(builder, /flutter build appbundle --release[\s\S]*?@dartDefines/);
  assert.ok(builder.includes("$manifest['appCheckBuild'] = $appCheckEvidence"));
  assert.ok(verifier.indexOf('Get-Sha256 $appCheckHelper') < verifier.indexOf('. $appCheckHelper'));
  assert.ok(verifier.includes('Assert-ProductionAppCheckManifest -Manifest $manifest -Expected $expectedAppCheck'));
  const policy = fs.readFileSync(path.join(root, 'tools/release/Test-ProductionReleasePolicy.ps1'), 'utf8');
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/production-artifact.yml'), 'utf8');
  assert.ok(policy.includes('if ($RequireArtifactConstructionAuthority -and $policy.release.buildNumber -ge 30)'));
  assert.ok(policy.includes('Get-ProductionAppCheckRepositoryEvidence -RepositoryRoot $RepositoryRoot -Policy $policy | Out-Null'));
  assert.ok(workflow.indexOf('-RequireArtifactConstructionAuthority') < workflow.indexOf('git tag -a'), 'invalid construction choice must fail before number reservation');
});

test('actual repository preflight verifies fresh bytes and refuses missing/changed approval before reservation', (t) => {
  const result = run(t, fixture(), `
$repo = Join-Path $PSScriptRoot 'repo'
$approvalPath = Join-Path $repo $f.policy.appCheckBuild.approvalFile
$backendPath = Join-Path $repo $f.policy.finalization.exactFunctionFleetDeploymentReceiptFile
New-Item -ItemType Directory -Path (Split-Path $approvalPath), (Split-Path $backendPath) -Force | Out-Null
$f.backend | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $backendPath -Encoding utf8
$f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256 = (Get-FileHash $backendPath).Hash
$f.approval.backendReceiptSha256 = $f.policy.finalization.exactFunctionFleetDeploymentReceiptSha256
$f.approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8
$f.policy.appCheckBuild.approvalSha256 = (Get-FileHash $approvalPath).Hash
$verified = Get-ProductionAppCheckRepositoryEvidence -RepositoryRoot $repo -Policy $f.policy
if ($verified.dartDefine -cne 'true') { throw 'Repository choice was not preserved' }
Add-Content -LiteralPath $approvalPath -Value ' '
$refused=$false
try { Get-ProductionAppCheckRepositoryEvidence -RepositoryRoot $repo -Policy $f.policy | Out-Null } catch { $refused=$true }
if (-not $refused) { throw 'Changed approval bytes admitted' }
$f.policy.finalization.exactFunctionFleetDeploymentReceiptFile='../outside.json'
$refused=$false
try { Get-ProductionAppCheckRepositoryEvidence -RepositoryRoot $repo -Policy $f.policy | Out-Null } catch { $refused=$true }
if (-not $refused) { throw 'Escaped backend receipt admitted' }
`);
  assert.equal(result.status, 0, result.stderr);
});
