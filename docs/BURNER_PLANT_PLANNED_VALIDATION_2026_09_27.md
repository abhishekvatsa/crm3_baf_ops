# Burner, physical inventory and planned work — 27 September 2026

Status: scoped repairs and DEV business verification complete; normal DEV app
restored on the connected phone. Not production release approval.

The owner asked for burner-block/associated workflows, incorrect Build29 asset
counts across Plant condition and other surfaces, and practical validation of
planned maintenance before it is first used operationally. All earlier local
changes remain preserved on `claude/dev-loop-seeding`.

## Scope and evidence standard

- Compare physical inventory consistently across Home, Plant condition and
  Operations reports. Keep uncertain condition distinct from missing equipment;
  do not count a serial cover and its numbered placeholder twice.
- Verify full/partial burner rounds, critical I&A directions, unchanged evidence
  attribution, unresolved damage, physical maintenance action dates, burner/UV
  installations and reasoned historical correction/replay.
- Exercise real template publication, assignment, accountable lanes, recorded
  work, supervisor review, diary, assurance, closure and counter effects.
- Use real UI/repositories and authenticated Firebase emulator requests with
  canonical readback. Setup fixtures are distinguished from business actions.
- Preserve the separate DEV package and existing emulator evidence. No production
  business writes, deployment, release, commit or push belongs to this pass.

## Repaired findings

1. Plant totals omitted registered assets when class evidence was missing;
   cumulative warnings could affect unrelated assets according to input order.
2. Home/Plant and reports used different Inner Cover populations. Shared physical
   inventory must count extant serial covers, excluding consumed/disposed stock,
   and omit duplicate numbered placeholders.
3. Legacy workflow resolution against isolated one-asset slices could bypass
   ambiguity in the complete asset register.
4. Burner reliability dated action readings by ticket closure/update, making late
   administrative closure look like new physical evidence. Non-restoring retained
   attendance also needs inclusion without falsely closing the issue.
5. Burner report stream failures with retained data could throw or show stale
   totals instead of a clear error and retry.
6. Remote template publication mutated the caller while persisting an unchanged
   draft candidate. Publication must atomically commit the actual candidate and
   leave the caller unchanged when refused or failed.
7. Final planned-work assurance looked answered "No" while its answer was still
   unset. Explicit Yes/No choices now distinguish no answer from a recorded
   decision, including whether preparation is required.
8. Accepted burner/UV correction retries returned native Firestore timestamp maps
   where the first reply returned ISO dates. The receipt response now canonicalizes
   only the known correction date fields; stored evidence, actor checks and audit
   verification remain intact. Invalid or submillisecond dates are refused.
9. Reports could rebuild serial-cover rows from raw data and lose Home/Plant's
   per-cover uncertainty or retained evidence. They now preserve that qualification.
   Home's high-risk total includes unfit covers in the same physical population.
10. A malformed issue-closure record could make the fleet incomplete without
    marking its exact asset uncertain. The qualification now follows the asset.
    A new real widget test also caught and fixed a missing Material ancestor for
    serial-cover rows on the Plant condition board.
11. **Phone-confirmed, repaired and rechecked:** first-attempt Burner/UV directive
    closure rejects the newly opened query's initial cached snapshot before fresh
    server evidence arrives. The real phone reported "Data is not yet
    server-confirmed for this approved session" before sending any closure
    callable. Acknowledgement was already persisted correctly. The correction
    now reads the current pointer and referenced round explicitly from the server,
    validates metadata/identity, and checks the approved actor/session before and
    after the read. It times out after 20 seconds and preserves permission/offline
    failures. The general watched-stream admission policy is unchanged.
12. **Phone-confirmed, repaired and freshly published on attempt07:** resuming a reviewed template draft and
    publishing a successor copied the earlier review sign-off while resetting
    creation time. The new draft then failed its own strict reader and disrupted
    template synchronisation. A successor needs explicit fresh review and a
    valid creation/review/save chronology. Successors now clear the inherited
    attestation, retain predecessor lineage, and require explicit review of their
    required modules/fields. Cancel writes neither package edits nor a successor.
    Actor approval is rechecked after asynchronous steps. Both native and remote
    saves strictly validate the candidate before writing and preserve its
    legitimate creation time before the new review.
13. **Phone-confirmed and repaired:** a published version could be accepted while
    its package and audit remained rejected. An Isar round trip changed the
    package's immutable `createdAt` from its original UTC string into local-time
    text. Both package writers now compare the timestamp instant and preserve
    the original stored representation only when it is unchanged. The equivalent
    ordinary-draft version update defect was reproduced and repaired too.
    Published audits wait for their canonical package dependency to converge.
    Firestore Rules and permanent-rejection quarantine remain unchanged; existing
    held work must use the normal explicit **Recheck with server** action.
14. **Phone-confirmed recovery access gap:** the detailed Sync health panel was
    reachable only inside the Admin data browser, although an approved SI can
    legitimately publish templates and needs to recheck their saved rejected
    writes. Home's ordinary retry deliberately does not release those holds.
    More → Sync health now opens the existing shared panel. Non-Admins see only
    their own rejection details; an explicit recheck action remains reachable
    even when the recent-row limit excludes older holds. Account changes and
    revoked approval block captured actions, and Admin resolution/removal retain
    their separate checks. Navigation/recovery adjacency: 33/33 passing checks
    across five files; focused analysis clean across three entrypoints.
15. **Phone-confirmed assignment blocker:** a freshly published template with a
    six-digit fractional review timestamp had a different content fingerprint in
    Dart and JavaScript. The backend dropped the final three digits when deriving
    its closure-review hash fields. The exact immutable DEV version reproduces
    `version-hash-mismatch`; no job or assignment receipt was created. A bounded
    repair now preserves Dart's canonical microsecond precision and also permits
    the exact recomputed historical JavaScript digest. Both hash the complete
    payload, including raw snapshot JSON, so changed content or changed review
    microseconds still invalidate both. Shared Dart goldens: 9/9; focused backend
    checks: 73/73, including assignment/replay without duplicate writes. Read-only
    revalidation of the exact phone version and audit passes with unchanged
    evidence: `output/dev-planned-validation-20260927/template-hash-actual-readback.json`.
16. **Phone-observed, reproduced and repaired:** a SharedPreferences reload during
    a cursor save could replace the optimistic cache with older data and report a
    false global-pull failure. Conversely, checking only the optimistic cache
    could miss absent/corrupt persisted bytes. The cursor now reloads persisted
    preferences after a successful write acknowledgement before the unchanged
    exact-equality check. There is no cursor migration or automatic advancement.
    The real method-channel/storage regression selection passes 16/16, including
    interleaved reloads, absent/corrupt persisted bytes and native failures.
17. **Phone-observed, reproduced and repaired:** saved-assignment retry feedback could
    disappear when the parent's evidence refresh destroyed the child that held
    the error message. The same request's child now remains mounted during an
    explicit evidence refresh, with its actions disabled until the refresh ends.
    Prior failure feedback is hidden during a retry or refresh, then the final
    explanation returns when idle. The stored explanation also appears after
    reopening. Account verification
    still runs before any retained entries are shown, and changing request identity
    replaces the child. The actual parent/controller widget regression failed
    before the repair; all four saved-assignment UI checks now pass, including
    hidden entries while account verification fails, hidden stale feedback during
    a gated retry, and unchanged retry envelopes.
    Focused three-entry analysis is clean. Evidence:
    `output/dev-planned-validation-20260927/saved-assignment-message-before.log`,
    `saved-assignment-message-after.log`, and `saved-assignment-message-analysis.log`
    in the same directory. These UI checks do not claim server acceptance.
18. **Phone-confirmed worker-save blocker:** the accepted job's worker findings
    were retained locally but the module update was refused because both
    immutable `createdAt` and `addedAt` changed from their original UTC wire
    values after an Isar round trip. Independent authenticated readback confirms
    the approved worker, open job, acknowledged Mechanical lane and draft
    transition satisfy their authority rules. Module direct/batch writers now
    preserve exact creation/addition values only after same-instant checks, and
    retain unchanged lifecycle evidence. New lifecycle and update times are UTC.
    Genuine origin edits still fail before transport; Rules are unchanged.
    Independent review found no blocker. Module adjacency passes 80/80 across
    seven files, including 23 actual Isar/writer/transition regressions; analyzer
    clean across five entrypoints. Evidence: `module-wire-adjacent.log` and
    `module-wire-analysis.log` under `output/dev-planned-validation-20260927/`.
19. **Reproduced and repaired in sibling writers:** execution and diary edits
    could rewrite immutable creation timestamps after local persistence. Direct
    and batch writers now preserve the exact server value only after a same-instant
    check. New creation and changed update timestamps are UTC; unchanged historical
    update values remain intact. Diary transaction audits retain exact raw before
    and after states, accepted retries make no write, and stale review versions or
    changed origins are refused. Real Isar-to-writer checks: 25/25, plus 6/6 existing
    diary precondition checks; five-entry analysis is clean. Only the Firestore
    transport is replaced in these host checks; Rules were inspected and unchanged.
    Evidence: `output/dev-planned-validation-20260927/planned-record-wire-before.log`,
    `planned-record-wire-after.log`, and `planned-record-wire-analysis.log`.
    Field-scoped lifecycle operations do not resend creation fields.
20. **Reproduced and repaired in the registry:** full-map family/revision writes
    changed native Timestamp or offset-string creation evidence. Revision retirement
    could also rewrite prior publication timestamps. Registry transaction writers
    now preserve unchanged date values, require the original creation instant, and
    use UTC for genuinely new/changed dates. Supplied origin changes and stale draft
    reviews fail without a write. Eight real-repository checks cover draft edit,
    publication and both retirements, alongside 12 existing registry checks: 20/20.
    These remote-only models have no Isar path; the test replaces Firestore transport
    and checks the pinned creation/publication contracts without changing Rules.
    Evidence: `output/dev-planned-validation-20260927/registry-creation-wire-before.log`,
    `registry-creation-wire-after.log`, and `registry-creation-wire-analysis.log`.
21. **Phone-confirmed coordinator lifetime defect:** a completed sync left an
    uncancellable five-second status callback that read its disposed provider
    owner during app teardown. The same callback could clear a newer run's
    success. Actual ProviderContainer regressions reproduced those failures and
    post-disposal continuation during push, pull, workflow and paused recovery.
    Ten tests failed against the prior source. The repair now cancels timers at
    new-run admission and disposal, binds callbacks to their run generation,
    stops later phases/provider access after disposal, and clears queued work.
    An already-started repository/recovery operation may finish; subsequent
    coordinator work stops and recovery guards still release. Total adjacency:
    51/51 across nine files, including the ten red-to-green lifetime checks;
    analyzer clean across two entrypoints and two independent reviews clear.
    Evidence: `coordinator-lifetime-{before,after,adjacent,contracts,analysis}.log`
    under `output/dev-planned-validation-20260927/`. No data protocol, Rules or
    backend change is involved.

## Physical inventory rule

Count active numbered physical assets (including standby or out-of-service
equipment), omitting numbered Inner Cover placeholders. Add serial Inner Cover
profiles still physically held. Disposed covers and fully consumed donor covers
are excluded; covers retired for salvage remain physical stock and are unfit.
Missing or retired class evidence does not remove an extant registered asset.
Uncertain rows remain visible and prevent a misleading complete-fleet percentage.
Components are not additional whole assets. Registry history remains available
with labels distinguishing its registration entries from physical stock totals.

The furnace condition matrix supports registered Furnace numbers 1–26, matching
the existing server command boundary. It now labels that range, shows the number
displayed out of the active registered Furnace population, and discloses the
count excluded from the matrix. Those excluded records still belong in the
shared physical inventory; matrix totals describe only its supported rows.
The existing matrix widget checks cover both an excluded Furnace27 and a full
1–26 matrix, including the existing narrow-screen and enlarged-text checks.

This proves consistent DEV calculations, not a production stocktake or a
certification of the actual physical inventory at the plant.

## Verification record

Completed checks so far:

- Planned work: final **497/497 Flutter tests across 65 files**, with no skipped
  tests or failures; analyzer clean across 15 runtime/test entrypoints.
  Real authenticated emulator journey 28/28, including cross-agency compliance,
  reopen/reaccept, closure, exact-once counter effects and replay.
  The final selection includes actual publisher confirmation/cancellation,
  authority revocation during asynchronous saving, native and remote prewrite
  chronology checks, real Isar timestamp round trips through both writers,
  retained creation evidence and rejected origin edits, package-aware audit
  dependencies, and publication/replay adjacency. The repaired DEV draft also
  passed a separate strict decoder/hash readback.
  Manifest: `output/dev-planned-validation-20260927/planned-review-final-tests.txt`;
  machine results: `planned-review-final-tests.jsonl`; exact counts and duration:
  `planned-review-final-summary.json`; analyzer: `planned-review-analysis.log`
  in the same directory. `review-timeline-focus.log` records the earlier 30
  focused checks including the actual repaired-draft readback. Timestamp
  reproduction and repair logs are `package-origin-before.log`,
  `package-origin-after.log`, `version-origin-before.log`, and
  `version-origin-after.log`. The separate authenticated Rules regression is
  recorded below; it does not replace the repository and phone checks.
- Burner/UV: 161 Flutter tests across 20 files; focused analyzer clean.
  Actual HTTP journey 12/12 (32 callable requests), including both replacements,
  late historical entry, reasoned correction, deterministic replay and refused
  unauthorized/stale requests on a separate DEV Furnace02 fixture.
  The subsequent phone-found preflight repair has an additional 67-test adjacent
  check, including 15 server-read/session regressions; analyzer clean. Independent
  review found no second identical one-shot command consumer of the trusted
  snapshot stream.
- Inventory/reporting: 138 tests across 11 files; analyzer clean across 17
  runtime/test entrypoints. Includes actual Home-to-board widget navigation.
  The later matrix range disclosure passed all 12 existing condition-totals
  widget checks and focused analysis of its screen/test. Evidence:
  `output/dev-burner-planned-20260927/matrix-range-disclosure-tests.log` and
  `matrix-range-disclosure-analysis.log` in the same directory. These checks
  overlap the burner suite and are not added as unique workflow coverage.
- Backend compiled output and callable/notification inventories pass.
- Final full backend Jest after the fingerprint repair: 81 host suites,
  2,440 passed and zero failures; 22
  emulator-gated suites / 249 tests skipped in that host run. Separately, eight
  selected native-Firestore UV replay cases passed. Auxiliary backend checks:
  81 passed. Focused burner/UV backend selection: 296 passed.
- Connected phone Home/Plant agree on 61 DEV physical records: 57 numbered assets
  and 4 serial covers. This is a synthetic fixture total, not the plant total.
- Connected phone burner journey07: **passed in 1:02**. Round
  `5dc637e7-d161-4141-803b-e56011065b62`, its generated I&A directive, and compliance
  round `b8003a68-fb65-4f0c-8854-b1f9139aeb75` were checked by authenticated server
  readback. The loaded matrix showed red-hot; compliance preserved red-hot and UV
  damage, removed the now-inapplicable targeted flame signal, and retained B2's
  original reading/source/time. The unrelated malformed trial template still
  caused a template-pull warning during this run; it was subsequently repaired
  and checked through the strict reader before the next phone journey.
- Independent authenticated final readback of the original planned job:
  **17/17 passed** at `2026-09-26T21:40:08Z`. Job
  `689iHtPriryiM6Oq89Qy` and module `OXpWVknCDmyqsZM7ZVWc` retained the exact
  original assignment intent, worker submission, distinct SI acceptance and
  diary `azX0xOPgY8abQcOgiH5c`. Lane/job closed with explicit No RED; original
  creation/addition strings and published-template business fields/hash remain
  unchanged. Evidence: `output/dev-burner-planned-20260927/phone-planned-final-readback.json`.
  This timestamped snapshot precedes the intentional fresh assignment in
  attempt13. It proves the original retry did not duplicate its job; it does not
  assert that the version may never have another legitimate assignment.
  Server-only receipt records were not accessed; uniqueness was verified from
  authorized job projections and preserved pre-work evidence.
- Final connected-phone planned journey14: **passed in 1:41**, including normal
  app teardown. Fresh job `cNxwKsAxlvSC3EptFMyf`, module
  `H2fEi5wxtajcLFBDILQ3`, diary `S0y4RyqI0bx2F3bBX7k3`, charge 64418.
  The real UI assigned the published package, classified/acknowledged the lane,
  saved and submitted findings under ContractSupervisor, accepted under SI,
  recorded handover, closed the lane, explicitly selected No RED, and completed
  the job. Canonical readback after the actions confirmed the results and an
  unchanged published template. Publication itself was performed through the
  fresh-review UI in attempt07; journey14 reused that immutable published version.
  Evidence: `output/dev-burner-planned-20260927/phone-planned-14.log`.
  The earlier lifecycle-teardown failure is absent without suppressing errors.

Both final phone workflows and the consolidated backend checks have passed. Test
groups overlap; their counts must not be added as unique coverage. Partial or
failed attempts are retained as diagnostics, not presented as passes. Emulator
testing does not establish production push delivery, IAM, App Check, release
signing or Play distribution.

The ordinary `lib/main.dart` DEV app was rebuilt and launched successfully after
the integration tests, preserving its data. Its startup confirms
`demo-crm3-baf-ops` and local emulator endpoints. The restored Home screen is
recorded in `output/dev-burner-planned-20260927/restored-dev-home.png`; it shows
the 61-record inventory denominator and explicitly incomplete condition evidence.
The launch log is `restore-normal-dev.log` in that directory. The production
package was not installed, cleared or changed. No production deployment, commit,
push or release was performed. Shared runtime repairs need the next reviewed
backend/client rollout; the DEV emulator results do not claim that rollout.

### Burner evidence and timing checks

- `output/dev-burner-validation-20260927/http-burner-lifecycle.json` records the
  12 passing checks and 32 authenticated callable requests. The final run used
  prefix `hj-burner-life-d8a11aef0abf` and position 5 on DEV Furnace02. All six
  replacement issues were resolved. Its separate
  `http-burner-event-readback.json` contains two authenticated, read-only checks
  of all six retained events, including late entries and distinct physical,
  completion and recording times; it made no further callable requests.
- `.dart_tool/installation-replay-before.log` records the two native-timestamp
  replay failures before repair. `.dart_tool/burner-uv-backend-after.log` records
  296 passing focused checks; `.dart_tool/burner-uv-native-replay.log` records
  eight selected native-Firestore replay cases in the separate
  `demo-crm3-burner-native` project (27 unrelated cases were not selected).
- `.dart_tool/burner-compliance-preflight-before.log` reproduces the phone's
  exact first-cache rejection. `burner-compliance-preflight-after.log` records
  15 passing regressions; `burner-compliance-adjacent-tests.log` records 67
  passing checks including those 15. The corresponding analyzer log is clean.
- `output/dev-burner-planned-20260927/phone-burner-07.log` contains the completed
  `DEV_BURNER_PLANT_PASS` record and the phone test's passing result.

The server reader is a command preflight, not an atomic reservation. It checks
the approved actor before reading, after receiving the current pointer and after
resolving the round; replacement, revocation and sign-out invalidate the pending
result. Both reads require server metadata without pending writes. If another
round becomes current afterward, the existing compliance transaction refuses the
stale `expectedCurrentRoundId`. A 20-second timeout ends the attempted closure;
the underlying read may finish later, but this read-only helper cannot submit a
command or turn that late result into an accepted closure.

## Phone-test diagnostics and remaining UX observation

Early burner attempts stopped before round submission because the global movable
critical-alarm shortcut intercepted the UV menu tap. An actual screen capture
showed Critical safety opening; this was not a burner menu or server rejection.
The phone helper now moves that shortcut aside using its supported drag gesture,
without hiding it, invoking private callbacks, or weakening business assertions.
The overlap is a genuine discoverability/usability limitation of the global
floating control. Reliable permanent avoidance needs a reserved location in app
navigation; merely changing its default position would move the collision.

Attempt04 saved a real trial round with UV already melted; by existing policy it
correctly had no new UV-in-service directive. The test scenario was corrected to
start with a red-hot burner and serviceable UV, then record melted UV during I&A
compliance. Attempts05/06 exposed the genuine first-query closure defect above;
attempt06 captures the actual visible error immediately. Those accepted DEV
rounds and acknowledgements remain intact and are not claimed as completed
business journeys.

The dedicated DEV Furnace02 is registered under the existing seed Furnace class,
with asset ID `e2e29b4d-7385-56b5-8496-cb4916514733`. One initial backend harness
attempt left the open issue `hj-burner-life-5f4d095a1f9a-burner-first`; that attempt
did not install a component. Earlier accepted burner trials at positions 6–8,
the final position-5 burner/UV events and their correction receipts remain as
DEV evidence. No repair, withdrawal or production outcome was fabricated to tidy
these trial records, and the lifecycle harness did not change phone Furnace01.

Planned attempt01 created an unpublished, unassigned malformed trial draft
`CIAb5zVyHPQ352VP55yu`. Its exact original/raw readback and empty publish/assignment
linkage checks were retained under
`output/dev-planned-validation-20260927/review-fixture-repair/`. An authenticated
DEV SI conditional write cleared the invalid inherited review and updated its
version to 3. It remains explicitly unreviewed. Identity, creation time, lineage
and all unrelated fields were preserved; no fresh review was fabricated. Its
strict Dart readback and content hash passed before retrying the phone flow.

Planned attempt03 correctly stopped publication because the earlier held package
and audit still made pre-publication synchronization unsuccessful. Attempt04
used an incorrect harness assumption that the detailed sync widget was on Home;
it stopped without changing business records. Attempt05 then established that
the actual Administration entry was absent for SI. Neither attempt is counted as
a passing planned-work journey. Recovery is being tested through the visible
shared Sync health route, without clearing the application store or bypassing
permanent-rejection safeguards. Attempt06 reached that actual sheet but tapped
during startup synchronization while the recheck button was disabled. The harness
now waits for the real enabled state before tapping; no business safeguard was
relaxed. Attempt07 successfully recovered the old package/audit and published
`QM6p97u2S7tttDk32vpZ` through the fresh review screen with zero push failures,
then discovered the fingerprint mismatch on assignment. Attempt08 retried the
same saved envelope; its rejection is not counted as completed work. The request
remains actor-bound and retained, with charge 68568 and uniquely marked DEV
remarks. The original published version, audit and request were not rewritten
to manufacture acceptance.

Attempt09 accepted that exact retained request and created the single execution
`689iHtPriryiM6Oq89Qy`. Its harness mistook the old failure message still visible
during retry for a new refusal; the saved-assignment feedback repair above fixes
that confusing display too. Attempt10 recovered the accepted response, classified
and acknowledged its Mechanical lane, then exposed the worker-save timestamp
defect. Attempt11 used the original worker's **Recheck with server**: one saved
module change succeeded with zero failures. The worker submitted, and the separate
SI accepted the module, with server readback after both transitions. Its test then
stopped because a `.first` finder evaluated before the lazy diary section was
scrolled into view. This is a harness navigation failure, not a failed acceptance;
the accepted evidence remains intact. Attempt12 resumed that same job/module,
saved its diary, closed the lane, explicitly answered RED No and completed the
job. All final server assertions, including unchanged published-template
evidence, passed. The harness then failed only while navigating Home after the
completion screen had begun its own route transition. Its overall test result
is retained as failed; successful business closure is reported separately.
Attempt13 removes that unnecessary final navigation and starts a fresh synthetic
assignment against the same reviewed version, preserving the original closed
job and all its evidence.
Its fresh job `DPguOWL4IlTalArBxPZn`, module `aGBhiGoXnB991MGTPzsZ` and diary
`OqABa8BWpdw3Wj4FRfRc` (charge 65543) passed every business step and final
canonical assertion. Teardown then exposed an actual coordinator lifetime bug:
its five-second delayed success reset read an already disposed provider owner.
The overall attempt remains failed despite its business-pass marker. The
coordinator's delayed callback and asynchronous disposal boundaries were repaired
and regression-tested before attempt14. No error handler was suppressed and the
phone harness still disposes the app normally after business assertions.
Attempt14 then passed the complete fresh assignment-to-closure journey and
teardown. The original recovered job and the fresh jobs from attempts13/14 all
remain completed, clearly marked DEV evidence; none was deleted to tidy results.

### Package timestamp Rules diagnostic

Planned attempt02 successfully published version `Ok3vJRHTVFbPiJOPQ6ek`
(revision 3, version number 3), but its package update was refused. At the
diagnostic readback, `dev-usability-planned-package` remained revision 1 with no
active version and latest version number 0; no publication audit or execution
existed for that version. The audit refusal followed the package failure, since
the audit rule requires the package's version number to cover the published
version. This was not a failed version publication.

An independent authenticated Rules probe passed six checks across UTC-string and
native Firestore Timestamp creation fields: rewriting the same instant as local
ISO text was refused, preserving the original wire value allowed the update,
and changing the creation instant was refused. Rejected writes left both stored
fields and update time unchanged. Rules were not altered or bypassed. Evidence:
`output/dev-planned-validation-20260927/package-timestamp-rules/hj-package-time-cf0aa328d0ad/report.json`,
with raw before/after records beside it. The two synthetic, unassigned packages
`hj-package-time-cf0aa328d0ad-utc-string` and
`hj-package-time-cf0aa328d0ad-native-timestamp` remain as DEV evidence; neither is
the phone package and neither has a published version. This probe verifies the
Rules contract, not the later client repair or a completed planned phone journey.
