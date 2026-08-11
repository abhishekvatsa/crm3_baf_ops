# C-04 Test Evidence Taxonomy

Status: CLOSED

## Finding

The former release-gate headlines used broad terms such as `tests` and
`packaging proof`. Those labels did not say whether a result came from a
static source contract, host process, Firebase emulator, constructed Android
package, Android runtime, live readback, or physical device.

## Evidence Levels

`governance/test-evidence-taxonomy.json` is the machine-readable authority for
eight distinct levels:

- source contract;
- host unit;
- host widget;
- Firebase emulator;
- Android package construction;
- Android emulator integration;
- mutation-free live readback;
- governed physical device.

Only the last level may claim physical-device authority. Android emulator
execution is runtime evidence, but it cannot prove production signing,
production backend behavior, weak-network behavior on real hardware,
distribution, or pilot readiness.

## Published Critical Paths

The same authority maps executable witnesses and still-open evidence for eight
business-critical paths: startup/recovery, authentication/authority, issue
lifecycle, planned work/workflow, template assignment, offline/reconnect,
notifications, and Firestore recoverability.

`tools/testing/verify_test_evidence_taxonomy.py` fails closed on missing or
duplicate levels, missing witness files, absent open-evidence declarations,
headline drift, an unpinned emulator action, or removal of the Android suite.
In GitHub Actions it publishes the critical-path matrix to the job summary.

## Android Runtime Suite

`integration_test/c04_operational_shell_android_test.dart` executes on an
Android API 33 `google_apis` x86_64 emulator in every pull request and admitted
main run. It proves that the Android runtime renders:

- local-database recovery controls;
- the signed-out Google sign-in surface;
- role-scoped planned-work navigation that hides template-governance actions
  from Operations and reaches the workflow queue.

The runner action is pinned to exact commit
`a421e43855164a8197daf9d8d40fe71c6996bb0d` and is registered in
`release/github-actions-pins.json`.

The pin registry is shared authority for production and CI-only workflows.
The production-policy verifier requires the production workflow's exact five
actions while permitting additional governed registry entries that are used
only by other workflows. A CI-only action therefore cannot be mistaken for a
production-build dependency or make production verification fail merely by
being present in the shared registry.

The first local Android run reproduced the workstation JVM crash: Gradle was
allowed an 8 GB heap, 4 GB metaspace, a 512 MB code cache, and unconstrained
workers while the emulator was resident on a 16 GB host. The repository now
bounds Gradle to a 4 GB heap, 1 GB metaspace, 256 MB code cache, and four
workers. The integration run and normal package construction must both pass
under that profile.

## CI Headlines

The release workflow now reports five bounded jobs:

```text
Flutter host analysis + tests + no-loss contracts
Android release package + cold-start proof (non-production)
Android emulator app-shell integration (not physical-device evidence)
Firestore Rules + governed callable emulator
Cloud Functions host build + non-emulator tests
```

The local release gate uses the same distinctions and validates the taxonomy
before running its test commands.

The Android package level now also cold-starts the exact disposable-signed
release APK on a clean emulator and checks process survival plus Android exit
and crash evidence. This remains non-production emulator evidence and does not
become physical-device or migration proof.

## Boundary

This source tranche does not construct a production artifact, use production
credentials, contact a production backend from the Android suite, deploy,
mutate cloud state, claim physical-device evidence, close F4, or authorize
pilot handout.

C-04 closed after all five governed jobs passed on exact pull-request head
`f332f4e780ca1ff4e63d696a549020de85c0e3f8` in run `30976162718` and on
exact admitted main commit `cf85476e924fe9941a7170d2bd4f4fa68bafc76d`
in run `30976649141`. The source and merge trees are identical at
`e645b8adf71b35c5c7a8901081efcca46c48cb53`.

The closure authority is
`PASS_C04_TEST_EVIDENCE_TAXONOMY_SOURCE_AND_CI_CLOSURE`. It closes only the
test-evidence classification and continuously executed Android-emulator gap.
Every production, physical-device, deployment, distribution, F4, and pilot
boundary stated above remains outside this decision.
