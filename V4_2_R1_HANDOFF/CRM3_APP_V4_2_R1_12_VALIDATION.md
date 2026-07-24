# CRM3 App v4.2_R1.12 — Validation Record

## Accepted Windows evidence

The R1.11 laboratory evidence ZIP SHA-256 is:

`67DA45E9A013F31D96928EEF5D65515692F339F97D705F6E993A9BF11AFC0962`

It passed stages 01–28 and failed only at `29_flutter_analyze`, with 18 diagnostics: seven errors, three warnings and eight infos.

## R1.12 correction scope

R1.12 corrects all 18 reported diagnostics. It changes ten Dart/test files plus the laboratory naming, canonical reconciliation hashes and audit assertions. It does not change dependencies, lockfiles, Firestore, Functions, Isar collection models, Android identity or programme authority.

## Packaging-environment validation

- Canonical R1 pristine audit: 34/34 PASS
- v4.2 ultimate audit: 17/17 PASS
- v4.1 due-diligence audit: 9/9 PASS
- whole-app reconciliation audit: 21/21 PASS
- inherited full-tree audit: 18/18 PASS
- inherited expanded audit: 15/15 PASS
- Dart structural audit: PASS across 369 Dart files
- Firestore integrity-sweep tests: 3/3 PASS
- generated workflow-policy check: PASS
- R1.12 targeted source/custody checks: 28/28 PASS
- R1.11 → R1.12 patch reconstruction: 16/16 paths exact

The three npm lockfiles, `pubspec.lock`, Firestore Rules/indexes, Firebase configuration, Android build configuration and programme ledger are byte-identical to R1.11.

## Unclaimed gates

The packaging environment has no Flutter/Dart SDK. It therefore does not claim:

- `flutter analyze` PASS;
- Flutter test PASS;
- APK build PASS;
- Firestore/Functions emulator PASS;
- device installation or launch PASS.

Those remain the purpose of the R1.12 Windows laboratory run.
