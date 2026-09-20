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
import 'workflow_retry_claim_guard.dart';

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

class _DispatchOwnership {
  const _DispatchOwnership({this.originActorUid, this.claimedAt, this.receipt});

  final String? originActorUid;
  final DateTime? claimedAt;
  final WorkflowCommandReceiptRecord? receipt;
}

/// Executes lifecycle commands online. The production origin-bound path saves
/// the original request and claims it before the first network dispatch. Atomic
/// receipt settlement clears retry state; failed settlement retains the request
/// for recovery. This is not a receipt-only recovery or offline admission API.
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

  /// The account which created a command. Production wiring supplies this
  /// from the live auth session; keeping it in the local journal prevents a
  /// later retry from silently becoming another account's action.
  final String? Function()? originActorUid;

  const WorkflowOnlineExecutor({
    required this.connectivity,
    required this.gateway,
    required this.repository,
    this.retryPolicy = const WorkflowRetryPolicy(),
    required this.now,
    this.checkConnectivity,
    this.isNetworkBlocked,
    this.originActorUid,
  });

  /// How long a command waits while the platform is withholding the network.
  ///
  /// Short, because the block usually lifts the moment the app is opened.
  static const Duration platformBlockHold = Duration(minutes: 1);
  static const String _originPayloadKey = '__workflowOriginBoundV1';
  static const String _receiptEnvelopeKey = '__workflowAcceptedEnvelopeV1';

  Future<WorkflowCommandReceipt> execute(
    WorkflowCommand command, {
    DateTime? claimedAt,
    void Function(WorkflowCommandReceipt)? validateReceipt,
  }) async {
    WorkflowCommandReceipt checked(WorkflowCommandReceipt receipt) {
      validateReceipt?.call(receipt);
      return receipt;
    }
    // Capture both actor and nested input before any platform or store await.
    final capturedOrigin = _captureOrigin();
    if (capturedOrigin != null) {
      command = WorkflowCommand(
        commandId: command.commandId,
        type: command.type,
        aggregateId: command.aggregateId,
        expectedVersion: command.expectedVersion,
        payload: Map<String, Object?>.from(
          jsonDecode(jsonEncode(command.payload)) as Map,
        ),
      );
    }
    final connectivityResult =
        await (checkConnectivity?.call() ?? connectivity.checkConnectivity());
    _assertOrigin(capturedOrigin);
    if (connectivityResult.every((value) => value == ConnectivityResult.none)) {
      // "What happened to this submitted command?" is answerable offline; it
      // is only "may I send a new one?" that is not. Refusing to read a
      // result the device already holds would report an accepted action as
      // never sent.
      final evidence = await _acceptedOutcomeFor(command, capturedOrigin);
      _assertOrigin(capturedOrigin);
      final settled = evidence.receipt;
      if (settled != null) return checked(_receiptFrom(settled));
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
    final platformBlocked = await _platformIsWithholdingNetwork();
    _assertOrigin(capturedOrigin);
    if (platformBlocked) {
      // Asked before anything else, because a settled command has no retry row
      // by design: settlement removes it. Making the receipt check conditional
      // on a surviving row meant the ordinary successful state - accepted,
      // nothing outstanding - was reported as "not sent and has not been
      // queued".
      final evidence = await _acceptedOutcomeFor(command, capturedOrigin);
      _assertOrigin(capturedOrigin);
      final settled = evidence.receipt;
      if (settled != null) return checked(_receiptFrom(settled));

      final existing = await repository.getRetryCommand(command.commandId);
      _assertOrigin(capturedOrigin);
      if (capturedOrigin != null && existing != null) {
        _validateSavedCommand(existing, command, capturedOrigin);
      }
      final hold = existing == null
          ? null
          : await _holdWithoutAttempt(existing, claimedAt);
      // Acceptance landing during the hold is still acceptance.
      final acceptedDuringHold = hold?.receipt;
      if (hold != null &&
          hold.wasAlreadyAccepted &&
          acceptedDuringHold != null) {
        _validateAcceptedCommand(acceptedDuringHold, command, capturedOrigin);
        _assertOrigin(capturedOrigin);
        return checked(_receiptFrom(acceptedDuringHold));
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
            : existing?.stateKey == 'sending'
            ? 'Android has paused network access for this app. Another attempt '
                  'is already checking this request; no additional attempt was made.'
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

    // Admission failures must not rewrite another caller's claim, old bytes or
    // a terminal record. Only the admitted owner records an attempt outcome.
    final ownership = await _prepareDispatchOwnership(
      command,
      claimedAt,
      capturedOrigin,
    );
    if (ownership.receipt != null) {
      _assertOrigin(capturedOrigin);
      return checked(_receiptFrom(ownership.receipt!));
    }
    try {
      _assertOrigin(capturedOrigin);
      final receipt = await _dispatch(command, ownership.originActorUid);
      if (receipt.commandId != command.commandId) {
        throw const WorkflowException(
          WorkflowErrorCode.unavailable,
          'The command may have been accepted, but its receipt identity is invalid.',
        );
      }
      validateReceipt?.call(receipt);
      try {
        // Storing the receipt and clearing the retry row together means the
        // command is never both accepted and outstanding, which is the state
        // a concurrent failure handler would otherwise act on.
        await repository.settleAccepted(
          _receiptRecord(command, receipt, capturedOrigin),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Workflow command ${command.commandId} was accepted, but its local '
          'receipt and retry state could not be settled: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      _assertOrigin(capturedOrigin);
      return receipt;
    } on WorkflowException catch (error) {
      WorkflowRetryTransition? transition;
      try {
        transition = await _recordFailure(
          command,
          error,
          ownership.claimedAt,
          capturedOrigin,
        );
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
        _validateAcceptedCommand(accepted, command, capturedOrigin);
        _assertOrigin(capturedOrigin);
        return checked(_receiptFrom(accepted));
      }
      rethrow;
    } catch (_) {
      if (capturedOrigin != null) {
        await _recordFailure(
          command,
          const WorkflowException(
            WorkflowErrorCode.unavailable,
            'The submitted outcome could not be verified. Original evidence is retained.',
          ),
          ownership.claimedAt,
          capturedOrigin,
        );
      }
      rethrow;
    }
  }

  Future<_DispatchOwnership> _prepareDispatchOwnership(
    WorkflowCommand command,
    DateTime? claimedAt,
    String? liveOrigin,
  ) async {
    // Test and legacy gateways which do not provide an actor callback retain
    // the established V1 path. The production provider always supplies one,
    // so only that path needs the owner journal and legacy-row fence below.
    if (liveOrigin == null) {
      return _DispatchOwnership(claimedAt: claimedAt);
    }
    final attemptedAt = now().toUtc();
    WorkflowException? refusal;
    final transition = await repository.applyRetryTransitionUnlessAccepted(
      commandId: command.commandId,
      build: (existing) {
        _assertOrigin(liveOrigin);
        if (existing != null) {
          if (_originFromPayload(existing.payloadJson) == null &&
              mayRecordWorkflowAttemptOutcome(
                currentState: existing.stateKey,
                currentClaimedAt: existing.lastAttemptAt,
                expectedClaimedAt: claimedAt,
              )) {
            refusal = const WorkflowException(
              WorkflowErrorCode.failedPrecondition,
              'This saved workflow action has no verified original account and needs review.',
              details: {'reasonCode': 'workflow-legacy-origin-review-required'},
            );
            return existing
              ..stateKey = 'manualReview'
              ..nextRetryAt = null
              ..lastErrorCode = 'workflow-legacy-origin-review-required'
              ..lastErrorMessage = refusal!.message;
          }
          _validateSavedCommand(existing, command, liveOrigin);
          if (existing.stateKey == 'rejected' ||
              existing.stateKey == 'manualReview' ||
              existing.stateKey == 'applied' ||
              (claimedAt == null &&
                  (existing.stateKey == 'sending' ||
                      existing.nextRetryAt?.isAfter(attemptedAt) == true)) ||
              (claimedAt != null &&
                  (existing.stateKey != 'sending' ||
                      existing.lastAttemptAt?.toUtc() != claimedAt.toUtc()))) {
            throw const WorkflowException(
              WorkflowErrorCode.unavailable,
              'The saved command is held or already being checked. Its original evidence is unchanged.',
              details: {'reasonCode': 'workflow-command-not-dispatchable'},
            );
          }
          return existing
            ..stateKey = 'sending'
            ..lastAttemptAt = claimedAt ?? attemptedAt;
        }
        if (claimedAt != null) {
          throw const WorkflowException(
            WorkflowErrorCode.failedPrecondition,
            'The original retry claim is missing. Nothing was sent.',
          );
        }
        return WorkflowCommandRecord()
          ..commandId = command.commandId
          ..aggregateId = command.aggregateId
          ..commandTypeKey = command.type.name
          ..expectedVersion = command.expectedVersion
          ..payloadJson = _payloadJsonFor(command, liveOrigin)
          ..stateKey = 'sending'
          ..attemptCount = 0
          ..createdLocallyAt = attemptedAt
          ..lastAttemptAt = attemptedAt;
      },
    );
    if (refusal != null) throw refusal!;
    if (transition.wasAlreadyAccepted) {
      final receipt = transition.receipt!;
      _validateAcceptedCommand(receipt, command, liveOrigin);
      return _DispatchOwnership(originActorUid: liveOrigin, receipt: receipt);
    }
    return _DispatchOwnership(
      originActorUid: liveOrigin,
      claimedAt: claimedAt ?? attemptedAt,
    );
  }

  Future<WorkflowCommandReceipt> _dispatch(
    WorkflowCommand command,
    String? origin,
  ) {
    if (origin == null) return gateway.execute(command);
    if (gateway is! OriginBoundWorkflowCommandGateway) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'This workflow gateway cannot preserve the originating account.',
      );
    }
    final originBound = gateway as OriginBoundWorkflowCommandGateway;
    return originBound.executeOriginBoundEnvelope(
      jsonEncode(<String, Object?>{
        'protocolVersion': 2,
        'originActorUid': origin,
        'command': command.toMap(),
      }),
    );
  }

  String? _captureOrigin() {
    if (originActorUid == null) return null; // Explicit legacy/test adapter.
    final origin = originActorUid!();
    if (origin == null || origin.isEmpty || origin.trim() != origin) {
      throw const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Verify the original approved account before sending this workflow action.',
        details: {'reasonCode': 'workflow-origin-unavailable'},
      );
    }
    return origin;
  }

  void _assertOrigin(String? origin) {
    if (origin == null) return;
    if (originActorUid?.call() != origin) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that created this workflow action. Its evidence is retained.',
        details: {'reasonCode': 'workflow-origin-changed'},
      );
    }
  }

  void _validateSavedCommand(
    WorkflowCommandRecord row,
    WorkflowCommand command,
    String origin,
  ) {
    final savedOrigin = _originFromPayload(row.payloadJson);
    if (savedOrigin == null) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'This saved workflow action has no verified original account and needs review.',
        details: {'reasonCode': 'workflow-legacy-origin-review-required'},
      );
    }
    if (savedOrigin != origin) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that created this saved workflow action.',
        details: {'reasonCode': 'workflow-origin-changed'},
      );
    }
    if (row.commandId != command.commandId ||
        row.aggregateId != command.aggregateId ||
        row.commandTypeKey != command.type.name ||
        row.expectedVersion != command.expectedVersion ||
        row.payloadJson != _payloadJsonFor(command, origin)) {
      throw const WorkflowException(
        WorkflowErrorCode.idempotencyConflict,
        'This command identity already has different retained evidence. Nothing was replaced.',
        details: {'reasonCode': 'workflow-local-envelope-conflict'},
      );
    }
  }

  String _envelopeJson(WorkflowCommand command, String origin) => jsonEncode({
    'protocolVersion': 2,
    'originActorUid': origin,
    'command': command.toMap(),
  });

  void _validateAcceptedCommand(
    WorkflowCommandReceiptRecord receipt,
    WorkflowCommand command,
    String? origin,
  ) {
    if (receipt.commandId != command.commandId ||
        receipt.aggregateId != command.aggregateId) {
      throw const WorkflowException(
        WorkflowErrorCode.idempotencyConflict,
        'The stored acceptance belongs to a different workflow request.',
      );
    }
    if (origin == null) return;
    final decoded = jsonDecode(receipt.resultJson);
    if (decoded is! Map ||
        decoded.length != 2 ||
        decoded[_receiptEnvelopeKey] != _envelopeJson(command, origin) ||
        decoded['result'] is! Map) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The stored acceptance does not prove this exact request and original account. Preserve it for review.',
        details: {'reasonCode': 'workflow-local-acceptance-origin-unverified'},
      );
    }
  }

  String? _originFromPayload(String payloadJson) {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map ||
          decoded.length != 2 ||
          decoded[_originPayloadKey] is! String ||
          decoded['payload'] is! Map) {
        return null;
      }
      final origin = decoded[_originPayloadKey] as String;
      return origin.isEmpty || origin.trim() != origin ? null : origin;
    } catch (_) {
      return null;
    }
  }

  String _payloadJsonFor(WorkflowCommand command, String origin) => jsonEncode(
    <String, Object?>{_originPayloadKey: origin, 'payload': command.payload},
  );

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
    String? origin,
  ) async {
    try {
      final receipt = await repository.getReceipt(command.commandId);
      if (receipt == null) return const _LocalAcceptanceEvidence.absent();
      _validateAcceptedCommand(receipt, command, origin);
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
    DateTime? claimedAt,
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
        if (current == null ||
            !mayRecordWorkflowAttemptOutcome(
              currentState: current.stateKey,
              currentClaimedAt: current.lastAttemptAt,
              expectedClaimedAt: claimedAt,
            )) {
          return null;
        }
        return current
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
    DateTime? claimedAt,
    String? origin,
  ) {
    final classified = retryPolicy.classify(error);
    final authorityHeld =
        origin != null &&
        (error.code == WorkflowErrorCode.permissionDenied ||
            error.code == WorkflowErrorCode.unauthenticated);
    // A fresh refusal cannot settle a potentially delayed earlier invocation.
    // Keep that evidence qualified; do not relabel it as definite rejection.
    final disposition = origin == null
        ? classified
        : authorityHeld
        ? WorkflowRetryDisposition.retryUncertain
        : classified == WorkflowRetryDisposition.reject
        ? WorkflowRetryDisposition.manualReview
        : classified;
    return repository.applyRetryTransitionUnlessAccepted(
      commandId: command.commandId,
      build: (existing) {
        if (origin != null) {
          if (existing == null) return null;
          _validateSavedCommand(existing, command, origin);
        }
        if (!mayRecordWorkflowAttemptOutcome(
          currentState: existing?.stateKey,
          currentClaimedAt: existing?.lastAttemptAt,
          expectedClaimedAt: claimedAt,
        )) {
          return null;
        }
        if (existing == null &&
            disposition != WorkflowRetryDisposition.retryUncertain) {
          return null;
        }

        final attemptedAt = now().toUtc();
        // A temporary quota refusal is not another uncertain dispatch.
        // Preserve the request identity and automatic-attempt budget while
        // honoring the server's retry window.
        final quotaRefused = error.code == WorkflowErrorCode.resourceExhausted;
        final attempts =
            (existing?.attemptCount ?? 0) +
            (quotaRefused || authorityHeld ? 0 : 1);
        // Exempting quota refusals from the attempt budget has to be bounded
        // by something, or a server that keeps refusing defers the same
        // request indefinitely and it never reaches anyone who could act.
        final quotaExhausted =
            quotaRefused &&
            retryPolicy.quotaDeferralExhausted(
              firstAcceptedLocallyAt: existing?.createdLocallyAt ?? attemptedAt,
              now: attemptedAt,
            );
        final terminal =
            disposition == WorkflowRetryDisposition.reject ||
            disposition == WorkflowRetryDisposition.manualReview ||
            quotaExhausted ||
            (!quotaRefused &&
                !authorityHeld &&
                attempts >= WorkflowRetryPolicy.maxAutomaticAttempts);
        final state = terminal
            ? (disposition == WorkflowRetryDisposition.reject
                  ? 'rejected'
                  : 'manualReview')
            : 'uncertainOutcome';

        return WorkflowCommandRecord()
          ..commandId = command.commandId
          ..aggregateId = command.aggregateId
          ..commandTypeKey = command.type.name
          ..expectedVersion = command.expectedVersion
          ..payloadJson = existing?.payloadJson ?? jsonEncode(command.payload)
          ..stateKey = state
          ..attemptCount = attempts
          ..createdLocallyAt = existing?.createdLocallyAt ?? attemptedAt
          ..lastAttemptAt = attemptedAt
          ..nextRetryAt = terminal
              ? null
              : attemptedAt.add(
                  authorityHeld
                      ? platformBlockHold
                      : retryPolicy.delayForFailure(error, attempts),
                )
          ..lastErrorCode = error.code.name
          ..lastErrorMessage = error.message;
      },
    );
  }

  WorkflowCommandReceiptRecord _receiptRecord(
    WorkflowCommand command,
    WorkflowCommandReceipt receipt,
    String? origin,
  ) {
    return WorkflowCommandReceiptRecord()
      ..commandId = receipt.commandId
      ..aggregateId = command.aggregateId
      ..resultKey = receipt.resultKey
      ..aggregateVersion = receipt.aggregateVersion
      ..resultJson = jsonEncode(
        origin == null
            ? receipt.result
            : {
                _receiptEnvelopeKey: _envelopeJson(command, origin),
                'result': receipt.result,
              },
      )
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
    final decoded = jsonDecode(record.resultJson);
    final result = decoded is Map && decoded.containsKey(_receiptEnvelopeKey)
        ? decoded.length == 2 &&
                  decoded[_receiptEnvelopeKey] is String &&
                  decoded['result'] is Map
              ? decoded['result']
              : throw const FormatException(
                  'Malformed local workflow acceptance capsule.',
                )
        : decoded;
    return WorkflowCommandReceipt.fromMap(<String, dynamic>{
      'commandId': record.commandId,
      'resultKey': record.resultKey,
      'aggregateVersion': record.aggregateVersion,
      'result': result,
      'appliedAt': record.appliedAt.toUtc().toIso8601String(),
    });
  }
}
