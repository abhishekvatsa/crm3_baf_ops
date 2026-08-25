part of 'complete_job_screen.dart';

class _WorkflowClosureGateResult {
  final bool identityPresent;
  final bool isLoading;
  final bool hasLoadError;
  final bool workflowPresent;
  final bool workflowTerminal;
  final int activeLaneCount;
  final List<String> openLaneKeys;
  final int blockingComplianceCount;

  const _WorkflowClosureGateResult({
    required this.identityPresent,
    required this.isLoading,
    required this.hasLoadError,
    required this.workflowPresent,
    required this.workflowTerminal,
    required this.activeLaneCount,
    required this.openLaneKeys,
    required this.blockingComplianceCount,
  });

  const _WorkflowClosureGateResult.missingIdentity()
    : identityPresent = false,
      isLoading = false,
      hasLoadError = false,
      workflowPresent = false,
      workflowTerminal = false,
      activeLaneCount = 0,
      openLaneKeys = const <String>[],
      blockingComplianceCount = 0;

  factory _WorkflowClosureGateResult.fromAsyncValues({
    required AsyncValue<WorkflowAggregateRecord?> workflowAsync,
    required AsyncValue<List<JobLaneRecord>> lanesAsync,
    required AsyncValue<List<ComplianceRequestRecord>> complianceAsync,
  }) {
    final workflow = workflowAsync.valueOrNull;
    final activeLanes = (lanesAsync.valueOrNull ?? const <JobLaneRecord>[])
        .where(
          (lane) =>
              lane.statusKey != 'removed' && lane.statusKey != 'terminated',
        )
        .toList(growable: false);
    final blockingCompliance =
        (complianceAsync.valueOrNull ?? const <ComplianceRequestRecord>[])
            .where(isBlockingCompliance)
            .length;

    return _WorkflowClosureGateResult(
      identityPresent: true,
      isLoading:
          workflowAsync.isLoading ||
          lanesAsync.isLoading ||
          complianceAsync.isLoading,
      hasLoadError:
          workflowAsync.hasError ||
          lanesAsync.hasError ||
          complianceAsync.hasError,
      workflowPresent: workflow != null,
      workflowTerminal:
          workflow != null &&
          (workflow.statusKey == 'completed' ||
              workflow.statusKey == 'cancelled' ||
              workflow.cancelled ||
              workflow.completedAt != null),
      activeLaneCount: activeLanes.length,
      openLaneKeys: activeLanes
          .where((lane) => lane.statusKey != 'closed')
          .map((lane) => lane.laneKey)
          .toList(growable: false),
      blockingComplianceCount: blockingCompliance,
    );
  }

  static bool isBlockingCompliance(ComplianceRequestRecord request) {
    return request.gatesLaneFirestoreId != null &&
        request.statusKey != 'confirmedClosed' &&
        request.statusKey != 'cancelled' &&
        request.statusKey != 'superseded';
  }

  bool get canComplete =>
      identityPresent &&
      !isLoading &&
      !hasLoadError &&
      workflowPresent &&
      !workflowTerminal &&
      activeLaneCount > 0 &&
      openLaneKeys.isEmpty &&
      blockingComplianceCount == 0;

  String get title {
    if (!identityPresent) return 'Workflow identity needs repair';
    if (isLoading) return 'Checking workflow lanes and coordination...';
    if (hasLoadError) return 'Workflow readiness cannot be verified';
    if (!workflowPresent) return 'Workflow record is unavailable';
    if (workflowTerminal) return 'Workflow is already closed';
    if (activeLaneCount == 0) return 'No active workflow lanes are available';
    if (openLaneKeys.isNotEmpty) return 'Workflow lane closure is incomplete';
    if (blockingComplianceCount > 0) {
      return 'Blocking coordination remains open';
    }
    return 'All workflow lanes are closed';
  }

  String get summary {
    if (!identityPresent) {
      return 'This governed job has no workflow identity. Synchronize or repair the saved execution before closing it.';
    }
    if (isLoading) {
      return 'The current lane and blocking-coordination state is loading.';
    }
    if (hasLoadError || !workflowPresent) {
      return 'The workflow, lane or coordination records could not be verified. Synchronize before final submission.';
    }
    if (workflowTerminal) {
      return 'This workflow is already completed or cancelled and cannot accept another closure.';
    }
    if (activeLaneCount == 0) {
      return 'Finalize at least one accountable maintenance lane before final submission.';
    }
    if (openLaneKeys.isNotEmpty) {
      return 'Close ${openLaneKeys.map((lane) => lane.toUpperCase()).join(', ')} before final submission.';
    }
    if (blockingComplianceCount > 0) {
      final label = blockingComplianceCount == 1 ? 'obligation' : 'obligations';
      return 'Close $blockingComplianceCount blocking coordination $label before final submission.';
    }
    return 'The server will recheck lane versions, blocking compliance, RED applicability and equipment state.';
  }
}
