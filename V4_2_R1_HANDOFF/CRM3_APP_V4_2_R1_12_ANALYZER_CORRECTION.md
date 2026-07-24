# CRM3 App v4.2_R1.12 — Flutter Analyzer Correction

## Evidence basis

R1.11 Windows laboratory evidence:

- ZIP: `CRM3_V42_R1_11_CANONICAL_LOCAL_LAB_20260722_235257.zip`
- SHA-256: `67DA45E9A013F31D96928EEF5D65515692F339F97D705F6E993A9BF11AFC0962`
- Stages 01–28: PASS
- Stage 29 (`flutter analyze`): FAIL with 18 diagnostics
  - 7 errors
  - 3 warnings
  - 8 infos

The analyzer was executed by Flutter 3.44.0 / Dart 3.12.0 in the authoritative Windows laboratory. The diagnostics are therefore accepted as runtime-toolchain findings rather than inferred source concerns.

## Corrections

### Errors

1. `IsarSchemaMigrator.defaultPlan` is now `static const`, making it valid as an optional-parameter default.
2. The second workflow timeline invocation now supplies `workflow.jobExecutionFirestoreId`.
3. The compliance dialog normalises its nullable gating-lane selection with `value ?? ''`.
4. The illegal assignment to the derived `isOpenForWork` getter is replaced with `isDeleted = false`; together with `status = reopened`, this restores the intended open-for-work state.
5. The RED exit-gate test no longer creates a const set containing `MaintenanceLaneId`, whose equality is non-primitive.
6. The retry-policy test now invokes the real `classify(WorkflowException)` API using typed `WorkflowErrorCode` values.

### Warnings

1. Removed unused `_epoch` from `workflow_record_mappers.dart`.
2. Removed the unused planned-maintenance provider import from `assign_job_screen.dart`.
3. Removed unused `_combineLatest2` from `fleet_status_provider.dart`.

### Infos

1. The six deprecated `DropdownButtonFormField.value` arguments are replaced with `initialValue`.
2. `complete_job_screen.dart` now checks `mounted` before passing `context` to `showRedExitDialog` after earlier awaits.
3. The `prefer_const_constructors` diagnostic is resolved by the `static const` migration-plan correction.

## Scope

No changes were made to:

- Firestore Rules or indexes;
- Functions source, tests, dependencies, or lockfiles;
- Isar collection models or generated bindings;
- Android package identity or Firebase identity;
- programme ledger, release authority, or remote Git state;
- production Firebase or device data.

R1.12 is a bounded Dart/analyzer correction candidate. The next Windows run remains authoritative for `flutter analyze`, Flutter tests, APK construction, and emulator suites.
