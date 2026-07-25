# v4.2_R1.8 Reconstruction Proof

The exact patch:

`CRM3_APP_V4_2_R1_7_TO_R1_8_ISAR_SEMANTIC_CONTINUITY_HOTFIX.patch`

was applied to a fresh copy of the R1.7 source candidate using `patch -p1`.

Comparison excluded only:

- the self-referential patch file itself;
- the regenerated handoff SHA manifest.

Result:

```text
reconstructed files: 650
target files:        650
missing:               0
extra:                 0
SHA-256 mismatches:    0
```

Therefore the R1.8 source/tool/document delta is exactly reconstructible from R1.7 plus the supplied patch.
