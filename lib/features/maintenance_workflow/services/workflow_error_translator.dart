import '../domain/workflow_error.dart';

abstract final class WorkflowErrorTranslator {
  static String operatorMessage(WorkflowException error) {
    final reasonCode = (error.details['workflowCode'] ?? error.details['reasonCode'])?.toString();
    switch (reasonCode) {
      case 'lane-set-not-finalized': return 'An Admin, SI or Contract Supervisor must first assign the responsible lanes.';
      case 'lane-ack-required': return 'The responsible lane must acknowledge this job before work can proceed.';
      case 'lane-progress-open': return 'This lane contains saved work and can only be terminated with a reason.';
      case 'blocking-compliance-open': return 'A required interdepartmental obligation is still open.';
      case 'red-answer-required': return 'Confirm whether RED work is required before final submission.';
      case 'preparation-answer-required': return 'Confirm whether the furnace must be placed on the maintenance stand.';
      case 'red-lane-not-ready': return 'Close all active non-RED lanes before releasing RED work.';
      case 'red-preparation-incomplete': return 'RED work is waiting for the required equipment preparation.';
      case 'red-not-applicable': return 'RED work is not applicable to this equipment type.';
      case 'red-successor-template-unconfigured': return 'The governed RED successor template is not configured.';
    }
    switch (error.code) {
      case WorkflowErrorCode.unavailable:
      case WorkflowErrorCode.deadlineExceeded:
        return 'The workflow server could not be reached. This action requires network connectivity.';
      case WorkflowErrorCode.versionConflict:
      case WorkflowErrorCode.aborted:
        return 'The workflow changed on the server. Refresh and review the latest state.';
      case WorkflowErrorCode.permissionDenied:
        return 'You are not authorised to perform this workflow action.';
      default:
        return error.message;
    }
  }
}
