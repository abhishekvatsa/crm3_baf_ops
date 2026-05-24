import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../models/asset_fleet_status.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';

const int _fleetStatusOpenTicketLimit = 300;
const int _fleetStatusExactAssetOpenTicketLimit = 200;
const int _fleetStatusExecutionHistoryLimit = 750;
const int _fleetStatusExactAssetExecutionLimit = 500;

class FleetStatusFilter {
  final AssetType assetType;
  final int? assetNumber;

  const FleetStatusFilter({
    required this.assetType,
    this.assetNumber,
  });

  bool get hasExactAsset => assetNumber != null;

  @override
  bool operator ==(Object other) {
    return other is FleetStatusFilter &&
        other.assetType == assetType &&
        other.assetNumber == assetNumber;
  }

  @override
  int get hashCode => Object.hash(assetType, assetNumber);
}

final fleetStatusProvider =
StreamProvider.family<List<AssetFleetStatus>, AssetType>((ref, assetType) {
  final maintenanceRepo = ref.watch(maintenanceRepositoryProvider);
  final plannedRepo = ref.watch(plannedRepositoryProvider);

  return _combineLatest2<List<MaintenanceRecord>, List<JobExecution>,
      List<AssetFleetStatus>>(
    maintenanceRepo.watchOpenTicketsByAssetType(
      assetType,
      limit: _fleetStatusOpenTicketLimit,
    ),
    plannedRepo.watchExecutionsByAssetType(
      assetType,
      limit: _fleetStatusExecutionHistoryLimit,
    ),
        (typeTickets, typeExecutions) => _buildFleetStatus(
      assetType: assetType,
      typeTickets: typeTickets,
      typeExecutions: typeExecutions,
    ),
  );
});

final filteredFleetStatusProvider =
StreamProvider.family<List<AssetFleetStatus>, FleetStatusFilter>((ref, filter) {
  final maintenanceRepo = ref.watch(maintenanceRepositoryProvider);
  final plannedRepo = ref.watch(plannedRepositoryProvider);

  if (!filter.hasExactAsset) {
    return _combineLatest2<List<MaintenanceRecord>, List<JobExecution>,
        List<AssetFleetStatus>>(
      maintenanceRepo.watchOpenTicketsByAssetType(
        filter.assetType,
        limit: _fleetStatusOpenTicketLimit,
      ),
      plannedRepo.watchExecutionsByAssetType(
        filter.assetType,
        limit: _fleetStatusExecutionHistoryLimit,
      ),
          (typeTickets, typeExecutions) => _buildFleetStatus(
        assetType: filter.assetType,
        typeTickets: typeTickets,
        typeExecutions: typeExecutions,
      ),
    );
  }

  return _combineLatest2<List<MaintenanceRecord>, List<JobExecution>,
      List<AssetFleetStatus>>(
    maintenanceRepo.watchOpenTicketsForAsset(
      filter.assetType,
      filter.assetNumber!,
      limit: _fleetStatusExactAssetOpenTicketLimit,
    ),
    plannedRepo.watchExecutionsForAsset(
      filter.assetType,
      filter.assetNumber!,
      limit: _fleetStatusExactAssetExecutionLimit,
    ),
        (assetTickets, assetExecutions) => _buildFleetStatus(
      assetType: filter.assetType,
      typeTickets: assetTickets,
      typeExecutions: assetExecutions,
    ),
  );
});

List<AssetFleetStatus> _buildFleetStatus({
  required AssetType assetType,
  required List<MaintenanceRecord> typeTickets,
  required List<JobExecution> typeExecutions,
}) {
  final assetNumbers = <int>{};
  final openTicketCountsByAsset = <int, int>{};
  final completedExecutionsByAsset = <int, List<JobExecution>>{};

  for (final ticket in typeTickets) {
    assetNumbers.add(ticket.assetNumber);

    if (!ticket.isResolved) {
      openTicketCountsByAsset.update(
        ticket.assetNumber,
            (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  for (final execution in typeExecutions) {
    assetNumbers.add(execution.assetNumber);

    if (execution.isCompleted && execution.completedAt != null) {
      completedExecutionsByAsset
          .putIfAbsent(execution.assetNumber, () => <JobExecution>[])
          .add(execution);
    }
  }

  final sortedNumbers = assetNumbers.toList()..sort();
  final now = DateTime.now();

  return sortedNumbers.map((assetNumber) {
    final completedExecutions =
        completedExecutionsByAsset[assetNumber] ?? <JobExecution>[];
    completedExecutions.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    final recentJobs = completedExecutions.take(3).toList();
    final lastJob = completedExecutions.isNotEmpty ? completedExecutions.first : null;
    final daysSince =
    lastJob == null ? null : now.difference(lastJob.completedAt!).inDays;

    return AssetFleetStatus(
      assetNumber: assetNumber,
      assetType: assetType,
      openTicketsCount: openTicketCountsByAsset[assetNumber] ?? 0,
      recentCompletedJobs: recentJobs,
      daysSinceLastCompletedJob: daysSince,
    );
  }).toList();
}

Stream<R> _combineLatest2<A, B, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    R Function(A latestA, B latestB) combine,
    ) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subscriptionA;
  StreamSubscription<B>? subscriptionB;

  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  var doneA = false;
  var doneB = false;

  void emitIfReady() {
    if (hasA && hasB && !controller.isClosed) {
      controller.add(combine(latestA as A, latestB as B));
    }
  }

  void closeIfDone() {
    if (doneA && doneB && !controller.isClosed) {
      controller.close();
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subscriptionA = streamA.listen(
            (value) {
          latestA = value;
          hasA = true;
          emitIfReady();
        },
        onError: controller.addError,
        onDone: () {
          doneA = true;
          closeIfDone();
        },
      );

      subscriptionB = streamB.listen(
            (value) {
          latestB = value;
          hasB = true;
          emitIfReady();
        },
        onError: controller.addError,
        onDone: () {
          doneB = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await subscriptionA?.cancel();
      await subscriptionB?.cancel();
    },
  );

  return controller.stream;
}
