# CRM3 App v4.2_R1 Independent Reconstruction Proof

## Immutable input

- input: `CRM3_APP_V4_2_ULTIMATE_LOCAL_TRIAL_CANDIDATE.zip`
- SHA-256: `51CB0B424009091E2D3C7B1F2FB6274D3FDEDE9B9C1A261192CFEFA2A404C4F2`

## Applied delta

- patch: `CRM3_APP_V4_2_TO_V4_2_R1_CANONICAL_MAIN_HARDENING.patch`
- SHA-256: `B3DD3C63F1ADF7A263462F14E884F7342DB54A1A71FBE0EC26A3D4854DADA4DB`
- `git apply --check`: **PASS**
- patch application: **PASS**

## Byte comparison

A fresh extraction of the immutable v4.2 ZIP was initialized as a local disposable Git repository, the patch was applied, and every destination path named by the patch was compared against the active v4.2_R1 source.

- patch-authored paths: **31**
- byte-identical: **31/31**
- mismatches: **0**

## Reconstructed-tree validation

The reconstructed tree independently passed:

- v4.2_R1 canonical-main audit: **20/20**;
- v4.2 ultimate audit: **17/17**;
- v4.1 due-diligence audit: **9/9**;
- whole-app audit: **21/21**;
- inherited full-tree audit: **18/18**;
- inherited expanded audit: **15/15**;
- Dart structural audit: **PASS across 369 files**, including `git diff --check`;
- Isar source verifier: **PASS**, with 13 provisional bindings and release authority denied;
- canonical-main Isar continuity: **PASS**;
- Firestore integrity-sweep pure tests: **3/3 PASS**.

## Boundary of the patch

The authored patch deliberately does not self-include final custody products generated after patching, including this proof, the validation log, the package manifest and final ZIP verification. These packaging-only files do not alter application behaviour.
