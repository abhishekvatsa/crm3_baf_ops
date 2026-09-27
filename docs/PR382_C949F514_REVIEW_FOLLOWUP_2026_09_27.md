# PR #382 — review of c949f514 and subsequent CI

The supplied review correctly recognizes the five passing Android journeys and
authenticated queue-ownership proof at `c949f514`. Its planned-maintenance
evidence covers the explicit **No RED** route; it does not qualify every planned
work variant. Unknown-origin legacy work still requires review, and production
rollout remains separate from source acceptance.

Both newly reported source findings were confirmed against the current code.

## Individual audit dependency holds

The supplied planned-work log holds a publication audit, then reports zero
failed writes and zero deferred stages. The row remains local, but that omission
allows the coordinator to report success prematurely.

The repair records distinct held-record identities separately from skipped
stages and failed writes. It includes the count in run health, diagnostics and
the operator's sync details. A held record makes the run partial; no failed
server write is invented. Stage prerequisites also account for newly held rows.
Counts reset on each run.

The regression exercises the actual sync service and coordinator with controlled
repository boundaries. It checks two held runs, unchanged audit evidence, no
write or acknowledgement, independent stage/pull progress, and partial status
after the usual success-reset interval. Once the remote package becomes valid,
the exact audit is reconciled and the held count clears. A separate test keeps
exact existing remote-audit convergence independent of historical dependencies.

## Authority during purge cleanup

The coordinator previously checked its run guard only outside the asynchronous
cleanup helper. The helper now receives that same guard, checks it after reads
and at local transaction mutation boundaries, and propagates invalidation.
Existing synchronized-state, identity/version and dependent-record protections
remain in place. A transaction that observes invalidation rolls back.

Three native Isar regressions pause manifest/dependency reads, invalidate the
same account's authority epoch or dispose the owning run, then resume. They
failed before the repair and now prove the original record and dependent work
remain unchanged. All 25 local recovery tests passed. Combined sync, recovery,
coordinator, status and decomposition verification passed **107 tests**.

## Later Android sign-out failure

The next source revision, `483d3ffb`, passed Functions, Flutter host, Rules,
Android packaging/cold start, and CodeQL. Its Android business job failed after
planned publication and assignment: the previous SI profile listener emitted
`permission-denied` during sign-out, before the token-change stream replaced it.
That is a session-lifecycle defect, not a missed-tap failure or failed ownership
assertion. The ownership pair was not reached in that run.

The follow-up detaches profile authority during sign-out and fences obsolete
profile generations against the live authentication identity. The profile
listener now has explicit cancellation, including cancellation while awaiting
asynchronous work; an obsolete generation stays invalid even if the same UID
returns before a new token event. A fresh session can establish authority again.
All 21 focused tests passed, including real-provider listener cancellation,
replacement account/startup cases, and genuine current-actor errors after the
existing one-refresh retry budget. Whole-client analysis is clean. No sleeps or
ignored Flutter exceptions were added to the integration journeys.

The final auth/profile-schema/current-ledger batch passed 27 tests, including
malformed current-profile rejection and cancellation during a paused token
refresh. The canonical audit passed 153/153, inventory rejection contracts
24/24, and release-authority contracts 9/9 (490 branch-acceptance cases).
The inventory refresh records only the changed provider boundary and explicit
error handlers; existing authority policies and historical evidence are retained.

See the latest PR checks for acceptance of the resulting commit. The earlier
green run is not acceptance of later untested edits. No production records,
phone installation, backend/Rules deployment, signing state, historical release
receipts or distribution authority were changed by this source repair.
