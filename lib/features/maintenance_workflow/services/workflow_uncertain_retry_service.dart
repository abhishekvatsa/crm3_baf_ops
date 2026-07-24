import 'dart:convert';

import '../data/workflow_command_record.dart';
import '../domain/workflow_command_contract.dart';
import '../domain/workflow_types.dart';
import '../repositories/workflow_repository.dart';
import 'workflow_online_executor.dart';

class WorkflowUncertainRetryService {
  final WorkflowRepository repository;
  final WorkflowOnlineExecutor executor;
  final DateTime Function() now;

  const WorkflowUncertainRetryService({
    required this.repository,
    required this.executor,
    required this.now,
  });

  Future<int> retryDueCommands() async {
    final rows = await repository.getRetryableCommands(now().toUtc());
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
        }
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
