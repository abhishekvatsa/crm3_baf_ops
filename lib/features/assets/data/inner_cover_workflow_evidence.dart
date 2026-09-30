import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance_workflow/repositories/firestore_workflow_read_repository.dart';
import '../../planned_maintenance/data/job_template_model.dart';

/// Read-only serial evidence omitted by the existing persisted workflow model.
/// This does not change that model, its Isar schema, or a workflow identity.
class InnerCoverWorkflowEvidence {
  const InnerCoverWorkflowEvidence._({
    required this.id,
    required this.executionId,
    required this.assetTypeKey,
    required this.workflowKind,
    required this.status,
    required this.cancelled,
    required this.activeRedWork,
    required this.awaitingPreparation,
    required this.position,
  });

  final String id;
  final String executionId;
  final String assetTypeKey;
  final String? workflowKind;
  final String status;
  final bool cancelled;
  final bool activeRedWork;
  final bool awaitingPreparation;
  final AssignmentInnerCoverPosition? position;

  bool get concernsInnerCover =>
      assetTypeKey == 'innerCover' && workflowKind != 'issueCoordination';
  bool get isTerminal => status == 'completed' || status == 'cancelled';

  factory InnerCoverWorkflowEvidence.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final core = workflowAggregateRecordFromFirestoreData(
      documentId: documentId,
      data: data,
    );
    final source = 'maintenance_workflows/$documentId';
    void invalid(String field, String detail) =>
        throw PersistedDataFormatException(
          field: field,
          source: source,
          detail: detail,
        );
    final relevant =
        core.assetTypeKey == 'innerCover' &&
        core.workflowKind != 'issueCoordination';
    final terminal =
        core.statusKey == 'completed' || core.statusKey == 'cancelled';
    AssignmentInnerCoverPosition? position;
    if (relevant) {
      if (core.workflowSchemaVersion != 1 || core.version < 1) {
        invalid('workflowSchemaVersion', 'unverified workflow revision');
      }
      for (final field in [
        'cancelled',
        'activeRedWork',
        'awaitingPreparation',
      ]) {
        readRequiredPersistedBool(data[field], field: field, source: source);
      }
      if (core.cancelled != (core.statusKey == 'cancelled') ||
          (terminal && (core.activeRedWork || core.awaitingPreparation)) ||
          (core.activeRedWork && core.awaitingPreparation)) {
        invalid('status', 'contradictory workflow contribution state');
      }
      // Terminal historical work need not acquire a fabricated serial identity.
      if (!terminal) {
        String text(String field) => readRequiredPersistedString(
          data[field],
          field: field,
          source: source,
        );
        position = AssignmentInnerCoverPosition(
          baseAssetInstanceId: text('assetInstanceId'),
          baseAssetClassId: text('assetClassId'),
          baseAssetNumber: core.assetNumber,
          innerCoverId: text('innerCoverId'),
          innerCoverSerialNumber: text('innerCoverSerialNumber'),
          linkageId: text('innerCoverLinkageId'),
          assignmentVersion: readRequiredPersistedInt(
            data['innerCoverAssignmentVersion'],
            field: 'innerCoverAssignmentVersion',
            source: source,
            minimum: 1,
          ),
        );
      }
    }
    return InnerCoverWorkflowEvidence._(
      id: documentId,
      executionId: core.jobExecutionFirestoreId,
      assetTypeKey: core.assetTypeKey,
      workflowKind: core.workflowKind,
      status: core.statusKey,
      cancelled: core.cancelled,
      activeRedWork: core.activeRedWork,
      awaitingPreparation: core.awaitingPreparation,
      position: position,
    );
  }
}
