import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AssetClassRecord assetClass(String id, String name, String legacy) =>
    AssetClassRecord(
      id: id,
      code: name.toUpperCase(),
      name: name,
      majorArea: 'BAF shop',
      legacyAssetTypeKey: legacy,
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: DateTime.utc(2026),
      createdByUid: 'admin',
      updatedAt: DateTime.utc(2026),
      updatedByUid: 'admin',
      lastMutationId: 'mutation',
    );

AssetInstanceRecord asset(String id, AssetClassRecord assetClass, int number) =>
    AssetInstanceRecord(
      id: id,
      assetClassId: assetClass.id,
      assetClassCode: assetClass.code,
      assetClassName: assetClass.name,
      assetNumber: number,
      name: '${assetClass.name} $number',
      serviceState: AssetServiceState.inService,
      ownershipStatus: AssetOwnershipStatus.confirmed,
      status: AssetHierarchyStatus.active,
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
    expect(report.topComponents.single.label, 'Pressure transmitter');
    expect(report.topComponents.single.count, 2);
    expect(report.topSubsystems.single.label, 'Combustion control');
    expect(report.classSummaries.single.assetClassName, 'Furnace');
    expect(report.classSummaries.single.disruptionCount, 1);
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
        assetClassId: furnace.id,
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
  });

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
