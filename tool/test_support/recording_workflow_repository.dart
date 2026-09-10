import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';

/// Records what the executor decided to persist.
///
/// The behaviour under test is which row the executor writes and what it
/// leaves alone, so the fake keeps every save rather than collapsing them.
class RecordingWorkflowRepository implements WorkflowRepository {
  RecordingWorkflowRepository({
    WorkflowCommandRecord? existing,
    WorkflowCommandReceiptRecord? acceptedReceipt,
  }) : _existing = existing,
       _receipt = acceptedReceipt;

  WorkflowCommandRecord? _existing;
  WorkflowCommandReceiptRecord? _receipt;

  final List<WorkflowCommandRecord> saved = <WorkflowCommandRecord>[];
  final List<String> deleted = <String>[];
  final List<WorkflowCommandReceiptRecord> receipts =
      <WorkflowCommandReceiptRecord>[];

  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) async {
    if (_existing?.commandId == commandId) return _existing;
    return null;
  }

  @override
  Future<void> saveRetryCommand(WorkflowCommandRecord record) async {
    saved.add(record);
    _existing = record;
  }

  @override
  Future<void> deleteRetryCommand(String commandId) async {
    deleted.add(commandId);
    if (_existing?.commandId == commandId) _existing = null;
  }

  @override
  Future<void> saveReceipt(WorkflowCommandReceiptRecord record) async {
    receipts.add(record);
    _receipt = record;
  }

  @override
  Future<WorkflowCommandReceiptRecord?> getReceipt(String commandId) async {
    if (_receipt?.commandId == commandId) return _receipt;
    return null;
  }

  @override
  Future<void> settleAccepted(WorkflowCommandReceiptRecord receipt) async {
    receipts.add(receipt);
    _receipt = receipt;
    if (_existing?.commandId == receipt.commandId) {
      deleted.add(receipt.commandId);
      _existing = null;
    }
  }

  /// Runs immediately before the guarded transition reads its evidence.
  ///
  /// The race being covered is another caller committing acceptance between
  /// the receipt check and the retry write. A real transaction closes that
  /// window; this hook lets a test open it deliberately and prove the
  /// transition still refuses to write.
  Future<void> Function()? beforeTransition;

  @override
  Future<WorkflowRetryTransition> applyRetryTransitionUnlessAccepted({
    required String commandId,
    required WorkflowCommandRecord? Function(WorkflowCommandRecord? current)
    build,
  }) async {
    await beforeTransition?.call();
    if (_receipt?.commandId == commandId) {
      return WorkflowRetryTransition(
        WorkflowRetryTransitionOutcome.alreadyAccepted,
        receipt: _receipt,
      );
    }
    final current = _existing?.commandId == commandId ? _existing : null;
    final next = build(current);
    if (next == null) {
      // Mirrors the production repository: writing nothing is not a recorded
      // transition, or a caller can describe work as held when no hold was
      // made.
      return const WorkflowRetryTransition(
        WorkflowRetryTransitionOutcome.noChange,
      );
    }
    saved.add(next);
    _existing = next;
    return const WorkflowRetryTransition(
      WorkflowRetryTransitionOutcome.recorded,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
