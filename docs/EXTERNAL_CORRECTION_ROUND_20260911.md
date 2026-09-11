# External correction round — 2026-09-11

An external review round delivered seven corrections against the `03c3e8fa`
review snapshot. This records what arrived, what was verified here, what was
changed before it landed, and what is still open. It is a verification record,
not a restatement of the supplier's report.

Nothing here is merged, deployed, distributed or demonstrated on a handset.

## 1. Binding

| Field | Value |
| --- | --- |
| Baseline | `03c3e8fa8697d8c3a045299a5eb04f52e1056487` |
| Snapshot sent for review | SHA-256 `cd292a2ac1c3c15bca002d51d0aa56eba4c024e08e7bb92e4b1c5a7bdae4bd33` |
| Supplier's declared input | identical SHA-256, sidecar verified |
| Review branch | `codex/external-correction-round-20260911` |
| Integration base | `codex/build28-release-readiness-20260909` (1 commit; `main` would bundle 47) |

Two delivered files were **not** taken: `MODIFICATION_NOTICE.md` and
`docs/LOCAL_CORRECTION_HANDOFF_20260911.md`. Both describe the supplier's own
working copy ("NOT the missing earlier workspace") and would be misleading in
this repository. Their technical content is carried here, with the CR-01–CR-07
mapping preserved so provenance is not lost.

## 2. The seven corrections, and what happened to each

| Ref | Correction | Disposition |
| --- | --- | --- |
| CR-01 | Inspection adjudication binds the reviewed finding revision | Retained. Rollout **unresolved** — see §4 |
| CR-02 | Burner-block evidence retains its source scope | **Narrowed.** As delivered it reversed a specified contract — see §5 |
| CR-03 | The in-memory workflow transaction test double is atomic | Retained as delivered (test double only) |
| CR-04 | Command identities and replay envelopes fail closed | Retained as delivered |
| CR-05 | A failed component stream cannot be re-certified by another source | Retained as delivered |
| CR-06 | Retry outcome writes respect the existing claim boundary | Retained as delivered |
| CR-07 | Temporary quota refusals retain retry semantics and delay | Retained, **bounded** — see §6 |

Three restore consistency with code this repository already had right, which is
the strongest available signal that a finding is real:

- **CR-05** — `combineQualityWarningWindows` already invalidated its source on
  error; twelve sibling sites did not.
- **CR-01** — `verifyInspectionFinding` already required
  `expectedFindingVersion` and already returned
  `aggregateVersion: command.expectedVersion`; `adjudicate` was the outlier.
- **CR-04** — `isSupportedWorkflowCommandType` already used an own-property
  check; the dispatcher was not using it.

**CR-07 is the most consequential.** `callableAbuseControl` throws
`resource-exhausted`; the gateway had no case for it, so it fell to `internal`,
which classifies as `manualReview`. A temporary rate-limit refusal permanently
stranded submitted work, and would fire hardest while recovering from a network
block when queued commands flush at once.

Two claims that could affect **already-stored** data were checked and are safe:
the new `canonicalAppliedAt` check cannot reject any receipt this system wrote
(`iso()` is `toISOString()`, `dispatcher.ts` is the only write site, and
`firebaseStore.ts` deliberately keeps `appliedAt` a string), and the
`zeroVersionTerminalReplay` set is complete — `finalizeJobHandler` and
`laneHandlers` are the only two `: 0` fallbacks. `WorkflowErrorCode` is not
persisted, so appending `resourceExhausted` has no A-04 consequence.

## 3. Adapted before landing

1. **The quota deferral was unbounded** (§6).
2. **A governance gate was broken.** The patch inserts
   `test:corrective-regressions` into the `functions` test chain, which
   `release_startup_hygiene_contract_test.dart` pins verbatim so no gate can be
   added or removed silently. The pin was updated deliberately.
3. **Two supplied tests asserted on local-time values.** Isar returns
   `DateTime` in local time and Dart's `==` requires a matching `isUtc` flag as
   well as the same instant. Normalised, with the reason recorded in the file.
4. **CR-07 handed the sync push path a tight loop.**
   `_shouldRetryWorkflowCommand` delegates to `WorkflowRetryPolicy.classify`, so
   making quota refusals retryable also made them retryable inside a 3-attempt,
   2s/4s loop that ignores the server's window. Now expressed as
   `WorkflowRetryPolicy.mayRetryInCallerLoop` and covered by regression tests in
   `test/audit_corrections/quota_deferral_boundary_test.dart`.
5. **CR-02 was narrowed** (§5).

## 4. CR-01 — the rollout is not yet solvable by ordering

`exactKeys` requires an exact payload key set, so it refuses a **missing** key
and an **extra** key alike. Both transition directions therefore break. This was
established by running identical requests against two compiled backends loaded
in one process; the replay rows execute on one backend and replay the receipt it
actually wrote rather than a fabricated one.

Probe: `tools/maintenance_workflow/cr01_adjudication_compatibility_matrix.cjs`

| Combination | Observed |
| --- | --- |
| existing client → existing backend | accepted — reference behaviour |
| **new client → existing backend** | **refused** `invalid-argument` |
| **existing client → new backend** | **refused** `invalid-argument` |
| new client → new backend, current revision | accepted, finding → v6 |
| new client → new backend, stale revision | refused `aborted` / `inspection-finding-version-conflict` — the intended protection |
| **accepted before transition, replayed on new backend** | **accepted** — receipt replay is unaffected |
| **retained but never accepted, sent to new backend** | **refused** `invalid-argument` |

Two consequences:

- **There is no safe ordering.** Client-first breaks new clients against the old
  backend; server-first breaks un-updated handsets. Earlier advice in this
  round that the client should simply ship first was wrong.
- **Already-accepted work is safe; unexecuted retained work is not.** The
  dispatcher reads the receipt before the handler validates the payload, so a
  replay returns the stored receipt. A request that was retained but never
  accepted fails `invalid-argument`, which the client classifies as `reject` —
  terminal. That is an operator's submitted adjudication becoming permanently
  rejected.

### Options for the rollout decision

Neither is implemented on this branch.

**Option A — expand, migrate, contract (smallest).** Make
`expectedFindingVersion` optional on the backend first: enforce it when present,
and when absent apply exactly today's behaviour. That is a superset, so old
clients are unchanged and new clients gain the protection. Ship the client.
Once no old client remains, make it required. Backend goes **first**, no
operation is ever unavailable, and retained old-shape requests still execute.
Cost: the protection is not universal until the contract step, and that step
needs evidence that no old client remains.

**Option B — controlled unavailability.** Disable finding adjudication, update
both sides, re-enable. Simpler to reason about and universal immediately, but it
takes a plant function offline for the window and still terminally rejects any
request retained across it.

Under no option should a missing revision be filled in from the latest server
record. That would sever the connection between the evidence a person reviewed
and the decision they submitted, which is the whole point of CR-01.

## 5. CR-02 — what the patch enforces, and what it wrongly removed

The delivered change scoped candidate actions by source **index**. CI showed it
breaks two named tests in `functions/test/burnerBlockLifecycle.test.js`:

    accepts an execution-level replacement for a changed module target
    reconciles a no-change module response with execution-level actions

Those names are the contract, and `executionLevelMechanicalEvidence` exists as a
parameter specifically so execution-level evidence can support a module
declaration.

**The representative flow, checked against the screens.** An operator can record
component work in two places: "Add component work" on
`job_module_detail_screen.dart` (module-scoped), or "Add action" on
`complete_job_screen.dart` (execution level, `sourceModuleId: null`, source
index 0). Both are ordinary and available; nothing in the UI marks one as the
one that counts for a module's declaration. `plannedJobClosure.ts` assembles the
sources with execution level first and each module after it, and only module
sources carry `responsesJson`, so only they raise a declaration.

Scoping by source index removed execution level from view entirely and broke the
contract in **both** directions: a "changed" declaration could no longer find
its replacement, and an execution-level replacement could no longer contradict
an "unchanged" declaration — the check that catches a misdeclaration. The second
is a safety regression, not a tightening.

**What now ships:** another *module's* action may not satisfy or veto this
module's declaration; execution-level actions remain in scope. That is the
stated operating rule — one physical action recorded once, with enough context
to say which declaration it supports — and it does not force the same repair to
be entered twice. The supplied regression asserting the wider rule was replaced
by one asserting this boundary, with the reason recorded in the file.

**What is not implemented:** an explicit, validated association binding an
action's identity to the declaration it supports. Today the association is
positional and contextual — same module, or execution level with matching
burner position and discipline — not an explicit link. Recording that as a
current limitation, not as a rule that execution-level evidence is invalid.

## 6. CR-07 — what the bounded deferral guarantees

| Property | Value |
| --- | --- |
| `WorkflowRetryPolicy.maxQuotaDeferral` | 6 hours |
| Window starts at | `WorkflowCommandRecord.createdLocallyAt` — **first local recording**, never server acceptance |
| Server-specified delay | `retryAfterSeconds`, accepted only as an integer in 1…86400 |
| Applied delay | the longer of ordinary backoff and the server's window |
| `WorkflowRetryPolicy.quotaFallbackDelay` | 5 minutes, used when no usable window is supplied |
| On expiry | `manualReview`, `nextRetryAt` cleared, payload and identity kept |

**Justification.** A quota refusal does not advance `attemptCount`, so ordinary
backoff does not grow between refusals; falling back to the plain value would
ask a rate-limited endpoint again every fifteen seconds. Six hours covers a
shift handover, so work that cannot get through within one shift becomes a
person's problem rather than a background loop's. Both values are policy
constants, not tuned to a measurement, and should be revisited against real
rate-limit behaviour.

**Why a refusal counts as definite non-execution — from source, not from the
error name.** `executeWithCallableAbuseControl` awaits `admitRequest` and throws
`resource-exhausted` there, *before* `args.execute()` is called. The handler,
its transaction and its receipt never run. This justification covers refusals
from that admission gate only; the client cannot distinguish one raised
elsewhere, which is why the design never *reduces* uncertainty.

**The two questions are kept separate.** "Was this attempt refused before
execution?" and "could an earlier attempt already have been accepted?" are
independent. A quota refusal writes `uncertainOutcome` and leaves an earlier
uncertain outcome and its attempt count intact, and
`applyRetryTransitionUnlessAccepted` returns `alreadyAccepted` before the build
callback runs, so a refusal cannot override an accepted receipt.

Demonstrated in `test/audit_corrections/quota_deferral_boundary_test.dart`:
the window is measured from first local recording; repeated refusals do not move
its origin; a later refusal leaves an earlier uncertain outcome uncertain; a
later refusal cannot override an accepted receipt; expiry reaches the operator
through `readOutcomeInventory` / `describeWorkflowAttention`; and the short
caller loop stands aside for a quota refusal while still reattempting ordinary
transient failures.

## 7. Verification

Toolchain: Flutter 3.44.0 (framework `559ffa3f75`), Dart 3.12.0, Node v22.15.0,
npm 10.9.2, TypeScript from `functions/package-lock.json`.

Lockfile identities (SHA-256, first 16): `pubspec.lock` `a90b03b4f9332a0b`,
`package-lock.json` `74a3de91c6d04543`, `functions/package-lock.json`
`4a494b48bfa42d19`.

| Command | Result |
| --- | --- |
| `flutter analyze` | clean, exit 0 — **local only; skipped in CI, see §8** |
| `flutter test` | 2258 passed, 1 skipped, **1 failed** — the failure is the governance gate in §9, not a product defect. One further test (`operational_event_creation_store_persistence_test`) failed once under the parallel runner and passes 14/14 in isolation; recorded as an observed flake, not dismissed |
| `python tools/v4/v4_2_r1_canonical_audit.py` | `pass=148 fail=2 total=150` — both failures are the backend-drift assertions in §9. **Local only; skipped in CI, see §8** |
| `functions: tsc --noEmit --pretty false` | clean, exit 0 |
| `functions: npm test` | 1036 passed, 102 emulator-skipped, 0 failed |
| `functions: node --test test/audit-corrections.node.cjs` | 44 / 44 |
| same, against untouched baseline | **14 passed / 30 failed** (revised suite) |
| `cr01_adjudication_compatibility_matrix.cjs` | §4 |

The baseline comparison was rebuilt independently: a separate detached worktree
at `03c3e8fa` with its **own** `npm ci` and its own `tsc` output, not a shared
or stale directory. Only the new test file was copied across; source stayed
untouched. Two different numbers exist and must not be conflated. The suite **as
delivered** produced 13 passed / 31 failed against baseline. After CR-02 was
narrowed, the test asserting the over-broad rule was replaced by one asserting
the corrected boundary, and that case also passes on baseline — so the
**revised** suite produces 14 passed / 30 failed. The earlier figure belongs
only to the delivered suite and is not carried forward. Independently
reproduced by the reviewer and re-verified here on a freshly built baseline.
The supplier's qualification still holds — the failures are not that many
independent defects, since the ten `envelope` cases are one defect
parameterised.

**Skipped Flutter test.** `test/tools/a05_persisted_reconciliation_bridge_test.dart`,
"reconciles an in-memory production envelope through app readers", skips when
`A05_BRIDGE_URL` / `A05_BRIDGE_TOKEN` are unset. It is the one check that would
drive real production-shaped envelopes through the persisted decoders, which is
the same A-05 territory CR-05 touches. It did not run, here or on baseline.

### 7.1 Invalidated and interrupted attempts

Kept deliberately, because a clean total that hides a discarded run is not
evidence.

| Attempt | Status | Why |
| --- | --- | --- |
| `functions` corrective regressions, first local run | **invalidated** | `npx` did not resolve the local compiler, so the suite ran against stale `functions/lib`. It reported 13/31 — the pre-patch result — and was mistaken for a real one until the build error was read. |
| `functions/node_modules` | **destroyed and restored** | A directory junction was created into it from a throwaway worktree; `git worktree remove --force` followed the junction and emptied the target. Gitignored build artifact, nothing in git or source affected, restored with `npm ci` and re-verified at 348 packages. A clean CI checkout never shares a writable dependency directory with a disposable worktree, and the junction technique has been abandoned. |
| CI run 34614296997 (`6525cd82`) | **cancelled** | Superseded by a push while it was in flight; the workflow uses `cancel-in-progress`. Its Cloud Functions job had already reported success. Not counted as an exact-head result. |
| CR-01 probe, first two versions | **invalidated** | Seeded the wrong receipt path, then an incomplete receipt. Both measured a fresh execution rather than a replay. Replaced by executing on one backend and replaying what it actually wrote. |

## 8. What CI actually executed, and what it did not

The Flutter host job **failed at step 4 of 20** — "Production policy and
package-verifier runtime gate". Every later step was skipped, including Flutter
setup, the canonical source and authority audit, `dart format`, `flutter
analyze`, the Isar bindings regeneration and the whole test stage.

So for this candidate, in CI:

| Evidence | Status |
| --- | --- |
| Firestore rules + governed callable emulator | ran, passed |
| Cloud Functions build + non-emulator tests | ran, passed |
| Android release package + cold-start | ran, passed |
| Android emulator app-shell integration | ran, passed |
| `flutter analyze` | **never ran** |
| `flutter test` | **never ran** |
| canonical audit (150/150) | **never ran in CI** |

The correct description is: **four jobs passed; the Flutter host job was blocked
before its analysis and test stages.** The 2253 / 1 skipped / 1 failed figure and
the 150/150 audit are local evidence only, and should not be read as CI results
for this head. An earlier draft of this record invited that reading.

Obtaining those checks on the exact candidate without first satisfying a
promotion gate is a real gap in the pipeline's shape, not just a reporting
nuance — the workflow places the policy step ahead of the toolchain.

## 9. Two governance gates are legitimately red

Build 28's 47 commits never touched `functions/src`, which is why PR #360 is
green. This is the first branch to change backend source, and two gates detect
that the deployed backend no longer matches it:

- `Test-ProductionReleasePolicy.ps1` — *"Current source backend authority
  differs from source state."*
- `test/successor_engineering_rearm_contract_test.dart` — the derived plane is
  `…AWAITING_GOVERNED_BACKEND_DEPLOYMENT…` while the recorded index still says
  `…BACKEND_READY…`. The same test passes on untouched `03c3e8fa`.

Both are correct. They can only clear through a governed backend deployment and
readback, which is a separate decision and is not authorised here. **No
fingerprint, receipt or index has been regenerated to obtain a pass.**

Consequence: this branch cannot show a fully green release-gate while it changes
backend source and no deployment exists for it.

**One earlier claim here was too strong.** Saying only a deployment can clear
these is not supported by what the policy code does. It already computes a
`SOURCE_SUCCESSOR_PENDING_GOVERNED_DEPLOYMENT` state, and derives candidate
construction, distribution and runtime authority separately. A truthful update
of a *derived current-state declaration* to say the candidate is pending
deployment is a different act from forging a deployment receipt or weakening a
check, and it would still go through the existing governance review. What must
not change is the historical receipt, the recorded deployed identity, or the
candidate's production authority, which stays false.

That distinction has not been demonstrated here — no PowerShell was run and no
metadata edit was shown to clear the gate. The narrower, supportable statement
is that **engineering verification should not require production deployment**,
and the two should be separable so source checks can run while promotion stays
blocked.

## 10. Scope

The sibling sweep was a **targeted examination using the seven correction
patterns**, not a whole-codebase audit. Areas and callers examined:

| Pattern | Examined | Result |
| --- | --- | --- |
| CR-05 stale stream retention | every `onError` forward in `lib/`, plus every `.listen` with an error handler | 12 sites, all in the six changed files; single-source listeners and health recorders correctly out of scope |
| CR-07 transport-code mapping | `published_template_assignment_server_service`, `runtime_job_module_population_service`, `quality_command_service`, the four `sync_service` classifiers | workflow gateway was the only outlier; **found** the sync short-loop consequence |
| CR-06 claim fence | all three `applyRetryTransitionUnlessAccepted` callers and every `stateKey` writer outside the repository | complete |
| CR-04 identity validation | callables building document paths from request data | each already validates through a local `documentId` guard; those guards do not check control characters or byte length, which is pre-existing and unaddressed |
| CR-01 parent-vs-child revision | every handler returning `aggregateVersion: command.expectedVersion` | one candidate raised and **withdrawn** — see below |

**Withdrawn finding.** `linkInspectionObservationIssue` bumps a finding's
version with no `expectedFindingVersion`, which looked like a CR-01 sibling. It
is not: its `activeFindings` filter already excludes `verifiedResolved`,
`acceptedCondition` and `invalidated`, so an adjudicated finding is never
touched. Recorded because a withdrawn finding is part of the sweep's result.

A clean result inside that sweep is not a claim that other business functions
have been audited.

## 11. The snapshot's completeness claim was wrong

The archive delivered for this round carried a manifest saying it was "the
commit's tracked tree minus one file, with one file redacted". That is false.
It was an archive of a **selected list of paths**, and 23 tracked top-level
entries were omitted:

`.firebaserc`, `.gitattributes`, `.github`, `.gitignore`, `.metadata`,
`.npmrc`, `README.md`, `SECURITY.md`, `V4_HANDOFF`, `V4_1_HANDOFF`,
`V4_2_HANDOFF`, `V4_2_R1_HANDOFF`, `assets`, `firebase.json`, `ios`,
`jest.config.js`, `linux`, `macos`, `release`, `release_gate.ps1`, `tooling`,
`web`, `windows`.

This is not only missing documentation. `.github` holds the very workflows under
discussion; `release` holds the authority records and current-state index that
§9 is about; and **both dependency manifests declare
`brace-expansion: file:tooling/brace-expansion-compat`**, so `npm ci` cannot run
from the archive at all. A reviewer could not reproduce the dependency install,
let alone the gates.

The checksum proved the archive arrived intact. It could not prove the archive
contained what its manifest claimed, because the manifest described a tree that
was never assembled. A supplemental archive from the same commit, with an exact
inclusion and exclusion list, corrects this.

## 12. A second stale measurement, and the CR-07 caller boundary

Two further corrections came from independent review, both worth recording
because they are the same mistake in different places.

**The audit figure was stale.** `150/150` was measured at `f56673b6` and carried
forward into this record and the pull request after CR-02 was narrowed. At the
head those documents describe it is **148/150**, failing the two backend-drift
assertions in §9. Together with the 13/31 figure in §7, that is twice that a
number measured on one artifact was reported for a later one. Measurements are
now taken at the head being described.

**The short-loop fix did not reach its own caller.** `SyncService` holds a
`WorkflowCommandGateway`, not `WorkflowOnlineExecutor`, so
`_pushMissingMaintenanceTicket` submits straight to the gateway and nothing
wrote `nextRetryAt` for it. Declining to retry inside one `_retry` loop stopped
a second attempt in that call and said nothing about the next sync invocation,
which could resubmit immediately. The policy comment asserting that "the
executor has already retained the request with the server's retry window" was
false for this caller.

**Two attempts to close it were made and both were withdrawn.** They are
recorded because the reason they failed is the useful part.

The approach was to store the server's window on a `ready`
`WorkflowCommandRecord` keyed by the identity the ticket already determines
(`createMaintenanceTicket_<ticketId>`), read before submitting and written on
refusal. Follow-up review found four defects in it:

- **The row had no completion path.** Nothing settled or removed it after a
  successful push, `getUnsyncedTickets` no longer returns a synced ticket, and
  `claimRetryableCommands` deliberately skips `ready`. The row would persist,
  counted as `retrying`, with nothing able to finish it.
- **The write was not atomic and ignored receipts.** It read with
  `getRetryCommand` and wrote with `saveRetryCommand` in separate transactions,
  so a concurrent acceptance could be overwritten.
  `applyRetryTransitionUnlessAccepted` exists precisely to prevent that.
- **The escalation rule was documented but not applied there.**
  `quotaDeferralExhausted` is only called by `WorkflowOnlineExecutor`, which
  this path bypasses, so the new owner would defer indefinitely.
- **The eligibility read considered only `nextRetryAt`**, so it expressed
  waiting but not ownership, terminal disposition or acceptance.

**The test did not test the production path.** It used real Isar storage but
defined its own copies of the two helpers and never constructed `SyncService`.
Disabling the production check outright (`if (false && …)`) left it passing
5/5 — verified, not assumed. It proved the storage behaved, not that anything
used it.

Both attempts are reverted. The honest reading is that this path deliberately
has no command lifecycle owner, and bolting one on incrementally produced a
leak and a race in exchange for closing a rate-limit inefficiency that loses no
data. A correct version needs the full owner contract — exact stored outcome
and current state, waiting without claiming acceptance, terminal and
other-owner dispositions, an atomic receipt-aware write retaining identity,
payload and first-local timestamp, the escalation policy applied in this owner
too, settlement of an accepted creation with removal of its cooldown row, and
explicit handling of local cancellation and missing source intent. That is
durable-dispatch work, not a patch to this branch.

What is kept from the attempt: the policy comment no longer claims a guarantee
this caller does not have, `mayRetryInCallerLoop` names the short-loop decision,
and the six-hour rule is stated precisely. **The gap itself remains open** — a
later sync invocation can still resubmit inside a server quota window.

**The six-hour value is not a visibility deadline.** `quotaDeferralExhausted`
is evaluated while handling a refusal, so the rule is *escalate on the first
quota refusal occurring after six hours have elapsed*. The next attempt is
scheduled by the server's own window, which may be as long as a day, so
escalation can be later than six hours. Scheduling an earlier attempt purely to
trigger escalation would mean ignoring the delay a rate-limited server asked
for. A true wall-clock guarantee would need something that promotes the row
without a network attempt, and that does not exist here. Stated in the policy
rather than left to be inferred.

## 13. Open

Durable intent before first dispatch, claim-generation isolation, WorkManager
continuation, historical cursor-omission reconciliation and external recovery
remain untouched — the incident's actual product gap is not addressed by this
round. CR-01's rollout is undecided (§4). CR-02's explicit action-to-declaration
association is unimplemented (§5). CR-07's constants are judgement, not
measurement (§6). Nothing here reaches *device path demonstrated*.
