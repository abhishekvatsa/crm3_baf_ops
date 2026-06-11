// FILE: test/issue_1_tombstone_conflict_regression_test.dart
//
// Issue 1 regression tests: remote tombstones must not bury fresher unsynced
// local field evidence. These tests exercise the Isar repository methods that
// GlobalPullService/SyncService call when Firestore returns a remote tombstone.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:isar/isar.dart';

// Use package imports so analyzer treats test references to lib/ as the
// canonical package libraries. Repository-relative imports resolve to the
// same package:crm3_baf_ops/main.dart library.

import 'package:crm3_baf_ops/main.dart' as app;

import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';

Future<void> _withTestIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp('baf_issue1_tombstone_');
  final instance = await Isar.open(
    [
      MaintenanceRecordSchema,
      JobExecutionSchema,
      JobDiaryEntrySchema,
      JobModuleInstanceSchema,
    ],
    directory: dir.path,
    name: 'baf_issue1_tombstone_test',
  );

  app.isar = instance;

  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

MaintenanceRecord _maintenanceRecord({
  required String firestoreId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required bool isSynced,
  bool isDeleted = false,
  DateTime? deletedAt,
  int version = 1,
}) {
  return MaintenanceRecord()
    ..firestoreId = firestoreId
    ..version = version
    ..isSynced = isSynced
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = isDeleted ? 'remote_deleter' : null
    ..deletedByName = isDeleted ? 'Remote Deleter' : null
    ..deleteReason = isDeleted ? 'Remote tombstone' : null
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Hydraulic clamp observation'
    ..routedTo = RoutedTo.mechanical
    ..isCritical = true
    ..status = TicketStatus.open
    ..isResolved = false
    ..loggedByUid = 'local_user'
    ..loggedByName = 'Local User'
    ..startDate = createdAt
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..actionsJson = '[]'
    ..resolutionHistoryJson = '[]';
}

JobExecution _jobExecution({
  required String firestoreId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required bool isSynced,
  bool isDeleted = false,
  DateTime? deletedAt,
  int version = 1,
}) {
  return JobExecution()
    ..firestoreId = firestoreId
    ..templateFirestoreId = 'template_1'
    ..templateName = 'BAF test template'
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..isCompleted = false
    ..assignedByUid = 'supervisor'
    ..assignedByName = 'Shift Supervisor'
    ..assignedAgencies = [RoutedTo.mechanical.name]
    ..version = version
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = isDeleted ? 'remote_deleter' : null
    ..deletedByName = isDeleted ? 'Remote Deleter' : null
    ..deleteReason = isDeleted ? 'Remote tombstone' : null
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..isSynced = isSynced
    ..responsesJson = '[]'
    ..actionsJson = '[]';
}

JobModuleInstance _jobModule({
  required String firestoreId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required bool isSynced,
  bool isDeleted = false,
  DateTime? deletedAt,
  int version = 1,
}) {
  return JobModuleInstance()
    ..firestoreId = firestoreId
    ..jobExecutionFirestoreId = 'execution_1'
    ..templateFirestoreId = 'template_1'
    ..moduleCode = 'M-01'
    ..moduleTitle = 'Inspect base fan'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..status = JobModuleStatus.draftSaved
    ..useMode = JobModuleUseMode.scheduledPM
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..responsesJson = '[{"fieldId":"f1","value":"local evidence"}]'
    ..actionsJson = '[]'
    ..createdByUid = 'supervisor'
    ..createdByName = 'Shift Supervisor'
    ..createdAt = createdAt
    ..updatedByUid = 'senior_mech'
    ..updatedByName = 'Senior Mechanical'
    ..updatedAt = updatedAt
    ..version = version
    ..isSynced = isSynced
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = isDeleted ? 'remote_deleter' : null
    ..deletedByName = isDeleted ? 'Remote Deleter' : null
    ..deleteReason = isDeleted ? 'Remote tombstone' : null;
}

JobDiaryEntry _diaryEntry({
  required String firestoreId,
  required DateTime createdAt,
  required DateTime updatedAt,
  required bool isSynced,
  bool isDeleted = false,
  DateTime? deletedAt,
  int version = 1,
}) {
  return JobDiaryEntry()
    ..firestoreId = firestoreId
    ..jobExecutionFirestoreId = 'execution_1'
    ..assetType = AssetType.base
    ..assetNumber = 1
    ..kind = JobDiaryKind.note
    ..discipline = JobDiaryDiscipline.mechanical
    ..severity = JobDiarySeverity.medium
    ..note = 'Local diary evidence'
    ..createdByUid = 'senior_mech'
    ..createdByName = 'Senior Mechanical'
    ..createdAt = createdAt
    ..updatedByUid = 'senior_mech'
    ..updatedByName = 'Senior Mechanical'
    ..updatedAt = updatedAt
    ..version = version
    ..isSynced = isSynced
    ..isDeleted = isDeleted
    ..deletedAt = deletedAt
    ..deletedByUid = isDeleted ? 'remote_deleter' : null
    ..deletedByName = isDeleted ? 'Remote Deleter' : null
    ..deleteReason = isDeleted ? 'Remote tombstone' : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final isarLib = File('${Directory.current.path}/libisar.so');

    await Isar.initializeIsarCore(
      libraries: {
        if (Abi.current() == Abi.linuxX64 && isarLib.existsSync())
          Abi.linuxX64: isarLib.path,
      },
      download: true,
    );
  });

  group(
    'Issue 1: remote tombstones preserve fresher unsynced local evidence',
    () {
      test(
        'maintenance ticket tombstone preserves newer dirty local ticket',
        () async {
          await _withTestIsar((isar) async {
            final localUpdatedAt = DateTime.utc(2026, 5, 12, 10, 10);
            final remoteDeletedAt = DateTime.utc(2026, 5, 12, 10, 0);
            final local = _maintenanceRecord(
              firestoreId: 'ticket_1',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: localUpdatedAt,
              isSynced: false,
              version: 2,
            );
            await isar.writeTxn(() => isar.maintenanceRecords.put(local));

            final remote = _maintenanceRecord(
              firestoreId: 'ticket_1',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: remoteDeletedAt,
              isSynced: true,
              isDeleted: true,
              deletedAt: remoteDeletedAt,
              version: 3,
            );

            final result = await IsarMaintenanceRepository()
                .applyTombstoneFromMaintenanceRemote(remote);

            expect(
              result.outcome,
              RemoteTombstoneApplyOutcome.localDirtyPreserved,
            );
            final after =
                await isar.maintenanceRecords
                    .filter()
                    .firestoreIdEqualTo('ticket_1')
                    .findFirst();
            expect(after, isNotNull);
            expect(after!.isDeleted, isFalse);
            expect(after.isSynced, isFalse);
            expect(after.updatedAt.toUtc(), localUpdatedAt);
            expect(after.version, 2);
          });
        },
      );

      test(
        'job execution tombstone preserves newer dirty local execution',
        () async {
          await _withTestIsar((isar) async {
            final localUpdatedAt = DateTime.utc(2026, 5, 12, 10, 10);
            final remoteDeletedAt = DateTime.utc(2026, 5, 12, 10, 0);
            await isar.writeTxn(
              () => isar.jobExecutions.put(
                _jobExecution(
                  firestoreId: 'execution_1',
                  createdAt: DateTime.utc(2026, 5, 12, 9),
                  updatedAt: localUpdatedAt,
                  isSynced: false,
                  version: 2,
                ),
              ),
            );

            final remote = _jobExecution(
              firestoreId: 'execution_1',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: remoteDeletedAt,
              isSynced: true,
              isDeleted: true,
              deletedAt: remoteDeletedAt,
              version: 3,
            );

            final result = await IsarPlannedRepository()
                .applyTombstoneFromExecutionRemote(remote);

            expect(
              result.outcome,
              RemoteTombstoneApplyOutcome.localDirtyPreserved,
            );
            final after =
                await isar.jobExecutions
                    .filter()
                    .firestoreIdEqualTo('execution_1')
                    .findFirst();
            expect(after, isNotNull);
            expect(after!.isDeleted, isFalse);
            expect(after.isSynced, isFalse);
            expect(after.updatedAt.toUtc(), localUpdatedAt);
            expect(after.version, 2);
          });
        },
      );

      test(
        'job module tombstone preserves newer dirty local module responses',
        () async {
          await _withTestIsar((isar) async {
            final localUpdatedAt = DateTime.utc(2026, 5, 12, 10, 10);
            final remoteDeletedAt = DateTime.utc(2026, 5, 12, 10, 0);
            await isar.writeTxn(
              () => isar.jobModuleInstances.put(
                _jobModule(
                  firestoreId: 'module_1',
                  createdAt: DateTime.utc(2026, 5, 12, 9),
                  updatedAt: localUpdatedAt,
                  isSynced: false,
                  version: 2,
                ),
              ),
            );

            final remote = _jobModule(
              firestoreId: 'module_1',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: remoteDeletedAt,
              isSynced: true,
              isDeleted: true,
              deletedAt: remoteDeletedAt,
              version: 3,
            );

            final result = await IsarJobModuleRepository()
                .applyTombstoneFromRemote(remote);

            expect(
              result.outcome,
              RemoteTombstoneApplyOutcome.localDirtyPreserved,
            );
            final after =
                await isar.jobModuleInstances
                    .filter()
                    .firestoreIdEqualTo('module_1')
                    .findFirst();
            expect(after, isNotNull);
            expect(after!.isDeleted, isFalse);
            expect(after.isSynced, isFalse);
            expect(after.responsesJson, contains('local evidence'));
            expect(after.updatedAt.toUtc(), localUpdatedAt);
            expect(after.version, 2);
          });
        },
      );

      test(
        'job diary tombstone preserves newer dirty local diary note',
        () async {
          await _withTestIsar((isar) async {
            final localUpdatedAt = DateTime.utc(2026, 5, 12, 10, 10);
            final remoteDeletedAt = DateTime.utc(2026, 5, 12, 10, 0);
            await isar.writeTxn(
              () => isar.jobDiaryEntrys.put(
                _diaryEntry(
                  firestoreId: 'diary_1',
                  createdAt: DateTime.utc(2026, 5, 12, 9),
                  updatedAt: localUpdatedAt,
                  isSynced: false,
                  version: 2,
                ),
              ),
            );

            final remote = _diaryEntry(
              firestoreId: 'diary_1',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: remoteDeletedAt,
              isSynced: true,
              isDeleted: true,
              deletedAt: remoteDeletedAt,
              version: 3,
            );

            final result = await IsarJobDiaryRepository()
                .applyTombstoneFromRemote(remote);

            expect(
              result.outcome,
              RemoteTombstoneApplyOutcome.localDirtyPreserved,
            );
            final after =
                await isar.jobDiaryEntrys
                    .filter()
                    .firestoreIdEqualTo('diary_1')
                    .findFirst();
            expect(after, isNotNull);
            expect(after!.isDeleted, isFalse);
            expect(after.isSynced, isFalse);
            expect(after.note, 'Local diary evidence');
            expect(after.updatedAt.toUtc(), localUpdatedAt);
            expect(after.version, 2);
          });
        },
      );
    },
  );

  group(
    'Issue 1: remote tombstones still apply when local row is clean or older',
    () {
      test(
        'maintenance tombstone applies to clean older local ticket',
        () async {
          await _withTestIsar((isar) async {
            final localUpdatedAt = DateTime.utc(2026, 5, 12, 9, 55);
            final remoteDeletedAt = DateTime.utc(2026, 5, 12, 10, 0);
            await isar.writeTxn(
              () => isar.maintenanceRecords.put(
                _maintenanceRecord(
                  firestoreId: 'ticket_clean',
                  createdAt: DateTime.utc(2026, 5, 12, 9),
                  updatedAt: localUpdatedAt,
                  isSynced: true,
                  version: 2,
                ),
              ),
            );

            final remote = _maintenanceRecord(
              firestoreId: 'ticket_clean',
              createdAt: DateTime.utc(2026, 5, 12, 9),
              updatedAt: remoteDeletedAt,
              isSynced: true,
              isDeleted: true,
              deletedAt: remoteDeletedAt,
              version: 3,
            );

            final result = await IsarMaintenanceRepository()
                .applyTombstoneFromMaintenanceRemote(remote);

            expect(result.outcome, RemoteTombstoneApplyOutcome.applied);
            final after =
                await isar.maintenanceRecords
                    .filter()
                    .firestoreIdEqualTo('ticket_clean')
                    .findFirst();
            expect(after, isNotNull);
            expect(after!.isDeleted, isTrue);
            expect(after.isSynced, isTrue);
            expect(after.deletedAt?.toUtc(), remoteDeletedAt);
            expect(after.version, 3);
          });
        },
      );
    },
  );
}
