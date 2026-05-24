# Issue 46 — Isar schema migration helpers + input validation breadth

## Scope

This package targets the corrected audit blockers:

1. Isar schema migration helpers.
2. Input validation breadth.

It is based on the current `lib(15)` baseline uploaded on May 13, 2026.

## Item 1 — Isar schema migration helpers

### What changed

Added a pre-open schema guard:

```text
lib/core/services/isar_schema_migration.dart
lib/core/services/isar_schema_guard.dart
lib/core/services/isar_schema_guard_io.dart
lib/core/services/isar_schema_guard_stub.dart
```

Changed `main.dart` so `_openLocalIsar()` now runs:

```dart
await ensureIsarSchemaBeforeOpen(databaseDirectoryPath: dir.path);
```

before:

```dart
return Isar.open(...);
```

### Why this is safe

- The schema marker is stored in `SharedPreferences`, not Isar, so it can be read before `Isar.open`.
- The current baseline version is `1` and has no data-mutating migration steps.
- Existing installs with Isar files but no marker are baseline-stamped as v1.
- Future app builds must bump `currentSchemaVersion` and register a migration step. If they forget, startup fails into the existing startup failure/recovery path instead of silently advancing the marker.
- Downgrades are refused: a database marker newer than the app build throws before open.

### Closure boundary

This closes the helper/guard infrastructure. It does not magically migrate a future unknown Isar-breaking schema change. Future schema changes must add explicit steps and tests.

## Item 5 — Input validation breadth

### What changed

Added reusable validation primitives:

```text
lib/core/validation/validation_result.dart
lib/core/validation/field_validators.dart
```

Added domain validators:

```text
lib/features/maintenance/validation/maintenance_input_validator.dart
lib/features/auth/validation/user_input_validator.dart
```

Wired validators into live save paths:

```text
lib/features/maintenance/presentation/maintenance_form.dart
lib/features/maintenance/presentation/resolve_form.dart
lib/features/admin/presentation/user_management_screen.dart
```

### Live-path coverage

- Maintenance ticket create:
  - asset number + AssetValidator range;
  - component required/length/control chars;
  - fault description required/length/control chars;
  - tag length/control chars;
  - charge number numeric/range;
  - start time not in future;
  - `RoutedTo.others` consistency.

- Maintenance ticket resolution:
  - end time not future;
  - end time not before start;
  - remarks length/control chars;
  - team names are known;
  - deleted/already-resolved tickets rejected.

- User management:
  - pending approval validates uid/name/email/roles before write;
  - role updates validate role selection, admin authority, self-admin removal, and last-admin removal before write.

## Tests added

```text
test/isar_schema_migrator_test.dart
test/input_validation_test.dart
```

## Verification commands

```powershell
dart format lib\core\services\isar_schema_migration.dart lib\core\services\isar_schema_guard.dart lib\core\services\isar_schema_guard_io.dart lib\core\services\isar_schema_guard_stub.dart lib\core\validation\validation_result.dart lib\core\validation\field_validators.dart lib\features\maintenance\validation\maintenance_input_validator.dart lib\features\auth\validation\user_input_validator.dart lib\main.dart lib\features\maintenance\presentation\maintenance_form.dart lib\features\maintenance\presentation\resolve_form.dart lib\features\admin\presentation\user_management_screen.dart test\isar_schema_migrator_test.dart test\input_validation_test.dart

flutter test test\isar_schema_migrator_test.dart
flutter test test\input_validation_test.dart
flutter test test\issue_1_tombstone_conflict_regression_test.dart
flutter test test\published_runtime_module_catalogue_test.dart
flutter analyze
```

## No-loss statement

No Firestore rules, Firestore indexes, Isar schemas, generated `.g.dart` files, sync services, audit repository injection, tombstone behavior, or response payload contracts are changed.

The schema helper writes only a SharedPreferences marker in the current v1 baseline. The input validators block malformed user-entered payloads before save; they do not mutate existing local or remote records.


## Hybrid V3 correction notes

Hybrid V3 intentionally rejects both previous ZIPs as whole packages.

It keeps the pre-open Isar guard so the schema marker/fingerprint check happens before `Isar.open`, preserving the existing startup recovery path for true open failures. It does not pretend to perform destructive row-level Isar migrations before Isar can open; future schema-breaking releases must either register an explicit pre-open file-level migration step or route through the existing recovery/export workflow.

It also closes the validation critique by combining field-aware validators with real UI/save-path adoption:

- `RoutedTo.others` shows an `Other department` field.
- `otherDepartment` is saved only when the route is `Others`.
- the controller is cleared when the route changes away from `Others`.
- resolution remarks remain required in both the form validator and save-path validation.
- the last-approved-admin guard remains explicit in the user-management screen and is also represented in the domain validator.

No Isar collection schema, generated file, Firestore rule, Firestore index, sync policy, audit injection path, tombstone behavior, planned-job closure behavior, or runtime-add catalogue behavior is changed.
