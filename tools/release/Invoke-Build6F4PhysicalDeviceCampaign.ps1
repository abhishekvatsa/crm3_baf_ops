#requires -Version 7.0
<#
.SYNOPSIS
Starts the exact-target Build 6 physical-device F4 campaign.

.DESCRIPTION
Preflight is read-only. Install installs and launches only the exact governed
Build 6 APK on the discovery-bound physical target. Authentication, sync and
network phases retain only hashes and non-identity state. Authority mutation
remains a separate tranche and this harness never closes STAGE2D-F4 or P-07.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet(
    'Preflight',
    'Install',
    'FinalizeInstall',
    'BeginApprovedSignIn',
    'CaptureApprovedSignIn',
    'CaptureSyncBaseline',
    'RunSyncMarker',
    'RunOfflineReconnect',
    'RunWeakNetwork'
  )]
  [string]$Phase = 'Preflight',

  [Parameter(Mandatory)]
  [string]$GovernedPackagePath,

  [Parameter(Mandatory)]
  [string]$DiscoveryReceiptPath,

  [Parameter(Mandatory)]
  [string]$DeviceSerial,

  [Parameter(Mandatory)]
  [string]$EvidenceDirectory,

  [string]$PromotionPath =
    'release/approvals/build-6-f4-physical-device-execution-promotion.json',

  [string]$RepositoryRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory)][string]$Value)

  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    ([Convert]::ToHexString($algorithm.ComputeHash($bytes))).ToUpperInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Text
  )

  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-ExternalText {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [switch]$AllowFailure
  )

  $output = & $FilePath @Arguments 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  if (-not $AllowFailure -and $exitCode -ne 0) {
    throw "$FilePath exited $exitCode.`n$output"
  }
  [pscustomobject]@{
    exitCode = $exitCode
    output = $output.Trim()
  }
}

function Assert-Equal {
  param(
    [Parameter(Mandatory)]$Actual,
    [Parameter(Mandatory)]$Expected,
    [Parameter(Mandatory)][string]$Label
  )

  if ($Actual -ne $Expected) {
    throw "$Label mismatch. Expected '$Expected', got '$Actual'."
  }
}

function Get-AndroidTool {
  param(
    [Parameter(Mandatory)][string]$SdkRoot,
    [Parameter(Mandatory)][string]$RelativePath
  )

  $path = Join-Path $SdkRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing Android SDK tool: $path"
  }
  (Resolve-Path -LiteralPath $path).Path
}

function Get-DeviceProperty {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$Name
  )

  (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'getprop', $Name
  )).output
}

function Expand-ExactZipEntry {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryName,
    [Parameter(Mandatory)][string]$Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    throw "Refusing to replace extracted artifact: $Destination"
  }
  $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    $matches = @($archive.Entries | Where-Object FullName -EQ $EntryName)
    if ($matches.Count -ne 1) {
      throw "Governed package must contain exactly one '$EntryName' entry."
    }
    [IO.Compression.ZipFileExtensions]::ExtractToFile(
      $matches[0],
      $Destination,
      $false
    )
  } finally {
    $archive.Dispose()
  }
}

function Get-UiEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label
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
    if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
      throw 'UI hierarchy capture did not produce the expected local file.'
    }
    $uiText = Get-Content -LiteralPath $localPath -Raw
    [pscustomobject]@{
      sha256 = Get-Sha256 $localPath
      text = $uiText
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
    [Parameter(Mandatory)][string]$UiText,
    [Parameter(Mandatory)][string]$XPath,
    [Parameter(Mandatory)][string]$Label
  )

  [xml]$document = $UiText
  $node = $document.SelectSingleNode($XPath)
  if ($null -eq $node) {
    throw "Could not find UI control: $Label"
  }
  $bounds = [string]$node.bounds
  $match = [regex]::Match(
    $bounds,
    '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'
  )
  if (-not $match.Success) {
    throw "$Label bounds are malformed: $bounds"
  }
  [pscustomobject]@{
    x = [int]((
      [int]$match.Groups[1].Value + [int]$match.Groups[3].Value
    ) / 2)
    y = [int]((
      [int]$match.Groups[2].Value + [int]$match.Groups[4].Value
    ) / 2)
  }
}

function Invoke-UiTap {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)]$Center
  )

  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'tap',
    ([string]$Center.x), ([string]$Center.y)
  )
}

function Get-AppProcessId {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$PackageId
  )

  $process = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pidof', '-s', $PackageId
  ) -AllowFailure
  if ($process.exitCode -ne 0 -or
      [string]::IsNullOrWhiteSpace($process.output)) {
    throw 'The CRM-III application process is not running.'
  }
  $process.output.Trim()
}

function Get-ApprovedHomeEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot
  )

  $homeMarkers = @('Home', 'Issues', 'Work', 'Directives', 'More', 'Core modules')
  $forbiddenMarkers = @(
    'Sign in with Google',
    'Awaiting Approval',
    'User profile error',
    '[cloud_firestore/permission-denied]',
    'Sign-in failed'
  )
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds(120)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label 'build6-f4-approved-home'
    $missing = @($homeMarkers | Where-Object { -not $ui.text.Contains($_) })
    $forbidden = @($forbiddenMarkers | Where-Object { $ui.text.Contains($_) })
    if ($missing.Count -eq 0 -and $forbidden.Count -eq 0) {
      return [pscustomobject]@{
        sha256 = $ui.sha256
        homeMarkersPresent = $true
        forbiddenMarkersAbsent = $true
      }
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  throw 'The approved home surface was not reached without a forbidden marker.'
}

function Assert-OneOf {
  param(
    [Parameter(Mandatory)]$Actual,
    [Parameter(Mandatory)][object[]]$Expected,
    [Parameter(Mandatory)][string]$Label
  )

  if ($Actual -notin $Expected) {
    throw "$Label mismatch. Expected one approved value, got '$Actual'."
  }
}

function Get-UiWithMarker {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Marker,
    [int]$TimeoutSeconds = 30
  )

  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label $Label
    if ($ui.text.Contains($Marker)) {
      return $ui
    }
    Start-Sleep -Seconds 1
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  throw "The expected UI marker was not reached: $Marker"
}

function Invoke-UiMarkerTap {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Marker,
    [Parameter(Mandatory)][string]$XPath,
    [int]$ScrollAttempts = 0
  )

  for ($attempt = 0; $attempt -le $ScrollAttempts; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-$attempt"
    if ($ui.text.Contains($Marker)) {
      $center = Get-NodeCenter `
        -UiText $ui.text `
        -XPath $XPath `
        -Label $Marker
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

  throw "Could not reach UI control: $Marker"
}

function Move-ToApprovedHome {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot
  )

  for ($attempt = 0; $attempt -le 5; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "build6-f4-home-navigation-$attempt"
    if ($ui.text.Contains('Core modules') -and $ui.text.Contains('Home')) {
      $home = Get-ApprovedHomeEvidence `
        -Adb $Adb `
        -Serial $Serial `
        -EvidenceRoot $EvidenceRoot
      return $home
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
        # A pushed route may contain non-navigation Home text; unwind below.
      }
    }
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'input', 'keyevent', '4'
    )
    Start-Sleep -Seconds 1
  }
  throw 'The approved Home navigation surface could not be restored.'
}

function Get-LocalDiagnosticsEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label
  )

  $null = Move-ToApprovedHome `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-more" `
    -Marker 'More' `
    -XPath "//node[(@text='More' or contains(@content-desc,'More')) and @clickable='true']"
  $null = Get-UiWithMarker `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-more-surface" `
    -Marker 'Tools, records and administrative access.'
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-diagnostics-tile" `
    -Marker 'Support Diagnostics' `
    -XPath "//node[(@text='Support Diagnostics' or contains(@content-desc,'Support Diagnostics')) and @clickable='true']" `
    -ScrollAttempts 8
  $ui = Get-UiWithMarker `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-diagnostics" `
    -Marker 'Local diagnostics inventory' `
    -TimeoutSeconds 60
  $unsynced = [regex]::Match($ui.text, '(\d+) unsynced rows')
  if (-not $unsynced.Success) {
    throw 'Local diagnostics did not expose the unsynced-row count.'
  }
  $rejections = [regex]::Match($ui.text, '(\d+) unresolved rejections')
  if (-not $rejections.Success) {
    throw 'Local diagnostics did not expose the rejection count.'
  }
  $evidence = [pscustomobject]@{
    uiSha256 = $ui.sha256
    unsyncedRows = [int]$unsynced.Groups[1].Value
    unresolvedRejections = [int]$rejections.Groups[1].Value
  }
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'keyevent', '4'
  )
  Start-Sleep -Seconds 1
  $null = Move-ToApprovedHome `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot
  $evidence
}

function Wait-ManualSyncOutcome {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [int]$TimeoutSeconds = 120
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
        uiSha256 = $ui.sha256
      }
    }
    if ($ui.text.Contains('Manual sync failed:')) {
      return [pscustomobject]@{
        outcome = 'FAILED'
        uiSha256 = $ui.sha256
      }
    }
    if ($ui.text.Contains(
        'Manual sync is already running or could not complete.')) {
      return [pscustomobject]@{
        outcome = 'NOT_COMPLETED'
        uiSha256 = $ui.sha256
      }
    }
    Start-Sleep -Milliseconds 500
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  [pscustomobject]@{
    outcome = 'TIMEOUT_WITHOUT_SUCCESS_MARKER'
    uiSha256 = $ui.sha256
  }
}

function Invoke-ManualSyncEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [int]$TimeoutSeconds = 120
  )

  $null = Move-ToApprovedHome `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)
  do {
    $before = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-ready"
    $stale = $before.text.Contains('Manual sync completed.') -or
      $before.text.Contains('Manual sync failed:') -or
      $before.text.Contains(
        'Manual sync is already running or could not complete.')
    if (-not $stale) {
      break
    }
    Start-Sleep -Seconds 1
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  if ($stale) {
    throw 'A stale manual-sync result marker did not clear before execution.'
  }
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-trigger" `
    -Marker 'Sync now' `
    -XPath "//node[(@text='Sync now' or contains(@content-desc,'Sync now')) and @clickable='true']"
  Wait-ManualSyncOutcome `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-outcome" `
    -TimeoutSeconds $TimeoutSeconds
}

function Get-TransportState {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial
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
  [pscustomobject]@{
    wifiOn = [int]$wifi
    mobileDataOn = [int]$mobile
    airplaneModeOn = [int]$airplane
  }
}

function Set-TransportState {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][int]$WifiOn,
    [Parameter(Mandatory)][int]$MobileDataOn
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

function Assert-InstalledApkHash {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$PackageId,
    [Parameter(Mandatory)][string]$ExpectedSha256,
    [Parameter(Mandatory)][string]$EvidenceRoot
  )

  $paths = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pm', 'path', $PackageId
  )).output
  $basePaths = @($paths -split "`n" | Where-Object {
    $_.StartsWith('package:') -and $_.Contains('/base.apk')
  })
  if ($basePaths.Count -ne 1) {
    throw 'Installed Build 6 base APK path is not uniquely available.'
  }
  $temporary = Join-Path $EvidenceRoot '.installed-build6-network-tranche.apk'
  try {
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'pull',
      $basePaths[0].Substring('package:'.Length),
      $temporary
    )
    Assert-Equal (Get-Sha256 $temporary) $ExpectedSha256 `
      'Installed APK SHA-256 for sync/network tranche'
  } finally {
    if (Test-Path -LiteralPath $temporary) {
      Remove-Item -LiteralPath $temporary -Force
    }
  }
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
$discoveryFile = (Resolve-Path -LiteralPath $DiscoveryReceiptPath).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json
$discovery = Get-Content -LiteralPath $discoveryFile -Raw | ConvertFrom-Json
$currentPromotionSha256 = Get-Sha256 $promotionFile
$acceptedPromotionSha256 = @($currentPromotionSha256)
if ($null -ne $promotion.syncNetworkTrancheAmendment) {
  $acceptedPromotionSha256 +=
    [string]$promotion.syncNetworkTrancheAmendment.priorPromotionSha256
}

Assert-Equal $promotion.schemaVersion 1 'Promotion schema version'
Assert-Equal `
  $promotion.approvalClass `
  'CONTROLLED_EXACT_TARGET_PHYSICAL_DEVICE_F4_EXECUTION' `
  'Promotion class'
Assert-Equal $promotion.channel.maxTargetCount 1 'Maximum target count'
Assert-Equal `
  $promotion.channel.physicalDeviceInstallationAuthorized `
  $true `
  'Physical-device installation authorization'
Assert-Equal `
  $promotion.channel.externalDistributionAuthorized `
  $false `
  'External distribution authorization'
Assert-Equal `
  $promotion.programmeBoundary.stage2dF4ClosureAuthorized `
  $false `
  'F4 closure authorization'
Assert-Equal `
  $promotion.programmeBoundary.pilotHandoutAuthorized `
  $false `
  'Pilot handout authorization'

Assert-Equal `
  (Get-Sha256 $discoveryFile) `
  $promotion.discoveryAuthority.receiptSha256 `
  'Target-discovery receipt SHA-256'
Assert-Equal `
  $discovery.decision `
  $promotion.discoveryAuthority.decision `
  'Target-discovery decision'
Assert-Equal `
  $discovery.mutationBoundary.packageInstalled `
  $false `
  'Discovery package-install boundary'
Assert-Equal `
  $discovery.authorityBoundary.stage2dF4ExecutionAuthorized `
  $false `
  'Discovery F4-execution boundary'

$expectedPackage = $promotion.artifactAuthority.governedPackage
Assert-Equal (Get-Sha256 $packageFile) $expectedPackage.sha256 `
  'Governed package SHA-256'
Assert-Equal (Get-Item -LiteralPath $packageFile).Length `
  $expectedPackage.bytes `
  'Governed package bytes'

$gitBranch = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'branch', '--show-current'
)).output
$null = Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'fetch', '--quiet', 'origin', 'main'
)
$gitHead = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'rev-parse', 'HEAD'
)).output
$originMain = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'rev-parse', 'origin/main'
)).output
$trackedStatus = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'status', '--porcelain', '--untracked-files=no'
)).output
if ($gitBranch -ne 'main' -or $gitHead -ne $originMain -or $trackedStatus) {
  throw 'Physical F4 execution requires exact tracked-clean main equal to freshly fetched origin/main.'
}
if ($gitHead -eq $promotion.approvalAuthority.baselineCommit) {
  throw 'The execution promotion is not effective on its unmodified baseline.'
}

$sdkRoot = if ($env:ANDROID_SDK_ROOT) {
  $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
  $env:ANDROID_HOME
} else {
  Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}
$adb = Get-AndroidTool -SdkRoot $sdkRoot -RelativePath 'platform-tools\adb.exe'
$aapt = Get-AndroidTool -SdkRoot $sdkRoot -RelativePath 'build-tools\36.0.0\aapt.exe'
$apksigner = Get-AndroidTool `
  -SdkRoot $sdkRoot `
  -RelativePath 'build-tools\36.0.0\apksigner.bat'

Assert-Equal `
  (Get-TextSha256 $DeviceSerial) `
  $promotion.targetAuthority.adbSerialSha256 `
  'Hashed ADB target identity'
Assert-Equal `
  (Get-TextSha256 (Get-DeviceProperty `
    -Adb $adb -Serial $DeviceSerial -Name 'ro.build.fingerprint')) `
  $promotion.targetAuthority.buildFingerprintSha256 `
  'Hashed build fingerprint'
Assert-Equal `
  (Get-DeviceProperty -Adb $adb -Serial $DeviceSerial -Name 'ro.kernel.qemu') `
  '0' `
  'Physical-device QEMU marker'
Assert-Equal `
  (Get-DeviceProperty -Adb $adb -Serial $DeviceSerial -Name 'ro.product.model') `
  $promotion.targetAuthority.model `
  'Physical target model'
$observedApiLevel = [int](Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.build.version.sdk')
$expectedApiLevel = [int]$promotion.targetAuthority.apiLevel
Assert-Equal `
  -Actual $observedApiLevel `
  -Expected $expectedApiLevel `
  -Label 'Physical target API level'
$gms = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', 'com.google.android.gms'
)).output
if (-not $gms.StartsWith('package:')) {
  throw 'The exact physical target no longer exposes Google Play Services.'
}

$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) +
  [IO.Path]::DirectorySeparatorChar
if ($evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'EvidenceDirectory must be outside the repository.'
}
$apkPath = Join-Path $evidenceRoot 'governed-build6.apk'
$preflightReceiptPath = Join-Path $evidenceRoot 'preflight-receipt.json'
$installReceiptPath = Join-Path $evidenceRoot 'install-receipt.json'
$chooserReceiptPath = Join-Path $evidenceRoot 'approved-signin-chooser-receipt.json'
$signInReceiptPath = Join-Path $evidenceRoot 'approved-signin-receipt.json'
$syncBaselineReceiptPath = Join-Path $evidenceRoot 'sync-baseline-receipt.json'
$syncMarkerReceiptPath = Join-Path $evidenceRoot 'sync-marker-receipt.json'
$offlineReceiptPath = Join-Path $evidenceRoot 'offline-reconnect-receipt.json'
$weakNetworkReceiptPath = Join-Path $evidenceRoot 'weak-network-receipt.json'
$offlineFailureReceiptPath =
  Join-Path $evidenceRoot 'offline-reconnect-failure-receipt.json'
$weakNetworkFailureReceiptPath =
  Join-Path $evidenceRoot 'weak-network-failure-receipt.json'
$applicationId = $promotion.artifactAuthority.applicationId
$expectedApk = $promotion.artifactAuthority.apk

if ($Phase -eq 'Preflight') {
  if (Test-Path -LiteralPath $evidenceRoot) {
    if ((Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
      throw 'Preflight evidence directory must be new or empty.'
    }
  } else {
    $null = New-Item -ItemType Directory -Path $evidenceRoot
  }
  Expand-ExactZipEntry `
    -ArchivePath $packageFile `
    -EntryName $expectedApk.entryName `
    -Destination $apkPath
  Assert-Equal (Get-Sha256 $apkPath) $expectedApk.sha256 `
    'Embedded APK SHA-256'
  Assert-Equal (Get-Item -LiteralPath $apkPath).Length $expectedApk.bytes `
    'Embedded APK bytes'

  $badging = (Invoke-ExternalText -FilePath $aapt -Arguments @(
    'dump', 'badging', $apkPath
  )).output
  if ($badging -notmatch "package: name='$([regex]::Escape($applicationId))'") {
    throw 'The governed APK package does not match the promotion.'
  }
  if ($badging -match '(?m)^application-debuggable') {
    throw 'The governed Build 6 APK is unexpectedly debuggable.'
  }
  $signer = (Invoke-ExternalText -FilePath $apksigner -Arguments @(
    'verify', '--print-certs', $apkPath
  )).output.Replace(':', '').ToUpperInvariant()
  if (-not $signer.Contains(
      $promotion.artifactAuthority.signer.certificateSha256)) {
    throw 'The governed APK signer does not match the promotion.'
  }

  $existing = Invoke-ExternalText `
    -FilePath $adb `
    -Arguments @('-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId) `
    -AllowFailure
  if ($existing.output.StartsWith('package:')) {
    throw 'Preflight requires the CRM-III package to remain absent.'
  }
  if (($existing.exitCode -notin @(0, 1)) -or
      -not [string]::IsNullOrWhiteSpace($existing.output)) {
    throw 'CRM-III package absence is not proved.'
  }

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-preflight'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    discoveryReceiptSha256 = Get-Sha256 $discoveryFile
    source = [ordered]@{
      head = $gitHead
      originMain = $originMain
      trackedClean = $true
    }
    artifact = [ordered]@{
      governedPackageSha256 = Get-Sha256 $packageFile
      apkSha256 = Get-Sha256 $apkPath
      applicationId = $applicationId
      versionCode = [int]$promotion.artifactAuthority.versionCode
      debuggable = $false
      certificateSha256 =
        $promotion.artifactAuthority.signer.certificateSha256
    }
    target = [ordered]@{
      adbSerialSha256 = Get-TextSha256 $DeviceSerial
      buildFingerprintSha256 =
        $promotion.targetAuthority.buildFingerprintSha256
      physicalDevice = $true
      googlePlayServicesPresent = $true
      crm3PackageAbsent = $true
      rawIdentifiersRetained = $false
    }
    mutationBoundary = [ordered]@{
      packageInstalled = $false
      applicationLaunched = $false
      authenticationSessionCreated = $false
      remoteMutationPerformed = $false
    }
    decision = 'PASS_BUILD6_F4_PHYSICAL_DEVICE_PREFLIGHT_READ_ONLY'
  }
  Write-Utf8NoBom `
    -Path $preflightReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $preflightReceiptPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
  throw "$Phase requires the governed preflight evidence."
}
$preflight = Get-Content -LiteralPath $preflightReceiptPath -Raw |
  ConvertFrom-Json
Assert-OneOf `
  -Actual $preflight.promotionSha256 `
  -Expected $acceptedPromotionSha256 `
  -Label 'Preflight promotion SHA-256'
Assert-Equal (Get-Sha256 $apkPath) $expectedApk.sha256 `
  'Campaign APK SHA-256'

if ($Phase -in @('Install', 'FinalizeInstall')) {
  if (Test-Path -LiteralPath $installReceiptPath) {
    throw "$Phase refuses to replace an existing install receipt."
  }
  $existing = Invoke-ExternalText `
    -FilePath $adb `
    -Arguments @('-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId) `
    -AllowFailure
  $recoveryMode = 'NONE'
  if ($Phase -eq 'Install') {
    if ($existing.output.StartsWith('package:') -or
        ($existing.exitCode -notin @(0, 1)) -or
        -not [string]::IsNullOrWhiteSpace($existing.output)) {
      throw 'Install requires the CRM-III package to remain absent.'
    }
    if (-not $PSCmdlet.ShouldProcess(
        $promotion.targetAuthority.adbSerialSha256,
        'Install exact governed Build 6 APK on the bound physical target')) {
      exit 0
    }
    $install = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'install', '--no-streaming', $apkPath
    )
    if (-not $install.output.Contains('Success')) {
      throw "Build 6 installation did not report success.`n$($install.output)"
    }
  } else {
    if (-not $existing.output.StartsWith('package:')) {
      throw 'FinalizeInstall requires a package left by an interrupted Install.'
    }
    $recoveryMode = 'INTERRUPTED_AFTER_INSTALL_BEFORE_RECEIPT'
  }
  $installedPathOutput = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId
  )).output
  $installedPath = @($installedPathOutput -split "`n" |
      Where-Object { $_.StartsWith('package:') } |
      Select-Object -First 1)
  if ($installedPath.Count -ne 1) {
    throw 'Installed Build 6 base APK path is not uniquely available.'
  }
  $installedTemp = Join-Path $evidenceRoot '.installed-build6.apk'
  try {
    $null = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'pull',
      $installedPath[0].Substring('package:'.Length),
      $installedTemp
    )
    Assert-Equal (Get-Sha256 $installedTemp) $expectedApk.sha256 `
      'Installed APK SHA-256'
  } finally {
    if (Test-Path -LiteralPath $installedTemp) {
      Remove-Item -LiteralPath $installedTemp -Force
    }
  }
  $null = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $applicationId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )
  Start-Sleep -Seconds 3
  $initialUi = Get-UiEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-post-install'
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-install'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    preflightReceiptSha256 = Get-Sha256 $preflightReceiptPath
    recoveryMode = $recoveryMode
    installedApkSha256 = $expectedApk.sha256
    targetAdbSerialSha256 = Get-TextSha256 $DeviceSerial
    applicationLaunched = $true
    initialUiSha256 = $initialUi.sha256
    rawUiRetained = $false
    authenticationSessionCreatedByHarness = $false
    remoteBusinessMutationPerformedByHarness = $false
    programmeBoundary = [ordered]@{
      stage2dF4Status = 'OPEN'
      stage2dF4ClosureAuthorized = $false
      p07ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
    }
    decision = 'PASS_EXACT_BUILD6_INSTALLED_ON_BOUND_PHYSICAL_TARGET'
  }
  Write-Utf8NoBom `
    -Path $installReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $installReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed install receipt."
}
$installed = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId
)).output
if (-not $installed.StartsWith('package:')) {
  throw 'The exact installed Build 6 package is no longer present.'
}

if ($Phase -eq 'BeginApprovedSignIn') {
  if (Test-Path -LiteralPath $chooserReceiptPath) {
    throw 'BeginApprovedSignIn refuses to replace an existing receipt.'
  }
  $null = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $applicationId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )
  Start-Sleep -Seconds 2
  $loginUi = Get-UiEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-login'
  if (-not $loginUi.text.Contains('Sign in with Google')) {
    throw 'BeginApprovedSignIn requires the fresh Google sign-in surface.'
  }
  $applicationProcessId = Get-AppProcessId `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId
  $signInCenter = Get-NodeCenter `
    -UiText $loginUi.text `
    -XPath "//node[@text='Sign in with Google' or contains(@content-desc,'Sign in with Google')]" `
    -Label 'Sign in with Google'
  Invoke-UiTap -Adb $adb -Serial $DeviceSerial -Center $signInCenter

  $chooserUi = $null
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
  do {
    $candidate = Get-UiEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build6-f4-account-chooser'
    if ($candidate.text.Contains('Choose an account') -and
        $candidate.text.Contains('package="com.google.android.gms"')) {
      $chooserUi = $candidate
      break
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  if ($null -eq $chooserUi) {
    throw 'The Google Play Services account chooser was not reached.'
  }
  Assert-Equal `
    (Get-AppProcessId `
      -Adb $adb -Serial $DeviceSerial -PackageId $applicationId) `
    $applicationProcessId `
    'Application process at Google account chooser'

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-account-chooser'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    installReceiptSha256 = Get-Sha256 $installReceiptPath
    targetAdbSerialSha256 = Get-TextSha256 $DeviceSerial
    applicationProcessIdBeforeSelection = $applicationProcessId
    loginUiSha256 = $loginUi.sha256
    chooserUiSha256 = $chooserUi.sha256
    googlePlayServicesChooserPresent = $true
    rawUiRetained = $false
    accountEmailRetained = $false
    firebaseUidRetained = $false
    nextStep =
      'Select the controlled approved SI/non-admin account, then run CaptureApprovedSignIn without relaunching the application.'
    decision = 'PASS_PHYSICAL_GOOGLE_ACCOUNT_CHOOSER_READY'
  }
  Write-Utf8NoBom `
    -Path $chooserReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if ($Phase -eq 'CaptureApprovedSignIn') {
  if (-not (Test-Path -LiteralPath $chooserReceiptPath -PathType Leaf)) {
    throw 'CaptureApprovedSignIn requires the governed account-chooser receipt.'
  }
  if (Test-Path -LiteralPath $signInReceiptPath) {
    throw 'CaptureApprovedSignIn refuses to replace an existing receipt.'
  }
  $chooserReceipt = Get-Content -LiteralPath $chooserReceiptPath -Raw |
    ConvertFrom-Json
  $focus = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'dumpsys', 'window', 'windows'
  )).output
  if (-not $focus.Contains($applicationId)) {
    throw 'The CRM-III application must remain foreground for sign-in capture.'
  }
  $approvedHome = Get-ApprovedHomeEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot
  $currentProcessId = Get-AppProcessId `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId
  Assert-Equal `
    $currentProcessId `
    $chooserReceipt.applicationProcessIdBeforeSelection `
    'Same-process approved sign-in'
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-approved-signin'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    installReceiptSha256 = Get-Sha256 $installReceiptPath
    chooserReceiptSha256 = Get-Sha256 $chooserReceiptPath
    installedApkSha256 = $expectedApk.sha256
    targetAdbSerialSha256 = Get-TextSha256 $DeviceSerial
    runtime = [ordered]@{
      googleFirebaseSignInObserved = $true
      approvedHomeReached = $true
      sameApplicationProcessFromChooserToApprovedHome = $true
      homeMarkersPresent = $approvedHome.homeMarkersPresent
      forbiddenMarkersAbsent = $approvedHome.forbiddenMarkersAbsent
      approvedHomeUiSha256 = $approvedHome.sha256
      rawUiRetained = $false
    }
    privacy = [ordered]@{
      accountEmailRetained = $false
      accountDisplayNameRetained = $false
      firebaseUidRetained = $false
      accessTokenRetained = $false
    }
    remainingRequiredPhases = @(
      'sync-marker',
      'offline-reconnect',
      'weak-network',
      'revocation-next-operation-denial',
      'wrong-role-denials'
    )
    programmeBoundary = [ordered]@{
      stage2dF4Status = 'OPEN'
      stage2dF4ClosureAuthorized = $false
      p07ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
      separateEvidenceAdjudicationRequired = $true
    }
    decision = 'PASS_APPROVED_SIGNIN_CAPTURED_FULL_F4_MATRIX_REMAINS_OPEN'
  }
  Write-Utf8NoBom `
    -Path $signInReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

$networkPhases = @(
  'CaptureSyncBaseline',
  'RunSyncMarker',
  'RunOfflineReconnect',
  'RunWeakNetwork'
)
if ($Phase -notin $networkPhases) {
  throw "Unsupported physical F4 phase: $Phase"
}
if ($null -eq $promotion.syncNetworkTrancheAmendment) {
  throw "$Phase requires the merged sync/network tranche amendment."
}
$tranche = $promotion.syncNetworkTrancheAmendment
if (-not (Test-Path -LiteralPath $signInReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed approved-signin receipt."
}
Assert-Equal `
  (Get-Sha256 $signInReceiptPath) `
  $tranche.privateEvidence.approvedSigninReceiptSha256 `
  'Approved-signin receipt SHA-256'
$signInReceipt = Get-Content -LiteralPath $signInReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $signInReceipt.decision `
  'PASS_APPROVED_SIGNIN_CAPTURED_FULL_F4_MATRIX_REMAINS_OPEN' `
  'Approved-signin decision'
Assert-Equal `
  $signInReceipt.runtime.sameApplicationProcessFromChooserToApprovedHome `
  $true `
  'Approved-signin process continuity'
Assert-InstalledApkHash `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $applicationId `
  -ExpectedSha256 $expectedApk.sha256 `
  -EvidenceRoot $evidenceRoot
$null = Move-ToApprovedHome `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot

if ($Phase -eq 'CaptureSyncBaseline') {
  if (Test-Path -LiteralPath $syncBaselineReceiptPath) {
    throw 'CaptureSyncBaseline refuses to replace an existing receipt.'
  }
  $diagnostics = Get-LocalDiagnosticsEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-sync-baseline'
  Assert-Equal $diagnostics.unsyncedRows 0 `
    'Fresh-install pending local business writes'
  $transport = Get-TransportState -Adb $adb -Serial $DeviceSerial
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-sync-baseline'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $currentPromotionSha256
    approvedSigninReceiptSha256 = Get-Sha256 $signInReceiptPath
    installedApkSha256 = $expectedApk.sha256
    localDiagnostics = [ordered]@{
      uiSha256 = $diagnostics.uiSha256
      unsyncedRows = $diagnostics.unsyncedRows
      unresolvedRejections = $diagnostics.unresolvedRejections
      rawUiRetained = $false
    }
    initialTransport = [ordered]@{
      wifiOn = $transport.wifiOn
      mobileDataOn = $transport.mobileDataOn
      airplaneModeOn = $transport.airplaneModeOn
      rawNetworkIdentifiersRetained = $false
    }
    remoteBusinessMutationPerformed = $false
    decision = 'PASS_ZERO_PENDING_LOCAL_WRITES_SYNC_BASELINE'
  }
  Write-Utf8NoBom `
    -Path $syncBaselineReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $syncBaselineReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed sync-baseline receipt."
}
$syncBaseline = Get-Content -LiteralPath $syncBaselineReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal $syncBaseline.promotionSha256 $currentPromotionSha256 `
  'Sync-baseline promotion SHA-256'
Assert-Equal `
  $syncBaseline.approvedSigninReceiptSha256 `
  (Get-Sha256 $signInReceiptPath) `
  'Sync-baseline approved-signin receipt SHA-256'
Assert-Equal $syncBaseline.installedApkSha256 $expectedApk.sha256 `
  'Sync-baseline installed APK SHA-256'
Assert-Equal $syncBaseline.decision `
  'PASS_ZERO_PENDING_LOCAL_WRITES_SYNC_BASELINE' `
  'Sync-baseline decision'
Assert-Equal $syncBaseline.localDiagnostics.unsyncedRows 0 `
  'Sync-baseline pending local business writes'

if ($Phase -eq 'RunSyncMarker') {
  if (Test-Path -LiteralPath $syncMarkerReceiptPath) {
    throw 'RunSyncMarker refuses to replace an existing receipt.'
  }
  $before = Get-LocalDiagnosticsEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-sync-marker-before'
  Assert-Equal $before.unsyncedRows 0 `
    'Pre-sync pending local business writes'
  $sync = Invoke-ManualSyncEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-sync-marker'
  Assert-Equal $sync.outcome 'SUCCESS' 'Authenticated manual-sync outcome'
  $after = Get-LocalDiagnosticsEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-sync-marker-after'
  Assert-Equal $after.unsyncedRows 0 `
    'Post-sync pending local business writes'
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-sync-marker'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $currentPromotionSha256
    syncBaselineReceiptSha256 = Get-Sha256 $syncBaselineReceiptPath
    installedApkSha256 = $expectedApk.sha256
    before = [ordered]@{
      diagnosticsUiSha256 = $before.uiSha256
      pendingLocalBusinessWrites = $before.unsyncedRows
    }
    manualSync = [ordered]@{
      outcome = $sync.outcome
      completionUiSha256 = $sync.uiSha256
      syntheticBusinessRecordCreated = $false
    }
    after = [ordered]@{
      diagnosticsUiSha256 = $after.uiSha256
      pendingLocalBusinessWrites = $after.unsyncedRows
    }
    privacy = [ordered]@{
      rawUiRetained = $false
      accountIdentityRetained = $false
      businessPayloadRetained = $false
    }
    decision = 'PASS_AUTHENTICATED_MANUAL_SYNC_ZERO_PENDING_WRITES'
  }
  Write-Utf8NoBom `
    -Path $syncMarkerReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $syncMarkerReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed sync-marker receipt."
}
$syncMarker = Get-Content -LiteralPath $syncMarkerReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal $syncMarker.promotionSha256 $currentPromotionSha256 `
  'Sync-marker promotion SHA-256'
Assert-Equal `
  $syncMarker.syncBaselineReceiptSha256 `
  (Get-Sha256 $syncBaselineReceiptPath) `
  'Sync-marker baseline receipt SHA-256'
Assert-Equal $syncMarker.installedApkSha256 $expectedApk.sha256 `
  'Sync-marker installed APK SHA-256'
Assert-Equal $syncMarker.decision `
  'PASS_AUTHENTICATED_MANUAL_SYNC_ZERO_PENDING_WRITES' `
  'Sync-marker decision'
Assert-Equal $syncMarker.after.pendingLocalBusinessWrites 0 `
  'Sync-marker post-run pending local business writes'

if ($Phase -eq 'RunOfflineReconnect') {
  if ((Test-Path -LiteralPath $offlineReceiptPath) -or
      (Test-Path -LiteralPath $offlineFailureReceiptPath)) {
    throw 'RunOfflineReconnect refuses to replace existing phase evidence.'
  }
  $before = Get-LocalDiagnosticsEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-offline-before'
  Assert-Equal $before.unsyncedRows 0 `
    'Pre-offline pending local business writes'
  $initialTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
  Assert-Equal $initialTransport.airplaneModeOn 0 `
    'Pre-offline airplane-mode setting'
  if ($initialTransport.wifiOn -eq 0 -and
      $initialTransport.mobileDataOn -eq 0) {
    throw 'Offline/reconnect requires an initially enabled network transport.'
  }
  $offlineSync = $null
  $offlineUi = $null
  $phaseError = $null
  $restorationError = $null
  $transportDisabledAt = $null
  $transportRestoreStartedAt = $null
  $transportDisabledDurationSeconds = 0.0
  try {
    $null = Set-TransportState `
      -Adb $adb `
      -Serial $DeviceSerial `
      -WifiOn 0 `
      -MobileDataOn 0
    $transportDisabledAt = [DateTimeOffset]::UtcNow
    Start-Sleep -Seconds 5
    $offlineUi = Move-ToApprovedHome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot
    $offlineSync = Invoke-ManualSyncEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build6-f4-offline-sync' `
      -TimeoutSeconds 20
    if ($offlineSync.outcome -eq 'SUCCESS') {
      $phaseError = 'FALSE_SUCCESS_WHILE_ALL_TRANSPORTS_DISABLED'
    }
    $offlineFinalUi = Get-UiEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build6-f4-offline-final-disconnected'
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
    try {
      $null = Set-TransportState `
        -Adb $adb `
        -Serial $DeviceSerial `
        -WifiOn $initialTransport.wifiOn `
        -MobileDataOn $initialTransport.mobileDataOn
    } catch {
      $restorationError = 'TRANSPORT_RESTORATION_FAILED'
    }
  }
  $restoredTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
  $transportRestored =
    $restoredTransport.wifiOn -eq $initialTransport.wifiOn -and
    $restoredTransport.mobileDataOn -eq $initialTransport.mobileDataOn -and
    $restoredTransport.airplaneModeOn -eq $initialTransport.airplaneModeOn
  if (-not $transportRestored -or $null -ne $restorationError -or
      $null -ne $phaseError) {
    $failure = [ordered]@{
      schemaVersion = 1
      evidenceType = 'build-6-f4-physical-device-offline-reconnect-failure'
      capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
      promotionSha256 = $currentPromotionSha256
      syncMarkerReceiptSha256 = Get-Sha256 $syncMarkerReceiptPath
      installedApkSha256 = $expectedApk.sha256
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
      decision = 'FAIL_OFFLINE_RECONNECT_REQUIRES_ADJUDICATION'
    }
    Write-Utf8NoBom `
      -Path $offlineFailureReceiptPath `
      -Text (($failure | ConvertTo-Json -Depth 30) + "`n")
    throw "Offline/reconnect stopped: $($failure.failureClass)"
  }
  $postReconnect = $null
  $after = $null
  try {
    Start-Sleep -Seconds 10
    $postReconnect = Wait-ManualSyncOutcome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build6-f4-offline-post-reconnect-existing' `
      -TimeoutSeconds 60
    if ($postReconnect.outcome -ne 'SUCCESS') {
      $postReconnect = Invoke-ManualSyncEvidence `
        -Adb $adb `
        -Serial $DeviceSerial `
        -EvidenceRoot $evidenceRoot `
        -Label 'build6-f4-offline-post-reconnect-new' `
        -TimeoutSeconds 120
    }
    Assert-Equal $postReconnect.outcome 'SUCCESS' `
      'Post-reconnect manual-sync outcome'
    $after = Get-LocalDiagnosticsEvidence `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build6-f4-offline-after'
    Assert-Equal $after.unsyncedRows 0 `
      'Post-reconnect pending local business writes'
  } catch {
    $failure = [ordered]@{
      schemaVersion = 1
      evidenceType = 'build-6-f4-physical-device-offline-reconnect-failure'
      capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
      promotionSha256 = $currentPromotionSha256
      syncMarkerReceiptSha256 = Get-Sha256 $syncMarkerReceiptPath
      installedApkSha256 = $expectedApk.sha256
      failureClass = 'POST_RECONNECT_VALIDATION_FAILED'
      initialTransport = $initialTransport
      observedTransportAfterFinally = $restoredTransport
      exactTransportStateRestored = $transportRestored
      offlineManualSyncOutcome = $offlineSync.outcome
      postReconnectManualSyncOutcome = if ($null -eq $postReconnect) {
        'NOT_OBSERVED'
      } else {
        $postReconnect.outcome
      }
      transportDisabledDurationSeconds = $transportDisabledDurationSeconds
      rawUiRetained = $false
      rawNetworkIdentifiersRetained = $false
      failedPhaseMayNotBeRelabelledPass = $true
      decision = 'FAIL_OFFLINE_RECONNECT_REQUIRES_ADJUDICATION'
    }
    Write-Utf8NoBom `
      -Path $offlineFailureReceiptPath `
      -Text (($failure | ConvertTo-Json -Depth 30) + "`n")
    throw 'Offline/reconnect stopped: POST_RECONNECT_VALIDATION_FAILED'
  }
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-offline-reconnect'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $currentPromotionSha256
    syncMarkerReceiptSha256 = Get-Sha256 $syncMarkerReceiptPath
    installedApkSha256 = $expectedApk.sha256
    initialTransport = $initialTransport
    offline = [ordered]@{
      allTransportsDisabled = $true
      transportStabilizationSeconds = 5
      manualSyncObservationTimeoutSeconds = 20
      measuredTransportDisabledDurationSeconds =
        $transportDisabledDurationSeconds
      approvedShellUiSha256 = $offlineUi.sha256
      manualSyncOutcome = $offlineSync.outcome
      falseSuccessObserved = $false
      remoteBusinessMutationAttempted = $false
    }
    restoration = [ordered]@{
      exactTransportStateRestored = $transportRestored
      postReconnectSyncOutcome = $postReconnect.outcome
      completionUiSha256 = $postReconnect.uiSha256
    }
    after = [ordered]@{
      diagnosticsUiSha256 = $after.uiSha256
      pendingLocalBusinessWrites = $after.unsyncedRows
    }
    rawUiRetained = $false
    rawNetworkIdentifiersRetained = $false
    decision = 'PASS_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY'
  }
  Write-Utf8NoBom `
    -Path $offlineReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $offlineReceiptPath -PathType Leaf)) {
  throw 'RunWeakNetwork requires the governed offline/reconnect receipt.'
}
$offlineReceipt = Get-Content -LiteralPath $offlineReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal $offlineReceipt.promotionSha256 $currentPromotionSha256 `
  'Offline/reconnect promotion SHA-256'
Assert-Equal `
  $offlineReceipt.syncMarkerReceiptSha256 `
  (Get-Sha256 $syncMarkerReceiptPath) `
  'Offline/reconnect sync-marker receipt SHA-256'
Assert-Equal $offlineReceipt.installedApkSha256 $expectedApk.sha256 `
  'Offline/reconnect installed APK SHA-256'
Assert-Equal $offlineReceipt.decision `
  'PASS_OFFLINE_SAFE_EXACT_TRANSPORT_RESTORATION_AND_SYNC_RECOVERY' `
  'Offline/reconnect decision'
Assert-Equal $offlineReceipt.restoration.exactTransportStateRestored $true `
  'Offline/reconnect transport restoration'
if ((Test-Path -LiteralPath $weakNetworkReceiptPath) -or
    (Test-Path -LiteralPath $weakNetworkFailureReceiptPath)) {
  throw 'RunWeakNetwork refuses to replace existing phase evidence.'
}
$before = Get-LocalDiagnosticsEvidence `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot `
  -Label 'build6-f4-weak-before'
Assert-Equal $before.unsyncedRows 0 `
  'Pre-profile pending local business writes'
$initialTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
Assert-Equal $initialTransport.airplaneModeOn 0 `
  'Pre-profile airplane-mode setting'
if ($initialTransport.wifiOn -eq 0 -and
    $initialTransport.mobileDataOn -eq 0) {
  throw 'Weak-network profile requires an initially enabled network transport.'
}
$events = @()
$profileSync = $null
$phaseError = $null
$restorationError = $null
$profileStartedAt = [DateTimeOffset]::UtcNow
try {
  for ($cycle = 1; $cycle -le 3; $cycle++) {
    $null = Set-TransportState `
      -Adb $adb `
      -Serial $DeviceSerial `
      -WifiOn 0 `
      -MobileDataOn 0
    $disconnectedStartedAt = [DateTimeOffset]::UtcNow
    Start-Sleep -Seconds 5
    $offlineHome = Move-ToApprovedHome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot
    if ($cycle -eq 1) {
      $profileSync = Invoke-ManualSyncEvidence `
        -Adb $adb `
        -Serial $DeviceSerial `
        -EvidenceRoot $evidenceRoot `
        -Label 'build6-f4-weak-profile-sync' `
        -TimeoutSeconds 8
      if ($profileSync.outcome -eq 'SUCCESS') {
        $phaseError = 'FALSE_SUCCESS_DURING_DISCONNECTED_PROFILE'
        break
      }
      $disconnectedFinalUi = Get-UiEvidence `
        -Adb $adb `
        -Serial $DeviceSerial `
        -EvidenceRoot $evidenceRoot `
        -Label 'build6-f4-weak-final-disconnected'
      if ($disconnectedFinalUi.text.Contains('Manual sync completed.')) {
        $phaseError = 'FALSE_SUCCESS_DURING_DISCONNECTED_PROFILE'
        break
      }
    }
    $disconnectedEndedAt = [DateTimeOffset]::UtcNow
    $disconnectedDurationSeconds = [math]::Round(
      ($disconnectedEndedAt - $disconnectedStartedAt).TotalSeconds,
      3
    )
    $events += [ordered]@{
      cycle = $cycle
      state = 'DISCONNECTED'
      measuredDurationSeconds = $disconnectedDurationSeconds
      approvedHomeUiSha256 = $offlineHome.sha256
    }
    $null = Set-TransportState `
      -Adb $adb `
      -Serial $DeviceSerial `
      -WifiOn $initialTransport.wifiOn `
      -MobileDataOn $initialTransport.mobileDataOn
    $restoredWindowStartedAt = [DateTimeOffset]::UtcNow
    Start-Sleep -Seconds 10
    $onlineHome = Move-ToApprovedHome `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot
    $restoredWindowEndedAt = [DateTimeOffset]::UtcNow
    $restoredWindowDurationSeconds = [math]::Round(
      ($restoredWindowEndedAt - $restoredWindowStartedAt).TotalSeconds,
      3
    )
    $events += [ordered]@{
      cycle = $cycle
      state = 'RESTORED_WINDOW'
      measuredDurationSeconds = $restoredWindowDurationSeconds
      approvedHomeUiSha256 = $onlineHome.sha256
    }
  }
} catch {
  $phaseError = 'INTERMITTENT_PROFILE_FAILED_CLOSED'
} finally {
  try {
    $null = Set-TransportState `
      -Adb $adb `
      -Serial $DeviceSerial `
      -WifiOn $initialTransport.wifiOn `
      -MobileDataOn $initialTransport.mobileDataOn
  } catch {
    $restorationError = 'TRANSPORT_RESTORATION_FAILED'
  }
}
$restoredTransport = Get-TransportState -Adb $adb -Serial $DeviceSerial
$transportRestored =
  $restoredTransport.wifiOn -eq $initialTransport.wifiOn -and
  $restoredTransport.mobileDataOn -eq $initialTransport.mobileDataOn -and
  $restoredTransport.airplaneModeOn -eq $initialTransport.airplaneModeOn
$profileDurationSeconds = [math]::Round(
  ([DateTimeOffset]::UtcNow - $profileStartedAt).TotalSeconds,
  3
)
if ($profileDurationSeconds -gt 120 -and $null -eq $phaseError) {
  $phaseError = 'INTERMITTENT_PROFILE_EXCEEDED_BOUND'
}
if (-not $transportRestored -or $null -ne $restorationError -or
    $null -ne $phaseError) {
  $failure = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-weak-network-failure'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $currentPromotionSha256
    offlineReconnectReceiptSha256 = Get-Sha256 $offlineReceiptPath
    installedApkSha256 = $expectedApk.sha256
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
    completedProfileEvents = $events.Count
    measuredProfileDurationSeconds = $profileDurationSeconds
    disconnectedManualSyncOutcome = if ($null -eq $profileSync) {
      'NOT_OBSERVED'
    } else {
      $profileSync.outcome
    }
    rawUiRetained = $false
    rawNetworkIdentifiersRetained = $false
    failedPhaseMayNotBeRelabelledPass = $true
    decision = 'FAIL_WEAK_NETWORK_REQUIRES_ADJUDICATION'
  }
  Write-Utf8NoBom `
    -Path $weakNetworkFailureReceiptPath `
    -Text (($failure | ConvertTo-Json -Depth 30) + "`n")
  throw "Weak-network profile stopped: $($failure.failureClass)"
}
$postProfile = $null
$after = $null
try {
  Start-Sleep -Seconds 10
  $postProfile = Invoke-ManualSyncEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-weak-post-profile' `
    -TimeoutSeconds 120
  Assert-Equal $postProfile.outcome 'SUCCESS' `
    'Post-profile manual-sync outcome'
  $after = Get-LocalDiagnosticsEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build6-f4-weak-after'
  Assert-Equal $after.unsyncedRows 0 `
    'Post-profile pending local business writes'
} catch {
  $failure = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-physical-device-weak-network-failure'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $currentPromotionSha256
    offlineReconnectReceiptSha256 = Get-Sha256 $offlineReceiptPath
    installedApkSha256 = $expectedApk.sha256
    failureClass = 'POST_PROFILE_VALIDATION_FAILED'
    initialTransport = $initialTransport
    observedTransportAfterFinally = $restoredTransport
    exactTransportStateRestored = $transportRestored
    completedProfileEvents = $events.Count
    measuredProfileDurationSeconds = $profileDurationSeconds
    disconnectedManualSyncOutcome = $profileSync.outcome
    postProfileManualSyncOutcome = if ($null -eq $postProfile) {
      'NOT_OBSERVED'
    } else {
      $postProfile.outcome
    }
    rawUiRetained = $false
    rawNetworkIdentifiersRetained = $false
    failedPhaseMayNotBeRelabelledPass = $true
    decision = 'FAIL_WEAK_NETWORK_REQUIRES_ADJUDICATION'
  }
  Write-Utf8NoBom `
    -Path $weakNetworkFailureReceiptPath `
    -Text (($failure | ConvertTo-Json -Depth 30) + "`n")
  throw 'Weak-network profile stopped: POST_PROFILE_VALIDATION_FAILED'
}
$receipt = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-6-f4-physical-device-weak-network'
  capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  promotionSha256 = $currentPromotionSha256
  offlineReconnectReceiptSha256 = Get-Sha256 $offlineReceiptPath
  installedApkSha256 = $expectedApk.sha256
  profile = [ordered]@{
    kind = 'THREE_CYCLE_TRANSPORT_INTERRUPTION'
    cycles = 3
    minimumDisconnectedHoldSecondsPerCycle = 5
    firstCycleSyncObservationTimeoutSeconds = 8
    minimumRestoredHoldSecondsPerCycle = 10
    maximumProfileSeconds = 120
    measuredProfileDurationSeconds = $profileDurationSeconds
    events = $events
    disconnectedManualSyncOutcome = $profileSync.outcome
    falseSuccessObservedWhileDisconnected = $false
  }
  restoration = [ordered]@{
    exactTransportStateRestored = $transportRestored
    postProfileSyncOutcome = $postProfile.outcome
    completionUiSha256 = $postProfile.uiSha256
  }
  after = [ordered]@{
    diagnosticsUiSha256 = $after.uiSha256
    pendingLocalBusinessWrites = $after.unsyncedRows
  }
  remainingRequiredPhases = @(
    'revocation-next-operation-denial',
    'wrong-role-denials'
  )
  programmeBoundary = [ordered]@{
    stage2dF4Status = 'OPEN'
    stage2dF4ClosureAuthorized = $false
    p07ClosureAuthorized = $false
    pilotHandoutAuthorized = $false
    separateEvidenceAdjudicationRequired = $true
  }
  rawUiRetained = $false
  rawNetworkIdentifiersRetained = $false
  decision = 'PASS_BOUNDED_INTERMITTENT_NETWORK_AND_SYNC_RECOVERY'
}
Write-Utf8NoBom `
  -Path $weakNetworkReceiptPath `
  -Text (($receipt | ConvertTo-Json -Depth 40) + "`n")
$receipt | ConvertTo-Json -Depth 40
