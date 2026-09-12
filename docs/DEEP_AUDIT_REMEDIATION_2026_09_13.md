# Deep audit repairs — 13 September 2026

Source repair branch: `codex/deep-audit-repairs-20260913`, based on local documentation commit `46d29c9d` and application source `86e06e7b`. The supplied `CRM3_Deep_Audit_86e06e7b_2026-09-12.md` was treated as evidence to investigate, not as authority to deploy or alter business records.

## Repairs selected

| Finding | Resulting behavior | Important boundary |
| --- | --- | --- |
| F01 — corrective work linked by host number | Linking and verification compare the original canonical physical identity. An Inner Cover is identified by its immutable cover ID and serial, using the ticket's contemporaneous association; the current occupant of a Base cannot stand in for it. | Incomplete historical identity remains a review case. Existing historical records are not silently rewritten. |
| F02 — reopened campaign with stale physical context | An explicit, audited context review advances the context of the same physical target. Original target, campaign baseline, measurements and coverage remain intact. Campaign/context versions and the reviewed live context are checked again by the server. | This does not substitute a different cover or component. Upgrade participating clients before using new reviewed/relocated observation shapes. |
| F03 — saved requests without a completing review route | An approved administrator can inspect retained work from **More → Saved work review**. Explicit completion records either an existing accepted result or cancellation, and both outcomes permanently prevent further business execution of the original request. Local proof preserves the original envelope, legacy bytes and unknown original actor. | An accepted-result hold never asserts cancellation or non-acceptance. Receipt absence is not proof that work never happened: receipts can expire. Inspect business records first. Undecodable legacy identity and contradictory acceptance/review evidence remain held for specialist investigation. |
| F04 — Morning Review crosses India midnight | New opening/not-held requests freeze their intended India date. The server refuses fresh creation on another day. Previously attempted requests can recover their original acceptance through a read-only receipt lookup, then perform normal business readback. Older unpinned requests use that lookup even on the same day, closing the race across a network wait at midnight. | An absent receipt cannot silently become permission to create a meeting. Never-sent old-day or unpinned work remains cancellable without dispatch. |
| F05 — entry time mistaken for physical work time | New planned-action entry requires selection of a local date and minute within the job bounds. Corrective-action entry exposes and preserves its supplied resolution time and allows correction within ticket bounds. The saved instant survives other form edits; burner/UV ordering uses it while preserving separate server recording time. | Corrective resolution still initially defaults its resolution time to now; operators must correct that time for late entry. A late entry for an older installation stays in history and does not replace a later physical installation. A separate governed correction workflow for already accepted history is not introduced here. |
| F06 — stale whole-module local save | Native saves compare the reviewed revision and complete persisted preimage, and check current module/parent lifecycle in the same transaction. A conflict retains the complete losing draft atomically. **Saved drafts** compares it with current work and requires explicit restoration against a fresh baseline. | No overwrite of submitted/accepted/deleted modules or terminal parents. Conflict evidence uses checksummed, bounded audit chunks and remains tied to its actual actor. |

## Recovery and compatibility

The server's administrative review is distinct from business acceptance or local adoption. A known accepted local submission must still use its original business readback path. A valid acceptance arriving after review retains both outcomes and blocks the resource for investigation; replaying an older review cannot release that conflict.

The review protocol is `savedSubmissionReview.v1` on the existing four V2 endpoints. Both V1 and V2 business calls consult the permanent execution hold inside their original Firestore transaction. Its explicit outcome distinguishes cancellation from an existing accepted result. This is necessary because an absent-receipt check alone cannot stop an in-flight original request, and an accepted receipt can later expire. The hold reserves the original ID across every operation sharing its receipt namespace. An installed client's delayed unpinned Morning Review request therefore cannot create a later day's meeting after its original acceptance has been reviewed and its receipt has expired.

Finalization of **both review outcomes is off by default**. The guarded V1/V2 fleet, drained older workers and a rollback that preserves both kinds of execution hold must be independently verified before setting the server activation record. Existing holds continue to apply if future finalization is disabled. Decisions and holds have no TTL. Client writes to these server control collections are prohibited. Inspection and supported read-only receipt lookup remain available; an expired receipt remains a read-only failure and never permits renewed execution.

If the review commits but its reply is lost, inspection can return the original immutable completed proof when its matching permanent hold remains valid, including after receipt expiry. The client retains the original reason and resolves local custody without another finalization or requiring the administrator to remember the earlier note. An earlier accepted-result proof lacking its matching hold is retained for specialist reconciliation; it is not silently rewritten, cancelled, or treated as safe completion.

Local compatibility advances from schema 11 to **schema 12** because review outcomes have new meanings in existing native columns. The exact v11 fingerprint remains recognized. The transition preserves the database generation and does not rewrite business rows. Older binaries must refuse a v12 store; clearing application data or downgrading the marker is not a recovery procedure. Source-bound release approval must identify schema 12 and its exact source fingerprint.

## Validation and release status

Focused verification includes native Isar restart/conflict tests, actual Flutter time-input tests, real handler asset/ticket/inspection journeys, Morning Review day-boundary tests, and administrative recovery receipt/fence tests. UI tests cover explicit confirmation and hiding retained evidence when account verification changes. These forms of evidence are distinct from emulator transactions, physical-device validation and production readback.

The integrated results below describe repair commit `f3d299d0`, before the
independent pre-build pass recorded in the following section. Local logs are
retained under `build/`; they are not production deployment evidence.

- Final canonical source/authority audit: **150 passed, 0 failed**, `build/review-20260912/deep-audit-canonical-verified.txt`. This includes current persistence, schema, decoding, timestamp and architecture inventories; historical release evidence remains unchanged. Test-evidence taxonomy also passes: `build/review-20260912/deep-audit-test-taxonomy-final.txt`.
- The separately required no-loss regression spine passed **110 tests**, `build/review-20260912/deep-audit-no-loss-spine-verified.txt`.
- Final full Flutter suite: **2,622 passed, 1 skipped, 0 failed** with the verified native Isar core: `build/review-20260912/deep-audit-full-flutter-verified.txt`. The skipped test is the bridge entry point that requires its external harness; it was executed separately through the successful 23-test bridge campaign below. Final whole-project analysis: **no issues**, `build/review-20260912/deep-audit-analyze-verified.txt`.
- Final complete Functions Jest host suite: **1,482 passed**, `build/review-20260912/deep-audit-functions-host-verified.txt`. The 149 intentionally skipped cases belong to separate emulator/fixture campaigns. The full build/custody pipeline's **81 Node tests** passed in `build/f03-functions-full-final.txt`; final build and inventories passed in `build/f03-functions-build-frozen.txt`.
- The actual Dart reader bridge passed **23/23** tests with the installed SDK and native reader harness available: `build/review-20260912/deep-audit-actual-reader-bridge.txt`.
- The complete governed emulator command passed **267 Rules tests, 3 identity-reconciliation tests and 145 Functions tests**, with no skipped or failed cases: `build/f03-governed-emulator-complete.txt`. CI now invokes the previously omitted master-integrity, actual V2 and submission-recovery suites as part of this command, under an explicit demo project.
- The final stricter receipt-shape checks passed **341 affected host tests** and **33 actual recovery/V1/V2 emulator tests** after that complete emulator run: `build/f03-final-receipt-shape-delta-host.txt` and `build/f03-final-receipt-shape-delta-emulator.txt`. They retain the same cancellation fence, wire format and historical business fingerprints. The full host suite above includes this final source.
- Native Morning Review recovery passed **45 tests**, including the four unpinned-request midnight/unsent regressions. The actual server review cancellation fixture also passed unchanged through the Dart service and native store. `build/review-20260912/deep-audit-final-integration-focused.txt` retains these passes and the then-failing UI ink-material issue; that UI issue was corrected, with all **34 tests** in the follow-up contract/UI/populated-migration batch passing: `build/review-20260912/deep-audit-final-contracts-focused.txt`.
- The actual-handler cancellation fixture proves that wire variant. Host producer and receipt-validation tests cover the other domains; this is not described as a native cross-runtime journey for every receipt-present variant.

No release identity was reused: `pubspec.yaml` remains the existing Build 27 version while these source repairs are reviewed. No successor APK, installation, distribution, production business-data change, recovery activation, IAM change or App Check activation is asserted by this note.

Before distribution, create an authorized successor artifact from the final reviewed source, verify the complete backend deployment and compatibility controls, perform the connected phone's in-place upgrade and representative business-flow checks, and retain exact artifact/readback evidence. The existing Build 27 download is not a download of these repairs.

Performance profiling, a database migration, full off-device restoration proof, broader durability for other command families, and accepted-history correction workflows are separate work. This repair does not claim to have completed them.

## Independent pre-build pass

The owner then requested an independent audit and construction of a successor
build, explicitly delegating the necessary authorization decisions. The audit
checked actual production wiring and delayed original callers as well as the
new recovery helpers. It found three additional defects:

| Finding | Concrete failure | Repair and regression evidence |
| --- | --- | --- |
| P1 — accepted review lacked a permanent execution hold | After the original accepted receipt expired, a delayed installed V1 client's unpinned Morning Review request could create another day's session. The earlier TTL test only retrieved the review proof. | Both outcomes now create permanent holds, preserving acceptance as a distinct outcome. The actual NOT_HELD producer, TTL expiry, delayed replay, transaction overlap and read-only recovery are exercised. Focused host: 119 passed; focused emulator: 38 passed. |
| P1 — production module provider omitted actor verification | Tests injected a verifier, but the production repository provider left it absent. Account changes or same-account permission revocation could therefore escape the transaction checks. | The actual provider now verifies live account readiness, UID and current roles. The action sheet hides on lost authority and checks authority around saving. Ten real native-provider cases and three actual widget cases pass, including rollback after a real native write. |
| P2 — inspection review retained visible details under another account | Disabling the approval button left the previous operator's selected target, current context and review note visible or editable. | The unauthorized dialog body is unmounted; the original operator's retained state returns only with current authority. The 21-test inspection board suite passes. |

The audit also corrected the deferred `js-yaml` build-tool advisory by raising
the root and Functions overrides/lockfiles to 3.15.2 and synchronizing both
installed trees. The complete dependency audit reports no advisory in either
population; its 13 acceptance/negative tests pass. The historical exception
record is retained with an explicit current-source update.

Combined application verification after these repairs:

- Full native-backed Flutter suite: **2,635 passed, 1 skipped, 0 failed**,
  `build/review-20260912/build28-fresh-audit-full-flutter.txt`. The skipped
  external reader-bridge entry point is the same separately exercised harness
  described above; this run did not execute that external campaign again.
- Whole-project analysis: **no issues**,
  `build/review-20260912/build28-fresh-audit-analyze.txt`. The separately
  required native no-loss regression spine passed **110 tests**,
  `build/review-20260912/build28-fresh-audit-no-loss-spine.txt`.
- Full Functions host pipeline: **1,494 Jest tests and 81 Node tests passed**,
  `build/build28-fresh-audit-functions-host.txt`. Its 154 skipped cases belong
  to separately invoked emulator/fixture suites.
- Full governed emulator campaign: **267 Rules tests, 3 identity-reconciliation
  tests and 150 Functions tests passed**,
  `build/build28-fresh-audit-governed-emulator.txt`.
- Final complete source/authority audit: **150 passed, 0 failed**,
  `build/review-20260912/build28-fresh-audit-canonical-final.txt`.
- Shared release-source and current-runtime authority suites: **52 passed**,
  followed by three focused checks of the extracted predeployment decision
  verifier and successor selection. Scoped permission evidence: **40 passed**
  on the frozen source, `build/build28-scoped-iam-frozen-root-check.txt`.
  The initial integrated custody run overlapped the final command-timestamp
  fixture update and retained one failure from the older fixture. The final
  integrated run on committed `64661ce1` passed **156/156**, including that
  correction, `build/build28-release-custody-frozen-final.txt`. Exact
  final-source CI remains required before deployment.

The final independent review found the same account-change visibility gap in
the sibling module progress form. Its body now uses the current-actor guard,
retains the original operator's entries for their return, and rechecks current
authority before saving and before adopting the result or showing success.
The complete production-provider/component/progress regression file passed
**16/16** and scoped analysis was clean, `build/job-module-progress-authority-test.txt`
and `build/job-module-progress-authority-analyze.txt`. The screen remains within
its existing 2,149-line architecture cap. This nine-line runtime delta followed
the full Flutter run above; it has its own targeted tests and requires the
final-source CI gate.

The first PR CI run on `64661ce1` passed Android packaging/cold start, Android
emulator integration and Functions host checks. Its Flutter run exposed an
obsolete source-text assertion that rejected a synchronous actor recheck after
the mounted guard. The contract now requires the guard for every module
adoption while allowing that recheck, and normalizes Windows/Linux newlines;
all **13** related checks pass in `build/build28-async-context-contract-final.txt`.
The Rules job stopped before emulators because npm returned an unavailable
audit response. Neither failure was waived; the final source still requires
all five CI jobs to pass.

The published follow-up `08d56d21` passed all five release-gate jobs and CodeQL
(release run `34721362992`). The independent PR review also found a further P1:
an inspection correction after a context review could inherit a later
installation. The server now derives the original context from the superseded
reading and its immutable baseline/review audit, retaining the current
campaign/review version as a concurrency precondition. Historical component
metadata and installation/removal bounds are preserved and checked. The
correction form shows the original location and starts with its original time.

Real Firestore tests additionally reproduced a context-audit Timestamp/string
comparison failure that memory-only fixtures did not expose. Persisted
`performedAt` and historical `linkedAt` are now normalized before comparison,
with all physical identity and audit checks retained. Final focused results:
**88 host, 18 Firestore emulator, 23 widget and 11 reader/context tests passed**;
Functions build/inventories and scoped Flutter analysis are clean. The
dedicated inspection repair note records the original failures, passing logs
and actual handler-produced cross-runtime fixture. These final inspection
changes follow the successful `08d56d21` run and require their own final CI.
The final complete canonical source/authority audit passes **150/150** in
`build/review-20260912/build28-final-inspection-canonical-verified.txt`.
The first attempt exposed the inspection editor's line limit; the unchanged
submission path and its draft now share a small companion part, preserving
both existing limits. All 34 affected Flutter checks pass after extraction.

The retained release records describe the older 15-function deployment. The
new source declares 19 endpoints, including four new V2 callable endpoints.
Current deployment evidence must measure their creation and any associated
invoker IAM provisioning explicitly; an old `iamMutated: false` receipt cannot
stand in for a new deployment. Existing project, service-account and service
permissions must remain unchanged. The production approval must retain the
owner's delegation as delegation, with an actual agent decision time and exact
reviewed source, rather than inventing an owner-spoken source approval.

The connected phone's installed Build 27 APK and signing certificate were read
and independently verified as the retained upgrade baseline. This does not
establish its current private data inventory or a completed successor upgrade.
Construction, backend readback, device validation and distribution will each
need their own measured result.
