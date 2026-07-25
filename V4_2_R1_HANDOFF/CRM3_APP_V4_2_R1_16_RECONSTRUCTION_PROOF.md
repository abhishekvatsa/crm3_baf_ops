# CRM3 App v4.2_R1.16 — Reconstruction Proof

The patch:

`CRM3_APP_V4_2_R1_15_TO_R1_16_MAINTENANCE_MATCH_PARSER_CORRECTION.patch`

was checked and applied to an independent clean copy of the sealed R1.15 candidate.

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
A1BF5695A6B6EE521645B11953263281A08DC53DA7881951634BAFD6B1F15EE5
```

The patch contains the complete substantive R1.15 → R1.16 parser, laboratory identity, audit, reconciliation, adjudication and runbook delta. It deliberately excludes its own copy and the later-generated static-validation log, reconstruction record, final-verification record and package manifest.
