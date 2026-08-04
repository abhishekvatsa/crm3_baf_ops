import '../../../planned_maintenance/data/job_module_model.dart';
import '../../../planned_maintenance/domain/planned_job_closure_guard.dart';
import '../../data/compliance_request_record.dart';
import '../../data/job_lane_record.dart';

class LaneClosureReadiness {
  final String laneStatusKey;
  final bool laneLinkageComplete;
  final int moduleCount;
  final int settledModuleCount;
  final int openModuleCount;
  final int unlinkedModuleCount;
  final int blockingComplianceCount;
  final List<PlannedJobClosureIssue> closureIssues;

  const LaneClosureReadiness({
    required this.laneStatusKey,
    required this.laneLinkageComplete,
    required this.moduleCount,
    required this.settledModuleCount,
    required this.openModuleCount,
    required this.unlinkedModuleCount,
    required this.blockingComplianceCount,
    required this.closureIssues,
  });

  factory LaneClosureReadiness.fromRecords({
    required JobLaneRecord lane,
    required Iterable<JobModuleInstance> modules,
    required Iterable<ComplianceRequestRecord> complianceRequests,
  }) {
    final laneDocumentId = lane.firestoreId?.trim();
    final linkageComplete = laneDocumentId != null && laneDocumentId.isNotEmpty;
    final activeModules = modules
        .where((module) => !module.isDeleted)
        .toList(growable: false);
    final laneModules =
        linkageComplete
            ? activeModules
                .where(
                  (module) =>
                      module.workflowLaneFirestoreId?.trim() == laneDocumentId,
                )
                .toList(growable: false)
            : const <JobModuleInstance>[];
    final unlinkedModules =
        activeModules.where((module) {
          final explicitLaneId = module.workflowLaneFirestoreId?.trim();
          return module.effectiveLaneKey == lane.laneKey &&
              (explicitLaneId == null || explicitLaneId.isEmpty);
        }).length;
    final openModules = laneModules
        .where((module) => module.isOpenForWork)
        .toList(growable: false);
    final blockingPath = linkageComplete ? 'job_lanes/$laneDocumentId' : null;
    final blockingCompliance =
        blockingPath == null
            ? 0
            : complianceRequests.where((request) {
              return !request.isDeleted &&
                  _isOpenCompliance(request.statusKey) &&
                  request.gatesLaneFirestoreId?.trim() == blockingPath;
            }).length;

    return LaneClosureReadiness(
      laneStatusKey: lane.statusKey,
      laneLinkageComplete: linkageComplete,
      moduleCount: laneModules.length,
      settledModuleCount: laneModules.length - openModules.length,
      openModuleCount: openModules.length,
      unlinkedModuleCount: unlinkedModules,
      blockingComplianceCount: blockingCompliance,
      closureIssues: PlannedJobClosureGuard.collectIssues(laneModules),
    );
  }

  bool get isClosed => laneStatusKey == 'closed';

  bool get isAcknowledged => laneStatusKey == 'acknowledged' || isClosed;

  List<String> get blockingReasons {
    if (isClosed) return const <String>[];

    final reasons = <String>[];
    if (!laneLinkageComplete) {
      reasons.add('Lane linkage is incomplete');
    }
    if (!isAcknowledged) {
      reasons.add('Lane acknowledgement is required');
    }
    if (unlinkedModuleCount > 0) {
      reasons.add(
        '$unlinkedModuleCount ${unlinkedModuleCount == 1 ? 'module lacks' : 'modules lack'} authoritative lane linkage',
      );
    }
    if (openModuleCount > 0) {
      reasons.add(
        '$openModuleCount ${openModuleCount == 1 ? 'module is' : 'modules are'} still open',
      );
    }
    for (final issue in closureIssues) {
      if (issue.type == PlannedJobClosureIssueType.openRequiredModule) {
        continue;
      }
      reasons.add(issue.message);
    }
    if (blockingComplianceCount > 0) {
      reasons.add(
        '$blockingComplianceCount blocking compliance '
        '${blockingComplianceCount == 1 ? 'request is' : 'requests are'} unresolved',
      );
    }
    return List<String>.unmodifiable(reasons);
  }

  bool get readyForClosure =>
      !isClosed && laneLinkageComplete && blockingReasons.isEmpty;

  double? get moduleProgress {
    if (moduleCount == 0) return null;
    return settledModuleCount / moduleCount;
  }

  String get summary {
    if (isClosed) {
      return moduleCount == 0
          ? 'Closed'
          : 'Closed - $moduleCount ${moduleCount == 1 ? 'module' : 'modules'}';
    }

    final progress =
        moduleCount == 0
            ? 'No modules assigned'
            : '$settledModuleCount of $moduleCount modules complete or submitted';
    final reasons = blockingReasons;
    if (reasons.isEmpty) return '$progress - ready to close';
    final additional = reasons.length > 1 ? ' (+${reasons.length - 1})' : '';
    return '$progress - ${reasons.first}$additional';
  }

  static bool _isOpenCompliance(String statusKey) {
    return statusKey != 'confirmedClosed' &&
        statusKey != 'superseded' &&
        statusKey != 'cancelled';
  }
}
