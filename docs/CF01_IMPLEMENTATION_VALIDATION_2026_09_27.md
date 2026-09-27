# CF-01 repair and verification — 27 September 2026

Status: source repair complete; final Android/CI verification pending. PR #382 remains draft.
This document does not authorize merge, backend deployment or distribution.

## Ownership boundary

The three previously generic queues now save their exact command, original
account, Firebase project, document, intended payload and expected version at
the same time as the native Isar projection. The existing durable-submission
store supplies the atomic transaction, claim, immutable envelope, accepted
receipt and conditional adoption. No new Isar collection is introduced.

The existing V2 maintenance-workflow endpoint owns three explicit operations:
`upsertAbnormalityType`, `upsertLegacyJobTemplate`, and
`updateJobExecutionWork`. Admission requires the original account and project,
fresh server authority and the original version. Accepted replay validates the
content-bound audit and receipt. The old V1 endpoint cannot execute these
commands, and direct Firestore writes no longer bypass them. The callable fleet
and runtime identities are unchanged.

Account B cannot acquire A's pending resource by saving a new command under B's
UID. A lost response retains the original command for exact replay. Accepted
receipt adoption compares the complete local payload inside the transaction;
it cannot erase or acknowledge a newer local edit just because a version and
timestamp happen to match. Unknown-origin legacy rows preserve their original
serialized evidence for review; no current user is retroactively assigned as
their author.

An additional legacy charge-abnormality path could reconstruct privileged
updates under the current account. These old edits/deletions are now retained
as review-only evidence before remote comparison or acknowledgement. The
current correction/deletion UI already uses its governed online command. The
generic native APIs refuse to enqueue new unbound privileged edits. New offline
creation remains available to its original reporter, with both document and
local identity protected against replacement. Holding another account's row is
a per-row failure, not a sign-out or an abort of independent synchronization.

## Evidence and pending work

- Native Isar ownership tests exercise A → B → database reopen → A across the
  three repaired queues, immutable retry, legacy evidence, concurrent local
  revision protection and transaction rollback.
- A separate real Auth/Functions/Rules HTTP suite has passed 7 tests in an
  isolated `demo-` project, including actor/project/payload mismatch, V1 refusal,
  revoked and restored access, exact replay and direct-write denial.
- The modified Firestore Rules suite passed all 247 tests in that isolated run.
- Full backend host suite passed 2,485 tests across 82 suites, followed by focused
  strict audit-fixture and malformed deletion-evidence regressions. Build,
  type-check and callable/runtime inventories passed.
- The final full Flutter run passed 3,967 tests with one skip and one stale
  current-source inventory assertion. That assertion was corrected to the
  independently measured source inventory; its complete test file then passed
  6/6. All runtime tests passed in the full run. Fresh CI must validate the final
  committed tree together.
- Whole-client analysis is clean. The canonical source audit passed 153/153,
  strict inventory adversarial tests passed 24/24, and key-custody tests passed
  20/20 plus the tracked-source custody scan. Existing field policies, limits,
  historical receipts and release approvals were preserved.
- The Android ownership journey uses real repositories, native Isar,
  authenticated Firebase accounts and server reads. It is declared in the CI
  manifest in preparation and resume phases. The runner force-stops the app,
  preserves data and uses a new application process; the resume phase checks
  the persisted B session and original pending records before A returns. Its
  actual Android execution is still pending.
- CI now requires a successful, non-skipped seven-test authenticated HTTP report
  before starting the Android journeys. A passing process without the exact
  completion marker is insufficient.

Database-reopen host proof is not represented as completed Android process-restart
proof. The existing separate-process abnormality recovery journey remains independent evidence.
No production records or connected-phone state were changed by these proofs.

## Other PR repairs

Secret-scanning alert #5 matched exactly the synthetic emulator placeholder at
its three reported paths. Independent source review verified demo-only project
selection, DEV package identity and emulator routing. The alert was resolved as
`used_in_tests` with a recorded rationale; secret scanning remains enabled and
no production key was rotated. A subsequent metadata-only query returned no
open secret-scanning alerts. No raw detected value is included here.

At head `ae46316e`, the abnormality and separate-process restart Android
journeys passed. Planned maintenance published through the real UI, then its
next tap hit the still-visible publication notice. The test now waits for that
notice to dismiss normally and requires a hit-testable assignment control;
missed taps and all business acceptance assertions remain failures. The fresh
planned journey result is still pending.

## Deployment consequence

These Rules intentionally stop older direct catalogue/template/work-edit
writers. Production requires a coordinated client/backend/Rules rollout and a
review of retained legacy work. Passing source tests alone does not prove that
installed clients have migrated or that a new backend has been deployed.
Historical deployment receipts and release approvals remain unchanged.
