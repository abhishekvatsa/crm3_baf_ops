# Overnight audit before PR 373 push and merge

Owner authorized independent repository audit, repair, push, bot-review resolution, merge after checks, and post-merge observation on 21 September 2026. Baseline was `d038797f9a2d3bd0126d311416acec4148506a67` on `claude/quality-case-backend-contract`, with the accumulated uncommitted domain repairs preserved.

## Scope and limits

Four parallel audit passes covered backend business handlers and replay contracts, Flutter domain producers/readers and dirty-form behavior, authentication/authority/durable recovery/synchronization, and Firestore Rules plus release/CI custody. The existing domain audit records remain the detailed disposition for earlier work. This was source, host-runtime and emulator review; it does not certify every business scenario, physical-device behavior, production configuration, or distributability.

## Additional confirmed repairs

- **Inner Cover physical boundaries:** historical inspection corrections and Base-vacancy ticket creation now use `removedPhysicalAt` when present, validate it against its recording time, and retain the original single-time interpretation for legacy rows. A delayed removal entry must not extend the physical installation.
- **Burner evidence across administrative closure:** a red-hot concern closed as `stillRelevant` remains in the condition basis. Its original observation time is preserved, so a later survey/replacement still has chronological priority. Canonical class/instance identity survives renumbering and excludes a different retired/replacement furnace using the same number; ambiguous number-only history requires review. Both server and Flutter readers use the same scope. The old-number case is retained-data compatibility: the current registry does not expose an asset renumber command.
- **Reviewed form conflicts:** choosing to retain local entries after a remote conflict now advances the clean baseline to the reviewed server values. A later snapshot cannot erase a new edit merely because it equals an obsolete baseline value.
- **Authority response races:** delayed original acceptance and idempotent replay compare immutable acceptance fields, not lookup-only current-authority observations. The original receipt stays retained. An accepted revision must be exactly the reviewed revision plus one; inconsistent receipts cannot release the saved decision.
- **Reserved audit identities:** an unrelated ordinary audit entry cannot occupy a deterministic knowledge/diary revision ID and obstruct future legitimate saves. Reserved IDs require the matching atomic row transition. Both positive and negative paths execute in the Rules emulator. Diary validation binds the reviewed server revision and allows multiple unsynchronized edits to advance beyond one version; it still refuses an intervening server edit.
- **Maintenance acceptance after Firestore storage:** exact replay hashed the pre-storage audit timestamp differently from its native Firestore Timestamp representation. Normalize only that lossless representation at the original millisecond precision. Emulator tests reject altered actor/content and a persisted one-microsecond timestamp change, then replay after exact restoration; the adapter unit test separately rejects a one-nanosecond change. Existing receipt bytes and digest prefix remain unchanged.
- **Notification sign-out:** the client already transactionally rereads its installation to avoid deleting a refreshed token, but Rules denied that read. The current Rules allow a canonical owner to read an exact own installation while denying listing and all cross-account reads, including Admin. An emulator test exercises the actual token comparison/removal sequence.

## Notification authority revalidation

The current R-04 policy is explicitly re-armed as `SOURCE_IMPLEMENTED_CI_REVALIDATION_REQUIRED`, with `OWNER_POINT_GET_ONLY_NO_LIST`. The PR 134 closure and its exact historical evidence remain unchanged; they certify the earlier source, not this authority change. Current-head Rules tests and release CI must pass. Separate production Rules deployment and readback are required before activation. No deployment, token logging, device-delivery proof or pilot authorization is created by this change.

## Verification guard repairs

Canonical audit guards now compare the reviewed 12-file database-consumer set, follow the extracted ticket-screen part, and recognize actual awaited sign-out calls across formatting while rejecting missing/misordered calls. The R-04 source contract checks the specific nested match block rather than unrelated later Rules. The read-only integrity sweep now classifies the retained quality cursor and ordinary directive receipts with strict server-control validation, including original audit/digest binding. CI now includes all 20 backend emulator suites. Generated-binding drift and immutable historical custody checks remain enforced.

## Bot-review disposition

Both previous PR 373 bot threads were independently checked against committed `d038797f`: current corrected Burner projections override historical rows, and their effective time/revision participates in the snapshot key. Passing targeted regressions were cited in replies and both threads resolved. Fresh review is required after the new source push; the earlier clean review does not certify this larger working tree.

## Verification and release boundary

Local verification before commit:

- Functions build, emitted output/callable/notification inventories and full unit suite: 77 suites, 2,245 passed.
- Full Flutter run: 3,123 passed, one existing skip, three stale source-contract assertions failed. The assertions were aligned to the stronger audit guard/current inventory; all 30 tests in the five affected contract suites then passed. Analyzer: no issues.
- Rules: five suites, 322 passed. Governed identity reconciliation: 13 host tests and three emulator tests passed. All 20 backend emulator suites were exercised: 213 tests, with the failed maintenance/Inner Cover cases repaired and their complete suites rerun successfully; Morning Review recovery also passed under the CI demo project. The concurrency test permits only the exact observed emulator transaction-closed transport signature and still requires the same losing request to return occupied on retry, unchanged winning/losing profiles, and one linkage/audit/receipt.
- Read-only integrity sweep contracts: 28 passed, followed by three focused checks after final strict fingerprint validation.
- Canonical committed-source audit at `655658b0`: 150/150. The reviewed regenerated maintenance binding is committed.
- Production release policy verification passed without artifact-construction authority. High-confidence credential-pattern scan: 2,209 text files, zero matches; this is a bounded pattern scan, not a universal secrecy guarantee.

Final backend emulator reruns and exact-head PR/post-merge checks are recorded in the PR conversation. No production deployment, signing change, artifact distribution or business-data mutation is part of this source merge. Existing open items in the domain ledger and remaining-domain reconciliation remain open, including coordinated reader-first activation, off-device restoration rehearsal, broader report qualification and supervised recovery coverage.

## Clean CI follow-up

The first pushed head passed CodeQL, Functions, Firestore Rules/governed emulator, and Android app-shell integration. The Flutter job exposed a missing prerequisite: the new read-only sweep regression imports the actual compiled directive producer, but its isolated checkout had not built Functions. The job now installs locked Functions dependencies and builds before that suite. The exact preparation and all 28 sweep tests passed locally; the real producer is still exercised. The first run's remaining package job was superseded by the corrected workflow run, not certified as passed.

The next CI run, `35533051239` at `461f704d`, passed Functions, Rules/governed emulator, Android app-shell integration and exact non-production APK cold start. Flutter completed with 3,125 passes, one failure and one existing skip: the report-period boundary case in `operations_report_test.dart`. Its disposition and final-head rerun are recorded below and in the PR conversation; this intermediate run is not a green release gate.

That report test constructed the close instant using device-local midnight, although the report deliberately uses Asia/Kolkata calendar boundaries. On a UTC runner its close time was 05:30 inside the report, so the count of one was correct. The original failure was reproduced with an explicit UTC fixture. The corrected test uses the report's explicit start instant and proves equivalent UTC/IST boundaries; a positive regression confirms that UTC midnight is inside the plant day. All 37 report tests pass. The production overlap calculation is unchanged.

## Fresh bot finding: retired equipment projection

The review of `655658b0` correctly identified a numbered equipment projection that could remain bound to a retired physical unit and block its registered replacement. A separate Admin/SI replacement review now captures both identities, the projection and registry versions, and a mandatory reason. The server checks retirement, a unique active replacement, and intervening work transactionally. Open old, unbound or third-subject work requires review; normal reconcile/deploy cannot silently change the physical subject.

The accepted event preserves the complete old projection and the new projection as JSON-safe history, including native timestamp precision. Each unit's manual conditions remain attached to that unit. The replacement does not inherit deployment or unsupported elapsed age. Acceptance binds the whole immutable event, original reviewer metadata, reviewed version and accepted outcome; identical retries after native Firestore storage or later work remain compatible, while changed requests/evidence are refused. The screen rechecks the original account, authority and reviewed evidence before submission. Existing timeline decoding remains compatible; it retains the archive but does not separately expand its nested details.

Follow-up local verification: Functions build/inventories; all 78 host suites with 2,283 tests passed; full maintenance-workflow emulator suite 27/27, including nine new transaction cases; 35 focused Flutter replacement/identity/authority tests; targeted analyzer clean; canonical audit 150/150; A02–A05 inventories unchanged and passing. Final-head review and CI remain required and are recorded in the PR conversation.
