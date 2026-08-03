[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Preflight', 'Deploy', 'Backfill', 'Activate')]
  [string]$Phase,

  [Parameter(Mandatory = $true)]
  [string]$RepositoryRoot,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^crm3-baf-ops-b8638$')]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^crm3-baf-ops-b8638$')]
  [string]$ConfirmProjectId,

  [Parameter(Mandatory = $true)]
  [ValidateLength(3, 160)]
  [string]$Operator,

  [Parameter(Mandatory = $true)]
  [ValidateRange(1, [long]::MaxValue)]
  [long]$PostMergeRunId,

  [Parameter(Mandatory = $true)]
  [string]$EvidenceDirectory,

  [string]$PromotionPath =
    'release/approvals/build-8-f4-production-backend-activation-promotion.json',

  [string]$PreflightReceiptPath,

  [string]$PostDeployReceiptPath,

  [string]$BackfillReceiptPath,

  [string]$PostBackfillInventoryPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-ExternalText {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  $priorLocation = Get-Location
  $nativeOutput = @()
  $exitCode = -1
  try {
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
      Set-Location -LiteralPath $WorkingDirectory
    }
    $nativeOutput = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    Set-Location -LiteralPath $priorLocation
  }
  $text = ($nativeOutput | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
  if ($exitCode -ne 0) {
    throw "External command failed ($exitCode): $FilePath $($Arguments -join ' ')`n$text"
  }
  if (-not [string]::IsNullOrWhiteSpace($text)) {
    Write-Host $text
  }
  return $text.Trim()
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Assert-Equal {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  if ([string]$Actual -cne [string]$Expected) {
    throw "$Label mismatch. Expected '$Expected', observed '$Actual'."
  }
}

function Read-Receipt {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedDecision
  )
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root -Arguments @(
    'tools/release/collectProductionGlobalPullBackend.js',
    '--verify-receipt', $resolved,
    '--label', $ExpectedDecision
  ) | Out-Null
  $receipt = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
  Assert-Equal $receipt.decision $ExpectedDecision 'Receipt decision'
  Assert-Equal $receipt.projectId $ProjectId 'Receipt Firebase project'
  Assert-Equal $receipt.readOnly $true 'Receipt read-only boundary'
  return [pscustomobject]@{
    path = $resolved
    sha256 = Get-Sha256 $resolved
    body = $receipt
  }
}

function Invoke-Inventory {
  param([Parameter(Mandatory = $true)][string]$OutputPath)
  Invoke-ExternalText `
    -FilePath 'node' `
    -WorkingDirectory $root `
    -Arguments @(
      'functions/tools/global-pull-server-clock.mjs',
      '--project', $ProjectId,
      '--mode', 'inventory',
      '--output', $OutputPath
    ) | Out-Null
}

function Invoke-Collector {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('preflight', 'readiness')]
    [string]$Mode,
    [Parameter(Mandatory = $true)][string]$InventoryPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$BackfillPath,
    [string]$ActivationPath
  )
  $arguments = @(
    'tools/release/collectProductionGlobalPullBackend.js',
    '--mode', $Mode,
    '--repository-root', $root,
    '--project-id', $ProjectId,
    '--promotion', $promotionFile,
    '--inventory', $InventoryPath,
    '--output', $OutputPath
  )
  if ($Mode -eq 'readiness') {
    $arguments += @(
      '--source-commit', $head,
      '--backfill-receipt', $BackfillPath,
      '--activation-receipt', $ActivationPath
    )
  }
  Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
    -Arguments $arguments | Out-Null
}

if ($ProjectId -cne $ConfirmProjectId) {
  throw 'ConfirmProjectId must exactly match ProjectId for every production phase.'
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('\', '/')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\', '/')
$rootPrefix = "$root$([IO.Path]::DirectorySeparatorChar)"
if (
  $evidenceRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
  $evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
) {
  throw 'EvidenceDirectory must be outside the repository.'
}
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null

$promotionFile = if ([IO.Path]::IsPathRooted($PromotionPath)) {
  (Resolve-Path -LiteralPath $PromotionPath).Path
} else {
  (Resolve-Path -LiteralPath (Join-Path $root $PromotionPath)).Path
}
$expectedPromotionFile = (Resolve-Path -LiteralPath (Join-Path $root `
  'release/approvals/build-8-f4-production-backend-activation-promotion.json')).Path
Assert-Equal $promotionFile $expectedPromotionFile 'Production activation promotion path'

Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('fetch', '--quiet', 'origin', 'main') | Out-Null
$branch = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('branch', '--show-current')
$head = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'HEAD')
$originMain = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'origin/main')
$trackedStatus = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('status', '--porcelain', '--untracked-files=no')
if ($branch -cne 'main' -or $head -cne $originMain -or $trackedStatus) {
  throw 'Production activation requires exact tracked-clean main equal to freshly fetched origin/main.'
}
$deploymentInputStatus = Invoke-ExternalText -FilePath 'git' `
  -WorkingDirectory $root `
  -Arguments @(
    'status', '--porcelain', '--untracked-files=all', '--',
    'firebase.json',
    'firestore.rules',
    'firestore.indexes.json',
    'functions',
    'governance/global-pull-protocol-v1.json',
    'tooling/firebase-cli/package.json',
    'tooling/firebase-cli/package-lock.json'
  )
if ($deploymentInputStatus) {
  throw 'Production deployment inputs contain tracked or untracked worktree changes.'
}
$functionEnvironmentFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'functions') `
  -Force -File -Filter '.env*')
if ($functionEnvironmentFiles.Count -ne 0) {
  throw 'Production deployment requires no pre-existing Functions .env files.'
}

$runJson = Invoke-ExternalText -FilePath 'gh' -WorkingDirectory $root `
  -Arguments @(
    'run', 'view', [string]$PostMergeRunId,
    '--repo', 'abhishekvatsa/crm3_baf_ops',
    '--json', 'databaseId,headSha,conclusion,event,workflowName,jobs,url'
  )
$run = $runJson | ConvertFrom-Json
Assert-Equal $run.databaseId $PostMergeRunId 'Post-merge CI run ID'
Assert-Equal $run.headSha $head 'Post-merge CI source commit'
Assert-Equal $run.workflowName 'release-gate' 'Post-merge CI workflow'
Assert-Equal $run.event 'push' 'Post-merge CI event'
Assert-Equal $run.conclusion 'success' 'Post-merge CI conclusion'
$runJobs = @($run.jobs)
if ($runJobs.Count -ne 4 -or @($runJobs | Where-Object {
  $_.conclusion -cne 'success'
}).Count -ne 0) {
  throw 'Post-merge release-gate must contain exactly four successful jobs.'
}

$preflightInventory = Join-Path $evidenceRoot '01-global-pull-inventory-preflight.json'
$preflightReceipt = Join-Path $evidenceRoot '02-production-backend-preflight.json'
$postDeployInventory = Join-Path $evidenceRoot '03-global-pull-inventory-postdeploy.json'
$postDeployReceipt = Join-Path $evidenceRoot '04-production-backend-postdeploy.json'
$backfillReceipt = Join-Path $evidenceRoot '05-global-pull-backfill.json'
$postBackfillInventory = Join-Path $evidenceRoot '06-global-pull-inventory-postbackfill.json'
$activationReceipt = Join-Path $evidenceRoot '07-global-pull-activation.json'
$postActivationInventory = Join-Path $evidenceRoot '08-global-pull-inventory-postactivation.json'
$readinessReceipt = Join-Path $evidenceRoot '09-build8-f4-backend-readiness.json'

switch ($Phase) {
  'Preflight' {
    Invoke-Inventory -OutputPath $preflightInventory
    Invoke-Collector -Mode 'preflight' -InventoryPath $preflightInventory `
      -OutputPath $preflightReceipt
    $receipt = Read-Receipt -Path $preflightReceipt `
      -ExpectedDecision 'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT'
    Write-Host "Preflight receipt: $($receipt.path)"
    Write-Host "Preflight SHA-256: $($receipt.sha256)"
  }

  'Deploy' {
    if ([string]::IsNullOrWhiteSpace($PreflightReceiptPath)) {
      throw 'Deploy requires PreflightReceiptPath.'
    }
    $prior = Read-Receipt -Path $PreflightReceiptPath `
      -ExpectedDecision 'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT'
    Assert-Equal $prior.body.source.commit $head 'Preflight source commit'
    Assert-Equal $prior.body.deploymentPromotionSha256 `
      (Get-Sha256 $promotionFile) 'Preflight deployment promotion'
    Assert-Equal $prior.body.checks.runtimeContractAbsent $true `
      'Preflight runtime-contract absence'

    Invoke-ExternalText -FilePath 'npm.cmd' -WorkingDirectory $root `
      -Arguments @('--prefix', 'functions', 'run', 'build') | Out-Null

    $firebaseBin = Join-Path $root `
      'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
      -Arguments @(
        $firebaseBin,
        'deploy',
        '--only', 'firestore:rules',
        '--project', $ProjectId,
        '--non-interactive'
      ) | Out-Null

    $parameterFile = Join-Path $root "functions/.env.$ProjectId"
    if (Test-Path -LiteralPath $parameterFile) {
      throw "Refusing to overwrite existing deployment environment file: $parameterFile"
    }
    try {
      [IO.File]::WriteAllText(
        $parameterFile,
        "CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false`n",
        [Text.UTF8Encoding]::new($false)
      )
      Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
        -Arguments @(
          $firebaseBin,
          'deploy',
          '--only',
          'functions:beginGlobalPullRun,functions:stampGlobalPullServerClock',
          '--project', $ProjectId,
          '--non-interactive'
        ) | Out-Null
    } finally {
      if (Test-Path -LiteralPath $parameterFile) {
        Remove-Item -LiteralPath $parameterFile -Force
      }
    }

    $trackedAfterDeploy = Invoke-ExternalText -FilePath 'git' `
      -WorkingDirectory $root `
      -Arguments @('status', '--porcelain', '--untracked-files=no')
    if ($trackedAfterDeploy) {
      throw 'Tracked source changed during the bounded deployment.'
    }
    Invoke-Inventory -OutputPath $postDeployInventory
    Invoke-Collector -Mode 'preflight' -InventoryPath $postDeployInventory `
      -OutputPath $postDeployReceipt
    $receipt = Read-Receipt -Path $postDeployReceipt `
      -ExpectedDecision 'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT'
    Assert-Equal $receipt.body.live.firestoreRulesMatchesSource $true `
      'Post-deploy Firestore Rules parity'
    Assert-Equal $receipt.body.live.firestoreIndexesMatchSource $true `
      'Post-deploy Firestore index parity'
    Assert-Equal $receipt.body.live.requiredFunctionsActive $true `
      'Post-deploy required Function readiness'
    Write-Host "Post-deploy receipt: $($receipt.path)"
    Write-Host "Post-deploy SHA-256: $($receipt.sha256)"
  }

  'Backfill' {
    if ([string]::IsNullOrWhiteSpace($PostDeployReceiptPath)) {
      throw 'Backfill requires PostDeployReceiptPath.'
    }
    $prior = Read-Receipt -Path $PostDeployReceiptPath `
      -ExpectedDecision 'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT'
    Assert-Equal $prior.body.source.commit $head 'Post-deploy source commit'
    Assert-Equal $prior.body.live.firestoreRulesMatchesSource $true `
      'Post-deploy Firestore Rules parity'
    Assert-Equal $prior.body.live.firestoreIndexesMatchSource $true `
      'Post-deploy Firestore index parity'
    Assert-Equal $prior.body.live.requiredFunctionsActive $true `
      'Post-deploy required Function readiness'
    Assert-Equal $prior.body.checks.runtimeContractAbsent $true `
      'Post-deploy runtime-contract absence'

    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
      -Arguments @(
        'functions/tools/global-pull-server-clock.mjs',
        '--project', $ProjectId,
        '--confirm-project', $ConfirmProjectId,
        '--mode', 'backfill',
        '--operator', $Operator,
        '--source-commit', $head,
        '--output', $backfillReceipt
      ) | Out-Null
    Invoke-Inventory -OutputPath $postBackfillInventory
    $inventory = Get-Content -LiteralPath $postBackfillInventory -Raw |
      ConvertFrom-Json
    Assert-Equal $inventory.inventory.missing 0 'Post-backfill missing count'
    Assert-Equal $inventory.inventory.malformed 0 'Post-backfill malformed count'
    Write-Host "Backfill receipt: $backfillReceipt"
    Write-Host "Backfill SHA-256: $(Get-Sha256 $backfillReceipt)"
    Write-Host "Post-backfill inventory: $postBackfillInventory"
    Write-Host "Post-backfill inventory SHA-256: $(Get-Sha256 $postBackfillInventory)"
  }

  'Activate' {
    foreach ($required in @(
      $PostDeployReceiptPath,
      $BackfillReceiptPath,
      $PostBackfillInventoryPath
    )) {
      if ([string]::IsNullOrWhiteSpace($required)) {
        throw 'Activate requires PostDeployReceiptPath, BackfillReceiptPath and PostBackfillInventoryPath.'
      }
    }
    $postDeploy = Read-Receipt -Path $PostDeployReceiptPath `
      -ExpectedDecision 'PASS_BUILD8_PRODUCTION_GLOBAL_PULL_ACTIVATION_PREFLIGHT'
    Assert-Equal $postDeploy.body.source.commit $head 'Post-deploy source commit'
    Assert-Equal $postDeploy.body.live.firestoreRulesMatchesSource $true `
      'Pre-activation Firestore Rules parity'
    Assert-Equal $postDeploy.body.live.firestoreIndexesMatchSource $true `
      'Pre-activation Firestore index parity'
    Assert-Equal $postDeploy.body.live.requiredFunctionsActive $true `
      'Pre-activation required Function readiness'
    Assert-Equal $postDeploy.body.checks.runtimeContractAbsent $true `
      'Pre-activation runtime-contract absence'

    $backfill = Get-Content -LiteralPath $BackfillReceiptPath -Raw |
      ConvertFrom-Json
    Assert-Equal $backfill.receiptType `
      'GLOBAL_PULL_SERVER_CLOCK_BACKFILL_VERIFIED' 'Backfill receipt type'
    Assert-Equal $backfill.projectId $ProjectId 'Backfill project'
    Assert-Equal $backfill.sourceCommit $head 'Backfill source commit'
    Assert-Equal $backfill.after.missing 0 'Backfill receipt missing count'
    Assert-Equal $backfill.after.malformed 0 'Backfill receipt malformed count'

    $postBackfill = Get-Content -LiteralPath $PostBackfillInventoryPath -Raw |
      ConvertFrom-Json
    Assert-Equal $postBackfill.inventory.missing 0 `
      'Pre-activation inventory missing count'
    Assert-Equal $postBackfill.inventory.malformed 0 `
      'Pre-activation inventory malformed count'

    Invoke-ExternalText -FilePath 'node' -WorkingDirectory $root `
      -Arguments @(
        'functions/tools/global-pull-server-clock.mjs',
        '--project', $ProjectId,
        '--confirm-project', $ConfirmProjectId,
        '--mode', 'activate',
        '--operator', $Operator,
        '--source-commit', $head,
        '--backfill-receipt', (Resolve-Path -LiteralPath $BackfillReceiptPath).Path,
        '--output', $activationReceipt
      ) | Out-Null
    Invoke-Inventory -OutputPath $postActivationInventory
    Invoke-Collector -Mode 'readiness' `
      -InventoryPath $postActivationInventory `
      -BackfillPath (Resolve-Path -LiteralPath $BackfillReceiptPath).Path `
      -ActivationPath $activationReceipt `
      -OutputPath $readinessReceipt
    $receipt = Read-Receipt -Path $readinessReceipt `
      -ExpectedDecision 'PASS_BUILD8_F4_BACKEND_READY'
    Assert-Equal $receipt.body.live.globalPullContractActive $true `
      'Activated global-pull contract'
    Assert-Equal $receipt.body.live.globalPullInventoryZeroGap $true `
      'Activated global-pull zero-gap inventory'
    Write-Host "Activation receipt: $activationReceipt"
    Write-Host "Activation SHA-256: $(Get-Sha256 $activationReceipt)"
    Write-Host "Backend-readiness receipt: $($receipt.path)"
    Write-Host "Backend-readiness SHA-256: $($receipt.sha256)"
  }
}
