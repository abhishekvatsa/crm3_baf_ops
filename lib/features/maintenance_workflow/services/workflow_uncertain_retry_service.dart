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
    var applied = 0;
    // Claim one command at a time, immediately before dispatching it. A whole
    // batch claimed up front and executed in sequence would leave the last
    // commands holding a lease that expires before anything tries to send
    // them, and another caller would then take work still nominally owned.
    final seen = <String>{};
    while (true) {
      final rows = await repository.claimRetryableCommands(
        now: now().toUtc(),
        lease: claimLease,
        limit: 1,
      );
      if (rows.isEmpty) break;
      final row = rows.single;
      // A released command keeps its due time, so it becomes claimable again
      // at once. Stopping at the first repeat leaves it for the next run
      // instead of spinning on it here.
      if (!seen.add(row.commandId)) {
        await repository.releaseClaim(
          row.commandId,
          claimedAt: row.lastAttemptAt!,
        );
        break;
      }
      final claimedAt = row.lastAttemptAt!;
      // Decoding is separated from execution. Catching both together treated a
      // StateError raised anywhere inside the send as evidence that the stored
      // payload was malformed, which it is not.
      final WorkflowCommand command;
      try {
        command = _command(row);
      } catch (error) {
        // Replaying intent that cannot be read is unsafe, so this is terminal.
        // It still goes through the receipt-aware transition: if the command
        // was accepted in the meantime, it must not be resurrected as
        // outstanding work needing review.
        await repository.applyRetryTransitionUnlessAccepted(
          commandId: row.commandId,
          build: (current) {
            final target = current ?? row;
            return target
              ..stateKey = 'manualReview'
              ..nextRetryAt = null
              ..lastErrorCode = 'malformedLocalCommand'
              ..lastErrorMessage = error.toString();
          },
        );
        continue;
      }
      try {
        await executor.execute(command);
        applied += 1;
      } catch (error) {
        // Anything else left no verdict. Hand the claim back now rather than
        // making the operator wait out the lease; the release is ignored if
        // the executor already settled the row or another caller has since
        // taken it, so neither a recorded outcome nor a newer claim is
        // disturbed.
        await repository.releaseClaim(row.commandId, claimedAt: claimedAt);
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
