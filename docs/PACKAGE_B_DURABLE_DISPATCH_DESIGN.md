# Package B — durable dispatch: design for review

**Status: design only. Nothing here is implemented.** For review before any
dispatch mechanics are written.

Reference baseline `4cbf702e20eadee40cc960894daa65a6fedc1c87`, plus the recovery
baseline added at `6113d2bf`. Every source claim below was read at that baseline
rather than recalled.

## 0. What problem this actually solves

On 2026-09-09 a handset stopped syncing. The cause was stock Android
`BLOCKED_REASON_APP_BACKGROUND`: the platform withdrew network access while the
app was backgrounded. That is not a defect in this application.

The defect is what the application does about it. **There is no durable record
of an intent to dispatch before the gateway is called**, and no way to continue
work while backgrounded. Every correction since has made the existing path more
honest about failing. None has made it able to finish.

Two attempts to bolt a narrow version of this onto the sync creation path were
withdrawn — they produced a leaked journal row, a write that raced acceptance,
and an escalation rule documented but never applied in the owner they created.
The lesson taken is that this lifecycle cannot be added incrementally to a path
that has no owner. It needs one owner, designed once.

## 1. Current-path map

### 1.1 Who dispatches

`grep -rn "\.execute(command)" lib/` returns 23 sites. One of those is the
executor's own `gateway.execute(command)`, i.e. the shared implementation rather
than an initiator. `WorkflowUncertainRetryService` calls
`executor.execute(command, claimedAt:)` and so does not match that pattern.

Counting initiators:

| Route | Sites | Journal? |
| --- | --- | --- |
| `WorkflowCommandController` → `WorkflowOnlineExecutor.execute` | **18** UI sites across ticket, lane, inspection, planned-job, admin and asset screens | **Yes** |
| `WorkflowUncertainRetryService` → `executor.execute` | 1 | **Yes** |
| `SyncService` → `_maintenanceCommands.execute` directly | 2 — `_pushMissingMaintenanceTicket`, `_tryRecoverAcceptedMaintenanceCreation` | **No** |
| `CriticalAlarmCommandService` → `gateway.execute` directly | 2 — first attempt and one immediate same-id replay | **No**, deliberately |

23 initiators; 19 of them already journaled.

`WorkflowCommandController` is constructed with a `WorkflowOnlineExecutor` and
binds `_executeCommand = executor.execute`, so every UI dispatch is journaled.
That is better than it first appears, and it means Package B does not have to
rewrite the UI.

### 1.2 Who writes the journal

Only four call sites write `WorkflowCommandRecord`, all inside two files:

| Writer | Operation |
| --- | --- |
| `workflow_online_executor.dart:146` | `settleAccepted` — stores the receipt and deletes the retry row |
| `workflow_online_executor.dart:245` | `applyRetryTransitionUnlessAccepted` — platform-block hold |
| `workflow_online_executor.dart:282` | `applyRetryTransitionUnlessAccepted` — failure recording |
| `workflow_uncertain_retry_service.dart:133` | `applyRetryTransitionUnlessAccepted` — malformed payload |

`applyRetryTransitionUnlessAccepted` reads the receipt inside the write
transaction and returns `alreadyAccepted` without calling the build callback, so
acceptance always wins. `settleAccepted` puts the receipt and deletes the row in
one transaction. **These are the contracts any new owner must use.** The
withdrawn attempts failed precisely by not using them.

### 1.3 Ownership today

`claimRetryableCommands(now, lease, limit, exclude)` selects in one write
transaction: rows in `uncertainOutcome` whose `nextRetryAt` is due, and rows in
`sending` whose lease has expired (a caller that died mid-send). It stamps
`lastAttemptAt` as the claim. `releaseClaim` is fenced on that timestamp.

`ready` is **not** claimable. That is why the withdrawn attempt's rows leaked:
nothing could finish them.

### 1.4 What the journal states mean

`ready | sending | uncertainOutcome | applied | rejected | manualReview`.
`readOutcomeInventory` counts `ready + uncertainOutcome` as *retrying*,
`rejected + manualReview` as needing action. `describeWorkflowAttention` is the
single decision point for what an operator is told.

### 1.5 The gap, stated exactly

The intent to dispatch is durable only **after** the gateway has been called and
failed. `_recordFailure` runs in the failure path. If the process stops between
building a command and receiving a response, there is no row, and no evidence
the operator's action ever existed beyond the business record's `isSynced=false`.

## 2. Three facts that must never collapse into one

B0 demonstrated this concretely: an accepted creation can be refused local
adoption because the operator edited the row while the request was in flight,
and the service already logs exactly that. The design must represent, separately:

| Fact | Meaning | Evidence |
| --- | --- | --- |
| **Accepted** | The server applied the operation | A stored receipt |
| **Adopted** | This device holds the resulting state | Business record updated from validated server state |
| **Superseded** | Newer local work exists | Snapshot mismatch at adoption |

Collapsing these into "synced / failed" is how work gets lost. A failed adoption
must never downgrade an acceptance, and newer local work must never be
overwritten to make a record look adopted.

## 3. Proposed transition table

`Intent` is the new state: durable, written **before** the gateway call.

| # | Trigger | Actor | Precondition | Durable transaction | Owner after | Result | Operator sees |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Operator submits | signed-in uid | none | create row `intent`, identity fixed, payload frozen, `originActorUid` stamped | dispatcher | `intent` | "Saved, sending" |
| 2 | Dispatch begins | must equal `originActorUid` | row `intent`/`uncertainOutcome` due | claim → `sending`, fence `claimedAt` | this claim | `sending` | "Sending" |
| 3 | Receipt returned | any | receipt validates | `settleAccepted` — store receipt, delete row | none | accepted | "Recorded" |
| 4 | Adoption succeeds | any | snapshot matches | business record updated | none | adopted | "Recorded" |
| 5 | **Adoption refused, snapshot stale** | any | acceptance stands | receipt **kept**; business row untouched | none | accepted + superseded | "Recorded; your newer edit was kept" |
| 6 | Transport uncertain | claim holder | fence matches | `applyRetryTransitionUnlessAccepted` → `uncertainOutcome`, attempt+1, `nextRetryAt` | retry service | `uncertainOutcome` | "Will retry" |
| 7 | Quota refusal | claim holder | fence matches | as 6 but attempt **unchanged**, `nextRetryAt` = max(backoff, server window) | retry service | `uncertainOutcome` | "Waiting, server asked us to slow down" |
| 8 | Quota refusal past deferral | claim holder | `now - createdLocallyAt >= maxQuotaDeferral` | → `manualReview`, `nextRetryAt` null | person | `manualReview` | "Needs attention" |
| 9 | Definite rejection | claim holder | fence matches | → `rejected` | person | `rejected` | "Not accepted: reason" |
| 10 | Attempts exhausted | claim holder | `attempts >= 8` | → `manualReview` | person | `manualReview` | "Needs attention" |
| 11 | Claim expires | — | `sending`, lease passed | reclaimable | next run | `sending`→claimable | unchanged |
| 12 | **Account changes mid-flight** | — | see §4 | outcome settled under `originActorUid`; **no new dispatch** | none/person | accepted or `manualReview` | "Recorded" or "Needs attention" |
| 13 | Local cancel/tombstone before dispatch | origin actor | row `intent`, never sent | delete row | none | none | "Discarded" |
| 14 | Local cancel after acceptance | — | receipt exists | receipt kept; deletion handled as its own operation | none | accepted | "Already recorded; deleting separately" |

Rows 5, 12, 13 and 14 are the ones absent today. Row 8 exists in the executor
only. Rows 1 and 2 are the durable intent this package adds.

**Returned failures count as transitions.** `WorkflowRetryTransition` already
distinguishes `recorded` / `noChange` / `alreadyAccepted`; a `noChange` must
never be reported as a recorded decision. That bug was fixed once already.

## 4. The actor rule

Two wrong answers to avoid:

- Discard a late authoritative result because the session changed. **Loses
  accepted work.**
- Let whoever is signed in now continue someone else's pending dispatch.
  **Attributes one person's action to another.**

Proposed rule, split by direction:

| Situation | Rule |
| --- | --- |
| Settling an **outcome** for an already-dispatched command | Permitted regardless of current session. The receipt is authoritative and is attributed to `originActorUid`, not the current user. |
| **Dispatching** an `intent` or retrying an `uncertainOutcome` | Requires current session == `originActorUid`. Otherwise the row is left claimable and untouched. |
| Row whose origin actor never signs in again | After the deferral bound, `manualReview`, attributed to the original actor. |

Today the uid is read once before `_retry` and not rechecked per attempt. The
B0 suite proves the session is re-read **between service runs**; it does not
establish in-flight safety, and I am not claiming it does.

## 5. Failure-sequence walkthroughs

| Sequence | Today | Under this design |
| --- | --- | --- |
| Process stops **before** dispatch | No row. Intent exists only as `isSynced=false`; the sync path may rebuild and resend | Row in `intent` with frozen identity and payload; resumes as the same request |
| Process stops **after** dispatch, before response | No row unless the failure path ran | `sending` with expired lease → reclaimed → replayed under the same id → server idempotency returns the original receipt |
| Response lost after acceptance | `uncertainOutcome`, retried, server replays receipt | Same, but a row exists even if the process died first |
| Account changes during execution | Undefined; uid read once before `_retry` | Outcome settles under `originActorUid`; no new dispatch by the new account (§4) |
| Claim expires while alive | Fenced write fails; `noChange` | Unchanged — the fence already works |
| Quota refusal | Classified retryable, delay honoured **within** one run only | Durable `nextRetryAt` consulted before dispatch; the open CR-07 gap closes as a consequence, not as a special case |
| Receipt unreadable | Treated as uncertain, not absent | Unchanged |
| **Accepted, adoption refused** | Logged, ticket stays pending, receipt kept | Explicit `accepted + superseded` (row 5); operator told their newer edit was kept |
| Backgrounded, network withdrawn | Nothing continues | Out of scope for the first slice — see §6 |

## 6. First implementation slice, and what it excludes

**One operation: governed maintenance issue creation.** Chosen because B0 now
covers its acceptance, recovery, contradiction and concurrent-edit behaviour
against the real repository, so regressions are detectable.

Slice contents:

1. Write `intent` before the gateway call, in the same transaction that marks
   the business record pending.
2. Move `SyncService`'s two dispatch sites behind the executor, so the journal
   has one writer. This subsumes the withdrawn quota work.
3. Settle through `settleAccepted`; represent refused adoption as row 5 rather
   than as failure.
4. Apply the deferral bound in the owner, not only in the executor.

**Explicitly not in this slice:** WorkManager or any background scheduler; a
schema migration; a generic outbox framework; critical-alarm changes (it
deliberately avoids delayed retry, and the plant emergency route stays primary);
and the other 20 initiators.

Background continuation is a **later** slice. Durable intent is worth having on
its own: it survives process death, which the incident also involved.

### Migration of existing pending work

Rows already in `uncertainOutcome` or `manualReview` keep their identity,
payload and `createdLocallyAt`. They gain no `originActorUid`, so §4's dispatch
rule cannot be applied to them; they are treated as dispatchable by their
recorded reporter, matching today's behaviour, and this is the one deliberate
compatibility concession. No row is rewritten to fit the new shape.

`SyncService` stops owning creation dispatch at the moment step 2 lands, not
gradually. A partially migrated state with two owners is exactly the condition
that produced the withdrawn attempts.

### Rollback

Steps 1–4 are additive to the journal and reversible by reverting the commits;
no stored row changes shape. If step 2 is reverted, sync resumes direct dispatch
and the CR-07 gap reopens — which is the current state, not a regression.

## 7. Open questions for the reviewer

1. **Row 5's operator message.** "Recorded; your newer edit was kept" is
   accurate but may be confusing mid-shift. Better wording welcome.
2. **§4 for pre-existing rows.** The concession above is the weakest point of
   this design. The alternative — refusing to dispatch any row without an
   origin actor — would strand existing pending work.
3. **Whether `intent` should be claimable by the retry service**, or dispatched
   only by the originating run. Claimable is more robust; it also widens
   ownership, which is what went wrong before.
4. **Deferral constants.** Six hours and five minutes are judgement, not
   measurement, and should be revisited against real rate-limit behaviour.

## 8. What this design does not claim

It is not implemented, not reviewed, and not tested. It does not establish that
the backend is idempotent under replay — that needs backend or integrated
evidence. It does not address background continuation. And nothing in the
lifecycle work so far, including B0, reaches *device path demonstrated*.
