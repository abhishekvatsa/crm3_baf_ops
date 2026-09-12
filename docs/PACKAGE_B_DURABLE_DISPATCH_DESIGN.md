# Package B — durable maintenance creation, revision 3

**Status: selected design for independent review; durable dispatch is not implemented.**
The companion September 12 recovery change implements only the bounded safety
boundary in section 2. No release, backend deployment, phone demonstration or
pilot authorization follows from this document.

Revision 3 replaces the conflicting normative text in revisions 1 and 2. Source
baseline is `ed13e30b`, followed by the working-tree recovery safety change.
The September 9 incident established Android background network blocking. It did
**not** establish process death; process-death recovery below is a design failure
case, not a newly attributed incident fact.

## 1. Current implementation and ownership

The named call-site inventory is 24 initiators: 18 UI calls through
`WorkflowCommandController`, one `WorkflowUncertainRetryService` call through
`WorkflowOnlineExecutor`, two direct SyncService creation/recovery calls, two
direct critical-alarm calls (first attempt and immediate replay), and one direct
web creation call in `maintenance_form.dart` using `execute(createCommand)`.
The executor's own gateway call is implementation, not another initiator.
This is a named dispatch inventory, not a count of all business actions.

Nineteen initiators route through a journal-aware executor. That does **not**
mean a durable intent is written before sending. The connected executor calls
its gateway first; only selected failures create a retry row. It does not make
one atomic pre-dispatch decision about ownership, due time and acceptance.
The retry service claims due `uncertainOutcome` or expired `sending` rows.
`ready` is not claimable. Neither existing command nor receipt rows store an
origin actor. SyncService calls the gateway directly and does not durably store
the returned creation receipt. The web creation route also bypasses the executor.

Repository mutation owners include `settleAccepted`, guarded failure/hold writes,
claim acquisition, claim release, raw `saveRetryCommand`, and deletion. A change
only to the four outcome call sites cannot establish exclusive dispatch.
`settleAccepted` atomically records a receipt and deletes its retry row, which
protects acceptance from later failure writes. It currently runs before
operation-specific caller validation. A local settlement exception is logged
and the receipt returned as success; success therefore does not establish local
durability. These are implementation gaps, not promises this design has fulfilled.

## 2. Bounded recovery boundary implemented separately

Recovery has four typed results: `recovered`, `existingIdentity`, `deferred`, and
`contradiction`. Only `existingIdentity` may enter the existing ordinary update
or close/reopen path. It is selected **before** any creation replay:

- Local and lookup records have the same nonempty ticket ID and reporter UID,
  exact creation instant, valid positive versions, and no remote tombstone.
- A further server-only read must confirm that immutable identity. Cached
  agreement alone is insufficient. The following conflict/lifecycle checks use
  this fresh record.
- Equality is an existing-record compatibility check. It is **not** proof of an
  accepted command receipt, a frozen original payload, or legacy provenance.
  Version/timestamp values are neither repaired nor reinterpreted.

Otherwise creation recovery requires its original reporter. A missing or
mismatched actor defers the affected ticket. Once replay is attempted, a failed
invocation, unavailable verification, invalid receipt, or contradictory exact
record cannot enter the identity bypass or a generic batch update. Contradictions
surface through the existing permanent sync-rejection mechanism; uncertainty
surfaces as a retryable diagnostic. The local business row is retained and
independent tickets continue. Diagnostic persistence uses the existing
sync-rejection facility. A behavioral fixture opens the real default Isar with
`SyncRejectionSchema`, records a contradiction, closes and reopens the same
store, and proves the hold still prevents sending. A real hold-collection lookup
exception now returns no eligible records and surfaces an in-memory retryable
diagnostic; it does not interpret an unreadable store as an empty hold list or
attempt another diagnostic write into that store.

These proofs are bounded to an available local Isar and the existing hold
collection. The existing absent-store route and best-effort diagnostic-write
failure remain separate limitations. This change does not create a frozen
request, an acceptance journal, or a durable owner for every dispatch.

The compatibility route has no local creation journal to consult today. Once
section 3 exists, the presence of any operation/receipt/hold for that identity
must be checked first and takes precedence over this route. An unreadable
journal must block mutation; it cannot be interpreted as absence.

The behavioral regression uses a batch double capable of succeeding, then
asserts **zero** batch calls for a contradiction. It also exercises ordinary
changed-payload edits without creation replay, unavailable server verification,
actor deferral, independent work, concurrent local edits, a hold surviving
reopening, and a missing hold collection preventing automatic writes. Historical r2's
`unexpected.toSet()` assertion did not pin multiplicity or sequence.

## 3. Selected storage representation

Add one Isar collection, `MaintenanceCreationOperationRecord`, for governed
maintenance creation only. It remains after dispatch completes, so acceptance
and unfinished adoption never require discovery through a deleted retry row.
Do not hide local actor metadata inside the backend ticket payload.

| Stored field | Contract |
| --- | --- |
| `schemaVersion` | 1; unknown versions are visible and non-dispatchable |
| `commandId`, `ticketId` | Separate unique indexes without replacement; immutable command ID and ticket ID establish one creation owner per ticket |
| `originActorUid` | Nonempty at new submission; immutable historical origin |
| `frozenCommandJson` | Complete command envelope built once, with deterministic key ordering; no mutation on retry |
| `localEnvelopeSha256` | Integrity checksum of exact stored envelope UTF-8 bytes, not a replacement for the backend fingerprint |
| `submittedLocalId`, `submittedVersion`, `submittedUpdatedAt`, `submittedSnapshotJson` | Exact submitted business snapshot for adoption and retained edits |
| `createdLocallyAt` | Original submission time; not reset by retry, account change or migration |
| `state` | `intent`, `sending`, `uncertain`, `acceptedPendingAdoption`, `adopted`, `needsReview`, `rejected`, `cancelledBeforeSend` |
| `attemptCount`, `nextRetryAt`, `attentionDueAt` | Actual dispatch count, earliest next network attempt, separate age-based attention deadline |
| `claimToken`, `claimExpiresAt` | Random unique token and UTC lease expiry; token fences every non-acceptance outcome |
| `receiptJson`, `acceptedObservedAt`, `acceptedSettledAt` | Validated acceptance envelope and local observation/settlement times; immutable after settlement |
| `reconciliationState` | `pending`, `adopted`, `newerLocalRevision`, `locallyDeleted`, `missing`, `identityMismatch`, `verificationUnavailable` |
| `pendingEditSnapshotJson`, `pendingEditVersion`, `pendingEditUpdatedAt` | Durable carrier for later edits; never substitutes into the original command |
| `cancelRequestedAt`, `lastErrorCode`, `lastErrorMessage` | Preserve cancellation/uncertainty and actionable diagnostics |

Store the operation in the same Isar instance as the maintenance row. Keep the
existing generic workflow receipt collection for acceptance-aware readers.
Creation-specific settlement writes that receipt **and** updates the operation
row to `acceptedPendingAdoption` in one transaction. It may remove an old
matching retry row in that same transaction, but it does not delete the operation.
A conflicting existing receipt is `needsReview`, never overwritten by a later
response. Keep completed operation rows through the pilot; automated compaction
is excluded. This preserves origin and reconciliation discovery after restart.
The unique ticket owner is retained in accepted, rejected and cancelled states.
A second submission ID for the same ticket cannot insert another operation or
replace that owner, even if its payload differs or the first command is terminal.

## 4. APIs and transaction boundaries

A single `MaintenanceCreationDispatcher` owns submission, dispatch and recovery.
UI submission, foreground sync and foreground resume are triggers, not separate
owners. Isar transactions contain no network calls.

1. `submitCreation(record, actor, submissionId)` builds and validates the command
   before opening the transaction. In one transaction, compare the expected
   local revision and look up both command ID and ticket ID before writing.
   An existing ticket owner must have the same submission ID, byte-identical
   envelope, origin and snapshot; otherwise return `identityConflict` with the
   existing owner ID and write nothing. Reusing a command ID for a different
   ticket also conflicts. With no owner, save the pending business row and
   insert `intent` with its frozen envelope in the same transaction. Unique
   command and ticket indexes use no replacement, and concurrent submissions
   must resolve through this same existing-owner comparison. Return `savedIntent`,
   `existingIntent`, `existingAcceptance`, `existingTerminal`, `revisionChanged`,
   `identityConflict` or `storageFailure`. Only the first two
   justify “Saved on this device, waiting to send.”
2. `claimCreation(commandId?, actor, now)` first reads accepted/terminal state,
   envelope integrity, actor and due time, then atomically claims eligible
   `intent`/`uncertain` or expired `sending` rows. Return `claimed(token)`,
   `acceptedNeedsAdoption`, `notDue`, `claimedElsewhere`, `actorMismatch`,
   `terminal`, `invalidEnvelope` or `storageFailure`. A later foreground run may
   claim an intent left by another process; submission need not still be alive.
   Every claim and settlement verifies that the operation remains the unique
   ticket owner, not merely a row with a unique command ID.
3. `dispatchClaim(claim)` sends only the frozen envelope through the actor-bound
   protocol in section 5. The server receipt is validated against that envelope
   with `validateMaintenanceIssueCreateReceipt` before any authoritative local
   settlement. A shape-valid, wrong-target/wrong-result receipt cannot settle.
4. `settleCreationAcceptance(commandId, envelopeHash, receipt)` checks immutable
   identity and receipt consistency in a transaction, writes the generic
   receipt and `acceptedPendingAdoption` marker together, and clears its claim.
   Return `settled`, `alreadySettledSameReceipt`, `conflictingAcceptance`, or
   `storageFailure`. An expired claim does not discard a valid acceptance of the
   same frozen request. Receipt observation with settlement failure returns
   `acceptedButNotDurable`; retain the operation and replay identity, do not
   report durable completion or downgrade to a definite rejection.
5. `recordCreationAttemptOutcome(commandId, token, outcome)` is a transaction
   that checks existing acceptance first, then the exact claim token. It returns
   `recorded`, `alreadyAccepted`, `staleClaim` or `storageFailure`. A stale caller
   cannot reset a newer claim, recreate pending work after acceptance, or change
   the frozen payload. No raw put from SyncService is permitted.
6. `reconcileCreation(commandId)` makes a server-only read outside the
   transaction. It validates the exact target/author/creation evidence and then
   compares the local snapshot inside one transaction. Adoption updates the
   business row and operation marker together. The typed outcomes below are
   persisted even when adoption is refused. A read/storage exception preserves
   pending reconciliation; it never manufactures successful adoption.
7. `cancelCreation(commandId, expectedRevision)` serializes with claim acquisition.
   An unclaimed, never-dispatched intent may become `cancelledBeforeSend` with
   its business tombstone in one transaction. Sending/uncertain work records a
   cancellation request, retains the command and resolves its outcome first.
   An accepted operation requires a separate authorized cancellation/deletion;
    it cannot be relabelled “never sent.”

There is no terminal replacement API in this slice. A changed payload after
rejection requires a separately reviewed, authorized correction or supersession
contract binding the old owner, proven terminal outcome, new command and audit
history atomically. Until that contract exists, preserve the rejected owner and
local correction for review; do not mint a second creation owner or reuse the
old command ID with changed bytes.

## 5. Selected actor binding and rollout protocol

A local UID read before an `await` does not bind the SDK's eventual authenticated
request. For new durable creation select a **new versioned callable envelope**:
`executeMaintenanceWorkflowCommandV2` accepts `{protocolVersion: 2,
originActorUid, command}`. The backend requires the authenticated UID to equal
`originActorUid` before invoking the existing dispatcher with the unchanged
inner command. Existing authority and receipt ownership checks still apply.
The wrapper metadata is excluded from the inner command fingerprint; existing
V1 requests and accepted receipts retain their existing representation.

This is an explicit backend protocol addition, not a client-only workaround or
an implemented feature. It requires backend-first compatibility tests and a
separate deployment decision. The durable native owner must not be activated
before that endpoint is available. Existing V1 callers remain supported; missing
origin is never filled from the current user or the latest remote record.
An account switch during connectivity checks or token selection is refused by
the backend origin check. No callable accepting arbitrary origin on trust is
permitted.

A valid late response may be durably retained with its original actor even after
sign-out. This grants no right to display its contents or perform new reads under
a previous session. Projection access uses current authorization. An actor-mismatch
claim is preserved, and an overdue inspection surfaces attention without sending
under another account. Same UID alone never bypasses changed backend permissions.

## 6. One authoritative transition and reconciliation table

| Event | Durable result and owner | Operator meaning |
| --- | --- | --- |
| Submission commits | `intent`; dispatcher/next foreground run | Saved locally, waiting to send |
| Eligible row claimed | `sending`, unique fence; current dispatcher | Sending |
| Transport outcome unknown | `uncertain`, due time; next eligible foreground run | Outcome unconfirmed; local work kept |
| Quota refusal | `uncertain`, server window respected; next eligible run | Waiting for server retry window |
| Valid receipt durably settled | `acceptedPendingAdoption`; reconciler | Recorded by plant system; updating this device |
| Receipt observed, storage failed | Existing intent/claim retained; dispatcher replays exact envelope | Server accepted; this device could not save the confirmation |
| Adoption snapshot matches | `adopted`; completed record retained | Recorded and current on this device |
| Local revision newer | Acceptance retained; `newerLocalRevision` plus frozen pending-edit carrier; review queue | Original issue recorded. Newer changes remain saved here and are not synchronized |
| Local row deleted | Acceptance retained; `locallyDeleted`; reconciliation owner | Original issue recorded; deletion needs separate resolution |
| Local row absent | Acceptance retained; `missing`; reconciliation owner | Original issue recorded; local record needs recovery |
| Identity/readback contradiction | `needsReview`; reconciliation owner | Evidence does not agree; no automatic ticket update |
| Exact read unavailable | Keep `acceptedPendingAdoption`, `verificationUnavailable`; next foreground read | Recorded; device update remains unverified |
| Definite rejection | `rejected`; visible review owner | Server refused the request with its reason |
| Attempts/age exhausted without verdict | `needsReview`, command retained; review owner | Outcome unresolved; automatic sending stopped |
| Cancel before any dispatch wins transaction | `cancelledBeforeSend`; retained audit record | Discarded before sending |
| Cancel while sending/uncertain | `cancelRequestedAt`; outcome owner continues | Cancellation requested; original outcome still being checked |

A refused adoption is not automatically a newer edit. The current Boolean
repository contract must become the typed result above before using these
messages. A newer edit receives a separately persisted carrier in the **same**
transaction that records the snapshot mismatch. In slice one it enters visible
manual review, not an automatically rebuilt creation request. A later authorized
correction uses its own command ID, exact current server version and documented
field-level correction contract. Reusing the creation ID with changed content
is forbidden, even when the original creation succeeded.

## 7. First slice boundary and compatibility behavior

Implement durable creation for **new, still-open native maintenance issues**.
The maintenance form writes intent in its save transaction. While that creation
is pending or its acceptance is unadopted, edits are retained as pending-edit
carriers; close/reopen requests are retained for review and cannot use generic
batch/lifecycle replay around the owner. The operator must see that these later
changes are not yet synchronized. Slice one does not add automatic downstream
close/reopen dispatch; enabling that requires its own immutable commands and
ordering contracts. Once creation is adopted and there is no unresolved carrier,
existing governed close/reopen routes retain their ordinary behavior.

Legacy collapsed closed/reopened unsynchronized records are **not silently
converted into new intents**: the original frozen creation request cannot be
proved from their current mutable content. Keep their identity/data and surface
reconciliation. This is a deliberate compatibility restriction requiring pilot
acceptance, not an unnoticed regression disguised as a routing refactor.
The section 2 pre-recovery identity route remains available for established
records with no pending new-format operation or contradictory receipt/hold.

The remaining named initiators receive no new durable-dispatch capability in this
slice; shared executor/repository changes still require regression coverage.
The web create route remains online V1 and is explicitly excluded from durable
native submission. Critical alarms retain immediate handling and the plant
emergency route; they must not gain delayed replay accidentally. WorkManager,
background execution, global outbox conversion and database replacement are
excluded. Foreground restart/resume can finish eligible intent without claiming
continuous background execution.

## 8. Migration and rollback selected

Add the collection with schema version 1; generated schemas and database-opening
lists must change together. Do not rewrite existing payloads, timestamps or
historical receipts to make them fit. A new record is created only for a new
submission with a contemporaneous known actor, or under an explicit reviewed
migration proving exact original envelope, origin and linked local snapshot.
Legacy receipt/command rows are classified read-only on first inspection:

| Existing evidence | Behavior |
| --- | --- |
| Valid acceptance with complete binding | Reconciliation only; never recreate a submission |
| Uncertain creation with exact frozen envelope and independently proven original actor/snapshot | Explicit compatibility import; preserve command ID, bytes and original time |
| Missing, ambiguous or contradictory origin/envelope | Visible review; no automatic creation dispatch |
| `rejected` or `manualReview` | Preserve terminal disposition; no automatic re-arming |
| Other workflow command type | Existing owner remains responsible; this slice does not migrate it |

Enablement requires compatibility tests for old clients and historical receipts,
a migration inventory, and verification that every new state is discoverable in
outcome inventory and attention UI. New-format creation identities are excluded
from the old retry claimant and SyncService direct gateway routes before enabling
submission. There is one retained creation owner per ticket and one sending
owner for its operation. Compatibility import checks both unique indexes in
the same transaction; duplicate legacy owners become visible review and are
never collapsed or replaced automatically.

**Rollback condition:** once any new-format row exists, do not install old code
that cannot enumerate it. First disable only new submissions, keep the new
reader/dispatcher/reconciler active, and export an inventory of unresolved rows.
Drain or individually reconcile all intent/sending/uncertain/accepted-pending/
pending-edit/cancellation work. Then use a rollback build that retains a
read-compatible collection and completed acceptance records; it may disable new
writes. A plain source revert or APK downgrade is not the rollback procedure.
Do not mass-delete records, convert them to old `ready`, or regenerate old payloads.

## 9. Timers, failure outcomes and evidence gates

Preserve the current eight-attempt budget and five-minute claim lease for the
first implementation, pending measured device evidence. Count actual dispatches,
not Android platform holds or quota refusals. A quota refusal honors the later
of the existing backoff and server retry window. Set `attentionDueAt` six hours
from original local submission, independent of the retry window. On each
foreground inspection, overdue unresolved work becomes visible for review
without dispatching earlier than `nextRetryAt`. The guarantee is **on the next
foreground inspection**, never an exact six-hour background timer. Expired claims
must be reclaimable; a random token, not timestamp equality alone, fences owners.
An exhausted budget proves automatic sending stopped, not that the server never
accepted the request.

Before enabling Package B require behavioral tests with real Isar transactions:
submission/storage failure makes zero gateway calls; concurrent different
submission IDs for one ticket produce one retained owner and a conflict without
rewriting either payload; accepted, rejected and cancelled owners cannot be
replaced implicitly; competing claims make one
call; intent survives reopen; stale fences cannot overwrite acceptance; settlement
and reconciliation marker are atomic; invalid receipts never settle; read failure
does not erase acceptance; every adoption result preserves the right local row;
newer edits have a durable separate carrier; late results retain origin; actor
switch during an awaited step reaches the V2 refusal; cancellations serialize
against claims; deadlines prevent premature dispatch; legacy and rollback
inventories remain visible. Test both client/server protocol combinations and
historical receipt replay in the governed emulator. A phone demonstration must
bind the exact successor artifact; host tests alone do not establish this.

## 10. Revision history and present evidence limits

R1 overstated how many calls were journaled and understated durable ownership.
R2 identified validation, actors, reconciliation, cancellation and rollback gaps
but retained contradictory old instructions. R3 selects one representation,
one first-slice boundary and explicit migration/rollback behavior. Superseded
r1/r2 requirements are preserved in Git history, not repeated as active rules.

The narrow safety suite verifies current recovery behavior and preservation; it
does not prove Package B implemented, backend idempotency under all failures,
background continuity, successful Inner Cover acceptance or physical-device
no-loss behavior. Inner Cover Accept has a separate callable and separate fixes.
No report of an individual plant incident is converted into a test result.
