<#
.SYNOPSIS
Builds a governed verification-class Android APK and emits a self-verifiable
release-provenance package.

.DESCRIPTION
This is 70I-B1 tooling. It intentionally builds a DEBUG-signed APK and labels
it verification-only. It must never be used to claim production distribution.

The script:
- requires a clean immutable Git commit;
- validates the authenticated backend-authority record;
- creates and hashes a deterministic Git source archive;
- supplies all ten AppBuildIdentity values;
- optionally runs the repository quality gate and closure emulator suite;
- builds a debug APK;
- records artifact and signer digests;
- emits release-manifest.json and release-ledger.md;
- runs the independent manifest verifier.

It does not deploy Firebase or modify the repository.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')]
  [string]$AppVersion,

  [Parameter(Mandatory)]
  [ValidateRange(1, 2147483647)]
  [int]$BuildNumber,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseTag,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ReleaseId,

  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9a-fA-F]{40}$')]
  [string]$ExpectedCommit,

  [string]$ReleaseChannel = 'verification',
  [string]$CiRunId = 'local',
  [string]$ExpectedBackendReleaseId =
    'prod-composite-20260628T171115Z-rules-0b3868bf-fleet-d57d11bd',
  [string]$AuthorityPath = 'release/backend-authority.prod.json',
  [string]$OutputRoot,
  [string]$IsarCorePath = $env:CRM_ISAR_CORE_PATH,
  [string]$ExpectedIsarCoreSha256 =
    '5E67863F188C5F9681A37F84F2EB942EAF702509D3F994C0344D5049EBC9E48F',
  [switch]$SkipQualityGates
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File not found for SHA-256: $Path"
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}


function Get-ZipEntrySha256 {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  $normalized = $EntryPath.Replace('\', '/')
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

  try {
    $entry = $archive.Entries |
      Where-Object FullName -eq $normalized |
      Select-Object -First 1

    if ($null -eq $entry) {
      throw "Archive entry not found: $normalized"
    }

    $stream = $entry.Open()

    try {
      $sha = [System.Security.Cryptography.SHA256]::Create()

      try {
        $hash = $sha.ComputeHash($stream)
      }
      finally {
        $sha.Dispose()
      }

      return [Convert]::ToHexString($hash)
    }
    finally {
      $stream.Dispose()
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Get-ZipEntryText {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  $normalized = $EntryPath.Replace('\', '/')
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

  try {
    $entry = $archive.Entries |
      Where-Object FullName -eq $normalized |
      Select-Object -First 1

    if ($null -eq $entry) {
      throw "Archive entry not found: $normalized"
    }

    $stream = $entry.Open()

    try {
      $reader = [System.IO.StreamReader]::new(
        $stream,
        [System.Text.Encoding]::UTF8,
        $true
      )

      try {
        return $reader.ReadToEnd()
      }
      finally {
        $reader.Dispose()
      }
    }
    finally {
      $stream.Dispose()
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Export-ZipEntry {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath,
    [Parameter(Mandatory)][string]$DestinationPath
  )

  $normalized = $EntryPath.Replace('\', '/')
  $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

  try {
    $entry = $archive.Entries |
      Where-Object FullName -eq $normalized |
      Select-Object -First 1

    if ($null -eq $entry) {
      throw "Archive entry not found: $normalized"
    }

    $input = $entry.Open()

    try {
      $output = [System.IO.File]::Create($DestinationPath)

      try {
        $input.CopyTo($output)
      }
      finally {
        $output.Dispose()
      }
    }
    finally {
      $input.Dispose()
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Get-RequiredCommand {
  param([Parameter(Mandatory)][string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required command is unavailable: $Name"
  }
  return $command
}

function Get-ApkSignerPath {
  $roots = @(
    $env:ANDROID_HOME
    $env:ANDROID_SDK_ROOT
  )

  if (
    $IsWindows -and
    -not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)
  ) {
    $roots += Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }

  $candidates = @()

  foreach ($root in $roots) {
    if ([string]::IsNullOrWhiteSpace($root)) { continue }

    $buildTools = Join-Path $root 'build-tools'
    if (-not (Test-Path -LiteralPath $buildTools -PathType Container)) {
      continue
    }

    $candidates += Get-ChildItem -LiteralPath $buildTools -Directory |
      Sort-Object Name -Descending |
      ForEach-Object {
        foreach ($name in @('apksigner.bat', 'apksigner')) {
          $candidate = Join-Path $_.FullName $name
          if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $candidate
          }
        }
      }
  }

  $first = $candidates | Select-Object -First 1

  if ([string]::IsNullOrWhiteSpace($first)) {
    throw 'Android SDK apksigner was not found.'
  }

  return $first
}

function Get-ApkCertificateSha256 {
  param(
    [Parameter(Mandatory)][string]$ApkSigner,
    [Parameter(Mandatory)][string]$ApkPath,
    [string]$LogPath
  )

  $output = @(& $ApkSigner verify --print-certs $ApkPath 2>&1)
  $exit = $LASTEXITCODE
  if ($LogPath) {
    $output | Set-Content -LiteralPath $LogPath -Encoding UTF8
  }
  if ($exit -ne 0) {
    $output | Out-Host
    throw 'apksigner verification failed.'
  }

  $match = $output |
    Select-String -Pattern 'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)' |
    Select-Object -First 1

  if ($null -eq $match) {
    throw 'Unable to parse APK signing-certificate SHA-256 digest.'
  }

  return $match.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
}

function Get-TextOutput {
  param([Parameter(Mandatory)][scriptblock]$Command)
  return ((& $Command 2>&1) | Out-String).Trim()
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo

foreach ($name in @('git', 'flutter', 'dart', 'node', 'npm', 'java', 'pwsh')) {
  Get-RequiredCommand $name | Out-Null
}

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
$tree = (git rev-parse 'HEAD^{tree}').Trim()
$status = @(git status --porcelain=v1 --untracked-files=all)

if ($status.Count -gt 0) {
  $status | Out-Host
  throw 'The repository must be clean before a governed artifact build.'
}

if ($head -ne $ExpectedCommit.ToLowerInvariant()) {
  throw "HEAD mismatch. Expected $ExpectedCommit; actual $head"
}

$commitObject = (git cat-file -t $head).Trim()
if ($commitObject -ne 'commit') {
  throw 'ExpectedCommit does not resolve to a Git commit.'
}

$authorityEntryPath = 'release/backend-authority.prod.json'
$authorityFullPath = (Resolve-Path $AuthorityPath).Path
$workingTreeAuthority =
  Get-Content -LiteralPath $authorityFullPath -Raw |
  ConvertFrom-Json

& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/Test-BackendAuthority.ps1 `
  -AuthorityPath $authorityFullPath `
  -RepositoryRoot $repo `
  -ExpectedReleaseId $ExpectedBackendReleaseId
if ($LASTEXITCODE -ne 0) {
  throw 'Composite backend authority verification failed.'
}
if ($workingTreeAuthority.releaseId -ne $ExpectedBackendReleaseId) {
  throw "Expected backend release does not match authority: $ExpectedBackendReleaseId"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $parent = Split-Path -Parent $repo
  $OutputRoot = Join-Path $parent 'crm3_baf_ops_verification_artifacts'
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

$releaseDir = Join-Path $OutputRoot $ReleaseId
if (Test-Path -LiteralPath $releaseDir) {
  throw "Output directory already exists: $releaseDir"
}
New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null

$logsDir = Join-Path $releaseDir 'logs'
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($IsarCorePath)) {
  throw @"
A verified Isar native core is required for the full Flutter quality gate.

Supply -IsarCorePath and -ExpectedIsarCoreSha256, or set
CRM_ISAR_CORE_PATH before invoking this governed builder.
"@
}

$verifiedIsarCorePath = (Resolve-Path $IsarCorePath).Path
$actualIsarCoreSha256 = Get-Sha256 $verifiedIsarCorePath

if (
  $actualIsarCoreSha256 -ne
  $ExpectedIsarCoreSha256.ToUpperInvariant()
) {
  throw @"
Isar native-core SHA-256 mismatch.

Expected: $ExpectedIsarCoreSha256
Actual:   $actualIsarCoreSha256
Path:     $verifiedIsarCorePath
"@
}

$nativeDir = Join-Path $releaseDir 'native'
New-Item -ItemType Directory -Path $nativeDir -Force | Out-Null

$nativeEvidenceName = Split-Path $verifiedIsarCorePath -Leaf
$nativeEvidencePath = Join-Path $nativeDir $nativeEvidenceName

Copy-Item `
  -LiteralPath $verifiedIsarCorePath `
  -Destination $nativeEvidencePath

if ((Get-Sha256 $nativeEvidencePath) -ne $actualIsarCoreSha256) {
  throw 'Copied Isar native-core custody verification failed.'
}

# Child-process scoped; the parent operator environment is not modified.
$env:CRM_ISAR_CORE_PATH = $nativeEvidencePath

$sourceArchiveName = "$ReleaseId-source.zip"
$sourceArchivePath = Join-Path $releaseDir $sourceArchiveName

& git archive --format=zip --output=$sourceArchivePath $head
if ($LASTEXITCODE -ne 0) {
  throw 'git archive failed.'
}
$sourceArchiveSha256 = Get-Sha256 $sourceArchivePath

$authorityHash = Get-ZipEntrySha256 `
  -ArchivePath $sourceArchivePath `
  -EntryPath $authorityEntryPath

$authority = (
  Get-ZipEntryText `
    -ArchivePath $sourceArchivePath `
    -EntryPath $authorityEntryPath
) | ConvertFrom-Json

if ($authority.releaseId -ne $workingTreeAuthority.releaseId) {
  throw 'Git-archive authority differs from the working-tree authority.'
}


$buildTimestampUtc = [DateTime]::UtcNow.ToString('o')

$identity = [ordered]@{
  APP_VERSION = $AppVersion
  APP_BUILD_NUMBER = [string]$BuildNumber
  GIT_COMMIT = $head
  RELEASE_TAG = $ReleaseTag
  RELEASE_CHANNEL = $ReleaseChannel
  CI_RUN_ID = $CiRunId
  BUILD_TIMESTAMP_UTC = $buildTimestampUtc
  RELEASE_ID = $ReleaseId
  EXPECTED_BACKEND_RELEASE_ID = $ExpectedBackendReleaseId
  SOURCE_ARCHIVE_SHA256 = $sourceArchiveSha256
}

foreach ($entry in $identity.GetEnumerator()) {
  if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
    throw "Required AppBuildIdentity value is empty: $($entry.Key)"
  }
  if ([string]$entry.Value -match '^(unidentified|unavailable|unknown)$') {
    throw "Required AppBuildIdentity value is non-authoritative: $($entry.Key)"
  }
}

if (-not $SkipQualityGates) {
  $qualityLog = Join-Path $logsDir 'quality-gate.log'
  $qualityOutput = @(
    & pwsh -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $repo 'release_gate.ps1') -SkipBuild 2>&1
  )
  $qualityExit = $LASTEXITCODE
  $qualityOutput | Tee-Object -FilePath $qualityLog | Out-Host
  if ($qualityExit -ne 0) {
    throw 'Repository quality gate failed.'
  }

  $closureLog = Join-Path $logsDir 'closure-emulator.log'
  $closureOutput = @(& npm run emulator:test:closure 2>&1)
  $closureExit = $LASTEXITCODE
  $closureOutput | Tee-Object -FilePath $closureLog | Out-Host
  if ($closureExit -ne 0) {
    throw 'Closure Firestore-emulator integration gate failed.'
  }
  if (($closureOutput -join "`n") -match 'Jest did not exit one second') {
    throw 'Closure emulator suite reported an open handle.'
  }
}

$flutterArgs = @(
  'build', 'apk', '--debug',
  "--build-name=$AppVersion",
  "--build-number=$BuildNumber"
)
foreach ($entry in $identity.GetEnumerator()) {
  $flutterArgs += "--dart-define=$($entry.Key)=$($entry.Value)"
}

$buildLog = Join-Path $logsDir 'flutter-build-debug.log'
$buildOutput = @(& flutter @flutterArgs 2>&1)
$buildExit = $LASTEXITCODE
$buildOutput | Tee-Object -FilePath $buildLog | Out-Host
if ($buildExit -ne 0) {
  throw 'Flutter debug APK build failed.'
}

$builtApk = Join-Path $repo 'build/app/outputs/flutter-apk/app-debug.apk'
if (-not (Test-Path -LiteralPath $builtApk -PathType Leaf)) {
  throw 'Expected debug APK was not produced.'
}

$artifactName = "$ReleaseId-verification-debug.apk"
$artifactPath = Join-Path $releaseDir $artifactName
Copy-Item -LiteralPath $builtApk -Destination $artifactPath
$artifactSha256 = Get-Sha256 $artifactPath
$artifactSize = (Get-Item -LiteralPath $artifactPath).Length

$apkSigner = Get-ApkSignerPath
$signerLog = Join-Path $logsDir 'apksigner.log'
$certificateSha256 = Get-ApkCertificateSha256 `
  -ApkSigner $apkSigner `
  -ApkPath $artifactPath `
  -LogPath $signerLog

$gradleWrapperText = Get-Content `
  -LiteralPath 'android/gradle/wrapper/gradle-wrapper.properties' -Raw
$gradleVersion = if (
  $gradleWrapperText -match 'gradle-([0-9.]+)-(?:all|bin)\.zip'
) { $Matches[1] } else { 'unparsed' }

$settingsText = Get-Content -LiteralPath 'android/settings.gradle.kts' -Raw
$agpVersion = if (
  $settingsText -match 'com\.android\.application"\) version "([^"]+)"'
) { $Matches[1] } else { 'unparsed' }
$kotlinVersion = if (
  $settingsText -match 'org\.jetbrains\.kotlin\.android"\) version "([^"]+)"'
) { $Matches[1] } else { 'unparsed' }

$appGradle = Get-Content -LiteralPath 'android/app/build.gradle.kts' -Raw
$applicationId = if (
  $appGradle -match 'applicationId\s*=\s*"([^"]+)"'
) { $Matches[1] } else { 'unparsed' }
$namespace = if (
  $appGradle -match 'namespace\s*=\s*"([^"]+)"'
) { $Matches[1] } else { 'unparsed' }

$flutterMachine = Get-TextOutput { flutter --version --machine }
$flutterInfo = $flutterMachine | ConvertFrom-Json

$lockfiles = [ordered]@{}
foreach ($path in @(
  'pubspec.lock'
  'package-lock.json'
  'functions/package-lock.json'
)) {
  $lockfiles[$path] = Get-ZipEntrySha256 `
    -ArchivePath $sourceArchivePath `
    -EntryPath $path
}

$configHashes = [ordered]@{}
foreach ($path in @(
  'firestore.rules'
  'firestore.indexes.json'
  'android/app/build.gradle.kts'
  'android/settings.gradle.kts'
  'android/gradle/wrapper/gradle-wrapper.properties'
  'pubspec.yaml'
)) {
  $configHashes[$path] = Get-ZipEntrySha256 `
    -ArchivePath $sourceArchivePath `
    -EntryPath $path
}

$verifierSourceEntry = 'tools/release/Test-ReleaseManifest.ps1'
$verifierName = 'verify-release-package.ps1'
$verifierPath = Join-Path $releaseDir $verifierName

Export-ZipEntry `
  -ArchivePath $sourceArchivePath `
  -EntryPath $verifierSourceEntry `
  -DestinationPath $verifierPath

$verifierSha256 = Get-Sha256 $verifierPath
$verifierSourceSha256 = Get-ZipEntrySha256 `
  -ArchivePath $sourceArchivePath `
  -EntryPath $verifierSourceEntry

if ($verifierSha256 -ne $verifierSourceSha256) {
  throw 'Packaged verifier differs from its canonical source-archive entry.'
}

$manifest = [ordered]@{
  schemaVersion = 3
  generatedAtUtc = $buildTimestampUtc
  artifactClass = 'verification'
  distributionAuthority = 'not-approved-for-production'
  release = [ordered]@{
    appVersion = $AppVersion
    buildNumber = [string]$BuildNumber
    releaseTag = $ReleaseTag
    releaseChannel = $ReleaseChannel
    ciRunId = $CiRunId
    releaseId = $ReleaseId
  }
  appIdentity = $identity
  source = [ordered]@{
    gitCommit = $head
    gitTree = $tree
    branch = $branch
    repositoryClean = $true
    sourceArchiveFile = $sourceArchiveName
    sourceArchiveSha256 = $sourceArchiveSha256
    hashBasis = 'git-archive-entry-bytes'
    entryPathStyle = 'posix'
  }
  artifact = [ordered]@{
    file = $artifactName
    type = 'apk'
    buildMode = 'debug'
    sha256 = $artifactSha256
    sizeBytes = $artifactSize
  }
  signing = [ordered]@{
    mode = 'debug'
    certificateSha256 = $certificateSha256
    productionSigningApproved = $false
  }
  packageIdentity = [ordered]@{
    applicationId = $applicationId
    namespace = $namespace
    permanentIdentityApproved = $false
  }
  backend = [ordered]@{
    expectedReleaseId = $ExpectedBackendReleaseId
    authorityFile = $authorityEntryPath
    authorityFileSha256 = $authorityHash
    authority = $authority
    expectedMatchesAuthority = $true
    runtimeParityEvaluatedByBuild = $false
    appGitCommit = $head
    authorityClass = [string]$authority.authorityClass
    authorityDigest = [string]$authority.authorityDigest
    releaseModel = $authority.releaseModel
    repositoryAuthority = $authority.repositoryAuthority
    firestore = $authority.firestore
    sourceCustody = $authority.sourceCustody
  }
  verificationTool = [ordered]@{
    file = $verifierName
    sha256 = $verifierSha256
    sourceArchiveEntry = $verifierSourceEntry
    sourceArchiveEntrySha256 = $verifierSourceSha256
    packageOnlyInvocation =
      'pwsh ./verify-release-package.ps1 -ManifestPath ./release-manifest.json'
  }
  nativeTestDependencies = [ordered]@{
    isarCore = [ordered]@{
      file = "native/$nativeEvidenceName"
      sha256 = $actualIsarCoreSha256
      platform =
        [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
      processArchitecture =
        [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
      source = 'preverified-external-native-dependency'
      usedForQualityGates = (-not $SkipQualityGates)
    }
  }
  dependencies = [ordered]@{
    lockfiles = $lockfiles
  }
  configuration = [ordered]@{
    hashes = $configHashes
  }
  toolchain = [ordered]@{
    flutterVersion = [string]$flutterInfo.frameworkVersion
    flutterChannel = [string]$flutterInfo.channel
    dartVersion = [string]$flutterInfo.dartSdkVersion
    javaVersion = Get-TextOutput { java -version }
    nodeVersion = Get-TextOutput { node --version }
    npmVersion = Get-TextOutput { npm --version }
    firebaseToolsVersion = Get-TextOutput { firebase --version }
    gradleWrapperVersion = $gradleVersion
    androidGradlePluginVersion = $agpVersion
    kotlinVersion = $kotlinVersion
    apkSignerPath = $apkSigner
  }
  qualityGates = [ordered]@{
    executed = (-not $SkipQualityGates)
    repositoryReleaseGate = if ($SkipQualityGates) { 'skipped' } else { 'passed' }
    closureFirestoreEmulator = if ($SkipQualityGates) { 'skipped' } else { 'passed' }
  }
  rollback = [ordered]@{
    verificationOnly = $true
    prerequisites = @(
      'Previous APK must use the same signing certificate.',
      'Device data must be backed up before any downgrade.',
      'Rollback is not production-approved under 70I-B1.'
    )
    adbCommandTemplate = 'adb install -r -d "<previous-verification-apk>"'
    sourceRebuildCommandTemplate =
      "git checkout $head; pwsh tools/release/New-VerificationArtifact.ps1 ..."
  }
}

$manifestPath = Join-Path $releaseDir 'release-manifest.json'
$manifest |
  ConvertTo-Json -Depth 100 |
  Set-Content -LiteralPath $manifestPath -Encoding UTF8

$ledgerPath = Join-Path $releaseDir 'release-ledger.md'
$ledger = @"
# CRM-III BAF Ops — Verification Artifact Ledger

- Artifact class: **verification**
- Distribution authority: **not approved for production**
- Signing mode: **debug**
- Release ID: ``$ReleaseId``
- Application version/build: ``$AppVersion+$BuildNumber``
- Application commit: ``$head``
- Git tree: ``$tree``
- Source archive SHA-256: ``$sourceArchiveSha256``
- APK SHA-256: ``$artifactSha256``
- Signing certificate SHA-256: ``$certificateSha256``
- Expected backend release: ``$ExpectedBackendReleaseId``
- Backend authority: ``$($authority.authorityClass)``
- Backend reconstruction commit: ``$($authority.repositoryAuthority.productionReconstructionSourceCommit)``
- Backend fleet: ``$($authority.releaseModel.functionFleetStatus)``
- Deployed-index parity: **$($authority.firestore.indexes.status)**
- Build time UTC: ``$buildTimestampUtc``

## Composite backend boundary

The backend authority records a mixed live Function fleet. It does not claim
that one Git commit represents every deployed Function.

## Rollback prerequisites

1. Preserve user data and diagnostic evidence.
2. Confirm the previous APK uses signing certificate
   ``$certificateSha256``.
3. Use only a previously verified artifact.
4. Run:

``````text
adb install -r -d "<previous-verification-apk>"
``````

This artifact is not a production release and does not authorize production
distribution.
"@
$ledger | Set-Content -LiteralPath $ledgerPath -Encoding UTF8

& pwsh -NoProfile -ExecutionPolicy Bypass -File $verifierPath `
  -ManifestPath $manifestPath

if ($LASTEXITCODE -ne 0) {
  throw 'Package-only release-manifest verification failed.'
}

$manifestSha256 = Get-Sha256 $manifestPath
$ledgerSha256 = Get-Sha256 $ledgerPath

[ordered]@{
  releaseId = $ReleaseId
  manifestSha256 = $manifestSha256
  ledgerSha256 = $ledgerSha256
  artifactSha256 = $artifactSha256
  sourceArchiveSha256 = $sourceArchiveSha256
  certificateSha256 = $certificateSha256
  verifierSha256 = $verifierSha256
} |
  ConvertTo-Json -Depth 20 |
  Set-Content `
    -LiteralPath (Join-Path $releaseDir 'custody-summary.json') `
    -Encoding UTF8

$statusAfter = @(git status --porcelain=v1 --untracked-files=all)
if ($statusAfter.Count -gt 0) {
  $statusAfter | Out-Host
  throw 'Repository changed during governed artifact generation.'
}

Write-Host ''
Write-Host '===== GOVERNED VERIFICATION ARTIFACT PASSED =====' `
  -ForegroundColor Green
Write-Host "Release directory: $releaseDir"
Write-Host "Artifact SHA-256:  $artifactSha256"
Write-Host "Archive SHA-256:   $sourceArchiveSha256"
Write-Host "Signer SHA-256:    $certificateSha256"
Write-Host 'Artifact class:     verification'
Write-Host 'Production use:     NOT APPROVED'
Write-Host 'Firebase deployment: NOT PERFORMED'
