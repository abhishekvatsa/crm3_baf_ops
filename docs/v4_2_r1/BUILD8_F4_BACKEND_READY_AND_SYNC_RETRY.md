# Build 8 F4 Backend Readiness and Physical Sync Retry

Status: BACKEND READY; ONE EXACT-TARGET SYNC RETRY PROPOSED

## Runtime result

The governed Build 8 production campaign completed from merged commit
`34dd01511ffd0ca4aba37735b6dfd710d2964b46` after release-gate run
`30850203589` passed all four jobs.

The bounded campaign:

- deployed the exact source Firestore Rules;
- redeployed only `beginGlobalPullRun` and `stampGlobalPullServerClock`;
- left all 51 exact, ready indexes unchanged;
- left IAM and App Check unchanged;
- added `_globalPullServerUpdatedAt` only to the 41 records missing it;
- created the one immutable `runtime_contracts/global_pull_v1` contract; and
- retained no document IDs, account identifiers or business payloads.

The final inventory is 42 total, 42 stamped, 0 missing and 0 malformed. Rules,
indexes, both required Functions, their dedicated runtime identities and the
runtime contract all passed exact live readback. The sealed final decision is
`PASS_BUILD8_F4_BACKEND_READY`.

Two initial Rules-validation calls returned service-unavailable before any
cloud mutation. On recovery, the first Rules release succeeded but a local
debug-log lock stopped the Firebase CLI before Function deployment. Repeating
the unchanged idempotent phase confirmed Rules were already exact, deployed
both Functions, and produced the passing post-deploy receipt.

## Build and device state

Build 8 is no longer merely reserved. GitHub Actions run `30839125687` built
and independently verified the production-signed artifact from commit
`731a02980d38e4e3a8f61ff2bca74a1e85771478`. Dual custody and the remote built
tag both passed. Distribution remains unauthorized.

A fresh read-only device check found the exact Build 8 APK still installed on
the one hash-bound Samsung physical target. Version code, APK hash, first
install time, last update time, physical-device properties and the absence of
forbidden authentication markers all matched the proposed promotion.

## Authorized next action

`release/approvals/build-8-f4-physical-sync-retry-promotion.json` authorizes
one ordinary in-app manual sync on the current network state. The harness must
run from clean merged `main`, verify one successful four-job post-merge CI run,
bind the exact package, signer, installed APK, target and backend evidence, and
stop unless local pending business writes are zero.

The retry may launch and navigate the already-installed app. It may not
install, upgrade, clear or uninstall the app; change network state; alter the
authentication session; deploy backend resources; retain raw UI or identity
data; or distribute the artifact.

## Programme boundary

The backend prerequisite is satisfied, but this source tranche does not close
`STAGE2D-F4` or `P-07`. It does not authorize offline/reconnect, weak-network,
revocation or wrong-role phases, pilot handout, or any distribution. A passing
sync receipt must be independently adjudicated before the next device phase.
