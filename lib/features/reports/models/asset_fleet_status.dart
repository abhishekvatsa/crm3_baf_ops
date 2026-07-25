import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';

class AssetFleetStatus {
  final int assetNumber;
  final AssetType assetType;
  final int openTicketsCount;
  final List<JobExecution> recentCompletedJobs; // most recent completed executions (max 3)
  final int? daysSinceLastCompletedJob; // null if never completed
  final EquipmentStatusRecord? workflowEquipmentStatus;

  AssetFleetStatus({
    required this.assetNumber,
    required this.assetType,
    required this.openTicketsCount,
    required this.recentCompletedJobs,
    required this.daysSinceLastCompletedJob,
    required this.workflowEquipmentStatus,
  });

  // Visual helper for aging severity
  // 0: green (≤30 days), 1: amber (31‑90 days), 2: red (>90 days or never serviced)
  String get operationalStateKey =>
      workflowEquipmentStatus?.stateKey ??
      (openTicketsCount > 0 ? 'underMaintenance' : 'inService');

  int get activeWorkflowCount =>
      workflowEquipmentStatus?.openMaintenanceCount ?? 0;

  int get activeRedCount => workflowEquipmentStatus?.openRedCount ?? 0;

  int get awaitingPreparationCount =>
      workflowEquipmentStatus?.awaitingPreparationCount ?? 0;

  int get agingSeverity {
    if (daysSinceLastCompletedJob == null) return 2;
    if (daysSinceLastCompletedJob! <= 30) return 0;
    if (daysSinceLastCompletedJob! <= 90) return 1;
    return 2;
  }
}