import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/workflow_command_receipt_record.dart';
import '../data/workflow_command_record.dart';
import '../domain/workflow_command_contract.dart';
import '../domain/workflow_error.dart';
import '../repositories/workflow_repository.dart';
import 'workflow_command_gateway.dart';
import 'workflow_outbox_policy.dart';

/// Executes lifecycle commands online. A local row is retained only when the
/// request may have reached the server but its receipt was lost.
class WorkflowOnlineExecutor {
  final Connectivity connectivity;
  final WorkflowCommandGateway gateway;
  final WorkflowRepository repository;
  final WorkflowRetryPolicy retryPolicy;
  final DateTime Function() now;

  const WorkflowOnlineExecutor({
    required this.connectivity,
    required this.gateway,
    required this.repository,
    this.retryPolicy = const WorkflowRetryPolicy(),
    required this.now,
  });

  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult.every((value) => value == ConnectivityResult.none)) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Workflow lifecycle actions require an online connection.',
      );
    }

    try {
      final receipt = await gateway.execute(command);
      await _saveReceipt(command, receipt);
      await repository.deleteRetryCommand(command.commandId);
      return receipt;
    } on WorkflowException catch (error) {
      await _recordFailure(command, error);
      rethrow;
    }
  }

  Future<void> _recordFailure(
    WorkflowCommand command,
    WorkflowException error,
  ) async {
    final existing = await repository.getRetryCommand(command.commandId);
    final disposition = retryPolicy.classify(error);
    if (existing == null && disposition != WorkflowRetryDisposition.retryUncertain) {
      return;
    }

    final attemptedAt = now().toUtc();
    final attempts = (existing?.attemptCount ?? 0) + 1;
    final terminal = disposition == WorkflowRetryDisposition.reject ||
        disposition == WorkflowRetryDisposition.manualReview ||
        attempts >= WorkflowRetryPolicy.maxAutomaticAttempts;
    final state = terminal
        ? (disposition == WorkflowRetryDisposition.reject ? 'rejected' : 'manualReview')
        : 'uncertainOutcome';

    await repository.saveRetryCommand(
      WorkflowCommandRecord()
        ..commandId = command.commandId
        ..aggregateId = command.aggregateId
        ..commandTypeKey = command.type.name
        ..expectedVersion = command.expectedVersion
        ..payloadJson = jsonEncode(command.payload)
        ..stateKey = state
        ..attemptCount = attempts
        ..createdLocallyAt = existing?.createdLocallyAt ?? attemptedAt
        ..lastAttemptAt = attemptedAt
        ..nextRetryAt = terminal
            ? null
            : attemptedAt.add(retryPolicy.delayForAttempt(attempts))
        ..lastErrorCode = error.code.name
        ..lastErrorMessage = error.message,
    );
  }

  Future<void> _saveReceipt(
    WorkflowCommand command,
    WorkflowCommandReceipt receipt,
  ) async {
    await repository.saveReceipt(
      WorkflowCommandReceiptRecord()
        ..commandId = receipt.commandId
        ..aggregateId = command.aggregateId
        ..resultKey = receipt.resultKey
        ..aggregateVersion = receipt.aggregateVersion
        ..resultJson = jsonEncode(receipt.result)
        ..appliedAt = receipt.appliedAt,
    );
  }
}
