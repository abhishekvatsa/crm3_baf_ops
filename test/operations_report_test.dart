import 'dart:convert';

import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AssetClassRecord assetClass(
  String id,
  String name,
  String? legacy, {
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetClassRecord(
  id: id,
  code: name.toUpperCase(),
  name: name,
  majorArea: 'BAF shop',
  legacyAssetTypeKey: legacy,
  status: status,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'mutation',
);

AssetInstanceRecord asset(
  String id,
  AssetClassRecord assetClass,
  int number, {
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
  AssetServiceState serviceState = AssetServiceState.inService,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: assetClass.id,
  assetClassCode: assetClass.code,
  assetClassName: assetClass.name,
  assetNumber: number,
  name: '${assetClass.name} $number',
  serviceState: serviceState,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: status,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'mutation',
);

MaintenanceRecord issue({
  required AssetType type,
  required int number,
  required DateTime started,
  String component = 'Pressure transmitter',
  String subsystem = 'Combustion control',
  bool resolved = false,
}) {
  final record =
      MaintenanceRecord()
        ..assetType = type
        ..assetNumber = number
        ..maintenanceType = MaintenanceType.breakdown
        ..description = 'Pressure control instability observed.'
        ..routedTo = RoutedTo.instrumentation
        ..status = resolved ? TicketStatus.resolved : TicketStatus.open
        ..isResolved = resolved
        ..component = component
        ..subsystem = subsystem
        ..startDate = started
        ..endDate = resolved ? started.add(const Duration(hours: 4)) : null
        ..createdAt = started
        ..updatedAt = started
        ..actionsJson = '[]'
        ..resolutionHistoryJson = '[]';
  return record;
}

JobExecution execution(DateTime created) =>
    JobExecution()
      ..templateFirestoreId = 'template-1'
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..createdAt = created
      ..updatedAt = created
      ..isCompleted = false
      ..isCancelled = false;

InspectionFinding finding({
  required String id,
  required String assetClassId,
  required String assetInstanceId,
  required InspectionFindingStatus status,
  required DateTime observedAt,
}) => InspectionFinding(
  id: id,
  version: 1,
  campaignId: 'campaign-1',
  targetKey: '$assetInstanceId:burner-1',
  assetTypeKey: 'furnace',
  assetNumber: 7,
  assetClassId: assetClassId,
  assetInstanceId: assetInstanceId,
  componentNodeId: 'burner-1',
  componentName: 'Burner block 1',
  physicalPosition: 'Burner 1',
  status: status,
  firstObservationId: 'observation-$id',
  currentObservationId: 'observation-$id',
  firstObservedAt: observedAt,
  latestObservedAt: observedAt,
  recurrenceCount: 1,
  linkedTicketId:
      status == InspectionFindingStatus.correctiveActionLinked
          ? 'ticket-$id'
          : null,
  verificationCount: status == InspectionFindingStatus.verifiedResolved ? 1 : 0,
  lastVerificationOutcome:
      status == InspectionFindingStatus.verifiedResolved
          ? InspectionComparisonOutcome.resolved
          : null,
  updatedAt: observedAt,
);

OperationalEvent event() => OperationalEvent(
  eventId: 'event-1',
  eventType: OperationalEventType.powerTrip,
  title: 'Power trip',
  description: 'Incoming supply was unavailable.',
  severity: OperationalEventSeverity.critical,
  scope: OperationalEventScope.plantWide,
  affectedAssetClassIds: const [],
  affectedAssetInstanceIds: const [],
  issueLinkIds: const ['event-issue-1', 'event-issue-2'],
  linkedIssueIds: const ['maintenance-issue-1', 'maintenance-issue-2'],
  startedAt: DateTime.utc(2026, 8, 10, 10),
  status: OperationalEventStatus.resolved,
  createdAt: DateTime.utc(2026, 8, 10, 10),
  createdByUid: 'ops',
  createdByName: 'Operations',
  resolvedAt: DateTime.utc(2026, 8, 10, 12),
  resolvedByUid: 'ops',
  resolvedByName: 'Operations',
  resolutionNote: 'Supply stable after restoration verification.',
  version: 2,
  updatedAt: DateTime.utc(2026, 8, 10, 12),
  updatedByUid: 'ops',
  updatedByName: 'Operations',
  lastMutationId: 'mutation',
);

QualityWarning qualityWarning({
  required String id,
  required AssetType type,
  required int number,
  required DateTime createdAt,
  QualityWarningStatus status = QualityWarningStatus.open,
}) => QualityWarning(
  warningId: id,
  sourceType: QualityWarningSourceType.issue,
  sourceId: id,
  sourceVersion: 1,
  sourceChargeNo: 41001,
  sourceSummary: 'Temperature deviation',
  sourceSeverity: 'high',
  warningReason: 'Review coil disposition.',
  affectedAssets: [
    QualityAffectedAsset(assetType: type.name, assetNumber: number),
  ],
  status: status,
  createdAt: createdAt,
  createdByUid: 'ops',
  updatedAt: createdAt,
  updatedByUid: 'ops',
  version: 1,
  closureRequestReason:
      status == QualityWarningStatus.closureRequested
          ? 'Coils inspected and found acceptable.'
          : null,
  closureRequestedAt:
      status == QualityWarningStatus.closureRequested ? createdAt : null,
  closureRequestedByUid:
      status == QualityWarningStatus.closureRequested ? 'ops' : null,
  closureRequestedByName:
      status == QualityWarningStatus.closureRequested ? 'Operations' : null,
);

ChargeAbnormality chargeAbnormality({
  required String id,
  required AssetType type,
  required int number,
  required DateTime loggedAt,
}) =>
    ChargeAbnormality()
      ..firestoreId = id
      ..sourceChargeNo = 41001
      ..abnormalityTypeId = 'temperature-deviation'
      ..abnormalityTypeTitle = 'Temperature deviation'
      ..abnormalityTypeCode = 'TEMP_DEV'
      ..category = AbnormalityCategory.process
      ..severity = AbnormalitySeverity.high
      ..affectedAssets = [
        AffectedAssetRef(assetType: type, assetNumber: number),
      ]
      ..observedReason = 'Cycle temperature deviated from target.'
      ..reannealingStatus = ReannealingStatus.required
      ..loggedAt = loggedAt
      ..updatedAt = loggedAt;

OperationalDirective directive({
  required String id,
  required AppRole role,
  required AssetType type,
  required int number,
  required DateTime createdAt,
}) =>
    OperationalDirective()
      ..firestoreId = id
      ..title = 'Verify burner permissive'
      ..description = 'Confirm permissive before the next cycle.'
      ..assetType = type
      ..assetNumber = number
      ..directedTo = role
      ..priority = DirectivePriority.high
      ..status = DirectiveStatus.open
      ..createdAt = createdAt
      ..updatedAt = createdAt;

JobLaneRecord workflowLane({
  required String id,
  required String laneKey,
  required String assetTypeKey,
  required int assetNumber,
  required DateTime createdAt,
}) =>
    JobLaneRecord()
      ..firestoreId = id
      ..workflowFirestoreId = 'workflow-$id'
      ..jobExecutionFirestoreId = 'execution-$id'
      ..laneKey = laneKey
      ..statusKey = 'pending'
      ..assetTypeKey = assetTypeKey
      ..assetNumber = assetNumber
      ..createdAt = createdAt
      ..updatedAt = createdAt;

ComplianceRequestRecord complianceRequest({
  required String id,
  required String laneKey,
  required String assetTypeKey,
  required int assetNumber,
  required DateTime createdAt,
}) =>
    ComplianceRequestRecord()
      ..firestoreId = id
      ..title = 'Operations support'
      ..description = 'Move the equipment to the maintenance position.'
      ..targetLaneKey = laneKey
      ..statusKey = 'raised'
      ..becameDueAt = createdAt
      ..assetTypeKey = assetTypeKey
      ..assetNumber = assetNumber
      ..createdAt = createdAt
      ..updatedAt = createdAt;

void main() {
  testWidgets('ranked report labels remain fully visible on narrow screens', (
    tester,
  ) async {
    const label =
        'Recorded path - Furnace - Combustion system > Zone 1 > Drive train';
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ReportRankedList(
              title: 'Top recorded subsystem paths',
              rows: [CountedReportLabel(label: label, count: 4)],
            ),
          ),
        ),
      ),
    );

    final labelText = tester.widget<Text>(find.text(label));
    expect(labelText.maxLines, isNull);
    expect(labelText.overflow, isNull);
    expect(find.byTooltip(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('report selection clears retired hierarchy records', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);

    final retiredClassSelection = reconcileOperationsReportSelection(
      assetClassId: furnace.id,
      assetInstanceId: furnace7.id,
      classes: [
        assetClass(
          furnace.id,
          furnace.name,
          furnace.legacyAssetTypeKey!,
          status: AssetHierarchyStatus.retired,
        ),
      ],
      assets: [furnace7],
    );
    expect(retiredClassSelection.assetClassId, isNull);
    expect(retiredClassSelection.assetInstanceId, isNull);

    final retiredAssetSelection = reconcileOperationsReportSelection(
      assetClassId: furnace.id,
      assetInstanceId: furnace7.id,
      classes: [furnace],
      assets: [
        asset(
          furnace7.id,
          furnace,
          furnace7.assetNumber,
          status: AssetHierarchyStatus.retired,
        ),
      ],
    );
    expect(retiredAssetSelection.assetClassId, furnace.id);
    expect(retiredAssetSelection.assetInstanceId, isNull);
  });

  test('builds dynamic class report with overlap and failure rankings', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final base = assetClass('base-class', 'Base', 'base');
    final furnace7 = asset('furnace-7', furnace, 7);
    final base1 = asset('base-1', base, 1);
    final assets = [furnace7, base1];
    final overview = PlantAssetOverview.build(
      assetClasses: [furnace, base],
      assetInstances: assets,
      operationalConditions: const [],
      workflowStatuses: const [],
    );
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
        assetClassId: furnace.id,
      ),
      tickets: [
        issue(
          type: AssetType.furnace,
          number: 7,
          started: DateTime.utc(2026, 7, 28),
        ),
        issue(
          type: AssetType.furnace,
          number: 7,
          started: DateTime.utc(2026, 8, 5),
        ),
        issue(
          type: AssetType.base,
          number: 1,
          started: DateTime.utc(2026, 8, 5),
        ),
      ],
      executions: [execution(DateTime.utc(2026, 8, 6))],
      events: [event()],
      assetClasses: [furnace, base],
      assetInstances: assets,
      overview: overview,
    );

    expect(report.issueCount, 2);
    expect(report.openIssueCount, 2);
    expect(report.plannedJobCount, 1);
    expect(report.openPlannedJobCount, 1);
    expect(report.disruptionCount, 1);
    expect(report.linkedDisruptionIssueCount, 2);
    expect(report.disruptionDuration.inHours, 2);
    expect(report.assetCount, 1);
    expect(report.availableAssetCount, 1);
    expect(report.topComponents.single.label, 'Unmapped legacy component');
    expect(report.topComponents.single.count, 2);
    expect(
      report.topSubsystemPaths.single.label,
      'Unmapped legacy subsystem path',
    );
    expect(report.classSummaries.single.assetClassName, 'Furnace');
    expect(report.classSummaries.single.disruptionCount, 1);
    expect(report.assetAvailabilityRate, 1);
    expect(report.issueClosureRate, 0);
    expect(report.plannedCompletionRate, 0);
    expect(report.unavailableAssetCount, 0);
    expect(report.actionBacklogCount, 3);
    expect(report.assuranceBacklogCount, 0);
    expect(report.leadingManagementSignal, '2 issues remain open');
    expect(report.managementSignals.map((signal) => signal.type), [
      OperationsManagementSignalType.openIssues,
      OperationsManagementSignalType.openPlannedWork,
    ]);
  });

  test('management signals rank operational severity before raw count', () {
    final now = DateTime.utc(2026, 8, 22);
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final standby = asset(
      'furnace-standby',
      furnace,
      3,
      serviceState: AssetServiceState.standby,
    );
    final critical = issue(type: AssetType.furnace, number: 1, started: now)
      ..isCritical = true;
    final ordinary = issue(type: AssetType.furnace, number: 2, started: now);
    final report = OperationsReport(
      filter: OperationsReportFilter(startDate: now, endDate: now),
      asOf: now,
      tickets: [critical, ordinary],
      executions: const [],
      events: const [],
      eventOccurrences: const [],
      dueStates: const [],
      inspectionFindings: const [],
      assetStates: [
        PlantAssetState(
          asset: standby,
          operationalCondition: null,
          availability: null,
          workflowStatus: null,
        ),
      ],
      classSummaries: const [],
      topComponents: const [],
      topSubsystemPaths: const [],
      sourceTicketCount: 2,
      sourceExecutionCount: 0,
      sourceEventCount: 1,
      sourceDueStateCount: 0,
      sourceInspectionFindingCount: 0,
      disruptionCount: 1,
      openDisruptionCount: 1,
      disruptionDuration: Duration.zero,
    );

    expect(report.openCriticalIssueCount, 1);
    expect(report.managementSignals.map((signal) => signal.type), [
      OperationsManagementSignalType.criticalIssues,
      OperationsManagementSignalType.operationalDisruptions,
      OperationsManagementSignalType.unavailableAssets,
      OperationsManagementSignalType.openIssues,
    ]);
    expect(report.highRiskUnavailableAssetCount, 0);
    expect(report.leadingManagementSignal, '1 critical issue remains open');
  });

  test('governed identity drives rankings instead of editable ticket text', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    final furnace8 = asset('furnace-8', furnace, 8);
    final canonicalReference = AssetHierarchyReference(
      assetClassId: furnace.id,
      assetClassCode: furnace.code,
      assetClassName: furnace.name,
      nodeId: 'pressure-transmitter',
      nodeVersion: 3,
      nodeName: 'Pressure transmitter',
      hierarchyPath: const ['Combustion system', 'Pressure transmitter'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'instrumentation',
      accountableRoleKeys: const ['senior_instrumentation'],
    );
    final first = issue(
      type: AssetType.furnace,
      number: 7,
      started: DateTime.utc(2026, 8, 5),
      component: 'PT setting',
      subsystem: 'Burner controls',
    )..assetHierarchyRefJson = canonicalReference.encode();
    final second = issue(
      type: AssetType.furnace,
      number: 8,
      started: DateTime.utc(2026, 8, 6),
      component: 'pressure xmitter',
      subsystem: 'Combustion',
    )..assetHierarchyRefJson = canonicalReference.encode();
    final legacy = issue(
      type: AssetType.furnace,
      number: 7,
      started: DateTime.utc(2026, 8, 7),
      component: 'PT',
      subsystem: 'Burner',
    );
    final assets = [furnace7, furnace8];

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
      ),
      tickets: [first, second, legacy],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: assets,
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: assets,
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(
      report.topComponents
          .map((row) => (row.label, row.count))
          .toList(growable: false),
      [
        ('Furnace - Combustion system / Pressure transmitter', 2),
        ('Unmapped legacy component', 1),
      ],
    );
    expect(
      report.topSubsystemPaths
          .map((row) => (row.label, row.count))
          .toList(growable: false),
      [
        ('Recorded path - Furnace - Combustion system', 2),
        ('Unmapped legacy subsystem path', 1),
      ],
    );
  });

  test('subsystem concentration is explicit path grouping, not identity', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    final firstReference = AssetHierarchyReference(
      assetClassId: furnace.id,
      assetClassCode: furnace.code,
      assetClassName: furnace.name,
      nodeId: 'pressure-transmitter-a',
      nodeVersion: 1,
      nodeName: 'Pressure transmitter A',
      hierarchyPath: const ['Combustion system', 'Pressure transmitter'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'instrumentation',
      accountableRoleKeys: const ['senior_instrumentation'],
    );
    final secondReference = AssetHierarchyReference(
      assetClassId: furnace.id,
      assetClassCode: furnace.code,
      assetClassName: furnace.name,
      nodeId: 'pressure-transmitter-b',
      nodeVersion: 1,
      nodeName: 'Pressure transmitter B',
      hierarchyPath: const ['Combustion system', 'Pressure transmitter'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'instrumentation',
      accountableRoleKeys: const ['senior_instrumentation'],
    );
    final first = issue(
      type: AssetType.furnace,
      number: 7,
      started: DateTime.utc(2026, 8, 5),
    )..assetHierarchyRefJson = firstReference.encode();
    final second = issue(
      type: AssetType.furnace,
      number: 7,
      started: DateTime.utc(2026, 8, 6),
    )..assetHierarchyRefJson = secondReference.encode();

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
      ),
      tickets: [first, second],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: [furnace7],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace7],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(report.topComponents.map((row) => row.label).toSet(), {
      'Furnace - Combustion system / Pressure transmitter · '
          'ref furnace-class/pressure-transmitter-a',
      'Furnace - Combustion system / Pressure transmitter · '
          'ref furnace-class/pressure-transmitter-b',
    });
    expect(
      report.topSubsystemPaths
          .map((row) => (row.label, row.count))
          .toList(growable: false),
      [('Recorded path - Furnace - Combustion system', 2)],
    );
  });

  test('definition ranking never borrows an installed component tag', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    final furnace8 = asset('furnace-8', furnace, 8);
    AssetHierarchyReference installedReference({
      required String assetId,
      required int assetNumber,
      required String componentId,
      required String tag,
    }) => AssetHierarchyReference(
      scope: AssetHierarchyReferenceScope.installedComponent,
      assetClassId: furnace.id,
      assetClassCode: furnace.code,
      assetClassName: furnace.name,
      nodeId: 'pressure-transmitter',
      nodeVersion: 1,
      nodeName: 'Pressure transmitter',
      assetInstanceId: assetId,
      assetInstanceVersion: 1,
      assetNumber: assetNumber,
      assetInstanceName: 'Furnace $assetNumber',
      componentInstanceId: componentId,
      componentInstanceVersion: 1,
      componentTag: tag,
      hierarchyPath: const ['Combustion system', 'Pressure transmitter'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'instrumentation',
      accountableRoleKeys: const ['senior_instrumentation'],
    );
    final first = issue(
        type: AssetType.furnace,
        number: 7,
        started: DateTime.utc(2026, 8, 5),
      )
      ..assetHierarchyRefJson =
          installedReference(
            assetId: furnace7.id,
            assetNumber: 7,
            componentId: 'furnace-7-pt',
            tag: 'PT-701',
          ).encode();
    final second = issue(
        type: AssetType.furnace,
        number: 8,
        started: DateTime.utc(2026, 8, 6),
      )
      ..assetHierarchyRefJson =
          installedReference(
            assetId: furnace8.id,
            assetNumber: 8,
            componentId: 'furnace-8-pt',
            tag: 'PT-801',
          ).encode();

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
      ),
      tickets: [first, second],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: [furnace7, furnace8],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace7, furnace8],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(
      report.topComponents
          .map((row) => (row.label, row.count))
          .toList(growable: false),
      [('Furnace - Combustion system / Pressure transmitter', 2)],
    );
  });

  test('recorded subsystem rows retain the complete parent path', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    MaintenanceRecord ticket(String nodeId, List<String> path, int day) =>
        issue(
            type: AssetType.furnace,
            number: 7,
            started: DateTime.utc(2026, 8, day),
          )
          ..assetHierarchyRefJson =
              AssetHierarchyReference(
                assetClassId: furnace.id,
                assetClassCode: furnace.code,
                assetClassName: furnace.name,
                nodeId: nodeId,
                nodeVersion: 1,
                nodeName: 'Motor',
                hierarchyPath: path,
                ownershipStatus: AssetOwnershipStatus.confirmed,
                ownerDiscipline: 'electrical',
                accountableRoleKeys: const ['senior_electrical'],
              ).encode();

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
      ),
      tickets: [
        ticket('line-a-motor', const ['Line A', 'Drive', 'Motor'], 5),
        ticket('line-b-motor', const ['Line B', 'Drive', 'Motor'], 6),
      ],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: [furnace7],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace7],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(report.topSubsystemPaths.map((row) => row.label).toSet(), {
      'Recorded path - Furnace - Line A > Drive',
      'Recorded path - Furnace - Line B > Drive',
    });
  });

  test('recorded path keys cannot collide with delimiters inside names', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    MaintenanceRecord ticket(String nodeId, List<String> path, int day) =>
        issue(
            type: AssetType.furnace,
            number: 7,
            started: DateTime.utc(2026, 8, day),
          )
          ..assetHierarchyRefJson =
              AssetHierarchyReference(
                assetClassId: furnace.id,
                assetClassCode: furnace.code,
                assetClassName: furnace.name,
                nodeId: nodeId,
                nodeVersion: 1,
                nodeName: 'Motor',
                hierarchyPath: path,
                ownershipStatus: AssetOwnershipStatus.confirmed,
                ownerDiscipline: 'electrical',
                accountableRoleKeys: const ['senior_electrical'],
              ).encode();

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
      ),
      tickets: [
        ticket('single-segment', const ['Line A / Drive', 'Motor'], 5),
        ticket('two-segments', const ['Line A', 'Drive', 'Motor'], 6),
      ],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: [furnace7],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: [furnace7],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(report.topSubsystemPaths.map((row) => row.label).toSet(), {
      'Recorded path - Furnace - Line A / Drive',
      'Recorded path - Furnace - Line A > Drive',
    });
  });

  test('physical-asset filter excludes another asset in the same class', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    final furnace8 = asset('furnace-8', furnace, 8);
    final assets = [furnace7, furnace8];
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 31),
        assetInstanceId: furnace7.id,
      ),
      tickets: [
        issue(
          type: AssetType.furnace,
          number: 7,
          started: DateTime.utc(2026, 8, 5),
        ),
        issue(
          type: AssetType.furnace,
          number: 8,
          started: DateTime.utc(2026, 8, 5),
        ),
      ],
      executions: const [],
      events: const [],
      assetClasses: [furnace],
      assetInstances: assets,
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: assets,
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );
    expect(report.issueCount, 1);
    expect(report.assetStates.single.asset.id, furnace7.id);
    expect(report.classSummaries.single.assetClassId, furnace.id);
  });

  test(
    'governed custom planned work uses its published hierarchy identity',
    () {
      final annealingCar = assetClass(
        'annealing-car-class',
        'Annealing car',
        null,
      );
      final car3 = asset('annealing-car-3', annealingCar, 3);
      final customExecution =
          execution(DateTime.utc(2026, 8, 6))
            ..assetType = AssetType.governedCustom
            ..assetNumber = 3
            ..templateVersionId = 'version-custom-1'
            ..metadataJson = jsonEncode(<String, dynamic>{
              'source': 'server_governed_published_template_assignment',
              'jobTemplateSnapshot': <String, dynamic>{
                'assetHierarchyRefJson':
                    AssetHierarchyReference(
                      assetClassId: annealingCar.id,
                      assetClassCode: annealingCar.code,
                      assetClassName: annealingCar.name,
                      nodeId: 'car-body',
                      nodeVersion: 1,
                      nodeName: 'Car body',
                      hierarchyPath: const ['Car body'],
                      ownershipStatus: AssetOwnershipStatus.unassigned,
                    ).encode(),
              },
            });
      final report = buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 31),
          assetInstanceId: car3.id,
        ),
        tickets: const [],
        executions: [customExecution],
        events: const [],
        assetClasses: [annealingCar],
        assetInstances: [car3],
        overview: PlantAssetOverview.build(
          assetClasses: [annealingCar],
          assetInstances: [car3],
          operationalConditions: const [],
          workflowStatuses: const [],
        ),
      );

      expect(report.plannedJobCount, 1);
      expect(report.openPlannedJobCount, 1);
      expect(report.classSummaries.single.plannedJobCount, 1);
    },
  );

  test(
    'Inner Cover planned work is attributed to its selected Base position',
    () {
      final baseClass = assetClass('base-class', 'Base', 'base');
      final innerCoverClass = assetClass(
        'inner-cover-class',
        'Inner Cover',
        'innerCover',
      );
      final base201 = asset('base-201', baseClass, 201);
      final innerCoverExecution =
          execution(DateTime.utc(2026, 8, 6))
            ..assetType = AssetType.innerCover
            ..assetNumber = 201
            ..templateVersionId = 'version-inner-cover-1'
            ..metadataJson = jsonEncode(<String, dynamic>{
              'source': 'server_governed_published_template_assignment',
              'assignmentAssetIdentity': <String, dynamic>{
                'assetClassId': baseClass.id,
                'assetInstanceId': base201.id,
                'assetNumber': base201.assetNumber,
              },
              'jobTemplateSnapshot': <String, dynamic>{
                'assetHierarchyRefJson':
                    AssetHierarchyReference(
                      assetClassId: innerCoverClass.id,
                      assetClassCode: innerCoverClass.code,
                      assetClassName: innerCoverClass.name,
                      nodeId: 'shell',
                      nodeVersion: 1,
                      nodeName: 'Shell',
                      hierarchyPath: const ['Shell'],
                      ownershipStatus: AssetOwnershipStatus.unassigned,
                    ).encode(),
              },
            });

      final report = buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 31),
          assetInstanceId: base201.id,
        ),
        tickets: const [],
        executions: [innerCoverExecution],
        events: const [],
        assetClasses: [baseClass, innerCoverClass],
        assetInstances: [base201],
        overview: PlantAssetOverview.build(
          assetClasses: [baseClass, innerCoverClass],
          assetInstances: [base201],
          operationalConditions: const [],
          workflowStatuses: const [],
        ),
      );

      expect(report.plannedJobCount, 1);
      expect(report.classSummaries.single.assetClassId, baseClass.id);
      expect(report.classSummaries.single.plannedJobCount, 1);
    },
  );

  test(
    'governed custom planned work without hierarchy identity fails closed',
    () {
      final customExecution =
          execution(DateTime.utc(2026, 8, 6))
            ..assetType = AssetType.governedCustom
            ..assetNumber = 3
            ..templateVersionId = 'version-custom-1'
            ..metadataJson = jsonEncode(<String, dynamic>{
              'source': 'server_governed_published_template_assignment',
              'jobTemplateSnapshot': <String, dynamic>{
                'jobName': 'Custom asset PM',
              },
            });

      expect(
        () => buildOperationsReport(
          filter: OperationsReportFilter(
            startDate: DateTime.utc(2026, 8, 1),
            endDate: DateTime.utc(2026, 8, 31),
          ),
          tickets: const [],
          executions: [customExecution],
          events: const [],
          assetClasses: const [],
          assetInstances: const [],
          overview: const PlantAssetOverview(classes: [], assets: []),
        ),
        throwsStateError,
      );
    },
  );

  test('governed custom planned work rejects ambiguous physical identity', () {
    final annealingCar = assetClass(
      'annealing-car-class',
      'Annealing car',
      null,
    );
    final customExecution =
        execution(DateTime.utc(2026, 8, 6))
          ..assetType = AssetType.governedCustom
          ..assetNumber = 3
          ..templateVersionId = 'version-custom-1'
          ..metadataJson = jsonEncode(<String, dynamic>{
            'source': 'server_governed_published_template_assignment',
            'jobTemplateSnapshot': <String, dynamic>{
              'assetHierarchyRefJson':
                  AssetHierarchyReference(
                    assetClassId: annealingCar.id,
                    assetClassCode: annealingCar.code,
                    assetClassName: annealingCar.name,
                    nodeId: 'car-body',
                    nodeVersion: 1,
                    nodeName: 'Car body',
                    hierarchyPath: const ['Car body'],
                    ownershipStatus: AssetOwnershipStatus.unassigned,
                  ).encode(),
            },
          });

    expect(
      () => buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 8, 1),
          endDate: DateTime.utc(2026, 8, 31),
        ),
        tickets: const [],
        executions: [customExecution],
        events: const [],
        assetClasses: [annealingCar],
        assetInstances: [
          asset('annealing-car-3-a', annealingCar, 3),
          asset('annealing-car-3-b', annealingCar, 3),
        ],
        overview: const PlantAssetOverview(classes: [], assets: []),
      ),
      throwsStateError,
    );
  });

  test(
    'report clock emits immediately and refreshes on its interval',
    () async {
      var minute = 0;
      final values =
          await operationsReportClock(
            interval: const Duration(milliseconds: 1),
            now: () => DateTime.utc(2026, 8, 14, 12, minute++),
          ).take(2).toList();
      expect(values, [
        DateTime.utc(2026, 8, 14, 12),
        DateTime.utc(2026, 8, 14, 12, 1),
      ]);
    },
  );

  test('disruption duration counts only overlap with the report period', () {
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 10),
        endDate: DateTime.utc(2026, 8, 10),
      ),
      tickets: const [],
      executions: const [],
      events: [
        OperationalEvent(
          eventId: 'event-overlap',
          eventType: OperationalEventType.water,
          title: 'Water interruption',
          description: 'Cooling water was unavailable across the plant.',
          severity: OperationalEventSeverity.critical,
          scope: OperationalEventScope.plantWide,
          affectedAssetClassIds: const [],
          affectedAssetInstanceIds: const [],
          startedAt: DateTime.utc(2026, 8, 9, 18),
          status: OperationalEventStatus.resolved,
          createdAt: DateTime.utc(2026, 8, 9, 18),
          createdByUid: 'ops',
          createdByName: 'Operations',
          resolvedAt: DateTime.utc(2026, 8, 11, 6),
          resolvedByUid: 'shift',
          resolvedByName: 'Shift Supervisor',
          resolutionNote: 'Cooling water remained stable after restoration.',
          version: 2,
          updatedAt: DateTime.utc(2026, 8, 11, 6),
          updatedByUid: 'shift',
          updatedByName: 'Shift Supervisor',
          lastMutationId: 'mutation',
        ),
      ],
      assetClasses: const [],
      assetInstances: const [],
      overview: const PlantAssetOverview(classes: [], assets: []),
    );
    expect(report.disruptionDuration, const Duration(days: 1));
  });

  test('open disruption duration stops at the report as-of instant', () {
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 14),
        endDate: DateTime.utc(2026, 8, 14),
      ),
      tickets: const [],
      executions: const [],
      events: [
        OperationalEvent(
          eventId: 'event-open',
          eventType: OperationalEventType.crane,
          title: 'Crane unavailable',
          description: 'Furnace movement is waiting for the charging crane.',
          severity: OperationalEventSeverity.significant,
          scope: OperationalEventScope.plantWide,
          affectedAssetClassIds: const [],
          affectedAssetInstanceIds: const [],
          startedAt: DateTime.utc(2026, 8, 14, 10),
          status: OperationalEventStatus.open,
          createdAt: DateTime.utc(2026, 8, 14, 10),
          createdByUid: 'ops',
          createdByName: 'Operations',
          resolvedAt: null,
          resolvedByUid: null,
          resolvedByName: null,
          resolutionNote: null,
          version: 1,
          updatedAt: DateTime.utc(2026, 8, 14, 10),
          updatedByUid: 'ops',
          updatedByName: 'Operations',
          lastMutationId: 'mutation',
        ),
      ],
      assetClasses: const [],
      assetInstances: const [],
      overview: const PlantAssetOverview(classes: [], assets: []),
      asOf: DateTime.utc(2026, 8, 14, 12),
    );
    expect(report.disruptionDuration, const Duration(hours: 2));
  });

  test('reopened disruptions retain separate report occurrences', () {
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 14),
        endDate: DateTime.utc(2026, 8, 14),
      ),
      tickets: const [],
      executions: const [],
      events: [
        OperationalEvent(
          eventId: 'event-recurring',
          eventType: OperationalEventType.water,
          title: 'Cooling-water interruption',
          description: 'Cooling water was interrupted twice during the shift.',
          severity: OperationalEventSeverity.significant,
          scope: OperationalEventScope.plantWide,
          affectedAssetClassIds: const [],
          affectedAssetInstanceIds: const [],
          issueLinkIds: const ['event-issue-current'],
          linkedIssueIds: const ['maintenance-issue-shared'],
          completedIntervals: [
            OperationalEventInterval(
              eventType: OperationalEventType.powerTrip,
              title: 'Earlier power interruption',
              description: 'The first occurrence was an incoming power trip.',
              severity: OperationalEventSeverity.critical,
              startedAt: DateTime.utc(2026, 8, 14, 10),
              resolvedAt: DateTime.utc(2026, 8, 14, 12),
              scope: OperationalEventScope.plantWide,
              affectedAssetClassIds: const [],
              affectedAssetInstanceIds: const [],
              issueLinkIds: const ['event-issue-prior'],
              linkedIssueIds: const ['maintenance-issue-shared'],
              resolvedByUid: 'shift-first',
              resolvedByName: 'Shift Supervisor One',
              resolutionNote:
                  'Cooling water remained stable after the first restoration.',
            ),
          ],
          startedAt: DateTime.utc(2026, 8, 14, 13),
          status: OperationalEventStatus.resolved,
          createdAt: DateTime.utc(2026, 8, 14, 10),
          createdByUid: 'ops',
          createdByName: 'Operations',
          resolvedAt: DateTime.utc(2026, 8, 14, 14),
          resolvedByUid: 'shift',
          resolvedByName: 'Shift Supervisor',
          resolutionNote: 'Cooling water remained stable after restoration.',
          version: 4,
          updatedAt: DateTime.utc(2026, 8, 14, 14),
          updatedByUid: 'shift',
          updatedByName: 'Shift Supervisor',
          lastMutationId: 'mutation',
        ),
      ],
      assetClasses: const [],
      assetInstances: const [],
      overview: const PlantAssetOverview(classes: [], assets: []),
      asOf: DateTime.utc(2026, 8, 14, 15),
    );

    expect(report.disruptionCount, 2);
    expect(report.linkedDisruptionIssueCount, 1);
    expect(report.disruptionDuration, const Duration(hours: 3));
    expect(report.eventOccurrences.length, 2);
    expect(report.eventOccurrences.map((item) => item.interval.startedAt), [
      DateTime.utc(2026, 8, 14, 13),
      DateTime.utc(2026, 8, 14, 10),
    ]);
    expect(
      report.eventOccurrences.last.interval.title,
      'Earlier power interruption',
    );
    expect(
      report.eventOccurrences.last.interval.eventType,
      OperationalEventType.powerTrip,
    );
  });

  test('reopened disruption keeps each occurrence on its recorded asset', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final furnace7 = asset('furnace-7', furnace, 7);
    final furnace8 = asset('furnace-8', furnace, 8);
    final assets = [furnace7, furnace8];
    final recurring = OperationalEvent(
      eventId: 'event-retargeted',
      eventType: OperationalEventType.crane,
      title: 'Crane support interruption',
      description: 'Separate crane interruptions affected two furnaces.',
      severity: OperationalEventSeverity.significant,
      scope: OperationalEventScope.assets,
      affectedAssetClassIds: [furnace.id],
      affectedAssetInstanceIds: [furnace8.id],
      completedIntervals: [
        OperationalEventInterval(
          eventType: OperationalEventType.crane,
          title: 'First crane support interruption',
          description: 'The first crane interruption affected Furnace 7.',
          severity: OperationalEventSeverity.critical,
          startedAt: DateTime.utc(2026, 8, 14, 10),
          resolvedAt: DateTime.utc(2026, 8, 14, 12),
          scope: OperationalEventScope.assets,
          affectedAssetClassIds: [furnace.id],
          affectedAssetInstanceIds: [furnace7.id],
          resolvedByUid: 'shift-first',
          resolvedByName: 'Shift Supervisor One',
          resolutionNote:
              'Crane support remained stable after the first restoration.',
        ),
      ],
      startedAt: DateTime.utc(2026, 8, 14, 13),
      status: OperationalEventStatus.resolved,
      createdAt: DateTime.utc(2026, 8, 14, 10),
      createdByUid: 'ops',
      createdByName: 'Operations',
      resolvedAt: DateTime.utc(2026, 8, 14, 14),
      resolvedByUid: 'shift',
      resolvedByName: 'Shift Supervisor',
      resolutionNote: 'Crane support remained stable after restoration.',
      version: 5,
      updatedAt: DateTime.utc(2026, 8, 14, 14),
      updatedByUid: 'shift',
      updatedByName: 'Shift Supervisor',
      lastMutationId: 'mutation',
    );

    OperationsReport reportFor(String assetId) => buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 14),
        endDate: DateTime.utc(2026, 8, 14),
        assetInstanceId: assetId,
      ),
      tickets: const [],
      executions: const [],
      events: [recurring],
      assetClasses: [furnace],
      assetInstances: assets,
      overview: PlantAssetOverview.build(
        assetClasses: [furnace],
        assetInstances: assets,
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
      asOf: DateTime.utc(2026, 8, 14, 15),
    );

    final furnace7Report = reportFor(furnace7.id);
    final furnace8Report = reportFor(furnace8.id);
    expect(furnace7Report.disruptionCount, 1);
    expect(furnace7Report.disruptionDuration, const Duration(hours: 2));
    expect(furnace7Report.classSummaries.single.disruptionCount, 1);
    expect(
      furnace7Report.eventOccurrences.single.interval.startedAt,
      DateTime.utc(2026, 8, 14, 10),
    );
    expect(furnace8Report.disruptionCount, 1);
    expect(furnace8Report.disruptionDuration, const Duration(hours: 1));
    expect(furnace8Report.classSummaries.single.disruptionCount, 1);
    expect(
      furnace8Report.eventOccurrences.single.interval.startedAt,
      DateTime.utc(2026, 8, 14, 13),
    );
  });

  test('duplicate legacy mappings preserve explicit hierarchy attribution', () {
    final furnaceA = assetClass('furnace-a', 'Furnace A', 'furnace');
    final furnaceB = assetClass('furnace-b', 'Furnace B', 'furnace');
    final explicit = issue(
        type: AssetType.furnace,
        number: 7,
        started: DateTime.utc(2026, 8, 14, 10),
      )
      ..assetHierarchyRefJson =
          AssetHierarchyReference(
            assetClassId: furnaceA.id,
            assetClassCode: furnaceA.code,
            assetClassName: furnaceA.name,
            nodeId: 'burner-system',
            nodeVersion: 1,
            nodeName: 'Burner system',
            hierarchyPath: const ['Burner system'],
            ownershipStatus: AssetOwnershipStatus.unassigned,
          ).encode();
    final ambiguousLegacy = issue(
      type: AssetType.furnace,
      number: 8,
      started: DateTime.utc(2026, 8, 14, 11),
    );
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 14),
        endDate: DateTime.utc(2026, 8, 14),
        assetClassId: furnaceA.id,
      ),
      tickets: [explicit, ambiguousLegacy],
      executions: const [],
      events: const [],
      assetClasses: [furnaceA, furnaceB],
      assetInstances: const [],
      overview: PlantAssetOverview.build(
        assetClasses: [furnaceA, furnaceB],
        assetInstances: const [],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
    );

    expect(report.issueCount, 1);
    expect(report.classSummaries.single.assetClassId, furnaceA.id);
    expect(report.classSummaries.single.issueCount, 1);
  });

  test('records ending at period start do not overlap the report', () {
    final start = DateTime(2026, 8, 14);
    final boundaryIssue = issue(
      type: AssetType.furnace,
      number: 7,
      started: start.subtract(const Duration(hours: 4)),
      resolved: true,
    )..endDate = start;
    final boundaryJob =
        execution(start.subtract(const Duration(hours: 4)))
          ..isCompleted = true
          ..completedAt = start;
    final report = buildOperationsReport(
      filter: OperationsReportFilter(startDate: start, endDate: start),
      tickets: [boundaryIssue],
      executions: [boundaryJob],
      events: [
        OperationalEvent(
          eventId: 'event-boundary',
          eventType: OperationalEventType.powerTrip,
          title: 'Earlier power trip',
          description: 'Power was restored at the report boundary.',
          severity: OperationalEventSeverity.significant,
          scope: OperationalEventScope.plantWide,
          affectedAssetClassIds: const [],
          affectedAssetInstanceIds: const [],
          startedAt: start.subtract(const Duration(hours: 4)),
          status: OperationalEventStatus.resolved,
          createdAt: start.subtract(const Duration(hours: 4)),
          createdByUid: 'ops',
          createdByName: 'Operations',
          resolvedAt: start,
          resolvedByUid: 'shift',
          resolvedByName: 'Shift Supervisor',
          resolutionNote:
              'Supply was stable at the start of the report period.',
          version: 2,
          updatedAt: start,
          updatedByUid: 'shift',
          updatedByName: 'Shift Supervisor',
          lastMutationId: 'mutation',
        ),
      ],
      assetClasses: const [],
      assetInstances: const [],
      overview: const PlantAssetOverview(classes: [], assets: []),
      asOf: start.add(const Duration(hours: 12)),
    );
    expect(report.issueCount, 0);
    expect(report.plannedJobCount, 0);
    expect(report.disruptionCount, 0);
  });

  test('cross-domain control records obey period and asset scope', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final base = assetClass('base-class', 'Base', 'base');
    final furnace7 = asset('furnace-7', furnace, 7);
    final base101 = asset('base-101', base, 101);
    final now = DateTime.utc(2026, 8, 22, 12);
    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 22),
        assetInstanceId: furnace7.id,
      ),
      tickets: const [],
      executions: const [],
      events: const [],
      qualityWarnings: [
        qualityWarning(
          id: 'furnace-warning',
          type: AssetType.furnace,
          number: 7,
          createdAt: DateTime.utc(2026, 7, 1),
          status: QualityWarningStatus.closureRequested,
        ),
        qualityWarning(
          id: 'base-warning',
          type: AssetType.base,
          number: 101,
          createdAt: DateTime.utc(2026, 8, 10),
        ),
      ],
      abnormalities: [
        chargeAbnormality(
          id: 'furnace-abnormality',
          type: AssetType.furnace,
          number: 7,
          loggedAt: DateTime.utc(2026, 8, 10),
        ),
        chargeAbnormality(
          id: 'outside-period',
          type: AssetType.furnace,
          number: 7,
          loggedAt: DateTime.utc(2026, 7, 10),
        ),
      ],
      directives: [
        directive(
          id: 'furnace-directive',
          role: AppRole.seniorInstrumentation,
          type: AssetType.furnace,
          number: 7,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
        directive(
          id: 'base-directive',
          role: AppRole.seniorInstrumentation,
          type: AssetType.base,
          number: 101,
          createdAt: DateTime.utc(2026, 8, 1),
        ),
      ],
      workflowLanes: [
        workflowLane(
          id: 'furnace-lane',
          laneKey: 'inst',
          assetTypeKey: 'furnace',
          assetNumber: 7,
          createdAt: now,
        ),
      ],
      complianceRequests: [
        complianceRequest(
          id: 'furnace-compliance',
          laneKey: 'inst',
          assetTypeKey: 'furnace',
          assetNumber: 7,
          createdAt: now,
        ),
      ],
      actor: AppUser(
        uid: 'admin',
        name: 'Admin',
        email: 'admin@example.com',
        roles: const [AppRole.admin],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      ),
      assetClasses: [furnace, base],
      assetInstances: [furnace7, base101],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace, base],
        assetInstances: [furnace7, base101],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
      asOf: now,
    );

    expect(report.sourceQualityWarningCount, 2);
    expect(report.qualityWarnings, hasLength(1));
    expect(report.qualityClosureRequestCount, 1);
    expect(report.abnormalities, hasLength(1));
    expect(report.highSeverityAbnormalityCount, 1);
    expect(report.pendingReannealingCount, 1);
    expect(report.directives, hasLength(1));
    expect(report.highPriorityDirectiveCount, 1);
    expect(report.pendingLaneAcknowledgementCount, 1);
    expect(report.dueComplianceRequestCount, 1);
    expect(report.workflowObligationCount, 2);
    expect(
      report.managementSignals.map((signal) => signal.type),
      containsAll([
        OperationsManagementSignalType.qualityWarnings,
        OperationsManagementSignalType.activeDirectives,
        OperationsManagementSignalType.workflowObligations,
        OperationsManagementSignalType.criticalAbnormalities,
      ]),
    );
  });

  test('directive and workflow report queues retain actor visibility', () {
    final now = DateTime.utc(2026, 8, 22);
    final actor = AppUser(
      uid: 'instrument-user',
      name: 'Instrumentation',
      email: 'instrument@example.com',
      roles: const [AppRole.seniorInstrumentation],
      isApproved: true,
      createdAt: DateTime.utc(2026),
    );
    final report = buildOperationsReport(
      filter: OperationsReportFilter(startDate: now, endDate: now),
      tickets: const [],
      executions: const [],
      events: const [],
      directives: [
        directive(
          id: 'visible-directive',
          role: AppRole.seniorInstrumentation,
          type: AssetType.furnace,
          number: 7,
          createdAt: now,
        ),
        directive(
          id: 'hidden-directive',
          role: AppRole.seniorElectrical,
          type: AssetType.furnace,
          number: 7,
          createdAt: now,
        ),
      ],
      workflowLanes: [
        workflowLane(
          id: 'visible-lane',
          laneKey: 'inst',
          assetTypeKey: 'furnace',
          assetNumber: 7,
          createdAt: now,
        ),
        workflowLane(
          id: 'hidden-lane',
          laneKey: 'elec',
          assetTypeKey: 'furnace',
          assetNumber: 7,
          createdAt: now,
        ),
      ],
      actor: actor,
      assetClasses: const [],
      assetInstances: const [],
      overview: const PlantAssetOverview(classes: [], assets: []),
      asOf: now,
    );

    expect(report.directives.map((record) => record.firestoreId), [
      'visible-directive',
    ]);
    expect(report.workflowLanes.map((record) => record.firestoreId), [
      'visible-lane',
    ]);
  });

  test('report includes current cadence and active inspection assurance', () {
    final furnace = assetClass('furnace-class', 'Furnace', 'furnace');
    final base = assetClass('base-class', 'Base', 'base');
    final furnace7 = asset('furnace-7', furnace, 7);
    final base101 = asset('base-101', base, 101);
    final asOf = DateTime.utc(2026, 8, 21, 12);
    MaintenanceDueState due({
      required String id,
      required AssetClassRecord assetClass,
      required AssetInstanceRecord asset,
      required DateTime nextDueAt,
    }) => MaintenanceDueState(
      id: id,
      assetIdentityKey: '${assetClass.legacyAssetTypeKey}:${asset.assetNumber}',
      assetTypeKey: assetClass.legacyAssetTypeKey!,
      assetNumber: asset.assetNumber,
      assetClassId: assetClass.id,
      assetInstanceId: asset.id,
      assetDisplayName: asset.name,
      counterKey: 'routine',
      counterLabel: 'Routine maintenance',
      thresholdDays: 30,
      lastCompletionAt: nextDueAt.subtract(const Duration(days: 30)),
      nextDueAt: nextDueAt,
      lastMaintenanceClassCode: 'RM',
    );

    final report = buildOperationsReport(
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 8, 1),
        endDate: DateTime.utc(2026, 8, 21),
        assetClassId: furnace.id,
      ),
      tickets: const [],
      executions: const [],
      events: const [],
      dueStates: [
        due(
          id: 'furnace-overdue',
          assetClass: furnace,
          asset: furnace7,
          nextDueAt: asOf.subtract(const Duration(days: 1)),
        ),
        due(
          id: 'furnace-due-soon',
          assetClass: furnace,
          asset: furnace7,
          nextDueAt: asOf.add(const Duration(days: 6)),
        ),
        due(
          id: 'base-overdue',
          assetClass: base,
          asset: base101,
          nextDueAt: asOf.subtract(const Duration(days: 2)),
        ),
      ],
      inspectionFindings: [
        finding(
          id: 'active-old',
          assetClassId: furnace.id,
          assetInstanceId: furnace7.id,
          status: InspectionFindingStatus.awaitingVerification,
          observedAt: DateTime.utc(2026, 7, 1),
        ),
        finding(
          id: 'resolved-in-period',
          assetClassId: furnace.id,
          assetInstanceId: furnace7.id,
          status: InspectionFindingStatus.verifiedResolved,
          observedAt: DateTime.utc(2026, 8, 15),
        ),
        finding(
          id: 'base-active',
          assetClassId: base.id,
          assetInstanceId: base101.id,
          status: InspectionFindingStatus.open,
          observedAt: DateTime.utc(2026, 8, 16),
        ),
      ],
      assetClasses: [furnace, base],
      assetInstances: [furnace7, base101],
      overview: PlantAssetOverview.build(
        assetClasses: [furnace, base],
        assetInstances: [furnace7, base101],
        operationalConditions: const [],
        workflowStatuses: const [],
      ),
      asOf: asOf,
    );

    expect(report.sourceDueStateCount, 3);
    expect(report.sourceInspectionFindingCount, 3);
    expect(report.dueStates, hasLength(2));
    expect(report.overdueMaintenanceCount, 1);
    expect(report.dueSoonMaintenanceCount, 1);
    expect(report.inspectionFindings, hasLength(2));
    expect(report.activeInspectionFindingCount, 1);
    expect(report.awaitingInspectionVerificationCount, 1);
    expect(report.activeInspectionFindings.single.id, 'active-old');
    expect(report.classSummaries.single.overdueMaintenanceCount, 1);
    expect(report.classSummaries.single.dueSoonMaintenanceCount, 1);
    expect(report.classSummaries.single.activeInspectionFindingCount, 1);
  });
}
