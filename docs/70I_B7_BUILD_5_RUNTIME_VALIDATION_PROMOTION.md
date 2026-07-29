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

It has six explicit phases:

1. `Preflight` verifies source, artifact, signer, AVD and Google Play Services
   without mutation.
2. `Install` requires clean merged `main`, an empty evidence directory and an
   explicit debug-replacement switch.
3. `FinalizeInstall` resumes only the interrupted first run whose exact
   prior-promotion hash, debug signer and installed Build 5 hash are preserved.
   It denies the Android 16 notification prompt and does not reinstall.
4. `PrepareSignIn` treats any restored approved session as gate evidence only,
   uses the app's own `Sign Out` control, and proves return to the Google
   sign-in screen without clearing app data or reinstalling.
5. `DiagnoseProfile` is available only after a fresh Google exchange reaches
   Firebase Authentication but own-user hydration fails. It retains only Auth
   verification flags, a Firebase uid hash, own-document field names/types,
   invariant booleans, and active Rules/App Check posture. It reads no other
   user document and performs no remote write.
6. `Verify` runs after fresh Google Sign-In and proves the approved-user home gate
   through stable UI markers without placing account email or display name in
   repository evidence.

The `FinalizeInstall` phase was added after the first governed install reached
the Android notification-permission controller after successful package
replacement. The original promotion hash is retained in the amended authority
and the interrupted evidence; target and distribution scope did not expand.

The first recovery then exposed a restored approved-user session. That state
proves package execution and the approval gate, but it is not accepted as a
fresh production-certificate OAuth exchange. The promotion therefore requires
an explicit in-app sign-out and a new Google Sign-In before P-01 adjudication.

That fresh exchange succeeded at Google and Firebase Authentication, then
returned `cloud_firestore/permission-denied` while hydrating the selected
identity's own user profile. App Check enforcement was read back as
`UNENFORCED`; the deployed Rules release differs from repository `main`.
Neither fact alone identifies a safe repair. The read-only diagnostic phase
therefore resolves only the selected chooser account and records privacy-safe
Auth and own-document invariants before any remediation is proposed.

The governed diagnostic proved that the selected Auth user is verified,
enabled and Google-linked, and that its own approved user document is complete,
canonical and email-matched. The unchanged signed-in session reached approved
home immediately after an app relaunch. The source remediation therefore gates
the current-user Firestore listener on `idTokenChanges()` and permits exactly
one same-uid `permission-denied` retry after a forced token refresh.

Build 5 remains the immutable runtime-validation artifact and does not contain
that source remediation. It proves the production OAuth and approved-user
authority path, with the first-listener race and relaunch recorded explicitly.
Any future pilot artifact must be built from source containing the remediation.

P-01 and STAGE2D-F3 may be adjudicated only from the resulting SHA-sealed
execution evidence. This source promotion alone closes neither record.
