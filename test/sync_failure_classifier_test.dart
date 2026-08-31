import 'package:crm3_baf_ops/core/services/sync_failure_classifier.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workflow sync failure classification', () {
    test('invalid command shape is a durable rejection', () {
      final result = classifySyncFailure(
        const WorkflowException(
          WorkflowErrorCode.invalidArgument,
          'ticket has unsupported or missing fields.',
          details: <String, Object?>{
            'reasonCode': 'maintenance-ticket-command-shape-invalid',
          },
        ),
      );

      expect(result.errorCode, 'invalidArgument');
      expect(result.message, 'ticket has unsupported or missing fields.');
      expect(result.isLikelyPermanent, isTrue);
    });

    test('network uncertainty remains retryable', () {
      for (final code in <WorkflowErrorCode>[
        WorkflowErrorCode.unavailable,
        WorkflowErrorCode.deadlineExceeded,
        WorkflowErrorCode.aborted,
      ]) {
        final result = classifySyncFailure(
          WorkflowException(code, 'The server response is uncertain.'),
        );
        expect(result.errorCode, code.name);
        expect(result.isLikelyPermanent, isFalse);
      }
    });

    test('workflow contract conflicts are held for reconciliation', () {
      for (final code in <WorkflowErrorCode>[
        WorkflowErrorCode.failedPrecondition,
        WorkflowErrorCode.permissionDenied,
        WorkflowErrorCode.versionConflict,
        WorkflowErrorCode.idempotencyConflict,
      ]) {
        expect(
          classifySyncFailure(
            WorkflowException(code, 'Operator action is required.'),
          ).isLikelyPermanent,
          isTrue,
        );
      }
    });
  });
}
