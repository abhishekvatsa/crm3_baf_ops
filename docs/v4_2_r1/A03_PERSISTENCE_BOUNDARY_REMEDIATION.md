# A-03 Persistence Boundary Remediation

Status: SOURCE_IMPLEMENTED

Programme adjudication: `FINDING:A-03` is source-implemented as of 17 August
2026. Closure remains contingent on exact-head pull-request CI, merge with an
identical source tree, and admitted-main post-merge CI.

## Exact Inventory

`tools/v4/a03_persistence_boundary_inventory.dart` parses every non-generated
Dart library under `lib/` with the analyzer AST. It discovers Firestore and
Isar handles, groups concrete persistence sites by owning operation, and
classifies each operation by store and read, mutation, or lifecycle mode.

The source-implemented inventory contains 484 operations and 1,548 concrete
sites across 44 files. Its stable digest is
`7923E15F9D3DBCD24C84FEBFD053A9056843E64D0BDDA2A484CDFBD826E3B92A`.
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

This tranche changes source architecture and tests only. It performs no
Firebase deployment, production data read or mutation, local data migration,
device validation, distribution action, pilot authorization, or cutover
authorization. A-04 remains independent and open.
