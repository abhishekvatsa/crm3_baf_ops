# v4.2_R1 Canonical-Main Reconciliation

## Authority resolved

The repository authority capture established the current integration baseline as:

- branch: `main`
- commit: `633c58bb0d936011e391b42627f8b8f02c510e95`
- tree: `2f547a79e79076c70dd15ae8b85a7ad70c9fa018`
- local `main`, local `origin/main`, working `HEAD`, live GitHub `main`: identical
- repository status: clean, ahead 0, behind 0

`556700310cf9982d7a771b0942bb46e10c1fd836` is retained as a valid historical baseline, but it is an ancestor 37 commits behind current main and is not the integration base.

## Source reconciliation result

The exact post-PR38/post-PR39 maintenance-workflow source collector was used as the canonical-main source/configuration scope. Its archive SHA-256 is:

`43A728FB58DC4C3155030BB65009C050158322DB27324E04002C05666A5B7627`

The original reconciliation contained 344 byte-identical paths and 66
intentional successor modifications. After the accepted source tranches through
21 August 2026, the same no-loss 410-path scope now contains:

- 188 byte-identical canonical paths;
- 222 intentional successor modifications;
- 0 missing canonical paths.

The machine-readable path and hash record is `CANONICAL_MAIN_RECONCILIATION.json`.

## Closures preserved exactly

The following canonical-main authority remains byte-identical and is checked as
an immutable release boundary:

- `release/stage2d-f-internal-controlled-deployment-scope.json`;

Historical release evidence retains its own recorded hashes. Mutable workflows,
the programme ledger, Android configuration and source contracts are explicitly
classified as successor modifications when they evolve.

The PR39 `websocket-driver` security closure is preserved in both root and Functions lockfiles at version `0.7.5` with the same integrity hash. Later dependency hardening is additive.

## Intentional successor modifications

The 222 modified canonical paths fall into these classes:

1. **New workflow architecture and UI integration** — workflow lanes, compliance, equipment state, ticket bridge, canonical closure and diagnostics.
2. **Server authority and Rules hardening** — generated policy, server-owned workflow fields, exact user schema and canonical approval/roles.
3. **Persistence and migration** — additive Isar fields, new collections, schema migration and remote synchronization.
4. **Operational projections** — timeline, reports, tickets and planned-maintenance provider changes needed to surface the new model.
5. **Dependency and toolchain hardening** — root, Functions and governed Firebase CLI lockfiles.
6. **Documentation/release assertions** — corrected Firebase identity and explicit successor/release gates.
7. **Authenticated test-contract alignment** — the maintenance replay contract follows the R1.14 single-router Rules architecture and its source-block helper now ignores marker-owned parameter braces such as `{docId}`.

These modifications are not compatibility concessions. They express the migration-first successor architecture while preserving the proven business, security and governance guarantees of canonical main.

## Canonical-main build-input custody

The authoritative current-main tracked-file capture records:

- `lib/firebase_options.dart` SHA-256: `07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE`
- `android/app/google-services.json` SHA-256: `DBD4450D064E6FE68D2F809A8A81B1FE5AC6E96E390F8F0B1762938D0EF5FE6D`

The earlier registration-source hash `730A044F...` is a different custody object and is not substituted for the canonical committed build file.

## Integration boundary

This reconciliation does not create a Git branch, commit, tag, PR, merge, Firebase deployment or production-data write. It establishes the source from which the disposable local laboratory must run.
