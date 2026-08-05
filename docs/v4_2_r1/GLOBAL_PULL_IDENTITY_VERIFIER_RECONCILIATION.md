# Global-Pull Identity Verifier Reconciliation

Status: SOURCE AND LOCAL AUDIT VERIFIED

## Finding

The whole-app reconciliation audit still expected the pre-fleet global-pull
identity implementation. Its verifier required direct Firebase parameter
imports and service-account literals in `globalPullSecurityConfig.ts`, policy
schema 2, project logging grants, and project-level Run Invoker in the writer's
ordinary role list.

Those expectations became stale when the complete 14-function fleet moved to
the shared `functionFleetRuntimeIdentity.ts` registry and completed the
least-privilege IAM campaign. Current source deliberately removes the logging
grant and separates Cloud Run service-level Run Invoker from ordinary project
roles.

## Correction

The global-pull verifier now binds:

- both endpoint options in the Functions entrypoint;
- the shared target-project identity registry and exact reader/writer IDs;
- Firebase `PROJECT_ID` interpolation without a production-project literal;
- global-pull policy schema 3 and its complete-fleet policy pointer;
- reader `roles/datastore.viewer` only;
- writer `roles/datastore.user` plus `roles/eventarc.eventReceiver`;
- writer service-level `roles/run.invoker` as a separate role class;
- absence of `roles/logging.logWriter` from the subordinate policy;
- the complete fleet's `DEPLOYED_AND_LIVE_READBACK_PROVED` authority.

The subordinate global-pull declaration now states
`DEPLOYED_SUBSET_SUBSUMED_BY_PROVED_COMPLETE_FLEET`. Its source-only nonclaims
remain intact; closure authority still comes from the complete-fleet policy and
sealed evidence, not from this subordinate declaration by itself.

## Evidence And Boundary

Local verification is:

- global-pull source verifier: 17 of 17 passed;
- whole-app reconciliation audit: 23 of 23 passed;
- global-pull runtime-identity Functions unit suite: passed;
- canonical source and governance audit: 113 of 113 passed.

This correction does not create or delete a service account, change IAM,
deploy a Function, mutate Firestore, alter Rules or indexes, change App Check,
produce device evidence, or authorize pilot handout.
