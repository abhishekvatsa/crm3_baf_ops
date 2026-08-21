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

function New-CryptographicPassword {
  [byte[]]$bytes = New-Object byte[] 24
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $generator.GetBytes($bytes)
  }
  finally {
    $generator.Dispose()
  }

  -join ($bytes | ForEach-Object { $_.ToString('X2') })
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

function Get-ApkStringResource {
  param(
    [Parameter(Mandatory)][string]$ApkAnalyzer,
    [Parameter(Mandatory)][string]$ApkPath,
    [Parameter(Mandatory)][string]$Name
  )

  $output = @(
    Invoke-Captured `
      -FilePath $ApkAnalyzer `
      -ArgumentList @(
        'resources',
        'value',
        '--type', 'string',
        '--config', 'default',
        '--name', $Name,
        $ApkPath
      ) `
      -FailureMessage "Release APK is missing string resource: $Name"
  )
  if ($output.Count -ne 1) {
    throw "Release APK returned an ambiguous string resource: $Name"
  }
  $output[0].ToString().Trim().Trim('"')
}

function Get-AndroidManifestMetaDataValue {
  param(
    [Parameter(Mandatory)][xml]$Manifest,
    [Parameter(Mandatory)][string]$Name
  )

  $androidNamespace = 'http://schemas.android.com/apk/res/android'
  $namespaceManager = [Xml.XmlNamespaceManager]::new($Manifest.NameTable)
  $namespaceManager.AddNamespace('android', $androidNamespace)
  $node = $Manifest.SelectSingleNode(
    "/manifest/application/meta-data[@android:name='$Name']",
    $namespaceManager
  )
  if ($null -eq $node) {
    throw "Release APK manifest is missing Firebase control: $Name"
  }
  $node.GetAttribute('value', $androidNamespace)
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$policyPath = Join-Path $root 'release/production-release-policy.json'
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
$productionGoogleServicesPath = Join-Path `
  $root `
  'android/app/google-services.json'
$productionGoogleServices = Get-Content `
  -Raw `
  -LiteralPath $productionGoogleServicesPath | ConvertFrom-Json
$productionFirebaseClients = @(
  $productionGoogleServices.client |
    Where-Object {
      [string]$_.client_info.android_client_info.package_name -eq
        [string]$policy.permanentApplicationId
    }
)
if ($productionFirebaseClients.Count -ne 1) {
  throw 'Production Firebase configuration has no singular permanent app client.'
}
$productionFirebaseClient = $productionFirebaseClients[0]
$productionFirebaseAppId = [string]$productionFirebaseClient.client_info.mobilesdk_app_id
$productionFirebaseProjectId = [string]$productionGoogleServices.project_info.project_id
$productionFirebaseSenderId = [string]$productionGoogleServices.project_info.project_number
$productionFirebaseApiKey = [string]$productionFirebaseClient.api_key[0].current_key
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
if (-not [string]::IsNullOrWhiteSpace($env:CRM3_CI_PACKAGE_PROOF)) {
  throw 'CI packaging proof refuses a pre-existing Firebase override.'
}

$ciFirebaseConfigPath = Join-Path `
  $root `
  'android/app/src/release/google-services.json'
if (Test-Path -LiteralPath $ciFirebaseConfigPath) {
  throw "CI Firebase override path already exists: $ciFirebaseConfigPath"
}
$ciFirebaseProjectNumber = '999999999999'
$ciFirebaseProjectId = 'crm3-ci-package-proof-isolated'
$ciFirebaseAppId = '1:999999999999:android:0000000000000000000000'
$ciFirebaseApiKey = 'crm3-ci-package-proof-no-api-access'

$flutter = Get-CommandPath -Name 'flutter'
$keytool = Get-CommandPath -Name 'keytool'
$jarsigner = Get-CommandPath -Name 'jarsigner'
$androidSdkRoot = Get-AndroidSdkRoot
$apksigner = Get-LatestBuildTool `
  -AndroidSdkRoot $androidSdkRoot `
  -ToolName 'apksigner'
$apkanalyzer = Get-ApkAnalyzer -AndroidSdkRoot $androidSdkRoot
$r8MappingPath = Join-Path `
  $root `
  'build/app/outputs/mapping/release/mapping.txt'
$resourceShrinkReportPath = Join-Path `
  $root `
  'build/app/outputs/mapping/release/resources.txt'
foreach ($path in @($r8MappingPath, $resourceShrinkReportPath)) {
  Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}

$temporaryStore = Join-Path (
  [IO.Path]::GetTempPath()
) "crm3-ci-package-proof-$([guid]::NewGuid().ToString('N')).p12"
$temporaryPassword = New-CryptographicPassword
$temporaryAlias = 'crm3-ci-package-proof'
$env:CRM_CI_PACKAGE_STORE_PASSWORD = $temporaryPassword

try {
  $null = New-Item `
    -ItemType Directory `
    -Path (Split-Path -Parent $ciFirebaseConfigPath) `
    -Force
  [ordered]@{
    project_info = [ordered]@{
      project_number = $ciFirebaseProjectNumber
      project_id = $ciFirebaseProjectId
      storage_bucket = "$ciFirebaseProjectId.invalid"
    }
    client = @(
      [ordered]@{
        client_info = [ordered]@{
          mobilesdk_app_id = $ciFirebaseAppId
          android_client_info = [ordered]@{
            package_name = [string]$policy.permanentApplicationId
          }
        }
        oauth_client = @()
        api_key = @(
          [ordered]@{
            current_key = $ciFirebaseApiKey
          }
        )
        services = [ordered]@{
          appinvite_service = [ordered]@{
            other_platform_oauth_client = @()
          }
        }
      }
    )
    configuration_version = '1'
  } | ConvertTo-Json -Depth 10 | Set-Content `
    -LiteralPath $ciFirebaseConfigPath `
    -Encoding utf8
  $env:CRM3_CI_PACKAGE_PROOF = 'true'

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
        '--dart-define=CRM3_CI_PACKAGE_PROOF=true',
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
        '--dart-define=CRM3_CI_PACKAGE_PROOF=true',
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
  foreach ($path in @($r8MappingPath, $resourceShrinkReportPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Expected release-shrinking evidence was not created: $path"
    }
    if ((Get-Item -LiteralPath $path).Length -le 0) {
      throw "Release-shrinking evidence is empty: $path"
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

  $compiledFirebaseAppId = Get-ApkStringResource `
    -ApkAnalyzer $apkanalyzer `
    -ApkPath $apkPath `
    -Name 'google_app_id'
  $compiledFirebaseProjectId = Get-ApkStringResource `
    -ApkAnalyzer $apkanalyzer `
    -ApkPath $apkPath `
    -Name 'project_id'
  $compiledFirebaseSenderId = Get-ApkStringResource `
    -ApkAnalyzer $apkanalyzer `
    -ApkPath $apkPath `
    -Name 'gcm_defaultSenderId'
  $compiledFirebaseApiKey = Get-ApkStringResource `
    -ApkAnalyzer $apkanalyzer `
    -ApkPath $apkPath `
    -Name 'google_api_key'
  if (
    $compiledFirebaseAppId -ne $ciFirebaseAppId -or
    $compiledFirebaseProjectId -ne $ciFirebaseProjectId -or
    $compiledFirebaseSenderId -ne $ciFirebaseProjectNumber -or
    $compiledFirebaseApiKey -ne $ciFirebaseApiKey
  ) {
    throw 'Release APK does not contain the exact isolated Firebase identity.'
  }
  if (
    $compiledFirebaseAppId -eq $productionFirebaseAppId -or
    $compiledFirebaseProjectId -eq $productionFirebaseProjectId -or
    $compiledFirebaseSenderId -eq $productionFirebaseSenderId -or
    $compiledFirebaseApiKey -eq $productionFirebaseApiKey
  ) {
    throw 'Release APK contains production Firebase identity material.'
  }

  $manifestOutput = @(
    Invoke-Captured `
      -FilePath $apkanalyzer `
      -ArgumentList @('manifest', 'print', $apkPath) `
      -FailureMessage 'Unable to read the compiled APK manifest.'
  )
  try {
    [xml]$compiledManifest = $manifestOutput -join "`n"
  }
  catch {
    throw "Compiled APK manifest is not valid XML. $($_.Exception.Message)"
  }
  $firebaseAutomaticCollectionControls = @(
    'firebase_data_collection_default_enabled',
    'firebase_crashlytics_collection_enabled',
    'firebase_messaging_auto_init_enabled',
    'firebase_analytics_collection_enabled'
  )
  foreach ($name in $firebaseAutomaticCollectionControls) {
    $value = Get-AndroidManifestMetaDataValue `
      -Manifest $compiledManifest `
      -Name $name
    if ($value.ToLowerInvariant() -ne 'false') {
      throw "Release APK Firebase control is not disabled: $name=$value"
    }
  }

  $crashlyticsMappingIdOutput = @(
    Invoke-Captured `
      -FilePath $apkanalyzer `
      -ArgumentList @(
        'resources',
        'value',
        '--type', 'string',
        '--config', 'default',
        '--name', 'com.google.firebase.crashlytics.mapping_file_id',
        $apkPath
      ) `
      -FailureMessage 'Release APK is missing Crashlytics mapping identity.'
  )
  if ($crashlyticsMappingIdOutput.Count -ne 1) {
    throw 'Release APK returned an ambiguous Crashlytics mapping identity.'
  }
  $crashlyticsMappingId = $crashlyticsMappingIdOutput[0].ToString().Trim()
  if ($crashlyticsMappingId -notmatch '^[0-9a-fA-F]{32}$') {
    throw 'Release APK has an invalid Crashlytics mapping identity.'
  }

  $apkSha256 = (
    Get-FileHash -LiteralPath $apkPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()
  $aabSha256 = (
    Get-FileHash -LiteralPath $aabPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()
  $r8MappingSha256 = (
    Get-FileHash -LiteralPath $r8MappingPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()
  $resourceShrinkReportSha256 = (
    Get-FileHash -LiteralPath $resourceShrinkReportPath -Algorithm SHA256
  ).Hash.ToUpperInvariant()

  Write-Output 'PASS_C03_ANDROID_RELEASE_PACKAGING_PROOF'
  Write-Output 'PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF'
  Write-Output "applicationId=$applicationId"
  Write-Output "buildName=$BuildName"
  Write-Output "buildNumber=$BuildNumber"
  Write-Output "apkSha256=$apkSha256"
  Write-Output "aabSha256=$aabSha256"
  Write-Output "r8MappingSha256=$r8MappingSha256"
  Write-Output "resourceShrinkReportSha256=$resourceShrinkReportSha256"
  Write-Output 'crashlyticsMappingIdPresent=true'
  Write-Output "ciCertificateSha256=$ciCertificateSha256"
  Write-Output 'productionCertificateUsed=false'
  Write-Output 'productionSecretsReferenced=false'
  Write-Output 'isolatedFirebaseIdentity=true'
  Write-Output 'productionFirebaseIdentityEmbedded=false'
  Write-Output 'firebaseAutomaticCollectionEnabled=false'
  Write-Output 'crashlyticsMappingUploadEnabled=false'
  Write-Output 'firebaseProductionTrafficDisabled=true'
  Write-Output 'artifactUploadPerformed=false'
}
finally {
  foreach ($name in $signingVariables) {
    [Environment]::SetEnvironmentVariable($name, $null)
  }
  $env:CRM3_CI_PACKAGE_PROOF = $null
  $env:CRM_CI_PACKAGE_STORE_PASSWORD = $null
  $temporaryPassword = $null
  Remove-Item -LiteralPath $ciFirebaseConfigPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $temporaryStore -Force -ErrorAction SilentlyContinue
}
