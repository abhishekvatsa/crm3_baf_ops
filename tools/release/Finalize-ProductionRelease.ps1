#requires -Version 7.0
<#
.SYNOPSIS
Finalizes O-01 to O-05 from an exact successful protected GitHub Actions run.

.DESCRIPTION
The finalizer does not accept an arbitrary local artifact. It queries the
GitHub run, verifies the workflow and PR, downloads the named run artifact,
requires and verifies the package sidecar, runs the package-contained verifier,
proves the remote build-number reservation, establishes production-package
dual custody, creates the remote built tag, emits the closure package, and
establishes closure-package dual custody.

O-05 closes only as a production-signed, independently verified,
non-distributable pre-release artifact. Controlled-pilot promotion is separate.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$RepoPath,
  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9a-fA-F]{40}$')]
  [string]$ExpectedCommit,
  [Parameter(Mandatory)][int]$PullRequestNumber,
  [Parameter(Mandatory)][long]$GitHubRunId,
  [Parameter(Mandatory)][string]$ArtifactName,
  [Parameter(Mandatory)][string]$PrimaryCustodyDirectory,
  [Parameter(Mandatory)][string]$BackupCustodyDirectory,
  [Parameter(Mandatory)][string]$CustodyApprover,
  [Parameter(Mandatory)][string]$CustodyReference,
  [string]$OutputDirectory = "$HOME\Downloads"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ExpectedRepositorySlug = 'abhishekvatsa/crm3_baf_ops'
$ExpectedWorkflowPath = '.github/workflows/production-artifact.yml'
$ExpectedEnvironmentName = 'crm3-baf-ops-production-signing'
$ExpectedEnvironmentSecretNames = @(
  'CRM_ANDROID_RELEASE_KEY_ALIAS'
  'CRM_ANDROID_RELEASE_KEY_PASSWORD'
  'CRM_ANDROID_RELEASE_KEYSTORE_BASE64'
  'CRM_ANDROID_RELEASE_STORE_PASSWORD'
)

if ($PullRequestNumber -le 0 -or $GitHubRunId -le 0) {
  throw 'PullRequestNumber and GitHubRunId must be positive.'
}
foreach ($value in @($ArtifactName, $CustodyApprover, $CustodyReference)) {
  if ([string]::IsNullOrWhiteSpace([string]$value) -or
      [string]$value -match '^REPLACE_') {
    throw 'Artifact name, custody approver and custody reference are mandatory.'
  }
}
if ($ArtifactName -notmatch '^[A-Za-z0-9._-]+$') {
  throw 'ArtifactName contains unsafe characters.'
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [AllowEmptyString()][string]$Text
  )

  $parent = Split-Path -Parent $Path
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }

  [IO.File]::WriteAllText(
    $Path,
    $Text,
    [Text.UTF8Encoding]::new($false)
  )
}

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }

  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-RepositorySlug {
  $url = (git remote get-url origin).Trim()
  if ($url -match
    'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$') {
    return "$($Matches.owner)/$($Matches.repo)"
  }

  throw "Unable to derive GitHub repository from origin URL: $url"
}

function Get-RemoteRefCommit {
  param([Parameter(Mandatory)][string]$RefName)

  $queries = @($RefName)
  if ($RefName -like 'refs/tags/*' -and $RefName -notmatch '\^\{\}$') {
    $queries += "$RefName^{}"
  }

  $lines = @(git ls-remote origin @queries)
  if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
    return $null
  }

  $peeled = $lines |
    Where-Object { $_ -match '\^\{\}$' } |
    Select-Object -First 1
  $chosen = if ($null -ne $peeled) {
    $peeled
  }
  else {
    $lines | Select-Object -First 1
  }

  (($chosen -split '\s+')[0]).Trim().ToLowerInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [Text.Encoding]::UTF8.GetBytes($Text)
    )
  )
}

function Get-LocalAnnotatedTagAuthority {
  param(
    [Parameter(Mandatory)][string]$TagName,
    [Parameter(Mandatory)][string]$ExpectedCommit
  )

  $tagRef = "refs/tags/$TagName"
  $objectSha = @(git rev-parse "$tagRef^{tag}")
  if ($LASTEXITCODE -ne 0 -or $objectSha.Count -ne 1) {
    throw "Expected annotated remote tag authority: $TagName"
  }

  $peeledCommit = @(git rev-parse "$tagRef^{}")
  if ($LASTEXITCODE -ne 0 -or $peeledCommit.Count -ne 1 -or
      $peeledCommit[0].Trim().ToLowerInvariant() -ne
        $ExpectedCommit.ToLowerInvariant()) {
    throw "Annotated tag does not peel to expected commit: $TagName"
  }

  $contentLines = @(
    git for-each-ref '--format=%(contents)' $tagRef
  )
  if ($LASTEXITCODE -ne 0 -or $contentLines.Count -eq 0) {
    throw "Unable to read annotated tag contents: $TagName"
  }

  $contents = (($contentLines -join "`n").TrimEnd() + "`n")
  [ordered]@{
    objectSha = $objectSha[0].Trim().ToLowerInvariant()
    peeledCommit = $peeledCommit[0].Trim().ToLowerInvariant()
    contents = $contents
    contentsSha256 = Get-TextSha256 $contents
  }
}

function Fetch-RemoteAnnotatedTag {
  param([Parameter(Mandatory)][string]$TagName)

  $ref = "refs/tags/$TagName"
  if (@(git tag --list $TagName).Count -gt 0) {
    git tag -d $TagName | Out-Null
  }
  git fetch origin "$ref`:$ref" --force
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to fetch remote annotated tag: $TagName"
  }
}

function Assert-RequiredSidecar {
  param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$SidecarPath
  )

  if (-not (Test-Path -LiteralPath $SidecarPath -PathType Leaf)) {
    throw "Mandatory package sidecar is absent: $SidecarPath"
  }

  $actual = Get-Sha256 $PackagePath
  $content = (Get-Content -LiteralPath $SidecarPath -Raw).Trim()
  $parts = $content -split '\s+'

  if ($parts.Count -ne 2 -or
      $parts[0].ToUpperInvariant() -ne $actual -or
      $parts[1] -ne (Split-Path -Leaf $PackagePath)) {
    throw 'Package sidecar must contain the exact hash and filename.'
  }

  $actual
}

function Copy-And-Verify {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestinationDirectory,
    [Parameter(Mandatory)][string]$ExpectedSha256
  )

  New-Item -ItemType Directory -Force -Path $DestinationDirectory |
    Out-Null
  $destination = Join-Path $DestinationDirectory (
    Split-Path -Leaf $SourcePath
  )
  Copy-Item -LiteralPath $SourcePath -Destination $destination -Force

  if ((Get-Sha256 $destination) -ne $ExpectedSha256) {
    throw "Custody-copy hash mismatch: $destination"
  }

  [IO.Path]::GetFullPath($destination)
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git is unavailable.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw 'GitHub CLI (gh) is required for authoritative finalization.'
}
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
  throw 'PowerShell 7 is required.'
}

Set-Location (Resolve-Path -LiteralPath $RepoPath)
$repo = (Get-Location).Path
$currentBranchOutput = @(git branch --show-current)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to determine the current branch.'
}
$currentBranch = ($currentBranchOutput -join "`n").Trim()
if ($currentBranch -ne 'main') {
  throw 'Finalization must run from local main.'
}

if (@(git status --porcelain=v1 --untracked-files=all).Count -gt 0) {
  throw 'Repository is dirty.'
}

git fetch --prune origin
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to refresh origin.'
}
git fsck --full
if ($LASTEXITCODE -ne 0) {
  throw 'git fsck failed.'
}

$head = (git rev-parse HEAD).Trim().ToLowerInvariant()
$originMain = (git rev-parse origin/main).Trim().ToLowerInvariant()
$liveMain = Get-RemoteRefCommit -RefName 'refs/heads/main'
$expected = $ExpectedCommit.ToLowerInvariant()

if ($head -ne $expected -or
    $originMain -ne $expected -or
    $liveMain -ne $expected) {
  throw 'Expected commit is not exact clean local/origin/live main.'
}

$repositorySlug = Get-RepositorySlug
if ($repositorySlug -ne $ExpectedRepositorySlug) {
  throw "Origin repository differs from governed authority: $repositorySlug"
}

$runJsonText = @(
  gh api "repos/$repositorySlug/actions/runs/$GitHubRunId"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read the GitHub Actions run.'
}
$run = ($runJsonText -join "`n") | ConvertFrom-Json

if ([string]$run.status -ne 'completed' -or
    [string]$run.conclusion -ne 'success' -or
    [string]$run.event -ne 'workflow_dispatch' -or
    [string]$run.head_branch -ne 'main' -or
    [string]$run.head_sha -ne $expected -or
    [string]$run.repository.full_name -ne $repositorySlug -or
    [string]$run.path -ne $ExpectedWorkflowPath) {
  throw 'GitHub run is not the successful approved workflow on exact commit.'
}

$artifactsJsonText = @(
  gh api "repos/$repositorySlug/actions/runs/$GitHubRunId/artifacts?per_page=100"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read GitHub Actions artifacts.'
}
$artifacts = ($artifactsJsonText -join "`n") | ConvertFrom-Json
$selectedArtifacts = @(
  $artifacts.artifacts |
    Where-Object { [string]$_.name -eq $ArtifactName }
)
if ($selectedArtifacts.Count -ne 1 -or
    $selectedArtifacts[0].expired -ne $false) {
  throw 'Named GitHub artifact is absent, duplicated or expired.'
}
$selectedArtifact = $selectedArtifacts[0]
$artifactDigestProperty = $selectedArtifact.PSObject.Properties['digest']
$selectedArtifactDigest = if ($null -ne $artifactDigestProperty) {
  [string]$artifactDigestProperty.Value
}
else {
  $null
}

$jobsJsonText = @(
  gh api "repos/$repositorySlug/actions/runs/$GitHubRunId/jobs?per_page=100"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read GitHub Actions jobs.'
}
$jobs = ($jobsJsonText -join "`n") | ConvertFrom-Json
$buildJob = $jobs.jobs |
  Where-Object {
    [string]$_.name -eq
      'Governed production-signed pre-release artifact'
  } |
  Select-Object -First 1

if ($null -eq $buildJob -or
    [string]$buildJob.status -ne 'completed' -or
    [string]$buildJob.conclusion -ne 'success') {
  throw 'Governed production build job did not complete successfully.'
}

$prJsonText = @(
  gh pr view $PullRequestNumber `
    --repo $repositorySlug `
    --json number,title,state,mergedAt,mergedBy,mergeCommit,headRefOid,baseRefName,url,commits
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to capture pull-request merge evidence.'
}
$pullRequest = ($prJsonText -join "`n") | ConvertFrom-Json

$mergeCommitOid =
  ([string]$pullRequest.mergeCommit.oid).ToLowerInvariant()
if ([string]$pullRequest.state -ne 'MERGED' -or
    [string]$pullRequest.baseRefName -ne 'main' -or
    $mergeCommitOid -ne $expected -or
    [string]::IsNullOrWhiteSpace([string]$pullRequest.mergedBy.login)) {
  throw 'Pull request is not merged to main at the expected commit.'
}

$prCommits = @($pullRequest.commits)
if ($prCommits.Count -lt 1) {
  throw 'Governed production PR contains no commits.'
}
if (([string]$pullRequest.headRefOid).ToLowerInvariant() -ne
    ([string]$prCommits[-1].oid).ToLowerInvariant()) {
  throw 'PR head authority does not match its final governed commit.'
}

$timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$work = Join-Path $OutputDirectory (
  "CRM_III_BAF_Ops_O1_O5_FINALIZATION_$timestamp"
)
$downloadDirectory = Join-Path $work 'github-artifact-download'
$extractedDirectory = Join-Path $work 'artifact-extracted'
$closureDirectory = Join-Path $work 'closure-evidence'

New-Item -ItemType Directory -Force -Path $downloadDirectory |
  Out-Null
New-Item -ItemType Directory -Force -Path $extractedDirectory |
  Out-Null
New-Item -ItemType Directory -Force -Path $closureDirectory |
  Out-Null

gh run download $GitHubRunId `
  --repo $repositorySlug `
  --name $ArtifactName `
  --dir $downloadDirectory
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to download the named GitHub workflow artifact.'
}

$downloadedFiles = @(
  Get-ChildItem -LiteralPath $downloadDirectory -File -Recurse
)
if ($downloadedFiles.Count -ne 2) {
  throw "Workflow artifact must contain exactly package ZIP plus sidecar; found $($downloadedFiles.Count) files."
}

$packageCandidates = @(
  Get-ChildItem -LiteralPath $downloadDirectory -File -Recurse `
    -Filter '*-GOVERNED-PACKAGE.zip'
)
if ($packageCandidates.Count -ne 1) {
  throw "Expected one governed package ZIP; found $($packageCandidates.Count)."
}

$packageZip = $packageCandidates[0].FullName
$packageSidecar = "$packageZip.sha256.txt"
$packageSha256 = Assert-RequiredSidecar `
  -PackagePath $packageZip `
  -SidecarPath $packageSidecar

Expand-Archive -LiteralPath $packageZip `
  -DestinationPath $extractedDirectory

$manifestFiles = @(
  Get-ChildItem -LiteralPath $extractedDirectory -File -Recurse `
    -Filter 'production-release-manifest.json'
)
$verifierFiles = @(
  Get-ChildItem -LiteralPath $extractedDirectory -File -Recurse `
    -Filter 'verify-production-release-package.ps1'
)
if ($manifestFiles.Count -ne 1 -or $verifierFiles.Count -ne 1) {
  throw 'Artifact package must contain exactly one manifest and one verifier.'
}

$manifestPath = $manifestFiles[0].FullName
$verifierPath = $verifierFiles[0].FullName
$verificationLog = Join-Path $closureDirectory 'independent-verification.log'

$verificationOutput = @(
  & pwsh -NoProfile -ExecutionPolicy Bypass `
    -File $verifierPath `
    -ManifestPath $manifestPath `
    -RepositoryRoot $repo 2>&1
)
Write-Utf8NoBom `
  -Path $verificationLog `
  -Text (($verificationOutput -join "`n") + "`n")

if ($LASTEXITCODE -ne 0) {
  $verificationOutput | Out-Host
  throw 'Independent artifact verification failed.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
  ConvertFrom-Json

$expectedArtifactName =
  "crm3-baf-ops-$($manifest.release.releaseId)-${expected}-run-$GitHubRunId"
if ($ArtifactName -ne $expectedArtifactName) {
  throw 'GitHub artifact name does not match the governed release identity.'
}

if ([string]$manifest.source.gitCommit -ne $expected -or
    [string]$manifest.ciAuthority.repository -ne $repositorySlug -or
    [long]$manifest.ciAuthority.runId -ne $GitHubRunId -or
    [int]$manifest.ciAuthority.runAttempt -ne [int]$run.run_attempt -or
    [string]$manifest.ciAuthority.ref -ne 'refs/heads/main' -or
    [string]$manifest.ciAuthority.refName -ne 'main' -or
    [string]$manifest.ciAuthority.workflowRef -notmatch
      '\.github/workflows/production-artifact\.yml@refs/heads/main$' -or
    [string]$manifest.ciAuthority.actor -ne [string]$run.actor.login -or
    [long]$manifest.ciAuthority.actorId -ne [long]$run.actor.id -or
    [string]$manifest.ciAuthority.triggeringActor -ne
      [string]$run.triggering_actor.login -or
    [string]$manifest.distributionAuthority -ne
      'production-signed-pre-release-candidate') {
  throw 'Artifact manifest does not match the verified GitHub run.'
}

if ([string]$manifest.ciAuthority.environment -ne $ExpectedEnvironmentName) {
  throw 'Artifact was not built under the governed production-signing environment.'
}

$encodedEnvironment = [Uri]::EscapeDataString($ExpectedEnvironmentName)
$repositoryJsonText = @(
  gh api "repos/$repositorySlug"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify GitHub repository visibility.'
}
$repositoryAuthority = ($repositoryJsonText -join "`n") |
  ConvertFrom-Json
$environmentJsonText = @(
  gh api "repos/$repositorySlug/environments/$encodedEnvironment"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify the GitHub production-signing environment.'
}
$environmentAuthority = ($environmentJsonText -join "`n") |
  ConvertFrom-Json
$requiredReviewerRules = @(
  $environmentAuthority.protection_rules |
    Where-Object { [string]$_.type -eq 'required_reviewers' }
)

$approvalHistoryText = @(
  gh api "repos/$repositorySlug/actions/runs/$GitHubRunId/approvals"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify protected-environment approval history.'
}
$approvalHistory = @((($approvalHistoryText -join "`n") | ConvertFrom-Json))
$approvedEnvironmentReviews = @(
  $approvalHistory |
    Where-Object {
      [string]$_.state -eq 'approved' -and
      @(
        $_.environments |
          Where-Object { [string]$_.name -eq $ExpectedEnvironmentName }
      ).Count -gt 0
    }
)

$environmentSecretsText = @(
  gh api `
    "repos/$repositorySlug/environments/$encodedEnvironment/secrets?per_page=100"
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify production-signing environment secret names.'
}
$environmentSecretsAuthority = ($environmentSecretsText -join "`n") |
  ConvertFrom-Json
$liveEnvironmentSecretNames = @(
  $environmentSecretsAuthority.secrets |
    ForEach-Object { [string]$_.name } |
    Sort-Object
)
if ($liveEnvironmentSecretNames.Count -ne
      $ExpectedEnvironmentSecretNames.Count -or
    ($liveEnvironmentSecretNames -join "`n") -cne
      (($ExpectedEnvironmentSecretNames | Sort-Object) -join "`n")) {
  throw 'Production-signing environment secret-name inventory differs.'
}

$sourcePolicy = Get-Content `
  -LiteralPath 'release/production-release-policy.json' `
  -Raw | ConvertFrom-Json
$environmentReviewControl =
  $sourcePolicy.github.environmentReviewControl
$manifestEnvironmentReviewControlJson =
  $manifest.ciAuthority.environmentReviewControl |
    ConvertTo-Json -Depth 20 -Compress
$sourceEnvironmentReviewControlJson =
  $environmentReviewControl |
    ConvertTo-Json -Depth 20 -Compress
if ($manifestEnvironmentReviewControlJson -cne
    $sourceEnvironmentReviewControlJson) {
  throw 'Artifact environment-review control differs from exact source.'
}

if ([string]$environmentReviewControl.mode -ne
      'private-repository-plan-exception' -or
    $environmentReviewControl.requiredReviewerAvailable -ne $false -or
    $environmentReviewControl.requiredReviewerRulePresentAtApproval -ne
      $false -or
    $environmentReviewControl.manualDispatchApprovalReferenceRequired -ne
      $true -or
    $environmentReviewControl.failClosedIfRequiredReviewerRuleAppears -ne
      $true -or
    $repositoryAuthority.private -ne $true -or
    [string]$repositoryAuthority.visibility -ne 'private' -or
    $requiredReviewerRules.Count -ne 0 -or
    $approvalHistory.Count -ne 0 -or
    $approvedEnvironmentReviews.Count -ne 0) {
  throw 'Live GitHub state does not satisfy the private-repository plan exception.'
}

$environmentExceptionPath =
  [string]$environmentReviewControl.exceptionApprovalFile
$environmentException = Get-Content `
  -LiteralPath $environmentExceptionPath `
  -Raw | ConvertFrom-Json
$versionApproval = Get-Content `
  -LiteralPath $sourcePolicy.versionPolicy.approvalReceiptFile `
  -Raw | ConvertFrom-Json
if ((Get-Sha256 $environmentExceptionPath) -ne
      ([string]$environmentReviewControl.exceptionApprovalSha256).
        ToUpperInvariant() -or
    [string]$environmentException.approvalReference -ne
      [string]$environmentReviewControl.exceptionApprovalReference -or
    [string]$environmentException.scope.repository -ne $repositorySlug -or
    [string]$environmentException.scope.repositoryVisibility -ne 'private' -or
    [string]$environmentException.scope.environmentName -ne
      $ExpectedEnvironmentName -or
    [int64]$environmentException.scope.buildNumber -ne
      [int64]$manifest.release.buildNumber -or
    [string]$environmentException.scope.versionApprovalReference -ne
      [string]$manifest.ciAuthority.dispatchApprovalReference -or
    [string]$environmentException.liveStateEvidence.authorizedDispatcher.login -ne
      [string]$manifest.ciAuthority.actor -or
    [long]$environmentException.liveStateEvidence.authorizedDispatcher.id -ne
      [long]$manifest.ciAuthority.actorId -or
    $environmentException.compensatingControls.
      authorizedDispatcherIdentityRequired -ne $true -or
    [string]$manifest.ciAuthority.dispatchApprovalReference -ne
      [string]$versionApproval.reference) {
  throw 'Private-repository environment-review exception authority mismatch.'
}

$reservationTag =
  [string]$manifest.remoteBuildAuthority.reservationTag
$builtTag = [string]$manifest.remoteBuildAuthority.builtTag
$reservationCommit =
  Get-RemoteRefCommit -RefName "refs/tags/$reservationTag"

if ($reservationCommit -ne $expected) {
  throw 'Remote build-number reservation tag is absent or points elsewhere.'
}

Fetch-RemoteAnnotatedTag -TagName $reservationTag
$reservationAuthority = Get-LocalAnnotatedTagAuthority `
  -TagName $reservationTag `
  -ExpectedCommit $expected
if ($reservationAuthority.objectSha -ne
      ([string]$manifest.remoteBuildAuthority.reservationTagObjectSha).
        ToLowerInvariant() -or
    $reservationAuthority.contentsSha256 -ne
      ([string]$manifest.remoteBuildAuthority.reservationTagMessageSha256).
        ToUpperInvariant()) {
  throw 'Remote reservation annotated-tag authority differs from the artifact.'
}
foreach ($requiredLine in @(
  "Build number: $($manifest.release.buildNumber)"
  "Release ID: $($manifest.release.releaseId)"
  "Reservation ID: $($manifest.versionPolicy.reservationId)"
  "Commit: $expected"
  "GitHub run: $GitHubRunId"
  "GitHub run attempt: $($run.run_attempt)"
)) {
  if ($reservationAuthority.contents -notmatch
      "(?m)^$([regex]::Escape($requiredLine))$") {
    throw "Remote reservation tag is missing governed field: $requiredLine"
  }
}

$existingBuiltCommit =
  Get-RemoteRefCommit -RefName "refs/tags/$builtTag"
if ($null -ne $existingBuiltCommit -and
    $existingBuiltCommit -ne $expected) {
  throw 'Remote built tag exists but points to another commit.'
}

$primaryRoot = [IO.Path]::GetFullPath($PrimaryCustodyDirectory)
$backupRoot = [IO.Path]::GetFullPath($BackupCustodyDirectory)

if ($primaryRoot.Equals(
      $backupRoot,
      [StringComparison]::OrdinalIgnoreCase
    )) {
  throw 'Primary and backup custody directories must be different.'
}
$repoRoot = [IO.Path]::GetFullPath($repo).TrimEnd(
  [IO.Path]::DirectorySeparatorChar,
  [IO.Path]::AltDirectorySeparatorChar
)
$repoPrefix = $repoRoot + [IO.Path]::DirectorySeparatorChar
foreach ($custodyRoot in @($primaryRoot, $backupRoot)) {
  if ($custodyRoot.Equals(
        $repoRoot,
        [StringComparison]::OrdinalIgnoreCase
      ) -or
      $custodyRoot.StartsWith(
        $repoPrefix,
        [StringComparison]::OrdinalIgnoreCase
      )) {
    throw 'Custody directories may not be inside the repository.'
  }
}

$primaryQualifier = Split-Path $primaryRoot -Qualifier
$backupQualifier = Split-Path $backupRoot -Qualifier
if (-not [string]::IsNullOrWhiteSpace($primaryQualifier) -and
    $primaryQualifier.Equals(
      $backupQualifier,
      [StringComparison]::OrdinalIgnoreCase
    )) {
  throw 'Primary and backup custody must use distinct volume/share roots.'
}

$primaryPackagePath = Copy-And-Verify `
  -SourcePath $packageZip `
  -DestinationDirectory $primaryRoot `
  -ExpectedSha256 $packageSha256
$backupPackagePath = Copy-And-Verify `
  -SourcePath $packageZip `
  -DestinationDirectory $backupRoot `
  -ExpectedSha256 $packageSha256

$sidecarSha256 = Get-Sha256 $packageSidecar
$primarySidecarPath = Copy-And-Verify `
  -SourcePath $packageSidecar `
  -DestinationDirectory $primaryRoot `
  -ExpectedSha256 $sidecarSha256
$backupSidecarPath = Copy-And-Verify `
  -SourcePath $packageSidecar `
  -DestinationDirectory $backupRoot `
  -ExpectedSha256 $sidecarSha256

$productionCustodyReceipt = [ordered]@{
  schemaVersion = 1
  completedAtUtc = [DateTime]::UtcNow.ToString('o')
  packageFile = Split-Path -Leaf $packageZip
  packageSha256 = $packageSha256
  sidecarFile = Split-Path -Leaf $packageSidecar
  sidecarSha256 = $sidecarSha256
  primaryPackagePath = $primaryPackagePath
  backupPackagePath = $backupPackagePath
  primarySidecarPath = $primarySidecarPath
  backupSidecarPath = $backupSidecarPath
  distinctCustodyRoots = $true
  custodyApprover = $CustodyApprover
  custodyReference = $CustodyReference
  status = 'passed'
}
$productionCustodyReceiptPath =
  Join-Path $closureDirectory 'production-package-dual-custody.json'
Write-Utf8NoBom `
  -Path $productionCustodyReceiptPath `
  -Text (($productionCustodyReceipt | ConvertTo-Json -Depth 20) + "`n")

# The built tag is created only after the production package is independently
# verified and present in two distinct custody roots.
if ($null -eq $existingBuiltCommit) {
  git fetch origin --tags --force
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to refresh remote tags.'
  }

  if (@(git tag --list $builtTag).Count -gt 0) {
    git tag -d $builtTag | Out-Null
  }

  $tagMessagePath = Join-Path $closureDirectory 'built-tag-message.txt'
  Write-Utf8NoBom -Path $tagMessagePath -Text @"
CRM-III BAF Ops governed built-artifact authority

Build number: $($manifest.release.buildNumber)
Release ID: $($manifest.release.releaseId)
Commit: $expected
GitHub run: $GitHubRunId
GitHub run attempt: $($run.run_attempt)
Production package SHA-256: $packageSha256
Reservation tag: $reservationTag
Dual production-package custody: passed
Environment review control: $($environmentReviewControl.mode)
Dispatch approval reference: $($manifest.ciAuthority.dispatchApprovalReference)
Authorized dispatcher: $($manifest.ciAuthority.actor)
Authorized dispatcher ID: $($manifest.ciAuthority.actorId)
Environment exception reference: $($environmentReviewControl.exceptionApprovalReference)
Distribution approval: not created
Unrestricted plant release: not approved
"@

  git `
    -c user.name=crm3-baf-ops-release-finalizer `
    -c user.email=crm3-baf-ops-release-finalizer@users.noreply.github.com `
    tag -a $builtTag $expected -F $tagMessagePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to create local built tag.'
  }

  git push origin "refs/tags/${builtTag}:refs/tags/${builtTag}"
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to push remote built tag.'
  }
}

$remoteBuiltCommit =
  Get-RemoteRefCommit -RefName "refs/tags/$builtTag"
if ($remoteBuiltCommit -ne $expected) {
  throw 'Remote built tag was not established at the expected commit.'
}

Fetch-RemoteAnnotatedTag -TagName $builtTag
$builtAuthority = Get-LocalAnnotatedTagAuthority `
  -TagName $builtTag `
  -ExpectedCommit $expected
foreach ($requiredLine in @(
  "Build number: $($manifest.release.buildNumber)"
  "Release ID: $($manifest.release.releaseId)"
  "Commit: $expected"
  "GitHub run: $GitHubRunId"
  "GitHub run attempt: $($run.run_attempt)"
  "Production package SHA-256: $packageSha256"
  "Reservation tag: $reservationTag"
  'Dual production-package custody: passed'
  "Environment review control: $($environmentReviewControl.mode)"
  "Dispatch approval reference: $($manifest.ciAuthority.dispatchApprovalReference)"
  "Authorized dispatcher: $($manifest.ciAuthority.actor)"
  "Authorized dispatcher ID: $($manifest.ciAuthority.actorId)"
  "Environment exception reference: $($environmentReviewControl.exceptionApprovalReference)"
  'Distribution approval: not created'
  'Unrestricted plant release: not approved'
)) {
  if ($builtAuthority.contents -notmatch
      "(?m)^$([regex]::Escape($requiredLine))$") {
    throw "Remote built tag is missing governed field: $requiredLine"
  }
}

Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-run.json') `
  -Text (($run | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-jobs.json') `
  -Text (($jobs | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-artifacts.json') `
  -Text (($artifacts | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-environment.json') `
  -Text (($environmentAuthority | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-repository.json') `
  -Text (($repositoryAuthority | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-environment-secrets.json') `
  -Text (($environmentSecretsAuthority | ConvertTo-Json -Depth 30) + "`n")
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'github-environment-approvals.json') `
  -Text (
    (ConvertTo-Json -InputObject @($approvalHistory) -Depth 30) + "`n"
  )
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'pull-request.json') `
  -Text (($pullRequest | ConvertTo-Json -Depth 20) + "`n")

$remoteRefs = [ordered]@{
  capturedAtUtc = [DateTime]::UtcNow.ToString('o')
  main = Get-RemoteRefCommit -RefName 'refs/heads/main'
  reservationTag = $reservationTag
  reservationTagCommit =
    Get-RemoteRefCommit -RefName "refs/tags/$reservationTag"
  reservationTagObjectSha = $reservationAuthority.objectSha
  reservationTagMessageSha256 = $reservationAuthority.contentsSha256
  builtTag = $builtTag
  builtTagCommit =
    Get-RemoteRefCommit -RefName "refs/tags/$builtTag"
  builtTagObjectSha = $builtAuthority.objectSha
  builtTagMessageSha256 = $builtAuthority.contentsSha256
}
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'remote-authority.json') `
  -Text (($remoteRefs | ConvertTo-Json -Depth 10) + "`n")

$closureDecision = [ordered]@{
  schemaVersion = 4
  decisionAtUtc = [DateTime]::UtcNow.ToString('o')
  sourceCommit = $expected
  pullRequestNumber = $PullRequestNumber
  githubRunId = [string]$GitHubRunId
  githubRunAttempt = [string]$run.run_attempt
  workflowPath = [string]$run.path
  pullRequestMergedBy = [string]$pullRequest.mergedBy.login
  productionSigningEnvironment = $ExpectedEnvironmentName
  repositoryPrivate = [bool]$repositoryAuthority.private
  environmentReviewControlMode =
    [string]$environmentReviewControl.mode
  protectedEnvironmentRequiredReviewerRule = $false
  protectedEnvironmentApprovalCount = $approvedEnvironmentReviews.Count
  environmentExceptionApprovalReference =
    [string]$environmentReviewControl.exceptionApprovalReference
  environmentExceptionApprovalSha256 =
    [string]$environmentReviewControl.exceptionApprovalSha256
  dispatchApprovalReference =
    [string]$manifest.ciAuthority.dispatchApprovalReference
  authorizedDispatcher = [string]$manifest.ciAuthority.actor
  authorizedDispatcherId = [string]$manifest.ciAuthority.actorId
  triggeringActor = [string]$manifest.ciAuthority.triggeringActor
  environmentSecretNames = $liveEnvironmentSecretNames
  environmentSecretValuesInspected = $false
  githubArtifactId = [string]$selectedArtifact.id
  githubArtifactName = [string]$selectedArtifact.name
  githubArtifactSizeBytes = [long]$selectedArtifact.size_in_bytes
  githubArtifactDigest = $selectedArtifactDigest
  packageSha256 = $packageSha256
  manifestSha256 = Get-Sha256 $manifestPath
  applicationId = [string]$manifest.packageIdentity.applicationId
  version =
    "$($manifest.release.versionName)+$($manifest.release.buildNumber)"
  certificateSha256 = [string]$manifest.signing.certificateSha256
  reservationTag = $reservationTag
  reservationTagObjectSha = $reservationAuthority.objectSha
  reservationTagMessageSha256 = $reservationAuthority.contentsSha256
  builtTag = $builtTag
  builtTagObjectSha = $builtAuthority.objectSha
  builtTagMessageSha256 = $builtAuthority.contentsSha256
  distributionAuthority =
    'production-signed-pre-release-candidate'
  issues = [ordered]@{
    'O-01' =
      'CLOSED - corrected 70I-C integrated into governed provenance'
    'O-02' =
      'CLOSED FOR SOURCE/FIREBASE IDENTITY - operational package-ID ' +
      'cutover and placeholder-app retirement remain O-10/70J'
    'O-03' =
      'CLOSED - approved pre-existing signer and custody evidence proven'
    'O-04' =
      'CLOSED - source policy, atomic reservation tag and built tag proven'
    'O-05' =
      'CLOSED AS PRODUCTION-SIGNED VERIFIED PRE-RELEASE ARTIFACT; ' +
      'DISTRIBUTION APPROVAL NOT CLAIMED'
  }
  productionPackageDualCustody = 'passed'
  unrestrictedPlantReleaseApproved = $false
  controlledPilotApproved = $false
  firebaseBackendDeploymentPerformed = $false
  remainingOpenGates = @($manifest.knownOpenGates)
}
$closureDecisionPath =
  Join-Path $closureDirectory 'O1_O5_CLOSURE_DECISION.json'
Write-Utf8NoBom `
  -Path $closureDecisionPath `
  -Text (($closureDecision | ConvertTo-Json -Depth 30) + "`n")

Copy-Item -LiteralPath $packageZip `
  -Destination (Join-Path $closureDirectory (Split-Path -Leaf $packageZip))
Copy-Item -LiteralPath $packageSidecar `
  -Destination (Join-Path $closureDirectory (Split-Path -Leaf $packageSidecar))

git status --short --branch |
  Set-Content (Join-Path $closureDirectory 'git-status.txt') -Encoding utf8
git show --no-patch --format=fuller HEAD |
  Set-Content (Join-Path $closureDirectory 'git-head.txt') -Encoding utf8

$fileHashes = @()
Get-ChildItem -LiteralPath $closureDirectory -File -Recurse |
  Sort-Object FullName |
  ForEach-Object {
    $relative = [IO.Path]::GetRelativePath(
      $closureDirectory,
      $_.FullName
    ).Replace('\', '/')
    $fileHashes += "$(Get-Sha256 $_.FullName)  $relative"
  }
Write-Utf8NoBom `
  -Path (Join-Path $closureDirectory 'PACKAGE_FILE_SHA256.txt') `
  -Text (($fileHashes -join "`n") + "`n")

$closureZip = Join-Path $OutputDirectory (
  "CRM_III_BAF_Ops_O1_O5_CLOSURE_$timestamp.zip"
)
Compress-Archive `
  -Path (Join-Path $closureDirectory '*') `
  -DestinationPath $closureZip `
  -CompressionLevel Optimal

$closureSha256 = Get-Sha256 $closureZip
$closureSidecar = "$closureZip.sha256.txt"
Write-Utf8NoBom `
  -Path $closureSidecar `
  -Text "$closureSha256  $(Split-Path -Leaf $closureZip)`n"

$primaryClosurePath = Copy-And-Verify `
  -SourcePath $closureZip `
  -DestinationDirectory $primaryRoot `
  -ExpectedSha256 $closureSha256
$backupClosurePath = Copy-And-Verify `
  -SourcePath $closureZip `
  -DestinationDirectory $backupRoot `
  -ExpectedSha256 $closureSha256

$closureSidecarSha256 = Get-Sha256 $closureSidecar
$primaryClosureSidecarPath = Copy-And-Verify `
  -SourcePath $closureSidecar `
  -DestinationDirectory $primaryRoot `
  -ExpectedSha256 $closureSidecarSha256
$backupClosureSidecarPath = Copy-And-Verify `
  -SourcePath $closureSidecar `
  -DestinationDirectory $backupRoot `
  -ExpectedSha256 $closureSidecarSha256

$finalCustodyRecord = [ordered]@{
  schemaVersion = 2
  completedAtUtc = [DateTime]::UtcNow.ToString('o')
  sourceCommit = $expected
  githubRunId = [string]$GitHubRunId
  productionPackageSha256 = $packageSha256
  closurePackageSha256 = $closureSha256
  primaryProductionPackagePath = $primaryPackagePath
  backupProductionPackagePath = $backupPackagePath
  primaryClosurePackagePath = $primaryClosurePath
  backupClosurePackagePath = $backupClosurePath
  primaryClosureSidecarPath = $primaryClosureSidecarPath
  backupClosureSidecarPath = $backupClosureSidecarPath
  reservationTag = $reservationTag
  builtTag = $builtTag
  builtTagCommit = $remoteBuiltCommit
  builtTagObjectSha = $builtAuthority.objectSha
  builtTagMessageSha256 = $builtAuthority.contentsSha256
  reservationTagObjectSha = $reservationAuthority.objectSha
  reservationTagMessageSha256 = $reservationAuthority.contentsSha256
  environmentReviewControlMode =
    [string]$environmentReviewControl.mode
  dispatchApprovalReference =
    [string]$manifest.ciAuthority.dispatchApprovalReference
  authorizedDispatcher = [string]$manifest.ciAuthority.actor
  authorizedDispatcherId = [string]$manifest.ciAuthority.actorId
  environmentExceptionApprovalReference =
    [string]$environmentReviewControl.exceptionApprovalReference
  custodyApprover = $CustodyApprover
  custodyReference = $CustodyReference
  primaryVerified = $true
  backupVerified = $true
  status = 'passed'
}
$custodyRecordPath =
  Join-Path $OutputDirectory (
    "CRM_III_BAF_Ops_O1_O5_CUSTODY_$timestamp.json"
  )
Write-Utf8NoBom `
  -Path $custodyRecordPath `
  -Text (($finalCustodyRecord | ConvertTo-Json -Depth 20) + "`n")
$custodyRecordSha256 = Get-Sha256 $custodyRecordPath
$custodySidecar = "$custodyRecordPath.sha256.txt"
Write-Utf8NoBom `
  -Path $custodySidecar `
  -Text "$custodyRecordSha256  $(Split-Path -Leaf $custodyRecordPath)`n"

foreach ($destination in @($primaryRoot, $backupRoot)) {
  Copy-And-Verify `
    -SourcePath $custodyRecordPath `
    -DestinationDirectory $destination `
    -ExpectedSha256 $custodyRecordSha256 | Out-Null
  Copy-And-Verify `
    -SourcePath $custodySidecar `
    -DestinationDirectory $destination `
    -ExpectedSha256 (Get-Sha256 $custodySidecar) | Out-Null
}

Write-Host ''
Write-Host '===== O-01 TO O-05 FINAL CLOSURE PASSED =====' `
  -ForegroundColor Green
Write-Host "Production package SHA-256: $packageSha256"
Write-Host "Closure package:             $closureZip"
Write-Host "Closure SHA-256:             $closureSha256"
Write-Host "Custody record:              $custodyRecordPath"
Write-Host "Custody SHA-256:             $custodyRecordSha256"
Write-Host "Reservation tag:             $reservationTag"
Write-Host "Built tag:                   $builtTag"
Write-Host 'O-05 status: production-signed verified pre-release only'
Write-Host 'Controlled pilot: NOT APPROVED'
Write-Host 'Unrestricted field release: NOT APPROVED'
