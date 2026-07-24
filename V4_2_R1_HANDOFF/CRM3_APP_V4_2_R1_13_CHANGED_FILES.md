# CRM3 App v4.2_R1.13 — Changed Files

## Product correction

- `lib/core/services/sync_service.job_modules.dart`

## Dialog ownership corrections

- `lib/features/maintenance_workflow/presentation/screens/compliance_detail_screen.dart`
- `lib/features/maintenance_workflow/presentation/widgets/planned_job_workflow_panel.dart`
- `lib/features/maintenance_workflow/presentation/widgets/raise_compliance_dialog.dart`

## Contract-test corrections

- `test/async_mounted_context_safety_contract_test.dart`
- `test/job_module_lifecycle_replay_contract_test.dart`
- `test/lifecycle_static_guardrail_contract_test.dart`
- `test/maintenance_workflow/firestore_rules_online_only_contract_test.dart`
- `test/maintenance_workflow/maintenance_lane_policy_test.dart`
- `test/stage2d_source_security_contract_test.dart`

## Hermetic Isar test custody

- `tool/test_support/test_isar_core.dart`
- `tools/isar/stage_governed_test_isar_core.py`
- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`

## Audit, reconciliation and handoff

- `tools/v4/v4_2_r1_canonical_audit.py`
- `tools/v4/r1_13_targeted_static_validation.py`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json`
- `docs/v4_2_r1/R1_12_FLUTTER_TEST_FAILURE_ADJUDICATION.md`
- `docs/v4_2_r1/R1_13_FLUTTER_TEST_AND_REPLAY_CORRECTION.md`
- `README.md`
- R1.13 handoff records, reconstruction patch and SHA manifest

No npm dependency, Dart dependency, lockfile, Firestore Rules, Firestore index, Functions source, Android identity or programme-authority file is intentionally changed.
