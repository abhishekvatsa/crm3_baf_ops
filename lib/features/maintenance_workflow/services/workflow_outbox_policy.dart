import '../domain/workflow_error.dart';

enum WorkflowRetryDisposition { retryUncertain, reject, applied, manualReview }

class WorkflowRetryPolicy {
  static const int maxAutomaticAttempts = 8;

  /// How long a request may keep deferring on temporary quota refusals.
  ///
  /// A quota refusal is a definite non-execution, so it does not spend an
  /// uncertain-dispatch attempt. That exemption has to be bounded by something
  /// or a server that keeps refusing would defer the same request forever, so
  /// it is bounded by elapsed time since the request was first accepted
  /// locally. Past this, the work stops waiting and asks for a human.
  static const Duration maxQuotaDeferral = Duration(hours: 6);

  /// Backoff used when a quota refusal carries no usable retry window.
  ///
  /// Longer than the ordinary first backoff on purpose: the server has just
  /// said it is out of capacity, and the normal 15s floor would keep asking
  /// a rate-limited endpoint roughly every fifteen seconds for hours.
  static const Duration quotaFallbackDelay = Duration(minutes: 5);

  const WorkflowRetryPolicy();

  WorkflowRetryDisposition classify(WorkflowException error) {
    switch (error.code) {
      case WorkflowErrorCode.unavailable:
      case WorkflowErrorCode.deadlineExceeded:
      case WorkflowErrorCode.aborted:
      case WorkflowErrorCode.resourceExhausted:
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

  /// Use the longer of backoff and a valid server-requested quota delay.
  /// Server limits are measured in seconds; do not silently interpret them as
  /// milliseconds, accept arbitrary strings, or overflow a DateTime.
  Duration delayForFailure(WorkflowException error, int attempt) {
    final backoff = delayForAttempt(attempt);
    if (error.code != WorkflowErrorCode.resourceExhausted) return backoff;
    final raw = error.details['retryAfterSeconds'];
    if (raw is! int || raw < 1 || raw > 86400) {
      // No usable window. A quota refusal does not advance the attempt
      // counter, so the ordinary backoff would not grow either; falling back
      // to the plain value would retry at a fixed short interval until the
      // deferral budget ran out.
      return backoff > quotaFallbackDelay ? backoff : quotaFallbackDelay;
    }
    final requested = Duration(seconds: raw);
    return requested > backoff ? requested : backoff;
  }

  /// Whether temporary quota refusals have deferred this request long enough.
  ///
  /// Measured from when the request was first accepted locally, so a run of
  /// refusals cannot extend the window by resetting it.
  bool quotaDeferralExhausted({
    required DateTime firstAcceptedLocallyAt,
    required DateTime now,
  }) => now.difference(firstAcceptedLocallyAt) >= maxQuotaDeferral;

  Duration delayForAttempt(int attempt) {
    final capped = attempt.clamp(1, 8);
    return Duration(seconds: 15 * (1 << (capped - 1)));
  }
}
