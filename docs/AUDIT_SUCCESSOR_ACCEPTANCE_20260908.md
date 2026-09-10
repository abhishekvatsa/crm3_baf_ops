# Audit successor acceptance plan — 8 September 2026

**Plan only: these checks have not been executed.** This document supplies no installation, business-mutation or distribution authorization, and records no passing result.

Before execution, record the exact successor APK version, SHA-256, package/signing identity, verified backend revision and CI/review evidence. Obtain installation and representative-test authorization separately. Use approved test records, role assignments and device/actor aliases; do not change live plant conditions to exercise this plan.

**Read-only** checks inspect existing records. **Mutation** rows require authorized business changes. Response-loss and delayed-snapshot timing require a controlled setup; if timing cannot be established, mark **not demonstrated**.

| Check / access | Practical steps | Required pass evidence |
| --- | --- | --- |
| **Retained-data upgrade** — installation + observation | Inventory installed **Build 21** records, unsynced work, attachments and pending confirmations; preserve the agreed recovery copy. Install the exact successor in place. **No uninstall, clear-data or Device recovery/reset.** Reopen records, restart and observe authorized sync. | Matching before/after inventory and artifact identity. No lost edits, attachments, duplicates or crash. Pending work is confirmed by real server evidence or remains visibly pending. |
| **Lost event response** — mutation; Operations, Shift Supervisor, Contract Supervisor, SI or Admin | Prove the server committed a test event while its response was lost. Choose **Confirm your previous event → Confirm event**; repeat after restart, including a legitimate intervening event update. | Same event/submission identity and actual receipt; current state displayed, no duplicate or premature confirmation. Retain timing evidence: a timeout alone proves neither commit nor response loss. |
| **Retained request identities** — controlled mutation fixtures | For monitoring, Morning Review and incidents, prepare separate pending submissions from independently cached runtimes; restart and confirm each. For burner rounds and assignments, lose the response to payload P, edit to Q, then return to exactly P. | Every unconfirmed identity survives. Confirming one leaves the other intact. Returning to P uses its original request/receipt and creates no second accepted record. Burner/assignment full-form restoration is not claimed. Use current binaries; record older-client limitations separately. |
| **Correct permanent rejection** — mutation; event-recording role | Obtain a genuine persisted terminal rejection; correct its cause and resubmit. Include an authorized **ahead-of-server phone-clock CREATE** fixture: verify rejection, correct the clock/time cause through the test setup, then submit again. Also observe an uncertain timeout. | Corrected work uses a fresh identity; no event exists for the rejected attempt. Rejected future-dated creation does not trap the corrected draft in replay. Uncertain work retains pending confirmation rather than being discarded. |
| **Two-device conflict** — controlled authorized fixtures; permitted editor + Admin observer | Have the test owner prepare **clean-local divergence**: lower local version, later local timestamp and `isSynced=true`, versus a higher server version. Run **Sync now**, inspect **Admin data browser → Sync conflicts**, and observe unrelated successful live sync followed by a newer adequate server revision. Also retain a dirty unsynced-edit case and, where authorized, a tombstone case. | Clean-local bytes are preserved and the affected cursor is held; conflict/failure is visible. Unrelated live success cannot clear it. A newer server revision with an adequate timestamp permits recovery and cursor progress. Dirty evidence remains protected; no silent overwrite, lost delete or false full-sync success. Capture actual bytes, versions, timestamps, cursor and recovery evidence. |
| **Delayed quality snapshot** — mutation; SI/Admin closes | After a newer closure is observed, deliver a controlled older active snapshot. Exercise refresh and failed-window recovery. Approved viewers observe. | Greater revision stays closed. Failed window remains an error until recovery; contradictory same-version evidence errors visibly. Retain ordering/version evidence; ordinary refresh is insufficient. |
| **Custom assets / historical joins** — read-only with prepared fixtures | In Reports, select each of two custom classes sharing a number. Check warnings, abnormalities, lanes and compliance, including an out-of-period linked issue/job, late/corrected or removed source and inconsistent identity. Include a warning already attributable from one of several affected assets. Observe corrections before manual refresh, then refresh. | Only proven matches appear. Old sources establish identity without increasing period issue/job counts. Live corrections recover; unresolved identity errors explicitly. Sufficient own identity does not wait for an unrelated source. Fixture creation requires separate Admin authorization. |
| **Morning Review evidence** — mutation; SI/Admin starts, contributors Join | Add completion-looking prose against a carried action, then use native **Complete** as assignee or SI/Admin. Include administrative closure/accepted condition, active Unfit/Unavailable issue and historical completion prose. | Prose remains unverified/open; native completion settles the action while preserving captured source status. Administrative outcomes use **Closed / accepted**. Condition appears independently of lifecycle. Historical statements remain visible with their limitation. |
| **Large review** — mutation; SI/Admin facilitator + contributors | In a dedicated test review, admit a current-day action, then add long multilingual entries and varied actions/concerns until capacity rejects further content. Accept and complete the admitted action with a full-length reason. Also accept/complete a carried action against the full meeting. **Finalize**, then inspect **Meeting record / Open PDF**. | Rejected new content creates no accepted entry/action or success receipt. Previously admitted actions can complete. A carried action and receipt commit even when its optional meeting entry cannot fit; that skipped entry does not consume a meeting version. Every accepted contribution remains readable after finalization/reopen and in the PDF; none must be deleted to finalize. |

Record **pass / fail / not demonstrated**, artifact/backend identifiers, aliases, actual record/receipt IDs and versions, timestamps, before/after evidence and observer conclusion. Store business content in the approved evidence location.

**Stop** for artifact/signature mismatch, missing authorization, data loss, duplicate work, silent overwrite, false success/completion, or unfinalizable accepted content. Preserve evidence and pending work; do not reset, delete, invent receipts or replace uncertain submission identities. Pilot promotion/distribution requires a separate decision after review of executed evidence.

## Shared-contract caller matrix, 2026-09-10

Four defects in this corrective round had the same shape: a result type was
correct and one caller did not use its full meaning, or an earlier throw
stopped the caller reaching it. Recovered receipts lost their payload because
one consumer was never checked; the attention inventory reused a query that
excludes rejections; the blocked-network branch read only the receipt from an
evidence object with three states; and a returned verification failure was
logged but never fed the decision.

None of these was found by the test suite. They were found by asking, for each
outcome a shared contract can produce, what every caller does with it. That
question is cheap and belongs here rather than in another governance document.

| Outcome | What a caller must do | Executing evidence |
| --- | --- | --- |
| Accepted | Return the full receipt and pass its real business validator, not the losing attempt's transport error | `test/maintenance_workflow/recovered_receipt_consumer_test.dart` drives the executor into `validateMaintenanceIssueLaneCommandReceipt` |
| Verified absent | Do not invent acceptance, and do not imply a request was retained when it was not | `test/maintenance_workflow/workflow_platform_block_hold_test.dart`, first-submission cases |
| Evidence unavailable | Say the previous outcome could not be checked; never report it as verified absence | Same file: Wi-Fi present, platform blocked, receipt store throwing, no retry row |
| Earlier phase failed, **by throwing or by returning** | Still inspect the journal; carry unresolved verification into health without collapsing the data-plane result | Decision cases in `test/workflow_attention_persistence_test.dart`; the returned-failure path in `test/workflow_uncertain_retry_service_test.dart` |

The last row is the one that keeps recurring. An exception is only one of the
two ways a phase reports that it established nothing.

### Evidence labels

These are three different claims and this round has produced them unevenly:

- **Source corrected** - the code no longer contains the defect.
- **Behaviour tested at a boundary** - a real repository, executor or service
  demonstrates it, with controlled dependencies.
- **Device path demonstrated** - an exact artifact did it on a handset.

Every row above reaches the second. None reaches the third. The coordinator's
own wiring is guarded structurally, not executed, and is labelled as such in
its test.
