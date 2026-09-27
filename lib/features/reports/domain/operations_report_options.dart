enum MaintenanceReportPeriodBasis {
  activeDuring,
  openedDuring,
  completedDuring,
}

extension MaintenanceReportPeriodBasisLabel on MaintenanceReportPeriodBasis {
  String get label => switch (this) {
    MaintenanceReportPeriodBasis.activeDuring => 'Active during period',
    MaintenanceReportPeriodBasis.openedDuring =>
      'Opened / assigned during period',
    MaintenanceReportPeriodBasis.completedDuring =>
      'Resolved / completed during period',
  };
  String get explanation => switch (this) {
    MaintenanceReportPeriodBasis.activeDuring =>
      'Includes work whose opening-to-closure interval overlaps the selected days. Older open work is included. Status is current, not reconstructed at period end.',
    MaintenanceReportPeriodBasis.openedDuring =>
      'Issues first opened and planned jobs assigned during the selected days. Later reopen events do not change the original opening date. Status is current.',
    MaintenanceReportPeriodBasis.completedDuring =>
      'Issues with a technical resolution in the selected days, including retained prior resolution cycles, and planned jobs completed then. Administrative closure and cancellation are not technical completion. Status is current.',
  };
}

enum QualityReportPeriodBasis { firstReported, raPerformed, outstanding }

extension QualityReportPeriodBasisLabel on QualityReportPeriodBasis {
  String get label => switch (this) {
    QualityReportPeriodBasis.firstReported =>
      'Cases first reported during period',
    QualityReportPeriodBasis.raPerformed => 'RA performed during period',
    QualityReportPeriodBasis.outstanding => 'Outstanding now',
  };
  String get explanation => switch (this) {
    QualityReportPeriodBasis.firstReported =>
      'Case first-report time selects the population; current decisions and outcomes are shown. Warning lifecycle rows are linked evidence, not additional cases.',
    QualityReportPeriodBasis.raPerformed =>
      'Uses the explicitly recorded physical RA completion time. Historical completed cases without that time are listed separately as undated evidence; no completion date is inferred from edits.',
    QualityReportPeriodBasis.outstanding =>
      'Current pending decision / required RA cases and cases with open Quality warnings, irrespective of the selected dates. This is a current snapshot, not historical outstanding status.',
  };
}

enum QualityReportSource { all, direct, maintenanceIssue }

extension QualityReportSourceLabel on QualityReportSource {
  String get label => switch (this) {
    QualityReportSource.all => 'Both reporting routes',
    QualityReportSource.direct => 'Direct abnormality log',
    QualityReportSource.maintenanceIssue => 'Maintenance issue',
  };
}

enum QualityReportKind { all, processEquipment, resultFinding }

extension QualityReportKindLabel on QualityReportKind {
  String get label => switch (this) {
    QualityReportKind.all => 'All observation kinds',
    QualityReportKind.processEquipment => 'Process / equipment observations',
    QualityReportKind.resultFinding => 'Result / coil findings',
  };
}
