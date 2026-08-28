#requires -Version 7.0
<#
.SYNOPSIS
Verifies the source-controlled CRM-III BAF Ops production-release policy.

.DESCRIPTION
This verifier checks identity, version, source reservation, signing, Firebase
registration, migration-plan boundary, independently approved Linux Isar core,
locked Firebase CLI, action pins and exact sealed-pilot distribution boundaries.
#>

[CmdletBinding()]
param(
  [string]$PolicyPath = 'release/production-release-policy.json',
  [string]$AuthorityPath = 'release/backend-authority.prod.json',
  [string]$RepositoryRoot = (Get-Location).Path,
  [switch]$RequireArtifactConstructionAuthority
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedRepositorySlug = 'abhishekvatsa/crm3_baf_ops'
$ExpectedWorkflowPath = '.github/workflows/production-artifact.yml'
$ExpectedEnvironmentName = 'crm3-baf-ops-production-signing'
$ExpectedRequiredReviewerLogin = 'abhishekvatsa'
$ExpectedRequiredReviewerId = 213690022
$ExpectedIntegratedSuccessorCommit =
  '28cb22064511c1abcb76759cbb302a303427f46f'
$ExpectedIntegratedSuccessorTree =
  '70cc865e7636de0f3906565707b1d85e69a3e0db'
$ExpectedIntegratedSuccessorPostMergeRunId = 31512254539
$ExpectedStartupRemediationCommit =
  '1772fe1cf34c649c6a29d375c77b75e985b6c2f0'
$ExpectedStartupRemediationTree =
  '59c6371680ed0bf444bdbf1f1623413b14180fb9'
$ExpectedStartupRemediationPostMergeRunId = 31538989781
$ExpectedEnvironmentAuthorityCommit =
  'e6bfa327466ffa99da9519846db7f83401c86c7b'
$ExpectedEnvironmentAuthorityTree =
  '5563c0ba7db287daed4f59d2769622655a5a0814'
$ExpectedEnvironmentAuthorityPostMergeRunId = 31544517283
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
  nodeVersion = '22.23.1'
  npmVersion = '10.9.8'
  flutterVersion = '3.44.0'
  dartVersion = '3.12.0'
  firebaseToolsVersion = '15.22.4'
}
$ApprovedArtifactExactSourcePaths = @(
  '.firebaserc'
  '.github/workflows/production-artifact.yml'
  '.metadata'
  '.npmrc'
  'analysis_options.yaml'
  'android'
  'assets'
  'firebase.json'
  'firestore.indexes.json'
  'firestore.rules'
  'functions'
  'integration_test'
  'jest.config.js'
  'lib'
  'package.json'
  'package-lock.json'
  'pubspec.lock'
  'release/approvals/linux-isar-core-authority.json'
  'release/github-actions-pins.json'
  'release_gate.ps1'
  'test'
  'tool'
  'tooling'
  'tools/release'
)

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

function Get-GitTreeObjectId {
  param(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
  )

  $treeOutput = @(
    git rev-parse --verify ("{0}:{1}" -f $Commit, $Path)
  )
  if ($LASTEXITCODE -ne 0 -or $treeOutput.Count -ne 1) {
    throw "Unable to resolve Git tree for $Commit`:$Path."
  }

  $tree = $treeOutput[0].Trim().ToLowerInvariant()
  if ($tree -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
    throw "Invalid Git tree identity for $Commit`:$Path."
  }
  $tree
}

function Get-GitFileText {
  param(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
  )

  $output = @(git show ("{0}:{1}" -f $Commit, $Path))
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read Git file for $Commit`:$Path."
  }
  $output -join "`n"
}

function Get-NormalizedArtifactPubspec {
  param(
    [Parameter(Mandatory)][string]$Text,
    [string]$ExpectedVersion,
    [switch]$RequireExpectedVersion
  )

  $pattern = '(?m)^version:[ \t]*(\S+)[ \t]*$'
  $matches = [regex]::Matches($Text, $pattern)
  if ($matches.Count -ne 1) {
    throw 'Artifact pubspec must contain exactly one version declaration.'
  }
  $version = $matches[0].Groups[1].Value
  if ($RequireExpectedVersion -and $version -cne $ExpectedVersion) {
    return $null
  }
  [regex]::Replace(
    $Text,
    $pattern,
    'version: <governed-artifact-version>'
  )
}

function Get-ApprovedArtifactSourceStatus {
  param(
    [Parameter(Mandatory)][string]$BaselineCommit,
    [Parameter(Mandatory)][string]$CurrentCommit,
    [Parameter(Mandatory)][string]$ExpectedPackageVersion
  )

  $driftedPaths = [Collections.Generic.List[string]]::new()
  foreach ($path in $ApprovedArtifactExactSourcePaths) {
    $baselineObject = Get-GitTreeObjectId `
      -Commit $BaselineCommit `
      -Path $path
    $currentObject = Get-GitTreeObjectId `
      -Commit $CurrentCommit `
      -Path $path
    if ($baselineObject -cne $currentObject) {
      $driftedPaths.Add($path)
    }
  }

  $baselinePubspec = Get-NormalizedArtifactPubspec `
    -Text (Get-GitFileText -Commit $BaselineCommit -Path 'pubspec.yaml')
  $currentPubspec = Get-NormalizedArtifactPubspec `
    -Text (Get-GitFileText -Commit $CurrentCommit -Path 'pubspec.yaml') `
    -ExpectedVersion $ExpectedPackageVersion `
    -RequireExpectedVersion
  if ($null -eq $currentPubspec -or
      $baselinePubspec -cne $currentPubspec) {
    $driftedPaths.Add('pubspec.yaml')
  }

  [pscustomobject]@{
    matches = $driftedPaths.Count -eq 0
    driftedPaths = @($driftedPaths)
  }
}

function Get-ArtifactConstructionAuthority {
  param(
    [Parameter(Mandatory)][bool]$PendingSourceAuthorization,
    [Parameter(Mandatory)][bool]$BackendMatchesDeployed,
    [Parameter(Mandatory)][bool]$ArtifactSourceMatchesApproval
  )

  $PendingSourceAuthorization -and
    $BackendMatchesDeployed -and
    $ArtifactSourceMatchesApproval
}

function Test-ArtifactConstructionAuthorityClassifier {
  foreach ($pending in @($false, $true)) {
    foreach ($backend in @($false, $true)) {
      foreach ($source in @($false, $true)) {
        $actual = Get-ArtifactConstructionAuthority `
          -PendingSourceAuthorization $pending `
          -BackendMatchesDeployed $backend `
          -ArtifactSourceMatchesApproval $source
        $expected = $pending -and $backend -and $source
        if ($actual -ne $expected) {
          throw 'Artifact-construction authority classifier self-test failed.'
        }
      }
    }
  }
}

function Get-FunctionFleetDeploymentStatus {
  param(
    [Parameter(Mandatory)][string]$DeployedTree,
    [Parameter(Mandatory)][string]$CurrentTree
  )

  $treePattern = '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$'
  if ($DeployedTree -notmatch $treePattern -or
      $CurrentTree -notmatch $treePattern) {
    throw 'Function fleet tree identity is invalid.'
  }
  if ($DeployedTree.ToLowerInvariant() -ceq
      $CurrentTree.ToLowerInvariant()) {
    return 'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK'
  }
  'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
}

function Test-FunctionFleetDeploymentStatusClassifier {
  $exactTree = 'a' * 40
  $changedTree = 'b' * 40
  if ((Get-FunctionFleetDeploymentStatus `
        -DeployedTree $exactTree `
        -CurrentTree $exactTree) -ne
      'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK' -or
      (Get-FunctionFleetDeploymentStatus `
        -DeployedTree $exactTree `
        -CurrentTree $changedTree) -ne
      'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT') {
    throw 'Function deployment-state classifier self-test failed.'
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
Test-FunctionFleetDeploymentStatusClassifier
Test-ArtifactConstructionAuthorityClassifier
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
      'public-repository-required-reviewer' -or
    [string]$environmentReviewControl.repositoryVisibility -ne 'public' -or
    $environmentReviewControl.requiredReviewerAvailable -ne $true -or
    $environmentReviewControl.requiredReviewerRulePresentAtApproval -ne
      $true -or
    [string]$environmentReviewControl.requiredReviewerLogin -ne
      $ExpectedRequiredReviewerLogin -or
    [long]$environmentReviewControl.requiredReviewerId -ne
      $ExpectedRequiredReviewerId -or
    $environmentReviewControl.preventSelfReview -ne $false -or
    $environmentReviewControl.adminBypassAllowed -ne $false -or
    $environmentReviewControl.deploymentBranchPolicy.protectedBranches -ne
      $false -or
    $environmentReviewControl.deploymentBranchPolicy.customBranchPolicies -ne
      $true -or
    @($environmentReviewControl.deploymentBranchPolicy.allowedBranches).Count -ne
      1 -or
    [string]$environmentReviewControl.deploymentBranchPolicy.
      allowedBranches[0].name -ne 'main' -or
    [string]$environmentReviewControl.deploymentBranchPolicy.
      allowedBranches[0].type -ne 'branch' -or
    $environmentReviewControl.manualDispatchApprovalReferenceRequired -ne
      $true -or
    $environmentReviewControl.approvedRunReviewHistoryRequired -ne $true -or
    [string]$environmentReviewControl.approvalReceiptFile -notmatch
      '^release/approvals/public-repository-environment-reviewer-approval-build-[1-9][0-9]*\.json$' -or
    [string]$environmentReviewControl.approvalReceiptSha256 -notmatch
      '^[0-9A-Fa-f]{64}$' -or
    [string]$environmentReviewControl.approvalReference -notmatch
      '^BAF-GH-ENV-[0-9]{3}$') {
  throw 'Public required-reviewer environment control is incomplete.'
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
      'exact-build11-sealed-small-group-pilot' -or
    $policy.distribution.approved -ne $true -or
    $policy.distribution.preservedHistoricalAuthority -ne $true -or
    $policy.distribution.appliesToCurrentCandidate -ne $false -or
    [int]$policy.distribution.approvedBuildNumber -ne 11 -or
    [string]$policy.distribution.approvedPackageSha256 -ne
      '104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970' -or
    $policy.distribution.pilotHandoutPerformed -ne $false -or
    $policy.distribution.unrestrictedPlantReleaseApproved -ne $false) {
  throw 'Source policy must authorize only exact Build 11 sealed-pilot handout and unrestricted=false.'
}
if ($policy.distribution.postBuildPromotionRequiredForAnyDistribution -ne
    $true) {
  throw 'Post-build promotion requirement is missing.'
}
$constructionBoundary = $policy.artifactConstructionBoundary
if ([string]$constructionBoundary.authority -ne
      'production-signed-pre-release-candidate' -or
    $constructionBoundary.distributionApproved -ne $false -or
    $constructionBoundary.controlledPilotApproved -ne $false -or
    $constructionBoundary.unrestrictedPlantReleaseApproved -ne $false -or
    $constructionBoundary.firebaseDeploymentPerformed -ne $false -or
    $constructionBoundary.postBuildPromotionRequiredForAnyDistribution -ne
      $true) {
  throw 'New production-artifact construction boundary is incomplete.'
}

$requiredFiles = @(
  [string]$policy.identityApproval.receiptFile
  [string]$policy.versionPolicy.approvalReceiptFile
  [string]$policy.versionPolicy.sourceDocumentFile
  [string]$environmentReviewControl.approvalReceiptFile
  [string]$policy.signing.approvalReceiptFile
  [string]$policy.firebaseAndroidApp.registrationReceiptFile
  [string]$policy.firebaseAndroidApp.restorationReceiptFile
  [string]$policy.migrationPlan.receiptFile
  [string]$policy.versionPolicy.ledgerFile
  [string]$policy.toolchain.githubActionPinsFile
  [string]$policy.toolchain.firebaseToolsLockfile
  [string]$policy.toolchain.linuxIsarCoreAuthorityReceipt
  [string]$policy.postBuildPromotion.promotionReceiptFile
  'tools/release/Finalize-ProductionRelease.ps1'
)
$finalizationStatus = [string]$policy.finalization.status
if ($finalizationStatus -eq 'completed-non-distributable') {
  $requiredFiles += [string]$policy.finalization.completionReceiptFile
  if ($policy.finalization.runtimeValidationPassed -eq $true) {
    $requiredFiles +=
      [string]$policy.finalization.deviceAcceptanceReceiptFile
  }
  foreach ($failedAttempt in @($policy.finalization.historicalFailedAttempts)) {
    $requiredFiles += [string]$failedAttempt.evidenceFile
  }
} elseif ($finalizationStatus -eq 'pending-source-authorized') {
  $requiredFiles +=
    [string]$policy.finalization.priorCompletedBuild.completionReceiptFile
  foreach ($failedAttempt in @($policy.finalization.historicalFailedAttempts)) {
    $requiredFiles += [string]$failedAttempt.evidenceFile
  }
} else {
  throw 'Production policy finalization state is unsupported.'
}

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Required policy file is missing: $file"
  }
}
$promotionReceiptPath =
  [string]$policy.postBuildPromotion.promotionReceiptFile
if ((Get-Sha256 $promotionReceiptPath) -ne
    ([string]$policy.postBuildPromotion.promotionReceiptSha256).
      ToUpperInvariant()) {
  throw 'Post-build promotion receipt hash differs from policy.'
}
$promotionReceipt = Get-Content -LiteralPath $promotionReceiptPath -Raw |
  ConvertFrom-Json
$promotionBuildNumber = [int]$policy.postBuildPromotion.buildNumber
$promotionAuthorityBuild = $promotionReceipt.admittedEvidence.governedBuild
if ($null -eq $promotionAuthorityBuild -or
    [int]$promotionAuthorityBuild.buildNumber -ne $promotionBuildNumber) {
  throw 'Post-build promotion receipt has no matching governed build authority.'
}
$promotionFinalizationPath =
  [string]$promotionAuthorityBuild.finalizationReceipt
if ((Get-Sha256 $promotionFinalizationPath) -ne
    ([string]$promotionAuthorityBuild.finalizationReceiptSha256).
      ToUpperInvariant()) {
  throw 'Promoted build finalization receipt hash differs from authority.'
}
$promotionFinalizationReceipt =
  Get-Content -LiteralPath $promotionFinalizationPath -Raw | ConvertFrom-Json
if ([string]$promotionFinalizationReceipt.status -ne
      'passed-non-distributable' -or
    [int]$promotionFinalizationReceipt.release.buildNumber -ne
      $promotionBuildNumber -or
    [string]$promotionFinalizationReceipt.sourceAuthority.commit -ne
      [string]$promotionAuthorityBuild.sourceCommit -or
    [string]$promotionFinalizationReceipt.governedPackage.sha256 -ne
      [string]$promotionAuthorityBuild.governedPackageSha256 -or
    $promotionAuthorityBuild.dualCustodyCompleted -ne $true -or
    [string]$promotionFinalizationReceipt.dualCustody.status -ne 'passed' -or
    $promotionAuthorityBuild.twoTargetInPlaceValidationPassed -ne $true -or
    [string]$promotionFinalizationReceipt.runtimeAdjudication.status -ne
      'passed-two-target-in-place') {
  throw 'Promoted build retained finalization authority is incomplete or divergent.'
}
if ([string]$policy.postBuildPromotion.status -ne
      'completed-controlled-pilot-only' -or
    $promotionBuildNumber -ne 11 -or
    [string]$policy.postBuildPromotion.sourceCommit -ne
      [string]$promotionAuthorityBuild.sourceCommit -or
    [string]$policy.postBuildPromotion.governedPackageSha256 -ne
      [string]$promotionAuthorityBuild.governedPackageSha256 -or
    $policy.postBuildPromotion.controlledPilotApproved -ne $true -or
    $policy.postBuildPromotion.pilotHandoutPerformed -ne $false -or
    $policy.postBuildPromotion.publicArtifactApproved -ne $false -or
    $policy.postBuildPromotion.githubReleaseApproved -ne $false -or
    $policy.postBuildPromotion.firebaseAppDistributionApproved -ne $false -or
    $policy.postBuildPromotion.playConsoleApproved -ne $false -or
    $policy.postBuildPromotion.playStoreApproved -ne $false -or
    $policy.postBuildPromotion.webDistributionApproved -ne $false -or
    $policy.postBuildPromotion.unrestrictedPlantReleaseApproved -ne $false -or
    [string]$policy.distribution.promotionReceiptFile -ne
      $promotionReceiptPath -or
    [string]$policy.distribution.promotionReceiptSha256 -ne
      [string]$policy.postBuildPromotion.promotionReceiptSha256 -or
    [string]$promotionReceipt.decision -ne
      'PASS_LR07_CLOSED_AND_STAGE2D_F6_CONTROLLED_PILOT_AUTHORIZED' -or
    [int]$promotionReceipt.promotion.authorizedBuildNumber -ne 11 -or
    [string]$promotionReceipt.promotion.authorizedPackageSha256 -ne
      [string]$promotionAuthorityBuild.governedPackageSha256 -or
    $promotionReceipt.promotion.pilotHandoutAuthorized -ne $true -or
    $promotionReceipt.promotion.pilotHandoutPerformedByThisRecord -ne $false -or
    $promotionReceipt.promotion.publicArtifactAuthorized -ne $false -or
    $promotionReceipt.promotion.githubReleaseAuthorized -ne $false -or
    $promotionReceipt.promotion.firebaseAppDistributionAuthorized -ne $false -or
    $promotionReceipt.promotion.playConsoleAuthorized -ne $false -or
    $promotionReceipt.promotion.playStoreAuthorized -ne $false -or
    $promotionReceipt.promotion.webDistributionAuthorized -ne $false -or
    $promotionReceipt.promotion.unrestrictedDistributionAuthorized -ne $false -or
    $promotionReceipt.closureBoundary.pilotHandoutPerformed -ne $false) {
  throw 'Post-build promotion exceeds or differs from the exact Build 11 sealed-pilot boundary.'
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
  '$currentBranchOutput = @(git branch --show-current)'
  '$prCommits.Count -lt 1'
  'public-repository-required-reviewer'
  'deployment-branch-policies'
  '$approvedRequiredReviewerReviews.Count -lt 1'
  'environmentApprovalReference'
  'environmentAuthorityMergeCommit'
  'successorFreezeBaselineCommit'
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
if ($finalizer -match
    '(?s)requiredIntegratedMergeCommit.{0,240}integratedSuccessorMergeCommit') {
  throw 'Governed finalizer retains divergent environment/integrated-successor coupling.'
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

$environmentApproval = Get-Content `
  -LiteralPath $environmentReviewControl.approvalReceiptFile `
  -Raw | ConvertFrom-Json
if ((Get-Sha256 $environmentReviewControl.approvalReceiptFile) -ne
      ([string]$environmentReviewControl.approvalReceiptSha256).
        ToUpperInvariant() -or
    [string]$environmentApproval.receiptType -ne
      'public-repository-required-reviewer-control' -or
    $environmentApproval.approved -ne $true -or
    [string]$environmentApproval.approvalReference -ne
      [string]$environmentReviewControl.approvalReference -or
    [string]$environmentApproval.scope.repository -ne
      [string]$policy.github.repository -or
    [string]$environmentApproval.scope.repositoryVisibility -ne 'public' -or
    [string]$environmentApproval.scope.environmentName -ne
      [string]$policy.github.environmentName -or
    [string]$environmentApproval.scope.workflowPath -ne
      [string]$policy.github.workflowPath -or
    [int64]$environmentApproval.scope.buildNumber -ne
      [int64]$policy.release.buildNumber -or
    [string]$environmentApproval.scope.versionName -ne
      [string]$policy.release.versionName -or
    [string]$environmentApproval.scope.versionApprovalReference -ne
      [string]$versionReceipt.reference -or
    $environmentApproval.scope.singleBuildOnly -ne $true -or
    $environmentApproval.liveStateEvidence.repositoryPrivate -ne $false -or
    [string]$environmentApproval.liveStateEvidence.repositoryVisibility -ne
      'public' -or
    [long]$environmentApproval.liveStateEvidence.environmentId -le 0 -or
    $environmentApproval.liveStateEvidence.requiredReviewerRulePresent -ne
      $true -or
    [long]$environmentApproval.liveStateEvidence.requiredReviewerRuleId -le 0 -or
    [string]$environmentApproval.liveStateEvidence.requiredReviewer.type -ne
      'User' -or
    [string]$environmentApproval.liveStateEvidence.requiredReviewer.login -ne
      $ExpectedRequiredReviewerLogin -or
    [long]$environmentApproval.liveStateEvidence.requiredReviewer.id -ne
      $ExpectedRequiredReviewerId -or
    $environmentApproval.liveStateEvidence.preventSelfReview -ne $false -or
    $environmentApproval.liveStateEvidence.canAdminsBypass -ne $false -or
    $environmentApproval.liveStateEvidence.deploymentBranchPolicy.
      protectedBranches -ne $false -or
    $environmentApproval.liveStateEvidence.deploymentBranchPolicy.
      customBranchPolicies -ne $true -or
    @($environmentApproval.liveStateEvidence.deploymentBranchPolicy.
      allowedBranches).Count -ne 1 -or
    [string]$environmentApproval.liveStateEvidence.deploymentBranchPolicy.
      allowedBranches[0].name -ne 'main' -or
    [string]$environmentApproval.liveStateEvidence.deploymentBranchPolicy.
      allowedBranches[0].type -ne 'branch' -or
    $environmentApproval.liveStateEvidence.secretValuesInspected -ne $false -or
    [string]$environmentApproval.liveStateEvidence.
      authorizedDispatcher.login -ne 'abhishekvatsa' -or
    [long]$environmentApproval.liveStateEvidence.
      authorizedDispatcher.id -ne 213690022 -or
    $environmentApproval.singleOperatorConstraint.
      independentSecondPartyReviewerAvailable -ne $false -or
    $environmentApproval.singleOperatorConstraint.selfReviewPermitted -ne
      $true -or
    $environmentApproval.singleOperatorConstraint.
      explicitEnvironmentApprovalStillRequired -ne $true -or
    $environmentApproval.controls.
      manualDispatchApprovalReferenceRequired -ne $true -or
    [string]$environmentApproval.controls.
      dispatchApprovalReference -ne [string]$versionReceipt.reference -or
    $environmentApproval.controls.
      authorizedDispatcherIdentityRequired -ne $true -or
    $environmentApproval.controls.
      protectedEnvironmentSecretsRequired -ne $true -or
    [string]$environmentApproval.controls.requiredIntegratedMergeCommit -ne
      $ExpectedEnvironmentAuthorityCommit -or
    $environmentApproval.controls.
      approvedRunReviewByRequiredReviewerRequired -ne $true -or
    $environmentApproval.controls.adminBypassMustRemainDisabled -ne $true -or
    $environmentApproval.controls.mainOnlyEnvironmentDeploymentRequired -ne
      $true -or
    $environmentApproval.controls.
      atomicOneTimeRemoteReservationRequired -ne $true -or
    $environmentApproval.controls.
      independentPackageVerificationRequired -ne $true -or
    $environmentApproval.controls.
      dualCustodyRequiredBeforeBuiltTag -ne $true -or
    $environmentApproval.controls.distributionApproved -ne
      $false -or
    $environmentApproval.controls.firebaseDeploymentApproved -ne $false) {
  throw 'Public required-reviewer environment approval differs from policy.'
}
$approvalSecretNames = @(
  $environmentApproval.liveStateEvidence.requiredEnvironmentSecretNames |
    ForEach-Object { [string]$_ } |
    Sort-Object
)
if (($approvalSecretNames -join "`n") -cne
    ($policySecretNames -join "`n")) {
  throw 'Environment approval secret-name inventory differs from policy.'
}

$versionSource = Get-Content `
  -LiteralPath $policy.versionPolicy.sourceDocumentFile `
  -Raw | ConvertFrom-Json
$currentSuccessorStatePath = 'release/current-successor-state.json'
$currentSuccessorState = Get-Content `
  -LiteralPath $currentSuccessorStatePath -Raw | ConvertFrom-Json
$predecessorBindingsPath =
  'release/predecessor-finalization-receipt-bindings.json'
$predecessorBindings = Get-Content `
  -LiteralPath $predecessorBindingsPath -Raw | ConvertFrom-Json
if ($predecessorBindings.schemaVersion -ne 1 -or
    [string]$predecessorBindings.recordType -ne
      'historical-predecessor-finalization-receipt-normalization' -or
    [string]$predecessorBindings.status -ne
      'ACTIVE_COMPATIBILITY_CONTRACT' -or
    $predecessorBindings.historicalApprovalFilesImmutable -ne $true -or
    [string]$predecessorBindings.legacyFieldNames.file -ne
      'build11FinalizationReceiptFile' -or
    [string]$predecessorBindings.legacyFieldNames.sha256 -ne
      'build11FinalizationReceiptSha256' -or
    [string]$predecessorBindings.futureFieldContract.object -ne
      'predecessorFinalizationReceipt' -or
    $predecessorBindings.futureFieldContract.
      legacyAliasPermittedOnlyWhenRegisteredHere -ne $true) {
  throw 'Predecessor finalization receipt normalization is incomplete.'
}

$legacyBindings = @($predecessorBindings.compatibilityBindings)
foreach ($binding in $legacyBindings) {
  $bindingApproval = Get-Content `
    -LiteralPath ([string]$binding.approvalFile) -Raw | ConvertFrom-Json
  $bindingReceipt = Get-Content `
    -LiteralPath ([string]$binding.receiptFile) -Raw | ConvertFrom-Json
  if ([int64]$binding.successorBuildNumber -ne
        ([int64]$binding.predecessorBuildNumber + 1) -or
      (Get-Sha256 ([string]$binding.approvalFile)) -ne
        ([string]$binding.approvalSha256).ToUpperInvariant() -or
      [int64]$bindingApproval.nextBuild.buildNumber -ne
        [int64]$binding.successorBuildNumber -or
      [int64]$bindingApproval.preservedCompletedBuild.buildNumber -ne
        [int64]$binding.predecessorBuildNumber -or
      [string]$bindingApproval.requiredSource.
        build11FinalizationReceiptFile -ne [string]$binding.receiptFile -or
      [string]$bindingApproval.requiredSource.
        build11FinalizationReceiptSha256 -ne [string]$binding.receiptSha256 -or
      (Get-Sha256 ([string]$binding.receiptFile)) -ne
        ([string]$binding.receiptSha256).ToUpperInvariant() -or
      [int64]$bindingReceipt.release.buildNumber -ne
        [int64]$binding.predecessorBuildNumber) {
    throw 'A historical predecessor finalization receipt binding is invalid.'
  }
}

$directPredecessorProperty = $versionSource.requiredSource.PSObject.Properties[
  'predecessorFinalizationReceipt'
]
if ($null -ne $directPredecessorProperty) {
  $directPredecessor = $directPredecessorProperty.Value
  $predecessorBuildNumber = [int64]$directPredecessor.buildNumber
  $predecessorReceiptFile = [string]$directPredecessor.file
  $predecessorReceiptSha256 = [string]$directPredecessor.sha256
} else {
  $currentApprovalSha =
    (Get-Sha256 ([string]$policy.versionPolicy.sourceDocumentFile))
  $currentBindings = @(
    $legacyBindings | Where-Object {
      [string]$_.approvalFile -eq
        [string]$policy.versionPolicy.sourceDocumentFile -and
      [string]$_.approvalSha256 -eq $currentApprovalSha -and
      [int64]$_.successorBuildNumber -eq
        [int64]$versionSource.nextBuild.buildNumber
    }
  )
  if ($currentBindings.Count -ne 1) {
    throw 'Legacy predecessor receipt alias is not explicitly registered.'
  }
  $currentBinding = $currentBindings[0]
  $predecessorBuildNumber = [int64]$currentBinding.predecessorBuildNumber
  $predecessorReceiptFile = [string]$currentBinding.receiptFile
  $predecessorReceiptSha256 = [string]$currentBinding.receiptSha256
}
$predecessorReceipt = Get-Content `
  -LiteralPath $predecessorReceiptFile -Raw | ConvertFrom-Json
if ($predecessorBuildNumber -ne
      ([int64]$versionSource.nextBuild.buildNumber - 1) -or
    $predecessorBuildNumber -ne
      [int64]$versionSource.preservedCompletedBuild.buildNumber -or
    $predecessorReceiptFile -ne
      [string]$versionSource.preservedCompletedBuild.completionReceiptFile -or
    $predecessorReceiptSha256 -ne
      [string]$versionSource.preservedCompletedBuild.completionReceiptSha256 -or
    $predecessorReceiptSha256 -notmatch '^[0-9A-Fa-f]{64}$' -or
    (Get-Sha256 $predecessorReceiptFile) -ne
      $predecessorReceiptSha256.ToUpperInvariant() -or
    [int64]$predecessorReceipt.release.buildNumber -ne
      $predecessorBuildNumber) {
  throw 'Resolved predecessor finalization receipt differs from authority.'
}
$functionFleetDeploymentReceiptPath =
  [string]$policy.finalization.exactFunctionFleetDeploymentReceiptFile
if ([string]::IsNullOrWhiteSpace($functionFleetDeploymentReceiptPath) -or
    [string]$policy.finalization.exactFunctionFleetDeploymentReceiptSha256 -notmatch
      '^[0-9A-Fa-f]{64}$' -or
    [string]$versionSource.requiredSource.exactFunctionFleetDeploymentReceiptFile -ne
      $functionFleetDeploymentReceiptPath -or
    [string]$versionSource.requiredSource.exactFunctionFleetDeploymentReceiptSha256 -ne
      [string]$policy.finalization.exactFunctionFleetDeploymentReceiptSha256 -or
    (Get-Sha256 $functionFleetDeploymentReceiptPath) -ne
      ([string]$policy.finalization.exactFunctionFleetDeploymentReceiptSha256).
        ToUpperInvariant()) {
  throw 'Exact Function fleet deployment receipt authority differs from policy.'
}
$functionFleetDeploymentReceipt = Get-Content `
  -LiteralPath $functionFleetDeploymentReceiptPath -Raw | ConvertFrom-Json
$deploymentPullRequestProperty = $versionSource.requiredSource.
  PSObject.Properties['exactFunctionFleetDeploymentPullRequest']
$expectedFunctionFleetPullRequest = if ($null -eq $deploymentPullRequestProperty) {
  265
} else {
  $configuredPullRequest = [int64]$deploymentPullRequestProperty.Value
  if ($configuredPullRequest -le 0) {
    throw 'Exact Function fleet deployment pull request is invalid.'
  }
  $configuredPullRequest
}
if ([string]$functionFleetDeploymentReceipt.decision -ne
      'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK' -or
    [string]$functionFleetDeploymentReceipt.sourceAuthority.commit -ne
      [string]$versionSource.sourceBaseline.commit -or
    [string]$functionFleetDeploymentReceipt.sourceAuthority.tree -ne
      [string]$versionSource.sourceBaseline.tree -or
    [int64]$functionFleetDeploymentReceipt.sourceAuthority.pullRequestNumber -ne
      $expectedFunctionFleetPullRequest -or
    $functionFleetDeploymentReceipt.deployment.functionCount -ne 15 -or
    $functionFleetDeploymentReceipt.deployment.allFunctionsExactSourceVerified -ne
      $true -or
    $functionFleetDeploymentReceipt.deployment.finalRuntimeIdentityReadbackPassed -ne
      $true -or
    $functionFleetDeploymentReceipt.deployment.finalIamDependencyReadbackPassed -ne
      $true -or
    $functionFleetDeploymentReceipt.controlBoundary.productionBusinessDataMutated -ne
      $false -or
    $functionFleetDeploymentReceipt.controlBoundary.distributionPerformed -ne
      $false) {
  throw 'Exact Function fleet deployment receipt is incomplete.'
}
$deployedFunctionsTree = Get-GitTreeObjectId `
  -Commit ([string]$functionFleetDeploymentReceipt.sourceAuthority.commit) `
  -Path 'functions'
$currentFunctionsTree = Get-GitTreeObjectId -Commit 'HEAD' -Path 'functions'
$expectedCurrentSourceFunctionDeployment =
  Get-FunctionFleetDeploymentStatus `
    -DeployedTree $deployedFunctionsTree `
    -CurrentTree $currentFunctionsTree
$functionsMatchDeployed =
  $expectedCurrentSourceFunctionDeployment -eq
    'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK'
$expectedPackageVersion =
  "$([string]$policy.release.versionName)+$([int64]$policy.release.buildNumber)"
$artifactSourceStatus = Get-ApprovedArtifactSourceStatus `
  -BaselineCommit ([string]$versionSource.sourceBaseline.commit) `
  -CurrentCommit 'HEAD' `
  -ExpectedPackageVersion $expectedPackageVersion
$firestoreReadbackAuthority =
  $policy.finalization.exactFirestoreRulesIndexesLiveReadback
$firestoreReadbackPath = [string]$firestoreReadbackAuthority.receiptFile
if ($firestoreReadbackAuthority.verified -ne $true -or
    [string]::IsNullOrWhiteSpace($firestoreReadbackPath) -or
    [string]$firestoreReadbackAuthority.receiptFileSha256 -notmatch
      '^[0-9A-Fa-f]{64}$' -or
    (Get-Sha256 $firestoreReadbackPath) -ne
      ([string]$firestoreReadbackAuthority.receiptFileSha256).
        ToUpperInvariant()) {
  throw 'Exact Firestore Rules/index live-readback authority differs from policy.'
}
$firestoreReadback = Get-Content -LiteralPath $firestoreReadbackPath -Raw |
  ConvertFrom-Json
& node tools/release/collectProductionGlobalPullBackend.js `
  --verify-receipt $firestoreReadbackPath `
  --label "Build $([int64]$versionSource.nextBuild.buildNumber) Firestore Rules/index live readback" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Exact Firestore Rules/index canonical receipt seal is invalid.'
}
$firestoreCheckValues = @(
  $firestoreReadback.checks.PSObject.Properties |
    ForEach-Object { $_.Value }
)
if ([string]$firestoreReadback.evidenceType -ne
      'firestore-rules-indexes-live-readback' -or
    [string]$firestoreReadback.mode -ne 'STRICT' -or
    [string]$firestoreReadback.projectId -ne 'crm3-baf-ops-b8638' -or
    [string]$firestoreReadback.decision -ne
      'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK' -or
    $firestoreReadback.failedChecks.Count -ne 0 -or
    $firestoreCheckValues.Count -eq 0 -or
    @($firestoreCheckValues | Where-Object { $_ -ne $true }).Count -ne 0 -or
    [string]$firestoreReadback.receiptSha256 -ne
      [string]$firestoreReadbackAuthority.receiptCanonicalSha256 -or
    [string]$firestoreReadback.source.before.branch -ne 'main' -or
    [string]$firestoreReadback.source.before.commit -ne
      [string]$firestoreReadbackAuthority.sourceCommit -or
    [string]$firestoreReadback.source.before.tree -ne
      [string]$firestoreReadbackAuthority.sourceTree -or
    [string]$firestoreReadback.source.before.originMain -ne
      [string]$firestoreReadbackAuthority.sourceCommit -or
    [string]$firestoreReadback.source.after.commit -ne
      [string]$firestoreReadbackAuthority.sourceCommit -or
    [string]$firestoreReadback.outputs.rules.sourceSha256 -ne
      [string]$firestoreReadbackAuthority.rulesSha256 -or
    [string]$firestoreReadback.outputs.rules.activeSha256 -ne
      [string]$firestoreReadbackAuthority.rulesSha256 -or
    $firestoreReadback.outputs.rules.byteExact -ne $true -or
    [int64]$firestoreReadback.outputs.indexes.sourceCount -ne
      [int64]$firestoreReadbackAuthority.indexCount -or
    [int64]$firestoreReadback.outputs.indexes.cliCount -ne
      [int64]$firestoreReadbackAuthority.indexCount -or
    [int64]$firestoreReadback.outputs.indexes.apiCount -ne
      [int64]$firestoreReadbackAuthority.indexCount -or
    [int64]$firestoreReadback.outputs.indexes.apiReadyCount -ne
      [int64]$firestoreReadbackAuthority.indexCount -or
    [string]$firestoreReadback.outputs.indexes.sourceSetSha256 -ne
      [string]$firestoreReadbackAuthority.indexSetSha256 -or
    [string]$firestoreReadback.outputs.indexes.cliSetSha256 -ne
      [string]$firestoreReadbackAuthority.indexSetSha256 -or
    [string]$firestoreReadback.outputs.indexes.apiSetSha256 -ne
      [string]$firestoreReadbackAuthority.indexSetSha256 -or
    $firestoreReadback.outputs.indexes.allApiIndexesReady -ne $true -or
    $firestoreReadbackAuthority.allIndexesReady -ne $true -or
    $firestoreReadbackAuthority.redundantDeploymentPerformed -ne $false -or
    $firestoreReadback.mutationBoundary.firestoreRulesDeployed -ne $false -or
    $firestoreReadback.mutationBoundary.firestoreIndexesDeployed -ne $false -or
    $firestoreReadback.mutationBoundary.firestoreDocumentsRead -ne $false -or
    $firestoreReadback.mutationBoundary.firestoreDocumentsWritten -ne $false -or
    $firestoreReadback.mutationBoundary.businessDataMutated -ne $false) {
  throw 'Exact Firestore Rules/index live-readback receipt is incomplete.'
}
$requiredRulesShaProperty = $versionSource.requiredSource.
  PSObject.Properties['exactFirestoreRulesSha256']
$requiredIndexCountProperty = $versionSource.requiredSource.
  PSObject.Properties['exactFirestoreIndexCount']
$requiredIndexSetShaProperty = $versionSource.requiredSource.
  PSObject.Properties['exactFirestoreIndexSetSha256']
if (($null -eq $requiredRulesShaProperty) -ne
      ($null -eq $requiredIndexCountProperty) -or
    ($null -eq $requiredRulesShaProperty) -ne
      ($null -eq $requiredIndexSetShaProperty)) {
  throw 'Exact successor Firestore Rules and index-set requirements must coexist.'
}
$backendMatchesDeployed = $false
$expectedArtifactConstructionAuthority = $false
if ($null -ne $requiredRulesShaProperty) {
  $requiredRulesSha = [string]$requiredRulesShaProperty.Value
  $requiredIndexCount = [int64]$requiredIndexCountProperty.Value
  $requiredIndexSetSha = [string]$requiredIndexSetShaProperty.Value
  $currentSourceAuthority =
    $currentSuccessorState.authorityPlanes.currentSource
  $currentSourceFirestoreAuthority =
    $currentSourceAuthority.firestoreRulesAndIndexes
  $currentDeployedBackendAuthority =
    $currentSuccessorState.authorityPlanes.deployedBackend
  $sourceIndexBindingOutput = @(
    & node tools/release/collectFirestoreRulesIndexesReadback.js `
      --source-index-set firestore.indexes.json
  )
  if ($LASTEXITCODE -ne 0 -or $sourceIndexBindingOutput.Count -ne 1) {
    throw 'Exact successor Firestore source index-set binding failed.'
  }
  $sourceIndexBinding =
    [string]$sourceIndexBindingOutput[0] | ConvertFrom-Json
  if ($requiredRulesSha -notmatch '^[0-9A-Fa-f]{64}$' -or
      $requiredIndexSetSha -notmatch '^[0-9A-Fa-f]{64}$' -or
      $requiredIndexCount -le 0 -or
      [string]$firestoreReadbackAuthority.rulesSha256 -ne $requiredRulesSha -or
      [int64]$firestoreReadbackAuthority.indexCount -ne $requiredIndexCount -or
      [string]$firestoreReadbackAuthority.indexSetSha256 -ne
        $requiredIndexSetSha -or
      [string]$firestoreReadback.outputs.rules.sourceSha256 -ne
        $requiredRulesSha -or
      [string]$firestoreReadback.outputs.indexes.sourceSetSha256 -ne
        $requiredIndexSetSha) {
    throw 'Exact finalized Firestore Rules/index readback differs from approval.'
  }

  $currentRulesSha =
    [string]$currentSourceFirestoreAuthority.rulesSha256
  $currentIndexCount =
    [int64]$currentSourceFirestoreAuthority.indexCount
  $currentIndexSetSha =
    [string]$currentSourceFirestoreAuthority.indexSetSha256
  $rulesChanged = $currentRulesSha -ne $requiredRulesSha
  $indexesChanged =
    $currentIndexCount -ne $requiredIndexCount -or
    $currentIndexSetSha -ne $requiredIndexSetSha
  $firestoreMatchesDeployed = -not $rulesChanged -and -not $indexesChanged
  $expectedCurrentSourceRelationship = if ($firestoreMatchesDeployed) {
    'EXACT_SOURCE_RULES_AND_INDEXES_DEPLOYED_AND_VERIFIED'
  } elseif ($rulesChanged -and $indexesChanged) {
    'RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  } elseif ($rulesChanged) {
    'RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  } else {
    'RULES_MATCH_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  }
  $expectedCurrentSourceDeployment = if ($firestoreMatchesDeployed) {
    'PASS_FIRESTORE_RULES_INDEXES_LIVE_READBACK'
  } elseif ($rulesChanged -and $indexesChanged) {
    'SOURCE_RULES_AND_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  } elseif ($rulesChanged) {
    'SOURCE_RULES_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  } else {
    'SOURCE_INDEX_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  }
  $backendMatchesDeployed =
    $functionsMatchDeployed -and $firestoreMatchesDeployed
  $expectedBackendDeploymentStatus = if ($backendMatchesDeployed) {
    'EXACT_SOURCE_BACKEND_DEPLOYED_AND_VERIFIED'
  } else {
    'SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT'
  }
  $expectedArtifactConstructionAuthority =
    Get-ArtifactConstructionAuthority `
      -PendingSourceAuthorization (
        [string]$policy.finalization.status -eq 'pending-source-authorized'
      ) `
      -BackendMatchesDeployed $backendMatchesDeployed `
      -ArtifactSourceMatchesApproval ([bool]$artifactSourceStatus.matches)
  if ($currentSuccessorState.schemaVersion -lt 2 -or
      [string]$currentSourceAuthority.reference -ne 'refs/heads/main' -or
      $currentSourceAuthority.sourceAndCiAuthority -ne $true -or
      $currentSourceAuthority.artifactConstructionAuthority -ne
        $expectedArtifactConstructionAuthority -or
      $currentSourceAuthority.deploymentAuthority -ne $false -or
      $currentSourceAuthority.distributionAuthority -ne $false -or
      [string]$currentSourceAuthority.backendDeploymentStatus -ne
        $expectedBackendDeploymentStatus -or
      $currentSourceAuthority.productionRuntimeUseAuthorized -ne $false -or
      $currentRulesSha -notmatch '^[0-9A-Fa-f]{64}$' -or
      $currentIndexSetSha -notmatch '^[0-9A-Fa-f]{64}$' -or
      $currentIndexCount -le 0 -or
      (Get-Sha256 'firestore.rules') -ne
        $currentRulesSha.ToUpperInvariant() -or
      [int64]$sourceIndexBinding.count -ne $currentIndexCount -or
      [string]$sourceIndexBinding.indexSetSha256 -ne $currentIndexSetSha -or
      [string]$currentSourceFirestoreAuthority.
        relationshipToDeployedBackend -ne
        $expectedCurrentSourceRelationship -or
      $currentSourceFirestoreAuthority.productionDeploymentPerformed -ne
        $firestoreMatchesDeployed -or
      $currentSourceFirestoreAuthority.productionRuntimeUseAuthorized -ne
        $firestoreMatchesDeployed -or
      [string]$currentDeployedBackendAuthority.functionFleetEvidenceFile -ne
        $functionFleetDeploymentReceiptPath -or
      [string]$currentDeployedBackendAuthority.functionFleetSourceCommit -ne
        [string]$versionSource.sourceBaseline.commit -or
      [string]$currentDeployedBackendAuthority.functionFleetReadbackDecision -ne
        'PASS_EXACT_SOURCE_FUNCTION_FLEET_DEPLOYED_AND_READ_BACK' -or
      [string]$currentDeployedBackendAuthority.
        currentSourceFunctionDeployment -ne
        $expectedCurrentSourceFunctionDeployment -or
      [string]$currentDeployedBackendAuthority.rulesAndIndexesEvidenceFile -ne
        $firestoreReadbackPath -or
      [string]$currentDeployedBackendAuthority.rulesAndIndexesSourceCommit -ne
        [string]$firestoreReadbackAuthority.sourceCommit -or
      [string]$currentDeployedBackendAuthority.rulesAndIndexesSourceCommit -ne
        [string]$firestoreReadback.source.before.commit -or
      [string]$currentDeployedBackendAuthority.
        currentSourceRulesAndIndexesDeployment -ne
        $expectedCurrentSourceDeployment -or
      $currentDeployedBackendAuthority.productionBackendRuntimeAuthorized -ne
        $true) {
    throw 'Current source backend authority differs from source state.'
  }
}
if ($RequireArtifactConstructionAuthority -and
    -not $expectedArtifactConstructionAuthority) {
  $sourceDrift = if (@($artifactSourceStatus.driftedPaths).Count -eq 0) {
    'none'
  } else {
    $artifactSourceStatus.driftedPaths -join ', '
  }
  throw (
    'Artifact construction is not authorized for this exact source. ' +
    "Approved build-source drift: $sourceDrift; " +
    "backend exact: $backendMatchesDeployed; " +
    "pending source authorization: " +
    ([string]$policy.finalization.status -eq 'pending-source-authorized') + '.'
  )
}
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
    $consumedDisposition -in @(
      'successful-build-finalization-blocked'
      'successful-build-finalization-authority-mismatch-non-distributable'
    ) -and
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
    $consumedDisposition -in @(
      'successful-build-finalized-non-distributable'
      'successful-build-finalized-runtime-failed-non-distributable'
    ) -and
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
      firestoreValueNormalizationRemediationRequired -ne $true -or
    $versionSource.controls.integratedSuccessorRequired -ne $true -or
    $versionSource.controls.successorFreezeRequired -ne $true -or
    $versionSource.controls.startupRemediationRequired -ne $true -or
    $versionSource.controls.crashlyticsGradlePluginRequired -ne $true -or
    $versionSource.controls.compiledCrashlyticsMappingIdRequired -ne $true -or
    $versionSource.controls.exactReleaseApkColdStartCiRequired -ne $true -or
    $versionSource.controls.lr07Build10RearmRequired -ne $true -or
    $versionSource.controls.publicRepositoryRequiredReviewerApproved -ne
      $true -or
    [string]$versionSource.controls.environmentApprovalReference -ne
      [string]$environmentReviewControl.approvalReference -or
    $versionSource.controls.approvedEnvironmentReviewHistoryRequired -ne
      $true -or
    $versionSource.controls.adminBypassProhibited -ne $true -or
    $versionSource.controls.mainOnlyEnvironmentDeploymentRequired -ne $true -or
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
    [int64]$versionSource.requiredSource.
      firestoreValueNormalizationPullRequest -ne 111 -or
    [string]$versionSource.requiredSource.
      firestoreValueNormalizationMergeCommit -notmatch '^[0-9a-f]{40}$' -or
    $versionSource.requiredSource.
      firestoreValueNormalizationMustBeAncestorOfDispatchCommit -ne $true -or
    [int64]$versionSource.requiredSource.integratedSuccessorPullRequest -ne
      193 -or
    [string]$versionSource.requiredSource.integratedSuccessorMergeCommit -ne
      $ExpectedIntegratedSuccessorCommit -or
    [string]$versionSource.requiredSource.integratedSuccessorTree -ne
      $ExpectedIntegratedSuccessorTree -or
    $versionSource.requiredSource.
      integratedSuccessorMustBeAncestorOfDispatchCommit -ne $true -or
    [int64]$versionSource.requiredSource.startupRemediationPullRequest -ne
      197 -or
    [string]$versionSource.requiredSource.startupRemediationMergeCommit -ne
      $ExpectedStartupRemediationCommit -or
    [string]$versionSource.requiredSource.startupRemediationTree -ne
      $ExpectedStartupRemediationTree -or
    $versionSource.requiredSource.
      startupRemediationMustBeAncestorOfDispatchCommit -ne $true -or
    [int64]$versionSource.requiredSource.environmentAuthorityPullRequest -ne
      198 -or
    [string]$versionSource.requiredSource.environmentAuthorityMergeCommit -ne
      $ExpectedEnvironmentAuthorityCommit -or
    [string]$versionSource.requiredSource.environmentAuthorityTree -ne
      $ExpectedEnvironmentAuthorityTree -or
    $versionSource.requiredSource.
      environmentAuthorityMustBeAncestorOfDispatchCommit -ne $true -or
    [string]$versionSource.requiredSource.successorFreezeBaselineCommit -notmatch
      '^[0-9a-f]{40}$' -or
    [string]$versionSource.requiredSource.successorFreezeBaselineTree -notmatch
      '^[0-9a-f]{40}$' -or
    $versionSource.requiredSource.
      successorFreezeMustBeAncestorOfDispatchCommit -ne $true -or
    [string]$environmentApproval.controls.requiredSuccessorFreezeCommit -ne
      [string]$versionSource.requiredSource.successorFreezeBaselineCommit -or
    [int64]$versionSource.requiredSource.
      successorFreezePostMergeGithubRunId -le 0 -or
    [string]$versionSource.requiredSource.
      successorFreezePostMergeGithubRunConclusion -ne 'success' -or
    [int64]$versionSource.requiredSource.
      successorFreezeCanonicalAuditPassCount -lt 144 -or
    $versionSource.requiredSource.crashlyticsGradlePluginRequired -ne
      $true -or
    $versionSource.requiredSource.compiledCrashlyticsMappingIdRequired -ne
      $true -or
    $versionSource.requiredSource.exactReleaseApkColdStartCiRequired -ne
      $true -or
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
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.
    firestoreValueNormalizationMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the Firestore value-normalization remediation.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.integratedSuccessorMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the integrated PR 193 successor.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.startupRemediationMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the PR 197 startup remediation.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.environmentAuthorityMergeCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the approved environment authority baseline.'
}
git merge-base --is-ancestor `
  ([string]$versionSource.requiredSource.successorFreezeBaselineCommit) `
  HEAD
if ($LASTEXITCODE -ne 0) {
  throw 'Dispatch source does not contain the approved successor freeze baseline.'
}
$successorFreezeTree = @(
  git show -s --format='%T' `
    ([string]$versionSource.requiredSource.successorFreezeBaselineCommit)
)
if ($LASTEXITCODE -ne 0 -or $successorFreezeTree.Count -ne 1 -or
    $successorFreezeTree[0].Trim().ToLowerInvariant() -ne
      ([string]$versionSource.requiredSource.successorFreezeBaselineTree).
        ToLowerInvariant()) {
  throw 'Approved successor freeze commit/tree binding differs from Git.'
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

  if ($policy.finalization.runtimeValidationPassed -eq $true) {
    $deviceAcceptancePath =
      [string]$policy.finalization.deviceAcceptanceReceiptFile
    $deviceAcceptance =
      Get-Content -LiteralPath $deviceAcceptancePath -Raw |
        ConvertFrom-Json
    $mutationValues = @(
      $deviceAcceptance.businessMutationBoundary.PSObject.Properties |
        ForEach-Object { $_.Value }
    )
    $readOnlySurfacesValidated =
      $deviceAcceptance.adjudication.authenticatedReadOnlySurfaceValidationCompleted
    $mutatingFlowsValidated =
      $deviceAcceptance.adjudication.mutatingBusinessFlowValidationCompleted
    if ((Get-Sha256 $deviceAcceptancePath) -ne
        ([string]$policy.finalization.deviceAcceptanceReceiptSha256).
          ToUpperInvariant() -or
        [string]$policy.finalization.runtimeDisposition -ne
          'passed-exact-build18-physical-in-place-authenticated-read-only-surfaces' -or
        $policy.finalization.fullBusinessFlowValidationCompleted -ne
          $false -or
        [string]$deviceAcceptance.evidenceType -ne
          'production-build-device-acceptance' -or
        [string]$deviceAcceptance.status -ne
          'passed-exact-build18-physical-in-place-authenticated-read-only-surfaces' -or
        [int64]$deviceAcceptance.release.buildNumber -ne
          [int64]$policy.release.buildNumber -or
        [string]$deviceAcceptance.release.finalizationReceiptSha256 -ne
          (Get-Sha256 $completionReceiptPath) -or
        [string]$deviceAcceptance.release.apkSha256 -ne
          [string]$completionReceipt.governedPackage.apkSha256 -or
        [string]$deviceAcceptance.release.certificateSha256 -ne
          [string]$completionReceipt.governedPackage.certificateSha256 -or
        $deviceAcceptance.physicalDevice.deviceSerialRecorded -ne $false -or
        $deviceAcceptance.physicalDevice.accountIdentifierRecorded -ne
          $false -or
        [int64]$deviceAcceptance.physicalDevice.installedVersionCode -ne
          [int64]$policy.release.buildNumber -or
        $deviceAcceptance.physicalDevice.exactGovernedApkMatch -ne $true -or
        $deviceAcceptance.physicalDevice.signerContinuityVerified -ne
          $true -or
        $deviceAcceptance.physicalDevice.firstInstallTimePreserved -ne
          $true -or
        $deviceAcceptance.physicalDevice.applicationDataCleared -ne
          $false -or
        [string]$deviceAcceptance.synchronization.lastSyncResult -ne
          'success' -or
        [int64]$deviceAcceptance.synchronization.unsyncedRows -ne 0 -or
        [int64]$deviceAcceptance.synchronization.unresolvedRejections -ne
          0 -or
        @($mutationValues | Where-Object { $_ -ne $false }).Count -ne 0 -or
        $deviceAcceptance.adjudication.runtimeValidationPassed -ne $true -or
        $readOnlySurfacesValidated -ne $true -or
        $mutatingFlowsValidated -ne $false -or
        $deviceAcceptance.adjudication.fullBusinessFlowValidationCompleted -ne
          $false -or
        $deviceAcceptance.releaseBoundary.controlledPilotApproved -ne
          $false -or
        $deviceAcceptance.releaseBoundary.pilotHandoutPerformed -ne
          $false -or
        $deviceAcceptance.releaseBoundary.deviceDataClearPerformed -ne
          $false -or
        $completionReceipt.runtimeAdjudication.runtimeValidationPassed -ne
          $false) {
      throw 'Device acceptance differs from the exact read-only runtime boundary.'
    }
  }

} else {
  $prior = $policy.finalization.priorCompletedBuild
  $preserved = $versionSource.preservedCompletedBuild
  $consumed = $versionSource.consumedBuild
  $successfulPredecessor =
    $consumed.closureFinalizationCompleted -eq $true -and
    $consumed.dualCustodyCompleted -eq $true -and
    $consumed.remoteBuiltTagCreated -eq $true
  $predecessorBoundaryInvalid = $false
  if ($successfulPredecessor) {
    $predecessorBoundaryInvalid =
      [int64]$prior.buildNumber -ne
        [int64]$preserved.buildNumber -or
      [int64]$prior.buildNumber -ne [int64]$consumed.buildNumber -or
      [string]$prior.completionReceiptFile -ne
        [string]$preserved.completionReceiptFile -or
      [string]$prior.completionReceiptFile -ne
        [string]$consumed.completionReceiptFile -or
      [string]$prior.completionReceiptSha256 -ne
        [string]$preserved.completionReceiptSha256 -or
      [string]$prior.completionReceiptSha256 -ne
        [string]$consumed.completionReceiptSha256 -or
      (Get-Sha256 $prior.completionReceiptFile) -ne
        ([string]$prior.completionReceiptSha256).ToUpperInvariant() -or
      [string]$prior.sourceCommit -ne
        [string]$consumed.remoteBuiltCommit -or
      [int64]$prior.githubRunId -ne [int64]$consumed.githubRunId -or
      [string]$prior.governedPackageSha256 -ne
        [string]$consumed.governedPackageSha256
  } else {
    $failed = $policy.finalization.priorFailedAttempt
    $predecessorBoundaryInvalid =
      [int64]$prior.buildNumber -ne [int64]$preserved.buildNumber -or
      [string]$prior.completionReceiptFile -ne
        [string]$preserved.completionReceiptFile -or
      [string]$prior.completionReceiptSha256 -ne
        [string]$preserved.completionReceiptSha256 -or
      [int64]$failed.buildNumber -ne [int64]$consumed.buildNumber -or
      [string]$failed.status -ne 'blocked-non-distributable' -or
      [string]$failed.evidenceFile -ne
        [string]$consumed.finalizationEvidenceFile -or
      [string]$failed.evidenceSha256 -ne
        [string]$consumed.finalizationEvidenceSha256 -or
      (Get-Sha256 $failed.evidenceFile) -ne
        ([string]$failed.evidenceSha256).ToUpperInvariant() -or
      [string]$failed.sourceCommit -ne
        [string]$consumed.remoteReservationCommit -or
      [int64]$failed.githubRunId -ne [int64]$consumed.githubRunId -or
      [int64]$failed.githubArtifactId -ne
        [int64]$consumed.githubArtifactId -or
      [string]$failed.githubArtifactDigest -ne
        [string]$consumed.githubArtifactDigest -or
      [string]$failed.governedPackageSha256 -ne
        [string]$consumed.governedPackageSha256 -or
      $failed.independentVerificationCompleted -ne $true -or
      $failed.dualCustodyCompleted -ne $false -or
      $failed.distributionPerformed -ne $false
  }
  if ($predecessorBoundaryInvalid -or
      $policy.finalization.dualCustodyCompleted -ne $false -or
      $policy.finalization.firebaseBackendDeploymentPerformed -ne $false -or
      $policy.finalization.controlledPilotApproved -ne $false -or
      $policy.finalization.unrestrictedPlantReleaseApproved -ne $false) {
    throw 'Pending finalization does not preserve its completed predecessor boundary.'
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
if ($actionPins.schemaVersion -ne 1 -or $null -eq $actionPins.actions) {
  throw 'GitHub Actions pin authority is incomplete.'
}
$actionPinsByRepository = @{}
foreach ($pin in @($actionPins.actions.PSObject.Properties)) {
  $repository = [string]$pin.Value.repository
  $commitSha = [string]$pin.Value.commitSha
  if ([string]::IsNullOrWhiteSpace($repository) -or
      $commitSha -notmatch '^[0-9a-fA-F]{40}$' -or
      $actionPinsByRepository.ContainsKey($repository)) {
    throw "GitHub Actions pin authority is malformed: $($pin.Name)"
  }
  $actionPinsByRepository[$repository] = $commitSha
}

$ledger = Get-Content -LiteralPath $policy.versionPolicy.ledgerFile -Raw |
  ConvertFrom-Json
$historicalFailedAttempts = @($policy.finalization.historicalFailedAttempts)
if ($finalizationStatus -in @(
    'completed-non-distributable'
    'pending-source-authorized'
  )) {
  if ($historicalFailedAttempts.Count -lt 1) {
    throw 'Production policy omits historical failed-attempt authority.'
  }
  foreach ($failed in $historicalFailedAttempts) {
    $failedLedgerMatches = @(
      $ledger.entries |
        Where-Object { [int64]$_.buildNumber -eq [int64]$failed.buildNumber }
    )
    if ($failedLedgerMatches.Count -ne 1) {
      throw 'Historical failed attempt does not resolve to one ledger entry.'
    }
    $failedLedger = $failedLedgerMatches[0]
    if ([string]$failed.status -ne 'blocked-non-distributable' -or
        [string]$failed.evidenceFile -ne
          [string]$failedLedger.finalizationEvidenceFile -or
        [string]$failed.evidenceSha256 -ne
          [string]$failedLedger.finalizationEvidenceSha256 -or
        (Get-Sha256 $failed.evidenceFile) -ne
          ([string]$failed.evidenceSha256).ToUpperInvariant() -or
        [string]$failed.sourceCommit -ne
          [string]$failedLedger.remoteReservationCommit -or
        [int64]$failed.githubRunId -ne [int64]$failedLedger.githubRunId -or
        [int64]$failed.githubArtifactId -ne
          [int64]$failedLedger.githubArtifactId -or
        [string]$failed.githubArtifactDigest -ne
          [string]$failedLedger.githubArtifactDigest -or
        [string]$failed.governedPackageSha256 -ne
          [string]$failedLedger.governedPackageSha256 -or
        $failed.independentVerificationCompleted -ne $true -or
        $failed.dualCustodyCompleted -ne $false -or
        $failed.remoteBuiltTagCreated -ne $false -or
        $failed.distributionPerformed -ne $false) {
      throw 'Historical failed-attempt authority differs from its ledger record.'
    }
  }
}
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
    [string]$versionSource.consumedBuild.disposition -in @(
      'successful-build-finalization-blocked'
      'successful-build-finalization-authority-mismatch-non-distributable'
    ) -and
    [string]$consumedMatches[0].status -in @(
      'remote-consumed-artifact-built-finalization-blocked'
      'remote-consumed-artifact-built-finalization-blocked-non-distributable'
    ) -and
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
$consumedRuntimeDispositionValid =
  $consumedDisposition -eq 'successful-build-finalized-non-distributable' -or
  ($consumedDisposition -eq
      'successful-build-finalized-runtime-failed-non-distributable' -and
    $versionSource.consumedBuild.runtimeValidationPassed -eq $false -and
    [string]$versionSource.consumedBuild.runtimeFailure -eq
      'missing-crashlytics-gradle-build-identifier' -and
    [int64]$versionSource.consumedBuild.remediationPullRequest -eq 197 -and
    $consumedMatches.Count -eq 1 -and
    $consumedMatches[0].runtimeValidationPassed -eq $false -and
    [string]$consumedMatches[0].runtimeFailure -eq
      [string]$versionSource.consumedBuild.runtimeFailure)
if ($consumedMatches.Count -eq 1 -and
    $consumedMatches[0].failedOrWithdrawnBuildConsumesNumber -eq $true -and
    $consumedRuntimeDispositionValid -and
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
$productionActionReferences = @{}
$productionActionPattern = '(?m)^\s*(?:-\s*)?uses:\s*([^@\s]+)@([^\s#]+)\s*$'
foreach ($match in [regex]::Matches($workflow, $productionActionPattern)) {
  $repository = [string]$match.Groups[1].Value
  $reference = [string]$match.Groups[2].Value
  if ($repository.StartsWith('./')) {
    continue
  }
  if (-not $actionPinsByRepository.ContainsKey($repository) -or
      [string]$actionPinsByRepository[$repository] -ne $reference) {
    throw "Production workflow action pin differs from authority: $repository"
  }
  $productionActionReferences[$repository] = $reference
}
$requiredProductionActionRepositories = @(
  'actions/checkout'
  'actions/setup-java'
  'actions/setup-node'
  'subosito/flutter-action'
  'actions/upload-artifact'
)
if ($productionActionReferences.Count -ne
      $requiredProductionActionRepositories.Count) {
  throw 'Production workflow action set is incomplete or contains extras.'
}
foreach ($repository in $requiredProductionActionRepositories) {
  if (-not $productionActionReferences.ContainsKey($repository)) {
    throw "Production workflow required action is absent: $repository"
  }
}
foreach ($required in @(
  'permissions:'
  'contents: write'
  'actions: read'
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
  'Required-reviewer mode requires the approved public repository.'
  'Live required-reviewer environment protection differs from policy.'
  'deployment-branch-policies'
  'actions/runs/'
  '/approvals'
  'Exact run lacks approval by the governed environment reviewer.'
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
  'Invoke-CIAndroidPackageProof.ps1'
  "-BuildName '0.0.0-production-preflight'"
  '-BuildNumber 1'
  'Secret-isolated Android package proof failed.'
  'flutter clean'
  'Secret-isolated preflight output remains:'
  'New-ProductionArtifact.ps1'
  '-ExpectedApprovalReference $env:CRM_DISPATCH_APPROVAL_REFERENCE'
  'retention-days: 1'
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
$packageProofIndex = $androidPreflightSection.IndexOf(
  'Invoke-CIAndroidPackageProof.ps1'
)
$preflightCleanupIndex = $androidPreflightSection.IndexOf(
  'flutter clean'
)
$packageProofFailureIndex = $androidPreflightSection.IndexOf(
  'Secret-isolated Android package proof failed.'
)
$dependencyRestoreAfterCleanupIndex = $androidPreflightSection.IndexOf(
  'flutter pub get'
)
if ($packageProofIndex -lt 0 -or
    $packageProofFailureIndex -le $packageProofIndex -or
    $preflightCleanupIndex -le $packageProofFailureIndex -or
    $dependencyRestoreAfterCleanupIndex -le $preflightCleanupIndex) {
  throw 'Secret-isolated Android packaging proof and cleanup order is invalid.'
}
if ($androidPreflightSection.Contains('${{ secrets.') -or
    $androidPreflightSection.Contains(
      'CRM_ANDROID_RELEASE_KEYSTORE_BASE64'
    )) {
  throw 'Secret-isolated Android preflight references production secrets.'
}
foreach ($requiredPreflightOutput in @(
  'build/app/outputs/flutter-apk/app-release.apk'
  'build/app/outputs/bundle/release/app-release.aab'
)) {
  if (-not $androidPreflightSection.Contains($requiredPreflightOutput)) {
    throw "Android preflight cleanup omits: $requiredPreflightOutput"
  }
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
Write-Host 'Distribution:   EXACT BUILD 11 SEALED PILOT ONLY'
Write-Host 'Operational package cutover remains O-10/70J.'
