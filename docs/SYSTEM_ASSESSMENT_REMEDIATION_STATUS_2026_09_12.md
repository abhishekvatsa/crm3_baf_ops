# Independent system assessment remediation — working status

Date: 2026-09-12. Branch: `codex/system-assessment-remediation-20260912`.
Starting main: `2ae7cbb45720fe61566b70a38d1bf9a1519e05ca`.

**This is an implementation record, not a release approval.** The source repair and integration corrections are recorded in
[PR #362](https://github.com/abhishekvatsa/crm3_baf_ops/pull/362). Its current
head checks determine final candidate verification; intermediate local results
below retain their original scope. Historical Build 27, CI results,
APK hashes and deployed-backend evidence do not certify these changes. No APK
with changed source may reuse the historical Build 27 identity.

## Confirmed business decision

For burner-block and UV-detector component life, a late entry for an older
physical installation belongs in history. It must not replace a later physical
installation as current. The user confirmed that replacement requires an
explicit correction. Ordinary event precedence now uses physical action time,
with deterministic ties. This work has not invented a correction callable or
repaired historical production projections.

## Implemented and specifically verified

| Area | Change and evidence boundary |
| --- | --- |
| Inspection corrective evidence | Verification now distinguishes actual corrective creation/linkage and technical resolution from administrative closure, deletion, reopening and incomplete evidence. Accepted historical replay remains read-only. Focused backend suites and the uploaded actual-handler probe passed. |
| Ticket deletion and lifecycle recovery | Cached reads and pending local writes cannot prove deletion. Authoritative absence alone cannot prove that an older creation was never dispatched. Lifecycle recovery has one write/readback attempt per step per pass; an attempted workflow decomposition failure does not fall through to a generic writer. The original 85 focused tests passed with native storage required. Final D09 follow-up: 43 native tests and 29 lifecycle contracts passed, including nine new rebased-closure restart/contradiction/account cases; scoped analysis is clean. |
| Inner Cover acceptance | Validated inspection input, original-account checks, immutable full request before sending, native claims, receipt before current-record readback, restored form and explicit saved acceptance check. Database reopen and UI recovery tests passed. A further native test proves an account change during the final local transaction cannot expose the previous account's result. |
| Master data and hierarchy replay | Root ancestry/counters, stable-ID validation despite display-name changes, exclusive legacy role ownership, active serial inventory and immutable replay proof were repaired. Host and local-emulator tests passed; production data was not changed. |
| Optional crash reporting | Failure of optional telemetry no longer prevents otherwise valid startup. Required Firebase, App Check setup and Isar integrity checks retain their existing authority. Startup/diagnostics focused tests passed. This does not add a timeout for initialization that never completes. |
| Native submission storage | Additive schema 11 stores exact envelopes, origin, resource ownership, claims, validated receipts and explicit states. Native tests cover reopen, conflicting identities, concurrent claimants, late receipts, atomic adoption rollback, corrupt/legacy evidence and unavailable storage. Existing populated migration fixtures passed. |
| Origin-bound compatibility endpoints | Four explicit V2 wrappers retain the original V1 payload and fingerprint: asset hierarchy, maintenance workflow, quality and published assignment. Fresh same-endpoint capability probes are read-only. Wrong-origin calls are refused before business/quota writes. Actual local-emulator V1/V2 replay and guard tests passed. These endpoints are not yet deployed. |
| Inspection campaign creation | Native full-envelope recovery retains both command and campaign IDs, checks original authority, preserves receipt before server-only campaign readback, and exposes saved work independently of the browse feed. Campaign now also fences account changes after native preparation, reconciliation and cancellation, with three actual-transaction regressions. The final core/campaign/assignment batch passed 90 tests, including 15 campaign native cases. |
| Quality monitoring creation | Native full-envelope and receipt recovery, original-account gates, exact governed Base identity, server-only current-record confirmation, never-sent cancellation, and retained legacy evidence. Combined quality/acceptance batch: 72 tests passed; scoped analyzer clean. Subsequent UI batch: 39 tests passed, including browse-error saved recovery and account-error/switch/recovery. The final native quality/acceptance batch passed 22 tests, including lost-response followed by legitimate closure and database reopen. Unknown legacy origin is retained without inventing an actor. |
| Published template assignment | Complete original V2 request and origin survive native reopen; validated acceptance is saved before atomic execution/module adoption. Dirty or newer local work is preserved; contradictory clean same-version projections abort adoption and retain acceptance. Final native suite: 15 passed; actual-handler host suite: 51 passed. This is retained-receipt adoption, not a separate fresh server readback; later-handler-state tests seed legal later projections rather than execute a full closure journey. |
| Burner rounds and directive compliance | Complete frozen intent and native saved-work review, shared furnace ownership, fresh capability and actor checks, retained legacy evidence. 34 selected tests passed; scoped analysis clean. Round completion relies on validated receipt; compliance additionally retains pending local adoption. |
| Morning Review | All 13 supported operations use the native owner and explicit saved-work check. Accepted evidence precedes server-only subject confirmation. 75 selected tests passed across final runs, including 39 native and three UI cases. Private server receipt collections remain private. |
| Current-account UI authority | Tested batches cover maintenance actions, abnormalities/directives creation, planned completion, Red exit, compliance navigation, composer and registry. Forms retain entries while unavailable or changed authority blocks actions. A final eight-test composer batch also fences replacement dialogs and paused preference lookup before clearing recovery. These batches do not establish that every privileged action in the app has been reviewed. |

## Verification and remaining scope

- Quality creation replay after a lost response and later closure now uses
  immutable original audit evidence. Actual backend host tests passed (70; one
  historical fixture-generator skip), and all 14 local V2 emulator tests passed,
  including real historical and modern create/close/replay with zero replay
  business writes. The new `qualitycreate2` evidence reader must be retained
  through backend rollback. Full combined source gates remain outstanding.
- Morning Review START/NOT_HELD requests deliberately omit a session, which the
  server derives from the current India day. An uncertain sessionless request
  must not dispatch on a later day; retained accepted receipts can be checked
  across days. A never-sent request may be explicitly cancelled. Cross-day
  unknown outcomes need review until a safe server lookup exists.
- The post-code-generation canonical audit passed all 150 checks. Current
  full-candidate Flutter/CI status is on PR #362. The first full Functions host
  pipeline passed 1,371 Jest tests and 75 Node tests;
  126 emulator cases and four opt-in fixture generators were skipped in that
  host run. All 126 then passed against the local emulator: 392 emulator-backed
  checks passed overall (Rules, projection reconciliation, governed handlers
  and Gate1B), plus 21 authority-classifier host checks, with zero emulator
  skips. The Rules expression-limit check passed and all emulators stopped.
  Passing these or the schema-only verifier is not distribution approval.
- The dedicated Package B maintenance-creation operation record, atomic dirty
  business-row preparation and proven never-dispatched cancellation remain
  separate integration work. The common native store alone does not complete
  that route.

## Required before distribution

Complete source review and full applicable test/governance gates; preserve
old-client replay and document schema rollback constraints; allocate a new
release identity; verify the exact backend deployment by readback; build and
verify the exact signed artifact; then validate an in-place upgrade and
representative business flows on the connected physical phone. Play signing
continuity with existing sideloaded users must be established before the first
Play release. No installation, distribution, production-data change or IAM/App
Check activation has been performed by this remediation work.

Other assessment recommendations concerning reporting performance, shared-device
exports, replacement-device restoration and structured diagnostics remain
recommendations unless separately implemented and evidenced. No Isar-to-Drift
migration is part of this repair.

Read-only device readiness on 12 September: ADB detected no connected device,
so the currently installed APK version and signer could not be verified. Live
remote release tags stop at Build 27; Build 28 is unused but not reserved by
this remediation. Future release validators need explicit schema-11 and
19-endpoint support without changing historical evidence.

## Integration review of the initial candidate

Canonical pristine audit passed all 150 checks and full analysis was clean. The
first complete Flutter run passed 2,513 tests, skipped the separately driven
A05 bridge harness, and found 15 integration failures. These include stale
source-contract/authority fixtures, current inventory/schema metadata, helper
placement, a two-file burner import cycle and missing shared BAF frames on
new assignment states. They are being corrected; this record does not claim
a complete Flutter pass for the initial candidate.

The root CI Node custody/dependency campaign passed 218 tests after correcting
two current-source endpoint-count expectations. Historical deployed fleet
receipts retain their original counts. The existing dated dependency exception
was unchanged; no new exception or production authority was granted.

The integration corrections then passed all 189 tests in a combined focused
run, including every previously failing contract, native burner recovery and
assignment saved-state UI. An independent four-file runtime review found no
semantic regression from the burner interface or shared assignment frames.
A05 remained exact at 86 surfaces and 53 catches. The complete Flutter suite
is being repeated on the integrated source.

The deterministic operational-event test correction passed all 16 tests in its
suite, with scoped analysis clean. Runtime was unchanged. The separate A05
actual-reader harness passed 23 tests with no skips, and governed-identity host
contracts passed 13. The bridge-only test is intentionally skipped in an ordinary
Flutter run and is exercised by that harness.

Final backend resource parity review aligned quality V2 memory with V1 at
256 MiB. All four wrappers now have exact source-option and SDK-metadata parity
checks. The final host pipeline passed 1,375 Jest and 75 Node tests; 14 actual
V2 emulator cases passed on the new index hash. The prior 392-case emulator
campaign retains its original hash; the only intervening runtime change was
that memory option. R04 records the exact hashes and evidence boundary.
