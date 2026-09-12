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

The collector enumerates all functions, all listed Run regions and the services
and policies in accessible regions, all project service accounts and their
policies, and the complete project IAM policy. Lists are paginated, and
unreachable/incomplete results fail except for the specific regional restriction
described below. Each new function **and its derived Run service** must independently
return HTTP404 with an actual `NOT_FOUND` body before deployment. HTTP403, a
permission error mentioning “not found,” and function404 plus an existing Run
service all fail. Collect this preflight after recording the approval: the
approval cannot contain its resulting hash without a circular reference. Record
the measured hash in the execution attempt before the first deployment command.

The only regional inventory exception is `me-central2`. Its first service-list
page must return a retained HTTP403 `PERMISSION_DENIED` body with exactly one
Google `ErrorInfo`: reason `LOCATION_POLICY_VIOLATED`, domain `googleapis.com`,
matching region and actual project-number consumer, and the measured empty
service metadata. The row records `unavailable` with the exact response; it has
no `pages` or empty-service substitute. Its derived `unavailableRunRegions` entry
contains the region, reason, domain and consumer. Before and after must have
identical exclusion sets and identities; a region becoming accessible or
inaccessible between captures fails comparison. A denial on a later page,
another region, the target `asia-south1`, a service policy or a new-service absence
read still fails. This exception does not enable an API or change any permission.

[Google documents access restrictions for the Dammam region](https://docs.cloud.google.com/docs/dammam-region-access).
The observed restriction establishes that its services could not be inspected;
it does **not** establish that it has no services. Comparison qualifications
explicitly exclude unseen regional service inventories and IAM from coverage.
All four authorized service creations remain confined to `asia-south1`.

`scopedCallableInvokerIam.js compare --repository-root ROOT --approval FILE
--approval-sha256 SHA256 --source-commit COMMIT --before BEFORE --after AFTER
--output PROOF` verifies both captures and retains them in the sealed proof.
It requires the original project policy, every observed existing service identity
and policy in accessible regions, and the complete service-account inventory,
identities and policies to remain unchanged. It makes no claim that service IAM
in an excluded, unseen region remained unchanged.
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
proof), and the canonical audit. For the original private proof it rederives the
comparison from retained raw responses. The separately typed public projection
below has a deliberately narrower, explicit offline verification boundary.

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

## Public release evidence and private raw custody

The complete raw proof can contain Function/Run environment values, secret
references, private service names, IAM members and conditions. The legacy raw
proof's phrase “no credentials retained” describes the collection token only;
it does **not** establish that environment values are safe to publish. Do not
copy either raw capture or the embedded raw comparison into a public repository.
Do not redact or rewrite those private bytes: that breaks their evidence seal.

`scopedCallableInvokerIamPublic.js` adds the distinct
`scoped-callable-invoker-iam-public-comparison` schema2. Its generator first
revalidates the complete raw proof and actual backend control comparison,
including the exact source's runtime/security options. It then requires the
existing `Copy-PrivateGcsCustodyFile` result for `Purpose=custodyRecord`, with
the exact proof saved as `scoped-iam-comparison.json` under an approved unique
Build28 private prefix. The existing helper performs create-only upload,
captures that upload's generation, downloads that exact generation, compares
SHA-256 and size, rechecks the source, and verifies the approved bucket privacy,
versioning and retention controls. Its temporary download is intentionally
removed after verification; no additional download artifact is required.

The public generator has no network, upload, IAM or deployment operations:

```text
node tools/release/scopedCallableInvokerIamPublic.js
  --repository-root ROOT --approval APPROVAL --approval-sha256 SHA
  --source-commit COMMIT --private-proof PRIVATE_RAW_PROOF
  --private-custody PRIVATE_CUSTODY_RESULT --observed-at-utc UTC --output PUBLIC_JSON
```

All inputs are required and output is create-only. The same local API is
`createPublicProof({repoRoot, approval, approvalSha256, sourceCommit,
rawProofBytes, privateCustody, observedAtUtc})`. The assembler rederives the
projection from private bytes and the custody result before copying only the
allowlisted public document. No success label can substitute for this generation
path. Custody must follow the observations and publication must follow custody;
future observation/publication times are refused.

The public document contains complete-observation and semantic-inventory
commitments, counts, the exact four approved public invoker bindings, control
comparison commitments and the generation-pinned private custody reference.
All pre-existing service/account identities and IAM plus project IAM must have
equal before/after commitments; the complete after inventory includes exactly
four additions. Any specifically unavailable region remains explicitly outside
the observed coverage. Unknown fields at every public boundary are rejected,
so raw environment or IAM fields cannot be smuggled into an otherwise valid
public document. The known source-declared endpoint names are public; unrelated
service names and private principals are present only inside full commitments.

`validatePublicProof` and the shared deployment boundary run without npm
dependencies or cloud credentials. They bind the exact seven source-option files
to immutable Git bytes, validate their combined commitment, the approved four
policies, inventory commitment equalities, controls and measured custody
attestation, and bracket the real deployment command interval. They do **not**
parse source options again, fetch the private object, re-read hidden raw API
responses, or independently prove upload authenticity. The full TypeScript and
raw-control comparison occurs during generation; authorized reviewers can
retrieve the pinned private generation to repeat it. Hash seals provide integrity,
not observation authenticity. This limitation is mandatory text in the public
proof and must remain visible in release reporting. Historical private proofs
continue through the unchanged raw validation route.

`scopedCallableInvokerIamPublic.test.mjs` uses synthetic private-secret,
principal and unrelated-service canaries through the actual raw and control
validators. It checks their exclusion, refusal of changed IAM/environment,
unverified custody, resealed contradictory commitments and unknown raw fields,
qualified inaccessible-region coverage, and a dependency-free checkout with
no `functions/node_modules`. These are host fixture results, not live production
observations or a completed release.
