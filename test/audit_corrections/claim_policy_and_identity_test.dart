import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_outbox_policy.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_retry_claim_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final old = DateTime.utc(2026, 9, 11, 8);
  final current = old.add(const Duration(minutes: 6));
  test('old and unclaimed callers cannot alter a newer sending claim', () {
    expect(mayRecordWorkflowAttemptOutcome(currentState: 'sending',
      currentClaimedAt: current, expectedClaimedAt: old), isFalse);
    expect(mayRecordWorkflowAttemptOutcome(currentState: 'sending',
      currentClaimedAt: current), isFalse);
    expect(mayRecordWorkflowAttemptOutcome(currentState: 'sending',
      currentClaimedAt: current, expectedClaimedAt: current), isTrue);
  });
  test('a vanished row cannot be recreated by a claimed retry', () {
    expect(mayRecordWorkflowAttemptOutcome(currentState: null,
      currentClaimedAt: null, expectedClaimedAt: old), isFalse);
    expect(mayRecordWorkflowAttemptOutcome(currentState: null,
      currentClaimedAt: null), isTrue);
  });
  for (final state in <String>['rejected', 'manualReview', 'applied']) {
    test('unclaimed failure does not reopen $state', () {
      expect(mayRecordWorkflowAttemptOutcome(currentState: state,
        currentClaimedAt: old), isFalse);
    });
  }
  const policy = WorkflowRetryPolicy();
  test('quota refusal is retryable and honors the server delay', () {
    const error = WorkflowException(WorkflowErrorCode.resourceExhausted,
      'Try later.', details: <String, Object?>{'retryAfterSeconds': 600});
    expect(policy.classify(error), WorkflowRetryDisposition.retryUncertain);
    expect(policy.delayForFailure(error, 2), const Duration(minutes: 10));
    expect(policy.delayForFailure(error, 8), policy.delayForAttempt(8));
  });
  for (final invalid in <Object?>[null, '600', -1, 0, 0.5, 86401]) {
    test('invalid quota delay $invalid falls back to a conservative floor', () {
      // A quota refusal does not advance the attempt counter, so ordinary
      // backoff does not grow between refusals. Falling back to the plain
      // value would keep asking a rate-limited endpoint every few seconds.
      final error = WorkflowException(WorkflowErrorCode.resourceExhausted,
        'Try later.', details: <String, Object?>{'retryAfterSeconds': invalid});
      expect(policy.delayForFailure(error, 2),
        WorkflowRetryPolicy.quotaFallbackDelay);
      // Where ordinary backoff is already longer, it still wins.
      expect(policy.delayForFailure(error, 8), policy.delayForAttempt(8));
    });
  }
  test('quota deferral is bounded by elapsed time, not by refusal count', () {
    // Exempting quota refusals from the attempt budget is only safe while it
    // is bounded by something. Measured from first local acceptance so a run
    // of refusals cannot extend the window by resetting it.
    final accepted = DateTime.utc(2026, 9, 11, 8);
    expect(policy.quotaDeferralExhausted(firstAcceptedLocallyAt: accepted,
      now: accepted), isFalse);
    expect(policy.quotaDeferralExhausted(firstAcceptedLocallyAt: accepted,
      now: accepted.add(WorkflowRetryPolicy.maxQuotaDeferral -
        const Duration(seconds: 1))), isFalse);
    expect(policy.quotaDeferralExhausted(firstAcceptedLocallyAt: accepted,
      now: accepted.add(WorkflowRetryPolicy.maxQuotaDeferral)), isTrue);
  });
  for (final id in <String>['.', '..', 'nested/path', 'a\nb', 'é' * 751]) {
    test('rejects unsafe document identity $id', () {
      expect(() => WorkflowCommand(commandId: id,
        type: WorkflowCommandType.acknowledgeMaintenanceTicket,
        aggregateId: 'ticket-1', expectedVersion: 1),
        throwsA(isA<WorkflowException>()));
    });
  }
}
