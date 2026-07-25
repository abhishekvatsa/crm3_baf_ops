# v4.2_R1.8 Authoritative Local Laboratory Runbook

## Purpose

This laboratory proves the canonical-main-reconciled successor source without changing the real repository, any Firebase backend, or an existing app installation.

R1.8 retains the R1.7 product, Functions, Rules, Isar models, Android and dependency trees. The executable correction is limited to the Isar continuity verifier: inherited collection identity, property names/types and index definitions remain fail-closed, while generator-local property-position changes are recorded rather than misclassified as data-contract failures.

The R1.6 Windows evidence already proves:

- pristine and disposable-workspace custody through dependency installation;
- root, Functions and Firebase CLI dependency audits at zero known vulnerabilities;
- Functions TypeScript compilation;
- Firebase CLI lock policy, installed-version checks and CLI load smoke;
- `flutter pub get` on Flutter `3.44.0` / Dart `3.12.0`;
- authentic Isar `build_runner` generation.

R1.8 reruns every gate from the beginning and then continues through semantic Isar continuity, source audits, Functions tests, Flutter analysis/tests, APK construction and optionally the emulator suite.

It does not push, merge, tag, deploy, write production data, uninstall an app, or clear device data.

## Required inputs

- extracted v4.2_R1.8 candidate;
- clean canonical repository at `C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops`, containing the governed Firebase inputs;
- Flutter `3.44.0`, Dart `3.12.0`, Node `22.15.0`, npm `10.9.2`, Java `21.0.11`.

Firebase build-input hashes remain:

- `firebase_options.dart`: `07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE`;
- `google-services.json`: `DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D`.

## Complete run

```powershell
Set-Location "$HOME\Downloads"

$Sidecar = Get-ChildItem "$HOME\Downloads" -File |
  Where-Object Name -Like `
    "CRM3_APP_V4_2_R1_8_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE*.zip.sha256.txt" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $Sidecar) {
    throw "R1.8 SHA-256 sidecar not found."
}

$ExpectedSha = ((Get-Content -LiteralPath $Sidecar.FullName -Raw).Trim() -split '\s+')[0].ToUpperInvariant()

$Zip = Get-ChildItem "$HOME\Downloads" -File |
  Where-Object Name -Like `
    "CRM3_APP_V4_2_R1_8_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if (-not $Zip) {
    throw "v4.2_R1.8 candidate ZIP not found."
}

$ActualSha = (Get-FileHash -LiteralPath $Zip.FullName -Algorithm SHA256).Hash
if ($ActualSha -ne $ExpectedSha) {
    throw "Candidate SHA-256 mismatch. Expected $ExpectedSha; got $ActualSha"
}

$CandidateRoot = "$HOME\Downloads\CRM3_APP_V4_2_R1_8_CANONICAL_MAIN_LOCAL_LAB_CANDIDATE"
Remove-Item $CandidateRoot -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $Zip.FullName -DestinationPath $CandidateRoot -Force

$Candidate = Get-ChildItem $CandidateRoot -Directory | Select-Object -First 1
$Script = Get-ChildItem $Candidate.FullName -Recurse -File `
  -Filter "Invoke-Crm3V42R1CanonicalLocalLab.ps1" |
  Select-Object -First 1

if (-not $Script) {
    throw "R1.8 laboratory script was not found."
}

& $Script.FullName `
  -CandidatePath $Candidate.FullName `
  -CurrentAppRoot "C:\Users\abhis\AndroidStudioProjects\crm3_baf_ops" `
  -EvidenceRoot "$HOME\Downloads" `
  -RunEmulators `
  -EmulatorPort 8180
```

The sidecar supplies the exact final ZIP hash without creating a self-referential package hash.

## Expected evidence

The evidence archive is named approximately:

```text
CRM3_V42_R1_8_CANONICAL_LOCAL_LAB_<timestamp>.zip
```

Upload it with its `.zip.sha256.txt` sidecar.

## Interpretation

- `PASS_AUTHORITATIVE_BUILD_ONLY`: all authoritative local build gates passed; emulators were not requested.
- `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`: local build and requested emulator gates passed.
- `PASS_AUTHORITATIVE_FRESH_INSTALL`: build, emulators where requested, and a clean-device install passed.
- `HOLD_*`: evidence was sealed, but one or more mandatory gates remain unresolved.
- `FAIL_LOCAL_LAB`: an unclassified execution defect stopped the run.

Generated Flutter plugin registrants remain explicitly classified. Stage 18 now writes `isar-semantic-continuity.json`; any inherited property-position changes remain visible, while missing names, type changes, collection-ID drift and inherited-index drift still fail closed.
