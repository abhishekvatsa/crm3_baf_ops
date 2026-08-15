# Governed Planned-Work Asset Assignment

## Purpose

Published planned work is assigned to a registered physical asset rather than
to a freely typed number. The assignment screen resolves the physical route
from the immutable published template snapshot, presents only eligible active
assets and sends the selected asset class and instance identities to the
server-authoritative callable.

## Selection Rules

- Legacy Furnace, Base and Forced Cooler templates require one
  unique active asset class carrying the corresponding legacy mapping.
- A published definition-scope hierarchy reference must agree with that class.
- An installed-component template is locked to its frozen asset instance.
- Governed custom work requires its published hierarchy class and cannot fall
  back to a legacy type-and-number lookup.
- Duplicate active legacy class mappings fail closed because legacy equipment
  projections still use type-and-number document paths.
- Retired, deleted, wrong-class and wrong-number asset records are excluded.

The client submits `assetClassId` and `assetInstanceId` together. A partial
identity is invalid. The callable re-reads the class, physical asset and
published snapshot inside the assignment transaction before any write.

## Inner Cover Route

Inner Cover work remains visible as Inner Cover work, while the operational
selection is the Base currently carrying it:

- the selector uses the unique active Base class;
- only active Bases with a current governed Inner Cover assignment are shown;
- the linked serial number is displayed beside the Base;
- the callable verifies both the Base assignment and reverse Inner Cover
  profile;
- the serial, linkage ID and assignment version are frozen in execution
  metadata and the maintenance workflow; and
- a concurrent unlink, swap or version change aborts the transaction without
  writes.

This prevents work recorded against Base 201 from later being attributed to a
different Inner Cover merely because the physical linkage changed.

## Persistence And Reporting

New exact assignments carry the governed class and instance identity in the
execution, modules, workflow and equipment projection. Existing complete
legacy projections may be upgraded only when the active legacy class mapping
is unique. Partially populated or contradictory projection identities fail
closed.

Operations reporting prefers the exact assignment identity, then the frozen
template hierarchy reference, and uses the legacy map only for historical
records. Inner Cover planned work is therefore grouped by the selected Base
position while retaining the frozen cover serial in assignment evidence.

## Compatibility And Cutover

Requests from an older installed client that omit both governed identity fields
retain their historical fingerprint and legacy non-custom assignment path.
This avoids invalidating existing request receipts during a staged release.
Updated clients include both fields and use the exact path. Governed custom
assignments remain strict and always require published hierarchy identity.

Server deployment may precede client distribution because the new fields are
optional only for the retained legacy compatibility path. Requiring exact
identity for every non-custom request is a later cutover decision after old
clients have been retired. This source increment does not itself deploy the
callable or authorize a production release.

The separate local legacy-template assignment screen was subsequently migrated
under `GOVERNED_LEGACY_TEMPLATE_ASSIGNMENT_MIGRATION.md`. It now shares the
governed selector and its command derives template and asset facts from current
server state. Historical records retain their documented legacy fallback.

## Verification Boundary

Regression coverage includes deterministic route resolution, duplicate mapping
rejection, fixed-instance restriction, request identity and fingerprint
contracts, physical registry validation, legacy projection upgrade, partial
projection rejection, Inner Cover linkage verification, concurrent cover swap
rejection, strict persisted metadata decoding and governed report attribution.
