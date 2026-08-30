import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/models/audit_event_model.dart';
import '../../auth/data/user_model.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../data/maintenance_model.dart';
import '../providers/maintenance_provider.dart';

class MaintenanceIssueCommandConvergenceException implements Exception {
  const MaintenanceIssueCommandConvergenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MaintenanceIssueCommandReconciler {
  const MaintenanceIssueCommandReconciler({
    required this.localRepository,
    required this.remoteRepository,
  });

  final MaintenanceRepository localRepository;
  final MaintenanceRepository remoteRepository;

  Future<MaintenanceRecord> adoptServerMutation({
    required String firestoreId,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
    required int minimumServerVersion,
  }) async {
    final id = firestoreId.trim();
    if (id.isEmpty || expectedLocalVersion < 1 || minimumServerVersion < 1) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The accepted issue command returned an invalid convergence boundary.',
      );
    }

    MaintenanceRecord? remote;
    try {
      remote = await remoteRepository.readMaintenanceIssueCommandServerState(
        id,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but its exact server state could not be read on this device.',
      );
    }
    if (remote == null ||
        remote.isDeleted ||
        remote.version < minimumServerVersion) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but its exact server state is not yet readable on this device.',
      );
    }

    bool didAdopt;
    try {
      didAdopt = await localRepository.applyMaintenanceIssueCommandReadback(
        remote: remote,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but this device could not adopt the exact server state.',
      );
    }
    MaintenanceRecord? adopted;
    try {
      adopted = await localRepository.getByFirestoreId(id);
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but this device could not verify its exact local state.',
      );
    }
    if (adopted != null && _sameCommandState(adopted, remote)) {
      return adopted;
    }
    if (!didAdopt) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but newer local work was preserved for reconciliation.',
      );
    }
    if (adopted == null) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue change was accepted, but this device could not adopt the exact server version.',
      );
    }
    throw const MaintenanceIssueCommandConvergenceException(
      'The issue change was accepted, but this device could not adopt the exact server version.',
    );
  }

  Future<MaintenanceRecord> refreshServerState({
    required String firestoreId,
    required int expectedLocalVersion,
    required DateTime expectedLocalUpdatedAt,
  }) async {
    final id = firestoreId.trim();
    if (id.isEmpty || expectedLocalVersion < 1) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue refresh boundary is invalid.',
      );
    }

    MaintenanceRecord? remote;
    try {
      remote = await remoteRepository.readMaintenanceIssueCommandServerState(
        id,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The exact server issue could not be read on this device.',
      );
    }
    if (remote == null || remote.version < expectedLocalVersion) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The exact server issue is absent or older than this synchronized device record.',
      );
    }

    bool didAdopt;
    try {
      didAdopt = await localRepository.applyMaintenanceIssueServerRefresh(
        remote: remote,
        expectedLocalVersion: expectedLocalVersion,
        expectedLocalUpdatedAt: expectedLocalUpdatedAt,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'This device could not apply the exact server issue safely.',
      );
    }
    MaintenanceRecord? adopted;
    try {
      adopted = await localRepository.getByFirestoreId(id);
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'This device could not verify the refreshed issue.',
      );
    }
    if (adopted != null && _sameCommandState(adopted, remote)) {
      return adopted;
    }
    if (!didAdopt) {
      throw const MaintenanceIssueCommandConvergenceException(
        'Newer local work was preserved; synchronize it before refreshing this issue.',
      );
    }
    if (adopted == null) {
      throw const MaintenanceIssueCommandConvergenceException(
        'This device could not verify the exact refreshed server version.',
      );
    }
    throw const MaintenanceIssueCommandConvergenceException(
      'This device could not verify the exact refreshed server version.',
    );
  }

  Future<MaintenanceRecord> softDeleteServerFirst({
    required MaintenanceRecord localRecord,
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    final firestoreId = localRecord.firestoreId?.trim() ?? '';
    if (firestoreId.isEmpty ||
        localRecord.version < 1 ||
        localRecord.isDeleted ||
        !localRecord.isSynced) {
      throw const MaintenanceIssueCommandConvergenceException(
        'Synchronize this issue before requesting its governed deletion.',
      );
    }
    final originalVersion = localRecord.version;
    final originalUpdatedAt = localRecord.updatedAt;

    try {
      await remoteRepository.deleteTicket(
        firestoreId,
        actor: actor,
        auditContext: auditContext,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The plant system did not accept this issue deletion. The device record was left unchanged.',
      );
    }

    MaintenanceRecord adopted;
    try {
      adopted = await refreshServerState(
        firestoreId: firestoreId,
        expectedLocalVersion: originalVersion,
        expectedLocalUpdatedAt: originalUpdatedAt,
      );
    } catch (_) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue was deleted in the plant system, but this device could not yet adopt the exact tombstone.',
      );
    }
    if (!adopted.isDeleted || adopted.version <= originalVersion) {
      throw const MaintenanceIssueCommandConvergenceException(
        'The issue deletion did not return a newer authoritative tombstone.',
      );
    }
    return adopted;
  }
}

void validateMaintenanceIssueLaneCommandReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
}) {
  final expectedResultKey = switch (command.type) {
    WorkflowCommandType.acknowledgeMaintenanceTicket =>
      'maintenance-ticket-acknowledged',
    WorkflowCommandType.completeMaintenanceTicketLane =>
      'maintenance-ticket-lane-completed',
    WorkflowCommandType.reconfigureMaintenanceTicketLanes =>
      'maintenance-ticket-lanes-reconfigured',
    _ => null,
  };
  if (expectedResultKey == null ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != expectedResultKey ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}') {
    throw StateError(
      'The governed issue-lane receipt is inconsistent with the request.',
    );
  }

  if (command.type == WorkflowCommandType.reconfigureMaintenanceTicketLanes) {
    if (!_sameReceiptList(receipt.result['lanes'], command.payload['lanes'])) {
      throw StateError(
        'The governed issue-lane receipt has inconsistent lane evidence.',
      );
    }
    return;
  }
  if (receipt.result['lane'] != command.payload['lane']) {
    throw StateError(
      'The governed issue-lane receipt has inconsistent lane evidence.',
    );
  }
}

void validateMaintenanceTicketCorrectionReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
}) {
  final corrections = command.payload['corrections'];
  if (command.type != WorkflowCommandType.correctMaintenanceTicket ||
      corrections is! Map ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'maintenance-ticket-corrected' ||
      receipt.aggregateVersion != command.expectedVersion + 1 ||
      receipt.result['ticketId'] != command.aggregateId ||
      receipt.result['auditId'] !=
          'server_maintenance_ticket_${command.commandId}') {
    throw StateError(
      'The governed issue-correction receipt is inconsistent with the request.',
    );
  }

  final correctedFields = <String>[];
  for (final key in corrections.keys) {
    if (key is! String) {
      throw StateError(
        'The governed issue-correction request contains an invalid field.',
      );
    }
    correctedFields.add(key);
  }
  correctedFields.sort();
  if (!_sameReceiptList(receipt.result['correctedFields'], correctedFields)) {
    throw StateError(
      'The governed issue-correction receipt has inconsistent field evidence.',
    );
  }
}

int validateMaintenanceIssueCoordinationReceipt({
  required WorkflowCommand command,
  required WorkflowCommandReceipt receipt,
}) {
  final ticketId = command.payload['ticketId'];
  final expectedTicketVersion = command.payload['expectedTicketVersion'];
  final complianceId = command.payload['complianceId'];
  final requestPurposeKey = command.payload['requestPurposeKey'];
  final ticketVersion = receipt.result['ticketVersion'];
  if (command.type != WorkflowCommandType.startIssueCoordination ||
      command.expectedVersion != 0 ||
      ticketId is! String ||
      expectedTicketVersion is! int ||
      complianceId is! String ||
      requestPurposeKey is! String ||
      receipt.commandId != command.commandId ||
      receipt.resultKey != 'issue-coordination-started' ||
      receipt.aggregateVersion != 1 ||
      receipt.result['workflowId'] != command.aggregateId ||
      receipt.result['ticketId'] != ticketId ||
      receipt.result['complianceId'] != complianceId ||
      receipt.result['requestPurposeKey'] != requestPurposeKey ||
      ticketVersion is! int ||
      ticketVersion != expectedTicketVersion + 1) {
    throw StateError(
      'The governed Operations-coordination receipt is inconsistent with the issue.',
    );
  }
  return ticketVersion;
}

final maintenanceIssueCommandReconcilerProvider =
    Provider<MaintenanceIssueCommandReconciler>((ref) {
      return MaintenanceIssueCommandReconciler(
        localRepository: ref.read(maintenanceRepositoryProvider),
        remoteRepository: ref.read(firestoreMaintenanceRepo),
      );
    });

bool _sameCommandState(MaintenanceRecord local, MaintenanceRecord remote) {
  final localPlan = local.issueLanePlanReadResult.value;
  final remotePlan = remote.issueLanePlanReadResult.value;
  if (localPlan == null || remotePlan == null) return false;

  return local.isSynced &&
      local.version == remote.version &&
      local.updatedAt.toUtc() == remote.updatedAt.toUtc() &&
      local.isDeleted == remote.isDeleted &&
      _sameInstant(local.deletedAt, remote.deletedAt) &&
      local.deletedByUid == remote.deletedByUid &&
      local.deletedByName == remote.deletedByName &&
      local.deleteReason == remote.deleteReason &&
      local.routedTo == remote.routedTo &&
      local.otherDepartment == remote.otherDepartment &&
      local.status == remote.status &&
      local.isResolved == remote.isResolved &&
      _sameInstant(local.endDate, remote.endDate) &&
      local.closedByUid == remote.closedByUid &&
      local.closedByName == remote.closedByName &&
      local.reopenedByUid == remote.reopenedByUid &&
      local.reopenedByName == remote.reopenedByName &&
      _sameInstant(local.reopenedAt, remote.reopenedAt) &&
      local.reopenReason == remote.reopenReason &&
      local.remarks == remote.remarks &&
      local.downtimeHours == remote.downtimeHours &&
      _sameStrings(local.teamsInvolved, remote.teamsInvolved) &&
      local.actionsJson == remote.actionsJson &&
      local.resolutionHistoryJson == remote.resolutionHistoryJson &&
      local.metadataJson == remote.metadataJson &&
      local.acknowledgedByUid == remote.acknowledgedByUid &&
      local.acknowledgedByName == remote.acknowledgedByName &&
      _sameInstant(local.acknowledgedAt, remote.acknowledgedAt) &&
      localPlan.revision == remotePlan.revision &&
      _sameStrings(localPlan.assignedLanes, remotePlan.assignedLanes) &&
      _sameStrings(localPlan.acknowledgedLanes, remotePlan.acknowledgedLanes) &&
      _sameStrings(localPlan.completedLanes, remotePlan.completedLanes) &&
      local.workflowDeferred == remote.workflowDeferred &&
      local.workflowQueueState == remote.workflowQueueState &&
      local.workflowAggregateId == remote.workflowAggregateId &&
      local.workflowComplianceId == remote.workflowComplianceId &&
      local.workflowOriginLaneKey == remote.workflowOriginLaneKey &&
      local.workflowTargetLaneKey == remote.workflowTargetLaneKey &&
      local.workflowConditionTypeKey == remote.workflowConditionTypeKey &&
      local.workflowConditionRef == remote.workflowConditionRef &&
      _sameInstant(local.workflowUpdatedAt, remote.workflowUpdatedAt) &&
      _sameStrings(
        local.operationalEventIssueLinkIds,
        remote.operationalEventIssueLinkIds,
      );
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameReceiptList(Object? left, Object? right) {
  if (left is! List || right is! List || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameInstant(DateTime? left, DateTime? right) {
  if (left == null || right == null) return left == right;
  return left.toUtc() == right.toUtc();
}
