# Build 6 F4 Staging Backend Tranche

Status: PASSED BOUNDED STAGING TRANCHE

## Decision

An isolated Firebase project, `crm3-baf-ops-staging`, now carries the exact
repository Firestore Rules, all 51 source-defined indexes and only the two
global-pull Functions required for the backend-readiness rehearsal.

This is not `PASS_BUILD6_F4_BACKEND_READY`. It does not close `STAGE2D-F4`,
authorize pilot handout or permit the held PRs `#87` through `#93` to merge.

The exact machine-readable receipt is
`release/evidence/build-6-f4-staging-backend-tranche.json`.

## Exact Readback

- deployment source: `6366a415f23ed2f5d31aa22d8401186b27062d2e`;
- Firestore database: native `(default)` in `asia-south1`;
- indexes: 51 source, 51 deployed, 51 `READY`;
- active Rules SHA-256:
  `1A575F795DE66A34BF9F0C8562569CA7F4257747263929351607D26DC10DB7DF`;
- Rules content: exact to repository, including length;
- active Functions: `beginGlobalPullRun` and
  `stampGlobalPullServerClock`, both Gen2 Node.js 22 in `asia-south1`;
- callable runtime identity: staging reader account with only Datastore Viewer
  and Logs Writer;
- trigger runtime identity: staging writer account with Datastore User,
  Eventarc Event Receiver, Cloud Run Invoker and Logs Writer;
- trigger filter: `(default)` database and namespace with top-level
  `{collectionId}/{documentId}` documents;
- trigger retry: enabled;
- runtime contract `runtime_contracts/global_pull_v1`: absent by design;
- App Check mutation parameter: explicitly `false` under the existing governed
  deferral.

Production retained its prior seven-function inventory and contains neither
global-pull Function. No production Rules, indexes, IAM or data were mutated.

## Runtime Proof

The staging-only record
`maintenance_records/codex-staging-clock-smoke-v1` was created with a client
timestamp. The deployed trigger added `_globalPullServerUpdatedAt` roughly two
seconds later. A read after 20 seconds showed the same document update time and
stamp, proving that the stamp-only follow-up event settled without recursion.

An unauthenticated callable request returned HTTP 401. Cloud Run policy allows
callable traffic, and logs show that callable verification passed, so the 401
was produced on the application authorization path rather than at ingress.

The synthetic record is retained and visibly labelled as staging evidence.

## Deployment Incidents

The final state was not inferred from CLI process codes. Four first-use issues
were observed and independently adjudicated:

1. Non-interactive parameter resolution stopped twice before any Function was
   created. A temporary staging dotenv file supplied the non-secret `false`
   value and was removed after deployment.
2. The CLI required explicit acknowledgement of the source-defined trigger
   retry policy. Source and tests established at-least-once safety before the
   retry policy was accepted.
3. Initial Gen2 source-bucket creation and Eventarc service-agent propagation
   raced. The official role was already present, so no broader IAM grant was
   added.
4. The trigger build raced creation of the shared artifact repository. The
   callable became active, while the trigger left a failed placeholder with no
   Cloud Run service or Eventarc trigger. Only that failed staging placeholder
   was deleted; the trigger was then recreated successfully.

The final cloud inventory, not the deploy banner, is the authority for this
tranche.

## Still Open

Full Stage B still requires Google authentication-provider parity, a
staging-specific client configuration with a visible staging identity,
synthetic users for the governed role matrix and the complete staging workflow
walkthrough.

Production readiness still requires the sealed restore pack, exact production
deployment, legacy-client compatibility proof, zero-gap global-pull inventory
and backfill, runtime-contract activation and a private
`PASS_BUILD6_F4_BACKEND_READY` receipt. Device sync/network phases remain
stopped until those conditions are met.
