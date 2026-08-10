[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet(
    'Preflight',
    'CaptureRevoked',
    'CaptureRevocationRestored',
    'CaptureWrongRole',
    'CaptureFinalRestoration'
  )]
  [string]$Phase,

  [Parameter(Mandatory)][string]$SubjectSerial,
  [Parameter(Mandatory)][string]$OperatorSerial,
  [Parameter(Mandatory)][string]$EvidenceDirectory,
  [Parameter(Mandatory)][string]$GovernedPackagePath,
  [Parameter(Mandatory)][string]$LiveBackendReadbackPath,
  [string[]]$SubjectInitialRoles = @(),
  [string]$PromotionPath =
    'release/approvals/build-8-f4-authority-negative-promotion.json',
  [switch]$ConfirmIdentitySeparation,
  [switch]$ConfirmSubjectExactRolesCaptured,
  [switch]$ConfirmLiveBackendReadback,
  [switch]$ConfirmGovernedMutationSucceeded,
  [switch]$ConfirmOperationsOnlyRoleSet,
  [switch]$ConfirmExactRoleRestoration
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

  if (Test-Path -LiteralPath $Path) {
    throw "Refusing to replace evidence: $Path"
  }
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
    throw "External command failed with exit code $exitCode."
  }
  [pscustomobject]@{
    exitCode = $exitCode
    output = $output.Trim()
  }
}

function Get-AuthorizedDeviceSerials {
  param([Parameter(Mandatory)][string]$DevicesOutput)

  @($DevicesOutput -split "`r?`n" | ForEach-Object {
      if ($_ -match '^(\S+)\s+device\s*$') {
        $Matches[1]
      }
    })
}

function Assert-Equal {
  param(
    [Parameter(Mandatory)]$Actual,
    [Parameter(Mandatory)]$Expected,
    [Parameter(Mandatory)][string]$Label
  )

  if ($Actual -ne $Expected) {
    throw "$Label mismatch."
  }
}

function ConvertFrom-CanonicalUtcTimestamp {
  param([Parameter(Mandatory)][object]$Value)

  if ($Value -is [DateTimeOffset]) {
    if ($Value.Offset -ne [TimeSpan]::Zero) {
      throw 'A canonical UTC timestamp is required.'
    }
    return $Value
  }
  if ($Value -is [DateTime]) {
    if ($Value.Kind -ne [DateTimeKind]::Utc) {
      throw 'A canonical UTC timestamp is required.'
    }
    return [DateTimeOffset]::new($Value)
  }
  if ($Value -isnot [string]) {
    throw 'A canonical UTC timestamp is required.'
  }

  if ($Value -notmatch `
      '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?Z$') {
    throw 'A canonical UTC timestamp is required.'
  }
  try {
    [DateTimeOffset]::Parse(
      $Value,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind
    )
  } catch {
    throw 'A canonical UTC timestamp is required.'
  }
}

function Assert-TrackedEvidence {
  param(
    [Parameter(Mandatory)]$Record,
    [Parameter(Mandatory)][string]$RepositoryRoot
  )

  $path = Join-Path $RepositoryRoot ([string]$Record.path)
  Assert-Equal (Get-Sha256 $path) ([string]$Record.sha256) `
    "Tracked evidence $($Record.path) SHA-256"
}

function Assert-LiveBackendReadback {
  param(
    [Parameter(Mandatory)]$Receipt,
    [Parameter(Mandatory)]$BackendAuthority
  )

  Assert-Equal $Receipt.decision `
    'PASS_FUNCTION_FLEET_RUNTIME_IDENTITY_FINAL' `
    'Fresh function-fleet readback decision'
  Assert-Equal $Receipt.projectId 'crm3-baf-ops-b8638' `
    'Fresh function-fleet project'
  Assert-Equal $Receipt.region 'asia-south1' `
    'Fresh function-fleet region'
  Assert-Equal ([int]$Receipt.posture.expectedFunctionCount) `
    ([int]$BackendAuthority.deployedFunctionCount) `
    'Expected function-fleet count'
  Assert-Equal ([int]$Receipt.posture.deployedFunctionCount) `
    ([int]$BackendAuthority.deployedFunctionCount) `
    'Deployed function-fleet count'
  if (@($Receipt.failedChecks).Count -ne 0) {
    throw 'Fresh function-fleet readback contains failed checks.'
  }
  foreach ($property in $Receipt.checks.PSObject.Properties) {
    if ($property.Value -ne $true) {
      throw 'Fresh function-fleet readback contains a non-passing check.'
    }
  }
  $functions = @($Receipt.outputs.functions)
  if ($functions.Count -ne [int]$BackendAuthority.deployedFunctionCount) {
    throw 'Fresh function-fleet output count is incomplete.'
  }
  $names = @($functions | ForEach-Object { [string]$_.name })
  $requiredAuthorityNames = @(
    'mutateUserAuthority',
    'assignPublishedTemplateVersion',
    'completePlannedJobExecution',
    'executeMaintenanceWorkflowCommand'
  )
  foreach ($required in $requiredAuthorityNames) {
    if ($names -notcontains $required) {
      throw 'Fresh function-fleet readback is missing required authority surface.'
    }
  }
  $authorityFunctions = @($functions | Where-Object {
      $requiredAuthorityNames -contains [string]$_.name
    })
  $authoritySourceHashes = @($authorityFunctions |
    ForEach-Object { [string]$_.firebaseFunctionsHash } |
    Sort-Object -Unique)
  if ($authorityFunctions.Count -ne 4 -or
      $authoritySourceHashes.Count -ne 1 -or
      [string]::IsNullOrWhiteSpace($authoritySourceHashes[0])) {
    throw 'Authority functions do not share one admitted deployed source.'
  }
  if (@($functions | Where-Object {
        $_.state -ne 'ACTIVE' -or $_.environment -ne 'GEN_2'
      }).Count -ne 0) {
    throw 'Fresh function-fleet readback contains an inactive function.'
  }
  $finalizedAt = ConvertFrom-CanonicalUtcTimestamp `
    $BackendAuthority.fleetFinalizedAtUtc
  if (@($authorityFunctions | Where-Object {
        (ConvertFrom-CanonicalUtcTimestamp $_.updateTime) `
          -gt $finalizedAt
      }).Count -ne 0) {
    throw 'Authority-function deployment changed after the admitted fleet finalization.'
  }
  $capturedAt = ConvertFrom-CanonicalUtcTimestamp $Receipt.capturedAtUtc
  $age = [DateTimeOffset]::UtcNow - $capturedAt
  if ($age.TotalMinutes -lt -5 -or $age.TotalHours -gt 12) {
    throw 'Function-fleet readback is not fresh for this campaign.'
  }
  Assert-Equal $Receipt.mutationBoundary.functionsDeployed $false `
    'Readback function deployment boundary'
  Assert-Equal $Receipt.mutationBoundary.iamMutated $false `
    'Readback IAM mutation boundary'
  Assert-Equal $Receipt.mutationBoundary.usersOrBusinessRecordsMutated $false `
    'Readback business mutation boundary'
}

function Get-AndroidTool {
  param([Parameter(Mandatory)][string]$RelativePath)

  $sdkRoot = if ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
  } elseif ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
  } else {
    Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }
  $path = Join-Path $sdkRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing Android SDK tool: $RelativePath"
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

function Get-UiEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label
  )

  $safeLabel = $Label -replace '[^a-zA-Z0-9-]', '-'
  $remotePath = "/sdcard/crm3-$safeLabel-window.xml"
  $localPath = Join-Path $EvidenceRoot ".$safeLabel-window.xml"
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
      if (-not $captured) { Start-Sleep -Seconds 2 }
    }
    if (-not $captured) {
      throw 'UI hierarchy capture failed.'
    }
    $raw = Get-Content -LiteralPath $localPath -Raw
    [pscustomobject]@{
      sha256 = Get-Sha256 $localPath
      text = $raw
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
    [Parameter(Mandatory)][string]$Marker
  )

  [xml]$document = $UiText
  $escaped = $Marker.Replace("'", "&apos;")
  $node = $document.SelectSingleNode(
    "//node[@text='$escaped' or contains(@content-desc,'$escaped')]"
  )
  if ($null -eq $node) {
    throw "Could not find required UI marker: $Marker"
  }
  $match = [regex]::Match(
    [string]$node.bounds,
    '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$'
  )
  if (-not $match.Success) {
    throw 'UI marker bounds are malformed.'
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
    [string]$Center.x, [string]$Center.y
  )
}

function Move-ToMore {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label
  )

  $ui = Get-UiEvidence -Adb $Adb -Serial $Serial `
    -EvidenceRoot $EvidenceRoot -Label "$Label-navigation"
  $lower = $ui.text.ToLowerInvariant()
  if ($lower.Contains('awaiting approval') -or
      $lower.Contains('sign in with google')) {
    throw 'Approved application shell is not active.'
  }
  if (-not $lower.Contains('more')) {
    throw 'Approved application navigation is not visible.'
  }
  $center = Get-NodeCenter -UiText $ui.text -Marker 'More'
  Invoke-UiTap -Adb $Adb -Serial $Serial -Center $center
  Start-Sleep -Seconds 2
}

function Get-MoreSurfaceEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label
  )

  Move-ToMore -Adb $Adb -Serial $Serial `
    -EvidenceRoot $EvidenceRoot -Label $Label
  $combined = ''
  $hashes = [Collections.Generic.List[string]]::new()
  for ($attempt = 0; $attempt -le 8; $attempt++) {
    $ui = Get-UiEvidence -Adb $Adb -Serial $Serial `
      -EvidenceRoot $EvidenceRoot -Label "$Label-more-$attempt"
    $combined += "`n$($ui.text)"
    $hashes.Add($ui.sha256)
    if ($attempt -lt 8) {
      $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
        '-s', $Serial, 'shell', 'input', 'swipe',
        '540', '1750', '540', '600', '400'
      )
      Start-Sleep -Milliseconds 700
    }
  }
  $lower = $combined.ToLowerInvariant()
  [pscustomobject]@{
    uiSha256 = Get-TextSha256 ($hashes -join '|')
    approvedShell = $lower.Contains('more')
    templateAuthoring = $lower.Contains('template authoring')
    legacyTemplatePublisher = $lower.Contains('legacy template publisher') -or
      $lower.Contains('template publisher')
    knowledgeGovernance = $lower.Contains('knowledge governance')
    supportDiagnostics = $lower.Contains('support diagnostics')
    administration = $lower.Contains('administration')
    auditLog = $lower.Contains('audit log')
    rawUiRetained = $false
  }
}

function Wait-PendingApproval {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [int]$TimeoutSeconds = 60
  )

  $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $ui = Get-UiEvidence -Adb $Adb -Serial $Serial `
      -EvidenceRoot $EvidenceRoot -Label 'build8-f4-awaiting-approval'
    if ($ui.text.ToLowerInvariant().Contains('awaiting approval')) {
      return [pscustomobject]@{
        awaitingApproval = $true
        uiSha256 = $ui.sha256
        rawUiRetained = $false
      }
    }
    Start-Sleep -Seconds 2
  } while ([DateTimeOffset]::UtcNow -lt $deadline)
  throw 'Subject did not reach Awaiting Approval within the bounded window.'
}

function Get-InstalledAppEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)]$ArtifactAuthority
  )

  $paths = @(
    (Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'shell', 'pm', 'path',
      [string]$ArtifactAuthority.applicationId
    )).output -split '\r?\n' | Where-Object { $_ -like 'package:*' }
  )
  if ($paths.Count -ne 1) {
    throw 'Installed application is absent or split unexpectedly.'
  }
  $remoteApk = ([string]$paths[0]).Substring('package:'.Length)
  $localApk = Join-Path $EvidenceRoot ".$Label-installed.apk"
  try {
    $null = Invoke-ExternalText -FilePath $Adb -Arguments @(
      '-s', $Serial, 'pull', $remoteApk, $localApk
    )
    $apkSha256 = Get-Sha256 $localApk
  } finally {
    if (Test-Path -LiteralPath $localApk) {
      Remove-Item -LiteralPath $localApk -Force
    }
  }
  Assert-Equal $apkSha256 ([string]$ArtifactAuthority.apkSha256) `
    "$Label installed APK SHA-256"
  $package = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'dumpsys', 'package',
    [string]$ArtifactAuthority.applicationId
  )).output
  $versionCode = [regex]::Match($package, 'versionCode=(\d+)')
  $versionName = [regex]::Match($package, 'versionName=([^\s]+)')
  if (-not $versionCode.Success -or -not $versionName.Success) {
    throw "$Label package version could not be read."
  }
  Assert-Equal ([int]$versionCode.Groups[1].Value) `
    ([int]$ArtifactAuthority.versionCode) "$Label version code"
  Assert-Equal $versionName.Groups[1].Value `
    ([string]$ArtifactAuthority.versionName) "$Label version name"
  $appProcessId = (Invoke-ExternalText -FilePath $Adb -Arguments @(
    '-s', $Serial, 'shell', 'pidof',
    [string]$ArtifactAuthority.applicationId
  ) -AllowFailure).output.Trim()
  if ($appProcessId -notmatch '^\d+$') {
    throw "$Label application process is not running."
  }
  [pscustomobject]@{
    apkSha256 = $apkSha256
    versionCode = [int]$versionCode.Groups[1].Value
    versionName = $versionName.Groups[1].Value
    processId = [int]$appProcessId
  }
}

function Get-DeviceEvidence {
  param(
    [Parameter(Mandatory)][string]$Adb,
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][string]$ExpectedKind
  )

  $qemu = Get-DeviceProperty -Adb $Adb -Serial $Serial `
    -Name 'ro.kernel.qemu'
  if ($ExpectedKind -eq 'PHYSICAL' -and $qemu -eq '1') {
    throw 'Subject target is an emulator.'
  }
  if ($ExpectedKind -eq 'EMULATOR' -and $qemu -ne '1') {
    throw 'Operator target is not an emulator.'
  }
  $fingerprint = Get-DeviceProperty -Adb $Adb -Serial $Serial `
    -Name 'ro.build.fingerprint'
  if ([string]::IsNullOrWhiteSpace($fingerprint)) {
    throw 'Device build fingerprint is unavailable.'
  }
  [pscustomobject]@{
    kind = $ExpectedKind
    serialSha256 = Get-TextSha256 $Serial
    buildFingerprintSha256 = Get-TextSha256 $fingerprint
    apiLevel = [int](Get-DeviceProperty -Adb $Adb -Serial $Serial `
      -Name 'ro.build.version.sdk')
    rawIdentifierRetained = $false
  }
}

function Assert-SubjectSiSurface {
  param([Parameter(Mandatory)]$Surface)

  Assert-Equal $Surface.approvedShell $true 'Subject approved shell'
  Assert-Equal $Surface.templateAuthoring $true 'Subject Template authoring'
  Assert-Equal $Surface.legacyTemplatePublisher $true `
    'Subject Legacy template publisher'
  Assert-Equal $Surface.knowledgeGovernance $true `
    'Subject Knowledge governance'
  Assert-Equal $Surface.supportDiagnostics $true `
    'Subject Support diagnostics'
  Assert-Equal $Surface.administration $false 'Subject Administration'
  Assert-Equal $Surface.auditLog $false 'Subject Audit log'
}

function Assert-OperatorAdminSurface {
  param([Parameter(Mandatory)]$Surface)

  Assert-Equal $Surface.approvedShell $true 'Operator approved shell'
  Assert-Equal $Surface.administration $true 'Operator Administration'
  Assert-Equal $Surface.auditLog $true 'Operator Audit log'
}

function Assert-OperationsOnlySurface {
  param([Parameter(Mandatory)]$Surface)

  Assert-Equal $Surface.approvedShell $true 'Operations approved shell'
  Assert-Equal $Surface.templateAuthoring $false 'Operations Template authoring'
  Assert-Equal $Surface.legacyTemplatePublisher $false `
    'Operations Legacy template publisher'
  Assert-Equal $Surface.knowledgeGovernance $false `
    'Operations Knowledge governance'
  Assert-Equal $Surface.supportDiagnostics $false `
    'Operations Support diagnostics'
  Assert-Equal $Surface.administration $false 'Operations Administration'
  Assert-Equal $Surface.auditLog $false 'Operations Audit log'
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$promotionAbsolute = Join-Path $repositoryRoot $PromotionPath
$promotion = Get-Content -LiteralPath $promotionAbsolute -Raw | ConvertFrom-Json
$promotionSha256 = Get-Sha256 $promotionAbsolute
$artifact = $promotion.artifactAuthority
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceDirectory)
$repoWithSeparator = $repositoryRoot.TrimEnd('\') + '\'
if ($evidenceRoot.StartsWith(
    $repoWithSeparator,
    [StringComparison]::OrdinalIgnoreCase
  )) {
  throw 'EvidenceDirectory must be outside the repository.'
}
if (-not (Test-Path -LiteralPath $evidenceRoot)) {
  New-Item -ItemType Directory -Path $evidenceRoot | Out-Null
}

$phaseFiles = [ordered]@{
  Preflight = '01-preflight.json'
  CaptureRevoked = '02-revoked.json'
  CaptureRevocationRestored = '03-revocation-restored.json'
  CaptureWrongRole = '04-wrong-role.json'
  CaptureFinalRestoration = '05-final-restoration.json'
}
$receiptPath = Join-Path $evidenceRoot $phaseFiles[$Phase]
$failurePath = Join-Path $evidenceRoot (
  $phaseFiles[$Phase].Replace('.json', '-failure.json')
)

try {
  if ((Test-Path -LiteralPath $receiptPath) -or
      (Test-Path -LiteralPath $failurePath)) {
    throw 'This phase already has pass or failure evidence.'
  }
  $git = (Get-Command git -ErrorAction Stop).Source
  $null = Invoke-ExternalText -FilePath $git -Arguments @(
    '-C', $repositoryRoot, 'fetch', 'origin', 'main'
  )
  Assert-Equal (
    (Invoke-ExternalText -FilePath $git -Arguments @(
      '-C', $repositoryRoot, 'branch', '--show-current'
    )).output
  ) 'main' 'Execution branch'
  Assert-Equal (
    (Invoke-ExternalText -FilePath $git -Arguments @(
      '-C', $repositoryRoot, 'status', '--porcelain'
    )).output
  ) '' 'Tracked-clean main'
  $head = (Invoke-ExternalText -FilePath $git -Arguments @(
    '-C', $repositoryRoot, 'rev-parse', 'HEAD'
  )).output
  $originMain = (Invoke-ExternalText -FilePath $git -Arguments @(
    '-C', $repositoryRoot, 'rev-parse', 'origin/main'
  )).output
  Assert-Equal $head $originMain 'Fresh main/origin parity'

  foreach ($record in $promotion.adjudicatedPrerequisites.evidence) {
    Assert-TrackedEvidence -Record $record -RepositoryRoot $repositoryRoot
  }
  Assert-Equal (
    Get-Sha256 (Join-Path $repositoryRoot `
      $promotion.approvalAuthority.priorPhysicalPromotion)
  ) $promotion.approvalAuthority.priorPhysicalPromotionSha256 `
    'Prior physical promotion SHA-256'
  Assert-Equal (
    Get-Sha256 (Join-Path $repositoryRoot `
      $artifact.finalizationEvidence)
  ) $artifact.finalizationEvidenceSha256 `
    'Build 8 finalization evidence SHA-256'
  Assert-Equal (
    Get-Sha256 (Join-Path $repositoryRoot `
      $promotion.backendAuthority.deployedFleetEvidence)
  ) $promotion.backendAuthority.deployedFleetEvidenceSha256 `
    'Deployed fleet evidence SHA-256'
  Assert-Equal (Get-Sha256 $GovernedPackagePath) `
    $artifact.governedPackageSha256 'Governed package SHA-256'
  if (-not (Test-Path -LiteralPath $LiveBackendReadbackPath -PathType Leaf)) {
    throw 'Fresh live backend readback is required.'
  }
  $liveBackendReadback = Get-Content -LiteralPath $LiveBackendReadbackPath `
    -Raw | ConvertFrom-Json
  Assert-LiveBackendReadback -Receipt $liveBackendReadback `
    -BackendAuthority $promotion.backendAuthority
  $liveBackendReadbackSha256 = Get-Sha256 $LiveBackendReadbackPath

  $archive = [IO.Compression.ZipFile]::OpenRead(
    (Resolve-Path -LiteralPath $GovernedPackagePath).Path
  )
  $embeddedApk = Join-Path $evidenceRoot '.build8-authority-apk.tmp'
  try {
    $matches = @($archive.Entries | Where-Object FullName -EQ `
      $artifact.apkEntry)
    if ($matches.Count -ne 1) {
      throw 'Governed package does not contain exactly one expected APK.'
    }
    [IO.Compression.ZipFileExtensions]::ExtractToFile(
      $matches[0], $embeddedApk, $false
    )
    Assert-Equal (Get-Sha256 $embeddedApk) $artifact.apkSha256 `
      'Embedded APK SHA-256'
  } finally {
    $archive.Dispose()
    if (Test-Path -LiteralPath $embeddedApk) {
      Remove-Item -LiteralPath $embeddedApk -Force
    }
  }

  if ($SubjectSerial -eq $OperatorSerial) {
    throw 'Subject and operator targets must be distinct.'
  }
  $adb = Get-AndroidTool 'platform-tools\adb.exe'
  $attached = (Invoke-ExternalText -FilePath $adb -Arguments @(
    'devices'
  )).output
  $attachedSerials = Get-AuthorizedDeviceSerials $attached
  foreach ($serial in @($SubjectSerial, $OperatorSerial)) {
    if ($attachedSerials -notcontains $serial) {
      throw 'A required target is not attached and authorized.'
    }
  }
  $subjectDevice = Get-DeviceEvidence -Adb $adb -Serial $SubjectSerial `
    -ExpectedKind 'PHYSICAL'
  $operatorDevice = Get-DeviceEvidence -Adb $adb -Serial $OperatorSerial `
    -ExpectedKind 'EMULATOR'
  $subjectApp = Get-InstalledAppEvidence -Adb $adb -Serial $SubjectSerial `
    -EvidenceRoot $evidenceRoot -Label 'subject' `
    -ArtifactAuthority $artifact
  $operatorApp = Get-InstalledAppEvidence -Adb $adb -Serial $OperatorSerial `
    -EvidenceRoot $evidenceRoot -Label 'operator' `
    -ArtifactAuthority $artifact

  $preflightPath = Join-Path $evidenceRoot $phaseFiles.Preflight
  $preflight = $null
  if ($Phase -ne 'Preflight') {
    if (-not (Test-Path -LiteralPath $preflightPath -PathType Leaf)) {
      throw 'Preflight receipt is required.'
    }
    $preflight = Get-Content -LiteralPath $preflightPath -Raw |
      ConvertFrom-Json
    Assert-Equal $preflight.promotionSha256 $promotionSha256 `
      'Preflight promotion SHA-256'
    Assert-Equal $preflight.subject.device.serialSha256 `
      $subjectDevice.serialSha256 'Subject target identity'
    Assert-Equal $preflight.operator.device.serialSha256 `
      $operatorDevice.serialSha256 'Operator target identity'
    Assert-Equal $preflight.subject.app.processId $subjectApp.processId `
      'Same physical application process'
    Assert-Equal $preflight.operator.app.processId $operatorApp.processId `
      'Same operator application process'
  }

  $base = [ordered]@{
    schemaVersion = 1
    evidenceType = 'build-8-f4-authority-negative-device-campaign'
    phase = $Phase
    capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    sourceCommit = $head
    promotionSha256 = $promotionSha256
    governedPackageSha256 = [string]$artifact.governedPackageSha256
    apkSha256 = [string]$artifact.apkSha256
    liveBackendReadbackSha256 = $liveBackendReadbackSha256
    rawUiRetained = $false
    rawDeviceIdentifiersRetained = $false
    rawAccountIdentifiersRetained = $false
    tokensRetained = $false
  }

  switch ($Phase) {
    'Preflight' {
      if (-not $ConfirmIdentitySeparation -or
          -not $ConfirmSubjectExactRolesCaptured -or
          -not $ConfirmLiveBackendReadback) {
        throw 'Preflight confirmations are incomplete.'
      }
      $normalizedRoles = @($SubjectInitialRoles |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Sort-Object -Unique)
      if ($normalizedRoles.Count -eq 0 -or
          $normalizedRoles -notcontains 'si' -or
          $normalizedRoles -contains 'admin') {
        throw 'SubjectInitialRoles must describe an SI non-Admin preimage.'
      }
      $subjectSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $SubjectSerial -EvidenceRoot $evidenceRoot `
        -Label 'subject-preflight'
      Assert-SubjectSiSurface $subjectSurface
      $operatorSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $OperatorSerial -EvidenceRoot $evidenceRoot `
        -Label 'operator-preflight'
      Assert-OperatorAdminSurface $operatorSurface
      $base.subject = [ordered]@{
        device = $subjectDevice
        app = $subjectApp
        surface = $subjectSurface
        initialApproval = $true
        initialRoles = $normalizedRoles
        exactRolePreimageCaptured = $true
      }
      $base.operator = [ordered]@{
        device = $operatorDevice
        app = $operatorApp
        surface = $operatorSurface
        confirmedDifferentApprovedAdmin = $true
      }
      $base.decision = 'PASS_BUILD8_F4_AUTHORITY_NEGATIVE_PREFLIGHT'
    }
    'CaptureRevoked' {
      if (-not $ConfirmGovernedMutationSucceeded) {
        throw 'Governed revoke confirmation is required.'
      }
      $pending = Wait-PendingApproval -Adb $adb `
        -Serial $SubjectSerial -EvidenceRoot $evidenceRoot
      $base.preflightReceiptSha256 = Get-Sha256 $preflightPath
      $base.subject = [ordered]@{
        device = $subjectDevice
        app = $subjectApp
        pendingApproval = $pending
        sameProcessWithoutRelaunch = $true
        privilegedSurfaceReachable = $false
      }
      $base.mutation = [ordered]@{
        operation = 'REVOKE'
        path = 'Build 8 User Management -> mutateUserAuthority'
        operatorConfirmedGovernedSuccess = $true
        restorationRequiredBeforeContinuation = $true
      }
      $base.decision =
        'PASS_BUILD8_F4_REVOCATION_NEXT_OPERATION_DENIAL_CAPTURED'
    }
    'CaptureRevocationRestored' {
      if (-not $ConfirmGovernedMutationSucceeded -or
          -not $ConfirmExactRoleRestoration) {
        throw 'Governed approve and exact restoration confirmations are required.'
      }
      $revokedPath = Join-Path $evidenceRoot $phaseFiles.CaptureRevoked
      if (-not (Test-Path -LiteralPath $revokedPath -PathType Leaf)) {
        throw 'Revocation receipt is required.'
      }
      $subjectSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $SubjectSerial -EvidenceRoot $evidenceRoot `
        -Label 'subject-revocation-restored'
      Assert-SubjectSiSurface $subjectSurface
      $operatorSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $OperatorSerial -EvidenceRoot $evidenceRoot `
        -Label 'operator-revocation-restored'
      Assert-OperatorAdminSurface $operatorSurface
      $base.preflightReceiptSha256 = Get-Sha256 $preflightPath
      $base.revocationReceiptSha256 = Get-Sha256 $revokedPath
      $base.subject = [ordered]@{
        device = $subjectDevice
        app = $subjectApp
        surface = $subjectSurface
        approvalRestored = $true
        exactRolesRestored = $true
        restoredRoles = @($preflight.subject.initialRoles)
        sameProcessWithoutRelaunch = $true
      }
      $base.operator = [ordered]@{
        app = $operatorApp
        surface = $operatorSurface
        remainsApprovedAdmin = $true
      }
      $base.decision = 'PASS_BUILD8_F4_REVOCATION_EXACTLY_RESTORED'
    }
    'CaptureWrongRole' {
      if (-not $ConfirmGovernedMutationSucceeded -or
          -not $ConfirmOperationsOnlyRoleSet) {
        throw 'Governed operations-only replacement confirmation is required.'
      }
      $restoredPath = Join-Path $evidenceRoot `
        $phaseFiles.CaptureRevocationRestored
      if (-not (Test-Path -LiteralPath $restoredPath -PathType Leaf)) {
        throw 'Revocation-restoration receipt is required.'
      }
      $subjectSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $SubjectSerial -EvidenceRoot $evidenceRoot `
        -Label 'subject-wrong-role'
      Assert-OperationsOnlySurface $subjectSurface
      $operatorSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $OperatorSerial -EvidenceRoot $evidenceRoot `
        -Label 'operator-wrong-role'
      Assert-OperatorAdminSurface $operatorSurface
      $base.preflightReceiptSha256 = Get-Sha256 $preflightPath
      $base.revocationRestorationReceiptSha256 = Get-Sha256 $restoredPath
      $base.subject = [ordered]@{
        device = $subjectDevice
        app = $subjectApp
        surface = $subjectSurface
        physicalCapabilityProfile = 'OPERATIONS_ONLY_SURFACES'
        operatorConfirmedRoleProfile = @('operations')
        sameProcessWithoutRelaunch = $true
      }
      $base.operator = [ordered]@{
        app = $operatorApp
        surface = $operatorSurface
        remainsApprovedAdmin = $true
      }
      $base.compositeServerDenial = [ordered]@{
        deployedFleetCommit =
          [string]$promotion.backendAuthority.deployedFleetCommit
        witnesses = @($promotion.backendAuthority.serverDenialWitnesses)
        livePhysicalMutationDenialClaimed = $false
        syntheticProductionMutationAttempted = $false
      }
      $base.restorationRequiredBeforeFinalPass = $true
      $base.decision =
        'PASS_BUILD8_F4_WRONG_ROLE_PHYSICAL_COMPONENT_CAPTURED'
    }
    'CaptureFinalRestoration' {
      if (-not $ConfirmGovernedMutationSucceeded -or
          -not $ConfirmExactRoleRestoration) {
        throw 'Governed final exact restoration confirmations are required.'
      }
      $wrongRolePath = Join-Path $evidenceRoot `
        $phaseFiles.CaptureWrongRole
      if (-not (Test-Path -LiteralPath $wrongRolePath -PathType Leaf)) {
        throw 'Wrong-role receipt is required.'
      }
      $subjectSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $SubjectSerial -EvidenceRoot $evidenceRoot `
        -Label 'subject-final-restoration'
      Assert-SubjectSiSurface $subjectSurface
      $operatorSurface = Get-MoreSurfaceEvidence -Adb $adb `
        -Serial $OperatorSerial -EvidenceRoot $evidenceRoot `
        -Label 'operator-final-restoration'
      Assert-OperatorAdminSurface $operatorSurface
      $base.preflightReceiptSha256 = Get-Sha256 $preflightPath
      $base.wrongRoleReceiptSha256 = Get-Sha256 $wrongRolePath
      $base.subject = [ordered]@{
        device = $subjectDevice
        app = $subjectApp
        surface = $subjectSurface
        approvalRestored = $true
        exactRolesRestored = $true
        restoredRoles = @($preflight.subject.initialRoles)
        sameProcessAcrossEntireCampaign = $true
      }
      $base.operator = [ordered]@{
        app = $operatorApp
        surface = $operatorSurface
        remainsApprovedAdmin = $true
      }
      $base.programme = [ordered]@{
        revocationCriterionReadyForAdjudication = $true
        wrongRoleCriterionReadyForAdjudication = $true
        stage2dF4Closed = $false
        p07Closed = $false
        pilotHandoutAuthorized = $false
        separateAdjudicationRequired = $true
      }
      $base.decision =
        'PASS_BUILD8_F4_AUTHORITY_NEGATIVE_CAPTURE_READY_FOR_ADJUDICATION'
    }
  }

  Write-Utf8NoBom -Path $receiptPath `
    -Text (($base | ConvertTo-Json -Depth 30) + "`n")
  $base | ConvertTo-Json -Depth 30
} catch {
  if (-not (Test-Path -LiteralPath $failurePath)) {
    $failure = [ordered]@{
      schemaVersion = 1
      evidenceType = 'build-8-f4-authority-negative-device-campaign-failure'
      phase = $Phase
      capturedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
      promotionSha256 = $promotionSha256
      failureClass = 'FAILED_CLOSED'
      failureDetailSha256 = Get-TextSha256 $_.Exception.Message
      rawFailureDetailRetained = $false
      authorityRestorationMustBeVerifiedBeforeAnyRetry =
        $Phase -ne 'Preflight'
      failedAttemptMayNotBeRelabelledPass = $true
      decision = 'FAIL_BUILD8_F4_AUTHORITY_NEGATIVE_REQUIRES_ADJUDICATION'
    }
    Write-Utf8NoBom -Path $failurePath `
      -Text (($failure | ConvertTo-Json -Depth 20) + "`n")
  }
  throw
}
