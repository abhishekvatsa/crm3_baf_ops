# CRM3 App v4.2_R1.14 — Reconstruction Proof

The patch:

`CRM3_APP_V4_2_R1_13_TO_R1_14_RULES_EXPRESSION_BUDGET_AND_ONLINE_OPEN_STATE_CORRECTION.patch`

was checked and applied to an independent clean copy of the sealed R1.13 candidate.

Result:

```text
patch check:                 PASS
patch apply:                 PASS
changed/added paths:         17
missing reconstructed paths: 0
byte mismatches:             0
reconstruction:              PASS
```

Patch SHA-256:

```text
43FFBF97B159CA5EBCE3C2D6C6E5CD6A58B584016AFAC3BADD283832592F2AA7
```

The patch contains the complete substantive R1.13 → R1.14 source, Rules, test, audit, harness, reconciliation and runbook delta. It deliberately excludes its own copy and the later-generated static-validation log, reconstruction record, final-verification record and package manifest.
