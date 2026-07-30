# C-03 Android PR Packaging

## Decision

Normal push and pull-request CI must construct both Android release package
forms before a production build number is reserved:

- APK;
- Android App Bundle.

The proof uses an ephemeral, non-production PKCS#12 identity generated inside
the CI job. It never references the production GitHub environment or production
signing secrets.

## Proof Boundary

`tools/release/Invoke-CIAndroidPackageProof.ps1`:

1. fails if any production signing input is already present;
2. generates a short-lived CI-only RSA signing identity;
3. reads the governed production certificate from
   `release/production-release-policy.json`;
4. proves the CI certificate differs from the production certificate;
5. builds a release APK and AAB through the real Flutter/Gradle release graph;
6. verifies both package signatures against the ephemeral certificate;
7. verifies the APK application ID and non-debuggable state;
8. records package hashes in the job log;
9. uploads no artifact and removes the temporary signing material.

The job is a packaging and dependency-graph proof. Its outputs are not governed
release candidates and are not authorized for installation or distribution.

## Workflow

`.github/workflows/release-gate.yml` runs the proof on every push and pull
request in a separate `android-package` job. The job has repository read
permission only, names no GitHub environment, references no secret, and uses
SHA-pinned setup actions.

## Closure Boundary

This source implementation does not itself close `C-03`. Closure requires:

- owner-reviewed merge of the source tranche;
- exact-head pull-request CI with the Android packaging job passing;
- post-merge CI on the admitted merge commit;
- a separate evidence record and append-only programme-ledger adjudication.

Production artifact construction, signing, installation, F4 execution and
pilot handout remain outside this change.
