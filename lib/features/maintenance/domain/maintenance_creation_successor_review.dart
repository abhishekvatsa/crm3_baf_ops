import 'dart:convert';

import '../../../core/persistence/durable_submission.dart';
import '../../maintenance_workflow/data/workflow_command_receipt_record.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../data/maintenance_model.dart';
import '../services/maintenance_issue_create_command.dart';
import 'maintenance_ticket_correction.dart';

String maintenanceReviewJson(Object? value) {
  Object? ordered(Object? item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: ordered(item[key])};
    }
    if (item is List) return item.map(ordered).toList();
    return item;
  }

  return jsonEncode(ordered(value));
}

Map<String, Object?> maintenanceCorrectionValues(MaintenanceRecord row) => {
  'description': row.description,
  'routedTo': row.routedTo.name,
  'maintenanceType': row.maintenanceType.name,
  'isCritical': row.isCritical,
  'plantConditionEffect': row.effectivePlantConditionEffect.name,
  'component': cleanMaintenanceOptionalText(row.component ?? ''),
  'subsystem': cleanMaintenanceOptionalText(row.subsystem ?? ''),
  'tag': cleanMaintenanceTagText(row.tag ?? ''),
  'classification': cleanMaintenanceOptionalText(row.classification ?? ''),
  'otherDepartment': cleanMaintenanceOptionalText(row.otherDepartment ?? ''),
  'remarks': cleanMaintenanceOptionalText(row.remarks ?? ''),
};

/// A server version fences all fields, including server-only lifecycle data.
/// The additional values make a same-version contradictory read fail closed.
String maintenanceReviewServerBoundary(MaintenanceRecord row) =>
    maintenanceReviewJson({
      'ticketId': row.firestoreId,
      'version': row.version,
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      'createdAt': row.createdAt.toUtc().toIso8601String(),
      'loggedByUid': row.loggedByUid,
      'assetType': row.assetType.name,
      'assetNumber': row.assetNumber,
      'assetHierarchyRefJson': row.assetHierarchyRefJson,
      'startDate': row.startDate.toUtc().toIso8601String(),
      'endDate': row.endDate?.toUtc().toIso8601String(),
      'isDeleted': row.isDeleted,
      'status': row.status.name,
      'metadataJson': row.metadataJson,
      'actionsJson': row.actionsJson,
      'resolutionHistoryJson': row.resolutionHistoryJson,
      'workflowAggregateId': row.workflowAggregateId,
      'workflowQueueState': row.workflowQueueState,
      'operationalEventIssueLinkIds': row.operationalEventIssueLinkIds,
      'values': maintenanceCorrectionValues(row),
    });

Map<String, Object?> maintenanceReviewReceiptMap(
  WorkflowCommandReceipt receipt,
) => {
  'commandId': receipt.commandId,
  'resultKey': receipt.resultKey,
  'aggregateVersion': receipt.aggregateVersion,
  'result': receipt.result,
  'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
};

/// Read-only evidence of A. Reading an accepted envelope never dispatches A or
/// changes its original actor to the supervisor reviewing B.
class MaintenanceCreationAcceptance {
  const MaintenanceCreationAcceptance({
    required this.envelopeJson,
    required this.actorUid,
    required this.command,
    required this.receipt,
  });
  final String envelopeJson, actorUid;
  final WorkflowCommand command;
  final WorkflowCommandReceipt receipt;

  factory MaintenanceCreationAcceptance.fromRecord(
    WorkflowCommandReceiptRecord row,
    String ticketId,
  ) {
    final saved = durableSubmissionJsonObject(row.resultJson);
    final envelopeJson = saved['__workflowAcceptedEnvelopeV1'];
    if (saved.length != 2 ||
        envelopeJson is! String ||
        saved['result'] is! Map) {
      throw StateError(
        'The original acceptance has incomplete evidence. Nothing was replaced.',
      );
    }
    final envelope = durableSubmissionJsonObject(envelopeJson);
    final raw = envelope['command'];
    final actor = envelope['originActorUid'];
    if (envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        actor is! String ||
        actor.isEmpty ||
        actor.trim() != actor ||
        raw is! Map<String, dynamic> ||
        raw.length != 5 ||
        raw['commandType'] != 'createMaintenanceTicket' ||
        raw['commandId'] !=
            maintenanceIssueCreateCommandIdForTicket(ticketId) ||
        raw['aggregateId'] != ticketId ||
        raw['expectedVersion'] != 0 ||
        raw['payload'] is! Map<String, dynamic> ||
        row.commandId != raw['commandId'] ||
        row.aggregateId != ticketId) {
      throw StateError(
        'The original creation identity or account is inconsistent. Nothing was replaced.',
      );
    }
    final command = WorkflowCommand(
      commandId: row.commandId,
      type: WorkflowCommandType.createMaintenanceTicket,
      aggregateId: ticketId,
      expectedVersion: 0,
      payload: Map<String, Object?>.from(raw['payload'] as Map),
    );
    final receipt = WorkflowCommandReceipt.fromMap({
      'commandId': row.commandId,
      'resultKey': row.resultKey,
      'aggregateVersion': row.aggregateVersion,
      'result': saved['result'],
      'appliedAt': row.appliedAt.toUtc().toIso8601String(),
    });
    validateMaintenanceIssueCreateReceipt(
      command: command,
      receipt: receipt,
      createVersion: 1,
    );
    return MaintenanceCreationAcceptance(
      envelopeJson: envelopeJson,
      actorUid: actor,
      command: command,
      receipt: receipt,
    );
  }

  void validateServer(MaintenanceRecord server) {
    if (server.firestoreId != command.aggregateId ||
        server.isDeleted ||
        server.version < 1 ||
        server.loggedByUid != actorUid ||
        !server.createdAt.isAtSameMomentAs(receipt.appliedAt)) {
      throw StateError(
        'The confirmed server issue does not match the original accepted creation. Both records are retained.',
      );
    }
  }
}

class MaintenanceCreationSuccessorReview {
  MaintenanceCreationSuccessorReview({
    required this.acceptance,
    required this.local,
    required this.server,
    required this.localSnapshotJson,
  }) : serverBoundaryJson = maintenanceReviewServerBoundary(server) {
    acceptance.validateServer(server);
    if (local.firestoreId != server.firestoreId ||
        local.isSynced ||
        local.isDeleted) {
      throw StateError(
        'This device no longer holds the pending draft selected for review.',
      );
    }
  }
  final MaintenanceCreationAcceptance acceptance;
  final MaintenanceRecord local, server;

  /// Complete native Isar export, including every persisted property and raw
  /// JSON string. Never substitute MaintenanceRecord.toAuditMap for this.
  final String localSnapshotJson;
  final String serverBoundaryJson;
  String get ticketId => acceptance.command.aggregateId;
  String get originalActorUid => acceptance.actorUid;
  String get originalEnvelopeJson => acceptance.envelopeJson;
  Map<String, Object?> get originalValues {
    final ticket = acceptance.command.payload['ticket'] as Map;
    return {
      for (final key in maintenanceCorrectionValues(local).keys)
        key: key == 'remarks' ? null : ticket[key],
    };
  }

  Map<String, Object?> get localValues => maintenanceCorrectionValues(local);
  Map<String, Object?> get serverValues => maintenanceCorrectionValues(server);
  List<String> get changedFields => [
    for (final key in localValues.keys)
      if (maintenanceReviewJson(originalValues[key]) !=
          maintenanceReviewJson(localValues[key]))
        key,
  ];
  List<String> get unsupportedChanges {
    final original = acceptance.command.payload['ticket'] as Map;
    final result = <String>[];
    void compare(String key, Object? value) {
      if (maintenanceReviewJson(original[key]) !=
          maintenanceReviewJson(value)) {
        result.add(key);
      }
    }

    compare('assetType', local.assetType.name);
    compare('assetNumber', local.assetNumber);
    compare('startDate', local.startDate.toUtc().toIso8601String());
    compare('chargeNoAtEvent', local.chargeNoAtEvent);
    compare('continuesIssueId', local.continuesIssueId);
    if (local.assetHierarchyRefJson != original['assetHierarchyRefJson']) {
      result.add(
        'registered target (requires a fresh explicit target selection)',
      );
    }
    if (local.status != TicketStatus.open ||
        local.isResolved ||
        local.endDate != null ||
        local.acknowledgedByUid != null ||
        local.closedByUid != null ||
        local.reopenedByUid != null ||
        local.actionsJson != '[]' ||
        local.resolutionHistoryJson != '[]' ||
        local.teamsInvolved.isNotEmpty ||
        local.performedBy != null) {
      result.add('work, acknowledgement or closure history');
    }
    if (local.metadataJson != server.metadataJson) {
      result.add('retained assessment, lane or specialist metadata');
    }
    if (local.workflowAggregateId != server.workflowAggregateId ||
        local.workflowQueueState != server.workflowQueueState ||
        maintenanceReviewJson(local.operationalEventIssueLinkIds) !=
            maintenanceReviewJson(server.operationalEventIssueLinkIds)) {
      result.add('workflow or linked operational evidence');
    }
    return List.unmodifiable(result);
  }

  bool get hasDifferences =>
      changedFields.isNotEmpty || unsupportedChanges.isNotEmpty;

  Map<String, Object?> evidence({
    required String reason,
    required Map<String, Object?> corrections,
    required String disposition,
    String? targetReferenceJson,
  }) => {
    'schemaVersion': 1,
    'kind': 'maintenanceCreationSuccessorReview',
    'ticketId': ticketId,
    'originalEnvelopeJson': originalEnvelopeJson,
    'originalReceipt': maintenanceReviewReceiptMap(acceptance.receipt),
    'localSnapshotJson': localSnapshotJson,
    'serverBoundaryJson': serverBoundaryJson,
    'originalValues': originalValues,
    'localValues': localValues,
    'serverValues': serverValues,
    'selectedCorrections': corrections,
    'retainedCorrectableFields': [
      for (final field in changedFields)
        if (!corrections.containsKey(field)) field,
    ],
    'targetReferenceJson': targetReferenceJson,
    'retainedUnsupportedChanges': unsupportedChanges,
    'reason': reason,
    'disposition': disposition,
  };
}
