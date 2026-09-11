import '../domain/workflow_error.dart';

enum WorkflowRetryDisposition { retryUncertain, reject, applied, manualReview }

class WorkflowRetryPolicy {
  static const int maxAutomaticAttempts = 8;

  /// How long a request may keep deferring on temporary quota refusals before
  /// the next refusal escalates it.
  ///
  /// A quota refusal is a definite non-execution, so it does not spend an
  /// uncertain-dispatch attempt. That exemption has to be bounded or a server
  /// that keeps refusing would defer the same request forever, so it is
  /// bounded by elapsed time since the request was first recorded locally.
  ///
  /// Read this precisely. It is **not** "the request becomes visible for
  /// manual review six hours after it was recorded". The check runs when an
  /// attempt returns another quota refusal, so the rule is:
  ///
  ///   escalate on the first quota refusal that happens after this has elapsed
  ///
  /// The next attempt is scheduled by the server's own window, which may be as
  /// long as a day, so escalation can be later than six hours. Scheduling an
  /// earlier attempt purely to trigger escalation would mean ignoring the delay
  /// a rate-limited server asked for, which is the behaviour this policy exists
  /// to prevent. A guarantee of visibility at a fixed wall-clock time would
  /// need something that promotes the row without a network attempt, and that
  /// does not exist here.
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

  /// Whether a failure may be reattempted inside a caller's own short retry
  /// loop, as distinct from being retried later against a stored deadline.
  ///
  /// A quota refusal is retryable but not here: repeating it within seconds
  /// asks a rate-limited endpoint again while ignoring the delay it asked for.
  ///
  /// Standing aside is only half of the contract. It stops a second attempt
  /// inside one loop; it says nothing about the next invocation. A caller that
  /// relies on this must also record the server's window somewhere that
  /// outlives the call and consult it before attempting again — otherwise the
  /// next run resubmits immediately and the delay was never honoured.
  bool mayRetryInCallerLoop(WorkflowException error) =>
      error.code != WorkflowErrorCode.resourceExhausted &&
      classify(error) == WorkflowRetryDisposition.retryUncertain;

  /// Whether temporary quota refusals have deferred this request long enough
  /// that the refusal being handled now should escalate it.
  ///
  /// Measured from when the request was first recorded locally, so a run of
  /// refusals cannot extend the window by resetting it. Evaluated while
  /// handling a refusal — it is a test applied to an attempt, not a timer that
  /// fires on its own. See [maxQuotaDeferral].
  bool quotaDeferralExhausted({
    required DateTime firstAcceptedLocallyAt,
    required DateTime now,
  }) => now.difference(firstAcceptedLocallyAt) >= maxQuotaDeferral;

  Duration delayForAttempt(int attempt) {
    final capped = attempt.clamp(1, 8);
    return Duration(seconds: 15 * (1 << (capped - 1)));
  }
}
