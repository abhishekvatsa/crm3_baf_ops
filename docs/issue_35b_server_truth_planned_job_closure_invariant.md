# Issue 35B — Server-truth planned-job closure invariant

## Status

Safe-now source patch: **closure guard extracted and regression-tested**.

Server-truth enforcement: **schema/function-stage**, not patched in this issue.

## Current invariant

A planned job may be completed only when every active `JobModuleInstance` marked
`requiredForClosure == true` is closure-ready.

The current app-side closure guard blocks completion when a required module is:

- still open (`notStarted`, `draftSaved`, `inProgress`, `reopened`);
- submitted but not accepted;
- accepted but missing required ordinary evidence fields;
- carrying `requiresFollowUp == true` or a non-empty `pendingIssue`.

`notApplicable` required modules are allowed to close without response evidence,
because the supervisor/module lifecycle moderation path is the authority for the
N/A decision.

## Why this cannot be fully enforced in current Firestore rules

`job_modules` are top-level documents. Firestore rules on a `job_executions/{id}`
update cannot safely query and aggregate all `job_modules` linked to that
execution. Current rules therefore enforce actor authority and completion field
shape, while the detailed module-readiness gate remains in app/provider code.

## Safe-now implementation

The closure decision has been extracted to a pure domain guard:

```text
lib/features/planned_maintenance/domain/planned_job_closure_guard.dart
```

Both Isar/local-first completion and direct Firestore completion call:

```dart
PlannedJobClosureGuard.assertReady(modules)
```

Regression coverage is added in:

```text
test/planned_job_closure_guard_test.dart
```

This makes the app-side invariant testable without Firebase or Isar.

## Schema-stage options for true server truth

### Option A — Denormalized closure readiness counters on JobExecution

Add fields such as:

```text
requiredClosureModuleCount
closureReadyModuleCount
closureBlockingModuleCount
closureBlockingReasonSummary
closureReadinessComputedAt
closureReadinessComputedBy
```

Rules can then require:

```text
closureBlockingModuleCount == 0
closureReadyModuleCount == requiredClosureModuleCount
```

before allowing `isCompleted` to become true.

Caveat: every module lifecycle/write path must update these counters correctly,
including offline sync, rejected pushes, tombstones, runtime-added modules, and
not-applicable transitions.

### Option B — Cloud Function final-completion authority

Move final completion to a callable/HTTPS function that:

1. verifies caller role;
2. queries all linked `job_modules` server-side;
3. checks the same readiness policy;
4. updates `job_executions/{id}` atomically or transactionally;
5. writes an audit event.

Rules would reject direct client completion writes, except possibly from the
server/function identity.

Caveat: this changes the offline completion UX. The app would need a pending
completion request state for offline use.

## Recommendation

Use the safe-now extracted guard and tests immediately.

For production server truth, prefer **Option A first** if offline-first completion
must remain a local action. Prefer **Option B** only when the team is ready for a
server-mediated final completion workflow and a pending-completion UX.

## What not to do

- Do not replace client-observed timestamps with server timestamps in this issue.
- Do not add closure counters without an Isar/Firestore migration plan.
- Do not weaken the existing app-side closure guard just because server truth is
  not complete yet.
- Do not make active jobs read mutable TemplateVersion drafts for closure truth.
