# CRM3 v4.2_R1.11 UTF-8 audit-tooling hotfix

## Purpose

R1.11 corrects the Windows locale-dependent Python failure observed in the authenticated R1.10 laboratory. The change is restricted to laboratory and schema-tool text I/O.

## Corrections

1. Every `read_text()` call in `tools/v4/v4_1_due_diligence_audit.py` now specifies `encoding="utf-8"`.
2. The remaining locale-dependent read in `tools/v4/whole_app_reconciliation_audit.py` now specifies UTF-8.
3. All text reads and writes in `tools/isar/reconcile_v4_existing_isar.py` now specify UTF-8.
4. All text reads in `tools/isar/verify_v4_isar_schema.py` now specify UTF-8.
5. The canonical R1 audit now parses every Python file under `tools/` with `ast` and fails if any `Path.read_text()` or `Path.write_text()` call omits an explicit `encoding` keyword.
6. Laboratory evidence naming advances to R1.11.

## Fail-closed invariant

The R1 audit requires:

`Python text-file tooling is locale-independent UTF-8 | implicit=0`

This protects later audits and utilities from the same Windows locale failure class rather than correcting only the first crashing line.

## Deliberately unchanged

- Flutter product source and tests
- Functions product source and tests
- Firestore Rules and indexes
- Isar model declarations and generated bindings
- npm/pub dependencies and lockfiles
- Android/Firebase identity
- governance, programme ledger and deployment authority

The R1.10 execution result remains the evidence authority for stages already passed. R1.11 must still execute the full laboratory from the beginning.
