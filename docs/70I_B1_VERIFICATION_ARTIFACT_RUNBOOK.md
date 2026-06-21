# 70I-B1 Governed Verification Artifact Runbook

## Purpose

This tooling creates an auditable **verification-class** Android APK. It does
not create or authorize a production release.

The artifact remains:

- signed with the Android debug certificate;
- bound to the placeholder Android package identity;
- explicitly marked `not-approved-for-production`.

## Canonical local command

Run from a clean `feat/70i-release-provenance` checkout at an exact commit:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass `
  -File tools/release/New-VerificationArtifact.ps1 `
  -AppVersion '0.70.1-verify.2' `
  -BuildNumber 70102 `
  -ReleaseTag '70i-b1-verification-2' `
  -ReleaseId 'crm3-baf-ops-70i-b1-verify-2' `
  -ExpectedCommit '<40-character-current-commit>' `
  -ReleaseChannel 'verification' `
  -CiRunId 'local-70i-b1'
```

The command runs the repository release gate, the real Firestore-emulator
closure transaction tests, builds the APK, emits a manifest and ledger, and
runs the independent verifier.

## Produced files

- verification debug APK;
- deterministic Git source archive;
- `release-manifest.json`;
- `release-ledger.md`;
- `verification-result.json`;
- `custody-summary.json`;
- build, quality-gate and signing logs.

## Backend binding

The builder validates `release/backend-authority.prod.json` and refuses an
unexpected backend release or any change to the governed Rules, indexes or
Cloud Functions runtime-source files.

The app commit may differ from the backend commit because 70H changed client
code and test evidence only. The reason is recorded in the manifest.

## Deployed indexes

The manifest records deployed-index parity as `not-proven`. Hashing
`firestore.indexes.json` proves source custody only; it is not a readback of
the deployed indexes.

## Production exclusions

70I-B1 does not approve:

- the permanent Android application ID;
- release signing or a production keystore;
- a public versioning policy;
- Firebase deployment;
- App Check;
- dependency remediation;
- production distribution.
