# R-03 Sync Request Outcome Remediation

Status: SOURCE_IMPLEMENTED

Merge and exact-head CI evidence: PENDING

## Finding

`SyncCoordinator.runFullSyncWithResult()` returned a boolean. `false` meant
three materially different things:

```text
the sync ran and failed
the request was queued behind a running sync
the request was throttled because another sync ran recently
```

Result-aware callers therefore could not preserve the difference between an
execution failure and deferred admission. Automatic health explicitly
displayed `Skipped / failed`, while manual surfaces used ambiguous failure
wording.

## Source Decision

The boolean has been replaced by `SyncRequestOutcome`:

| Outcome | Meaning | Successful | Failure | Deferred |
| --- | --- | --- | --- | --- |
| `succeeded` | A full run completed without push failures | yes | no | no |
| `failed` | A run completed with failures or threw | no | yes | no |
| `queued` | One coalesced follow-up was accepted behind the active run | no | no | yes |
| `throttled` | A non-forced request was skipped inside the minimum gap | no | no | yes |

This is not a relaxation of any confirmation gate. Startup synchronization,
normal-ticket retry cancellation, and governed Composer confirmation continue
to require `isSuccessful`. Queued and throttled requests remain non-successful
until a real run completes.

## Caller Treatment

- Automatic health records the exact outcome and no longer records deferred
  admission as a completed failure.
- Manual surfaces distinguish successful, failed, queued, and throttled
  requests.
- A queued immediate ticket sync does not clear its five-minute retry.
- Auth startup does not set `syncOnceProvider` for deferred admission.
- Composer reloads authoritative local state after every attempt and still
  refuses publish eligibility until the same draft is remotely confirmed.
- Fire-and-forget callers remain unchanged because they do not make a result
  claim.

## Verification

Local source verification on 2026-07-31:

```text
Flutter analyze:                  no issues
Focused R-03 and caller tests:    39 passed
Full Flutter suite:               553 passed
Functions non-emulator suite:     320 passed
Firestore Rules suite:            145 passed
Governed transaction emulator:     58 passed
Canonical R1 audit:                84 passed, 0 failed
```

The focused matrix covers the four outcome predicates and labels, queue and
throttle admission, manual messaging, pending follow-up health, startup
contracts, mounted-context safety, and Composer save/sync/refresh behavior.

## Remaining Boundary

`R-03` remains `SOURCE_IMPLEMENTED`. Closure requires the exact pull-request
head and the admitted post-merge main commit to pass the governed CI matrix.
The first available run after implementation did not execute any job steps
because GitHub reported an account payment or spending-limit condition. That
external condition is not source evidence and is not bypassed here.

No production deployment, device proof, F4 closure, pilot authorization, or
cutover is claimed by this document.
