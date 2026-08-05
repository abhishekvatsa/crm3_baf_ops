# A-05 Persisted-State Integrity Tranche 2

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Decision

This tranche removes silent component-action loss across maintenance tickets,
planned-job executions and runtime job modules. It also makes malformed saved
action evidence visible in the relevant operational screens and blocks every
reviewed mutation or synchronization path until that evidence is repaired.

It does not close `A-05`, inspect or repair production records, change the
programme gate count, authorize deployment, or authorize pilot handout.
Existing records still require a governed inventory and reconciliation
decision before the stricter mutation paths are enabled for pilot use.

## Canonical Component-Action Contract

The Flutter and Functions validators now agree on the persisted action shape.
Each row requires:

- non-empty `asset` and `component` strings;
- a known `actionType` and `severity`;
- a boolean `isAutoResolved`;
- a valid persisted `createdAt` instant;
- an integer `version` of at least one.

Present optional fields must retain their declared types. Unknown extension
keys are preserved. A wholly absent top-level action field remains compatible
with records created before actions were introduced and initializes as `[]`.
A present empty string, malformed JSON, wrong root type, sparse row, invalid
timestamp, unknown enum or wrong-typed field is rejected.

This is intentionally stricter than the historical broad decoder. It may
surface legacy rows that previously appeared as zero actions. That is an
integrity signal, not a reason to erase or automatically rewrite those rows.

## Client And UI Behavior

`MaintenanceRecord`, `JobExecution` and `JobModuleInstance` expose explicit
action read results. Their authoritative getters throw on malformed state;
they no longer return an invented empty list.

Maintenance resolution, planned-job completion, planned-job dossiers, module
cards, module dossiers and module workspaces now display a repair state rather
than `0 actions`. Add, save, lifecycle and completion commands are disabled or
rejected while saved action evidence is invalid.

Valid existing actions are loaded into maintenance resolution and planned-job
completion forms. Adding a new action therefore appends to the saved evidence
instead of replacing it.

The admin ticket browser also shows the repair state and disables editing.
Admin edits now preserve actions on already-open tickets. A resolved-to-open
admin transition archives the current closure and clears only the action set
that has just been archived. The Firestore admin update writes both
`actionsJson` and `resolutionHistoryJson`, closing the prior history-persistence
gap.

## Repository And Sync Boundaries

Local and Firestore ticket save, edit, resolve and reopen paths validate both
action evidence and resolution history before writing. Planned-job completion
and every reviewed module save or lifecycle transition validate saved action
evidence before mutation.

The ordinary maintenance push path records malformed local evidence as a sync
failure and does not fall through to the generic batch upload. The live remote
mirror no longer coerces a non-string Firestore value with `toString()`. It
validates action and resolution-history payloads before any Isar write, and
mapping failures now remain inside the existing sync-health error boundary.

Tombstone and diagnostic paths no longer dereference malformed actions merely
to calculate an empty/non-empty decision or count. Diagnostics report the
state as `invalid` without manufacturing a count.

## Server Authority

The shared Functions validator is applied to:

- direct planned-job completion requests;
- the saved execution before planned-job closure;
- every non-deleted module used for closure readiness;
- maintenance-workflow finalization requests and the saved execution;
- runtime module population;
- maintenance workflow correction and resolution-history archiving.

Malformed request payloads return stable `invalid-argument` failures. Invalid
saved evidence returns stable `failed-precondition` failures. The maintenance
bridge no longer catches malformed history and replaces it with an empty list.
It validates existing history rows and nested action payloads, preserves
unknown extension keys, and serializes Firestore/native closure timestamps as
ISO text before embedding them in history JSON.

## Regression Evidence

The focused Flutter regressions prove valid extension-preserving round trips,
malformed and sparse rejection, wrong canonical payload-type rejection,
nested-history rejection, visible repair states, mutation blocking, admin
open-edit preservation, and strict sync-source contracts.

The Functions regressions prove the shared schema, stable callable error
mapping, saved execution/module rejection, runtime admission rejection, and
no-loss maintenance history behavior.

Local verification for the reviewed source is:

- `flutter analyze --no-pub`: no issues;
- focused A-05 Flutter tests: 18 passed;
- full Flutter suite: 663 passed;
- full Functions unit suite: 367 passed, 63 emulator-only skipped;
- governed Firestore Rules suite: 152 passed;
- governed Functions emulator suite: 63 passed;
- Functions emitted-output, callable and notification inventories: passed;
- canonical source and governance audit: 113 of 113 passed.

Pull-request CI and admitted-main CI remain required before this source tranche
is accepted.

## Reconciliation Update

Twenty-four captured canonical paths receive reviewed successor hashes. Four
were previously byte-identical and now become `SUCCESSOR_MODIFIED`:

- `lib/core/services/sync_service.executions.dart`;
- `lib/core/services/sync_service.tickets_templates.dart`;
- `lib/features/admin/presentation/admin_data_browser/admin_tickets_browser.dart`;
- `lib/features/planned_maintenance/models/component_action_model.dart`.

The reconciliation aggregate therefore moves from `255 / 155` to
`251 BYTE_IDENTICAL / 159 SUCCESSOR_MODIFIED`. No canonical path is removed.

## Remaining A-05 Scope

`A-05` remains open for persisted response payloads, template fields,
validation payloads, module-composer defaults, remaining persisted timestamp
fallbacks, remote tombstone authority, other silent JSON catches, and a
governed legacy-data inventory and repair path.

This tranche is source and local verification evidence only. It does not
inspect or mutate production documents, alter Firebase settings, deploy
Rules or Functions, produce physical-device evidence, close a programme gate,
close `A-05`, or authorize pilot handout.
