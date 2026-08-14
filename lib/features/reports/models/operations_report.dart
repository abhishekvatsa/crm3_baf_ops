import '../../assets/domain/plant_asset_overview.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../operational_events/data/operational_event.dart';
import '../../planned_maintenance/data/job_template_model.dart';

class OperationsReportFilter {
  const OperationsReportFilter({
    required this.startDate,
    required this.endDate,
    this.assetClassId,
    this.assetInstanceId,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String? assetClassId;
  final String? assetInstanceId;

  DateTime get startInclusive =>
      DateTime(startDate.year, startDate.month, startDate.day);

  DateTime get endExclusive => DateTime(
    endDate.year,
    endDate.month,
    endDate.day,
  ).add(const Duration(days: 1));

  @override
  bool operator ==(Object other) =>
      other is OperationsReportFilter &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.assetClassId == assetClassId &&
      other.assetInstanceId == assetInstanceId;

  @override
  int get hashCode =>
      Object.hash(startDate, endDate, assetClassId, assetInstanceId);
}

class CountedReportLabel {
  const CountedReportLabel({required this.label, required this.count});
  final String label;
  final int count;
}

class AssetClassReportSummary {
  const AssetClassReportSummary({
    required this.assetClassId,
    required this.assetClassName,
    required this.assetCount,
    required this.availableCount,
    required this.underMaintenanceCount,
    required this.downCount,
    required this.unfitCount,
    required this.issueCount,
    required this.openIssueCount,
    required this.plannedJobCount,
    required this.openPlannedJobCount,
    required this.disruptionCount,
  });

  final String assetClassId;
  final String assetClassName;
  final int assetCount;
  final int availableCount;
  final int underMaintenanceCount;
  final int downCount;
  final int unfitCount;
  final int issueCount;
  final int openIssueCount;
  final int plannedJobCount;
  final int openPlannedJobCount;
  final int disruptionCount;
}

class OperationsReport {
  const OperationsReport({
    required this.filter,
    required this.asOf,
    required this.tickets,
    required this.executions,
    required this.events,
    required this.assetStates,
    required this.classSummaries,
    required this.topComponents,
    required this.topSubsystems,
    required this.sourceTicketCount,
    required this.sourceExecutionCount,
    required this.sourceEventCount,
    required this.disruptionCount,
    required this.openDisruptionCount,
    required this.disruptionDuration,
  });

  final OperationsReportFilter filter;
  final DateTime asOf;
  final List<MaintenanceRecord> tickets;
  final List<JobExecution> executions;
  final List<OperationalEvent> events;
  final List<PlantAssetState> assetStates;
  final List<AssetClassReportSummary> classSummaries;
  final List<CountedReportLabel> topComponents;
  final List<CountedReportLabel> topSubsystems;
  final int sourceTicketCount;
  final int sourceExecutionCount;
  final int sourceEventCount;
  final int disruptionCount;
  final int openDisruptionCount;
  final Duration disruptionDuration;

  int get issueCount => tickets.length;
  int get openIssueCount =>
      tickets.where((ticket) => !ticket.isResolved).length;
  int get resolvedIssueCount =>
      tickets.where((ticket) => ticket.isResolved).length;
  int get criticalIssueCount =>
      tickets.where((ticket) => ticket.isCritical).length;

  int get plannedJobCount => executions.length;
  int get openPlannedJobCount =>
      executions.where((job) => !job.isCompleted && !job.isCancelled).length;
  int get completedPlannedJobCount =>
      executions.where((job) => job.isCompleted).length;
  int get cancelledPlannedJobCount =>
      executions.where((job) => job.isCancelled).length;

  int get assetCount => assetStates.length;
  int get availableAssetCount =>
      assetStates.where((state) => state.isAvailable).length;
  int get underMaintenanceAssetCount =>
      assetStates.where((state) => state.isUnderMaintenance).length;
  int get downAssetCount => assetStates.where((state) => state.isDown).length;
  int get unfitAssetCount => assetStates.where((state) => state.isUnfit).length;

  List<MaintenanceRecord> get openIssues {
    final rows = tickets.where((ticket) => !ticket.isResolved).toList();
    rows.sort((left, right) {
      if (left.isCritical != right.isCritical) return left.isCritical ? -1 : 1;
      return right.startDate.compareTo(left.startDate);
    });
    return List<MaintenanceRecord>.unmodifiable(rows);
  }
}
