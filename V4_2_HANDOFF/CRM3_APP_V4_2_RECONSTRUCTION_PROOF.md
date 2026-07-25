# CRM3 v4.2 Independent Reconstruction Proof

## Inputs

- Immutable v4.1 candidate ZIP SHA-256:
  `5E72E2B220115DBED6A389832CA8363A79CA09BBB43ACF1C7AB9975871C85560`
- v4.1 → v4.2 binary-safe patch SHA-256:
  `673F02CBE5A3A3B417C13FCC81C97D741A0001F595676373A818759C0AA99DDE`

## Reconstruction procedure

1. Extracted the immutable v4.1 ZIP to a fresh directory.
2. Created a local detached audit repository; no connected repository was used.
3. Applied `CRM3_APP_V4_1_TO_V4_2_ULTIMATE_LOCAL_TRIAL.patch` after a clean `git apply --check`.
4. Compared every patch-covered path against the active v4.2 source tree.
5. Installed root, Functions and governed Firebase CLI dependencies from their lockfiles.
6. Re-ran the source, dependency and Functions validation on the reconstructed tree.

## Results

```text
Patch-covered paths:                    33
Byte-identical reconstructed paths:     33/33
v4.2 ultimate audit:                    17/17 PASS
v4.1 due-diligence audit:                9/9 PASS
v4 whole-app audit:                     21/21 PASS
Inherited full-tree audit:              18/18 PASS
Inherited expanded audit:               15/15 PASS
Dart structural audit:                  PASS (369 files)
Policy regeneration check:              PASS
Isar source verifier:                   PASS
Isar release verifier:                  EXPECTED FAIL (13 provisional bindings)
Root npm audit:                          0 vulnerabilities
Functions npm audit:                     0 vulnerabilities
Governed Firebase CLI npm audit:         0 vulnerabilities
Functions tests:                        224 passed / 29 emulator-skipped
```

## Scope statement

The reconstruction proves source custody from v4.1 to v4.2. It does not substitute for authentic Flutter/Isar generation, repository ancestry, emulator execution, Android build or physical-device migration.
