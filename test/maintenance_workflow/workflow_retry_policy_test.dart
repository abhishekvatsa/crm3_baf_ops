import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_outbox_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = WorkflowRetryPolicy();

  test('only uncertain online failures are retried', () {
    expect(
      policy.classify(
        const WorkflowException(WorkflowErrorCode.unavailable, 'x'),
      ),
      WorkflowRetryDisposition.retryUncertain,
    );
    expect(
      policy.classify(
        const WorkflowException(WorkflowErrorCode.permissionDenied, 'x'),
      ),
      WorkflowRetryDisposition.reject,
    );
  });
}
