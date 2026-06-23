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

The manifest records deployed-index parity as `proven` and binds the corrected
70I-C decision-package SHA-256. The source/deployed comparison established 28 =
28, all READY, with zero actual field overrides. The prior divergent decision is
retained as superseded historical evidence. This source-only update deploys no Firebase resource.

## Production exclusions

70I-B1 does not approve:

- the permanent Android application ID;
- release signing or a production keystore;
- a public versioning policy;
- Firebase deployment;
- App Check;
- dependency remediation;
- production distribution.
## Isar native-test dependency

The full Flutter suite includes native Isar tests. The governed builder must
therefore receive a preverified platform core:

```powershell
-IsarCorePath '<path-to-verified-isar-core>' `
-ExpectedIsarCoreSha256 '<verified-sha256>'
```

The builder:

- verifies the supplied SHA-256 before testing;
- copies the core into the evidence package;
- sets `CRM_ISAR_CORE_PATH` only in the child build process;
- records the dependency in `release-manifest.json`;
- requires the independent verifier to recompute the packaged core hash.

The GitHub workflow independently discovers a Linux x86-64 `libisar.so`,
checks its architecture and linked libraries, performs a load probe, calculates
its SHA-256, and passes both its path and digest to the governed builder.

## Canonical and portable source custody

Manifest hashes for lockfiles, configuration, backend authority, and governed
backend source are calculated from the exact bytes inside the deterministic
Git source archive. They are not calculated from a platform-specific working
tree, so CRLF/LF checkout differences cannot alter the recorded source
identity.

The manifest uses POSIX archive-entry paths. The evidence package contains a
canonical copy of `verify-release-package.ps1`, byte-identical to its source
archive entry.

Package-only verification can therefore be run without the original checkout:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass `
  -File .\verify-release-package.ps1 `
  -ManifestPath .\release-manifest.json
```

A repository root may still be supplied as an optional additional check of the
clean Git commit and tree, but source-file custody is always recomputed from
the packaged source archive.
