# CRM3 App Expanded Implementation Candidate v3.3

## 1. Purpose and authority

This candidate deliberately widens the engineering canvas beyond the files changed by the v3.2 maintenance-workflow package. It uses the complete uploaded application tree as the source available for analysis, while preserving v3.2 as the frozen static-correction baseline.

The authority order used here is:

1. later user-ratified programme decisions;
2. executable policy, current source and tests;
3. reviewer findings as adversarial evidence, not governing design authority.

Accordingly, the ratified **online-only lifecycle mutation model remains unchanged**. This candidate does not reintroduce the superseded hybrid/offline lifecycle design.

This is an implementation candidate built from the uploaded v3.2 proposed repository. It is **not represented as merged into the authoritative live Git repository**. Repository and branch reconciliation remains a prerequisite before applying this patch to current main.

## 2. Expanded canvas

A generated whole-app source atlas now inventories and risk-ranks the application rather than following only the v3.2 diff:

- 320 source/configuration files indexed;
- 250 non-generated application Dart files;
- 42 Functions TypeScript source files;
- 115 test files;
- cross-cutting risk tags for authority, persistence, sync, lifecycle, notification, identity/security, serialization and remote-write concentration.

See:

- `docs/expanded_audit/WHOLE_APP_SOURCE_ATLAS.md`
- `docs/expanded_audit/WHOLE_APP_SOURCE_ATLAS.tsv`
- `tools/expanded_audit/build_source_atlas.py`

## 3. What the deeper implementation pass found

### 3.1 Four authoritative commands existed but were unreachable from the client

The server and cross-language command vocabulary contained 20 commands, but no Dart business path existed for:

- `raiseCompliance`;
- `prepareRedLane`;
- `cancelWorkflow`;
- `reconcileEquipment`.

This was not merely missing cosmetic UI. In particular, a preselected RED lane could remain pending without an operator path to execute the preparation command that releases it.

### 3.2 Compliance creation had an avoidable authority asymmetry

`raiseCompliance` checked lane authority only when `originLaneKey` happened to be supplied. A handcrafted approved client could omit the origin and bypass the intended accountable-lane relationship. The server now requires a valid origin lane and always verifies the actor's work authority on it.

### 3.3 Escalation state changed without reaching a human

The scheduled sweep incremented `escalationTier`, but did not create a workflow event. Since workflow notifications are event-driven, the escalation ladder could advance in storage without alerting the next authority tier.

### 3.4 The existing sweep shape could exceed a Firestore batch

The sweep could select up to 600 records. Once one deterministic notification event is added per escalation, each candidate requires two writes. A single batch would therefore be structurally unsafe. The implementation now uses bounded groups of 200 candidates, or at most 400 writes per batch.

### 3.5 The Pass-5 composite-index concern was already closed

All three required escalation query indexes were already declared in `firestore.indexes.json`. No duplicate or speculative index change was made.

## 4. Implemented source changes

### 4.1 Server-authoritative command reachability

The client now exposes role-gated paths for all four previously unreachable commands:

- **Raise compliance:** structured dialog with accountable origin lane, target lane, description, priority, condition, reference and optional gating lane.
- **Prepare RED lane:** shown only in the permitted workflow state and only to authorized actors; furnace placement is explicitly confirmed before submission.
- **Cancel workflow:** guarded cancellation action with a mandatory reason.
- **Reconcile equipment:** Admin/SI action that asks the server to derive state from authoritative workflow facts; the client never selects the equipment state.

All 20 authoritative commands now have at least one client entry point.

### 4.2 Role-aware compliance operations

The previous thin compliance list has been replaced by an operational inbox with:

- **For my lane**;
- **Raised by me / my lane**;
- supervisory **All** view;
- actionable filtering;
- dormant, due and overdue context;
- priority and escalation-tier visibility;
- pull-to-refresh;
- provider/repository support for complete lane and compliance projections.

The Home screen now surfaces pending lane acknowledgements and due compliance work before the user opens the workflow hub.

### 4.3 Escalation-to-human delivery

The scheduled sweep now:

- stops at Tier 3;
- uses a 20-minute suppression guard for a 15-minute schedule;
- updates the source record and writes one deterministic workflow event;
- chunks writes below the Firestore batch ceiling;
- preserves retry idempotency through deterministic event IDs.

Notification routing follows the ratified ladder:

- Tier 1: lane senior authority;
- Tier 2: Shift Supervisor and SI;
- Tier 3: Admin.

Notification payloads preserve source collection/document, lane, aggregate and escalation tier so the app can route to the relevant operational surface.

### 4.4 Authority hardening

- `raiseCompliance` cannot omit the accountable origin lane.
- New controls are hidden when the actor lacks the same authority the server enforces.
- Existing generated policy remains the source for lane-role routing.
- The online-only lifecycle model is retained without architectural backtracking.

## 5. Validation performed

### 5.1 TypeScript / Functions

- strict TypeScript build: PASS;
- 14 executable Jest suites: PASS;
- 179 executed tests: PASS;
- 3 emulator-dependent suites / 29 tests: intentionally skipped in this environment;
- new escalation policy, routing and origin-authority tests: PASS.

### 5.2 Static source audits

- expanded implementation audit: **15/15 PASS**;
- inherited v3.2 full-tree regression audit: **18/18 PASS**;
- generated TypeScript/Dart policy parity: PASS;
- Git whitespace/error check: PASS;
- patch application to a fresh clone of the exact baseline: PASS;
- changed-file byte comparison after reconstruction: PASS;
- Dart delimiter/import-path structural checks: PASS.

Evidence logs are under `docs/expanded_audit/evidence/`.

## 6. What has deliberately not been claimed

The following remain runtime gates and are not replaced by source inspection:

1. Isar generation and schema validation;
2. `flutter analyze` and Flutter tests;
3. Android/Gradle build;
4. Firestore emulator Rules and real transaction-contention tests;
5. controlled device tests for notification routing and online-only failure/form retention;
6. live repository branch/commit reconciliation;
7. production Rules, Functions or application deployment.

No GitHub push, PR, deployment, release-build reservation or production mutation has been performed.

## 7. Next implementation tranches

### Tranche A — runtime proof of this candidate

- run `build_runner` / Isar generation;
- run `flutter analyze` and full Flutter suite;
- fix any generated-schema or analyzer findings;
- run Functions/Rules emulator suites;
- execute concurrent command and deterministic escalation-event tests;
- run Android debug build and controlled notification-tap tests.

### Tranche B — complete business breadth

- implement governed ticket defer/reactivation only after extending the maintenance record/schema and migration path;
- add direct compliance-detail notification routing rather than lane-inbox routing only;
- add lane module-progress fraction and blocked-closure explanation;
- integrate workflow equipment state into fleet/timeline and admin diagnostics;
- add admin support surfaces for outbox, receipts and compliance investigation.

### Tranche C — real-repository/platform authority

Only after branch/commit reconciliation:

- reconcile Android identity, namespace, `applicationId`, Firebase app identity and Kotlin/AGP settings;
- apply the v3.2→v3.3 patch on a fresh governed branch from the proven mainline;
- run CI, review, merge and then continue the Rules/runtime/release programme.

## 8. Readiness statement

The expanded first tranche is **source-ready for runtime validation and governed integration**. It is not yet production-ready. The maintenance-workflow architecture is no longer the limiting uncertainty; the next highest-value work is to execute the runtime toolchain and then continue into the remaining business breadth on the reconciled authoritative repository.
