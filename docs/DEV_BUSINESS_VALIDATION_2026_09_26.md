# Development business validation — 26 September 2026

This is the working validation matrix for the owner's instruction to make the
development profile usable and check the major business functions before another
release. The starting checkout is `claude/dev-loop-seeding` at `cea55364`, with
concurrent authorized local repairs. This is not a frozen release certificate.
The initial validation used isolated DEV services. Later, the owner individually
authorized the production actions recorded at the end of this report. The
isolated backend timestamp compatibility repair was subsequently deployed to
two endpoints with exact-source verification. The other local repairs are not
established as part of the installed production build.

## Evidence recorded in this pass

- **Full maintenance-origin Quality phone journey: PASS — 1/1 integration
  test, 2 minutes 34 seconds.** On DEV source charge **73325**, the real phone
  created two maintenance-origin cases and two independent direct abnormalities,
  completed the required RA paths, switched Operations → SI, adjudicated both
  maintenance warnings, and switched SI → Operations. Actor, decision evidence,
  exact case/warning identities and persisted results were asserted. Evidence:
  `output/dev-business-validation-20260926/phone-issue-quality-final.log`, with
  `DEV_ISSUE_QUALITY_PASS` and `All tests passed!`. A caught provider-disposed
  warning occurred after the test removed the root during teardown; it remains
  a cleanup limitation, not a test failure or a claim of an error-free log.
- **Final broad client run: PASS — 72 selected Flutter files, 729 tests, zero
  failures.** The machine-readable aggregate confirms exit code `0` and
  `completion.success=true`. Evidence:
  `output/dev-business-validation-20260926/flutter-current-final-summary.json`
  and `flutter-current-final.jsonl` in the same directory. This repeat includes
  the signed-out login-surface regressions below. The preceding **725-test / 72-file**
  checkpoint remains recorded in `flutter-current-domain-summary.json` and
  `flutter-current-domain.jsonl`. These host runs do not establish phone or
  production behavior; earlier and focused results overlap and are not added to
  the final total.
- **Earlier broad client run: PASS — 68 Flutter files, 703 tests, zero failures, zero
  skips.** One runner used `flutter test --no-pub --reporter json
  --concurrency=4` with the explicit file manifest. It completed successfully in
  approximately 26.6 seconds of reported runner time. These are host domain,
  controller, widget and native-local-storage checks; they do not establish
  Android operation or Firebase callable HTTP middleware behavior. This run
  preceded the later session repairs documented below; their focused results are
  recorded separately and are not added to this overlapping total.
- Broad-run manifest: `output/dev-business-validation-20260926/final-selected-tests.txt`.
- Broad-run reporter output:
  `output/dev-business-validation-20260926/flutter-domain-final.jsonl`.
- Machine-readable aggregate:
  `output/dev-business-validation-20260926/flutter-domain-final-summary.json`.
- Process exit record:
  `output/dev-business-validation-20260926/flutter-domain-final.exit.txt` (`0`).
  The earlier 669-test run and its original manifest/output remain preserved;
  the 703-test repeat included the live-dropdown and lifecycle regressions then
  available, not every later account-session regression.
- **Fresh backend host tests: PASS — 81 Jest suites, 2,353 tests.** The full
  `npm test` run also completed the Functions build, emitted-output custody,
  callable/notification inventories and auxiliary Node checks. Its 21
  environment-gated emulator suites / 245 tests were skipped in that invocation
  and are not counted as passing. Evidence:
  `.dart_tool/backend-runtime-repair-tests.log`. The aggregate and skipped counts
  were independently read back from the log. This includes the new regression
  for Firebase CLI binding of the Admin Firestore namespace.
- **Fresh governed Firestore tests: PASS — 21 suites, 241 tests, no skips or
  failures.** These ran against the separate `demo-crm3-governed` project on the
  local Firestore emulator. Evidence:
  `.dart_tool/backend-governed-emulator-tests.log`; the aggregate was independently
  read back. This establishes the covered transactions and selected Rules cases,
  not callable HTTP middleware or physical-device behavior.
- **Fresh additional callable HTTP journeys: PASS — 24 business checks across
  authority (7), Inner Covers (8), Burner rounds (5) and published assignment (4),
  plus one setup check in each of two executions.** The actual Auth emulator
  issued tokens used with the Functions emulator, and accepted results were read
  back from Firestore. Evidence:
  `output/dev-business-validation-20260926/http-other-domains.json` and
  `output/dev-business-validation-20260926/http-burner-template-domains-complete.json`.
  These counts must not be added again if a consolidated harness reruns them.
  Earlier unsuccessful fixture bring-up reports remain separate from these
  completed passing runs; no business validator was relaxed.
- **Final consolidated callable HTTP: PASS — 104 checks, zero failures**, including
  the extension checks above, the additional condition/cadence/inspection journeys
  below, and setup/transport assertions. The report records 119 actual callable
  requests across seven endpoints:
  `output/dev-business-validation-20260926/http-business-journeys-complete.json`.
  A separate Morning Review run passed **19 checks**, including setup, attendance,
  assignment, completion, correction/reopen, cancellation and minutes finalization:
  `output/dev-business-validation-20260926/http-morning-review-complete.json`.
  Both result aggregates and named outcomes were independently read back. They
  share setup checks and must not be summed as distinct business requirements.
- **Additional high-risk HTTP: condition/cadence PASS — 18 business checks plus
  setup; inspection PASS — 8 business checks plus setup.** Evidence:
  `output/dev-business-validation-20260926/http-condition-cadence-registered.json` and
  `output/dev-business-validation-20260926/http-inspection-journey.json`.
  Actual historical-maintenance submissions preserve same-day conflicts for
  review, and a later physical day establishes a new basis without erasing earlier
  records. Actual survey closure preserves an unresolved linked repair/finding.
  SI retirement exposed a real callable preflight mismatch despite the direct
  handler allowance. The wrapper now uses the same bounded registry admission
  policy, and the fresh HTTP rerun proves that retirement/replay preserve the
  unresolved Unfit assessment. The two extra V1/V2 boundary regressions and
  existing registry suite passed **41 tests**; this overlaps the earlier governed
  run and is not an extra 41 unique cases. Final host repeat remained **2,353
  passed**, with 247 emulator cases skipped in that host-only invocation.
  Evidence: `.dart_tool/si-retirement-boundary-after.log` and
  `.dart_tool/backend-final-si-host-tests.log`.
- **Physical phone restart: PASS — 1 integration test** in
  `output/dev-business-validation-20260926/phone-restart.log` (the
  `DEV_RESTART_PASS` marker and runner completion were read back). After a separate
  process start, the online gate accepted access and the app reopened the same
  Isar-persisted, synced abnormality `784535f8-7148-4c31-ac0f-79ce10653765`, charge
  `88807`, with exactly one server case and warning. This is restart/readback
  evidence; the final fresh-create journey below subsequently passed too.
- **Final physical phone create journey: PASS — 1 integration test**, including
  teardown, on the Samsung SM-G990E in the distinct `.dev` app. The real UI
  created charge `89079` abnormality `b8381cdf-faf7-4890-b901-ec5fee64f2da`,
  authenticated reads proved exactly one canonical case and linked warning,
  the normal Quality screen displayed it, and reopening the charge retained it.
  Evidence: `output/dev-business-validation-20260926/phone-journey-final.log`,
  with `DEV_JOURNEY_PASS`, `All tests passed!` and runner exit zero. No business
  provider, repository or callable was substituted in either phone test.
- **Live selector repair:** stable field identity and current-item validation
  replace catalogue-size/selected-ID keys. Withdrawn popup choices are rejected
  and the form value is restored; empty authoritative lists keep the field
  mounted with the existing notice. The final maintenance interaction rerun
  passed **16 tests**, including a real provider-stream withdrawal/empty-list
  popup regression; **34** related current-asset/planned-selection/stuck-up checks
  also passed. Targeted analysis of the two selector files and regression file
  reported no issues. Evidence: `selector-popup-rerun.log`,
  `selector-popup-tests.log` and `selector-popup-analysis.log` in the same output
  directory. The initial new test fixture timed out before emitting its first
  catalogue; its setup was corrected and the affected suite rerun green.
- **Callable HTTP and physical-device results are separate checkpoints.**
  Historical passing counts in review documents are existing evidence, not added
  to today's results. Device rows remain pending except for the explicit results
  recorded here. Host/HTTP counts are not added together as unique requirements.

The local evidence directory is ignored output, not immutable CI or release
custody. The initial broad host tests passed while actual HTTP and phone testing
still exposed defects. The earlier 703-test and 725-test checkpoints included the
regressions available then; the final 729-test repeat includes the signed-out
login-surface follow-up. The separate final phone run supplies the covered
account-switch evidence; host aggregates do not substitute for it. The final
workspace `git diff --check` returned exit code `0`, with only existing CRLF
notices.

## Repairs made in this pass

- Direct Admin Firestore imports preserve Timestamp/FieldValue/FieldPath access
  when the emulator binds the namespace function. Exported entry points and real
  callable journeys were checked after rebuilding the emitted source.
- Explicit emulator host mapping makes USB forwarding work on the physical
  phone. The launcher selects the intended device and preserves DEV data between
  test processes. Gradle rejects mismatched DEV/backend flags and non-debug tasks;
  four actual negative Gradle checks passed.
- Registry preflight now applies the same existing permission as its handler:
  approved SI may retire with preserved restriction evidence. Other registry
  mutations remain Admin-only. V1/V2 negative and replay tests passed.
- The shared decorated section provides the Material surface required by its
  interactive ListTiles. Both new regressions failed before the fix and passed
  afterward.
- Live sync disposal releases subscriptions/timers and invalidates stale
  callbacks without reading the disposed WidgetRef. Normal stop still publishes
  its disconnected state. The reproduced regression and reconciliation/startup
  tests passed; existing database transactions are not claimed to be cancelled.
- Seven live asset selectors now retain field identity, validate old popup
  responses against the latest eligible items, and retain disabled fields when
  authoritative lists become empty. Real screen/provider-stream regressions
  cover additions, withdrawal and empty catalogues.

## Retained limits

Some DEV launches immediately after installation stalled before Flutter attached
to the VM service. A force-stop/relaunch of **only the DEV package** recovered
them without clearing app data; the final phone test then completed successfully.
The cause is unresolved. The final two resource listings match the APK's complete
asset sizes and contain the current extraction marker, so incomplete extraction
is not established. A Java stack request was unavailable on the non-rooted phone;
no rooting or SDK/renderer change was attempted. Evidence is in the
`native-dev-*` files and the verbose final phone log. A passing recovered journey
does not certify consistent first launch after installation.

At an earlier checkpoint, the normal `lib/main.dart` DEV entry point was restored
using the guarded launcher and `--no-resident`. That launch completed with exit
zero without a manual relaunch; the foreground screen showed the approved Dev
user's normal home dashboard and demo records. Evidence: `normal-dev-launch.log`
and `normal-dev-ready.png` in the same output directory. Subsequent integration
APK runs and the owner-authorized production actions supersede that checkpoint.
The final normal DEV restoration then completed successfully using
`run_dev.ps1 --no-resident --no-pub`, with exit code `0`. Evidence:
`output/dev-business-validation-20260926/dev-normal-restored.log`; the ordinary
entry point started against the local demo services. The production
`1.0.0-rc.19` / code 29 app remains installed, and its existing activity was
brought back to the foreground after restoration. No further business changes
were made during that final return to the production app.

FCM is not supplied by the local Firebase suite: the demo configuration produces
Firebase Installations/token errors, so these runs do not prove push delivery.
The passing final phone test also logged a caught `SyncCoordinator` read of an
already disposed provider container after the test removed the app root. The
runner passed; this residual teardown warning is not claimed to be repaired.
The matrix retains unexecuted device/HTTP scenarios explicitly. In particular,
in-flight process loss, account recovery beyond the two covered transitions,
off-device recovery, final signed release behavior, and production IAM/App Check
enforcement remain separate work.

## Reading the matrix

**Client pass** means the named tests were executed in a broad or focused run
explicitly recorded here. The final broad aggregate is 729 tests; earlier
703-test, 725-test and focused results remain distinct, overlapping checkpoints.
**Handler reference** names suites covered by the fresh full host run, with real
production handlers exercised using controlled stores/transports; it is not a
real HTTP request. **Firestore emulator reference** names suites covered by the
fresh 241-test run, but does not imply Firebase Auth or `onCall` middleware was
used. **HTTP pass** means actual emulator Auth, callable HTTP and persisted
readback, with any administrative setup fixtures disclosed. **HTTP pending** and **device
pending** mean that evidence has not yet been attached here. A listed suite or
historical green result is not an assertion that it ran today.

The 18 rows below are validation groupings, not a renumbering of the historical
audit's Function/Domain identifiers, which differ between supplied reports.

| ID / business area | Approved behavior to preserve | Fresh client coverage | Stronger-path coverage and remaining journey |
| --- | --- | --- | --- |
| V01 Critical safety alarms | Original-account uncertain intent remains recoverable; alarm state and notification readiness must not be conflated. | **Client pass:** `critical_alarm_model_test`, `critical_alarm_command_service_test`, `critical_alarm_notification_boundary_test`. | Handler reference: `criticalAlarm.test.js`. **HTTP pass:** raise, support confirmation, stale resolution refusal, resolution and historical replay retaining terminal state. Native posting, channel/permission denial, background receipt and recipient delivery remain **device pending**. No emulator substitutes for FCM delivery. |
| V02 Planned work and multi-agency coordination | Acknowledged active lanes govern closure; non-blocking agency follow-up can finish after physical closure without reopening work. Blocking/cancelled/issue-coordination paths must not gain that exception. | **Client pass:** `planned_job_closure_guard_test`, `planned_job_closure_attestation_test`, `planned_job_dossier_test`, lane closure/compliance policy, `compliance_visibility_policy_test`, `compliance_detail_convergence_test`. | Handler reference: `multiAgencyReview.test.js`, `maintenanceWorkflow.test.js`; Firestore reference: `maintenanceWorkflow.firestoreEmulator.test.js`. **HTTP pass:** reactive ticket creation, discipline acknowledgement/completion, supervised addition of accountable lane, rejection of premature finalization and SI resolution/replay. Planned work → physical closure → remaining non-blocking agency finish remains **HTTP/device pending**. |
| V03 Inner Cover lifecycle | Preserve serial and Base identity, physical chronology, acceptance evidence and original-account recovery; retirement does not fabricate new acceptance. | **Client pass:** `inner_cover_lifecycle_model_test`, `inner_cover_acceptance_controller_test`. | Handler reference: `innerCoverLifecycleMutation.test.js`. **HTTP pass:** register → inspect/accept → link to Base → delink → reject old inspection → fresh reinspection; replay preserves later custody and the three records agree. Transfer/retirement HTTP and the phone journey remain pending. |
| V04 Burner blocks, UV and condition rounds | Late entry of earlier physical work stays history. Replacement clears only older condition evidence. Corrections preserve originals, reasons, reviewer and exact predecessor; inherited readings do not become newly observed facts. | **Client pass:** `planned_maintenance_burner_block_lifecycle_test`, both installation correction readers, UV correction controls, `burner_condition_round_test`, furnace audit issue/in-flight-save tests. | Handler reference: `burnerBlockLifecycle.test.js`, `uvDetectorLifecycle.test.js`, `burnerConditionRoundMutation.test.js`. **HTTP pass:** complete eight-position round, partial update retaining untouched source/time/observer, stale draft refusal, historical replay after a later survey. Corrected installation HTTP and phone remain pending. |
| V05 Inspection campaigns and findings | Survey closure does not resolve findings. Closed surveys retain scoped follow-up/verification and immutable closure history. Maintenance completion is distinct from inspection verification; physical subject/episode must match. | **Client pass:** `inspection_campaign_model_test`, `inspection_target_context_test`, `inspection_campaign_submission_controller_test`, `inspection_audit_board_test`. | Handler reference: `inspectionFindingIntegrity.test.js`; matching Firestore suite passed. **HTTP pass:** exact survey targets, assigned adverse reading, scoped actual repair link, close/replay preserving unresolved repair and `correctiveActionLinked` finding plus frozen closure. Premature closure, wrong observer and false-resolution attempts refused. Repair completion → fresh verification and phone remain pending. |
| V06 Operational intervals and stuck-up events | Removal confirmation does not silently close maintenance or adjudicate cause. An interval amendment retains the original and existing issue membership. | **Client pass:** `furnace_stuckup_case_test`, `furnace_stuckup_removal_test`, `operational_event_interval_amendment_test`, `operational_event_issue_link_test`. | Handler reference: `furnaceStuckupWorkflow.test.js`, `operationalEventMutation.test.js`, `operationalEventIssueLinkMutation.test.js`; interval emulator suite exists. Backdated amendment and linked issue readback are **HTTP/device pending**. |
| V07 Quality, charge monitoring and abnormalities | Distinguish warning/request/abnormality intent and stable charge/asset identity; preserve accepted and uncertain command outcomes. A populated form is not proof of a persisted abnormality. | **Client pass:** quality warning/submission/report identity tests, charge monitoring review recovery, `a05_abnormality_integrity_test`, `charge_abnormality_command_convergence_test`, `issue_quality_intent_test`. | Handler/Firestore references: charge abnormality mutation suites and charge monitoring review. **HTTP pass:** abnormality/warning creation, RA decision/completion, SI Quality close, reopen and Admin evidence correction retaining physical RA/identity; monitoring create/correct/cancel or complete; stale/origin/role refusal and accepted replay. **Device pass:** separate-process restart reopens the same synced Isar case with exactly one server case/warning. Real-UI creation, canonical acceptance, visible Quality warning and charge reopening passed. The final complete charge 73325 phone journey passed maintenance-origin acceptable/RA closures, two independent same-charge abnormalities and both Operations/SI account transitions, preserving both open physical issues. Earlier charge 76575 two-session proof and failed attempts remain recorded below. |
| V08 Reactive maintenance and administrative closure | Registered equipment identity is protected. Admin/SI corrections require explicit reviewed target/reason. Administrative `stillRelevant` closure retains the concern; ending relevance is explicit and distinct from technical repair. | **Client pass:** administrative closure transition/dialog, `maintenance_closure_evidence_admission_test`, component identity and furnace issue-evidence tests. | Handler reference: `maintenanceTicketSupervision.test.js`; worked/dependent/cross-asset target correction remains bounded by documented admission, not assumed universally supported. Closure/continuation/relevance history is **HTTP/device pending**. |
| V09 Maintenance cadence | Conflicting due dates from the same Indian plant day preserve both records and require review; no settled next due date is invented. Later unambiguous physical evidence can establish a new basis. | **Client pass:** `maintenance_due_state_integrity_test`, `due_state_population_completeness_test` verify readable pending/qualified state. They do **not** execute the server conflict reducer. | Handler reference: `maintenanceCadenceReview.test.js` tests both arrival orders, plant-day boundaries, interpretation replacement and historical-only exclusion. **HTTP pass:** governed definitions and historical producers; different times in one Indian day retain both completion events, require review and clear due date; replay preserves conflict, later physical day establishes a new basis without deleting originals. Plan/review UI and historical adjudication remain pending. |
| V10 Equipment condition and availability | One complete manual assessment; replacing an active assessment reviews the exact existing declaration. Admin/SI retirement may preserve Down/Unfit with reason; retirement does not imply repair or erase independent restrictions. | **Client pass:** operational condition model, condition evidence/board, replacement lifecycle UI. | Handler reference: `assetOperationalConditionMutation.test.js`; Firestore reference: `assetHierarchyMutation.firestoreEmulator.test.js`. **HTTP pass after wrapper repair:** actual registration/number custody, Down declaration, exact reviewed SI Unfit replacement, missing/wrong predecessor and Operations denials, SI retirement retaining unchanged unresolved assessment and audit, historical replay preserving retired/Unfit state. Phone remains pending. |
| V11 Ordinary directives | Material amendment or transfer requires fresh acknowledgement; original instruction/acknowledgement remains historical. Completed instructions cannot be rewritten as active work. | **Client pass:** `governed_directive_acknowledgement_test`, `ordinary_directive_commands_test`, `directive_server_closure_adoption_test`. | Handler reference: `ordinaryDirectiveMutation.test.js`; matching Firestore suite passed. **HTTP pass:** issue → acknowledge → amend → refuse stale acknowledgement → acknowledge current text → complete/replay, retaining historical acceptance and terminal state. Transfer HTTP and phone remain pending. |
| V12 Morning Review | Preserve agenda/current obligations, original review identity and correction/recovery semantics; old-day uncertain intent must not become an invented new meeting. | **Client pass:** `morning_review_integrity_test`, `morning_review_agenda_test`. | Handler reference: `morningReviewMutation.test.js`; Firestore reference: `morningReviewRecovery.firestoreEmulator.test.js`. **HTTP pass:** labelled dev meeting, role/window denials, attendance, accountable assignment/reassignment, completion, immutable correction/reopen, cancel/replay and frozen minutes. Account change, India-midnight recovery and phone remain pending. |
| V13 Modules, templates and published assignment | Publication readiness and frozen published identity gate assignment; original-account origin survives awaiting/dispatch. Empty template screens are not assignment proof. | **Client pass:** `template_publication_readiness_test`, `published_template_assignment_origin_bound_test`, planned job closure/dossier tests. | Handler references: published assignment/runtime population and planned closure suites. **HTTP pass:** seeded valid publication → SI assignment → frozen execution/module/receipt readback, exact replay, changed-intent and Operations-role refusal. Author/publish UI and execute/close remain pending; publication was an administrative setup fixture. |
| V14 Reports, fleet status and retained obligations | Current obligations and administratively closed `stillRelevant` concerns remain visible independently of historical period. Stable canonical identity survives renaming/retirement; unreadable sources cannot claim completeness. | **Client pass:** `operations_report_test`, `operations_report_abnormality_identity_test`, quality report identity and equipment/furnace evidence tests. | Report output/section selection has prior documented evidence. Physical PDF preview/share/authority loss and representative scale are **device pending**. No certified common database cutoff is claimed. |
| V15 User administration and operational access | Online server authority is required at open/resume. Revocation removes current access while preserving work; reviewed Admin restoration is permitted with reason/retained roles. Stale approval cannot survive a revoke/regrant cycle. | **Client pass:** `online_access_gate_test`, `current_actor_access_test`, `user_authority_schema_test`, `user_authority_recovery_test`, `auth_profile_stream_replacement_test`. | Handler reference: `userAuthorityMutation.test.js`; actual Firestore authority suite passed. **HTTP pass:** reviewed revoke/restore, retained roles/audited reason, revoked pull and self-restoration refusal, revision guard through the cycle, historical revoke replay preserving restored access. Offline launch, foreground recheck and lost-reply phone recovery remain pending. |
| V16 Governed register and installed components | Stable physical/component identity and lineage remain protected; reviewed historical installation corrections preserve original evidence and do not reactivate replaced equipment. | **Client pass:** `asset_hierarchy_business_reference_test`, `component_action_identity_test`, `equipment_registry_rebinding_test`, `component_replacement_lifecycle_ui_test`. | Handler reference: `assetRegistryReplayIntake.test.js`; registry/asset hierarchy Firestore suites exist. Register → install → replace → historical correction/readback is **HTTP/device pending**. |
| V17 Knowledge catalogue | Authoritative empty/withdrawn data must not resurrect embedded defaults; accepted revision and later local draft remain distinguishable. A row revision is not a certified catalogue edition. | **Client pass:** `baf_knowledge_catalogue_state_test`, `knowledge_catalogue_recovery_test`. | Existing concrete controller/repository and revision-audit tests are documented in remaining-domain remediation. Multi-row import interruption and representative phone browsing are **device pending**; certified editions remain open. |
| V18 Saved submissions, sync and recovery | Retain original account/envelope and uncertainty; accepted older intent must not erase newer work. Unsupported administrative recovery stays held, not falsely declared cancelled or retried under another identity. | **Client pass:** `saved_submission_review_test`, plus actual selected command/controller/native journal tests above. | Handler/Firestore reference: submission recovery suites. **Device pass:** accepted synced abnormality survives separate process restart and online access recheck, reopening without duplicate server records. In-flight process loss, offline/reconnect, new-account refusal and protected newer draft remain pending. This does not establish off-device restoration. |

Names ending in `_test` above are under `test/` with `.dart`; named backend suites
are under `functions/test/`. The exact executed file list is the evidence manifest,
including the two selected `test/maintenance_workflow/` files.

## Approved nuance anchors and evidence boundaries

- **Physical chronology, corrections and inherited evidence:**
  [Burner/UV review](BURNER_UV_REVIEW_REMEDIATION_2026_09_20.md). Its old statement
  that UV correction is unsupported is superseded by
  [the September 21 follow-through](AUDIT_CLOSURE_AND_KOTLIN_2026_09_21.md), which
  records the separately governed UV correction. Today's client run includes the
  late-earlier-work regression and Admin/SI correction controls.
- **Survey closure keeps findings actionable:**
  [inspection owner decision](INSPECTIONS_REVIEW_PROGRESS_2026_09_20.md).
  `inspectionFindingIntegrity.test.js` contains a real-handler closed-survey
  repair/verification sequence; the client run does not turn it into HTTP proof.
- **Non-blocking agency work after closure:** the reconciled historical entries in
  [September 21 follow-through](AUDIT_CLOSURE_AND_KOTLIN_2026_09_21.md) supersede the
  original Domain 02 open decision. `multiAgencyReview.test.js` exercises the
  production dispatcher with `MemoryWorkflowStore`; the client suite checks that
  blocking, cancelled and completed issue-coordination exceptions stay closed.
- **Protected equipment target and reasoned corrections:**
  [reactive maintenance decision](REACTIVE_MAINTENANCE_REMEDIATION_2026_09_20.md).
  Permission for a correction is not permission to silently relabel historical
  physical work; documented dependent-target restrictions remain material.
- **Manual replacement/retirement:**
  [equipment-condition decisions](EQUIPMENT_CONDITION_REMEDIATION_2026_09_20.md).
- **Same-day conflict requires review:**
  [cadence owner decision](MAINTENANCE_CADENCE_REMEDIATION_2026_09_20.md).
  The backend reducer tests are the relevant rule evidence; a Dart decoder test
  alone cannot prove ordering or transactional write behavior.
- **Fresh acknowledgement after amendment/transfer:**
  [ordinary directives decision](ORDINARY_DIRECTIVES_REMEDIATION_2026_09_20.md).
- **Online access and reversible revocation:**
  [user administration decisions](USER_ADMINISTRATION_REMEDIATION_2026_09_20.md).
- **Closed physical work, diary follow-up and retained relevance:**
  [remaining functions decisions](REMAINING_FUNCTIONS_REMEDIATION_2026_09_20.md).

The older [domain ledger](DOMAIN_AUDIT_REMEDIATION_LEDGER.md) is a historical
checkpoint. Its open entries are not automatically current defects when later
source and accepted review records supersede them. Conversely, later local green
tests do not close the explicitly retained off-device recovery, historical
cadence adjudication, catalogue certification, report cutoff/scale or notification
delivery qualification programmes.

## Runtime checkpoints to record separately

| Evidence layer | Result in this pass | Scope limit |
| --- | --- | --- |
| Source/rule review | Reviewed all 18 groups and the superseding owner decisions above. Dev launcher/Gradle safeguards independently reviewed. | Reading code and approved rules cannot prove runtime behavior. |
| Flutter host | Final broad run: **729 passed / 72 selected files**, zero failures, exit `0`. Earlier broad checkpoints: **725 / 72 files** and **703 / 68 files**. | Broad and focused counts overlap and are not summed. Models, controllers, widgets and selected native-local-store checks; not Android or HTTP middleware. |
| Backend host | Final repeat: **2,353 passed / 81 Jest suites**, build and auxiliary checks passed. | Real handlers with controlled stores/transports; 247 emulator cases skipped in the final host invocation. |
| Actual local Firestore | **241 passed / 21 suites**; later focused **41 passed / 2 suites**, including two new callable-boundary regressions. | No failures/skips in either emulator run; counts overlap. Covered real transactions and selected Rules cases. `.run` boundary tests are distinct from actual HTTP. |
| Actual callable HTTP | Final consolidated **104 passed / 0 failed**; separate **19 passed / 0 failed** Morning Review. | 119 actual callable requests in the consolidated run. Actual Auth, HTTP middleware and persisted reads; setup overlaps. No Android/offline or production proof. |
| Connected Android phone | **Full charge 73325 maintenance/Quality journey: 1/1 passed**, including both Operations → SI → Operations transitions, four cases/warnings, two Quality closures and two still-open physical issues. Earlier creation, separate-process restart and SI continuation tests also passed. | Earlier failed attempts remain failures. A caught provider-disposed warning occurred after the final test removed the root during teardown. Some earlier launches required a DEV-only relaunch; cause unresolved. These passes do not qualify every domain or production notifications. |
| Owner-authorized production phone actions | Case A closed with its recorded RA. After the verified backend patch, case B closed as `coilFoundAcceptable`, RA `notRequired`, with the exact owner-confirmed decision. Actual UI and server readback agree. A separately authorized **TRIAL DATA** abnormality retains its own open warning. | Individual production actions in installed Build 29, not a passing production suite. Case B's physical maintenance record was already resolved and remained unchanged. The two-endpoint timestamp repair is live; remaining client changes are uncommitted and release-pending. Exact operational identifiers remain in private evidence. |

Independent phone-test review caught a six-digit generated charge number before
acceptance: the application requires exactly five digits. That was a test-fixture
defect, not grounds to relax the business validator. The root task owns its repair
and rerun. Review also identified that custom seeded identity settings need to be
forwarded by the guarded launcher if non-default accounts are to be selected.

1. Emulator launcher validates the demo project and compiles/audits the actual
   Functions source before serving its emitted entry point. File modification
   times alone do not prove stale emitted code.
2. Real Auth token + actual HTTP callable, normal permissions and real local
   Firestore commit/readback succeed for the selected business journey. Setup may
   seed administrative fixtures; the action under test must use the normal app or
   authenticated callable path. Record negative authority/input cases separately.
3. The DEV phone journeys run the distinct `.dev` application against the local
   demo services. Record screens/actions, accepted business identity and
   subsequent readback. The separately authorized production actions below are
   not DEV fixtures or additions to the automated DEV pass counts.
4. Repeat representative nuance journeys and interruption/account-switch checks.
   The presence of a seeded row, a green handler test or an open form is not that
   outcome. Broader unexecuted rows remain clearly pending.

These pending entries should be replaced only by actual observed results from
this pass, with the transport and fixture limits retained. Release-mode shrinking,
real Google sign-in, production IAM/App Check enforcement, notifications and the
eventual signed-release device check remain separate from this development profile.

HTTP fixtures use unique `hj-` run prefixes (protocol identities requiring UUIDs
are deterministically derived from them). Asset classes/instances and published
template metadata must satisfy the strict Flutter readers because the phone
shares this demo project. Unique document IDs alone do not isolate legacy asset
lookup: several active classes with the same legacy mapping can correctly trigger
an ambiguity refusal. The final assignment fixture uses a unique governed custom
class. After all HTTP checks completed, **41 positively identified session-owned
legacy-mapped fixture classes were retired by changing only `status`** through the
guarded loopback demo endpoint. All documents/receipts were retained. Readback
verified zero active harness legacy mappings, zero changes to non-harness
classes, all class IDs retained, and `seed-class-annealing-furnace` still active.
Exact ownership evidence and before/after data:
`output/dev-business-validation-20260926/http-fixture-deactivation-plan.json` and
`output/dev-business-validation-20260926/http-fixture-deactivation-result.json`.
These retired fixture classes are historical test evidence, not active choices
for manual use. New harness runs create active fixtures again and need the same
bounded cleanup after their evidence is recorded.

## Requested maintenance-origin Quality and same-charge phone journey

The follow-up specifically starts at **Raise issue**, rather than substituting
direct abnormality creation for maintenance-origin Quality. The reusable phone
journey is `integration_test/dev_issue_quality_journey_test.dart`; its later SI
continuation is `integration_test/dev_quality_adjudication_test.dart`. The
companion HTTP journey is `tool/dev/http_issue_quality_journey.py`. All use only
the local `demo-crm3-baf-ops` backend. Phone identity setup uses the default
Operations account and the dedicated `dev.quality-si@example.invalid` fixture.

The actual HTTP run passed **15/15 checks using 21 callable requests** on source
charge **91341**. It raised two physical maintenance issues, adjudicated one as
acceptable, completed RA for the other on **91342**, then added two independent
abnormalities on the same source charge without RA and with completed RA
**91343**. Exact linked identities and all earlier decisions remained intact.
Negative checks refused unapproved creation, missing classification, Operations
adjudication, discarded required RA, same-source RA and replacement of a recorded
RA target. Physical maintenance remained unresolved after Quality closure.
Evidence: `output/dev-business-validation-20260926/http-issue-quality-journey.json`.
This separate result is not added to earlier overlapping HTTP totals.

**Final complete phone journey: PASS — 1/1 test on source charge 73325.** It
used the real issue and abnormality forms, canonical server reads and actual
Operations → SI → Operations account transitions. Both transition assertions
passed. SI adjudication preserved the exact actor and entered decision evidence,
and the RA target was read-only during the completed-RA closure.

| Final phone-created source record | Verified Quality result | Preserved business state |
| --- | --- | --- |
| Maintenance issue `eb834868-cac7-49db-8b6f-98714bd35286` | Warning closed as `coilFoundAcceptable`; linked case RA `notRequired`. | Physical issue remains unresolved. |
| Maintenance issue `6a098e3d-fbc7-41c1-9d38-2d226df6a5de` | Warning closed as `reannealingCompleted`; completed RA **73326** retained. | Physical issue remains unresolved. |
| Direct abnormality `a0e95ee2-4fa1-40e5-bfb9-f8e60c39a19e` | Independent warning remains open, with no RA. | Same source charge **73325**; earlier maintenance decisions remain intact. |
| Direct abnormality `4e750102-ff29-4ff6-b199-945271e7ce99` | Independent warning remains open, with completed RA **73327**. | Same source charge **73325**; earlier maintenance decisions remain intact. |

The final assertions verified exactly four canonical cases and four warnings,
both physical issues still unresolved, both recorded closure dispositions and
their SI actor/reasons, and return to the Operations account. Evidence:
`output/dev-business-validation-20260926/phone-issue-quality-final.log` contains
`DEV_ISSUE_QUALITY_PASS` for these exact identities and `All tests passed!` at
**02:34**. After the test removed its root widget, a caught `SyncCoordinator`
provider-disposed warning was logged. That residual cleanup warning is retained
separately; the passing runner does not mean the execution was warning-free.

**Earlier checkpoint: the four scenarios were verified across two sessions on
source charge 76575.** The Operations session used the real issue and
abnormality forms, accepted two maintenance-origin cases, declared/completed RA
for the second, and accepted two independent same-charge abnormalities. Each
creation was verified by canonical server readback. That test then failed during
actual UI sign-out, so its complete runner result is a failure. Evidence:
`output/dev-business-validation-20260926/phone-issue-quality.log`.

The separate SI continuation passed **1/1 integration test** on those exact
previously accepted records. Its actual Quality screens closed the first warning
as coil acceptable and the second after completed RA. Readback confirmed:

| Phone-created source record | Final Quality result | Preserved business state |
| --- | --- | --- |
| Maintenance issue `19e0b4c9-cbf9-4d3d-84e7-3ecb56fcf694` | Warning closed as coil acceptable; linked case RA state `notRequired`. | Physical issue remains unresolved. |
| Maintenance issue `64d59b55-954b-43f1-8be7-8d5843c3e168` | Warning closed after RA; completed target **76576** appeared locked in adjudication and was retained. | Physical issue remains unresolved. |
| Direct abnormality `364f643a-c590-4faf-82b3-2c7267af28eb` | Independent warning remains open; RA `notApplicable`, with no RA target. | Same source charge **76575**; maintenance decisions remain intact. |
| Direct abnormality `181c19c6-c2c7-4d13-80e7-e4e86a690b2d` | Independent warning remains open; RA `completed`, target **76577** retained. | Same source charge **76575**; maintenance decisions remain intact. |

The SI run verified exactly **four cases, four warnings and two still-open
physical issues**. Evidence:
`output/dev-business-validation-20260926/phone-quality-adjudication.log`, containing
`DEV_QUALITY_ADJUDICATION_PASS charge=76575 cases=4 warnings=4 physicalIssuesRemainOpen=2`
and `All tests passed!`. This is two-session business proof, **not a passing
end-to-end account-switch journey**. The remaining Firestore query error during
sign-out was reproduced in the critical-alarm feed's cancellation path and has
a host-tested repair below. The later complete charge 73325 run above passed;
that does not turn this earlier failed account-switch run into a pass.

The phone investigation produced five client repairs with focused host evidence:

1. Actual **Home → profile → Sign Out** reproduced a Riverpod assertion because
   `_StartupSyncGate.dispose` called `AutoSyncService.stop`, which published
   health state during widget teardown. The gate now uses restartable `detach`:
   cancel subscriptions/timers without provider access, invalidate outstanding
   callbacks, and initialize fresh health when the next actor starts. A widget
   regression reproduced the original failure; **17 focused checks passed**
   after repair. Logs: `.dart_tool/auto-sync-lifecycle-before.log` and
   `.dart_tool/auto-sync-lifecycle-after.log`.
2. The permanent Quality warning/monitoring feeds did not depend on the approved
   actor or sign-out state. Controlled-stream regressions demonstrated **two
   failures before** the repair. Both feeds now stop during sign-out or lost
   approval and resubscribe for a new approved actor; real in-session permission
   failures remain errors. **3/3 new checks passed**, and **83 adjacent Quality,
   authority and startup checks passed** (counts overlap). Logs:
   `.dart_tool/quality-session-before.log`, `.dart_tool/quality-session-after.log`
   and `.dart_tool/quality-session-adjacent.log`.
3. Home's Management pulse read a plant `AsyncError` through `.value`, rethrowing
   the original Firestore query denial. It now shows **Plant data unavailable**
   and an explicit retry signal without treating retained data as current
   evidence. Regressions cover errors with and without a previous value and
   recovery after a valid result. The focused set passed **12 checks**. Logs:
   `.dart_tool/home-pulse-query-error-before.log` and
   `.dart_tool/home-pulse-query-error-after.log`.
4. The online access gate also read a failed profile through `.value`. It now
   conceals and removes focus from retained editors during profile loading or
   error, and does not start a new access check under retained authority. Retry
   restarts the profile listener only when that listener failed; recovery still
   requires fresh matching server authority. All **5 access-gate checks** and
   targeted analysis passed. Evidence: `.dart_tool/online-access-profile-tests.log`
   and `.dart_tool/online-access-profile-analysis.log`.
5. The active critical-alarm feed used an `async*` / `await for` subscription that
   could route a queued Firestore query error into its cancellation future while
   account authority was being removed. The replacement explicitly forwards
   data and active errors and delegates cancellation to the underlying query;
   genuine active errors retain their identity and stack. The baseline reproduced
   **5 failures**. After repair, **49 focused and adjacent checks passed**,
   including cancellation ordering and existing alarm qualification behavior.
   Evidence: `.dart_tool/critical-alarm-cancellation-before.log` and
   `.dart_tool/critical-alarm-cancellation-after.log`. A subsequent phone probe
   passed the previous unhandled-query failure point but then failed waiting for
   login; this is not a passing account-switch result.

The follow-up phone probe exposed a distinct login trap: Firebase had signed out,
but a retained profile-listener error left the outer online-access overlay above
the login screen. Evidence:
`output/dev-business-validation-20260926/phone-account-probe-after-alarm-fix.log`.
A focused regression reproduced the missing login screen (**1 failure, 7
passes**). The safer repair renders the actual authentication-only `LoginScreen`
after an observable, settled signed-out auth result; it never reveals the
protected child through that branch. While sign-out cleanup is still active,
only a locked progress screen is shown. Profile errors under an authenticated or
uncertain session remain blocked. The final gate suite passed **9/9 tests**, and
targeted analysis reported no issues. Evidence:
`.dart_tool/online-access-signout-before.log`,
`.dart_tool/online-access-signout-after.log` and
`.dart_tool/online-access-signout-analysis.log`. The later full DEV phone journey
on charge **73325** passed both account transitions and all business assertions,
as recorded above.

These focused results overlap the broad runs and are not added to the final
729-test total. The separate final phone log establishes the covered complete
account-switch flow; host results alone do not.

Earlier phone attempts are preserved separately. The first stopped on an
incorrect lazy-popup test finder; the next awaited sign-out without pumping UI
frames and encountered an unattributed query error. The subsequent actual UI
sign-out isolated the AutoSync teardown defect above. They are not passing runs.
Those attempts accepted their own isolated demo records, which remain preserved.
Direct abnormality saves received a server response that their recorded time was
ahead of the server clock, then retried after about two seconds; readback
confirmed acceptance without duplication. The device/host/server clock offsets
were not measured, so the underlying timing cause is not established.

## Owner-authorized production actions and deployed timestamp repair

The installed production app is **1.0.0-rc.19, version code 29**. Build 29's source
was identified as `770f1745`; the current checkout is a descendant. That ancestry
does not place the current local client repairs in the installed app. The
separately deployed backend repair is identified by its exact candidate archive
below, not by the old release commit. Each production action below was explicitly
authorized by the owner. Public case labels replace operational identifiers;
exact identities and raw readbacks remain in ignored private evidence.

1. **Production case A, with recorded RA:** actual production Quality UI
   adjudication succeeded. Independent server readback confirmed the warning
   closed with decision `reannealingCompleted`, preserving its recorded RA target.
2. **Production case B, acceptable / no RA:** the first production UI attempt
   refused adjudication with **“The persisted quality-warning is malformed”**.
   Server readback confirmed the original warning stayed open. The failure was
   traced to native Firestore Timestamp values in nested
   `innerCoverAssociation.eventAt` and `innerCoverAssociation.confirmedAt` being
   rejected by the shared validator. A local shared-helper repair passed **440
   adjacent host tests**, with **2 existing skips**, and **2 real Firestore
   regression tests**. The latter prove atomic closure and historical replay for
   valid native timestamps, and atomic refusal of invalid chronology without an
   audit or receipt. Evidence: `.dart_tool/quality-native-timestamp-adjacent.log`
   and `.dart_tool/quality-native-timestamp-emulator.log`. **The isolated repair
   is deployed to both production abnormality endpoints**, as verified below.
   **The actual production UI retry subsequently succeeded and displayed Closed.**
   Server readback confirmed status `closed`, disposition `coilFoundAcceptable`,
   RA `notRequired` and the exact owner-confirmed decision. The linked physical
   maintenance record **was already resolved before this adjudication** and
   remained resolved afterward; its persisted update time was unchanged. Quality
   closure did not change that physical record. Exact identifiers and before/after
   readbacks remain in the ignored private output.
3. **Separately authorized production TRIAL DATA entry:** the owner authorized
   choosing a trial entry, and the actual phone created a separate whole-asset
   abnormality with RA **NotApplicable**. Both observations and description clearly
   label it as **TRIAL DATA**, with no actual fault or RA asserted. Server readback
   confirmed this new record and its own open warning. It is separate from case B,
   which subsequently closed as recorded above. No deletion or cleanup of this
   intentionally created production record is claimed. Production charge, asset
   and record identifiers are omitted from this public report.

Deployment verification passed for `mutateChargeAbnormality` and
`mutateChargeAbnormalityV2`, both `ACTIVE`. The exact candidate ZIP SHA-256 is
`4d4a6ddcef82158eb82c519cad49797c07d86987174f1a1febe7e62480f32aff`;
all **512 archive entries** matched the candidate for each deployed function.
The isolated change comprises three files. Its source remains uncommitted, so
the archive hash is the deployment identity; no unchanged Git commit is claimed
as the hotfix source.

The verified live revisions were updated at **17:15:31 UTC / 22:45:31 IST** and
**17:16:23 UTC / 22:46:23 IST** on 26 September 2026. Before/after runtime
configuration and IAM were identical; build configuration changed only for the
source, with the stale Firebase source-cache label removed. No APK, Rules, IAM
change or business-data migration was required. Evidence:
`output/dev-business-validation-20260926/quality-timestamp-deployment-verification.json`.
These deployment checks prove the bounded code/configuration change. The separate
real-UI retry and server readback establish case B's adjudication outcome. The
remaining client changes are uncommitted and await release; no replacement
production APK was needed for this backend repair.

Private server readbacks are retained only in ignored local evidence output.
This public report uses labelled cases and outcomes; it omits production charge,
asset and record identifiers, user identities and raw business records. These
individual production actions do not establish production IAM/App Check or push
delivery. The complete DEV account-switch journey and successful normal DEV
restoration have their separate evidence above; the phone was then returned to
the existing production app.
