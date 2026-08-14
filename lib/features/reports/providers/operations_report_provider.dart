import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/domain/plant_asset_overview.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/providers/plant_asset_overview_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../operational_events/data/operational_event.dart';
import '../../operational_events/providers/operational_event_provider.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../models/operations_report.dart';

const operationsReportTicketSourceLimit = 2000;
const operationsReportExecutionSourceLimit = 2000;

final operationsReportTicketsProvider = StreamProvider<List<MaintenanceRecord>>(
  (ref) {
    return ref
        .watch(maintenanceRepositoryProvider)
        .watchAllTickets(limit: operationsReportTicketSourceLimit);
  },
);

final operationsReportExecutionsProvider = StreamProvider<List<JobExecution>>((
  ref,
) {
  return ref
      .watch(plannedRepositoryProvider)
      .watchAllExecutions(limit: operationsReportExecutionSourceLimit);
});

final operationsReportProvider =
    Provider.family<AsyncValue<OperationsReport>, OperationsReportFilter>((
      ref,
      filter,
    ) {
      final tickets = ref.watch(operationsReportTicketsProvider);
      final executions = ref.watch(operationsReportExecutionsProvider);
      final events = ref.watch(operationalEventsProvider);
      final classes = ref.watch(assetClassesProvider);
      final assets = ref.watch(allAssetInstancesProvider);
      final overview = ref.watch(plantAssetOverviewProvider);
      final error =
          tickets.asError ??
          executions.asError ??
          events.asError ??
          classes.asError ??
          assets.asError ??
          overview.asError;
      if (error != null) return AsyncError(error.error, error.stackTrace);
      if (tickets.isLoading ||
          executions.isLoading ||
          events.isLoading ||
          classes.isLoading ||
          assets.isLoading ||
          overview.isLoading) {
        return const AsyncLoading();
      }
      try {
        return AsyncData(
          buildOperationsReport(
            filter: filter,
            tickets: tickets.requireValue,
            executions: executions.requireValue,
            events: events.requireValue,
            assetClasses: classes.requireValue,
            assetInstances: assets.requireValue,
            overview: overview.requireValue,
          ),
        );
      } catch (error, stackTrace) {
        return AsyncError(error, stackTrace);
      }
    });

OperationsReport buildOperationsReport({
  required OperationsReportFilter filter,
  required List<MaintenanceRecord> tickets,
  required List<JobExecution> executions,
  required List<OperationalEvent> events,
  required List<AssetClassRecord> assetClasses,
  required List<AssetInstanceRecord> assetInstances,
  required PlantAssetOverview overview,
  DateTime? asOf,
}) {
  if (filter.endExclusive.isBefore(filter.startInclusive) ||
      filter.endExclusive == filter.startInclusive) {
    throw ArgumentError('The report end date must not precede its start date.');
  }
  final assetsById = {for (final item in assetInstances) item.id: item};
  final legacyClasses = <String, AssetClassRecord>{};
  for (final item in assetClasses) {
    final key = item.legacyAssetTypeKey;
    if (key == null) continue;
    if (legacyClasses.containsKey(key)) {
      throw StateError('More than one governed asset class maps to $key.');
    }
    legacyClasses[key] = item;
  }

  String? ticketClassId(MaintenanceRecord ticket) =>
      ticket.assetHierarchyReference?.assetClassId ??
      legacyClasses[ticket.assetType.name]?.id;

  String? ticketAssetId(MaintenanceRecord ticket) {
    final reference = ticket.assetHierarchyReference;
    if (reference?.assetInstanceId != null) return reference!.assetInstanceId;
    final classId = ticketClassId(ticket);
    if (classId == null) return null;
    return assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId &&
              asset.assetNumber == ticket.assetNumber,
        )
        .map((asset) => asset.id)
        .firstOrNull;
  }

  String? executionClassId(JobExecution execution) =>
      legacyClasses[execution.assetType.name]?.id;

  String? executionAssetId(JobExecution execution) {
    final classId = executionClassId(execution);
    if (classId == null) return null;
    return assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId &&
              asset.assetNumber == execution.assetNumber,
        )
        .map((asset) => asset.id)
        .firstOrNull;
  }

  bool matchesIdentity(String? classId, String? assetId) {
    if (filter.assetClassId != null && classId != filter.assetClassId) {
      return false;
    }
    if (filter.assetInstanceId != null && assetId != filter.assetInstanceId) {
      return false;
    }
    return true;
  }

  bool overlaps(DateTime start, DateTime? end) =>
      start.isBefore(filter.endExclusive) &&
      (end == null || end.isAfter(filter.startInclusive));

  final filteredTickets =
      tickets
          .where(
            (ticket) =>
                overlaps(ticket.startDate, ticket.endDate) &&
                matchesIdentity(ticketClassId(ticket), ticketAssetId(ticket)),
          )
          .toList();
  final filteredExecutions =
      executions
          .where(
            (execution) =>
                overlaps(
                  execution.createdAt,
                  execution.completedAt ?? execution.cancelledAt,
                ) &&
                matchesIdentity(
                  executionClassId(execution),
                  executionAssetId(execution),
                ),
          )
          .toList();

  bool eventMatches(OperationalEvent event) {
    if (!overlaps(event.startedAt, event.resolvedAt)) return false;
    if (event.scope == OperationalEventScope.plantWide) return true;
    if (filter.assetInstanceId != null) {
      if (event.scope == OperationalEventScope.assets) {
        return event.affectedAssetInstanceIds.contains(filter.assetInstanceId);
      }
      final selectedAsset = assetsById[filter.assetInstanceId];
      return selectedAsset != null &&
          event.affectedAssetClassIds.contains(selectedAsset.assetClassId);
    }
    if (filter.assetClassId != null) {
      if (event.affectedAssetClassIds.contains(filter.assetClassId)) {
        return true;
      }
      return event.affectedAssetInstanceIds.any(
        (id) => assetsById[id]?.assetClassId == filter.assetClassId,
      );
    }
    return true;
  }

  final filteredEvents = events.where(eventMatches).toList();
  final filteredStates =
      overview.assets
          .where(
            (state) =>
                matchesIdentity(state.asset.assetClassId, state.asset.id),
          )
          .toList();

  List<CountedReportLabel> rank(String? Function(MaintenanceRecord) value) {
    final labels = <String, String>{};
    final counts = <String, int>{};
    for (final ticket in filteredTickets) {
      final label = value(ticket)?.trim();
      if (label == null || label.isEmpty) continue;
      final key = label.toLowerCase();
      labels.putIfAbsent(key, () => label);
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final result =
        counts.entries
            .map(
              (entry) => CountedReportLabel(
                label: labels[entry.key]!,
                count: entry.value,
              ),
            )
            .toList()
          ..sort((left, right) {
            final count = right.count.compareTo(left.count);
            return count != 0
                ? count
                : left.label.toLowerCase().compareTo(right.label.toLowerCase());
          });
    return List<CountedReportLabel>.unmodifiable(result.take(8));
  }

  bool eventAffectsClass(OperationalEvent event, String classId) =>
      event.scope == OperationalEventScope.plantWide ||
      event.affectedAssetClassIds.contains(classId) ||
      event.affectedAssetInstanceIds.any(
        (id) => assetsById[id]?.assetClassId == classId,
      );

  final selectedClasses =
      assetClasses
          .where(
            (assetClass) =>
                assetClass.isActive &&
                (filter.assetClassId == null ||
                    assetClass.id == filter.assetClassId),
          )
          .toList();
  final classSummaries =
      selectedClasses.map((assetClass) {
          final states =
              filteredStates
                  .where((state) => state.asset.assetClassId == assetClass.id)
                  .toList();
          final classTickets =
              filteredTickets
                  .where((ticket) => ticketClassId(ticket) == assetClass.id)
                  .toList();
          final classExecutions =
              filteredExecutions
                  .where(
                    (execution) => executionClassId(execution) == assetClass.id,
                  )
                  .toList();
          return AssetClassReportSummary(
            assetClassId: assetClass.id,
            assetClassName: assetClass.name,
            assetCount: states.length,
            availableCount: states.where((state) => state.isAvailable).length,
            underMaintenanceCount:
                states.where((state) => state.isUnderMaintenance).length,
            downCount: states.where((state) => state.isDown).length,
            unfitCount: states.where((state) => state.isUnfit).length,
            issueCount: classTickets.length,
            openIssueCount:
                classTickets.where((ticket) => !ticket.isResolved).length,
            plannedJobCount: classExecutions.length,
            openPlannedJobCount:
                classExecutions
                    .where((job) => !job.isCompleted && !job.isCancelled)
                    .length,
            disruptionCount:
                filteredEvents
                    .where((event) => eventAffectsClass(event, assetClass.id))
                    .length,
          );
        }).toList()
        ..sort(
          (left, right) => left.assetClassName.toLowerCase().compareTo(
            right.assetClassName.toLowerCase(),
          ),
        );

  return OperationsReport(
    filter: filter,
    asOf: asOf ?? DateTime.now(),
    tickets: List<MaintenanceRecord>.unmodifiable(filteredTickets),
    executions: List<JobExecution>.unmodifiable(filteredExecutions),
    events: List<OperationalEvent>.unmodifiable(filteredEvents),
    assetStates: List<PlantAssetState>.unmodifiable(filteredStates),
    classSummaries: List<AssetClassReportSummary>.unmodifiable(classSummaries),
    topComponents: rank(
      (ticket) =>
          ticket.component ??
          (ticket.hierarchyPath?.isNotEmpty == true
              ? ticket.hierarchyPath!.last
              : null),
    ),
    topSubsystems: rank(
      (ticket) =>
          ticket.subsystem ??
          (ticket.hierarchyPath != null && ticket.hierarchyPath!.length > 1
              ? ticket.hierarchyPath![ticket.hierarchyPath!.length - 2]
              : null),
    ),
    sourceTicketCount: tickets.length,
    sourceExecutionCount: executions.length,
    sourceEventCount: events.length,
  );
}
