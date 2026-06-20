import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:crm3_baf_ops/core/services/planned_job_local_link_repair.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final explicitCorePath = Platform.environment['CRM_ISAR_CORE_PATH'];

    final explicitCore =
        explicitCorePath == null || explicitCorePath.trim().isEmpty
            ? null
            : File(explicitCorePath);

    final localLinuxLibrary = File('${Directory.current.path}/libisar.so');

    if (explicitCore != null && !explicitCore.existsSync()) {
      throw StateError(
        'CRM_ISAR_CORE_PATH does not exist: '
        '${explicitCore.path}',
      );
    }

    await Isar.initializeIsarCore(
      libraries: {
        if (explicitCore != null) Abi.current(): explicitCore.path,
        if (explicitCore == null &&
            Abi.current() == Abi.linuxX64 &&
            localLinuxLibrary.existsSync())
          Abi.linuxX64: localLinuxLibrary.path,
      },
      download: explicitCore == null,
    );
  });

  test('clears only transported local links and is idempotent', () async {
    final dir = await Directory.systemTemp.createTemp('baf_local_link_repair_');
    final isar = await Isar.open(
      [JobModuleInstanceSchema, JobDiaryEntrySchema],
      directory: dir.path,
      name: 'baf_local_link_repair_test',
    );

    try {
      final now = DateTime.utc(2026, 6, 20);
      final remoteBackedModule =
          JobModuleInstance()
            ..firestoreId = 'module-remote'
            ..jobExecutionFirestoreId = 'exec-remote'
            ..jobExecutionLocalId = 7
            ..moduleTitle = 'Remote-backed module'
            ..moduleSnapshotJson = '{}'
            ..fieldDefinitionsJson = '[]'
            ..assetType = AssetType.base
            ..assetNumber = 209
            ..responsesJson = '[{"key":"pressure","value":"ok"}]'
            ..actionsJson = '[{"action":"inspect"}]'
            ..createdAt = now
            ..updatedAt = now
            ..version = 4
            ..isSynced = true;
      final localOnlyModule =
          JobModuleInstance()
            ..firestoreId = 'module-local'
            ..jobExecutionFirestoreId = null
            ..jobExecutionLocalId = 7
            ..moduleTitle = 'Local-only module'
            ..moduleSnapshotJson = '{}'
            ..fieldDefinitionsJson = '[]'
            ..assetType = AssetType.base
            ..assetNumber = 209
            ..createdAt = now
            ..updatedAt = now
            ..version = 2
            ..isSynced = false;
      final diary =
          JobDiaryEntry()
            ..firestoreId = 'diary-1'
            ..jobExecutionFirestoreId = 'exec-remote'
            ..jobExecutionLocalId = 7
            ..moduleInstanceFirestoreId = 'module-remote'
            ..moduleInstanceLocalId = 8
            ..assetType = AssetType.base
            ..assetNumber = 209
            ..note = 'Evidence note'
            ..createdAt = now
            ..updatedAt = now
            ..version = 3
            ..isSynced = true;

      await isar.writeTxn(() async {
        await isar.jobModuleInstances.putAll([
          remoteBackedModule,
          localOnlyModule,
        ]);
        await isar.jobDiaryEntrys.put(diary);
      });

      final first = await repairPlannedJobLocalLinks(isar);
      expect(first.repairedModules, 1);
      expect(first.repairedDiaryExecutionLinks, 1);
      expect(first.repairedDiaryModuleLinks, 1);

      final repairedRemote =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo('module-remote')
              .findFirst();
      final preservedLocal =
          await isar.jobModuleInstances
              .filter()
              .firestoreIdEqualTo('module-local')
              .findFirst();
      final repairedDiary =
          await isar.jobDiaryEntrys
              .filter()
              .firestoreIdEqualTo('diary-1')
              .findFirst();

      expect(repairedRemote!.jobExecutionLocalId, isNull);
      expect(repairedRemote.version, 4);
      expect(repairedRemote.isSynced, isTrue);
      expect(repairedRemote.responsesJson, '[{"key":"pressure","value":"ok"}]');
      expect(repairedRemote.actionsJson, '[{"action":"inspect"}]');
      expect(repairedRemote.updatedAt.isAtSameMomentAs(now), isTrue);
      expect(preservedLocal!.jobExecutionLocalId, 7);
      expect(preservedLocal.isSynced, isFalse);
      expect(repairedDiary!.jobExecutionLocalId, isNull);
      expect(repairedDiary.moduleInstanceLocalId, isNull);
      expect(repairedDiary.version, 3);
      expect(repairedDiary.isSynced, isTrue);

      final second = await repairPlannedJobLocalLinks(isar);
      expect(second.totalRepairs, 0);
    } finally {
      await isar.close(deleteFromDisk: true);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}
