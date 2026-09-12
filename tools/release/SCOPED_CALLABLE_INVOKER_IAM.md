# Four new callable invoker policies

This is an additive evidence contract, not deployment authorization. The ordinary
release verifier must first admit the immutable source-specific approval. Old
approvals and receipts retain their `iamMutated: false` interpretation.

The pinned Firebase CLI creates each new Gen2 callable's Cloud Run policy with
an unconditional `roles/run.invoker` binding for `allUsers`. That is an IAM write,
even when no existing policy changes. For this cohort only, the new approval may
contain `approvedDeployment.newCallableInvokerPolicies`: exactly four objects
with `functionName`, `serviceResource`, `role: "roles/run.invoker"`, and
`members: ["allUsers"]`. The names are `assignPublishedTemplateVersionV2`,
`executeMaintenanceWorkflowCommandV2`, `mutateAssetHierarchyV2`, and
`mutateChargeAbnormalityV2`. The approved resource is in project
`crm3-baf-ops-b8638`, region `asia-south1`, with the lowercase function name as
the service name; actual postdeployment function service references must agree.
All four reuse their source policy's existing V1 runtime accounts.

`collectScopedCallableInvokerIam.js --repository-root ROOT --approval FILE
--approval-sha256 SHA256 --source-commit COMMIT --phase before|after --output FILE`
only reads Google control-plane APIs using existing gcloud credentials. It
refuses to overwrite evidence. No token is stored in the receipt. The capture
retains exact response body text, methods, URLs, status codes, source and approval
bindings, collection times and a canonical seal. Raw project IAM and account
identities are sensitive operational custody; keep the full proof in authorized
release evidence custody, not a public audit download. Redacting it invalidates
this verifier; a hash alone does not replace measured evidence.

The collector enumerates all functions, all project-visible Run regions and
their services/policies, all project service accounts and their policies, and
the complete project IAM policy. Lists are paginated, and unreachable/incomplete
results fail. Each new function **and its derived Run service** must independently
return HTTP404 with an actual `NOT_FOUND` body before deployment. HTTP403, a
permission error mentioning “not found,” and function404 plus an existing Run
service all fail. Collect this preflight after recording the approval: the
approval cannot contain its resulting hash without a circular reference. Record
the measured hash in the execution attempt before the first deployment command.

`scopedCallableInvokerIam.js compare --repository-root ROOT --approval FILE
--approval-sha256 SHA256 --source-commit COMMIT --before BEFORE --after AFTER
--output PROOF` verifies both captures and retains them in the sealed proof.
It requires the original project policy, every existing service identity/policy,
and the complete service-account inventory/identity/policies to remain unchanged.
Only four services may appear, with exactly the approved public invoker binding.
Comparison ignores policy etags and syntax version, and normalizes array order;
conditions, audit configuration and additional fields remain material.

The deployment receipt must truthfully record `controlBoundary.iamMutated: true`
and `deployment.newCallableInvokerIamEvidence` with repository-relative `file`,
`physicalSha256` and `canonicalReceiptSha256`. This scope does not allow project
IAM changes, existing service policy changes, runtime account creation/changes,
App Check activation, or extra grants. The collector and comparison themselves
retain `mutationBoundary.iamMutated: false`, because their own actions are reads.
Both flags describe their respective operations and are not interchangeable.
The shared gate also requires the before capture to finish before
`deployment.startedAtUtc` and the after capture to begin after
`deployment.lastDeploymentCommandCompletedAtUtc`. These are the actual first
and last deployment command times, compared as strict UTC instants with up to
nine fractional digits, including PowerShell's seven-digit output. Missing,
invalid, reversed or unbracketed command timestamps fail.

The shared `validateDeploymentIamBoundary` is used by the production policy,
staged source authority (including the distribution reader's current-backend
proof), and the canonical audit. It rederives comparison from retained raw
responses instead of trusting a success label or four claimed counts.

This is before/after observation, not a continuous guarantee that no transient
write occurred. Use the unmodified pinned CLI, reviewed deployment options and
the existing dedicated-account checks. On a failure stop; keep the original
preflight/attempt and do not describe an existing service as absent on a retry.
No deployment, live measurement, permission change or new approval is claimed
by the host fixture tests or by the presence of these tools.

API methods checked against official references on 2026-09-13:

- [Cloud Run locations](https://docs.cloud.google.com/run/docs/reference/rest/v1/projects.locations/list): v1 GET, project-scoped location enumeration and `pageSize`/`pageToken`.
- [Cloud Run services](https://docs.cloud.google.com/run/docs/reference/rest/v2/projects.locations.services/list): v2 GET in each region; the `-` location wildcard is unsupported.
- [Functions inventory](https://docs.cloud.google.com/functions/docs/reference/rest/v2/projects.locations.functions/list): v2 GET supports all-region `-`; reject `unreachable`.
- [Service accounts](https://docs.cloud.google.com/iam/docs/reference/rest/v1/projects.serviceAccounts/list): GET, maximum page size100.
- [Service-account policy](https://docs.cloud.google.com/iam/docs/reference/rest/v1/projects.serviceAccounts/getIamPolicy): POST with an empty body; requested policy version in query.
- [Run service policy](https://docs.cloud.google.com/run/docs/reference/rest/v2/projects.locations.services/getIamPolicy): GET, requested policy version in query.

The focused host suite exercises the actual collector through an injected read
transport, as well as negative raw responses, proof tampering, and the CLI used
by PowerShell/Python. It is separate from a later authenticated live preflight.
