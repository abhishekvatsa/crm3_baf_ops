# CRM3 App v4.2_R1.14 — Changed Files

## Product and Rules correction

- `firestore.rules`
  - single maintenance update router;
  - status-routed template, directive, module-registry and job-module transitions;
  - full approved-user shape remains mandatory;
  - one cached module-family `getAfter` per revision publication.
- `lib/features/planned_maintenance/providers/job_module_provider.dart`
  - direct submit/accept/not-applicable persist `isOpenForWork: false`;
  - direct reopen persists `isOpenForWork: true`.

## Test correction and regression guards

- `test/job_module_rules.test.js`
- `test/firestore.rules.test.js`
- `test/job_module_lifecycle_replay_contract_test.dart`
- `test/firestore_rules_expression_budget_contract_test.dart` — new

## Laboratory and audit correction

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
- `tools/v4/r1_14_targeted_static_audit.py` — new
- `tools/v4/v4_2_r1_canonical_audit.py`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.md`
- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
- `docs/v4_2_r1/R1_13_RULES_EMULATOR_FAILURE_ADJUDICATION.md` — new
- `README.md`

## Handoff and sealing records

The R1.14 patch, validation log, reconstruction proof, final verification and package manifest are generated after all source checks complete.
