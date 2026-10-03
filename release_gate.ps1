<#
  release_gate.ps1 — CRM-III BAF Ops repeatable local release gate
  ----------------------------------------------------------------
  Runs source, host-runtime, emulator, and package gates and stops at the
  first failure. Each level remains distinct from physical-device evidence.

  Field gates are intentionally manual and remain outside this script:
    - signed APK install on a physical Android device
    - weak-network/offline smoke
    - rollback/recovery drill
    - dependency/security review

  Usage:
    pwsh ./release_gate.ps1
    pwsh ./release_gate.ps1 -SkipBuild
    pwsh ./release_gate.ps1 -SkipFunctions
    pwsh ./release_gate.ps1 -SkipRules
#>

param(
  [switch]$SkipBuild,
  [switch]$SkipFunctions,
  [switch]$SkipRules,
  [string]$EvidenceRoot = "release_evidence/local_release_gate"
)

$ErrorActionPreference = 'Stop'
$script:step = 0
$startedAt = Get-Date
$stamp = $startedAt.ToString('yyyyMMdd_HHmmss')
$EvidenceDir = [System.IO.Path]::GetFullPath((Join-Path $EvidenceRoot $stamp))
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

. (Join-Path $PSScriptRoot 'tools/testing/local_gate_reporting.ps1')
$script:gateReport = New-LocalGateReport -Names @(
  'checked-in source preflight',
  'dart format (warning-only)',
  'production policy and composite backend authority',
  'test evidence taxonomy and critical-path coverage',
  'Flutter dependency resolution',
  'A03 persistence boundary audit',
  'flutter analyze',
  'flutter host suite (source contracts + unit + widget)',
  'no-loss host regression contracts',
  'Firestore Rules + governed callable emulator',
  'rules expression-limit check (must be ABSENT)',
  'Functions host build + non-emulator tests',
  'Android release APK construction (no install)',
  'Android 16 KB native-library compatibility',
  'Android compiled backup and device-transfer exclusion'
)
$script:gateReportPath = Join-Path $EvidenceDir 'gate-results.json'
if ($SkipRules) {
  Set-LocalGateResult $script:gateReport 'Firestore Rules + governed callable emulator' skipped '-SkipRules selected'
  Set-LocalGateResult $script:gateReport 'rules expression-limit check (must be ABSENT)' skipped '-SkipRules selected'
}
if ($SkipFunctions) {
  Set-LocalGateResult $script:gateReport 'Functions host build + non-emulator tests' skipped '-SkipFunctions selected'
}
if ($SkipBuild) {
  Set-LocalGateResult $script:gateReport 'Android release APK construction (no install)' skipped '-SkipBuild selected'
  Set-LocalGateResult $script:gateReport 'Android 16 KB native-library compatibility' skipped '-SkipBuild selected'
  Set-LocalGateResult $script:gateReport 'Android compiled backup and device-transfer exclusion' skipped '-SkipBuild selected'
}

function Run-Gate {
  param([string]$Name, [scriptblock]$Action)
  $script:step++
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host "[$script:step] $Name" -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  try {
    & $Action
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  } catch {
    Set-LocalGateResult $script:gateReport $Name failed $_.Exception.Message
    Write-LocalGateReport $script:gateReport $script:gateReportPath
    throw
  }
  if ($exitCode -ne 0) {
    Set-LocalGateResult $script:gateReport $Name failed "exit $exitCode"
    Write-Host ">>> GATE FAILED: $Name (exit $exitCode)" -ForegroundColor Red
    Write-LocalGateReport $script:gateReport $script:gateReportPath
    exit $exitCode
  }
  Set-LocalGateResult $script:gateReport $Name passed
  Write-Host ">>> PASS: $Name" -ForegroundColor Green
}

Write-Host "CRM-III BAF Ops — release gate starting at $startedAt" -ForegroundColor Yellow
Write-Host "Evidence directory: $EvidenceDir" -ForegroundColor Yellow

Run-Gate "checked-in source preflight" {
  python tools/testing/run_source_preflight.py 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "source_preflight.log")
}

# Record tool identity.
flutter --version | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_version.log")
dart --version 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "dart_version.log")
git status --short --untracked-files=all | Tee-Object -FilePath (Join-Path $EvidenceDir "git_status_start.log")
git log -1 --oneline | Tee-Object -FilePath (Join-Path $EvidenceDir "git_head.log")

# 1. Formatting is warning-only for now, matching current project policy.
$script:step++
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[$script:step] dart format (WARN-ONLY — not blocking)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
dart format lib test --output=none --set-exit-if-changed *> (Join-Path $EvidenceDir "dart_format.log")
if ($LASTEXITCODE -ne 0) {
  Set-LocalGateResult $script:gateReport 'dart format (warning-only)' warning 'Formatting differences are non-blocking'
  Write-Host ">>> WARN: some files are not dart-formatted (non-blocking; run 'dart format lib test' later)" -ForegroundColor Yellow
} else {
  Set-LocalGateResult $script:gateReport 'dart format (warning-only)' passed
  Write-Host ">>> PASS: formatting clean" -ForegroundColor Green
}
$global:LASTEXITCODE = 0

Run-Gate "production policy and composite backend authority" {
  pwsh -NoProfile -ExecutionPolicy Bypass `
    -File tools/release/Test-ProductionReleasePolicy.ps1 `
    -PolicyPath release/production-release-policy.json `
    -AuthorityPath release/backend-authority.prod.json `
    -RepositoryRoot (Get-Location).Path `
    2>&1 | Tee-Object -FilePath (
      Join-Path $EvidenceDir "production_policy_authority.log"
    )
}

Run-Gate "test evidence taxonomy and critical-path coverage" {
  python tools/testing/verify_test_evidence_taxonomy.py `
    2>&1 | Tee-Object -FilePath (
      Join-Path $EvidenceDir "test_evidence_taxonomy.log"
    )
}

Run-Gate "Flutter dependency resolution" {
  flutter pub get 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_pub_get.log")
}

Run-Gate "A03 persistence boundary audit" {
  dart run tools/v4/a03_persistence_boundary_inventory.dart `
    2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "a03_persistence_boundary.log")
}

Run-Gate "flutter analyze" {
  flutter analyze 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_analyze.log")
}

Run-Gate "flutter host suite (source contracts + unit + widget)" {
  flutter test 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_test_full.log")
}

Run-Gate "no-loss host regression contracts" {
  flutter test `
    test/issue_1_tombstone_conflict_regression_test.dart `
    test/sync_remote_freshness_policy_test.dart `
    test/sync_coordinator_queue_contract_test.dart `
    test/planned_job_closure_guard_test.dart `
    test/planned_job_closure_attestation_test.dart `
    test/job_module_lifecycle_replay_contract_test.dart `
    test/maintenance_lifecycle_replay_contract_test.dart `
    test/release_startup_hygiene_contract_test.dart `
    test/firestore_deployment_readiness_contract_test.dart `
    test/runtime_module_population_fence_contract_test.dart `
    test/runtime_module_population_no_loss_test.dart `
    test/runtime_job_module_population_exception_test.dart `
    test/job_module_population_replay_equivalence_test.dart `
    test/release_gate_action_pin_contract_test.dart `
    2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_test_no_loss_spine.log")
}

if (-not $SkipRules) {
  Run-Gate "Firestore Rules + governed callable emulator" {
    if (Test-Path ".\firestore-debug.log") { Remove-Item ".\firestore-debug.log" -Force }
    npm run emulator:test:governed 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "release_gate_governed_firestore.log")
  }

  Run-Gate "rules expression-limit check (must be ABSENT)" {
    if (Test-Path ".\firestore-debug.log") {
      Copy-Item ".\firestore-debug.log" (Join-Path $EvidenceDir "firestore-debug.log") -Force
      $hit = Select-String -Path ".\firestore-debug.log" -Pattern "maximum of 1000 expressions"
      if ($hit) {
        Write-Host "FOUND expression-limit warning in firestore-debug.log:" -ForegroundColor Red
        $hit | Tee-Object -FilePath (Join-Path $EvidenceDir "expression_limit_hit.log")
        $global:LASTEXITCODE = 1
      } else {
        Write-Host "Clean: no 'maximum of 1000 expressions' warning." -ForegroundColor Green
        $global:LASTEXITCODE = 0
      }
    } else {
      Write-Host "firestore-debug.log not found; expression-limit gate is inconclusive." -ForegroundColor Red
      $global:LASTEXITCODE = 1
    }
  }
}

if (-not $SkipFunctions) {
  Run-Gate "Functions host build + non-emulator tests" {
    Push-Location functions
    try {
      npm run build 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "functions_build.log")
      if ($LASTEXITCODE -ne 0) { return }
      npm test 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "functions_test.log")
    } finally {
      Pop-Location
    }
    if ($LASTEXITCODE -ne 0) { return }
    $business31Tests = @(
      Get-ChildItem -Path "tools/release" -Filter "business31*.test.cjs" -File |
        Sort-Object Name
    )
    if ($business31Tests.Count -eq 0) {
      throw "Build31 business-source test discovery found no suites."
    }
    $privateBundleTest = Get-Item -LiteralPath "tools/release/privateEvidenceBundle31.test.cjs"
    $business31TestPaths = @($business31Tests.FullName) + @($privateBundleTest.FullName)
    node --test --test-concurrency=2 @business31TestPaths 2>&1 |
      Tee-Object -FilePath (Join-Path $EvidenceDir "business31_source_custody_test.log")
  }
}

if (-not $SkipBuild) {
  $apk = "build\app\outputs\flutter-apk\app-release.apk"
  Run-Gate "Android release APK construction (no install)" {
    flutter build apk --release 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_build_apk_release.log")
    if ($LASTEXITCODE -ne 0) { return }
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) {
      throw "Android release APK was not produced at $apk."
    }
  }

  Run-Gate "Android 16 KB native-library compatibility" {
    python tools/release/verify_android_16kb_alignment.py `
      --apk $apk `
      --json-output (Join-Path $EvidenceDir "android_16kb_alignment.json") `
      2>&1 | Tee-Object -FilePath (
        Join-Path $EvidenceDir "android_16kb_alignment.log"
      )
  }

  Run-Gate "Android compiled backup and device-transfer exclusion" {
    pwsh -NoProfile -ExecutionPolicy Bypass `
      -File tools/release/Test-AndroidCompiledBackupPolicy.ps1 `
      -ApkPath $apk `
      2>&1 | Tee-Object -FilePath (
        Join-Path $EvidenceDir "android_compiled_backup_policy.log"
      )
  }

  $hash = (Get-FileHash $apk -Algorithm SHA256).Hash
  $line = "$((Get-Date).ToString('o'))  app-release.apk  $hash"
  Write-Host "Local candidate APK SHA-256 (not signing or distribution proof): $hash"
  $line | Out-File -Append -FilePath (
    Join-Path $EvidenceDir "release_gate_artifacts.log"
  )
}

git status --short --untracked-files=all | Tee-Object -FilePath (Join-Path $EvidenceDir "git_status_end.log")

$elapsed = (Get-Date) - $startedAt
$script:gateReport['elapsedSeconds'] = [int]$elapsed.TotalSeconds
Write-LocalGateReport $script:gateReport $script:gateReportPath
Write-Host "Evidence directory: $EvidenceDir" -ForegroundColor Green
Write-Host ""
Write-Host "Source gate is NOT the whole release. Field gates remain manual:" -ForegroundColor Yellow
Write-Host "  [ ] Install app-release.apk on a physical Android device; smoke role/sync/closure/diagnostics"
Write-Host "  [ ] Airplane-mode: create/edit a job offline, reconnect, confirm sync + diagnostics"
Write-Host "  [ ] Rehearse rollback + local recovery; document the steps"
Write-Host "  [ ] Dependency/security review (npm + pub); record exceptions"
