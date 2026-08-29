import '../../assets/domain/plant_asset_overview.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../critical_alarm/domain/critical_alarm_models.dart';
import '../../directives/data/operational_directive_model.dart';
import '../../inspections/data/inspection_campaign.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/data/compliance_request_record.dart';
import '../../maintenance_workflow/data/job_lane_record.dart';
import '../../operational_events/data/operational_event.dart';
import '../../planned_maintenance/data/maintenance_intelligence.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../quality/data/quality_warning.dart';

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
  safetyCriticalAlarms,
  unavailableAssets,
  criticalIssues,
  operationalDisruptions,
  overdueMaintenance,
  inspectionFindings,
  qualityWarnings,
  workflowObligations,
  activeDirectives,
  criticalAbnormalities,
  qualityMonitoring,
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
    this.innerCoverProfiles = const [],
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
    this.inventoryAssetCount,
    this.inventoryAvailableAssetCount,
    this.inventoryUnderMaintenanceAssetCount,
    this.inventoryDownAssetCount,
    this.inventoryUnfitAssetCount,
    this.qualityWarnings = const [],
    this.qualityMonitoringRequests = const [],
    this.abnormalities = const [],
    this.directives = const [],
    this.workflowLanes = const [],
    this.complianceRequests = const [],
    this.criticalAlarms = const [],
    this.sourceQualityWarningCount = 0,
    this.sourceQualityMonitoringCount = 0,
    this.sourceAbnormalityCount = 0,
    this.sourceDirectiveCount = 0,
    this.sourceWorkflowLaneCount = 0,
    this.sourceComplianceRequestCount = 0,
    this.sourceCriticalAlarmCount = 0,
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
  final List<InnerCoverProfile> innerCoverProfiles;
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
  final int? inventoryAssetCount;
  final int? inventoryAvailableAssetCount;
  final int? inventoryUnderMaintenanceAssetCount;
  final int? inventoryDownAssetCount;
  final int? inventoryUnfitAssetCount;
  final List<QualityWarning> qualityWarnings;
  final List<QualityMonitoringRequest> qualityMonitoringRequests;
  final List<ChargeAbnormality> abnormalities;
  final List<OperationalDirective> directives;
  final List<JobLaneRecord> workflowLanes;
  final List<ComplianceRequestRecord> complianceRequests;
  final List<CriticalAlarm> criticalAlarms;
  final int sourceQualityWarningCount;
  final int sourceQualityMonitoringCount;
  final int sourceAbnormalityCount;
  final int sourceDirectiveCount;
  final int sourceWorkflowLaneCount;
  final int sourceComplianceRequestCount;
  final int sourceCriticalAlarmCount;

  int get issueCount => tickets.length;
  int get openIssueCount =>
      tickets.where((ticket) => !ticket.isResolved).length;
  int get resolvedIssueCount =>
      tickets.where((ticket) => ticket.wasTechnicallyResolved).length;
  int get administrativelyClosedIssueCount =>
      tickets.where((ticket) => ticket.wasClosedWithoutResolution).length;
  int get retainedUnresolvedClosureCount =>
      tickets
          .where(
            (ticket) =>
                ticket.administrativeClosure?.disposition.name ==
                'stillRelevant',
          )
          .length;
  int get terminalIssueCount =>
      resolvedIssueCount + administrativelyClosedIssueCount;
  int get issueReopenEventCount {
    var count = 0;
    for (final ticket in tickets) {
      final instants = <int>{};
      final history = ticket.resolutionHistoryReadResult;
      if (!history.isValid) {
        throw StateError(
          'Issue ${ticket.firestoreId ?? ticket.id} has invalid resolution history.',
        );
      }
      for (final entry in history.entries) {
        final reopenedAt = entry.reopenedAt;
        if (reopenedAt != null) {
          instants.add(reopenedAt.toUtc().microsecondsSinceEpoch);
        }
      }
      final reopenedAt = ticket.reopenedAt;
      if (reopenedAt != null) {
        instants.add(reopenedAt.toUtc().microsecondsSinceEpoch);
      }
      count += instants.length;
    }
    return count;
  }

  int get reopenedIssueCount =>
      tickets.where((ticket) {
        if (ticket.reopenedAt != null) return true;
        final history = ticket.resolutionHistoryReadResult;
        if (!history.isValid) {
          throw StateError(
            'Issue ${ticket.firestoreId ?? ticket.id} has invalid resolution history.',
          );
        }
        return history.entries.any((entry) => entry.reopenedAt != null);
      }).length;

  Duration get issueImpactDuration {
    var microseconds = 0;
    for (final ticket in tickets) {
      microseconds += issueImpactDurationFor(ticket).inMicroseconds;
    }
    return Duration(microseconds: microseconds);
  }

  Duration issueImpactDurationFor(MaintenanceRecord ticket) {
    var microseconds = 0;
    for (final interval in _issueImpactIntervals(ticket)) {
      final clippedStart =
          interval.start.isAfter(filter.startInclusive)
              ? interval.start
              : filter.startInclusive;
      final clippedEnd =
          interval.end.isBefore(filter.endExclusive)
              ? interval.end
              : filter.endExclusive;
      if (clippedEnd.isAfter(clippedStart)) {
        microseconds += clippedEnd.difference(clippedStart).inMicroseconds;
      }
    }
    return Duration(microseconds: microseconds);
  }

  List<({DateTime start, DateTime end})> _issueImpactIntervals(
    MaintenanceRecord ticket,
  ) {
    final history = ticket.resolutionHistoryReadResult;
    if (!history.isValid) {
      throw StateError(
        'Issue ${ticket.firestoreId ?? ticket.id} has invalid resolution history.',
      );
    }
    final intervals = <({DateTime start, DateTime end})>[];
    var episodeStart = ticket.startDate;
    for (final entry in history.entries) {
      final resolvedAt = entry.resolvedAt;
      if (resolvedAt == null || resolvedAt.isBefore(episodeStart)) {
        throw StateError(
          'Issue ${ticket.firestoreId ?? ticket.id} has invalid lifecycle chronology.',
        );
      }
      intervals.add((start: episodeStart, end: resolvedAt));
      episodeStart = entry.reopenedAt ?? resolvedAt;
    }
    final latestReopen = ticket.reopenedAt;
    if (latestReopen != null && latestReopen.isAfter(episodeStart)) {
      episodeStart = latestReopen;
    }
    final currentEnd = ticket.endDate ?? asOf;
    if (currentEnd.isAfter(episodeStart)) {
      intervals.add((start: episodeStart, end: currentEnd));
    }
    return intervals;
  }

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

  int get activeCriticalAlarmCount =>
      criticalAlarms.where((alarm) => alarm.isActive).length;
  int get highestActiveCriticalAlarmCount =>
      criticalAlarms.where((alarm) => alarm.isActive && alarm.isHighest).length;
  int get awaitingCriticalAlarmSupportCount =>
      criticalAlarms.where((alarm) => alarm.isRinging).length;
  int get resolvedCriticalAlarmCount =>
      criticalAlarms
          .where((alarm) => alarm.status == CriticalAlarmStatus.resolved)
          .length;
  int get withdrawnCriticalAlarmCount =>
      criticalAlarms
          .where(
            (alarm) => alarm.status == CriticalAlarmStatus.withdrawnInError,
          )
          .length;

  int get openQualityWarningCount =>
      qualityWarnings.where((warning) => warning.isOpen).length;
  int get qualityClosureRequestCount =>
      qualityWarnings
          .where(
            (warning) =>
                warning.status == QualityWarningStatus.closureRequested,
          )
          .length;
  int get activeQualityMonitoringCount =>
      qualityMonitoringRequests
          .where((request) => request.status == QualityMonitoringStatus.active)
          .length;

  int get highSeverityAbnormalityCount =>
      abnormalities
          .where(
            (record) =>
                !record.isDeleted &&
                (record.severity == AbnormalitySeverity.high ||
                    record.severity == AbnormalitySeverity.critical),
          )
          .length;
  int get pendingReannealingCount =>
      abnormalities
          .where(
            (record) =>
                !record.isDeleted &&
                record.reannealingStatus == ReannealingStatus.required,
          )
          .length;

  int get activeDirectiveCount =>
      directives.where((directive) => !directive.isClosed).length;
  int get highPriorityDirectiveCount =>
      directives
          .where(
            (directive) =>
                !directive.isClosed &&
                (directive.priority == DirectivePriority.high ||
                    directive.priority == DirectivePriority.critical),
          )
          .length;

  bool _isActiveLane(JobLaneRecord lane) =>
      !lane.isDeleted &&
      !const {'closed', 'removed', 'terminated'}.contains(lane.statusKey);
  bool _isActiveCompliance(ComplianceRequestRecord request) =>
      !request.isDeleted &&
      !const {
        'confirmedClosed',
        'superseded',
        'cancelled',
      }.contains(request.statusKey);

  int get activeWorkflowLaneCount => workflowLanes.where(_isActiveLane).length;
  int get pendingLaneAcknowledgementCount =>
      workflowLanes
          .where((lane) => _isActiveLane(lane) && lane.statusKey == 'pending')
          .length;
  int get activeComplianceRequestCount =>
      complianceRequests.where(_isActiveCompliance).length;
  int get dueComplianceRequestCount =>
      complianceRequests
          .where(
            (request) =>
                _isActiveCompliance(request) && request.becameDueAt != null,
          )
          .length;
  int get workflowObligationCount =>
      pendingLaneAcknowledgementCount + dueComplianceRequestCount;

  int get assetCount => inventoryAssetCount ?? assetStates.length;
  int get availableAssetCount =>
      inventoryAvailableAssetCount ??
      assetStates.where((state) => state.isAvailable).length;
  int get underMaintenanceAssetCount =>
      inventoryUnderMaintenanceAssetCount ??
      assetStates.where((state) => state.isUnderMaintenance).length;
  int get downAssetCount =>
      inventoryDownAssetCount ??
      assetStates.where((state) => state.isDown).length;
  int get unfitAssetCount =>
      inventoryUnfitAssetCount ??
      assetStates.where((state) => state.isUnfit).length;

  double? get assetAvailabilityRate =>
      assetCount == 0 ? null : availableAssetCount / assetCount;

  double? get issueClosureRate =>
      issueCount == 0 ? null : terminalIssueCount / issueCount;

  double? get plannedCompletionRate =>
      plannedJobCount == 0 ? null : completedPlannedJobCount / plannedJobCount;

  int get unavailableAssetCount => assetCount - availableAssetCount;
  int get highRiskUnavailableAssetCount => downAssetCount + unfitAssetCount;

  int get actionBacklogCount =>
      openIssueCount +
      openPlannedJobCount +
      openDisruptionCount +
      activeDirectiveCount +
      workflowObligationCount +
      openQualityWarningCount +
      activeCriticalAlarmCount;

  int get assuranceBacklogCount =>
      overdueMaintenanceCount +
      activeInspectionFindingCount +
      qualityClosureRequestCount +
      pendingReannealingCount;

  List<OperationsManagementSignal> get managementSignals {
    final signals = <OperationsManagementSignal>[
      if (activeCriticalAlarmCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.safetyCriticalAlarms,
          level: OperationsManagementSignalLevel.critical,
          title:
              '$activeCriticalAlarmCount safety-critical '
              '${activeCriticalAlarmCount == 1 ? 'alarm is' : 'alarms are'} active',
          detail:
              '$highestActiveCriticalAlarmCount highest-criticality; '
              '$awaitingCriticalAlarmSupportCount await support confirmation.',
          count: activeCriticalAlarmCount,
        ),
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
      if (qualityClosureRequestCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.qualityWarnings,
          level: OperationsManagementSignalLevel.critical,
          title:
              '$qualityClosureRequestCount quality closure '
              '${qualityClosureRequestCount == 1 ? 'request awaits' : 'requests await'} decision',
          detail:
              'Review charge evidence before accepting or rejecting closure.',
          count: qualityClosureRequestCount,
        ),
      if (highPriorityDirectiveCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.activeDirectives,
          level: OperationsManagementSignalLevel.critical,
          title:
              '$highPriorityDirectiveCount high-priority '
              '${highPriorityDirectiveCount == 1 ? 'directive is' : 'directives are'} active',
          detail:
              'Confirm acknowledgement, owner response and closure evidence.',
          count: highPriorityDirectiveCount,
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
      if (workflowObligationCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.workflowObligations,
          level: OperationsManagementSignalLevel.warning,
          title:
              '$workflowObligationCount workflow '
              '${workflowObligationCount == 1 ? 'obligation needs' : 'obligations need'} action',
          detail:
              '$pendingLaneAcknowledgementCount lane acknowledgements and '
              '$dueComplianceRequestCount due compliance requests.',
          count: workflowObligationCount,
        ),
      if (openQualityWarningCount - qualityClosureRequestCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.qualityWarnings,
          level: OperationsManagementSignalLevel.warning,
          title:
              '${openQualityWarningCount - qualityClosureRequestCount} quality '
              '${openQualityWarningCount - qualityClosureRequestCount == 1 ? 'warning remains' : 'warnings remain'} open',
          detail:
              'Review affected charges, operating evidence and disposition path.',
          count: openQualityWarningCount - qualityClosureRequestCount,
        ),
      if (highSeverityAbnormalityCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.criticalAbnormalities,
          level: OperationsManagementSignalLevel.warning,
          title:
              '$highSeverityAbnormalityCount high-severity charge '
              '${highSeverityAbnormalityCount == 1 ? 'abnormality was' : 'abnormalities were'} recorded',
          detail:
              '$pendingReannealingCount currently require re-annealing follow-through.',
          count: highSeverityAbnormalityCount,
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
      if (activeDirectiveCount - highPriorityDirectiveCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.activeDirectives,
          level: OperationsManagementSignalLevel.attention,
          title:
              '${activeDirectiveCount - highPriorityDirectiveCount} other '
              '${activeDirectiveCount - highPriorityDirectiveCount == 1 ? 'directive remains' : 'directives remain'} active',
          detail: 'Review acknowledgement and closure ownership.',
          count: activeDirectiveCount - highPriorityDirectiveCount,
        ),
      if (activeQualityMonitoringCount > 0)
        OperationsManagementSignal(
          type: OperationsManagementSignalType.qualityMonitoring,
          level: OperationsManagementSignalLevel.attention,
          title:
              '$activeQualityMonitoringCount quality monitoring '
              '${activeQualityMonitoringCount == 1 ? 'request is' : 'requests are'} active',
          detail:
              'Track selected bases, grades, cycles and charges to completion.',
          count: activeQualityMonitoringCount,
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
