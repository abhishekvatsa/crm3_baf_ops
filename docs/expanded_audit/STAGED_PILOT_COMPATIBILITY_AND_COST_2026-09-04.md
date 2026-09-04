# Staged Pilot Compatibility, Latency and Cost Review

Date: 4 September 2026. Baseline: `cdf54f2`, followed by the changes recorded here.

## Decision and Limits

The owner approved a staged rollout preserving existing older-phone validation
during upgrades, explicitly accepting the temporary legacy validation gap.
This is a compatibility decision, not evidence that the gap is fixed, that a
backup exists, or that production deployment, deletion or restoration occurred.

The working Rules are byte-identical to deployed source
`32aae03c1d1bd65eafe611496fdf29caed3759fb`, SHA-256
`9B0A8B0E9F316AE104C0507B70B94C9B7A6F04D379C86A67933CD4FC27CD54DC`.
Only the abnormality-rule changes in this PR were withdrawn. The unchanged
rules/index deployment receipt remains authoritative; modified Functions are
still pending deployment. No new rules deployment is needed for stage one.

## Stage One: Compatible Migration

1. Finish review and CI, select the exact merged Functions source, and use the
   governed deployment procedure with existing IAM and App Check preserved.
2. Retain deployed Rules while the new client and its fully validating
   `mutateChargeAbnormality CREATE` path are installed and verified. Validate
   source, warning, receipt and exact local adoption, including lost responses.
3. Old direct paired writes with 1 through 50 affected assets remain permitted.
   Zero-asset paired writes and 51-asset writes remain rejected by the deployed
   contract. The earlier proposed claim of unchanged zero-asset direct support
   was incorrect: the deployed warning requires a nonempty affected list.
4. Rich hierarchy creation must use the new callable. Tests deliberately record
   that the old direct path still admits malformed nested identity entries.
   Modern callable malformed-input tests continue to require atomic rejection.
5. Confirm upgrade uptake and reconcile retained pending drafts before changing
   the legacy route. Do not equate a version handshake with all drafts being safe.

The stricter modern route supports legacy draft normalization, including cases
whose local edit counter exceeds one. It does not silently erase conflicted
drafts or certify that every installed client has migrated.

## Stage Two: Remove the Remaining Gap

Gate this separately on controlled-roster upgrade evidence, a pending-draft
inventory/reconciliation result, and mixed-version/offline retry tests. Choose
either retirement of direct creation after migration or a proven compatible
validator within Firestore's evaluation limits. Review the exact Rules hash,
deploy with approval and perform strict readback. No automatic date-based
cutoff is enabled. The P1 nested-validation finding remains accepted/deferred
for old clients until this stage is completed.

## Latency Fixes

The preceding timestamp commit corrects new component action timestamps to UTC
and reads legacy unzoned plant times as IST without rewriting historical text.
It addresses the demonstrated maintenance-work-period rejection class.

Resolution previously waited for a workflow-wide projection pull, adopted the
exact issue, and then waited for another whole-app sync. It now skips only the
first redundant projection pull, validates the receipt, awaits exact issue
adoption, and admits the normal full refresh in the background. Other command
callers retain their default refresh behavior. Real command failures still
reconcile and fail; a pending exact readback is not described as verified.

`maintenance_resolution_latency_test.dart` drives the actual form with a delayed
server receipt, delayed readback, an unfinished unrelated sync and a late sync
error after navigation. The form does not finish before the authoritative
boundary, and does finish without waiting for unrelated sync. Both verified
and pending-readback messages are tested. No mutation is silently marked synced.

Issue creation already observes acceptance of the exact ticket, rather than
using completion of unrelated sync as its success signal. Planned-job completion
still waits for module evidence synchronization: this is an integrity dependency,
not a delay removed for appearance. No server latency percentile or phone
network-speed claim is made from these host tests.

## Cost and Resource Findings

| Area | Finding and treatment |
| --- | --- |
| Resolution refresh | Removed one redundant seven-domain workflow pull per successful issue resolution. The remaining sync keeps normal queue/recovery guards. Moving work to the background alone would not reduce its cost; removing the duplicate pull does. Exact billed savings are unmeasured. |
| Active feeds | Shared live mirror has same-scope duplicate-start prevention, lifecycle cancellation and restart. Active directives/jobs stay complete; recent diary/abnormality/template audit feeds use limits of 100, knowledge 50. No arbitrary cap is added to outstanding operational work. |
| Quality cards | Linked cases use exact-document, auto-disposed subscriptions on lazy cards. Active warnings plus 500 recent warnings remain a workspace window, not report completeness evidence. |
| Reports: remaining scaling risk | Quality warning/monitoring and some other report inputs read full history before filtering. Actor-keyed auto-disposal limits lifetime, but initial read/memory cost grows with history. A future date-overlap query/report snapshot design must preserve old unresolved cases, reopen history and complete period coverage. Simply limiting to recent records would make reports wrong. |
| Global pull | Actor/database-generation cursors and pages of 500 bound transfer batches, not total history. Cold initialization can still be substantial. Live plus delta paths deliberately overlap for reliable convergence. Do not remove either without proving its responsibilities are replaced. |
| UI timer | Issue-screen one-minute timer only updates local elapsed-time presentation; it does not issue a cloud read. It is cancelled on disposal. |
| Server clock | A relevant business write can cause a second stamp write and listener event. Stamp-only events are ignored, preventing an endless write loop. This cost buys a trustworthy delta cursor and must not be removed without a replacement. |
| Scheduler | Every 15 minutes: only eligible escalations are queried, pages 200, cap 1,000 per category, transaction concurrency 20. The sweep also performs monitoring retention. This is bounded work, not a full database poll. |
| Functions capacity | Source explicitly sets callable memory/timeouts/concurrency, but does not explicitly set fleet min/max instance counts. Actual deployed settings, cold-start latency and billing must be inspected before selecting caps or paid warm instances. No capacity/IAM change was made. |
| Local processes | The process inventory showed no stale Dart, Flutter, Jest or Java emulator before testing. Unrelated Adobe/Codex Node processes were left alone. Final test-process status is recorded below. |

Firestore bills document/index operations, storage and bandwidth; listening is
not a one-time free read. Reconnects and rule-dependent reads can add cost.
See [Firestore billing](https://firebase.google.com/docs/firestore/pricing).
No actual project billing export, spending ceiling or restore test was available
to this pass; therefore no monthly currency figure or claimed percentage saving
is offered. Compare daily reads/writes, function time/invocations and p50/p95
submit latency before/after the pilot upgrade, normalized by active users.

Use project-scoped spending alerts at agreed thresholds. A billing budget does
not itself cap spending: [Google Cloud budget guidance](https://cloud.google.com/billing/docs/how-to/budgets).
Warm instances trade recurring cost for fewer cold starts; instance caps can
trade cost for queuing/rejection: [Functions capacity guidance](https://firebase.google.com/docs/functions/manage-functions).
Safety traffic should not be automatically disabled by a spending cutoff.

## Recovery Is Not Validation

Server synchronization is not an independent backup. A recoverable checkpoint
requires verified retention, access, restore procedure and testing. A restore
can also overwrite later legitimate work and cannot undo decisions already
made from bad data. This pass neither asserts universal recoverability nor
restores, deletes, or edits any production business record.

## Verification

| Check | Final result |
| --- | --- |
| Full Flutter suite | 1,845 passed; one conditional production-bridge test skipped, not certified. |
| Full analyzer | No issues. |
| Firestore Rules emulator | 262 passed, including each legacy size 1-50 and explicit known-gap witnesses. |
| Governed Functions emulator | 97 passed; emitted source and callable/notification inventories passed. |
| Canonical source/authority audit | 149 passed, zero failed. Only measured successor pins changed; historical hashes retained. |
| Production release policy | Passed with Functions still pending and no fresh artifact authority. |
| Rules expression budget | No 1,000-expression warnings in the emulator log. |
| Process and whitespace checks | No matching Dart/Jest/Firestore-emulator processes left; diff check clean. |

PRs 342-344 were rechecked; no unresolved review threads remained. PR 345's
6-50-asset regression is addressed by retaining the exact deployed Rules;
fresh remote review and CI are still required for this new source.

Raw local evidence:
`output/build24-release-preflight/staged-*.log` (ignored generated files).
No APK or production deployment is implied by local checks.
