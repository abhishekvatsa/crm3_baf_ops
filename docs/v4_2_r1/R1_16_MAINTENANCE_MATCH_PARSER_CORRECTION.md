# R1.16 Maintenance-Match Parser Correction

R1.16 is a parser-only Flutter contract correction over the sealed R1.15 candidate.

## Preserved bytes

The following authority-bearing areas are unchanged from R1.15:

- `firestore.rules`;
- all `lib/` product source;
- all `functions/` source and tests;
- root and Functions dependency lockfiles;
- Firebase configuration;
- Android build identity;
- release policy and workflows.

## Corrected helper

`test/maintenance_lifecycle_replay_contract_test.dart` now begins its opening-brace search after the full marker:

```dart
final openBrace = source.indexOf('{', markerIndex + marker.length);
```

This prevents a parameter brace inside a Rules match marker, such as `{docId}`, from being mistaken for the block-opening brace. The implementation is byte-equivalent to the already-passing helper in `firestore_rules_expression_budget_contract_test.dart` for this statement.

## Scope decision

Several contract files contain private block parsers with different capabilities. Consolidating them into one shared parser is a valid maintenance improvement, but doing so in R1.16 would enlarge the immediate correction and create avoidable test-surface change before emulator certification. R1.16 therefore performs only the proven one-line repair. Shared-parser consolidation is deferred to a separately reviewed test-infrastructure change.

## Required authority

Only a fresh authoritative Windows run with `-RunEmulators` can prove:

- the complete Flutter suite;
- Firestore Rules compilation;
- 122/122 Rules tests;
- the governed Functions emulator suites;
- Android debug APK construction;
- `PASS_AUTHORITATIVE_BUILD_AND_EMULATOR`.
