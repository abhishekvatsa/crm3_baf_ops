# LR-04 Firestore Recoverability Live Readback

Collector status: SOURCE_IMPLEMENTED_PENDING_MERGE_CI_AND_LIVE_EXECUTION

Merge and exact-head CI evidence: PENDING

Live readback evidence: PENDING

## Purpose

`LR-04` requires current production evidence for Firestore point-in-time
recovery, delete protection, native backup schedules, native backups, and
restore history. Repository declarations and a historical managed export do
not prove those live facts.

The collector is deliberately read-only. It describes the exact production
database, lists native backup schedules and backups, lists a bounded inventory
of database operations, and independently describes the managed-export
operation already bound by the sealed production restore-pack receipt.

## Evidence Semantics

The receipt has two independent decisions:

- the acquisition decision says whether a clean, exact `main` commit produced
  complete, target-bound, canonically sealed evidence; and
- the posture decision says whether the observed recovery controls and restore
  evidence satisfy the underlying recoverability objective.

A strict acquisition may pass while posture remains on hold. This is required
behavior. A disabled control, absent backup, or missing restore rehearsal must
remain visible without corrupting an otherwise complete live readback.

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
  --gcloud "C:\Users\abhis\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" `
  --output "C:\Users\abhis\Downloads\crm3-lr04-firestore-recoverability-readback.json"
```

The strict receipt must then be copied into `release/evidence/` without
modification, hash-bound to a closure record, and adjudicated in a separate PR.

## Pre-Execution Observation

A read-only planning observation indicated disabled point-in-time recovery and
delete protection, no native backup schedule or native backup, and no observed
successful import operation. It also reconfirmed one successful managed export
already bound to the sealed private restore pack. That observation is not a
governed receipt and has no closure authority.

## Remaining Boundary

This source tranche does not close `LR-04` or `P-05`, authorize a recovery
control change, incur a new backup cost, or authorize a restore against
production. `LR-04` remains open until a strict receipt is adjudicated. `P-05`
remains open until adverse posture is remediated and an isolated governed
restore rehearsal is proved.
