import '../../abnormalities/data/abnormality_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../quality/data/quality_warning.dart';
import '../models/operations_report.dart';

bool reportInstantInPeriod(DateTime instant, OperationsReportFilter filter) =>
    !instant.isBefore(filter.startInclusive) &&
    instant.isBefore(filter.endExclusive);

bool maintenanceTicketMatchesPeriod(
  MaintenanceRecord ticket,
  OperationsReportFilter filter,
) {
  switch (filter.maintenancePeriodBasis) {
    case MaintenanceReportPeriodBasis.activeDuring:
      return ticket.startDate.isBefore(filter.endExclusive) &&
          (ticket.endDate == null ||
              ticket.endDate!.isAfter(filter.startInclusive));
    case MaintenanceReportPeriodBasis.openedDuring:
      return reportInstantInPeriod(ticket.startDate, filter);
    case MaintenanceReportPeriodBasis.completedDuring:
      final history = ticket.resolutionHistoryReadResult;
      if (!history.isValid) {
        throw StateError(
          'Issue resolution history needs review before reporting.',
        );
      }
      return (ticket.wasTechnicallyResolved &&
              ticket.endDate != null &&
              reportInstantInPeriod(ticket.endDate!, filter)) ||
          history.entries.any(
            (cycle) =>
                cycle.resolvedAt != null &&
                reportInstantInPeriod(cycle.resolvedAt!, filter),
          );
  }
}

bool qualityWarningBelongsToCase(
  QualityWarning warning,
  ChargeAbnormality record,
) =>
    warning.sourceChargeNo == record.sourceChargeNo &&
    (warning.sourceType == QualityWarningSourceType.issue
        ? record.linkedTicketFirestoreId == warning.sourceId
        : record.firestoreId == warning.sourceId);

bool qualityCaseMatchesAttributes(
  ChargeAbnormality record,
  OperationsReportFilter filter,
) {
  final fromIssue = record.linkedTicketFirestoreId?.trim().isNotEmpty == true;
  if (filter.qualitySource == QualityReportSource.direct && fromIssue ||
      filter.qualitySource == QualityReportSource.maintenanceIssue &&
          !fromIssue) {
    return false;
  }
  if (filter.raOnly && !record.requiresReannealing) return false;
  // Legacy category is used only for its explicit meaning. A legacy RA label
  // alone does not prove whether the initial observation was process or result.
  final kind = record.observationKind;
  if (filter.qualityKind == QualityReportKind.processEquipment &&
      !(kind == AbnormalityObservationKind.processEquipment ||
          kind == null &&
              (record.category == AbnormalityCategory.process ||
                  record.category == AbnormalityCategory.equipment))) {
    return false;
  }
  if (filter.qualityKind == QualityReportKind.resultFinding &&
      !(kind == AbnormalityObservationKind.resultFinding ||
          kind == null &&
              record.category == AbnormalityCategory.resultQuality)) {
    return false;
  }
  return true;
}

bool qualityCaseMatchesPeriod(
  ChargeAbnormality record,
  OperationsReportFilter filter,
  Iterable<QualityWarning> warnings,
) => switch (filter.qualityPeriodBasis) {
  QualityReportPeriodBasis.firstReported => reportInstantInPeriod(
    record.loggedAt,
    filter,
  ),
  QualityReportPeriodBasis.raPerformed =>
    record.hasCompletedReannealing &&
        record.raPerformedAt != null &&
        reportInstantInPeriod(record.raPerformedAt!, filter),
  QualityReportPeriodBasis.outstanding =>
    record.reannealingStatus == ReannealingStatus.pendingDecision ||
        record.reannealingStatus == ReannealingStatus.required ||
        warnings.any((w) => w.isOpen && qualityWarningBelongsToCase(w, record)),
};
