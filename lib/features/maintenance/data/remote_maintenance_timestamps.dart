import '../../../core/serialization/persisted_data_reader.dart';

class RemoteMaintenanceTimestamps {
  const RemoteMaintenanceTimestamps({
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.workflowDeferredAt,
    this.workflowReactivatedAt,
    this.workflowReleasedAt,
    this.workflowUpdatedAt,
    this.acknowledgedAt,
    this.reopenedAt,
    this.endDate,
    this.deletedAt,
  });

  final DateTime startDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? workflowDeferredAt;
  final DateTime? workflowReactivatedAt;
  final DateTime? workflowReleasedAt;
  final DateTime? workflowUpdatedAt;
  final DateTime? acknowledgedAt;
  final DateTime? reopenedAt;
  final DateTime? endDate;
  final DateTime? deletedAt;
}

RemoteMaintenanceTimestamps readRemoteMaintenanceTimestamps(
  Map<String, dynamic> data, {
  required String source,
}) {
  return RemoteMaintenanceTimestamps(
    startDate: readRequiredPersistedDateTime(
      data['startDate'],
      field: 'startDate',
      source: source,
    ),
    createdAt: readRequiredPersistedDateTime(
      data['createdAt'],
      field: 'createdAt',
      source: source,
    ),
    updatedAt: readRequiredPersistedDateTime(
      data['updatedAt'],
      field: 'updatedAt',
      source: source,
    ),
    workflowDeferredAt: readOptionalPersistedDateTime(
      data['workflowDeferredAt'],
      field: 'workflowDeferredAt',
      source: source,
    ),
    workflowReactivatedAt: readOptionalPersistedDateTime(
      data['workflowReactivatedAt'],
      field: 'workflowReactivatedAt',
      source: source,
    ),
    workflowReleasedAt: readOptionalPersistedDateTime(
      data['workflowReleasedAt'],
      field: 'workflowReleasedAt',
      source: source,
    ),
    workflowUpdatedAt: readOptionalPersistedDateTime(
      data['workflowUpdatedAt'],
      field: 'workflowUpdatedAt',
      source: source,
    ),
    acknowledgedAt: readOptionalPersistedDateTime(
      data['acknowledgedAt'],
      field: 'acknowledgedAt',
      source: source,
    ),
    reopenedAt: readOptionalPersistedDateTime(
      data['reopenedAt'],
      field: 'reopenedAt',
      source: source,
    ),
    endDate: readOptionalPersistedDateTime(
      data['endDate'],
      field: 'endDate',
      source: source,
    ),
    deletedAt: readOptionalPersistedDateTime(
      data['deletedAt'],
      field: 'deletedAt',
      source: source,
    ),
  );
}
