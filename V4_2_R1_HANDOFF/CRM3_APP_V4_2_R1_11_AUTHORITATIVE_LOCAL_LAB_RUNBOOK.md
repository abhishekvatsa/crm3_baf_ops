# CRM3 v4.2_R1.11 authoritative local-laboratory runbook

## Scope

R1.11 retains the R1.10 application tree and corrects locale-dependent Python audit tooling. The laboratory remains read-only with respect to the original repository, Git remotes and Firebase, and it does not uninstall or clear a device.

## Governing source

- canonical main commit: `633c58bb0d936011e391b42627f8b8f02c510e95`
- canonical main tree: `2f547a79e79076c70dd15ae8b85a7ad70c9fa018`
- initial trial policy: fresh installation / clean local development database

## Expected progression

R1.10 proved stages 01–21. R1.11 must independently rerun those stages and then prove:

- v4.1 audit under Windows locale conditions;
- whole-app, inherited and structural audits;
- Functions tests;
- `flutter analyze`;
- Flutter tests;
- Android debug APK construction and identity;
- Firestore/Functions emulator campaign when requested.

No later outcome is presumed.

## Invocation

Extract the candidate and invoke `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1` with the canonical current-app root and `-RunEmulators`.

Evidence output begins with:

`CRM3_V42_R1_11_CANONICAL_LOCAL_LAB_`

Upload the resulting ZIP and `.sha256.txt` sidecar together.
