import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';
import '../domain/critical_alarm_models.dart';

class CriticalAlarmCommandService {
  const CriticalAlarmCommandService({
    required this.connectivity,
    required this.durableStore,
    required this.originBoundGateway,
    required this.currentActorUid,
    this.checkConnectivity,
    this.immediateReplayDelay = const Duration(milliseconds: 250),
  });

  final Connectivity connectivity;
  final DurableSubmissionRepository durableStore;
  final OriginBoundWorkflowCommandGateway originBoundGateway;
  final String Function() currentActorUid;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Duration immediateReplayDelay;

  String _originUid() {
    final originUid = currentActorUid().trim();
    if (originUid.isEmpty) {
      throw const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Sign in before recording a critical-safety command.',
        details: {'reasonCode': 'critical-alarm-origin-actor-missing'},
      );
    }
    return originUid;
  }

  void _assertOrigin(String? originUid) {
    if (_originUid() != originUid) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that saved this alarm command before continuing.',
        details: {'reasonCode': 'critical-alarm-origin-actor-mismatch'},
      );
    }
  }

  Future<List<DurableSubmission>> pending() async {
    final originUid = _originUid();
    final rows = await durableStore.listForActor(originUid);
    _assertOrigin(originUid);
    return _alarmRows(rows);
  }

  Stream<List<DurableSubmission>> watchPending() {
    final originUid = _originUid();
    return durableStore.watchForActor(originUid).map((rows) {
      _assertOrigin(originUid);
      return _alarmRows(rows);
    });
  }

  List<DurableSubmission> _alarmRows(List<DurableSubmission> rows) => rows
      .where((submission) => submission.protocol == 'criticalAlarm.v1')
      .toList(growable: false);

  Future<WorkflowCommandReceipt> resume(String submissionId) async {
    final saved = await durableStore.read(submissionId);
    if (saved == null || saved.protocol != 'criticalAlarm.v1') {
      throw const WorkflowException(
        WorkflowErrorCode.notFound,
        'The saved critical-safety command could not be found.',
        details: {'reasonCode': 'critical-alarm-saved-command-missing'},
      );
    }
    final originUid = _originUid();
    if (saved.actorUid != originUid) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that saved this alarm command before checking it.',
        details: {'reasonCode': 'critical-alarm-origin-actor-mismatch'},
      );
    }
    return _checkSaved(saved);
  }

  Future<WorkflowCommandReceipt> _execute(WorkflowCommand command) async {
    final originUid = _originUid();
    // Freeze the origin before any connectivity check or uncertain-outcome
    // wait. The native record is written before dispatch; a process ending at
    // this boundary therefore leaves a recoverable original command.
    final originBoundEnvelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': originUid,
      'command': command.toMap(),
    });
    final saved = await durableStore.prepare(
      DurableSubmissionDraft(
        submissionId: command.commandId,
        actorUid: originUid,
        requestId: command.commandId,
        aggregateId: command.aggregateId,
        resourceKey: 'criticalAlarm:${command.aggregateId}',
        protocol: 'criticalAlarm.v1',
        envelopeJson: originBoundEnvelope,
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'commandType': command.type.name,
        }),
      ),
    );
    return _checkSaved(saved);
  }

  Future<WorkflowCommandReceipt> _checkSaved(DurableSubmission saved) async {
    final originUid = _originUid();
    if (saved.actorUid != originUid) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that saved this alarm command before checking it.',
        details: {'reasonCode': 'critical-alarm-origin-actor-mismatch'},
      );
    }
    if (saved.state.isAccepted) return _storedReceipt(saved);
    final result =
        await (checkConnectivity?.call() ?? connectivity.checkConnectivity());
    _assertOrigin(originUid);
    if (result.every((entry) => entry == ConnectivityResult.none)) {
      throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'The alarm command is saved on this device, but cannot be sent until connectivity is available.',
        details: {'reasonCode': 'critical-alarm-saved-offline'},
      );
    }
    final claim = await durableStore.claim(
      submissionId: saved.submissionId,
      actorUid: originUid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _storedReceipt(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw WorkflowException(
        WorkflowErrorCode.unavailable,
        'The saved critical-safety command is not ready for another check. Its original request remains preserved.',
        details: {
          'reasonCode': 'critical-alarm-saved-command-not-dispatchable',
          'commandId': saved.requestId,
          'aggregateId': saved.aggregateId,
        },
      );
    }
    return _dispatchClaim(claim);
  }

  Future<WorkflowCommandReceipt> _dispatchClaim(
    DurableSubmissionClaim claim,
  ) async {
    final saved = claim.submission;
    try {
      _assertOrigin(saved.actorUid);
      final receipt = await _dispatch(saved.envelopeJson);
      return await _settle(saved, receipt);
    } on WorkflowException catch (error) {
      if (!_isUncertain(error)) {
        final outcome = await durableStore.recordOutcome(
          claim,
          // Auth, unknown and replay-evidence failures do not prove that an
          // earlier attempt was refused. Keep its exact request recoverable.
          state: saved.attemptCount == 1 && _isDefinitiveRefusal(error)
              ? DurableSubmissionState.rejected
              : DurableSubmissionState.uncertain,
          errorCode: error.code.name,
          message: error.message,
        );
        if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
          final accepted = await durableStore.read(saved.submissionId);
          if (accepted != null) return _storedReceipt(accepted);
        }
        rethrow;
      }
      if (immediateReplayDelay > Duration.zero) {
        await Future<void>.delayed(immediateReplayDelay);
      }
      try {
        _assertOrigin(saved.actorUid);
        final receipt = await _dispatch(saved.envelopeJson);
        return await _settle(saved, receipt);
      } on WorkflowException catch (replayError) {
        final outcome = await durableStore.recordOutcome(
          claim,
          // A refusal now cannot fence an earlier in-flight attempt. A mutable
          // catalogue condition may change again before that attempt arrives.
          state: DurableSubmissionState.uncertain,
          errorCode: 'critical-alarm-outcome-unconfirmed',
          message:
              'The critical-safety command outcome is not confirmed. The original request is retained for a later check.',
        );
        if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
          final accepted = await durableStore.read(saved.submissionId);
          if (accepted != null) return _storedReceipt(accepted);
        }
        throw WorkflowException(
          replayError.code,
          'The critical-safety command outcome could not be confirmed. Its original request is saved on this device; check it again before submitting a new command.',
          details: {
            ...replayError.details,
            'reasonCode': 'critical-alarm-outcome-unconfirmed',
            'commandId': saved.requestId,
            'aggregateId': saved.aggregateId,
          },
        );
      } catch (_) {
        await _recordUnexpectedOutcome(claim);
        rethrow;
      }
    } catch (_) {
      await _recordUnexpectedOutcome(claim);
      rethrow;
    }
  }

  Future<void> _recordUnexpectedOutcome(DurableSubmissionClaim claim) async {
    await durableStore.recordOutcome(
      claim,
      state: DurableSubmissionState.uncertain,
      errorCode: 'critical-alarm-outcome-unconfirmed',
      message:
          'The command outcome could not be confirmed. Its original request is retained for review.',
    );
  }

  Future<WorkflowCommandReceipt> _dispatch(String envelopeJson) =>
      originBoundGateway.executeOriginBoundEnvelope(envelopeJson);

  Future<WorkflowCommandReceipt> _settle(
    DurableSubmission saved,
    WorkflowCommandReceipt receipt,
  ) async {
    final receiptJson = jsonEncode(_receiptMap(receipt));
    final accepted = await durableStore.settleAccepted(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptJson: receiptJson,
      validateReceipt: (submission, raw) {
        final value = WorkflowCommandReceipt.fromMap(raw);
        return value.commandId == submission.requestId &&
            value.commandId == receipt.commandId;
      },
    );
    return _storedReceipt(accepted);
  }

  Future<WorkflowCommandReceipt> _storedReceipt(DurableSubmission saved) async {
    _assertOrigin(saved.actorUid);
    final raw = saved.receiptJson;
    if (!saved.state.isAccepted || raw == null) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The saved critical-safety command has no accepted receipt. Review it before continuing.',
        details: {'reasonCode': 'critical-alarm-accepted-receipt-missing'},
      );
    }
    final receipt = WorkflowCommandReceipt.fromMap(
      durableSubmissionJsonObject(raw),
    );
    if (receipt.commandId != saved.requestId) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The saved critical-safety receipt does not match its original command.',
        details: {'reasonCode': 'critical-alarm-receipt-identity-invalid'},
      );
    }
    if (saved.state == DurableSubmissionState.acceptedPendingAdoption) {
      await durableStore.markReconciled(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptSha256: saved.receiptSha256!,
        adoptInTransaction: (_) async => _assertOrigin(saved.actorUid),
      );
    }
    _assertOrigin(saved.actorUid);
    return receipt;
  }

  Map<String, Object?> _receiptMap(WorkflowCommandReceipt receipt) => {
    'commandId': receipt.commandId,
    'resultKey': receipt.resultKey,
    'aggregateVersion': receipt.aggregateVersion,
    'result': receipt.result,
    'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
  };

  bool _isUncertain(WorkflowException error) =>
      error.code == WorkflowErrorCode.unavailable ||
      error.code == WorkflowErrorCode.deadlineExceeded ||
      error.code == WorkflowErrorCode.aborted;

  // These reason/code pairs can settle only a first attempt with no earlier
  // uncertainty. Receipt absence is not a fence against a delayed prior call.
  // Generic transport/auth and malformed/orphaned replay stay recoverable.
  bool _isDefinitiveRefusal(WorkflowException error) {
    const reasons = <WorkflowErrorCode, Set<String>>{
      WorkflowErrorCode.versionConflict: {'critical-alarm-version-conflict'},
      WorkflowErrorCode.invalidArgument: {
        'critical-alarm-type-unsupported',
        'critical-alarm-contact-number-invalid',
        'critical-alarm-definition-criticality-invalid',
      },
      WorkflowErrorCode.failedPrecondition: {
        'critical-alarm-type-retired',
        'critical-alarm-details-required',
      },
    };
    return reasons[error.code]?.contains(error.details['reasonCode']) == true;
  }

  Future<WorkflowCommandReceipt> raise({
    required CriticalAlarmDefinition definition,
    required String location,
    String? assetTypeKey,
    int? assetNumber,
    required String initialDetails,
  }) {
    final alarmId = WorkflowCommandFactory.uniqueId('critical_alarm');
    return _execute(
      WorkflowCommandFactory.create(
        type: WorkflowCommandType.raiseCriticalAlarm,
        aggregateId: alarmId,
        expectedVersion: 0,
        payload: {
          'alarmTypeKey': definition.key,
          'location': location,
          'assetTypeKey': assetTypeKey,
          'assetNumber': assetNumber,
          'initialDetails': initialDetails,
        },
      ),
    );
  }

  Future<WorkflowCommandReceipt> provideDetails(
    CriticalAlarm alarm,
    String details,
  ) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.provideCriticalAlarmDetails,
      aggregateId: alarm.id,
      expectedVersion: alarm.version,
      payload: {'details': details},
    ),
  );

  Future<WorkflowCommandReceipt> confirmSupport({
    required CriticalAlarm alarm,
    required CriticalAlarmSupportBasis basis,
    required String responderNote,
    String? details,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.confirmCriticalAlarmSupport,
      aggregateId: alarm.id,
      expectedVersion: alarm.version,
      payload: {
        'basis': basis.name,
        'responderNote': responderNote,
        'details': details,
      },
    ),
  );

  Future<WorkflowCommandReceipt> resolve(CriticalAlarm alarm, String summary) =>
      _execute(
        WorkflowCommandFactory.create(
          type: WorkflowCommandType.resolveCriticalAlarm,
          aggregateId: alarm.id,
          expectedVersion: alarm.version,
          payload: {'resolutionSummary': summary},
        ),
      );

  Future<WorkflowCommandReceipt> withdraw(CriticalAlarm alarm, String reason) =>
      _execute(
        WorkflowCommandFactory.create(
          type: WorkflowCommandType.withdrawCriticalAlarmInError,
          aggregateId: alarm.id,
          expectedVersion: alarm.version,
          payload: {'reason': reason},
        ),
      );

  Future<WorkflowCommandReceipt> upsertContact({
    required String contactId,
    required int expectedVersion,
    required String label,
    required CriticalAlarmContactKind kind,
    required String dialValue,
    required List<String> alarmTypeKeys,
    required int priority,
    required String? notes,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.upsertCriticalAlarmContact,
      aggregateId: contactId,
      expectedVersion: expectedVersion,
      payload: {
        'contact': {
          'schemaVersion': 1,
          'label': label,
          'contactKind': kind.name,
          'dialValue': dialValue,
          'alarmTypeKeys': alarmTypeKeys,
          'priority': priority,
          'notes': notes,
        },
        'reason': reason,
      },
    ),
  );

  Future<WorkflowCommandReceipt> setContactStatus({
    required CriticalAlarmContact contact,
    required CriticalAlarmContactStatus status,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.setCriticalAlarmContactStatus,
      aggregateId: contact.id,
      expectedVersion: contact.version,
      payload: {'status': status.name, 'reason': reason},
    ),
  );

  Future<WorkflowCommandReceipt> upsertDefinition({
    CriticalAlarmDefinition? definition,
    required String name,
    required String criticalityKey,
    required int criticalityRank,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.upsertCriticalAlarmDefinition,
      aggregateId:
          definition?.key ??
          WorkflowCommandFactory.uniqueId('critical_alarm_definition'),
      expectedVersion: definition?.version ?? 0,
      payload: {
        'definition': {
          'schemaVersion': 1,
          'name': name,
          'criticalityKey': criticalityKey,
          'criticalityRank': criticalityRank,
        },
        'reason': reason,
      },
    ),
  );

  Future<WorkflowCommandReceipt> setDefinitionStatus({
    required CriticalAlarmDefinition definition,
    required CriticalAlarmDefinitionStatus status,
    required String reason,
  }) => _execute(
    WorkflowCommandFactory.create(
      type: WorkflowCommandType.setCriticalAlarmDefinitionStatus,
      aggregateId: definition.key,
      expectedVersion: definition.version,
      payload: {'status': status.name, 'reason': reason},
    ),
  );
}
