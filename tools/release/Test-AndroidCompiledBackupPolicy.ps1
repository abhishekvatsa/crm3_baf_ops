#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ApkPath,
  [string]$ApkAnalyzerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-ApkAnalyzer {
  $names = if ($IsWindows) {
    @('apkanalyzer.bat', 'apkanalyzer')
  } else {
    @('apkanalyzer', 'apkanalyzer.bat')
  }
  $roots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
  if ($IsWindows -and $env:LOCALAPPDATA) {
    $roots += Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }
  foreach ($root in ($roots | Where-Object { $_ } | Select-Object -Unique)) {
    $commandRoot = Join-Path $root 'cmdline-tools'
    if (-not (Test-Path -LiteralPath $commandRoot -PathType Container)) {
      continue
    }
    foreach ($name in $names) {
      $candidate = Get-ChildItem -LiteralPath $commandRoot -Recurse -File `
        -Filter $name -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
      if ($candidate) {
        return $candidate.FullName
      }
    }
  }
  foreach ($name in $names) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
      return $command.Source
    }
  }
  throw 'Android apkanalyzer was not found.'
}

function Invoke-ApkAnalyzer {
  param([Parameter(Mandatory)][string[]]$Arguments)

  $output = @(& $script:Analyzer @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "apkanalyzer failed: $($output -join "`n")"
  }
  $output
}

function Get-ApplicationAttribute {
  param(
    [Parameter(Mandatory)][xml]$Manifest,
    [Parameter(Mandatory)][string]$Name
  )

  $androidNamespace = 'http://schemas.android.com/apk/res/android'
  $application = $Manifest.SelectSingleNode('/manifest/application')
  if ($null -eq $application) {
    throw 'Compiled APK manifest has no application element.'
  }
  $application.GetAttribute($Name, $androidNamespace)
}

function Get-CompiledXmlResource {
  param([Parameter(Mandatory)][string]$Name)

  $value = @(
    Invoke-ApkAnalyzer -Arguments @(
      'resources', 'value',
      '--type', 'xml',
      '--config', 'default',
      '--name', $Name,
      $script:ResolvedApk
    )
  )
  if ($value.Count -ne 1 -or [string]::IsNullOrWhiteSpace($value[0])) {
    throw "Compiled APK has no singular XML resource named $Name."
  }
  $entry = $value[0].ToString().Trim()
  $decoded = @(
    Invoke-ApkAnalyzer -Arguments @(
      'resources', 'xml',
      "--file=$entry",
      $script:ResolvedApk
    )
  )
  try {
    [xml]($decoded -join "`n")
  } catch {
    throw "Compiled XML resource is invalid: $Name. $($_.Exception.Message)"
  }
}

function Assert-Exclusions {
  param(
    [Parameter(Mandatory)][xml]$Document,
    [Parameter(Mandatory)][string]$ParentXPath,
    [Parameter(Mandatory)][string]$Label
  )

  $domains = @(
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref'
  )
  foreach ($domain in $domains) {
    $nodes = @(
      $Document.SelectNodes(
        "$ParentXPath/exclude[@domain='$domain' and @path='.']"
      )
    )
    if ($nodes.Count -ne 1) {
      throw "$Label must exclude the complete $domain domain exactly once."
    }
  }
}

$script:ResolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$script:Analyzer = if ([string]::IsNullOrWhiteSpace($ApkAnalyzerPath)) {
  Find-ApkAnalyzer
} else {
  (Resolve-Path -LiteralPath $ApkAnalyzerPath).Path
}

try {
  [xml]$manifest = (
    Invoke-ApkAnalyzer -Arguments @(
      'manifest', 'print', $script:ResolvedApk
    )
  ) -join "`n"
} catch {
  throw "Compiled APK manifest is invalid. $($_.Exception.Message)"
}

if ((Get-ApplicationAttribute -Manifest $manifest -Name 'allowBackup') -ne
    'false') {
  throw 'Compiled APK must set android:allowBackup=false.'
}
foreach ($attribute in @('fullBackupContent', 'dataExtractionRules')) {
  if ([string]::IsNullOrWhiteSpace(
      (Get-ApplicationAttribute -Manifest $manifest -Name $attribute))) {
    throw "Compiled APK manifest is missing android:$attribute."
  }
}

$legacyRules = Get-CompiledXmlResource -Name 'backup_rules'
$modernRules = Get-CompiledXmlResource -Name 'data_extraction_rules'
Assert-Exclusions `
  -Document $legacyRules `
  -ParentXPath '/full-backup-content' `
  -Label 'Android 11-and-lower backup policy'
Assert-Exclusions `
  -Document $modernRules `
  -ParentXPath '/data-extraction-rules/cloud-backup' `
  -Label 'Android 12+ cloud-backup policy'
Assert-Exclusions `
  -Document $modernRules `
  -ParentXPath '/data-extraction-rules/device-transfer' `
  -Label 'Android 12+ device-transfer policy'

Write-Output 'PASS_ANDROID_COMPILED_BACKUP_POLICY'
Write-Output 'allowBackup=false'
Write-Output 'cloudBackupExcluded=true'
Write-Output 'deviceTransferExcluded=true'
