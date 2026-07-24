# v4.2_R1.5 Changed Files

## Executable laboratory source

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
  - uses `ConvertFrom-Json -AsHashTable` for npm lockfile parsing;
  - supports both dictionary and object JSON access;
  - removes direct `$lock.packages` access;
  - fails closed on a missing `packages` map;
  - advances evidence naming and banner to R1.5.

## Regression audit and runbook

- `tools/v4/v4_2_r1_canonical_audit.py`
  - requires the empty-key-safe lockfile parser and rejects regression to `$lock.packages`.
- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
  - advances the run command/evidence naming and records the parser boundary.

## Handoff evidence

- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_5_FIREBASE_CLI_LOCK_POLICY_PARSER_HOTFIX.md`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_5_VALIDATION.md`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_5_CHANGED_FILES.md`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_5_FINAL_VERIFICATION.txt`
- `V4_2_R1_HANDOFF/CRM3_APP_V4_2_R1_4_TO_R1_5_LOCK_POLICY_PARSER_HOTFIX.patch`

## Explicitly unchanged

All product source and all dependency declarations/lockfiles are byte-identical to R1.4.
