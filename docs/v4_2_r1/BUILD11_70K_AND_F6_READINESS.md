# Build 11 70K Closure and F6 Readiness

## Decision

Build 11 closes `P-06` and `70K-RECOVERY` with exact source, CI, signed-artifact,
two-target in-place upgrade, installed-store provenance, restart, recovery-package
and cloud-reconciliation evidence.

`STAGE2D-F6` remains `OPEN`. Its complete operational pack is ready. Exact
Builds 9-11 containment and a fresh strict readback from admitted main are now
proved, but pilot handout remains `NOT_AUTHORIZED` until that evidence receives
merged source/CI closure adjudication under `LR-07`.

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

The pack's original decision remains `READY_AWAITING_LR07_CONTAINMENT` because
the evidence record is append-only. Its prerequisite is now satisfied: the
three exact artifact payloads were removed and strict readback found zero live
production artifacts and zero GitHub Releases. F6 deliberately remains open
until the new LR-07 records merge, admitted-main CI passes and a separate final
adjudication authorizes only the sealed small-group pilot.

## Remaining Sequence

1. Merge the Builds 9-11 containment and strict-readback records with exact-head
   CI.
2. Require all five release-gate jobs to pass again on the admitted merge
   commit.
3. Bind that PR and post-merge CI to a separate LR-07 closure adjudication.
4. Only then adjudicate F6 through `PILOT_AUTHORIZED -> CLOSED`. Any failed
   acceptance or stop condition leaves pilot handout unauthorized.
