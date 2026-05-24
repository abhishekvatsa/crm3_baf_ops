import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';

class AssetFleetStatus {
  final int assetNumber;
  final AssetType assetType;
  final int openTicketsCount;
  final List<JobExecution> recentCompletedJobs; // most recent completed executions (max 3)
  final int? daysSinceLastCompletedJob; // null if never completed

  AssetFleetStatus({
    required this.assetNumber,
    required this.assetType,
    required this.openTicketsCount,
    required this.recentCompletedJobs,
    required this.daysSinceLastCompletedJob,
  });

  // Visual helper for aging severity
  // 0: green (≤30 days), 1: amber (31‑90 days), 2: red (>90 days or never serviced)
  int get agingSeverity {
    if (daysSinceLastCompletedJob == null) return 2;
    if (daysSinceLastCompletedJob! <= 30) return 0;
    if (daysSinceLastCompletedJob! <= 90) return 1;
    return 2;
  }
}