# Package B — durable dispatch: design for review

**Status: design only, revision 2. Nothing here is implemented.** For review
before any dispatch mechanics are written.

Revision 2 answers a review of revision 1. The corrections were substantive and
are marked **[r2]** where they change what revision 1 said. Two of them mean
revision 1 understated the work.

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

23 initiators; 19 **route through the journal-aware executor**.

**[r2] That is not the same as "already journaled", and revision 1 was wrong to
say so.** `WorkflowOnlineExecutor.execute` calls the gateway *first* and records
only selected failure outcomes afterwards. On the ordinary connected path it
does not persist an intent, does not consult `nextRetryAt`, and does not acquire
an exclusive claim — its claim handling is in outcome recording. A failure with
no pre-existing row and a non-retryable disposition produces no row at all.

The consequence for scope: **replacing SyncService's direct gateway call with
`executor.execute` would not, on its own, give it durable intent, deadline
enforcement or exclusive dispatch.** Revision 1 implied this was mostly a
routing change. It is not.

`WorkflowCommandController` is constructed with a `WorkflowOnlineExecutor` and
binds `_executeCommand = executor.execute`, so every UI dispatch is journaled.
That is better than it first appears, and it means Package B does not have to
rewrite the UI.

### 1.2 Who writes the journal

Four *outcome* call sites write `WorkflowCommandRecord` through the
high-level contracts, all inside two files:

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

**[r2] Those four are not the complete mutation map.** The repository also
mutates rows in `claimRetryableCommands` (select-and-claim in one write
transaction), `releaseClaim` (fenced on `claimedAt`), `saveRetryCommand` (a raw
`put`) and row deletion inside `settleAccepted`. Any ownership reasoning has to
account for all of them, because they are where the races Package B exists to
control actually occur. `saveRetryCommand` in particular is an unfenced raw put
— it is what the second withdrawn attempt used.

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

**[r2] `false` from adoption does not mean "your newer edit was kept".** The
real repository returns `false` when the local record is missing, when its
remote identity differs, when it is deleted, or when its version/timestamp no
longer match the snapshot. Only the last establishes a newer edit. A storage
exception is a further outcome again. Adoption must therefore return a typed
result — adopted, newer local revision, locally deleted, missing, identity
mismatch, storage failure — and only the second may produce row 5's message.

**[r2] Keeping the edit is half the obligation.** If creation command C was
accepted and the operator changed the description mid-flight, the edit survives
locally — but nothing carries it to the server. Rebuilding C from the edited row
is not safe replay: the backend fingerprints the request, so the same command id
with a changed payload is an idempotency conflict. The design must preserve the
acceptance *and* represent the newer work as separately pending. A preserved
edit is not a synchronised edit.

Revised wording for row 5, replacing revision 1's:

> **Original issue recorded. Your newer changes remain saved on this device and
> are not yet synchronised.**

To be used only when the stored outcome actually establishes both halves.

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

## 3a. [r2] Validation must precede authoritative settlement

A hazard revision 1 missed, and it directly threatens the proposed first slice.

`WorkflowOnlineExecutor.execute` calls `settleAccepted` **immediately** after
the gateway returns, before any operation-specific validation. The gateway
checks only that the receipt's command id matches the request.
`validateMaintenanceIssueCreateReceipt` — which checks result key, aggregate
version, ticket id, audit id and derived quality identifiers — runs in the
*caller*, after the executor has already returned.

So moving SyncService behind the executor as written would allow:

> receipt has the right command id but an inconsistent ticket or result →
> executor stores it as acceptance and deletes the retry row → the caller then
> rejects it → every later acceptance-aware transition treats that stored
> receipt as authoritative.

The revised contract is a three-step boundary:

1. validate the receipt against the **frozen request**
2. durably record acceptance only once it is valid
3. independently read back and adopt current server state

Step 3 failing must not erase step 2. An invalid receipt must not reach step 2
merely because it arrived.

**Settlement failure needs its own outcome.** The executor currently catches a
`settleAccepted` failure, logs it, and returns the receipt; the retry service
counts a normally returned call as applied. A caller can therefore observe
success while local settlement failed. The design must distinguish *acceptance
observed* from *acceptance durably settled*, and keep the frozen request until
the latter is recoverable.

## 3b. [r2] Who finishes the work after each durable state

Revision 1 named states without saying who must finish them. Three gaps:

**Intent after process death.** Revision 1 left open whether the retry service
may claim `intent`. Those options are not equivalent: if only the originating
run may dispatch, then a process that dies after committing the intent leaves a
row nothing will ever progress. **Answer to open question 3: a later execution
must be able to claim eligible `intent` rows.** It need not be a background
worker; the next foreground sync run is sufficient for slice one. One shared
lifecycle owner, several triggers, the same transactional claim.

**Acceptance after settlement.** `settleAccepted` deletes the retry row, so a
process that dies between settlement and adoption leaves an accepted operation
with no dispatch row and no owner for the outstanding adoption. The command
should leave the *dispatch* queue; that does not mean the local work is done.
The design needs a durable reconciliation record — receipt-linked, enumerable
after restart, carrying enough to identify the business record and the original
submission snapshot.

**A single pre-dispatch decision.** Because the executor does not enforce
deadlines or exclusivity, one atomic decision must precede every dispatch:

| Situation | Decision |
| --- | --- |
| No intent exists | Persist the frozen request in the submission transaction |
| Acceptance already exists | Reconcile it; create no new dispatch work |
| Another live claim exists | Do not dispatch |
| `nextRetryAt` in the future | Do not dispatch |
| Eligible intent, or expired claim | Acquire a claim, then dispatch |
| Ineligible actor, or terminal row | Preserve without dispatching |

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

**[r2] A session check before an `await` does not bind the eventual request.**
The callable SDK attaches the authentication token at invocation time, so an
earlier `currentUser` reading is not the authentication of the outbound call.
Rechecking per retry narrows the window; it does not define the guarantee. The
design must name the boundary at which intended actor and actual authenticated
invocation are bound, including sessions that change during connectivity checks
or other awaited work. The backend's own receipt-ownership and authority checks
on replay stay in force — and mean a matching uid is not sufficient if that
user's permissions have since changed.

Settling under any session must also not become permission to *read* or display
another actor's data under the old actor's authority. Preserve a legitimately
received result; govern subsequent access separately.

**[r2] Legacy rows: revision 1's concession was too loose.** There is no actor
field on `WorkflowCommandRecord` or `WorkflowCommandReceiptRecord`, the creation
payload does not carry the reporter uid, and `WorkflowUncertainRetryService` has
no actor dependency at all. "Dispatchable by their recorded reporter" is
therefore not a defined operation. Replacing it with a narrow classification:

| Legacy evidence | Treatment |
| --- | --- |
| Origin establishable from the exact linked creation record with supported provenance | Bind under an explicit, validated compatibility rule |
| Origin absent, ambiguous or contradictory | Preserve for visible reconciliation; **no automatic dispatch** |
| Already `manualReview` or `rejected` | Preserve the terminal disposition |
| Valid acceptance exists | Reconcile the acceptance; do not regenerate a submission |

No payload or original timestamp is rewritten to make a legacy row fit.

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

**[r2] The business boundary is not settled by naming two call sites.** The
missing-ticket path continues into close or reopen replay when the local record
carries that evidence, and the recovery path continues into lifecycle replay
before returning. B0 also showed that a refused recovery falls through to
generic batch synchronisation. Slice one must state whether it covers only
creation of still-open issues, or the creation component of already-resolved and
reopened offline records too — and for the latter, how downstream lifecycle work
waits for, consumes and survives the durable creation result.

The other initiators are excluded from new functionality but **not** from
regression testing, since the executor and repository contracts they share are
what changes.

**Explicitly not in this slice:** WorkManager or any background scheduler; a
generic outbox framework; critical-alarm changes (it deliberately avoids delayed
retry, and the plant emergency route stays primary); and new functionality for
the other 20 initiators.

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

### [r2] Schema

Revision 1 said "no schema migration" and "no stored row changes shape" while
also proposing to persist `originActorUid`. Those cannot both be true.
`WorkflowCommandRecord` has no such field today.

A new nullable persisted field is a schema change even where Isar needs no
handwritten migration script. Putting actor metadata inside an existing JSON
field is not automatically safer: the new reader, the old reader and the
backend's payload fingerprint all have to stay compatible, and actor metadata
must never become part of the wire command. The choice belongs in the revised
design, stated as a schema change either way.

### [r2] Rollback

"Revert the commits" is **not** a safe rollback procedure, and revision 1 was
wrong to present it as one.

> New code writes an `intent` row → the code is reverted → the old claimant
> selects only due `uncertainOutcome` and expired `sending` rows → the intent
> has no owner, and the old outcome inventory does not count it either.

If old `SyncService` also resumes direct dispatch, it may rebuild a command from
the mutable business record rather than consuming the frozen request.

Returning to old code after new durable state exists is not returning to the old
situation. Rollback needs a stated condition and procedure — drain or reconcile
new-format work first, keep a compatible reader, or block downgrade while
incompatible outstanding rows exist.

## 6a. [r2] Cancellation while the outcome is uncertain

Revision 1's table covers cancellation before dispatch (row 13) and deletion
after acceptance (row 14). It omits the dangerous middle: **the command may have
reached the server and the outcome is unknown.**

That work cannot be deleted or called "discarded". The owner must retain the
unresolved submission and the cancellation request, recover the outcome, and
only then decide whether a separate authorised cancellation or deletion
operation is required.

Cancellation before dispatch must also serialise against claiming, or the
canceller and the dispatcher can each believe they won. The business record and
the intent have to move together, so ordinary sync does not recreate cancelled
work.

## 6b. [r2] What the timers mean, before what they are set to

The six-hour threshold is evaluated when a quota refusal arrives, and a
server-requested delay may be a day, so escalation can be later than six hours.
There is no timer that promotes a row at the threshold. The new actor rule adds
a case with no trigger at all: if the origin actor never returns, no dispatch
outcome ever occurs to escalate on.

Three distinct quantities need separate names before any of them is tuned:

| Quantity | Meaning |
| --- | --- |
| Earliest permitted network retry | The server's window; never violated to force escalation |
| Age at which work needs a person | Independent of whether a network attempt happened |
| Claim expiry | When another run may take over |

With background execution excluded from slice one, the honest guarantee is **"on
the next eligible foreground inspection"**, not "at six hours". A foreground
inspection can surface overdue work without breaching a retry window.

An exhausted attempt budget means automatic retries stopped. It does not
establish that the server never accepted the operation.

## 7. Open questions for the reviewer

Questions 1, 2 and 3 from revision 1 are now answered in §2, §4 and §3b
respectively. What remains open:

1. **Whether contradictory creation evidence should permit a generic batch
   push at all.** B0 pins the current behaviour: recovery refuses, then the loop
   falls through to `batchUpsertTickets`. That fall-through is now visible in a
   test rather than hidden inside a caught exception, but whether it is correct
   is a domain question.
2. **Where actor metadata lives** — a new nullable persisted field, or versioned
   local metadata. Both are schema changes with different compatibility costs.
3. **The slice boundary against close/reopen replay** (§6).
4. **Timer semantics before values** (§6b). The constants are judgement, not
   measurement.

## 8. What this design does not claim

It is not implemented, not reviewed, and not tested. It does not establish that
the backend is idempotent under replay — that needs backend or integrated
evidence. It does not address background continuation. And nothing in the
lifecycle work so far, including B0, reaches *device path demonstrated*.
