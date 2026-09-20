# Morning Review preliminary audit remediation — 20 September 2026

Source baseline: `d038797f9a2d3bd0126d311416acec4148506a67`, with substantial existing uncommitted inspection and other domain work preserved. This is a local working-tree report, not a release or deployment receipt.

Evidence reviewed: `Function_07_Morning_Review_Deep_Audit.html` and its supplied text. Findings were checked against the implementation. The auditor's characterization probes were not treated as release tests.

## Business decision

The owner explicitly confirmed that Admin/SI may cancel, reassign or reopen Morning Review actions with a mandatory reason and preserved history. Assigned-role members retain completion authority. Implemented as a version-checked command with transactional before/after correction evidence. Cancellation is a distinct state, not a claimed completion. Reopening preserves the previous completion in history and leaves frozen minutes unchanged.

## Implemented repairs

| Finding | Local implementation |
| --- | --- |
| F07-01 | Modern requests use a permanent transactional refusal fence. A genuine business refusal can release the local queue only when its proof matches the original actor and entire request. Unproved transport/conflict errors remain uncertain. Original prose stays saved and selectable; finalization can prefill the refused summary for review. |
| F07-02 | Receipt lookup supplies exact-request acceptance evidence. Server-normalized asset labels no longer have to equal an outdated draft. Historical receipts can prove acceptance through their stored request fingerprint without inventing old registry labels. Missing or mismatched evidence remains unresolved. |
| F07-03 | Entries and actions share subject resolution: registered identities are checked against the register, and meeting-provided identities are accepted consistently. Provisional scope is excluded from the agenda's governed-asset label. |
| F07-04 | Operation authority is checked again inside the acceptance transaction. A withdrawn SI role cannot finalize using former facilitator status. Historical acceptance lookup remains distinct from permission to execute new work. |
| F07-05 | Open archive rows lead to their historical workspace. All unfinished meetings are queried separately from the recent archive window. Administrative late closure/takeover adds no invented historical attendance. |
| F07-06 | Standing concerns from later plant days are excluded from an older frozen record. The action register is explicitly progress as of finalization, with origin meeting dates. Live follow-through is labelled separately from the frozen record. |
| F07-07 | Newly created modern meetings retain unfinished session/child records without TTL. Independent membership manifests detect missing minutes, attendance, checks and original actions. Acceptance, refusal and correction evidence are retained separately. Terminal action/concern evidence supports referenced history after display expiry. Old meetings beyond their original retention period without a manifest require evidence reconciliation. |
| F07-08 | Live feeds retain valid rows and expose rejected-row incompleteness. Unavailable/partial counts are qualified. Independent carried-action transitions do not require unrelated current-meeting content to be healthy; optional entry admission isolates classified content failures while transport failures still propagate. |
| F07-09 | Recent completed actions remain queryable. Frozen registers include action identities captured as carried work, with later outcomes and origin dates. They do not manufacture current-day attendance or import arbitrary later actions. |
| F07-10 | The first standing concern can be added without an existing safety agenda. Daily checks require an explicit Complied/Exception selection. Admin/SI can correct an existing check with a reason and current meeting version, preserving before/after evidence. The check capacity matches the standing-concern capacity. |
| F07-11 | Audited action cancellation, role/user reassignment and reopening are implemented. The editor offers role reassignment; the backend also validates approved named assignees. Existing role-member completion remains available. |
| F07-12 | A current Admin may retrieve another Admin's existing recovery decision. Original reviewer attribution, submission identity and evidence binding are retained. |

## Verification

- Full backend build, inventories and Jest: **72 suites / 2,047 tests passed**; environment-dependent suites skipped as declared by the runner.
- Final focused backend rerun after the check-history retention adjustment: **68 tests passed**.
- Actual Firestore emulator transactions: **3 tests passed**, covering competing acceptance/refusal, late execution after refusal, accepted replay precedence and missing retained population.
- Flutter/native/UI/schema suites: **141 tests passed**. Includes process-style native database close/reopen, actual backend-produced normalization/refusal/cancellation fixtures, mismatched-proof rejection, explicit check selection, first-concern creation and Admin-B retrieval of Admin-A decisions.
- Whole-app Flutter analyzer: **no issues** at the recorded run.
- Persisted-data registry and actual Dart-reader bridge: **24 tests passed** with the required local SDK permissions.
- Final repository source audit: **148/150 checks passed**. The two remaining failures concern the concurrent maintenance files and generated-binding drift described below; the Morning Review inventory checks passed.
- Diff whitespace validation passed; existing line-ending notices remain informational.

Local logs are under `tmp/morning-*`. The durable fixture generator runs the actual compiled handler against the repository's local transaction harness. It is separate from the real Firestore emulator concurrency tests. Neither is a physical-device or production acceptance claim.

Current inventories: A-03 **601 operations / 2,097 sites / 72 surfaces**; A-04 **55 fields / 106 inherited decoder surfaces**; A-05 **106 surfaces / 482 risk candidates**, with **38** classified direct timestamp candidates. Existing historical custody receipts were not rewritten.

## Remaining boundaries

1. **Coordinate app and backend rollout.** New clients require `morningReviewRecoveryEvidence.v1`. Older strict readers do not understand cancelled actions, explicit null expiry for retained unfinished meetings, or the larger carried-action frozen register. Backend capability support alone does not establish that the installed reader fleet is compatible. These changes are not authorized here as a backend-only production rollout.
2. **Do not guess lost historical data.** A retained valid legacy receipt can prove the original request was accepted. If both the original receipt and required historical records are absent, or an old meeting's original population cannot be established, retain the review requirement rather than manufacture completeness or attendance.
3. **Repository-wide release checks are separate.** At the latest source audit, unrelated active maintenance changes exceeded existing architecture limits in `ticket_screen.dart`, `maintenance_provider.dart` and `maintenance_provider.remote.dart`; `maintenance_model.g.dart` also differs from committed HEAD. This report does not raise those limits or overwrite that concurrent work. Re-run the full gate on the eventual reviewed commit.
4. The deeper Morning Review report is now reconciled in `MORNING_REVIEW_DEEP_REMEDIATION_2026_09_20.md`. Physical-device acceptance remains outstanding. Correction evidence is server-retained; this patch does not add a general-purpose correction-history browsing screen.

No commit, push, production mutation, APK/AAB build, signing or Play distribution was performed in this Morning Review task.
