# CRM3 v4.2 — Tomorrow Local Trial Runbook

## Purpose

This trial validates the **new v4.2 successor architecture** on a local Windows checkout and, optionally, on one controlled test device. The old app is used only as the source of governed Firebase inputs and as an upgrade/data-continuity baseline. The trial does not restore old architectural authority or remove v4 functionality.

## Absolute boundaries

- **NO FIREBASE DEPLOYMENT**
- **NO PRODUCTION DATA MUTATION**
- **NO GIT REMOTE MUTATION**
- **NO PILOT OR FIELD DISTRIBUTION**
- **NO APP UNINSTALL OR DATA CLEARING**

The script contains no command that performs those actions.

## What this trial attempts

1. Verify the candidate’s internal SHA-256 manifest.
2. Restore separately governed Firebase configuration files.
3. Verify project, package, Firebase app ID and `google-services.json` SHA-256.
4. Verify the pinned Flutter 3.44.0 / Dart 3.12.0 toolchain.
5. Clean-install and audit the root, Functions and governed Firebase CLI npm trees.
6. Run authentic Isar `build_runner` generation.
7. Require the Isar release verifier to pass with no provisional markers.
8. Run v4.2, v4.1, v4 and inherited source audits.
9. Run Functions compilation and all non-emulator tests.
10. Run `flutter analyze`, the full Flutter suite and a debug APK build.
11. Optionally run the governed Firestore emulator suites.
12. Optionally install the APK as an in-place upgrade on one backed-up test device.
13. Produce a timestamped evidence folder and APK hash.

## Prerequisites

Use a Windows workstation with:

- Flutter 3.44.0
- Dart 3.12.0
- Java 21
- Node 22 and npm 10
- Python 3
- network access for package restoration if caches are incomplete
- Android SDK and `adb` only when testing a device

Prepare either:

- the current app root containing `lib/firebase_options.dart` and `android/app/google-services.json`; or
- those two files as separate explicit paths.

The governed `google-services.json` must have one of the two exact raw hashes
for the same semantic configuration:

```text
Repository UTF-8 LF:             6CBC8F2E9D021999433636E9AD517EEC461C9811A19DC7DAA28EEE7C28D750C7
Restoration artifact UTF-8 CRLF: 2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B
```

## Recommended first run: build and tests only

From PowerShell:

```powershell
Set-Location "$HOME\Downloads\CRM3_APP_V4_2_ULTIMATE_LOCAL_TRIAL_CANDIDATE"

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42LocalTrial.ps1" `
  -CurrentAppRoot "C:\path\to\current\crm3_baf_ops"
```

Do not use `-AllowToolchainMismatch` for evidence intended to support migration authority.

## Optional emulator run

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42LocalTrial.ps1" `
  -CurrentAppRoot "C:\path\to\current\crm3_baf_ops" `
  -RunEmulators `
  -EmulatorPort 8187
```

Use `-EmulatorPort` when port 8080 is occupied. The emulator path is local-only. Confirm that no production credentials or service-account environment variables are injected into the shell.

## Optional test-device upgrade

Before this step:

1. Use a non-production or explicitly approved test device.
2. Record the currently installed package/version.
3. Back up any evidence or data that can be backed up.
4. Do not uninstall the current package.
5. Do not clear application data.

Then run:

```powershell
adb devices

pwsh -NoProfile -ExecutionPolicy Bypass -File `
  ".\tools\v4\Invoke-Crm3V42LocalTrial.ps1" `
  -CurrentAppRoot "C:\path\to\current\crm3_baf_ops" `
  -InstallOnDevice `
  -DeviceId "<adb-device-id>"
```

The script uses an in-place debug APK installation. A successful install is not migration acceptance; open the app and carry out the manual matrix below.

## Manual device matrix after successful installation

Record evidence for:

- app startup without local database loss;
- login and approved-user role loading;
- existing charges, abnormalities, directives and maintenance records;
- planned-job and module visibility;
- workflow hub, lane and compliance views;
- deferred ticket → condition confirmation → reactivation;
- equipment-state projection;
- notification navigation from foreground, background and terminated state;
- weak network and reconnection;
- duplicate command taps and receipt/idempotency behaviour;
- process kill and restart;
- test-user role revocation;
- no malformed projection silently appearing as asset 0, epoch time or empty authority state.

Do not use production data to create artificial workflow events during this first local trial.

## Expected stopping conditions

Stop and preserve the evidence folder when any of these occurs:

- Firebase identity/hash mismatch;
- Flutter/Dart version mismatch;
- authentic code generation fails;
- any provisional Isar marker remains;
- source audit failure;
- npm advisory reappears;
- Functions or Flutter test failure;
- analysis/build failure;
- upgrade installation proposes uninstall/data clearing;
- existing data is missing or structurally altered.

Do not “work around” a failed gate by deleting data, weakening Rules, removing v4 fields or reverting to an old authority path.

## Evidence location

By default, evidence is written inside:

```text
local_trial_evidence/V4_2_LOCAL_TRIAL_<timestamp>/
```

The key file is `trial-result.json`. It records each step, result, logs, toolchain and APK SHA-256, and explicitly states that no remote/backend/production mutation was performed.
