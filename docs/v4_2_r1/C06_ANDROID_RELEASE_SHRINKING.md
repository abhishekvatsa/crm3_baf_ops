# C-06 Android Release Shrinking

Status: CLOSED

Source merge and CI evidence: COMPLETE

Production artifact, device evidence and distribution: NOT AUTHORIZED

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

## Closure Evidence

C-06 is `SOURCE_AND_CI`. PR #152 merged exact green head
`6af4bd411a15611f790138c38e35f3918e9f807d`, tree
`b6c0129e14107d09ea8ffd822b305af177824691`, to main as
`cacab29a5cf79bdc723a80b9e4a33557f7a1eada` with the identical tree.

Exact-head pull-request run `30942169313` passed all four governed jobs,
including Android package job `92103071831`. Its fresh release build emitted:

```text
PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF
r8MappingSha256=21832BEEC5CD7E812C3559B4CBCDE950A3B9B760A2986217EDAE5B17CEF1E39F
resourceShrinkReportSha256=D8D201EA1F504DA131271CD373D738995B4A237DD0ACA8596D2E4B6CE5AE860D
productionCertificateUsed=false
productionSecretsReferenced=false
artifactUploadPerformed=false
```

Post-merge run `30942876995` passed the same four jobs on the exact admitted
main commit, including Android package job `92105447536`. It independently
emitted the same R8 mapping hash and a fresh nonempty resource report hash.

The evidence record is
`release/evidence/c06-android-release-shrinking-closure.json`.

Decision:
`PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE`

## Operational Boundary

Closure proves the release source and normal CI shrinking path. It does not
construct or authorize a production artifact, mutate Build 8, inherit device
evidence, perform runtime validation, reserve a build number, deploy, or permit
pilot handout.

```text
C-06 source-and-CI finding: closed
production artifact:        not constructed
device/runtime evidence:    not claimed
pilot handout:              prohibited
```
