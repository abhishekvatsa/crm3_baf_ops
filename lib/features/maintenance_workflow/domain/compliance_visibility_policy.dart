import '../../auth/data/user_model.dart';
import '../data/compliance_request_record.dart';

enum ComplianceRequestView { forMyLane, raisedByUs, all }

bool canUserSeeComplianceRequest(
  ComplianceRequestRecord request,
  AppUser actor,
) {
  if (!actor.isApproved) return false;
  return actor.isModuleLifecycleSupervisor ||
      actor.canAcknowledgeOrWorkMaintenanceLane(request.targetLaneKey) ||
      request.raisedByUid == actor.uid ||
      (request.originLaneKey != null &&
          actor.canAcknowledgeOrWorkMaintenanceLane(request.originLaneKey));
}

bool complianceRequestMatchesView(
  ComplianceRequestRecord request, {
  required AppUser? actor,
  required ComplianceRequestView view,
  String? restrictedTargetLane,
}) {
  if (actor == null || !actor.isApproved) return false;
  switch (view) {
    case ComplianceRequestView.forMyLane:
      final restricted = restrictedTargetLane?.trim().toLowerCase();
      if (restricted != null &&
          restricted.isNotEmpty &&
          request.targetLaneKey != restricted) {
        return false;
      }
      return actor.canAcknowledgeOrWorkMaintenanceLane(request.targetLaneKey);
    case ComplianceRequestView.raisedByUs:
      return request.raisedByUid == actor.uid ||
          (request.originLaneKey != null &&
              actor.canAcknowledgeOrWorkMaintenanceLane(request.originLaneKey));
    case ComplianceRequestView.all:
      return actor.isModuleLifecycleSupervisor;
  }
}
