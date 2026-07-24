enum WorkflowErrorCode {
  invalidArgument,
  unauthenticated,
  permissionDenied,
  notFound,
  alreadyExists,
  failedPrecondition,
  versionConflict,
  idempotencyConflict,
  laneSetNotFinalized,
  laneAcknowledgementRequired,
  laneProgressOpen,
  laneNotReadyToClose,
  blockingComplianceOpen,
  redAnswerRequired,
  preparationAnswerRequired,
  redSuccessorTemplateUnconfigured,
  redLaneNotReady,
  redPreparationIncomplete,
  redNotApplicable,
  equipmentStateConflict,
  unsupportedCommand,
  unavailable,
  deadlineExceeded,
  aborted,
  internal,
}

class WorkflowException implements Exception {
  final WorkflowErrorCode code;
  final String message;
  final Map<String, Object?> details;

  const WorkflowException(
    this.code,
    this.message, {
    this.details = const <String, Object?>{},
  });

  @override
  String toString() => 'WorkflowException(${code.name}: $message)';
}
