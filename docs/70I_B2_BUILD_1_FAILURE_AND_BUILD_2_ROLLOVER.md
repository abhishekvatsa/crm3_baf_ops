# 70I-B2 Build 1 Failure and Build 2 Rollover

## Decision

Android build number 1 is permanently consumed. Build number 2 is the next
approved production-candidate construction attempt.

This record does not approve Firebase deployment, controlled-pilot
distribution, or unrestricted plant release.

## Consumed build 1

- GitHub run: `30387521656`
- Run URL:
  `https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/30387521656`
- Exact commit: `7b4686295f8fd971ba74c61173ec3304aaea9fc9`
- Reservation tag: `crm3-build-reserved/1`
- Reservation tag object: `7b0c7182dc9c8d5b29a88759d35bbebb60d39f1e`
- Result: failure
- Failed step: `Build once and independently verify`
- Artifact constructed: no
- Artifact uploaded: no
- Built tag created: no

The workflow restored and hash-checked the approved keystore, proved the pinned
toolchain, downloaded and verified bundletool, and proved the approved Linux
Isar core before entering the builder. The builder then failed on an obsolete
pre-composite backend-authority property.

The reservation tag remains authoritative. Build number 1 must never be reused.

## Source defect

`release/backend-authority.prod.json` uses strict composite schema version 2.
The production and verification artifact tools still consumed fields from the
superseded homogeneous schema:

- `backendGitCommit`
- `deployedIndexesParityStatus`
- `deployedIndexesParityEvidence`
- `intentionalDivergencePolicy`

Their source-custody loops also treated historical live-reconstruction hashes
as hashes of the current checkout. That interpretation is invalid after the
authority moved to a mixed live Function fleet.

## Corrected boundary

The release tools now consume:

- `authorityClass`
- `authorityDigest`
- `releaseModel`
- `repositoryAuthority`
- `firestore`
- `sourceCustody`

The authority's `firestore.indexes` record proves the captured live backend
state: 28 source indexes, 28 deployed indexes, all ready, and no field
overrides. Its `sourceSha256` is checked against the matching
`sourceCustody.files` reconstruction entry.

Current `firestore.indexes.json` has evolved after that reconstruction. It is
hashed as current source in the artifact package, but it is not relabelled as
deployed parity. The production artifact workflow does not deploy Firestore
Rules, indexes, or Functions.

## Prevention

The normal release gate and the production workflow now execute the shared
composite backend-authority validator. In the production workflow, the complete
source policy and backend authority preflight runs before the atomic remote
reservation step.

A deterministic source-policy or authority defect therefore fails before
consuming the next Android build number.

## Build 2 authority

- Version: `1.0.0-rc.1+2`
- Release ID: `crm3-baf-ops-1.0.0-rc.1-b2`
- Reservation ID: `crm3-baf-ops-o1-o5-v4-7b46862-b2-2`
- Reservation tag: `crm3-build-reserved/2`
- Built tag: `crm3-build-built/2`
- Approval: `release/approvals/build-number-2-rollover-approval.json`

The build-2 reservation tag does not exist until the protected workflow creates
it after the source repair is merged to exact live `main`.
