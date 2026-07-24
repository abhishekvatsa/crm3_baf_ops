# R1.13 Flutter-Test, Replay-Integrity and Hermetic-Isar Correction

## Purpose

R1.13 addresses the complete, evidence-backed set of 12 failures exposed by the R1.12 Flutter-test gate. It does not broaden application scope or alter backend deployment state.

## Product correction

Both offline job-module lifecycle replay builders now write:

```dart
'isOpenForWork': false,
```

This is required for exact parity with the submit/accept Rules whitelist and transition invariants. Because replay uses Firestore merge semantics, explicit clearing is necessary to prevent a previously open remote module from remaining logically open after submit or accept replay.

## Dialog lifecycle correction

The following surfaces now use private State-owned `TextEditingController` instances with deterministic disposal:

- compliance-detail text prompt;
- planned-job workflow text prompt;
- raise-compliance dialog title, description and condition-reference inputs.

No lifecycle guard was removed or weakened.

## Contract-test correction

R1.13 updates six stale or brittle contracts to test current governed behaviour rather than historical formatting or superseded architecture:

- async/mounted marker matching and assignment-command contract;
- arrow-bodied `Widget build` support in the static scanner;
- semantic explicit deny for direct workflow writes;
- seven accountable maintenance lanes, including governed `shared` coordination;
- `protobufjs 7.6.5` security authority.

The replay contract also now asserts that both transitions explicitly clear `isOpenForWork`.

## Hermetic Isar test-core custody

The authoritative laboratory now adds `30_isar_test_core_custody` before Flutter tests. The staging helper:

1. requires `isar_flutter_libs 3.1.0+1` in `pubspec.lock`;
2. verifies archive SHA-256 `BC6768CC4B9C61AABFF77152E7F33B4B17D2FC93134F7AF1C3DD51500FE8D5E8`;
3. resolves the selected package through `.dart_tool/package_config.json`;
4. requires exactly one PE AMD64 `isar.dll`;
5. copies it to `.governed-native/isar.dll`;
6. verifies source and staged DLL hashes;
7. writes evidence custody; and
8. prohibits network download during Flutter tests.

If that custody cannot be proven, the laboratory fails before the test suite rather than misclassifying three product tests as failures.

## Boundaries

R1.13 does not claim:

- authoritative `flutter analyze` success;
- authoritative Flutter-test success;
- debug APK success;
- emulator or device success;
- Git integration, backend deployment, signing or production release authority.

Those gates require the complete Windows laboratory against the packaged R1.13 bytes.
