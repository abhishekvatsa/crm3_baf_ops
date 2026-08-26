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
import {ticketLanePlan, ticketRouteLane} from "./ticketLanePlan";
import {COMMAND_AUTHORITY_ROLES} from "./policy.generated";

const AUTHORITY_SCOPE_SCHEMA_VERSION = 1 as const;

const isIssueSupervisor = (actor: Actor): boolean =>
  ["admin", "si", "contractSupervisor", "shiftSupervisor"]
    .some((role) => actor.roles.has(role as RoleKey));

const STATIC_CAPABILITY_BY_COMMAND: Readonly<
  Partial<Record<WorkflowCommandType, WorkflowAuthorityCapability>>
> = {
  createLegacyWorkflowJob: "laneSet.finalize",
  createMaintenanceTicket: "ticket.create",
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
  reconfigureMaintenanceTicketLanes: "ticket.lanes.manage",
  closeMaintenanceTicketWithoutResolution: "ticket.closeWithoutResolution",
  reopenMaintenanceTicket: "ticket.reopen",
  correctMaintenanceTicket: "ticket.correct",
  upsertFrequentIssueDefinition: "issueDefinition.manage",
  setFrequentIssueDefinitionStatus: "issueDefinition.manage",
  upsertMaintenanceClassDefinition: "maintenanceClass.manage",
  setMaintenanceClassDefinitionStatus: "maintenanceClass.manage",
  classifyMaintenanceExecution: "maintenance.classify",
  classifyMaintenanceTicket: "maintenance.classify",
  recordHistoricalMaintenance: "maintenanceHistory.record",
  upsertMaintenancePlan: "maintenancePlan.manage",
  setMaintenancePlanStatus: "maintenancePlan.manage",
  completeMaintenancePlan: "maintenancePlan.manage",
  upsertInspectionDefinition: "inspectionDefinition.manage",
  setInspectionDefinitionStatus: "inspectionDefinition.manage",
  createInspectionCampaign: "inspectionCampaign.manage",
  setInspectionCampaignStatus: "inspectionCampaign.manage",
  addInspectionCampaignTargets: "inspectionCampaign.manage",
  setInspectionTargetDisposition: "inspectionCampaign.manage",
  recordInspectionObservation: "inspection.observe",
  linkInspectionObservationIssue: "inspectionIssue.link",
  verifyInspectionFinding: "inspection.observe",
  adjudicateInspectionFinding: "inspectionFinding.adjudicate",
  releaseFurnaceStuckup: "integrity.supervise",
  adjudicateFurnaceStuckup: "integrity.adjudicate",
  raiseCriticalAlarm: "criticalAlarm.raise",
  provideCriticalAlarmDetails: "criticalAlarm.details",
  confirmCriticalAlarmSupport: "criticalAlarm.support",
  resolveCriticalAlarm: "criticalAlarm.resolve",
  withdrawCriticalAlarmInError: "criticalAlarm.withdraw",
  upsertCriticalAlarmContact: "criticalAlarm.contacts.manage",
  setCriticalAlarmContactStatus: "criticalAlarm.contacts.manage",
  purgePilotBusinessRecord: "pilotRecord.purge",
};

const LANE_CAPABILITIES = new Set<WorkflowAuthorityCapability>([
  "lane.acknowledge",
  "lane.work",
  "lane.close",
  "compliance.raise",
  "ticket.acknowledge",
  "ticket.complete",
]);

const STATIC_CAPABILITIES = new Set<WorkflowAuthorityCapability>([
  "ticket.create",
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
  "ticket.closeWithoutResolution",
  "ticket.lanes.manage",
  "ticket.reopen",
  "issueDefinition.manage",
  "maintenanceClass.manage",
  "maintenance.classify",
  "maintenanceHistory.record",
  "maintenancePlan.manage",
  "inspectionDefinition.manage",
  "inspectionCampaign.manage",
  "inspection.observe",
  "inspectionIssue.link",
  "inspectionFinding.adjudicate",
  "integrity.supervise",
  "integrity.adjudicate",
  "criticalAlarm.raise",
  "criticalAlarm.details",
  "criticalAlarm.support",
  "criticalAlarm.resolve",
  "criticalAlarm.withdraw",
  "criticalAlarm.contacts.manage",
  "pilotRecord.purge",
]);

const hasPolicyRole = (actor: Actor, key: string): boolean =>
  (COMMAND_AUTHORITY_ROLES[key] ?? []).some((role) =>
    actor.roles.has(role as RoleKey),
  );

const laneScope = (
  capability: "lane.acknowledge" | "lane.work" | "lane.close" |
    "compliance.raise" | "ticket.acknowledge" | "ticket.complete",
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
    "compliance.raise" | "ticket.acknowledge" | "ticket.complete"
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
          "compliance.raise" | "ticket.acknowledge" | "ticket.complete",
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
    "compliance.raise" | "ticket.acknowledge" | "ticket.complete"
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
  case "ticket.create":
    // The callable and transaction have already revalidated the canonical
    // approved-user capsule. Every approved role may raise an issue.
    return;
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
    if (isIssueSupervisor(actor)) return;
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "acknowledge");
    return;
  case "ticket.complete":
    if (isIssueSupervisor(actor)) return;
    assertLaneAuthority(actor, scope.laneKey as LaneKey, "close");
    return;
  case "ticket.lanes.manage":
    if (!isIssueSupervisor(actor)) denied();
    return;
  case "ticket.reopen":
    if (!actor.roles.has("admin") && !actor.roles.has("si") &&
        !actor.roles.has("operations")) denied();
    return;
  case "ticket.correct":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "ticket.closeWithoutResolution":
    if (!actor.roles.has("admin")) denied();
    return;
  case "pilotRecord.purge":
    if (!actor.roles.has("admin")) denied();
    return;
  case "issueDefinition.manage":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "maintenanceClass.manage":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "maintenanceHistory.record":
    if (!actor.roles.has("admin")) denied();
    return;
  case "maintenance.classify":
  case "maintenancePlan.manage":
  case "inspectionCampaign.manage":
    if (!["admin", "si", "contractSupervisor", "shiftSupervisor"]
      .some((role) => actor.roles.has(role as RoleKey))) denied();
    return;
  case "inspectionDefinition.manage":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "inspectionFinding.adjudicate":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "inspection.observe":
  case "inspectionIssue.link":
    return;
  case "integrity.supervise":
    if (!["admin", "si", "contractSupervisor", "shiftSupervisor"]
      .some((role) => actor.roles.has(role as RoleKey))) denied();
    return;
  case "integrity.adjudicate":
    if (!actor.roles.has("admin") && !actor.roles.has("si")) denied();
    return;
  case "criticalAlarm.raise":
  case "criticalAlarm.details":
  case "criticalAlarm.withdraw":
    return;
  case "criticalAlarm.support":
    if (!hasPolicyRole(actor, "confirmCriticalAlarmSupport")) denied();
    return;
  case "criticalAlarm.resolve":
    if (!hasPolicyRole(actor, "resolveCriticalAlarm")) denied();
    return;
  case "criticalAlarm.contacts.manage":
    if (!hasPolicyRole(actor, "manageCriticalAlarmContacts")) denied();
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
      "compliance.raise" | "ticket.acknowledge" | "ticket.complete"
    >);
  }

  switch (command.commandType) {
  case "startIssueCoordination": {
    if (command.payload.originRoute != null) {
      return laneScope(
        "compliance.raise",
        ticketRouteLane(cleanText(command.payload.originRoute, "originRoute")),
      );
    }
    const ticketId = cleanText(command.payload.ticketId, "ticketId");
    const ticket = await tx.get(maintenancePath(ticketId));
    if (!ticket.exists || ticket.data == null) {
      throw new WorkflowError(
        "not-found",
        "Maintenance ticket was not found.",
        {reasonCode: "maintenance-ticket-not-found"},
      );
    }
    const plan = ticketLanePlan(ticket.data);
    const originRoute = command.payload.originRoute == null ?
      plan.assigned[0] : cleanText(command.payload.originRoute, "originRoute");
    if (!plan.assigned.includes(originRoute)) {
      throw new WorkflowError(
        "failed-precondition",
        "The Operations request origin is not an active issue lane.",
        {reasonCode: "issue-coordination-origin-lane-inactive"},
      );
    }
    return laneScope(
      "compliance.raise",
      ticketRouteLane(originRoute),
    );
  }
  case "acknowledgeMaintenanceTicket": {
    if (command.payload.lane != null) {
      return laneScope(
        "ticket.acknowledge",
        ticketRouteLane(cleanText(command.payload.lane, "lane")),
      );
    }
    const ticket = await tx.get(maintenancePath(command.aggregateId));
    if (!ticket.exists || ticket.data == null) {
      throw new WorkflowError(
        "not-found",
        "Maintenance ticket was not found.",
        {reasonCode: "maintenance-ticket-not-found"},
      );
    }
    const plan = ticketLanePlan(ticket.data);
    const route = command.payload.lane == null ? plan.assigned[0] :
      cleanText(command.payload.lane, "lane");
    const lane = ticketRouteLane(route);
    return laneScope("ticket.acknowledge", lane);
  }
  case "completeMaintenanceTicketLane":
    return laneScope(
      "ticket.complete",
      ticketRouteLane(cleanText(command.payload.lane, "lane")),
    );
  case "resolveMaintenanceTicket": {
    const ticket = await tx.get(maintenancePath(command.aggregateId));
    if (!ticket.exists || ticket.data == null) {
      throw new WorkflowError(
        "not-found",
        "Maintenance ticket was not found.",
        {reasonCode: "maintenance-ticket-not-found"},
      );
    }
    const plan = ticketLanePlan(ticket.data);
    return plan.assigned.length === 1 ?
      laneScope("ticket.complete", ticketRouteLane(plan.assigned[0])) :
      staticScope("ticket.lanes.manage");
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
    return compliance.raisedUnderCoordination === true &&
      compliance.originLaneKey != null ?
      laneScope(
        "compliance.raise",
        laneKey(compliance.originLaneKey, "originLaneKey"),
      ) :
      unscopedComplianceOrLane(
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
