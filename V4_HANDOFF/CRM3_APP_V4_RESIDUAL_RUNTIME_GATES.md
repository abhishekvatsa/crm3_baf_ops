# CRM3 App v4 — Residual Runtime and Programme Gates

## Blocking source-authority gate

### G0 — Pinned Isar generation

Run the repository's authentic code-generation scripts with exactly:

- Flutter `3.44.0`
- Dart `3.12.0`
- Isar / `isar_generator` `3.1.0+1`
- `build_runner` `2.4.13`

The 13 files marked `PROVISIONAL_V4_ISAR_CODEGEN` must be replaced by authentic generator output. The release verifier intentionally fails until then. Generated collection/property/index IDs and migration compatibility must be reviewed before a real app open.

## Required development gates

1. `flutter pub get` under the pinned toolchain.
2. `dart run build_runner build --delete-conflicting-outputs`.
3. v4 Isar verifier in `--release` mode.
4. `flutter analyze`.
5. Complete Flutter test suite, including the added v2→v3 migration test.
6. Debug Android build and release-mode unsigned build.
7. Firestore emulator Rules tests.
8. Real Firestore transaction-contention tests for closure, lane replacement, compliance transfer, cancellation and escalation.
9. Malformed-projection quarantine tests against Isar and Firestore timestamp watermarks.

## Repository and backend authority gates

The programme preflight remains controlling:

1. Reconcile current main, all branches and the known outstanding local commit before merging v4.
2. Apply v4 on a fresh governed branch from the proven canonical main.
3. Reconcile intended Rules with deployed Rules and production document shapes.
4. Deploy Rules/Functions only through governed, scope-limited preflight packages.
5. Prove downloaded deployed source parity after deployment.

## Device and operational gates

1. Online-only assignment rejection with form retention.
2. Notification tap from background and terminated state.
3. Escalation delivery at all three tiers.
4. Weak/intermittent network and process-kill matrix.
5. Outbox uncertain-retry and no-duplicate proof.
6. Multi-user authority matrix on physical devices.
7. Upgrade from the current installed build with realistic Isar data.
8. Interrupted upgrade, local recovery and rollback drills.
9. Limited pilot monitoring before wider distribution.

## Security/release gates

1. Final Android package identity and Kotlin migration.
2. Production signing key generation and custody.
3. Firebase app/package/SHA binding.
4. Play Integrity/App Check registration.
5. Enable `CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK` only after the signed-client App Check and Play Integrity matrix is proven for all six mutating callables.
6. Protected build-number reservation and governed APK/AAB production.

## Current classification

- Architecture reconciliation: **source-complete candidate**
- TypeScript/server unit verification: **green**
- Dart source structure: **green, not compiled**
- Isar release authority: **blocked by design**
- Emulator/device/production proof: **not performed**
- Pilot readiness: **NO-GO until all blocking gates close**
