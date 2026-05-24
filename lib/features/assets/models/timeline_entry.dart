import '../../maintenance/data/maintenance_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';

enum TimelineEventType { maintenance, plannedJob }

class TimelineEntry {
  final TimelineEventType type;
  final DateTime timestamp;
  final AssetType assetType;
  final int assetNumber;
  final MaintenanceRecord? ticket;
  final JobExecution? execution;

  TimelineEntry.fromTicket(MaintenanceRecord t)
      : type = TimelineEventType.maintenance,
        timestamp = t.createdAt,
        assetType = t.assetType,
        assetNumber = t.assetNumber,
        ticket = t,
        execution = null;

  TimelineEntry.fromExecution(JobExecution e)
      : type = TimelineEventType.plannedJob,
        timestamp = e.createdAt,
        assetType = e.assetType,
        assetNumber = e.assetNumber,
        ticket = null,
        execution = e;

  String get title {
    if (type == TimelineEventType.maintenance) {
      return ticket?.description ?? '';
    } else {
      return execution?.templateName ?? '';
    }
  }

  String get subtitle {
    if (type == TimelineEventType.maintenance) {
      final t = ticket!;
      final routed = t.routedTo.name.toUpperCase();
      final by = t.loggedByName ?? t.reportedBy ?? 'Unknown';
      final status = t.isResolved ? 'Resolved' : 'Open';
      return '$routed — $status — By $by';
    } else {
      final e = execution!;
      // Fixed: was duplicate isNotEmpty check — second branch never executed
      final agencies = e.assignedAgencies.isNotEmpty
          ? e.assignedAgencies.map((a) => a.toUpperCase()).join(', ')
          : 'Unassigned';
      return e.isCompleted
          ? '$agencies — Completed by ${e.completedByName ?? "Unknown"}'
          : '$agencies — Pending';
    }
  }

  bool get isResolved {
    if (type == TimelineEventType.maintenance) {
      return ticket?.isResolved ?? false;
    }
    return execution?.isCompleted ?? false;
  }
}