import 'dart:convert';

import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_evidence_snapshot.dart';
import 'package:crm3_baf_ops/features/inspections/repositories/inspection_repository.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_report.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/services/structured_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bounded comparison report distinguishes limit status from evidence',
    () {
      const definition = FrozenInspectionDefinition(
        schemaVersion: 2,
        id: 'definition-1',
        version: 3,
        code: 'PRESSURE',
        title: 'Pressure',
        description: 'Record pressure.',
        assetTypeKeys: ['furnace'],
        assetClassIds: ['class-furnace'],
        componentNodeIds: ['burner-block'],
        valueType: null,
        unit: null,
        choiceValues: [],
        minimumValue: null,
        maximumValue: null,
        preconditions: [],
        requiresChargeNo: false,
        readingFields: [
          InspectionReadingField(
            id: 'pressure',
            label: 'Pressure',
            valueType: InspectionValueType.number,
            unit: 'bar',
            maximumValue: 5,
          ),
        ],
      );
      final campaign = _campaign(
        definition: definition,
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'reading-1',
        lastObservedAt: _time(1),
        observationCount: 1,
      );
      final observation = _observation(
        campaign,
        id: 'reading-1',
        value: true,
        observedAt: _time(1),
        comparisonOutcome: InspectionComparisonOutcome.unchanged,
        readings: const [
          InspectionReadingValue(
            fieldId: 'pressure',
            valueType: InspectionValueType.number,
            value: 4,
          ),
        ],
      );
      final report = buildInspectionCampaignReport(
        campaign: campaign,
        observations: [observation],
        findings: [],
        createdFindingIds: [],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      );
      final row = report.sections[2].tables.single.rows.single;
      expect(row[5], contains('Limit status unchanged from baseline'));
      expect(row[5].split('\n'), isNot(contains('Unchanged')));
      expect(row[2], contains('Pressure: 4 bar'));
    },
  );

  test(
    'multi-reading dossier keeps every label, date and superseded value',
    () async {
      const definition = FrozenInspectionDefinition(
        schemaVersion: 2,
        id: 'definition-1',
        version: 3,
        code: 'FURNACE_READING_SET',
        title: 'Furnace examination',
        description: 'Record the complete examination.',
        assetTypeKeys: ['furnace'],
        assetClassIds: ['class-furnace'],
        componentNodeIds: ['burner-block'],
        valueType: null,
        unit: null,
        choiceValues: [],
        minimumValue: null,
        maximumValue: null,
        preconditions: [],
        requiresChargeNo: false,
        readingFields: [
          InspectionReadingField(
            id: 'verified',
            label: 'Seal verified',
            valueType: InspectionValueType.boolean,
          ),
          InspectionReadingField(
            id: 'date',
            label: 'Next examination',
            valueType: InspectionValueType.date,
          ),
          InspectionReadingField(
            id: 'pressure',
            label: 'Pressure',
            valueType: InspectionValueType.number,
            unit: 'bar',
            maximumValue: 5,
          ),
        ],
      );
      final campaign = _campaign(
        definition: definition,
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'corrected',
        lastObservedAt: _time(1),
        observationCount: 2,
      );
      final readings = [
        const InspectionReadingValue(
          fieldId: 'verified',
          valueType: InspectionValueType.boolean,
          value: false,
        ),
        const InspectionReadingValue(
          fieldId: 'date',
          valueType: InspectionValueType.date,
          value: '2032-02-29',
        ),
        const InspectionReadingValue(
          fieldId: 'pressure',
          valueType: InspectionValueType.number,
          value: 7.5,
        ),
      ];
      final original = _observation(
        campaign,
        id: 'original',
        value: false,
        observedAt: _time(1),
        readings: readings,
      );
      final corrected = _observation(
        campaign,
        id: 'corrected',
        value: false,
        observedAt: _time(1),
        supersedesObservationId: 'original',
        readings: [
          readings[0],
          const InspectionReadingValue(
            fieldId: 'date',
            valueType: InspectionValueType.date,
            value: '2040-12-31',
          ),
          readings[2],
        ],
      );
      final report = buildInspectionCampaignReport(
        campaign: campaign,
        observations: [original, corrected],
        findings: [
          InspectionFinding(
            id: 'pressure-finding',
            version: 1,
            campaignId: campaign.id,
            targetKey: original.targetKey,
            assetTypeKey: 'furnace',
            assetNumber: 22,
            assetClassId: 'class-furnace',
            assetInstanceId: 'furnace-22',
            componentNodeId: 'burner-block',
            componentName: 'Burner Block',
            physicalPosition: 'Position 4',
            status: InspectionFindingStatus.open,
            firstObservationId: original.id,
            currentObservationId: corrected.id,
            firstObservedAt: original.observedAt,
            latestObservedAt: corrected.observedAt,
            recurrenceCount: 1,
            linkedTicketId: null,
            verificationCount: 0,
            lastVerificationOutcome: null,
            updatedAt: _time(2),
          ),
        ],
        createdFindingIds: ['pressure-finding'],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      );
      final contracts = report.sections.first.fields
          .map((field) => field.value)
          .join('\n');
      expect(contracts, contains('Seal verified: Yes / No'));
      expect(contracts, contains('Next examination: Date (DD-MM-YYYY)'));
      expect(contracts, contains('Pressure: Number in bar; maximum 5.0'));
      final target = report.sections[1].tables.single.rows.single.join('\n');
      expect(
        target,
        contains(
          'Seal verified: No\nNext examination: 31-12-2040\nPressure: 7.5 bar',
        ),
      );
      final history = report.sections[2].tables.single.rows
          .map((row) => row.join('\n'))
          .join('\n');
      expect(history, contains('Next examination: 29-02-2032'));
      expect(history, contains('Superseded'));
      expect(history, contains('Corrects original'));
      expect(history, contains('Exception recorded'));
      expect(history, isNot(contains('2032-02-29')));
      final bytes = await StructuredReportPdfService.build(report);
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    },
  );

  test(
    'maximum labelled text readings paginate without dropping values',
    () async {
      final fields = [
        for (var i = 0; i < 20; i++)
          InspectionReadingField(
            id: 'field_$i',
            label: 'Witnessed condition $i',
            valueType: InspectionValueType.text,
          ),
      ];
      final definition = FrozenInspectionDefinition(
        schemaVersion: 2,
        readingFields: fields,
        id: 'definition-1',
        version: 3,
        code: 'MULTI_TEXT',
        title: 'Full reading set',
        description: 'Twenty labelled readings.',
        assetTypeKeys: ['furnace'],
        assetClassIds: ['class-furnace'],
        componentNodeIds: ['burner-block'],
        valueType: null,
        unit: null,
        choiceValues: [],
        minimumValue: null,
        maximumValue: null,
        preconditions: [],
        requiresChargeNo: false,
      );
      final campaign = _campaign(
        definition: definition,
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'all-fields',
        lastObservedAt: _time(1),
        observationCount: 1,
      );
      final observation = _observation(
        campaign,
        id: 'all-fields',
        value: true,
        observedAt: _time(1),
        readings: [
          for (final field in fields)
            InspectionReadingValue(
              fieldId: field.id,
              valueType: field.valueType,
              value: '${field.id} ${'Observed detail. ' * 60}',
            ),
        ],
      );
      final report = buildInspectionCampaignReport(
        campaign: campaign,
        observations: [observation],
        findings: [],
        createdFindingIds: [],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      );
      for (final field in fields) {
        expect(
          report.sections
              .expand((section) => section.tables)
              .expand((table) => table.rows)
              .expand((row) => row)
              .join('\n'),
          contains('${field.label}:'),
        );
      }
      final bytes = await StructuredReportPdfService.build(report);
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    },
  );

  test('campaign freshness does not erase rejected population identities', () {
    const snapshot = InspectionEvidenceSnapshot<String>(
      records: ['valid'],
      isServerVerified: true,
      rejectedDocumentIds: ['unreadable'],
    );
    expect(snapshot.isServerVerified, isTrue);
    expect(snapshot.isComplete, isFalse);
    expect(snapshot.rawCount, 2);
    expect(snapshot.records, ['valid']);
  });

  test('creation history is strict and keeps terminal episode identities', () {
    expect(
      () => readInspectionFindingCreationIds(
        [],
        'campaign-1',
        expectedManifest: ['inspection-finding-missing'],
      ),
      throwsStateError,
    );
    final create = <String, dynamic>{
      'schemaVersion': 1,
      'eventId': 'event-1',
      'campaignId': 'campaign-1',
      'findingId': 'inspection-finding-reading-1',
      'operation': 'create',
      'observationId': 'reading-1',
      'previousStatus': null,
    };
    expect(
      readInspectionFindingCreationIds([
        (id: 'event-1', data: create),
      ], 'campaign-1'),
      ['inspection-finding-reading-1'],
    );
    for (final bad in [
      <String, dynamic>{...create, 'findingId': 'wrong'},
      {...create, 'campaignId': 'other'},
      {...create, 'operation': 'unknown'},
    ]) {
      expect(
        () => readInspectionFindingCreationIds([
          (id: 'event-1', data: bad),
        ], 'campaign-1'),
        throwsStateError,
      );
    }
    expect(
      () => readInspectionFindingCreationIds([
        (id: 'event-1', data: create),
        (id: 'event-2', data: {...create, 'eventId': 'event-2'}),
      ], 'campaign-1'),
      throwsStateError,
    );
  });

  test('an empty campaign cannot produce an audit report', () {
    final campaign = _campaign();

    expect(
      hasInspectionCampaignReportEvidence(
        campaign: campaign,
        observations: const <InspectionObservation>[],
      ),
      isFalse,
    );
    expect(
      () => buildInspectionCampaignReport(
        campaign: campaign,
        observations: const <InspectionObservation>[],
        findings: const <InspectionFinding>[],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      ),
      throwsStateError,
    );
  });

  test('an accounted target is reportable without a measured reading', () {
    final campaign = _campaign(
      disposition: InspectionTargetDisposition.unavailable,
      dispositionReason: 'Asset was isolated during the audit window.',
    );

    expect(
      hasInspectionCampaignReportEvidence(
        campaign: campaign,
        observations: const <InspectionObservation>[],
      ),
      isTrue,
    );
    final report = buildInspectionCampaignReport(
      campaign: campaign,
      observations: const <InspectionObservation>[],
      findings: const <InspectionFinding>[],
      generatedAt: _time(3),
      generatedByName: 'Admin One',
      provenance: const ReportProvenance.applicationSnapshot(),
    );

    expect(report.title, 'Inspection audit dossier');
    expect(report.orientation.name, 'landscape');
    expect(report.sections, hasLength(2));
    expect(
      report.sections[1].tables.single.rows.single,
      contains('Unavailable\nAsset was isolated during the audit window.'),
    );
  });

  test('the dossier retains readings, corrections and findings', () async {
    final campaign = _campaign(
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-2',
      lastObservedAt: _time(2),
      observationCount: 2,
    );
    final first = _observation(
      campaign,
      id: 'reading-1',
      value: true,
      observedAt: _time(1),
    );
    final correction = _observation(
      campaign,
      id: 'reading-2',
      value: false,
      observedAt: _time(2),
      supersedesObservationId: 'reading-1',
    );
    final finding = InspectionFinding(
      id: 'finding-1',
      version: 2,
      campaignId: campaign.id,
      targetKey: campaign.targets.single.targetKey,
      assetTypeKey: 'furnace',
      assetNumber: 22,
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      componentNodeId: 'burner-block',
      componentName: 'Burner Block',
      physicalPosition: 'Position 4',
      status: InspectionFindingStatus.correctiveActionLinked,
      firstObservationId: first.id,
      currentObservationId: correction.id,
      firstObservedAt: first.observedAt,
      latestObservedAt: correction.observedAt,
      recurrenceCount: 1,
      effectiveAdverseObservationCount: 0,
      evidenceReviewRequired: true,
      evidenceReviewReason: 'inspection-episode-adverse-basis-corrected',
      linkedTicketId: 'ticket-44',
      verificationCount: 1,
      lastVerificationOutcome: InspectionComparisonOutcome.unchanged,
      updatedAt: _time(2),
    );

    final report = buildInspectionCampaignReport(
      campaign: campaign,
      observations: <InspectionObservation>[correction, first],
      findings: <InspectionFinding>[finding],
      createdFindingIds: <String>[finding.id],
      generatedAt: _time(3),
      generatedByName: 'Admin One',
      provenance: const ReportProvenance.applicationSnapshot(),
    );

    for (final rows in <List<InspectionFinding>>[
      [],
      [finding, finding],
    ]) {
      expect(
        InspectionCampaignReportEvidence(
          campaign: campaign,
          observations: [correction, first],
          findings: rows,
          createdFindingIds: [finding.id],
        ).isInternallyComplete,
        isFalse,
      );
    }
    expect(
      InspectionCampaignReportEvidence(
        campaign: campaign,
        observations: [correction, first],
        findings: [finding],
        createdFindingIds: [finding.id, 'missing-terminal-episode'],
      ).isInternallyComplete,
      isFalse,
    );
    expect(
      InspectionCampaignReportEvidence(
        campaign: campaign,
        observations: [correction, first],
        findings: [finding],
        createdFindingIds: [],
      ).isInternallyComplete,
      isFalse,
    );

    expect(report.sections, hasLength(4));
    expect(
      report.sections.first.metrics
          .singleWhere((metric) => metric.label == 'Findings')
          .detail,
      '1 outstanding',
    );
    final readingRows = report.sections[2].tables.single.rows;
    expect(readingRows.first[2], contains('Superseded'));
    expect(readingRows.last[2], contains('Current'));
    expect(readingRows.last[5], contains('Corrects reading-1'));
    expect(
      report.sections[3].tables.single.rows.single.last,
      contains('Issue ticket-44'),
    );
    expect(report.sections[3].tables.single.rows.single[4], '0');
    expect(
      report.sections[3].tables.single.rows.single.last,
      contains('Last: Unchanged'),
    );
    expect(
      report.sections[3].tables.single.rows.single.last,
      isNot(contains('Limit status')),
    );
    expect(
      report.sections[3].tables.single.rows.single.last,
      contains('record a decision'),
    );

    final bytes = await StructuredReportPdfService.build(report);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(10000));
  });

  test('evidence from another campaign is rejected', () {
    final campaign = _campaign(
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: _time(1),
      observationCount: 1,
    );
    final foreign = _observation(
      campaign,
      id: 'reading-1',
      value: true,
      observedAt: _time(1),
      campaignId: 'another-campaign',
    );

    expect(
      () => buildInspectionCampaignReport(
        campaign: campaign,
        observations: <InspectionObservation>[foreign],
        findings: const <InspectionFinding>[],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      ),
      throwsStateError,
    );
  });

  test('an incomplete campaign projection cannot produce an audit report', () {
    final campaign = _campaign(
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: _time(1),
      observationCount: 1,
    );

    expect(
      () => buildInspectionCampaignReport(
        campaign: campaign,
        observations: const <InspectionObservation>[],
        findings: const <InspectionFinding>[],
        generatedAt: _time(3),
        generatedByName: 'Admin One',
        provenance: const ReportProvenance.applicationSnapshot(),
      ),
      throwsStateError,
    );
  });
}

DateTime _time(int hour) => DateTime.utc(2026, 9, 6, hour);

InspectionCampaign _campaign({
  FrozenInspectionDefinition? definition,
  InspectionTargetDisposition disposition = InspectionTargetDisposition.pending,
  String? dispositionReason,
  String? lastObservationId,
  DateTime? lastObservedAt,
  int observationCount = 0,
}) {
  final target = InspectionCampaignTarget(
    targetKey: 'class-furnace:furnace-22|burner-block|Position 4',
    assetTypeKey: 'furnace',
    assetClassId: 'class-furnace',
    assetNumber: 22,
    assetInstanceId: 'furnace-22',
    assetInstanceVersion: 3,
    assetInstanceName: 'Furnace 22',
    hostAssetClassId: null,
    hostAssetInstanceId: null,
    hostAssetInstanceVersion: null,
    hostAssetNumber: null,
    hostAssetInstanceName: null,
    subjectSerialNumber: null,
    linkageId: null,
    linkageVersion: null,
    linkedAt: null,
    componentNodeId: 'burner-block',
    physicalPosition: 'Position 4',
    disposition: disposition,
    dispositionReason: dispositionReason,
    dispositionAt: _time(2),
    dispositionByUid: 'admin-1',
    dispositionByName: 'Admin One',
    addedLater: false,
    lastObservationId: lastObservationId,
    lastObservedAt: lastObservedAt,
  );
  return InspectionCampaign(
    id: 'campaign-1',
    version: 4,
    status: InspectionCampaignStatus.open,
    definition:
        definition ??
        const FrozenInspectionDefinition(
          id: 'definition-1',
          version: 2,
          code: 'FURNACE_BURNER_BLOCK',
          title: 'Burner Block condition',
          description: 'Record governed Burner Block condition by position.',
          assetTypeKeys: <String>['furnace'],
          assetClassIds: <String>['class-furnace'],
          componentNodeIds: <String>['burner-block'],
          valueType: InspectionValueType.boolean,
          unit: null,
          choiceValues: <String>[],
          minimumValue: null,
          maximumValue: null,
          preconditions: <String>['Furnace safely observable'],
          requiresChargeNo: false,
        ),
    purpose: 'Fleet condition audit',
    assetTypeKey: 'furnace',
    assetClassId: 'class-furnace',
    populationMode: InspectionCampaignPopulationMode.assetInstances,
    hostAssetClassId: null,
    targetAssetNumbers: const <int>[22],
    physicalPositionLabels: const <String>['Position 4'],
    targets: <InspectionCampaignTarget>[target],
    expectedPopulation: 1,
    baselineCampaignId: null,
    observerRoleKeys: const <String>['operations'],
    observationCount: observationCount,
    distinctTargetKeys: observationCount == 0
        ? const <String>[]
        : <String>[target.targetKey],
    latestObservationAt: lastObservedAt,
    createdAt: _time(0),
  );
}

InspectionObservation _observation(
  InspectionCampaign campaign, {
  List<InspectionReadingValue> readings = const [],
  InspectionComparisonOutcome? comparisonOutcome,
  required String id,
  required bool value,
  required DateTime observedAt,
  String? supersedesObservationId,
  String? campaignId,
}) {
  final target = campaign.targets.single;
  return InspectionObservation(
    readings: readings,
    id: id,
    campaignId: campaignId ?? campaign.id,
    definition: campaign.definition,
    assetTypeKey: target.assetTypeKey,
    assetNumber: target.assetNumber,
    assetClassId: target.assetClassId,
    assetInstanceId: target.assetInstanceId,
    hostAssetClassId: null,
    hostAssetInstanceId: null,
    hostAssetInstanceVersion: null,
    hostAssetNumber: null,
    hostAssetInstanceName: null,
    subjectSerialNumber: null,
    linkageId: null,
    linkageVersion: null,
    linkedAt: null,
    componentNodeId: target.componentNodeId,
    componentNodeVersion: 2,
    componentName: 'Burner Block',
    hierarchyPath: const <String>['Combustion system', 'Burner Block'],
    physicalPosition: target.physicalPosition,
    targetKey: target.targetKey,
    observedAt: observedAt,
    observerUid: 'operations-1',
    observerName: 'Operations One',
    numericValue: null,
    booleanValue: campaign.definition.isMultiReading ? null : value,
    textValue: null,
    choiceValue: null,
    unit: null,
    outOfRange: !value,
    operatingConditions: const <String, String>{'furnaceState': 'Heating'},
    chargeNo: 51139,
    note: value ? null : 'Red hot condition observed.',
    evidenceUrls: value
        ? const <String>[]
        : const <String>['https://evidence.invalid/photo-1'],
    supersedesObservationId: supersedesObservationId,
    baselineCampaignId: comparisonOutcome == null ? null : 'baseline-campaign',
    baselineObservationId: comparisonOutcome == null
        ? null
        : 'baseline-reading',
    comparisonOutcome: comparisonOutcome,
    recordedAt: observedAt.add(const Duration(minutes: 2)),
  );
}
