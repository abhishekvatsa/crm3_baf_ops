import 'dart:convert';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
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
}) => AssetInstanceRecord(
  id: id,
  assetClassId: assetClass.id,
  assetClassCode: assetClass.code,
  assetClassName: assetClass.name,
  assetNumber: number,
  name: '${assetClass.name} $number',
  serviceState: AssetServiceState.inService,
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

OperationalEvent event() => OperationalEvent(
  eventId: 'event-1',
  eventType: OperationalEventType.powerTrip,
  title: 'Power trip',
  description: 'Incoming supply was unavailable.',
  severity: OperationalEventSeverity.critical,
  scope: OperationalEventScope.plantWide,
  affectedAssetClassIds: const [],
  affectedAssetInstanceIds: const [],
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
}
