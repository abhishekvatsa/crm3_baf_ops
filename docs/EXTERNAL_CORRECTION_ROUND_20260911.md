# External correction round — 2026-09-11

An external review round delivered seven corrections against the `03c3e8fa`
review snapshot. This records what arrived, what was verified here, and what
was changed before it landed. It is a verification record, not a restatement
of the supplier's report.

## Binding

| Field | Value |
| --- | --- |
| Baseline | `03c3e8fa8697d8c3a045299a5eb04f52e1056487` |
| Snapshot sent for review | SHA-256 `cd292a2a…4bd33` |
| Supplier's declared input | identical SHA-256, verified byte-for-byte |
| Delivered patch | 29 files, applied cleanly to the baseline |

Two files in the delivery were **not** taken: `MODIFICATION_NOTICE.md` and
`docs/LOCAL_CORRECTION_HANDOFF_20260911.md`. Both describe the supplier's own
working copy ("NOT the missing earlier workspace") and would be misleading
inside this repository. Their technical content is summarised here instead.

## What arrived

| Ref | Correction |
| --- | --- |
| CR-01 | Inspection adjudication binds the reviewed finding revision |
| CR-02 | Burner-block answers and actions retain their source scope |
| CR-03 | The in-memory workflow transaction test double is atomic |
| CR-04 | Command identities and replay envelopes fail closed |
| CR-05 | A failed component stream cannot be re-certified by another source |
| CR-06 | Retry outcome writes respect the existing claim boundary |
| CR-07 | Temporary quota refusals retain retry semantics and delay |

## Verified here, against source

Three corrections restore consistency with code that was **already correct
elsewhere in this repository**. That is the strongest available signal that a
finding is real rather than invented, and it is recorded per-item:

- **CR-05.** `combineQualityWarningWindows` already invalidated its source on
  error. Twelve sibling sites did not. A sweep of `lib/` found exactly twelve
  `onError` forwards that retain last-value state, all inside the six files
  changed. Scope is complete.
- **CR-01.** `verifyInspectionFinding` already required `expectedFindingVersion`
  and already returned `aggregateVersion: command.expectedVersion` without
  bumping the campaign. `adjudicateInspectionFinding` was the outlier.
- **CR-04.** `isSupportedWorkflowCommandType` already used an own-property
  check; the dispatcher was not using it. Other callables already validate
  document identities through local `documentId` guards.
- **CR-07.** Three other services already treat `resource-exhausted` as
  retryable. The workflow gateway was the only one mapping it to `internal`,
  and `internal` classifies as `manualReview` — so a temporary rate-limit
  refusal permanently stranded submitted work. `callableAbuseControl` is
  applied to the workflow callable, so this path was reachable in production.

Two claims were checked specifically because they can affect **already-stored**
data, and both are safe:

- The new `canonicalAppliedAt` check in `idempotency.ts` cannot reject any
  receipt this system wrote: `iso()` is `toISOString()`, `dispatcher.ts` is the
  only write site, and `firebaseStore.ts` deliberately keeps `appliedAt` a
  string rather than a Timestamp.
- The `zeroVersionTerminalReplay` set is complete. `finalizeJobHandler` and
  `laneHandlers` are the only two sites with a `: 0` version fallback.

`WorkflowErrorCode` is not persisted, so appending `resourceExhausted` carries
no A-04 schema consequence.

## Changed before landing

Four corrections were made to the delivered patch.

1. **The quota deferral was unbounded.** CR-07 exempts a quota refusal from the
   attempt budget — correct, because a quota refusal is a definite
   non-execution rather than an uncertain dispatch. But `attemptCount` was
   frozen, `terminal` could never be reached by attempt count, and no age cap
   exists anywhere, so a server that kept refusing would defer the same request
   forever. Bounded by elapsed time from first local acceptance
   (`maxQuotaDeferral`), landing in `manualReview` rather than `rejected`, and
   given a conservative fallback delay for refusals that carry no usable
   window.
2. **A governance gate was broken.** The patch inserts
   `test:corrective-regressions` into the `functions` test chain, which
   `release_startup_hygiene_contract_test.dart` pins verbatim so no gate can be
   added or removed silently. The pin was updated deliberately.
3. **Two supplied tests asserted on local-time values.** Isar returns
   `DateTime` in local time and Dart's `==` requires a matching `isUtc` flag as
   well as the same instant. Comparisons are normalised, with the reason
   recorded in the file.
4. **CR-07 handed the sync push path a tight loop.** `_shouldRetryWorkflowCommand`
   delegates to `WorkflowRetryPolicy.classify`, so making quota refusals
   retryable also made them retryable inside a 3-attempt, 2s/4s loop that
   ignores the server's window. Quota refusals now defer to the durable retry
   path, which already carries the correct delay.

## Evidence level reached

The three-way distinction from `AUDIT_SUCCESSOR_ACCEPTANCE_20260908.md` still
applies, and this round reaches the first two only.

| Check | Result |
| --- | --- |
| `flutter analyze` | clean |
| Flutter suite | 2247 passed, 1 skipped, 0 failed |
| Canonical audit | 150 / 150 |
| Functions typecheck and build | clean |
| Corrective regressions, this source | 44 / 44 |
| Corrective regressions, untouched baseline | 13 passed / 31 failed |
| Emitted-output custody, callable, notification, asset-master gates | pass |
| Firestore emulator suites | not run |
| Android build, retained-data upgrade, second device | not run |

The baseline run is the load-bearing one: these tests fail on untouched source,
so they are regressions rather than tests written to pass. The supplier's own
qualification holds — the 31 failures are not 31 independent defects, since the
ten `envelope` cases are one defect parameterised.

**No handset path is demonstrated by any of this.** CR-01 additionally requires
a coordinated rollout: `exactKeys` demands an exact payload key set, so a
handset that has not been updated would have its adjudication rejected, not
retried, the moment the backend ships. The client must go first.

## Not addressed

Durable intent before first dispatch, claim-generation isolation, WorkManager
continuation, historical cursor-omission reconciliation and external recovery
remain open. CR-02 tightens acceptance — an execution-level action can no longer
satisfy a module-level declaration — which is coherent with the data model but
is a plant-process judgement that has not been confirmed against real closures.
