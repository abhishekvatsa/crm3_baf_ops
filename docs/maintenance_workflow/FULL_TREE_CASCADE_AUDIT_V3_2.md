# CRM3 Maintenance Workflow — Full-Tree Cascade Audit v3.2

## Purpose

v3.1 was strong inside the new command/transaction architecture, but the user
correctly required a broader method: do not assume that only files explicitly
patched by the feature matter. This pass reconstructs the pre-v3.1 baseline,
diffs the complete tree, follows changed shared types/services into untouched
consumers, and reopens already-touched files at the next lower call-path layer.

## Audit method

1. Reconstructed the exact pre-v3.1 tree by reverse-applying the package patch.
2. Compared the whole proposed repository rather than the advertised patch
   subset.
3. Built the reverse-import surface from changed Dart files into untouched
   consumers.
4. Traced central entities and vocabularies through serializers, Firestore
   writes, rules, pull/push orchestration, notification delivery, permissions,
   UI navigation and generated policy.
5. Mechanically inspected every `JobModuleDiscipline` and
   `JobDiaryDiscipline` switch in `lib/`, excluding generated `.g.dart` output
   that must be regenerated.
6. Inspected string-to-discipline parsers separately; this found semantic
   collapses that an enum-switch scan alone cannot find.
7. Re-ran policy generation, TypeScript strict compilation and the complete
   available Functions test suite.
8. Added a repeatable source-only full-tree audit script. It currently reports
   **18/18 PASS**.

## Surface explored

The original v3.1 package modified 126 source files, while the app contained
303 additional source-like files outside that change set. The reverse-import
map found 122 untouched Dart files importing one or more changed files.

v3.2 deliberately modifies:

- **14 already-touched files**, revisited at deeper call-path level;
- **9 previously untouched pre-existing files**, changed only after a proven
  cascade was found;
- **3 new audit/test/policy-helper files**.

The nine previously untouched files are:

1. `functions/src/notifications.ts`
2. `functions/test/notifications.test.js`
3. `lib/features/planned_maintenance/domain/published_runtime_module_catalogue.dart`
4. `lib/features/planned_maintenance/domain/template_version_assignment_builder.dart`
5. `lib/features/planned_maintenance/presentation/dossier/planned_job_detail_common.dart`
6. `lib/features/planned_maintenance/presentation/job_module_detail_screen.dart`
7. `lib/features/planned_maintenance/presentation/module_composer_screen.helpers.dart`
8. `lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart`
9. `lib/features/planned_maintenance/presentation/widgets/job_module_card.dart`

## Valid defects fixed by reopening touched paths

### 1. Client/server execution serialization boundary

The live batch push used `JobExecution.toMap()` instead of the purpose-built
client-safe map. Firestore Rules failed safe, but normal execution sync could
be rejected whenever server-owned workflow state differed locally.

v3.2:

- changes the batch writer to `toClientWritableMap()`;
- discovers and fixes a second omission: `workflowSchemaVersion` was also
  server-owned in Rules but had not been removed by the safe map;
- defaults new unproven local `JobExecution` objects to schema 0 so a constructor
  cannot accidentally claim an aggregate exists.

### 2. Mature-sync/control-plane coupling

The workflow retry and pull were awaited inside the same catch boundary as the
mature application sync. A supplemental workflow failure could mark the entire
sync failed after the mature push/pull had succeeded.

v3.2 isolates workflow retry and projection pull. Within the workflow pull,
each collection is also isolated: a malformed lane document no longer prevents
compliance, equipment, prompt and event pulls from being attempted.

### 3. Notification delivery chain

The workflow notifier had three integration gaps:

- parallel role routing;
- no reuse of race-safe dead-token cleanup;
- no working tap destination.

v3.2 derives lane recipients from generated policy, uses the mature shared
notification sender, passes workflow deep-link data, adds a leased idempotency
receipt with retry, and resolves notification taps through the authenticated
HomeScreen to the actual workflow panel.

### 4. Role universe drift

The callable's supported role set was manually maintained beside generated
lane policy. v3.2 generates the complete role universe from the same JSON
policy and consumes it in the callable.

## New defects found only in previously untouched files

### 1. Non-exhaustive discipline display switches

The new `emd` and `refractory` enum values were not handled in several existing
module/detail/dossier/assignment widgets. These are not merely cosmetic: an
exhaustive switch can block analysis/compilation, while a default can silently
misclassify.

All affected untouched switches now explicitly label and colour EMD and
Refractory.

### 2. Composer ownership collapse

`module_composer_screen.helpers.dart` mapped unrecognised disciplines to
`others`. EMD and Refractory therefore lost their identity when crossing the
owner bridge. Both now map explicitly.

### 3. Published-template parser collapse

Two untouched parsers still implemented the pre-enum world:

- Refractory was mapped to `others`;
- EMD fell through to `shared`.

Both `published_runtime_module_catalogue.dart` and
`template_version_assignment_builder.dart` now preserve first-class EMD and
Refractory for newly published work.

### 4. Historical `others` operability

Before Refractory became first-class, historical records could legitimately be
stored as `others`. The v3.1 permission change made those records inaccessible
to Senior Refractory. v3.2 restores that compatibility without undoing the
separately agreed Operations authority.

## Concerns closed without unnecessary code

- Firestore workflow timestamp parsing already accepts native `Timestamp`.
- Workflow joins do not consume the device-local lane execution id, so a second
  transported-DB repair pass is unnecessary.
- Workflow visibility is not actually restricted to a supervisory subset;
  `canViewPlannedMaintenance` is approved-user visibility.
- Per-collection workflow watermarks are an explicit architecture choice. They
  remain, with improved isolation and observability rather than forced merger
  into the mature data-plane cursor.
- Online-only lifecycle is a ratified decision, not a regression to reverse.

## Remaining gates that source review cannot satisfy

1. `dart run build_runner build --delete-conflicting-outputs` for all Isar
   adapters, including the modified generated models.
2. `flutter analyze` and the full Flutter test suite.
3. Firestore emulator suites, including rules and transaction contention.
4. Android build and a controlled on-device matrix:
   - online assignment and completion;
   - explicit no-connectivity rejection with form retention;
   - uncertain response/receipt retry;
   - notification tap from background and terminated state;
   - sync with one malformed workflow projection;
   - legacy in-flight `others` module under Senior Refractory.
5. Live scheduler/escalation suppression proof.

No pilot/deployment claim is made until these gates pass.
