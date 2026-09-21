import 'operations_report_document.dart';

enum OperationsReportSource {
  issues,
  plannedWork,
  disruptions,
  cadence,
  inspections,
  qualityWarnings,
  monitoring,
  abnormalities,
  directives,
  workflowLanes,
  compliance,
  alarms,
  plantCondition,
}

/// The report's required source families, distinct from the PDF layout.
/// Asset identities are always loaded so an unavailable selection never widens.
class OperationsReportQueryPlan {
  const OperationsReportQueryPlan.all() : _bits = (1 << 13) - 1;
  const OperationsReportQueryPlan._(this._bits);

  factory OperationsReportQueryPlan.forSections(
    Set<OperationsReportSection> sections,
  ) {
    if (sections.isEmpty) {
      throw ArgumentError('Select at least one report section.');
    }
    var bits = 0;
    void add(OperationsReportSource source) => bits |= 1 << source.index;
    for (final section in sections) {
      switch (section) {
        case OperationsReportSection.executiveSummary:
          return const OperationsReportQueryPlan.all();
        case OperationsReportSection.assetCondition:
          add(OperationsReportSource.plantCondition);
          add(OperationsReportSource.issues);
          add(OperationsReportSource.plannedWork);
        case OperationsReportSection.maintenanceIssues:
        case OperationsReportSection.reliability:
          add(OperationsReportSource.issues);
        case OperationsReportSection.plannedMaintenance:
          add(OperationsReportSource.plannedWork);
          add(OperationsReportSource.cadence);
        case OperationsReportSection.operationalControl:
          add(OperationsReportSource.disruptions);
          add(OperationsReportSource.directives);
          add(OperationsReportSource.workflowLanes);
          add(OperationsReportSource.compliance);
        case OperationsReportSection.qualityAndAssurance:
          add(OperationsReportSource.inspections);
          add(OperationsReportSource.qualityWarnings);
          add(OperationsReportSource.monitoring);
          add(OperationsReportSource.abnormalities);
        case OperationsReportSection.plantDisruptions:
          add(OperationsReportSource.disruptions);
        case OperationsReportSection.safetyCriticalAlarms:
          add(OperationsReportSource.alarms);
        case OperationsReportSection.burnerUvCondition:
          // Loaded separately by selected physical Furnace identity.
          break;
      }
    }
    return OperationsReportQueryPlan._(bits);
  }

  final int _bits;
  bool includes(OperationsReportSource source) =>
      _bits & (1 << source.index) != 0;
  bool covers(OperationsReportQueryPlan required) =>
      _bits & required._bits == required._bits;
  bool get isComplete => this == const OperationsReportQueryPlan.all();

  @override
  bool operator ==(Object other) =>
      other is OperationsReportQueryPlan && other._bits == _bits;
  @override
  int get hashCode => _bits.hashCode;
}
