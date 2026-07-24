# CRM3 App v4.2_R1.14 — Authoritative Local-Laboratory Runbook

## Purpose

R1.14 is the bounded correction for the authenticated R1.13 emulator failure. It:

- routes expensive Firestore lifecycle checks through one selected transition;
- preserves full approved-user document-shape validation;
- persists `isOpenForWork` in every direct online job-module lifecycle transition;
- corrects Rules fixtures to represent the persisted field;
- captures the Firebase CLI load-smoke output in its individual evidence log.

The required next run is the emulator-enabled authoritative tier. Do not add clean-device installation yet.

## Expected candidate ZIP

`CRM3_APP_V4_2_R1_14_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip`

Verify its SHA-256 against the supplied sidecar before extraction.

## Authoritative command

```powershell
Set-Location "$HOME\Downloads"

Get-FileHash `
  ".\CRM3_APP_V4_2_R1_14_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip" `
  -Algorithm SHA256

Remove-Item `
  ".\CRM3_APP_V4_2_R1_14_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE" `
  -Recurse -Force `
  -ErrorAction SilentlyContinue

Expand-Archive `
  -LiteralPath ".\CRM3_APP_V4_2_R1_14_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip" `
  -DestinationPath "." `
  -Force

Set-Location `
  ".\CRM3_APP_V4_2_R1_14_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE"

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42R1CanonicalLocalLab.ps1" `
  -CandidatePath (Get-Location).Path `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -Mode Authoritative `
  -RunEmulators
```

Use `-EmulatorPort <free-port>` only if the default port is occupied.

## Required successful tier

The expected authoritative result is:

`PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`

A `PASS_AUTHORITATIVE_BUILD_ONLY` result is insufficient because it does not rerun the failed Rules and governed Functions emulator gates. `PASS_AUTHORITATIVE_FRESH_INSTALL` is not required at this stage.

## Evidence expected

The harness writes:

- `CRM3_V42_R1_14_CANONICAL_LOCAL_LAB_<timestamp>.zip`;
- the matching `.sha256.txt` sidecar.

Upload both. The evidence must contain an individual `13_firebase_cli_load_smoke.log`, a passing Rules result, a passing governed Functions emulator result, and `trial-result.json` with `emulatorPassed: true`.

## Mutation boundary

This run must not perform a Git push/merge/tag, Firebase deployment, production-data write, app uninstall or device-data clear.
