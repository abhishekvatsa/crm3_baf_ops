# S-01 Function Fleet Runtime Identity Campaign

Status: SOURCE IMPLEMENTED; IAM AND DEPLOYMENT PENDING

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

## Deployment order

1. Merge and verify this source tranche at exact `main`.
2. Create only the missing same-project accounts and the notification sender
   custom role.
3. Grant each identity only the roles recorded in the policy.
4. Grant Default Compute `roles/cloudbuild.builds.builder` while Editor is
   still present.
5. Deploy the exact 14-function source fleet in bounded cohorts.
6. Verify every Function is active under its exact account, all five missing
   exports are present, and dependencies match current source.
7. Exercise authenticated or negative callable checks and verify trigger and
   scheduler control-plane health without manufacturing business state.
8. Remove Default Compute Editor only after all prior checks pass.
9. Repeat the strict LR-03/LR-06 collector and record exact-head evidence.

Any failure before step 8 leaves Editor unchanged. Any failure after step 8
requires immediate role restoration followed by incident adjudication.

## Closure boundary

This source tranche does not create accounts, mutate IAM, deploy Functions,
remove Editor, write Firestore data, deploy Rules or indexes, authorize a
pilot, or authorize distribution. `S-01`, `H2-IAM`, and `D-01` remain open
until post-deployment live readback proves their individual exit criteria.
