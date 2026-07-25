# CRM3 v4.2_R1.11 validation

## Bounded scope

R1.11 changes only Python audit/schema-tool text encoding, its regression audit, laboratory evidence naming and handoff records. Product source, Rules, models, dependencies, lockfiles and governance remain unchanged from R1.10.

## Authenticated predecessor evidence

R1.10 evidence SHA-256:

`8F2E3B61F9A495F60543FDE9E98C4EAFC61867DCF0D90833B83AF3B71286869B`

The run passed stages 01–21 and stopped when the v4.1 audit used Windows `cp1252` for UTF-8 `firestore.rules`.

## Static validation completed for R1.11

- Python tooling compilation: PASS
- v4.1 audit with UTF-8 mode disabled and `LC_ALL=C`: 9/9 PASS
- canonical R1 audit, pristine phase: 33/33 PASS
- v4.2 audit: 17/17 PASS
- whole-app audit: 21/21 PASS
- inherited full-tree audit: 18/18 PASS
- inherited expanded audit: 15/15 PASS
- Dart structural audit: PASS across 369 files
- Firestore integrity-sweep tests: 3/3 PASS
- Python `read_text`/`write_text` calls inspected through AST: 50
- implicit locale-dependent text calls: 0

The packaged tree still contains the pre-codegen generated bindings and therefore the static Dart audit reports 13 provisional bindings. This is expected for the pristine package; the Windows laboratory must regenerate them and prove zero provisional bindings as R1.10 did.

## Not claimed here

- Windows PowerShell execution of R1.11
- authentic R1.11 code generation
- Functions complete tests
- `flutter analyze`
- Flutter tests
- APK construction or identity inspection
- emulator campaign
- device installation

Those remain execution gates in the disposable Windows laboratory.
