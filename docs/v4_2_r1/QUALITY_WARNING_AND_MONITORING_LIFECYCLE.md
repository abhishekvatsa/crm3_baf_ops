# Quality Warning and Monitoring Lifecycle

Status: SOURCE IMPLEMENTED AND LOCALLY VERIFIED

## Purpose

This tranche gives suspected product-quality impact an explicit, governed
lifecycle instead of leaving it as free text inside an issue or charge
abnormality.

It covers:

- issue-originated quality warnings;
- abnormality-originated quality warnings;
- connected issue, charge-abnormality and warning cases;
- governed RA decision, completion and reopening transitions;
- operational requests to close a warning;
- SI/Admin adjudication, closure and reopening;
- Base, Grade, cycle and optional charge monitoring requests; and
- strict persisted-data reconciliation for both quality collections.

## Warning Creation

An issue records one complete quality assessment under schema version 2:

- `notSuspected`; or
- `suspected`, with an exact five-digit charge number, a reason of at least
  eight characters and an active governed abnormality type that applies to the
  selected asset class.

The assessment fields are present together or absent together for a legacy
record. A partial current field set fails closed. Opaque pre-feature local
metadata remains readable only when it does not claim to contain a current
`qualityIntent` envelope.

A suspected issue, linked charge abnormality and one shared warning are written
atomically by the governed maintenance command, together with audit and
idempotency evidence. The linked abnormality begins at `pendingDecision` and
uses the issue's charge, asset, component, observation, severity, actor and
timestamp evidence. Their deterministic identities are:

- issue: `<maintenance-record-id>`;
- abnormality: `issue_quality_<maintenance-record-id>`;
- warning and shared case: `issue_<maintenance-record-id>`.

The maintenance record retains all three links. Replay revalidates the issue,
abnormality and warning before returning the original receipt. Direct client
creation of an issue-originated connected case is denied.

A standalone charge abnormality still requires a paired warning in the same
client batch. Standalone warning IDs are deterministic:

- `abnormality_<charge-abnormality-id>`.

The governed maintenance command validates and constructs the complete issue
projection. Rules verify an abnormality warning against its source identity,
version, charge, summary, severity, reason, asset/component projection,
timestamp and actor. A missing abnormality warning blocks the source mutation.
A pre-existing warning satisfies the pairing requirement only when its
original projection still matches the source. Historical remediation must
therefore use a governed backfill; another client actor cannot manufacture or
replace source evidence.

Repository batches are limited to 250 source records because each record can
require a second warning write. This preserves each source/warning pair within
Firestore's 500-write batch ceiling.

## Authority

All approved users may view quality warnings. The business actions are
separated as follows:

| Action | Operations | Shift Supervisor | SI | Admin |
|---|---:|---:|---:|---:|
| View warnings | Yes | Yes | Yes | Yes |
| Request warning closure | Yes | Yes | Yes | Yes |
| Declare RA required | No | No | Yes | Yes |
| Close or reopen warning | No | No | Yes | Yes |
| Create or close monitoring request | No | No | Yes | Yes |

Client Rules permit only a valid abnormality-bound warning create and an exact
no-op retry. Issue-originated warning creation, warning lifecycle changes,
monitoring changes, receipts and server audit events are committed only by the
governed backend.

The quality operation is carried over the existing secured
`mutateChargeAbnormality` callable surface. The callable performs authority
preflight, repeats authority validation in the transaction, validates the
entire persisted target, enforces optimistic versioning, writes immutable
audit evidence and records an idempotency receipt. Exact replay returns the
same result without additional writes.

## Closure Lifecycle

Warning review state moves through:

`open -> closureRequested -> closed`

SI/Admin may also close an open warning directly when they already possess the
decision evidence. Operations or a Shift Supervisor may request closure with
an explicit reason but cannot decide it. A closure request is retained as
evidence after the final decision.

A closed warning records one disposition:

- `coilFoundAcceptable`;
- `reannealingCompleted`; or
- `qualityAdjudication`.

For a connected case, quality adjudication also advances the charge
abnormality in the same transaction:

- initial suspicion or reopening -> `pendingDecision`;
- explicit SI/Admin decision -> `required`, while the warning remains open;
- coil acceptable or other non-RA adjudication -> `notRequired` and warning
  closure; and
- re-annealing closure -> `completed` with exactly one new and different
  five-digit charge number.

The warning and abnormality versions advance together and both are bound into
the immutable audit and replay receipt. A missing or contradictory case link,
multiple RA targets, or an RA target matching the source charge fails closed.
Standalone abnormalities follow the same warning synchronization rule when
their source or RA state is changed. Linked issue abnormalities cannot be
deleted independently; a standalone abnormality can be retired only after its
warning is closed.

SI/Admin may reopen a closed warning with a reason. Reopening clears the prior
closure decision while preserving the action in immutable audit history.

Malformed or partial request evidence, closure evidence, charge references,
identity, timestamps, versions or callable receipts fail closed. Wrong-role,
stale-version and malformed-target attempts are write-free.

## Monitoring

SI/Admin may create a monitoring request containing:

- a positive Base number;
- Grade;
- cycle reference;
- zero to fifty distinct positive charge numbers; and
- a monitoring reason.

The request remains active until SI/Admin records completion evidence. The
quality workspace presents warnings and monitoring as separate views, with
open, review and closed warning filters and role-appropriate actions.

The operational screen uses bounded live windows: every non-closed warning plus
500 recently updated warnings, and every active monitoring request plus 250
recently updated monitoring requests. It discloses the recent-history bound
when reached. Complete historical analysis belongs to the report/archive path
rather than an unbounded live Firestore listener.

The Quality workspace opens on Warnings and shows actionable counts in both tab
labels. Operational Control presents separate warning and cycle-monitoring
counts so active monitoring is visible without first opening its tab.

## Persisted-State Coverage

The current A-05 machine inventory covers 45 persisted decoder surfaces, 37
decoder exception sites, 26 strict-reader files, 24 raw-JSON consumer files,
243 risk candidates and 40 timestamp readers. No new file or exception site is
unclassified.

The read-only production sweep registry treats `quality_warnings` and
`quality_monitoring_requests` as app records that require reconciliation
through the real Dart readers. `quality_mutation_receipts` is counted as a
server-control collection and is not misrepresented as app-decoder evidence.

The historical A-05 closure record remains immutable evidence of the source
and production population measured when A-05 closed. The current inventory is
an expansion of that continuing source control, not a rewrite of historical
evidence.

## Deployment Boundary

Source verification does not deploy or activate this lifecycle. Production
activation requires one coordinated release containing:

1. the updated Firestore Rules;
2. the updated Functions deployment; and
3. a client build containing the issue assessment and Quality workspace.

Deploying only one layer would either reject the new client writes or expose a
screen whose governed commands are unavailable. Production data should be
reconciled read-only before activation, and any historical source records that
require warnings should be handled through a separate governed backfill.

No pilot, distribution or cutover gate is closed by this source tranche alone.
