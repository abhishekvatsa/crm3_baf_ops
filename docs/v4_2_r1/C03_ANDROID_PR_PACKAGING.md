# C-03 Android PR Packaging

Status: CLOSED

Source merge and CI evidence: COMPLETE

Production artifact, device evidence and distribution: NOT AUTHORIZED

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

The later review hardening also prevents this disposable package from touching
the production Firebase plane. The proof creates a temporary release-variant
`google-services.json` with an isolated non-production identity, supplies the
compile-time `CRM3_CI_PACKAGE_PROOF=true` marker, and removes the override in a
`finally` block. In that mode:

- Dart renders a minimal package-proof screen before Firebase, App Check,
  Crashlytics, messaging, Isar, authentication or synchronization can start;
- the compiled proof manifest disables Android's native `FirebaseInitProvider`,
  while production packages retain the provider;
- Android manifest metadata disables default Firebase data collection,
  Crashlytics collection, Messaging auto-init and Analytics collection;
- the Crashlytics Gradle plugin still generates mapping identity and shrinking
  evidence, but mapping upload is disabled;
- the packaging and cold-start verifiers independently read the compiled APK,
  require the native provider to be disabled, and require the isolated app ID,
  project ID, sender ID and API key plus all four collection flags set to
  `false`;
- the permanent production application ID is retained, while no production
  Firebase identity, signing certificate, secret or artifact is used.

The governed production-artifact workflow invokes the same package proof only
as a preflight. Its `finally` cleanup and the workflow's subsequent
`flutter clean` ensure the real artifact is rebuilt from the repository-owned
production Firebase configuration with the proof marker absent.

The job is a packaging and dependency-graph proof. Its outputs are not governed
release candidates and are not authorized for installation or distribution.

## Workflow

`.github/workflows/release-gate.yml` runs the proof once for every pull request
and once after admission to `main`, in a separate `android-package` job. Branch
pushes do not duplicate the pull-request run. The job has repository read
permission only, names no GitHub environment, references no secret, and uses
SHA-pinned setup actions.

## Closure Evidence

The source implementation did not by itself close `C-03`. PR #79 merged exact
green head `1021ccd0a628112f8e1e50ace1664b721e3ccb88`, tree
`f0737f16c42d4005d55108dcac3591e64a510b30`, to main as
`34ff071ee39d55c16cc7578c8898f00a371164c8` with the identical tree.

Exact-head pull-request run `30511076330` passed all four jobs, including
Android package job `90771130887`. The log recorded:

```text
PASS_C03_ANDROID_RELEASE_PACKAGING_PROOF
applicationId=in.co.sail.bsl.crm3.bafops
productionCertificateUsed=false
productionSecretsReferenced=false
artifactUploadPerformed=false
```

Post-merge run `30524580357` passed on the exact admitted main commit, including
Android package job `90812461841`.

The evidence record is
`release/evidence/c03-android-pr-packaging-closure.json`.

Decision:
`PASS_C03_ANDROID_PR_PACKAGING_SOURCE_AND_CI_CLOSURE`

## Operational Boundary

C-03 source-and-CI closure proves that normal push and pull-request CI build
and verify release-mode APK and AAB packages without production authority. It
does not authorize a production artifact, reserve a build number, use the
production signing key, install a package, claim device evidence, perform F4,
or permit distribution.

```text
C-03 source-and-CI finding: closed
production artifact:        not constructed
device/F4 evidence:         not claimed
pilot handout:              prohibited
```
