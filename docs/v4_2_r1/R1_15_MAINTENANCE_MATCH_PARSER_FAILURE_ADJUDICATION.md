# R1.15 Maintenance-Match Parser Failure Adjudication

## Evidence authority

The authoritative R1.15 emulator-requested laboratory evidence is:

- archive: `CRM3_V42_R1_15_CANONICAL_LOCAL_LAB_20260723_022011.zip`;
- archive SHA-256: `7A77A446FF9151022A2909BA5485A242F72E897969652F0A1AD976860CA2F1F4`;
- final result: `FAIL_LOCAL_LAB`;
- failed stage: `31_flutter_tests`;
- remote Git mutation: none;
- Firebase deployment: none;
- production-data mutation: none;
- device uninstall/clear: none.

The evidence candidate manifest contains 722 files and matches the sealed R1.15 candidate with zero missing, extra, size-mismatched or SHA-256-mismatched files.

## Exact result

Stages 01–30 passed, including dependency custody, authentic Isar generation, source audits, Functions compilation and ordinary tests, `flutter analyze`, and governed no-download Isar native-core custody.

The complete Flutter suite reached:

- 472 passing tests;
- 1 failing test;
- no additional failing test.

The failed contract was:

`test/maintenance_lifecycle_replay_contract_test.dart`

Test name:

`rules accept mobile close/reopen field surfaces without allowing identity edits`

The emulator stage was not reached because the harness correctly stops after a failed Flutter suite.

## Root cause

The R1.15 contract correctly sought the Rules block beginning at:

```text
match /maintenance_records/{docId}
```

The Rules source contains exactly one routed update at that match:

```text
allow update: if validMaintenanceUpdate();
```

The private `_blockStartingAt` helper nevertheless searched for the first opening brace from `markerIndex`. Because the marker itself contains `{docId}`, it selected the path-token brace, matched the immediately following `}`, and returned only the marker token instead of the match body. The assertion consequently counted zero update rules.

The already-passing expression-budget contract uses the correct search boundary:

```dart
source.indexOf('{', markerIndex + marker.length)
```

The failure is therefore a parser defect in the test helper. It does not demonstrate a Rules, authorization, lifecycle, or expression-budget regression.

## Programme-history correction

The Rules refactor remains uncertified by an emulator PASS, and the governed Functions emulator suites still have not executed because the R1.13 Rules command failed before them and the R1.14/R1.15 runs stopped at Flutter stage 31.

It is not accurate to describe three consecutive runs as stopping at stage 31: the authenticated R1.13 emulator run reached the Rules emulator stage and failed there. The two subsequent emulator-requested runs, R1.14 and R1.15, stopped at stage 31.

## R1.16 correction

R1.16 changes only the helper's brace-search start to `markerIndex + marker.length`, matching the proven budget-guard implementation. Firestore Rules and all product-authority bytes remain unchanged.
