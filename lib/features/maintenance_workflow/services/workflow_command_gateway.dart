import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/persistence/durable_submission.dart';

import '../domain/workflow_command_contract.dart';
import '../domain/workflow_error.dart';

const maintenanceWorkflowCallableName = 'executeMaintenanceWorkflowCommand';
const maintenanceWorkflowCallableRegion = 'asia-south1';
const maintenanceWorkflowV2CallableName = 'executeMaintenanceWorkflowCommandV2';

abstract interface class WorkflowCommandGateway {
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command);
}

abstract interface class OriginBoundWorkflowCommandGateway {
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  );
}

class FirebaseWorkflowCommandGateway
    implements WorkflowCommandGateway, OriginBoundWorkflowCommandGateway {
  final FirebaseFunctions? functions;
  final String? Function()? currentActorUid;
  const FirebaseWorkflowCommandGateway({this.functions, this.currentActorUid});

  FirebaseFunctions get _client =>
      functions ??
      FirebaseFunctions.instanceFor(region: maintenanceWorkflowCallableRegion);

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) => _execute(
    maintenanceWorkflowCallableName,
    command.toMap(),
    command.commandId,
  );

  /// Consume the saved wrapper, never attach today's account to a prior draft.
  /// This transport creates no second local command/retry owner.
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) {
    final envelope = durableSubmissionJsonObject(envelopeJson);
    final command = envelope['command'];
    final origin = envelope['originActorUid'];
    if (envelope.length != 3 ||
        envelope['protocolVersion'] != 2 ||
        origin is! String ||
        origin.trim().isEmpty ||
        origin != origin.trim() ||
        command is! Map<String, dynamic> ||
        command['commandId'] is! String) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'The saved command does not prove its original account. Nothing was sent.',
      );
    }
    final liveActor = currentActorUid == null
        ? FirebaseAuth.instance.currentUser?.uid
        : currentActorUid!();
    if (liveActor != origin) {
      throw const WorkflowException(
        WorkflowErrorCode.permissionDenied,
        'Return to the account that saved this command before checking it.',
      );
    }
    return _execute(
      maintenanceWorkflowV2CallableName,
      envelope,
      command['commandId'] as String,
    );
  }

  Future<WorkflowCommandReceipt> _execute(
    String callableName,
    Map<String, Object?> envelope,
    String commandId,
  ) async {
    try {
      final response = await _client
          .httpsCallable(callableName)
          .call<Map<String, dynamic>>(envelope);
      final receipt = WorkflowCommandReceipt.fromMap(response.data);
      if (receipt.commandId != commandId) {
        throw const FormatException(
          'Workflow command receipt identity does not match the request.',
        );
      }
      return receipt;
    } on FirebaseFunctionsException catch (error) {
      final details = _details(error.details);
      throw WorkflowException(
        _mapCode(error.code, details['workflowCode']?.toString()),
        error.message ?? 'Maintenance workflow command failed.',
        details: details,
      );
    } on FormatException catch (error) {
      throw WorkflowException(
        WorkflowErrorCode.unavailable,
        'The workflow command may have been accepted, but its server receipt was malformed. The same request will be reconciled safely.',
        details: <String, Object?>{
          'reasonCode': 'workflow-command-receipt-invalid',
          'receiptError': error.message,
        },
      );
    }
  }

  WorkflowErrorCode _mapCode(String transportCode, String? workflowCode) {
    switch (workflowCode) {
      case 'workflow-version-conflict':
        return WorkflowErrorCode.versionConflict;
      case 'command-idempotency-conflict':
        return WorkflowErrorCode.idempotencyConflict;
      case 'lane-set-not-finalized':
        return WorkflowErrorCode.laneSetNotFinalized;
      case 'lane-ack-required':
        return WorkflowErrorCode.laneAcknowledgementRequired;
      case 'lane-progress-open':
        return WorkflowErrorCode.laneProgressOpen;
      case 'lane-not-ready-to-close':
        return WorkflowErrorCode.laneNotReadyToClose;
      case 'blocking-compliance-open':
        return WorkflowErrorCode.blockingComplianceOpen;
      case 'red-answer-required':
        return WorkflowErrorCode.redAnswerRequired;
      case 'preparation-answer-required':
        return WorkflowErrorCode.preparationAnswerRequired;
      case 'red-successor-template-unconfigured':
        return WorkflowErrorCode.redSuccessorTemplateUnconfigured;
      case 'red-lane-not-ready':
        return WorkflowErrorCode.redLaneNotReady;
      case 'red-preparation-incomplete':
        return WorkflowErrorCode.redPreparationIncomplete;
      case 'red-not-applicable':
        return WorkflowErrorCode.redNotApplicable;
      case 'equipment-state-conflict':
        return WorkflowErrorCode.equipmentStateConflict;
      case 'unsupported-workflow-command':
        return WorkflowErrorCode.unsupportedCommand;
      case 'unauthorized-represented-lane':
        return WorkflowErrorCode.permissionDenied;
    }
    switch (transportCode) {
      case 'unauthenticated':
        return WorkflowErrorCode.unauthenticated;
      case 'permission-denied':
        return WorkflowErrorCode.permissionDenied;
      case 'invalid-argument':
        return WorkflowErrorCode.invalidArgument;
      case 'not-found':
        return WorkflowErrorCode.notFound;
      case 'already-exists':
        return WorkflowErrorCode.alreadyExists;
      case 'failed-precondition':
        return WorkflowErrorCode.failedPrecondition;
      case 'aborted':
        return WorkflowErrorCode.aborted;
      case 'unavailable':
        return WorkflowErrorCode.unavailable;
      case 'deadline-exceeded':
        return WorkflowErrorCode.deadlineExceeded;
      case 'resource-exhausted':
        return WorkflowErrorCode.resourceExhausted;
      default:
        return WorkflowErrorCode.internal;
    }
  }

  Map<String, Object?> _details(Object? raw) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    return <String, Object?>{};
  }
}
