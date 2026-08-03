#requires -Version 7.0
<#
.SYNOPSIS
Builds one governed production-signed pre-release APK/AAB from exact protected
GitHub Actions authority and emits a self-verifying evidence package.

.DESCRIPTION
This script is CI-only. It refuses local execution, arbitrary branches,
unreserved build numbers, reused build numbers, skipped quality gates, a
self-derived Isar expected hash, debug signing, or distribution approval.

The workflow must create the remote reservation tag before invoking this script.
The remote built tag is created only by the post-download finalizer after
independent verification and dual custody.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9a-fA-F]{40}$')]
  [string]$ExpectedCommit,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ExpectedReleaseId,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ExpectedReservationId,

  [Parameter(Mandatory)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$')]
  [string]$ExpectedApprovalReference,

  [Parameter(Mandatory)]
  [ValidateRange(1, 2147483647)]
  [int]$ExpectedBuildNumber,

  [Parameter(Mandatory)]
  [string]$BundletoolJarPath,

  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9A-Fa-f]{64}$')]
  [string]$ExpectedBundletoolSha256,

  [Parameter(Mandatory)]
  [string]$IsarCorePath,

  [Parameter(Mandatory)]
  [ValidatePattern('^[0-9A-Fa-f]{64}$')]
  [string]$ExpectedIsarCoreSha256,

  [string]$PolicyPath = 'release/production-release-policy.json',
  [string]$AuthorityPath = 'release/backend-authority.prod.json',
  [Parameter(Mandatory)]
  [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory)][string]$Path,
    [AllowEmptyString()][string]$Text
  )

  $parent = Split-Path -Parent $Path
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }

  [IO.File]::WriteAllText(
    $Path,
    $Text,
    [Text.UTF8Encoding]::new($false)
  )
}

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing file: $Path"
  }

  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-ZipEntryBytes {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  $normalized = $EntryPath.Replace('\', '/')
  $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)

  try {
    $entry = $archive.Entries |
      Where-Object FullName -eq $normalized |
      Select-Object -First 1

    if ($null -eq $entry) {
      throw "Source entry missing: $normalized"
    }

    $stream = $entry.Open()
    try {
      $memory = [IO.MemoryStream]::new()
      $stream.CopyTo($memory)
      $memory.ToArray()
    }
    finally {
      $stream.Dispose()
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Get-ZipEntrySha256 {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      (Get-ZipEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath)
    )
  )
}

function Get-ZipEntryText {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath
  )

  [Text.Encoding]::UTF8.GetString(
    (Get-ZipEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath)
  )
}

function Export-ZipEntry {
  param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$EntryPath,
    [Parameter(Mandatory)][string]$DestinationPath
  )

  [IO.File]::WriteAllBytes(
    $DestinationPath,
    (Get-ZipEntryBytes -ArchivePath $ArchivePath -EntryPath $EntryPath)
  )
}

function Invoke-Logged {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Command,
    [Parameter(Mandatory)][string]$LogPath,
    [switch]$AllowFailure
  )

  Write-Host "==> $Name" -ForegroundColor Cyan
  $output = @(& $Command 2>&1)
  $exitCode = $LASTEXITCODE

  Write-Utf8NoBom -Path $LogPath -Text (
    ($output -join [Environment]::NewLine) +
    [Environment]::NewLine
  )

  if ($exitCode -ne 0 -and -not $AllowFailure) {
    $output | Out-Host
    throw "$Name failed with exit code $exitCode"
  }

  [ordered]@{
    exitCode = $exitCode
    output = $output
  }
}

function Find-AndroidTool {
  param(
    [Parameter(Mandatory)][string[]]$Names,
    [Parameter(Mandatory)][string[]]$RelativeRoots
  )

  $sdkRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)

  if ($IsWindows -and $env:LOCALAPPDATA) {
    $sdkRoots += Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }

  foreach ($sdkRoot in ($sdkRoots | Where-Object { $_ } | Select-Object -Unique)) {
    foreach ($relativeRoot in $RelativeRoots) {
      $searchRoot = Join-Path $sdkRoot $relativeRoot
      if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) {
        continue
      }

      foreach ($name in $Names) {
        $match = Get-ChildItem -LiteralPath $searchRoot -File -Recurse `
          -Filter $name -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending |
          Select-Object -First 1

        if ($match) {
          return $match.FullName
        }
      }
    }
  }

  foreach ($name in $Names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }

  throw "Android tool unavailable: $($Names -join ', ')"
}

function Get-ApkManifestValue {
  param(
    [Parameter(Mandatory)][string]$Analyzer,
    [Parameter(Mandatory)][string]$Command,
    [Parameter(Mandatory)][string]$ApkPath
  )

  $output = @(& $Analyzer manifest $Command $ApkPath 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "apkanalyzer manifest $Command failed: $($output -join "`n")"
  }

  ($output | Select-Object -Last 1).ToString().Trim()
}

function Get-ApkCertificateSha256 {
  param(
    [Parameter(Mandatory)][string]$ApkSigner,
    [Parameter(Mandatory)][string]$ApkPath,
    [Parameter(Mandatory)][string]$LogPath
  )

  $output = @(
    & $ApkSigner verify --verbose --print-certs $ApkPath 2>&1
  )
  Write-Utf8NoBom -Path $LogPath -Text (($output -join "`n") + "`n")

  if ($LASTEXITCODE -ne 0) {
    throw 'APK signature verification failed.'
  }

  $digests = @(
    $output |
      Select-String -Pattern 'certificate SHA-256 digest:\s*([0-9A-Fa-f:]+)' |
      ForEach-Object {
        $_.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
      } |
      Sort-Object -Unique
  )

  if ($digests.Count -ne 1) {
    throw "APK must have exactly one unique signer certificate; found $($digests.Count)."
  }

  $digests[0]
}

function Export-ApprovedSignerCertificate {
  param(
    [Parameter(Mandatory)][string]$StoreFile,
    [Parameter(Mandatory)][string]$Alias,
    [Parameter(Mandatory)][string]$DerPath,
    [Parameter(Mandatory)][string]$PemPath
  )

  & keytool -exportcert `
    -keystore $StoreFile `
    -storepass:env CRM_ANDROID_RELEASE_STORE_PASSWORD `
    -alias $Alias `
    -file $DerPath | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to export approved signer certificate in DER format.'
  }

  & keytool -exportcert -rfc `
    -keystore $StoreFile `
    -storepass:env CRM_ANDROID_RELEASE_STORE_PASSWORD `
    -alias $Alias `
    -file $PemPath | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to export approved signer certificate in PEM format.'
  }
}

function Get-AabCertificateSha256 {
  param(
    [Parameter(Mandatory)][string]$AabPath,
    [Parameter(Mandatory)][string]$ApprovedCertificateDerPath,
    [Parameter(Mandatory)][string]$LogPath
  )

  $trustStore = Join-Path $env:RUNNER_TEMP (
    'crm3-aab-trust-' + [guid]::NewGuid().ToString('N') + '.p12'
  )
  $trustPassword = [Convert]::ToBase64String(
    [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
  ).Replace('/', 'A').Replace('+', 'B').TrimEnd('=')

  try {
    & keytool -importcert -noprompt `
      -alias crm3-approved-production-signer `
      -file $ApprovedCertificateDerPath `
      -keystore $trustStore `
      -storetype PKCS12 `
      -storepass $trustPassword | Out-Null

    if ($LASTEXITCODE -ne 0) {
      throw 'Unable to create temporary AAB verification truststore.'
    }

    $verifyOutput = @(
      & jarsigner -verify -strict -verbose -certs `
        -keystore $trustStore `
        -storetype PKCS12 `
        -storepass $trustPassword `
        $AabPath 2>&1
    )
    Write-Utf8NoBom -Path $LogPath -Text (
      ($verifyOutput -join "`n") + "`n"
    )

    if ($LASTEXITCODE -ne 0) {
      throw 'AAB strict signature verification failed.'
    }

    $certificateOutput = @(& keytool -printcert -jarfile $AabPath 2>&1)
    if ($LASTEXITCODE -ne 0) {
      throw 'AAB signer certificate extraction failed.'
    }

    $digests = @(
      $certificateOutput |
        Select-String -Pattern 'SHA256:\s*([0-9A-Fa-f:]+)' |
        ForEach-Object {
          $_.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
        } |
        Sort-Object -Unique
    )

    if ($digests.Count -ne 1) {
      throw "AAB must have exactly one unique signer certificate; found $($digests.Count)."
    }

    $digests[0]
  }
  finally {
    Remove-Item -LiteralPath $trustStore -Force -ErrorAction SilentlyContinue
    $trustPassword = $null
  }
}

function Get-AabManifestFacts {
  param(
    [Parameter(Mandatory)][string]$BundletoolJar,
    [Parameter(Mandatory)][string]$AabPath,
    [Parameter(Mandatory)][string]$LogPath
  )

  $output = @(
    & java -jar $BundletoolJar dump manifest `
      "--bundle=$AabPath" `
      '--module=base' 2>&1
  )
  Write-Utf8NoBom -Path $LogPath -Text (($output -join "`n") + "`n")

  if ($LASTEXITCODE -ne 0) {
    throw 'bundletool manifest dump failed.'
  }

  $xml = $output -join "`n"
  $packageName = [regex]::Match(
    $xml,
    '<manifest[^>]*\bpackage="([^"]+)"'
  ).Groups[1].Value
  $versionCode = [regex]::Match(
    $xml,
    'android:versionCode="([^"]+)"'
  ).Groups[1].Value
  $versionName = [regex]::Match(
    $xml,
    'android:versionName="([^"]+)"'
  ).Groups[1].Value
  $debuggable = [regex]::Match(
    $xml,
    '<application[^>]*android:debuggable="([^"]+)"'
  ).Groups[1].Value

  if (-not $packageName -or -not $versionCode -or -not $versionName) {
    throw 'Unable to parse AAB package/version identity.'
  }

  if (-not $debuggable) {
    $debuggable = 'false'
  }

  [ordered]@{
    applicationId = $packageName
    versionCode = $versionCode
    versionName = $versionName
    debuggable = $debuggable
  }
}

function Get-RemoteRefCommit {
  param([Parameter(Mandatory)][string]$RefName)

  $queries = @($RefName)
  if ($RefName -like 'refs/tags/*' -and $RefName -notmatch '\^\{\}$') {
    $queries += "$RefName^{}"
  }

  $lines = @(git ls-remote origin @queries)
  if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
    return $null
  }

  $peeled = $lines |
    Where-Object { $_ -match '\^\{\}$' } |
    Select-Object -First 1
  $chosen = if ($null -ne $peeled) {
    $peeled
  }
  else {
    $lines | Select-Object -First 1
  }

  (($chosen -split '\s+')[0]).Trim().ToLowerInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [Text.Encoding]::UTF8.GetBytes($Text)
    )
  )
}

function Get-LocalAnnotatedTagAuthority {
  param(
    [Parameter(Mandatory)][string]$TagName,
    [Parameter(Mandatory)][string]$ExpectedCommit
  )

  $tagRef = "refs/tags/$TagName"
  $objectSha = @(git rev-parse "$tagRef^{tag}")
  if ($LASTEXITCODE -ne 0 -or $objectSha.Count -ne 1) {
    throw "Build reservation must be an annotated tag: $TagName"
  }

  $peeledCommit = @(git rev-parse "$tagRef^{}")
  if ($LASTEXITCODE -ne 0 -or $peeledCommit.Count -ne 1 -or
      $peeledCommit[0].Trim().ToLowerInvariant() -ne
        $ExpectedCommit.ToLowerInvariant()) {
    throw "Annotated tag does not peel to the expected commit: $TagName"
  }

  $contentLines = @(
    git for-each-ref '--format=%(contents)' $tagRef
  )
  if ($LASTEXITCODE -ne 0 -or $contentLines.Count -eq 0) {
    throw "Unable to read annotated tag contents: $TagName"
  }

  $contents = (($contentLines -join "`n").TrimEnd() + "`n")
  [ordered]@{
    objectSha = $objectSha[0].Trim().ToLowerInvariant()
    peeledCommit = $peeledCommit[0].Trim().ToLowerInvariant()
    contents = $contents
    contentsSha256 = Get-TextSha256 $contents
  }
}

# CI-only authority.
if ($env:GITHUB_ACTIONS -ne 'true') {
  throw 'Production artifact builder is CI-only; GITHUB_ACTIONS must be true.'
}
foreach ($requiredEnvironment in @(
  'GITHUB_REPOSITORY',
  'GITHUB_REF',
  'GITHUB_REF_NAME',
  'GITHUB_RUN_ID',
  'GITHUB_RUN_ATTEMPT',
  'GITHUB_WORKFLOW_REF',
  'GITHUB_WORKFLOW',
  'GITHUB_JOB',
  'GITHUB_SHA',
  'GITHUB_ACTOR',
  'GITHUB_ACTOR_ID',
  'GITHUB_TRIGGERING_ACTOR'
)) {
  if ([string]::IsNullOrWhiteSpace(
      [Environment]::GetEnvironmentVariable($requiredEnvironment)
    )) {
    throw "Missing required GitHub Actions authority: $requiredEnvironment"
  }
}
if ($env:GITHUB_SHA.ToLowerInvariant() -ne $ExpectedCommit.ToLowerInvariant()) {
  throw 'GITHUB_SHA differs from ExpectedCommit.'
}
if ($env:GITHUB_REF -ne 'refs/heads/main' -or
    $env:GITHUB_REF_NAME -ne 'main') {
  throw 'Production artifact workflow must be dispatched from main.'
}
if ($env:GITHUB_WORKFLOW_REF -notmatch
  '\.github/workflows/production-artifact\.yml@refs/heads/main$') {
  throw 'Builder was not invoked by the approved production-artifact workflow.'
}

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo

$head = (git rev-parse HEAD).Trim().ToLowerInvariant()
$tree = (git rev-parse 'HEAD^{tree}').Trim().ToLowerInvariant()
$remoteMain = Get-RemoteRefCommit -RefName 'refs/heads/main'

if ($head -ne $ExpectedCommit.ToLowerInvariant() -or $remoteMain -ne $head) {
  throw 'Artifact must be built from exact live remote main.'
}
if (@(git status --porcelain=v1 --untracked-files=all).Count -gt 0) {
  throw 'Repository must be clean.'
}

$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $AuthorityPath -Raw | ConvertFrom-Json

if ($policy.schemaVersion -ne 3) {
  throw 'Unsupported production policy schema; expected 3.'
}
if ([string]$env:GITHUB_REPOSITORY -ne [string]$policy.github.repository -or
    [string]$env:GITHUB_WORKFLOW -ne 'Production signed artifact' -or
    [string]$policy.github.workflowPath -ne
      '.github/workflows/production-artifact.yml' -or
    [string]$policy.github.environmentName -ne
      'crm3-baf-ops-production-signing') {
  throw 'GitHub Actions repository/workflow/environment authority mismatch.'
}
if ([string]$policy.release.releaseId -ne $ExpectedReleaseId) {
  throw 'Release ID mismatch.'
}
if ([string]$policy.versionPolicy.reservationId -ne
  $ExpectedReservationId) {
  throw 'Reservation ID mismatch.'
}
$versionApproval = Get-Content `
  -LiteralPath $policy.versionPolicy.approvalReceiptFile `
  -Raw | ConvertFrom-Json
if ([string]$versionApproval.reference -ne $ExpectedApprovalReference -or
    [string]$policy.github.environmentReviewControl.mode -ne
      'public-repository-required-reviewer' -or
    $policy.github.environmentReviewControl.
      manualDispatchApprovalReferenceRequired -ne $true) {
  throw 'Dispatch approval reference differs from governed authority.'
}
if ([int]$policy.release.buildNumber -ne $ExpectedBuildNumber) {
  throw 'Build-number input differs from policy.'
}
if ([string]$policy.distribution.authority -ne
  'production-signed-pre-release-candidate' -or
  $policy.distribution.approved -ne $false) {
  throw 'O-05 builder may produce only a non-distributable pre-release candidate.'
}

& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/Test-ProductionReleasePolicy.ps1 `
  -PolicyPath $PolicyPath `
  -RepositoryRoot $repo
if ($LASTEXITCODE -ne 0) {
  throw 'Production policy verification failed.'
}

& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/Test-BackendAuthority.ps1 `
  -AuthorityPath $AuthorityPath `
  -RepositoryRoot $repo `
  -ExpectedReleaseId ([string]$authority.releaseId)
if ($LASTEXITCODE -ne 0) {
  throw 'Composite backend authority verification failed.'
}

$nodeVersion = (& node --version).Trim().TrimStart('v')
$npmVersion = (& npm --version).Trim()
$flutterMachine = ((& flutter --version --machine) -join "`n") |
  ConvertFrom-Json
$dartVersionOutput = ((& dart --version 2>&1) -join "`n")
$javaVersionOutput = ((& java -version 2>&1) -join "`n")
$gitVersionOutput = (& git --version).Trim()

if ($nodeVersion -ne [string]$policy.toolchain.nodeVersion -or
    $npmVersion -ne [string]$policy.toolchain.npmVersion -or
    [string]$flutterMachine.frameworkVersion -ne
      [string]$policy.toolchain.flutterVersion -or
    $dartVersionOutput -notmatch
      [regex]::Escape([string]$policy.toolchain.dartVersion)) {
  throw 'Actual Node/npm/Flutter/Dart toolchain differs from policy.'
}
$javaBase = ([string]$policy.toolchain.javaVersion).Split('+')[0]
$javaBuild = ([string]$policy.toolchain.javaVersion).Split('+')[-1]
if ($javaVersionOutput -notmatch [regex]::Escape($javaBase) -or
    $javaVersionOutput -notmatch [regex]::Escape("+$javaBuild")) {
  throw 'Actual Java toolchain differs from policy.'
}
$actualToolchain = [ordered]@{
  runnerImage = [string]$policy.toolchain.runnerImage
  githubImageOs = [string]$env:ImageOS
  githubImageVersion = [string]$env:ImageVersion
  runnerOs = [string]$env:RUNNER_OS
  runnerArch = [string]$env:RUNNER_ARCH
  powerShellVersion = $PSVersionTable.PSVersion.ToString()
  javaVersion = [string]$policy.toolchain.javaVersion
  javaVersionOutput = $javaVersionOutput
  nodeVersion = $nodeVersion
  npmVersion = $npmVersion
  flutterVersion = [string]$flutterMachine.frameworkVersion
  flutterFrameworkRevision = [string]$flutterMachine.frameworkRevision
  dartVersion = [string]$policy.toolchain.dartVersion
  dartVersionOutput = $dartVersionOutput
  gitVersionOutput = $gitVersionOutput
}

$reservationTag = [string]$policy.versionPolicy.remoteReservationTag
$builtTag = [string]$policy.versionPolicy.remoteBuiltTag
$reservationRef = "refs/tags/$reservationTag"
$builtRef = "refs/tags/$builtTag"

$reservedCommit = Get-RemoteRefCommit -RefName $reservationRef
if ($reservedCommit -ne $head) {
  throw "Remote reservation tag is absent or points elsewhere: $reservationTag"
}
$reservationAuthority = Get-LocalAnnotatedTagAuthority `
  -TagName $reservationTag `
  -ExpectedCommit $head

$requiredReservationLines = @(
  "Build number: $ExpectedBuildNumber"
  "Release ID: $ExpectedReleaseId"
  "Reservation ID: $ExpectedReservationId"
  "Commit: $head"
  "GitHub run: $($env:GITHUB_RUN_ID)"
  "GitHub run attempt: $($env:GITHUB_RUN_ATTEMPT)"
)
foreach ($line in $requiredReservationLines) {
  if ($reservationAuthority.contents -notmatch
      "(?m)^$([regex]::Escape($line))$") {
    throw "Reservation tag message is missing governed field: $line"
  }
}
if ($null -ne (Get-RemoteRefCommit -RefName $builtRef)) {
  throw "Remote built tag already exists; build number is already consumed: $builtTag"
}

$storeFile = [Environment]::GetEnvironmentVariable(
  'CRM_ANDROID_RELEASE_STORE_FILE'
)
$storePassword = [Environment]::GetEnvironmentVariable(
  'CRM_ANDROID_RELEASE_STORE_PASSWORD'
)
$keyAlias = [Environment]::GetEnvironmentVariable(
  'CRM_ANDROID_RELEASE_KEY_ALIAS'
)
$keyPassword = [Environment]::GetEnvironmentVariable(
  'CRM_ANDROID_RELEASE_KEY_PASSWORD'
)

foreach ($value in @($storeFile, $storePassword, $keyAlias, $keyPassword)) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw 'Production signing environment is incomplete.'
  }
}

if ((Get-Sha256 $storeFile) -ne
  ([string]$policy.signing.keystoreSha256).ToUpperInvariant()) {
  throw 'Runner keystore hash differs from approved policy.'
}
if ($keyAlias -ne [string]$policy.signing.keyAlias) {
  throw 'Runner key alias differs from approved policy.'
}

if ((Get-Sha256 $BundletoolJarPath) -ne
  $ExpectedBundletoolSha256.ToUpperInvariant() -or
  $ExpectedBundletoolSha256.ToUpperInvariant() -ne
  ([string]$policy.toolchain.bundletoolSha256).ToUpperInvariant()) {
  throw 'bundletool hash differs from approved policy.'
}

if ((Get-Sha256 $IsarCorePath) -ne
  $ExpectedIsarCoreSha256.ToUpperInvariant() -or
  $ExpectedIsarCoreSha256.ToUpperInvariant() -ne
  ([string]$policy.toolchain.linuxIsarCoreSha256).ToUpperInvariant()) {
  throw 'Linux Isar core differs from the independently approved authority.'
}

$env:CRM_ISAR_CORE_PATH = (Resolve-Path $IsarCorePath).Path

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$releaseDirectory = Join-Path $OutputRoot ([string]$policy.release.releaseId)

if (Test-Path -LiteralPath $releaseDirectory) {
  throw 'Release output already exists; this invocation will not overwrite it.'
}

New-Item -ItemType Directory -Path $releaseDirectory | Out-Null
$logsDirectory = Join-Path $releaseDirectory 'logs'
$toolsDirectory = Join-Path $releaseDirectory 'tools'
$signerDirectory = Join-Path $releaseDirectory 'signer'
$remoteAuthorityDirectory = Join-Path $releaseDirectory 'remote-authority'
New-Item -ItemType Directory -Path $logsDirectory | Out-Null
New-Item -ItemType Directory -Path $toolsDirectory | Out-Null
New-Item -ItemType Directory -Path $signerDirectory | Out-Null
New-Item -ItemType Directory -Path $remoteAuthorityDirectory | Out-Null

$reservationMessagePath = Join-Path `
  $remoteAuthorityDirectory `
  'reservation-tag-message.txt'
Write-Utf8NoBom `
  -Path $reservationMessagePath `
  -Text $reservationAuthority.contents

$archiveName = "$($policy.release.releaseId)-source.zip"
$archivePath = Join-Path $releaseDirectory $archiveName

git archive --format=zip --output=$archivePath $head
if ($LASTEXITCODE -ne 0) {
  throw 'git archive failed.'
}
$archiveSha256 = Get-Sha256 $archivePath

$releaseGate = Invoke-Logged `
  -Name 'Repository release gate' `
  -Command {
    pwsh -NoProfile -ExecutionPolicy Bypass `
      -File release_gate.ps1 `
      -SkipBuild
  } `
  -LogPath (Join-Path $logsDirectory 'repository-release-gate.log')

$closureGate = Invoke-Logged `
  -Name 'Closure Firestore-emulator gate' `
  -Command { npm run emulator:test:closure } `
  -LogPath (Join-Path $logsDirectory 'closure-emulator.log')

if (($closureGate.output -join "`n") -match
  'Jest did not exit one second') {
  throw 'Closure emulator reported an open-handle warning.'
}

$rootAudit = Invoke-Logged `
  -Name 'Root npm audit capture' `
  -Command { npm audit --json } `
  -LogPath (Join-Path $logsDirectory 'npm-audit-root.json') `
  -AllowFailure

$functionsAudit = Invoke-Logged `
  -Name 'Functions npm audit capture' `
  -Command { npm --prefix functions audit --json } `
  -LogPath (Join-Path $logsDirectory 'npm-audit-functions.json') `
  -AllowFailure

$generatedAtUtc = [DateTime]::UtcNow.ToString('o')
$identityDefines = [ordered]@{
  APP_VERSION = [string]$policy.release.versionName
  APP_BUILD_NUMBER = [string]$policy.release.buildNumber
  GIT_COMMIT = $head
  RELEASE_TAG = [string]$policy.release.releaseTag
  RELEASE_CHANNEL = [string]$policy.release.releaseChannel
  CI_RUN_ID = [string]$env:GITHUB_RUN_ID
  BUILD_TIMESTAMP_UTC = $generatedAtUtc
  RELEASE_ID = [string]$policy.release.releaseId
  EXPECTED_BACKEND_RELEASE_ID = [string]$authority.releaseId
  SOURCE_ARCHIVE_SHA256 = $archiveSha256
}

$dartDefines = @()
foreach ($entry in $identityDefines.GetEnumerator()) {
  $dartDefines += "--dart-define=$($entry.Key)=$($entry.Value)"
}

$versionName = [string]$policy.release.versionName
$versionCode = [string]$policy.release.buildNumber

Invoke-Logged `
  -Name 'Build production-signed release APK' `
  -Command {
    flutter build apk --release `
      "--build-name=$versionName" `
      "--build-number=$versionCode" `
      @dartDefines
  } `
  -LogPath (Join-Path $logsDirectory 'flutter-build-apk.log') |
  Out-Null

Invoke-Logged `
  -Name 'Build production-signed release AAB' `
  -Command {
    flutter build appbundle --release `
      "--build-name=$versionName" `
      "--build-number=$versionCode" `
      @dartDefines
  } `
  -LogPath (Join-Path $logsDirectory 'flutter-build-aab.log') |
  Out-Null

$builtApk = Join-Path $repo 'build/app/outputs/flutter-apk/app-release.apk'
$builtAab = Join-Path $repo 'build/app/outputs/bundle/release/app-release.aab'

foreach ($artifact in @($builtApk, $builtAab)) {
  if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
    throw "Expected build artifact is missing: $artifact"
  }
}

$apkName = "$($policy.release.releaseId)-release.apk"
$aabName = "$($policy.release.releaseId)-release.aab"
$apkPath = Join-Path $releaseDirectory $apkName
$aabPath = Join-Path $releaseDirectory $aabName

Copy-Item -LiteralPath $builtApk -Destination $apkPath
Copy-Item -LiteralPath $builtAab -Destination $aabPath
Copy-Item -LiteralPath $BundletoolJarPath `
  -Destination (Join-Path $toolsDirectory 'bundletool.jar')

$certificateDer = Join-Path $signerDirectory 'approved-production-signer.der'
$certificatePem = Join-Path $signerDirectory 'approved-production-signer.pem'

Export-ApprovedSignerCertificate `
  -StoreFile $storeFile `
  -Alias $keyAlias `
  -DerPath $certificateDer `
  -PemPath $certificatePem

if ((Get-Sha256 $certificateDer) -ne
  ([string]$policy.signing.certificateSha256).ToUpperInvariant()) {
  throw 'Exported signer certificate differs from approved certificate SHA-256.'
}

$apkSigner = Find-AndroidTool `
  -Names @('apksigner.bat', 'apksigner') `
  -RelativeRoots @('build-tools')
$apkAnalyzer = Find-AndroidTool `
  -Names @('apkanalyzer.bat', 'apkanalyzer') `
  -RelativeRoots @('cmdline-tools', 'tools')
$actualToolchain['androidTools'] = [ordered]@{
  apkSignerPath = $apkSigner
  apkSignerSha256 = Get-Sha256 $apkSigner
  apkAnalyzerPath = $apkAnalyzer
  apkAnalyzerSha256 = Get-Sha256 $apkAnalyzer
}

$apkCertificateSha256 = Get-ApkCertificateSha256 `
  -ApkSigner $apkSigner `
  -ApkPath $apkPath `
  -LogPath (Join-Path $logsDirectory 'apksigner.log')

$aabCertificateSha256 = Get-AabCertificateSha256 `
  -AabPath $aabPath `
  -ApprovedCertificateDerPath $certificateDer `
  -LogPath (Join-Path $logsDirectory 'jarsigner-aab.log')

if ($apkCertificateSha256 -ne
  ([string]$policy.signing.certificateSha256).ToUpperInvariant() -or
  $aabCertificateSha256 -ne $apkCertificateSha256) {
  throw 'APK/AAB signer differs from the approved production certificate.'
}

$apkFacts = [ordered]@{
  applicationId = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'application-id' `
    -ApkPath $apkPath
  versionName = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'version-name' `
    -ApkPath $apkPath
  versionCode = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'version-code' `
    -ApkPath $apkPath
  debuggable = Get-ApkManifestValue `
    -Analyzer $apkAnalyzer `
    -Command 'debuggable' `
    -ApkPath $apkPath
}

$aabFacts = Get-AabManifestFacts `
  -BundletoolJar $BundletoolJarPath `
  -AabPath $aabPath `
  -LogPath (Join-Path $logsDirectory 'bundletool-manifest.log')

foreach ($facts in @($apkFacts, $aabFacts)) {
  if ($facts.applicationId -ne [string]$policy.permanentApplicationId -or
      $facts.versionName -ne $versionName -or
      [string]$facts.versionCode -ne $versionCode -or
      [string]$facts.debuggable -ne 'false') {
    throw 'Compiled artifact package/version/debuggable state differs from policy.'
  }
}

$verifierEntry =
  'tools/release/Test-ProductionReleaseManifest.ps1'
$packagedVerifier =
  Join-Path $releaseDirectory 'verify-production-release-package.ps1'
Export-ZipEntry `
  -ArchivePath $archivePath `
  -EntryPath $verifierEntry `
  -DestinationPath $packagedVerifier

$receiptFiles = @(
  'release/approvals/permanent-identity-approval.json'
  'release/approvals/version-policy-approval.json'
  [string]$policy.versionPolicy.sourceDocumentFile
  [string]$policy.github.environmentReviewControl.approvalReceiptFile
  'release/approvals/signing-custody-approval.json'
  'release/approvals/firebase-registration-receipt.json'
  'release/approvals/firebase-production-signing-restoration-receipt.json'
  'release/approvals/android-identity-migration-plan.json'
  'release/approvals/linux-isar-core-authority.json'
)

$receiptHashes = [ordered]@{}
foreach ($file in $receiptFiles) {
  $receiptHashes[$file] = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath $file
}

$configurationFiles = @(
  'firestore.rules'
  'firestore.indexes.json'
  'android/app/build.gradle.kts'
  'android/app/google-services.json'
  'lib/firebase_options.dart'
  'pubspec.yaml'
  'release/backend-authority.prod.json'
  'release/production-release-policy.json'
  'release/build-number-ledger.json'
  'release/evidence/70I_C_INDEX_PARITY_DECISION.json'
  'release/github-actions-pins.json'
  '.github/workflows/production-artifact.yml'
  'tools/release/New-ProductionArtifact.ps1'
  'tools/release/Finalize-ProductionRelease.ps1'
  'tools/release/Test-BackendAuthority.ps1'
  'tools/release/Test-ProductionReleaseManifest.ps1'
  'tools/release/Test-ProductionReleasePolicy.ps1'
  'tooling/firebase-cli/package.json'
  'tooling/firebase-cli/package-lock.json'
)

$configurationHashes = [ordered]@{}
foreach ($file in $configurationFiles) {
  $configurationHashes[$file] = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath $file
}

$lockfileHashes = [ordered]@{}
foreach ($file in @(
  'pubspec.lock'
  'package-lock.json'
  'functions/package-lock.json'
  'tooling/firebase-cli/package-lock.json'
)) {
  $lockfileHashes[$file] = Get-ZipEntrySha256 `
    -ArchivePath $archivePath `
    -EntryPath $file
}

$buildLedger = (
  Get-ZipEntryText `
    -ArchivePath $archivePath `
    -EntryPath 'release/build-number-ledger.json'
) | ConvertFrom-Json

$buildReservation = $buildLedger.entries |
  Where-Object reservationId -eq $policy.versionPolicy.reservationId |
  Select-Object -First 1

$manifest = [ordered]@{
  schemaVersion = 6
  generatedAtUtc = $generatedAtUtc
  artifactClass = 'production-signed-pre-release-candidate'
  distributionAuthority = 'production-signed-pre-release-candidate'
  release = $policy.release
  appIdentity = $identityDefines
  ciAuthority = [ordered]@{
    provider = 'github-actions'
    repository = [string]$env:GITHUB_REPOSITORY
    ref = [string]$env:GITHUB_REF
    refName = [string]$env:GITHUB_REF_NAME
    workflow = [string]$env:GITHUB_WORKFLOW
    workflowRef = [string]$env:GITHUB_WORKFLOW_REF
    runId = [string]$env:GITHUB_RUN_ID
    runAttempt = [string]$env:GITHUB_RUN_ATTEMPT
    job = [string]$env:GITHUB_JOB
    headSha = [string]$env:GITHUB_SHA
    actor = [string]$env:GITHUB_ACTOR
    actorId = [string]$env:GITHUB_ACTOR_ID
    triggeringActor = [string]$env:GITHUB_TRIGGERING_ACTOR
    environment = [string]$policy.github.environmentName
    dispatchApprovalReference = $ExpectedApprovalReference
    environmentReviewControl =
      $policy.github.environmentReviewControl
    localExecutionPermitted = $false
  }
  source = [ordered]@{
    gitCommit = $head
    gitTree = $tree
    remoteMainAtBuild = $remoteMain
    repositoryClean = $true
    sourceArchiveFile = $archiveName
    sourceArchiveSha256 = $archiveSha256
    hashBasis = 'git-archive-entry-bytes'
    entryPathStyle = 'posix'
  }
  remoteBuildAuthority = [ordered]@{
    buildNumber = [int]$policy.release.buildNumber
    reservationTag = $reservationTag
    reservationTagCommit = $reservedCommit
    reservationTagObjectSha = $reservationAuthority.objectSha
    reservationTagMessageFile =
      'remote-authority/reservation-tag-message.txt'
    reservationTagMessageSha256 =
      $reservationAuthority.contentsSha256
    builtTag = $builtTag
    builtTagMustBeAbsentDuringBuild = $true
    failedOrWithdrawnBuildConsumesNumber = $true
  }
  artifacts = @(
    [ordered]@{
      file = $apkName
      type = 'apk'
      sha256 = Get-Sha256 $apkPath
      sizeBytes = (Get-Item $apkPath).Length
      compiled = $apkFacts
    }
    [ordered]@{
      file = $aabName
      type = 'aab'
      sha256 = Get-Sha256 $aabPath
      sizeBytes = (Get-Item $aabPath).Length
      compiled = $aabFacts
    }
  )
  signing = [ordered]@{
    mode = 'release'
    productionSigningApproved = $true
    keyAlias = [string]$policy.signing.keyAlias
    keystoreSha256 = [string]$policy.signing.keystoreSha256
    certificateSha1 = [string]$policy.signing.certificateSha1
    certificateSha256 = $apkCertificateSha256
    certificateDerFile = 'signer/approved-production-signer.der'
    certificateDerSha256 = Get-Sha256 $certificateDer
    certificatePemFile = 'signer/approved-production-signer.pem'
    certificatePemSha256 = Get-Sha256 $certificatePem
    primaryCustodianName = [string]$policy.signing.primaryCustodianName
    backupCustodianName = [string]$policy.signing.backupCustodianName
    custodyReference = [string]$policy.signing.custodyReference
    backupProofSha256 = [string]$policy.signing.backupProofSha256
    recoveryProofSha256 = [string]$policy.signing.recoveryProofSha256
    approvalReceiptFile = [string]$policy.signing.approvalReceiptFile
    sourceDocumentSha256 = [string]$policy.signing.sourceDocumentSha256
    aabTrustModel = 'temporary-truststore-from-approved-public-certificate'
  }
  packageIdentity = [ordered]@{
    applicationId = [string]$policy.permanentApplicationId
    namespace = [string]$policy.namespace
    permanentIdentityApproved = $true
    operationalPackageIdCutoverBoundary = [string]$policy.migrationPlan.operationalCutoverBoundary
  }
  versionPolicy = $policy.versionPolicy
  buildNumberReservation = $buildReservation
  firebaseAndroidApp = $policy.firebaseAndroidApp
  migrationPlan = $policy.migrationPlan
  distribution = $policy.distribution
  backend = [ordered]@{
    expectedReleaseId = [string]$authority.releaseId
    authorityFile = 'release/backend-authority.prod.json'
    authorityFileSha256 = Get-ZipEntrySha256 `
      -ArchivePath $archivePath `
      -EntryPath 'release/backend-authority.prod.json'
    authorityClass = [string]$authority.authorityClass
    authorityDigest = [string]$authority.authorityDigest
    releaseModel = $authority.releaseModel
    repositoryAuthority = $authority.repositoryAuthority
    firestore = $authority.firestore
    sourceCustody = $authority.sourceCustody
  }
  policy = [ordered]@{
    file = 'release/production-release-policy.json'
    sha256 = Get-ZipEntrySha256 `
      -ArchivePath $archivePath `
      -EntryPath 'release/production-release-policy.json'
    approvalReceiptHashes = $receiptHashes
  }
  verificationTool = [ordered]@{
    file = 'verify-production-release-package.ps1'
    sha256 = Get-Sha256 $packagedVerifier
    sourceArchiveEntry = $verifierEntry
    sourceArchiveEntrySha256 = Get-ZipEntrySha256 `
      -ArchivePath $archivePath `
      -EntryPath $verifierEntry
  }
  toolchain = [ordered]@{
    bundletoolFile = 'tools/bundletool.jar'
    bundletoolSha256 = Get-Sha256 (
      Join-Path $toolsDirectory 'bundletool.jar'
    )
    firebaseToolsVersion = [string]$policy.toolchain.firebaseToolsVersion
    firebaseToolsLockfile = [string]$policy.toolchain.firebaseToolsLockfile
    firebaseToolsLockfileSha256 =
      [string]$policy.toolchain.firebaseToolsLockfileSha256
    linuxIsarCoreSha256 = Get-Sha256 $IsarCorePath
    linuxIsarCoreAuthorityReceipt =
      [string]$policy.toolchain.linuxIsarCoreAuthorityReceipt
    actual = $actualToolchain
  }
  dependencies = [ordered]@{
    lockfiles = $lockfileHashes
    rootAuditExitCode = $rootAudit.exitCode
    functionsAuditExitCode = $functionsAudit.exitCode
    auditsCapturedButNotReleaseApproved = $true
  }
  configuration = [ordered]@{
    hashes = $configurationHashes
  }
  qualityGates = [ordered]@{
    executed = $true
    repositoryReleaseGate = 'passed'
    closureFirestoreEmulator = 'passed'
    artifactApkSignature = 'passed'
    artifactAabSignature = 'passed'
    artifactApkIdentity = 'passed'
    artifactAabIdentity = 'passed'
    sourceArchiveIdentityDefineSupplied = $true
  }
  knownOpenGates = @($policy.knownOpenGates)
  releaseBoundary = [ordered]@{
    distributionApproved = $false
    controlledPilotApproved = $false
    unrestrictedPlantReleaseApproved = $false
    firebaseDeploymentPerformed = $false
    postBuildPromotionRequiredForAnyDistribution = $true
  }
}

$manifestPath =
  Join-Path $releaseDirectory 'production-release-manifest.json'
Write-Utf8NoBom `
  -Path $manifestPath `
  -Text (($manifest | ConvertTo-Json -Depth 50) + "`n")

$ledgerText = @"
# CRM-III BAF Ops Production-Signed Pre-Release Artifact Ledger

- Release ID: $($policy.release.releaseId)
- Version: $versionName+$versionCode
- Git commit: $head
- GitHub run: $($env:GITHUB_RUN_ID), attempt $($env:GITHUB_RUN_ATTEMPT)
- Application ID: $($policy.permanentApplicationId)
- APK SHA-256: $(Get-Sha256 $apkPath)
- AAB SHA-256: $(Get-Sha256 $aabPath)
- Certificate SHA-256: $apkCertificateSha256
- Source archive SHA-256: $archiveSha256
- Backend release: $($authority.releaseId)
- Backend authority: $($authority.authorityClass)
- Backend fleet: $($authority.releaseModel.functionFleetStatus)
- Index parity: $($authority.firestore.indexes.status) ($($authority.firestore.indexes.sourceCompositeIndexes) = $($authority.firestore.indexes.deployedCompositeIndexes), all ready)
- Remote reservation tag: $reservationTag
- Remote built tag: not created by builder
- Distribution: NOT APPROVED
- Unrestricted plant release: NOT APPROVED
- Firebase backend deployment: NOT PERFORMED
"@
Write-Utf8NoBom `
  -Path (Join-Path $releaseDirectory 'production-release-ledger.md') `
  -Text $ledgerText

& pwsh -NoProfile -ExecutionPolicy Bypass `
  -File $packagedVerifier `
  -ManifestPath $manifestPath `
  -RepositoryRoot $repo
if ($LASTEXITCODE -ne 0) {
  throw 'Independent package verification failed.'
}

$custodySummary = [ordered]@{
  schemaVersion = 2
  releaseId = [string]$policy.release.releaseId
  gitCommit = $head
  githubRunId = [string]$env:GITHUB_RUN_ID
  githubRunAttempt = [string]$env:GITHUB_RUN_ATTEMPT
  manifestSha256 = Get-Sha256 $manifestPath
  apkSha256 = Get-Sha256 $apkPath
  aabSha256 = Get-Sha256 $aabPath
  certificateSha256 = $apkCertificateSha256
  sourceArchiveSha256 = $archiveSha256
  reservationTag = $reservationTag
  distributionAuthority = 'production-signed-pre-release-candidate'
  unrestrictedPlantReleaseApproved = $false
}
Write-Utf8NoBom `
  -Path (Join-Path $releaseDirectory 'production-custody-summary.json') `
  -Text (($custodySummary | ConvertTo-Json -Depth 20) + "`n")

if (@(git status --porcelain=v1 --untracked-files=all).Count -gt 0) {
  throw 'Repository changed during artifact generation.'
}

$packageZip = Join-Path $OutputRoot (
  "$($policy.release.releaseId)-GOVERNED-PACKAGE.zip"
)
Compress-Archive `
  -Path (Join-Path $releaseDirectory '*') `
  -DestinationPath $packageZip `
  -CompressionLevel Optimal

$packageSha256 = Get-Sha256 $packageZip
Write-Utf8NoBom `
  -Path "$packageZip.sha256.txt" `
  -Text "$packageSha256  $(Split-Path -Leaf $packageZip)`n"

Write-Host ''
Write-Host '===== GOVERNED PRODUCTION-SIGNED PRE-RELEASE PACKAGE PASSED =====' `
  -ForegroundColor Green
Write-Host "Package:         $packageZip"
Write-Host "SHA-256:         $packageSha256"
Write-Host "Reservation tag: $reservationTag"
Write-Host "GitHub run:      $($env:GITHUB_RUN_ID)"
Write-Host 'Distribution:    NOT APPROVED'
Write-Host 'Unrestricted:    NOT APPROVED'
Write-Host 'Firebase deploy: NOT PERFORMED'
