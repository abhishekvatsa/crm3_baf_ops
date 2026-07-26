# R-06 Versioned Workflow Receipt Fingerprints

## Finding

Maintenance-workflow receipts previously stored an unversioned 16-hex
`payloadHash`. The function named `fnv1a64` did not implement standard
FNV-1a-64:

* multiplication applied `0x1b3` but omitted the prime's `2^40` term;
* non-empty standard vectors did not match FNV-1a-64;
* `charCodeAt` processed UTF-16 code units rather than UTF-8 bytes;
* no focused vector or canonicalization tests protected the implementation.

No unsupported collision-resistance estimate is used as evidence. The defect
is standard non-compliance, bespoke hash risk and an unversioned persisted
contract.

## Source decision

New receipts use:

```text
receiptSchemaVersion: 2
payloadFingerprint: "sha256:<64 lowercase hex characters>"
```

The digest is SHA-256 over the existing recursively key-sorted `stableJson`
representation encoded as UTF-8. Tests prove that reordered object keys and
non-ASCII content produce the intended canonical fingerprint.

A malformed fingerprint fails with
`workflow-receipt-fingerprint-malformed`. Reusing a command ID with a different
valid SHA-256 fingerprint fails with `command-idempotency-conflict`.

## Legacy receipt boundary

Changing the algorithm without a schema boundary would turn every legitimate
legacy replay into an apparent command conflict. Schema-v2 therefore does not
silently reinterpret old `payloadHash` documents.

An unversioned 16-hex receipt fails with:

```text
code: failed-precondition
reasonCode: legacy-workflow-receipt-reconciliation-required
```

Before workflow mutations are enabled for pilot or cutover, a governed
readback must establish one of:

* the legacy receipt collection is absent;
* every legacy receipt can be unambiguously reconciled from immutable evidence;
* ambiguous receipts are quarantined and remain fail-closed.

This source tranche does not perform or authorize that production readback or
reconciliation.

## Evidence

The source and test contract is held by:

```text
functions/src/maintenanceWorkflow/utils.ts
functions/src/maintenanceWorkflow/types.ts
functions/src/maintenanceWorkflow/idempotency.ts
functions/src/maintenanceWorkflow/dispatcher.ts
functions/test/maintenanceWorkflowReplayAuthority.test.js
```

The tests prove:

* SHA-256 has an explicit algorithm prefix and 64 lowercase hex characters;
* stable key order and UTF-8 non-ASCII input are canonical;
* same-owner conflicting replay fails without business mutation;
* malformed persisted receipt fields fail closed;
* legacy unversioned receipts require governed reconciliation;
* the client-facing receipt response remains compatible.

## Exact source evidence

```text
Repository:      abhishekvatsa/crm3_baf_ops
Baseline commit: efd41221b8d13c612ae075bc1651b74d1f97be8d
Source commit:   e15b9676fc1e6e5c5ef56ff161f8558cac80dadf
Source tree:     7c1f5b387756f37d7d99a7bded2ca77abc616145
Decision:        PASS_SOURCE_R06_VERSIONED_WORKFLOW_RECEIPT_FINGERPRINTS
```

## Exact merge and post-merge evidence

```text
Repository:              abhishekvatsa/crm3_baf_ops
Pull request:            #47
Head commit:             5a2d7e62fc7de810e6edbf8a69e9558c90930c8b
Merge commit:            3c0861dcfe032ae795833283f9a7d63a45dde7e3
Post-merge workflow run: 30196339736
Decision:                PASS_R06_VERSIONED_WORKFLOW_RECEIPT_FINGERPRINTS
```

All six exact-head release-gate checks across the branch-push and pull-request
runs passed. All three release-gate jobs also passed on the exact merge commit.
The finding is therefore `CLOSED` as a source-and-CI finding.

Closure does not classify or rewrite legacy unversioned receipts. Their
read-only inventory and any governed reconciliation remain pilot/cutover
prerequisites.

## Authorization boundary

This change does not authorize deployment, production receipt mutation,
legacy-data reconciliation, pilot operation, handout or cutover.
