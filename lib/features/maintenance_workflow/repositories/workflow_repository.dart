import '../data/compliance_attempt_record.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_prompt_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_command_receipt_record.dart';
import '../data/workflow_command_record.dart';
import '../data/workflow_event_record.dart';

/// Why a retry transition did or did not happen.
enum WorkflowRetryTransitionOutcome {
  /// The transition was applied.
  recorded,

  /// Nothing was written, because the row's current state made the
  /// transition inapplicable. Distinct from [recorded] so a caller cannot
  /// describe work as held when no hold was made.
  noChange,

  /// The server had already accepted the command, so no retry state was
  /// written. The accepted result stands.
  alreadyAccepted,
}

class WorkflowRetryTransition {
  const WorkflowRetryTransition(this.outcome, {this.receipt});

  final WorkflowRetryTransitionOutcome outcome;
  final WorkflowCommandReceiptRecord? receipt;

  bool get wasAlreadyAccepted =>
      outcome == WorkflowRetryTransitionOutcome.alreadyAccepted;

  bool get wasRecorded => outcome == WorkflowRetryTransitionOutcome.recorded;
}

abstract interface class WorkflowRepository {
  Stream<WorkflowAggregateRecord?> watchWorkflow(String workflowId);
  Stream<List<JobLaneRecord>> watchLanes(String workflowId);
  Stream<List<JobLaneRecord>> watchLanesByLane(String laneKey);
  Stream<List<JobLaneRecord>> watchAllLanes();
  Stream<List<ComplianceRequestRecord>> watchCompliance(String workflowId);
  Stream<List<WorkflowEventRecord>> watchEvents(String workflowId);
  Stream<List<ComplianceRequestRecord>> watchComplianceInbox(String laneKey);
  Stream<List<ComplianceRequestRecord>> watchAllCompliance();
  Stream<List<EquipmentStatusRecord>> watchEquipmentByState(String? stateKey);

  Future<WorkflowAggregateRecord?> getWorkflow(String workflowId);
  Future<List<JobLaneRecord>> getLanes(String workflowId);
  Future<List<ComplianceRequestRecord>> getCompliance(String workflowId);
  Future<ComplianceRequestRecord?> getComplianceById(String complianceId);
  Future<EquipmentStatusRecord?> getEquipment(
    String assetTypeKey,
    int assetNumber, {
    String? assetClassId,
    String? assetInstanceId,
  });

  Future<void> upsertWorkflowFromRemote(WorkflowAggregateRecord record);
  Future<void> upsertLaneFromRemote(JobLaneRecord record);
  Future<void> upsertComplianceFromRemote(ComplianceRequestRecord record);
  Future<void> upsertComplianceAttemptFromRemote(
    ComplianceAttemptRecord record,
  );
  Future<void> upsertEquipmentFromRemote(EquipmentStatusRecord record);
  Future<void> upsertPromptFromRemote(EquipmentPromptRecord record);
  Future<void> upsertEventFromRemote(WorkflowEventRecord record);
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record);

  /// The stored receipt for a command, if the server has already accepted it.
  ///
  /// A receipt is authoritative evidence that the command was applied. It
  /// outranks a transport failure arriving later from an older attempt.
  Future<WorkflowCommandReceiptRecord?> getReceipt(String commandId);

  /// Stores an accepted receipt and clears its retry state together.
  ///
  /// Saving the receipt and removing the retry row separately leaves a window
  /// in which acceptance is recorded while the command still looks unresolved,
  /// and a concurrent failure handler can act on that half state.
  Future<void> settleAccepted(WorkflowCommandReceiptRecord receipt);

  /// Applies a retry transition unless the command has already been accepted.
  ///
  /// The receipt read, the current-row read and the write share one
  /// transaction. Checking for a receipt and writing afterwards leaves the
  /// interleaving this exists to prevent: the check finds nothing, another
  /// caller then records acceptance and clears the row, and the late write
  /// recreates uncertainty for work that was already applied.
  ///
  /// [build] receives the row as it exists inside the transaction and returns
  /// the row to store, or null to write nothing. It must not perform I/O.
  Future<WorkflowRetryTransition> applyRetryTransitionUnlessAccepted({
    required String commandId,
    required WorkflowCommandRecord? Function(WorkflowCommandRecord? current)
    build,
  });

  Future<void> saveRetryCommand(WorkflowCommandRecord record);
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId);
  Future<List<WorkflowCommandRecord>> getRetryableCommands(DateTime now);

  /// Takes exclusive ownership of the commands due for replay.
  ///
  /// [getRetryableCommands] answers "what is due" and hands the same rows to
  /// every caller. That is safe while one engine runs in one process, and
  /// stops being safe the moment a second execution context exists: both would
  /// read the same row and replay it.
  ///
  /// The claim moves each row to `sending` inside the same write transaction
  /// that selected it, so a concurrent caller sees no eligible rows rather
  /// than a duplicate set. A row already claimed is only re-offered once its
  /// lease has expired, so a caller that died mid-send cannot strand the
  /// command forever.
  /// [limit] bounds how many are taken at once. A large batch executed
  /// sequentially would let the last commands sit claimed until their lease
  /// expired before anything tried to send them, and another caller would then
  /// take work still nominally owned.
  Future<List<WorkflowCommandRecord>> claimRetryableCommands({
    required DateTime now,
    required Duration lease,
    int limit,
  });

  /// Returns a claimed command to the retry queue without counting an attempt.
  ///
  /// Used when the caller stops before deciding an outcome - the process is
  /// shutting down, or the network was withdrawn again. Abandoning the claim
  /// is not a failed attempt and must not consume the retry budget.
  /// [claimedAt] is the claim being released, and acts as a fencing token.
  ///
  /// Without it a caller whose lease expired could return from a slow send and
  /// release a claim another caller has since taken, handing the command to a
  /// third caller while the second is still working it. Only the holder of the
  /// current claim may release it.
  Future<void> releaseClaim(
    String commandId, {
    required DateTime claimedAt,
    DateTime? nextRetryAt,
  });
  Future<List<WorkflowCommandRecord>> getPendingCommands();
  Future<void> deleteRetryCommand(String commandId);
}
