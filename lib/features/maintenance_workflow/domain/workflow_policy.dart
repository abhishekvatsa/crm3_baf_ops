import 'maintenance_lane.dart';
import 'workflow_actor.dart';
import 'workflow_policy_generated.dart';

abstract final class WorkflowPolicy {
  static const bool onlineOnlyLifecycleCommands =
      WorkflowPolicyGenerated.onlineOnlyLifecycleCommands;

  static bool mayFinalizeLaneSet(WorkflowActorContext actor) =>
      actor.hasAnyRole(WorkflowPolicyGenerated.laneSetFinalizerRoles);

  static bool mayManageLanePopulation(WorkflowActorContext actor) =>
      actor.hasAnyRole(const <String>{'admin', 'si', 'contractSupervisor'});

  static bool mayCancelWorkflow(WorkflowActorContext actor) =>
      actor.hasAnyRole(const <String>{'admin', 'si', 'contractSupervisor'});

  static bool mayMarkConditionDue(WorkflowActorContext actor) =>
      actor.hasAnyRole(const <String>{'admin', 'si', 'operations', 'shiftSupervisor'});

  static bool mayDeployEquipment(WorkflowActorContext actor) =>
      actor.hasAnyRole(const <String>{'admin', 'si', 'operations', 'shiftSupervisor'});

  static bool isRedApplicable(String assetTypeKey) =>
      WorkflowPolicyGenerated.redApplicableAssetTypes.contains(assetTypeKey.trim());

  static bool requiresStandPreparationQuestion(String assetTypeKey) =>
      WorkflowPolicyGenerated.standPreparationAssetTypes.contains(assetTypeKey.trim());

  static MaintenanceLaneDefinition lane(MaintenanceLaneId id) =>
      MaintenanceLaneCatalog.crm3.definition(id);
}
