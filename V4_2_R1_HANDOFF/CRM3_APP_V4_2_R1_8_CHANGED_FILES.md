# v4.2_R1.8 Changed Files

Compared with v4.2_R1.7:

1. `tools/isar/verify_canonical_main_isar_continuity.py`
   - replaces numeric-position identity enforcement with semantic continuity;
   - records generated position changes explicitly.

2. `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
   - advances evidence naming/banner to R1.8;
   - renames stage 18 to `18_canonical_isar_semantic_continuity`;
   - writes `isar-semantic-continuity.json`.

3. `tools/v4/v4_2_r1_canonical_audit.py`
   - audits the corrected continuity contract and rejects regression to the old full-definition comparison.

4. `docs/v4_2_r1/CLEAN_CUTOVER_AND_ROLLBACK_POLICY.md`
   - separates clean-cutover policy from generated property-position reporting.

5. `tools/v4/v4_2_ultimate_audit.py`
   - stops presenting historical provisional property positions as current codegen identity;
   - retains the no-removal historical evidence check.

6. R1.8 handoff records, clean-cutover clarification and manifest.
