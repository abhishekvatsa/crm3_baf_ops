import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/maintenance_workflow/data/equipment_status_record.dart';
import '../../features/maintenance_workflow/data/workflow_aggregate_record.dart';

class GovernedAssetIdentityLocalRepairReport {
  final int removedWorkflowProjections;
  final int removedEquipmentProjections;

  const GovernedAssetIdentityLocalRepairReport({
    required this.removedWorkflowProjections,
    required this.removedEquipmentProjections,
  });

  bool get changed =>
      removedWorkflowProjections > 0 || removedEquipmentProjections > 0;
}

const _workflowPullCursorKey = 'last_maintenance_workflow_pull_v2_workflows';
const _equipmentPullCursorKey = 'last_maintenance_workflow_pull_v2_equipment';

bool _isIncompleteCustomIdentity({
  required String assetTypeKey,
  required String? assetClassId,
  required String? assetInstanceId,
}) =>
    assetTypeKey == 'governedCustom' &&
    ((assetClassId?.trim().isEmpty ?? true) ||
        (assetInstanceId?.trim().isEmpty ?? true));

/// Removes only legacy custom-asset cache rows whose physical identity cannot
/// be reconstructed safely. The server remains authoritative for both local
/// projection collections.
Future<GovernedAssetIdentityLocalRepairReport>
repairLegacyGovernedAssetIdentityProjections(Isar isar) async {
  var removedWorkflows = 0;
  var removedEquipment = 0;
  await isar.writeTxn(() async {
    final workflows = await isar.workflowAggregateRecords.where().findAll();
    final workflowIds = workflows
        .where(
          (record) => _isIncompleteCustomIdentity(
            assetTypeKey: record.assetTypeKey,
            assetClassId: record.assetClassId,
            assetInstanceId: record.assetInstanceId,
          ),
        )
        .map((record) => record.id)
        .toList(growable: false);
    if (workflowIds.isNotEmpty) {
      removedWorkflows = await isar.workflowAggregateRecords.deleteAll(
        workflowIds,
      );
    }

    final equipment = await isar.equipmentStatusRecords.where().findAll();
    final equipmentIds = equipment
        .where(
          (record) => _isIncompleteCustomIdentity(
            assetTypeKey: record.assetTypeKey,
            assetClassId: record.assetClassId,
            assetInstanceId: record.assetInstanceId,
          ),
        )
        .map((record) => record.id)
        .toList(growable: false);
    if (equipmentIds.isNotEmpty) {
      removedEquipment = await isar.equipmentStatusRecords.deleteAll(
        equipmentIds,
      );
    }
  });
  return GovernedAssetIdentityLocalRepairReport(
    removedWorkflowProjections: removedWorkflows,
    removedEquipmentProjections: removedEquipment,
  );
}

/// Forces the two repaired projection collections to refetch from their full
/// server histories. Failure keeps schema provenance in PREPARED state.
Future<void> resetGovernedAssetIdentityProjectionPullCursors() async {
  final preferences = await SharedPreferences.getInstance();
  for (final key in <String>[_workflowPullCursorKey, _equipmentPullCursorKey]) {
    if (!preferences.containsKey(key)) continue;
    final removed = await preferences.remove(key);
    if (!removed || preferences.containsKey(key)) {
      throw StateError('Governed asset projection cursor reset failed: $key');
    }
  }
}
