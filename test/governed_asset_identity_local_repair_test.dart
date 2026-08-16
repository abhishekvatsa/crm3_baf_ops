import 'dart:io';

import 'package:crm3_baf_ops/core/services/governed_asset_identity_local_repair.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestIsarCore();
  });

  test('repair activation covers every upgrade crossing schema v5', () {
    for (final sourceVersion in <int>[1, 3, 4]) {
      expect(
        requiresGovernedAssetIdentityLocalRepair(
          fromVersion: sourceVersion,
          toVersion: 6,
        ),
        isTrue,
        reason: 'v$sourceVersion to v6 crosses the governed-identity boundary',
      );
    }
    expect(
      requiresGovernedAssetIdentityLocalRepair(fromVersion: 4, toVersion: 5),
      isTrue,
    );
    expect(
      requiresGovernedAssetIdentityLocalRepair(fromVersion: 5, toVersion: 6),
      isFalse,
    );
    expect(
      requiresGovernedAssetIdentityLocalRepair(fromVersion: 6, toVersion: 6),
      isFalse,
    );
  });

  test(
    'removes only custom projections with incomplete physical identity',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'baf_governed_identity_repair_',
      );
      final isar = await Isar.open(
        [WorkflowAggregateRecordSchema, EquipmentStatusRecordSchema],
        directory: directory.path,
        name: 'governed_asset_identity_repair_test',
      );

      try {
        final now = DateTime.utc(2026, 8, 14);
        final legacyWorkflow =
            WorkflowAggregateRecord()
              ..firestoreId = 'workflow-legacy-custom'
              ..jobExecutionFirestoreId = 'execution-legacy-custom'
              ..assetTypeKey = 'governedCustom'
              ..assetNumber = 3
              ..createdAt = now
              ..updatedAt = now;
        final currentWorkflow =
            WorkflowAggregateRecord()
              ..firestoreId = 'workflow-current-custom'
              ..jobExecutionFirestoreId = 'execution-current-custom'
              ..assetTypeKey = 'governedCustom'
              ..assetNumber = 3
              ..assetClassId = 'class-furnace'
              ..assetInstanceId = 'asset-furnace-3'
              ..createdAt = now
              ..updatedAt = now;
        final legacyEquipment =
            EquipmentStatusRecord()
              ..firestoreId = 'governedCustom_3'
              ..assetTypeKey = 'governedCustom'
              ..assetNumber = 3
              ..updatedAt = now;
        final currentEquipment =
            EquipmentStatusRecord()
              ..firestoreId = 'governedCustom_class-furnace_asset-furnace-3'
              ..assetTypeKey = 'governedCustom'
              ..assetNumber = 3
              ..assetClassId = 'class-furnace'
              ..assetInstanceId = 'asset-furnace-3'
              ..updatedAt = now;
        final legacyTypedEquipment =
            EquipmentStatusRecord()
              ..firestoreId = 'furnace_3'
              ..assetTypeKey = 'furnace'
              ..assetNumber = 3
              ..updatedAt = now;

        await isar.writeTxn(() async {
          await isar.workflowAggregateRecords.putAll([
            legacyWorkflow,
            currentWorkflow,
          ]);
          await isar.equipmentStatusRecords.putAll([
            legacyEquipment,
            currentEquipment,
            legacyTypedEquipment,
          ]);
        });

        final first = await repairLegacyGovernedAssetIdentityProjections(isar);
        expect(first.removedWorkflowProjections, 1);
        expect(first.removedEquipmentProjections, 1);
        expect(
          (await isar.workflowAggregateRecords.where().findAll()).map(
            (record) => record.firestoreId,
          ),
          <String>['workflow-current-custom'],
        );
        expect(
          (await isar.equipmentStatusRecords.where().findAll())
              .map((record) => record.firestoreId)
              .toSet(),
          <String?>{
            'governedCustom_class-furnace_asset-furnace-3',
            'furnace_3',
          },
        );

        final second = await repairLegacyGovernedAssetIdentityProjections(isar);
        expect(second.changed, isFalse);
      } finally {
        await isar.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      }
    },
  );

  test('resets only workflow and equipment projection pull cursors', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'last_maintenance_workflow_pull_v2_workflows': 'workflow-cursor',
      'last_maintenance_workflow_pull_v2_equipment': 'equipment-cursor',
      'last_maintenance_workflow_pull_v2_lanes': 'lane-cursor',
    });

    await resetGovernedAssetIdentityProjectionPullCursors();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey('last_maintenance_workflow_pull_v2_workflows'),
      isFalse,
    );
    expect(
      preferences.containsKey('last_maintenance_workflow_pull_v2_equipment'),
      isFalse,
    );
    expect(
      preferences.getString('last_maintenance_workflow_pull_v2_lanes'),
      'lane-cursor',
    );
  });

  test(
    'populated v3 and v4 stores repair safely on a direct v6 upgrade',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'baf_governed_identity_upgrade_',
      );
      final isar = await Isar.open(
        [WorkflowAggregateRecordSchema, EquipmentStatusRecordSchema],
        directory: directory.path,
        name: 'governed_asset_identity_upgrade_test',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();

      try {
        for (final sourceVersion in <int>[3, 4]) {
          final now = DateTime.utc(2026, 8, 16, sourceVersion);
          final incompleteWorkflow =
              WorkflowAggregateRecord()
                ..firestoreId = 'workflow-v$sourceVersion-incomplete'
                ..jobExecutionFirestoreId = 'execution-v$sourceVersion'
                ..assetTypeKey = 'governedCustom'
                ..assetNumber = sourceVersion
                ..createdAt = now
                ..updatedAt = now;
          final completeWorkflow =
              WorkflowAggregateRecord()
                ..firestoreId = 'workflow-v$sourceVersion-complete'
                ..jobExecutionFirestoreId = 'execution-v$sourceVersion-complete'
                ..assetTypeKey = 'governedCustom'
                ..assetNumber = sourceVersion
                ..assetClassId = 'class-v$sourceVersion'
                ..assetInstanceId = 'asset-v$sourceVersion'
                ..createdAt = now
                ..updatedAt = now;
          final incompleteEquipment =
              EquipmentStatusRecord()
                ..firestoreId = 'equipment-v$sourceVersion-incomplete'
                ..assetTypeKey = 'governedCustom'
                ..assetNumber = sourceVersion
                ..updatedAt = now;
          final completeEquipment =
              EquipmentStatusRecord()
                ..firestoreId = 'equipment-v$sourceVersion-complete'
                ..assetTypeKey = 'governedCustom'
                ..assetNumber = sourceVersion
                ..assetClassId = 'class-v$sourceVersion'
                ..assetInstanceId = 'asset-v$sourceVersion'
                ..updatedAt = now;
          await isar.writeTxn(() async {
            await isar.workflowAggregateRecords.putAll(
              <WorkflowAggregateRecord>[incompleteWorkflow, completeWorkflow],
            );
            await isar.equipmentStatusRecords.putAll(<EquipmentStatusRecord>[
              incompleteEquipment,
              completeEquipment,
            ]);
          });
          await preferences.setString(
            'last_maintenance_workflow_pull_v2_workflows',
            'workflow-v$sourceVersion-cursor',
          );
          await preferences.setString(
            'last_maintenance_workflow_pull_v2_equipment',
            'equipment-v$sourceVersion-cursor',
          );

          final report = await repairGovernedAssetIdentityForSchemaUpgrade(
            isar,
            fromVersion: sourceVersion,
            toVersion: 6,
          );

          expect(report, isNotNull);
          expect(report!.removedWorkflowProjections, 1);
          expect(report.removedEquipmentProjections, 1);
          expect(
            preferences.containsKey(
              'last_maintenance_workflow_pull_v2_workflows',
            ),
            isFalse,
          );
          expect(
            preferences.containsKey(
              'last_maintenance_workflow_pull_v2_equipment',
            ),
            isFalse,
          );
          expect(
            (await isar.workflowAggregateRecords.where().findAll()).any(
              (record) => record.firestoreId == completeWorkflow.firestoreId,
            ),
            isTrue,
          );
          expect(
            (await isar.equipmentStatusRecords.where().findAll()).any(
              (record) => record.firestoreId == completeEquipment.firestoreId,
            ),
            isTrue,
          );
        }

        final repeated = await repairGovernedAssetIdentityForSchemaUpgrade(
          isar,
          fromVersion: 4,
          toVersion: 6,
        );
        expect(repeated, isNotNull);
        expect(repeated!.changed, isFalse);
      } finally {
        await isar.close(deleteFromDisk: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
