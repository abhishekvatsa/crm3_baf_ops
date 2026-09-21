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
