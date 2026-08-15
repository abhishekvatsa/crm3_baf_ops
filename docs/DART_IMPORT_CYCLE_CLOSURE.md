# Dart Import Cycle Closure

Status: CLOSED

Programme adjudication: `FINDING:A-01` is `CLOSED` as of 15 August 2026.
PR #214 exact head `2a5a2751ae5bb2d17cb4148799ac58ed0ae78cf6`
and admitted-main merge `dad9ec6d27177699a1656b0a33ca23739ffb41ea`
share source tree `99deeb6966cc1b694f861a6154d9a4ddef3c7af0`.

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

## Closure evidence

Exact-head release-gate run `31863973925` and admitted-main run `31864544804`
passed the Tarjan regression, canonical audit, Flutter analysis, complete
Flutter suite and every governed release-gate job. The immutable evidence is
recorded in
`release/evidence/a01-dart-import-cycle-source-and-ci-closure.json`.

## Boundary

This is dependency-direction and test-fixture refactoring only. Isar schemas,
database naming, open order, migration, provenance markers and recovery policy
are unchanged. Closure is source-and-CI authority only; it does not provide
deployment, migration, device, pilot, distribution or production-data
authority.
