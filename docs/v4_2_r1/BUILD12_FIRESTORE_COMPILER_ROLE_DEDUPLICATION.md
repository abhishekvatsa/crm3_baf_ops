# Build 12 Firestore compiler role-policy deduplication

Date: 2026-08-18

Status: SOURCE AND LOCAL CI PROVED; MERGE AND DEPLOYMENT PENDING

## Finding

Build 12 Rules were behaviorally valid in the Firestore emulator, but Google's
production Rules compiler intermittently returned HTTP 503. Capacity probes
showed that the service accepted a minimal file and historical Rules sources,
while both the active production file and the larger successor file could fail.

The generated workflow authority block emitted the same eleven-branch role
expression twice: once for module work and once for module submission. The
governed policy currently defines those two role maps identically. Evaluating
the duplicate source as a shared helper produced a successful production
compiler response and reduced compiler warnings without changing any role,
discipline, transition or document-access decision.

## Correction

`generate_policy.mjs` now emits the submission helper as a call to the work
helper only when the two policy maps are exactly equal. If the maps later
diverge, the generator emits separate expressions again. Source tests enforce
both the current shared expression and the EMD-specific authority clause.

Six functions with no path from any Firestore `allow` expression were also
removed. This cleanup changes no reachable authorization result.

The corrected Rules source is:

- bytes: `160754`;
- SHA-256: `ED6D3E0A67E7C2353BE0B691594E27EEC230596155EAA4365DDA97EBCDB6D87A`.

## Verification

- workflow policy generation check: pass;
- Functions tests: 516 passed;
- Firestore Rules emulator tests: 175 passed;
- governed asset reconciliation emulator tests: 3 passed;
- governed callable emulator tests: 80 passed;
- canonical audit: 144 passed, 0 failed;
- production compiler probe of the behavior-equivalent deduplicated candidate:
  HTTP 200 with four warnings and no errors.

## Boundary

This tranche performs no Firebase deployment, Firestore document access,
business-data mutation, IAM change, App Check activation, artifact signing,
device installation or distribution. Production deployment still requires
merged exact-head CI followed by byte-exact live readback.
