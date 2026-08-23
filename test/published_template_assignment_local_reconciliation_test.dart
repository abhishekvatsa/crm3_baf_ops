import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_local_reconciler.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_server_service.dart';

Future<void> _withAssignmentIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp(
    'published_assignment_reconcile_',
  );
  final instance = await Isar.open(
    [JobExecutionSchema, JobModuleInstanceSchema],
    directory: dir.path,
    name: 'published_assignment_reconcile_test',
  );
  app.isar = instance;
  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

JobExecution _execution() =>
    JobExecution()
      ..firestoreId = 'execution_1'
      ..templateFirestoreId = 'version_1'
      ..templateName = 'Governed PM'
      ..templatePackageId = 'package_1'
      ..templateVersionId = 'version_1'
      ..templateVersionNumber = 1
      ..templateContentHash = 'hash_1'
      ..assetType = AssetType.base
      ..assetNumber = 201
      ..assignedByUid = 'supervisor_1'
      ..assignedByName = 'Supervisor'
      ..assignedAgencies = [RoutedTo.mechanical.name]
      ..responsesJson = '[]'
      ..actionsJson = '[]'
      ..version = 1
      ..createdAt = DateTime.utc(2026, 8, 23, 7)
      ..updatedAt = DateTime.utc(2026, 8, 23, 7)
      ..isSynced = true;

JobModuleInstance _module({
  required String firestoreId,
  required String title,
  int version = 1,
  bool isSynced = true,
  String responsesJson = '[]',
  DateTime? updatedAt,
}) =>
    JobModuleInstance()
      ..firestoreId = firestoreId
      ..jobExecutionFirestoreId = 'execution_1'
      ..templateFirestoreId = 'version_1'
      ..templatePackageId = 'package_1'
      ..templateVersionId = 'version_1'
      ..moduleCode = firestoreId.toUpperCase()
      ..moduleTitle = title
      ..moduleSnapshotJson = '{}'
      ..fieldDefinitionsJson = '[]'
      ..assetType = AssetType.base
      ..assetNumber = 201
      ..status = JobModuleStatus.notStarted
      ..useMode = JobModuleUseMode.scheduledPM
      ..discipline = JobModuleDiscipline.mechanical
      ..safetyClass = JobModuleSafetyClass.normal
      ..isRequired = true
      ..requiredForClosure = true
      ..responsesJson = responsesJson
      ..actionsJson = '[]'
      ..createdByUid = 'supervisor_1'
      ..createdByName = 'Supervisor'
      ..createdAt = DateTime.utc(2026, 8, 23, 7)
      ..updatedByUid = 'supervisor_1'
      ..updatedByName = 'Supervisor'
      ..updatedAt = updatedAt ?? DateTime.utc(2026, 8, 23, 7)
      ..version = version
      ..isSynced = isSynced
      ..isDeleted = false;

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'idempotent assignment replay preserves newer local module work',
    () async {
      await _withAssignmentIsar((isar) async {
        final dirty = _module(
          firestoreId: 'module_1',
          title: 'Inspect base fan',
          version: 2,
          isSynced: false,
          responsesJson: '[{"key":"reading","value":"2.4"}]',
          updatedAt: DateTime.utc(2026, 8, 23, 8),
        );
        await isar.writeTxn(() => isar.jobModuleInstances.put(dirty));
        final initialReplayModule = _module(
          firestoreId: 'module_1',
          title: 'Inspect base fan',
        );
        final missingReplayModule = _module(
          firestoreId: 'module_2',
          title: 'Inspect base seals',
        );
        final result = PublishedTemplateAssignmentServerResult(
          execution: _execution(),
          modules: [initialReplayModule, missingReplayModule],
          requestId: 'request_1',
          idempotentReplay: true,
          publicationAuditFirestoreId: 'audit_1',
          assignedAt: DateTime.utc(2026, 8, 23, 7),
        );

        await PublishedTemplateAssignmentLocalReconciler(
          plannedRepository: IsarPlannedRepository(),
          moduleRepository: IsarJobModuleRepository(),
        ).persist(result);

        final preserved = await isar.jobModuleInstances.get(dirty.id);
        expect(preserved!.version, 2);
        expect(preserved.responsesJson, contains('2.4'));
        expect(preserved.isSynced, isFalse);
        final inserted =
            await isar.jobModuleInstances
                .filter()
                .firestoreIdEqualTo('module_2')
                .findFirst();
        expect(inserted, isNotNull);
        expect(inserted!.isSynced, isTrue);
        expect(inserted.jobExecutionFirestoreId, 'execution_1');
        expect(
          await isar.jobExecutions
              .filter()
              .firestoreIdEqualTo('execution_1')
              .findFirst(),
          isNotNull,
        );
      });
    },
  );
}
