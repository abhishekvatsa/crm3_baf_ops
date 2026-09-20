import 'dart:convert';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/services/workflow_command_gateway.dart';

/// Operator-facing command boundary for correcting a recorded Burner Block
/// installation time. The original event is never edited or recreated.
class BurnerBlockCorrectionCommandService {
  const BurnerBlockCorrectionCommandService({
    required this.gateway,
    required this.currentActorUid,
    required this.durableStore,
    required this.confirmReadback,
  });

  final OriginBoundWorkflowCommandGateway gateway;
  final String Function() currentActorUid;
  final DurableSubmissionRepository durableStore;
  final Future<void> Function(
    WorkflowCommandReceipt receipt,
    String originalEnvelopeJson,
  )
  confirmReadback;

  static String resource(String eventId) => 'burnerBlockCorrection:$eventId';

  String _actor([String? expected]) {
    final uid = currentActorUid().trim();
    if (uid.isEmpty || (expected != null && uid != expected)) {
      throw const WorkflowException(
        WorkflowErrorCode.unauthenticated,
        'Return to the approved account that saved this installation correction.',
      );
    }
    return uid;
  }

  Future<DurableSubmission?> pendingForEvent(String eventId) async {
    final uid = _actor();
    final saved = await durableStore.findUnresolvedForResource(
      resource(eventId),
    );
    _actor(uid);
    if (saved == null) return null;
    _actor(saved.actorUid);
    _command(saved);
    return saved;
  }

  Future<WorkflowCommandReceipt> correct({
    required String correctionId,
    required String eventId,
    required String expectedCurrentEventId,
    required String correctedActionPerformedAt,
    required String reason,
    String? supersedesCorrectionId,
  }) async {
    final originActorUid = _actor();
    final command = WorkflowCommandFactory.create(
      type: WorkflowCommandType.correctBurnerBlockInstallation,
      aggregateId: correctionId,
      expectedVersion: 0,
      payload: {
        'eventId': eventId,
        'expectedCurrentEventId': expectedCurrentEventId,
        'correctedActionPerformedAt': correctedActionPerformedAt,
        'reason': reason,
        'supersedesCorrectionId': supersedesCorrectionId,
      },
    );
    final envelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': originActorUid,
      'command': command.toMap(),
    });
    final saved = await durableStore.prepare(
      DurableSubmissionDraft(
        submissionId: command.commandId,
        actorUid: originActorUid,
        requestId: command.commandId,
        aggregateId: correctionId,
        resourceKey: resource(eventId),
        protocol: 'maintenanceWorkflow.v2',
        envelopeJson: envelope,
        displayMetadataJson: jsonEncode({
          'schemaVersion': 1,
          'eventId': eventId,
        }),
      ),
    );
    _actor(originActorUid);
    return resume(saved.submissionId);
  }

  Map<String, dynamic> _command(DurableSubmission saved) {
    final envelope = durableSubmissionJsonObject(saved.envelopeJson);
    final raw = envelope['command'];
    if (saved.protocol != 'maintenanceWorkflow.v2' ||
        envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        saved.actorUid == null ||
        envelope['originActorUid'] != saved.actorUid ||
        raw is! Map<String, dynamic> ||
        raw['commandType'] != 'correctBurnerBlockInstallation' ||
        raw['commandId'] != saved.requestId ||
        raw['aggregateId'] != saved.aggregateId ||
        raw['expectedVersion'] != 0 ||
        raw['payload'] is! Map<String, dynamic>) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The saved installation correction needs review before it can be checked.',
      );
    }
    final payload = raw['payload'] as Map<String, dynamic>;
    if (payload['eventId'] is! String ||
        saved.resourceKey != resource(payload['eventId'] as String)) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The saved correction does not match its original installation.',
      );
    }
    return raw;
  }

  Future<WorkflowCommandReceipt> resume(String submissionId) async {
    final uid = _actor();
    final saved = await durableStore.read(submissionId);
    _actor(uid);
    if (saved == null) {
      throw const WorkflowException(
        WorkflowErrorCode.notFound,
        'The original saved correction could not be found. Nothing was sent.',
      );
    }
    _actor(saved.actorUid);
    _command(saved);
    if (saved.state.isAccepted) return _adopt(saved);
    final claim = await durableStore.claim(
      submissionId: submissionId,
      actorUid: uid,
    );
    if (claim.disposition == DurableSubmissionClaimDisposition.accepted) {
      return _adopt(claim.submission);
    }
    if (!claim.mayDispatch) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'This correction is already being checked or needs review. Its original request remains saved.',
      );
    }
    try {
      _actor(uid);
      final receipt = await gateway.executeOriginBoundEnvelope(
        saved.envelopeJson,
      );
      final receiptJson = jsonEncode({
        'commandId': receipt.commandId,
        'resultKey': receipt.resultKey,
        'aggregateVersion': receipt.aggregateVersion,
        'result': receipt.result,
        'appliedAt': receipt.appliedAt.toUtc().toIso8601String(),
      });
      _receipt(saved, durableSubmissionJsonObject(receiptJson));
      final accepted = await durableStore.settleAccepted(
        submissionId: saved.submissionId,
        envelopeSha256: saved.envelopeSha256,
        receiptJson: receiptJson,
        validateReceipt: (row, raw) {
          _receipt(row, raw);
          return true;
        },
      );
      return _adopt(accepted);
    } catch (error) {
      // Only a first attempt's explicit pre-commit rejection proves this intent
      // was refused. A retry refusal cannot fence an earlier delayed request.
      final reason = error is WorkflowException
          ? error.details['reasonCode']
          : null;
      final refused =
          claim.submission.attemptCount == 1 &&
          error is WorkflowException &&
          const {
            'burner-block-lifecycle-correction-stale',
            'burner-block-lifecycle-current-version-conflict',
            'burner-block-lifecycle-correction-no-change',
            'burner-block-lifecycle-correction-after-completion',
            'burner-block-correction-future-dated',
          }.contains(reason);
      final outcome = await durableStore.recordOutcome(
        claim,
        state: refused
            ? DurableSubmissionState.rejected
            : DurableSubmissionState.uncertain,
        errorCode: reason is String
            ? reason
            : 'burner-block-correction-unconfirmed',
        message: error is WorkflowException
            ? error.message
            : 'The correction remains saved. Check its original request before making another correction.',
      );
      if (outcome == DurableSubmissionOutcome.alreadyAccepted) {
        final accepted = await durableStore.read(submissionId);
        if (accepted != null) return _adopt(accepted);
      }
      rethrow;
    }
  }

  WorkflowCommandReceipt _receipt(
    DurableSubmission saved,
    Map<String, dynamic> raw,
  ) {
    final command = _command(saved);
    final payload = command['payload'] as Map<String, dynamic>;
    final receipt = WorkflowCommandReceipt.fromMap(raw);
    final result = receipt.result;
    if (receipt.commandId != saved.requestId ||
        receipt.aggregateVersion != 1 ||
        receipt.resultKey != 'burner-block-installation-corrected' ||
        result['correctionId'] != saved.aggregateId ||
        result['correctsEventId'] != payload['eventId'] ||
        result['expectedCurrentEventId'] != payload['expectedCurrentEventId'] ||
        result['supersedesCorrectionId'] != payload['supersedesCorrectionId'] ||
        result['auditId'] !=
            'server_burner_block_correction_${saved.requestId}' ||
        readRequiredPersistedDateTime(
              result['correctedActionPerformedAt'],
              field: 'correctedActionPerformedAt',
              source: 'correction receipt',
            ).toUtc() !=
            readRequiredPersistedDateTime(
              payload['correctedActionPerformedAt'],
              field: 'correctedActionPerformedAt',
              source: 'saved correction',
            ).toUtc()) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The accepted correction receipt disagrees with its original request. Retained evidence needs review.',
      );
    }
    return receipt;
  }

  Future<WorkflowCommandReceipt> _adopt(DurableSubmission saved) async {
    _actor(saved.actorUid);
    if (!saved.state.isAccepted ||
        saved.receiptJson == null ||
        saved.receiptSha256 == null) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'The saved correction has no confirmed acceptance.',
      );
    }
    final receipt = _receipt(
      saved,
      durableSubmissionJsonObject(saved.receiptJson!),
    );
    await confirmReadback(receipt, saved.envelopeJson);
    _actor(saved.actorUid);
    await durableStore.markReconciled(
      submissionId: saved.submissionId,
      envelopeSha256: saved.envelopeSha256,
      receiptSha256: saved.receiptSha256!,
    );
    _actor(saved.actorUid);
    return receipt;
  }
}
