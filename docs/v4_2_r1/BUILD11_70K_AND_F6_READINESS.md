# Build 11 70K Closure and F6 Readiness

## Decision

Build 11 closes `P-06` and `70K-RECOVERY` with exact source, CI, signed-artifact,
two-target in-place upgrade, installed-store provenance, restart, recovery-package
and cloud-reconciliation evidence.

`STAGE2D-F6` remains `OPEN`. Its complete operational pack is ready, but pilot
handout remains `NOT_AUTHORIZED` until the current `LR-07` re-arm is closed by
exact artifact containment and a fresh strict readback from admitted main.

## 70K Evidence

The physical Android target was upgraded in place from Build 9 and retained two
existing rows. The Android virtual target was upgraded in place from Build 8.
Neither target was uninstalled or cleared. Package UID, first-install time and
app data remained present on both targets.

Both targets then reported:

- a `COMMITTED` canonical provenance marker at schema 3;
- a recognized source fingerprint;
- `EXISTING_STORE_CANONICAL_CURRENT` classification;
- stable database generation across restart;
- zero unsynced rows and zero unresolved synchronization rejections;
- successful reconnect synchronization; and
- successful app-native recovery-package creation with two database files.

The native 70K suite passed 21 tests. It includes a populated repository-proven
v1-to-v3 migration with row and relationship checks, fail-closed unrecognized v2
handling, interruption and restart across every PREPARED/open/repair/COMMITTED
boundary, byte-sealed backup/restore, and generation rotation on rebuild.

The exact closure record is
`release/evidence/70k-local-database-recovery-closure.json`.

## Build 11 Boundary

Build 11 was built from admitted main commit
`ca65d3deead23cccdf07ca24255bc073221d84db`, independently verified, finalized,
written to two distinct custody volumes, and represented by the remote built tag
`crm3-build-built/11`. Its governed package SHA-256 is
`104D5ADA33244CCC9090C31A72FBF167F4D69699C93EDD75FA3F6AAB6D99D970`.

This is artifact and runtime authority, not distribution authority. Build 10's
failed finalization receipt remains mandatory historical evidence and is not
replaced or hidden by Build 11's successful completion.

## F6 Readiness

The F6 pack records all seven required categories:

1. support owner and backup custodian;
2. explicit stop conditions;
3. a privacy-minimized device inventory;
4. local and Firestore backup/restore authority;
5. diagnostic and evidence privacy boundaries;
6. incident containment and rollback paths; and
7. an ordered pilot acceptance script.

The pack's decision is `READY_AWAITING_LR07_CONTAINMENT`. It deliberately does
not transition F6 to `PILOT_AUTHORIZED` or `CLOSED` while any current production
workflow artifact remains live or the new strict LR-07 readback is absent.

## Remaining Sequence

1. Merge this source-and-readiness tranche with exact-head and admitted-main CI.
2. From clean admitted main, delete only the exact Builds 9, 10 and 11 Actions
   artifacts under the existing owner authorization, preserving runs, logs, tags
   and repository visibility.
3. Run the strict LR-07 collector and seal the zero-artifact readback.
4. Adjudicate LR-07 and F6 together. Any failed acceptance or stop condition
   leaves pilot handout unauthorized.
