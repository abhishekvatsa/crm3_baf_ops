# Starts the Firebase emulator suite for the CRM-III DEV loop.
#
# Run this in its own terminal and leave it running, then start the app with
# tool/dev/run_dev.ps1 in a second terminal.
#
# The project id must begin with "demo-": the emulator suite accepts any id,
# but a demo id cannot resolve to a real Firebase project, so a call that is
# somehow not routed to an emulator fails instead of reaching production.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

$projectId = $env:CRM_DEMO_PROJECT_ID
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = 'demo-crm3-baf-ops' }
if (-not $projectId.StartsWith('demo-')) {
  throw "CRM_DEMO_PROJECT_ID must start with 'demo-'. Received: $projectId"
}

$firebase = 'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
if (-not (Test-Path $firebase)) {
  throw "Governed Firebase CLI not installed. Run: npm --prefix tooling/firebase-cli ci --ignore-scripts"
}

Write-Host "Starting Auth + Firestore + Functions emulators for $projectId" -ForegroundColor Cyan
Write-Host "Emulator UI: http://127.0.0.1:4000" -ForegroundColor Cyan

node $firebase emulators:start --only auth,firestore,functions --project $projectId
