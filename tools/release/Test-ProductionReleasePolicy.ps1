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
$ExpectedEnvironmentSecretNames = @(
  'CRM_ANDROID_RELEASE_KEY_ALIAS'
  'CRM_ANDROID_RELEASE_KEY_PASSWORD'
  'CRM_ANDROID_RELEASE_KEYSTORE_BASE64'
  'CRM_ANDROID_RELEASE_STORE_PASSWORD'
)
$ExpectedToolchain = [ordered]@{
  runnerImage = 'ubuntu-24.04'
  javaDistributionVersion = '21.0.11+10.0.LTS'
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
& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/Test-ProductionReleaseManifest.ps1 `
  -LedgerSelectionSelfTest
if ($LASTEXITCODE -ne 0) {
  throw 'Production release manifest runtime self-test failed.'
}

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
$environmentReviewControl = $policy.github.environmentReviewControl
if ([string]$environmentReviewControl.mode -ne
      'private-repository-plan-exception' -or
    $environmentReviewControl.requiredReviewerAvailable -ne $false -or
    $environmentReviewControl.requiredReviewerRulePresentAtApproval -ne
      $false -or
    $environmentReviewControl.manualDispatchApprovalReferenceRequired -ne
      $true -or
    [string]$environmentReviewControl.exceptionApprovalFile -notmatch
      '^release/approvals/private-repository-environment-reviewer-exception-build-[1-9][0-9]*\.json$' -or
    [string]$environmentReviewControl.exceptionApprovalSha256 -notmatch
      '^[0-9A-Fa-f]{64}$' -or
    [string]$environmentReviewControl.exceptionApprovalReference -notmatch
      '^BAF-GH-ENV-[0-9]{3}$' -or
    $environmentReviewControl.failClosedIfRequiredReviewerRuleAppears -ne
      $true) {
  throw 'Private-repository environment-review control is incomplete.'
}
$policySecretNames = @(
  $environmentReviewControl.requiredSecretNames |
    ForEach-Object { [string]$_ } |
    Sort-Object
)
if ($policySecretNames.Count -ne $ExpectedEnvironmentSecretNames.Count -or
    ($policySecretNames -join "`n") -cne
      (($ExpectedEnvironmentSecretNames | Sort-Object) -join "`n")) {
  throw 'Production environment secret-name inventory differs from authority.'
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
  [string]$environmentReviewControl.exceptionApprovalFile
  [string]$policy.signing.approvalReceiptFile
  [string]$policy.firebaseAndroidApp.registrationReceiptFile
  [string]$policy.firebaseAndroidApp.restorationReceiptFile
  [string]$policy.migrationPlan.receiptFile
  [string]$policy.versionPolicy.ledgerFile
  [string]$policy.toolchain.githubActionPinsFile
  [string]$policy.toolchain.firebaseToolsLockfile
  [string]$policy.toolchain.linuxIsarCoreAuthorityReceipt
  'tools/release/Finalize-ProductionRelease.ps1'
)
$finalizationStatus = [string]$policy.finalization.status
if ($finalizationStatus -eq 'completed-non-distributable') {
  $requiredFiles += [string]$policy.finalization.completionReceiptFile
} elseif ($finalizationStatus -eq 'pending-source-authorized') {
  $requiredFiles +=
    [string]$policy.finalization.priorCompletedBuild.completionReceiptFile
} else {
  throw 'Production policy finalization state is unsupported.'
}

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Required policy file is missing: $file"
  }
}
$finalizerTokens = $null
$finalizerParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path -LiteralPath 'tools/release/Finalize-ProductionRelease.ps1').Path,
  [ref]$finalizerTokens,
  [ref]$finalizerParseErrors
) | Out-Null
if (@($finalizerParseErrors).Count -gt 0) {
  throw 'Governed production finalizer does not parse.'
}
$finalizer = Get-Content `
  -LiteralPath 'tools/release/Finalize-ProductionRelease.ps1' `
  -Raw
foreach ($requiredFinalizerControl in @(
  '$prCommits.Count -lt 1'
  'private-repository-plan-exception'
  'github-environment-secrets.json'
  'environmentSecretValuesInspected = $false'
  'Authorized dispatcher ID:'
  'Dual production-package custody: passed'
  'git push origin "refs/tags/${builtTag}:refs/tags/${builtTag}"'
  'ConvertTo-Json -InputObject @($approvalHistory) -Depth 30'
)) {
  if (-not $finalizer.Contains($requiredFinalizerControl)) {
    throw "Governed finalizer control is missing: $requiredFinalizerControl"
  }
}
if ($finalizer.Contains('expectedCommitHeadlines')) {
  throw 'Governed finalizer retains obsolete commit-headline coupling.'
}
if ($finalizer.Contains(
    'git push origin "refs/tags/$builtTag:refs/tags/$builtTag"')) {
  throw 'Governed finalizer retains the ambiguous built-tag refspec.'
}
if ($finalizer.Contains('$approvalHistory | ConvertTo-Json')) {
  throw 'Governed finalizer can serialize an empty approval list as invalid JSON.'
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

$environmentException = Get-Content `
  -LiteralPath $environmentReviewControl.exceptionApprovalFile `
  -Raw | ConvertFrom-Json
if ((Get-Sha256 $environmentReviewControl.exceptionApprovalFile) -ne
      ([string]$environmentReviewControl.exceptionApprovalSha256).
        ToUpperInvariant() -or
    [string]$environmentException.receiptType -ne
      'private-repository-environment-reviewer-plan-exception' -or
    $environmentException.approved -ne $true -or
    [string]$environmentException.approvalReference -ne
      [string]$environmentReviewControl.exceptionApprovalReference -or
    [string]$environmentException.scope.repository -ne
      [string]$policy.github.repository -or
    [string]$environmentException.scope.repositoryVisibility -ne 'private' -or
    [string]$environmentException.scope.environmentName -ne
      [string]$policy.github.environmentName -or
    [string]$environmentException.scope.workflowPath -ne
      [string]$policy.github.workflowPath -or
    [int64]$environmentException.scope.buildNumber -ne
      [int64]$policy.release.buildNumber -or
    [string]$environmentException.scope.versionName -ne
      [string]$policy.release.versionName -or
    [string]$environmentException.scope.versionApprovalReference -ne
      [string]$versionReceipt.reference -or
    $environmentException.scope.singleBuildOnly -ne $true -or
    $environmentException.liveStateEvidence.repositoryPrivate -ne $true -or
    $environmentException.liveStateEvidence.requiredReviewerRulePresent -ne
      $false -or
    $environmentException.liveStateEvidence.secretValuesInspected -ne $false -or
    [string]$environmentException.liveStateEvidence.
      authorizedDispatcher.login -ne 'abhishekvatsa' -or
    [long]$environmentException.liveStateEvidence.
      authorizedDispatcher.id -ne 213690022 -or
    $environmentException.compensatingControls.
      manualDispatchApprovalReferenceRequired -ne $true -or
    [string]$environmentException.compensatingControls.
      dispatchApprovalReference -ne [string]$versionReceipt.reference -or
    $environmentException.compensatingControls.
      authorizedDispatcherIdentityRequired -ne $true -or
    $environmentException.compensatingControls.
      protectedEnvironmentSecretsRequired -ne $true -or
    $environmentException.compensatingControls.
      atomicOneTimeRemoteReservationRequired -ne $true -or
    $environmentException.compensatingControls.
      independentPackageVerificationRequired -ne $true -or
    $environmentException.compensatingControls.
      dualCustodyRequiredBeforeBuiltTag -ne $true -or
    $environmentException.compensatingControls.distributionApproved -ne
      $false -or
    $environmentException.compensatingControls.firebaseDeploymentApproved -ne
      $false -or
    $environmentException.planConstraintEvidence.
      publicRepositoryConversionApproved -ne $false) {
  throw 'Private-repository environment-review exception differs from policy.'
}
$exceptionSecretNames = @(
  $environmentException.liveStateEvidence.requiredEnvironmentSecretNames |
    ForEach-Object { [string]$_ } |
    Sort-Object
)
if (($exceptionSecretNames -join "`n") -cne
    ($policySecretNames -join "`n")) {
  throw 'Environment exception secret-name inventory differs from policy.'
}

$versionSource = Get-Content `
  -LiteralPath $policy.versionPolicy.sourceDocumentFile `
  -Raw | ConvertFrom-Json
$consumedDisposition = [string]$versionSource.consumedBuild.disposition
$consumedAuthorityValid = $false
if ([string]$versionSource.consumedBuild.conclusion -eq 'failure' -and
    $consumedDisposition -in @('', 'failed-build') -and
    $versionSource.consumedBuild.artifactConstructed -eq $false -and
    $versionSource.consumedBuild.artifactUploaded -eq $false -and
    $versionSource.consumedBuild.remoteBuiltTagCreated -eq $false) {
  $consumedAuthorityValid = $true
}
if ([string]$versionSource.consumedBuild.conclusion -eq 'success' -and
    $consumedDisposition -eq 'successful-build-finalization-blocked' -and
    $versionSource.consumedBuild.independentPackageVerificationCompleted -eq
      $true -and
    $versionSource.consumedBuild.artifactConstructed -eq $true -and
    $versionSource.consumedBuild.governedPackageConstructed -eq $true -and
    $versionSource.consumedBuild.artifactUploaded -eq $true -and
    [string]$versionSource.consumedBuild.governedPackageSha256 -match
      '^[0-9A-Fa-f]{64}$' -and
    [string]$versionSource.consumedBuild.governedPackageSidecarSha256 -match
      '^[0-9A-Fa-f]{64}$' -and
    [string]$versionSource.consumedBuild.githubArtifactDigest -match
      '^sha256:[0-9A-Fa-f]{64}$' -and
    $versionSource.consumedBuild.closureFinalizationCompleted -eq $false -and
    $versionSource.consumedBuild.dualCustodyCompleted -eq $false -and
    $versionSource.consumedBuild.remoteBuiltTagCreated -eq $false) {
  $consumedAuthorityValid = $true
}
if ([string]$versionSource.consumedBuild.conclusion -eq 'success' -and
    $consumedDisposition -eq
      'successful-build-finalized-non-distributable' -and
    $versionSource.consumedBuild.independentPackageVerificationCompleted -eq
      $true -and
    $versionSource.consumedBuild.artifactConstructed -eq $true -and
    $versionSource.consumedBuild.governedPackageConstructed -eq $true -and
    $versionSource.consumedBuild.artifactUploaded -eq $true -and
    [string]$versionSource.consumedBuild.governedPackageSha256 -match
      '^[0-9A-Fa-f]{64}$' -and
    [string]$versionSource.consumedBuild.githubArtifactDigest -match
      '^sha256:[0-9A-Fa-f]{64}$' -and
    [string]$versionSource.consumedBuild.completionReceiptSha256 -match
      '^[0-9A-Fa-f]{64}$' -and
    $versionSource.consumedBuild.closureFinalizationCompleted -eq $true -and
    $versionSource.consumedBuild.dualCustodyCompleted -eq $true -and
    $versionSource.consumedBuild.remoteBuiltTagCreated -eq $true -and
    $versionSource.consumedBuild.firebaseBackendDeploymentPerformed -eq
      $false -and
    $versionSource.consumedBuild.controlledPilotApproved -eq $false -and
    $versionSource.consumedBuild.unrestrictedPlantReleaseApproved -eq
      $false -and
    $versionSource.consumedBuild.distributionPerformed -eq $false) {
  $consumedCompletionPath =
    [string]$versionSource.consumedBuild.completionReceiptFile
  if ((Get-Sha256 $consumedCompletionPath) -eq
      ([string]$versionSource.consumedBuild.completionReceiptSha256).
        ToUpperInvariant()) {
    $consumedAuthorityValid = $true
  }
}
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
    -not $consumedAuthorityValid -or
    [string]$versionSource.nextBuild.remoteReservationTag -ne
      [string]$policy.versionPolicy.remoteReservationTag -or
    [string]$versionSource.nextBuild.remoteBuiltTag -ne
      [string]$policy.versionPolicy.remoteBuiltTag -or
    [string]$versionReceipt.reference -ne
      [string]$versionSource.approvalReference -or
    $versionSource.controls.fullPolicyAndAuthorityPreflightBeforeReservation -ne
      $true -or
    $versionSource.controls.
      androidDependencyConfigurationPreflightBeforeReservation -ne $true -or
    $versionSource.controls.
      androidReleaseSourceCompilationBeforeReservation -ne $true -or
    $versionSource.controls.androidPrPackagingProofRequired -ne $true -or
    $versionSource.controls.tokenRaceRemediationRequired -ne $true -or
    $versionSource.controls.
      privateRepositoryEnvironmentReviewerExceptionApproved -ne $true -or
    [string]$versionSource.controls.environmentExceptionApprovalReference -ne
      [string]$environmentReviewControl.exceptionApprovalReference -or
    $versionSource.controls.manualDispatchApprovalReferenceRequired -ne
      $true -or
    $versionSource.controls.environmentSecretNameInventoryRequired -ne
      $true -or
    $versionSource.controls.governedFinalizerMustMatchCurrentPullRequest -ne
      $true -or
    $versionSource.controls.failedOrWithdrawnBuildConsumesNumber -ne $true -or
    [int64]$versionSource.requiredSource.
      tokenRaceRemediationPullRequest -ne 77 -or
    [string]$versionSource.requiredSource.
      tokenRaceRemediationMergeCommit -notmatch '^[0-9a-f]{40}$' -or
    $versionSource.requiredSource.
      tokenRaceRemediationMustBeAncestorOfDispatchCommit -ne $true -or
    [string]$versionSource.requiredSource.c03ClosureMergeCommit -notmatch
      '^[0-9a-f]{40}$' -or
    $versionSource.requiredSource.androidPrPackagingProofRequired -ne $true -or
    $versionSource.distributionApproved -ne $false -or
    $versionSource.unrestrictedPlantReleaseApproved -ne $false) {
  throw 'Governed build-number rollover authority is incomplete.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.tokenRaceRemediationMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the token-race remediation.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.c03ClosureMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the C-03 Android packaging closure.'
}

$completionReceiptPath = $null
$completionReceipt = $null
if ($finalizationStatus -eq 'completed-non-distributable') {
  $completionReceiptPath =
    [string]$policy.finalization.completionReceiptFile
  $completionReceipt =
    Get-Content -LiteralPath $completionReceiptPath -Raw |
      ConvertFrom-Json
  $recoveryIncident = $completionReceipt.recoveryIncident
  $recoveryValid = $false
  if ($recoveryIncident.occurred -eq $true -and
      [string]$recoveryIncident.failureBoundary -eq
        'remote-built-tag-push' -and
      [string]$recoveryIncident.sourceExpression -eq
        'git push origin "refs/tags/$builtTag:refs/tags/$builtTag"' -and
      [string]$recoveryIncident.sourceCorrection.correctedExpression -eq
        'git push origin "refs/tags/${builtTag}:refs/tags/${builtTag}"' -and
      $recoveryIncident.stateBeforeRecovery.rebuildPerformed -eq $false -and
      $recoveryIncident.stateBeforeRecovery.workflowRerunPerformed -eq
        $false -and
      $recoveryIncident.recovery.forceUsed -eq $false -and
      $recoveryIncident.verification.closurePassed -eq $true) {
    $recoveryValid = $true
  }
  if ($recoveryIncident.occurred -eq $false -and
      $recoveryIncident.PSObject.Properties.Name -contains 'forceUsed' -and
      $recoveryIncident.forceUsed -eq $false -and
      $recoveryIncident.PSObject.Properties.Name -notcontains
        'sourceExpression') {
    $recoveryValid = $true
  }
  if ((Get-Sha256 $completionReceiptPath) -ne
      ([string]$policy.finalization.completionReceiptSha256).
        ToUpperInvariant() -or
      [string]$completionReceipt.evidenceType -ne
        'production-build-finalization-closure' -or
      $completionReceipt.schemaVersion -ne 1 -or
      [string]$completionReceipt.status -ne 'passed-non-distributable' -or
      [int64]$completionReceipt.release.buildNumber -ne
        [int64]$policy.release.buildNumber -or
      [string]$completionReceipt.release.releaseId -ne
        [string]$policy.release.releaseId -or
      [string]$completionReceipt.release.applicationId -ne
        [string]$policy.permanentApplicationId -or
      [string]$completionReceipt.sourceAuthority.commit -ne
        [string]$policy.finalization.sourceCommit -or
      [int64]$completionReceipt.workflow.runId -ne
        [int64]$policy.finalization.githubRunId -or
      [string]$completionReceipt.workflow.conclusion -ne 'success' -or
      [string]$completionReceipt.workflow.actor -ne 'abhishekvatsa' -or
      [long]$completionReceipt.workflow.actorId -ne 213690022 -or
      $completionReceipt.workflow.secretValuesInspected -ne $false -or
      [string]$completionReceipt.governedPackage.sha256 -ne
        [string]$policy.finalization.governedPackageSha256 -or
      $completionReceipt.governedPackage.independentVerificationCompleted -ne
        $true -or
      [string]$completionReceipt.remoteAuthority.reservationTag -ne
        [string]$policy.versionPolicy.remoteReservationTag -or
      [string]$completionReceipt.remoteAuthority.reservationTagObjectSha -ne
        [string]$policy.finalization.remoteReservationTagObject -or
      [string]$completionReceipt.remoteAuthority.builtTag -ne
        [string]$policy.versionPolicy.remoteBuiltTag -or
      [string]$completionReceipt.remoteAuthority.builtTagObjectSha -ne
        [string]$policy.finalization.remoteBuiltTagObject -or
      [string]$completionReceipt.remoteAuthority.builtTagCommit -ne
        [string]$policy.finalization.sourceCommit -or
      [string]$completionReceipt.closure.closurePackageSha256 -ne
        [string]$policy.finalization.closurePackageSha256 -or
      [string]$completionReceipt.closure.custodyRecordSha256 -ne
        [string]$policy.finalization.custodyRecordSha256 -or
      $completionReceipt.dualCustody.distinctVolumes -ne $true -or
      $completionReceipt.dualCustody.allFileHashesMatched -ne $true -or
      $policy.finalization.dualCustodyCompleted -ne $true -or
      -not $recoveryValid -or
      $policy.finalization.firebaseBackendDeploymentPerformed -ne $false -or
      $policy.finalization.controlledPilotApproved -ne $false -or
      $policy.finalization.unrestrictedPlantReleaseApproved -ne $false -or
      $completionReceipt.releaseBoundary.firebaseBackendDeploymentPerformed -ne
        $false -or
      $completionReceipt.releaseBoundary.controlledPilotApproved -ne $false -or
      $completionReceipt.releaseBoundary.unrestrictedPlantReleaseApproved -ne
        $false -or
      $completionReceipt.releaseBoundary.distributionPerformed -ne $false) {
    throw 'Finalization receipt differs from policy or release boundary.'
  }
} else {
  $prior = $policy.finalization.priorCompletedBuild
  if ([int64]$prior.buildNumber -ne
        [int64]$versionSource.consumedBuild.buildNumber -or
      [string]$prior.completionReceiptFile -ne
        [string]$versionSource.consumedBuild.completionReceiptFile -or
      [string]$prior.completionReceiptSha256 -ne
        [string]$versionSource.consumedBuild.completionReceiptSha256 -or
      [string]$prior.sourceCommit -ne
        [string]$versionSource.consumedBuild.remoteBuiltCommit -or
      [int64]$prior.githubRunId -ne
        [int64]$versionSource.consumedBuild.githubRunId -or
      [string]$prior.remoteBuiltTag -ne
        [string]$versionSource.consumedBuild.remoteBuiltTag -or
      [string]$prior.governedPackageSha256 -ne
        [string]$versionSource.consumedBuild.governedPackageSha256 -or
      $policy.finalization.dualCustodyCompleted -ne $false -or
      $policy.finalization.firebaseBackendDeploymentPerformed -ne $false -or
      $policy.finalization.controlledPilotApproved -ne $false -or
      $policy.finalization.unrestrictedPlantReleaseApproved -ne $false) {
    throw 'Pending finalization does not preserve the consumed build boundary.'
  }
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
$baseReservationInvalid =
  [string]$reservation.reservationId -ne
    [string]$policy.versionPolicy.reservationId -or
  [string]$reservation.releaseId -ne [string]$policy.release.releaseId -or
  [string]$reservation.versionName -ne [string]$policy.release.versionName -or
  [string]$reservation.versionApprovalReference -ne
    [string]$versionReceipt.reference -or
  [string]$reservation.versionApprovalDocumentSha256 -ne
    [string]$policy.versionPolicy.sourceDocumentSha256 -or
  [string]$reservation.remoteReservationTag -ne
    [string]$policy.versionPolicy.remoteReservationTag -or
  [string]$reservation.remoteBuiltTag -ne
    [string]$policy.versionPolicy.remoteBuiltTag -or
  $reservation.failedOrWithdrawnBuildConsumesNumber -ne $true

if ($finalizationStatus -eq 'pending-source-authorized') {
  $remoteEvidenceFields = @(
    'githubRunId'
    'remoteReservationTagObject'
    'remoteReservationCommit'
    'remoteBuiltTagObject'
    'remoteBuiltCommit'
    'githubArtifactDigest'
    'governedPackageSha256'
    'completionReceiptFile'
  )
  $hasRemoteEvidence = @(
    $remoteEvidenceFields |
      Where-Object { $reservation.PSObject.Properties.Name -contains $_ }
  ).Count -gt 0
  if ($baseReservationInvalid -or
      [string]$reservation.status -ne
        'source-reserved-awaiting-remote-consumption' -or
      $hasRemoteEvidence) {
    throw 'Pending build-number evidence differs from source authority.'
  }
} else {
  $expectedRecoveryRequired =
    [bool]$completionReceipt.recoveryIncident.occurred
  $expectedRecoveryForceUsed =
    if ($expectedRecoveryRequired) {
      [bool]$completionReceipt.recoveryIncident.recovery.forceUsed
    } else {
      [bool]$completionReceipt.recoveryIncident.forceUsed
    }
  if ($baseReservationInvalid -or
    [string]$reservation.status -ne
      'remote-consumed-artifact-built-finalized-non-distributable' -or
    [int64]$reservation.githubRunId -ne
      [int64]$completionReceipt.workflow.runId -or
    [string]$reservation.remoteReservationTagObject -ne
      [string]$completionReceipt.remoteAuthority.reservationTagObjectSha -or
    [string]$reservation.remoteReservationCommit -ne
      [string]$completionReceipt.remoteAuthority.reservationTagCommit -or
    [string]$reservation.remoteBuiltTagObject -ne
      [string]$completionReceipt.remoteAuthority.builtTagObjectSha -or
    [string]$reservation.remoteBuiltCommit -ne
      [string]$completionReceipt.remoteAuthority.builtTagCommit -or
    [string]$reservation.githubArtifactDigest -ne
      [string]$completionReceipt.githubArtifact.digest -or
    [string]$reservation.governedPackageSha256 -ne
      [string]$completionReceipt.governedPackage.sha256 -or
    [string]$reservation.closurePackageSha256 -ne
      [string]$completionReceipt.closure.closurePackageSha256 -or
    [string]$reservation.custodyRecordSha256 -ne
      [string]$completionReceipt.closure.custodyRecordSha256 -or
    [string]$reservation.completionReceiptFile -ne
      $completionReceiptPath -or
    [string]$reservation.completionReceiptSha256 -ne
      [string]$policy.finalization.completionReceiptSha256 -or
    $reservation.closureFinalizationCompleted -ne $true -or
    $reservation.dualCustodyCompleted -ne $true -or
    $reservation.remoteBuiltTagCreated -ne $true -or
    $reservation.remoteTagPushRecoveryRequired -ne
      $expectedRecoveryRequired -or
    $reservation.remoteTagPushRecoveryForceUsed -ne
      $expectedRecoveryForceUsed -or
    $reservation.firebaseBackendDeploymentPerformed -ne $false -or
    $reservation.controlledPilotApproved -ne $false -or
    $reservation.unrestrictedPlantReleaseApproved -ne $false -or
    $reservation.distributionPerformed -ne $false) {
    throw 'Finalized build-number evidence differs from policy.'
  }
}

$consumedMatches = @(
  $ledger.entries |
    Where-Object {
      [int64]$_.buildNumber -eq
        [int64]$versionSource.consumedBuild.buildNumber
    }
)
$consumedLedgerValid = $false
if ($consumedMatches.Count -eq 1 -and
    [int64]$consumedMatches[0].githubRunId -ne
      [int64]$versionSource.consumedBuild.githubRunId) {
  throw 'Consumed build run differs from rollover authority.'
}
if ($consumedMatches.Count -eq 1 -and
    $consumedMatches[0].failedOrWithdrawnBuildConsumesNumber -eq $true -and
    [string]$versionSource.consumedBuild.conclusion -eq 'failure' -and
    [string]$consumedMatches[0].status -eq
      'remote-consumed-build-failed' -and
    $consumedMatches[0].artifactConstructed -eq $false -and
    $consumedMatches[0].artifactUploaded -eq $false -and
    $consumedMatches[0].remoteBuiltTagCreated -eq $false) {
  $consumedLedgerValid = $true
}
if ($consumedMatches.Count -eq 1 -and
    $consumedMatches[0].failedOrWithdrawnBuildConsumesNumber -eq $true -and
    [string]$versionSource.consumedBuild.disposition -eq
      'successful-build-finalization-blocked' -and
    [string]$consumedMatches[0].status -eq
      'remote-consumed-artifact-built-finalization-blocked' -and
    [string]$consumedMatches[0].disposition -eq
      [string]$versionSource.consumedBuild.disposition -and
    $consumedMatches[0].independentPackageVerificationCompleted -eq $true -and
    $consumedMatches[0].artifactConstructed -eq $true -and
    $consumedMatches[0].artifactUploaded -eq $true -and
    [string]$consumedMatches[0].governedPackageSha256 -eq
      [string]$versionSource.consumedBuild.governedPackageSha256 -and
    [string]$consumedMatches[0].githubArtifactDigest -eq
      [string]$versionSource.consumedBuild.githubArtifactDigest -and
    $consumedMatches[0].closureFinalizationCompleted -eq $false -and
    $consumedMatches[0].dualCustodyCompleted -eq $false -and
    $consumedMatches[0].remoteBuiltTagCreated -eq $false) {
  $consumedLedgerValid = $true
}
if ($consumedMatches.Count -eq 1 -and
    $consumedMatches[0].failedOrWithdrawnBuildConsumesNumber -eq $true -and
    [string]$versionSource.consumedBuild.disposition -eq
      'successful-build-finalized-non-distributable' -and
    [string]$consumedMatches[0].status -eq
      'remote-consumed-artifact-built-finalized-non-distributable' -and
    [string]$consumedMatches[0].disposition -eq
      [string]$versionSource.consumedBuild.disposition -and
    [string]$consumedMatches[0].remoteReservationTagObject -eq
      [string]$versionSource.consumedBuild.remoteReservationTagObject -and
    [string]$consumedMatches[0].remoteReservationCommit -eq
      [string]$versionSource.consumedBuild.remoteReservationCommit -and
    [string]$consumedMatches[0].remoteBuiltTagObject -eq
      [string]$versionSource.consumedBuild.remoteBuiltTagObject -and
    [string]$consumedMatches[0].remoteBuiltCommit -eq
      [string]$versionSource.consumedBuild.remoteBuiltCommit -and
    [string]$consumedMatches[0].governedPackageSha256 -eq
      [string]$versionSource.consumedBuild.governedPackageSha256 -and
    [string]$consumedMatches[0].completionReceiptSha256 -eq
      [string]$versionSource.consumedBuild.completionReceiptSha256 -and
    $consumedMatches[0].closureFinalizationCompleted -eq $true -and
    $consumedMatches[0].dualCustodyCompleted -eq $true -and
    $consumedMatches[0].remoteBuiltTagCreated -eq $true -and
    $consumedMatches[0].firebaseBackendDeploymentPerformed -eq $false -and
    $consumedMatches[0].controlledPilotApproved -eq $false -and
    $consumedMatches[0].unrestrictedPlantReleaseApproved -eq $false -and
    $consumedMatches[0].distributionPerformed -eq $false) {
  $consumedLedgerValid = $true
}
if (-not $consumedLedgerValid) {
  throw 'Consumed build evidence differs from rollover authority.'
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
  'compileSdk = 36'
  'isDebuggable = false'
)) {
  if (-not $gradle.Contains($required)) {
    throw "Gradle production contract is missing: $required"
  }
}

$rootGradle = Get-Content -LiteralPath 'android/build.gradle.kts' -Raw
foreach ($required in @(
  'name == "isar_flutter_libs"'
  'pluginManager.withPlugin("com.android.library")'
  'extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>'
  'finalizeDsl { libraryExtension ->'
  'if (libraryExtension.namespace == null)'
  'libraryExtension.namespace = "dev.isar.isar_flutter_libs"'
  'libraryExtension.compileSdk = 36'
)) {
  if (-not $rootGradle.Contains($required)) {
    throw "Isar AGP namespace compatibility contract is missing: $required"
  }
}

$pubspecLock = Get-Content -LiteralPath 'pubspec.lock' -Raw
if ($pubspecLock -notmatch
    '(?ms)^\s{2}isar_flutter_libs:\s+.*?^\s{4}version:\s+"3\.1\.0\+1"\s*$') {
  throw 'Isar AGP namespace compatibility is not bound to the locked package.'
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
  'CRM_DISPATCH_APPROVAL_REFERENCE: ${{ inputs.approval_reference }}'
  'CRM_DISPATCH_BUILD_NUMBER: ${{ inputs.build_number }}'
  'CRM_DISPATCH_ACTOR: ${{ github.actor }}'
  'CRM_DISPATCH_ACTOR_ID: ${{ github.actor_id }}'
  'CRM_TRIGGERING_ACTOR: ${{ github.triggering_actor }}'
  '[[ "$CRM_DISPATCH_COMMIT_SHA" =~ ^[0-9a-fA-F]{40}$ ]]'
  '[[ "$CRM_DISPATCH_BUILD_NUMBER" =~ ^[1-9][0-9]{0,9}$ ]]'
  'test "$CRM_DISPATCH_BUILD_NUMBER" -le 2147483647'
  '[[ "$CRM_DISPATCH_RELEASE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]'
  '[[ "$CRM_DISPATCH_RESERVATION_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]'
  '[[ "$CRM_DISPATCH_APPROVAL_REFERENCE" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]'
  'Workflow dispatcher identity differs from approved authority.'
  'test "$GITHUB_REF" = ''refs/heads/main'''
  'test "$GITHUB_SHA" = "$CRM_DISPATCH_COMMIT_SHA"'
  'GH_TOKEN: ${{ github.token }}'
  'Environment-review exception requires a private repository.'
  'A required-reviewer rule now exists; exception mode is invalid.'
  "environment: $($policy.github.environmentName)"
  "runs-on: $($policy.toolchain.runnerImage)"
  "java-version: '$($policy.toolchain.javaDistributionVersion)'"
  "node-version: '$($policy.toolchain.nodeVersion)'"
  "flutter-version: '$($policy.toolchain.flutterVersion)'"
  'CRM_EXPECTED_NPM_VERSION'
  'CRM_EXPECTED_DART_VERSION'
  'CRM_RESERVATION_TAG=$($policy.versionPolicy.remoteReservationTag)'
  'CRM_BUILT_TAG=$($policy.versionPolicy.remoteBuiltTag)'
  'reserved_ref="refs/tags/${CRM_RESERVATION_TAG}"'
  'built_ref="refs/tags/${CRM_BUILT_TAG}"'
  'tooling/firebase-cli/node_modules/.bin'
  'Prove Android dependency configuration before reservation'
  'Prove production environment secrets before reservation'
  'crm3-android-preflight-placeholder.p12'
  './gradlew :app:assembleRelease --dry-run --no-daemon --stacktrace'
  './gradlew :app:compileReleaseSources --no-daemon --stacktrace'
  'New-ProductionArtifact.ps1'
  '-ExpectedApprovalReference $env:CRM_DISPATCH_APPROVAL_REFERENCE'
)) {
  if (-not $workflow.Contains($required)) {
    throw "Production workflow contract is missing: $required"
  }
}
$dependencyRestoreIndex =
  $workflow.IndexOf('- name: Restore locked dependencies and Firebase CLI')
$androidPreflightIndex =
  $workflow.IndexOf(
    '- name: Prove Android dependency configuration before reservation'
  )
$environmentSecretPreflightIndex =
  $workflow.IndexOf(
    '- name: Prove production environment secrets before reservation'
  )
$reservationIndex =
  $workflow.IndexOf('- name: Atomically consume the build number')
$productionBuildIndex =
  $workflow.IndexOf('- name: Build once and independently verify')
if ($dependencyRestoreIndex -lt 0 -or
    $androidPreflightIndex -le $dependencyRestoreIndex -or
    $environmentSecretPreflightIndex -le $androidPreflightIndex -or
    $reservationIndex -le $environmentSecretPreflightIndex -or
    $productionBuildIndex -le $reservationIndex) {
  throw 'Android preflight, reservation and production build order is invalid.'
}
$androidPreflightSection = $workflow.Substring(
  $androidPreflightIndex,
  $environmentSecretPreflightIndex - $androidPreflightIndex
)
if ($androidPreflightSection -notmatch
    '(?m)^\s+\./gradlew :app:compileReleaseSources ' +
      '--no-daemon --stacktrace\r?\n\s+\)\s*$') {
  throw 'Android preflight subshell is not closed before secret preflight.'
}
$secretPreflightBlocks = @(
  Get-YamlRunBlocks -Source $workflow |
    Where-Object {
      $_.Contains('Production signing environment is missing secret')
    }
)
if ($secretPreflightBlocks.Count -ne 1) {
  throw 'Production environment secret preflight block is not singular.'
}
$secretPreflightTokens = $null
$secretPreflightParseErrors = $null
[Management.Automation.Language.Parser]::ParseInput(
  $secretPreflightBlocks[0],
  [ref]$secretPreflightTokens,
  [ref]$secretPreflightParseErrors
) | Out-Null
if (@($secretPreflightParseErrors).Count -gt 0) {
  throw 'Production environment secret preflight does not parse.'
}
$powerShellRunBlocks = @(
  Get-YamlRunBlocks -Source $workflow |
    Where-Object { $_.Contains('$ErrorActionPreference') }
)
if ($powerShellRunBlocks.Count -lt 1) {
  throw 'Production workflow has no discoverable PowerShell run blocks.'
}
foreach ($powerShellRunBlock in $powerShellRunBlocks) {
  $powerShellRunTokens = $null
  $powerShellRunParseErrors = $null
  [Management.Automation.Language.Parser]::ParseInput(
    $powerShellRunBlock,
    [ref]$powerShellRunTokens,
    [ref]$powerShellRunParseErrors
  ) | Out-Null
  if (@($powerShellRunParseErrors).Count -gt 0) {
    throw 'A production workflow PowerShell run block does not parse.'
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
foreach ($requiredBuilderControl in @(
  'ExpectedApprovalReference'
  'dispatchApprovalReference = $ExpectedApprovalReference'
  'actor = [string]$env:GITHUB_ACTOR'
  'actorId = [string]$env:GITHUB_ACTOR_ID'
  'triggeringActor = [string]$env:GITHUB_TRIGGERING_ACTOR'
  'environmentReviewControl ='
  'tools/release/Finalize-ProductionRelease.ps1'
)) {
  if (-not $builder.Contains($requiredBuilderControl)) {
    throw "Production builder control is missing: $requiredBuilderControl"
  }
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
