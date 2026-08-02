#requires -Version 7.0
<#
.SYNOPSIS
Runs the exact-target Build 7 Firestore compatibility campaign.

.DESCRIPTION
Preflight is read-only. Upgrade replaces exact installed Build 6 with exact
Build 7 while preserving the application sandbox. ProveRead uses existing app
surfaces to pull and render the one controlled stamped knowledge row. RetireRow
performs the sole authorized production mutation through Knowledge Governance.
The two Finalize phases are evidence-only recovery paths and never repeat their
corresponding mutation.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet(
    'Preflight',
    'Upgrade',
    'FinalizeUpgrade',
    'ProveRead',
    'RetireRow',
    'FinalizeRetirement'
  )]
  [string]$Phase = 'Preflight',

  [Parameter(Mandatory)]
  [string]$GovernedPackagePath,

  [Parameter(Mandatory)]
  [string]$Build6EvidenceDirectory,

  [Parameter(Mandatory)]
  [string]$DeviceSerial,

  [Parameter(Mandatory)]
  [string]$EvidenceDirectory,

  [string]$PromotionPath =
    'release/approvals/build-7-f4-firestore-compatibility-promotion.json',

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

function Assert-True {
  param(
    [Parameter(Mandatory)][bool]$Condition,
    [Parameter(Mandatory)][string]$Label
  )

  if (-not $Condition) {
    throw "$Label was not proved."
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

function Get-PackageState {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$PackageId,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$ApkSigner,
    [Parameter(Mandatory)][string]$ExpectedCertificateSha256
  )

  $pathOutput = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pm', 'path', $PackageId
  )).output
  $basePaths = @($pathOutput -split "`n" | Where-Object {
    $_.StartsWith('package:') -and $_.Contains('/base.apk')
  })
  if ($basePaths.Count -ne 1) {
    throw 'The installed CRM-III base APK path is not uniquely available.'
  }

  $temporaryApk = Join-Path $EvidenceRoot '.installed-package-evidence.apk'
  try {
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'pull',
      $basePaths[0].Substring('package:'.Length),
      $temporaryApk
    )
    $signer = (Invoke-ExternalText -FilePath $ApkSigner -Arguments @(
      'verify', '--print-certs', $temporaryApk
    )).output.Replace(':', '').ToUpperInvariant()
    $dump = (Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'dumpsys', 'package', $PackageId
    )).output
    $versionCode = [regex]::Match($dump, '(?m)versionCode=(\d+)')
    $versionName = [regex]::Match($dump, '(?m)versionName=([^\r\n]+)')
    $firstInstall = [regex]::Match($dump, '(?m)firstInstallTime=([^\r\n]+)')
    $lastUpdate = [regex]::Match($dump, '(?m)lastUpdateTime=([^\r\n]+)')
    if (-not $versionCode.Success -or
        -not $versionName.Success -or
        -not $firstInstall.Success -or
        -not $lastUpdate.Success) {
      throw 'Installed package version and time state is incomplete.'
    }
    [pscustomobject]@{
      apkSha256 = Get-Sha256 $temporaryApk
      versionCode = [int]$versionCode.Groups[1].Value
      versionName = $versionName.Groups[1].Value.Trim()
      firstInstallTime = $firstInstall.Groups[1].Value.Trim()
      lastUpdateTime = $lastUpdate.Groups[1].Value.Trim()
      certificateMatches = $signer.Contains($ExpectedCertificateSha256)
    }
  } finally {
    if (Test-Path -LiteralPath $temporaryApk) {
      Remove-Item -LiteralPath $temporaryApk -Force
    }
  }
}

function Assert-PackageState {
  param(
    [Parameter(Mandatory)]$State,
    [Parameter(Mandatory)][int]$VersionCode,
    [Parameter(Mandatory)][string]$VersionName,
    [Parameter(Mandatory)][string]$ApkSha256,
    [Parameter(Mandatory)][string]$Label
  )

  Assert-Equal $State.versionCode $VersionCode "$Label version code"
  Assert-Equal $State.versionName $VersionName "$Label version name"
  Assert-Equal $State.apkSha256 $ApkSha256 "$Label APK SHA-256"
  Assert-Equal $State.certificateMatches $true "$Label signer"
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
    if (-not $captured) {
      throw 'UI hierarchy capture did not produce the expected local file.'
    }
    [pscustomobject]@{
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
    [Parameter(Mandatory)][string]$UiText,
    [Parameter(Mandatory)][string]$XPath,
    [Parameter(Mandatory)][string]$Label,
    [switch]$NearestClickableAncestor
  )

  [xml]$document = $UiText
  $node = $document.SelectSingleNode($XPath)
  if ($null -eq $node) {
    throw "Could not find UI control: $Label"
  }
  if ($NearestClickableAncestor) {
    $cursor = $node
    while ($null -ne $cursor -and $cursor.Name -eq 'node') {
      if ([string]$cursor.clickable -eq 'true') {
        $node = $cursor
        break
      }
      $cursor = $cursor.ParentNode
    }
  }
  $bounds = [string]$node.bounds
  $match = [regex]::Match($bounds, '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$')
  if (-not $match.Success) {
    throw "$Label bounds are malformed: $bounds"
  }
  [pscustomobject]@{
    x = [int](([int]$match.Groups[1].Value +
        [int]$match.Groups[3].Value) / 2)
    y = [int](([int]$match.Groups[2].Value +
        [int]$match.Groups[4].Value) / 2)
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

function Invoke-UiMarkerTap {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Marker,
    [Parameter(Mandatory)][string]$XPath,
    [int]$ScrollAttempts = 0,
    [switch]$NearestClickableAncestor
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
        -Label $Marker `
        -NearestClickableAncestor:$NearestClickableAncestor
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

function Move-ToUiMarker {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Marker,
    [int]$ScrollAttempts = 0
  )

  for ($attempt = 0; $attempt -le $ScrollAttempts; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "$Label-$attempt"
    if ($ui.text.Contains($Marker)) {
      return $ui
    }
    if ($attempt -lt $ScrollAttempts) {
      $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
        '-s', $Serial, 'shell', 'input', 'swipe',
        '540', '1800', '540', '650', '450'
      )
      Start-Sleep -Seconds 1
    }
  }
  throw "Could not reach UI marker: $Marker"
}

function Wait-UiState {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [string[]]$RequiredMarkers = @(),
    [string[]]$ForbiddenMarkers = @(),
    [string[]]$AbsentMarkers = @(),
    [int]$TimeoutSeconds = 60
  )

  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label $Label
    $missing = @($RequiredMarkers | Where-Object {
      -not $ui.text.Contains($_)
    })
    $forbidden = @($ForbiddenMarkers | Where-Object {
      $ui.text.Contains($_)
    })
    $presentButRequiredAbsent = @($AbsentMarkers | Where-Object {
      $ui.text.Contains($_)
    })
    if ($missing.Count -eq 0 -and
        $forbidden.Count -eq 0 -and
        $presentButRequiredAbsent.Count -eq 0) {
      return $ui
    }
    if ($forbidden.Count -gt 0) {
      throw "Forbidden UI state reached: $($forbidden -join ', ')"
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  throw "Expected UI state was not reached: $($RequiredMarkers -join ', ')"
}

function Get-ApprovedHomeEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot
  )

  Wait-UiState `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label 'build7-approved-home' `
    -RequiredMarkers @('Home', 'Issues', 'Work', 'Directives', 'More', 'Core modules') `
    -ForbiddenMarkers @(
      'Sign in with Google',
      'Awaiting Approval',
      'User profile error',
      '[cloud_firestore/permission-denied]',
      'Sign-in failed'
    ) `
    -TimeoutSeconds 120
}

function Move-ToApprovedHome {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot
  )

  for ($attempt = 0; $attempt -le 6; $attempt++) {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label "build7-home-navigation-$attempt"
    if ($ui.text.Contains('Core modules') -and $ui.text.Contains('Home')) {
      return Get-ApprovedHomeEvidence `
        -Adb $Adb `
        -Serial $Serial `
        -EvidenceRoot $EvidenceRoot
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
        # A pushed route can contain non-navigation Home text.
      }
    }
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'input', 'keyevent', '4'
    )
    Start-Sleep -Seconds 1
  }
  throw 'The approved Home navigation surface could not be restored.'
}

function Open-MoreModule {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$ModuleTitle,
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
  Start-Sleep -Seconds 1
  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label "$Label-module" `
    -Marker $ModuleTitle `
    -XPath "//node[@text='$ModuleTitle' or contains(@content-desc,'$ModuleTitle')]" `
    -ScrollAttempts 8 `
    -NearestClickableAncestor
  Start-Sleep -Seconds 2
}

function Enter-UiText {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Marker,
    [Parameter(Mandatory)][string]$XPath,
    [Parameter(Mandatory)][string]$Text,
    [int]$ScrollAttempts = 0
  )

  $null = Invoke-UiMarkerTap `
    -Adb $Adb `
    -Serial $Serial `
    -EvidenceRoot $EvidenceRoot `
    -Label $Label `
    -Marker $Marker `
    -XPath $XPath `
    -ScrollAttempts $ScrollAttempts
  $encoded = $Text.Replace(' ', '%s')
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'text', $encoded
  )
  Start-Sleep -Seconds 1
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'input', 'keyevent', '4'
  )
  Start-Sleep -Seconds 1
}

function Test-RowLifecycleInUi {
  param(
    [Parameter(Mandatory)][string]$UiText,
    [Parameter(Mandatory)][string]$DocumentId,
    [Parameter(Mandatory)][string]$Lifecycle
  )

  [xml]$document = $UiText
  $row = $document.SelectSingleNode("//node[@text='$DocumentId']")
  if ($null -eq $row) {
    return $false
  }
  $cursor = $row
  while ($null -ne $cursor -and $cursor.Name -eq 'node') {
    if ([string]$cursor.clickable -eq 'true') {
      return $null -ne $cursor.SelectSingleNode(
        ".//node[@text='$Lifecycle']"
      )
    }
    $cursor = $cursor.ParentNode
  }
  return $false
}

function Wait-RowLifecycle {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$DocumentId,
    [Parameter(Mandatory)][string]$Lifecycle,
    [string[]]$AbsentMarkers = @(),
    [int]$TimeoutSeconds = 90
  )

  $forbidden = @(
    'Failed to load knowledge base',
    'KnowledgeGovernanceException',
    '[cloud_firestore/',
    'User profile error'
  )
  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $ui = Get-UiEvidence `
      -Adb $Adb `
      -Serial $Serial `
      -EvidenceRoot $EvidenceRoot `
      -Label $Label
    $bad = @($forbidden | Where-Object { $ui.text.Contains($_) })
    if ($bad.Count -gt 0) {
      throw "Knowledge UI entered a forbidden state: $($bad -join ', ')"
    }
    $absentSatisfied = @($AbsentMarkers | Where-Object {
      $ui.text.Contains($_)
    }).Count -eq 0
    if ($absentSatisfied -and (Test-RowLifecycleInUi `
        -UiText $ui.text `
        -DocumentId $DocumentId `
        -Lifecycle $Lifecycle)) {
      return $ui
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  throw "The controlled row was not rendered as $Lifecycle."
}

function Start-Crm3Application {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$PackageId
  )

  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'monkey',
    '-p', $PackageId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )
  Start-Sleep -Seconds 3
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
$build6EvidenceRoot = (Resolve-Path -LiteralPath $Build6EvidenceDirectory).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json
$promotionSha256 = Get-Sha256 $promotionFile

Assert-Equal $promotion.schemaVersion 1 'Promotion schema version'
Assert-Equal `
  $promotion.approvalClass `
  'CONTROLLED_EXACT_TARGET_BUILD7_FIRESTORE_COMPATIBILITY_EXECUTION' `
  'Promotion class'
Assert-Equal $promotion.channel.maxTargetCount 1 'Maximum target count'
Assert-Equal $promotion.channel.inPlaceUpgradeAuthorized $true `
  'In-place upgrade authorization'
Assert-Equal $promotion.channel.freshInstallAuthorized $false `
  'Fresh-install authorization'
Assert-Equal $promotion.channel.externalDistributionAuthorized $false `
  'External distribution authorization'
Assert-Equal $promotion.programmeBoundary.stage2dF4ClosureAuthorized $false `
  'F4 closure authorization'
Assert-Equal $promotion.programmeBoundary.pilotHandoutAuthorized $false `
  'Pilot handout authorization'

$closureFile = (Resolve-Path -LiteralPath (
  Join-Path $root $promotion.build7ArtifactAuthority.finalizationReceipt.path
)).Path
Assert-Equal `
  (Get-Sha256 $closureFile) `
  $promotion.build7ArtifactAuthority.finalizationReceipt.sha256 `
  'Build 7 finalization receipt SHA-256'
$closure = Get-Content -LiteralPath $closureFile -Raw | ConvertFrom-Json
Assert-Equal $closure.status 'passed-non-distributable' `
  'Build 7 finalization status'
Assert-Equal `
  $closure.governedPackage.sha256 `
  $promotion.build7ArtifactAuthority.governedPackage.sha256 `
  'Build 7 finalization package SHA-256'
Assert-Equal `
  $closure.governedPackage.apkSha256 `
  $promotion.build7ArtifactAuthority.apk.sha256 `
  'Build 7 finalization APK SHA-256'

$build6PromotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $promotion.build6Lineage.physicalExecutionPromotion.path
)).Path
Assert-Equal `
  (Get-Sha256 $build6PromotionFile) `
  $promotion.build6Lineage.physicalExecutionPromotion.sha256 `
  'Build 6 physical promotion SHA-256'

$build6ReceiptBindings = [ordered]@{
  'preflight-receipt.json' =
    $promotion.build6Lineage.privateEvidence.preflightReceiptSha256
  'install-receipt.json' =
    $promotion.build6Lineage.privateEvidence.installReceiptSha256
  'approved-signin-receipt.json' =
    $promotion.build6Lineage.privateEvidence.approvedSigninReceiptSha256
  'sync-baseline-receipt.json' =
    $promotion.build6Lineage.privateEvidence.syncBaselineReceiptSha256
  'run-sync-marker-retry2.stderr.log' =
    $promotion.build6Lineage.privateEvidence.failedCompatibilityLogSha256
}
foreach ($entry in $build6ReceiptBindings.GetEnumerator()) {
  Assert-Equal `
    (Get-Sha256 (Join-Path $build6EvidenceRoot $entry.Key)) `
    $entry.Value `
    "Build 6 private evidence $($entry.Key) SHA-256"
}
$build6InstallReceipt = Get-Content -LiteralPath (
  Join-Path $build6EvidenceRoot 'install-receipt.json'
) -Raw | ConvertFrom-Json
$build6SignInReceipt = Get-Content -LiteralPath (
  Join-Path $build6EvidenceRoot 'approved-signin-receipt.json'
) -Raw | ConvertFrom-Json
$build6BaselineReceipt = Get-Content -LiteralPath (
  Join-Path $build6EvidenceRoot 'sync-baseline-receipt.json'
) -Raw | ConvertFrom-Json
Assert-Equal `
  $build6InstallReceipt.decision `
  'PASS_EXACT_BUILD6_INSTALLED_ON_BOUND_PHYSICAL_TARGET' `
  'Build 6 install decision'
Assert-Equal `
  $build6SignInReceipt.decision `
  'PASS_APPROVED_SIGNIN_CAPTURED_FULL_F4_MATRIX_REMAINS_OPEN' `
  'Build 6 sign-in decision'
Assert-Equal `
  $build6BaselineReceipt.decision `
  'PASS_ZERO_PENDING_LOCAL_WRITES_SYNC_BASELINE' `
  'Build 6 local baseline decision'
Assert-Equal $build6BaselineReceipt.localDiagnostics.unsyncedRows 0 `
  'Build 6 pending local writes'

Assert-Equal `
  (Get-Sha256 $packageFile) `
  $promotion.build7ArtifactAuthority.governedPackage.sha256 `
  'Build 7 governed package SHA-256'
Assert-Equal `
  (Get-Item -LiteralPath $packageFile).Length `
  $promotion.build7ArtifactAuthority.governedPackage.bytes `
  'Build 7 governed package bytes'

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
  throw 'Build 7 compatibility execution requires exact tracked-clean main equal to freshly fetched origin/main.'
}
if ($gitHead -eq $promotion.approvalAuthority.baselineCommit) {
  throw 'The Build 7 compatibility promotion is not effective on its unmodified baseline.'
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
$apkSigner = Get-AndroidTool `
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
Assert-True $gms.StartsWith('package:') `
  'Google Play Services on the bound target'

$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) +
  [IO.Path]::DirectorySeparatorChar
if ($evidenceRoot.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
    $evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'EvidenceDirectory must be outside the repository.'
}
$apkPath = Join-Path $evidenceRoot 'governed-build7.apk'
$preflightReceiptPath = Join-Path $evidenceRoot 'preflight-receipt.json'
$upgradeReceiptPath = Join-Path $evidenceRoot 'upgrade-receipt.json'
$readReceiptPath = Join-Path $evidenceRoot 'stamped-row-read-receipt.json'
$retirementCompletionWitnessPath =
  Join-Path $evidenceRoot 'controlled-row-retirement-completion-witness.json'
$retirementReceiptPath = Join-Path $evidenceRoot 'controlled-row-retirement-receipt.json'
$applicationId = [string]$promotion.build7ArtifactAuthority.applicationId
$build7Apk = $promotion.build7ArtifactAuthority.apk
$certificateSha256 = [string]$promotion.build7ArtifactAuthority.signer.certificateSha256
$controlledDocumentId = [string]$promotion.controlledRecordAuthority.documentId
$retirementReason = [string]$promotion.controlledRecordAuthority.retirementReason

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
    -EntryName $build7Apk.entryName `
    -Destination $apkPath
  Assert-Equal (Get-Sha256 $apkPath) $build7Apk.sha256 `
    'Embedded Build 7 APK SHA-256'
  Assert-Equal (Get-Item -LiteralPath $apkPath).Length $build7Apk.bytes `
    'Embedded Build 7 APK bytes'

  $badging = (Invoke-ExternalText -FilePath $aapt -Arguments @(
    'dump', 'badging', $apkPath
  )).output
  Assert-True `
    ($badging -match "package: name='$([regex]::Escape($applicationId))'") `
    'Build 7 package id'
  Assert-True ($badging -match "versionCode='7'") 'Build 7 version code'
  Assert-True ($badging -notmatch '(?m)^application-debuggable') `
    'Build 7 non-debuggable state'
  $signer = (Invoke-ExternalText -FilePath $apkSigner -Arguments @(
    'verify', '--print-certs', $apkPath
  )).output.Replace(':', '').ToUpperInvariant()
  Assert-True $signer.Contains($certificateSha256) 'Build 7 signer'

  $installed = Get-PackageState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId `
    -EvidenceRoot $evidenceRoot `
    -ApkSigner $apkSigner `
    -ExpectedCertificateSha256 $certificateSha256
  Assert-PackageState `
    -State $installed `
    -VersionCode ([int]$promotion.build6Lineage.versionCode) `
    -VersionName $promotion.build7ArtifactAuthority.versionName `
    -ApkSha256 $promotion.build6Lineage.installedApkSha256 `
    -Label 'Installed Build 6 precondition'

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-7-f4-firestore-compatibility-preflight'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $promotionSha256
    build7FinalizationReceiptSha256 = Get-Sha256 $closureFile
    source = [ordered]@{
      head = $gitHead
      originMain = $originMain
      trackedClean = $true
    }
    build7Artifact = [ordered]@{
      governedPackageSha256 = Get-Sha256 $packageFile
      apkSha256 = Get-Sha256 $apkPath
      versionCode = 7
      debuggable = $false
      certificateSha256 = $certificateSha256
    }
    installedBuild6 = [ordered]@{
      apkSha256 = $installed.apkSha256
      versionCode = $installed.versionCode
      versionName = $installed.versionName
      firstInstallTime = $installed.firstInstallTime
      signerMatched = $installed.certificateMatches
    }
    build6Evidence = [ordered]@{
      installReceiptSha256 = Get-Sha256 (
        Join-Path $build6EvidenceRoot 'install-receipt.json'
      )
      approvedSigninReceiptSha256 = Get-Sha256 (
        Join-Path $build6EvidenceRoot 'approved-signin-receipt.json'
      )
      syncBaselineReceiptSha256 = Get-Sha256 (
        Join-Path $build6EvidenceRoot 'sync-baseline-receipt.json'
      )
      pendingLocalWrites = 0
    }
    target = [ordered]@{
      adbSerialSha256 = Get-TextSha256 $DeviceSerial
      buildFingerprintSha256 = $promotion.targetAuthority.buildFingerprintSha256
      physicalDevice = $true
      googlePlayServicesPresent = $true
      rawIdentifiersRetained = $false
    }
    mutationBoundary = [ordered]@{
      packageUpgraded = $false
      applicationLaunched = $false
      remoteMutationPerformed = $false
    }
    decision = 'PASS_BUILD7_COMPATIBILITY_PREFLIGHT_EXACT_BUILD6_INSTALLED'
  }
  Write-Utf8NoBom `
    -Path $preflightReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $preflightReceiptPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
  throw "$Phase requires the governed Build 7 preflight evidence."
}
$preflight = Get-Content -LiteralPath $preflightReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal $preflight.promotionSha256 $promotionSha256 `
  'Preflight promotion SHA-256'
Assert-Equal `
  $preflight.decision `
  'PASS_BUILD7_COMPATIBILITY_PREFLIGHT_EXACT_BUILD6_INSTALLED' `
  'Preflight decision'
Assert-Equal (Get-Sha256 $apkPath) $build7Apk.sha256 `
  'Campaign Build 7 APK SHA-256'

if ($Phase -in @('Upgrade', 'FinalizeUpgrade')) {
  if (Test-Path -LiteralPath $upgradeReceiptPath) {
    throw "$Phase refuses to replace an existing upgrade receipt."
  }
  $installedBefore = Get-PackageState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId `
    -EvidenceRoot $evidenceRoot `
    -ApkSigner $apkSigner `
    -ExpectedCertificateSha256 $certificateSha256
  $recoveryMode = 'NONE'
  if ($Phase -eq 'Upgrade') {
    Assert-PackageState `
      -State $installedBefore `
      -VersionCode 6 `
      -VersionName $promotion.build7ArtifactAuthority.versionName `
      -ApkSha256 $promotion.build6Lineage.installedApkSha256 `
      -Label 'Build 6 upgrade precondition'
    Assert-Equal `
      $installedBefore.firstInstallTime `
      $preflight.installedBuild6.firstInstallTime `
      'Build 6 first-install time before upgrade'
    if (-not $PSCmdlet.ShouldProcess(
        $promotion.targetAuthority.adbSerialSha256,
        'Upgrade exact installed Build 6 to exact Build 7')) {
      exit 0
    }
    $upgrade = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'install', '--no-streaming', '-r', $apkPath
    )
    Assert-True $upgrade.output.Contains('Success') `
      'Build 7 in-place upgrade result'
  } else {
    Assert-PackageState `
      -State $installedBefore `
      -VersionCode 7 `
      -VersionName $promotion.build7ArtifactAuthority.versionName `
      -ApkSha256 $build7Apk.sha256 `
      -Label 'Interrupted Build 7 upgrade state'
    $recoveryMode = 'INTERRUPTED_AFTER_UPGRADE_BEFORE_RECEIPT'
  }

  $installedAfter = Get-PackageState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId `
    -EvidenceRoot $evidenceRoot `
    -ApkSigner $apkSigner `
    -ExpectedCertificateSha256 $certificateSha256
  Assert-PackageState `
    -State $installedAfter `
    -VersionCode 7 `
    -VersionName $promotion.build7ArtifactAuthority.versionName `
    -ApkSha256 $build7Apk.sha256 `
    -Label 'Installed Build 7'
  Assert-Equal `
    $installedAfter.firstInstallTime `
    $preflight.installedBuild6.firstInstallTime `
    'Application sandbox first-install continuity'

  Start-Crm3Application `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId
  $approvedHome = Get-ApprovedHomeEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-7-f4-in-place-upgrade'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $promotionSha256
    preflightReceiptSha256 = Get-Sha256 $preflightReceiptPath
    recoveryMode = $recoveryMode
    installedApkSha256 = $installedAfter.apkSha256
    versionCodeBefore = 6
    versionCodeAfter = $installedAfter.versionCode
    firstInstallTimePreserved = $true
    applicationSandboxPreserved = $true
    approvedSessionPreserved = $true
    approvedHomeUiSha256 = $approvedHome.sha256
    rawUiRetained = $false
    remoteMutationPerformed = $false
    programmeBoundary = [ordered]@{
      stage2dF4Status = 'OPEN'
      stage2dF4ClosureAuthorized = $false
      p07ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
    }
    decision = 'PASS_EXACT_BUILD7_IN_PLACE_UPGRADE_SESSION_PRESERVED'
  }
  Write-Utf8NoBom `
    -Path $upgradeReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $upgradeReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed Build 7 upgrade receipt."
}
$upgradeReceipt = Get-Content -LiteralPath $upgradeReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $upgradeReceipt.decision `
  'PASS_EXACT_BUILD7_IN_PLACE_UPGRADE_SESSION_PRESERVED' `
  'Build 7 upgrade decision'
Assert-Equal $upgradeReceipt.promotionSha256 $promotionSha256 `
  'Build 7 upgrade promotion SHA-256'

$installedBuild7 = Get-PackageState `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $applicationId `
  -EvidenceRoot $evidenceRoot `
  -ApkSigner $apkSigner `
  -ExpectedCertificateSha256 $certificateSha256
Assert-PackageState `
  -State $installedBuild7 `
  -VersionCode 7 `
  -VersionName $promotion.build7ArtifactAuthority.versionName `
  -ApkSha256 $build7Apk.sha256 `
  -Label 'Installed Build 7 phase precondition'

if ($Phase -eq 'ProveRead') {
  if (Test-Path -LiteralPath $readReceiptPath) {
    throw 'ProveRead refuses to replace an existing read receipt.'
  }
  Start-Crm3Application `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $applicationId
  $null = Get-ApprovedHomeEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot

  Open-MoreModule `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -ModuleTitle 'Template Authoring' `
    -Label 'build7-template-authoring'
  $moduleComposer = Wait-UiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-module-composer' `
    -RequiredMarkers @('Module Composer') `
    -ForbiddenMarkers @(
      'Recover unsaved composer draft?',
      'Knowledge source unavailable',
      '[cloud_firestore/'
    ) `
    -TimeoutSeconds 120
  $null = Move-ToUiMarker `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-knowledge-loader-marker' `
    -Marker 'Search asset, tag, task, procedure' `
    -ScrollAttempts 8
  $knowledgeLoader = Wait-UiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-knowledge-loader-settled' `
    -RequiredMarkers @('Search asset, tag, task, procedure') `
    -ForbiddenMarkers @(
      'Knowledge source unavailable',
      'Knowledge source returned no active rows',
      '[cloud_firestore/'
    ) `
    -AbsentMarkers @('class="android.widget.ProgressBar"') `
    -TimeoutSeconds 120

  Open-MoreModule `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -ModuleTitle 'Knowledge Governance' `
    -Label 'build7-knowledge-governance'
  $null = Wait-UiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-knowledge-governance-ready' `
    -RequiredMarkers @('Knowledge Governance', 'Rows') `
    -ForbiddenMarkers @('Failed to load knowledge base', '[cloud_firestore/') `
    -TimeoutSeconds 90
  Enter-UiText `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-governance-search' `
    -Marker 'Search rowCode' `
    -XPath "//node[contains(@text,'Search rowCode') or contains(@content-desc,'Search rowCode')]" `
    -Text $controlledDocumentId
  $rowEvidence = Wait-RowLifecycle `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-stamped-row-active' `
    -DocumentId $controlledDocumentId `
    -Lifecycle 'active' `
    -TimeoutSeconds 90

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-7-f4-stamped-knowledge-row-read'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $promotionSha256
    upgradeReceiptSha256 = Get-Sha256 $upgradeReceiptPath
    installedApkSha256 = $installedBuild7.apkSha256
    controlledDocument = "knowledge_base/$controlledDocumentId"
    templateAuthoringKnowledgeLoaderSettled = $true
    moduleComposerUiSha256 = $moduleComposer.sha256
    knowledgeLoaderSettledUiSha256 = $knowledgeLoader.sha256
    governanceRowUiSha256 = $rowEvidence.sha256
    renderedLifecycle = 'active'
    firestoreTimestampDecodeClaimed = $false
    compatibilityProofDeferredToGovernedPostWritePull = $true
    rawUiRetained = $false
    remoteMutationPerformed = $false
    programmeBoundary = [ordered]@{
      stage2dF4Status = 'OPEN'
      stage2dF4ClosureAuthorized = $false
      p07ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
    }
    decision = 'PASS_BUILD7_CONTROLLED_ROW_ACTIVE_PRECONDITION'
  }
  Write-Utf8NoBom `
    -Path $readReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if (-not (Test-Path -LiteralPath $readReceiptPath -PathType Leaf)) {
  throw "$Phase requires the separate passing stamped-row read receipt."
}
$readReceipt = Get-Content -LiteralPath $readReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $readReceipt.decision `
  'PASS_BUILD7_CONTROLLED_ROW_ACTIVE_PRECONDITION' `
  'Stamped-row read decision'
Assert-Equal $readReceipt.promotionSha256 $promotionSha256 `
  'Stamped-row read promotion SHA-256'
Assert-Equal $readReceipt.controlledDocument "knowledge_base/$controlledDocumentId" `
  'Stamped-row read document'

if ($Phase -notin @('RetireRow', 'FinalizeRetirement')) {
  throw "Unsupported phase reached: $Phase"
}
if (Test-Path -LiteralPath $retirementReceiptPath) {
  throw "$Phase refuses to replace an existing retirement receipt."
}
if ($Phase -eq 'RetireRow' -and
    (Test-Path -LiteralPath $retirementCompletionWitnessPath)) {
  throw 'RetireRow found a completion witness. Use FinalizeRetirement; do not write the lifecycle transition again.'
}
$completionWitness = $null
if ($Phase -eq 'FinalizeRetirement') {
  if (-not (Test-Path -LiteralPath $retirementCompletionWitnessPath -PathType Leaf)) {
    throw 'FinalizeRetirement requires the governed completion witness; row state alone is insufficient.'
  }
  $completionWitness = Get-Content `
    -LiteralPath $retirementCompletionWitnessPath `
    -Raw | ConvertFrom-Json
  Assert-Equal `
    $completionWitness.decision `
    'PASS_BUILD7_GOVERNED_RETIREMENT_PULL_AUDIT_AND_RENDER' `
    'Retirement completion witness decision'
  Assert-Equal $completionWitness.promotionSha256 $promotionSha256 `
    'Retirement completion witness promotion SHA-256'
  Assert-Equal `
    $completionWitness.readReceiptSha256 `
    (Get-Sha256 $readReceiptPath) `
    'Retirement completion witness read-receipt SHA-256'
  Assert-Equal `
    $completionWitness.controlledDocument `
    "knowledge_base/$controlledDocumentId" `
    'Retirement completion witness document'
  Assert-Equal $completionWitness.governanceAuditCompleted $true `
    'Retirement completion witness governance audit'
}

Start-Crm3Application `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $applicationId
$null = Get-ApprovedHomeEvidence `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot
Open-MoreModule `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot `
  -ModuleTitle 'Knowledge Governance' `
  -Label 'build7-retirement-governance'
$null = Wait-UiState `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot `
  -Label 'build7-retirement-governance-ready' `
  -RequiredMarkers @('Knowledge Governance', 'Rows') `
  -ForbiddenMarkers @('Failed to load knowledge base', '[cloud_firestore/') `
  -TimeoutSeconds 90
Enter-UiText `
  -Adb $adb `
  -Serial $DeviceSerial `
  -EvidenceRoot $evidenceRoot `
  -Label 'build7-retirement-search' `
  -Marker 'Search rowCode' `
  -XPath "//node[contains(@text,'Search rowCode') or contains(@content-desc,'Search rowCode')]" `
  -Text $controlledDocumentId

$recoveryMode = 'NONE'
$postWritePullEvidence = 'NOT_OBSERVED'
if ($Phase -eq 'RetireRow') {
  $activeRow = Wait-RowLifecycle `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retirement-active-precondition' `
    -DocumentId $controlledDocumentId `
    -Lifecycle 'active' `
    -TimeoutSeconds 60
  $null = Invoke-UiMarkerTap `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-include-retired-filter' `
    -Marker 'retired' `
    -XPath "//node[@text='retired']" `
    -NearestClickableAncestor
  Start-Sleep -Seconds 1
  $rowCenter = Get-NodeCenter `
    -UiText $activeRow.text `
    -XPath "//node[@text='$controlledDocumentId']" `
    -Label $controlledDocumentId `
    -NearestClickableAncestor
  Invoke-UiTap -Adb $adb -Serial $DeviceSerial -Center $rowCenter
  $null = Wait-UiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-row-editor' `
    -RequiredMarkers @('Edit row', $controlledDocumentId, 'Retire') `
    -ForbiddenMarkers @('[cloud_firestore/', 'KnowledgeGovernanceException') `
    -TimeoutSeconds 60
  if (-not $PSCmdlet.ShouldProcess(
      "knowledge_base/$controlledDocumentId",
      'Retire the exact controlled F4 compatibility row')) {
    exit 0
  }
  $null = Invoke-UiMarkerTap `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retire-action' `
    -Marker 'Retire' `
    -XPath "//node[@text='Retire' or contains(@content-desc,'Retire')]" `
    -NearestClickableAncestor
  $null = Wait-UiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retirement-reason-dialog' `
    -RequiredMarkers @('Reason for retired') `
    -ForbiddenMarkers @('[cloud_firestore/') `
    -TimeoutSeconds 30
  Enter-UiText `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retirement-reason' `
    -Marker 'Why is this row being changed?' `
    -XPath "//node[@class='android.widget.EditText']" `
    -Text $retirementReason
  $null = Invoke-UiMarkerTap `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retirement-confirm' `
    -Marker 'retired' `
    -XPath "//node[@text='retired']" `
    -NearestClickableAncestor
  $retiredRow = Wait-RowLifecycle `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retired-row-result' `
    -DocumentId $controlledDocumentId `
    -Lifecycle 'retired' `
    -AbsentMarkers @('Edit row', 'Reason for retired') `
    -TimeoutSeconds 120
  $completionWitness = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-7-f4-governed-retirement-completion-witness'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = $promotionSha256
    readReceiptSha256 = Get-Sha256 $readReceiptPath
    installedApkSha256 = $installedBuild7.apkSha256
    controlledDocument = "knowledge_base/$controlledDocumentId"
    finalLifecycle = 'retired'
    governedControllerCompleted = $true
    postWriteCloudPullCompleted = $true
    governanceAuditCompleted = $true
    retiredRowUiSha256 = $retiredRow.sha256
    rawUiRetained = $false
    decision = 'PASS_BUILD7_GOVERNED_RETIREMENT_PULL_AUDIT_AND_RENDER'
  }
  Write-Utf8NoBom `
    -Path $retirementCompletionWitnessPath `
    -Text (($completionWitness | ConvertTo-Json -Depth 30) + "`n")
  $postWritePullEvidence = 'DIRECT_CHAINED_COMPLETION_WITNESS_AND_LOCAL_RETIRED_RENDER'
} else {
  $currentUi = Get-UiEvidence `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-retirement-finalization-initial'
  if (Test-RowLifecycleInUi `
      -UiText $currentUi.text `
      -DocumentId $controlledDocumentId `
      -Lifecycle 'active') {
    throw 'FinalizeRetirement refuses an active controlled row.'
  }
  if (-not (Test-RowLifecycleInUi `
      -UiText $currentUi.text `
      -DocumentId $controlledDocumentId `
      -Lifecycle 'retired')) {
    $null = Invoke-UiMarkerTap `
      -Adb $adb `
      -Serial $DeviceSerial `
      -EvidenceRoot $evidenceRoot `
      -Label 'build7-finalization-include-retired-filter' `
      -Marker 'retired' `
      -XPath "//node[@text='retired']" `
      -NearestClickableAncestor
  }
  $retiredRow = Wait-RowLifecycle `
    -Adb $adb `
    -Serial $DeviceSerial `
    -EvidenceRoot $evidenceRoot `
    -Label 'build7-finalized-retired-row' `
    -DocumentId $controlledDocumentId `
    -Lifecycle 'retired' `
    -AbsentMarkers @('Edit row', 'Reason for retired') `
    -TimeoutSeconds 90
  $recoveryMode = 'INTERRUPTED_AFTER_RETIREMENT_BEFORE_RECEIPT'
  $postWritePullEvidence = 'CHAINED_COMPLETION_WITNESS_AND_RECOVERED_LOCAL_RETIRED_RENDER'
}

$receipt = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-7-f4-controlled-knowledge-row-retirement'
  capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  promotionSha256 = $promotionSha256
  readReceiptSha256 = Get-Sha256 $readReceiptPath
  completionWitnessSha256 = Get-Sha256 $retirementCompletionWitnessPath
  recoveryMode = $recoveryMode
  installedApkSha256 = $installedBuild7.apkSha256
  controlledDocument = "knowledge_base/$controlledDocumentId"
  initialLifecycle = 'active'
  finalLifecycle = 'retired'
  retirementReasonSha256 = Get-TextSha256 $retirementReason
  governedApplicationPathUsed = $true
  directFirestoreWriteUsed = $false
  secondKnowledgeRecordMutated = $false
  activeRowPreconditionReceiptPassed = $true
  postWriteCloudPullCompleted = $true
  postWriteCloudPullEvidence = $postWritePullEvidence
  governanceAuditCompleted = $true
  nativeTimestampDecodePassed = $true
  postGovernedWriteRendered = $true
  retiredRowUiSha256 = $retiredRow.sha256
  rawUiRetained = $false
  programmeBoundary = [ordered]@{
    stage2dF4Status = 'OPEN'
    stage2dF4CompatibilityEvidenceCreated = $true
    stage2dF4ClosureAuthorized = $false
    p07ClosureAuthorized = $false
    pilotHandoutAuthorized = $false
    productionBackfillAuthorized = $false
    runtimeContractActivationAuthorized = $false
    separateEvidenceAdjudicationRequired = $true
  }
  decision = 'PASS_BUILD7_CONTROLLED_TIMESTAMP_ROW_RETIRED_POST_WRITE_RENDERED'
}
Write-Utf8NoBom `
  -Path $retirementReceiptPath `
  -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
$receipt | ConvertTo-Json -Depth 30
