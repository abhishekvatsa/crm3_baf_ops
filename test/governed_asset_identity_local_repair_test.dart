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
}
