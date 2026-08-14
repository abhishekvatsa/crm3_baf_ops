# Quality Warning and Monitoring Lifecycle

Status: SOURCE IMPLEMENTED AND LOCALLY VERIFIED

## Purpose

This tranche gives suspected product-quality impact an explicit, governed
lifecycle instead of leaving it as free text inside an issue or charge
abnormality.

It covers:

- issue-originated quality warnings;
- abnormality-originated quality warnings;
- operational requests to close a warning;
- SI/Admin adjudication, closure and reopening;
- Base, Grade, cycle and optional charge monitoring requests; and
- strict persisted-data reconciliation for both quality collections.

## Warning Creation

An issue records one complete quality assessment:

- `notSuspected`; or
- `suspected`, with a positive charge number and a reason of at least eight
  characters.

The assessment fields are present together or absent together for a legacy
record. A partial current field set fails closed. Opaque pre-feature local
metadata remains readable only when it does not claim to contain a current
`qualityIntent` envelope.

A suspected issue and its warning are written in the same Firestore batch. A
charge abnormality always requires a paired warning in the same way. Warning
IDs are deterministic:

- `issue_<maintenance-record-id>`; and
- `abnormality_<charge-abnormality-id>`.

Rules verify the warning against its source identity, version, charge,
summary, severity, reason, asset/component projection, timestamp and actor.
A missing warning blocks the source mutation. A pre-existing warning satisfies
the pairing requirement only when its original projection still matches the
source. Historical remediation must therefore use a governed backfill; another
client actor cannot manufacture or replace source evidence.

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
| Close or reopen warning | No | No | Yes | Yes |
| Create or close monitoring request | No | No | Yes | Yes |

Client Rules permit only a valid source-bound warning create and an exact
no-op retry. Warning lifecycle changes, monitoring changes, receipts and
server audit events are committed only by the governed callable.

The quality operation is carried over the existing secured
`mutateChargeAbnormality` callable surface. The callable performs authority
preflight, repeats authority validation in the transaction, validates the
entire persisted target, enforces optimistic versioning, writes immutable
audit evidence and records an idempotency receipt. Exact replay returns the
same result without additional writes.

## Closure Lifecycle

Warnings move through:

`open -> closureRequested -> closed`

SI/Admin may also close an open warning directly when they already possess the
decision evidence. Operations or a Shift Supervisor may request closure with
an explicit reason but cannot decide it. A closure request is retained as
evidence after the final decision.

A closed warning records one disposition:

- `coilFoundAcceptable`;
- `reannealingCompleted`; or
- `qualityAdjudication`.

Re-annealing closure requires one to twenty distinct positive target charge
numbers. Those references are explicit evidence supplied and accepted by the
SI/Admin adjudicator. They are not represented as an automatic database lookup
or a machine assertion that the referenced RA records exist. Other
dispositions reject RA charge references.

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

The operational screen uses bounded live windows: 500 recently updated
warnings and 250 recently updated monitoring requests. It discloses the bound
when reached. Complete historical analysis belongs to the report/archive path
rather than an unbounded live Firestore listener.

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
