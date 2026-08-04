# C-06 Android Release Shrinking

Status: SOURCE CANDIDATE

## Decision

Android release packages enable R8 minification, optimization and resource
shrinking. The release build uses Android's optimized default rules plus the
repository-owned `android/app/proguard-rules.pro` file. That file may carry
narrow compatibility rules, but it must not broadly disable shrinking,
optimization or obfuscation.

## Continuous Proof

The normal release gate builds both a release APK and Android App Bundle with
an ephemeral non-production signer. Before each build, the proof removes the
specific prior R8 mapping and resource report files. A pass requires fresh,
nonempty `mapping.txt` and `resources.txt` outputs, verifies both package
signatures, proves signer inequality from the production certificate, and
emits only hashes of the shrinking reports.

The proof does not name a production environment, read production signing
secrets, upload either package or mapping output, deploy, install, distribute
or authorize pilot handout.

## Runtime Boundary

Build 8 remains the immutable production-signed artifact that was built under
the recorded bounded no-R8 acceptance. This source change does not rewrite or
upgrade Build 8 and does not transfer its device evidence to a later build.

Every future production-signed artifact carrying this change must complete its
own governed construction and device validation before distribution. That
validation must include launch, authentication, local database opening, core
navigation and synchronization so reflection or serialization regressions
cannot be hidden by package-only evidence.

## Closure Boundary

C-06 is `SOURCE_AND_CI`. Closure requires exact-head pull-request CI and the
same four-job release gate on the admitted main commit. Until those identifiers
are recorded in a separate closure adjudication, this document makes no C-06
closure claim.
