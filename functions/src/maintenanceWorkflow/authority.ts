import {COMMAND_AUTHORITY_ROLES, LANE_POLICY, LANE_SET_FINALIZER_ROLES} from "./policy.generated";
import {WorkflowError} from "./errors";
import {Actor, LaneKey, RoleKey} from "./types";

const hasAny = (actor: Actor, roles: readonly string[]): boolean =>
  roles.some((role) => actor.roles.has(role as RoleKey));

export const mayFinalizeLaneSet = (actor: Actor): boolean => hasAny(actor, LANE_SET_FINALIZER_ROLES);
export const mayAcknowledgeLane = (actor: Actor, lane: LaneKey): boolean => hasAny(actor, LANE_POLICY[lane].ackRoles);
export const mayWorkLane = (actor: Actor, lane: LaneKey): boolean => hasAny(actor, LANE_POLICY[lane].workRoles);
export const mayCloseLane = (actor: Actor, lane: LaneKey): boolean => hasAny(actor, LANE_POLICY[lane].closeRoles);
export const mayManageLanePopulation = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.manageLanePopulation);
export const mayCancelWorkflow = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.cancelWorkflow);
export const mayFinalizeJob = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.finalizeJob);
export const mayMarkConditionDue = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.markConditionDue);
export const mayDeployEquipment = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.deployEquipment);
export const mayReconcileEquipment = (actor: Actor): boolean => hasAny(actor, COMMAND_AUTHORITY_ROLES.reconcileEquipment);
export const mayPrepareRedLane = (actor: Actor): boolean =>
  hasAny(actor, COMMAND_AUTHORITY_ROLES.prepareRedLane);
export const mayReopenWorkflowModule = (actor: Actor): boolean =>
  hasAny(actor, COMMAND_AUTHORITY_ROLES.reopenWorkflowModule);
export const mayCoordinateCompliance = (actor: Actor): boolean =>
  hasAny(actor, COMMAND_AUTHORITY_ROLES.raiseComplianceCoordination);
export const mayManageUnscopedCompliance = (actor: Actor): boolean =>
  hasAny(actor, ["admin", "si"]);

export const assertMayRaiseCompliance = (
  actor: Actor,
  lane: LaneKey,
): void => {
  if (!mayWorkLane(actor, lane) && !mayCoordinateCompliance(actor)) {
    throw new WorkflowError(
      "permission-denied",
      `Actor is not authorised to raise a request from ${lane}.`,
      {lane, action: "raiseCompliance"},
    );
  }
};

export const assertLaneAuthority = (
  actor: Actor,
  lane: LaneKey,
  action: "acknowledge" | "work" | "close",
): void => {
  const allowed = action === "acknowledge" ? mayAcknowledgeLane(actor, lane)
    : action === "work" ? mayWorkLane(actor, lane) : mayCloseLane(actor, lane);
  if (!allowed) throw new WorkflowError("permission-denied", `Actor is not authorised to ${action} ${lane}.`, {lane, action});
};

export const eventRepresentation = (actor: Actor, lane: LaneKey): {
  representedLaneKey: LaneKey | null; delegationBasis: string | null;
} => {
  const policy = LANE_POLICY[lane];
  if (policy.delegated === true) {
    if (!hasAny(actor, policy.ackRoles)) {
      throw new WorkflowError("unauthorized-represented-lane", `Actor cannot represent lane ${lane}.`);
    }
    return {representedLaneKey: lane, delegationBasis: policy.delegationBasis ?? null};
  }
  return {representedLaneKey: null, delegationBasis: null};
};
