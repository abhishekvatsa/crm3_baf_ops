# PR 382: reclaimed retries and handoff verification

## Confirmed retry defect

The review on `83faaef2` correctly identified a stranded-command path. A process can die during its first send, before recording any failure or retry time. The retry service can reclaim that expired `sending` lease. If its session guard then aborts, cleanup previously changed the row to `uncertainOutcome` while leaving `nextRetryAt` null. Neither the due-uncertain query nor abandoned-sending recovery would claim it again. Ordinary claim release had the same missing-schedule defect.

Both transitions now supply the exact UTC claim timestamp only when no retry schedule exists. An existing hold remains intact, and ordinary release retains explicit retry-time precedence. The receipt-aware aborted cleanup, exact lease ownership checks, terminal outcomes, retained origin identity, original envelope and attempt budget are unchanged. This repairs release transitions; it does not bulk-reschedule historical null-schedule rows or infer authority from them.

Five added real-Isar regressions cover aborted first-send recovery, database reopen, refusal under another account, exact original-account V2 replay, ordinary release, and existing/explicit future holds. Before the source fix, the test file reported 20 passing tests and two behavioral failures, both proving the absent retry time. A fixture import error was corrected separately and is not counted as behavioral evidence. After the fix, all 105 focused retry, lease, ownership, receipt, quota and repository checks passed.

## Handoff relevance

The supplied handoff describes `463fdd4f`. Its Git/worktree and CI observations were historical by the time of this assessment. At `83faaef2`, nine checks succeeded and the Flutter host job failed because the new equipment-recovery screen used a plain text app bar. The screen now uses the existing branded component; the unchanged UI convention test passes. The catalogue compatibility finding is addressed separately in [the historical creator validation note](CATALOGUE_HISTORICAL_CREATOR_COMPATIBILITY_2026_09_27.md).

The handoff's unsupported `accessDisposition` throw still exists intentionally, so malformed authority cannot grant access. Its proposed unrecoverable sign-in consequence does not describe the current app: the outer access gate already provides recheck and sign-out controls. Two additional regressions now exercise this exact malformed field through the real profile decoder and through the access gate. They verify no actor is admitted, obsolete listener callbacks cannot unlock the app, saved UI state is retained, and an explicit recheck requires fresh valid profile and online evidence. All 17 profile-session and gate tests passed; no authentication runtime change was needed.

The Firebase Admin namespace crash pattern remains absent from current `functions/src`. The current CI manifest still requires seven Android business journeys. Imported-module inventory is useful coverage evidence, but does not prove every business path in each handler has been exercised. Relayed owner statements in the handoff have not been treated as permission to delete data or remove existing update safeguards.

## Validation and release boundary

- Full combined-source Flutter suite: 4,084 passed, with one existing skip.
- Whole-client analyzer: no issues.
- Canonical source/authority audit: all 153 checks passed, including 434 receipt pointers.
- Independent source review found no remaining blocker in the narrow retry correction.
- The retry file is already part of the required CI no-loss regression spine; its new cases therefore run there as well as in the full suite.

The PR remains draft. Local checks and prior-head Android results do not establish new-head CI completion, a production deployment, a signed release, or a Play-delivered update.
