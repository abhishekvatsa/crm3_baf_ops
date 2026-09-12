import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const quote = (value) => `'${value.replaceAll("'", "''")}'`;
function probe(mode, extra = '') {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-gcs-test-'));
  try {
    const script = `
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. ${quote(path.join(root, 'tools/release/Private-GcsReleaseCustody.ps1'))}
$script:mode = ${quote(mode)}
$script:calls = [Collections.Generic.List[object]]::new()
$source = Join-Path ${quote(directory)} 'release.zip'
[IO.File]::WriteAllBytes($source, [byte[]](1,2,3,4))
$expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
function Invoke-PrivateGcsCommand([string]$Command, [string[]]$ArgumentList) {
  $script:calls.Add(@($ArgumentList))
  if ($ArgumentList[1] -eq 'buckets' -and $ArgumentList[2] -eq 'describe') {
    $bucket = @{name='crm3-baf-ops-b8638-firestore-restore';location='ASIA-SOUTH1';public_access_prevention='enforced';uniform_bucket_level_access=$true;versioning_enabled=$true;retention_policy=@{retentionPeriod='7776000'};soft_delete_policy=@{retentionDurationSeconds='604800'}}
    switch ($script:mode) {
      'public' { $bucket.public_access_prevention='inherited' }
      'versioning' { $bucket.versioning_enabled=$false }
      'retention' { $bucket.retention_policy.retentionPeriod='1' }
      'soft-delete' { $bucket.soft_delete_policy.retentionDurationSeconds='1' }
      'location' { $bucket.location='US-CENTRAL1' }
      'acl' { $bucket.uniform_bucket_level_access=$false }
    }
    return ($bucket | ConvertTo-Json -Depth 5)
  }
  if ($ArgumentList[1] -eq 'buckets' -and $ArgumentList[2] -eq 'get-iam-policy') {
    $members = if ($script:mode -eq 'public-iam') { @('allUsers') } else { @('projectOwner:crm3-baf-ops-b8638') }
    return (@{bindings=@(@{role='roles/storage.legacyBucketOwner';members=$members})} | ConvertTo-Json -Depth 5)
  }
  if ($ArgumentList[1] -eq 'cp' -and $ArgumentList[2] -notlike 'gs://*') {
    if ($ArgumentList -notcontains '--if-generation-match=0' -or $ArgumentList -notcontains '--print-created-message') { throw 'Unsafe upload arguments' }
    if ($script:mode -eq 'exists') { throw '412 generation precondition failed' }
    $script:uploaded = [IO.File]::ReadAllBytes($ArgumentList[2])
    if ($script:mode -eq 'source-changed') { [IO.File]::WriteAllBytes($source, [byte[]](9,9,9,9)) }
    if ($script:mode -eq 'lost-upload-response') { throw 'Upload response lost' }
    if ($script:mode -eq 'missing-generation') { return 'Upload complete' }
    if ($script:mode -eq 'wrong-created-object') { return 'Created: gs://other/object#1788912345678901' }
    return "Created: $($ArgumentList[3])#1788912345678901"
  }
  if ($ArgumentList[1] -eq 'objects') {
    if ($ArgumentList[3] -cne 'gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-28/test-campaign/release.zip#1788912345678901') { throw 'Metadata lookup is not pinned to the created generation' }
    return (@{bucket='crm3-baf-ops-b8638-firestore-restore';name='release-custody/build-28/test-campaign/release.zip';generation=$(if ($script:mode -eq 'wrong-generation') {'1788912345678902'} else {'1788912345678901'});size=$(if ($script:mode -eq 'wrong-size') {5} else {4})} | ConvertTo-Json)
  }
  if ($ArgumentList[1] -eq 'cp' -and $ArgumentList[2] -like 'gs://*') {
    if ($ArgumentList[2] -cne 'gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-28/test-campaign/release.zip#1788912345678901') { throw 'Download is not pinned to the created generation' }
    if (Test-Path -LiteralPath $ArgumentList[3]) { throw 'Readback destination is not fresh' }
    if ($script:mode -eq 'download-failure') { throw 'Download unavailable' }
    $bytes = if ($script:mode -eq 'corrupt-download') { [byte[]](9,2,3,4) } else { $script:uploaded }
    [IO.File]::WriteAllBytes($ArgumentList[3], $bytes)
    return ''
  }
  throw 'Unexpected cloud command'
}
$prefix='gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-28/test-campaign'
$build=28
${extra}
try {
  $proof=Copy-PrivateGcsCustodyFile -RepositoryRoot ${quote(root)} -Prefix $prefix -BuildNumber $build -SourcePath $source -ExpectedSha256 $expected -Purpose productionPackage -GcloudCommand fake
  @{ok=$true;proof=$proof;calls=@($script:calls.ToArray())} | ConvertTo-Json -Depth 12 -Compress
} catch {
  @{ok=$false;error=$_.Exception.Message;calls=@($script:calls.ToArray())} | ConvertTo-Json -Depth 12 -Compress
}
`;
    const scriptFile = path.join(directory, 'probe.ps1');
    fs.writeFileSync(scriptFile, script);
    const result = spawnSync('pwsh', ['-NoProfile', '-File', scriptFile], {encoding: 'utf8', windowsHide: true, timeout: 30000});
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    return JSON.parse(result.stdout.trim());
  } finally {
    assert.equal(path.dirname(fs.realpathSync(directory)), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(directory), /^crm3-gcs-test-/);
    fs.rmSync(directory, {recursive: true, force: true});
  }
}

test('private backup creates once and proves bytes from the created generation', () => {
  const result = probe('ok');
  assert.equal(result.ok, true, result.error);
  assert.equal(result.proof.generation, '1788912345678901');
  assert.equal(result.proof.bytes, 4);
  assert.equal(result.proof.downloadedSha256, result.proof.sha256);
  assert.equal(result.proof.createOnly, true);
  assert.equal(result.proof.generationPinnedReadback, true);
  assert.equal(result.proof.approval.commit, 'e1db8eaa4b34c26254d3fd2a4cfc533747e187a4');
  assert.equal(result.calls.filter((args) => args[1] === 'cp').length, 2);
  assert.equal(result.calls.some((args) => args.some((arg) => ['delete','rm','update','set-iam-policy'].includes(arg))), false);
});
for (const mode of ['public','public-iam','versioning','retention','soft-delete','location','acl']) {
  test(`changed ${mode} controls stop before any upload`, () => {
    const result = probe(mode);
    assert.equal(result.ok, false);
    assert.equal(result.calls.some((args) => args[1] === 'cp'), false);
  });
}
for (const mode of ['exists','lost-upload-response','missing-generation','wrong-created-object','wrong-generation','wrong-size','download-failure','corrupt-download','source-changed']) {
  test(`${mode} cannot create a verified custody claim or delete the uncertain backup`, () => {
    const result = probe(mode);
    assert.equal(result.ok, false);
    assert.equal(result.calls.filter((args) => args[1] === 'cp' && !args[2].startsWith('gs://')).length, 1);
    assert.equal(result.calls.some((args) => args.includes('rm') || args.includes('delete')), false);
  });
}
for (const [name, extra] of [
  ['wrong build', '$build=27'],
  ['other bucket', "$prefix='gs://gcf-v2-sources-894346496105-asia-south1/release-custody/build-28/test'"],
  ['outside prefix', "$prefix='gs://crm3-baf-ops-b8638-firestore-restore/pre-live/test'"],
  ['path traversal', "$prefix += '/../escape'"],
  ['wrong local hash', "$expected='0'*64"],
]) {
  test(`${name} fails before any cloud operation`, () => {
    const result = probe('ok', extra);
    assert.equal(result.ok, false);
    assert.deepEqual(result.calls, []);
  });
}

function finalizerGate(mode) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-gcs-gate-'));
  try {
    const script = `
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$finalizer=${quote(path.join(root, 'tools/release/Finalize-ProductionRelease.ps1'))}
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($finalizer,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw ($parseErrors | Out-String) }
foreach ($name in @('Write-Utf8NoBom','Get-Sha256','Copy-And-Verify','Copy-BackupCustody')) {
  $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
  . ([scriptblock]::Create($definition.Extent.Text))
}
. ${quote(path.join(root, 'tools/release/Private-GcsReleaseCustody.ps1'))}
$mode=${quote(mode)}
$privateCloudCustody=$mode -ne 'legacy-same-volume'
$cloudCustodyProofs=[Collections.Generic.List[object]]::new()
$script:backupPurposes=[Collections.Generic.List[string]]::new()
function Copy-PrivateGcsCustodyFile {
  param($RepositoryRoot,$Prefix,$BuildNumber,$SourcePath,$ExpectedSha256,$Purpose,$GcloudCommand)
  $script:backupPurposes.Add($Purpose)
  if ($mode -eq $Purpose -or $mode -eq "tail-$Purpose") { throw 'Independent cloud verification failed' }
  [pscustomobject]@{purpose=$Purpose;generationUri="$Prefix/$(Split-Path -Leaf $SourcePath)#123";verified=$true}
}
$repo=${quote(root)}
$temporary=${quote(directory)}
$PrimaryCustodyDirectory=Join-Path $temporary 'primary'
$BackupCustodyDirectory=Join-Path $temporary 'backup'
$BackupCustodyGsPrefix='gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-28/test-campaign'
$manifest=@{release=@{buildNumber=28}}
$GcloudCommand='fake'
$CustodyApprover='Fixture'; $CustodyReference='Fixture'
$packageZip=Join-Path $temporary 'release.zip'
[IO.File]::WriteAllBytes($packageZip,[byte[]](1,2,3,4))
$packageSha256=Get-Sha256 $packageZip
$packageSidecar="$packageZip.sha256.txt"
[IO.File]::WriteAllText($packageSidecar,"$packageSha256  release.zip")
$closureDirectory=Join-Path $temporary 'closure'
if ($mode -eq 'existing-primary') {
  [IO.Directory]::CreateDirectory($PrimaryCustodyDirectory) | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $PrimaryCustodyDirectory 'release.zip'),[byte[]](9,9,9,9))
}
$text=Get-Content -LiteralPath $finalizer -Raw
$start=$text.IndexOf('$primaryRoot = [IO.Path]::GetFullPath($PrimaryCustodyDirectory)')
$end=$text.IndexOf('# The built tag is created only after',$start)
if ($start -lt 0 -or $end -lt $start) { throw 'Production custody gate not found' }
$tagReached=$false
try {
  . ([scriptblock]::Create($text.Substring($start,$end-$start)))
  $tagReached=$true
  if ($mode -like 'tail-*') {
    $closureZip=Join-Path $temporary 'closure.zip'
    [IO.File]::WriteAllBytes($closureZip,[byte[]](5,6,7,8))
    $closureSha256=Get-Sha256 $closureZip
    $closureSidecar="$closureZip.sha256.txt"
    [IO.File]::WriteAllText($closureSidecar,"$closureSha256  closure.zip")
    $expected='c00c77e2a04a0a79a2bfab6d711e5ad2b59e6d56'; $GitHubRunId=1
    $reservationTag='crm3-build-reserved/28'; $builtTag='crm3-build-built/28'; $remoteBuiltCommit=$expected
    $builtAuthority=@{objectSha=('b'*40);contentsSha256=('b'*64)}
    $reservationAuthority=@{objectSha=('a'*40);contentsSha256=('a'*64)}
    $environmentReviewControl=@{mode='fixture';approvalReference='fixture'}
    $manifest.ciAuthority=@{dispatchApprovalReference='fixture';actor='fixture';actorId=1}
    $timestamp='fixture'
    $OutputDirectory=Join-Path $temporary 'output'
    $tailStart=$text.IndexOf('$primaryClosurePath = Copy-And-Verify')
    $tailEnd=$text.IndexOf("Write-Host ''",$tailStart)
    $null = . ([scriptblock]::Create($text.Substring($tailStart,$tailEnd-$tailStart))) 6>$null
    $verification=Get-Content -LiteralPath $cloudVerificationPath -Raw | ConvertFrom-Json
    @{ok=$true;tagReached=$tagReached;verification=$verification;custody=$finalCustodyRecord;purposes=@($script:backupPurposes.ToArray())} | ConvertTo-Json -Depth 12 -Compress
    exit 0
  }
  @{ok=$true;tagReached=$tagReached;receipt=$productionCustodyReceipt;purposes=@($script:backupPurposes.ToArray())} | ConvertTo-Json -Depth 9 -Compress
} catch {
  $primaryFile=Join-Path $PrimaryCustodyDirectory 'release.zip'
  @{ok=$false;tagReached=$tagReached;error=$_.Exception.Message;verificationExists=(Test-Path -LiteralPath (Join-Path $temporary 'output/PRIVATE_GCS_CUSTODY_READBACK_fixture.json'));purposes=@($script:backupPurposes.ToArray());primaryBytes=$(if(Test-Path -LiteralPath $primaryFile){@([IO.File]::ReadAllBytes($primaryFile))}else{@()})} | ConvertTo-Json -Depth 9 -Compress
}
`;
    const scriptFile = path.join(directory, 'gate.ps1');
    fs.writeFileSync(scriptFile, script);
    const result = spawnSync('pwsh', ['-NoProfile','-File',scriptFile], {encoding:'utf8',windowsHide:true,timeout:30000});
    assert.equal(result.status, 0, result.stderr || result.error?.message);
    return JSON.parse(result.stdout.trim());
  } finally {
    assert.equal(path.dirname(fs.realpathSync(directory)),fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(directory),/^crm3-gcs-gate-/);
    fs.rmSync(directory,{recursive:true,force:true});
  }
}

test('actual finalizer admits the cloud gate only after both independent object checks', () => {
  const result=finalizerGate('ok');
  assert.equal(result.ok,true,result.error);
  assert.equal(result.tagReached,true);
  assert.equal(result.receipt.mode,'local-primary-private-gcs-backup');
  assert.equal(result.receipt.schemaVersion,2);
  assert.deepEqual(result.purposes,['productionPackage','productionPackageSidecar']);
  assert.equal(Object.hasOwn(result.receipt,'backupPackagePath'),false);
  assert.equal(Object.hasOwn(result.receipt,'backupSidecarPath'),false);
  assert.equal(result.receipt.backup.objects.length,2);
});
for (const purpose of ['productionPackage','productionPackageSidecar']) {
  test(`actual finalizer never reaches built-tag gate when ${purpose} verification fails`, () => {
    const result=finalizerGate(purpose);
    assert.equal(result.ok,false);
    assert.equal(result.tagReached,false);
    assert.match(result.error,/Independent cloud verification failed/);
  });
}
test('new cloud mode cannot overwrite a primary backup', () => {
  const result=finalizerGate('existing-primary');
  assert.equal(result.ok,false);
  assert.equal(result.tagReached,false);
  assert.deepEqual(result.primaryBytes,[9,9,9,9]);
  assert.deepEqual(result.purposes,[]);
});
test('legacy filesystem mode still rejects two directories on the same volume', () => {
  const result=finalizerGate('legacy-same-volume');
  assert.equal(result.ok,false);
  assert.equal(result.tagReached,false);
  assert.match(result.error,/distinct volume\/share roots/);
  assert.deepEqual(result.purposes,[]);
});
test('actual finalizer emits its new typed manifest only after all six backup verifications', () => {
  const result=finalizerGate('tail-ok');
  assert.equal(result.ok,true,result.error);
  assert.equal(result.verification.evidenceType,'private-gcs-release-custody');
  assert.equal(result.verification.mode,'local-primary-private-gcs-backup');
  assert.equal(result.verification.buildNumber,28);
  assert.equal(result.verification.objects.length,6);
  assert.deepEqual(result.purposes,['productionPackage','productionPackageSidecar','closurePackage','closurePackageSidecar','custodyRecord','custodyRecordSidecar']);
  assert.equal(result.custody.schemaVersion,3);
  assert.equal(Object.hasOwn(result.custody,'backupProductionPackagePath'),false);
  assert.equal(Object.hasOwn(result.custody,'backupClosurePackagePath'),false);
  assert.equal(Object.hasOwn(result.custody,'backupClosureSidecarPath'),false);
});
for (const purpose of ['closurePackage','closurePackageSidecar','custodyRecord','custodyRecordSidecar']) {
  test(`actual finalizer does not emit completed cloud custody after failed ${purpose}`, () => {
    const result=finalizerGate(`tail-${purpose}`);
    assert.equal(result.ok,false);
    assert.equal(result.verificationExists,false);
    assert.match(result.error,/Independent cloud verification failed/);
  });
}
