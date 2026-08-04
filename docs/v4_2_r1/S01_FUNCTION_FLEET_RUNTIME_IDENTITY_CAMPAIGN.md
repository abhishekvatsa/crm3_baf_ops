# S-01 Function Fleet Runtime Identity Campaign

Status: SOURCE AND CAMPAIGN EXECUTOR IMPLEMENTED; IAM AND DEPLOYMENT PENDING

## Purpose

This tranche binds every admitted Cloud Function export to a unique,
same-project runtime service account. It prepares the production fleet for
removal of the unconditional `roles/editor` grant from the Default Compute
service account without treating source configuration as deployed proof.

The complete machine-readable authority is:

`release/function-fleet-runtime-identity-policy.json`

## Verified starting point

The strict LR-03/LR-06 readback established 14 source exports and nine active
production Functions. Seven active Functions used Default Compute, two global
pull Functions used dedicated accounts, and five source exports were absent
from production. Every deployed dependency archive differed from current
source.

A read-only predeployment inventory on 2026-08-04 confirmed:

- the nine Cloud Run services are the nine deployed Functions;
- no Cloud Run jobs or Cloud Scheduler jobs exist in `asia-south1`;
- no App Engine application or BigQuery dataset exists;
- the Compute Engine API is disabled;
- the Cloud Asset API remains disabled and was not enabled for this campaign;
- the Functions build configuration uses Default Compute as its build service
  account.

The last fact is load-bearing. Default Compute must receive
`roles/cloudbuild.builds.builder` before Editor is removed. It must not remain
a Function runtime identity after cutover.

A privacy-minimised aggregate read at `2026-08-04T10:32:19.779Z` found zero
currently overdue lane acknowledgements, compliance acknowledgements, or
compliance completions. This observation does not authorize the scheduler.
The executor repeats the same three aggregate counts immediately before the
scheduler cohort and stops unless the total is still zero.

## Source control

`functions/src/functionFleetRuntimeIdentity.ts` owns one account ID for each
of the 14 exports. Every address is resolved through Firebase's built-in
`PROJECT_ID` parameter, so a staging deployment resolves to staging-owned
accounts and cannot silently borrow a production identity.

The build and test path loads the emitted Function endpoints and proves:

- the export inventory and policy inventory are identical;
- every export has a runtime identity;
- all 14 account IDs are unique;
- every wire value preserves target-project interpolation;
- no runtime binding admits Editor or a logging API role;
- the notification custom role contains only
  `cloudmessaging.messages.create`.

Firebase Functions logging writes structured entries to stdout or stderr.
Consequently, runtime accounts do not need `roles/logging.logWriter` merely
for `firebase-functions/logger` calls.

The strict LR-03/LR-06 policy now contains the expected account for all 14
exports. Its collector fails acquisition when that binding inventory is
partial, so post-deployment evidence cannot silently omit a newly dedicated
identity.

## Governed executor

`tools/release/Invoke-FunctionFleetRuntimeIdentityCampaign.ps1` implements
the deployment order below as seven explicit phases. Every mutating phase is
bound to clean `main`, the exact production project and region, a successful
four-job post-merge release gate, and the sealed receipt from its predecessor.

`tools/release/collectFunctionFleetRuntimeIdentityReadback.js` is the
adjudicator. Its control-plane and Firestore acquisition is read-only. In the
post-deployment phases it also sends unauthenticated empty requests to the
callable endpoints and requires every request to return no data. Its receipts
retain IAM and runtime identity metadata, aggregate escalation counts,
scheduler health, and privacy-minimised probe outcomes. They retain no
Firestore document IDs, business payloads, user identity, or callable response
body.

The executor:

- creates no project, user, business document, Rule, index, App Check policy,
  or distribution resource;
- never deletes a Function or service account;
- keeps mutating-callable App Check at the governed `false` deployment value;
- deploys callables, event triggers, and the scheduler as separate cohorts;
- invokes the scheduler only after a fresh zero-candidate aggregate read;
- restores Default Compute Editor automatically if final IAM or dependency
  adjudication fails after removal.

## Deployment order

1. Merge and verify this source tranche at exact `main`.
2. Create only the missing same-project accounts and the notification sender
   custom role.
3. Grant each identity only the roles recorded in the policy.
4. Grant Default Compute `roles/cloudbuild.builds.builder` while Editor is
   still present.
5. Use project-level Run Invoker only as a temporary deployment bridge for
   event and schedule identities.
6. Deploy the exact 14-function source fleet in bounded cohorts.
7. Bind Run Invoker on each trigger's own Cloud Run service and remove every
   temporary project-level grant.
8. Verify every Function is active under its exact account, all five missing
   exports are present, and dependencies match current source.
9. Exercise authenticated or negative callable checks and verify trigger and
   scheduler control-plane health without manufacturing business state.
10. Remove Default Compute Editor only after all prior checks pass.
11. Repeat the strict LR-03/LR-06 collector and record exact-head evidence.

Any failure before step 10 leaves Editor unchanged. Any failure after step 10
requires immediate role restoration followed by incident adjudication.

## Closure boundary

This source tranche does not create accounts, mutate IAM, deploy Functions,
remove Editor, write Firestore data, deploy Rules or indexes, authorize a
pilot, or authorize distribution. `S-01`, `H2-IAM`, and `D-01` remain open
until post-deployment live readback proves their individual exit criteria.
