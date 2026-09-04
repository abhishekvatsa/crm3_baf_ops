# Quality and Abnormality: Independent Pre-Merge Review

Date: 4 September 2026 (IST)

Scope: uncommitted changes on `codex/governed-charge-abnormality-form`, based on `6b7fdcd690c9b13d9f32e52243a28c0531f9f42b`. This is a review of the changed quality/abnormality paths and their immediate sync, issue, hierarchy, authority, and presentation dependencies. It is not certification of the entire application or the installed APK.

## Resolution Update: Three Requested Findings

Later on 4 September 2026, the P1/P2/P2 findings were addressed in source. This section supersedes their original open status below; the earlier review is retained as a historical checkpoint. Release-state reconciliation is separate and remains outstanding. These changes are not deployed and are not present in an APK produced by this pass.

### P1: Governed Creation and Validated Legacy Boundary

- Added `CREATE` to `mutateChargeAbnormality`. It validates nested asset and hierarchy evidence before any write, checks the active canonical abnormality type and approved author, and atomically creates the case, warning, audit, and replay receipt.
- Both the outer callable admission and transaction authority checks admit the five existing approved creation roles. Update/delete authority is not widened. Client-supplied server clocks, linked-workflow imports, malformed hierarchy data, identity collisions, and impossible chronology are rejected.
- The remote repository and mobile sync creation path now use this command. They adopt its committed version and timestamp rather than marking an unchanged local draft synchronized.
- Legacy drafts with local edit counts above one start at canonical server version one. Tests cover old zero-asset and 50-asset drafts through the command.
- Direct Firestore creation is restricted to fully validated identity-only entries and a newly created, exactly matching warning in the same atomic write. Neither document can be paired with a pre-existing counterpart to bypass validation.

**Compatibility boundary:** the direct old-client route supports zero through five identity-only affected assets. Larger cases, up to the existing 50-asset limit, and all hierarchy-rich creation must use the upgraded command path. This is an intentional restriction, not unchanged old-client compatibility. Validating the larger nested shape in the paired Rules path exceeded the emulator's expression budget; the callable performs that validation without relaxing it. Do not deploy the Rules change as an isolated, transparent fix for all installed versions. Stage the backend first, test an upgraded client and pending drafts, and coordinate the Rules/client rollout. Existing documents are not rewritten or deleted by this patch.

### P2: Monitoring Creation Keeps Its Retry Identity

- Added `MonitoringCreationStore`, scoped to Firebase project and signed-in account. The complete payload and request/entity UUIDs are persisted before sending.
- Lost responses, invalid receipts, service restarts, and concurrent attempts retain and reuse the same intent. Changed inputs cannot silently replace an uncertain request with fresh IDs.
- The Quality workspace offers a pending-confirmation dialog with the retained request and a safe retry. Only a verified successful receipt clears the matching intent; a subsequent deliberate creation then receives new IDs.
- Tests simulate a server commit followed by a lost response and a restarted service/store. The retry uses identical IDs and produces one simulated server entity. Additional tests cover invalid input, persistence-load failure, invalid receipts, concurrent attempts, and account/project isolation.

### P2: Original Case Identity Is Required for Convergence

- Shared identity comparison includes the document ID, source charge, original time, original actor UID/name, source ticket, and source execution.
- Sync checks this identity before treating mutable facts as equivalent or submitting an update/deletion. Mismatches retain local evidence and record a conflict.
- Both receipt-adoption repository paths recheck identity inside the local transaction. Incoming update and deletion paths also reject a different original case, preventing a later pull from bypassing the protection.
- Repository-backed tests vary each original identity field, including a newer remote update/deletion, and verify that the local record remains unchanged and unsynced.

### Verification of This Fix Pass

| Check | Result |
| --- | --- |
| Full Functions unit suite | 54 suites, 859 tests passed; 93 emulator tests assessed separately. |
| Full Firestore Rules emulator suite | 3 suites, 217 tests passed. |
| Governed database-emulator suite | 12 suites, 93 tests passed, including concurrent CREATE replay and malformed-creation rollback. |
| Focused Flutter rerun before the additional pull/deletion guard | 67 tests passed, including original-identity adoption and Raise Issue selection/Back behavior. |
| Full Flutter sweep including pull/deletion identity tests | 1,734 passed, 1 skipped, 2 failed: A-02 file length and the existing release-state assertion. The A-02 failure was then corrected and rechecked below. |
| Final focused Flutter rerun | 80 tests passed across A-02, A-03, lifecycle guardrails, abnormality command/convergence, monitoring receipts/retries, and Raise Issue interaction tests. |
| Final full analyzer | No issues. One test-style brace warning was corrected before this clean rerun. |
| Whitespace and process checks | `git diff --check` passed; no Dart/Flutter test worker, Jest runner, or Java emulator remained running at handoff. |

The first Functions run found an outdated source-contract assertion for the old operation-blind authority signature. The assertion was updated to require the operation-aware predicate; the complete suite then passed. Earlier Flutter checks also exposed A-02 classification bookkeeping and a test filename that conflicted with the repository's reserved-name guard. The last pull/deletion guards briefly exceeded the local repository's line limit; their repeated identity assertion was consolidated into the shared domain helper, and A-02 then passed. Those checks were corrected, not waived. No architecture ceiling or release assertion was raised or weakened.

The last full Flutter run is not claimed to be wholly green. Its A-02 failure was closed by the final focused rerun; the release-state assertion remains open. The entire suite was not rerun after that small helper extraction and the test-style brace correction. The final analyzer covers the resulting tree.

### Limits and Release Requirements

- These tests are local, with isolated `demo-` emulator data. No production records, phone data, IAM, distribution settings, or deployed Rules/Functions were changed. There was no APK construction, commit, or push.
- Monitoring persistence uses the app's SharedPreferences mechanism. Restart/service-recreation behavior is tested; sudden power-loss durability, cross-device uniqueness, and cross-isolate locking are not certified. Uncertain, corrupt, or rejected intents are retained rather than automatically discarded; persistent holds require reconciliation.
- The abnormality creation receipt is adopted when verified. An older draft whose creation response is lost and whose canonical record has subsequently changed can still require conflict reconciliation; this patch does not silently rebase it or declare all old/offline permutations covered.
- Hierarchy snapshots are structurally validated, not independently proven against every current live asset-registry node.
- `release/current-successor-state.json` still describes the earlier Build 23 backend state. Reconcile it against the exact source selected for merge and authorized deployment; passing the local functional tests does not make the modified backend deployed or the app distributable.
- Before rollout, test the final client/backend pair with mixed installed versions and real-device offline/retry behavior. The five-asset legacy direct-write restriction must be included in that decision.

Raw results are retained in `output/quality-abnormality-review-2026-09-04/`, including `three-risk-functions-final.log`, `three-risk-rules-full.log`, `three-risk-governed-emulator-final.log`, `three-risk-flutter-final-full.log`, `three-risk-flutter-handoff.log`, and `three-risk-analyzer-handoff.log`. Earlier failed runs are retained separately. This directory is ignored generated evidence, not committed production data. The branch and HEAD are unchanged; these remain uncommitted source changes.

## Original Review Checkpoint

Everything below records the earlier review, before the three fixes above. Its open-finding and test-count statements are historical, not the final status of this fix pass.

### Original Conclusion

The changed flows are substantially stronger, but this working tree is **not ready to describe as deployed or distributable**. The full app test run has one remaining release-state failure: the current release index still describes the previous backend-ready state while the working tree contains backend changes. No release assertion was weakened, and no APK, commit, push, deployment, phone operation, or production data mutation was performed during this resumed review.

The remaining engineering findings below must not be confused with that release-record issue. Passing tests do not establish that those wider boundaries are complete.

## Original Remaining Findings

### P1: Direct creation still has weaker nested-data validation

`firestore.rules`, `validChargeAbnormalityCreate` (around line 3196), checks affected-asset arrays and their sizes, but does not validate every nested asset/hierarchy entry. `validQualityWarningCommon` and `validAbnormalityQualityWarning` require a matching warning projection, not a fully validated nested asset model. Matching malformed values can therefore satisfy both sides while strict Dart and callable decoders reject the resulting records.

This is a static finding in the legacy direct-create boundary, not a claim that the normal new form currently emits malformed entries. The new form and callable paths do validate them. A server-governed create command, with an explicit old-client/offline-draft migration policy, is the recommended closure. Do not simply deny the existing create route without addressing installed clients and pending drafts.

### P2: Monitoring creation lacks durable retry identity

`lib/features/quality/services/quality_command_service.dart` generates a fresh monitoring ID in `createMonitoringRequest` (around line 367) and a fresh command ID in `_call` (around line 395). If the server commits but the response is lost, a user's subsequent submission can create another monitoring request. The backend replay protocol is effective only when the original request identity is retained.

Recommended closure: retain a persisted command intent and its request/entity IDs until a receipt or authoritative rejection is reconciled. A retry must reuse those IDs; a deliberate new request must get new IDs. Test process restart and response-loss cases, not only repeated calls with a manually reused ID.

### P2: Sync equality omits immutable case identity

`lib/core/services/sync_service.directives_abnormalities.dart`, `_governedChargeAbnormalityStateMatches` (around line 637), compares version and mutable facts but omits source charge, original actor/time, and linked source IDs. Its caller adopts the server row when that comparison succeeds. A corrupt or colliding local identity with otherwise matching facts can therefore be treated as successful convergence.

This was identified statically; it was not reproduced through the normal governed form. Add immutable case identity to the comparison and a repository-backed conflict test. Preserve local evidence rather than labelling a different case as synchronized.

### Release Integration: Current state must be reconciled

`release/current-successor-state.json:5` still states `BUILD23_FINALIZED_BACKEND_READY_AWAITING_DEVICE_AND_PILOT_DECISIONS`. The unchanged drift-sensitive test expects a source-successor/pending-backend state for these changes. Reconcile the release records against the exact source selected for review/merge. Existing Build 23 deployment evidence is not evidence that this modified tree has been deployed.

## Changes Checked and Hardened

| Area | Reviewed outcome |
| --- | --- |
| RA authority | Approved Operations can record RA required/completed; formal quality adjudication remains separately governed. |
| RA sequence | Completion of an existing case requires a prior required/completed state; closure cannot silently replace an already recorded RA charge or erase an RA requirement. |
| Warning linkage | Standalone warnings and governed issue warnings require their canonical abnormality; a missing case cannot silently become legacy unlinked adjudication. |
| Operational evidence | The existing opinion and old/new charge relationship remain visible; pending new-charge identity is explicit. |
| Corrections and reopening | Corrections preserve applicable historical hierarchy evidence. Reopening does not silently erase an already completed physical RA fact. |
| Command receipts | Receipts bind request, entity, operation, version advance, commit instant, and required linked readback. An unchanged older linked case remains valid for a closure-request-only operation. |
| Local adoption | Accepted linked abnormality evidence is adopted through the repository boundary; newer local work is preserved and incomplete local convergence is not announced as full success. |
| Mixed-version data | Supplemental hierarchy evidence is stored separately from legacy identity entries; empty legacy asset lists and older wire shapes remain explicitly handled. |
| Time | New abnormality times serialize in UTC. Legacy timezone-less plant timestamps use the explicit IST compatibility interpretation. Timestamp-map monitoring receipts are accepted. |
| Read load | Warning cards are lazy, with exact-document, auto-disposed linked-case subscriptions rather than one eager charge query for every warning. |
| Screen layout | Charge identity and metrics use separate phone rows. Long warning facts wrap. Form, record widgets, and orchestration are now separated into bounded files. |
| Authority refresh | Screens hide protected data during authority failure/refresh; actions reflect the signed-in role. |
| Disposed pages | A late quality-dialog result cannot start `_runCommand` after its parent page has been disposed. |
| Deletion evidence | Missing authoritative deletion time is reported before parsing nested asset data; no deletion time is manufactured. |
| Architecture records | A-02 was reconciled by decomposing oversized screens, without increasing its thresholds. A-03 regeneration changed only the reviewed operation fingerprint, not its allowed stores, modes, or authority profiles. |

## Verification

- Full Functions unit suite: 54 suites, 840 tests passed. The normal unit command skipped 12 emulator-dependent suites (90 tests); these are assessed separately below.
- Local Firestore Rules suite: 3 suites, 197 tests passed against a `demo-` emulator project.
- Full Flutter single-worker rerun: 1,703 passed, 1 skipped, 1 failed. The only failure is the release-state assertion described above.
- Final focused rerun after the disposed-page guard: 53 tests passed, covering async context safety, quality command receipts, and quality lifecycle/UI behavior.
- A-02 architecture inventory: passed after decomposition. A-03 exact inventory: passed in the full rerun. A-04 schema inventory: passed.
- Initial and final full analyzers: no issues.
- Final governed database-emulator suite: 12 suites, 91 tests passed. This includes the formerly skipped transaction suites and the added invalid-closure-time rejection test.
- `git diff --check`: passed at the review checkpoint.

One concurrent rerun exhausted host memory. It is not counted as a pass. The surviving worker was identified through its exact process, start time, parent, and test command, then stopped. The successful full rerun used one worker with no emulator running alongside it.

## Coverage Limits

- Widget tests exercise 320-pixel phone layouts, governed form navigation, role-dependent actions, long evidence text, missing linked cases, pending RA charges, and decision dialogs. They are not a fresh visual inspection of an installed phone build.
- No current physical-device, real-account, or production-network end-to-end claim is made.
- The tests cover many malformed payloads and races, but not every combination of old installed client, pending local draft, server response loss, app restart, and deletion.
- Supplemental hierarchy snapshots are structural evidence; this review does not claim every supplied snapshot is independently verified against the live asset registry at every mutation boundary.
- A single affected-asset identity currently carries one hierarchy target. Multiple component targets on the same physical asset, and custom classes sharing an asset number, need a deliberate identity-model review rather than accidental expansion of this patch.

## Recommended Sequence

1. Close the direct-create validation and retry-identity findings, including old-client compatibility tests.
2. Harden immutable case matching in the abnormality sync path.
3. Reconcile release source/deployment states honestly for the exact selected commit, then rerun the unchanged release gate.
4. Perform real-device smoke and mixed-client/offline tests on a subsequently authorized build. Do not infer device acceptance from these local checks.

## Original Completion Update

Final local verification is complete. The governed emulator rerun passed all 91 tests; the final analyzer reported no issues. The initial emulator run exposed an invalid test fixture whose closure timestamp was later than its update timestamp. The valid fixture was corrected and a separate rejection/rollback test retained the impossible chronology as a negative case. No production record was repaired or modified.

The final process check found no remaining Dart, Flutter test worker, or Java emulator process. `git diff --check` passed. The branch and HEAD remain unchanged; the reviewed edits are uncommitted.

Local raw logs are retained under `output/quality-abnormality-review-2026-09-04/` (ignored generated evidence), including the initial failures, memory-exhausted run, completed single-worker run, rules results, focused tests, final database-emulator results, and final analyzer result. The full Flutter run is still **not wholly green** because of the one release-state assertion, and the remaining engineering findings above are **not closed**.
