#requires -Version 7.0
<#
.SYNOPSIS
Verifies the source-controlled CRM-III BAF Ops production-release policy.

.DESCRIPTION
This verifier checks identity, version, source reservation, signing, Firebase
registration, migration-plan boundary, independently approved Linux Isar core,
locked Firebase CLI, action pins and non-distribution release boundaries.
#>

[CmdletBinding()]
param(
  [string]$PolicyPath = 'release/production-release-policy.json',
  [string]$AuthorityPath = 'release/backend-authority.prod.json',
  [string]$RepositoryRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedRepositorySlug = 'abhishekvatsa/crm3_baf_ops'
$ExpectedWorkflowPath = '.github/workflows/production-artifact.yml'
$ExpectedEnvironmentName = 'crm3-baf-ops-production-signing'
$ExpectedToolchain = [ordered]@{
  runnerImage = 'ubuntu-24.04'
  javaVersion = '21.0.11+10'
  nodeVersion = '22.15.0'
  npmVersion = '10.9.2'
  flutterVersion = '3.44.0'
  dartVersion = '3.12.0'
  firebaseToolsVersion = '15.22.4'
}

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }

  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-Utf8CrlfSha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }

  $text = [IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $Path).Path,
    [Text.UTF8Encoding]::new($false)
  )
  $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
    $normalized.Replace("`n", "`r`n")
  )
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    [Convert]::ToHexString($sha.ComputeHash($bytes))
  } finally {
    $sha.Dispose()
  }
}

function Get-YamlRunBlocks {
  param([Parameter(Mandatory)][string]$Source)

  $lines = [regex]::Split($Source, '\r?\n')
  $blocks = [Collections.Generic.List[string]]::new()
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    $inlineMatch = [regex]::Match($line, '^([ ]*)run:[ ]*(.+)$')
    if ($inlineMatch.Success -and
        $inlineMatch.Groups[2].Value -notmatch
          '^[|>][+-]?[ ]*(?:#.*)?$') {
      $blocks.Add($inlineMatch.Groups[2].Value)
      continue
    }
    $blockMatch = [regex]::Match(
      $line,
      '^([ ]*)run:[ ]*[|>][+-]?[ ]*(?:#.*)?$'
    )
    if (-not $blockMatch.Success) {
      continue
    }

    $baseIndent = $blockMatch.Groups[1].Value.Length
    $body = [Collections.Generic.List[string]]::new()
    $cursor = $index + 1
    while ($cursor -lt $lines.Count) {
      $bodyLine = $lines[$cursor]
      if ($bodyLine.Trim().Length -eq 0) {
        $body.Add($bodyLine)
        $cursor++
        continue
      }
      $indentMatch = [regex]::Match($bodyLine, '^([ ]*)')
      if (-not $indentMatch.Success -or
          $indentMatch.Groups[1].Value.Length -le $baseIndent) {
        break
      }
      $body.Add($bodyLine)
      $cursor++
    }
    $blocks.Add(($body -join "`n"))
    $index = $cursor - 1
  }
  $blocks.ToArray()
}

Set-Location (Resolve-Path -LiteralPath $RepositoryRoot)
$provisionalIsarBindings = @(
  Get-ChildItem -LiteralPath 'lib' -Recurse -Filter '*.g.dart' -File |
    Select-String -SimpleMatch 'PROVISIONAL_V4_ISAR_CODEGEN'
)
if ($provisionalIsarBindings.Count -gt 0) {
  $paths = $provisionalIsarBindings |
    ForEach-Object { $_.Path } |
    Sort-Object -Unique
  throw "Pinned Isar code generation has not replaced provisional v4 bindings: $($paths -join ', ')"
}
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json

if ($policy.schemaVersion -ne 3) {
  throw 'Unsupported production policy schema; expected 3.'
}

& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/Test-BackendAuthority.ps1 `
  -AuthorityPath $AuthorityPath `
  -RepositoryRoot $RepositoryRoot
if ($LASTEXITCODE -ne 0) {
  throw 'Composite backend authority verification failed.'
}
if ([string]$policy.firebaseProjectId -ne 'crm3-baf-ops-b8638') {
  throw 'Unexpected Firebase project.'
}
if ([string]$policy.github.repository -ne $ExpectedRepositorySlug -or
    [string]$policy.github.workflowPath -ne $ExpectedWorkflowPath -or
    [string]$policy.github.environmentName -ne $ExpectedEnvironmentName) {
  throw 'GitHub repository/workflow/environment differs from governed authority.'
}
foreach ($entry in $ExpectedToolchain.GetEnumerator()) {
  if ([string]$policy.toolchain.($entry.Key) -ne [string]$entry.Value) {
    throw "Production policy toolchain mismatch: $($entry.Key)"
  }
}
if ([string]$policy.toolchain.bundletoolUrl -notmatch '^https://') {
  throw 'bundletoolUrl must use HTTPS.'
}
if ([string]$policy.toolchain.bundletoolSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    [string]$policy.toolchain.linuxIsarCoreSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
  throw 'bundletool or Linux Isar authority hash is invalid.'
}
if ($policy.permanentIdentityApproved -ne $true -or
    [string]$policy.permanentApplicationId -like 'com.example*') {
  throw 'Permanent identity is not approved.'
}
if ([string]$policy.namespace -ne
    [string]$policy.permanentApplicationId) {
  throw 'Namespace/applicationId mismatch.'
}
if ($policy.versionPolicy.approved -ne $true -or
    [int64]$policy.versionPolicy.buildNumber -le 0) {
  throw 'Version policy is not approved.'
}
if ($policy.signing.productionSigningApproved -ne $true -or
    [string]$policy.signing.keystoreType -ne 'PKCS12' -or
    [string]$policy.signing.keystoreSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    [string]$policy.signing.certificateSha1 -notmatch '^[0-9A-Fa-f]{40}$' -or
    [string]$policy.signing.certificateSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    [string]$policy.signing.backupProofSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    [string]$policy.signing.recoveryProofSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    [string]$policy.signing.primaryCustodianName -eq
      [string]$policy.signing.backupCustodianName) {
  throw 'Production signing/custody policy is incomplete.'
}
if ([string]$policy.distribution.authority -ne
      'production-signed-pre-release-candidate' -or
    $policy.distribution.approved -ne $false -or
    $policy.distribution.unrestrictedPlantReleaseApproved -ne $false) {
  throw 'Source policy must remain non-distributable and unrestricted=false.'
}
if ($policy.distribution.postBuildPromotionRequiredForAnyDistribution -ne
    $true) {
  throw 'Post-build promotion requirement is missing.'
}

$requiredFiles = @(
  [string]$policy.identityApproval.receiptFile
  [string]$policy.versionPolicy.approvalReceiptFile
  [string]$policy.versionPolicy.sourceDocumentFile
  [string]$policy.signing.approvalReceiptFile
  [string]$policy.firebaseAndroidApp.registrationReceiptFile
  [string]$policy.firebaseAndroidApp.restorationReceiptFile
  [string]$policy.migrationPlan.receiptFile
  [string]$policy.versionPolicy.ledgerFile
  [string]$policy.toolchain.githubActionPinsFile
  [string]$policy.toolchain.firebaseToolsLockfile
  [string]$policy.toolchain.linuxIsarCoreAuthorityReceipt
)

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Required policy file is missing: $file"
  }
}

$identityReceipt = Get-Content -LiteralPath $policy.identityApproval.receiptFile -Raw |
  ConvertFrom-Json
if ([string]$identityReceipt.receiptType -ne 'permanent-android-identity' -or
    [string]$identityReceipt.applicationId -ne
      [string]$policy.permanentApplicationId -or
    [string]$identityReceipt.namespace -ne [string]$policy.namespace -or
    [string]$identityReceipt.sourceDocumentSha256 -ne
      [string]$policy.identityApproval.sourceDocumentSha256) {
  throw 'Permanent-identity approval receipt differs from policy.'
}

$versionReceipt = Get-Content `
  -LiteralPath $policy.versionPolicy.approvalReceiptFile `
  -Raw | ConvertFrom-Json
if ([string]$versionReceipt.receiptType -ne 'version-and-build-policy' -or
    [string]$versionReceipt.versionName -ne [string]$policy.release.versionName -or
    [int64]$versionReceipt.buildNumber -ne [int64]$policy.release.buildNumber -or
    [string]$versionReceipt.reservationId -ne
      [string]$policy.versionPolicy.reservationId -or
    [string]$versionReceipt.remoteReservationTag -ne
      [string]$policy.versionPolicy.remoteReservationTag -or
    [string]$versionReceipt.remoteBuiltTag -ne
      [string]$policy.versionPolicy.remoteBuiltTag -or
    [string]$versionReceipt.sourceDocumentFile -ne
      [string]$policy.versionPolicy.sourceDocumentFile -or
    [string]$versionReceipt.sourceDocumentSha256 -ne
      [string]$policy.versionPolicy.sourceDocumentSha256) {
  throw 'Version-policy approval receipt differs from policy.'
}

$versionSource = Get-Content `
  -LiteralPath $policy.versionPolicy.sourceDocumentFile `
  -Raw | ConvertFrom-Json
if ((Get-Sha256 $policy.versionPolicy.sourceDocumentFile) -ne
      ([string]$policy.versionPolicy.sourceDocumentSha256).
        ToUpperInvariant() -or
    [string]$versionSource.documentType -ne
      'governed-build-number-rollover-approval' -or
    $versionSource.approved -ne $true -or
    [int64]$versionSource.nextBuild.buildNumber -ne
      [int64]$policy.release.buildNumber -or
    [string]$versionSource.nextBuild.releaseId -ne
      [string]$policy.release.releaseId -or
    [string]$versionSource.nextBuild.reservationId -ne
      [string]$policy.versionPolicy.reservationId -or
    [int64]$versionSource.consumedBuild.buildNumber -ge
      [int64]$versionSource.nextBuild.buildNumber -or
    [int64]$versionSource.nextBuild.buildNumber -ne
      ([int64]$versionSource.consumedBuild.buildNumber + 1) -or
    [string]$versionSource.consumedBuild.conclusion -ne 'failure' -or
    [string]$versionSource.nextBuild.remoteReservationTag -ne
      [string]$policy.versionPolicy.remoteReservationTag -or
    [string]$versionSource.nextBuild.remoteBuiltTag -ne
      [string]$policy.versionPolicy.remoteBuiltTag -or
    [string]$versionReceipt.reference -ne
      [string]$versionSource.approvalReference -or
    $versionSource.controls.fullPolicyAndAuthorityPreflightBeforeReservation -ne
      $true -or
    $versionSource.controls.failedOrWithdrawnBuildConsumesNumber -ne $true -or
    $versionSource.distributionApproved -ne $false -or
    $versionSource.unrestrictedPlantReleaseApproved -ne $false) {
  throw 'Governed build-number rollover authority is incomplete.'
}

$signingReceipt = Get-Content -LiteralPath $policy.signing.approvalReceiptFile -Raw |
  ConvertFrom-Json
if ([string]$signingReceipt.receiptType -ne 'production-signing-and-custody' -or
    [string]$signingReceipt.keyAlias -ne [string]$policy.signing.keyAlias -or
    [string]$signingReceipt.keystoreSha256 -ne
      [string]$policy.signing.keystoreSha256 -or
    [string]$signingReceipt.certificateSha1 -ne
      [string]$policy.signing.certificateSha1 -or
    [string]$signingReceipt.certificateSha256 -ne
      [string]$policy.signing.certificateSha256 -or
    [string]$signingReceipt.primaryCustodian -ne
      [string]$policy.signing.primaryCustodianName -or
    [string]$signingReceipt.backupCustodian -ne
      [string]$policy.signing.backupCustodianName -or
    [string]$signingReceipt.sourceDocumentSha256 -ne
      [string]$policy.signing.sourceDocumentSha256 -or
    [string]$signingReceipt.backupProofSha256 -ne
      [string]$policy.signing.backupProofSha256 -or
    [string]$signingReceipt.recoveryProofSha256 -ne
      [string]$policy.signing.recoveryProofSha256) {
  throw 'Signing/custody approval receipt differs from policy.'
}

$firebaseReceipt = Get-Content `
  -LiteralPath $policy.firebaseAndroidApp.registrationReceiptFile `
  -Raw | ConvertFrom-Json
if ([string]$firebaseReceipt.receiptType -ne 'firebase-android-registration' -or
    [string]$firebaseReceipt.projectId -ne [string]$policy.firebaseProjectId -or
    [string]$firebaseReceipt.applicationId -ne
      [string]$policy.permanentApplicationId -or
    [string]$firebaseReceipt.firebaseAppId -ne
      [string]$policy.firebaseAndroidApp.firebaseAppId -or
    [string]$firebaseReceipt.oauthClientId -ne
      [string]$policy.firebaseAndroidApp.androidOauthClientId -or
    [string]$firebaseReceipt.certificateSha1 -ne
      [string]$policy.signing.certificateSha1 -or
    [string]$firebaseReceipt.sourceDocumentSha256 -ne
      [string]$policy.firebaseAndroidApp.registrationSourceDocumentSha256) {
  throw 'Firebase registration receipt differs from policy.'
}

$actionPins = Get-Content -LiteralPath $policy.toolchain.githubActionPinsFile -Raw |
  ConvertFrom-Json
if ($actionPins.schemaVersion -ne 1 -or
    @($actionPins.actions.PSObject.Properties).Count -ne 5) {
  throw 'GitHub Actions pin authority is incomplete.'
}

$ledger = Get-Content -LiteralPath $policy.versionPolicy.ledgerFile -Raw |
  ConvertFrom-Json
$ledgerMatches = @(
  $ledger.entries |
    Where-Object {
      [int64]$_.buildNumber -eq
        [int64]$policy.versionPolicy.buildNumber
    }
)

if ($ledgerMatches.Count -ne 1) {
  throw 'Build number must have exactly one source reservation.'
}

$reservation = $ledgerMatches[0]
if ([string]$reservation.reservationId -ne
      [string]$policy.versionPolicy.reservationId -or
    [string]$reservation.releaseId -ne
      [string]$policy.release.releaseId -or
    [string]$reservation.versionName -ne
      [string]$policy.release.versionName -or
    [string]$reservation.status -ne
      'source-reserved-awaiting-remote-consumption' -or
    [string]$reservation.versionApprovalReference -ne
      [string]$versionReceipt.reference -or
    [string]$reservation.versionApprovalDocumentSha256 -ne
      [string]$policy.versionPolicy.sourceDocumentSha256) {
  throw 'Build-number source reservation differs from policy.'
}

$consumedMatches = @(
  $ledger.entries |
    Where-Object {
      [int64]$_.buildNumber -eq
        [int64]$versionSource.consumedBuild.buildNumber
    }
)
if ($consumedMatches.Count -ne 1 -or
    [string]$consumedMatches[0].status -ne
      'remote-consumed-build-failed' -or
    [int64]$consumedMatches[0].githubRunId -ne
      [int64]$versionSource.consumedBuild.githubRunId -or
    $consumedMatches[0].failedOrWithdrawnBuildConsumesNumber -ne $true -or
    $consumedMatches[0].artifactConstructed -ne $false -or
    $consumedMatches[0].artifactUploaded -ne $false -or
    $consumedMatches[0].remoteBuiltTagCreated -ne $false) {
  throw 'Consumed failed-build evidence differs from rollover authority.'
}

if (@(
    $ledger.entries |
      Group-Object buildNumber |
      Where-Object Count -gt 1
  ).Count -gt 0) {
  throw 'Duplicate build number exists in source ledger.'
}

$expectedReservationTag =
  "crm3-build-reserved/$($policy.versionPolicy.buildNumber)"
$expectedBuiltTag =
  "crm3-build-built/$($policy.versionPolicy.buildNumber)"

if ([string]$policy.versionPolicy.remoteReservationTag -ne
      $expectedReservationTag -or
    [string]$policy.versionPolicy.remoteBuiltTag -ne
      $expectedBuiltTag -or
    $policy.versionPolicy.failedOrWithdrawnBuildConsumesNumber -ne $true) {
  throw 'Remote never-reuse build-number contract is incomplete.'
}

if ([int64]$policy.release.buildNumber -ne
    [int64]$policy.versionPolicy.buildNumber) {
  throw 'Release/build-number mismatch.'
}

$pubspec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
$expectedVersionLine =
  "$([regex]::Escape([string]$policy.release.versionName))\+" +
  "$($policy.release.buildNumber)"
if ($pubspec -notmatch "(?m)^version:\s*$expectedVersionLine\s*$") {
  throw 'pubspec version differs from policy.'
}

$gradle = Get-Content -LiteralPath 'android/app/build.gradle.kts' -Raw
foreach ($required in @(
  "namespace = `"$($policy.namespace)`""
  "applicationId = `"$($policy.permanentApplicationId)`""
  'signingConfigs.getByName("production")'
  'Release signing input missing'
  'isDebuggable = false'
)) {
  if (-not $gradle.Contains($required)) {
    throw "Gradle production contract is missing: $required"
  }
}

$google = Get-Content -LiteralPath 'android/app/google-services.json' -Raw |
  ConvertFrom-Json
$firebaseClient = $google.client |
  Where-Object {
    [string]$_.client_info.android_client_info.package_name -eq
      [string]$policy.permanentApplicationId
  } |
  Select-Object -First 1

if ($null -eq $firebaseClient -or
    [string]$firebaseClient.client_info.mobilesdk_app_id -ne
      [string]$policy.firebaseAndroidApp.firebaseAppId) {
  throw 'Firebase Android app identity mismatch.'
}

$oauthClient = $firebaseClient.oauth_client |
  Where-Object {
    [int]$_.client_type -eq 1 -and
    [string]$_.android_info.package_name -eq
      [string]$policy.permanentApplicationId -and
    ([string]$_.android_info.certificate_hash).
      Replace(':', '').
      ToUpperInvariant() -eq
      ([string]$policy.signing.certificateSha1).ToUpperInvariant()
  } |
  Select-Object -First 1

if ($null -eq $oauthClient -or
    [string]$oauthClient.client_id -ne
      [string]$policy.firebaseAndroidApp.androidOauthClientId) {
  throw 'Firebase OAuth package/certificate registration mismatch.'
}

$debugOauthClient = $firebaseClient.oauth_client |
  Where-Object {
    [int]$_.client_type -eq 1 -and
    [string]$_.android_info.package_name -eq
      [string]$policy.permanentApplicationId -and
    ([string]$_.android_info.certificate_hash).
      Replace(':', '').
      ToUpperInvariant() -eq
      ([string]$policy.firebaseAndroidApp.debugSigningCertificateSha1).ToUpperInvariant()
  } |
  Select-Object -First 1

if ($null -eq $debugOauthClient -or
    [string]$debugOauthClient.client_id -ne
      [string]$policy.firebaseAndroidApp.debugAndroidOauthClientId) {
  throw 'Firebase debug OAuth continuity mismatch.'
}

$androidOauthClients = @($firebaseClient.oauth_client | Where-Object {
  [int]$_.client_type -eq 1 -and
  [string]$_.android_info.package_name -eq [string]$policy.permanentApplicationId
})
if ($androidOauthClients.Count -ne 2) {
  throw 'Combined Firebase configuration must contain exactly two Android OAuth clients for the permanent package.'
}

$restorationReceipt = Get-Content -LiteralPath $policy.firebaseAndroidApp.restorationReceiptFile -Raw | ConvertFrom-Json
if ([string]$restorationReceipt.receiptType -ne 'firebase-android-production-signing-additive-restoration' -or
    [string]$restorationReceipt.operationReference -ne [string]$policy.firebaseAndroidApp.restorationReference -or
    [string]$restorationReceipt.historicalRegistrationReference -ne [string]$policy.firebaseAndroidApp.registrationReference -or
    [string]$restorationReceipt.finalStatus -ne 'PASS_FIREBASE_PRODUCTION_SIGNING_RESTORED_HISTORICAL_AUTHORITY' -or
    [string]$restorationReceipt.combinedGoogleServicesSha256 -ne [string]$policy.firebaseAndroidApp.googleServicesSha256 -or
    [string]$restorationReceipt.combinedGoogleServicesSemanticSha256 -ne [string]$policy.firebaseAndroidApp.googleServicesSemanticSha256 -or
    [string]$restorationReceipt.debugAuthorityPreserved.sha1 -ne [string]$policy.firebaseAndroidApp.debugSigningCertificateSha1 -or
    [string]$restorationReceipt.debugAuthorityPreserved.sha256 -ne [string]$policy.firebaseAndroidApp.debugSigningCertificateSha256 -or
    [string]$restorationReceipt.debugAuthorityPreserved.oauthClientId -ne [string]$policy.firebaseAndroidApp.debugAndroidOauthClientId -or
    [string]$restorationReceipt.productionAuthorityRestored.sha1 -ne [string]$policy.firebaseAndroidApp.signingCertificateSha1 -or
    [string]$restorationReceipt.productionAuthorityRestored.sha256 -ne [string]$policy.firebaseAndroidApp.signingCertificateSha256 -or
    [string]$restorationReceipt.productionAuthorityRestored.historicalOauthClientId -ne [string]$policy.firebaseAndroidApp.androidOauthClientId -or
    -not @($restorationReceipt.productionAuthorityRestored.oauthClientIds).Contains([string]$policy.firebaseAndroidApp.androidOauthClientId) -or
    @($restorationReceipt.mutations).Count -ne 2 -or
    @($restorationReceipt.mutations | Where-Object {
      [string]$_.action -ne 'create' -or
      $_.createdByThisRun -ne $true -or
      $_.postconditionPresent -ne $true -or
      [int]$_.commandExitCode -ne 0
    }).Count -ne 0 -or
    $restorationReceipt.repositoryModified -ne $false -or
    $restorationReceipt.firebaseDeletionPerformed -ne $false -or
    $restorationReceipt.adjacentFirebaseMutationPerformed -ne $false) {
  throw 'Firebase production-signing restoration receipt mismatch.'
}
if ([string]$policy.firebaseAndroidApp.restorationReceiptSha256Representation -ne
      'UTF8_CRLF_RESTORATION_ARTIFACT' -or
    [string]$policy.firebaseAndroidApp.repositoryRestorationReceiptSha256Representation -ne
      'UTF8_LF_GIT_BLOB') {
  throw 'Firebase restoration receipt raw-hash representation policy mismatch.'
}
if ((Get-Sha256 $policy.firebaseAndroidApp.restorationReceiptFile) -ne
    ([string]$policy.firebaseAndroidApp.repositoryRestorationReceiptSha256).ToUpperInvariant()) {
  throw 'Repository Firebase restoration receipt hash mismatch.'
}
if ((Get-Utf8CrlfSha256 $policy.firebaseAndroidApp.restorationReceiptFile) -ne
    ([string]$policy.firebaseAndroidApp.restorationReceiptSha256).ToUpperInvariant()) {
  throw 'Firebase restoration receipt CRLF evidence hash mismatch.'
}

if ([string]$policy.firebaseAndroidApp.googleServicesSha256Representation -ne
      'UTF8_CRLF_RESTORATION_ARTIFACT' -or
    [string]$policy.firebaseAndroidApp.repositoryGoogleServicesSha256Representation -ne
      'UTF8_LF_GIT_BLOB') {
  throw 'google-services.json raw-hash representation policy mismatch.'
}
if ((Get-Sha256 'android/app/google-services.json') -ne
    ([string]$policy.firebaseAndroidApp.repositoryGoogleServicesSha256).ToUpperInvariant()) {
  throw 'Repository google-services.json hash mismatch.'
}
if ((Get-Utf8CrlfSha256 'android/app/google-services.json') -ne
    ([string]$policy.firebaseAndroidApp.googleServicesSha256).ToUpperInvariant()) {
  throw 'google-services.json CRLF restoration hash mismatch.'
}

$migrationReceipt = Get-Content -LiteralPath $policy.migrationPlan.receiptFile `
  -Raw | ConvertFrom-Json
if ([string]$migrationReceipt.receiptType -ne
      'android-identity-migration-plan' -or
    [string]$migrationReceipt.sourceDocumentSha256 -ne
      [string]$policy.migrationPlan.sourceDocumentSha256 -or
    [string]$policy.migrationPlan.operationalCutoverBoundary -notmatch
      'O-10/70J') {
  throw 'Android identity migration-plan boundary is incomplete.'
}

$firebaseLockfileEol = @(
  git check-attr eol -- $policy.toolchain.firebaseToolsLockfile
)
if ($LASTEXITCODE -ne 0 -or
    ($firebaseLockfileEol -join "`n") -notmatch ': eol: lf$') {
  throw 'Firebase CLI tooling lockfile must use checkout-stable LF custody.'
}
if ((Get-Sha256 $policy.toolchain.firebaseToolsLockfile) -ne
    ([string]$policy.toolchain.firebaseToolsLockfileSha256).ToUpperInvariant()) {
  throw 'Firebase CLI tooling lockfile hash mismatch.'
}

$firebasePackage = Get-Content -LiteralPath 'tooling/firebase-cli/package.json' `
  -Raw | ConvertFrom-Json
if ([string]$firebasePackage.dependencies.'firebase-tools' -ne
    [string]$policy.toolchain.firebaseToolsVersion) {
  throw 'Firebase CLI package version differs from policy.'
}

$isarReceipt = Get-Content `
  -LiteralPath $policy.toolchain.linuxIsarCoreAuthorityReceipt `
  -Raw | ConvertFrom-Json
if ([string]$isarReceipt.receiptType -ne
      'linux-x64-isar-core-authority' -or
    [string]$isarReceipt.expectedSha256 -ne
      [string]$policy.toolchain.linuxIsarCoreSha256) {
  throw 'Independent Linux Isar core authority is incomplete.'
}

$workflow = Get-Content `
  -LiteralPath '.github/workflows/production-artifact.yml' `
  -Raw
foreach ($pin in $actionPins.actions.PSObject.Properties) {
  $entry = $pin.Value
  if ([string]$entry.commitSha -notmatch '^[0-9a-fA-F]{40}$' -or
      -not $workflow.Contains(
        "$([string]$entry.repository)@$([string]$entry.commitSha)"
      )) {
    throw "Workflow action pin differs from authority: $($pin.Name)"
  }
}
foreach ($required in @(
  'permissions:'
  'contents: write'
  'group: crm3-production-build-number-${{ inputs.build_number }}'
  'CRM_DISPATCH_COMMIT_SHA: ${{ inputs.commit_sha }}'
  'CRM_DISPATCH_RELEASE_ID: ${{ inputs.release_id }}'
  'CRM_DISPATCH_RESERVATION_ID: ${{ inputs.reservation_id }}'
  'CRM_DISPATCH_BUILD_NUMBER: ${{ inputs.build_number }}'
  '[[ "$CRM_DISPATCH_COMMIT_SHA" =~ ^[0-9a-fA-F]{40}$ ]]'
  '[[ "$CRM_DISPATCH_BUILD_NUMBER" =~ ^[1-9][0-9]{0,9}$ ]]'
  'test "$CRM_DISPATCH_BUILD_NUMBER" -le 2147483647'
  '[[ "$CRM_DISPATCH_RELEASE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]'
  '[[ "$CRM_DISPATCH_RESERVATION_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]'
  'test "$GITHUB_REF" = ''refs/heads/main'''
  'test "$GITHUB_SHA" = "$CRM_DISPATCH_COMMIT_SHA"'
  "environment: $($policy.github.environmentName)"
  "runs-on: $($policy.toolchain.runnerImage)"
  "java-version: '$($policy.toolchain.javaVersion)'"
  "node-version: '$($policy.toolchain.nodeVersion)'"
  "flutter-version: '$($policy.toolchain.flutterVersion)'"
  'CRM_EXPECTED_NPM_VERSION'
  'CRM_EXPECTED_DART_VERSION'
  'CRM_RESERVATION_TAG=$($policy.versionPolicy.remoteReservationTag)'
  'CRM_BUILT_TAG=$($policy.versionPolicy.remoteBuiltTag)'
  'reserved_ref="refs/tags/${CRM_RESERVATION_TAG}"'
  'built_ref="refs/tags/${CRM_BUILT_TAG}"'
  'tooling/firebase-cli/node_modules/.bin'
  'New-ProductionArtifact.ps1'
)) {
  if (-not $workflow.Contains($required)) {
    throw "Production workflow contract is missing: $required"
  }
}
$unsafeRunBlocks = @(
  Get-YamlRunBlocks -Source $workflow |
    Where-Object {
      $_ -match '\$\{\{\s*(?:inputs|github\.event\.inputs)\.'
    }
)
if ($unsafeRunBlocks.Count -gt 0) {
  throw 'Production workflow interpolates dispatch input into script source.'
}
$builder = Get-Content `
  -LiteralPath 'tools/release/New-ProductionArtifact.ps1' `
  -Raw
if (-not $builder.Contains('$env:GITHUB_ACTIONS -ne ''true''')) {
  throw 'Production builder is missing its fail-closed GitHub Actions guard.'
}
if ($workflow -match
  'uses:\s+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]') {
  throw 'Production workflow contains a mutable action tag.'
}
$cacheLines = @(
  $workflow -split '\r?\n' |
    Where-Object { $_ -match '^[ \t]+cache:' }
)
foreach ($cacheLine in $cacheLines) {
  if ($cacheLine -notmatch
      '^[ \t]+cache:[ \t]*false[ \t]*(?:#.*)?$') {
    throw 'Production workflow may not enable dependency caches.'
  }
}

Write-Host ''
Write-Host '===== PRODUCTION RELEASE POLICY VERIFIED =====' `
  -ForegroundColor Green
Write-Host "Application ID: $($policy.permanentApplicationId)"
Write-Host "Version:        $($policy.release.versionName)+$($policy.release.buildNumber)"
Write-Host "Reservation:    $($policy.versionPolicy.remoteReservationTag)"
Write-Host 'Distribution:   NOT APPROVED'
Write-Host 'Operational package cutover remains O-10/70J.'
