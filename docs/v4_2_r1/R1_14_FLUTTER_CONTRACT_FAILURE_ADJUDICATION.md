# R1.14 Flutter Contract Failure Adjudication

## Evidence authority

The authoritative R1.14 emulator-requested laboratory evidence is:

- archive: `CRM3_V42_R1_14_CANONICAL_LOCAL_LAB_20260723_020341.zip`;
- archive SHA-256: `1410C13D866367D116EA8C638E2A868EF42749FA899405C1A32290CAD6C65B4E`;
- final result: `FAIL_LOCAL_LAB`;
- failed stage: `31_flutter_tests`;
- remote Git mutation: none;
- Firebase deployment: none;
- production-data mutation: none;
- device uninstall/clear: none.

The evidence candidate manifest contains 712 entries and matches the sealed R1.14 candidate with zero missing, extra, size-mismatched or SHA-256-mismatched files.

## Exact result

Stages 01–30 passed, including dependency custody, authentic Isar generation, all source audits, Functions compilation and ordinary tests, `flutter analyze`, and governed no-download Isar native-core custody.

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

R1.14 deliberately changed maintenance-record Rules from four independent `allow update` expressions to one routed expression:

```text
allow update: if validMaintenanceUpdate();
```

This was the bounded correction for the authenticated R1.13 Firestore 1,000-expression failures. The router selects exactly one of:

- `validMaintenanceCloseUpdate()`;
- `validMaintenanceReopenUpdate()`;
- `validMaintenanceSoftDeleteUpdate()`;
- `validMaintenanceAdminEditUpdate()`.

The failed Flutter contract still required all four deleted pre-R1.14 `allow update` clauses and explicitly asserted that the new router must be absent. Its own explanatory reason described the superseded architecture.

The failure is therefore a stale structural assertion. It is not evidence that close/reopen payload fields, authorization, immutable identity fields or the R1.14 Rules router are defective.

## R1.15 correction

R1.15 changes the contract to prove the governed R1.14 architecture:

- exactly one maintenance `allow update` exists;
- that rule invokes `validMaintenanceUpdate()`;
- the router distinguishes deleted-state and resolved-state transitions;
- all four transition validators remain reachable;
- the router contains no parallel `||` chain.

R1.15 does not change `firestore.rules`, application product code, Functions code, dependency locks, Firebase configuration or release policy.

## Scope and non-claims

Static validation can prove that the stale assertion is removed and the replacement contract follows the current Rules structure. Only a fresh authoritative Windows run can prove the complete Flutter suite and the subsequently reached Rules and governed Functions emulator gates.
