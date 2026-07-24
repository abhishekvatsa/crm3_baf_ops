# R1.13 Rules/Emulator Failure Adjudication

## Evidence authority

The authoritative R1.13 emulator-enabled laboratory evidence is:

- archive: `CRM3_V42_R1_13_CANONICAL_LOCAL_LAB_20260723_011733.zip`;
- archive SHA-256: `9BD708BB5E2EDD7AE8EF4671637311FC8BC629FE4CA807733BD4FD307F617C20`;
- final result: `FAIL_LOCAL_LAB`;
- failed stage: `33_rules_and_functions_emulators`;
- remote Git mutation: none;
- Firebase deployment: none;
- production-data mutation: none;
- device uninstall/clear: none.

Stages 01–32 passed, including the canonical audit, Functions compilation and ordinary tests, `flutter analyze`, the complete Flutter suite, governed Isar test-core custody, authentic code generation and debug APK construction.

## Exact Rules result

The candidate's own `firestore.rules` was loaded by the Firestore emulator. The Rules suite reported:

- 3 suites total;
- 1 suite passed;
- 2 suites failed;
- 122 tests total;
- 103 tests passed;
- 19 tests failed.

The command was serialized as `npm run test:rules && npm --prefix functions run test:emulator:governed`. Because `test:rules` failed, the governed Functions emulator suites did not execute. R1.13 therefore proves neither a Functions-emulator failure nor a Functions-emulator pass.

## Bucket A — ten expression-budget failures

Ten permitted Rules operations reached Firestore's maximum of 1,000 evaluated expressions:

1. maintenance-record admin soft delete;
2. maintenance-record mobile reopen;
3. maintenance-record legacy reopen;
4. draft template archive;
5. archived draft restore;
6. directive creation;
7. directive closure by issuer;
8. module-registry atomic publication;
9. module-registry revision retirement;
10. module-registry family refresh against its published revision.

The failures were caused by evaluation structure, not by an absent role or malformed test document. The principal amplifiers were:

- four independent `allow update` expressions for maintenance records;
- lifecycle validators expressed as broad OR chains;
- directive role authority repeatedly reopening and revalidating the same user document;
- repeated `getAfter` reads of the same module-registry family;
- complete user-shape validation repeated across overlapping branches.

R1.14 retains the same fail-closed user-document shape, role vocabulary, immutable fields and transition conditions. It replaces overlapping evaluation with source/target-status routers, snapshots a fully validated role list once where needed, and caches the module-family `getAfter` result.

## Bucket B — nine job-module open-state failures

Nine positive job-module Rules tests were denied without the 1,000-expression message. Their seeded documents omitted the persisted `isOpenForWork` field, while the Rules correctly require:

- an open-work status to carry `isOpenForWork == true`;
- `submitted`, `accepted` and `notApplicable` to carry `isOpenForWork == false`;
- `reopened` to carry `isOpenForWork == true`.

That fixture omission exposed a second real product defect. R1.13 corrected only the offline replay builders. The direct online Firestore repository still changed `status` without writing the materialized `isOpenForWork` field. Because the repository uses merge writes, a module could retain an obsolete open flag across submit, accept or not-applicable, or retain a closed flag across reopen.

R1.14 therefore writes the field explicitly in all four online transitions:

- submit → `false`;
- accept → `false`;
- not applicable → `false`;
- reopen → `true`.

The Rules fixtures now materialize the field and each positive transition writes the expected target value. Negative role and immutable-field tests remain fail-closed.

## Scope and non-claims

R1.14 is a bounded source correction. It does not:

- weaken full approved-user document validation;
- broaden any role;
- permit direct client job-module creation or deletion;
- change canonical closure criteria;
- deploy Rules or Functions;
- mutate Git or production data.

Static validation can prove structure, field parity, custody and reconstruction. Only a fresh authoritative Windows run with `-RunEmulators` can prove that the 122 Rules tests and governed Functions emulator suites pass under the actual Firebase emulator.
