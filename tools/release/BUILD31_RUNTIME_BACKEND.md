# Build 31 runtime backend verification

This route admits only the reviewed `@grpc/grpc-js` runtime change for the existing
13 callable, five event and one scheduled Functions. Rules, indexes, IAM,
enforcement settings and business logic must remain unchanged. The older exact
backend and development-tool routes remain separate. A failed runtime-route
verification never falls back to either route.

Adding these tools does not select the route, allocate a version, enable
construction, authorize deployment or authorize distribution. The current
release policy and approval records control those actions.

## Required source and approval

Execution requires the exact clean `main` source, its settled source review and
both successful main CI runs. A later, immutable decision must bind that source,
the bounded change, current controls, runtime evidence and the owner's actual
production-deployment instruction. Permission to prepare or test code is not
production-deployment consent. Deployment is restricted to the recorded fleet;
it does not include Rules, indexes, IAM changes, manual scheduler invocation or
business-data experiments.

Closure is accepted only after replaying the measured deployment, complete
source archive, endpoint hashes, runtime dependencies and before/after controls.
Client compatibility requires its own source-specific decision. Later signing
source may change only the finite admitted metadata paths and governed version.
Historical decisions and evidence are preserved.

## Private evidence is required

The public descriptor contains sanitized immutable pointers and commitments.
Those commitments, or a public `PASS` assertion, are insufficient by themselves.
Verification downloads the exact authenticated private object generation,
checks the bounded compressed and expanded populations, and replays every
required private record using the source-bound verifier. Missing evidence,
changed bytes or unavailable credentials fail closed.

The bundle contains self-contained Git objects, original raw receipts, archives,
installed dependency files and observed interpreter bytes. Original paths are
mapped through an immutable relocation contract; receipt contents are not
rewritten. The transport preserves regular-file bytes and derives only the
empty `.git/refs` directory required by Git when references are packed. It never
rewrites a Git reference, configuration or object. Original producer binaries
are historical evidence; current pure replay uses the separately identified
Node 22 interpreter. An actual Git repository is still required to establish
signing-source ancestry. A source ZIP alone cannot establish that ancestry.

## Hosted readiness is not configured

These tools do not provision credentials or a trusted hosted private-evidence
context. Selecting this route therefore cannot make the current metadata PR,
main or signing checks pass without that separately reviewed setup. Public PR
code must never receive raw evidence credentials.

A future trusted verification job should execute the immutable, already
reviewed source verifier and treat candidate metadata solely as data. Before
loading code or granting read access, it must verify the finite metadata
allowlist and every protected source blob. Metadata PR, main and signing each
need the appropriate trusted context and required verification result. This is
a readiness dependency, not permission to bypass existing checks or replace
full replay with an unauthenticated attestation.

Offline component tests and synthetic full-chain replay establish code behavior.
They do not establish real cloud custody, actual owner consent, deployed state,
Play delivery or production readiness.
