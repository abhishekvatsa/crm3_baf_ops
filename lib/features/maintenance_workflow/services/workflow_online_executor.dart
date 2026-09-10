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

  /// Whether the platform is currently refusing this application's network
  /// access. Null, or a null answer, means the platform has said nothing and
  /// the ordinary failure path applies.
  final Future<bool?> Function()? isNetworkBlocked;

  const WorkflowOnlineExecutor({
    required this.connectivity,
    required this.gateway,
    required this.repository,
    this.retryPolicy = const WorkflowRetryPolicy(),
    required this.now,
    this.checkConnectivity,
    this.isNetworkBlocked,
  });

  /// How long a command waits while the platform is withholding the network.
  ///
  /// Short, because the block usually lifts the moment the app is opened.
  static const Duration platformBlockHold = Duration(minutes: 1);

  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    final connectivityResult =
        await (checkConnectivity?.call() ?? connectivity.checkConnectivity());
    if (connectivityResult.every((value) => value == ConnectivityResult.none)) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Workflow lifecycle actions require an online connection.',
      );
    }

    // A refused request is not evidence about the command. Attempting it would
    // spend one of eight attempts on a call the platform was never going to
    // let out, and eight of those retire the command to manual review inside
    // about half an hour - while the operator believes it is still trying.
    // Only a command already in the journal is held: a first submission still
    // fails in front of the person making it, because this app does not accept
    // lifecycle commands it cannot send.
    if (await _platformIsWithholdingNetwork()) {
      final existing = await repository.getRetryCommand(command.commandId);
      final held = existing != null && await _holdWithoutAttempt(existing);
      // The message must describe what actually happened to the work. Telling
      // someone their action is saved when nothing was queued is the same
      // class of fault as telling them a paused sync had failed.
      throw WorkflowException(
        WorkflowErrorCode.unavailable,
        held
            ? 'Android has paused network access for this app. This action is '
                'saved and will be sent when the app is opened.'
            : existing == null
            ? 'Android has paused network access for this app. This action was '
                'not sent and has not been queued. Open the app while '
                'connected and try again.'
            : 'Android has paused network access for this app. The earlier '
                'request is preserved but needs review before it is sent '
                'again.',
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

  Future<bool> _hasAcceptedReceipt(String commandId) async {
    try {
      return await repository.getReceipt(commandId) != null;
    } catch (_) {
      // An unreadable receipt store is not evidence of acceptance. Fall
      // through to the ordinary failure path rather than silently discarding
      // a real failure.
      return false;
    }
  }

  Future<bool> _platformIsWithholdingNetwork() async {
    final reader = isNetworkBlocked;
    if (reader == null) return false;
    try {
      return await reader() ?? false;
    } catch (_) {
      // An unreadable signal is not a block. Guessing would hold a command
      // that could have been sent.
      return false;
    }
  }

  /// Reschedules a retained command without spending an attempt.
  ///
  /// Returns whether the command is now waiting to be retried, so the caller
  /// can say so truthfully rather than assuming it.
  Future<bool> _holdWithoutAttempt(WorkflowCommandRecord record) async {
    if (record.stateKey == 'rejected' || record.stateKey == 'manualReview') {
      return false;
    }
    record
      ..stateKey = 'uncertainOutcome'
      ..nextRetryAt = now().toUtc().add(platformBlockHold)
      ..lastErrorCode = 'networkBlockedByPlatform'
      ..lastErrorMessage =
          'Android was withholding network access for this app, so no attempt '
          'was made.';
    await repository.saveRetryCommand(record);
    return true;
  }

  Future<void> _recordFailure(
    WorkflowCommand command,
    WorkflowException error,
  ) async {
    // A stored receipt means the server already accepted this command. A
    // transport failure arriving afterwards belongs to an attempt that lost
    // the race, and must not downgrade established acceptance: without this,
    // a caller whose claim expired could return late and recreate an
    // `uncertainOutcome` row for work another caller had already settled,
    // leaving an accepted command showing as unresolved and inviting replay.
    if (await _hasAcceptedReceipt(command.commandId)) return;

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
