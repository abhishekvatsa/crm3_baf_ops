# LR-04 Firestore Recoverability Live Readback

Collector status: SOURCE_CI_AND_LIVE_READBACK_PROVED

Merge and exact-head CI evidence: PASS - PR #139 and post-merge run
`30893195416`

Live readback evidence: PASS acquisition / HOLD recoverability posture

## Purpose

`LR-04` requires current production evidence for Firestore point-in-time
recovery, delete protection, native backup schedules, native backups, and
restore history. Repository declarations and a historical managed export do
not prove those live facts.

The collector is deliberately read-only. It describes the exact production
database, lists native backup schedules and backups, lists a bounded inventory
of database operations, and independently describes the managed-export
operation already bound by the sealed production restore-pack receipt.

For P-05 closure, the collector can additionally describe one policy-bound,
delete-protected isolated database and its exact import operation. The
isolated operation is supplied at execution time and must match the SHA-256
authority in the policy. Its raw resource name and Cloud Storage prefix are
not retained in evidence.

## Evidence Semantics

The receipt has two independent decisions:

- the acquisition decision says whether a clean, exact `main` commit produced
  complete, target-bound, canonically sealed evidence; and
- the posture decision says whether the observed recovery controls and restore
  evidence satisfy the underlying recoverability objective.

A strict acquisition may pass while posture remains on hold. This is required
behavior. A disabled control, absent backup, or missing restore rehearsal must
remain visible without corrupting an otherwise complete live readback.

A native backup clears the posture hold only in `READY` state. A restore clears
its hold only when the isolated database, location, type, delete-protection
state, operation and input hashes, successful terminal state, response type,
and completed/estimated document counts all match policy.

The existing managed export and its independently verified private custody
pack are reconfirmed as evidence of export recoverability. They are not
represented as a native Firestore backup and are not represented as proof that
a restore or import has succeeded.

## Privacy And Mutation Boundary

The receipt retains only the exact project, database and location, protection
states, bounded counts, state/type aggregates, timestamps, and hashes of the
sealed export identifiers. It does not retain the operator account, Firestore
documents, business payloads, database UID or etag, backup names, operation
names, Cloud Storage output prefixes, or private custody paths.

The collector cannot enable or disable point-in-time recovery or delete
protection, create or change a backup schedule, create or delete a backup,
start an export or import, read or write a Firestore document, change IAM or
billing, or mutate a Cloud Storage object. Its local evidence output must be a
new file outside the repository. On Windows, `gcloud.cmd` is resolved to the
Cloud SDK bundled Python entrypoint without introducing a command shell.

## Governed Execution

After collector source is merged and post-merge CI is green, execute it from a
clean local `main` equal to `origin/main`:

```powershell
node tools/release/collectFirestoreRecoverabilityReadback.js `
  --repository-root . `
  --project-id crm3-baf-ops-b8638 `
  --database "(default)" `
  --location asia-south1 `
  --isolated-restore-operation "<exact isolated import operation resource>" `
  --gcloud "C:\Users\abhis\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" `
  --output "C:\Users\abhis\Downloads\crm3-lr04-firestore-recoverability-readback.json"
```

The strict receipt must then be copied into `release/evidence/` without
modification, hash-bound to a closure record, and adjudicated in a separate PR.

Omitting `--isolated-restore-operation` remains valid for an adverse posture
readback, but it cannot clear `noRestoreImportProof`. The collector performs no
import and reads no Firestore document or business payload; it describes only
the isolated database and service-authored import operation metadata.

## Adjudicated Live Result

The strict receipt was captured on 2026-08-04 from clean `main` at
`0d323449be267849e7043772dbfea0a7dc3bd107`, equal to `origin/main` before
and after collection. All 13 acquisition checks passed. The receipt and
closure record are:

- `release/evidence/lr04-firestore-recoverability-live-readback.json`
- `release/evidence/lr04-firestore-recoverability-live-readback-closure.json`

The complete operation inventory contained 24 finished operations: 23 index
operations and one successful managed export. The exact export already bound
to the sealed private restore pack was independently described and matched.
No successful import operation was present.

The readback also proved the following adverse production posture:

- point-in-time recovery is disabled;
- delete protection is disabled;
- no native Firestore backup schedule exists;
- no native Firestore backup exists; and
- no successful restore or import is proved.

The complete, sealed acquisition closes evidence gate `LR-04`. It does not
resolve the adverse state, which remains open under `P-05` with exact exit
evidence.

## Remaining Boundary

This closure does not close `P-05`, authorize a recovery-control change, incur
a new backup cost, or authorize a restore against production. `P-05` remains
open until the adverse posture is remediated and an isolated governed restore
rehearsal is proved. No Stage 2D F4, device, pilot, distribution, deployment,
IAM or billing authorization is created.

## P-05 Closure Readback

The adverse result above remains the exact historical state observed on
2026-08-04. It was subsequently remediated under governed control-plane and
isolated-restore work. A new strict receipt was captured on 2026-08-10 from
clean `main` at `1e9803109844eaede717337317e82865c74bbd6f`, equal to
`origin/main` before and after collection:

- `release/evidence/p05-firestore-recoverability-final-live-readback.json`
- `release/evidence/p05-firestore-recoverability-closure.json`

The final receipt passed every acquisition check and returned
`PASS_FIRESTORE_RECOVERABILITY_POSTURE`. It proves production point-in-time
recovery and delete protection enabled, one daily and one weekly native backup
schedule, and five native backups in `READY` state.

The same receipt binds the delete-protected isolated database
`p05-restore-20260806` to the policy-pinned successful import operation. The
operation imported all 81 expected documents from the sealed pre-purge export,
with completed and estimated counts both equal to 81. The production database
has no import operation in the bounded history; the rehearsal did not restore
into production.

PR #172 merged the exact isolated-restore collector and policy corrections.
GitHub created PR run `31124450098` and post-merge run `31124445219`, but both
were cancelled and therefore supply no successful CI authority. Equivalent
local validation passed the canonical audit (118/118), focused tests (14/14),
Flutter analysis, and all 727 Flutter tests before the final strict readback.

The closure itself was then admitted through PR #173. Exact-head run
`31394196080` and exact-main run `31395073297` each passed all five required
release-gate jobs. The closure evidence records both the cancelled collector
runs and the successful closure runs without conflating their authority.

These facts satisfy all six P-05 exit-evidence requirements and move P-05
through `OPEN -> LIVE_READBACK_PROVED -> CLOSED`. They do not close Stage 2D
F4, authorize pilot handout, or weaken any re-arm trigger. The finding re-arms
if protection is disabled, schedules or backup readiness cease to satisfy the
declared posture, restore evidence becomes unverifiable, the evidence set or
collector changes, or its clean-main source authority is no longer admitted.
