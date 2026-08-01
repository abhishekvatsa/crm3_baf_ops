#requires -Version 7.0
<#
.SYNOPSIS
Discovers one candidate physical Android target for the Build 6 F4 campaign.

.DESCRIPTION
This is a read-only target-discovery step. It verifies the governed Build 6
artifact, rejects emulators and previously installed CRM-III packages, and
writes privacy-minimized target evidence outside the repository. It contains
no installation, launch, authentication, Firebase or business-data mutation.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$GovernedPackagePath,

  [Parameter(Mandatory)]
  [string]$DeviceSerial,

  [Parameter(Mandatory)]
  [string]$EvidenceDirectory,

  [string]$PromotionPath =
    'release/approvals/build-6-f4-physical-device-target-discovery.json',

  [string]$RepositoryRoot = (Get-Location).Path
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

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    $matches = @($archive.Entries | Where-Object {
      $_.FullName -eq $EntryName
    })
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

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$promotionFile = (Resolve-Path -LiteralPath (
  Join-Path $root $PromotionPath
)).Path
$packageFile = (Resolve-Path -LiteralPath $GovernedPackagePath).Path
$promotion = Get-Content -LiteralPath $promotionFile -Raw | ConvertFrom-Json

Assert-Equal $promotion.schemaVersion 1 'Promotion schema version'
Assert-Equal `
  $promotion.approvalClass `
  'CONTROLLED_PHYSICAL_DEVICE_TARGET_DISCOVERY_ONLY' `
  'Promotion class'
Assert-Equal $promotion.channel.maxTargetCount 1 'Maximum target count'
Assert-Equal `
  $promotion.channel.target.kind `
  'ANDROID_PHYSICAL_DEVICE_CANDIDATE' `
  'Target kind'
Assert-Equal `
  $promotion.channel.physicalDeviceInstallationAuthorized `
  $false `
  'Physical-device installation authorization'
Assert-Equal `
  $promotion.channel.firebaseAuthenticationAuthorized `
  $false `
  'Firebase Authentication authorization'
Assert-Equal `
  $promotion.channel.remoteMutationAuthorized `
  $false `
  'Remote mutation authorization'
Assert-Equal `
  $promotion.programmeBoundary.stage2dF4ExecutionAuthorized `
  $false `
  'F4 execution authorization'
Assert-Equal `
  $promotion.programmeBoundary.stage2dF4ClosureAuthorized `
  $false `
  'F4 closure authorization'

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
  throw 'Target discovery requires exact tracked-clean main equal to freshly fetched origin/main.'
}
if ($gitHead -eq $promotion.approvalAuthority.baselineCommit) {
  throw 'The promotion record is not effective on its unmodified baseline.'
}

$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) +
  [IO.Path]::DirectorySeparatorChar
if ($evidenceRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'EvidenceDirectory must be outside the repository.'
}
if (Test-Path -LiteralPath $evidenceRoot) {
  if ((Get-ChildItem -LiteralPath $evidenceRoot -Force).Count -ne 0) {
    throw 'EvidenceDirectory must be new or empty.'
  }
} else {
  $null = New-Item -ItemType Directory -Path $evidenceRoot
}

$apkAuthority = $promotion.artifactAuthority.apk
$apkPath = Join-Path $evidenceRoot 'governed-build6.apk'
Expand-ExactZipEntry `
  -ArchivePath $packageFile `
  -EntryName $apkAuthority.entryName `
  -Destination $apkPath
Assert-Equal (Get-Sha256 $apkPath) $apkAuthority.sha256 'Embedded APK SHA-256'
Assert-Equal (Get-Item -LiteralPath $apkPath).Length $apkAuthority.bytes `
  'Embedded APK bytes'

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
  'dump', 'badging', $apkPath
)).output
$applicationId = $promotion.artifactAuthority.applicationId
$versionCode = [string]$promotion.artifactAuthority.versionCode
$versionName = $promotion.artifactAuthority.versionName
$packagePattern = "package: name='$([regex]::Escape($applicationId))' " +
  "versionCode='$([regex]::Escape($versionCode))' " +
  "versionName='$([regex]::Escape($versionName))'"
if ($badging -notmatch $packagePattern) {
  throw 'APK package/version identity does not match the approval record.'
}
if ($badging -match '(?m)^application-debuggable') {
  throw 'The governed Build 6 APK is unexpectedly debuggable.'
}
$sdkMatch = [regex]::Match($badging, "sdkVersion:'(\d+)'")
if (-not $sdkMatch.Success) {
  throw 'APK minimum SDK could not be resolved.'
}
$minimumSdk = [int]$sdkMatch.Groups[1].Value

$signerOutput = (Invoke-ExternalText -FilePath $apksigner -Arguments @(
  'verify', '--print-certs', $apkPath
)).output
$normalizedSigner = $signerOutput.Replace(':', '').ToUpperInvariant()
if (-not $normalizedSigner.Contains(
    $promotion.artifactAuthority.signer.certificateSha1)) {
  throw 'APK signer SHA-1 does not match the approval record.'
}
if (-not $normalizedSigner.Contains(
    $promotion.artifactAuthority.signer.certificateSha256)) {
  throw 'APK signer SHA-256 does not match the approval record.'
}

$state = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'get-state'
)).output
Assert-Equal $state 'device' 'ADB device state'

$apiLevel = [int](Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.build.version.sdk')
if ($apiLevel -lt $minimumSdk) {
  throw "Physical target API level $apiLevel is below APK minimum $minimumSdk."
}

$qemuKernel = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.kernel.qemu'
$qemuBoot = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.boot.qemu'
$manufacturer = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.product.manufacturer'
$model = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.product.model'
$product = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.product.name'
$deviceName = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.product.device'
$brand = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.product.brand'
$fingerprint = Get-DeviceProperty `
  -Adb $adb -Serial $DeviceSerial -Name 'ro.build.fingerprint'

if ($qemuKernel -eq '1' -or $qemuBoot -eq '1') {
  throw 'F4 target discovery rejects Android emulators.'
}
$identitySurface = @(
  $manufacturer,
  $model,
  $product,
  $deviceName,
  $brand,
  $fingerprint
) -join ' '
if ($identitySurface -match '(?i)(generic|emulator|sdk_gphone|goldfish|ranchu)') {
  throw 'F4 target discovery found emulator markers in device properties.'
}
foreach ($requiredProperty in @(
    $manufacturer,
    $model,
    $product,
    $deviceName,
    $brand,
    $fingerprint
  )) {
  if ([string]::IsNullOrWhiteSpace($requiredProperty)) {
    throw 'Physical target identity contains an empty required property.'
  }
}

$gms = (Invoke-ExternalText -FilePath $adb -Arguments @(
  '-s', $DeviceSerial, 'shell', 'pm', 'path', 'com.google.android.gms'
)).output
if (-not $gms.StartsWith('package:')) {
  throw 'The physical target does not expose Google Play Services.'
}

$existingPackage = Invoke-ExternalText `
  -FilePath $adb `
  -Arguments @('-s', $DeviceSerial, 'shell', 'pm', 'path', $applicationId) `
  -AllowFailure
if ($existingPackage.exitCode -ne 0) {
  throw 'CRM-III package-presence lookup failed; absence is not proved.'
}
if ($existingPackage.output.StartsWith('package:')) {
  throw 'Physical target discovery requires the CRM-III package to be absent; no removal is authorized.'
}

$receipt = [ordered]@{
  schemaVersion = 1
  evidenceType = 'build-6-f4-physical-device-target-discovery'
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
    trackedClean = [string]::IsNullOrEmpty($trackedStatus)
  }
  artifact = [ordered]@{
    releaseId = $promotion.artifactAuthority.releaseId
    governedPackageSha256 = Get-Sha256 $packageFile
    apkSha256 = Get-Sha256 $apkPath
    applicationId = $applicationId
    versionName = $versionName
    versionCode = [int]$versionCode
    minimumSdk = $minimumSdk
    debuggable = $false
    certificateSha1 = $promotion.artifactAuthority.signer.certificateSha1
    certificateSha256 = $promotion.artifactAuthority.signer.certificateSha256
  }
  target = [ordered]@{
    kind = 'ANDROID_PHYSICAL_DEVICE_CANDIDATE'
    adbSerialSha256 = Get-TextSha256 $DeviceSerial
    buildFingerprintSha256 = Get-TextSha256 $fingerprint
    manufacturer = $manufacturer
    model = $model
    product = $product
    device = $deviceName
    brand = $brand
    apiLevel = $apiLevel
    qemuKernel = $qemuKernel
    qemuBoot = $qemuBoot
    emulatorMarkersAbsent = $true
    googlePlayServicesPresent = $true
    crm3PackageAbsent = $true
    rawAdbSerialRetained = $false
    rawBuildFingerprintRetained = $false
    androidIdRead = $false
  }
  mutationBoundary = [ordered]@{
    packageInstalled = $false
    packageRemoved = $false
    applicationLaunched = $false
    authenticationSessionCreated = $false
    deviceUiInteractionPerformed = $false
    firebaseReadPerformed = $false
    firebaseWritePerformed = $false
    businessDataMutationPerformed = $false
  }
  authorityBoundary = [ordered]@{
    targetBoundForFutureProposal = $true
    physicalDeviceInstallationAuthorized = $false
    stage2dF4ExecutionAuthorized = $false
    stage2dF4ClosureAuthorized = $false
    p07ClosureAuthorized = $false
    pilotHandoutAuthorized = $false
    separateOwnerReviewedPromotionRequired = $true
  }
  decision = 'PASS_BUILD6_F4_PHYSICAL_DEVICE_TARGET_CANDIDATE_READ_ONLY'
}

$receiptPath = Join-Path $evidenceRoot 'target-discovery-receipt.json'
Write-Utf8NoBom `
  -Path $receiptPath `
  -Text (($receipt | ConvertTo-Json -Depth 30) + "`n")
$receipt | ConvertTo-Json -Depth 30
