# CRM3 App v4 — Independent Patch Reconstruction Proof

## Baseline authority

- Baseline package: v3.3 expanded implementation candidate
- Baseline Git commit: `deba971729d2787834b818b6585b82285639d463`
- Baseline label: `Baseline v3.3 expanded implementation`

## Reconstruction method

1. Created a detached worktree at the exact baseline commit.
2. Generated the complete binary-safe v3.3→v4 patch from the active v4 tree.
3. Ran `git apply --check` against the untouched baseline.
4. Applied the patch.
5. Compared every changed or newly created file against the active v4 tree.
6. Regenerated policy outputs and verified byte stability.
7. Re-ran source audits, structural persistence checks and the complete available Functions suite on the reconstructed tree.

## Results

- Patch applies cleanly: **PASS**
- Changed/new files reconstructed: **91**
- Byte comparison: **91/91 identical**
- v4 whole-app reconciliation audit: **21/21 PASS**
- inherited v3.2 full-tree audit: **18/18 PASS**
- inherited v3.3 expanded audit: **15/15 PASS**
- Dart structural audit: **PASS across 367 files**
- Isar source-structure verification: **PASS**
- Isar release authority: **EXPECTED FAIL-CLOSED** because 13 provisional bindings remain
- policy generation: **byte-stable**
- TypeScript strict compile: **PASS**
- Functions tests: **207 passed, 29 emulator-dependent skipped**

## Boundary

This proves that the delivered patch reconstructs the source candidate exactly. It does **not** substitute for pinned Flutter/Isar code generation, Flutter analysis, emulator execution, Android build, physical-device proof or production deployment.
