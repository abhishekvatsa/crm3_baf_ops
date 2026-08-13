# Asset Operational Condition and Home Overview

Status: SOURCE_IMPLEMENTED

Date: 2026-08-14

## Scope

This tranche adds a governed operational availability lifecycle for physical
assets and exposes the current plant scenario on Home and on a dedicated Plant
Condition board.

It deliberately preserves three different facts:

1. `asset_instances.serviceState` is Admin-controlled master-data lifecycle:
   in service, standby, or out of service.
2. `equipment_status` is the server-derived maintenance workflow projection.
3. `asset_operational_conditions` is the current Operations declaration:
   available, down, or unfit.

These facts may overlap. An asset may be both down and under maintenance. The
overview therefore reports overlapping counts and does not force them into one
exclusive state.

## Authority

- Approved Operations, Shift Supervisor, SI, and Admin users may declare an
  active asset down or unfit.
- Only an approved Shift Supervisor, SI, or Admin may restore availability.
- Contract Supervisors and discipline supervisors use the separate assurance,
  deferment, and Operations-support lifecycle. They do not decide plant
  availability.
- Every approved user may read current asset condition.
- Condition audits are Admin-readable. Mutation receipts remain private.
- All client writes to condition, audit, and receipt collections are denied.

## Integrity

The existing `mutateAssetHierarchy` callable dispatches condition operations
through the shared App Check, runtime identity, and abuse-control boundary.
Each mutation:

- revalidates current actor authority transactionally;
- revalidates the permanent asset identity and active registry status;
- verifies every optional linked issue belongs to the same governed asset;
- requires an exact expected condition version;
- rejects partial or malformed existing condition projections;
- writes current state, immutable before/after audit, and replay receipt in one
  transaction;
- validates condition, audit, and current-state evidence on exact replay.

An administratively out-of-service asset cannot receive a new declaration. An
existing declaration can still be closed after such a master-data change so
that its operational event is not stranded.

## User Experience

Home now shows verified totals for available, under-maintenance, down, and
unfit assets, followed by class summaries. Malformed or unavailable source data
is shown as an error rather than reassuring zero counts.

The Plant Condition board shows each asset's overlapping status badges,
declaration reason and authority, and role-appropriate actions. Declarations
capture one or more causes, a mandatory reason, and optional open issues already
bound to the same governed physical asset.

## Verification

Local verification for this source tranche includes:

- Flutter analysis: clean.
- Focused condition decoder, overview, and Home widget tests: 10 passed.
- Functions condition unit tests: 10 passed.
- Full Functions unit suite: 414 passed, 70 intentionally skipped emulator
  tests.
- Full Flutter suite: 886 passed, 1 intentionally skipped.
- Firestore Rules suite: 164 passed.
- Governed Functions emulator suite: 70 passed.
- A-05 production integrity sweep tests: 15 passed.
- A-05 decoder inventory: 42 surfaces, 23 strict-reader consumer files,
  38 timestamp readers, no unclassified surfaces.

Whole-app source audit: 23/23 passed. Canonical audit: 138/138 passed in
pristine and post-codegen phases. Hosted CI remains required before merge.

## Deployment Boundary

Source merge does not activate this feature in production. Production use
requires coordinated deployment of the updated Function and Firestore Rules,
followed by distribution of a client build containing the condition decoder,
Home overview, and Plant Condition board. No backend deployment, client build,
distribution, device proof, or gate closure is claimed by this source tranche.
