import 'report_provenance.dart';

enum OperationsReportDocumentPreset {
  executive,
  assetCondition,
  maintenance,
  reliability,
  quality,
  safetyAndDisruption,
  assurance,
  complete,
  custom,
}

extension OperationsReportDocumentPresetLabel
    on OperationsReportDocumentPreset {
  String get label => switch (this) {
    OperationsReportDocumentPreset.executive => 'Executive brief',
    OperationsReportDocumentPreset.assetCondition =>
      'Asset availability and condition',
    OperationsReportDocumentPreset.maintenance => 'Maintenance performance',
    OperationsReportDocumentPreset.reliability => 'Reliability and condition',
    OperationsReportDocumentPreset.quality => 'Quality and RA assurance',
    OperationsReportDocumentPreset.safetyAndDisruption =>
      'Safety and plant disruption',
    OperationsReportDocumentPreset.assurance => 'Assurance and control',
    OperationsReportDocumentPreset.complete => 'Integrated operations report',
    OperationsReportDocumentPreset.custom => 'Custom report',
  };

  String get description => switch (this) {
    OperationsReportDocumentPreset.executive =>
      'Management summary, plant availability and priority exceptions.',
    OperationsReportDocumentPreset.assetCondition =>
      'Current status of every asset, with availability constraints and maintenance exposure.',
    OperationsReportDocumentPreset.maintenance =>
      'Maintenance issues, planned work, cadence and current asset condition.',
    OperationsReportDocumentPreset.reliability =>
      'Failure concentrations plus the current Furnace Burner and UV snapshot.',
    OperationsReportDocumentPreset.quality =>
      'Warnings, monitoring, abnormalities, RA decisions and inspection findings.',
    OperationsReportDocumentPreset.safetyAndDisruption =>
      'Critical alarms, utilities and material-handling interruptions, and response controls.',
    OperationsReportDocumentPreset.assurance =>
      'Quality, inspections, directives, lane progress and compliance obligations.',
    OperationsReportDocumentPreset.complete =>
      'The broadest integrated management view available in this report.',
    OperationsReportDocumentPreset.custom =>
      'Choose the sections required for this audience.',
  };
}

enum OperationsReportSection {
  executiveSummary,
  assetCondition,
  maintenanceIssues,
  plannedMaintenance,
  operationalControl,
  reliability,
  qualityAndAssurance,
  burnerUvCondition,
  plantDisruptions,
  safetyCriticalAlarms,
}

extension OperationsReportSectionLabel on OperationsReportSection {
  String get label => switch (this) {
    OperationsReportSection.executiveSummary => 'Executive summary',
    OperationsReportSection.assetCondition => 'Plant condition',
    OperationsReportSection.maintenanceIssues => 'Maintenance issues',
    OperationsReportSection.plannedMaintenance => 'Planned maintenance',
    OperationsReportSection.operationalControl =>
      'Operational control and workflow',
    OperationsReportSection.reliability => 'Reliability concentrations',
    OperationsReportSection.qualityAndAssurance => 'Quality and assurance',
    OperationsReportSection.burnerUvCondition =>
      'Current Burner Block and UV condition',
    OperationsReportSection.plantDisruptions => 'Plant disruptions',
    OperationsReportSection.safetyCriticalAlarms => 'Safety-critical alarms',
  };

  String get description => switch (this) {
    OperationsReportSection.executiveSummary =>
      'Selected-period outcomes and the leading management signals.',
    OperationsReportSection.assetCondition =>
      'Current fleet availability, maintenance, down and unfit state.',
    OperationsReportSection.maintenanceIssues =>
      'Issue lifecycle, ownership, component and impact evidence.',
    OperationsReportSection.plannedMaintenance =>
      'Assigned, completed, cancelled and open planned jobs.',
    OperationsReportSection.operationalControl =>
      'Disruptions, directives, lane acknowledgements and compliance.',
    OperationsReportSection.reliability =>
      'Top affected components and subsystem paths.',
    OperationsReportSection.qualityAndAssurance =>
      'Warnings, monitoring, abnormalities, RA and inspection findings.',
    OperationsReportSection.burnerUvCondition =>
      'Latest governed Furnace audit, including red-hot blocks and UV state.',
    OperationsReportSection.plantDisruptions =>
      'Utilities, cranes, transfer cars and other operating interruptions.',
    OperationsReportSection.safetyCriticalAlarms =>
      'Critical alarms, support response and terminal disposition evidence.',
  };
}

const operationsReportSectionOrder = <OperationsReportSection>[
  OperationsReportSection.executiveSummary,
  OperationsReportSection.assetCondition,
  OperationsReportSection.maintenanceIssues,
  OperationsReportSection.plannedMaintenance,
  OperationsReportSection.burnerUvCondition,
  OperationsReportSection.qualityAndAssurance,
  OperationsReportSection.plantDisruptions,
  OperationsReportSection.safetyCriticalAlarms,
  OperationsReportSection.operationalControl,
  OperationsReportSection.reliability,
];

Set<OperationsReportSection> operationsReportSectionsForPreset(
  OperationsReportDocumentPreset preset,
) => switch (preset) {
  OperationsReportDocumentPreset.executive => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
    OperationsReportSection.assetCondition,
    OperationsReportSection.operationalControl,
    OperationsReportSection.plantDisruptions,
    OperationsReportSection.safetyCriticalAlarms,
  },
  OperationsReportDocumentPreset.assetCondition => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
    OperationsReportSection.assetCondition,
    OperationsReportSection.maintenanceIssues,
    OperationsReportSection.plantDisruptions,
  },
  OperationsReportDocumentPreset.maintenance => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
    OperationsReportSection.assetCondition,
    OperationsReportSection.maintenanceIssues,
    OperationsReportSection.plannedMaintenance,
    OperationsReportSection.reliability,
  },
  OperationsReportDocumentPreset.reliability => <OperationsReportSection>{
    OperationsReportSection.assetCondition,
    OperationsReportSection.reliability,
    OperationsReportSection.burnerUvCondition,
  },
  OperationsReportDocumentPreset.quality => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
    OperationsReportSection.qualityAndAssurance,
  },
  OperationsReportDocumentPreset.safetyAndDisruption =>
    <OperationsReportSection>{
      OperationsReportSection.executiveSummary,
      OperationsReportSection.plantDisruptions,
      OperationsReportSection.safetyCriticalAlarms,
      OperationsReportSection.operationalControl,
    },
  OperationsReportDocumentPreset.assurance => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
    OperationsReportSection.operationalControl,
    OperationsReportSection.qualityAndAssurance,
    OperationsReportSection.safetyCriticalAlarms,
  },
  OperationsReportDocumentPreset.complete => Set<OperationsReportSection>.from(
    operationsReportSectionOrder,
  ),
  OperationsReportDocumentPreset.custom => <OperationsReportSection>{
    OperationsReportSection.executiveSummary,
  },
};

class OperationsReportDocumentRequest {
  OperationsReportDocumentRequest({
    required this.title,
    required this.preset,
    required Set<OperationsReportSection> sections,
    required this.generatedAt,
    required this.generatedByName,
    required this.generatedByEmail,
    required this.reportId,
    required this.provenance,
    String? snapshotStatement,
  }) : sections = Set<OperationsReportSection>.unmodifiable(sections),
       snapshotStatement = snapshotStatement ?? provenance.evidenceStatement;

  factory OperationsReportDocumentRequest.forPreset({
    required OperationsReportDocumentPreset preset,
    required DateTime generatedAt,
    required String generatedByName,
    required String generatedByEmail,
    ReportProvenance provenance = const ReportProvenance.applicationSnapshot(),
  }) {
    final instant = generatedAt.toUtc();
    final compactDate =
        _two(instant.year % 100) + _two(instant.month) + _two(instant.day);
    final compactTime =
        _two(instant.hour) + _two(instant.minute) + _two(instant.second);
    return OperationsReportDocumentRequest(
      title: preset.label,
      preset: preset,
      sections: operationsReportSectionsForPreset(preset),
      generatedAt: generatedAt,
      generatedByName: generatedByName.trim(),
      generatedByEmail: generatedByEmail.trim(),
      reportId: 'OPS-$compactDate-$compactTime',
      provenance: provenance,
    );
  }

  final String title;
  final OperationsReportDocumentPreset preset;
  final Set<OperationsReportSection> sections;
  final DateTime generatedAt;
  final String generatedByName;
  final String generatedByEmail;
  final String reportId;
  final ReportProvenance provenance;
  final String snapshotStatement;

  List<OperationsReportSection> get orderedSections =>
      operationsReportSectionOrder
          .where(sections.contains)
          .toList(growable: false);

  String get fileName {
    final cleaned = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'crm3_${cleaned.isEmpty ? 'operations_report' : cleaned}_$reportId.pdf';
  }

  OperationsReportDocumentRequest copyWith({
    String? title,
    OperationsReportDocumentPreset? preset,
    Set<OperationsReportSection>? sections,
    String? snapshotStatement,
    ReportProvenance? provenance,
  }) => OperationsReportDocumentRequest(
    title: title ?? this.title,
    preset: preset ?? this.preset,
    sections: sections ?? this.sections,
    generatedAt: generatedAt,
    generatedByName: generatedByName,
    generatedByEmail: generatedByEmail,
    reportId: reportId,
    provenance: provenance ?? this.provenance,
    snapshotStatement: snapshotStatement ?? this.snapshotStatement,
  );
}

String _two(int value) => value.toString().padLeft(2, '0');
