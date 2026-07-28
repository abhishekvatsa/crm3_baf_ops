<#
  release_gate.ps1 — CRM-III BAF Ops repeatable local release gate
  ----------------------------------------------------------------
  Runs source-level gates and stops at the first failure.

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

function Run-Gate {
  param([string]$Name, [scriptblock]$Action)
  $script:step++
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host "[$script:step] $Name" -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor Cyan
  $global:LASTEXITCODE = 0
  & $Action
  $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host ">>> GATE FAILED: $Name (exit $exitCode)" -ForegroundColor Red
    exit $exitCode
  }
  Write-Host ">>> PASS: $Name" -ForegroundColor Green
}

Write-Host "CRM-III BAF Ops — release gate starting at $startedAt" -ForegroundColor Yellow
Write-Host "Evidence directory: $EvidenceDir" -ForegroundColor Yellow

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
  Write-Host ">>> WARN: some files are not dart-formatted (non-blocking; run 'dart format lib test' later)" -ForegroundColor Yellow
} else {
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

Run-Gate "flutter analyze" {
  flutter analyze 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_analyze.log")
}

Run-Gate "flutter test (full suite)" {
  flutter test 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_test_full.log")
}

Run-Gate "no-loss regression spine" {
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
  Run-Gate "firestore rules + governed assignment/closure/population emulator" {
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
  Run-Gate "functions build + test" {
    Push-Location functions
    try {
      npm run build 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "functions_build.log")
      if ($LASTEXITCODE -ne 0) { return }
      npm test 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "functions_test.log")
    } finally {
      Pop-Location
    }
  }
}

if (-not $SkipBuild) {
  Run-Gate "flutter build apk --release" {
    flutter build apk --release 2>&1 | Tee-Object -FilePath (Join-Path $EvidenceDir "flutter_build_apk_release.log")
  }

  $apk = "build\app\outputs\flutter-apk\app-release.apk"
  if (Test-Path $apk) {
    $hash = (Get-FileHash $apk -Algorithm SHA256).Hash
    $line = "$((Get-Date).ToString('o'))  app-release.apk  $hash"
    Write-Host "Release APK SHA-256: $hash"
    $line | Out-File -Append -FilePath (Join-Path $EvidenceDir "release_gate_artifacts.log")
  }
}

git status --short --untracked-files=all | Tee-Object -FilePath (Join-Path $EvidenceDir "git_status_end.log")

$elapsed = (Get-Date) - $startedAt
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "ALL SOURCE GATES GREEN  ($([int]$elapsed.TotalSeconds)s)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Evidence directory: $EvidenceDir" -ForegroundColor Green
Write-Host ""
Write-Host "Source gate is NOT the whole release. Field gates remain manual:" -ForegroundColor Yellow
Write-Host "  [ ] Install app-release.apk on a physical Android device; smoke role/sync/closure/diagnostics"
Write-Host "  [ ] Airplane-mode: create/edit a job offline, reconnect, confirm sync + diagnostics"
Write-Host "  [ ] Rehearse rollback + local recovery; document the steps"
Write-Host "  [ ] Dependency/security review (npm + pub); record exceptions"
