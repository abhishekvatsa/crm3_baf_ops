import '../domain/workflow_error.dart';

enum WorkflowRetryDisposition { retryUncertain, reject, applied, manualReview }

class WorkflowRetryPolicy {
  static const int maxAutomaticAttempts = 8;
  const WorkflowRetryPolicy();

  WorkflowRetryDisposition classify(WorkflowException error) {
    switch (error.code) {
      case WorkflowErrorCode.unavailable:
      case WorkflowErrorCode.deadlineExceeded:
      case WorkflowErrorCode.aborted:
        return WorkflowRetryDisposition.retryUncertain;
      case WorkflowErrorCode.versionConflict:
      case WorkflowErrorCode.idempotencyConflict:
      case WorkflowErrorCode.invalidArgument:
      case WorkflowErrorCode.permissionDenied:
      case WorkflowErrorCode.failedPrecondition:
      case WorkflowErrorCode.laneSetNotFinalized:
      case WorkflowErrorCode.laneAcknowledgementRequired:
      case WorkflowErrorCode.laneProgressOpen:
      case WorkflowErrorCode.laneNotReadyToClose:
      case WorkflowErrorCode.blockingComplianceOpen:
      case WorkflowErrorCode.redAnswerRequired:
      case WorkflowErrorCode.preparationAnswerRequired:
      case WorkflowErrorCode.redSuccessorTemplateUnconfigured:
      case WorkflowErrorCode.redLaneNotReady:
      case WorkflowErrorCode.redPreparationIncomplete:
      case WorkflowErrorCode.redNotApplicable:
      case WorkflowErrorCode.equipmentStateConflict:
      case WorkflowErrorCode.unsupportedCommand:
      case WorkflowErrorCode.unauthenticated:
      case WorkflowErrorCode.notFound:
      case WorkflowErrorCode.alreadyExists:
        return WorkflowRetryDisposition.reject;
      case WorkflowErrorCode.internal:
        return WorkflowRetryDisposition.manualReview;
    }
  }

  Duration delayForAttempt(int attempt) {
    final capped = attempt.clamp(1, 8);
    return Duration(seconds: 15 * (1 << (capped - 1)));
  }
}
