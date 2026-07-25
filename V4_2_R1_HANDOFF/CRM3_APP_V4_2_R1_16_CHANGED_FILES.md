# CRM3 App v4.2_R1.16 — Changed Files

## Test-parser correction

- `test/maintenance_lifecycle_replay_contract_test.dart`
  - starts block-brace search after the complete marker;
  - prevents `{docId}` from being treated as the Rules block;
  - preserves the R1.15 single-router assertions unchanged.

## Laboratory and audit identity

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
- `tools/v4/r1_16_targeted_static_audit.py` — new
- `tools/v4/v4_2_r1_canonical_audit.py`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.json`
- `docs/v4_2_r1/CANONICAL_MAIN_RECONCILIATION.md`
- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
- `docs/v4_2_r1/R1_15_MAINTENANCE_MATCH_PARSER_FAILURE_ADJUDICATION.md` — new
- `docs/v4_2_r1/R1_16_MAINTENANCE_MATCH_PARSER_CORRECTION.md` — new
- `README.md`

## Product-source boundary

`firestore.rules`, `lib/`, `functions/`, dependency locks, Firebase configuration and Android/release authority are unchanged from R1.15.

## Sealing records

The R1.16 patch, static-validation log, reconstruction proof, final-verification record and manifest are generated after source checks.
