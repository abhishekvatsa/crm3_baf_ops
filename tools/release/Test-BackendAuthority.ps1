#requires -Version 7.0
<#
.SYNOPSIS
Validates the current composite production-backend authority.

.DESCRIPTION
This is a source-only gate. It verifies the strict schema-v2 boundary, exact
live Firestore index authority, evidence shape, and reconstruction custody
metadata. Historical source-custody entries are not compared with the current
checkout: they describe the reconstructed live deployment, not current
application source.
#>

[CmdletBinding()]
param(
  [string]$AuthorityPath = 'release/backend-authority.prod.json',
  [string]$RepositoryRoot = (Get-Location).Path,
  [string]$ExpectedReleaseId = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RequiredProperty {
  param(
    [Parameter(Mandatory)]$Object,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Context
  )

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    throw "Backend authority is missing $Context.$Name."
  }
  $property.Value
}

function Assert-Sha256 {
  param(
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][string]$Name
  )

  if ($Value -notmatch '^[0-9A-Fa-f]{64}$') {
    throw "Backend authority $Name is not a SHA-256 digest."
  }
}

$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$authorityFile = if ([IO.Path]::IsPathRooted($AuthorityPath)) {
  (Resolve-Path -LiteralPath $AuthorityPath).Path
} else {
  (Resolve-Path -LiteralPath (Join-Path $repo $AuthorityPath)).Path
}

$authority = Get-Content -LiteralPath $authorityFile -Raw | ConvertFrom-Json

if ([int]$authority.schemaVersion -ne 2 -or
    [string]$authority.authorityClass -ne
      'verified-production-backend-composite' -or
    [string]$authority.authorityStatus -ne
      'CURRENT_LIVE_STATE_RECORDED' -or
    [string]$authority.environment -ne 'production' -or
    [string]$authority.firebaseProjectId -ne 'crm3-baf-ops-b8638') {
  throw 'Backend authority is not the current strict production composite.'
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

Assert-Sha256 -Value ([string]$authority.authorityDigest) `
  -Name 'authorityDigest'
if ([string]$authority.authorityDigestAlgorithm -ne
  'CRM3-CANONICAL-JSON-V1: SHA-256 of UTF-8 JSON with sorted keys and compact separators after omitting top-level authorityDigest') {
  throw 'Backend authority digest algorithm is unexpected.'
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedReleaseId) -and
    [string]$authority.releaseId -ne $ExpectedReleaseId) {
  throw 'Backend authority release ID differs from the expected release.'
}

$releaseModel = Get-RequiredProperty `
  -Object $authority `
  -Name 'releaseModel' `
  -Context 'root'
if ([string]$releaseModel.type -ne 'COMPOSITE_LIVE_STATE' -or
    $releaseModel.singleHomogeneousDeployment -ne $false -or
    [string]$releaseModel.functionFleetStatus -ne
      'MIXED_DEPLOYMENT_FLEET') {
  throw 'Backend authority release model overstates a homogeneous deployment.'
}

$firestore = Get-RequiredProperty `
  -Object $authority `
  -Name 'firestore' `
  -Context 'root'
$indexes = Get-RequiredProperty `
  -Object $firestore `
  -Name 'indexes' `
  -Context 'firestore'

if ([string]$indexes.status -ne 'EXACT' -or
    $indexes.allReady -ne $true -or
    [int]$indexes.sourceCompositeIndexes -le 0 -or
    [int]$indexes.sourceCompositeIndexes -ne
      [int]$indexes.deployedCompositeIndexes -or
    [int]$indexes.fieldOverrideCount -ne 0) {
  throw 'Firestore composite-index authority is not exact and ready.'
}

foreach ($field in @(
  'sourceSha256'
  'fieldOverrideFingerprint'
  'indexIdentityFingerprint'
)) {
  Assert-Sha256 -Value ([string]$indexes.$field) `
    -Name "firestore.indexes.$field"
}

$parityEvidence = @(
  $authority.evidenceChain |
    Where-Object {
      [string]$_.role -eq
        'LIVE_PARITY_FUNCTION_ARCHIVES_IAM_AND_TOPOLOGY'
    }
)
if ($parityEvidence.Count -ne 1) {
  throw 'Backend authority must contain exactly one live-parity evidence record.'
}
Assert-Sha256 -Value ([string]$parityEvidence[0].sha256) `
  -Name 'live-parity evidence sha256'

$sourceCustody = Get-RequiredProperty `
  -Object $authority `
  -Name 'sourceCustody' `
  -Context 'root'
$custodyFiles = @(Get-RequiredProperty `
  -Object $sourceCustody `
  -Name 'files' `
  -Context 'sourceCustody')
if ($custodyFiles.Count -eq 0) {
  throw 'Backend authority reconstruction source custody is empty.'
}

$seenPaths = [Collections.Generic.HashSet[string]]::new(
  [StringComparer]::Ordinal
)
foreach ($entry in $custodyFiles) {
  if ([string]::IsNullOrWhiteSpace([string]$entry.path) -or
      [string]::IsNullOrWhiteSpace([string]$entry.role) -or
      -not $seenPaths.Add([string]$entry.path)) {
    throw 'Backend authority reconstruction custody has an invalid path or role.'
  }
  Assert-Sha256 -Value ([string]$entry.sha256) `
    -Name "sourceCustody.files[$($entry.path)].sha256"
}

$indexCustody = @(
  $custodyFiles |
    Where-Object { [string]$_.path -eq 'firestore.indexes.json' }
)
if ($indexCustody.Count -ne 1 -or
    [string]$indexCustody[0].sha256 -ne
      [string]$indexes.sourceSha256) {
  throw 'Live Firestore index authority differs from reconstruction custody.'
}

$reconstructionCommit = [string]$sourceCustody.reconstructionCommit
if ($reconstructionCommit -notmatch '^[0-9a-f]{40}$' -or
    $reconstructionCommit -ne
      [string]$authority.repositoryAuthority.productionReconstructionSourceCommit) {
  throw 'Backend authority reconstruction commit is incomplete or inconsistent.'
}

Write-Host 'Composite backend authority: PASS'
Write-Host "Backend release: $($authority.releaseId)"
Write-Host "Firestore indexes: $($indexes.sourceCompositeIndexes) exact and ready"
Write-Host "Reconstruction custody files: $($custodyFiles.Count)"
