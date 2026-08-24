import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../maintenance_workflow/data/equipment_status_record.dart';

enum TimelineEventType { maintenance, plannedJob, equipmentProjection }

class TimelineEntry {
  final TimelineEventType type;
  final DateTime timestamp;
  final AssetType assetType;
  final int assetNumber;
  final MaintenanceRecord? ticket;
  final JobExecution? execution;
  final EquipmentStatusRecord? equipmentStatus;

  TimelineEntry.fromTicket(MaintenanceRecord t)
      : type = TimelineEventType.maintenance,
        timestamp = t.createdAt,
        assetType = t.assetType,
        assetNumber = t.assetNumber,
        ticket = t,
        execution = null,
        equipmentStatus = null;

  TimelineEntry.fromExecution(JobExecution e)
      : type = TimelineEventType.plannedJob,
        timestamp = e.createdAt,
        assetType = e.assetType,
        assetNumber = e.assetNumber,
        ticket = null,
        execution = e,
        equipmentStatus = null;

  TimelineEntry.fromEquipmentProjection(EquipmentStatusRecord row)
      : type = TimelineEventType.equipmentProjection,
        timestamp = row.lastTransitionAt ?? row.updatedAt,
        assetType = AssetType.values.firstWhere(
          (value) => value.name == row.assetTypeKey,
          orElse: () => AssetType.base,
        ),
        assetNumber = row.assetNumber,
        ticket = null,
        execution = null,
        equipmentStatus = row;

  String get title {
    switch (type) {
      case TimelineEventType.maintenance:
        return ticket?.description ?? '';
      case TimelineEventType.plannedJob:
        return execution?.templateName ?? '';
      case TimelineEventType.equipmentProjection:
        return 'Canonical equipment state: ${equipmentStatus?.stateKey ?? 'unknown'}';
    }
  }

  String get subtitle {
    switch (type) {
      case TimelineEventType.maintenance:
        final t = ticket!;
        final routed = t.routedTo.name.toUpperCase();
        final by = t.loggedByName ?? t.reportedBy ?? 'Unknown';
        final status = t.lifecycleSummaryLabel;
        return '$routed — $status — By $by';
      case TimelineEventType.plannedJob:
        final e = execution!;
        final agencies = e.assignedAgencies.isNotEmpty
            ? e.assignedAgencies.map((a) => a.toUpperCase()).join(', ')
            : 'Unassigned';
        if (e.isCancelled) return '$agencies — Cancelled';
        return e.isCompleted
            ? '$agencies — Completed by ${e.completedByName ?? "Unknown"}'
            : '$agencies — Pending';
      case TimelineEventType.equipmentProjection:
        final row = equipmentStatus!;
        return 'Maintenance ${row.openMaintenanceCount} · RED ${row.openRedCount} · Preparation ${row.awaitingPreparationCount}';
    }
  }

  bool get isResolved {
    switch (type) {
      case TimelineEventType.maintenance:
        return ticket?.isResolved ?? false;
      case TimelineEventType.plannedJob:
        return (execution?.isCompleted ?? false) ||
            (execution?.isCancelled ?? false);
      case TimelineEventType.equipmentProjection:
        return equipmentStatus?.stateKey == 'available' ||
            equipmentStatus?.stateKey == 'inService';
    }
  }
}
