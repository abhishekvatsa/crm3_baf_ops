import 'compliance_models.dart';
import 'workflow_error.dart';
import 'workflow_types.dart';

enum CounterDecision { accept, reject }

class ComplianceDecisionPolicy {
  const ComplianceDecisionPolicy();

  bool mayProposeCounter(ComplianceRequestSnapshot request) =>
      (request.status == ComplianceStatus.raised || request.status == ComplianceStatus.acknowledged) &&
      request.counterDepth == 0 &&
      request.counterProposal == null;

  void assertMayProposeCounter(ComplianceRequestSnapshot request) {
    if (!mayProposeCounter(request)) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'Only one counter-condition may be proposed while the request is open.',
      );
    }
  }

  bool mayReturnForCorrection(ComplianceRequestSnapshot request) =>
      request.status == ComplianceStatus.complied;

  ComplianceStatus statusAfterReturnForCorrection(ComplianceRequestSnapshot request) {
    if (!mayReturnForCorrection(request)) {
      throw const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'Only a complied request may be returned for correction.',
      );
    }
    return ComplianceStatus.acknowledged;
  }

  ComplianceStatus originalStatusAfterCounterDecision(CounterDecision decision) =>
      decision == CounterDecision.accept
          ? ComplianceStatus.superseded
          : ComplianceStatus.acknowledged;

  bool shouldCreateSuccessor(CounterDecision decision) => decision == CounterDecision.accept;
  bool shouldEscalate(CounterDecision decision) => decision == CounterDecision.reject;
}
