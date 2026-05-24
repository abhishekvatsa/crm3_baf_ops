# Issue 63 — Development-mode callable region migration runbook

## Objective

Move `completePlannedJobExecution` from `us-central1` to `asia-south1`, matching the Firestore database location.

This project is still in development and there are no other tablets or old app builds in the field. Because of that, the migration can go directly to the final target region instead of keeping a long multi-region retirement window.

## Current design

- Firestore database location: `asia-south1`
- Callable name remains stable: `completePlannedJobExecution`
- Callable region after Issue 63: `asia-south1`
- Dart client calls:

```dart
FirebaseFunctions
    .instanceFor(region: 'asia-south1')
    .httpsCallable('completePlannedJobExecution');
```

## Pre-deploy verification

```powershell
dart format `
  lib\features\planned_maintenance\services\planned_job_server_completion_service.dart `
  test\planned_job_server_completion_service_test.dart

flutter analyze
flutter test test\planned_job_server_completion_service_test.dart
flutter test test\planned_job_server_completion_no_loss_test.dart
flutter test test\planned_job_closure_guard_test.dart
flutter test test\issue_1_tombstone_conflict_regression_test.dart
flutter test test\issue_41_response_payload_contract_test.dart
flutter test test\published_runtime_module_catalogue_test.dart
flutter test test\complete_job_screen_server_gate_test.dart

cd functions
npm run build
npm test
npm audit --omit=dev
cd ..
```

Do not run `npm audit fix --force`; it has previously proposed a breaking `firebase-admin@10.3.0` downgrade.

## Deploy

Deploy only the callable after tests pass:

```powershell
firebase deploy --only functions:completePlannedJobExecution
firebase functions:list --project crm3-baf-ops-b8638
```

Expected after deploy: `completePlannedJobExecution` appears in `asia-south1`. Notification triggers remain in `asia-south1`.

## Smoke test must prove region

A successful completion is not enough. It must prove the app hit `asia-south1`.

1. Run a planned-job completion from the development app build.
2. Immediately inspect recent logs:

```powershell
firebase functions:log --only completePlannedJobExecution --limit 5
```

3. Confirm the latest smoke invocation is for `asia-south1`.

If the smoke call succeeds but appears under `us-central1`, the migration is not verified; the app is still calling the old region.

## Development-mode rollback

If `asia-south1` misbehaves, rollback is simple because there are no field tablets to coordinate:

1. Change `CALLABLE_REGION` in `functions/src/index.ts` back to `us-central1`.
2. Change `plannedJobCompletionCallableRegion` in Dart back to `us-central1`.
3. Re-run the verification chain.
4. Redeploy `functions:completePlannedJobExecution`.
5. Smoke again.

## Future production note

When real tablets/users exist, use a staged multi-region migration instead of a direct switch:

1. Deploy the same callable name in both old and new regions.
2. Update clients to the new region.
3. Confirm every client is updated.
4. Monitor old-region invocation logs.
5. Retire the old region only after the fleet is fully migrated.

## No-touch boundaries

This migration must not change:

- `functions/src/plannedJobClosure.ts` closure validation logic
- Firestore rules
- Firestore indexes
- Isar schema or generated files
- role authority matrix
- audit/attestation logic
- sync/tombstone policy
- notification trigger logic
