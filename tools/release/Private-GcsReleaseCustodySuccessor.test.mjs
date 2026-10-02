import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const baseline = 'c76cfa38ffdf6ca323613af0270ffe00a40afc7c';
const approvalFile = 'release/approvals/build30-private-cloud-custody-approval.json';
const prefix = 'gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-30/synthetic-candidate';
const quote = value => `'${value.replaceAll("'", "''")}'`;
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();

function integrationChecks(directory, source, commit, hash) {
  return `
$parseTokens=$null; $parseErrors=$null
$policyAst=[Management.Automation.Language.Parser]::ParseFile(${quote(path.join(root, 'tools/release/Test-ProductionReleasePolicy.ps1'))},[ref]$parseTokens,[ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Policy parse failed' }
foreach ($name in @('Get-Sha256','Get-UtcEvidenceInstant','Get-PrivateCustodyUtcInstant','Test-PrivateCustodyFacts','Test-CompletedReleaseCustody')) {
  $definition=$policyAst.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
  . ([scriptblock]::Create($definition.Extent.Text))
}
$objects=@(); $hashes=@{}
foreach ($purpose in @('productionPackage','closurePackage','custodyRecord')) {
  $name=if($purpose -eq 'productionPackage'){'synthetic-release-b30-GOVERNED-PACKAGE.zip'}else{"$purpose.zip"}
  $parent=$proof | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $parent.purpose=$purpose; $parent.objectName="release-custody/build-30/synthetic-candidate/$name"
  $parent.objectUri="${prefix}/$name"; $parent.generationUri="$($parent.objectUri)#123"
  $hashes[$purpose]=$parent.sha256; $objects+=,$parent
  $sidecar=$parent | ConvertTo-Json -Depth 12 | ConvertFrom-Json
  $sidecar.purpose="$($purpose)Sidecar"; $sidecar.objectName+='.sha256.txt'; $sidecar.objectUri+='.sha256.txt'
  $sidecar.generationUri="$($sidecar.objectUri)#123"
  $bytes=[Text.Encoding]::UTF8.GetBytes("$($parent.sha256)  $name" + [char]10)
  $sidecar.sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
  $sidecar.downloadedSha256=$sidecar.sha256; $sidecar.bytes=$bytes.Length; $sidecar.downloadedBytes=$bytes.Length
  $hashes[$sidecar.purpose]=$sidecar.sha256; $objects+=,$sidecar
}
$verification=@{schemaVersion=1;evidenceType='private-gcs-release-custody';mode='local-primary-private-gcs-backup';buildNumber=30;sourceCommit='${source}';githubRunId='1';primaryDirectory='C:\\synthetic-owner-custody';backupPrefix='${prefix}';independentlyStored=$true;status='passed';completedAtUtc=[DateTime]::UtcNow.ToString('o');approval=$proof.approval;objects=$objects}
$evidenceFile='release/evidence/build30-private-gcs-custody-readback.json'
$evidencePath=Join-Path ${quote(directory)} $evidenceFile
[IO.Directory]::CreateDirectory((Split-Path $evidencePath)) | Out-Null
[IO.File]::WriteAllText($evidencePath,($verification | ConvertTo-Json -Depth 20))
$receipt=@{release=@{buildNumber=30;releaseId='synthetic-release-b30'};sourceAuthority=@{commit='${source}'};workflow=@{runId=1};dualCustody=@{mode='local-primary-private-gcs-backup';distinctVolumes=$false;independentlyStored=$true;status='passed';allFileHashesMatched=$true;backupVerification=@{file=$evidenceFile;sha256=(Get-Sha256 $evidencePath)}};governedPackage=@{sha256=$hashes.productionPackage;sidecarSha256=$hashes.productionPackageSidecar};closure=@{closurePackageSha256=$hashes.closurePackage;custodyRecordSha256=$hashes.custodyRecord;closurePackageSidecarSha256=$hashes.closurePackageSidecar}} | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$readerPassed=Test-CompletedReleaseCustody $receipt ${quote(directory)}
$readerRefusals=@()
foreach ($mutation in @('release','source','approvalHash','crossBuildProof','sidecar','prefix')) {
  $r=$receipt | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  $v=$verification | ConvertTo-Json -Depth 20 | ConvertFrom-Json
  switch($mutation) {
    'release' { $r.release.releaseId='other' }
    'source' { $r.sourceAuthority.commit='${baseline}' }
    'approvalHash' { $v.approval.sha256='0'*64 }
    'crossBuildProof' { $v.objects[0].buildNumber=29 }
    'sidecar' { $v.objects[1].sha256='0'*64; $v.objects[1].downloadedSha256='0'*64 }
    'prefix' { $v.backupPrefix+='-other' }
  }
  [IO.File]::WriteAllText($evidencePath,($v | ConvertTo-Json -Depth 20))
  $r.dualCustody.backupVerification.sha256=Get-Sha256 $evidencePath
  $readerRefusals+=,@{mutation=$mutation;refused=(-not(Test-CompletedReleaseCustody $r ${quote(directory)}))}
}
$finalizerAst=[Management.Automation.Language.Parser]::ParseFile(${quote(path.join(root, 'tools/release/Finalize-ProductionRelease.ps1'))},[ref]$parseTokens,[ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Finalizer parse failed' }
$finalizerText=Get-Content -LiteralPath ${quote(path.join(root, 'tools/release/Finalize-ProductionRelease.ps1'))} -Raw
$gateStart=$finalizerText.IndexOf('$head = (git rev-parse HEAD)')
$gateEnd=$finalizerText.IndexOf('$repositorySlug = Get-RepositorySlug',$gateStart)
if ($gateStart -lt 0 -or $gateEnd -lt $gateStart) { throw 'Exact-main gate missing' }
$ExpectedCommit='${source}'
function Get-RemoteRefCommit { param($RefName) if($RefName -cne 'refs/heads/main'){throw 'Unexpected remote read'}; return '${source}' }
Push-Location ${quote(directory)}
try {
  if (@(git status --porcelain=v1 --untracked-files=all).Count -gt 0) { throw 'Synthetic artifact checkout is not clean' }
  . ([scriptblock]::Create($finalizerText.Substring($gateStart,$gateEnd-$gateStart)))
  $exactMainPassed=$head -ceq $expected -and $originMain -ceq $expected -and $liveMain -ceq $expected
} finally { Pop-Location }
$definition=$finalizerAst.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Copy-BackupCustody'},$true)
. ([scriptblock]::Create($definition.Extent.Text))
$privateCloudCustody=$true; $repo=${quote(directory)}; $manifest=@{release=@{buildNumber=30}}
$expected='${source}'; $PrivateCustodyApprovalCommit='${commit}'; $PrivateCustodyApprovalSha256='${hash}'
$BackupCustodyGsPrefix='${prefix}'; $GcloudCommand='fake'; $cloudCustodyProofs=[Collections.Generic.List[object]]::new()
$forwarded=$false
function Copy-PrivateGcsCustodyFile {
  param($RepositoryRoot,$Prefix,$BuildNumber,$SourcePath,$ExpectedSha256,$Purpose,$GcloudCommand,$CandidateSourceCommit,$ApprovalCommit,$ApprovalSha256)
  if ($RepositoryRoot -cne $repo -or $Prefix -cne $BackupCustodyGsPrefix -or $BuildNumber -ne 30 -or $CandidateSourceCommit -cne $expected -or $ApprovalCommit -cne $PrivateCustodyApprovalCommit -or $ApprovalSha256 -cne $PrivateCustodyApprovalSha256) { throw 'Caller lost candidate binding' }
  $script:forwarded=$true
  [pscustomobject]@{buildNumber=30;generationUri='synthetic-generation'}
}
$null=Copy-BackupCustody $sourceFile $proof.sha256 productionPackage
$integration=@{readerPassed=$readerPassed;readerRefusals=$readerRefusals;exactMainPassed=$exactMainPassed;callerForwarded=$script:forwarded;proofCount=$cloudCustodyProofs.Count}
`;
}

function probe(mutate = () => {}, options = {}) {
  const candidateBuild = options.candidateBuild ?? 30;
  const baseline = candidateBuild === 31 ? '7ed87824447f1349cb0481c448e0b21c3fa5856f' : 'c76cfa38ffdf6ca323613af0270ffe00a40afc7c';
  const approvalFile = `release/approvals/build${candidateBuild}-private-cloud-custody-approval.json`;
  const prefix = `gs://crm3-baf-ops-b8638-firestore-restore/release-custody/build-${candidateBuild}/synthetic-candidate`;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'crm3-gcs-successor-'));
  const run = (command, args, extra = {}) => {
    const result = spawnSync(command, args, {cwd: directory, encoding: 'utf8', windowsHide: true,
      timeout: 30000, ...extra});
    assert.equal(result.status, 0, [result.error?.message, result.signal, result.stderr, result.stdout].filter(Boolean).join('\n'));
    return result.stdout.trim();
  };
  try {
    run('git', ['init', '--quiet']);
    const objects = run('git', ['rev-parse', '--path-format=absolute', '--git-path', 'objects'], {cwd: root});
    fs.mkdirSync(path.join(directory, '.git/objects/info'), {recursive: true});
    fs.writeFileSync(path.join(directory, '.git/objects/info/alternates'), `${objects.replaceAll('\\', '/')}\n`);
    const now = Date.now();
    const instant = delta => new Date(now + delta).toISOString();
    const gitEnv = {...process.env, GIT_AUTHOR_NAME: 'Synthetic Fixture',
      GIT_AUTHOR_EMAIL: 'fixture@example.invalid', GIT_COMMITTER_NAME: 'Synthetic Fixture',
      GIT_COMMITTER_EMAIL: 'fixture@example.invalid', GIT_AUTHOR_DATE: instant(-120000),
      GIT_COMMITTER_DATE: instant(-120000)};
    const write = (file, value) => {
      fs.mkdirSync(path.dirname(path.join(directory, file)), {recursive: true});
      fs.writeFileSync(path.join(directory, file), `${JSON.stringify(value, null, 2)}\n`);
    };
    const ledger = {schemaVersion: 2, entries: [{buildNumber: candidateBuild, reservationId: `synthetic-candidate-${candidateBuild}`,
      releaseId: `synthetic-release-b${candidateBuild}`, campaignId: 'synthetic-candidate'}]};
    if (options.ledger) options.ledger(ledger);
    write('release/build-number-ledger.json', ledger);
    run('git', ['add', 'release/build-number-ledger.json']);
    const sourceBaseline = run('git', ['commit-tree', run('git', ['write-tree']), '-p', baseline, '-m', 'Synthetic allocation baseline'], {env: gitEnv});
    const approval = {schemaVersion: 2, documentType: 'candidate-specific-private-release-backup-custody-decision',
      approved: true, approvedAtUtc: instant(-10000), approverName: 'Synthetic test decision',
      authorityType: 'owner-delegated agent decision', sourceBaselineCommit: sourceBaseline, buildNumber: candidateBuild,
      candidateLedgerGitBlob: run('git', ['rev-parse', `${sourceBaseline}:release/build-number-ledger.json`]),
      reservationId: `synthetic-candidate-${candidateBuild}`, releaseId: `synthetic-release-b${candidateBuild}`, campaignId: 'synthetic-candidate',
      firebaseProjectId: 'crm3-baf-ops-b8638', permanentApplicationId: 'in.co.sail.bsl.crm3.bafops',
      scope: 'private-release-custody-only', custodyMode: 'local-primary-private-gcs-backup',
      ownerInstruction: {reference: 'synthetic-test-instruction', text: 'Synthetic authorization for test only.', recordedAtUtc: instant(-60000)},
      backup: {bucket: 'crm3-baf-ops-b8638-firestore-restore', prefix, location: 'ASIA-SOUTH1',
        publicAccessPrevention: 'enforced', uniformBucketLevelAccessRequired: true,
        publicIamPrincipalsProhibited: true, versioningRequired: true, existingRetentionSeconds: 7776000,
        existingSoftDeleteSeconds: 604800, acceptExistingRetentionAndOrdinaryStorageCharges: true,
        createOnlyGenerationPreconditionRequired: true, overwriteOrDeleteAuthorized: false,
        accessControlOrBucketConfigurationMutationAuthorized: false}};
    mutate(approval);
    write(approvalFile, approval);
    run('git', ['add', approvalFile]);
    const commit = run('git', ['commit-tree', run('git', ['write-tree']), '-p', options.unrelatedApproval ? baseline : sourceBaseline,
      '-m', 'Synthetic custody decision'], {env: {...gitEnv, GIT_AUTHOR_DATE: instant(-5000), GIT_COMMITTER_DATE: instant(options.futureCommit ? 60000 : -5000)}});
    const hash = digest(fs.readFileSync(path.join(directory, approvalFile)));
    if (options.changedAllocation) {
      ledger.entries[0].reservationId = 'changed-after-approval';
      write('release/build-number-ledger.json', ledger);
      run('git', ['add', 'release/build-number-ledger.json']);
    }
    if (options.changedDecision) {
      write(approvalFile, {...approval, approverName: 'Changed after approval'});
      run('git', ['add', approvalFile]);
    }
    const source = run('git', ['commit-tree', run('git', ['write-tree']), '-p', options.unrelatedArtifact ? sourceBaseline : commit,
      '-m', 'Synthetic exact artifact source'], {env: {...gitEnv, GIT_AUTHOR_DATE: instant(-1000), GIT_COMMITTER_DATE: instant(-1000)}});
    if (options.changedDecision) write(approvalFile, approval);
    run('git', ['update-ref', 'refs/heads/fixture', options.unreachableApproval ? sourceBaseline : source]);
    run('git', ['update-ref', 'refs/remotes/origin/main', source]);
    run('git', ['symbolic-ref', 'HEAD', 'refs/heads/fixture']);
    // Untracked test harness/download files are not artifact source content.
    fs.writeFileSync(path.join(directory, '.git/info/exclude'), '*\n');
    if (options.dirty) fs.appendFileSync(path.join(directory, approvalFile), ' ');
    fs.mkdirSync(path.join(directory, 'tools/release'), {recursive: true});
    fs.copyFileSync(path.join(root, 'tools/release/Private-GcsReleaseCustody.ps1'), path.join(directory, 'tools/release/Private-GcsReleaseCustody.ps1'));
    let script = `
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. ${quote(path.join(root, 'tools/release/Private-GcsReleaseCustody.ps1'))}
$calls=[Collections.Generic.List[object]]::new()
function Invoke-PrivateGcsCommand([string]$Command,[string[]]$ArgumentList) {
  $calls.Add(@($ArgumentList))
  if ($ArgumentList[1] -eq 'buckets' -and $ArgumentList[2] -eq 'describe') {
    return (@{name='crm3-baf-ops-b8638-firestore-restore';location='ASIA-SOUTH1';public_access_prevention='enforced';uniform_bucket_level_access=$true;versioning_enabled=$true;retention_policy=@{retentionPeriod='7776000'};soft_delete_policy=@{retentionDurationSeconds='604800'}} | ConvertTo-Json -Depth 5)
  }
  if ($ArgumentList[1] -eq 'buckets') { return (@{bindings=@(@{role='roles/storage.legacyBucketOwner';members=@('projectOwner:crm3-baf-ops-b8638')})} | ConvertTo-Json -Depth 5) }
  if ($ArgumentList[1] -eq 'objects') {
    if ($ArgumentList[3] -cne '${prefix}/release.zip#123') { throw 'Unpinned lookup' }
    return (@{bucket='crm3-baf-ops-b8638-firestore-restore';name='release-custody/build-30/synthetic-candidate/release.zip';generation='123';size='4'} | ConvertTo-Json)
  }
  if ($ArgumentList[2] -like 'gs://*') {
    if ($ArgumentList[2] -cne '${prefix}/release.zip#123') { throw 'Unpinned download' }
    [IO.File]::WriteAllBytes($ArgumentList[3], [byte[]](1,2,3,4)); return ''
  }
  if ($ArgumentList -notcontains '--if-generation-match=0') { throw 'Overwrite risk' }
  return 'Created: ${prefix}/release.zip#123'
}
$sourceFile=Join-Path ${quote(directory)} 'release.zip'
[IO.File]::WriteAllBytes($sourceFile,[byte[]](1,2,3,4))
$binding=@{CandidateSourceCommit=${quote(options.wrongSource ? baseline : source)};ApprovalCommit=${quote(commit)};ApprovalSha256=${quote(options.wrongHash ? '0'.repeat(64) : hash)}}
${options.noBinding ? '$binding=@{}' : ''}
try {
  $proof=Copy-PrivateGcsCustodyFile -RepositoryRoot ${quote(directory)} -Prefix ${quote(options.wrongPrefix ? `${prefix}-other` : prefix)} -BuildNumber ${options.build ?? candidateBuild} -SourcePath $sourceFile -ExpectedSha256 (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -Purpose productionPackage -GcloudCommand fake @binding
  $integration=$null
  ${options.integration ? integrationChecks(directory, source, commit, hash) : ''}
  @{ok=$true;proof=$proof;integration=$integration;calls=@($calls.ToArray())} | ConvertTo-Json -Depth 12 -Compress
} catch { @{ok=$false;error=$_.Exception.Message;calls=@($calls.ToArray())} | ConvertTo-Json -Depth 12 -Compress }
`;
    // Reuse the exact synthetic proof/reader/caller exercise for31. Production
    // code is loaded unchanged; this only selects the fixture's candidate IDs.
    if (candidateBuild === 31) script = script.replaceAll('build-30', 'build-31')
      .replaceAll('build30', 'build31').replaceAll('-b30', '-b31')
      .replaceAll('buildNumber=30', 'buildNumber=31').replaceAll('$BuildNumber -ne 30', '$BuildNumber -ne 31');
    fs.writeFileSync(path.join(directory, 'probe.ps1'), script);
    // The integration fixture re-reads seven complete Git-backed receipts.
    // Keep each simple command bounded while allowing that deliberate matrix
    // to complete on a busy Windows host; this changes no cloud/retry limits.
    return JSON.parse(run('pwsh', ['-NoProfile', '-File', path.join(directory, 'probe.ps1')],
      {timeout: options.integration ? 90000 : 30000}));
  } finally {
    assert.equal(path.dirname(fs.realpathSync(directory)), fs.realpathSync(os.tmpdir()));
    assert.match(path.basename(directory), /^crm3-gcs-successor-/);
    fs.rmSync(directory, {recursive: true, force: true});
  }
}

test('Build30 exact committed candidate approval permits only generation-pinned create/readback', () => {
  const result = probe(undefined, {integration: true});
  assert.equal(result.ok, true, result.error);
  assert.equal(result.proof.buildNumber, 30);
  assert.equal(result.proof.prefix, prefix);
  assert.equal(result.proof.approval.file, approvalFile);
  assert.equal(result.proof.sha256, result.proof.downloadedSha256);
  assert.equal(result.calls.length, 5);
  assert.equal(result.calls.some(args => args.some(arg => ['delete','rm','set-iam-policy','update'].includes(arg))), false);
  assert.equal(result.integration.readerPassed, true);
  assert.equal(result.integration.exactMainPassed, true);
  assert.equal(result.integration.callerForwarded, true);
  assert.equal(result.integration.proofCount, 1);
  assert.equal(result.integration.readerRefusals.length, 6);
  assert.ok(result.integration.readerRefusals.every(row => row.refused), JSON.stringify(result.integration.readerRefusals));
});

test('Build31 separately committed custody is bound through producer, finalizer and six-proof reader', () => {
  const result = probe(undefined, {candidateBuild: 31, integration: true});
  assert.equal(result.ok, true, result.error);
  assert.equal(result.proof.buildNumber, 31);
  assert.equal(result.proof.approval.file, 'release/approvals/build31-private-cloud-custody-approval.json');
  assert.equal(result.integration.readerPassed, true);
  assert.equal(result.integration.callerForwarded, true);
  assert.equal(result.integration.exactMainPassed, true);
  assert.ok(result.integration.readerRefusals.every(row => row.refused), JSON.stringify(result.integration.readerRefusals));
});

for (const [label, options] of [
  ['old Build30 decision', {build: 30}], ['future Build32', {build: 32}],
  ['missing binding', {noBinding: true}], ['changed ledger', {changedAllocation: true}],
  ['changed custody', {changedDecision: true}], ['unrelated custody', {unrelatedApproval: true}],
  ['unrelated artifact', {unrelatedArtifact: true}], ['wrong digest', {wrongHash: true}],
]) {
  test(`Build31 refuses ${label} before private cloud access`, () => {
    const result = probe(undefined, {candidateBuild: 31, ...options});
    assert.equal(result.ok, false); assert.deepEqual(result.calls, []);
  });
}

for (const [name, mutation] of [
  ['unapproved', a => { a.approved = false; }],
  ['string approval', a => { a.approved = 'true'; }],
  ['wrong build', a => { a.buildNumber = 29; }],
  ['wrong source baseline', a => { a.sourceBaselineCommit = baseline; }],
  ['wrong allocation blob', a => { a.candidateLedgerGitBlob = '0'.repeat(40); }],
  ['wrong reservation', a => { a.reservationId = 'other'; }],
  ['wrong release', a => { a.releaseId = 'other'; }],
  ['wrong campaign', a => { a.campaignId = 'other'; }],
  ['wrong project', a => { a.firebaseProjectId = 'another-project'; }],
  ['wrong app', a => { a.permanentApplicationId = 'another.app'; }],
  ['unbounded scope', a => { a.scope = 'all-future-builds'; }],
  ['blank instruction reference', a => { a.ownerInstruction.reference = ' '; }],
  ['blank instruction', a => { a.ownerInstruction.text = ''; }],
  ['future decision', a => { a.approvedAtUtc = '2099-01-01T00:00:00Z'; }],
  ['decision later than its custody commit', a => { a.approvedAtUtc = new Date(Date.now() - 1000).toISOString(); }],
  ['decision before instruction', a => { a.approvedAtUtc = '2020-01-01T00:00:00Z'; }],
  ['unqualified time', a => { a.approvedAtUtc = '2026-09-27T12:00:00'; }],
  ['different prefix', a => { a.backup.prefix += '-different'; }],
  ['different bucket', a => { a.backup.bucket = 'another-bucket'; }],
  ['different region', a => { a.backup.location = 'US-CENTRAL1'; }],
  ['public access', a => { a.backup.publicAccessPrevention = 'inherited'; }],
  ['overwrite permission', a => { a.backup.overwriteOrDeleteAuthorized = true; }],
  ['IAM mutation permission', a => { a.backup.accessControlOrBucketConfigurationMutationAuthorized = true; }],
  ['shorter retention', a => { a.backup.existingRetentionSeconds = 1; }],
]) {
  test(`Build30 refuses ${name} even in a coherently committed approval before cloud access`, () => {
    const result = probe(mutation);
    assert.equal(result.ok, false, name);
    assert.deepEqual(result.calls, []);
  });
}
for (const [name, options] of [
  ['missing explicit binding', {noBinding: true}], ['wrong selected source', {wrongSource: true}],
  ['wrong selected digest', {wrongHash: true}], ['dirty approval', {dirty: true}],
  ['unrelated approval history', {unrelatedApproval: true}], ['unreachable approval', {unreachableApproval: true}],
  ['artifact outside approval history', {unrelatedArtifact: true}],
  ['changed allocation in artifact', {changedAllocation: true}],
  ['changed decision in artifact', {changedDecision: true}],
  ['future approval custody commit', {futureCommit: true}],
  ['different requested prefix', {wrongPrefix: true}], ['future Build31', {build: 31}],
  ['missing ledger candidate', {ledger: l => { l.entries = []; }}],
  ['duplicate ledger candidate', {ledger: l => { l.entries.push({...l.entries[0]}); }}],
  ['string ledger build', {ledger: l => { l.entries[0].buildNumber = '30'; }}],
  ['unsafe ledger campaign', {ledger: l => { l.entries[0].campaignId = '../escape'; }}],
]) {
  test(`Build30 refuses ${name} without cloud calls`, () => {
    const result = probe(undefined, options);
    assert.equal(result.ok, false, name);
    assert.deepEqual(result.calls, []);
  });
}
