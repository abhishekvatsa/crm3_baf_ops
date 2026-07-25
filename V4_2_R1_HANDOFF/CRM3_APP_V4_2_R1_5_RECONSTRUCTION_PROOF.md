# v4.2_R1.5 Reconstruction Proof

The exact patch `CRM3_APP_V4_2_R1_4_TO_R1_5_LOCK_POLICY_PARSER_HOTFIX.patch` was applied to a fresh copy of the sealed R1.4 candidate.

The following reconstructed paths matched the R1.5 working candidate byte-for-byte:

- `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
- `tools/v4/v4_2_r1_canonical_audit.py`
- `docs/v4_2_r1/AUTHORITATIVE_LOCAL_LAB_RUNBOOK.md`
- the three R1.5 hotfix/validation/change handoff records.

The R1.4 → R1.5 executable laboratory delta is therefore independently reconstructible from the supplied patch. Final verification, this reconstruction proof and the package SHA manifest are sealing artifacts added after patch reconstruction.
