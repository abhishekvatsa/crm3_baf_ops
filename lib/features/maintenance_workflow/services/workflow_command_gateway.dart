import 'package:cloud_functions/cloud_functions.dart';

import '../domain/workflow_command_contract.dart';
import '../domain/workflow_error.dart';

const maintenanceWorkflowCallableName = 'executeMaintenanceWorkflowCommand';
const maintenanceWorkflowCallableRegion = 'asia-south1';

abstract interface class WorkflowCommandGateway {
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command);
}

class FirebaseWorkflowCommandGateway implements WorkflowCommandGateway {
  final FirebaseFunctions? functions;
  const FirebaseWorkflowCommandGateway({this.functions});

  FirebaseFunctions get _client =>
      functions ??
      FirebaseFunctions.instanceFor(region: maintenanceWorkflowCallableRegion);

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    try {
      final response = await _client
          .httpsCallable(maintenanceWorkflowCallableName)
          .call<Map<String, dynamic>>(command.toMap());
      final receipt = WorkflowCommandReceipt.fromMap(response.data);
      if (receipt.commandId != command.commandId) {
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
      default:
        return WorkflowErrorCode.internal;
    }
  }

  Map<String, Object?> _details(Object? raw) {
    if (raw is Map) return Map<String, Object?>.from(raw);
    return <String, Object?>{};
  }
}
