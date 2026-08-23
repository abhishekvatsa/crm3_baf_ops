import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

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
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;

  const WorkflowOnlineExecutor({
    required this.connectivity,
    required this.gateway,
    required this.repository,
    this.retryPolicy = const WorkflowRetryPolicy(),
    required this.now,
    this.checkConnectivity,
  });

  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    final connectivityResult =
        await (checkConnectivity?.call() ?? connectivity.checkConnectivity());
    if (connectivityResult.every((value) => value == ConnectivityResult.none)) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Workflow lifecycle actions require an online connection.',
      );
    }

    try {
      final receipt = await gateway.execute(command);
      var receiptSaved = false;
      try {
        await _saveReceipt(command, receipt);
        receiptSaved = true;
      } catch (error, stackTrace) {
        debugPrint(
          'Workflow command ${command.commandId} was accepted, but its local '
          'receipt could not be saved: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (receiptSaved) {
        try {
          await repository.deleteRetryCommand(command.commandId);
        } catch (error, stackTrace) {
          debugPrint(
            'Workflow command ${command.commandId} was accepted, but its stale '
            'local retry row could not be removed: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      return receipt;
    } on WorkflowException catch (error) {
      try {
        await _recordFailure(command, error);
      } catch (recordError, stackTrace) {
        debugPrint(
          'Workflow command ${command.commandId} failed and its local retry '
          'diagnostic could not be saved: $recordError',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  Future<void> _recordFailure(
    WorkflowCommand command,
    WorkflowException error,
  ) async {
    final existing = await repository.getRetryCommand(command.commandId);
    final disposition = retryPolicy.classify(error);
    if (existing == null &&
        disposition != WorkflowRetryDisposition.retryUncertain) {
      return;
    }

    final attemptedAt = now().toUtc();
    final attempts = (existing?.attemptCount ?? 0) + 1;
    final terminal =
        disposition == WorkflowRetryDisposition.reject ||
        disposition == WorkflowRetryDisposition.manualReview ||
        attempts >= WorkflowRetryPolicy.maxAutomaticAttempts;
    final state =
        terminal
            ? (disposition == WorkflowRetryDisposition.reject
                ? 'rejected'
                : 'manualReview')
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
        ..nextRetryAt =
            terminal
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
