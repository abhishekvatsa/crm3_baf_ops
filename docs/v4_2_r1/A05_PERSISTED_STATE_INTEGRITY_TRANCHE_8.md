# A-05 Persisted-State Integrity Tranche 8

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche removes local-clock manufacture from the two remote maintenance
ticket readers and makes paginated global pull account for malformed source
documents without committing its maintenance cursor. It does not close `A-05`:
the repository-wide persisted-state inventory, remaining parsers and fallbacks,
durable repair workflow, and governed production/local reconciliation remain
outstanding.

## Source Boundary

The source change establishes these invariants:

1. Remote maintenance `startDate`, `createdAt`, and `updatedAt` are required.
   Missing or malformed values fail closed and are never replaced by device
   time. `updatedAt` no longer silently inherits `createdAt`.
2. Workflow, acknowledgement, end, and deletion timestamps may be absent. A
   present value must be a Firestore `Timestamp`, a `DateTime`, or a parseable
   timestamp string; malformed present values fail closed.
3. Firestore repository and live-listener mapping use one shared timestamp
   decoder. The former private timestamp helpers and arbitrary `toDate()` or
   `toString()` compatibility paths are removed.
4. The reopen path reuses the already strict-decoded ticket and `endDate`; it
   does not perform a second permissive timestamp parse.
5. A paginated maintenance page records source document count separately from
   decoded record count. Each malformed document is counted and quarantined;
   valid siblings remain eligible for local reconciliation.
6. An all-malformed page is not interpreted as end-of-data. Pagination follows
   source cardinality and the source cursor, while any rejection marks the
   maintenance domain unsuccessful.
7. The existing global-pull envelope fails with
   `domain-record-processing-failed` before domain completion, so its cursor
   cannot advance past a quarantined document.

## User-Facing Representation

The live listener already places a decode failure into its error health state.
The shared Sync status panel colors that state as an error and shows the last
live error. Global pull reports a failed run rather than false success. This
tranche preserves those representations and adds no duplicate repair screen.

## Compatibility And Cutover

Firestore `Timestamp`, `DateTime`, and parseable string timestamps remain
accepted. Objects accepted only because they happened to expose `toDate()`, and
arbitrary values previously parsed through `toString()`, are rejected.

Existing records missing one of the three required timestamps need governed
read-only inventory and repair before pilot or cutover. This tranche deliberately
does not guess whether a missing historical value equals another timestamp or
the current device time.

## Verification

Focused regressions cover accepted timestamp representations, missing and
malformed required values, malformed present optional values, shared decoder
use, per-document page accounting, pagination by source cardinality, cursor
non-commit ordering, and existing sync-health UI representation.

Local verification before publication produced:

- focused timestamp and ledger contracts: 11 passed;
- expanded A-05, maintenance, tombstone and global-pull suite: 107 passed;
- `flutter analyze`: no issues;
- complete Flutter suite: 717 passed;
- canonical source and governance audit: 116 of 116 passed;
- whole-app reconciliation source audit: 23 of 23 passed.

Pull-request CI and admitted-main post-merge CI evidence remain required before
this tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for the complete persisted-state parser/fallback inventory,
remaining operational and knowledge-record decoders, durable operator repair,
and governed production and supported-local-generation reconciliation.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, alter PITR, backup, or deletion-protection settings,
produce physical-device evidence, close a programme gate, close `A-05`, or
authorize pilot handout.
