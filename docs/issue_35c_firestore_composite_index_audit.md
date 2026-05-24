# Issue 35C — Firestore composite index audit

## Scope

This audit reviewed the current Dart Firestore queries in `lib/` and produced a conservative `firestore.indexes.json` candidate for the query families most likely to need composite indexes in production.

This issue does **not** change app behavior. Index creation is operational metadata only, but index deployment should still be reviewed because unnecessary indexes cost storage and build time.

## Current evidence

The latest `firestore-debug.log` did not show an active missing-index URL or `FAILED_PRECONDITION: The query requires an index` failure. The existing emulator/rules failures were permission-denied/expression-limit related, not index-build failures.

## Recommended artifact

Add:

```text
firestore.indexes.json
```

and update `firebase.json` under the existing `firestore` block:

```json
"firestore": {
  "rules": "firestore.rules",
  "indexes": "firestore.indexes.json"
}
```

Then deploy indexes explicitly:

```powershell
firebase deploy --only firestore:indexes
```

Keep rules deployment separate:

```powershell
firebase deploy --only firestore:rules
```

## High-priority query families covered

### `maintenance_records`

Covered query shapes:

- open tickets: `isResolved == false`, `isDeleted == false`, `orderBy(createdAt desc)`
- all tickets: `isDeleted == false`, `orderBy(createdAt desc)`
- asset timeline/history: `assetType`, `assetNumber`, `isDeleted`, `orderBy(createdAt desc)`
- open asset tickets: `assetType`, `assetNumber`, `isResolved`, `isDeleted`, `orderBy(createdAt desc)`
- type-level history/open queries: `assetType`, `isDeleted/isResolved`, `orderBy(createdAt desc)`
- closed tickets: `isResolved == true`, `isDeleted == false`, `orderBy(endDate desc)`
- live mirror scope queries: `isDeleted`, `isResolved`, plus `loggedByUid` / `routedTo` / `isCritical`

### `job_executions`

Covered query shapes:

- asset execution history: `assetType`, `assetNumber`, `isDeleted`, `orderBy(createdAt desc)`
- asset-type execution history: `assetType`, `isDeleted`, `orderBy(createdAt desc)`
- open execution list: `isCompleted == false`, `isDeleted == false`, optional `orderBy(createdAt desc)` path
- template execution lookup: `templateFirestoreId`, `isDeleted`

### `job_modules`

Covered query shapes:

- module list per job: `jobExecutionFirestoreId`, `isDeleted`, `orderBy(displayOrder)`, `orderBy(moduleTitle)`
- module list per job and discipline: same plus `discipline`

### `job_diary_entries`

Covered query shape:

- diary list per job: `jobExecutionFirestoreId`, `isDeleted`, `orderBy(createdAt desc)`

### `directives`

Covered query shapes:

- all directives: `isDeleted`, `orderBy(createdAt desc)`
- open/acknowledged directives: `status whereIn`, `isDeleted`, `orderBy(createdAt desc)`

### `audit_logs`

Covered query shape:

- entity timeline: `entityType`, `entityId`, `orderBy(timestamp desc)`

### Template governance / planned maintenance

Covered query shapes:

- `job_templates`: `isDeleted`, `orderBy(jobName)` and `isDeleted`, `orderBy(updatedAt desc)`
- `template_packages`: `isDeleted`, `orderBy(title)`
- `template_versions`: `packageFirestoreId`, `isDeleted`; and `status`, `orderBy(publishedAt desc)`

### Abnormalities

Covered query shapes:

- `charge_abnormalities`: `sourceChargeNo`, `isDeleted`
- `abnormality_types`: `isDeleted`, `isActive`

## What is intentionally not included

- Single-field delta queries such as `orderBy(updatedAt)` with an optional `updatedAt > since` are not included because Firestore single-field indexes normally cover these.
- `FieldPath.documentId whereIn` chunk lookups are not included.
- Queries that are currently local-Isar-only are not included.

## Verification commands

```powershell
firebase deploy --only firestore:indexes
npm run emulator:test:rules
flutter analyze
```

Then run the app against Firestore and watch for missing-index links in logs. If Firestore reports a generated index URL, add the exact index it requests rather than guessing.

## Closure condition

Issue 35C can be considered closed when:

1. `firestore.indexes.json` is committed/reviewed.
2. `firebase.json` points to it.
3. `firebase deploy --only firestore:indexes` succeeds.
4. No missing-index URL appears during smoke tests of Home, Issues, Work, Directives, asset timeline, audit timeline, and Template Publisher.
