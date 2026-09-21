import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../audit/models/audit_event_model.dart';
import '../../maintenance_workflow/repositories/workflow_repository.dart';
import '../data/maintenance_model.dart';
import '../domain/maintenance_creation_successor_review.dart';
import '../services/maintenance_issue_create_command.dart';

/// Native review/adoption owner. This repository never writes business data to
/// Firestore. Its audit is a device reconciliation, not a server correction.
class MaintenanceCreationSuccessorRepository {
  const MaintenanceCreationSuccessorRepository({
    required this.isar,
    required this.workflow,
    required this.readServer,
    required this.readCorrectionAudit,
  });
  final Isar isar;
  final WorkflowRepository workflow;
  final Future<MaintenanceRecord?> Function(String ticketId) readServer;
  final Future<Map<String, dynamic>> Function(String auditId)
  readCorrectionAudit;

  Future<({MaintenanceRecord record, String snapshot})> _local(
    String ticketId,
  ) async {
    final query = isar.maintenanceRecords.filter().firestoreIdEqualTo(ticketId);
    final rows = await query.findAll();
    if (rows.length != 1) {
      throw StateError(
        'Exactly one saved device ticket is required. Duplicate or missing evidence remains retained.',
      );
    }
    final snapshot = await query.exportJsonRaw((bytes) => utf8.decode(bytes));
    // Apply the same bounded immutable evidence limit as the submission owner.
    durableSubmissionJsonObject(
      jsonEncode({'nativeRows': jsonDecode(snapshot)}),
    );
    return (record: rows.single, snapshot: snapshot);
  }

  Future<MaintenanceCreationSuccessorReview> review(String ticketId) async {
    final saved = await workflow.getReceipt(
      maintenanceIssueCreateCommandIdForTicket(ticketId),
    );
    if (saved == null) {
      throw StateError(
        'Original creation acceptance is not confirmed. The original reporter must recover the saved creation before Admin or SI can review newer edits.',
      );
    }
    final acceptance = MaintenanceCreationAcceptance.fromRecord(
      saved,
      ticketId,
    );
    final local = await isar.txn(() => _local(ticketId));
    final server = await readServer(ticketId);
    if (server == null) {
      throw StateError(
        'The server issue could not be confirmed. The device draft remains saved.',
      );
    }
    return MaintenanceCreationSuccessorReview(
      acceptance: acceptance,
      local: local.record,
      server: server,
      localSnapshotJson: local.snapshot,
    );
  }

  Future<void> requireUnchangedLocal(
    String ticketId,
    String snapshot,
  ) => isar.txn(() async {
    final current = await _local(ticketId);
    if (current.snapshot != snapshot) {
      throw StateError(
        'The device draft changed during review. Review the newer draft; no local evidence was replaced.',
      );
    }
  });

  /// Call only inside the submission owner's transaction, or [keepServer].
  Future<bool> adoptInTransaction({
    required String ticketId,
    required String expectedSnapshot,
    required MaintenanceRecord server,
    required Map<String, dynamic> evidence,
    required String reviewerUid,
    required String reviewerName,
    required DateTime reviewedAt,
    required void Function() requireActor,
    bool preserveNewerDraft = false,
  }) async {
    requireActor();
    final current = await _local(ticketId);
    requireActor();
    final unchanged =
        current.snapshot == expectedSnapshot &&
        !current.record.isSynced &&
        !current.record.isDeleted;
    if ((!unchanged && !preserveNewerDraft) ||
        server.firestoreId != ticketId ||
        server.isDeleted) {
      throw StateError(
        'Newer device work was preserved. The accepted correction remains available for review; this draft was not replaced.',
      );
    }
    final reason = evidence['reason'];
    if (reason is! String || reason.trim().isEmpty) {
      throw StateError('A review reason is required.');
    }
    if (unchanged) {
      server
        ..id = current.record.id
        ..isSynced = true;
      await isar.maintenanceRecords.put(server);
    }
    final adopted = await _local(ticketId);
    requireActor();
    await isar.auditEvents.put(
      AuditEvent(
          entityType: 'maintenance_draft_review',
          entityId: ticketId,
          action: AuditAction.update,
          severity: AuditSeverity.medium,
          performedByUid: reviewerUid,
          performedByName: reviewerName,
          reason: AuditReason.manualOverride,
          reasonNotes: reason,
          summary: unchanged
              ? 'Device draft reviewed and retained; confirmed server record adopted.'
              : 'Reviewed correction confirmed; newer device work preserved for another review.',
          before: evidence,
          after: {
            'schemaVersion': 1,
            'kind': unchanged
                ? 'deviceReconciliation'
                : 'acceptedCorrectionWithNewerDraft',
            'localProjectionAdopted': unchanged,
            if (unchanged) 'adoptedNativeSnapshotJson': adopted.snapshot,
            if (!unchanged) 'preservedNativeSnapshotJson': adopted.snapshot,
            'remoteMutationPerformed':
                evidence['disposition'] == 'correctSelectedFields',
          },
        )
        ..timestamp = reviewedAt.toUtc()
        ..isSynced = false,
    );
    requireActor();
    return unchanged;
  }

  Future<void> keepServer({
    required MaintenanceCreationSuccessorReview review,
    required MaintenanceRecord server,
    required Map<String, dynamic> evidence,
    required String reviewerUid,
    required String reviewerName,
    required DateTime reviewedAt,
    required void Function() requireActor,
    required Future<void> Function() requireNoPendingCorrection,
  }) => isar.writeTxn(() async {
    await requireNoPendingCorrection();
    await adoptInTransaction(
      ticketId: review.ticketId,
      expectedSnapshot: review.localSnapshotJson,
      server: server,
      evidence: evidence,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      reviewedAt: reviewedAt,
      requireActor: requireActor,
    );
  });
}
