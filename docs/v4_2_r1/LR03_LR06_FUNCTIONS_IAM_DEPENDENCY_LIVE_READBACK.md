# LR-03 / LR-06 Functions, IAM And Dependency Live Readback

Collector status: SOURCE_IMPLEMENTED

Merge and exact-head CI evidence: PENDING

Live readback evidence: PENDING

## Purpose

`LR-03` requires a live inventory of deployed Cloud Functions runtime
identities and their project-level IAM grants. `LR-06` requires a live
dependency inventory from the generation-pinned source archive behind every
deployed Function. Repository lockfiles and source declarations cannot prove
either live fact.

The collector is deliberately read-only. It AST-discovers every named export
from the TypeScript Functions entrypoint, lists Gen2 Functions, reads the
project IAM policy, downloads each already-deployed source archive by its exact
Cloud Storage generation, and extracts only `package.json` and
`package-lock.json` in a temporary local directory. The archives and extracted
content are removed after hashes, counts, and selected dependency versions are
derived.

Strict collection also requires the discovered source export set to match the
governed policy exactly. A newly exported Function therefore cannot be omitted
from the source-to-live comparison by leaving a hand-maintained list unchanged.

## Evidence Semantics

The receipt has two independent decisions:

- the acquisition decision says whether a clean, exact `main` commit produced
  complete, generation-pinned and canonically sealed evidence;
- the posture decision says whether the observed fleet, runtime identities,
  broad IAM roles, and deployed dependency inventories match current source
  expectations.

A strict acquisition may pass while posture remains on hold. That is an
intentional result, not a softened check: `LR-03` and `LR-06` are evidence
gates, while `S-01` and `D-01` own remediation of adverse runtime identity and
dependency posture. The collector cannot close those findings.

## Privacy And Mutation Boundary

The receipt retains deployed service-account identities because they are the
subject of `LR-03`. It does not retain the operator's account, user or business
documents, Function environment variables, source code, package manifests, or
lockfile content. Dependency state is represented only by hashes, counts, and
the versions of the policy's bounded package set.

The collector cannot deploy or invoke a Function, change IAM, create or delete
a service account, alter a Cloud Storage object, or read Firestore business
data. Its local evidence output must be a new file outside the repository.
On Windows, the governed `gcloud.cmd` path is resolved to the Cloud SDK's
bundled Python and `lib/gcloud.py` entrypoint. Arguments remain discrete process
arguments; no command shell is introduced.

## Governed Execution

After the collector source is merged and post-merge CI is green, execute it
from a clean local `main` equal to `origin/main`:

```powershell
node tools/release/collectFunctionsIamDependenciesReadback.js `
  --repository-root . `
  --project-id crm3-baf-ops-b8638 `
  --region asia-south1 `
  --gcloud "C:\Users\abhis\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd" `
  --output "C:\Users\abhis\Downloads\crm3-lr03-lr06-functions-live-readback.json"
```

The strict receipt must then be copied into `release/evidence/` without
modification, hash-bound to a closure record, and adjudicated in a separate PR.

## Remaining Boundary

This source tranche does not claim that production IAM is least privilege,
that every source export is deployed, that deployed dependencies match current
repository locks, or that any production mutation is authorized. `LR-03`,
`LR-06`, `S-01`, and `D-01` remain open until later evidence says otherwise.
