# v4.2_R1.8 Validation

## Evidence basis

R1.7 execution evidence reached authentic Isar generation and post-codegen custody. Stage 18 reported 101 inherited-property findings, all limited to generated numeric position changes:

- JobExecution: 27
- TemplateVersion: 33
- JobModuleInstance: 41

No inherited property name or type was lost or changed. No inherited collection ID or index definition changed.

## R1.8 semantic regression proof

A temporary schema fixture was reconstructed from the exact 101 R1.7 findings.

Result:

```text
PASS_CANONICAL_ISAR_SEMANTIC_CONTINUITY
positionChanges=101
failures=0
```

Collection distribution exactly matched the R1.7 evidence.

A negative fixture then changed `JobExecution.chargeNoAtEvent` from `long` to `string`.

Result:

```text
FAIL_CANONICAL_ISAR_SEMANTIC_CONTINUITY
reason=inherited-property-type-changed
failures=1
```

The verifier therefore permits only generated-position movement while retaining a fail-closed property-type boundary.

## Static/source gates

- canonical R1 audit: 28/28 PASS
- v4.2 ultimate audit: 17/17 PASS
- v4.1 due-diligence audit: 9/9 PASS
- whole-app audit: 21/21 PASS
- inherited full-tree audit: 18/18 PASS
- inherited expanded audit: 15/15 PASS
- Dart structural audit: PASS, 369 files
- integrity-sweep tests: 3/3 PASS
- workflow policy generation check: PASS
- provisional source schema verification: PASS, release authority remains NO until authentic codegen

## Runtime boundary

Packaging does not claim:

- PowerShell execution;
- authentic R1.8 `build_runner`;
- release-mode Isar verification;
- Functions test suite;
- `flutter analyze`;
- Flutter tests;
- APK construction;
- emulator execution.

Those remain governed by the Windows laboratory.
