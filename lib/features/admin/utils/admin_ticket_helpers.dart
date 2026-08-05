import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';

String? cleanAdminOptionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? cleanAdminTagText(String value) {
  return cleanAdminOptionalText(value)?.toUpperCase();
}

MaintenanceRecord copyTicketForAdminEdit({
  required MaintenanceRecord source,
  required AssetType assetType,
  required int assetNumber,
  required String description,
  required RoutedTo routedTo,
  required MaintenanceType maintenanceType,
  required TicketStatus status,
  required String? component,
  required String? tag,
  required String? remarks,
  required String editedByUid,
  required String editedByName,
}) {
  if (!source.actionsReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'actionsJson',
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
      detail: 'saved action evidence needs repair',
    );
  }
  if (!source.resolutionHistoryReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'resolutionHistoryJson',
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
      detail: 'saved resolution history needs repair',
    );
  }
  final now = DateTime.now();
  final wasResolved =
      source.isResolved || source.status == TicketStatus.resolved;
  final willBeResolved = status == TicketStatus.resolved;
  final sourceResolvedAt = source.endDate;
  if (wasResolved && sourceResolvedAt == null) {
    throw PersistedDataFormatException(
      field: 'endDate',
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
      detail: 'resolved ticket has no closure timestamp',
    );
  }
  final resolvedAt = sourceResolvedAt ?? now;
  final downtimeHours =
      source.downtimeHours ??
      resolvedAt.difference(source.startDate).inMinutes / 60.0;

  final edited =
      MaintenanceRecord()
        ..id = source.id
        ..firestoreId = source.firestoreId
        ..version = source.version
        ..isSynced = source.isSynced
        ..isDeleted = source.isDeleted
        ..deletedAt = source.deletedAt
        ..deletedByUid = source.deletedByUid
        ..deletedByName = source.deletedByName
        ..deleteReason = source.deleteReason
        ..assetType = assetType
        ..assetNumber = assetNumber
        ..component = component
        ..subsystem = source.subsystem
        ..tag = tag
        ..hierarchyPath =
            source.hierarchyPath == null
                ? null
                : List<String>.from(source.hierarchyPath!)
        ..maintenanceType = maintenanceType
        ..classification = source.classification
        ..description = description
        ..routedTo = routedTo
        ..otherDepartment = source.otherDepartment
        ..status = status
        ..isResolved = willBeResolved
        ..loggedByUid = source.loggedByUid
        ..loggedByName = source.loggedByName
        ..reportedBy = source.reportedBy
        ..acknowledgedByUid = source.acknowledgedByUid
        ..acknowledgedByName = source.acknowledgedByName
        ..acknowledgedAt = source.acknowledgedAt
        ..closedByUid =
            willBeResolved ? (source.closedByUid ?? editedByUid) : null
        ..closedByName =
            willBeResolved ? (source.closedByName ?? editedByName) : null
        ..teamsInvolved =
            willBeResolved
                ? List<String>.from(source.teamsInvolved)
                : <String>[]
        ..performedBy = source.performedBy
        ..remarks = remarks
        ..startDate = source.startDate
        ..endDate = willBeResolved ? resolvedAt : null
        ..downtimeHours = willBeResolved ? downtimeHours : null
        ..chargeNoAtEvent = source.chargeNoAtEvent
        ..createdAt = source.createdAt
        ..updatedAt = now
        ..metadataJson = source.metadataJson
        ..actionsJson =
            wasResolved && !willBeResolved ? '[]' : source.actionsJson
        ..resolutionHistoryJson = source.resolutionHistoryJson;

  if (wasResolved && !willBeResolved) {
    final historyPayload = readValidatedResolutionHistoryPayload(
      source.resolutionHistoryJson,
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
    );
    historyPayload.rows.add(
      ResolutionHistory(
        resolvedByUid: source.closedByUid,
        resolvedByName: source.closedByName,
        resolvedAt: sourceResolvedAt,
        actionsJson: source.actionsJson,
        remarks: source.remarks,
        downtimeHours: source.downtimeHours,
        teamsInvolved: List<String>.from(source.teamsInvolved),
      ).toMap(),
    );
    edited.resolutionHistoryJson = jsonEncode(historyPayload.rows);
  }

  return edited;
}
