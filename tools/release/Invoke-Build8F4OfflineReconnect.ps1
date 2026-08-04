[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepositoryRoot,

  [Parameter(Mandatory = $true)]
  [string]$GovernedPackagePath,

  [Parameter(Mandatory = $true)]
  [string]$DeviceSerial,

  [Parameter(Mandatory = $true)]
  [string]$EvidenceDirectory,

  [Parameter(Mandatory = $true)]
  [string]$PriorSyncReceiptPath,

  [Parameter(Mandatory = $true)]
  [ValidateRange(1, [long]::MaxValue)]
  [long]$PostMergeRunId,

  [string]$PromotionPath =
    'release/approvals/build-8-f4-offline-reconnect-promotion.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory = $true)][string]$Value)

  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))
    return ([BitConverter]::ToString($hash)).Replace('-', '')
  } finally {
    $algorithm.Dispose()
  }
}

function Write-NewUtf8Json {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )

  $text = ($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($text)
  $stream = [IO.File]::Open(
    $Path,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
  )
  try {
    $stream.Write($bytes, 0, $bytes.Length)
  } finally {
    $stream.Dispose()
  }
}

function Invoke-ExternalText {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$WorkingDirectory,
    [switch]$AllowFailure
  )

  $prior = Get-Location
  $priorErrorActionPreference = $ErrorActionPreference
  $output = ''
  $exitCode = 1
  try {
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
      Set-Location -LiteralPath $WorkingDirectory
    }
    # Native tools can write progress to stderr even when they succeed.
    $ErrorActionPreference = 'Continue'
    $output = & $FilePath @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $priorErrorActionPreference
    Set-Location -LiteralPath $prior
  }
  if (-not $AllowFailure -and $exitCode -ne 0) {
    throw "External command failed ($exitCode): $FilePath $($Arguments -join ' ')"
  }
  return [pscustomobject]@{
    exitCode = $exitCode
    output = $output.Trim()
  }
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

function Assert-OneOf {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)][object[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not ($Expected -ccontains $Actual)) {
    throw "$Label mismatch. Expected one of '$($Expected -join ', ')', observed '$Actual'."
  }
}

function Get-AndroidTool {
  param(
    [Parameter(Mandatory = $true)][string]$SdkRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $candidate = Join-Path $SdkRoot $RelativePath
  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Missing Android SDK tool: $candidate"
  }
  return (Resolve-Path -LiteralPath $candidate).Path
}

function Get-DeviceProperty {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$Name
  )

  return (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'getprop', $Name
  )).output
}

function Get-UiEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $remotePath = "/sdcard/crm3-$Label-window.xml"
  $localPath = Join-Path $EvidenceRoot ".$Label-window.xml"
  try {
    $captured = $false
    for ($attempt = 1; $attempt -le 3 -and -not $captured; $attempt++) {
      $dump = Invoke-ExternalText -FilePath $Adb -Arguments @(
        '-s', $Serial, 'shell', 'uiautomator', 'dump', $remotePath
      ) -AllowFailure
      $pull = Invoke-ExternalText -FilePath $Adb -Arguments @(
        '-s', $Serial, 'pull', $remotePath, $localPath
      ) -AllowFailure
      $captured = $dump.exitCode -eq 0 -and
        $pull.exitCode -eq 0 -and
        (Test-Path -LiteralPath $localPath -PathType Leaf)
      if (-not $captured) {
        Start-Sleep -Seconds 2
      }
    }
    if (-not $captured) {
      throw 'UI hierarchy capture failed.'
    }
    return [pscustomobject]@{
      sha256 = Get-Sha256 $localPath
      text = Get-Content -LiteralPath $localPath -Raw
    }
  } finally {
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'rm', '-f', $remotePath
    ) -AllowFailure
    if (Test-Path -LiteralPath $localPath) {
      Remove-Item -LiteralPath $localPath -Force
    }
  }
}

function Get-NodeCenter {
  param(
    [Parameter(Mandatory = $true)][string]$UiText,
    [Parameter(Mandatory = $true)][string]$XPath,
    [Parameter(Mandatory = $true)][string]$Label
  )

  [xml]$document = $UiText
  $node = $document.SelectSingleNode($XPath)
  if ($null -eq $node) {
    throw "Could not find UI control: $Label"
  }
  $match = [regex]::Match(
    [string]$node.bounds,
    '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'
  )
  if (-not $match.Success) {
    throw "$Label exposes malformed bounds."
  }
  return [pscustomobject]@{
    x = [int](([int]$match.Groups[1].Value + [int]$match.Groups[3].Value) / 2)
    y = [int](([int]$match.Groups[2].Value + [int]$match.Groups[4].Value) / 2)
  }
}

function Invoke-UiTap {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)]$Center
  )

  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'tap',
    [string]$Center.x, [string]$Center.y
  )
}

function Move-ToApprovedHome {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot
  )

  $required = @(
    'Home',
    'Issues',
    'Work',
    'Directives',
    'More',
    'Raise issue',
    'Needs attention'
  )
  $forbidden = @(
    'Sign in with Google',
    'Awaiting Approval',
    'User profile error',
    'permission-denied',
    'Sign-in failed'
  )
  for ($attempt = 0; $attempt -le 8; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "build8-home-$attempt"
    $forbiddenCount = @($forbidden | Where-Object { $ui.text.Contains($_) }).Count
    if ($forbiddenCount -ne 0) {
      throw 'The approved session exposes a forbidden authentication or authority marker.'
    }
    $present = @($required | Where-Object { $ui.text.Contains($_) }).Count
    if ($present -eq $required.Count) {
      return [pscustomobject]@{
        uiSha256 = $ui.sha256
        requiredMarkerCount = $present
        forbiddenMarkerCount = 0
      }
    }
    if ($ui.text.Contains('Home')) {
      try {
        $center = Get-NodeCenter `
          -UiText $ui.text `
          -XPath "//node[(@text='Home' or contains(@content-desc,'Home')) and @clickable='true']" `
          -Label 'Home'
        Invoke-UiTap -Adb $Adb -Serial $Serial -Center $center
        Start-Sleep -Seconds 1
        continue
      } catch {
        # Unwind a pushed route below when Home text is not a navigation node.
      }
    }
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'input', 'keyevent', '4'
    )
    Start-Sleep -Seconds 1
  }
  throw 'The role-appropriate Home surface could not be reached.'
}

function Invoke-UiMarkerTap {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string[]]$Markers,
    [Parameter(Mandatory = $true)][string]$XPath,
    [int]$ScrollAttempts = 0
  )

  for ($attempt = 0; $attempt -le $ScrollAttempts; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-$attempt"
    $visible = $Markers | Where-Object { $ui.text.Contains($_) } |
      Select-Object -First 1
    if ($null -ne $visible) {
      $center = Get-NodeCenter -UiText $ui.text -XPath $XPath -Label $visible
      Invoke-UiTap -Adb $Adb -Serial $Serial -Center $center
      return $ui.sha256
    }
    if ($attempt -lt $ScrollAttempts) {
      $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
        '-s', $Serial, 'shell', 'input', 'swipe',
        '540', '1800', '540', '650', '450'
      )
      Start-Sleep -Seconds 1
    }
  }
  throw "Could not reach UI control: $($Markers -join ' or ')"
}

function Get-LocalDiagnosticsEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $null = Move-ToApprovedHome -Adb $Adb -Serial $Serial -EvidenceRoot $EvidenceRoot
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-more" `
    -Markers @('More') `
    -XPath "//node[(@text='More' or contains(@content-desc,'More')) and @clickable='true']"
  Start-Sleep -Seconds 1
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-diagnostics-tile" `
    -Markers @('Support diagnostics') `
    -XPath "//node[(@text='Support diagnostics' or contains(@content-desc,'Support diagnostics')) and @clickable='true']" `
    -ScrollAttempts 8
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-diagnostics"
    if ($ui.text.Contains('Local diagnostics inventory')) {
      break
    }
    Start-Sleep -Seconds 1
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  if (-not $ui.text.Contains('Local diagnostics inventory')) {
    throw 'Local diagnostics inventory was not reached.'
  }
  $unsynced = [regex]::Match($ui.text, '(\d+) unsynced rows')
  $rejections = [regex]::Match($ui.text, '(\d+) unresolved rejections')
  if (-not $unsynced.Success -or -not $rejections.Success) {
    throw 'Local diagnostics counters were not available.'
  }
  $result = [pscustomobject]@{
    uiSha256 = $ui.sha256
    unsyncedRows = [int]$unsynced.Groups[1].Value
    unresolvedRejections = [int]$rejections.Groups[1].Value
  }
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'keyevent', '4'
  )
  Start-Sleep -Seconds 1
  $null = Move-ToApprovedHome -Adb $Adb -Serial $Serial -EvidenceRoot $EvidenceRoot
  return $result
}

function Wait-ManualSyncOutcome {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds
  )

  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label $Label
    if ($ui.text.Contains('Manual sync completed.')) {
      return [pscustomobject]@{
        outcome = 'SUCCESS'
        outcomeUiSha256 = $ui.sha256
      }
    }
    if ($ui.text.Contains('Manual sync failed:')) {
      return [pscustomobject]@{
        outcome = 'FAILED'
        outcomeUiSha256 = $ui.sha256
      }
    }
    if ($ui.text.Contains('Manual sync is already running or could not complete.')) {
      return [pscustomobject]@{
        outcome = 'NOT_COMPLETED'
        outcomeUiSha256 = $ui.sha256
      }
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  return [pscustomobject]@{
    outcome = 'TIMEOUT_WITHOUT_SUCCESS_MARKER'
    outcomeUiSha256 = $ui.sha256
  }
}

function Invoke-ManualSyncEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds
  )

  $null = Move-ToApprovedHome -Adb $Adb -Serial $Serial -EvidenceRoot $EvidenceRoot
  $readyDeadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
  do {
    $before = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-ready"
    $stale = $before.text.Contains('Manual sync completed.') -or
      $before.text.Contains('Manual sync failed:') -or
      $before.text.Contains('Manual sync is already running or could not complete.')
    if (-not $stale) { break }
    Start-Sleep -Seconds 1
  } while ([DateTimeOffset]::UtcNow -lt $readyDeadline)
  if ($stale) {
    throw 'A stale manual-sync result marker did not clear.'
  }
  $triggerSha = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-trigger" `
    -Markers @('Sync now', 'Retry sync') `
    -XPath "//node[(@text='Sync now' or @text='Retry sync' or contains(@content-desc,'Sync now') or contains(@content-desc,'Retry sync')) and @clickable='true']"
  $outcome = Wait-ManualSyncOutcome `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-outcome" `
    -TimeoutSeconds $TimeoutSeconds
  return [pscustomobject]@{
    outcome = $outcome.outcome
    triggerUiSha256 = $triggerSha
    outcomeUiSha256 = $outcome.outcomeUiSha256
  }
}

function Get-TransportState {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial
  )

  $wifi = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'settings', 'get', 'global', 'wifi_on'
  )).output
  $mobile = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'settings', 'get', 'global', 'mobile_data'
  )).output
  $airplane = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'settings', 'get', 'global', 'airplane_mode_on'
  )).output
  Assert-OneOf -Actual $wifi -Expected @('0', '1') -Label 'Wi-Fi setting'
  Assert-OneOf `
    -Actual $mobile `
    -Expected @('0', '1') `
    -Label 'Mobile-data setting'
  Assert-OneOf `
    -Actual $airplane `
    -Expected @('0', '1') `
    -Label 'Airplane-mode setting'
  return [pscustomobject]@{
    wifiOn = [int]$wifi
    mobileDataOn = [int]$mobile
    airplaneModeOn = [int]$airplane
  }
}

function Set-TransportState {
  param(
    [Parameter(Mandatory = $true)][string]$Adb,
    [Parameter(Mandatory = $true)][string]$Serial,
    [Parameter(Mandatory = $true)][int]$WifiOn,
    [Parameter(Mandatory = $true)][int]$MobileDataOn
  )

  Assert-OneOf `
    -Actual $WifiOn `
    -Expected @(0, 1) `
    -Label 'Requested Wi-Fi setting'
  Assert-OneOf `
    -Actual $MobileDataOn `
    -Expected @(0, 1) `
    -Label 'Requested mobile-data setting'
  $wifiAction = if ($WifiOn -eq 1) { 'enable' } else { 'disable' }
  $mobileAction = if ($MobileDataOn -eq 1) { 'enable' } else { 'disable' }
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'svc', 'wifi', $wifiAction
  )
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'svc', 'data', $mobileAction
  )
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
  do {
    $observed = Get-TransportState -Adb $Adb -Serial $Serial
    if ($observed.wifiOn -eq $WifiOn -and
        $observed.mobileDataOn -eq $MobileDataOn) {
      return $observed
    }
    Start-Sleep -Seconds 1
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  throw 'Device transport state did not reach the requested values.'
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('\', '/')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\', '/')
$rootPrefix = "$root$([IO.Path]::DirectorySeparatorChar)"
if ($evidenceRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
    $evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'EvidenceDirectory must be outside the repository.'
}
if (Test-Path -LiteralPath $evidenceRoot) {
  if (@(Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
    throw 'EvidenceDirectory must be new or empty.'
  }
} else {
  New-Item -ItemType Directory -Path $evidenceRoot | Out-Null
}

$promotionFile = if ([IO.Path]::IsPathRooted($PromotionPath)) {
  (Resolve-Path -LiteralPath $PromotionPath).Path
} else {
  (Resolve-Path -LiteralPath (Join-Path $root $PromotionPath)).Path
}
$expectedPromotionFile = (Resolve-Path -LiteralPath (Join-Path $root `
  'release/approvals/build-8-f4-offline-reconnect-promotion.json')).Path
Assert-Equal $promotionFile $expectedPromotionFile `
  'Offline/reconnect promotion path'
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json
Assert-Equal $promotion.approved $true 'Promotion approval'
Assert-Equal $promotion.approvalClass `
  'CONTROLLED_EXACT_TARGET_BUILD8_OFFLINE_RECONNECT' `
  'Promotion class'
Assert-Equal $promotion.programmeBoundary.stage2dF4ClosureAuthorized $false `
  'F4 closure boundary'
Assert-Equal $promotion.programmeBoundary.pilotHandoutAuthorized $false `
  'Pilot handout boundary'
Assert-Equal $promotion.programmeBoundary.offlineReconnectAuthorized $true `
  'Offline/reconnect phase authority'
Assert-Equal $promotion.programmeBoundary.weakNetworkAuthorized $false `
  'Weak-network boundary'

$null = Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root -Arguments @(
  'fetch', '--quiet', 'origin', 'main', '--tags'
)
$branch = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('branch', '--show-current')).output
$head = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'HEAD')).output
$originMain = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', 'origin/main')).output
$trackedStatus = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('status', '--porcelain', '--untracked-files=no')).output
if ($branch -cne 'main' -or $head -cne $originMain -or $trackedStatus) {
  throw 'Offline/reconnect requires exact tracked-clean main equal to origin/main.'
}
if ($head -ceq $promotion.approvalAuthority.baselineCommit) {
  throw 'The offline/reconnect promotion is not effective on its baseline.'
}

$run = ((Invoke-ExternalText -FilePath 'gh' -WorkingDirectory $root -Arguments @(
  'run', 'view', [string]$PostMergeRunId,
  '--repo', 'abhishekvatsa/crm3_baf_ops',
  '--json', 'databaseId,headSha,conclusion,event,workflowName,jobs,url'
)).output | ConvertFrom-Json)
Assert-Equal $run.databaseId $PostMergeRunId 'Post-merge run ID'
Assert-Equal $run.headSha $head 'Post-merge run source'
Assert-Equal $run.workflowName 'release-gate' 'Post-merge workflow'
Assert-Equal $run.event 'push' 'Post-merge run event'
Assert-Equal $run.conclusion 'success' 'Post-merge run conclusion'
if (@($run.jobs).Count -ne 4 -or @($run.jobs | Where-Object {
  $_.conclusion -cne 'success'
}).Count -ne 0) {
  throw 'Post-merge release-gate must contain exactly four successful jobs.'
}

$priorSyncReceiptFile = (Resolve-Path -LiteralPath $PriorSyncReceiptPath).Path
if ($priorSyncReceiptFile.Equals(
      $root, [StringComparison]::OrdinalIgnoreCase
    ) -or $priorSyncReceiptFile.StartsWith(
      $rootPrefix, [StringComparison]::OrdinalIgnoreCase
    )) {
  throw 'PriorSyncReceiptPath must be outside the repository.'
}
$syncAdjudicationFile = (Resolve-Path -LiteralPath (
  Join-Path $root $promotion.syncAuthority.adjudicationPath
)).Path
Assert-Equal (Get-Sha256 $syncAdjudicationFile) `
  $promotion.syncAuthority.adjudicationSha256 `
  'Sync-marker adjudication SHA-256'
Assert-Equal (Get-Sha256 $priorSyncReceiptFile) `
  $promotion.syncAuthority.externalReceiptSha256 `
  'External sync-marker receipt SHA-256'
Assert-Equal (Get-Item -LiteralPath $priorSyncReceiptFile).Length `
  $promotion.syncAuthority.externalReceiptBytes `
  'External sync-marker receipt bytes'
$syncAdjudication = Get-Content -LiteralPath $syncAdjudicationFile -Raw |
  ConvertFrom-Json
$priorSyncReceipt = Get-Content -LiteralPath $priorSyncReceiptFile -Raw |
  ConvertFrom-Json
Assert-Equal $syncAdjudication.decision `
  'PASS_BUILD8_F4_SYNC_MARKER_ADJUDICATED' `
  'Sync-marker adjudication decision'
Assert-Equal $syncAdjudication.externalReceipt.sha256 `
  $promotion.syncAuthority.externalReceiptSha256 `
  'Adjudicated external receipt SHA-256'
Assert-Equal $priorSyncReceipt.evidenceType `
  'build-8-f4-post-activation-physical-sync-retry' `
  'External sync-marker evidence type'
Assert-Equal $priorSyncReceipt.decision `
  'PASS_BUILD8_F4_POST_ACTIVATION_SYNC_MARKER' `
  'External sync-marker decision'
Assert-Equal $priorSyncReceipt.source.trackedClean $true `
  'External sync-marker clean-source flag'
Assert-Equal $priorSyncReceipt.backend.decision `
  'PASS_BUILD8_F4_BACKEND_READY' `
  'External sync-marker backend decision'
Assert-Equal $priorSyncReceipt.backend.inventoryMissing 0 `
  'External sync-marker missing-watermark count'
Assert-Equal $priorSyncReceipt.backend.inventoryMalformed 0 `
  'External sync-marker malformed-watermark count'
Assert-Equal $priorSyncReceipt.artifact.installedApkSha256 `
  $promotion.artifactAuthority.apk.sha256 `
  'External sync-marker installed APK SHA-256'
Assert-Equal $priorSyncReceipt.artifact.versionCode `
  $promotion.artifactAuthority.apk.versionCode `
  'External sync-marker version code'
Assert-Equal $priorSyncReceipt.session.approvedHomeReached $true `
  'External sync-marker approved-session flag'
Assert-Equal $priorSyncReceipt.session.forbiddenMarkerCount 0 `
  'External sync-marker forbidden UI count'
Assert-Equal $priorSyncReceipt.diagnosticsBefore.unsyncedRows 0 `
  'External sync-marker pre-run pending writes'
Assert-Equal $priorSyncReceipt.manualSync.outcome 'SUCCESS' `
  'External sync-marker manual-sync outcome'
Assert-Equal $priorSyncReceipt.diagnosticsAfter.unsyncedRows 0 `
  'External sync-marker post-run pending writes'
Assert-Equal $priorSyncReceipt.mutationBoundary.networkStateChanged $false `
  'External sync-marker network boundary'
Assert-Equal `
  $priorSyncReceipt.mutationBoundary.authenticationSessionChanged `
  $false `
  'External sync-marker authentication boundary'
Assert-Equal $priorSyncReceipt.programmeBoundary.stage2dF4Status 'OPEN' `
  'External sync-marker F4 status'
Assert-Equal `
  $priorSyncReceipt.programmeBoundary.stage2dF4ClosureAuthorized `
  $false `
  'External sync-marker closure boundary'

$backendFile = (Resolve-Path -LiteralPath (
  Join-Path $root $promotion.backendAuthority.evidencePath
)).Path
$finalizationFile = (Resolve-Path -LiteralPath (
  Join-Path $root $promotion.artifactAuthority.finalizationEvidencePath
)).Path
Assert-Equal (Get-Sha256 $backendFile) `
  $promotion.backendAuthority.evidenceSha256 'Backend evidence SHA-256'
Assert-Equal (Get-Sha256 $finalizationFile) `
  $promotion.artifactAuthority.finalizationEvidenceSha256 `
  'Build finalization evidence SHA-256'
$backend = Get-Content -LiteralPath $backendFile -Raw | ConvertFrom-Json
$finalization = Get-Content -LiteralPath $finalizationFile -Raw | ConvertFrom-Json
Assert-Equal $backend.decision $promotion.backendAuthority.decision `
  'Backend readiness decision'
Assert-Equal $backend.liveReadback.globalPullContractState 'ACTIVE' `
  'Global-pull contract state'
Assert-Equal $backend.liveReadback.inventoryMissing 0 `
  'Backend missing-watermark count'
Assert-Equal $backend.liveReadback.inventoryMalformed 0 `
  'Backend malformed-watermark count'
Assert-Equal $finalization.status 'passed-non-distributable' `
  'Build finalization status'
Assert-Equal $finalization.sourceAuthority.commit `
  $promotion.artifactAuthority.buildSourceCommit 'Build source commit'
Assert-Equal $finalization.governedPackage.apkSha256 `
  $promotion.artifactAuthority.apk.sha256 'Finalized APK SHA-256'

$builtTagObject = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-parse', "refs/tags/$($promotion.artifactAuthority.remoteBuiltTag)")).output
Assert-Equal $builtTagObject $promotion.artifactAuthority.remoteBuiltTagObjectSha `
  'Remote built-tag object'
$builtTagCommit = (Invoke-ExternalText -FilePath 'git' -WorkingDirectory $root `
  -Arguments @('rev-list', '-n', '1', $promotion.artifactAuthority.remoteBuiltTag)).output
Assert-Equal $builtTagCommit $promotion.artifactAuthority.buildSourceCommit `
  'Remote built-tag commit'

$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
Assert-Equal (Get-Sha256 $packageFile) `
  $promotion.artifactAuthority.governedPackage.sha256 `
  'Governed package SHA-256'
$temporaryApk = Join-Path $evidenceRoot '.governed-build8.apk'
$archive = [IO.Compression.ZipFile]::OpenRead($packageFile)
try {
  $entries = @($archive.Entries | Where-Object {
    $_.FullName -ceq $promotion.artifactAuthority.governedPackage.apkEntryName
  })
  if ($entries.Count -ne 1) {
    throw 'Governed package does not contain one exact Build 8 APK entry.'
  }
  [IO.Compression.ZipFileExtensions]::ExtractToFile(
    $entries[0], $temporaryApk, $false
  )
} finally {
  $archive.Dispose()
}
Assert-Equal (Get-Sha256 $temporaryApk) `
  $promotion.artifactAuthority.apk.sha256 'Embedded APK SHA-256'
Assert-Equal (Get-Item -LiteralPath $temporaryApk).Length `
  $promotion.artifactAuthority.apk.bytes 'Embedded APK bytes'

$sdkRoot = if ($env:ANDROID_SDK_ROOT) {
  $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
  $env:ANDROID_HOME
} else {
  Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}
$adb = Get-AndroidTool $sdkRoot 'platform-tools\adb.exe'
$aapt = Get-AndroidTool $sdkRoot 'build-tools\36.0.0\aapt.exe'
$apksigner = Get-AndroidTool $sdkRoot 'build-tools\36.0.0\apksigner.bat'

$badging = (Invoke-ExternalText -FilePath $aapt -Arguments @(
  'dump', 'badging', $temporaryApk
)).output
if ($badging -notmatch "package: name='$([regex]::Escape(
    $promotion.artifactAuthority.apk.applicationId
  ))'.*versionCode='$($promotion.artifactAuthority.apk.versionCode)'") {
  throw 'Build 8 APK package or version code differs from the promotion.'
}
if ($badging -match '(?m)^application-debuggable') {
  throw 'Build 8 APK is unexpectedly debuggable.'
}
$signer = (Invoke-ExternalText -FilePath $apksigner -Arguments @(
  'verify', '--print-certs', $temporaryApk
)).output.Replace(':', '').ToUpperInvariant()
if (-not $signer.Contains($promotion.artifactAuthority.apk.certificateSha256)) {
  throw 'Build 8 APK signer differs from the promotion.'
}

$devices = (Invoke-ExternalText -FilePath $adb -Arguments @('devices')).output
$deviceLines = @($devices -split "`n" | Where-Object { $_ -match "\tdevice\s*$" })
if ($deviceLines.Count -ne 1) {
  throw 'Exactly one authorized Android device is required.'
}
Assert-Equal (Get-TextSha256 $DeviceSerial) `
  $promotion.targetAuthority.adbSerialSha256 'Hashed ADB target'
Assert-Equal (Get-TextSha256 (Get-DeviceProperty $adb $DeviceSerial `
  'ro.build.fingerprint')) $promotion.targetAuthority.buildFingerprintSha256 `
  'Hashed build fingerprint'
Assert-Equal (Get-DeviceProperty $adb $DeviceSerial 'ro.kernel.qemu') '0' `
  'Physical-device marker'
Assert-Equal (Get-DeviceProperty $adb $DeviceSerial 'ro.product.model') `
  $promotion.targetAuthority.model 'Target model'
Assert-Equal (Get-DeviceProperty $adb $DeviceSerial 'ro.build.version.sdk') `
  $promotion.targetAuthority.apiLevel 'Target API level'
$gms = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', 'com.google.android.gms'
)).output
if (-not $gms.StartsWith('package:')) {
  throw 'The bound target no longer exposes Google Play Services.'
}

$applicationId = $promotion.artifactAuthority.apk.applicationId
$paths = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId
)).output
$basePaths = @($paths -split "`n" | Where-Object {
  $_.StartsWith('package:') -and $_.Contains('/base.apk')
})
if ($basePaths.Count -ne 1) {
  throw 'The installed Build 8 base APK path is not unique.'
}
$installedApk = Join-Path $evidenceRoot '.installed-build8.apk'
$null = Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'pull',
  $basePaths[0].Substring('package:'.Length), $installedApk
)
Assert-Equal (Get-Sha256 $installedApk) `
  $promotion.artifactAuthority.apk.sha256 'Installed APK SHA-256'
$packageDump = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'dumpsys', 'package', $applicationId
)).output
$versionCode = [regex]::Match($packageDump, 'versionCode=(\d+)').Groups[1].Value
$firstInstallTime = [regex]::Match(
  $packageDump, 'firstInstallTime=([^\r\n]+)'
).Groups[1].Value.Trim()
$lastUpdateTime = [regex]::Match(
  $packageDump, 'lastUpdateTime=([^\r\n]+)'
).Groups[1].Value.Trim()
Assert-Equal $versionCode $promotion.artifactAuthority.apk.versionCode `
  'Installed version code'
Assert-Equal $firstInstallTime `
  $promotion.observedPrePromotionState.firstInstallTime `
  'Preserved first-install time'
Assert-Equal $lastUpdateTime `
  $promotion.observedPrePromotionState.lastUpdateTime `
  'Preserved last-update time'

$initialTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
Assert-Equal $initialTransport.airplaneModeOn 0 `
  'Pre-offline airplane-mode setting'
if ($initialTransport.wifiOn -eq 0 -and
    $initialTransport.mobileDataOn -eq 0) {
  throw 'Offline/reconnect requires an initially enabled network transport.'
}

$receiptPath = Join-Path $evidenceRoot 'build8-f4-offline-reconnect-receipt.json'
$failureReceiptPath = Join-Path $evidenceRoot `
  'build8-f4-offline-reconnect-failure-receipt.json'
if ((Test-Path -LiteralPath $receiptPath) -or
    (Test-Path -LiteralPath $failureReceiptPath)) {
  throw 'Offline/reconnect refuses to replace existing phase evidence.'
}

$startedAt = [DateTimeOffset]::UtcNow.ToString('o')
$homeEvidence = $null
$before = $null
$offlineHome = $null
$offlineSync = $null
$offlineFinalUi = $null
$restoredTransport = $null
$postReconnect = $null
$after = $null
$phaseError = $null
$restorationError = $null
$transportDisabledAt = $null
$transportRestoreStartedAt = $null
$transportDisabledDurationSeconds = 0.0
try {
  $null = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $applicationId, '-c', 'android.intent.category.LAUNCHER', '1'
  )
  Start-Sleep -Seconds 3
  $homeEvidence = Move-ToApprovedHome `
    -Adb $adb -Serial $DeviceSerial -EvidenceRoot $evidenceRoot
  $before = Get-LocalDiagnosticsEvidence `
    -Adb $adb -Serial $DeviceSerial -EvidenceRoot $evidenceRoot `
    -Label 'build8-offline-before'
  Assert-Equal $before.unsyncedRows 0 `
    'Pre-offline pending local business writes'
  Assert-Equal $before.unresolvedRejections 0 `
    'Pre-offline unresolved local rejections'

  try {
    $null = Set-TransportState `
      -Adb $adb `
      -Serial $DeviceSerial `
      -WifiOn 0 `
      -MobileDataOn 0
    $transportDisabledAt = [DateTimeOffset]::UtcNow
    Start-Sleep -Seconds 5
    $offlineHome = Move-ToApprovedHome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot
    $offlineSync = Invoke-ManualSyncEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build8-offline-sync' `
      -TimeoutSeconds 20
    if ($offlineSync.outcome -ceq 'SUCCESS') {
      $phaseError = 'FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED'
    }
    $offlineFinalUi = Get-UiEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build8-offline-final-disconnected'
    if ($offlineFinalUi.text.Contains('Manual sync completed.')) {
      $phaseError = 'FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED'
    }
  } catch {
    $phaseError = 'OFFLINE_OBSERVATION_FAILED_CLOSED'
  } finally {
    $transportRestoreStartedAt = [DateTimeOffset]::UtcNow
    if ($null -ne $transportDisabledAt) {
      $transportDisabledDurationSeconds = [math]::Round(
        ($transportRestoreStartedAt - $transportDisabledAt).TotalSeconds,
        3
      )
    }
    for ($attempt = 1; $attempt -le 2; $attempt++) {
      try {
        $null = Set-TransportState `
          -Adb $adb `
          -Serial $DeviceSerial `
          -WifiOn $initialTransport.wifiOn `
          -MobileDataOn $initialTransport.mobileDataOn
        $restorationError = $null
        break
      } catch {
        $restorationError = 'TRANSPORT_RESTORATION_FAILED'
        if ($attempt -lt 2) {
          Start-Sleep -Seconds 2
        }
      }
    }
  }

  try {
    $restoredTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
  } catch {
    $restorationError = 'TRANSPORT_RESTORATION_READBACK_FAILED'
    $restoredTransport = [pscustomobject]@{
      wifiOn = -1
      mobileDataOn = -1
      airplaneModeOn = -1
    }
  }
  $transportRestored =
    $restoredTransport.wifiOn -eq $initialTransport.wifiOn -and
    $restoredTransport.mobileDataOn -eq $initialTransport.mobileDataOn -and
    $restoredTransport.airplaneModeOn -eq $initialTransport.airplaneModeOn
  if (-not $transportRestored -or $null -ne $restorationError -or
      $null -ne $phaseError) {
    $failure = [ordered]@{
      schemaVersion = 1
      evidenceType = 'build-8-f4-offline-reconnect-failure'
      capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
      promotionSha256 = Get-Sha256 $promotionFile
      syncMarkerReceiptSha256 = Get-Sha256 $priorSyncReceiptFile
      installedApkSha256 = $promotion.artifactAuthority.apk.sha256
      failureClass = if ($null -ne $restorationError) {
        $restorationError
      } elseif (-not $transportRestored) {
        'EXACT_TRANSPORT_STATE_NOT_RESTORED'
      } else {
        $phaseError
      }
      initialTransport = $initialTransport
      observedTransportAfterFinally = $restoredTransport
      exactTransportStateRestored = $transportRestored
      offlineManualSyncOutcome = if ($null -eq $offlineSync) {
        'NOT_OBSERVED'
      } else {
        $offlineSync.outcome
      }
      transportDisabledDurationSeconds = $transportDisabledDurationSeconds
      rawUiRetained = $false
      rawNetworkIdentifiersRetained = $false
      failedPhaseMayNotBeRelabelledPass = $true
      decision = 'FAIL_BUILD8_OFFLINE_RECONNECT_REQUIRES_ADJUDICATION'
    }
    Write-NewUtf8Json -Path $failureReceiptPath -Value $failure
    throw "Offline/reconnect stopped: $($failure.failureClass)"
  }

  try {
    Start-Sleep -Seconds 10
    $null = Move-ToApprovedHome `
      -Adb $adb -Serial $DeviceSerial -EvidenceRoot $evidenceRoot
    $postReconnect = Wait-ManualSyncOutcome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build8-post-reconnect-existing' `
      -TimeoutSeconds 8
    if ($postReconnect.outcome -cne 'SUCCESS') {
      $postReconnect = Invoke-ManualSyncEvidence `
        -Adb $adb `
        -Serial $DeviceSerial `
        -EvidenceRoot $evidenceRoot `
        -Label 'build8-post-reconnect-new' `
        -TimeoutSeconds 120
    }
    Assert-Equal $postReconnect.outcome 'SUCCESS' `
      'Post-reconnect manual-sync outcome'

    $after = Get-LocalDiagnosticsEvidence `
      -Adb $adb -Serial $DeviceSerial -EvidenceRoot $evidenceRoot `
      -Label 'build8-offline-after'
    Assert-Equal $after.unsyncedRows 0 `
      'Post-reconnect pending local business writes'
    Assert-Equal $after.unresolvedRejections 0 `
      'Post-reconnect unresolved local rejections'
  } catch {
    if (-not (Test-Path -LiteralPath $failureReceiptPath)) {
      $failure = [ordered]@{
        schemaVersion = 1
        evidenceType = 'build-8-f4-offline-reconnect-failure'
        capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
        promotionSha256 = Get-Sha256 $promotionFile
        syncMarkerReceiptSha256 = Get-Sha256 $priorSyncReceiptFile
        installedApkSha256 = $promotion.artifactAuthority.apk.sha256
        failureClass = 'POST_RECONNECT_VALIDATION_FAILED'
        initialTransport = $initialTransport
        observedTransportAfterFinally = $restoredTransport
        exactTransportStateRestored = $transportRestored
        offlineManualSyncOutcome = if ($null -eq $offlineSync) {
          'NOT_OBSERVED'
        } else {
          $offlineSync.outcome
        }
        postReconnectManualSyncOutcome = if ($null -eq $postReconnect) {
          'NOT_OBSERVED'
        } else {
          $postReconnect.outcome
        }
        transportDisabledDurationSeconds = $transportDisabledDurationSeconds
        rawUiRetained = $false
        rawNetworkIdentifiersRetained = $false
        failedPhaseMayNotBeRelabelledPass = $true
        decision = 'FAIL_BUILD8_OFFLINE_RECONNECT_REQUIRES_ADJUDICATION'
      }
      Write-NewUtf8Json -Path $failureReceiptPath -Value $failure
    }
    throw 'Offline/reconnect stopped: POST_RECONNECT_VALIDATION_FAILED'
  }

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-8-f4-offline-reconnect'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    startedAtUtc = $startedAt
    promotionSha256 = Get-Sha256 $promotionFile
    source = [ordered]@{
      commit = $head
      originMain = $originMain
      postMergeRunId = $PostMergeRunId
      trackedClean = $true
    }
    syncMarker = [ordered]@{
      adjudicationSha256 = Get-Sha256 $syncAdjudicationFile
      externalReceiptSha256 = Get-Sha256 $priorSyncReceiptFile
      decision = $priorSyncReceipt.decision
    }
    backend = [ordered]@{
      evidenceSha256 = Get-Sha256 $backendFile
      decision = $backend.decision
      runtimeContractState = $backend.liveReadback.globalPullContractState
      inventoryMissing = $backend.liveReadback.inventoryMissing
      inventoryMalformed = $backend.liveReadback.inventoryMalformed
    }
    artifact = [ordered]@{
      finalizationEvidenceSha256 = Get-Sha256 $finalizationFile
      governedPackageSha256 = Get-Sha256 $packageFile
      installedApkSha256 = $promotion.artifactAuthority.apk.sha256
      versionCode = [int]$versionCode
      productionSignerVerified = $true
      firstInstallTimePreserved = $true
      lastUpdateTimePreserved = $true
    }
    target = [ordered]@{
      adbSerialSha256 = Get-TextSha256 $DeviceSerial
      buildFingerprintSha256 = $promotion.targetAuthority.buildFingerprintSha256
      physicalDevice = $true
      googlePlayServicesPresent = $true
      rawIdentifiersRetained = $false
    }
    session = [ordered]@{
      approvedHomeReached = $true
      requiredHomeMarkerCount = $homeEvidence.requiredMarkerCount
      forbiddenMarkerCount = $homeEvidence.forbiddenMarkerCount
      homeUiSha256 = $homeEvidence.uiSha256
      accountIdentityRetained = $false
    }
    diagnosticsBefore = $before
    initialTransport = $initialTransport
    offline = [ordered]@{
      allTransportsDisabled = $true
      transportStabilizationSeconds = 5
      manualSyncObservationTimeoutSeconds = 20
      measuredTransportDisabledDurationSeconds =
        $transportDisabledDurationSeconds
      approvedHomeUiSha256 = $offlineHome.uiSha256
      finalDisconnectedUiSha256 = $offlineFinalUi.sha256
      manualSyncOutcome = $offlineSync.outcome
      falseSuccessObserved = $false
      productionBusinessWriteAttempted = $false
    }
    restoration = [ordered]@{
      exactTransportStateRestored = $transportRestored
      observedTransport = $restoredTransport
      postReconnectSyncOutcome = $postReconnect.outcome
      completionUiSha256 = $postReconnect.outcomeUiSha256
    }
    diagnosticsAfter = $after
    mutationBoundary = [ordered]@{
      applicationInstalledUpgradedOrCleared = $false
      networkStateTemporarilyChanged = $true
      exactNetworkStateRestored = $transportRestored
      authenticationSessionChanged = $false
      pendingProductionBusinessWritesBefore = $before.unsyncedRows
      pendingProductionBusinessWritesAfter = $after.unsyncedRows
      backendDeploymentPerformed = $false
      distributionPerformed = $false
    }
    privacyBoundary = [ordered]@{
      rawUiRetained = $false
      rawAdbSerialRetained = $false
      rawBuildFingerprintRetained = $false
      rawNetworkIdentifiersRetained = $false
      accountIdentityRetained = $false
      businessPayloadRetained = $false
    }
    programmeBoundary = [ordered]@{
      stage2dF4Status = 'OPEN'
      offlineReconnectCriterionProved = $true
      stage2dF4ClosureAuthorized = $false
      p07ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
      distributionAuthorized = $false
      weakNetworkAuthorized = $false
      revocationAuthorized = $false
      wrongRoleExecutionAuthorized = $false
    }
    decision = 'PASS_BUILD8_F4_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY'
  }
  Write-NewUtf8Json -Path $receiptPath -Value $receipt
  $receipt | ConvertTo-Json -Depth 40
} finally {
  foreach ($temporary in @($temporaryApk, $installedApk)) {
    if (Test-Path -LiteralPath $temporary) {
      Remove-Item -LiteralPath $temporary -Force
    }
  }
}
