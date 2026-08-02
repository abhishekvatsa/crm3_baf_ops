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

## Staging Tranche Update - 2026-08-02

The bounded staging backend tranche is now proven at exact deployment source
`6366a415f23ed2f5d31aa22d8401186b27062d2e`. The isolated staging project has
51 ready indexes, byte-exact current Rules and only the two required global-pull
Functions under separate least-privilege runtime identities. A synthetic live
write was server-stamped and settled without recursive rewrites; an
unauthenticated callable request reached the handler and failed closed.

At that staging-tranche checkpoint, this progress did not change the controlled
stop above. Authentication and client parity, the full staging walkthrough,
the production restore pack, production deployment, backfill, contract
activation and the private backend readiness receipt remained required. See
`BUILD6_F4_STAGING_BACKEND_TRANCHE.md` and
`release/evidence/build-6-f4-staging-backend-tranche.json`.

## Production Restore-Pack Update - 2026-08-02

The private production restore pack is now sealed and independently verified
at exact source commit `f604c5e1966fc40f4ddd5d4eb75e483d807435eb` after
post-merge `release-gate` run `30747352624`. Its privacy-safe receipt is
`release/evidence/production-prelive-restore-pack-seal.json`.

This satisfies the restore-pack prerequisite only.
The seal does not change the controlled stop: it does not authorize a
production backend mutation, activate the runtime contract, resume the device
campaign, close `STAGE2D-F4` or `P-07`, authorize pilot handout, or adjudicate
held PRs #87 through #93. The controlled stop remains in force until the other
requirements above are proven in their required order.
