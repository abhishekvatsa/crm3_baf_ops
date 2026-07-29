# Build 5 Runtime Validation Promotion

Date: 2026-07-29

## Decision

Build 5 is promoted only into a one-emulator internal validation channel. This
is the `internal-release-signed-apk` planning mode already admitted by the
Stage 2D-F deployment scope.

The promotion permits:

- exact Build 5 APK verification;
- secure removal of the inventoried debuggable versionCode 1 app sandbox from
  the named `Pixel_9` AVD;
- direct ADB installation of the production-signed versionCode 5 APK;
- Google Sign-In using the existing owner-controlled emulator account;
- own-user profile hydration and privacy-minimized runtime evidence.

The promotion does not permit pilot handout, physical-device installation,
Firebase App Distribution, Play Console, public links, backend deployment,
roster changes, or distribution to a second target.

## Authority

The machine-readable authority is:

`release/approvals/build-5-runtime-validation-promotion.json`

It becomes effective only after owner-reviewed merge to `main`. Device mutation
must then be executed from an exact clean local `main` equal to `origin/main`.

The artifact remains:

- package: `in.co.sail.bsl.crm3.bafops`
- version: `1.0.0-rc.1+5`
- APK SHA-256:
  `1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C`
- certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`

## Execution

The governed harness is:

`tools/release/Invoke-Build5RuntimeValidation.ps1`

It has three explicit phases:

1. `Preflight` verifies source, artifact, signer, AVD and Google Play Services
   without mutation.
2. `Install` requires clean merged `main`, an empty evidence directory and an
   explicit debug-replacement switch.
3. `Verify` runs after Google Sign-In and proves the approved-user home gate
   through stable UI markers without placing account email or display name in
   repository evidence.

P-01 and STAGE2D-F3 may be adjudicated only from the resulting SHA-sealed
execution evidence. This source promotion alone closes neither record.
