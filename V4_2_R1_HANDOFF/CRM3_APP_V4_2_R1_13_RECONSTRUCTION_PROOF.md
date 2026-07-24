# CRM3 App v4.2_R1.13 — Reconstruction Proof

The patch `CRM3_APP_V4_2_R1_12_TO_R1_13_FLUTTER_TEST_REPLAY_AND_HERMETIC_ISAR_CORRECTION.patch` was checked and applied to an independent copy of the R1.12 candidate.

Result:

- patch SHA-256: `51AA7E8CC770645D74AF72CFC3C7D8E08C63FA1BBF26CCD67C20C57BAC0B98D9`
- patch bytes: `85244`
- patch check: PASS
- patch apply: PASS
- substantive changed/added paths reconstructed: 19
- byte mismatches against the R1.13 working tree: 0
- `git diff --check`: PASS

The patch covers the product, dialog lifecycle, contract-test, Isar-custody, audit, harness, canonical reconciliation and adjudication delta. Generated R1.13 handoff registers, final SHA manifest and the patch itself are produced after reconstruction and are not self-referential patch inputs.
