#requires -Version 7.0
<#
.SYNOPSIS
Independently verifies a CRM-III BAF Ops production-signed pre-release package.

.DESCRIPTION
The verifier is extracted from the canonical source archive and packaged with
the artifact. It validates source custody, policy, approvals, remote-build
metadata, mandatory gates, APK/AAB identities, APK/AAB signatures, approved
public signer certificate, toolchain, lockfiles and release boundaries.

RepositoryRoot is optional. When supplied, live clean main parity is checked in
addition to package-only verification.
#>

[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
  [Parameter(Mandatory, ParameterSetName = 'Verify')]
  [string]$ManifestPath,

  [Parameter(Mandatory, ParameterSetName = 'LedgerSelectionSelfTest')]
  [switch]$LedgerSelectionSelfTest,

  [Parameter(ParameterSetName = 'Verify')]
  [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LedgerReservationMatches {
  param(
    [Parameter(Mandatory)][object[]]$Entries,
    [Parameter(Mandatory)][string]$ReservationId
  )

  @(
    $Entries |
      Where-Object {
        [string]$_.reservationId -eq $ReservationId
      }
  )
}

if ($LedgerSelectionSelfTest) {
  $fixtureEntries = @(
    [pscustomobject]@{
      reservationId = 'fixture-reservation-1'
      buildNumber = 1
    }
    [pscustomobject]@{
      reservationId = 'fixture-reservation-2'
      buildNumber = 2
    }
  )
  $fixtureMatches = @(
    Get-LedgerReservationMatches `
      -Entries $fixtureEntries `
      -ReservationId 'fixture-reservation-2'
  )
  if ($fixtureMatches.Count -ne 1 -or
      [int]$fixtureMatches[0].buildNumber -ne 2) {
    throw 'Production release manifest ledger-selection self-test failed.'
  }
  Write-Output 'Production release manifest ledger-selection self-test: PASS'
  return
}

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }

  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [Text.Encoding]::UTF8.GetBytes($Text)
    )
  )
}

function Resolve-ContainedFile {
  param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$RelativePath
  )

  if ([IO.Path]::IsPathRooted($RelativePath) -or
      [string]::IsNullOrWhiteSpace($RelativePath)) {
    throw "Package path must be non-empty and relative: $RelativePath"
  }

  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $candidate = [IO.Path]::GetFullPath(
    (Join-Path $rootFull $RelativePath)
  )
  $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar

  if (-not $candidate.StartsWith(
      $prefix,
      [StringComparison]::OrdinalIgnoreCase
    ) -or
    -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Package file escapes or is absent: $RelativePath"
  }

  $candidate
}

function Get-ZipEntryBytes {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  $normalized = $EntryPath.Replace('\', '/')
  $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)

  try {
    $entry = $archive.Entries |
      Where-Object FullName -eq $normalized |
      Select-Object -First 1

    if ($null -eq $entry) {
      throw "Missing source entry: $normalized"
    }

    $stream = $entry.Open()
    try {
      $memory = [IO.MemoryStream]::new()
      $stream.CopyTo($memory)
      $memory.ToArray()
    }
    finally {
      $stream.Dispose()
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Get-ZipEntrySha256 {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      (Get-ZipEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath)
    )
  )
}

function Get-ZipEntryText {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  [Text.Encoding]::UTF8.GetString(
    (Get-ZipEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath)
  )
}

function Find-AndroidTool {
  param(
    [Parameter(Mandatory)][string[]]$Names,
    [Parameter(Mandatory)][string[]]$RelativeRoots
  )

  $sdkRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)

  if ($IsWindows -and $env:LOCALAPPDATA) {
    $sdkRoots += Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }

  foreach ($sdkRoot in ($sdkRoots | Where-Object { $_ } | Select-Object -Unique)) {
    foreach ($relativeRoot in $RelativeRoots) {
      $searchRoot = Join-Path $sdkRoot $relativeRoot
      if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) {
        continue
      }

      foreach ($name in $Names) {
        $match = Get-ChildItem -LiteralPath $searchRoot -File -Recurse `
          -Filter $name -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending |
          Select-Object -First 1

        if ($match) {
          return $match.FullName
        }
      }
    }
  }

  foreach ($name in $Names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Android tool unavailable: $($Names -join ', ')"
}

function Get-ApkManifestValue {
  param(
    [Parameter(Mandatory)][string]$Analyzer,
    [Parameter(Mandatory)][string]$Command,
    [Parameter(Mandatory)][string]$ApkPath
  )

  $output = @(& $Analyzer manifest $Command $ApkPath 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "apkanalyzer manifest $Command failed."
  }

  ($output | Select-Object -Last 1).ToString().Trim()
}

function Get-ApkCertificateSha256 {
  param(
    [Parameter(Mandatory)][string]$ApkSigner,
    [Parameter(Mandatory)][string]$ApkPath
  )

  $output = @(
    & $ApkSigner verify --verbose --print-certs $ApkPath 2>&1
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'APK signature verification failed.'
  }

  $digests = @(
    $output |
      Select-String -Pattern 'certificate SHA-256 digest:\s*([0-9A-Fa-f:]+)' |
      ForEach-Object {
        $_.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
      } |
      Sort-Object -Unique
  )

  if ($digests.Count -ne 1) {
    throw "APK must have exactly one unique signer certificate; found $($digests.Count)."
  }

  $digests[0]
}

function Get-AabCertificateSha256 {
  param(
    [Parameter(Mandatory)][string]$AabPath,
    [Parameter(Mandatory)][string]$ApprovedCertificateDerPath
  )

  $trustStore = Join-Path ([IO.Path]::GetTempPath()) (
    'crm3-aab-trust-' + [guid]::NewGuid().ToString('N') + '.p12'
  )
  $trustPassword = [Convert]::ToBase64String(
    [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
  ).Replace('/', 'A').Replace('+', 'B').TrimEnd('=')

  try {
    & keytool -importcert -noprompt `
      -alias crm3-approved-production-signer `
      -file $ApprovedCertificateDerPath `
      -keystore $trustStore `
      -storetype PKCS12 `
      -storepass $trustPassword | Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw 'Unable to create temporary AAB verification truststore.'
    }

    & jarsigner -verify -strict -verbose -certs `
      -keystore $trustStore `
      -storetype PKCS12 `
      -storepass $trustPassword `
      $AabPath *> $null

    if ($LASTEXITCODE -ne 0) {
      throw 'AAB strict signature verification failed.'
    }

    $certificateOutput = @(& keytool -printcert -jarfile $AabPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
      throw 'AAB signer certificate extraction failed.'
    }

    $digests = @(
      $certificateOutput |
        Select-String -Pattern 'SHA256:\s*([0-9A-Fa-f:]+)' |
        ForEach-Object {
          $_.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
        } |
        Sort-Object -Unique
    )

    if ($digests.Count -ne 1) {
      throw "AAB must have exactly one unique signer certificate; found $($digests.Count)."
    }

    $digests[0]
  }
  finally {
    Remove-Item -LiteralPath $trustStore -Force -ErrorAction SilentlyContinue
    $trustPassword = $null
  }
}

function Get-AabManifestFacts {
  param(
    [Parameter(Mandatory)][string]$BundletoolJar,
    [Parameter(Mandatory)][string]$AabPath
  )

  $output = @(
    & java -jar $BundletoolJar dump manifest `
      "--bundle=$AabPath" `
      '--module=base' 2>&1
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'bundletool manifest dump failed.'
  }

  $xml = $output -join "`n"
  $packageName = [regex]::Match(
    $xml,
    '<manifest[^>]*\bpackage="([^"]+)"'
  ).Groups[1].Value
  $versionCode = [regex]::Match(
    $xml,
    'android:versionCode="([^"]+)"'
  ).Groups[1].Value
  $versionName = [regex]::Match(
    $xml,
    'android:versionName="([^"]+)"'
  ).Groups[1].Value
  $debuggable = [regex]::Match(
    $xml,
    '<application[^>]*android:debuggable="([^"]+)"'
  ).Groups[1].Value

  if (-not $packageName -or -not $versionCode -or -not $versionName) {
    throw 'Unable to parse AAB package/version identity.'
  }

  if (-not $debuggable) {
    $debuggable = 'false'
  }

  [ordered]@{
    applicationId = $packageName
    versionCode = $versionCode
    versionName = $versionName
    debuggable = $debuggable
  }
}

$manifestFile = (Resolve-Path -LiteralPath $ManifestPath).Path
$packageDirectory = Split-Path -Parent $manifestFile
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json

if ($manifest.schemaVersion -ne 6) {
  throw 'Unsupported production manifest schema; expected 6.'
}
if ([string]$manifest.artifactClass -ne
  'production-signed-pre-release-candidate' -or
  [string]$manifest.distributionAuthority -ne
  'production-signed-pre-release-candidate') {
  throw 'Artifact class is not the governed non-distributable pre-release class.'
}
if ($manifest.releaseBoundary.distributionApproved -ne $false -or
    $manifest.releaseBoundary.controlledPilotApproved -ne $false -or
    $manifest.releaseBoundary.unrestrictedPlantReleaseApproved -ne $false -or
    $manifest.releaseBoundary.firebaseDeploymentPerformed -ne $false) {
  throw 'Unsafe release boundary.'
}
if ($manifest.releaseBoundary.postBuildPromotionRequiredForAnyDistribution -ne
  $true) {
  throw 'Post-build promotion boundary is missing.'
}

foreach ($qualityGate in @(
  'repositoryReleaseGate'
  'closureFirestoreEmulator'
  'artifactApkSignature'
  'artifactAabSignature'
  'artifactApkIdentity'
  'artifactAabIdentity'
)) {
  if ([string]$manifest.qualityGates.$qualityGate -ne 'passed') {
    throw "Mandatory quality gate is not passed: $qualityGate"
  }
}
if ($manifest.qualityGates.executed -ne $true -or
    $manifest.qualityGates.sourceArchiveIdentityDefineSupplied -ne $true) {
  throw 'Quality gates or SOURCE_ARCHIVE_SHA256 identity were skipped.'
}

if ([string]$manifest.ciAuthority.provider -ne 'github-actions' -or
    [string]$manifest.ciAuthority.ref -ne 'refs/heads/main' -or
    [string]$manifest.ciAuthority.refName -ne 'main' -or
    [string]$manifest.ciAuthority.runId -notmatch '^[0-9]+$' -or
    [string]$manifest.ciAuthority.runAttempt -notmatch '^[0-9]+$' -or
    [string]$manifest.ciAuthority.headSha -ne
    [string]$manifest.source.gitCommit -or
    [string]$manifest.ciAuthority.workflowRef -notmatch
    '\.github/workflows/production-artifact\.yml@refs/heads/main$' -or
    [string]$manifest.ciAuthority.dispatchApprovalReference -notmatch
      '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' -or
    [string]$manifest.ciAuthority.actor -notmatch
      '^[A-Za-z0-9][A-Za-z0-9-]{0,38}$' -or
    [string]$manifest.ciAuthority.actorId -notmatch '^[1-9][0-9]{0,19}$' -or
    [string]$manifest.ciAuthority.triggeringActor -ne
      [string]$manifest.ciAuthority.actor -or
    $manifest.ciAuthority.localExecutionPermitted -ne $false) {
  throw 'Protected GitHub Actions provenance is incomplete.'
}

if ([string]$manifest.backend.authorityClass -ne
      'verified-production-backend-composite' -or
    [string]$manifest.backend.releaseModel.type -ne
      'COMPOSITE_LIVE_STATE' -or
    $manifest.backend.releaseModel.singleHomogeneousDeployment -ne $false -or
    [string]$manifest.backend.firestore.indexes.status -ne 'EXACT' -or
    $manifest.backend.firestore.indexes.allReady -ne $true -or
    [int]$manifest.backend.firestore.indexes.sourceCompositeIndexes -ne
      [int]$manifest.backend.firestore.indexes.deployedCompositeIndexes -or
    [int]$manifest.backend.firestore.indexes.fieldOverrideCount -ne 0) {
  throw 'Composite backend or exact Firestore-index authority is missing.'
}

$sourceArchivePath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$manifest.source.sourceArchiveFile)
if ((Get-Sha256 $sourceArchivePath) -ne
  ([string]$manifest.source.sourceArchiveSha256).ToUpperInvariant()) {
  throw 'Source archive hash mismatch.'
}
if ([string]$manifest.source.gitCommit -ne
  [string]$manifest.source.remoteMainAtBuild) {
  throw 'Artifact was not built from exact remote main.'
}

if ($RepositoryRoot) {
  Push-Location (Resolve-Path -LiteralPath $RepositoryRoot)
  try {
    if (@(git status --porcelain=v1 --untracked-files=all).Count -gt 0) {
      throw 'Repository is dirty.'
    }

    $repositoryHead = (git rev-parse HEAD).Trim().ToLowerInvariant()
    if ($repositoryHead -ne
      ([string]$manifest.source.gitCommit).ToLowerInvariant()) {
      throw 'Repository HEAD differs from artifact source.'
    }

    $remoteLine = @(git ls-remote origin refs/heads/main)
    if ($LASTEXITCODE -ne 0 -or $remoteLine.Count -ne 1) {
      throw 'Unable to query live remote main.'
    }

    $remoteMain = (($remoteLine[0] -split '\s+')[0]).Trim().ToLowerInvariant()
    if ($remoteMain -ne $repositoryHead) {
      throw 'Live remote main differs from artifact source.'
    }
  }
  finally {
    Pop-Location
  }
}

$policy = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath 'release/production-release-policy.json'
) | ConvertFrom-Json
$authority = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath 'release/backend-authority.prod.json'
) | ConvertFrom-Json
$buildLedger = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath 'release/build-number-ledger.json'
) | ConvertFrom-Json
$versionApproval = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath ([string]$policy.versionPolicy.approvalReceiptFile)
) | ConvertFrom-Json
$environmentException = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath (
      [string]$policy.github.environmentReviewControl.exceptionApprovalFile
    )
) | ConvertFrom-Json

if ($policy.schemaVersion -ne 3) {
  throw 'Unsupported policy schema in source archive.'
}
if ((Get-ZipEntrySha256 `
      -ArchivePath $sourceArchivePath `
      -EntryPath 'release/production-release-policy.json') -ne
    ([string]$manifest.policy.sha256).ToUpperInvariant()) {
  throw 'Policy source-entry hash mismatch.'
}
if ((Get-ZipEntrySha256 `
      -ArchivePath $sourceArchivePath `
      -EntryPath 'release/backend-authority.prod.json') -ne
    ([string]$manifest.backend.authorityFileSha256).ToUpperInvariant()) {
  throw 'Backend authority source-entry hash mismatch.'
}

if ([int]$authority.schemaVersion -ne 2 -or
    [string]$authority.authorityClass -ne
      'verified-production-backend-composite' -or
    [string]$authority.releaseId -ne
      [string]$manifest.backend.expectedReleaseId -or
    [string]$authority.authorityDigest -ne
      [string]$manifest.backend.authorityDigest) {
  throw 'Manifest/backend composite authority identity mismatch.'
}

foreach ($legacyField in @(
  'backendGitCommit'
  'deployedIndexesParityStatus'
  'deployedIndexesParityEvidence'
  'intentionalDivergencePolicy'
)) {
  if ($null -ne $authority.PSObject.Properties[$legacyField]) {
    throw "Backend authority retains obsolete top-level field: $legacyField"
  }
}

foreach ($field in @(
  'releaseModel'
  'repositoryAuthority'
  'firestore'
  'sourceCustody'
)) {
  $authorityJson = $authority.$field | ConvertTo-Json -Depth 100 -Compress
  $manifestJson = $manifest.backend.$field |
    ConvertTo-Json -Depth 100 -Compress
  if ($authorityJson -cne $manifestJson) {
    throw "Manifest backend field differs from authority: $field"
  }
}

$indexCustody = @(
  $authority.sourceCustody.files |
    Where-Object { [string]$_.path -eq 'firestore.indexes.json' }
)
if ($indexCustody.Count -ne 1 -or
    [string]$indexCustody[0].sha256 -ne
      [string]$authority.firestore.indexes.sourceSha256) {
  throw 'Live Firestore index authority differs from reconstruction custody.'
}

foreach ($receipt in $manifest.policy.approvalReceiptHashes.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $sourceArchivePath `
    -EntryPath ([string]$receipt.Name)

  if ($actual -ne ([string]$receipt.Value).ToUpperInvariant()) {
    throw "Approval receipt mismatch: $($receipt.Name)"
  }
}
$exceptionApprovalPath =
  [string]$policy.github.environmentReviewControl.exceptionApprovalFile
$exceptionHashProperty =
  $manifest.policy.approvalReceiptHashes.PSObject.Properties[
    $exceptionApprovalPath
  ]
if ($null -eq $exceptionHashProperty -or
    [string]$exceptionHashProperty.Value -ne
      [string]$policy.github.environmentReviewControl.exceptionApprovalSha256 -or
    [string]$environmentException.approvalReference -ne
      [string]$policy.github.environmentReviewControl.exceptionApprovalReference) {
  throw 'Environment-review exception receipt is absent or differs from policy.'
}

if ([string]$manifest.ciAuthority.repository -ne
      [string]$policy.github.repository -or
    [string]$manifest.ciAuthority.environment -ne
      [string]$policy.github.environmentName -or
    [string]$policy.github.workflowPath -ne
      '.github/workflows/production-artifact.yml' -or
    [string]$manifest.ciAuthority.dispatchApprovalReference -ne
      [string]$versionApproval.reference -or
    [string]$manifest.ciAuthority.workflowRef -notmatch
      [regex]::Escape(
        [string]$policy.github.workflowPath + '@refs/heads/main'
      )) {
  throw 'Manifest/policy GitHub Actions authority mismatch.'
}
$policyEnvironmentControlJson =
  $policy.github.environmentReviewControl |
    ConvertTo-Json -Depth 20 -Compress
$manifestEnvironmentControlJson =
  $manifest.ciAuthority.environmentReviewControl |
    ConvertTo-Json -Depth 20 -Compress
if ($policyEnvironmentControlJson -cne $manifestEnvironmentControlJson -or
    [int64]$environmentException.scope.buildNumber -ne
      [int64]$manifest.release.buildNumber -or
    [string]$environmentException.scope.versionApprovalReference -ne
      [string]$manifest.ciAuthority.dispatchApprovalReference -or
    [string]$environmentException.liveStateEvidence.authorizedDispatcher.login -ne
      [string]$manifest.ciAuthority.actor -or
    [string]$environmentException.liveStateEvidence.authorizedDispatcher.id -ne
      [string]$manifest.ciAuthority.actorId -or
    $environmentException.compensatingControls.
      authorizedDispatcherIdentityRequired -ne $true -or
    $environmentException.compensatingControls.distributionApproved -ne
      $false) {
  throw 'Manifest environment-review control differs from approved exception.'
}

if ([string]$policy.permanentApplicationId -ne
      [string]$manifest.packageIdentity.applicationId -or
    [string]$policy.namespace -ne
      [string]$manifest.packageIdentity.namespace) {
  throw 'Manifest/policy package identity mismatch.'
}
if ([string]$policy.release.releaseId -ne
      [string]$manifest.release.releaseId -or
    [string]$policy.release.versionName -ne
      [string]$manifest.release.versionName -or
    [int64]$policy.release.buildNumber -ne
      [int64]$manifest.release.buildNumber) {
  throw 'Manifest/policy release mismatch.'
}
if ([string]$policy.signing.certificateSha256 -ne
      [string]$manifest.signing.certificateSha256 -or
    [string]$policy.signing.keyAlias -ne
      [string]$manifest.signing.keyAlias -or
    [string]$policy.signing.primaryCustodianName -ne
      [string]$manifest.signing.primaryCustodianName -or
    [string]$policy.signing.backupCustodianName -ne
      [string]$manifest.signing.backupCustodianName -or
    [string]$policy.signing.custodyReference -ne
      [string]$manifest.signing.custodyReference -or
    [string]$policy.signing.backupProofSha256 -ne
      [string]$manifest.signing.backupProofSha256 -or
    [string]$policy.signing.recoveryProofSha256 -ne
      [string]$manifest.signing.recoveryProofSha256 -or
    [string]$policy.signing.approvalReceiptFile -ne
      [string]$manifest.signing.approvalReceiptFile -or
    [string]$policy.signing.sourceDocumentSha256 -ne
      [string]$manifest.signing.sourceDocumentSha256) {
  throw 'Manifest/policy signer and custody mismatch.'
}
if ([string]$policy.firebaseAndroidApp.firebaseAppId -ne
      [string]$manifest.firebaseAndroidApp.firebaseAppId -or
    [string]$policy.firebaseAndroidApp.androidOauthClientId -ne
      [string]$manifest.firebaseAndroidApp.androidOauthClientId) {
  throw 'Manifest/policy Firebase identity mismatch.'
}
if ([string]$policy.distribution.authority -ne
      'production-signed-pre-release-candidate' -or
    $policy.distribution.approved -ne $false) {
  throw 'Source policy improperly claims distribution approval.'
}

if ([string]$manifest.toolchain.actual.runnerImage -ne
      [string]$policy.toolchain.runnerImage -or
    [string]$manifest.toolchain.actual.javaVersion -ne
      [string]$policy.toolchain.javaVersion -or
    [string]$manifest.toolchain.actual.nodeVersion -ne
      [string]$policy.toolchain.nodeVersion -or
    [string]$manifest.toolchain.actual.npmVersion -ne
      [string]$policy.toolchain.npmVersion -or
    [string]$manifest.toolchain.actual.flutterVersion -ne
      [string]$policy.toolchain.flutterVersion -or
    [string]$manifest.toolchain.actual.dartVersion -ne
      [string]$policy.toolchain.dartVersion) {
  throw 'Manifest actual toolchain differs from approved source policy.'
}
foreach ($actualField in @(
  'githubImageOs',
  'githubImageVersion',
  'runnerOs',
  'runnerArch',
  'powerShellVersion',
  'javaVersionOutput',
  'dartVersionOutput',
  'gitVersionOutput',
  'flutterFrameworkRevision'
)) {
  if ([string]::IsNullOrWhiteSpace(
      [string]$manifest.toolchain.actual.$actualField
    )) {
    throw "Manifest actual toolchain field is absent: $actualField"
  }
}


foreach ($androidHashField in @('apkSignerSha256', 'apkAnalyzerSha256')) {
  if ([string]$manifest.toolchain.actual.androidTools.$androidHashField -notmatch
      '^[0-9A-Fa-f]{64}$') {
    throw "Android tool provenance hash is absent: $androidHashField"
  }
}
foreach ($androidPathField in @('apkSignerPath', 'apkAnalyzerPath')) {
  if ([string]::IsNullOrWhiteSpace(
      [string]$manifest.toolchain.actual.androidTools.$androidPathField
    )) {
    throw "Android tool provenance path is absent: $androidPathField"
  }
}

$ledgerMatches = @(
  Get-LedgerReservationMatches `
    -Entries @($buildLedger.entries) `
    -ReservationId ([string]$manifest.versionPolicy.reservationId)
)
if ($ledgerMatches.Count -ne 1 -or
    [int64]$ledgerMatches[0].buildNumber -ne
      [int64]$manifest.release.buildNumber -or
    [string]$ledgerMatches[0].releaseId -ne
      [string]$manifest.release.releaseId) {
  throw 'Build-number source reservation mismatch.'
}
if (@(
    $buildLedger.entries |
      Group-Object buildNumber |
      Where-Object Count -gt 1
  ).Count -gt 0) {
  throw 'Duplicate build number exists in source ledger.'
}

if ([string]$manifest.remoteBuildAuthority.reservationTag -ne
      [string]$policy.versionPolicy.remoteReservationTag -or
    [string]$manifest.remoteBuildAuthority.builtTag -ne
      [string]$policy.versionPolicy.remoteBuiltTag -or
    [string]$manifest.remoteBuildAuthority.reservationTagCommit -ne
      [string]$manifest.source.gitCommit -or
    [string]$manifest.remoteBuildAuthority.reservationTagObjectSha -notmatch
      '^[0-9a-fA-F]{40}$' -or
    [string]$manifest.remoteBuildAuthority.reservationTagMessageSha256 -notmatch
      '^[0-9A-Fa-f]{64}$' -or
    $manifest.remoteBuildAuthority.failedOrWithdrawnBuildConsumesNumber -ne
      $true) {
  throw 'Remote build-number authority metadata is inconsistent.'
}

$reservationMessagePath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath (
    [string]$manifest.remoteBuildAuthority.reservationTagMessageFile
  )
$reservationMessage = Get-Content -LiteralPath $reservationMessagePath -Raw
$reservationMessage = $reservationMessage.TrimEnd("`r", "`n") + "`n"
if ((Get-TextSha256 $reservationMessage) -ne
    ([string]$manifest.remoteBuildAuthority.reservationTagMessageSha256).
      ToUpperInvariant()) {
  throw 'Captured reservation-tag message hash mismatch.'
}
foreach ($requiredLine in @(
  "Build number: $($manifest.release.buildNumber)"
  "Release ID: $($manifest.release.releaseId)"
  "Reservation ID: $($manifest.versionPolicy.reservationId)"
  "Commit: $($manifest.source.gitCommit)"
  "GitHub run: $($manifest.ciAuthority.runId)"
  "GitHub run attempt: $($manifest.ciAuthority.runAttempt)"
)) {
  if ($reservationMessage -notmatch
      "(?m)^$([regex]::Escape($requiredLine))$") {
    throw "Captured reservation tag is missing governed field: $requiredLine"
  }
}

$apkRecord = $manifest.artifacts |
  Where-Object type -eq 'apk' |
  Select-Object -First 1
$aabRecord = $manifest.artifacts |
  Where-Object type -eq 'aab' |
  Select-Object -First 1

if (-not $apkRecord -or -not $aabRecord) {
  throw 'Both APK and AAB records are required.'
}

$apkPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$apkRecord.file)
$aabPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$aabRecord.file)

if ((Get-Sha256 $apkPath) -ne
      ([string]$apkRecord.sha256).ToUpperInvariant() -or
    (Get-Sha256 $aabPath) -ne
      ([string]$aabRecord.sha256).ToUpperInvariant()) {
  throw 'Artifact hash mismatch.'
}

$bundletoolPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$manifest.toolchain.bundletoolFile)
if ((Get-Sha256 $bundletoolPath) -ne
      ([string]$manifest.toolchain.bundletoolSha256).ToUpperInvariant() -or
    [string]$manifest.toolchain.bundletoolSha256 -ne
      [string]$policy.toolchain.bundletoolSha256) {
  throw 'bundletool custody mismatch.'
}

if ([string]$manifest.toolchain.firebaseToolsVersion -ne
      [string]$policy.toolchain.firebaseToolsVersion -or
    [string]$manifest.toolchain.firebaseToolsLockfileSha256 -ne
      [string]$policy.toolchain.firebaseToolsLockfileSha256 -or
    [string]$manifest.toolchain.linuxIsarCoreSha256 -ne
      [string]$policy.toolchain.linuxIsarCoreSha256) {
  throw 'Governed Firebase CLI or Isar toolchain authority mismatch.'
}

$certificateDerPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$manifest.signing.certificateDerFile)
$certificatePemPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$manifest.signing.certificatePemFile)

if ((Get-Sha256 $certificateDerPath) -ne
      ([string]$manifest.signing.certificateDerSha256).ToUpperInvariant() -or
    (Get-Sha256 $certificatePemPath) -ne
      ([string]$manifest.signing.certificatePemSha256).ToUpperInvariant() -or
    (Get-Sha256 $certificateDerPath) -ne
      ([string]$manifest.signing.certificateSha256).ToUpperInvariant()) {
  throw 'Packaged approved signer certificate custody mismatch.'
}

$apkSigner = Find-AndroidTool `
  -Names @('apksigner.bat', 'apksigner') `
  -RelativeRoots @('build-tools')
$apkAnalyzer = Find-AndroidTool `
  -Names @('apkanalyzer.bat', 'apkanalyzer') `
  -RelativeRoots @('cmdline-tools', 'tools')

$apkCertificateSha256 = Get-ApkCertificateSha256 `
  -ApkSigner $apkSigner `
  -ApkPath $apkPath
$aabCertificateSha256 = Get-AabCertificateSha256 `
  -AabPath $aabPath `
  -ApprovedCertificateDerPath $certificateDerPath

if ($apkCertificateSha256 -ne
      ([string]$manifest.signing.certificateSha256).ToUpperInvariant() -or
    $aabCertificateSha256 -ne $apkCertificateSha256) {
  throw 'APK/AAB signer does not match the approved certificate.'
}

$apkFacts = [ordered]@{
  applicationId = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'application-id' `
    -ApkPath $apkPath
  versionName = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'version-name' `
    -ApkPath $apkPath
  versionCode = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'version-code' `
    -ApkPath $apkPath
  debuggable = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'debuggable' `
    -ApkPath $apkPath
}
$aabFacts = Get-AabManifestFacts `
  -BundletoolJar $bundletoolPath `
  -AabPath $aabPath

foreach ($facts in @($apkFacts, $aabFacts)) {
  if ($facts.applicationId -ne
        [string]$manifest.packageIdentity.applicationId -or
      $facts.versionName -ne [string]$manifest.release.versionName -or
      [string]$facts.versionCode -ne
        [string]$manifest.release.buildNumber -or
      [string]$facts.debuggable -ne 'false') {
    throw 'Compiled artifact package/version/debuggable state mismatch.'
  }
}

foreach ($property in $manifest.dependencies.lockfiles.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $sourceArchivePath `
    -EntryPath ([string]$property.Name)

  if ($actual -ne ([string]$property.Value).ToUpperInvariant()) {
    throw "Lockfile mismatch: $($property.Name)"
  }
}

foreach ($property in $manifest.configuration.hashes.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $sourceArchivePath `
    -EntryPath ([string]$property.Name)

  if ($actual -ne ([string]$property.Value).ToUpperInvariant()) {
    throw "Configuration mismatch: $($property.Name)"
  }
}
if ($null -eq
      $manifest.configuration.hashes.PSObject.Properties[
        'tools/release/Finalize-ProductionRelease.ps1'
      ]) {
  throw 'Governed finalizer is absent from source configuration custody.'
}

$packagedVerifierPath = Resolve-ContainedFile `
  -Root $packageDirectory `
  -RelativePath ([string]$manifest.verificationTool.file)
if ((Get-Sha256 $packagedVerifierPath) -ne
      ([string]$manifest.verificationTool.sha256).ToUpperInvariant() -or
    (Get-ZipEntrySha256 `
      -ArchivePath $sourceArchivePath `
      -EntryPath ([string]$manifest.verificationTool.sourceArchiveEntry)) -ne
      ([string]$manifest.verificationTool.sourceArchiveEntrySha256).ToUpperInvariant()) {
  throw 'Packaged verifier custody mismatch.'
}

$result = [ordered]@{
  schemaVersion = 2
  verifiedAtUtc = [DateTime]::UtcNow.ToString('o')
  status = 'passed'
  gitCommit = [string]$manifest.source.gitCommit
  githubRunId = [string]$manifest.ciAuthority.runId
  applicationId = [string]$manifest.packageIdentity.applicationId
  version =
    "$($manifest.release.versionName)+$($manifest.release.buildNumber)"
  apkSha256 = Get-Sha256 $apkPath
  aabSha256 = Get-Sha256 $aabPath
  certificateSha256 = $apkCertificateSha256
  backendReleaseId = [string]$authority.releaseId
  indexParity = 'proven'
  remoteReservationTag =
    [string]$manifest.remoteBuildAuthority.reservationTag
  distributionAuthority =
    'production-signed-pre-release-candidate'
  unrestrictedPlantReleaseApproved = $false
}

$resultPath = Join-Path $packageDirectory 'production-verification-result.json'
[IO.File]::WriteAllText(
  $resultPath,
  (($result | ConvertTo-Json -Depth 20) + "`n"),
  [Text.UTF8Encoding]::new($false)
)

Write-Host ''
Write-Host '===== PRODUCTION-SIGNED PRE-RELEASE PACKAGE VERIFIED =====' `
  -ForegroundColor Green
Write-Host "Application ID: $($result.applicationId)"
Write-Host "Version:        $($result.version)"
Write-Host "GitHub run:     $($result.githubRunId)"
Write-Host "Reservation:    $($result.remoteReservationTag)"
Write-Host 'Distribution:   NOT APPROVED'
Write-Host 'Unrestricted:   NOT APPROVED'
