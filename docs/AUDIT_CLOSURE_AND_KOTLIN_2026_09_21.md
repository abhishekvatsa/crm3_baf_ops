# Audit follow-through and Kotlin scanning

Working record for the owner's instruction to address the remaining findings in
our audit and the Kotlin scanning gap. Baseline main is
`e09b153da9bcaf032b3b3bf82d693317ee605f19` (PR 373). PR 374 is the current draft.
This record is not deployment or distribution approval.

## Security scanning

Default CodeQL scans Actions, JavaScript/TypeScript and Python. Its automatic
Kotlin expansion failed because the Android build lacked Flutter preparation.
The new advanced workflow prepares the actual toolchain, traces a fresh isolated
debug build, and queries method bodies in the real application database.

Preview run 35553439362 at branch head `d87c9078` successfully ran all four
language jobs. Its Kotlin proof identifies the synthetic PR merge commit
`2bf599be4e714f3b049c5bd1684338f2898dabbb`, CodeQL 2.27.0 and the three required
MainActivity method bodies. **This does not establish complete extraction:**
the SARIF also contains an extraction-error diagnostic in MainActivity. The
`(5)` in that message is a severity value, not an error count. A stronger gate
now retains the detailed diagnostics and refuses a coverage proof if any app
extraction errors remain. Detailed run 35555031998 identifies a CodeQL 2.27.0 extractor error for
`MainActivity::class.java` in `showCriticalAlarmNotification`. The source now
uses `Intent().setComponent(componentName)`, keeping the explicit current
Activity target, flags, immutable PendingIntent and alarm identity. The proof
also requires this fourth method. Hosted run [35555752900](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/35555752900) at branch head `4b7dc8eb` now passes all four languages. Its proof binds synthetic PR merge `ad3df4530a9a7495aae6392ce13c8a35f46e08f1`, all four method bodies and zero app extraction errors; the detailed diagnostic CSV contains only its header. Actual main publication remains a separate requirement below.
The [Android Activity API](https://developer.android.com/reference/android/app/Activity#getComponentName())
and [explicit Intent API](https://developer.android.com/reference/android/content/Intent#setComponent(android.content.ComponentName))
define this target selection.

The established default scans remain enabled. Temporary preview mode prevents
conflicting advanced uploads. Migration requires a reviewed green main run,
removal of preview mode, and accepted analyses for all four languages at the
exact merged SHA. The rollback procedure is in `tools/security/codeql/README.md`.

The first Kotlin-only release run also found the canonical guard's old total of
27 action references. The new workflow adds seven immutable action references;
the independent Node guard and canonical guard now both enforce 34.

## Source work in this follow-through

| Finding | Current disposition |
|---|---|
| UV installation-date correction | Implemented locally as a separate governed correction with retained original installation, reviewed chronology, immutable correction history, exact replay, native original-account recovery and visible review controls. Local verification passed; final-head bot review/CI pending. |
| Interrupted knowledge import | Durable original intent and per-row outcomes implemented locally; restart recovery verifies exact atomic revision evidence before deciding whether to send. Local integration passed; final-head bot review/CI pending. This is not a claim that a multi-row import is atomic. |
| Report source isolation | Selected PDF sections now determine source subscriptions; omitted sources are labelled not included and cannot satisfy an export requiring them. An unrelated failed source no longer blocks a focused export. The integrated dashboard still requires its full source set. |
| Report snapshot stability | A prepared report retains its PDF bytes for preview/share/print instead of regenerating under the same report ID when streams change. Confirmed authority loss removes access to that preview. This is not a certified common database cutoff. |
| Operational closed-interval correction | Implemented locally; original intervals and links remain retained, while a separately reviewed amendment supplies effective chronology. Stable occurrence ordinals preserve existing issue membership. Local verification passed; final-head bot review/CI pending. |

Focused report tests: 73 passed, including new checks for excluded-source
non-subscription, required-source failure, authority loss and refusal to present
a narrow snapshot as a complete report. A replacement/addition during preparation now updates Burner/UV membership from the same registry emission used by the report; labels and bytes then freeze together. UV evidence is recorded by the focused
host, native-journal and Firestore emulator regressions; combined final-source
results must be recorded before merge. The full backend host run passes 78 suites / 2,340 tests. The governed emulator run separately passes 341 Rules tests and 21 backend suites / 239 tests. The first full Flutter run passed 3,256 tests, with six integration-guard failures and one existing skip; five stale guard/helper-path failures are repaired and their combined rerun passes 128 tests with the same existing skip. The final report-screen/query-plan/document rerun passes 49 tests and the full analyzer reports no issues. The no-loss regression spine passes 110 tests and the canonical audit passes 150/150. These are local source/runtime results, not deployment evidence.

Independent report review found a further preview-lifetime defect: transient authority loading disposed the preview state, allowing its PDF bytes to regenerate under the original report ID. The byte future now belongs to the retained preparation state and the preview receives it. Both loading/error regressions failed before the repair and now preserve the identical future and generated bytes. A confirmed account switch permanently closes that preview. All 84 focused report, preview, authority and design-system tests pass after this repair; scoped analysis is clean.

## Audit-tool hardening

Independent review also identified three false-pass routes in verification tooling: undeclared dynamic timestamp calls, wrapper tear-offs outside caller coverage, and ordinary stored maps mistaken for native timestamp transport envelopes. All three now have negative regressions: 15 inventory tests and 29 complete integrity-sweep tests pass. The timestamp-map failure was reproduced through the real bridge before its repair. The inventory tests are included in release CI. Production data is not read or changed by these local checks. The inventory and decoder reconciliation remain separate from parent/chain integrity and from deployment qualification.

## Reconciled historical entries

The old domain ledger records the state at its own commit. Subsequent repairs
already implemented Burner corrections, historical inspection amendments,
Morning Review correction/cancellation, registered component protection,
completion of non-blocking agency requests after physical closure, original-
account critical-alarm storage, qualified alarm feeds, notification readiness
checks and physical Inner Cover assurance invalidation. Those old observations
are retained as history, not reopened without a current failing path.

## Items that this source checkpoint does not yet close

The remaining programmes include certified catalogue editions, broader
supervised and off-device recovery, cadence historical/legacy adjudication,
newer maintenance-draft comparison and dependent target correction (a concrete unreachable successor-recovery action has been confirmed for the next repair), report
source-version/cutoff and scale qualification, and per-recipient notification
adjudication. Each requires its own concrete implementation or evidence; a
passing PR is not their closure. Existing owner decisions apply; unresolved
business semantics must not be invented as part of a code repair.

Reader-first activation, backend/Rules/capability readback, R04 authority
revalidation, populated-device upgrade/restoration and representative business
flows remain separate release requirements. Historical production receipts and
approvals are unchanged. No live business-data repair, backend activation,
signing change or app distribution has occurred in this follow-through.


## First combined CI follow-up

The Flutter job at `d22dca4c` passed canonical verification but stopped in the
new timestamp-transport regression: it imported the root web Firebase package,
which that isolated job does not install. The regression now loads Timestamp
from the installed Functions Admin SDK, matching the sweep's actual adapter.
The same real-bridge precision and forged-map cases pass with that dependency.
No test is skipped and no acceptance condition is relaxed. Final-head CI remains
required; the earlier failed job is not reported as a green release gate.


## Bot P1 and related reader repair

Review 5262839192 at `d22dca4c` correctly identified the UV correction validator's
incorrect equality between completion and recording time. The actual lifecycle
producer allows a later recording; only a recording before completion is invalid.
The correction now enforces that ordering for the complete retained history.
Four producer-based target/sibling positives failed before the repair, including
native Firestore conversion. Backward chronology still fails without writes.

A related-source sweep found the same obsolete equality in both Burner and UV
Flutter readers. Both now admit truthful late recording while retaining all
other identity and chronology checks. A committed fixture is compared to the
actual producers in the backend suite and read by the real Dart history/current
factories, including native timestamp representations. Eight positive cases
failed before the reader repair. The final 24-case consumer regression and 24
existing lifecycle/readback tests pass; native dates are compared by instant.
The Burner current projection's pre-existing separate correction chronology is
preserved, and original events still enforce the physical closure tolerance.

Final follow-up local results: Functions build and inventories plus all 79 host
suites / 2,347 tests pass; both workflow Firestore emulator suites / 39 tests
pass, including the two new late-recording transactions; scoped Flutter analysis
is clean; canonical audit remains 150/150. Existing full governed-emulator/Rules
results are earlier evidence; final-head CI must execute the complete gate again.
This adds a further reader-first qualification requirement for late-recorded
lifecycle evidence. It does not authorize live producer activation.

Combined preview run 35557398190 at `d22dca4c` passed all four security languages;
its proof binds synthetic merge `b96d16afe5debef90a3d7d06d046723d30aee7af`, four
required app methods and zero app extraction errors. Release run 35557398231
passed backend, Rules/transactions and both Android jobs, but its Flutter job
failed on the dependency issue above. Neither run certifies the follow-up head.

## PR 374 merged checkpoint

PR 374 merged normally as `0058002ccf52010584fa398326773912b1622ad6` after
release run 35558595269 passed all five jobs and security run 35558595251 passed
all four languages at reviewed head `38a6eeed`. The bot's fresh review completed
at 03:53 UTC with no new findings and its earlier P1 thread was resolved with
regression evidence. The Kotlin proof binds the tested synthetic PR merge
`313b477f5ce9475bd2f0563f8f5ba35fdb76bf3a`, four required method bodies and zero
app extraction errors. Exact-main verification and active analysis publication
remain separate checks; this paragraph does not claim their completion.

The subsequent maintenance successor repair is described in
`MAINTENANCE_SUCCESSOR_RECOVERY_2026_09_21.md`. It closes the concrete native review
dead end without closing the broader recovery or release programmes listed above.

## Active Kotlin scanning verified

On 21 September 2026, main `0058002ccf52010584fa398326773912b1622ad6`
passed release run 35559419957 (all five jobs) and security preview run
35559419931 (all four jobs). Default setup was then disabled and read back as
`not-configured`; temporary `CRM3_CODEQL_PREVIEW` was removed.

Active publication run [35560291657](https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/35560291657)
passed all four jobs. Readback confirms new accepted analyses for the exact main
commit and `.github/workflows/codeql.yml:analyze`:

| Category | Accepted analysis |
| --- | --- |
| Actions | 1808735379 |
| JavaScript/TypeScript | 1808739672 |
| Python | 1808739874 |
| Java/Kotlin | 1808765043 |

All four report empty error/warning fields and zero results. The separate open
alert readback returned zero. The published Kotlin proof binds this actual main
SHA, CodeQL 2.27.0, the four required app method bodies and zero app extraction
errors. Earlier default/failed analyses remain historical evidence. This closes
the scanner migration at that commit; future source changes require their own
normal analysis and release checks.


## Current disposition after the maintenance review repair

The earlier "next repair" entry for the newer maintenance draft is superseded by
`MAINTENANCE_SUCCESSOR_RECOVERY_2026_09_21.md`, including its complete native
comparison, durable correction recovery, retained unsupported differences and
known dependent-target UI restrictions. This is a native review repair, not a
universal recovery or dependent-retargeting service.

For precision, whole-event withdrawal of an erroneous or duplicate operational
event already exists (`OperationalEventService.withdraw`) and preserves the raw
history. The new amendment corrects a closed occurrence's end time. Corrected
starts and individual-occurrence withdrawal/adjudication within a retained
multi-occurrence event are not claimed by that whole-event withdrawal route.

An independent current-source reconciliation found no further concrete defect
within this repair batch. Certified catalogue editions, supervised unavailable-
account/off-device restoration, cadence historical amendment/legacy adjudication,
report common-cutoff and scale/privacy qualification, and per-recipient ordinary
notification adjudication remain separate open work, not silently closed or all
owner-blocked. Deployment/readback and physical-device qualification also remain
release requirements. The accepted Kotlin migration evidence above is complete;
new source still requires its normal exact-commit checks.


## Decoder handler inventory coverage

Classifying the maintenance dialog's new strict read exposed a real audit-tool
coverage gap: the catch inventory omitted bare typed handlers and later handlers
in a chain. It now walks each structurally identified try/handler chain, including
typed handlers without a catch variable, and ignores decoder-like strings and
comments. Existing first-handler fingerprints are preserved; changes in earlier
handlers remain bound into later-handler fingerprints.

Nine focused regressions include mixed chains, nesting, generic qualified types,
nondecoder/finally exclusions and prior fingerprint stability. Five of the first
seven failed before the repair; all nine final cases pass afterwards. The combined
handler and dynamic-timestamp inventory regression run passes 24 tests. The existing CI inventory step runs
these alongside the dynamic-timestamp regressions. Current discovery adds 49
sites to the previously tracked 59. Each added site requires an explicit reviewed
policy and regression reference; a larger count alone proves neither a repaired
business defect nor complete semantic coverage by a Dart parser.


## Raw legacy metadata preservation

Reviewing the newly discovered handlers found two adjacent evidence-loss paths.
Frequent-issue and furnace-stuck-up metadata mergers already retained malformed
JSON text, but valid non-object JSON fell through to an empty object and lost the
original text. Both now preserve the exact original string as `legacyMetadata`,
matching the Burner merger's established behaviour. Existing objects and absent
metadata keep their prior behaviour; a later merge retains the same original
bytes. Fourteen failures were reproduced before repair. The new preservation
suite and existing model/creation compatibility tests pass 53 cases, with clean
scoped analysis. No saved production records are rewritten by this source repair.


## Unreadable local closure evidence

The expanded handler review found a concrete suppression path. A synchronized
issue closed without technical resolution could have unreadable or absent local
closure metadata, decode as no closure, and disappear from plant-condition
attention. Its previously stored derived index could remain false even after a
reader-only fix.

The maintenance model now requires closure status and disposition evidence to be
consistent. A typed read result exposes unreadable evidence to presentation. The
persisted condition flag conservatively admits a review candidate; it does not
assert a physical condition. The native query independently admits closure-status
rows and resolved, nondeleted metadata candidates, then excludes only verified
noncontributors. This catches old false-index records and contradictory retained
closure evidence. Strict report/furnace readers refuse unqualified evidence, and
the qualified overview records the uncertainty rather than claiming a clear state.

Ten failures were reproduced before repair. The integration run passes 103 cases;
151 native successor, complete-boundary and populated-upgrade compatibility cases
also pass, with clean scoped analysis. Raw Isar export/import verifies old false
index values, valid retained concerns, damaged closure evidence, contradictory
status, ended relevance and tombstones. The wider query is a native database
filter followed by candidate qualification, not the prior index-only feed. A local
10,000-row representative historical-metadata run completed in 58 ms and returned
no false active issues. This host result is not physical-device scale proof.
Presentation qualification and final combined verification are recorded in the
subsequent final-head evidence; these local counts do not replace hosted review.


## Final local source verification for the follow-up

The final combined native service/stream/UI run passes 170 tests; the final
presentation rerun passes 44, scoped analysis is clean, and independent bounded
review found no further blocker. Focused governance contracts pass 19/19, both
inventory regression files pass 24/24, and the canonical audit passes 150/150.
Earlier focused counts above overlap and are not an additive test total.

A03 retains 628 operations across 2,190 sites and 83 surfaces. A04 retains all 55
schema field policies and the existing extension/generation rules, with 123
inherited decoder surfaces. A05 now tracks 123 decoder surfaces, 108 discovered
catch sites, 64 strict-reader consumer files, 58 raw-JSON consumer files and 552
risk sites. All 59 prior catch policies remain unchanged; the 49 added policies
state their actual evidence and verification limits. No unclassified or stale
catch policy remains. A02's two reviewed file-size bounds reflect only the native
candidate query and qualified closed-ticket UI additions; ownership and other
bounds remain unchanged. These results establish a source checkpoint, subject to
fresh bot review and final-head hosted checks before merge.
