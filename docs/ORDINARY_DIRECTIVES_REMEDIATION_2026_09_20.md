# Function 13 — Ordinary directives remediation, 20 September 2026

## Evidence and scope

Reviewed `CRM3_Ordinary_Directives_Final_Review.pdf` (23 pages), the preliminary HTML, and the supplied evidence ZIP against the current working tree based on `d038797f`. The supplied 51 source-transcribed models were treated as audit evidence, not as runtime acceptance or proof of production corruption. Uploaded scripts were not executed. Existing unrelated domain repairs were preserved.

Owner decision: material amendment or transfer of an active instruction requires fresh acknowledgement; previous wording and acknowledgement remain historical evidence. Completed instructions remain historical records. No physical-work completion, individual acknowledgement from every role member, or new notification promise is inferred.

## Repairs and containment

| Finding | Current disposition |
| --- | --- |
| OD-01 collapsed offline lifecycle | New ordinary creation, acknowledgement, closure, amendment and deletion retain an immutable original-account command in the existing native durable journal. The existing `mutateAssetHierarchyV2` callable dispatches `APPLY_ORDINARY_DIRECTIVE`; capability `ordinaryDirective.v1` is checked before sending. A successor is blocked until its predecessor is confirmed. This is deliberate bounded offline containment, not a claim of arbitrary multi-action offline queueing. Browser work retains its original envelope and accepted receipt before readback. |
| OD-02 changed wording / transferred acknowledgement | Admin amendment atomically resets active status to open and clears current acknowledgement. Full before/after audit retains the old instruction, recipient and acknowledgement. The complete reviewed before-image and revision are compared by the transaction. Closed/deleted records cannot be rewritten. |
| OD-03 stale Admin mutation | Local compare-and-save and server transaction checks prevent rebasing a stale editor over another action. Deletion requires the reviewed revision and actor. Edit and ordinary close dialogs stay open with entered text when saving fails, with account guards. |
| OD-04 contradictory closure / unreadable admission | Canonical handler validates required shape, legal role/asset values, lifecycle tuples, chronology including microseconds, real calendar dates, and action field whitelists. Closure derives acknowledgement status from its frozen reviewed basis; competing acknowledgement aborts it. Legacy Rules now require essential readable lifecycle fields and dates and route legitimate Admin acknowledgement/closure correctly. New command-managed rows reject all direct client updates. |
| OD-05 divergent clean local state | An accepted receipt is retained before authoritative readback. Only the matching optimistic row or verified clean predecessor can be replaced; a newer draft is preserved. Same-revision differences require reconciliation, except the narrowly recognized old redundant closed/isActive flag defect. |
| OD-06 failure isolation / incomplete lists | Pull batches carry rejected IDs and raw count. Valid later pages are applied while the failed domain cursor remains held. Known native pull incompleteness persists per account and is surfaced in lists/counts/reports; Web retains snapshot completeness/cache qualification. Legacy direct pushes are isolated by row; older ordinary dirty evidence without an original immutable command is retained for reviewed reconciliation. No actor or missing intermediate action is reconstructed. |
| OD-07 audit and recovery | The business row, immutable before/after audit and content-bound acceptance receipt commit in one transaction. Replay verifies retained receipt and audit hashes. Original-account retry survives process loss; administrative review uses the existing permanent execution fence and preserves its evidence. Browser review archives the original envelope and decision before clearing the held retry. Earlier recovery activation sets remain compatible for their already-supported domains. |

Automatic Burner/UV directives keep their separate acknowledgement/compliance path. Ordinary Admin editing/deletion of those records now fails before changing local evidence. Audit snapshots include the two linked-record IDs. The journal is scanned once per sync to identify owned rows rather than once per pending directive.

## Verification

- Backend TypeScript build, emitted-output custody, callable inventory and notification inventory passed. No callable or runtime identity was added.
- Full backend Jest run: 77 suites, 2,179 tests passed; emulator-dependent suites skipped in that run. See the separate emulator result below.
- Scoped Flutter: 142 tests passed, including real Isar close/reopen, lost reply, wrong account, retained acceptance, protected later draft, fresh acknowledgement, reviewed cancellation, browser review, actual editor retention, actual-handler output decoded by Dart, partial-page cursor retention, reporting and the existing Burner directive regressions.
- Scoped analyzer: no issues on the verified repair surfaces.
- Firestore Rules: 226/227 passed on the full run; the only failure was an accidentally changed negative timestamp fixture. After restoring that negative control, all 20 directive Rules tests passed (207 unrelated tests excluded on the focused rerun). This is not represented as a second full Rules run.
- Actual Firestore emulator: 30 tests passed across ordinary directive transaction boundaries and existing V1/V2 saved-submission recovery. Competing acknowledgements accept exactly once. Injected audit failure leaves no business row or acceptance receipt.
- Diff whitespace validation passed; repository line-ending warnings remain informational.

The full backend run exposed a stale source-wiring assertion for the concurrent user-authority replay work. It was updated to require both current authority and the separately verified original-receipt replay branch. A report test likewise still expected missing workflow evidence to mean Available; its expectations now assert unverified availability and the resulting management signal. Neither production rule was weakened to satisfy those tests.

## Still required before release

1. Independently review the combined dirty working tree, commit a reviewed candidate and run its exact release gates. This pass neither committed nor pushed.
2. Deploy the matching callable implementation and reviewed Rules together, verify capability/readback, and explicitly activate `ordinaryDirective` in saved-submission recovery only after the guarded fleet and rollback have been verified. Source changes do not activate production controls.
3. Qualify supported installed-client combinations: old clients can read the unchanged business shape, but cannot directly modify new command-managed rows. They need the new client for those actions. Do not claim seamless mixed-version write compatibility.
4. Inventory and review older unbound/collapsed dirty directives, malformed server rows and unrelated content-divergence holds. Their original history cannot safely be invented. This pass made no business-data migration.
5. Run the populated physical-device upgrade and real browser campaign, including offline creation, confirmation before acknowledgement/closure, account change, interruption, recovery and restore/reconnect. Local tests are not device qualification.

Unsubmitted text is retained in the open failed editor; process-loss durability begins once the command has been saved. No claim is made that every keystroke is durably autosaved. No APK/AAB, deployment, Play change, IAM change or distribution was performed.
