# Build 28 delegated backend deployment campaign

Status: **reviewable plan; no production command has been executed by this record.**

The owner delegated release-readiness work and necessary approval decisions to
Codex. The bounded decision is recorded in
`release/approvals/build28-backend-deployment-approval.json`. Its time is the
agent's recorded observation and decision time, not an invented user-message
receipt time. Quoted excerpts are explicitly partial. This plan contains no
personal reason for the delegation and no unknown message identifiers.

## Source and purpose

The tested baseline is main commit
`c00c77e2a04a0a79a2bfab6d711e5ad2b59e6d56`, tree
`38a201b1afaf99a71da233448a547b5a8fc05a52`, Functions tree
`33c0659a4370fd438fefa5a7e19f2e377fccaec4`, following merged PR #359.
Its exact-main release gate, run `34276210640`, passed all five required jobs.

The compatible backend carries the reviewed command-outcome, terminal-rejection,
Morning Review completion/capacity and abuse-classification corrections. It must
be deployed and read back before a successor APK depends on the new actor guard
or rejection evidence. Existing client request/response shapes and receipt
fingerprints remain supported. This does not repair the client-side retry,
sync, quality or reporting defects in already installed older binaries.

Build 27 remains the existing signed artifact from `c933ca0a`; none of its
approval, completion, device or pilot receipts is rewritten. No Build 28 number
is reserved and no new APK is claimed by this backend decision.

## Exact authority before execution

First independently review and commit the approval bytes into separately
admitted immutable custody. Extend the shared approval verifier to admit that
fixed custody and the delegated decision's actual meaning, retaining the
historical Build 27 owner and promotion anchors. Tests must reject changed
delegation text, source, scope and chronology even when mutable receipts are
coherently rehashed.

Commit the reviewed approval on the release feature branch, without merging it
into main before deployment. Its immutable custody commit is separate from the
approved execution source. Extend and review the verifier on that feature
branch while preserving the already passed baseline release gate.

Deploy and collect evidence from an isolated clean main checkout at exactly
`c00c77e2a04a0a79a2bfab6d711e5ad2b59e6d56`. Freshly verified `origin/main` and
live remote main must still equal that same commit. Hold the approval and
reconciliation merge until successful backend readback. Record the actual
execution commit/tree and exact-main gate `34276210640`; no descendant or later
artifact-version commit is admitted by this decision. Check remote main before
each deployment cohort and final collection. If it moves, stop and reassess the
source decision instead of relabelling the checkout or bypassing the existing
collectors' clean-main checks.

## Bounded deployment

Target only `crm3-baf-ops-b8638`, region `asia-south1`. Retain the existing 15
Functions, dedicated runtime identities, IAM bindings and
`CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK=false`. The approved scope is:

| Cohort | Exact functions |
| --- | --- |
| Nine callables | `assignPublishedTemplateVersion`, `beginGlobalPullRun`, `completePlannedJobExecution`, `executeMaintenanceWorkflowCommand`, `getBackendReleaseIdentity`, `mutateChargeAbnormality`, `mutateAssetHierarchy`, `mutateRuntimeJobModulePopulation`, `mutateUserAuthority` |
| Five event/protocol triggers | `onJobAssigned`, `onMaintenanceWorkflowEventCreated`, `onTicketCreated`, `onTicketResolved`, `stampGlobalPullServerClock` |
| One scheduled function | `maintenanceWorkflowEscalationSweep` |

1. Capture a fresh read-only preflight outside the repository. Verify source and
   CI identity, the complete live fleet, existing runtime service accounts and
   IAM, App Check posture, unchanged Rules/indexes and a zero aggregate scheduler
   backlog. Do not export business payloads. A nonzero backlog, drift or failed
   readback stops this campaign for a separate assessed decision.
2. Build the exact reviewed Functions source with the repository's locked tools.
   Deploy only the listed Functions through the pinned Firebase CLI, in the
   callable and event cohorts, preserving IAM. Read back each completed cohort
   before proceeding. Any generated configuration must retain App Check false
   and must not overwrite an existing environment file.
3. Deploy the single scheduled Function as an explicit deployment target.
   **Do not manually invoke it.** The existing campaign wrapper's
   `DeployScheduler` phase runs the scheduler; do not use that phase. The
   scheduler's normal configured operation is not evidence of a manually run
   smoke test and must not be described as one.
4. Run the read-only final fleet, IAM/dependency and Firestore Rules/index
   collectors directly. Do not use the legacy `Finalize` phase, which contains
   IAM-removal operations. Require exact source runtime hashes, timestamps after
   the delegated decision, all 15 identities, valid triggers and callable
   contracts, preserved IAM/App Check, exact source dependency inventories and
   no failed checks.
   Callable probes send an unauthenticated empty request and must receive a
   protocol rejection without returned data. They can target mutation endpoints
   only behind their authentication fence; they do not submit authenticated
   business commands. Normal access/error logs may be emitted.
5. Repeat the aggregate backlog readback. Record actual observations and any
   operational change; do not infer zero business changes merely from the lack
   of a manual invocation. No business mutation or scheduler smoke result is
   fabricated to satisfy a receipt predicate. If unexpected work or a deployment
   error appears, stop further campaign steps and assess it with the retained
   evidence; no automatic rollback, IAM change or data repair is authorized here.

Firestore Rules must remain SHA-256
`823877B9B03F8D4E2687532615F5037A9742F3AA224AE209BC2C7A866F845E04`.
The unchanged 66-index set must remain SHA-256
`E58BEAEF69212C4B00035C120F345D25F962588EE84ACC6D88363CD5EE2D95A4`.
Read them back; do not redeploy them.

## Existing read-only commands

Run these from the admitted clean checkout, using a fresh private evidence
directory outside the repository. `EVIDENCE` and `REPO` below are placeholders
for resolved paths, not permission to use a different source or project.

```powershell
node tools/release/collectFunctionFleetRuntimeIdentityReadback.js --phase preflight --repository-root REPO --project-id crm3-baf-ops-b8638 --region asia-south1 --output EVIDENCE/preflight.json --gcloud gcloud.cmd
node tools/release/collectFunctionFleetRuntimeIdentityReadback.js --phase final --repository-root REPO --project-id crm3-baf-ops-b8638 --region asia-south1 --output EVIDENCE/final-fleet.json --gcloud gcloud.cmd --probe-callables
node tools/release/collectFunctionsIamDependenciesReadback.js --repository-root REPO --project-id crm3-baf-ops-b8638 --region asia-south1 --output EVIDENCE/final-iam-dependencies.json --gcloud gcloud.cmd --tar tar
node tools/release/collectFirestoreRulesIndexesReadback.js --repository-root REPO --project-id crm3-baf-ops-b8638 --output EVIDENCE/final-firestore.json
```

The concrete deployment invocation and environment-file handling must be
reviewed against this plan before execution. The old wrapper's dangerous phases
are not made safe merely by adding `PreserveExistingIam`.

## Closure and successor release

Only after successful actual readback, create a new backend closure recording
the exact approval custody, actual execution source/CI, deployment timestamps,
function counts and runtime hash, each physical and canonical child-receipt hash,
and observed control boundaries. Distinguish `delegatedDecisionAtUtc` from
`ownerInstructionReceivedAtUtc`; no user-message receipt timestamp is known.
Update current deployed-backend authority while preserving the separate
historical Build 27 chain. Independently review the new closure and run the
existing release-policy and source/receipt regressions.

Build-number allocation, protected artifact construction, dual custody,
retained-data physical acceptance and pilot/download-channel promotion require
their own concrete delegated decisions and measured evidence. The connected
Build 27 phone is useful for an in-place successor check; it does not prove a
Build 21 retained-data upgrade or a second-device operating shift. Use the
existing `docs/AUDIT_SUCCESSOR_ACCEPTANCE_20260908.md` for those evidence gaps.
