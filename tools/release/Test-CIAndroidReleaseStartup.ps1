[CmdletBinding()]
param(
  [Parameter()]
  [string]$DeviceId = 'emulator-5554',

  [Parameter()]
  [string]$ApkPath = 'build/app/outputs/flutter-apk/app-release.apk',

  [Parameter()]
  [string]$ApplicationId = 'in.co.sail.bsl.crm3.bafops'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
$adbCandidates = @(
  $(if ($null -ne $adbCommand) { $adbCommand.Source }),
  $(if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    Join-Path $env:ANDROID_HOME 'platform-tools/adb'
  }),
  $(if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
    Join-Path $env:ANDROID_SDK_ROOT 'platform-tools/adb'
  }),
  $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    Join-Path $HOME 'AppData/Local/Android/Sdk/platform-tools/adb.exe'
  })
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$adb = $adbCandidates |
  Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
  Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($adb)) {
  throw 'Android Debug Bridge is unavailable.'
}

function Invoke-AdbCaptured {
  param(
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [Parameter(Mandatory)][string]$FailureMessage
  )

  $output = @(& $adb -s $DeviceId @ArgumentList 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "$FailureMessage Exit code: $LASTEXITCODE.`n$($output -join "`n")"
  }
  $output
}

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
$devices = @(& $adb devices)
if (
  $LASTEXITCODE -ne 0 -or
  -not ($devices -match "^$([regex]::Escape($DeviceId))\s+device$")
) {
  throw "Android startup-proof device is unavailable: $DeviceId"
}

$null = Invoke-AdbCaptured `
  -ArgumentList @('install', '-r', $resolvedApk) `
  -FailureMessage 'Release APK installation failed.'
$null = Invoke-AdbCaptured `
  -ArgumentList @('logcat', '-c') `
  -FailureMessage 'Unable to clear the isolated emulator log buffer.'
$null = Invoke-AdbCaptured `
  -ArgumentList @(
    'shell',
    'pm',
    'grant',
    $ApplicationId,
    'android.permission.POST_NOTIFICATIONS'
  ) `
  -FailureMessage 'Unable to grant notification permission on the isolated emulator.'
$null = Invoke-AdbCaptured `
  -ArgumentList @('shell', 'am', 'force-stop', $ApplicationId) `
  -FailureMessage 'Unable to stop the isolated release process.'
$launchOutput = @(
  Invoke-AdbCaptured `
    -ArgumentList @(
      'shell',
      'am',
      'start',
      '-W',
      '-n',
      "$ApplicationId/.MainActivity"
    ) `
    -FailureMessage 'Release APK cold launch failed.'
)
if (-not ($launchOutput -match '^Status:\s+ok$')) {
  throw "Release APK did not report a successful cold launch.`n$($launchOutput -join "`n")"
}

Start-Sleep -Seconds 8
$pidOutput = @(& $adb -s $DeviceId shell pidof $ApplicationId 2>&1)
$pidExitCode = $LASTEXITCODE
$appProcessIds = ($pidOutput -join '').Trim()
if (
  $pidExitCode -ne 0 -or
  $appProcessIds -notmatch '^\d+(?:\s+\d+)*$'
) {
  throw 'Release process is not alive after cold launch.'
}

$exitInfo = @(
  Invoke-AdbCaptured `
    -ArgumentList @('shell', 'dumpsys', 'activity', 'exit-info', $ApplicationId) `
    -FailureMessage 'Unable to query Android process-exit evidence.'
)
if ($exitInfo -match 'reason=4 \(APP CRASH\(EXCEPTION\)\)') {
  throw "Android recorded a release startup crash.`n$($exitInfo -join "`n")"
}

$crashBuffer = @(
  Invoke-AdbCaptured `
    -ArgumentList @('logcat', '-b', 'crash', '-d', '-v', 'brief') `
    -FailureMessage 'Unable to query the Android crash buffer.'
)
if ($crashBuffer -match [regex]::Escape($ApplicationId)) {
  throw "Release package appears in the Android crash buffer.`n$($crashBuffer -join "`n")"
}

Write-Output 'PASS_C03_ANDROID_RELEASE_COLD_START_PROOF'
Write-Output "applicationId=$ApplicationId"
Write-Output "deviceId=$DeviceId"
Write-Output 'processAlive=true'
Write-Output 'startupCrashRecorded=false'
