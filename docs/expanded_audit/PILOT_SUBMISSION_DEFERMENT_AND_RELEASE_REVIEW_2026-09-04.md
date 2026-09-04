# Pilot Submission, Deferment Chronology, and Release Review

Date: 4 September 2026

## Scope and Verdict

The application changes are frozen in local commit
`fd7cb4ec7993ca9bcad20743ce3eee5f6c429f28`. This follow-up also reconciles
the exact source, persistence, schema, and decoder audit inventories. Historical
deployment receipts and build identities remain unchanged.

Three conclusions are supported by this review:

1. Issue submission unnecessarily waited for unrelated full-app synchronization
   after its own server acceptance. The form now observes acceptance of its exact
   issue, while background synchronization remains centrally coordinated.
2. Deferment and Operations-support regression flows retain the original ticket
   timestamps, each compliance attempt, and earlier coordination cycles. The
   latest ticket summary is not a complete chronology display.
3. All 26 production furnace registry records had correct names. Repeated
   furnace names came from display composition, not corrupt registry documents.
   No production record correction was necessary or performed.

This is source, host-test, database-emulator, and limited read-only production
evidence. It is not a claim that every phone, role combination, network condition,
or historical production record has been exercised. No new APK was constructed,
installed, or distributed in this pass.

## Issue Submission

### Confirmed Cause and Change

After durable local save, the native issue form previously awaited the entire
central synchronization pass, including unrelated uploads, downloads, purge
reconciliation, and supplementary workflow synchronization. An issue already
accepted by the server could therefore leave the user waiting.

`maintenance_submission_confirmation.dart` now subscribes before requesting
central sync and observes the exact ticket identity, asset, synchronized flag,
non-deleted status, and version at least as new as the submission. It can release
the form as soon as canonical acceptance has been adopted locally. It never
marks a row synchronized itself and does not bypass the sync/recovery lock.

An eight-second observation limit bounds the wait after durable save, not the
server operation. If acceptance is still unknown, the UI reports pending
confirmation, keeps background retry active, and tells the user not to raise the
same issue again. A failed unrelated sync does not undo proven issue acceptance.

Eleven focused asynchronous tests cover early acceptance, late failures, pending
timeout, queued sync, exact readback, stale or unrelated records, deleted records,
and observer errors. These prove control flow, not actual production latency.
Network transport, function startup, server contention, and earlier queued work
can still delay confirmation. No live pilot submission latency was measured.

## Deferment and Timestamp Retention

Both `deferment` and `operationsSupport` were exercised through initial request,
Operations acknowledgement, completion, return for correction, a second
completion, acceptance, a later independent coordination request, and exact
command replay, using different server times at each step.

| Evidence | Behaviour checked |
| --- | --- |
| Ticket creation, start, and original acknowledgement | Preserved during ordinary coordination |
| Server global-pull stamp | Not replaced by client chronology during the tested projection |
| First rejected compliance attempt | Its attempt time, return time, and rejection remain recorded |
| Later accepted attempt | Its separate attempt time and acceptance remain recorded |
| Workflow event times | Retained separately for each event |
| Previous coordination request and workflow | Retained when another deferment/support cycle starts |
| Exact command replay | Does not create another event or overwrite historical times |

Returning work for correction deliberately clears the current completion fields
only after retaining the previous attempt. Likewise, the ticket's latest
coordination reference moves to the new cycle; this does not delete the previous
request or its history. Ordinary release and reopening an already resolved
ticket are distinct lifecycle actions and should not be conflated.

The ticket dossier/PDF does not yet render every retained workflow event. The
request detail exposes the current request chronology; a consolidated multi-cycle
coordination timeline would improve visibility. Storage preservation is not the
same claim as complete history presentation.

No affected user's production deferment record was repaired or inspected in this
pass. See `DEFERMENT_WORKFLOW_REVIEW_2026-09-04.md` for the earlier transition,
revision, identity, notification, and role-alignment defects included in the same
source commit.

## Furnace Names

A read-only production registry query on 4 September at 13:43:02 UTC found
exactly 26 active Furnace records, numbered 1 through 26, with names
`Furnace 01` through `Furnace 26`. All were version 1. Remote writes: zero.

The screen had treated `Furnace 3` and `Furnace 03` as different descriptions and
joined them. `AssetInstanceRecord.displayLabel` now recognizes equivalent
zero-padded identities and displays the saved name once. Meaningful aliases or
mismatched names remain visible rather than being silently discarded.

The shared label is used in issue raising, governed planned-work assignment,
fleet reports, and operational events. It does not change asset IDs, asset
numbers, stored names, versions, or historical evidence. Twenty-eight tests cover
all 26 furnaces and alias, mismatch, other-class, and punctuation cases.

## Broader Verification

| Area | Evidence in this pass |
| --- | --- |
| Issue creation and synchronization | Exact acceptance observation, replay/version contracts, preserved draft and keyboard-back tests |
| Deferment and Operations support | Multi-attempt chronology, revision convergence, completed-lane rejection, custom-asset identity, notification routing |
| Planned maintenance | Full assignment, runtime module, closure, and workflow emulator suites; missing-projection initialization and transaction ordering regressions |
| Furnace stuck-up removal | Operations authorization and UI/backend regression coverage |
| Burner directives and reliability | Field-only acknowledgement tests, native server timestamp rule cases, condition totals and UI tests |
| Quality and abnormalities | Governed asset details, role/lifecycle transitions, strict command receipts, monitoring retry identity, exact case matching, responsive form tests |
| Asset hierarchy and Inner Covers | Full hierarchy and lifecycle emulator suites; registry display tests |
| Server rules and authorization | Full rule suites, user authority, command replay, abuse-control, and notification receipt emulator tests |
| Persistence and recovery | Full app suite plus exact architecture, persistence, schema, timestamp, and decoder inventories |
| Reports and navigation | Existing full-suite PDF/zoom, report, screen, and navigation tests; revised-request detail regression |

This table describes coverage of automated tests, not a manual tour of every
screen or proof of complete business-path coverage. Morning Review's proposed
asset-first suggestion/PDF redesign was not implemented by this pass.

The broad run found a circular revised-request navigation dependency. The detail
screen now loads its exact authorized successor and navigates to another detail
screen without importing the inbox/notification navigation cycle. Missing,
deleted, wrong-workflow, and failed-read successors remain recoverable errors.

## Recorded Results

| Check | Result |
| --- | --- |
| Full Flutter suite on application commit | 1,832 passed, one conditional bridge test skipped, zero failures |
| Final Flutter rerun after audit reconciliation | 1,832 passed, the same conditional bridge test skipped, zero failures; completed in 4 minutes 3 seconds |
| Analyzer | No issues |
| Backend ordinary tests | 54 suites, 902 passed |
| Backend database-emulator tests | 12 suites, all 97 passed; these are the 97 skipped in the ordinary backend run |
| Firestore rules tests | Three suites, all 218 passed |
| Strict canonical source/authority audit | 149 passed, zero failures |
| Test evidence taxonomy | Passed; eight evidence levels, five jobs, eight critical paths; no physical-device evidence claimed |
| Production release policy verification | Passed for the honest source-successor pending state; not new artifact authority |

The Flutter bridge test is conditional on `A05_BRIDGE_URL` and
`A05_BRIDGE_TOKEN`. No authorized production-envelope bridge was connected for
this run. Its skip must not be reported as a passed production data sweep.

Audit inventory measurements: 563 persistence operations, 1,940 sites, 60
classified persistence surfaces; 53 persisted schema fields and 79 inherited
decoder surfaces; 90 timestamp readers, 222 direct calls, 134 required and 86
optional field declarations; 30 classified direct timestamp parser candidates;
79 decoder surfaces, 50 structurally discovered catch sites, and 408 reviewed
risk candidates. New/changed parser candidates are typed display comparison,
strict linked-entity timestamp decoding, and fail-closed monitoring retry storage.
No general fallback or authorization exemption was introduced.

## Release Boundary and Next Steps

Later update: the owner approved keeping the deployed Rules unchanged while
older phones migrate. The Rules hash and proposed Rules deployment below are
historical, superseded by
[the staged compatibility decision](STAGED_PILOT_COMPATIBILITY_AND_COST_2026-09-04.md).
Functions remain a source successor requiring governed deployment.

Current Functions tree:
`2da1d3d564e6e526899631740b1ee457432af490`.

Current rules SHA-256:
`9C59C7E687A72970D252D9D0469BB45ECF45F593C6440225AAF075353AD9303E`.

The deployed backend is an earlier source. The release state now explicitly says
the current Functions and rules await governed deployment; it no longer implies
that this changed source is already deployed. Existing index definitions are
unchanged. Build 23 is already consumed; the next candidate is at least Build 24.

Before handing out another APK: review and CI on the reconciled source, authorize
and deploy the exact backend/rules successor with existing IAM and App Check
settings preserved, perform strict live readback, then allocate a fresh build
number and construct/verify the signed package. Exact-device and controlled-pilot
decisions remain separate from host-test success. Previously installed clients
do not acquire these Dart/UI changes until upgraded.

## Local Evidence

Logs and the read-only registry result are in
`output/submission-release-review-2026-09-04/`:

- `registry-readback.json`: production furnace-name inventory, zero remote writes.
- `focused-flutter-final.log` and `final-fix-regression.log`: focused tests.
- `flutter-final.log` and `flutter-release-final.log`: complete app runs.
- `functions-full.log`, `emulator-full.log`, and `rules-full.log`: backend and rules evidence.
- `analyze.log`, `production-policy.log`, and `canonical-verified.log`: source gates.
- `decoder-inventory-verified.json` and `schema-inventory-verified.json`: exact inventory readback.
- `hash-refresh.json`: the fifteen reviewed application-source hash updates;
  the additional programme-ledger test pin changes only with its measured schema
  expectation. Original canonical hashes and historical deployment receipts are
  preserved.

Earlier failing/interrupted logs in this directory are retained for traceability;
the named final logs are the authoritative results of the corrected runs.
