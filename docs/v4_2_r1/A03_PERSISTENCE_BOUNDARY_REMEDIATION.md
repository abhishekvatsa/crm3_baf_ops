# A-03 Persistence Boundary Remediation

Status: CLOSED

Programme adjudication: `FINDING:A-03` is closed as of 17 August 2026 by
`PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE`.

## Exact Inventory

`tools/v4/a03_persistence_boundary_inventory.dart` parses every non-generated
Dart library under `lib/` with the analyzer AST. It discovers Firestore and
Isar handles, groups concrete persistence sites by owning operation, and
classifies each operation by store and read, mutation, or lifecycle mode.

The source-implemented inventory contains 484 operations and 1,548 concrete
sites across 44 files. Its stable digest is
`7923E15F9D3DBCD24C84FEBFD053A9056843E64D0BDDA2A484CDFBD826E3B92A`.

Post-closure re-arms on 20-21 August 2026 classified the read-only
`asset_availability_current`, furnace stuck-up/condition, frequent-issue,
maintenance-intelligence, and inspection-programme surfaces under existing
read/repository profiles. A subsequent review correction added the exact remote
maintenance-lifecycle replay readback under the existing repository surface.
This P1 correction also adds atomic local adoption of that verified receipt so
the rebased server version is stored before the row is marked synchronized.
A further cross-business alignment pass adds exact lost-response convergence,
server-timestamp receipt adoption for knowledge rows, and an explicit
ordinary-user server recheck for held records that neither changes nor deletes
source evidence. A late review correction now retains that hold through failed
or uncertain rechecks and resolves it only after authoritative remote
acceptance or exact readback for the same record. The 23 August
reporting-completeness correction also classifies one additional read-only
quality-monitoring query and binds its focused regression. The issue multi-lane
workflow re-arm classifies its additional local reconciliation sites under the
existing maintenance repository boundary. Strict server-readback adoption for
planned executions, runtime modules and charge abnormalities adds two further
compare-and-apply operations under their existing repository adapters. The
event-link authority correction makes three read streams auto-dispose when
their last authorized listener leaves and keys every live cache to the approved
actor UID, including direct approved-account switches; operation and surface
counts do not change, while explicit metadata-aware subscriptions add
three scanned sites and constructor lifecycle plus session scope remain part of
the exact digest. The burner-round report adds one metadata-aware read operation
under its already classified provider surface. Cache-origin snapshots are
admitted only after the same
continuous approved actor and exact query have received server confirmation;
loading, error, revocation, sign-out, or UID change clears that in-memory
trust, while a confirmed same-actor query remains usable offline. The current
actor-scoped compliance lookup now obtains each record through a server-only
point read and permits offline fallback only from an exact record proved during
the same continuous approved-actor session. The cross-device workflow-freshness
correction adds bounded active workflow, lane, and compliance listeners under
the existing live-sync service surface; server-confirmed stale-projection
reconciliation preserves unsynchronized local work and introduces no
presentation-owned persistence. Immediate cross-business synchronization now
classifies pending-write observation, bounded strict remote mirrors, and
account-owned local recovery under three explicit service surfaces. The
recovery service also owns exact, Admin-receipted local tombstone removal;
presentation still owns no persistence. Exact-device administrator recovery adds
one separately classified, regression-covered service that backs up and clears
only the authorized installation's local store before its fresh synchronization;
the administrator screen never owns database access. The manifest refresh
also classifies the critical-alarm repository and provider as remote-read-only
surfaces. Alarm lifecycle commands remain online-only callable operations and
alarm state is deliberately never persisted to Isar; the unbounded active feed
is separate from the bounded recent-history feed so historical volume cannot
displace an active emergency. It preserves every previously registered feature
regression instead of replacing named coverage with a generic test. The
seven-day operational retention stream for closed quality-monitoring requests
adds two read-only stream operations under the already classified quality
provider; the complete reporting provider continues to retain full history.
The current manifest therefore covers 549 operations and 1,899 sites across 57
surfaces with digest
`9611BC81E6650378D6C991C13D986D8344ECE22CF1A2237CE18F412450D93DC6`;
the original closure evidence remains preserved as historical source and CI
proof.
The governed policy is `governance/a03-persistence-boundaries-v1.json`.

The audit fails when the operation digest changes, a persistence-owning file is
unclassified, declared stores or access modes drift, presentation or widget
code gains direct persistence, a mutation is not repository/service owned, a
cross-source path is not repository/service owned, a diagnostic adapter becomes
mutating, or named regression coverage is absent.

## Removed Presentation Access

Five user-facing boundaries were corrected:

- user roster Firestore streaming is owned by `UserDirectoryRepository`, with
  Admin authorization enforced by `UserDirectoryReadService` before the read;
- closed-ticket pagination is owned by `MaintenanceRepository` and
  `ClosedTicketHistoryService`; the Firestore cursor is returned by the same
  page query and is opaque to the screen;
- published-template correction harvesting is owned by
  `KnowledgeCorrectionSourceRepository`, with Admin/SI authorization before
  the remote query;
- sync-rejection reads and local resolution transactions are owned by
  `SyncRejectionService`, which rejects unauthorized mutation before looking up
  the local database;
- Local Diagnostics performs its Admin/SI check before invoking the registered
  `LocalDiagnosticsReadAdapter`; that adapter is privacy-safe, Isar-only, and
  read-only.

No file under a presentation or widget directory now owns direct Firestore or
Isar access.

## Behavioral Preservation

The extracted boundaries retain the existing loading, error, web/offline,
refresh, paging, and denial states. Focused tests prove authorization precedes
the user roster, closed-history, template-correction, and sync-rejection store
access. The diagnostics adapter retains provenance and collection-count output
without acquiring sync, reset, delete, or clean-state behavior.

The A-02 inventory was updated because its three explicit A-03 carryover
hotspots ceased to be mixed-responsibility hotspots after this extraction.
A-02 remains closed and its current machine inventory passes.

## Boundary

PR #234 exact green head `af14218f5281cb210bda5382fbedc5eaa2ca27e8`
merged as `829c87ee07de43846f1d6b5e6d0b1879a3801d93` with identical
tree `0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff`. Exact-head run
`32042648071` and admitted-main run `32043979797` passed all five governed
jobs. The closure is sealed in
`release/evidence/a03-persistence-boundary-source-and-ci-closure.json`.

This closure changes source architecture and evidence only. It performs no
Firebase deployment, production data read or mutation, local data migration,
device validation, distribution action, pilot authorization, or cutover
authorization. Its three ledger re-arm triggers remain binding.
