[CmdletBinding()]
param(
  [Parameter()]
  [string]$RepositoryRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '../..')
  ).Path,

  [Parameter()]
  [string]$BuildName = '0.0.0-ci',

  [Parameter()]
  [ValidateRange(1, 2100000000)]
  [int]$BuildNumber = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Checked {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [Parameter(Mandatory)][string]$FailureMessage
  )

  & $FilePath @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "$FailureMessage Exit code: $LASTEXITCODE."
  }
}

function Invoke-Captured {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [Parameter(Mandatory)][string]$FailureMessage
  )

  $output = @(& $FilePath @ArgumentList 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "$FailureMessage Exit code: $LASTEXITCODE.`n$($output -join "`n")"
  }
  $output
}

function Get-CommandPath {
  param([Parameter(Mandatory)][string]$Name)

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Required command is unavailable: $Name"
  }
  $command.Source
}

function Get-AndroidSdkRoot {
  $runningOnWindows = (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  )
  $candidates = @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    $(if ($runningOnWindows) {
      Join-Path $HOME 'AppData\Local\Android\Sdk'
    }),
    $(if (-not $runningOnWindows) {
      Join-Path $HOME 'Android/Sdk'
    })
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  foreach ($candidate in $candidates) {
    $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
    if ($null -ne $resolved) {
      return $resolved.Path
    }
  }

  throw 'Android SDK root was not found.'
}

function Get-LatestBuildTool {
  param(
    [Parameter(Mandatory)][string]$AndroidSdkRoot,
    [Parameter(Mandatory)][string]$ToolName
  )

  $buildToolsRoot = Join-Path $AndroidSdkRoot 'build-tools'
  $directories = @(
    Get-ChildItem -LiteralPath $buildToolsRoot -Directory |
      Sort-Object {
        try {
          [version]$_.Name
        }
        catch {
          [version]'0.0'
        }
      } -Descending
  )

  $runningOnWindows = (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  )
  $fileName = if ($runningOnWindows) { "$ToolName.bat" } else { $ToolName }
  foreach ($directory in $directories) {
    $candidate = Join-Path $directory.FullName $fileName
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }

  throw "Android build tool was not found: $ToolName"
}

function Get-ApkAnalyzer {
  param([Parameter(Mandatory)][string]$AndroidSdkRoot)

  $command = Get-Command apkanalyzer -ErrorAction SilentlyContinue
  if ($null -ne $command) {
    return $command.Source
  }

  $runningOnWindows = (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  )
  $fileName = if ($runningOnWindows) {
    'apkanalyzer.bat'
  }
  else {
    'apkanalyzer'
  }
  $candidate = Get-ChildItem `
    -LiteralPath (Join-Path $AndroidSdkRoot 'cmdline-tools') `
    -Recurse `
    -Filter $fileName `
    -File `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($null -eq $candidate) {
    throw 'Android apkanalyzer was not found.'
  }
  $candidate.FullName
}

function Get-CertificateSha256 {
  param([Parameter(Mandatory)][object[]]$Output)

  $matches = @(
    $Output |
      Where-Object { $_.ToString() -notmatch 'public key' } |
      Select-String -Pattern 'SHA-?256(?: digest)?:\s*([0-9A-Fa-f:]{64,95})' |
      ForEach-Object {
        $_.Matches[0].Groups[1].Value.Replace(':', '').ToUpperInvariant()
      } |
      Sort-Object -Unique
  )

  if ($matches.Count -ne 1) {
    throw "Expected one SHA-256 certificate digest; found $($matches.Count)."
  }
  $matches[0]
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$policyPath = Join-Path $root 'release/production-release-policy.json'
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
$productionCertificateSha256 = (
  [string]$policy.signing.certificateSha256
).ToUpperInvariant()
if ($productionCertificateSha256 -notmatch '^[0-9A-F]{64}$') {
  throw 'Production signing policy has an invalid certificate SHA-256.'
}

$signingVariables = @(
  'CRM_ANDROID_RELEASE_STORE_FILE',
  'CRM_ANDROID_RELEASE_STORE_PASSWORD',
  'CRM_ANDROID_RELEASE_KEY_ALIAS',
  'CRM_ANDROID_RELEASE_KEY_PASSWORD'
)
foreach ($name in $signingVariables) {
  if (-not [string]::IsNullOrWhiteSpace(
      [Environment]::GetEnvironmentVariable($name))) {
    throw "CI packaging proof refuses pre-existing signing input: $name"
  }
}

$flutter = Get-CommandPath -Name 'flutter'
$keytool = Get-CommandPath -Name 'keytool'
$jarsigner = Get-CommandPath -Name 'jarsigner'
$androidSdkRoot = Get-AndroidSdkRoot
$apksigner = Get-LatestBuildTool `
  -AndroidSdkRoot $androidSdkRoot `
  -ToolName 'apksigner'
$apkanalyzer = Get-ApkAnalyzer -AndroidSdkRoot $androidSdkRoot

$temporaryStore = Join-Path (
  [IO.Path]::GetTempPath()
) "crm3-ci-package-proof-$([guid]::NewGuid().ToString('N')).p12"
$temporaryPassword = [Convert]::ToHexString(
  [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
)
$temporaryAlias = 'crm3-ci-package-proof'
$env:CRM_CI_PACKAGE_STORE_PASSWORD = $temporaryPassword

try {
  Invoke-Checked `
    -FilePath $keytool `
    -ArgumentList @(
      '-genkeypair',
      '-noprompt',
      '-storetype', 'PKCS12',
      '-keystore', $temporaryStore,
      '-storepass:env', 'CRM_CI_PACKAGE_STORE_PASSWORD',
      '-alias', $temporaryAlias,
      '-keyalg', 'RSA',
      '-keysize', '3072',
      '-sigalg', 'SHA256withRSA',
      '-validity', '2',
      '-dname', 'CN=CRM3 CI Package Proof,OU=Non-Production,O=CRM3,C=IN'
    ) `
    -FailureMessage 'Unable to create the ephemeral CI signing identity.'

  $keyOutput = @(
    Invoke-Captured `
      -FilePath $keytool `
      -ArgumentList @(
        '-list',
        '-v',
        '-storetype', 'PKCS12',
        '-keystore', $temporaryStore,
        '-storepass:env', 'CRM_CI_PACKAGE_STORE_PASSWORD',
        '-alias', $temporaryAlias
      ) `
      -FailureMessage 'Unable to inspect the ephemeral CI signing identity.'
  )
  $ciCertificateSha256 = Get-CertificateSha256 -Output $keyOutput
  if ($ciCertificateSha256 -eq $productionCertificateSha256) {
    throw 'Ephemeral CI signer unexpectedly matches the production certificate.'
  }

  $env:CRM_ANDROID_RELEASE_STORE_FILE = $temporaryStore
  $env:CRM_ANDROID_RELEASE_STORE_PASSWORD = $temporaryPassword
  $env:CRM_ANDROID_RELEASE_KEY_ALIAS = $temporaryAlias
  $env:CRM_ANDROID_RELEASE_KEY_PASSWORD = $temporaryPassword

  Push-Location $root
  try {
    Invoke-Checked `
      -FilePath $flutter `
      -ArgumentList @('pub', 'get') `
      -FailureMessage 'Flutter dependency restoration failed.'
    Invoke-Checked `
      -FilePath $flutter `
      -ArgumentList @(
        'build',
        'apk',
        '--release',
        "--build-name=$BuildName",
        "--build-number=$BuildNumber"
      ) `
      -FailureMessage 'Release APK packaging failed.'
    Invoke-Checked `
      -FilePath $flutter `
      -ArgumentList @(
        'build',
        'appbundle',
        '--release',
        "--build-name=$BuildName",
        "--build-number=$BuildNumber"
      ) `
      -FailureMessage 'Release AAB packaging failed.'
  }
  finally {
    Pop-Location
  }

  $apkPath = Join-Path $root 'build/app/outputs/flutter-apk/app-release.apk'
  $aabPath = Join-Path $root 'build/app/outputs/bundle/release/app-release.aab'
  foreach ($path in @($apkPath, $aabPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Expected Android package was not created: $path"
    }
    if ((Get-Item -LiteralPath $path).Length -le 0) {
      throw "Android package is empty: $path"
    }
  }

  $apkSignerOutput = @(
    Invoke-Captured `
      -FilePath $apksigner `
      -ArgumentList @('verify', '--verbose', '--print-certs', $apkPath) `
      -FailureMessage 'APK signature verification failed.'
  )
  $apkCertificateSha256 = Get-CertificateSha256 -Output $apkSignerOutput
  if ($apkCertificateSha256 -ne $ciCertificateSha256) {
    throw 'APK signer does not match the ephemeral CI certificate.'
  }

  $null = @(
    Invoke-Captured `
      -FilePath $jarsigner `
      -ArgumentList @(
      '-verify',
      '-strict',
      '-keystore', $temporaryStore,
      '-storetype', 'PKCS12',
      '-storepass', $temporaryPassword,
      $aabPath
      ) `
      -FailureMessage 'AAB signature verification failed.'
  )
  $aabCertificateOutput = @(
    Invoke-Captured `
      -FilePath $keytool `
      -ArgumentList @('-printcert', '-jarfile', $aabPath) `
      -FailureMessage 'Unable to inspect the AAB signer certificate.'
  )
  $aabCertificateSha256 = Get-CertificateSha256 `
    -Output $aabCertificateOutput
  if ($aabCertificateSha256 -ne $ciCertificateSha256) {
    throw 'AAB signer does not match the ephemeral CI certificate.'
  }

  $applicationIdOutput = @(
    Invoke-Captured `
      -FilePath $apkanalyzer `
      -ArgumentList @('manifest', 'application-id', $apkPath) `
      -FailureMessage 'Unable to read the APK application ID.'
  )
  $applicationId = $applicationIdOutput[-1].ToString().Trim()
  if ($applicationId -ne [string]$policy.permanentApplicationId) {
    throw "APK application ID mismatch: $applicationId"
  }

  $debuggableOutput = @(
    Invoke-Captured `
      -FilePath $apkanalyzer `
      -ArgumentList @('manifest', 'debuggable', $apkPath) `
      -FailureMessage 'Unable to read the APK debuggable flag.'
  )
  $debuggable = $debuggableOutput[-1].ToString().Trim().ToLowerInvariant()
  if ($debuggable -ne 'false') {
    throw "Release APK must be non-debuggable; observed: $debuggable"
  }

  $apkSha256 = (
    Get-FileHash -LiteralPath $apkPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()
  $aabSha256 = (
    Get-FileHash -LiteralPath $aabPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()

  Write-Output 'PASS_C03_ANDROID_RELEASE_PACKAGING_PROOF'
  Write-Output "applicationId=$applicationId"
  Write-Output "buildName=$BuildName"
  Write-Output "buildNumber=$BuildNumber"
  Write-Output "apkSha256=$apkSha256"
  Write-Output "aabSha256=$aabSha256"
  Write-Output "ciCertificateSha256=$ciCertificateSha256"
  Write-Output 'productionCertificateUsed=false'
  Write-Output 'productionSecretsReferenced=false'
  Write-Output 'artifactUploadPerformed=false'
}
finally {
  foreach ($name in $signingVariables) {
    [Environment]::SetEnvironmentVariable($name, $null)
  }
  $env:CRM_CI_PACKAGE_STORE_PASSWORD = $null
  $temporaryPassword = $null
  Remove-Item -LiteralPath $temporaryStore -Force -ErrorAction SilentlyContinue
}
