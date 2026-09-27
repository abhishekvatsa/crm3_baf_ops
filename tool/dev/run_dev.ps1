# Runs the real CRM-III application against the local emulator suite.
#
# This is the ordinary app: same screens, repositories, Isar schemas and
# synchronization code as production. Only the backend endpoints and the
# installed application id differ.
#
# It installs as in.co.sail.bsl.crm3.bafops.dev and therefore cannot overwrite
# or require uninstalling the signed production app or its local records.
#
# Start tool/dev/emulators.ps1 in another terminal first.

param(
  [string]$DeviceId,
  [switch]$Test,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

# The development application id is opt-in, so ordinary debug builds - including
# CI's app-shell integration and the CodeQL isolated Android compilation - keep
# the production id and the Firebase configuration they already rely on.
$env:CRM3_DEV_APP = 'true'

$projectId = $env:CRM_DEMO_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = 'demo-crm3-baf-ops' }
if ($projectId -notmatch '^demo-[a-z0-9][a-z0-9-]*$') {
  throw 'CRM_DEMO_PROJECT_ID must be a demo project id.'
}
$emulatorHost = $env:CRM_EMULATOR_HOST
if ([string]::IsNullOrWhiteSpace($emulatorHost)) { $emulatorHost = '127.0.0.1' }
if ($emulatorHost -notin @('127.0.0.1', 'localhost', '10.0.2.2')) {
  throw 'Development endpoints must use localhost, 127.0.0.1 or Android emulator host 10.0.2.2.'
}
if ($FlutterArgs | Where-Object { $_ -match '^--(release|profile)$|^--dart-define' }) {
  throw 'Use the documented CRM_* environment settings; release/profile and custom Dart defines are not accepted by this DEV launcher.'
}

# Refresh the demo config even if an older or CI-specific override exists.
& (Join-Path $PSScriptRoot 'setup_dev.ps1')

$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) { throw "Android platform tools not found: $adb" }
$devices = @(& $adb devices | ForEach-Object {
  if ($_ -match '^(\S+)\s+device$') { $Matches[1] }
})
if ($LASTEXITCODE -ne 0) { throw 'Could not read connected Android devices.' }
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  if ($devices.Count -ne 1) { throw 'Specify -DeviceId when there is not exactly one ready Android device.' }
  $DeviceId = $devices[0]
}
if ($DeviceId -notin $devices) { throw 'The selected device is not connected and authorized.' }

# A physical device reaches the host machine's emulators through adb reverse.
# The Android emulator can use 10.0.2.2 instead; pass CRM_EMULATOR_HOST for that.
if ($emulatorHost -in @('127.0.0.1', 'localhost')) {
    foreach ($port in 8080, 9099, 5001) {
      & $adb -s $DeviceId reverse "tcp:$port" "tcp:$port" | Out-Null
      if ($LASTEXITCODE -ne 0) { throw "Could not forward emulator port $port to the selected device." }
    }
    Write-Host 'adb reverse configured for 8080/9099/5001' -ForegroundColor DarkGray
}

$verb = if ($Test) { 'test' } else { 'run' }
$testOptions = @(if ($Test) { '--no-uninstall' })
$identityDefines = @(foreach ($setting in 'CRM_DEV_EMAIL', 'CRM_DEV_SECRET', 'CRM_DEV_DISPLAY_NAME') {
  $value = [Environment]::GetEnvironmentVariable($setting)
  if (-not [string]::IsNullOrWhiteSpace($value)) { "--dart-define=$setting=$value" }
})
flutter $verb -d $DeviceId `
  @testOptions `
  --dart-define=CRM_USE_EMULATORS=true `
  --dart-define=CRM_DEMO_PROJECT_ID=$projectId `
  --dart-define=CRM_EMULATOR_HOST=$emulatorHost `
  @identityDefines `
  @FlutterArgs
if ($LASTEXITCODE -ne 0) { throw "Flutter $verb failed with code $LASTEXITCODE." }
