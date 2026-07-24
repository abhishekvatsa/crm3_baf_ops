# CRM3 v4.2_R1.10 reconstruction proof

The exact patch:

`CRM3_APP_V4_2_R1_9_TO_R1_10_POST_CODEGEN_AUDIT_ALIGNMENT.patch`

was applied to a clean extraction of the R1.9 candidate. All 12 paths represented by the patch were then compared byte-for-byte with the R1.10 working tree.

Result:

`PATCH_RECONSTRUCTION: files=12 failures=0`

The package manifest and the patch file itself are custody artifacts generated after reconstruction and are therefore not self-represented by the patch.
