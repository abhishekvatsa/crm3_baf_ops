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

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

$projectId = $env:CRM_DEMO_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = 'demo-crm3-baf-ops' }
$emulatorHost = $env:CRM_EMULATOR_HOST
if ([string]::IsNullOrWhiteSpace($emulatorHost)) { $emulatorHost = '127.0.0.1' }

# A physical device reaches the host machine's emulators through adb reverse.
# The Android emulator can use 10.0.2.2 instead; pass CRM_EMULATOR_HOST for that.
if ($emulatorHost -eq '127.0.0.1') {
  $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
  if (Test-Path $adb) {
    foreach ($port in 8080, 9099, 5001) {
      & $adb reverse "tcp:$port" "tcp:$port" | Out-Null
    }
    Write-Host 'adb reverse configured for 8080/9099/5001' -ForegroundColor DarkGray
  }
}

flutter run `
  --dart-define=CRM_USE_EMULATORS=true `
  --dart-define=CRM_DEMO_PROJECT_ID=$projectId `
  --dart-define=CRM_EMULATOR_HOST=$emulatorHost `
  @args
