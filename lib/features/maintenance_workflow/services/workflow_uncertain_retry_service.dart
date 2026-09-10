import 'dart:convert';

import '../data/workflow_command_record.dart';
import '../domain/workflow_command_contract.dart';
import '../domain/workflow_types.dart';
import '../repositories/workflow_repository.dart';
import 'workflow_online_executor.dart';

class WorkflowUncertainRetryService {
  /// How long a claimed command may stay claimed before another caller may
  /// take it over.
  ///
  /// Long enough that a slow callable is not stolen from a caller still
  /// waiting on it; short enough that a process killed mid-send does not
  /// strand the command for an operator who is waiting to hear whether their
  /// work was accepted.
  static const Duration claimLease = Duration(minutes: 5);

  final WorkflowRepository repository;
  final WorkflowOnlineExecutor executor;
  final DateTime Function() now;

  const WorkflowUncertainRetryService({
    required this.repository,
    required this.executor,
    required this.now,
  });

  Future<int> retryDueCommands() async {
    // Claim rather than read. Reading would hand the same rows to a second
    // execution context, and one physical action would be submitted twice.
    final rows = await repository.claimRetryableCommands(
      now: now().toUtc(),
      lease: claimLease,
    );
    var applied = 0;
    for (final row in rows) {
      try {
        final command = _command(row);
        await executor.execute(command);
        applied += 1;
      } catch (error) {
        // WorkflowOnlineExecutor records typed server failures. Decode failures
        // are terminal because replaying malformed local intent is unsafe.
        if (error is FormatException || error is StateError || error is TypeError) {
          row
            ..stateKey = 'manualReview'
            ..nextRetryAt = null
            ..lastErrorCode = 'malformedLocalCommand'
            ..lastErrorMessage = error.toString();
          await repository.saveRetryCommand(row);
          continue;
        }
        // Anything else left no verdict. Hand the claim back now rather than
        // making the operator wait out the lease; the release is ignored if
        // the executor already settled the row, so a recorded outcome is
        // never reopened.
        await repository.releaseClaim(row.commandId);
      }
    }
    return applied;
  }

  WorkflowCommand _command(WorkflowCommandRecord row) {
    final type = WorkflowCommandType.values.firstWhere(
      (value) => value.name == row.commandTypeKey,
      orElse: () => throw FormatException(
        'Unknown workflow command type ${row.commandTypeKey}.',
      ),
    );
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Workflow command payload is not a map.');
    }
    return WorkflowCommand(
      commandId: row.commandId,
      type: type,
      aggregateId: row.aggregateId,
      expectedVersion: row.expectedVersion,
      payload: Map<String, Object?>.from(decoded),
    );
  }
}
