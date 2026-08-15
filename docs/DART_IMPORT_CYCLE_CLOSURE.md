# Dart Import Cycle Closure

Status: SOURCE_IMPLEMENTED

Programme adjudication: `FINDING:A-01` is `SOURCE_IMPLEMENTED` as of
15 August 2026. Exact-head pull-request CI and admitted-main post-merge CI
remain required before the ledger may record `CLOSED`.

## Finding

The app data layer imported `main.dart` in eleven repositories, providers and
diagnostic surfaces solely to access the global Isar handle. Because
`main.dart` imports `home_screen.dart`, and screens import those providers,
this created one strongly connected component across the app.

Measured before correction on the PR #89 head:

```text
Dart files:             280
Internal import edges:  1022
Cyclic components:      1
Largest component:      72 files
```

The three screens added by the UX stack joined an inherited 69-file component;
they did not create the underlying cycle.

## Correction

The Isar handle now lives in `core/persistence/app_database.dart`. Application
startup initializes that module, while repositories, providers, diagnostics
and Isar-backed tests import it directly. No library under `lib/` imports
`main.dart`.

Measured after correction:

```text
Dart files:             281
Internal import edges:  1023
Cyclic components:      0
Largest component:      0 files
```

`dart_import_cycle_test.dart` computes strongly connected components over all
internal Dart imports and requires the cycle set to remain empty in CI.

## Boundary

This is dependency-direction and test-fixture refactoring only. Isar schemas,
database naming, open order, migration, provenance markers and recovery policy
are unchanged. It does not provide deployment, migration or device evidence.
