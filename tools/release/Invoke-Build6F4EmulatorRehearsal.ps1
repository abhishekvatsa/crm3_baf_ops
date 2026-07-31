#requires -Version 7.0
<#
.SYNOPSIS
Runs the governed one-AVD Build 6 first-listener remediation rehearsal.

.DESCRIPTION
Preflight performs no install or Firebase mutation. Upgrade is permitted only
from an exact clean main equal to origin/main after the promotion record is
merged. Runtime phases retain only hashes and non-identity state in receipts.
This harness creates no physical-device or STAGE2D-F4 closure authority.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet(
    'Preflight',
    'Upgrade',
    'PrepareSignIn',
    'BeginFreshSignIn',
    'VerifyFreshSignIn'
  )]
  [string]$Phase = 'Preflight',

  [Parameter(Mandatory)]
  [string]$GovernedPackagePath,

  [string]$PromotionPath =
    'release/approvals/build-6-f4-emulator-rehearsal-promotion.json',

  [string]$RepositoryRoot = (Get-Location).Path,

  [string]$DeviceSerial = 'emulator-5554',

  [string]$EvidenceDirectory
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

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Text
  )

  [IO.File]::WriteAllText(
    $Path,
    $Text,
    [Text.UTF8Encoding]::new($false)
  )
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

function Get-ZipEntrySha256 {
  param(
    [Parameter(Mandatory)][string]$ZipPath,
    [Parameter(Mandatory)][string]$EntryName
  )

  $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entries = @($archive.Entries | Where-Object FullName -EQ $EntryName)
    if ($entries.Count -ne 1) {
      throw "Expected one governed-package entry '$EntryName'."
    }
    $entry = $entries[0]
    $stream = $entry.Open()
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
      $hash = [Convert]::ToHexString($hasher.ComputeHash($stream))
    } finally {
      $hasher.Dispose()
      $stream.Dispose()
    }
    [pscustomobject]@{
      fullName = $entry.FullName
      length = $entry.Length
      sha256 = $hash.ToUpperInvariant()
    }
  } finally {
    $archive.Dispose()
  }
}

function Expand-ExactZipEntry {
  param(
    [Parameter(Mandatory)][string]$ZipPath,
    [Parameter(Mandatory)][string]$EntryName,
    [Parameter(Mandatory)][string]$Destination
  )

  if (Test-Path -LiteralPath $Destination) {
    throw "Refusing to replace extracted artifact: $Destination"
  }
  $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $entries = @($archive.Entries | Where-Object FullName -EQ $EntryName)
    if ($entries.Count -ne 1) {
      throw "Expected one governed-package entry '$EntryName'."
    }
    [IO.Compression.ZipFileExtensions]::ExtractToFile(
      $entries[0],
      $Destination,
      $false
    )
  } finally {
    $archive.Dispose()
  }
}

function Get-UiSnapshot {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$Destination
  )

  $remotePath = '/sdcard/crm3-build6-f4-rehearsal-window.xml'
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'uiautomator', 'dump', $remotePath
  )
  $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'pull', $remotePath, $Destination
  )
  if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
    throw 'UI hierarchy capture did not produce the expected local file.'
  }
}

function Get-NodeCenter {
  param(
    [Parameter(Mandatory)][string]$UiPath,
    [Parameter(Mandatory)][string]$XPath,
    [Parameter(Mandatory)][string]$Label
  )

  [xml]$document = Get-Content -LiteralPath $UiPath -Raw
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
      [int]$match.Groups[1].Value +
      [int]$match.Groups[3].Value
    ) / 2)
    y = [int]((
      [int]$match.Groups[2].Value +
      [int]$match.Groups[4].Value
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

  $result = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pidof', '-s', $PackageId
  ) -AllowFailure
  if ($result.exitCode -ne 0 -or
      [string]::IsNullOrWhiteSpace($result.output)) {
    throw 'The CRM-III application process is not running.'
  }
  $result.output.Trim()
}

function Get-UiState {
  param([Parameter(Mandatory)][string]$UiText)

  if ($UiText.Contains('Sign in with Google')) {
    return 'LOGIN'
  }
  $homeMarkers = @('Home', 'Issues', 'Work', 'Directives', 'More', 'Core modules')
  if (@($homeMarkers | Where-Object { -not $UiText.Contains($_) }).Count -eq 0) {
    return 'APPROVED_HOME'
  }
  if ($UiText.Contains('Choose an account') -and
      $UiText.Contains('package="com.google.android.gms"')) {
    return 'GOOGLE_ACCOUNT_CHOOSER'
  }
  'OTHER'
}

function Wait-ForUiState {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$Destination,
    [Parameter(Mandatory)][string[]]$AllowedStates,
    [int]$TimeoutSeconds = 90
  )

  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    Get-UiSnapshot -Adb $Adb -Serial $Serial -Destination $Destination
    $uiText = Get-Content -LiteralPath $Destination -Raw
    $state = Get-UiState -UiText $uiText
    if ($AllowedStates.Contains($state)) {
      return [pscustomobject]@{
        state = $state
        uiText = $uiText
      }
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)

  throw "The expected UI state was not reached: $($AllowedStates -join ', ')."
}

function Get-InstalledPackage {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$PackageId
  )

  $pathResult = Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pm', 'path', $PackageId
  ) -AllowFailure
  if ($pathResult.exitCode -ne 0 -or
      -not $pathResult.output.StartsWith('package:')) {
    throw 'The required installed CRM-III package is absent.'
  }
  $installedPath = $pathResult.output.Replace('package:', '').Trim()
  $details = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'dumpsys', 'package', $PackageId
  )).output
  $shaOutput = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'sha256sum', $installedPath
  )).output
  $sha256 = ($shaOutput -split '\s+')[0].ToUpperInvariant()
  $firstInstallMatch = [regex]::Match(
    $details,
    '(?m)^\s*firstInstallTime=(.+)$'
  )
  if (-not $firstInstallMatch.Success) {
    throw 'Installed package first-install time is unavailable.'
  }
  [pscustomobject]@{
    path = $installedPath
    details = $details
    sha256 = $sha256
    firstInstallTime = $firstInstallMatch.Groups[1].Value.Trim()
    debuggable = $details.Contains('DEBUGGABLE')
  }
}

function Assert-InstalledVersion {
  param(
    [Parameter(Mandatory)]$Installed,
    [Parameter(Mandatory)][int]$VersionCode,
    [Parameter(Mandatory)][string]$VersionName,
    [Parameter(Mandatory)][string]$Sha256,
    [Parameter(Mandatory)][string]$Label
  )

  if ($Installed.debuggable -or
      $Installed.details -notmatch "versionCode=$VersionCode(?:\s|$)" -or
      $Installed.details -notmatch
        "versionName=$([regex]::Escape($VersionName))(?:\s|$)" -or
      $Installed.sha256 -ne $Sha256) {
    throw "$Label is not exact."
  }
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json

Assert-Equal $promotion.schemaVersion 1 'Promotion schema version'
Assert-Equal `
  $promotion.approvalClass `
  'CONTROLLED_INTERNAL_RUNTIME_REHEARSAL_ONLY' `
  'Promotion class'
Assert-Equal `
  $promotion.channel.transport `
  'DIRECT_ADB_FROM_GOVERNED_LOCAL_CUSTODY' `
  'Promotion transport'
Assert-Equal $promotion.channel.maxTargetCount 1 'Maximum target count'
Assert-Equal `
  $promotion.channel.physicalDeviceInstallationAuthorized `
  $false `
  'Physical-device installation authorization'
Assert-Equal `
  $promotion.programmeBoundary.stage2dF4ClosureAuthorized `
  $false `
  'STAGE2D-F4 closure authorization'
Assert-Equal `
  $promotion.programmeBoundary.pilotHandoutAuthorized `
  $false `
  'Pilot handout authorization'
Assert-Equal `
  $promotion.expectedRemoteMutationBoundary.otherFirestoreBusinessWritesAuthorized `
  $false `
  'Business-write authorization'
Assert-Equal `
  $promotion.expectedRemoteMutationBoundary.userAuthorityMutationAuthorized `
  $false `
  'User-authority mutation authorization'

$artifact = $promotion.artifactAuthority
$expectedPackage = $artifact.governedPackage
$expectedApk = $artifact.apk
Assert-Equal (Get-Sha256 $packageFile) $expectedPackage.sha256 'Package SHA-256'
Assert-Equal `
  (Get-Item -LiteralPath $packageFile).Length `
  $expectedPackage.bytes `
  'Package bytes'
$embeddedApk = Get-ZipEntrySha256 `
  -ZipPath $packageFile `
  -EntryName $expectedApk.entryName
Assert-Equal $embeddedApk.sha256 $expectedApk.sha256 'Embedded APK SHA-256'
Assert-Equal $embeddedApk.length $expectedApk.bytes 'Embedded APK bytes'

$finalizationPath = Join-Path $root $artifact.finalizationReceipt.path
Assert-Equal `
  (Get-Sha256 $finalizationPath) `
  $artifact.finalizationReceipt.sha256 `
  'Finalization receipt SHA-256'

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

$state = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'get-state'
)).output
Assert-Equal $state 'device' 'ADB device state'

$avdOutput = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'emu', 'avd', 'name'
)).output
$avdName = ($avdOutput -split '\r?\n' |
    Where-Object { $_ -and $_ -ne 'OK' } |
    Select-Object -First 1).Trim()
Assert-Equal $avdName $promotion.channel.target.avdName 'AVD name'
Assert-Equal $DeviceSerial $promotion.channel.target.adbSerial 'ADB serial'

$apiLevel = [int](Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.build.version.sdk'
)).output
if ($apiLevel -lt $promotion.channel.target.minimumApiLevel) {
  throw "AVD API level $apiLevel is below the approved minimum."
}
$isEmulator = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.kernel.qemu'
)).output
Assert-Equal $isEmulator '1' 'Emulator identity'
$gms = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', 'com.google.android.gms'
)).output
if (-not $gms.StartsWith('package:')) {
  throw 'The approved AVD does not expose Google Play Services.'
}
$fingerprint = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.build.fingerprint'
)).output
$model = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.product.model'
)).output

$gitBranch = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'branch', '--show-current'
)).output
$null = Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'fetch', '--quiet', 'origin', 'main'
)
$gitHead = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'rev-parse', 'HEAD'
)).output
$gitStatus = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'status', '--porcelain'
)).output
$originMain = (Invoke-ExternalText -FilePath 'git' -Arguments @(
  '-C', $root, 'rev-parse', 'origin/main'
)).output

$packageId = $artifact.applicationId
$prior = $promotion.deviceProvenance.requiredPriorPackage
$installed = Get-InstalledPackage `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $packageId

if ($Phase -eq 'Preflight') {
  Assert-InstalledVersion `
    -Installed $installed `
    -VersionCode ([int]$prior.versionCode) `
    -VersionName $prior.versionName `
    -Sha256 $prior.apkSha256 `
    -Label 'The installed prerequisite is not exact Build 5.'

  [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-emulator-rehearsal-preflight'
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotion = [ordered]@{
      path = $PromotionPath.Replace('\', '/')
      sha256 = Get-Sha256 $promotionFile
      approvalId = $promotion.approvalId
    }
    source = [ordered]@{
      branch = $gitBranch
      head = $gitHead
      originMain = $originMain
      clean = [string]::IsNullOrEmpty($gitStatus)
    }
    artifact = [ordered]@{
      governedPackageSha256 = Get-Sha256 $packageFile
      embeddedApkSha256 = $embeddedApk.sha256
      embeddedApkBytes = $embeddedApk.length
      releaseId = $artifact.releaseId
      versionCode = $artifact.versionCode
      applicationId = $packageId
    }
    target = [ordered]@{
      serial = $DeviceSerial
      avdName = $avdName
      apiLevel = $apiLevel
      model = $model
      fingerprint = $fingerprint
      googlePlayServicesPresent = $true
    }
    installedPrerequisite = [ordered]@{
      releaseId = $prior.releaseId
      versionCode = $prior.versionCode
      apkSha256 = $installed.sha256
      debuggable = $installed.debuggable
    }
    programmeBoundary = [ordered]@{
      physicalDeviceEvidenceCreated = $false
      stage2dF4ClosureAuthorized = $false
      pilotHandoutAuthorized = $false
    }
    decision = 'PASS_READ_ONLY_BUILD6_EMULATOR_REHEARSAL_PREFLIGHT'
  } | ConvertTo-Json -Depth 30
  exit 0
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  throw 'EvidenceDirectory is mandatory outside Preflight.'
}
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)

if ($Phase -eq 'Upgrade') {
  if ($gitBranch -ne 'main' -or $gitHead -ne $originMain -or $gitStatus) {
    throw 'Upgrade requires an exact clean main equal to origin/main.'
  }
  if ($gitHead -eq $promotion.approvalAuthority.baselineCommit) {
    throw 'The promotion record is not effective on its unmodified baseline.'
  }
  $upgradeReceiptPath = Join-Path $evidenceRoot 'upgrade-receipt.json'
  if (Test-Path -LiteralPath $upgradeReceiptPath) {
    throw 'Upgrade refuses to replace an existing receipt.'
  }
  if (Test-Path -LiteralPath $evidenceRoot) {
    if ((Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
      throw 'Upgrade evidence directory must be new or empty.'
    }
  } else {
    $null = New-Item -ItemType Directory -Path $evidenceRoot
  }

  Assert-InstalledVersion `
    -Installed $installed `
    -VersionCode ([int]$prior.versionCode) `
    -VersionName $prior.versionName `
    -Sha256 $prior.apkSha256 `
    -Label 'The installed prerequisite is not exact Build 5.'

  $apkPath = Join-Path $evidenceRoot $expectedApk.entryName
  Expand-ExactZipEntry `
    -ZipPath $packageFile `
    -EntryName $expectedApk.entryName `
    -Destination $apkPath
  Assert-Equal (Get-Sha256 $apkPath) $expectedApk.sha256 'Extracted APK SHA-256'
  Assert-Equal `
    (Get-Item -LiteralPath $apkPath).Length `
    $expectedApk.bytes `
    'Extracted APK bytes'

  $badging = (Invoke-ExternalText -FilePath $aapt -Arguments @(
    'dump', 'badging', $apkPath
  )).output
  $packagePattern = "package: name='$([regex]::Escape(
    $packageId
  ))' versionCode='$($artifact.versionCode)' versionName='$([regex]::Escape(
    $artifact.versionName
  ))'"
  if ($badging -notmatch $packagePattern) {
    throw 'Build 6 APK package or version identity is unexpected.'
  }
  $signerOutput = (Invoke-ExternalText -FilePath $apksigner -Arguments @(
    'verify', '--print-certs', $apkPath
  )).output
  $normalizedSigner = $signerOutput.Replace(':', '').ToUpperInvariant()
  if (-not $normalizedSigner.Contains($artifact.signer.certificateSha1) -or
      -not $normalizedSigner.Contains($artifact.signer.certificateSha256)) {
    throw 'Build 6 APK signer does not match the production authority.'
  }

  if ($PSCmdlet.ShouldProcess(
      "$DeviceSerial/$packageId",
      'upgrade exact Build 5 to exact governed Build 6 in place')) {
    $upgrade = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'install', '-r', '--no-streaming', $apkPath
    )
    if (($upgrade.output -split '\r?\n')[-1].Trim() -ne 'Success') {
      throw "Build 6 in-place upgrade did not report success.`n$($upgrade.output)"
    }
  }

  $installedAfter = Get-InstalledPackage `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $packageId
  Assert-InstalledVersion `
    -Installed $installedAfter `
    -VersionCode ([int]$artifact.versionCode) `
    -VersionName $artifact.versionName `
    -Sha256 $expectedApk.sha256 `
    -Label 'The installed successor is not exact Build 6.'
  Assert-Equal `
    $installedAfter.firstInstallTime `
    $installed.firstInstallTime `
    'Preserved package first-install time'

  $launch = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $packageId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )
  $uiPath = Join-Path $evidenceRoot 'post-upgrade-window.xml'
  $ui = Wait-ForUiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $uiPath `
    -AllowedStates @('APPROVED_HOME', 'LOGIN')
  $processId = Get-AppProcessId `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $packageId

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-emulator-in-place-upgrade'
    upgradedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    source = [ordered]@{
      branch = $gitBranch
      head = $gitHead
      originMain = $originMain
      clean = $true
    }
    artifact = [ordered]@{
      governedPackageSha256 = Get-Sha256 $packageFile
      embeddedApkSha256 = $embeddedApk.sha256
      extractedApkSha256 = Get-Sha256 $apkPath
      versionCode = $artifact.versionCode
      certificateSha256 = $artifact.signer.certificateSha256
    }
    target = [ordered]@{
      serial = $DeviceSerial
      avdName = $avdName
      apiLevel = $apiLevel
      model = $model
      fingerprint = $fingerprint
    }
    prior = [ordered]@{
      versionCode = $prior.versionCode
      apkSha256 = $installed.sha256
      debuggable = $installed.debuggable
    }
    installed = [ordered]@{
      versionCode = $artifact.versionCode
      apkSha256 = $installedAfter.sha256
      debuggable = $installedAfter.debuggable
      firstInstallTimePreserved = $true
      applicationSandboxDisposition =
        'adb install -r completed without uninstall or data clear; application sandbox was preserved'
    }
    runtime = [ordered]@{
      initialUiState = $ui.state
      initialUiSha256 = Get-Sha256 $uiPath
      applicationProcessId = $processId
      accountEmailRetained = $false
      firebaseUidRetained = $false
    }
    programmeBoundary = [ordered]@{
      physicalDeviceEvidenceCreated = $false
      stage2dF4ClosureAuthorized = $false
      businessWritesAuthorized = $false
      pilotHandoutAuthorized = $false
    }
    launchOutput = $launch.output
    decision = 'PASS_EXACT_BUILD6_IN_PLACE_EMULATOR_UPGRADE'
  }
  Write-Utf8NoBom `
    -Path $upgradeReceiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

if ($gitBranch -ne 'main' -or $gitHead -ne $originMain -or $gitStatus) {
  throw "$Phase requires an exact clean main equal to origin/main."
}
$upgradeReceiptPath = Join-Path $evidenceRoot 'upgrade-receipt.json'
if (-not (Test-Path -LiteralPath $upgradeReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed Build 6 upgrade receipt."
}
$upgradeReceipt = Get-Content -LiteralPath $upgradeReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $upgradeReceipt.promotionSha256 `
  (Get-Sha256 $promotionFile) `
  'Upgrade receipt promotion SHA-256'
Assert-Equal `
  $upgradeReceipt.artifact.embeddedApkSha256 `
  $expectedApk.sha256 `
  'Upgrade receipt APK SHA-256'
$installedBuild6 = Get-InstalledPackage `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $packageId
Assert-InstalledVersion `
  -Installed $installedBuild6 `
  -VersionCode ([int]$artifact.versionCode) `
  -VersionName $artifact.versionName `
  -Sha256 $expectedApk.sha256 `
  -Label 'The installed successor is not exact Build 6.'

if ($Phase -eq 'PrepareSignIn') {
  $receiptPath = Join-Path $evidenceRoot 'signout-receipt.json'
  if (Test-Path -LiteralPath $receiptPath) {
    throw 'PrepareSignIn refuses to replace an existing receipt.'
  }
  $launch = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $packageId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )
  $beforePath = Join-Path $evidenceRoot 'pre-signout-window.xml'
  $before = Wait-ForUiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $beforePath `
    -AllowedStates @('APPROVED_HOME', 'LOGIN')
  $explicitSignOut = $false

  if ($before.state -eq 'APPROVED_HOME') {
    $profilePath = Join-Path $evidenceRoot 'profile-signout-window.xml'
    Get-UiSnapshot -Adb $adb -Serial $DeviceSerial -Destination $profilePath
    $profileText = Get-Content -LiteralPath $profilePath -Raw
    if (-not $profileText.Contains('Sign Out')) {
      $more = Get-NodeCenter `
        -UiPath $profilePath `
        -XPath "//node[@text='More' or contains(@content-desc,'More')]" `
        -Label 'More'
      Invoke-UiTap -Adb $adb -Serial $DeviceSerial -Center $more
      Start-Sleep -Seconds 2
      Get-UiSnapshot -Adb $adb -Serial $DeviceSerial -Destination $profilePath
    }
    $signOut = Get-NodeCenter `
      -UiPath $profilePath `
      -XPath "//node[@content-desc='Sign Out']" `
      -Label 'Sign Out'
    Invoke-UiTap -Adb $adb -Serial $DeviceSerial -Center $signOut
    $explicitSignOut = $true
  }

  $loginPath = Join-Path $evidenceRoot 'signed-out-login-window.xml'
  $login = Wait-ForUiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $loginPath `
    -AllowedStates @('LOGIN')
  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-emulator-fresh-signin-preparation'
    preparedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    upgradeReceiptSha256 = Get-Sha256 $upgradeReceiptPath
    installedApkSha256 = $installedBuild6.sha256
    initialUiState = $before.state
    explicitInAppSignOutPerformed = $explicitSignOut
    signedOutLoginUiSha256 = Get-Sha256 $loginPath
    signInWithGoogleMarkerPresent = $login.state -eq 'LOGIN'
    appDataClearPerformed = $false
    reinstallPerformed = $false
    accountEmailRetained = $false
    firebaseUidRetained = $false
    launchOutput = $launch.output
    decision = 'PASS_BUILD6_READY_FOR_FRESH_GOOGLE_SIGN_IN'
  }
  Write-Utf8NoBom `
    -Path $receiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

$signOutReceiptPath = Join-Path $evidenceRoot 'signout-receipt.json'
if (-not (Test-Path -LiteralPath $signOutReceiptPath -PathType Leaf)) {
  throw "$Phase requires the governed fresh-sign-in preparation receipt."
}
$signOutReceipt = Get-Content -LiteralPath $signOutReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $signOutReceipt.signInWithGoogleMarkerPresent `
  $true `
  'Signed-out login marker'

if ($Phase -eq 'BeginFreshSignIn') {
  $receiptPath = Join-Path $evidenceRoot 'account-chooser-receipt.json'
  if (Test-Path -LiteralPath $receiptPath) {
    throw 'BeginFreshSignIn refuses to replace an existing receipt.'
  }
  $loginPath = Join-Path $evidenceRoot 'fresh-signin-login-window.xml'
  $null = Wait-ForUiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $loginPath `
    -AllowedStates @('LOGIN')
  $processId = Get-AppProcessId `
    -Adb $adb `
    -Serial $DeviceSerial `
    -PackageId $packageId
  $signIn = Get-NodeCenter `
    -UiPath $loginPath `
    -XPath "//node[@text='Sign in with Google' or contains(@content-desc,'Sign in with Google')]" `
    -Label 'Sign in with Google'
  Invoke-UiTap -Adb $adb -Serial $DeviceSerial -Center $signIn

  $chooserPath = Join-Path $evidenceRoot 'google-account-chooser-window.xml'
  $chooser = Wait-ForUiState `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $chooserPath `
    -AllowedStates @('GOOGLE_ACCOUNT_CHOOSER')
  $screenshotRemote = '/sdcard/crm3-build6-account-chooser.png'
  $screenshotPath = Join-Path $evidenceRoot 'google-account-chooser.png'
  $null = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'screencap', '-p', $screenshotRemote
  )
  $null = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'pull', $screenshotRemote, $screenshotPath
  )

  $receipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-6-f4-emulator-google-account-chooser'
    openedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    signOutReceiptSha256 = Get-Sha256 $signOutReceiptPath
    installedApkSha256 = $installedBuild6.sha256
    applicationProcessIdBeforeChooser = $processId
    googlePlayServicesChooserPresent =
      $chooser.state -eq 'GOOGLE_ACCOUNT_CHOOSER'
    chooserUiSha256 = Get-Sha256 $chooserPath
    chooserScreenshotSha256 = Get-Sha256 $screenshotPath
    accountSelectionPerformedByHarness = $false
    accountEmailRetained = $false
    accountDisplayNameRetained = $false
    firebaseUidRetained = $false
    nextStep =
      'Select the existing owner-controlled account, then run VerifyFreshSignIn without relaunching the application.'
    decision = 'PASS_GOOGLE_ACCOUNT_CHOOSER_READY_FOR_CONTROLLED_SELECTION'
  }
  Write-Utf8NoBom `
    -Path $receiptPath `
    -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
  $receipt | ConvertTo-Json -Depth 30
  exit 0
}

$chooserReceiptPath = Join-Path $evidenceRoot 'account-chooser-receipt.json'
if (-not (Test-Path -LiteralPath $chooserReceiptPath -PathType Leaf)) {
  throw 'VerifyFreshSignIn requires the governed account-chooser receipt.'
}
$chooserReceipt = Get-Content -LiteralPath $chooserReceiptPath -Raw |
  ConvertFrom-Json
Assert-Equal `
  $chooserReceipt.googlePlayServicesChooserPresent `
  $true `
  'Google account chooser evidence'

$runtimePath = Join-Path $evidenceRoot 'fresh-signin-approved-home-window.xml'
$runtime = Wait-ForUiState `
  -Adb $adb `
  -Serial $DeviceSerial `
  -Destination $runtimePath `
  -AllowedStates @('APPROVED_HOME') `
  -TimeoutSeconds 120
$currentProcessId = Get-AppProcessId `
  -Adb $adb `
  -Serial $DeviceSerial `
  -PackageId $packageId
if ($currentProcessId -ne $chooserReceipt.applicationProcessIdBeforeChooser) {
  throw 'Same-process first-listener proof failed because the app process changed.'
}
$forbiddenMarkers = @(
  'User profile error',
  '[cloud_firestore/permission-denied]',
  'Sign-in failed',
  'pending admin approval'
)
$presentForbidden = @($forbiddenMarkers |
    Where-Object { $runtime.uiText.Contains($_) })
if ($presentForbidden.Count -ne 0) {
  throw "Fresh sign-in reached a forbidden surface: $($presentForbidden -join ', ')"
}
$focus = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'dumpsys', 'window', 'windows'
)).output
if (-not $focus.Contains($packageId)) {
  throw 'The CRM-III package is not the foreground application.'
}

$screenshotRemote = '/sdcard/crm3-build6-fresh-signin-home.png'
$screenshotPath = Join-Path $evidenceRoot 'fresh-signin-approved-home.png'
$null = Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'screencap', '-p', $screenshotRemote
)
$null = Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'pull', $screenshotRemote, $screenshotPath
)
$receiptPath = Join-Path $evidenceRoot 'runtime-receipt.json'
if (Test-Path -LiteralPath $receiptPath) {
  throw 'VerifyFreshSignIn refuses to replace an existing receipt.'
}
$receipt = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-6-first-listener-remediation-emulator-rehearsal'
  verifiedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  promotionSha256 = Get-Sha256 $promotionFile
  upgradeReceiptSha256 = Get-Sha256 $upgradeReceiptPath
  signOutReceiptSha256 = Get-Sha256 $signOutReceiptPath
  chooserReceiptSha256 = Get-Sha256 $chooserReceiptPath
  installedApkSha256 = $installedBuild6.sha256
  target = [ordered]@{
    serial = $DeviceSerial
    avdName = $avdName
    apiLevel = $apiLevel
    fingerprint = $fingerprint
  }
  runtime = [ordered]@{
    freshGoogleSignInCompleted = $true
    approvedHomeReached = $true
    sameApplicationProcessFromChooserToApprovedHome = $true
    applicationProcessId = $currentProcessId
    priorFirstListenerPermissionDeniedSurfaceAbsent = $true
    approvedHomeUiSha256 = Get-Sha256 $runtimePath
    approvedHomeScreenshotSha256 = Get-Sha256 $screenshotPath
  }
  privacy = [ordered]@{
    accountEmailRetained = $false
    accountDisplayNameRetained = $false
    firebaseUidRetained = $false
  }
  mutationBoundary = [ordered]@{
    firebaseAuthenticationSessionCreated = $true
    ownUserProfileHydrationPermitted = $true
    ordinaryOwnUserFcmTokenMutationPermitted = $true
    otherFirestoreBusinessWritesAuthorized = $false
    userAuthorityMutationAuthorized = $false
    firebaseConfigurationMutationPerformed = $false
    backendDeploymentPerformed = $false
    externalDistributionPerformed = $false
  }
  programmeBoundary = [ordered]@{
    evidenceClass = 'EMULATOR_REHEARSAL_ONLY'
    physicalDeviceEvidenceCreated = $false
    stage2dF4Status = 'OPEN'
    stage2dF4ClosureAuthorized = $false
    p07ClosureAuthorized = $false
    pilotHandoutAuthorized = $false
  }
  decision = 'PASS_BUILD6_FIRST_LISTENER_REMEDIATION_EMULATOR_REHEARSAL'
}
Write-Utf8NoBom `
  -Path $receiptPath `
  -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
$receipt | ConvertTo-Json -Depth 30
