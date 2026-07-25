# CRM3 App v4.2_R1.15 — Reconstruction Proof

The patch:

`CRM3_APP_V4_2_R1_14_TO_R1_15_MAINTENANCE_ROUTER_CONTRACT_CORRECTION.patch`

was checked and applied to an independent clean copy of the sealed R1.14 candidate.

Result:

```text
patch check:                 PASS
patch apply:                 PASS
changed/added paths:         13
missing reconstructed paths: 0
byte mismatches:             0
reconstruction:              PASS
```

Patch SHA-256:

```text
7905E8DA8F4520DDED62F6A28CE1FD03F8609BC3F13FECF8898254DF9D32210C
```

The patch contains the complete substantive R1.14 → R1.15 test-contract, laboratory identity, audit, reconciliation, adjudication and runbook delta. It deliberately excludes its own copy and the later-generated static-validation log, reconstruction record, final-verification record and package manifest.
