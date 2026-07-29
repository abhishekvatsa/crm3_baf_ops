#requires -Version 7.0
<#
.SYNOPSIS
Runs the governed one-AVD Build 5 production-signing validation channel.

.DESCRIPTION
Preflight is read-only. Install is permitted only from an exact clean main
equal to origin/main after the promotion record is merged. Verify captures
privacy-minimized proof that the approved-user home screen was reached.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet('Preflight', 'Install', 'Verify')]
  [string]$Phase = 'Preflight',

  [Parameter(Mandatory)]
  [string]$ApkPath,

  [string]$PromotionPath =
    'release/approvals/build-5-runtime-validation-promotion.json',

  [string]$RepositoryRoot = (Get-Location).Path,

  [string]$DeviceSerial = 'emulator-5554',

  [string]$EvidenceDirectory,

  [switch]$AllowDebugReplacement
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Get-UiSnapshot {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$Destination
  )

  $remotePath = '/sdcard/crm3-build5-window.xml'
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

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$apkFile = (Resolve-Path -LiteralPath $ApkPath).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json

Assert-Equal $promotion.schemaVersion 1 'Promotion schema version'
Assert-Equal `
  $promotion.approvalClass `
  'CONTROLLED_INTERNAL_RUNTIME_VALIDATION_ONLY' `
  'Promotion class'
Assert-Equal `
  $promotion.channel.planningMode `
  'internal-release-signed-apk' `
  'Promotion channel'
Assert-Equal `
  $promotion.channel.transport `
  'DIRECT_ADB_FROM_GOVERNED_LOCAL_CUSTODY' `
  'Promotion transport'
Assert-Equal $promotion.channel.maxTargetCount 1 'Maximum target count'
Assert-Equal `
  $promotion.programmeBoundary.pilotHandoutAuthorized `
  $false `
  'Pilot handout authorization'
Assert-Equal `
  $promotion.channel.firebaseAppDistributionUploadAuthorized `
  $false `
  'Firebase App Distribution authorization'
Assert-Equal `
  $promotion.channel.playConsoleUploadAuthorized `
  $false `
  'Play Console authorization'

$expectedApk = $promotion.artifactAuthority.apk
Assert-Equal (Get-Sha256 $apkFile) $expectedApk.sha256 'APK SHA-256'
Assert-Equal (Get-Item -LiteralPath $apkFile).Length $expectedApk.bytes 'APK bytes'

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

$badging = (Invoke-ExternalText -FilePath $aapt -Arguments @(
  'dump', 'badging', $apkFile
)).output
$packagePattern = "package: name='$([regex]::Escape(
  $promotion.artifactAuthority.applicationId
))' versionCode='$($promotion.artifactAuthority.versionCode)' " +
  "versionName='$([regex]::Escape(
    $promotion.artifactAuthority.versionName
  ))'"
if ($badging -notmatch $packagePattern) {
  throw 'APK package/version identity does not match the promotion record.'
}

$signerOutput = (Invoke-ExternalText -FilePath $apksigner -Arguments @(
  'verify', '--print-certs', $apkFile
)).output
$normalizedSigner = $signerOutput.Replace(':', '').ToUpperInvariant()
if (-not $normalizedSigner.Contains(
    $promotion.artifactAuthority.signer.certificateSha1)) {
  throw 'APK signer SHA-1 does not match the promotion record.'
}
if (-not $normalizedSigner.Contains(
    $promotion.artifactAuthority.signer.certificateSha256)) {
  throw 'APK signer SHA-256 does not match the promotion record.'
}

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

$fingerprint = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.build.fingerprint'
)).output
$model = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'getprop', 'ro.product.model'
)).output
$gms = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', 'com.google.android.gms'
)).output
if (-not $gms.StartsWith('package:')) {
  throw 'The approved AVD does not expose Google Play Services.'
}

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

$packageId = $promotion.artifactAuthority.applicationId
$installedPathResult = Invoke-ExternalText `
  -FilePath $adb `
  -Arguments @('-s', $DeviceSerial, 'shell', 'pm', 'path', $packageId) `
  -AllowFailure
$installedBefore = $installedPathResult.output.StartsWith('package:')
$installedBeforeDetails = $null
if ($installedBefore) {
  $installedBeforeDetails = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'dumpsys', 'package', $packageId
  )).output
}

$preflight = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-5-runtime-validation-preflight'
  capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  phase = $Phase
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
    path = $apkFile
    sha256 = Get-Sha256 $apkFile
    bytes = (Get-Item -LiteralPath $apkFile).Length
    applicationId = $packageId
    versionName = $promotion.artifactAuthority.versionName
    versionCode = $promotion.artifactAuthority.versionCode
    certificateSha1 = $promotion.artifactAuthority.signer.certificateSha1
    certificateSha256 = $promotion.artifactAuthority.signer.certificateSha256
  }
  target = [ordered]@{
    serial = $DeviceSerial
    avdName = $avdName
    apiLevel = $apiLevel
    model = $model
    fingerprint = $fingerprint
    googlePlayServicesPresent = $true
    existingPackagePresent = $installedBefore
  }
  decision = 'PASS_READ_ONLY_PREFLIGHT'
}

if ($Phase -eq 'Preflight') {
  $preflight | ConvertTo-Json -Depth 30
  exit 0
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  throw 'EvidenceDirectory is mandatory for Install and Verify.'
}

$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
if ($Phase -eq 'Install') {
  if ($gitBranch -ne 'main' -or $gitHead -ne $originMain -or $gitStatus) {
    throw 'Install requires an exact clean main equal to origin/main.'
  }
  if ($gitHead -eq $promotion.approvalAuthority.baselineCommit) {
    throw 'The promotion record is not effective on its unmodified baseline.'
  }
  if (Test-Path -LiteralPath $evidenceRoot) {
    if ((Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
      throw 'Install evidence directory must be new or empty.'
    }
  } else {
    $null = New-Item -ItemType Directory -Path $evidenceRoot
  }

  Write-Utf8NoBom `
    -Path (Join-Path $evidenceRoot 'preflight.json') `
    -Text (($preflight | ConvertTo-Json -Depth 30) + "`n")

  $debugRemoved = $false
  $priorDebugApkSha256 = $null
  $priorDebugCertificateSha1 = $null
  $priorDebugCertificateSha256 = $null
  if ($installedBefore) {
    if (-not $AllowDebugReplacement) {
      throw 'Existing package removal requires AllowDebugReplacement.'
    }
    if (-not $installedBeforeDetails.Contains('DEBUGGABLE') -or
        $installedBeforeDetails -notmatch 'versionCode=1(?:\s|$)') {
      throw 'Existing package is not the exact approved debuggable versionCode 1.'
    }
    $priorPackagePath = $installedPathResult.output.Replace(
      'package:',
      ''
    ).Trim()
    $priorDebugApk = Join-Path $evidenceRoot 'prior-debug-base.apk'
    $null = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'pull', $priorPackagePath, $priorDebugApk
    )
    $priorDebugApkSha256 = Get-Sha256 $priorDebugApk
    $priorSignerOutput = (Invoke-ExternalText `
      -FilePath $apksigner `
      -Arguments @('verify', '--print-certs', $priorDebugApk)).output
    $normalizedPriorSigner = $priorSignerOutput.Replace(
      ':',
      ''
    ).ToUpperInvariant()
    $expectedPrior = $promotion.deviceProvenance.expectedPriorPackage
    if (-not $normalizedPriorSigner.Contains($expectedPrior.certificateSha1)) {
      throw 'Existing debug package signer SHA-1 is not approved.'
    }
    if (-not $normalizedPriorSigner.Contains(
        $expectedPrior.certificateSha256)) {
      throw 'Existing debug package signer SHA-256 is not approved.'
    }
    $priorDebugCertificateSha1 = $expectedPrior.certificateSha1
    $priorDebugCertificateSha256 = $expectedPrior.certificateSha256
    Write-Utf8NoBom `
      -Path (Join-Path $evidenceRoot 'prior-debug-signer.txt') `
      -Text ($priorSignerOutput + "`n")
    if ($PSCmdlet.ShouldProcess(
        "$DeviceSerial/$packageId",
        'uninstall exact prior debuggable package and wipe its app sandbox')) {
      $uninstall = Invoke-ExternalText -FilePath $adb -Arguments @(
        '-s', $DeviceSerial, 'uninstall', $packageId
      )
      if (($uninstall.output -split '\r?\n')[-1].Trim() -ne 'Success') {
        throw "Debug package uninstall did not report success.`n$($uninstall.output)"
      }
      $debugRemoved = $true
    }
  }

  if ($PSCmdlet.ShouldProcess(
      "$DeviceSerial/$packageId",
      'install exact governed Build 5 release APK')) {
    $install = Invoke-ExternalText -FilePath $adb -Arguments @(
      '-s', $DeviceSerial, 'install', '--no-streaming', $apkFile
    )
    if (($install.output -split '\r?\n')[-1].Trim() -ne 'Success') {
      throw "Build 5 APK install did not report success.`n$($install.output)"
    }
  }

  $installedDetails = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'dumpsys', 'package', $packageId
  )).output
  if ($installedDetails.Contains('DEBUGGABLE')) {
    throw 'Installed Build 5 package is unexpectedly debuggable.'
  }
  if ($installedDetails -notmatch 'versionCode=5(?:\s|$)' -or
      $installedDetails -notmatch 'versionName=1\.0\.0-rc\.1(?:\s|$)') {
    throw 'Installed package version does not match Build 5.'
  }

  $installedPath = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'pm', 'path', $packageId
  )).output.Replace('package:', '').Trim()
  $installedShaOutput = (Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'sha256sum', $installedPath
  )).output
  $installedSha = ($installedShaOutput -split '\s+')[0].ToUpperInvariant()
  Assert-Equal $installedSha $expectedApk.sha256 'Installed APK SHA-256'

  $launch = Invoke-ExternalText -FilePath $adb -Arguments @(
    '-s', $DeviceSerial, 'shell', 'monkey',
    '-p', $packageId,
    '-c', 'android.intent.category.LAUNCHER',
    '1'
  )

  Start-Sleep -Seconds 5
  $uiPath = Join-Path $evidenceRoot 'login-window.xml'
  Get-UiSnapshot -Adb $adb -Serial $DeviceSerial -Destination $uiPath
  $loginUi = Get-Content -LiteralPath $uiPath -Raw
  if (-not $loginUi.Contains('Sign in with Google')) {
    throw 'The installed release did not reach the expected Google sign-in UI.'
  }

  $installReceipt = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-5-controlled-internal-install'
    installedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    promotionSha256 = Get-Sha256 $promotionFile
    source = $preflight.source
    artifact = $preflight.artifact
    target = $preflight.target
    priorDebugPackageRemoved = $debugRemoved
    priorAppSandboxSecurelyWiped = $debugRemoved
    priorDebugApkSha256 = $priorDebugApkSha256
    priorDebugCertificateSha1 = $priorDebugCertificateSha1
    priorDebugCertificateSha256 = $priorDebugCertificateSha256
    installedApkSha256 = $installedSha
    installedPackageDebuggable = $false
    loginUiSha256 = Get-Sha256 $uiPath
    loginUiMarkerPresent = $true
    launchOutput = $launch.output
    channel = [ordered]@{
      planningMode = $promotion.channel.planningMode
      transport = $promotion.channel.transport
      targetCount = 1
      externalDistributionPerformed = $false
      pilotHandoutPerformed = $false
    }
    decision = 'PASS_EXACT_BUILD5_CONTROLLED_INTERNAL_INSTALL'
  }
  Write-Utf8NoBom `
    -Path (Join-Path $evidenceRoot 'install-receipt.json') `
    -Text (($installReceipt | ConvertTo-Json -Depth 30) + "`n")
  $installReceipt | ConvertTo-Json -Depth 30
  exit 0
}

if ($gitBranch -ne 'main' -or $gitHead -ne $originMain -or $gitStatus) {
  throw 'Verify requires an exact clean main equal to origin/main.'
}
if (-not (Test-Path -LiteralPath (
    Join-Path $evidenceRoot 'install-receipt.json'
  ) -PathType Leaf)) {
  throw 'Verify requires the governed install receipt.'
}

$installEvidence = Get-Content -LiteralPath (
  Join-Path $evidenceRoot 'install-receipt.json'
) -Raw | ConvertFrom-Json
Assert-Equal `
  $installEvidence.installedApkSha256 `
  $expectedApk.sha256 `
  'Install evidence APK SHA-256'

$requiredHomeMarkers = @(
  'Home',
  'Issues',
  'Work',
  'Directives',
  'More',
  'Core modules'
)
$forbiddenMarkers = @(
  'Sign in with Google',
  'pending admin approval',
  'Sign-in failed'
)

$runtimeUiPath = Join-Path $evidenceRoot 'approved-home-window.xml'
$runtimeUi = ''
$deadline = [DateTimeOffset]::UtcNow.AddSeconds(90)
do {
  Get-UiSnapshot `
    -Adb $adb `
    -Serial $DeviceSerial `
    -Destination $runtimeUiPath
  $runtimeUi = Get-Content -LiteralPath $runtimeUiPath -Raw
  $allPresent = @($requiredHomeMarkers |
      Where-Object { -not $runtimeUi.Contains($_) }).Count -eq 0
  $noneForbidden = @($forbiddenMarkers |
      Where-Object { $runtimeUi.Contains($_) }).Count -eq 0
  if ($allPresent -and $noneForbidden) {
    break
  }
  Start-Sleep -Seconds 3
} while ([DateTimeOffset]::UtcNow -lt $deadline)

if (-not $allPresent -or -not $noneForbidden) {
  throw 'Approved-user home markers were not reached before the timeout.'
}

$currentFocus = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'dumpsys', 'window', 'windows'
)).output
if (-not $currentFocus.Contains($packageId)) {
  throw 'The CRM-III package is not the current foreground application.'
}

$runtimeScreenshotRemote = '/sdcard/crm3-build5-approved-home.png'
$runtimeScreenshot = Join-Path $evidenceRoot 'approved-home.png'
$null = Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'screencap', '-p',
  $runtimeScreenshotRemote
)
$null = Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'pull',
  $runtimeScreenshotRemote, $runtimeScreenshot
)

$runtimeReceipt = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-5-production-signed-google-sign-in-runtime'
  verifiedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
  promotionSha256 = Get-Sha256 $promotionFile
  installReceiptSha256 = Get-Sha256 (
    Join-Path $evidenceRoot 'install-receipt.json'
  )
  artifact = $preflight.artifact
  target = $preflight.target
  approvedUserGate = [ordered]@{
    sourceInvariant = 'HomeScreen is reachable only after Firebase authentication, users/{uid} resolution and isApproved=true.'
    requiredMarkers = $requiredHomeMarkers
    forbiddenMarkersAbsent = $true
    accountEmailStoredInRepositoryEvidence = $false
    accountDisplayNameStoredInRepositoryEvidence = $false
    uiHierarchySha256 = Get-Sha256 $runtimeUiPath
    screenshotSha256 = Get-Sha256 $runtimeScreenshot
  }
  mutationBoundary = [ordered]@{
    firebaseAuthenticationSessionCreated = $true
    ownUserProfileHydrationPermitted = $true
    otherFirestoreBusinessWritesAuthorized = $false
    firebaseConfigurationMutationPerformed = $false
    backendDeploymentPerformed = $false
    externalDistributionPerformed = $false
    pilotHandoutPerformed = $false
  }
  decision = 'PASS_EXACT_PRODUCTION_SIGNED_GOOGLE_SIGN_IN_AND_APPROVED_USER_GATE'
}
Write-Utf8NoBom `
  -Path (Join-Path $evidenceRoot 'runtime-receipt.json') `
  -Text (($runtimeReceipt | ConvertTo-Json -Depth 30) + "`n")
$runtimeReceipt | ConvertTo-Json -Depth 30
