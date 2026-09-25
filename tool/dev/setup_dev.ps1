# Writes the local development Firebase override.
#
# This file is intentionally NOT committed. The CodeQL workflow's
# tools/security/codeql/prepare_android.py writes its own isolated override to
# the same path inside the runner and refuses to replace an existing one, so a
# committed copy would break that job.
#
# Run once after cloning, and again if you ever delete the file.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

$projectId = $env:CRM_DEMO_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = 'demo-crm3-baf-ops' }
if (-not $projectId.StartsWith('demo-')) {
  throw "CRM_DEMO_PROJECT_ID must start with 'demo-'. Received: $projectId"
}

$target = 'android/app/src/debug/google-services.json'
New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null

$config = [ordered]@{
  project_info = [ordered]@{
    project_number = '000000000000'
    project_id     = $projectId
    storage_bucket = "$projectId.appspot.com"
  }
  # Both ids are listed so a debug build works whether or not CRM3_DEV_APP is
  # set. Without it the application id has no .dev suffix, and a file naming
  # only the suffixed package would fail the Google Services plugin.
  client = @(
    'in.co.sail.bsl.crm3.bafops.dev',
    'in.co.sail.bsl.crm3.bafops'
  ) | ForEach-Object {
    [ordered]@{
      client_info = [ordered]@{
        mobilesdk_app_id    = '1:000000000000:android:0000000000000000000000'
        android_client_info = [ordered]@{ package_name = $_ }
      }
      oauth_client = @()
      api_key      = @(@{ current_key = 'emulator-only-not-a-real-key' })
      services     = [ordered]@{
        appinvite_service = [ordered]@{ other_platform_oauth_client = @() }
      }
    }
  }
  configuration_version = '1'
}

$json = $config | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText((Resolve-Path .).Path + '\' + ($target -replace '/', '\'), $json, [Text.UTF8Encoding]::new($false))
Write-Host "Wrote $target for $projectId" -ForegroundColor Green
