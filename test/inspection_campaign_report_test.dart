import 'dart:convert';

import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/domain/inspection_campaign_report.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/services/structured_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      verificationCount: 0,
      lastVerificationOutcome: null,
      updatedAt: _time(2),
    );

    final report = buildInspectionCampaignReport(
      campaign: campaign,
      observations: <InspectionObservation>[correction, first],
      findings: <InspectionFinding>[finding],
      generatedAt: _time(3),
      generatedByName: 'Admin One',
      provenance: const ReportProvenance.applicationSnapshot(),
    );

    expect(report.sections, hasLength(4));
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
    definition: const FrozenInspectionDefinition(
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
  required String id,
  required bool value,
  required DateTime observedAt,
  String? supersedesObservationId,
  String? campaignId,
}) {
  final target = campaign.targets.single;
  return InspectionObservation(
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
    booleanValue: value,
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
    baselineCampaignId: null,
    baselineObservationId: null,
    comparisonOutcome: null,
    recordedAt: observedAt.add(const Duration(minutes: 2)),
  );
}
