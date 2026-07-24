# CRM3 App v4.2_R1 Validation Log

Generated: 22 July 2026

## Inputs

- exact v4.2 source ZIP SHA-256: `51CB0B424009091E2D3C7B1F2FB6274D3FDEDE9B9C1A261192CFEFA2A404C4F2`
- exact v4.2 → v4.2_R1 patch SHA-256: `B3DD3C63F1ADF7A263462F14E884F7342DB54A1A71FBE0EC26A3D4854DADA4DB`
- canonical-main source collector SHA-256: `43A728FB58DC4C3155030BB65009C050158322DB27324E04002C05666A5B7627`
- canonical repository authority: `main @ 633c58bb0d936011e391b42627f8b8f02c510e95`
- canonical tree: `2f547a79e79076c70dd15ae8b85a7ad70c9fa018`

## Active-source validation

| Gate | Result |
|---|---|
| v4.2_R1 canonical-main audit | **20/20 PASS** |
| v4.2 ultimate audit | **17/17 PASS** |
| v4.1 due-diligence audit | **9/9 PASS** |
| whole-app reconciliation audit | **21/21 PASS** |
| inherited full-tree audit | **18/18 PASS** |
| inherited expanded audit | **15/15 PASS** |
| Dart structural audit | **PASS across 369 files** |
| v4 Isar source verifier | **PASS**, 13 provisional bindings retained |
| canonical Isar continuity | **PASS: 16 inherited, 25 actual, 9 new, 0 failures** |
| Firestore integrity-sweep pure tests | **3/3 PASS** |
| Functions TypeScript syntax transpilation | **48/48 PASS** |

Canonical-main reconciliation:

- captured canonical paths: **410**
- byte-identical: **347**
- intentionally successor-modified: **63**
- missing: **0**

## Independent reconstruction

- patch applies cleanly to the exact v4.2 ZIP;
- patch-authored paths: **31**;
- byte-identical against the active R1 source: **31/31**;
- mismatches: **0**;
- the complete static audit family and integrity-sweep tests pass again on the reconstructed tree.

## Environment-limited gates not executed here

The packaging environment does not contain Flutter, Dart or PowerShell. Its Node and Java versions also differ from the pinned authoritative versions:

- available Node: `22.16.0`; pinned: `22.15.0`;
- available npm: `10.9.2`; pinned: `10.9.2`;
- available Java: `21.0.10`; pinned: `21.0.11`;
- Flutter: unavailable;
- Dart: unavailable;
- PowerShell: unavailable.

Consequently, the following are **not claimed** for R1 in this environment:

- authentic `build_runner` generation;
- full TypeScript dependency-aware compilation;
- R1 Functions Jest suite;
- npm registry/audit reproduction;
- `flutter analyze`;
- Flutter tests;
- Android build or APK inspection;
- Firestore/Functions emulator suite;
- fresh-device installation;
- execution of the PowerShell laboratory harness.

The 13 provisional Isar bindings intentionally remain, and the release verifier must continue to refuse release authority until the Windows laboratory replaces them through the pinned generator and passes canonical ID continuity.

## Mutation boundary

No Git repository, local/remote ref, Firebase project, Rules, Functions, indexes, Firestore data, authentication data or Android device was mutated while creating or validating R1.
