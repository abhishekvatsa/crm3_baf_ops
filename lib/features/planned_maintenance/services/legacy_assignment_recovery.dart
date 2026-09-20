import '../../../core/persistence/durable_submission.dart';
import '../../maintenance_workflow/data/workflow_command_record.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';

final _activeAdmissions = <String>{};

/// Serialize new-screen admission until its original request reaches the journal.
/// Once released, the durable row, rather than this process lock, owns recovery.
void Function() claimLegacyAssignmentAdmission(
  String actorUid,
  String templateId,
) {
  final key = '$actorUid\u0000$templateId';
  if (!_activeAdmissions.add(key)) {
    throw StateError(
      'Another screen is already checking this assignment. Wait for that result.',
    );
  }
  var released = false;
  return () {
    if (!released) {
      released = true;
      _activeAdmissions.remove(key);
    }
  };
}

/// Reopening a screen must not create a second identity for an uncertain send.
/// Unknown-origin evidence blocks admission; it is never assigned today's user.
WorkflowCommand? retainedLegacyAssignment(
  List<WorkflowCommandRecord> rows, {
  required String actorUid,
  required String templateId,
}) {
  final candidates = <WorkflowCommand>[];
  for (final row in rows) {
    if (row.commandTypeKey !=
            WorkflowCommandType.createLegacyWorkflowJob.name ||
        row.stateKey == 'applied' ||
        row.stateKey == 'rejected') {
      continue;
    }
    final envelope = durableSubmissionJsonObject(row.payloadJson);
    final origin = envelope['__workflowOriginBoundV1'];
    if (origin is! String ||
        origin.isEmpty ||
        origin.trim() != origin ||
        envelope.length != 2 ||
        envelope['payload'] is! Map<String, dynamic>) {
      throw StateError(
        'An earlier assignment has unreadable account evidence. Ask Admin/SI to review saved workflow requests before assigning new work.',
      );
    }
    if (origin != actorUid) continue;
    final payload = envelope['payload'] as Map<String, dynamic>;
    if (payload['templateFirestoreId'] is! String ||
        (payload['templateFirestoreId'] as String).trim().isEmpty) {
      throw StateError(
        'The saved assignment has no readable template identity. Ask Admin/SI to review it before assigning new work.',
      );
    }
    if (payload['templateFirestoreId'] != templateId) continue;
    if (payload['executionId'] != row.aggregateId || row.expectedVersion != 0) {
      throw StateError(
        'The saved assignment identity needs Admin/SI review. It has been preserved.',
      );
    }
    candidates.add(
      WorkflowCommand(
        commandId: row.commandId,
        type: WorkflowCommandType.createLegacyWorkflowJob,
        aggregateId: row.aggregateId,
        expectedVersion: row.expectedVersion,
        payload: payload,
      ),
    );
  }
  if (candidates.length > 1) {
    throw StateError(
      'Several earlier assignments need review. Check the saved workflow requests before starting another assignment.',
    );
  }
  return candidates.firstOrNull;
}
