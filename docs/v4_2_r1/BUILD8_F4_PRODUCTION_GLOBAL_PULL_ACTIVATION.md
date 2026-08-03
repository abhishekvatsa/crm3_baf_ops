# Build 8 F4 Production Global-Pull Activation

Status: SOURCE PROMOTION PROPOSED; LIVE MUTATION REQUIRES MERGE AND CI

## Finding

Build 8 was constructed from merged commit
`731a02980d38e4e3a8f61ff2bca74a1e85771478`, independently finalized,
dual-custodied and installed as an in-place upgrade on the bound Samsung
physical target. Android package, signer, UID, first-install time and app-data
inode continuity all passed. The preserved approved session reached Home.

The next automatic sync contacted `beginGlobalPullRun` successfully and failed
with `firebase_functions/failed-precondition`: the global-pull protocol is not
activated. This supersedes the earlier Build 6 `not-found` diagnosis. The two
global-pull Functions and all 51 indexes are now live; the immutable activation
contract remains absent by design.

The privacy-minimized production inventory observed 42 protocol documents:

- 1 carries a valid Firestore Timestamp watermark;
- 41 have no watermark;
- 0 carry malformed watermarks;
- no document IDs or business payloads were retained.

The migration is therefore small, but it is still a production data mutation
and may not be inferred from the device error alone.

## Authority

The machine-readable promotion is
`release/approvals/build-8-f4-production-backend-activation-promotion.json`.
It becomes effective only after owner-reviewed merge, exact post-merge CI and
execution from tracked-clean `main` equal to freshly fetched `origin/main`.
The harness requires the exact post-merge `release-gate` run ID and verifies a
`push` run at the execution commit with all four jobs successful.

The promotion binds:

- production project `crm3-baf-ops-b8638` and region `asia-south1`;
- the exact protocol fingerprint, complete tracked Functions source/build
  manifest, Firebase deployment configuration and deployment-toolchain hashes;
- the sealed pre-live managed Firestore export and dual private custody;
- a ceiling of 100 observed protocol documents and 50 watermark updates;
- zero tolerance for malformed watermarks;
- the two dedicated least-privilege runtime identities;
- continued App Check deferral.

## Exact Sequence

The governed harness is
`tools/release/Invoke-ProductionGlobalPullActivation.ps1`. Each phase creates
append-only evidence outside the repository and must be run separately.

1. `Preflight` repeats Rules, index, Function, runtime-IAM, contract and
   watermark readback. It performs no cloud mutation.
2. `Deploy` activates the exact source Rules and redeploys only
   `beginGlobalPullRun` and `stampGlobalPullServerClock`. It does not deploy
   indexes or any other Function.
3. `Backfill` adds only missing `_globalPullServerUpdatedAt` values using
   server timestamps and optimistic last-update preconditions. Any malformed
   value stops the phase before writes.
4. `Activate` requires the sealed backfill receipt and a fresh zero-gap
   inventory, creates `runtime_contracts/global_pull_v1` once, and captures a
   read-only `PASS_BUILD8_F4_BACKEND_READY` receipt.

The contract remains absent after any deployment failure or incomplete
backfill. A partially completed backfill is safe to re-inventory and retry
under the same effective promotion because only still-missing fields are
eligible.

## Deliberate Exclusions

This campaign does not deploy the full Function fleet, mutate IAM, alter
indexes, enable App Check, edit business fields, delete documents, perform a
Firestore import, distribute Build 8, or close a programme gate.

PITR and Firestore delete protection remain read-only observations in this
campaign. Enabling them changes production control-plane and cost posture and
requires a separate decision; the sealed managed export is the admitted
rollback prerequisite for this bounded activation.

## Device Continuation

Backend readiness does not itself authorize a device retry. After a passing
readiness receipt is independently summarized in source, a separate Build 8
physical-execution promotion must bind the exact APK, signer, target and
receipt. Only then may the sync-marker, offline/reconnect, weak-network,
revocation and wrong-role phases resume.

`STAGE2D-F4`, `P-07`, pilot handout and external distribution remain open or
not authorized throughout this campaign.
