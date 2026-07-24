# v4.2_R1.6 Authoritative Local Laboratory Runbook

## Purpose

This laboratory proves the canonical-main-reconciled successor source without changing the real repository, any Firebase backend, or an existing app installation.

R1.6 preserves the R1.4 product and dependency tree and corrects only the PowerShell parser used by the Firebase CLI lock-policy gate. The lockfile is parsed with `ConvertFrom-Json -AsHashTable`, because npm lockfile v2/v3 contains the required empty-string root package key. Before the CLI can be used, the harness proves:

- `firebase-tools` is exactly `15.22.4`;
- `@hono/node-server` is exactly `1.19.14`;
- `fast-uri` is exactly `3.1.4`;
- the lockfile uses only the expected public npm artifacts and integrity hashes;
- the installed versions match the lock policy;
- the Firebase CLI dependency audit passes at `--audit-level=low`.

The script also:

- verifies the pristine package and disposable copy;
- exact-hash binds the two Firebase build inputs from canonical main;
- enforces Flutter, Dart, Node, npm and Java versions;
- proves all lockfiles stable;
- runs the early Functions TypeScript compiler gate proven in R1.3;
- runs authentic Isar generation and inherited-ID continuity checks;
- runs source audits, Functions tests, Flutter analysis/tests and debug APK build;
- optionally runs Rules/Functions emulator gates;
- optionally installs only where the package is absent;
- seals an evidence ZIP for both PASS and HOLD outcomes.

It does not push, merge, tag, deploy, write production data, uninstall an app, or clear device data.

## Required inputs

- extracted v4.2_R1.6 candidate;
- clean canonical repository at `C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops` containing the canonical Firebase inputs;
- Flutter `3.44.0`, Dart `3.12.0`, Node `22.15.0`, npm `10.9.2`, Java `21.0.11`.

Firebase build-input hashes remain:

- `firebase_options.dart`: `07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE`;
- `google-services.json`: `DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D`.

## Complete run

```powershell
Set-Location "$HOME\Downloads"

$Zip = Get-ChildItem "$HOME\Downloads" -File |
  Where-Object Name -Like `
    "CRM3_APP_V4_2_R1_5_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $Zip) {
    throw "v4.2_R1.6 candidate ZIP not found."
}

$CandidateRoot = `
  "$HOME\Downloads\CRM3_APP_V4_2_R1_5_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE"

Remove-Item $CandidateRoot -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $Zip.FullName -DestinationPath $CandidateRoot -Force

$Candidate = Get-ChildItem $CandidateRoot -Directory |
  Select-Object -First 1

$Script = Get-ChildItem $Candidate.FullName -Recurse -File `
  -Filter "Invoke-Crm3V42R1CanonicalLocalLab.ps1" |
  Select-Object -First 1

if (-not $Script) {
    throw "R1.6 local-laboratory script not found."
}

& $Script.FullName `
  -CandidatePath $Candidate.FullName `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -EvidenceRoot "$HOME\Downloads" `
  -RunEmulators `
  -EmulatorPort 8180
```

Use a free emulator port if `8180` is occupied.

## Important HOLD outcomes

- `HOLD_FIREBASE_CLI_LOCK_POLICY`: declared or locked tooling versions/artifacts are not exact.
- `HOLD_FIREBASE_CLI_DEPENDENCY_VERSION`: `npm ci` installed a version other than the governed versions.
- `HOLD_FIREBASE_CLI_DEPENDENCY_AUDIT`: the strict Firebase CLI audit still reports a known advisory.
- `HOLD_FUNCTIONS_TYPECHECK`: the early real Functions compiler gate failed.

No HOLD can be promoted to an authoritative PASS by skipping the affected gate.

## Authoritative outcomes

- `PASS_AUTHORITATIVE_BUILD_ONLY`
- `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`
- `PASS_AUTHORITATIVE_FRESH_INSTALL`

A diagnostic run, skipped Flutter tests, or toolchain mismatch cannot produce an authoritative PASS.

## Evidence to upload

The run writes:

- `CRM3_V42_R1_5_CANONICAL_LOCAL_LAB_<timestamp>.zip`
- its `.sha256.txt` sidecar.

Upload both files.


## R1.6 parallel-verdict rule

The Firebase CLI dependency audit remains mandatory for an authoritative PASS. Its advisory result is recorded as a nonblocking HOLD so that local Flutter, Isar, Functions, APK and emulator evidence can still be collected. If that audit is not clean, the final status remains `HOLD_FIREBASE_CLI_DEPENDENCY_AUDIT` even when downstream execution succeeds. This continuation never authorizes deployment or production mutation.


## R1.9 custody-regression correction

R1.9 restores the exact ten-path Flutter platform-registrant classification that was present in R1.7 but accidentally omitted while R1.8 introduced the semantic Isar-continuity verifier. The registrants remain visible in the post-codegen delta as `flutter-platform-registrant-added`; no broad directory or wildcard exclusion is used. The R1.8 semantic continuity gate remains unchanged.
