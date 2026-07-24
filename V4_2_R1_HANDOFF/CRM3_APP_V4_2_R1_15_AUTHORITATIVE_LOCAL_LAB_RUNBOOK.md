# CRM3 App v4.2_R1.15 — Authoritative Local-Laboratory Runbook

## Purpose

R1.15 is the bounded test-contract correction for the authenticated R1.14 build failure. It preserves the R1.14 application and Firestore Rules and aligns one stale Flutter structural assertion with the single maintenance transition router.

The required next run remains the emulator-enabled authoritative tier. Do not add clean-device installation yet.

## Expected candidate ZIP

`CRM3_APP_V4_2_R1_15_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip`

Verify its SHA-256 against the supplied sidecar before extraction.

## Authoritative command

```powershell
Set-Location "$HOME\Downloads"

Get-FileHash `
  ".\CRM3_APP_V4_2_R1_15_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip" `
  -Algorithm SHA256

Remove-Item `
  ".\CRM3_APP_V4_2_R1_15_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE" `
  -Recurse -Force `
  -ErrorAction SilentlyContinue

Expand-Archive `
  -LiteralPath ".\CRM3_APP_V4_2_R1_15_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE.zip" `
  -DestinationPath "." `
  -Force

Set-Location `
  ".\CRM3_APP_V4_2_R1_15_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE"

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42R1CanonicalLocalLab.ps1" `
  -CandidatePath (Get-Location).Path `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -Mode Authoritative `
  -RunEmulators
```

Use `-EmulatorPort <free-port>` only when the default port is occupied.

## Required successful tier

The required result is:

`PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`

A build-only result is insufficient because the R1.13 Rules failure still requires a fresh proof against the unchanged R1.14 Rules correction. Fresh-install authority is not required yet.

## Evidence expected

The harness writes:

- `CRM3_V42_R1_15_CANONICAL_LOCAL_LAB_<timestamp>.zip`;
- the matching SHA-256 sidecar.

Upload both. The evidence must show the complete Flutter suite passing, the Rules suite passing, the governed Functions emulator suites passing, and `trial-result.json` with `emulatorPassed: true`.

## Mutation boundary

This run must not perform a Git push, merge or tag; Firebase deployment; production-data write; app uninstall; or device-data clear.
