# Build 11 70K Closure and F6 Readiness

## Decision

Build 11 closes `P-06` and `70K-RECOVERY` with exact source, CI, signed-artifact,
two-target in-place upgrade, installed-store provenance, restart, recovery-package
and cloud-reconciliation evidence.

`STAGE2D-F6` and `LR-07` are now `CLOSED`. PR #201 merged the exact Builds 9-11
containment and strict readback and all five pull-request and post-merge jobs
passed. The separate promotion authorizes only exact governed Build 11 for the
sealed small-group pilot. No handout was performed by the promotion record;
public, Play, web, Firebase App Distribution and unrestricted distribution
remain prohibited.

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

This finalization is artifact and runtime authority, not distribution
authority. The later, separate post-build promotion supplies the bounded pilot
authority without rewriting finalization history. Build 10's failed
finalization receipt remains mandatory historical evidence and is not replaced
or hidden by Build 11's successful completion.

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
the evidence record is append-only. Its prerequisite is satisfied: the three
exact artifact payloads were removed, strict readback found zero live
production artifacts and zero GitHub Releases, PR #201 merged the evidence, and
its five-job pull-request and post-merge runs passed.

The final authority is
`release/evidence/stage2d-f6-build11-controlled-pilot-authorization.json`,
SHA-256
`878897E7DAAF26BF099F3894CAA2EB6719E5F56CED3F7546E8D48E352C4E7400`.
It records `OPEN -> PILOT_AUTHORIZED -> CLOSED` for F6 and
`LIVE_READBACK_PROVED -> CLOSED` for LR-07.

## Execution Boundary

Actual pilot handout is conditional and separate from authorization. Before
each handout, the operator must verify the exact Build 11 package and signer,
freeze the admitted user and physical-device rosters, complete the acceptance
script, and retain a privacy-safe execution receipt. Any failed acceptance or
stop condition re-arms the gate and stops further pilot use.
