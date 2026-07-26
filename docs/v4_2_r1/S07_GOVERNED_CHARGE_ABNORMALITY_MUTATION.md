# S-07 Governed Charge-Abnormality Mutation

Status: CLOSED

Source commit: `880a46f4c2530e5d2d830b5c083ec2688551cb4e`

Source and merge tree: `1d10661ed09e14f82352a3c1bf2e0b90ee5d3633`

Pull request: #52

Merge commit: `31c890bb96518365ba0365a0e9b8e2cd79abb9de`

Post-merge workflow run: `30214251697`

Decision: `PASS_GATE_1A_S07_GOVERNED_CHARGE_ABNORMALITY_MUTATION`

## Finding

An approved Admin could previously update any field in
`charge_abnormalities/{id}` because Rules used:

```text
allow update: if isAdmin()
```

The app then performed:

```text
read current abnormality
write merged abnormality document
write a separate best-effort audit event
```

The update had no server-owned immutable-field boundary, no transactional
version check, and no atomic coupling between business state and audit state.
Soft deletion used the same unconstrained update permission and separate audit
sequence.

## Source Decision

Admin `UPDATE` and `SOFT_DELETE` operations now use the
`mutateChargeAbnormality` callable:

```text
parse exact request
read and authorize current actor
apply transactional per-actor abuse control
start Firestore transaction
revalidate current approved-Admin authority
read receipt, abnormality, and deterministic audit identity
validate complete current document shape and expected version
for UPDATE, read and validate the active abnormality type
write abnormality, immutable audit, and replay receipt atomically
```

Firestore Rules deny every direct client update to
`charge_abnormalities/{id}`. Clients also cannot read or mutate
`charge_abnormality_mutation_receipts`, or pre-create a
`server_charge_abnormality_*` audit identity.

## Transaction Invariants

- Canonical UUID request IDs bind to one actor and normalized payload.
- The actor is an approved Admin both before database work and again inside the
  business transaction.
- `expectedVersion` must match a positive, safe, complete current document;
  each accepted mutation advances exactly one version.
- The document identity, source charge, original logger, original log time,
  and existing external links are not client-mutable.
- Updates may change only the abnormality type selection, severity, affected
  assets, observation fields, root-reason fields, and RA state.
- The selected abnormality type must exist, be active, be undeleted, and have a
  valid canonical code, title, category, and severity. The server writes its
  canonical code, title, and category instead of trusting client copies.
- Enum values, text bounds, asset identities, duplicate assets, and positive
  integer bounds are validated.
- Completed RA requires a positive target charge; a target charge requires
  completed status; the target cannot equal the immutable source charge.
- Deleted records cannot be updated or deleted again.
- The abnormality document, high-severity immutable audit, and request receipt
  commit in one transaction or not at all.
- Exact replay requires the same actor and payload and verifies that the
  current document, audit, receipt, version, and deterministic identities still
  agree. Missing or drifted evidence fails closed.

## Client And Sync Routing

The Admin screen calls the governed service directly and rebases its local
record from the verified canonical response. A privileged edit therefore
requires the governed backend and no longer creates a separate client audit.

Older mobile installations may already hold an unsynchronized Admin edit.
The current sync engine preserves those records and submits a single-version
update or soft deletion through the same callable. Its request identity is
deterministic over operation, document identity, and local version, so a lost
response cannot create an unbounded duplicate mutation. Durable server
rejections remain visible as sync failures and keep local evidence available.

New charge-abnormality creation remains an approved-user client operation and
is outside this Admin-update finding. Its Rules contract now requires the full
known field set, exact version 1, valid enums, bounded values, a coherent RA
state, immutable deletion defaults, and no unknown fields. This document does
not claim that the existing client-side creation audit is atomically coupled.

## Verification

Local verification on 2026-07-26:

```text
Functions build and non-emulator tests: 308 passed, 54 emulator tests skipped
Firestore Rules suite:                 144 passed
Governed transaction emulator suite:    54 passed
Focused S-07 Functions tests:            13 passed
Focused S-07 emulator tests:              4 passed
Focused S-07 Flutter tests:               5 passed
Flutter analyze:                          no issues
Flutter full test suite:                488 passed
```

The emulator proves concurrent same-version updates permit exactly one commit
and one evidence set. It also proves exact replay, atomic soft deletion, and
full rollback for malformed current state.

PR #52 passed both exact-head workflow invocations. The exact merge commit then
passed the main-branch release gate in run `30214251697`, including Functions,
Firestore Rules and governed transaction emulators, Flutter analysis and tests,
the canonical audit, the no-loss regression spine, and the Rules
expression-limit check.

## Deployment Boundary

This closes the S-07 source-and-CI finding. It does not authorize Functions or
Rules deployment, production writes, pilot operation, or cutover.

Before this boundary is enabled outside source review:

1. Existing `charge_abnormalities` documents must undergo governed
   reconciliation against the complete schema and business invariants.
2. The callable and its abuse-control state must be deployed and attested.
3. A compatible client must be distributed under the existing release-custody
   controls.
4. Direct-update Rules denial must be enabled only under the governed cutover
   sequence.

The current production signing environment and release secrets remain absent,
so this change creates no production authority.
