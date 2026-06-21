<#
.SYNOPSIS
Independently verifies a CRM-III BAF Ops release-manifest package.

This script does not trust hashes merely because they appear in the manifest.
It recomputes artifact, archive, signing, authority, lockfile, configuration,
and backend source-custody digests.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$ManifestPath,

  [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
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
  param([string]$ApkSigner, [string]$ApkPath)
  $output = @(& $ApkSigner verify --print-certs $ApkPath 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw 'apksigner verification failed.'
  }
  $match = $output |
    Select-String -Pattern 'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)' |
    Select-Object -First 1
  if ($null -eq $match) {
    throw 'Unable to parse signer SHA-256.'
  }
  return $match.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
}

$manifestFull = (Resolve-Path $ManifestPath).Path
$releaseDir = Split-Path -Parent $manifestFull
$manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json

if ($manifest.schemaVersion -ne 2) {
  throw 'Unsupported manifest schema.'
}
if ($manifest.artifactClass -ne 'verification') {
  throw 'Artifact class must be verification.'
}
if ($manifest.distributionAuthority -ne 'not-approved-for-production') {
  throw 'Distribution authority is unsafe.'
}
if ($manifest.signing.mode -ne 'debug') {
  throw '70I-B1 manifest must declare debug signing.'
}
if ($manifest.signing.productionSigningApproved -ne $false) {
  throw '70I-B1 cannot approve production signing.'
}
if ($manifest.packageIdentity.permanentIdentityApproved -ne $false) {
  throw '70I-B1 cannot approve permanent package identity.'
}
if ($manifest.backend.deployedIndexesParityStatus -ne 'not-proven') {
  throw 'Manifest must preserve deployed-index parity as not-proven.'
}

if ($manifest.source.hashBasis -ne 'git-archive-entry-bytes') {
  throw 'Manifest source hash basis is not canonical Git-archive bytes.'
}
if ($manifest.source.entryPathStyle -ne 'posix') {
  throw 'Manifest source-entry path style is not posix.'
}

if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $repo = (Resolve-Path $RepositoryRoot).Path
  Set-Location $repo

  $status = @(git status --porcelain=v1 --untracked-files=all)
  if ($status.Count -gt 0) {
    throw 'Repository is dirty during manifest verification.'
  }

  $head = (git rev-parse HEAD).Trim()
  $tree = (git rev-parse 'HEAD^{tree}').Trim()

  if ($head -ne [string]$manifest.source.gitCommit) {
    throw 'Manifest Git commit differs from repository HEAD.'
  }
  if ($tree -ne [string]$manifest.source.gitTree) {
    throw 'Manifest Git tree differs from repository HEAD tree.'
  }
}

$artifactPath = Join-Path $releaseDir ([string]$manifest.artifact.file)
$archivePath = Join-Path $releaseDir ([string]$manifest.source.sourceArchiveFile)

if ((Get-Sha256 $artifactPath) -ne [string]$manifest.artifact.sha256) {
  throw 'Artifact SHA-256 mismatch.'
}
if ((Get-Sha256 $archivePath) -ne [string]$manifest.source.sourceArchiveSha256) {
  throw 'Source archive SHA-256 mismatch.'
}
if (
  [string]$manifest.appIdentity.SOURCE_ARCHIVE_SHA256 -ne
  [string]$manifest.source.sourceArchiveSha256
) {
  throw 'App identity source-archive hash mismatch.'
}

$verifierFile = [string]$manifest.verificationTool.file
$verifierPath = Join-Path $releaseDir $verifierFile
$verifierSha256 = Get-Sha256 $verifierPath

if ($verifierSha256 -ne [string]$manifest.verificationTool.sha256) {
  throw 'Packaged verifier SHA-256 mismatch.'
}

$verifierSourceSha256 = Get-ZipEntrySha256 `
  -ArchivePath $archivePath `
  -EntryPath ([string]$manifest.verificationTool.sourceArchiveEntry)

if (
  $verifierSourceSha256 -ne
  [string]$manifest.verificationTool.sourceArchiveEntrySha256
) {
  throw 'Verifier source-archive entry SHA-256 mismatch.'
}

if ($verifierSha256 -ne $verifierSourceSha256) {
  throw 'Packaged verifier differs from its canonical source entry.'
}

$isarCoreFile =
  [string]$manifest.nativeTestDependencies.isarCore.file
$isarCorePath = Join-Path $releaseDir $isarCoreFile
$isarCoreSha256 = Get-Sha256 $isarCorePath

if (
  $isarCoreSha256 -ne
  [string]$manifest.nativeTestDependencies.isarCore.sha256
) {
  throw 'Isar native-core SHA-256 mismatch.'
}

if (
  $manifest.nativeTestDependencies.isarCore.source -ne
  'preverified-external-native-dependency'
) {
  throw 'Isar native-core source classification is invalid.'
}

$apkSigner = Get-ApkSignerPath
$signerHash = Get-ApkCertificateSha256 $apkSigner $artifactPath
if ($signerHash -ne [string]$manifest.signing.certificateSha256) {
  throw 'Signing-certificate SHA-256 mismatch.'
}

$authorityEntry = ([string]$manifest.backend.authorityFile).Replace('\', '/')
$authorityHash = Get-ZipEntrySha256 `
  -ArchivePath $archivePath `
  -EntryPath $authorityEntry

if ($authorityHash -ne [string]$manifest.backend.authorityFileSha256) {
  throw 'Backend authority source-entry SHA-256 mismatch.'
}

$authority = (
  Get-ZipEntryText `
    -ArchivePath $archivePath `
    -EntryPath $authorityEntry
) | ConvertFrom-Json

if ($authority.releaseId -ne [string]$manifest.backend.expectedReleaseId) {
  throw 'Expected backend release differs from authority.'
}
if (
  [string]$manifest.appIdentity.EXPECTED_BACKEND_RELEASE_ID -ne
  [string]$authority.releaseId
) {
  throw 'App identity expected backend differs from authority.'
}
if (
  [string]$manifest.backend.backendGitCommit -ne
  [string]$authority.backendGitCommit
) {
  throw 'Backend Git commit mismatch.'
}

foreach ($property in $authority.sourceCustody.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath ([string]$property.Name)

  if ($actual -ne ([string]$property.Value).ToUpperInvariant()) {
    throw "Backend source-custody mismatch: $($property.Name)"
  }

  $manifestProperty = $manifest.backend.sourceCustody.PSObject.Properties |
    Where-Object Name -eq $property.Name |
    Select-Object -First 1

  if (
    $null -eq $manifestProperty -or
    [string]$manifestProperty.Value -ne $actual
  ) {
    throw "Manifest backend custody mismatch: $($property.Name)"
  }
}

foreach ($property in $manifest.dependencies.lockfiles.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath ([string]$property.Name)

  if ($actual -ne [string]$property.Value) {
    throw "Lockfile source-entry SHA-256 mismatch: $($property.Name)"
  }
}

foreach ($property in $manifest.configuration.hashes.PSObject.Properties) {
  $actual = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath ([string]$property.Name)

  if ($actual -ne [string]$property.Value) {
    throw "Configuration source-entry SHA-256 mismatch: $($property.Name)"
  }
}

$requiredIdentity = @(
  'APP_VERSION',
  'APP_BUILD_NUMBER',
  'GIT_COMMIT',
  'RELEASE_TAG',
  'RELEASE_CHANNEL',
  'CI_RUN_ID',
  'BUILD_TIMESTAMP_UTC',
  'RELEASE_ID',
  'EXPECTED_BACKEND_RELEASE_ID',
  'SOURCE_ARCHIVE_SHA256'
)
foreach ($name in $requiredIdentity) {
  $property = $manifest.appIdentity.PSObject.Properties |
    Where-Object Name -eq $name |
    Select-Object -First 1
  if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
    throw "Missing AppBuildIdentity field: $name"
  }
  if ([string]$property.Value -match '^(unidentified|unavailable|unknown)$') {
    throw "Non-authoritative AppBuildIdentity field: $name"
  }
}
if (
  [string]$manifest.appIdentity.GIT_COMMIT -ne
  [string]$manifest.source.gitCommit
) {
  throw 'AppBuildIdentity Git commit mismatch.'
}
if ([string]$manifest.appIdentity.RELEASE_ID -ne [string]$manifest.release.releaseId) {
  throw 'AppBuildIdentity release ID mismatch.'
}

$result = [ordered]@{
  schemaVersion = 2
  verifiedAtUtc = [DateTime]::UtcNow.ToString('o')
  status = 'passed'
  manifest = (Split-Path -Leaf $manifestFull)
  gitCommit = [string]$manifest.source.gitCommit
  artifactSha256 = Get-Sha256 $artifactPath
  sourceArchiveSha256 = Get-Sha256 $archivePath
  certificateSha256 = $signerHash
  isarCoreSha256 = $isarCoreSha256
  verifierSha256 = $verifierSha256
  sourceHashBasis = [string]$manifest.source.hashBasis
  backendReleaseId = [string]$authority.releaseId
  deployedIndexesParityStatus = [string]$authority.deployedIndexesParityStatus
}

$resultPath = Join-Path $releaseDir 'verification-result.json'
$result |
  ConvertTo-Json -Depth 20 |
  Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host ''
Write-Host '===== RELEASE MANIFEST VERIFIED =====' -ForegroundColor Green
Write-Host "Manifest:             $manifestFull"
Write-Host "Artifact SHA-256:     $($result.artifactSha256)"
Write-Host "Archive SHA-256:      $($result.sourceArchiveSha256)"
Write-Host "Certificate SHA-256:  $($result.certificateSha256)"
Write-Host "Backend release:      $($result.backendReleaseId)"
Write-Host 'Production approved:  NO'
