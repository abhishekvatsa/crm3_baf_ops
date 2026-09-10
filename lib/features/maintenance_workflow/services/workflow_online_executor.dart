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
/// Local evidence about whether a submitted command was accepted.
class _LocalAcceptanceEvidence {
  const _LocalAcceptanceEvidence.accepted(this.receipt) : isUnavailable = false;
  const _LocalAcceptanceEvidence.absent()
    : receipt = null,
      isUnavailable = false;

  /// The store could not be read, so nothing was established either way.
  const _LocalAcceptanceEvidence.unavailable()
    : receipt = null,
      isUnavailable = true;

  final WorkflowCommandReceiptRecord? receipt;
  final bool isUnavailable;
}

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
      // "What happened to this submitted command?" is answerable offline; it
      // is only "may I send a new one?" that is not. Refusing to read a
      // result the device already holds would report an accepted action as
      // never sent.
      final evidence = await _acceptedOutcomeFor(command);
      final settled = evidence.receipt;
      if (settled != null) return _receiptFrom(settled);
      throw WorkflowException(
        WorkflowErrorCode.unavailable,
        evidence.isUnavailable
            // Saying it was not sent would assert something this device could
            // not check.
            ? 'Workflow lifecycle actions require an online connection, and '
                  'this action could not be checked against local records.'
            : 'Workflow lifecycle actions require an online connection.',
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
      // Asked before anything else, because a settled command has no retry row
      // by design: settlement removes it. Making the receipt check conditional
      // on a surviving row meant the ordinary successful state - accepted,
      // nothing outstanding - was reported as "not sent and has not been
      // queued".
      final evidence = await _acceptedOutcomeFor(command);
      final settled = evidence.receipt;
      if (settled != null) return _receiptFrom(settled);

      final existing = await repository.getRetryCommand(command.commandId);
      final hold =
          existing == null ? null : await _holdWithoutAttempt(existing);
      // Acceptance landing during the hold is still acceptance.
      final acceptedDuringHold = hold?.receipt;
      if (hold != null && hold.wasAlreadyAccepted && acceptedDuringHold != null) {
        return _receiptFrom(acceptedDuringHold);
      }
      final held = hold?.wasRecorded ?? false;
      // The message must describe what actually happened to the work. Telling
      // someone their action is saved when nothing was queued is the same
      // class of fault as telling them a paused sync had failed - and so is
      // saying it was never sent when the local record could not be read to
      // check. Unavailable evidence gets its own wording rather than
      // borrowing the absence one.
      throw WorkflowException(
        WorkflowErrorCode.unavailable,
        held
            ? 'Android has paused network access for this app. This action is '
                'saved and will be sent when the app is opened.'
            : existing != null
            ? 'Android has paused network access for this app. The earlier '
                'request is preserved but needs review before it is sent '
                'again.'
            : evidence.isUnavailable
            ? 'Android has paused network access for this app. No new attempt '
                'was made, and the previous outcome could not be checked '
                'against local records.'
            : 'Android has paused network access for this app. This action was '
                'not sent and has not been queued. Open the app while '
                'connected and try again.',
      );
    }

    try {
      final receipt = await gateway.execute(command);
      try {
        // Storing the receipt and clearing the retry row together means the
        // command is never both accepted and outstanding, which is the state
        // a concurrent failure handler would otherwise act on.
        await repository.settleAccepted(_receiptRecord(command, receipt));
      } catch (error, stackTrace) {
        debugPrint(
          'Workflow command ${command.commandId} was accepted, but its local '
          'receipt and retry state could not be settled: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return receipt;
    } on WorkflowException catch (error) {
      WorkflowRetryTransition? transition;
      try {
        transition = await _recordFailure(command, error);
      } catch (recordError, stackTrace) {
        debugPrint(
          'Workflow command ${command.commandId} failed and its local retry '
          'diagnostic could not be saved: $recordError',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      final accepted = transition?.receipt;
      if (accepted != null && transition!.wasAlreadyAccepted) {
        // Another attempt of this same command was accepted. Reporting the
        // transport failure would tell the operator their work did not land
        // when it did. Acceptance is authoritative; an outstanding projection
        // refresh is a different matter.
        //
        // Reconstruction sits outside the diagnostic catch on purpose. A
        // damaged stored receipt is an integrity problem about accepted work,
        // not a transport failure, and must not be reported as one.
        return _receiptFrom(accepted);
      }
      rethrow;
    }
  }

  /// What local evidence says about a submitted command.
  ///
  /// `null` is the answer to a question, not the absence of one: it means the
  /// store was read and held no receipt. A read that failed is a different
  /// state, and collapsing the two let an unreadable store produce the same
  /// "this action was not sent" message as verified absence.
  ///
  /// The stored acceptance for this exact submitted command, if any.
  ///
  /// A receipt is only honoured when it belongs to the same aggregate as the
  /// command being resolved. A command id is replayed deliberately during
  /// recovery, so matching on it alone would let a changed request inherit an
  /// unrelated outcome.
  Future<_LocalAcceptanceEvidence> _acceptedOutcomeFor(
    WorkflowCommand command,
  ) async {
    try {
      final receipt = await repository.getReceipt(command.commandId);
      if (receipt == null) return const _LocalAcceptanceEvidence.absent();
      return receipt.aggregateId == command.aggregateId
          ? _LocalAcceptanceEvidence.accepted(receipt)
          : const _LocalAcceptanceEvidence.absent();
    } catch (error, stackTrace) {
      // An unreadable receipt store is not evidence of acceptance, and not
      // evidence of its absence either. The ordinary path still runs, because
      // refusing to act would be worse, but the caller must not be told the
      // command was never sent on the strength of a read that failed.
      debugPrint(
        'Local acceptance evidence for ${command.commandId} could not be '
        'read: $error. Any outcome reported below is unverified against it.',
      );
      debugPrintStack(stackTrace: stackTrace);
      return const _LocalAcceptanceEvidence.unavailable();
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
  Future<WorkflowRetryTransition> _holdWithoutAttempt(
    WorkflowCommandRecord record,
  ) async {
    if (record.stateKey == 'rejected' || record.stateKey == 'manualReview') {
      return const WorkflowRetryTransition(
        WorkflowRetryTransitionOutcome.noChange,
      );
    }
    // The same guarded transition, so a hold cannot return accepted work to
    // "waiting" when acceptance lands first.
    final transition = await repository.applyRetryTransitionUnlessAccepted(
      commandId: record.commandId,
      build: (current) {
        final target = current ?? record;
        if (target.stateKey == 'rejected' ||
            target.stateKey == 'manualReview') {
          return null;
        }
        return target
          ..stateKey = 'uncertainOutcome'
          ..nextRetryAt = now().toUtc().add(platformBlockHold)
          ..lastErrorCode = 'networkBlockedByPlatform'
          ..lastErrorMessage =
              'Android was withholding network access for this app, so no '
              'attempt was made.';
      },
    );
    return transition;
  }

  /// Records the outcome of a failed attempt, unless the command was already
  /// accepted.
  ///
  /// The receipt read, the current-row read and the write share one
  /// transaction. Reading the receipt first and writing afterwards left the
  /// interleaving this exists to prevent: the read finds nothing, another
  /// caller records acceptance and clears the row, and this write then
  /// recreates uncertainty for work that was already applied.
  Future<WorkflowRetryTransition> _recordFailure(
    WorkflowCommand command,
    WorkflowException error,
  ) {
    final disposition = retryPolicy.classify(error);
    return repository.applyRetryTransitionUnlessAccepted(
      commandId: command.commandId,
      build: (existing) {
        if (existing == null &&
            disposition != WorkflowRetryDisposition.retryUncertain) {
          return null;
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

        return WorkflowCommandRecord()
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
          ..lastErrorMessage = error.message;
      },
    );
  }

  WorkflowCommandReceiptRecord _receiptRecord(
    WorkflowCommand command,
    WorkflowCommandReceipt receipt,
  ) {
    return WorkflowCommandReceiptRecord()
      ..commandId = receipt.commandId
      ..aggregateId = command.aggregateId
      ..resultKey = receipt.resultKey
      ..aggregateVersion = receipt.aggregateVersion
      ..resultJson = jsonEncode(receipt.result)
      ..appliedAt = receipt.appliedAt;
  }

  /// Rebuilds the accepted outcome from its stored receipt.
  ///
  /// The stored payload is decoded, not substituted. Callers validate this
  /// receipt against the command they issued: the maintenance issue and lane
  /// reconcilers read `ticketId`, `auditId`, `lane` and corrected-field
  /// evidence out of `result`, and the critical alarm, inspection and
  /// administrative closure callers read their own keys. Returning an empty
  /// map would make those validators reject an outcome the server had
  /// genuinely accepted, so the operator would be told an accepted action had
  /// failed - the exact fault this recovery path exists to prevent.
  ///
  /// Decoding goes through the same bounded reader the wire path uses, so a
  /// malformed stored payload raises a persisted-data error instead of
  /// silently becoming an empty result.
  WorkflowCommandReceipt _receiptFrom(WorkflowCommandReceiptRecord record) {
    return WorkflowCommandReceipt.fromMap(<String, dynamic>{
      'commandId': record.commandId,
      'resultKey': record.resultKey,
      'aggregateVersion': record.aggregateVersion,
      'result': record.resultJson,
      'appliedAt': record.appliedAt.toUtc().toIso8601String(),
    });
  }
}
