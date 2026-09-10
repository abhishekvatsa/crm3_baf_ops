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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
