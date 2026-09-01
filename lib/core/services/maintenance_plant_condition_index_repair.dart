import 'package:isar/isar.dart';

import '../../features/maintenance/data/maintenance_model.dart';

const maintenancePlantConditionIndexSchemaVersion = 10;

class MaintenancePlantConditionIndexRepairReport {
  final int reindexedRecords;

  const MaintenancePlantConditionIndexRepairReport({
    required this.reindexedRecords,
  });

  bool get changed => reindexedRecords > 0;
}

bool requiresMaintenancePlantConditionIndexRepair({
  required int fromVersion,
  required int toVersion,
}) =>
    fromVersion < maintenancePlantConditionIndexSchemaVersion &&
    toVersion >= maintenancePlantConditionIndexSchemaVersion;

/// Rewrites local ticket projections so Isar persists and indexes the derived
/// Plant Condition contribution state introduced in schema v10. No business
/// field, sync state, version, or remote document is changed.
Future<MaintenancePlantConditionIndexRepairReport?>
repairMaintenancePlantConditionIndexForSchemaUpgrade(
  Isar isar, {
  required int fromVersion,
  required int toVersion,
}) async {
  if (!requiresMaintenancePlantConditionIndexRepair(
    fromVersion: fromVersion,
    toVersion: toVersion,
  )) {
    return null;
  }

  var reindexedRecords = 0;
  await isar.writeTxn(() async {
    final records = await isar.maintenanceRecords.where().findAll();
    if (records.isEmpty) return;
    await isar.maintenanceRecords.putAll(records);
    reindexedRecords = records.length;
  });

  return MaintenancePlantConditionIndexRepairReport(
    reindexedRecords: reindexedRecords,
  );
}
