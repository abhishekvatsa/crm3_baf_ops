# CRM3 v4.2_R1.10 evidence adjudication

## Evidence custody

Submitted evidence package:

`CRM3_V42_R1_10_CANONICAL_LOCAL_LAB_20260722_233114.zip`

Verified SHA-256:

`8F2E3B61F9A495F60543FDE9E98C4EAFC61867DCF0D90833B83AF3B71286869B`

The package sidecar and recalculated digest matched exactly.

## Proven execution

The Windows laboratory passed stages 01 through 21. This includes dependency custody, Functions typecheck, Firebase CLI policy/install/load/audit, Flutter dependency resolution, authentic Isar code generation, post-codegen custody, semantic Isar continuity, Isar release authority, the v4.2_R1 audit and the v4.2 audit.

Stage 22 (`v4_1_due_diligence_audit.py`) did not report a substantive audit failure. It crashed while Python 3.13 on Windows decoded UTF-8 `firestore.rules` using the locale codec `cp1252`:

`UnicodeDecodeError: 'charmap' codec can't decode byte 0x8f in position 9599`

The surrounding bytes encode the UTF-8 sequence for the variation selector in the `⚙️` section heading. The script used bare `Path.read_text()` calls and therefore inherited the machine locale.

## Adjudication

- Application-source defect: **not established**.
- Rules defect: **not established**.
- Audit-tool portability defect: **established**.
- Repository/Firebase/device mutation: **none**.
- Required correction: make all Python text-file tooling explicitly UTF-8 and add a regression gate against implicit locale-dependent text I/O.

No application behaviour, schema, Rules, dependency or deployment authority needs to change for this finding.
