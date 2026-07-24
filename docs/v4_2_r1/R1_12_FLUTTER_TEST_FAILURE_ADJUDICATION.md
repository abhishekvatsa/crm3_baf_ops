# R1.12 Flutter-Test Failure Adjudication

## Authority reviewed

This adjudication uses the authenticated R1.12 Windows laboratory evidence and the package-owned patch
`V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_11_TO_R1_12_FLUTTER_ANALYZER_CORRECTION.patch`.

The R1.12 laboratory reached `flutter test` only after stages 01–29 passed. The suite reported 441 passing and 12 failing tests.

## R1.11 → R1.12 regression question

The package-owned patch changes 16 paths. It is the bounded analyzer-correction set described by R1.12. In particular:

- it does not change `lib/core/services/sync_service.job_modules.dart`;
- it does not change `tool/test_support/test_isar_core.dart`;
- it does not change `compliance_detail_screen.dart`;
- it does not change the failing replay, lifecycle, lane, Rules or Stage-2D security contract tests;
- its changes to `planned_job_workflow_panel.dart` and `raise_compliance_dialog.dart` are analyzer corrections outside the controller-ownership debt identified by the test;
- its laboratory-script delta only changes the R1.11 run name/banner to R1.12.

Therefore the 12 failures are not attributable to the R1.12 analyzer correction. They are pre-existing product, test-contract and laboratory debt exposed when the analyzer gate finally passed.

One external assessment phrase is corrected: R1.12 did **not add** the Flutter-test stage. The stage already existed; R1.12 made it reachable by clearing the analyzer gate.

## Failure classification

### A. Confirmed product defect — two failures

`_jobModuleSubmitReplayStepData` and `_jobModuleAcceptReplayStepData` omit `isOpenForWork`, although:

1. Firestore Rules permit that field in both lifecycle transitions and require it to become `false`.
2. The remote replay primitive is merge-scoped, so an omitted field retains its prior remote value.
3. Canonical closure treats any module with `isOpenForWork == true` as open.

An offline lifecycle replay can therefore materialize a submitted or accepted module whose persisted open flag remains true. This can produce phantom-open closure behaviour. R1.13 adds `isOpenForWork: false` to both replay maps and strengthens the replay contract tests.

### B. Non-hermetic native-test environment — three failures

Three `setUpAll` failures attempted to download IsarCore because `CRM_ISAR_CORE_PATH` was unset. The existing helper already recognized a governed path, but the authoritative harness did not stage one or prohibit fallback download.

R1.13 stages exactly one Windows AMD64 `isar.dll` from the `isar_flutter_libs` package selected by `.dart_tool/package_config.json`, verifies the exact lockfile version and archive SHA-256, records DLL custody, sets `CRM_ISAR_CORE_PATH`, sets `CRM_ISAR_CORE_REQUIRED=1`, and disables network fallback.

### C. Valid guardrail exposing old ownership debt — one failure covering five sites

Five dialog controllers were created as caller-owned locals. Although the former code disposed them after dialog completion, it violated the repository's explicit State/private-owner lifecycle rule.

R1.13 converts the three affected dialog surfaces to `StatefulWidget` owners with private controller fields and deterministic `dispose()`.

### D. Stale or structurally brittle tests — six failures

R1.13 corrects the tests without weakening governed intent:

- async marker matching is whitespace-tolerant and recognizes the current command-controller assignment architecture;
- the `ref.listen` scanner handles arrow-bodied `build` methods instead of crashing on them;
- the Rules test accepts only semantically equivalent explicit fail-closed write denial forms;
- the lane test recognizes all seven governed lanes and explicitly proves `shared` is generated and delegated;
- the Stage-2D security test agrees with the lockfile and v4.2 audit authority at `protobufjs 7.6.5`.

## Release disposition

R1.12 remains `FAIL_LOCAL_LAB`. R1.13 is a bounded correction candidate only. It cannot claim Flutter-test, APK, emulator or device authority until the complete authoritative Windows laboratory is rerun from a pristine R1.13 archive.
