import 'compliance_decision_policy.dart';
import 'compliance_models.dart';
import 'workflow_error.dart';
import 'workflow_types.dart';

class CompliancePreviewEngine {
  final ComplianceDecisionPolicy policy;
  const CompliancePreviewEngine({this.policy = const ComplianceDecisionPolicy()});

  ComplianceStatus previewReturnForCorrection(ComplianceRequestSnapshot request) =>
      policy.statusAfterReturnForCorrection(request);

  CounterDecisionPreview previewCounterDecision({
    required ComplianceRequestSnapshot request,
    required CounterDecision decision,
  }) {
    if (request.counterProposal == null) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'There is no counter-condition awaiting decision.',
      );
    }
    return CounterDecisionPreview(
      originalStatus: policy.originalStatusAfterCounterDecision(decision),
      createSuccessor: policy.shouldCreateSuccessor(decision),
      escalate: policy.shouldEscalate(decision),
      successorStatus: decision == CounterDecision.accept
          ? ComplianceStatus.acknowledged
          : null,
    );
  }
}

class CounterDecisionPreview {
  final ComplianceStatus originalStatus;
  final bool createSuccessor;
  final bool escalate;
  final ComplianceStatus? successorStatus;

  const CounterDecisionPreview({
    required this.originalStatus,
    required this.createSuccessor,
    required this.escalate,
    required this.successorStatus,
  });
}
