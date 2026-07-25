# CRM3 App v4.2_R1.15 — Changed Files

## Test-contract correction

- `test/maintenance_lifecycle_replay_contract_test.dart`
  - removes the superseded four-allow expectation;
  - requires exactly one maintenance update allow;
  - proves routing through `validMaintenanceUpdate()`;
  - proves all four governed lifecycle validators remain reachable without a parallel OR chain.

## Laboratory and audit identity

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
- `tools/v4/r1_15_targeted_static_audit.py` — new
- `tools/v4/v4_2_r1_canonical_audit.py`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.md`
- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
- `docs/v4_2_r1/R1_14_FLUTTER_CONTRACT_FAILURE_ADJUDICATION.md` — new
- `docs/v4_2_r1/R1_15_MAINTENANCE_ROUTER_CONTRACT_CORRECTION.md` — new
- `README.md`

## Product-source boundary

`firestore.rules`, `lib/`, `functions/`, dependency locks, Firebase configuration and Android/release authority are unchanged from R1.14.

## Sealing records

The R1.15 patch, static-validation log, reconstruction proof, final-verification record and manifest are generated after source checks.
