# S-06 Atomic Closure Authority

## Finding

The planned-job closure callable previously authorized the actor with a direct
`users/{uid}` read before entering the Firestore transaction:

```text
read actor
authorize actor
start transaction
read execution and modules
write completion and audit
```

An authority change between the direct read and transaction start could leave
the business transaction acting on stale authorization.

## Source decision

Closure authority is now part of the same transaction as the closure decision:

```text
parse and validate request
start transaction
read users/{uid}
fail closed unless the current authority capsule permits closure
read job_executions/{executionId}
return an authorized idempotent replay when already complete
read canonical job_modules when a new closure is required
write completion and audit atomically
```

The authority read is the first Firestore read in the transaction. A denied,
missing, unapproved, malformed, or non-completer authority document returns
`permission-denied` with reason code `closure-authority-denied` before the
execution document or module query is read.

Idempotent completion replay remains authorization-gated. A caller who no
longer has closure authority cannot use a completed execution to bypass the
current authority check.

## Concurrency contract

Firestore includes `users/{uid}` in the transaction read set. A closure
transaction therefore cannot commit from an authority snapshot that conflicts
with a concurrent authority mutation. The deterministic emulator regression
also pauses an invocation immediately before transaction start, revokes the
actor, and proves that the transaction reads the revoked state and performs no
execution, module, or audit mutation.

The valid serialized outcomes are:

```text
closure transaction first  -> closure may commit, then authority may change
authority mutation first    -> closure reads new authority and fails closed
```

There is no longer an authorized-outside-the-transaction state that can be
carried into a later closure commit.

## Evidence

The source and test contract is held by:

```text
functions/src/plannedJobClosure.ts
functions/test/plannedJobClosure.test.js
functions/test/plannedJobClosure.firestoreEmulator.test.js
functions/test/newBehavior.test.js
tools/v4/v4_2_r1_canonical_audit.py
```

The tests prove:

* invalid requests fail before database work;
* authority is read with `transaction.get`;
* authority rejection precedes execution and module reads;
* authority rejection produces no completion or audit write;
* revocation before transaction start fails closed;
* authorized new closure and authorized idempotent replay remain sound.

## Exact merge evidence

```text
Repository:   abhishekvatsa/crm3_baf_ops
Pull request: #45
Head commit:  1bf9292cc16c35775f8d005eae477e76ad7135fc
Merge commit: d48ad31985d98f9415923b36bc5acb8133de7068
Decision:     PASS_GATE_1A_S06_ATOMIC_CLOSURE_AUTHORITY
```

All six release-gate jobs passed at the exact head. The merge closes the S-06
source-and-CI finding. It does not change the deployment boundary below.

## Authorization boundary

This source correction authorizes source review, local validation, CI, and an
exact-head pull-request merge only. It does not authorize Functions or Rules
deployment, production writes, authority changes, App Check changes, pilot
operation, or cutover.
