# S-09 Atomic Workflow Authority and Replay

## Finding

The maintenance-workflow callable previously resolved the actor before the
business transaction and passed that captured role set to every command
handler:

```text
read actor
authorize canonical approval
start transaction
read receipt
return replay before command authorization, or execute handler
```

This created three related authority defects:

* revocation or role narrowing before transaction start could not stop a new
  command from using the captured authority;
* receipt replay returned before handler-level command authorization;
* receipts were keyed only by `commandId` and were not bound to the actor who
  created them.

The S-06 planned-job closure finding remains closed. S-09 records the same
stale-authority class on the distinct maintenance-workflow command surface,
plus its replay-specific authorization and ownership defects.

## Source decision

The transaction now performs:

```text
read users/{uid}
validate current canonical approval and roles
read command receipt
if receipt exists:
  reject a non-owner before fingerprint comparison
  validate immutable semantic authority scope
  evaluate current roles against current policy
  validate command identity and fingerprint
  return replay
otherwise:
  resolve the command's semantic authority scope from request or canonical state
  evaluate current roles against current policy
  execute handler checks and business mutation
  write the owner-bound receipt atomically
```

The actor document is the first transaction read. Firestore therefore includes
current authority in the transaction read set on every transaction attempt.
The preflight actor supplies identity and display-name fallback only; its role
set is never mutation authority.

## Semantic replay authority

Receipts store semantic capability, not the role list that happened to satisfy
the policy at execution time. Examples include:

```text
lane.close + laneKey=elec
lane.work + laneKey=oprn
workflow.cancel
equipment.deploy
```

Replay evaluates that scope against the current generated workflow policy.
Policy changes therefore take effect without rewriting historical receipts.

Commands such as `closeLane` can derive scope from payload. Compliance
commands whose authority depends on `compliance_requests` resolve that scope
from canonical transaction state during the original mutation. The immutable
scope then permits a replay decision without depending on mutable or deleted
business documents. Handler-level checks remain in place as defense in depth.

## Concurrency and replay contract

The valid serialized outcomes are:

```text
workflow transaction first -> authorized command may commit, then authority changes
authority mutation first   -> workflow transaction reads new authority and denies
```

An exact replay is permitted only when:

* the current user document is canonically approved;
* the caller owns the receipt;
* the current actor satisfies the receipt's semantic scope under current policy;
* receipt schema, identity, result and fingerprint are valid;
* the command fingerprint is an exact match.

Owner rejection precedes fingerprint comparison, so a different actor cannot
use conflict-versus-success behavior to probe the original payload.

## Evidence

The source and test contract is held by:

```text
functions/src/maintenanceWorkflow/commandAuthority.ts
functions/src/maintenanceWorkflow/dispatcher.ts
functions/src/maintenanceWorkflow/idempotency.ts
functions/test/maintenanceWorkflowReplayAuthority.test.js
functions/test/maintenanceWorkflow.firestoreEmulator.test.js
functions/test/workflowAuthorityReplayAdjudication.firestoreEmulator.test.js
```

The tests prove:

* revoked and role-narrowed stale preflight actors fail before business writes;
* current authority is read inside the Firestore transaction;
* exact replay fails after command capability is removed;
* exact and altered cross-actor replay attempts fail with the same owner error;
* document-derived semantic scopes reauthorize without mutable business state;
* new receipts contain actor ownership and canonical semantic scope;
* all governed callable emulator suites remain green.

## Exact source evidence

```text
Repository:      abhishekvatsa/crm3_baf_ops
Baseline commit: efd41221b8d13c612ae075bc1651b74d1f97be8d
Source commit:   e15b9676fc1e6e5c5ef56ff161f8558cac80dadf
Source tree:     7c1f5b387756f37d7d99a7bded2ca77abc616145
Decision:        PASS_SOURCE_S09_ATOMIC_WORKFLOW_AUTHORITY_AND_REPLAY
```

## Exact merge and post-merge evidence

```text
Repository:              abhishekvatsa/crm3_baf_ops
Pull request:            #47
Head commit:             5a2d7e62fc7de810e6edbf8a69e9558c90930c8b
Merge commit:            3c0861dcfe032ae795833283f9a7d63a45dde7e3
Post-merge workflow run: 30196339736
Decision:                PASS_GATE_1A_S09_ATOMIC_WORKFLOW_AUTHORITY_AND_REPLAY
```

All six exact-head release-gate checks across the branch-push and pull-request
runs passed. All three release-gate jobs also passed on the exact merge commit.
The finding is therefore `CLOSED` as a source-and-CI finding.

Closure does not dispose of legacy receipts. Their read-only inventory and any
governed reconciliation remain pilot/cutover prerequisites.

## Authorization boundary

This source correction authorizes local validation, CI, review and a governed
pull request only. It does not authorize Functions or Rules deployment,
production mutation, legacy-receipt reconciliation, pilot operation, handout
or cutover.
