import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../models/asset_fleet_status.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';

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
  final workflowRepo = ref.watch(workflowRepositoryProvider);

  return _combineLatest3<List<MaintenanceRecord>, List<JobExecution>,
      List<EquipmentStatusRecord>, List<AssetFleetStatus>>(
    maintenanceRepo.watchOpenTicketsByAssetType(
      assetType,
      limit: _fleetStatusOpenTicketLimit,
    ),
    plannedRepo.watchExecutionsByAssetType(
      assetType,
      limit: _fleetStatusExecutionHistoryLimit,
    ),
    workflowRepo.watchEquipmentByState(null),
    (typeTickets, typeExecutions, equipment) => _buildFleetStatus(
      assetType: assetType,
      typeTickets: typeTickets,
      typeExecutions: typeExecutions,
      equipment: equipment,
    ),
  );
});

final filteredFleetStatusProvider =
StreamProvider.family<List<AssetFleetStatus>, FleetStatusFilter>((ref, filter) {
  final maintenanceRepo = ref.watch(maintenanceRepositoryProvider);
  final plannedRepo = ref.watch(plannedRepositoryProvider);
  final workflowRepo = ref.watch(workflowRepositoryProvider);

  final ticketStream = filter.hasExactAsset
      ? maintenanceRepo.watchOpenTicketsForAsset(
          filter.assetType,
          filter.assetNumber!,
          limit: _fleetStatusExactAssetOpenTicketLimit,
        )
      : maintenanceRepo.watchOpenTicketsByAssetType(
          filter.assetType,
          limit: _fleetStatusOpenTicketLimit,
        );
  final executionStream = filter.hasExactAsset
      ? plannedRepo.watchExecutionsForAsset(
          filter.assetType,
          filter.assetNumber!,
          limit: _fleetStatusExactAssetExecutionLimit,
        )
      : plannedRepo.watchExecutionsByAssetType(
          filter.assetType,
          limit: _fleetStatusExecutionHistoryLimit,
        );

  return _combineLatest3<List<MaintenanceRecord>, List<JobExecution>,
      List<EquipmentStatusRecord>, List<AssetFleetStatus>>(
    ticketStream,
    executionStream,
    workflowRepo.watchEquipmentByState(null),
    (tickets, executions, equipment) => _buildFleetStatus(
      assetType: filter.assetType,
      typeTickets: tickets,
      typeExecutions: executions,
      equipment: equipment,
      exactAssetNumber: filter.assetNumber,
    ),
  );
});

List<AssetFleetStatus> _buildFleetStatus({
  required AssetType assetType,
  required List<MaintenanceRecord> typeTickets,
  required List<JobExecution> typeExecutions,
  required List<EquipmentStatusRecord> equipment,
  int? exactAssetNumber,
}) {
  final assetNumbers = <int>{};
  final openTicketCountsByAsset = <int, int>{};
  final completedExecutionsByAsset = <int, List<JobExecution>>{};
  final equipmentByAsset = <int, EquipmentStatusRecord>{};

  for (final row in equipment) {
    if (row.assetTypeKey != assetType.name) continue;
    if (exactAssetNumber != null && row.assetNumber != exactAssetNumber) {
      continue;
    }
    assetNumbers.add(row.assetNumber);
    equipmentByAsset[row.assetNumber] = row;
  }

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
      workflowEquipmentStatus: equipmentByAsset[assetNumber],
    );
  }).toList();
}

Stream<R> _combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A latestA, B latestB, C latestC) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subscriptionA;
  StreamSubscription<B>? subscriptionB;
  StreamSubscription<C>? subscriptionC;
  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var doneA = false;
  var doneB = false;
  var doneC = false;

  void emitIfReady() {
    if (hasA && hasB && hasC && !controller.isClosed) {
      controller.add(combine(latestA as A, latestB as B, latestC as C));
    }
  }

  void closeIfDone() {
    if (doneA && doneB && doneC && !controller.isClosed) {
      controller.close();
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subscriptionA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emitIfReady();
      }, onError: controller.addError, onDone: () {
        doneA = true;
        closeIfDone();
      });
      subscriptionB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emitIfReady();
      }, onError: controller.addError, onDone: () {
        doneB = true;
        closeIfDone();
      });
      subscriptionC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emitIfReady();
      }, onError: controller.addError, onDone: () {
        doneC = true;
        closeIfDone();
      });
    },
    onCancel: () async {
      await subscriptionA?.cancel();
      await subscriptionB?.cancel();
      await subscriptionC?.cancel();
    },
  );
  return controller.stream;
}
