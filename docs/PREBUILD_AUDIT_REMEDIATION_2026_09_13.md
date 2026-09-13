# Pre-build audit response and repair evidence — 13 September 2026

The supplied pre-build audit is materially correct. Candidate `30330c72ca2a92cb0a485e0ced7e3c21f0479292` must not be described as ready for an operational successor unchanged. Its green CI established the scenarios exercised by that run; it did not establish the repeated-history and competing-writer invariants identified here. The earlier assessment that no implementation blocker remained was too broad.

This repair branch starts at that exact candidate. The uploaded documents are evidence, not deployment instructions. The user's standing audit, repair and build instruction authorizes the implementation work.

## Supplied evidence custody

The uploaded ZIP SHA-256 is `2791F4AF58D6B794BCEF72D8C1F2D294844D165CACA5D41C57A46D0393CCF0F6`. All 115 manifest-listed files verified. All 63 product TypeScript modules in its runtime dependency closure also match the candidate's Git blobs. This is a source-bound dependency closure, not a claim that the ZIP contains the entire current repository.

The original audit used actual handlers with synthetic adapters. Its two expected-red inspection regressions were independently reproduced against the local candidate. Further local native and widget reproductions establish the module version inflation and second-precision time-input failures. Red logs are retained as failures; passing characterization assertions are not counted as repaired behavior.

## Repairs and business consequences

| Finding | Implemented behavior | Verification boundary |
| --- | --- | --- |
| PBA-01: backdated correction hides a later adverse reading | Immutable correction edges replace only the named observation. Current evidence is selected from surviving physical observations, with deterministic identity ordering for ties. The first adverse reading and recurrence derive from the effective episode, while its original recording identity remains stable. | Actual handler tests and real Firestore transactions, including correction chains, timestamp values, malformed histories and positive resolution controls. |
| PBA-02: historical reopen creates competing active findings | Every activation writer checks the population and shares a campaign revision fence. An older episode cannot reopen over a newer episode, including a newer terminal episode; its history remains separate and the refusal identifies the newer finding. | Simultaneous reopen, recurrence/reopen and closure/reopen tests on Firestore, plus normal single-episode reopen and immutable receipt replay controls. |
| PBA-03: local module reopen invents a revision or overwrites intervening work | The accepted original request and receipt are retained before readback. The original immutable audit and current server module are checked. Native adoption uses a transaction and complete local preimage; a matching mirror is a no-op, dirty or contradictory state is preserved, and later valid server state is displayed as it exists. A saved reopen remains discoverable after restart. | Native Isar interleavings, real close/reopen of the database, actual handler and FirebaseWorkflowStore producer fixtures consumed by Dart, screen tests and Rules emulator access tests. |
| PBA-04: a matching delayed acceptance is always treated as a review conflict | A domain-validated acceptance matching every retained `reviewedExisting` decision can proceed to normal adoption. Both the review and acceptance are retained. Proven later native submissions keep their state and identity while the earlier confirmed work is adopted first. Cancellation, contradictions, legacy ambiguity and unproven ordering remain held. | Native repository and actual campaign-controller sequences, cross-domain summary tests and the frozen candidate's reader exercised against the new retained capsule. |
| PBA-05: minute-only input cannot represent short work intervals | The user can explicitly confirm seconds and fractions within exact work bounds. The picker preserves an existing precise timestamp when its minute is unchanged. Cancellation keeps the prior value; no guessed time is silently saved. | The candidate widget fails the short-interval regression; the repaired widget covers second and subsecond intervals, invalid input, cancellation and existing timestamp preservation. |

Correcting away all adverse evidence requires an explicit accepted-condition or invalidation decision. It cannot be represented as a verified repair. A linked maintenance issue remains visible but does not bypass this review requirement or permit campaign closure. The app and both inspection report paths show the effective abnormal count and the review explanation. Schema-1 readers still receive a positive historical `recurrenceCount`; the separate effective count carries zero without breaking those readers.

The reopen route also handles a narrowly proven newer-workflow-version refusal: the server checks an existing immutable receipt before its monotonic version fence. Only that exact structured refusal can release the local request as rejected, retaining its original record. Generic aborted, malformed responses and transport uncertainty do not release it. The user must synchronize, review the current module and deliberately start a new request.

The original currently approved module supervisor may read their own immutable reopen audit by document ID. The Rules change grants no supervisor collection listing or audit writes, and reserves the server reopen namespace against client creation. Existing administrator read access remains separately governed.

The nested date, time and seconds routes also retain the original account and permission boundary. Account changes hide their contents, and a late picker result cannot change the retained draft. All three production action-sheet entry points pass their existing exact permission into this check.

## Why the previous checks missed these issues

The earlier tests covered individual accepted corrections, replay and one local adoption writer. They did not challenge a correction moving behind another surviving reading, a historical reopen after a recurrence, or a separate module-reopen writer after a mirror or local edit. One earlier positive test also treated correction of the sole adverse reading as if it were a new follow-up proving repair. That expectation has been replaced with separate correction/adjudication and actual later-reading controls.

This pass checks complete sequences and sibling writers. It also found and closed the older-terminal-episode mixing path and the issue-link-to-campaign-closure bypass while reviewing the initial fixes. None of these findings justifies claiming that every possible defect in the codebase has now been excluded.

The final integration review also caught an insufficient fixture in the first reopen repair: the real Firestore adapter stores the audit time as a native timestamp and serializes embedded module times as timestamp maps. A memory adapter's ISO strings did not establish compatibility. The real adapter now produces a frozen fixture with nonzero microseconds, independently compared in the emulator and consumed by Dart and Rules tests. The narrow reader validates exact timestamp shapes and supported precision without rewriting the original audit JSON; unsupported sub-microsecond evidence remains held with its receipt retained.

## Release boundary

Local repairs and test results are source evidence. Final source review, exact-source CI, backend and Rules deployment/readback, governed signing, and the exact APK's in-place phone upgrade and representative business-flow checks remain separate requirements.

No new production deployment, build-number reservation, signed successor, phone installation or distribution has been performed in this repair pass. Build 27 is already consumed; the planned successor remains Build 28, with the current schema-12 compatibility floor. No database clear, downgrade, asset re-registration or recovery-journal deletion is part of these repairs.

Automatic approval review previously rejected the production Functions command before execution because it includes persistent `allUsers` invoker grants for four new V2 services. The requested explicit scope confirmation remains pending; the uploaded audit does not supply that confirmation. The earlier unexecuted deployment decision for `30330c72` cannot authorize or certify this changed source. Any later deployment needs fresh source-bound checks and an updated concrete decision.

The Samsung SM-G990E was rechecked during this pass: ADB reported it connected, with the secure keyguard not showing at that check. No unlock bypass was attempted. Physical-device evidence still requires the exact governed successor and representative business-flow checks. Native host tests and Android emulator checks are not physical-device proof.

## Local evidence retention

Source-bound raw logs and reproduction inputs are retained under `build/review-20260913/` in the working repository. The original upload verification is `prebuild-input-verification.json`. The failed candidate demonstrations include `pba-inspection-before.txt`, `pba03-before-native.txt`, `pba05-before-widget.txt` and `pba-inspection-review-hold-before.txt`. These local files are not public deployment custody or a release download.

## Validation at submission for source review

| Check | Observed result | Local log |
| --- | --- | --- |
| Whole-project Flutter analysis | PASS, no issues; the subsequent five test-only edits also pass scoped analysis | `prebuild-full-analyze-final.txt`, `prebuild-contract-integration-analyze.txt` |
| Canonical post-code-generation audit | 150 PASS, zero failures after refreshing reviewed inventory pins | `prebuild-canonical-integrated-final.txt` |
| Complete native Flutter run | 2,728 PASS, one intentional bridge-harness skip, five stale source-contract failures retained | `prebuild-full-flutter-final.txt` |
| All five affected source-contract suites after repair | 40 PASS, zero failures; includes an additional extracted-reopen lifecycle assertion | `prebuild-contract-integration-final.txt` |
| Functions host Jest suites | 64 suites / 1,546 PASS; emulator cases are intentionally separate | `pba-functions-full-host-complete.txt` |
| Governed Functions Firestore suites | 16 suites / 162 PASS | `pba-functions-governed-final.txt` |
| Added actual Firestore reopen producer, generation disabled | One suite / one PASS; fixture comparison enforced in governed CI | `pba03-firestore-producer-fixture-check.txt` |
| Complete Rules suite on final timestamp rule | Five suites / 293 PASS | `pba03-all-rules-final.txt` |
| Final actual-Firestore/native reopen and UI boundary | 53 PASS | `pba03-native-firestore-boundary.txt` |
| Matching reviewed acceptance and older-reader/native recovery | 94 PASS | `pba04-native-second.txt` |
| Second-precision input and nested account guards | 19 PASS | `pba05-nested-authority-final.txt` |
| Final inspection model, report and screen tests | 45 PASS | `pba-inspection-client-final.txt` |
| Release evidence/custody contracts | 233 PASS | `prebuild-release-custody-final.txt` |
| Production policy and evidence taxonomy | PASS, with current deployment/signing/device boundaries retained | `prebuild-production-policy-final.txt`, `prebuild-evidence-taxonomy-final.txt` |

The complete native run is not relabelled green: its five failures concerned the reviewed decoder count, current manifest pins, the relocated reopen method, and two assertions of the old audit-create predicate. The targeted repair preserves historical evidence and requires both reserved audit namespaces plus the existing create validator. The lifecycle contract now checks the extracted mounted/actor guard and every confirmed UI adoption. No application behavior changed after that complete run. The bridge test is intentionally skipped without its dedicated bridge endpoint and token; that skip is not production reconciliation evidence.

The focused cases overlap the full suites and must not be added together as independent coverage. Independent source reviews challenged inspection closure, recovery ownership, timestamp transport, local adoption and the governance delta, finding no additional blocker within those reviewed boundaries. These are pre-PR local results. The protected branch's full CI, Android package/startup checks and separate exact-main run remain required; their eventual GitHub receipts must be consulted separately.

Submission follow-up: PR #366's first CI run stopped at one obsolete canonical assertion of the relocated lifecycle test's single-line formatting (149 PASS / one FAIL). The assertion now checks the retained exact reopen-call pattern and the new every-adoption guard assertions. The complete local canonical rerun passes 150/150 (`prebuild-canonical-pr366-followup.txt`). No application behavior or authority was changed by that checker repair; a fresh complete CI run is required.

## Independent PR review follow-up

The complete [PR verification run 34742404443](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/34742404443) passed all five jobs for `2420b591929d85d2b75adc60bde7778dedb124aa`. Its Flutter job recorded 2,734 tests passed with one intentional bridge-harness skip, followed by 110 no-loss spine tests passed. The same run passed 293 Rules tests, 163 Functions emulator tests in 17 suites, the Android application interaction scenario and package/cold-start checks. CodeQL also passed. Those results establish that candidate's exercised checks, not the absence of untested lifecycle defects.

The [automated PR review](https://github.com/abhishekvatsa/crm3_baf_ops/pull/366#discussion_r3998918813) then identified another reachable inspection correction failure. When a correction makes older adverse evidence current again after its finding became terminal, the handler can try to create the original finding ID again. Both the actual handler and actual Firestore adapter reproduce the collision; the merge was paused despite green CI. The retained red logs are `inspection-terminal-correction-host-before.txt` and `inspection-terminal-correction-firestore-before-actual.txt`. An earlier filtered emulator attempt matched no tests and is not counted as reproduction evidence.

The repair reuses the original episode and retains its verification/adjudication history when the corrected reading was evidence used to close that episode. A separate `reopen-after-observation-correction` event records the old and new status/version and the replaced/effective observation IDs. Correcting a later reading that was never part of that decision preserves the earlier adjudication and does not invent a duplicate episode. Earlier or competing episode evidence is refused with an explicit review reason. The existing rule that only the current certified reading can be corrected remains in force; zero remaining adverse evidence still requires explicit adjudication rather than technical resolution.

The Functions build and emitted/callable/notification inventories passed. The complete focused host set passed 122 tests across the inspection history, campaign and physical-context suites (`inspection-terminal-correction-host-final.txt`). The complete inspection Firestore file passed 15 tests (`inspection-terminal-correction-firestore-reviewed-final.txt`), including all three terminal statuses, preservation of existing immutable decision events, stored Timestamp evidence, three correction/new-episode races and accepted-receipt replay without duplicate writes. A repeated emulator race produced its exact native closed-transaction error after lock contention; the diagnostic is retained in `inspection-terminal-correction-emulator-contention.txt`. The race test permits only that exact emulator error or the domain version refusal, and unconditionally retries the unchanged losing command to prove the stable version refusal and zero writes. These results do not reuse the earlier green CI as proof for the changed source; fresh complete CI remains required before merge.
