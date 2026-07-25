# CRM3 v4.2_R1.11 reconstruction proof

The patch:

`CRM3_APP_V4_2_R1_10_TO_R1_11_UTF8_AUDIT_TOOLING_HOTFIX.patch`

was applied to a clean extraction of the R1.10 candidate. The 13 paths represented by the patch were compared byte-for-byte with the R1.11 working tree.

Result:

```text
represented paths: 13
missing paths:      0
byte mismatches:    0
reconstruction:     PASS
```

The patch deliberately does not include its own copy, this reconstruction record or the final file manifest. Those are packaging evidence added after patch construction.
