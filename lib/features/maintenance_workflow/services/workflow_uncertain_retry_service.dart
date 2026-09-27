import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/services/sync_run_guard.dart';
import '../data/workflow_command_record.dart';
import '../domain/workflow_command_contract.dart';
import '../domain/workflow_error.dart';
import '../domain/workflow_types.dart';
import '../repositories/workflow_repository.dart';
import 'workflow_online_executor.dart';
import 'workflow_retry_claim_guard.dart';

/// What one retry run actually did.
///
/// The run used to return only a count of applied commands and swallow every
/// error, so a damaged receipt or a fault inside the send was indistinguishable
/// from an empty queue. A background caller relying on that result would have
/// had no way to tell the difference either.
class WorkflowRetryRunSummary {
  const WorkflowRetryRunSummary({
    this.applied = const <String>[],
    this.deferred = const <String>[],
    this.rejected = const <String>[],
    this.manualReview = const <String>[],
    this.failedVerification = const <String>[],
  });

  /// Accepted by the server on this run.
  final List<String> applied;

  /// Attempted, left without a verdict, and still eligible to retry.
  final List<String> deferred;

  /// Terminal: the server refused the command. It will not be retried, and the
  /// reason belongs in front of a person.
  final List<String> rejected;

  /// Terminal: the stored intent could not be read, so it was preserved for a
  /// person rather than replayed.
  final List<String> manualReview;

  /// Neither applied nor an ordinary transport outcome - evidence about the
  /// command could not be verified. These need looking at, not retrying.
  final List<String> failedVerification;

  int get attempted =>
      applied.length +
      deferred.length +
      rejected.length +
      manualReview.length +
      failedVerification.length;

  /// Work that will not progress on its own.
  bool get needsAttention =>
      rejected.isNotEmpty ||
      manualReview.isNotEmpty ||
      failedVerification.isNotEmpty;

  /// A one-line description for diagnostics, or null when the run was quiet.
  String? get summaryLine {
    if (attempted == 0) return null;
    final parts = <String>[
      if (applied.isNotEmpty) '${applied.length} applied',
      if (deferred.isNotEmpty) '${deferred.length} still retrying',
      if (rejected.isNotEmpty) '${rejected.length} rejected',
      if (manualReview.isNotEmpty) '${manualReview.length} need review',
      if (failedVerification.isNotEmpty)
        '${failedVerification.length} unverifiable',
    ];
    return parts.join(', ');
  }
}

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

  Future<WorkflowRetryRunSummary> retryDueCommands({
    SyncRunGuard? runGuard,
  }) async {
    final applied = <String>[];
    final deferred = <String>[];
    final rejected = <String>[];
    final manualReview = <String>[];
    final failedVerification = <String>[];

    // Claim one command at a time, immediately before dispatching it. A whole
    // batch claimed up front and executed in sequence would leave the last
    // commands holding a lease that expires before anything tries to send
    // them, and another caller would then take work still nominally owned.
    final handled = <String>{};
    while (true) {
      runGuard?.checkCurrent();
      final rows = await repository.claimRetryableCommands(
        now: now().toUtc(),
        lease: claimLease,
        limit: 1,
        // A released command keeps its due time. Excluding what this run has
        // already handled is what stops one unresolvable command being handed
        // back forever while every command behind it goes unattempted.
        exclude: handled,
      );
      if (rows.isEmpty) {
        runGuard?.checkCurrent();
        break;
      }
      final row = rows.single;
      handled.add(row.commandId);
      final claimedAt = row.lastAttemptAt!;

      try {
        runGuard?.checkCurrent();

        // Decoding is separated from execution. Catching both together treated a
        // StateError raised anywhere inside the send as evidence that the stored
        // payload was malformed, which it is not.
        final WorkflowCommand command;
        try {
          command = _command(row);
        } catch (error) {
          _checkRun(runGuard, error);
          // Replaying intent that cannot be read is unsafe, so this is terminal.
          // It still goes through the receipt-aware transition: if the command
          // was accepted in the meantime, it must not be resurrected as
          // outstanding work needing review.
          final transition = await repository
              .applyRetryTransitionUnlessAccepted(
                commandId: row.commandId,
                build: (current) {
                  runGuard?.checkCurrent();
                  if (current == null ||
                      !mayRecordWorkflowAttemptOutcome(
                        currentState: current.stateKey,
                        currentClaimedAt: current.lastAttemptAt,
                        expectedClaimedAt: claimedAt,
                      )) {
                    return null;
                  }
                  return current
                    ..stateKey = 'manualReview'
                    ..nextRetryAt = null
                    ..lastErrorCode = 'malformedLocalCommand'
                    ..lastErrorMessage = error.toString();
                },
              );
          runGuard?.checkCurrent();
          if (transition.wasRecorded) {
            manualReview.add(row.commandId);
          } else if (!transition.wasAlreadyAccepted) {
            // Another claimant or disposition won. This caller made no write.
            // Do not misreport its malformed-payload decision as recorded.
            failedVerification.add(row.commandId);
          }
          continue;
        }

        try {
          runGuard?.checkCurrent();
          await executor.execute(command, claimedAt: claimedAt);
          runGuard?.checkCurrent();
          applied.add(row.commandId);
        } on WorkflowException catch (error) {
          _checkRun(runGuard, error);
          // The executor has already classified this failure and written the
          // resulting state. Authority changes can hold an origin-bound command
          // without spending its retry budget; they never establish acceptance
          // for the replacement account, even if its predecessor saved a receipt.
          final settled = await repository.getRetryCommand(row.commandId);
          runGuard?.checkCurrent();
          switch (settled?.stateKey) {
            case 'rejected':
              rejected.add(row.commandId);
            case 'manualReview':
              manualReview.add(row.commandId);
            case null:
              // The row is gone, which is consistent with the executor having
              // settled an accepted command - but absence is not a receipt.
              // Only a stored receipt establishes acceptance; without one this
              // stays unverified rather than being counted as applied.
              if (executor.originActorUid != null &&
                  (error.code == WorkflowErrorCode.permissionDenied ||
                      error.code == WorkflowErrorCode.unauthenticated)) {
                failedVerification.add(row.commandId);
              } else {
                final receipt = await repository.getReceipt(row.commandId);
                runGuard?.checkCurrent();
                if (receipt != null) {
                  applied.add(row.commandId);
                } else {
                  failedVerification.add(row.commandId);
                }
              }
            default:
              deferred.add(row.commandId);
          }
          // Hand the claim back so the next run can pick it up; the release is
          // ignored if the row was settled or another caller has since taken it.
          runGuard?.checkCurrent();
          await repository.releaseClaim(
            row.commandId,
            claimedAt: claimedAt,
            nextRetryAt:
                executor.originActorUid != null &&
                    (error.code == WorkflowErrorCode.permissionDenied ||
                        error.code == WorkflowErrorCode.unauthenticated)
                ? now().toUtc().add(WorkflowOnlineExecutor.platformBlockHold)
                : null,
          );
          runGuard?.checkCurrent();
        } catch (error, stackTrace) {
          _checkRun(runGuard, error);
          // Anything else is not an ordinary transport outcome: a damaged stored
          // receipt, or a fault in the send itself. Reducing it to "nothing was
          // applied" hid it from the operator and from diagnostics entirely.
          failedVerification.add(row.commandId);
          debugPrint(
            'Workflow retry could not verify command ${row.commandId}: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
          runGuard?.checkCurrent();
          await repository.releaseClaim(row.commandId, claimedAt: claimedAt);
          runGuard?.checkCurrent();
        }
      } catch (_) {
        if (runGuard != null) {
          await _releaseAbortedClaim(row.commandId, claimedAt);
        }
        rethrow;
      }
    }

    runGuard?.checkCurrent();
    return WorkflowRetryRunSummary(
      applied: List<String>.unmodifiable(applied),
      deferred: List<String>.unmodifiable(deferred),
      rejected: List<String>.unmodifiable(rejected),
      manualReview: List<String>.unmodifiable(manualReview),
      failedVerification: List<String>.unmodifiable(failedVerification),
    );
  }

  void _checkRun(SyncRunGuard? runGuard, Object error) {
    if (runGuard == null) return;
    rethrowIfSyncRunMustAbort(error);
    runGuard.checkCurrent();
  }

  Future<void> _releaseAbortedClaim(
    String commandId,
    DateTime claimedAt,
  ) async {
    try {
      // Cleanup is allowed after the session ends, but only for this exact
      // lease. The atomic receipt check prevents restoring accepted work;
      // a newer claimant, terminal outcome, payload and retry budget survive.
      await repository.applyRetryTransitionUnlessAccepted(
        commandId: commandId,
        build: (current) {
          if (current == null ||
              current.stateKey != 'sending' ||
              current.lastAttemptAt?.toUtc() != claimedAt.toUtc()) {
            return null;
          }
          return current..stateKey = 'uncertainOutcome';
        },
      );
    } catch (error) {
      // An unavailable database can leave the lease to expire normally. Never
      // replace the whole-run abort with a best-effort cleanup failure.
      debugPrint('Workflow retry claim cleanup could not complete: $error');
    }
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
    final hasOrigin = decoded.containsKey('__workflowOriginBoundV1');
    final origin = decoded['__workflowOriginBoundV1'];
    if (hasOrigin &&
        (decoded.length != 2 ||
            origin is! String ||
            origin.isEmpty ||
            origin.trim() != origin ||
            decoded['payload'] is! Map)) {
      throw const FormatException(
        'Saved workflow origin wrapper is malformed.',
      );
    }
    final storedPayload = hasOrigin ? decoded['payload'] : decoded;
    if (storedPayload is! Map) {
      throw const FormatException('Workflow command payload is not a map.');
    }
    return WorkflowCommand(
      commandId: row.commandId,
      type: type,
      aggregateId: row.aggregateId,
      expectedVersion: row.expectedVersion,
      payload: Map<String, Object?>.from(storedPayload),
    );
  }
}
