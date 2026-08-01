#requires -Version 7.0
<#
.SYNOPSIS
Starts the exact-target Build 6 physical-device F4 campaign.

.DESCRIPTION
Preflight is read-only. Install installs and launches only the exact governed
Build 6 APK on the discovery-bound physical target. CaptureApprovedSignIn
retains only hashes and non-identity UI state. Later F4 evidence remains a
separate phase and this harness never closes STAGE2D-F4 or P-07.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet(
    'Preflight',
    'Install',
    'FinalizeInstall',
    'BeginApprovedSignIn',
    'CaptureApprovedSignIn'
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

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
$discoveryFile = (Resolve-Path -LiteralPath $DiscoveryReceiptPath).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json
$discovery = Get-Content -LiteralPath $discoveryFile -Raw | ConvertFrom-Json

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
Assert-Equal `
  $preflight.promotionSha256 `
  (Get-Sha256 $promotionFile) `
  'Preflight promotion SHA-256'
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
