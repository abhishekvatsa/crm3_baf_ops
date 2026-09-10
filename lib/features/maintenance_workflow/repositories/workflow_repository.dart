import '../data/compliance_attempt_record.dart';
import '../data/compliance_request_record.dart';
import '../data/equipment_prompt_record.dart';
import '../data/equipment_status_record.dart';
import '../data/job_lane_record.dart';
import '../data/workflow_aggregate_record.dart';
import '../data/workflow_command_receipt_record.dart';
import '../data/workflow_command_record.dart';
import '../data/workflow_event_record.dart';

/// A count of the command journal by outcome, for deciding what to show.
class WorkflowOutcomeInventory {
  const WorkflowOutcomeInventory({
    this.retrying = 0,
    this.sending = 0,
    this.rejected = 0,
    this.manualReview = 0,
  });

  /// Eligible for automatic retry: it will progress on its own.
  final int retrying;

  /// Claimed and in flight.
  final int sending;

  /// Terminal. The server refused it and a person must decide what happens.
  final int rejected;

  /// Terminal for automatic purposes: it needs a person.
  final int manualReview;

  /// Work that will not move without someone acting.
  int get needingAction => rejected + manualReview;

  bool get isQuiet => retrying == 0 && sending == 0 && needingAction == 0;
}

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
  /// [exclude] holds commands a caller has already handled in this run. A
  /// released command keeps its due time, so without this the oldest one is
  /// handed back immediately and the run makes no further progress - a single
  /// unresolvable command would stop every other command behind it.
  Future<List<WorkflowCommandRecord>> claimRetryableCommands({
    required DateTime now,
    required Duration lease,
    int limit,
    Set<String> exclude,
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

  /// What the command journal currently holds, by outcome.
  ///
  /// Deliberately separate from [getPendingCommands], which excludes rejected
  /// rows because they are not retryable. That exclusion is right for
  /// claiming and wrong for attention: a rejection is precisely the thing a
  /// person still has to deal with, and reusing that query let the warning
  /// clear on the next quiet run while the rejected row was still there.
  Future<WorkflowOutcomeInventory> readOutcomeInventory();
  Future<void> deleteRetryCommand(String commandId);
}

/// The operator-facing description of outstanding submitted work, or null when
/// there is nothing to say.
///
/// Pure so the two-run behaviour can be exercised directly: the defect this
/// replaces was that attention cleared on a quiet second run, and a test that
/// only checked a value survives `copyWith` could never have shown it.
///
/// [inventory] is null when the journal could not be read. That is reported as
/// unverified rather than as nothing outstanding: an unread journal establishes
/// no absence.
String? describeWorkflowAttention(WorkflowOutcomeInventory? inventory) {
  if (inventory == null) {
    return 'Submitted work could not be checked against local records.';
  }
  if (inventory.needingAction == 0) return null;
  final parts = <String>[
    if (inventory.rejected > 0) '${inventory.rejected} rejected',
    if (inventory.manualReview > 0) '${inventory.manualReview} need review',
  ];
  // Retrying work is deliberately excluded: it progresses on its own and
  // calling it "action needed" would train operators to ignore the warning.
  return 'Submitted work needs attention: ${parts.join(', ')}';
}
