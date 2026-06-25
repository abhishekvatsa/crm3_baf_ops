import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';

JobModuleInstance _module() {
  final now = DateTime.utc(2026, 6, 24, 12);
  return JobModuleInstance()
    ..firestoreId = 'runtime-replay-1'
    ..jobExecutionFirestoreId = 'execution-1'
    ..templateFirestoreId = 'legacy-template'
    ..templateName = 'Runtime module'
    ..moduleCode = 'RUNTIME-01'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..chargeNoAtEvent = 12345
    ..moduleTitle = 'Lost response replay'
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

void main() {
  test('exact client payload is recognized after a lost create response', () {
    final local = _module();
    final remote = JobModuleInstance.fromMap(<String, dynamic>{
      ...local.toMap(),
      // Server-only fields are deliberately ignored by fromMap/toMap.
      'populationAcceptedByUid': 'supervisor1',
      'parentPopulationVersionAtAcceptance': 4,
    }, local.firestoreId!);

    expect(jobModuleClientSnapshotsEquivalentForSync(local, remote), isTrue);
  });

  test(
    'different client-owned content is not treated as an idempotent replay',
    () {
      final local = _module();
      final remote = JobModuleInstance.fromMap(
        local.toMap(),
        local.firestoreId!,
      );
      remote
        ..status = JobModuleStatus.inProgress
        ..updatedAt = local.updatedAt.add(const Duration(minutes: 1))
        ..version = local.version + 1;

      expect(jobModuleClientSnapshotsEquivalentForSync(local, remote), isFalse);
    },
  );
}
