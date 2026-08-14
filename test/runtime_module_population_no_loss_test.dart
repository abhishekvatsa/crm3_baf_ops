import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/runtime_job_module_population_service.dart';

class _UnusedMaintenanceRepository extends MaintenanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedPlannedMaintenanceRepository extends PlannedMaintenanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedJobDiaryRepository implements JobDiaryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedTemplateGovernanceRepository
    implements TemplateGovernanceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedDirectiveRepository implements DirectiveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedAbnormalityRepository implements AbnormalityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedBafKnowledgeRepository implements BafKnowledgeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedServerCompletionService
    implements PlannedJobServerCompletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedAuditRepository implements AuditRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _UnusedRepositories {
  final MaintenanceRepository maintenance = _UnusedMaintenanceRepository();

  final PlannedMaintenanceRepository planned =
      _UnusedPlannedMaintenanceRepository();

  final JobDiaryRepository jobDiary = _UnusedJobDiaryRepository();

  final TemplateGovernanceRepository templateGovernance =
      _UnusedTemplateGovernanceRepository();

  final DirectiveRepository directive = _UnusedDirectiveRepository();

  final AbnormalityRepository abnormality = _UnusedAbnormalityRepository();

  final BafKnowledgeRepository knowledge = _UnusedBafKnowledgeRepository();

  final PlannedJobServerCompletionService serverCompletion =
      _UnusedServerCompletionService();

  final AuditRepository audit = _UnusedAuditRepository();
}

class _RejectingRemoteModules implements JobModuleRepository {
  final List<JobModuleInstance> remoteModules;
  int mutationAttempts = 0;

  _RejectingRemoteModules({this.remoteModules = const <JobModuleInstance>[]});

  @override
  Future<List<JobModuleInstance>> getModulesByFirestoreIds(
    List<String> ids,
  ) async => remoteModules
      .where((module) => ids.contains(module.firestoreId))
      .toList(growable: false);

  @override
  Future<void> batchUpsertModules(List<JobModuleInstance> records) async {
    mutationAttempts++;
    throw const RuntimeJobModulePopulationException(
      code: 'failed-precondition',
      message: 'Parent execution is already complete.',
      reasonCode: 'parent-execution-completed',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

JobModuleInstance _dirtyRuntimeModule() {
  final now = DateTime.utc(2026, 6, 24, 12);
  return JobModuleInstance()
    ..firestoreId = 'runtime_dirty_1'
    ..jobExecutionFirestoreId = 'execution_completed_remote'
    ..templateFirestoreId = 'legacy-template'
    ..templateName = 'Runtime module'
    ..moduleCode = 'RUNTIME-01'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..moduleTitle = 'Preserve rejected runtime evidence'
    ..status = JobModuleStatus.notStarted
    ..useMode = JobModuleUseMode.scheduledPM
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..isRequired = false
    ..requiredForClosure = false
    ..addedDuringExecution = true
    ..displayOrder = 1
    ..targetRefs = <String>[]
    ..procedureRefs = <String>[]
    ..safetyConfirmations = <String>[]
    ..tags = <String>[]
    ..operationalStatePreconditions = <String>[]
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..requiresFollowUp = false
    ..addedByUid = 'supervisor1'
    ..addedByName = 'Shift Supervisor'
    ..addedAt = now
    ..addReason = 'Observed offline'
    ..createdByUid = 'supervisor1'
    ..createdByName = 'Shift Supervisor'
    ..createdAt = now
    ..updatedByUid = 'supervisor1'
    ..updatedByName = 'Shift Supervisor'
    ..updatedAt = now
    ..isDeleted = false
    ..version = 1
    ..isSynced = false;
}

JobModuleInstance _dirtyTombstone() {
  final module = _dirtyRuntimeModule();
  module
    ..isDeleted = true
    ..deletedByUid = 'supervisor1'
    ..deletedByName = 'Shift Supervisor'
    ..deletedAt = DateTime.utc(2026, 6, 24, 13)
    ..deleteReason = 'Duplicate module'
    ..updatedAt = DateTime.utc(2026, 6, 24, 13)
    ..version = 2
    ..isSynced = false;
  return module;
}

JobModuleInstance _remoteActiveModule() {
  final module = _dirtyRuntimeModule();
  module
    ..id = Isar.autoIncrement
    ..isSynced = true
    ..version = 1;
  return module;
}

Future<void> _withIsar(Future<void> Function(Isar isar) body) async {
  final dir = await Directory.systemTemp.createTemp('runtime_population_loss_');
  final instance = await Isar.open([
    JobModuleInstanceSchema,
    SyncRejectionSchema,
  ], directory: dir.path);
  app.isar = instance;
  try {
    await body(instance);
  } finally {
    await instance.close(deleteFromDisk: true);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

void main() {
  setUpAll(() async {
    await initializeTestIsarCore();
  });

  test(
    'durable callable rejection keeps local evidence dirty and persists SyncRejection before sync returns',
    () async {
      await _withIsar((isar) async {
        final module = _dirtyRuntimeModule();
        await isar.writeTxn(() => isar.jobModuleInstances.put(module));

        final localModules = IsarJobModuleRepository();
        final remoteModules = _RejectingRemoteModules();
        final unused = _UnusedRepositories();
        final sync = SyncService(
          maintenanceRepo: unused.maintenance,
          firestoreMaintenance: unused.maintenance,
          plannedRepo: unused.planned,
          firestorePlanned: unused.planned,
          serverCompletion: unused.serverCompletion,
          jobDiaryRepo: unused.jobDiary,
          firestoreJobDiary: unused.jobDiary,
          jobModuleRepo: localModules,
          firestoreJobModule: remoteModules,
          templateGovernanceRepo: unused.templateGovernance,
          firestoreTemplateGovernance: unused.templateGovernance,
          directiveRepo: unused.directive,
          firestoreDirective: unused.directive,
          abnormalityRepo: unused.abnormality,
          firestoreAbnormality: unused.abnormality,
          knowledgeRepo: unused.knowledge,
          auditRepository: unused.audit,
        );

        await sync.syncJobModulesForTest();

        final preserved = await isar.jobModuleInstances.get(module.id);
        expect(preserved, isNotNull);
        expect(preserved!.isSynced, isFalse);
        expect(preserved.isDeleted, isFalse);

        final rejections = await isar.syncRejections.where().findAll();
        expect(rejections, hasLength(1));
        expect(rejections.single.entityType, 'job_module');
        expect(rejections.single.firestoreId, 'runtime_dirty_1');
        expect(rejections.single.errorCode, 'failed-precondition');
        expect(rejections.single.isLikelyPermanent, isTrue);
        expect(rejections.single.isResolved, isFalse);
        expect(
          rejections.single.message,
          contains('already completed remotely'),
        );

        // One batch attempt and one diagnostic single-record attempt. Durable
        // rejections are not retried three times within either attempt.
        expect(remoteModules.mutationAttempts, 2);
        expect(sync.lastFailureCount, 1);
        expect(sync.lastSuccessCount, 0);
        expect(sync.lastFailureDetails, hasLength(1));

        // The persisted permanent rejection holds the next automatic pass; no
        // additional remote mutation attempt is made until an operator resolves it.
        await sync.syncJobModulesForTest();
        expect(remoteModules.mutationAttempts, 2);
        expect(sync.lastFailureCount, 2);
        expect(
          sync.lastFailureDetails.last.message,
          contains('Automatic retry held'),
        );
      });
    },
  );

  test(
    'rejected governed soft delete keeps the local tombstone dirty and quarantined',
    () async {
      await _withIsar((isar) async {
        final tombstone = _dirtyTombstone();
        await isar.writeTxn(() => isar.jobModuleInstances.put(tombstone));

        final localModules = IsarJobModuleRepository();
        final remoteModules = _RejectingRemoteModules(
          remoteModules: <JobModuleInstance>[_remoteActiveModule()],
        );
        final unused = _UnusedRepositories();
        final sync = SyncService(
          maintenanceRepo: unused.maintenance,
          firestoreMaintenance: unused.maintenance,
          plannedRepo: unused.planned,
          firestorePlanned: unused.planned,
          serverCompletion: unused.serverCompletion,
          jobDiaryRepo: unused.jobDiary,
          firestoreJobDiary: unused.jobDiary,
          jobModuleRepo: localModules,
          firestoreJobModule: remoteModules,
          templateGovernanceRepo: unused.templateGovernance,
          firestoreTemplateGovernance: unused.templateGovernance,
          directiveRepo: unused.directive,
          firestoreDirective: unused.directive,
          abnormalityRepo: unused.abnormality,
          firestoreAbnormality: unused.abnormality,
          knowledgeRepo: unused.knowledge,
          auditRepository: unused.audit,
        );

        await sync.syncJobModulesForTest();

        final preserved = await isar.jobModuleInstances.get(tombstone.id);
        expect(preserved, isNotNull);
        expect(preserved!.isDeleted, isTrue);
        expect(preserved.isSynced, isFalse);
        final rejections = await isar.syncRejections.where().findAll();
        expect(rejections, hasLength(1));
        expect(rejections.single.firestoreId, 'runtime_dirty_1');
        expect(rejections.single.isLikelyPermanent, isTrue);
        expect(remoteModules.mutationAttempts, 2);
      });
    },
  );
}
