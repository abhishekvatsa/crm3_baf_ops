import {
  assertLaneAuthority,
  mayCancelWorkflow,
  mayDeployEquipment,
  mayFinalizeJob,
  mayFinalizeLaneSet,
  mayManageLanePopulation,
  mayManageUnscopedCompliance,
  mayCoordinateCompliance,
  mayMarkConditionDue,
  mayPrepareRedLane,
  mayReconcileEquipment,
  mayReopenWorkflowModule,
} from "./authority";
import {requireComplianceForWorkflow} from "./documents";
import {WorkflowError} from "./errors";
import {maintenancePath} from "./paths";
import {WorkflowTransaction} from "./store";
import {
  Actor,
  JsonMap,
  LaneKey,
  RoleKey,
  WorkflowAuthorityCapability,
  WorkflowAuthorityScope,
  WorkflowCommand,
  WorkflowCommandType,
} from "./types";
import {cleanText, laneKey} from "./utils";

const AUTHORITY_SCOPE_SCHEMA_VERSION = 1 as const;

const STATIC_CAPABILITY_BY_COMMAND: Readonly<
  Partial<Record<WorkflowCommandType, WorkflowAuthorityCapability>>
> = {
  createLegacyWorkflowJob: "laneSet.finalize",
  finalizeLaneSet: "laneSet.finalize",
  addLane: "lanePopulation.manage",
  removeLane: "lanePopulation.manage",
  terminateLane: "lanePopulation.manage",
  cancelWorkflow: "workflow.cancel",
  confirmConditionAndReactivate: "condition.markDue",
  prepareRedLane: "redLane.prepare",
  reopenWorkflowModule: "workflowModule.reopen",
  finalizeJob: "job.finalize",
  deployEquipment: "equipment.deploy",
  reconcileEquipment: "equipment.reconcile",
  correctMaintenanceTicket: "ticket.correct",
};

const LANE_CAPABILITIES = new Set<WorkflowAuthorityCapability>([
  "lane.acknowledge",
  "lane.work",
  "lane.close",
  "compliance.raise",
  "ticket.acknowledge",
]);

const STATIC_CAPABILITIES = new Set<WorkflowAuthorityCapability>([
  "laneSet.finalize",
  "lanePopulation.manage",
  "workflow.cancel",
  "condition.markDue",
  "redLane.prepare",
  "workflowModule.reopen",
  "job.finalize",
  "equipment.deploy",
  "equipment.reconcile",
  "compliance.unscoped.manage",
  "ticket.correct",
]);

const laneScope = (
  capability: "lane.acknowledge" | "lane.work" | "lane.close" |
    "compliance.raise" | "ticket.acknowledge",
  lane: LaneKey,
): WorkflowAuthorityScope => ({
  schemaVersion: AUTHORITY_SCOPE_SCHEMA_VERSION,
  capability,
  laneKey: lane,
});

const staticScope = (
  capability: Exclude<
    WorkflowAuthorityCapability,
    "lane.acknowledge" | "lane.work" | "lane.close" |
    "compliance.raise" | "ticket.acknowledge"
  >,
): WorkflowAuthorityScope => ({
  schemaVersion: AUTHORITY_SCOPE_SCHEMA_VERSION,
  capability,
});

const unscopedComplianceOrLane = (
  rawLane: unknown,
  field: string,
): WorkflowAuthorityScope => rawLane == null ?
  staticScope("compliance.unscoped.manage") :
  laneScope("lane.work", laneKey(rawLane, field));

export const canonicalWorkflowAuthorityScope = (
  value: unknown,
): WorkflowAuthorityScope | null => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const data = value as JsonMap;
  const keys = Object.keys(data).sort();
  if (data.schemaVersion !== AUTHORITY_SCOPE_SCHEMA_VERSION ||
      typeof data.capability !== "string") {
    return null;
  }
  const capability = data.capability as WorkflowAuthorityCapability;
  if (LANE_CAPABILITIES.has(capability)) {
    if (keys.join(",") !== "capability,laneKey,schemaVersion" ||
        typeof data.laneKey !== "string") {
      return null;
    }
    try {
      return laneScope(
        capability as "lane.acknowledge" | "lane.work" | "lane.close" |
          "compliance.raise" | "ticket.acknowledge",
        laneKey(data.laneKey, "authorityScope.laneKey"),
      );
    } catch {
      return null;
    }
  }
  if (!STATIC_CAPABILITIES.has(capability) ||
      keys.join(",") !== "capability,schemaVersion") {
    return null;
  }
  return staticScope(capability as Exclude<
    WorkflowAuthorityCapability,
    "lane.acknowledge" | "lane.work" | "lane.close" |
    "compliance.raise" | "ticket.acknowledge"
  >);
};

export const assertWorkflowAuthorityScope = (
  actor: Actor,
  scope: WorkflowAuthorityScope,
): void => {
  const denied = (): never => {
    throw new WorkflowError(
      "permission-denied",
      "The current actor is not authorized for this workflow command.",
      {
        reasonCode: "workflow-command-authority-required",
        capability: scope.capability,
        laneKey: scope.laneKey ?? null,
      },
    );
  };

  switch (scope.capability) {
  case "lane.acknowledge":
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "acknowledge");
    return;
  case "lane.work":
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "work");
    return;
  case "lane.close":
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "close");
    return;
  case "compliance.raise":
    if (mayCoordinateCompliance(actor)) return;
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "work");
    return;
  case "ticket.acknowledge":
    if (["admin", "si", "contractSupervisor", "shiftSupervisor"]
      .some((role) => actor.roles.has(role as RoleKey))) return;
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "acknowledge");
    return;
  case "ticket.correct":
    if (!actor.roles.has("admin")) denied();
    return;
  case "laneSet.finalize":
    if (!mayFinalizeLaneSet(actor)) denied();
    return;
  case "lanePopulation.manage":
    if (!mayManageLanePopulation(actor)) denied();
    return;
  case "workflow.cancel":
    if (!mayCancelWorkflow(actor)) denied();
    return;
  case "condition.markDue":
    if (!mayMarkConditionDue(actor)) denied();
    return;
  case "redLane.prepare":
    if (!mayPrepareRedLane(actor)) denied();
    return;
  case "workflowModule.reopen":
    if (!mayReopenWorkflowModule(actor)) denied();
    return;
  case "job.finalize":
    if (!mayFinalizeJob(actor)) denied();
    return;
  case "equipment.deploy":
    if (!mayDeployEquipment(actor)) denied();
    return;
  case "equipment.reconcile":
    if (!mayReconcileEquipment(actor)) denied();
    return;
  case "compliance.unscoped.manage":
    if (!mayManageUnscopedCompliance(actor)) denied();
    return;
  default:
    denied();
  }
};

export const resolveFreshWorkflowAuthorityScope = async (
  tx: WorkflowTransaction,
  command: WorkflowCommand,
): Promise<WorkflowAuthorityScope> => {
  const staticCapability = STATIC_CAPABILITY_BY_COMMAND[command.commandType];
  if (staticCapability != null) {
    return staticScope(staticCapability as Exclude<
      WorkflowAuthorityCapability,
      "lane.acknowledge" | "lane.work" | "lane.close" |
      "compliance.raise" | "ticket.acknowledge"
    >);
  }

  switch (command.commandType) {
  case "acknowledgeMaintenanceTicket": {
    const ticket = await tx.get(maintenancePath(command.aggregateId));
    if (!ticket.exists || ticket.data == null) {
      throw new WorkflowError(
        "not-found",
        "Maintenance ticket was not found.",
        {reasonCode: "maintenance-ticket-not-found"},
      );
    }
    const route = cleanText(ticket.data.routedTo, "routedTo");
    const lane: LaneKey = route === "electrical" ? "elec" :
      route === "mechanical" ? "mech" :
      route === "instrumentation" ? "inst" :
      route === "operations" || route === "shiftInCharge" ? "oprn" :
      route === "emd" ? "emd" :
      route === "refractory" ? "red" :
      route === "others" ? "shared" :
      (() => {
        throw new WorkflowError(
          "failed-precondition",
          "Maintenance ticket routing is malformed.",
          {reasonCode: "maintenance-ticket-route-invalid", routedTo: route},
        );
      })();
    return laneScope("ticket.acknowledge", lane);
  }
  case "acknowledgeLane":
    return laneScope(
      "lane.acknowledge",
      laneKey(command.payload.laneKey),
    );
  case "closeLane":
    return laneScope("lane.close", laneKey(command.payload.laneKey));
  case "raiseCompliance":
    return laneScope(
      "compliance.raise",
      laneKey(command.payload.originLaneKey, "originLaneKey"),
    );
  case "acknowledgeCompliance":
  case "markComplianceComplied":
  case "proposeCounterCondition": {
    const complianceId = cleanText(
      command.payload.complianceId,
      "complianceId",
    );
    const compliance = await requireComplianceForWorkflow(
      tx,
      complianceId,
      command.aggregateId,
    );
    return laneScope(
      "lane.work",
      laneKey(compliance.targetLaneKey, "targetLaneKey"),
    );
  }
  case "returnComplianceForCorrection":
  case "confirmComplianceClosed":
  case "decideCounterCondition": {
    const complianceId = cleanText(
      command.payload.complianceId,
      "complianceId",
    );
    const compliance = await requireComplianceForWorkflow(
      tx,
      complianceId,
      command.aggregateId,
    );
    return unscopedComplianceOrLane(
      compliance.originLaneKey,
      "originLaneKey",
    );
  }
  default:
    throw new WorkflowError(
      "unsupported-workflow-command",
      `Unsupported command ${command.commandType}.`,
    );
  }
};
