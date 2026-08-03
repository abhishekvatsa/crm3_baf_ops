# R-05 Notification Event Idempotency

Status: SOURCE_IMPLEMENTED

Merge and post-merge CI evidence: PENDING

Deployment, delivery and pilot evidence: NOT CLAIMED

## Finding

Three legacy Firestore notification triggers sent directly after recipient
lookup and had no event receipt. The maintenance-workflow trigger used a lease,
but reset a failed receipt after any exception. A crash after FCM accepted a
message but before the completion write could therefore cause an automatic
retry to send the same notification again.

## Source Decision

All four notification triggers now call
`executeIdempotentNotificationEvent` and enable Cloud Functions retries:

```text
onTicketCreated
onTicketResolved
onJobAssigned
onMaintenanceWorkflowEventCreated
```

The Functions build runs a TypeScript-AST inventory over exported Firestore
triggers and notification dispatch calls. It compares the discovered surface
to a governed policy, rejects new or removed triggers until adjudicated,
rejects unowned or directly invoked FCM dispatch, and requires every send to
remain inside the coordinator's `dispatch` callback. Aliased imports remain
discoverable.

The receipt document ID is SHA-256 over a versioned namespace, the exported
trigger name and the immutable CloudEvent ID. The receipt also stores and
validates the trigger name, CloudEvent ID and source-document path. A schema
mismatch, identity mismatch, malformed attempt counter, malformed lease,
unknown state, missing receipt or stale attempt fails closed before dispatch.

## State Boundary

```text
preparing
  -> failedBeforeDispatch -> retry may reacquire
  -> suppressed           -> replay skips
  -> dispatching
       -> completed        -> replay skips
       -> deliveryUncertain -> replay skips
```

The preparing lease permits recovery only while no external delivery has
begun. An attempt ID is transaction-bound, so an expired attempt cannot resume
after another attempt takes ownership.

Immediately before FCM, the receipt moves transactionally to `dispatching`.
Neither `dispatching` nor `deliveryUncertain` can be automatically reacquired.
This is deliberate: Firestore and FCM do not share an atomic transaction, so a
timeout or crash after dispatch begins cannot prove whether a message reached
FCM.

This is not an exactly-once delivery claim. It is an at-most-one automatic
dispatch policy with retryable pre-dispatch preparation. The narrow opposite
risk is notification loss if a process stops after committing `dispatching`
but before invoking FCM. Such a receipt requires governed operational
adjudication; automatic resend is prohibited because it could duplicate a
message that FCM already accepted.

Entering `dispatching` durably sets `requiresAdjudication: true`; completion
clears it. A process stop therefore leaves an operator-queryable marker even
when no catch block can run. Every caught ambiguous dispatch also emits a
structured error-level signal with the receipt ID, immutable event identity,
attempt ID and failure phase. The signal excludes notification payload and
recipient data. A reporting failure cannot reopen or resend the event.

When a pre-dispatch failure is safely retried, the next attempt clears the
active `lastError`; successful completion records `requiresAdjudication: false`.
Historical attempt timestamps remain available without making a recovered
receipt appear currently failed.

## Legacy Boundary

`workflow_notification_receipts` remains client-denied and is no longer
written by current source. A workflow event with any historical receipt under
its source event ID is suppressed into the new receipt collection rather than
silently re-dispatched. This quarantines both completed and ambiguous legacy
attempts.

The other three triggers had no historical receipts. Deployment must therefore
be governed so old trigger revisions are quiescent before the new revision is
treated as authoritative. This source change does not claim that deployment or
readback.

## Client Boundary

Firestore Rules deny all client reads and writes to
`notification_event_receipts`. Only server code using Admin SDK authority may
create or transition a receipt.

## Verification

Focused source proof on 2026-08-01:

```text
TypeScript build and callable inventory: PASS
Notification-surface discovery tests:   5 passed
Receipt state-machine unit tests:       11 passed
Firestore receipt emulator tests:       3 passed
Firestore Rules tests:                  145 passed
```

The unit suite proves deterministic identity, completed replay, retryable
pre-dispatch failure, active-lease exclusion, expired-lease takeover,
stale-attempt rejection, exhausted-counter rejection, durable suppression,
delivery uncertainty and malformed-receipt rejection. They also prove
the durable dispatching marker, structured uncertainty reporting,
recovered-error cleanup and that an observability failure cannot weaken the
non-replayable boundary.

The emulator suite proves that twelve concurrent copies of one event produce
one dispatch, completed replay performs no preparation or dispatch, and a
failed dispatch is quarantined without a second delivery attempt.

## Closure Boundary

R-05 remains `SOURCE_IMPLEMENTED`. Closure requires exact-head pull-request CI,
merge evidence and passing post-merge CI for the admitted source. This record
does not authorize deployment, assert receipt data exists in production, prove
FCM delivery, authorize pilot handout or advance a programme gate.
