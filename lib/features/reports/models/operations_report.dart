import '../../assets/domain/plant_asset_overview.dart';
import '../../inspections/data/inspection_campaign.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../operational_events/data/operational_event.dart';
import '../../planned_maintenance/data/maintenance_intelligence.dart';
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

enum OperationsManagementSignalType {
  unavailableAssets,
  criticalIssues,
  operationalDisruptions,
  overdueMaintenance,
  inspectionFindings,
  openIssues,
  openPlannedWork,
}

enum OperationsManagementSignalLevel { critical, warning, attention }

class OperationsManagementSignal {
  const OperationsManagementSignal({
    required this.type,
    required this.level,
    required this.title,
    required this.detail,
    required this.count,
  });

  final OperationsManagementSignalType type;
  final OperationsManagementSignalLevel level;
  final String title;
  final String detail;
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
    required this.overdueMaintenanceCount,
    required this.dueSoonMaintenanceCount,
    required this.activeInspectionFindingCount,
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
  final int overdueMaintenanceCount;
  final int dueSoonMaintenanceCount;
  final int activeInspectionFindingCount;
}

class OperationalEventReportOccurrence {
  const OperationalEventReportOccurrence({
    required this.event,
    required this.interval,
    required this.isCurrent,
  });

  final OperationalEvent event;
  final OperationalEventInterval interval;
  final bool isCurrent;

  bool get isOpen => isCurrent && event.isOpen;
}

class OperationsReport {
  const OperationsReport({
    required this.filter,
    required this.asOf,
    required this.tickets,
    required this.executions,
    required this.events,
    required this.eventOccurrences,
    required this.dueStates,
    required this.inspectionFindings,
    required this.assetStates,
    required this.classSummaries,
    required this.topComponents,
    required this.topSubsystemPaths,
    required this.sourceTicketCount,
    required this.sourceExecutionCount,
    required this.sourceEventCount,
    required this.sourceDueStateCount,
    required this.sourceInspectionFindingCount,
    required this.disruptionCount,
    required this.openDisruptionCount,
    required this.disruptionDuration,
  });

  final OperationsReportFilter filter;
  final DateTime asOf;
  final List<MaintenanceRecord> tickets;
  final List<JobExecution> executions;
  final List<OperationalEvent> events;
  final List<OperationalEventReportOccurrence> eventOccurrences;
  final List<MaintenanceDueState> dueStates;
  final List<InspectionFinding> inspectionFindings;
  final List<PlantAssetState> assetStates;
  final List<AssetClassReportSummary> classSummaries;
  final List<CountedReportLabel> topComponents;
  final List<CountedReportLabel> topSubsystemPaths;
  final int sourceTicketCount;
  final int sourceExecutionCount;
  final int sourceEventCount;
  final int sourceDueStateCount;
  final int sourceInspectionFindingCount;
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
  int get openCriticalIssueCount =>
      tickets.where((ticket) => ticket.isCritical && !ticket.isResolved).length;

  int get plannedJobCount => executions.length;
  int get openPlannedJobCount =>
      executions.where((job) => !job.isCompleted && !job.isCancelled).length;
  int get completedPlannedJobCount =>
      executions.where((job) => job.isCompleted).length;
  int get cancelledPlannedJobCount =>
      executions.where((job) => job.isCancelled).length;

  int get overdueMaintenanceCount =>
      dueStates
          .where(
            (state) =>
                state.nextDueAt != null && state.nextDueAt!.isBefore(asOf),
          )
          .length;
  int get dueSoonMaintenanceCount =>
      dueStates.where((state) {
        final dueAt = state.nextDueAt;
        return dueAt != null &&
            !dueAt.isBefore(asOf) &&
            !dueAt.isAfter(asOf.add(const Duration(days: 7)));
      }).length;

  bool _isActiveFinding(InspectionFinding finding) => {
    InspectionFindingStatus.open,
    InspectionFindingStatus.correctiveActionLinked,
    InspectionFindingStatus.awaitingVerification,
  }.contains(finding.status);

  int get activeInspectionFindingCount =>
      inspectionFindings.where(_isActiveFinding).length;
  int get awaitingInspectionVerificationCount =>
      inspectionFindings
          .where(
            (finding) =>
                finding.status == InspectionFindingStatus.awaitingVerification,
          )
          .length;

  List<InspectionFinding> get activeInspectionFindings =>
      List<InspectionFinding>.unmodifiable(
        inspectionFindings.where(_isActiveFinding),
      );

  Set<String> get linkedDisruptionIssueIds => Set<String>.unmodifiable(
    eventOccurrences.expand((occurrence) => occurrence.interval.linkedIssueIds),
  );
  int get linkedDisruptionIssueCount => linkedDisruptionIssueIds.length;

  int get assetCount => assetStates.length;
  int get availableAssetCount =>
      assetStates.where((state) => state.isAvailable).length;
  int get underMaintenanceAssetCount =>
      assetStates.where((state) => state.isUnderMaintenance).length;
  int get downAssetCount => assetStates.where((state) => state.isDown).length;
  int get unfitAssetCount => assetStates.where((state) => state.isUnfit).length;

  double? get assetAvailabilityRate =>
      assetCount == 0 ? null : availableAssetCount / assetCount;

  double? get issueClosureRate =>
      issueCount == 0 ? null : resolvedIssueCount / issueCount;

  double? get plannedCompletionRate =>
      plannedJobCount == 0 ? null : completedPlannedJobCount / plannedJobCount;

  int get unavailableAssetCount => assetCount - availableAssetCount;
  int get highRiskUnavailableAssetCount =>
      assetStates.where((state) => state.isDown || state.isUnfit).length;

  int get actionBacklogCount =>
      openIssueCount + openPlannedJobCount + openDisruptionCount;

  int get assuranceBacklogCount =>
      overdueMaintenanceCount + activeInspectionFindingCount;

  List<OperationsManagementSignal> get managementSignals {
    final signals = <OperationsManagementSignal>[
      if (openCriticalIssueCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.criticalIssues,
          level: OperationsManagementSignalLevel.critical,
          title:
              '$openCriticalIssueCount critical '
              '${openCriticalIssueCount == 1 ? 'issue remains' : 'issues remain'} open',
          detail: 'Review ownership, operating impact and next action.',
          count: openCriticalIssueCount,
        ),
      if (highRiskUnavailableAssetCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.unavailableAssets,
          level: OperationsManagementSignalLevel.critical,
          title:
              highRiskUnavailableAssetCount == 1
                  ? '1 asset is down or unfit'
                  : '$highRiskUnavailableAssetCount assets are down or unfit',
          detail:
              '$downAssetCount down, $unfitAssetCount unfit and '
              '$underMaintenanceAssetCount under maintenance',
          count: highRiskUnavailableAssetCount,
        ),
      if (openDisruptionCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.operationalDisruptions,
          level: OperationsManagementSignalLevel.critical,
          title:
              '$openDisruptionCount plant '
              '${openDisruptionCount == 1 ? 'disruption remains' : 'disruptions remain'} open',
          detail:
              'Confirm affected scope, linked issues and restoration evidence.',
          count: openDisruptionCount,
        ),
      if (unavailableAssetCount > 0 && highRiskUnavailableAssetCount == 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.unavailableAssets,
          level: OperationsManagementSignalLevel.warning,
          title:
              unavailableAssetCount == 1
                  ? '1 asset is outside the available state'
                  : '$unavailableAssetCount assets are outside the available state',
          detail:
              '$underMaintenanceAssetCount under maintenance; remaining '
              'exceptions include blocks, standby or out-of-service state.',
          count: unavailableAssetCount,
        ),
      if (overdueMaintenanceCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.overdueMaintenance,
          level: OperationsManagementSignalLevel.warning,
          title:
              '$overdueMaintenanceCount maintenance '
              '${overdueMaintenanceCount == 1 ? 'counter is' : 'counters are'} overdue',
          detail: 'Review cadence exposure and planned intervention.',
          count: overdueMaintenanceCount,
        ),
      if (activeInspectionFindingCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.inspectionFindings,
          level: OperationsManagementSignalLevel.warning,
          title:
              '$activeInspectionFindingCount inspection '
              '${activeInspectionFindingCount == 1 ? 'finding is' : 'findings are'} active',
          detail:
              '$awaitingInspectionVerificationCount await verification evidence.',
          count: activeInspectionFindingCount,
        ),
      if (openIssueCount - openCriticalIssueCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.openIssues,
          level: OperationsManagementSignalLevel.attention,
          title:
              openCriticalIssueCount == 0
                  ? '$openIssueCount '
                      '${openIssueCount == 1 ? 'issue remains' : 'issues remain'} open'
                  : '${openIssueCount - openCriticalIssueCount} other '
                      '${openIssueCount - openCriticalIssueCount == 1 ? 'issue remains' : 'issues remain'} open',
          detail: 'Review lane ownership and resolution progress.',
          count: openIssueCount - openCriticalIssueCount,
        ),
      if (openPlannedJobCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.openPlannedWork,
          level: OperationsManagementSignalLevel.attention,
          title:
              '$openPlannedJobCount planned '
              '${openPlannedJobCount == 1 ? 'job remains' : 'jobs remain'} active',
          detail: 'Review execution progress, modules and closure readiness.',
          count: openPlannedJobCount,
        ),
    ];
    return List<OperationsManagementSignal>.unmodifiable(signals);
  }

  String get leadingManagementSignal {
    final signals = managementSignals;
    return signals.isEmpty
        ? 'No active exception leads the selected scope'
        : signals.first.title;
  }

  List<MaintenanceRecord> get openIssues {
    final rows = tickets.where((ticket) => !ticket.isResolved).toList();
    rows.sort((left, right) {
      if (left.isCritical != right.isCritical) return left.isCritical ? -1 : 1;
      return right.startDate.compareTo(left.startDate);
    });
    return List<MaintenanceRecord>.unmodifiable(rows);
  }
}
