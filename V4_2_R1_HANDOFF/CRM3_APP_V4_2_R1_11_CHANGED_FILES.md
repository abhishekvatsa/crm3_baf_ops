# CRM3 v4.2_R1.11 changed-file register

Product-source changes: **0**

Tooling changes:

1. `tools/v4/v4_1_due_diligence_audit.py`
   - explicit UTF-8 on all 12 text reads.
2. `tools/v4/whole_app_reconciliation_audit.py`
   - explicit UTF-8 on the remaining tolerant text read.
3. `tools/isar/reconcile_v4_existing_isar.py`
   - explicit UTF-8 on all text reads and writes.
4. `tools/isar/verify_v4_isar_schema.py`
   - explicit UTF-8 on all text reads.
5. `tools/v4/v4_2_r1_canonical_audit.py`
   - AST-based fail-closed check for implicit Python text encoding.
6. `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
   - R1.11 evidence naming/header only.

Handoff additions:

- R1.10 evidence adjudication
- R1.11 correction, validation, runbook, reconstruction and verification records
- exact R1.10-to-R1.11 patch

No dependency, lockfile, application, Rules, model, Android or governance file changed.
