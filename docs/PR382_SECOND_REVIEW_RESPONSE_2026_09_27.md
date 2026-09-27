# PR #382: response to the review of 1023459d

This records review findings and their evidence. It does not authorize a merge,
backend deployment, production build or distribution. CF-01 remains open.

Implementation update: the bounded CF-01 repair is now in source, including native
atomic ownership, online retained requests, the V2 backend boundary and direct-write
denial. The historical design discussion below describes the earlier checkpoint.
See [the implementation and validation record](CF01_IMPLEMENTATION_VALIDATION_2026_09_27.md)
for current evidence; actual Android and fresh CI acceptance remain required.

The supplied review identifies its baseline as
`1023459d2c9f5351823c2c7220ac21304f6252ad`. The CI setup repair is
`81def5072d3b4f52d47f152e0c4807ee99e6d984`. The difference matters when reading
the earlier failing job results.

## Findings checked against the source and CI

| Finding | Assessment and current evidence |
| --- | --- |
| Persistent ownership differs from current-session protection | Agreed. CF-01 remains a release blocker for the bounded paths in `CF01_QUEUE_OWNERSHIP_FINDINGS_2026_09_27.md`. The current session guard must not be represented as that repair. |
| Android fresh-install setup blocked the new journeys | Agreed with a factual correction: the failed command queried `pm path` for an absent DEV package; the helper did not run `pm uninstall`. The repair accepts only the verified empty absent-package result, rejects transport/unexpected responses, and clears only an installed DEV package on a verified emulator. |
| Synthetic emulator key conflicts with production custody | Agreed. Exactly one known placeholder is hash-pinned at three exact tracked paths and checked as a bounded token. Production paths/counts remain unchanged. Negative tests reject copied real keys, altered/duplicate/missing placeholders, unapproved locations and placeholder substitution in production. No directory exemption was added. |
| Root YAML dependency missing in Functions-only installation | Agreed. The fixture now extracts the five unique literal job names from its pinned Git workflow without the undeclared dependency. Source binding and negative authority assertions remain. Clean GitHub CI passes all 495 release-custody tests. |
| Conflict reconciliation may hold dependents yet report success | Confirmed and repaired in the accompanying source change. A stale execution tombstone can be audited and reconciled with a conflict count but no failure count. Deferred stage identities now make the coordinator report partial progress independently of failed-write counts. Dependency holds remain in force. |

Fresh-emulator inspection also found that Flutter's default integration-test
teardown uninstalls the app. The runner now passes `--no-uninstall` so the restart
journey retains the first process's actual Isar/session data. Explicit per-journey
reset still isolates the independent planned-work case. The orchestration test
asserts the reset, abnormality, force-stop, restart, reset, planned-work sequence.

## Verified CI evidence

The earlier run at `1023459d` passed analysis, all 3,915 Flutter tests (one skip),
222 no-loss tests, and Android release packaging/cold start. Those results did
not prove that the newly introduced business journeys had completed.

The repair run at `81def507` is
[36294322176](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/36294322176).
Its completed logs establish:

- Functions host/build and release contracts passed, including 495/495
  release-custody tests.
- Rules/callable validation actually executed: 341 Rules tests across six
  suites, three governed identity-reconciliation tests, and 243 governed backend
  tests across 21 suites passed.
- Android release packaging, alignment/backup checks and exact APK cold start
  passed. This is non-production emulator evidence.
- The new Android business journeys did not complete. The first journey timed
  out before application startup returned: Android's native notification grant
  dialog remained open. This is a new first-install setup blocker, after the
  absent-package repair succeeded. Restart and planned work did not run. A
  passing runner unit test or backend seed does not substitute for acceptance.

## Deferred-sync repair verification

The targeted regression first failed on the old implementation: the reconciled
parent had zero failed writes, dependent module work remained unchanged and
unsent, and the coordinator incorrectly returned success. With the repair:

- The same actual SyncService/SyncCoordinator path reports partial progress and
  records the three deferred stages; it does not invent a pending-record count.
- Independent pushes and the canonical pull still proceed. The held module's
  exact payload remains unchanged and unsynced.
- Partial status survives the success-reset interval. A subsequent eligible run
  uploads and acknowledges the original module, clears deferred status and
  returns success.
- Reconciled conflicts with no deferred stages can still finish successfully.

All 81 focused tests across six suites passed, scoped analysis reported no
issues, and the canonical audit passed 153/153. An independent source review
found no actionable regression. This proves the tested control flow; it does
not claim a device-level queue-ownership proof or close CF-01.

The repaired runner passed 15 local orchestration tests and the key-security
prerequisite passed 20. A separate review of CodeQL alert #3 confirmed that the
flagged SHA-256 function computes source-identity fingerprints, not password
verifiers. The specific false-positive disposition is recorded on GitHub; the
query, security severity policy and production-key checks remain enabled.

## CF-01 repair design, not closure

The existing `DurableSubmissionRepository` provides useful machinery: immutable
envelope/hash, stable request identity, origin-actor claims, retained unknown
legacy evidence and accepted-result adoption. Reuse should preserve those
properties rather than create three loosely coordinated ownership flags.

The proposed implementation must:

1. Freeze the original actor, Firebase project/environment, target, expected
   version and exact intended payload before enqueueing. The journal and local
   business-row write must commit in one Isar transaction. A resource key must
   exclude the actor UID so another account cannot claim the same pending row
   through a separate actor-specific key.
2. Refuse overwriting another account's pending intent or unbound legacy work.
   Preserve legacy payloads for explicit review; do not infer their author from
   the current actor, creator, assigner or timestamp.
3. Dispatch and adopt through the saved envelope and origin account, including
   after restart, revocation/regrant, a lost response and concurrent local edits.
4. Extend existing governed command/receipt machinery with narrowly defined
   domain mutations if it satisfies each domain's authority and version rules.
   Remove the corresponding direct-write bypass only with the coordinated
   client/backend rollout. Older installed clients' write compatibility is an
   explicit rollout concern, not a reason to silently accept unbound writes.
5. Prove A queues work, B with the same role cannot upload or acknowledge it,
   restart preserves that refusal, and A can return and converge once. Use native
   Isar and an authenticated emulator, with project, payload, version, role,
   unknown-owner and interrupted-receipt negative cases.

No journal migration, new server mutation or CF-01 closure is claimed by this
review response. The PR remains draft while that evidence is absent.
