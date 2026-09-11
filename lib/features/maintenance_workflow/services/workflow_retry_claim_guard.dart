/// Whether this attempt may change the currently stored retry bookkeeping.
///
/// Called inside the repository's receipt-aware transaction. Accepted server
/// evidence is handled before this guard; an expired claimant never invalidates
/// a genuine receipt. This extends the existing claim-timestamp fence, not a
/// replacement for future durable claim generations or originating-actor scope.
bool mayRecordWorkflowAttemptOutcome({
  required String? currentState,
  required DateTime? currentClaimedAt,
  DateTime? expectedClaimedAt,
}) {
  if (expectedClaimedAt != null) {
    return currentState == 'sending' &&
        currentClaimedAt?.toUtc() == expectedClaimedAt.toUtc();
  }
  // A foreground invocation without a claim cannot borrow another attempt's
  // ownership or automatically reopen a terminal decision.
  return currentState != 'sending' &&
      currentState != 'applied' &&
      currentState != 'rejected' &&
      currentState != 'manualReview';
}
