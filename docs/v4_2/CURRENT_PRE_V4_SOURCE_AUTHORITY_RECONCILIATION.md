# CRM3 Current-Pre-v4 Source Authority Reconciliation

## Custody

- User-supplied archive: `currentbeforev4.zip`
- SHA-256: `84BB9114C05C29777154E5EA7095DFF00850C478A2DB2048FDE5787CD5EB48CC`
- ZIP entries: 440
- Files: 360
- Unsafe traversal paths: 0
- Normalized source roots: `.github`, `functions`, `lib`, `test`, and root project files

## Source continuity against v4.1

| Area | Old files | Present in v4.1 | Byte-identical | Deliberately changed | Missing |
|---|---:|---:|---:|---:|---:|
| `lib/` | 205 | 204 | 167 | 37 | 1 |
| `test/` | 87 | 87 | 84 | 3 | 0 |
| `functions/` | 45 | 45 | 27 | 18 | 0 |
| `.github/` | 3 | 3 | 3 | 0 | 0 |


Whole normalized file comparison (directories and archive container entries excluded):

- Common paths: 351
- Byte-identical common paths: 288
- Changed common paths: 63
- Old-only paths: 9
- v4.1-only file paths: 229

**No old test file, Cloud Functions file, workflow file, or ordinary application source file is absent from v4.1.** The only old `lib/` path not carried in the ordinary v4.1 handoff is the controlled Firebase output `lib/firebase_options.dart`.

## Old-only path disposition

| Path | Disposition |
|---|---|
| `.flutter-plugins` | Generated Flutter state; exclude |
| `.flutter-plugins-dependencies` | Generated Flutter state; exclude |
| `.gitattributes` | Useful line-ending/binary custody metadata; carry into next anchored candidate |
| `.gitignore` | Useful source-control metadata; carry into next anchored candidate |
| `.metadata` | Useful Flutter project provenance; carry into next anchored candidate |
| `firestore-debug.log` | Emulator/debug output; exclude |
| `isar.dll` | Host binary/build support artifact; exclude |
| `lib/firebase_options.dart` | Controlled Firebase build input; use for identity/hash proof, keep outside ordinary evidence ZIP unless explicitly authorized |
| `release-gate.yml` | Stale root duplicate; authoritative pinned workflow exists under .github/workflows |

## Isar continuity result

All 16 pre-existing collections retain:

- the same collection ID;
- the same ID and type for every pre-existing property;
- the same ID and definition for every pre-existing index;
- no removed old property;
- no removed old index.

v4.1 adds fields only to `JobExecution` and `MaintenanceRecord`, adds EMD/Refractory enum values without changing the persisted property shape, and registers nine new workflow collections.

| Collection | Old collection ID | ID preserved | Properties | Old property mismatches | Removed old properties | New properties |
|---|---:|---|---:|---:|---:|---|
| AbnormalityType | 8484628406258702188 | YES | 22 → 22 | 0 | 0 | — |
| AuditEvent | -228283108298215510 | YES | 13 → 13 | 0 | 0 | — |
| BafKnowledgeMatrixMetaStore | -4597930498197848453 | YES | 19 → 19 | 0 | 0 | — |
| BafKnowledgeRow | 6184583526286388735 | YES | 38 → 38 | 0 | 0 | — |
| Charge | 1755725158846388127 | YES | 32 → 32 | 0 | 0 | — |
| ChargeAbnormality | 4068838871833800476 | YES | 30 → 30 | 0 | 0 | — |
| JobDiaryEntry | 3610953931278188100 | YES | 40 → 40 | 0 | 0 | — |
| JobExecution | 8749547484972275668 | YES | 33 → 47 | 0 | 0 | cancellationReason, cancelledAt, cancelledByName, cancelledByUid, isCancelled, laneMappingReview, laneSetFinalizedAt, laneSetFinalizedByName, laneSetFinalizedByUid, laneSetVersion, parentExecutionFirestoreId, redAnswerJson, spawnedRedExecutionFirestoreId, workflowSchemaVersion |
| JobModuleInstance | 1431400483870693323 | YES | 73 → 73 | 0 | 0 | — |
| JobTemplate | 7389994387465344115 | YES | 25 → 25 | 0 | 0 | — |
| MaintenanceRecord | 8394037719530270343 | YES | 46 → 65 | 0 | 0 | workflowAggregateId, workflowComplianceId, workflowConditionRef, workflowConditionTypeKey, workflowCorrectionReason, workflowDeferred, workflowDeferredAt, workflowDeferredByName, workflowDeferredByUid, workflowOriginLaneKey, workflowQueueState, workflowReactivatedAt, workflowReactivatedByName, workflowReactivatedByUid, workflowReleasedAt, workflowReleasedByName, workflowReleasedByUid, workflowTargetLaneKey, workflowUpdatedAt |
| OperationalDirective | 8926677232068899510 | YES | 44 → 44 | 0 | 0 | — |
| SyncRejection | -7653774813178690174 | YES | 14 → 14 | 0 | 0 | — |
| TemplatePackage | 7246776624816934243 | YES | 38 → 38 | 0 | 0 | — |
| TemplatePublishAudit | -236492924270429194 | YES | 17 → 17 | 0 | 0 | — |
| TemplateVersion | 3679262402733643249 | YES | 52 → 52 | 0 | 0 | — |

### Authority boundary

This substantially reduces migration uncertainty but does not convert provisional bindings into genuine `build_runner` output. Authentic generation under Flutter 3.44.0 / Dart 3.12.0 / Isar 3.1.0+1 remains mandatory, especially for the nine new workflow collections.

## Dependency and toolchain continuity

The old snapshot and v4.1 have byte-identical:

- `pubspec.yaml`
- `pubspec.lock`
- root `package-lock.json`
- Functions `package-lock.json`

The lockfile resolves Flutter `>=3.44.0`, Dart `>=3.12.0`, Isar `3.1.0+1`, `isar_generator 3.1.0+1`, and `build_runner 2.4.13`.

## Firebase identity evidence

- Old `firebase_options.dart` Android app ID: `1:894346496105:android:fba14febfbbee102e63af8`
- Old `firebase.json` Android app ID: `1:894346496105:android:c320c57f2393dceee63af8`
- Corrected v4.1 `firebase.json` Android app ID: `1:894346496105:android:fba14febfbbee102e63af8`
- Old `firebase_options.dart` SHA-256: `07912823FCC37500C785BE26741B3930087D7A47F02F5E2268F7C7FC1A6031DE`

This independently confirms that the old app contained the same Firebase identity contradiction identified by due diligence, and that v4.1 aligned `firebase.json` to the Android app already embedded in the old generated Firebase options.

## What this archive proves

1. v4.1 retains the old app's source/test/Functions capability inventory.
2. The original Isar schema IDs are preserved exactly.
3. The pinned dependency and generator versions are known and unchanged.
4. The permanent Firebase Android registration selected in v4.1 is supported by the old app's generated Firebase options.
5. The old source can now be used as a concrete no-loss baseline even without Git connectivity.

## What it does not prove

- Git ancestry or the commit SHA from which the ZIP was assembled;
- Android Gradle/Kotlin/package identity, because no `android/` directory is present;
- `google-services.json` parity;
- authentic v4 Isar generation;
- migration of a real installed Isar database;
- Flutter compilation, emulator behaviour, device upgrade or rollback.

## Governing disposition

Treat SHA-256 `84BB9114C05C29777154E5EA7095DFF00850C478A2DB2048FDE5787CD5EB48CC` as the **user-supplied current-pre-v4 source snapshot authority** for source no-loss reconciliation. It does not supersede later repository evidence when Git authority becomes available, but it is materially stronger than reconstructing the old app indirectly from v3.3 artifacts.
