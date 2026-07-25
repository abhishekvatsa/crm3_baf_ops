[CmdletBinding()]
param(
  [string]$CandidatePath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
  [string]$CurrentAppRoot,
  [string]$FirebaseOptionsPath,
  [string]$GoogleServicesPath,
  [string]$EvidenceRoot,
  [switch]$RunEmulators,
  [ValidateRange(1024, 65535)][int]$EmulatorPort = 8080,
  [switch]$InstallOnDevice,
  [string]$DeviceId,
  [switch]$AllowToolchainMismatch,
  [switch]$SkipFlutterTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$expectedProjectId = 'crm3-baf-ops-b8638'
$expectedPackage = 'in.co.sail.bsl.crm3.bafops'
$expectedFirebaseAppId = '1:894346496105:android:fba14febfbbee102e63af8'
$expectedGoogleServicesSha256 = '2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B'
$expectedFlutter = '3.44.0'
$expectedDart = '3.12.0'

$CandidatePath = (Resolve-Path $CandidatePath).Path
if (-not $EvidenceRoot) {
  $EvidenceRoot = Join-Path $CandidatePath 'local_trial_evidence'
}
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$evidenceDir = Join-Path $EvidenceRoot "V4_2_LOCAL_TRIAL_$runStamp"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$transcript = Join-Path $evidenceDir 'trial-transcript.txt'
Start-Transcript -Path $transcript -Force | Out-Null

$steps = [System.Collections.Generic.List[object]]::new()
$startedAt = (Get-Date).ToUniversalTime().ToString('o')

function Add-StepResult {
  param([string]$Name, [string]$Status, [string]$Log, [string]$Detail = '')
  $steps.Add([ordered]@{ name = $Name; status = $Status; log = $Log; detail = $Detail })
}

function Invoke-CheckedStep {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action,
    [string]$WorkingDirectory = $CandidatePath
  )
  $safeName = ($Name -replace '[^A-Za-z0-9_.-]', '_')
  $log = Join-Path $evidenceDir "$safeName.log"
  Write-Host "`n===== $Name =====" -ForegroundColor Cyan
  Push-Location $WorkingDirectory
  try {
    $global:LASTEXITCODE = 0
    & $Action 2>&1 | Tee-Object -FilePath $log
    $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int]$global:LASTEXITCODE }
    if ($exitCode -ne 0) {
      Add-StepResult -Name $Name -Status 'FAIL' -Log $log -Detail "exitCode=$exitCode"
      throw "$Name failed with exit code $exitCode"
    }
    Add-StepResult -Name $Name -Status 'PASS' -Log $log
  }
  catch {
    if (-not ($steps | Where-Object { $_.name -eq $Name -and $_.status -eq 'FAIL' })) {
      Add-StepResult -Name $Name -Status 'FAIL' -Log $log -Detail $_.Exception.Message
    }
    throw
  }
  finally {
    Pop-Location
  }
}

function Assert-Command {
  param([Parameter(Mandatory)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Get-Sha256 {
  param([Parameter(Mandatory)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-GeneratedBindingInventory {
  param([Parameter(Mandatory)][string]$OutputPath)
  $items = Get-ChildItem -LiteralPath (Join-Path $CandidatePath 'lib') -Recurse -File -Filter '*.g.dart' |
    Sort-Object FullName |
    ForEach-Object {
      [ordered]@{
        path = [IO.Path]::GetRelativePath($CandidatePath, $_.FullName).Replace('\','/')
        sha256 = Get-Sha256 $_.FullName
        provisional = (Select-String -LiteralPath $_.FullName -Pattern 'PROVISIONAL_V4_ISAR_CODEGEN' -Quiet)
      }
    }
  $items | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

try {
  Write-Host 'CRM3 v4.2 governed local trial' -ForegroundColor Green
  Write-Host "Candidate: $CandidatePath"
  Write-Host "Evidence:  $evidenceDir"
  Write-Host 'Scope: local source/build/test only; no remote repository or production backend action is performed.'

  foreach ($required in @(
    'firebase.json',
    'firestore.rules',
    'governance/v4_successor_programme_authority_v1.json',
    'release/production-release-policy.json',
    'tools/v4/v4_2_ultimate_audit.py'
  )) {
    if (-not (Test-Path -LiteralPath (Join-Path $CandidatePath $required) -PathType Leaf)) {
      throw "Candidate is incomplete; missing $required"
    }
  }

  Assert-Command 'node'
  Assert-Command 'npm'
  Assert-Command 'flutter'
  Assert-Command 'dart'

  $pythonCommand = Get-Command 'python' -ErrorAction SilentlyContinue
  $pythonPrefix = @()
  if (-not $pythonCommand) {
    $pythonCommand = Get-Command 'py' -ErrorAction SilentlyContinue
    $pythonPrefix = @('-3')
  }
  if (-not $pythonCommand) { throw 'Python 3 is required.' }
  $pythonExe = $pythonCommand.Source

  $manifestPath = Join-Path $CandidatePath 'V4_2_HANDOFF/FILE_SHA256SUMS.txt'
  if (Test-Path -LiteralPath $manifestPath) {
    Invoke-CheckedStep -Name '01_candidate_manifest' -Action {
      & $pythonExe @pythonPrefix 'tools/v4/verify_file_manifest.py' '--manifest' 'V4_2_HANDOFF/FILE_SHA256SUMS.txt' '--root' '.'
    }
  }

  if (-not $FirebaseOptionsPath -and $CurrentAppRoot) {
    $FirebaseOptionsPath = Join-Path $CurrentAppRoot 'lib/firebase_options.dart'
  }
  if (-not $GoogleServicesPath -and $CurrentAppRoot) {
    $GoogleServicesPath = Join-Path $CurrentAppRoot 'android/app/google-services.json'
  }
  if (-not $FirebaseOptionsPath -or -not (Test-Path -LiteralPath $FirebaseOptionsPath -PathType Leaf)) {
    throw 'Provide -FirebaseOptionsPath or -CurrentAppRoot containing lib/firebase_options.dart.'
  }
  if (-not $GoogleServicesPath -or -not (Test-Path -LiteralPath $GoogleServicesPath -PathType Leaf)) {
    throw 'Provide -GoogleServicesPath or -CurrentAppRoot containing android/app/google-services.json.'
  }
  $FirebaseOptionsPath = (Resolve-Path $FirebaseOptionsPath).Path
  $GoogleServicesPath = (Resolve-Path $GoogleServicesPath).Path

  $firebaseOptionsText = Get-Content -LiteralPath $FirebaseOptionsPath -Raw
  if ($firebaseOptionsText -notmatch [regex]::Escape($expectedProjectId) -or
      $firebaseOptionsText -notmatch [regex]::Escape($expectedFirebaseAppId)) {
    throw 'firebase_options.dart does not match the governed Firebase project/app identity.'
  }
  $googleServices = Get-Content -LiteralPath $GoogleServicesPath -Raw | ConvertFrom-Json
  if ([string]$googleServices.project_info.project_id -ne $expectedProjectId) {
    throw 'google-services.json project_id does not match the governed project.'
  }
  $matchingClient = @($googleServices.client | Where-Object {
    $_.client_info.android_client_info.package_name -eq $expectedPackage -and
    $_.client_info.mobilesdk_app_id -eq $expectedFirebaseAppId
  })
  if ($matchingClient.Count -ne 1) {
    throw 'google-services.json does not contain exactly one governed package/app registration.'
  }
  $googleSha = Get-Sha256 $GoogleServicesPath
  if ($googleSha -ne $expectedGoogleServicesSha256) {
    throw "google-services.json SHA-256 mismatch. Expected $expectedGoogleServicesSha256; got $googleSha"
  }

  $targetFirebaseOptions = Join-Path $CandidatePath 'lib/firebase_options.dart'
  $targetGoogleServices = Join-Path $CandidatePath 'android/app/google-services.json'
  foreach ($pair in @(
    @($FirebaseOptionsPath, $targetFirebaseOptions),
    @($GoogleServicesPath, $targetGoogleServices)
  )) {
    $source = $pair[0]; $target = $pair[1]
    if (Test-Path -LiteralPath $target) {
      $backupName = ([IO.Path]::GetFileName($target)) + '.before-trial'
      Copy-Item -LiteralPath $target -Destination (Join-Path $evidenceDir $backupName) -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
  }
  [ordered]@{
    projectId = $expectedProjectId
    packageName = $expectedPackage
    firebaseAppId = $expectedFirebaseAppId
    firebaseOptionsSha256 = Get-Sha256 $targetFirebaseOptions
    googleServicesSha256 = Get-Sha256 $targetGoogleServices
  } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidenceDir 'firebase-identity.json') -Encoding UTF8

  $flutterMachineText = (& flutter --version --machine 2>&1) -join "`n"
  $flutterMachineText | Set-Content -LiteralPath (Join-Path $evidenceDir 'flutter-version-machine.json') -Encoding UTF8
  $flutterInfo = $flutterMachineText | ConvertFrom-Json
  $actualFlutter = [string]$flutterInfo.frameworkVersion
  $actualDart = ([string]$flutterInfo.dartSdkVersion -split '\s+')[0]
  if (-not $AllowToolchainMismatch -and ($actualFlutter -ne $expectedFlutter -or $actualDart -ne $expectedDart)) {
    throw "Pinned toolchain mismatch. Expected Flutter $expectedFlutter / Dart $expectedDart; got Flutter $actualFlutter / Dart $actualDart."
  }

  Write-GeneratedBindingInventory -OutputPath (Join-Path $evidenceDir 'generated-bindings-before.json')

  Invoke-CheckedStep -Name '02_root_npm_clean_install' -Action { npm ci --ignore-scripts }
  Invoke-CheckedStep -Name '03_root_npm_audit' -Action { npm audit --audit-level=low }
  Invoke-CheckedStep -Name '04_functions_npm_clean_install' -WorkingDirectory (Join-Path $CandidatePath 'functions') -Action { npm ci --ignore-scripts }
  Invoke-CheckedStep -Name '05_functions_npm_audit' -WorkingDirectory (Join-Path $CandidatePath 'functions') -Action { npm audit --audit-level=low }
  Invoke-CheckedStep -Name '06_firebase_cli_clean_install' -WorkingDirectory (Join-Path $CandidatePath 'tooling/firebase-cli') -Action { npm ci --ignore-scripts }
  Invoke-CheckedStep -Name '07_firebase_cli_npm_audit' -WorkingDirectory (Join-Path $CandidatePath 'tooling/firebase-cli') -Action { npm audit --audit-level=low }

  Invoke-CheckedStep -Name '08_flutter_pub_get' -Action { flutter pub get }
  Invoke-CheckedStep -Name '09_authentic_isar_codegen' -Action { dart run build_runner build --delete-conflicting-outputs }
  Write-GeneratedBindingInventory -OutputPath (Join-Path $evidenceDir 'generated-bindings-after.json')

  Invoke-CheckedStep -Name '10_v42_ultimate_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/v4_2_ultimate_audit.py' }
  Invoke-CheckedStep -Name '11_v41_due_diligence_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/v4_1_due_diligence_audit.py' }
  Invoke-CheckedStep -Name '12_v4_whole_app_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/whole_app_reconciliation_audit.py' }
  Invoke-CheckedStep -Name '13_inherited_full_tree_audit' -Action { & $pythonExe @pythonPrefix 'tools/maintenance_workflow/full_tree_source_audit.py' }
  Invoke-CheckedStep -Name '14_inherited_expanded_audit' -Action { & $pythonExe @pythonPrefix 'tools/expanded_audit/expanded_implementation_audit.py' }
  Invoke-CheckedStep -Name '15_dart_structural_audit' -Action { & $pythonExe @pythonPrefix 'tools/v4/dart_structural_audit.py' }
  Invoke-CheckedStep -Name '16_policy_generation_check' -Action { npm run workflow:policy:check }
  Invoke-CheckedStep -Name '17_isar_source_verification' -Action { & $pythonExe @pythonPrefix 'tools/isar/verify_v4_isar_schema.py' }
  Invoke-CheckedStep -Name '18_isar_release_authority' -Action { & $pythonExe @pythonPrefix 'tools/isar/verify_v4_isar_schema.py' '--release' }

  Invoke-CheckedStep -Name '19_functions_build_and_tests' -WorkingDirectory (Join-Path $CandidatePath 'functions') -Action { npm test }
  Invoke-CheckedStep -Name '20_flutter_analyze' -Action { flutter analyze }
  if (-not $SkipFlutterTests) {
    Invoke-CheckedStep -Name '21_flutter_full_test_suite' -Action { flutter test }
  }
  Invoke-CheckedStep -Name '22_android_debug_apk' -Action { flutter build apk --debug }

  if ($RunEmulators) {
    $emulatorConfig = Join-Path $CandidatePath ".firebase.v42.local.$runStamp.json"
    $emulatorJson = Get-Content -LiteralPath (Join-Path $CandidatePath 'firebase.json') -Raw | ConvertFrom-Json
    $emulatorJson.emulators.firestore | Add-Member -NotePropertyName host -NotePropertyValue '127.0.0.1' -Force
    $emulatorJson.emulators.firestore.port = $EmulatorPort
    $emulatorJson.emulators.ui.enabled = $false
    $emulatorJson | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $emulatorConfig -Encoding UTF8
    try {
      $firebaseCli = Join-Path $CandidatePath 'tooling/firebase-cli/node_modules/firebase-tools/lib/bin/firebase.js'
      Invoke-CheckedStep -Name '23_governed_emulator_suites' -Action {
        node $firebaseCli emulators:exec --config $emulatorConfig --only firestore `
          "npm run test:rules && npm --prefix functions run test:emulator:governed"
      }
    }
    finally {
      Remove-Item -LiteralPath $emulatorConfig -Force -ErrorAction SilentlyContinue
    }
  }

  $apkPath = Join-Path $CandidatePath 'build/app/outputs/flutter-apk/app-debug.apk'
  if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "Debug APK not found after build: $apkPath"
  }
  $apkSha = Get-Sha256 $apkPath
  [ordered]@{ path = $apkPath; sha256 = $apkSha; sizeBytes = (Get-Item $apkPath).Length } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidenceDir 'debug-apk.json') -Encoding UTF8

  if ($InstallOnDevice) {
    Assert-Command 'adb'
    if (-not $DeviceId) {
      $devices = @(& adb devices | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '^([^\s]+)\s+device$') { $matches[1] }
      })
      if ($devices.Count -ne 1) {
        throw 'Specify -DeviceId unless exactly one authorised device is connected.'
      }
      $DeviceId = $devices[0]
    }
    Invoke-CheckedStep -Name '24_test_device_upgrade_install' -Action { adb -s $DeviceId install -r -t $apkPath }
    & adb -s $DeviceId shell dumpsys package $expectedPackage 2>&1 |
      Set-Content -LiteralPath (Join-Path $evidenceDir 'device-package-dump.txt') -Encoding UTF8
  }

  $result = [ordered]@{
    candidate = $CandidatePath
    startedAt = $startedAt
    completedAt = (Get-Date).ToUniversalTime().ToString('o')
    status = 'PASS_LOCAL_TRIAL'
    remoteMutationPerformed = $false
    backendDeploymentPerformed = $false
    productionDataMutationPerformed = $false
    flutterVersion = $actualFlutter
    dartVersion = $actualDart
    apkSha256 = $apkSha
    deviceId = if ($InstallOnDevice) { $DeviceId } else { $null }
    steps = $steps
  }
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'trial-result.json') -Encoding UTF8
  Write-Host "`nPASS: v4.2 local trial completed. Evidence: $evidenceDir" -ForegroundColor Green
}
catch {
  $failure = [ordered]@{
    candidate = $CandidatePath
    startedAt = $startedAt
    failedAt = (Get-Date).ToUniversalTime().ToString('o')
    status = 'FAIL_LOCAL_TRIAL'
    error = $_.Exception.Message
    remoteMutationPerformed = $false
    backendDeploymentPerformed = $false
    productionDataMutationPerformed = $false
    steps = $steps
  }
  $failure | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'trial-result.json') -Encoding UTF8
  Write-Error "v4.2 local trial failed: $($_.Exception.Message). Evidence: $evidenceDir"
  exit 1
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}
