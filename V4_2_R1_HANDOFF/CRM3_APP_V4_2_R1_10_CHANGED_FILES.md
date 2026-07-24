# CRM3 v4.2_R1.10 changed-file register

Product/runtime source changes: **none**.

Changed or added laboratory/handoff files:

1. `tools/v4/v4_2_r1_canonical_audit.py`
   - adds explicit pristine and post-codegen phases;
   - exact-binds all generated outputs in post-codegen phase;
   - continues exact pinning of all non-generated canonical paths.
2. `tools/v4/Invoke-Crm3V42R1CanonicalLocalLab.ps1`
   - invokes stage 20 with `--phase post-codegen`;
   - advances evidence naming to R1.10.
3. `docs/v4_2_r1/AUTHORITATIVE_POST_CODEGEN_BINDINGS.json`
   - exact 19-binding register from authenticated R1.9 execution evidence.
4. `README.md`
   - records the bounded R1.10 audit correction.
5. `V4_2_R1_HANDOFF/*R1_10*` and R1.9 evidence adjudication
   - records scope, validation, runbook and custody.
6. `V4_2_R1_HANDOFF/FILE_SHA256SUMS.txt`
   - regenerated package manifest.
