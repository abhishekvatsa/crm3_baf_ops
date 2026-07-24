# CRM3 App v4.2_R1.13 — Validation Record

## Accepted R1.12 evidence

The authenticated R1.12 Windows laboratory passed stages 01–29 and reached the full Flutter suite. The suite produced 441 passing and 12 failing tests.

The failures have been reconciled as:

- two failures from one confirmed offline replay-integrity defect;
- three failures from unavailable, non-hermetic IsarCore download;
- one guardrail failure covering five old controller-ownership sites;
- six stale or structurally brittle contracts.

## Regression adjudication

The package-owned R1.11 → R1.12 patch changes exactly 16 paths and does not introduce the replay defect, Isar fallback behaviour, compliance-detail controller debt, or the failing contract assertions. The R1.12 harness already contained the Flutter-test stage; R1.12 merely made it reachable by fixing analyzer errors.

## R1.13 packaging-environment validation

The packaging environment performs only source, structural, custody and reconstruction validation. Exact output is recorded in `CRM3_APP_V4_2_R1_13_STATIC_VALIDATION.log`.

- targeted R1.13 checks: 27/27 PASS
- canonical R1 pristine audit: 38/38 PASS
- v4.2 ultimate audit: 17/17 PASS
- v4.1 due-diligence audit: 9/9 PASS
- whole-app reconciliation audit: 21/21 PASS
- inherited full-tree audit: 18/18 PASS
- inherited expanded audit: 15/15 PASS
- Dart structural audit: PASS across 369 Dart files
- Firestore integrity-sweep tests: 3/3 PASS
- workflow-policy generation check: PASS
- governed Isar-core synthetic custody test: PASS
- R1.12 → R1.13 patch reconstruction: 19/19 paths exact

## Mandatory authoritative rerun

The packaging environment has no governed Windows Flutter/Android runtime. It therefore does not claim:

- `flutter analyze` PASS;
- 453/453 Flutter tests PASS;
- debug APK build PASS;
- Firestore/Functions emulator PASS;
- clean-device installation or launch PASS.

The R1.13 Windows laboratory must start from the pristine packaged candidate and rerun all stages. No resume from the R1.12 Stage 30 workspace is valid.
