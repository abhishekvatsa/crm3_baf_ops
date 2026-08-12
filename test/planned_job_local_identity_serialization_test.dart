import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';

void main() {
  test('job module Firestore payload never transports an Isar parent id', () {
    final now = DateTime.utc(2026, 6, 20);
    final module =
        JobModuleInstance()
          ..firestoreId = 'module-1'
          ..jobExecutionFirestoreId = 'exec-1'
          ..jobExecutionLocalId = 77
          ..moduleTitle = 'Module'
          ..moduleSnapshotJson = '{}'
          ..fieldDefinitionsJson = '[]'
          ..assetType = AssetType.base
          ..assetNumber = 209
          ..createdAt = now
          ..updatedAt = now;

    final map = module.toMap();
    expect(map.containsKey('jobExecutionLocalId'), isFalse);

    final remote = JobModuleInstance.fromMap(<String, dynamic>{
      ...map,
      'jobExecutionLocalId': 999,
    }, 'module-1');
    expect(remote.jobExecutionLocalId, isNull);
  });

  test('job diary Firestore payload never transports local parent ids', () {
    final now = DateTime.utc(2026, 6, 20);
    final entry =
        JobDiaryEntry()
          ..firestoreId = 'diary-1'
          ..jobExecutionFirestoreId = 'exec-1'
          ..jobExecutionLocalId = 77
          ..moduleInstanceFirestoreId = 'module-1'
          ..moduleInstanceLocalId = 88
          ..assetType = AssetType.base
          ..assetNumber = 209
          ..note = 'Observation'
          ..createdByUid = 'actor-1'
          ..updatedByUid = 'actor-1'
          ..createdAt = now
          ..updatedAt = now;

    final map = entry.toMap();
    expect(map.containsKey('jobExecutionLocalId'), isFalse);
    expect(map.containsKey('moduleInstanceLocalId'), isFalse);

    final remote = JobDiaryEntry.fromMap(<String, dynamic>{
      ...map,
      'jobExecutionLocalId': 999,
      'moduleInstanceLocalId': 1000,
    }, 'diary-1');
    expect(remote.jobExecutionLocalId, isNull);
    expect(remote.moduleInstanceLocalId, isNull);
  });
}
