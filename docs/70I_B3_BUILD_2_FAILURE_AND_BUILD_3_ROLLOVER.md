# 70I-B3 Build 2 Failure and Build 3 Rollover

## Decision

Android build number 2 is permanently consumed. Build number 3 is the next
approved production-candidate construction attempt.

This record does not approve Firebase deployment, controlled-pilot
distribution, or unrestricted plant release.

## Consumed build 2

- GitHub run: `30392976122`
- Run URL:
  `https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/30392976122`
- Exact commit: `4d5ea36327c3e7bc9d4ad162de362a3f94528610`
- Reservation tag: `crm3-build-reserved/2`
- Reservation tag object: `47e2063c3826c1c7ba4192b1796a745800a8815a`
- Result: failure
- Failed step: `Build once and independently verify`
- Production keystore restored and hash-checked: yes
- Artifact constructed: no
- Artifact uploaded: no
- Built tag created: no

The source release gate, governed emulators, dependency audits, composite
backend authority, signing custody, bundletool and Linux Isar-core custody all
passed. Android release construction then failed while configuring the locked
`isar_flutter_libs 3.1.0+1` plugin because its published Android Gradle file
does not declare the namespace required by Android Gradle Plugin 9.0.1.

The reservation tag remains authoritative. Build number 2 must never be reused.

## Local-cache qualification

The workstation Pub cache already carried a local namespace edit in the Isar
plugin. That ungoverned cache state masked the clean-runner failure during local
testing. Repository validation must therefore exercise this compatibility
boundary with a fresh isolated Pub cache.

## Corrected boundary

The root Android build now supplies `dev.isar.isar_flutter_libs` and aligns
`compileSdk` to the governed application SDK 36 only when the project is
exactly `isar_flutter_libs` and the Android library plugin is present. It does
not mutate the package cache and does not apply a blanket namespace or SDK
override to other dependencies.

The protected production workflow now restores the locked dependencies and
runs the release task-graph configuration and release-source compilation before
it creates the remote reservation tag. Dependency/AGP configuration, AAR
metadata and compiler defects therefore fail without consuming the next build
number.

The atomic reservation still precedes production signing and artifact
construction. Any failure after reservation still consumes the number.

## Build 3 authority

- Version: `1.0.0-rc.1+3`
- Release ID: `crm3-baf-ops-1.0.0-rc.1-b3`
- Reservation ID: `crm3-baf-ops-o1-o5-v4-4d5ea36-b3-3`
- Reservation tag: `crm3-build-reserved/3`
- Built tag: `crm3-build-built/3`
- Approval: `release/approvals/build-number-3-rollover-approval.json`

The build-3 reservation tag does not exist until the protected workflow creates
it after the source repair is merged to exact live `main`.
