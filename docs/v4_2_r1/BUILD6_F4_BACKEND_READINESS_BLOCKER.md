# Build 6 F4 Backend Readiness Blocker

Status: CONTROLLED STOP

## Finding

The exact Build 6 physical-device campaign reached the authenticated manual
sync operation but did not complete it. Privacy-minimized lifecycle evidence
classified the server response as `firebase_functions/not-found`.

Read-only production readback established that this is not a device, router or
UI defect:

- production exposes 7 Functions while current source exports 14;
- `beginGlobalPullRun` and `stampGlobalPullServerClock` are absent;
- active Firestore Rules exactly match commit
  `f8308c99e0fbf836a550e50e01d9ff93d4587111`, not current `main`;
- live Firestore indexes exactly match commit
  `33f599d90d3ff1057c3c8dd90f2b0d5f9ee941b7`, with 28 live indexes versus
  51 in current source;
- Firestore PITR and delete protection are disabled.

Stale Rules do not cause a Functions `not-found` response. They are an
independent deployment gap that must be handled in the same backend-readiness
campaign so F4 proves the admitted system rather than a mixed deployment.

## Safety Decision

No further `RunSyncMarker`, `RunOfflineReconnect` or `RunWeakNetwork` phase is
permitted until an append-only `backendReadinessActivationAmendment` binds an
exact private readiness receipt with decision
`PASS_BUILD6_F4_BACKEND_READY`.

The receipt must prove current-source Rules and index parity, the required F4
Functions active, the global-pull runtime contract active, and a fresh
zero-gap inventory. The device harness verifies that receipt before contacting
the physical target.

## Required Order

1. Admit an exact backend deployment and migration promotion with rollback.
2. Reconcile every data prerequisite imposed by current Rules and governed
   callable contracts.
3. Deploy the global-pull stamp trigger and compatible Rules/indexes/callable
   surface while the runtime contract remains absent.
4. Prove legacy-client write compatibility.
5. Run the read-only global-pull stamp inventory and adjudicate malformed
   values.
6. Backfill under the active stamp trigger and seal a zero-gap receipt.
7. Activate the exact runtime contract.
8. Capture and bind the read-only backend-readiness receipt.
9. Resume the physical F4 sync/network phases.

Deploying only `beginGlobalPullRun` is insufficient: the callable deliberately
fails closed until the exact runtime contract and backfill evidence exist.
Deploying all current Functions wholesale is also not authorized by this
record because it would activate additional mutation surfaces and retain the
known runtime-IAM blocker without a separately reviewed scope decision.

## Boundary

This record and harness correction perform no Firebase deployment, Rules
mutation, Functions mutation, IAM mutation, production-data write, device
network mutation, pilot handout or F4 closure. The stopped device attempt is
not a pass and may not be relabelled as one.
