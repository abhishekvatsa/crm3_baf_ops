import {mayPrepareRedLane} from "./authority";
import {activeLanes, assertExpectedVersion, requireMutableWorkflow} from "./documents";
import {equipmentProjectionWrite, loadEquipmentFacts, projectEquipment, withWorkflowContribution} from "./equipmentFacts";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {compliancePath, equipmentPath, lanePath, workflowPath} from "./paths";
import {cleanText, iso} from "./utils";

export const prepareRedLane: CommandHandler = async ({tx, command, context}) => {
  if (!mayPrepareRedLane(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot prepare a RED lane for work.");
  }
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (workflow.status === "completed" || workflow.status === "cancelled") {
    throw new WorkflowError("failed-precondition", "A final workflow cannot prepare RED work.");
  }
  const lanes = await activeLanes(tx, command.aggregateId);
  const redLane = lanes.find((lane) => lane.laneKey === "red");
  if (!redLane) throw new WorkflowError("not-found", "An active RED lane was not found.");
  if (redLane.status !== "pending") {
    throw new WorkflowError("failed-precondition", "RED preparation is only valid before RED acknowledgement.");
  }
  const unfinishedOtherLanes = lanes.filter((lane) => lane.laneKey !== "red" && lane.status !== "closed");
  if (unfinishedOtherLanes.length > 0) {
    throw new WorkflowError("red-lane-not-ready", "All non-RED lanes must close before RED work can begin.", {
      openLaneKeys: unfinishedOtherLanes.map((lane) => lane.laneKey ?? "unknown"),
    });
  }
  if (workflow.activeRedWork === true || workflow.awaitingPreparation === true) {
    throw new WorkflowError("failed-precondition", "RED preparation has already been decided for this workflow.");
  }
  const assetTypeKey = cleanText(workflow.assetTypeKey, "assetTypeKey");
  const assetNumber = typeof workflow.assetNumber === "number" ? workflow.assetNumber : 0;
  if (assetNumber <= 0) throw new WorkflowError("failed-precondition", "Workflow asset identity is invalid.");
  if (assetTypeKey !== "base" && assetTypeKey !== "furnace") {
    throw new WorkflowError("red-not-applicable", "RED work is only applicable to bases and furnaces.");
  }
  const preparationRequired = assetTypeKey === "furnace"
    ? (typeof command.payload.preparationRequired === "boolean" ? command.payload.preparationRequired : null)
    : false;
  if (assetTypeKey === "furnace" && preparationRequired == null) {
    throw new WorkflowError("preparation-answer-required", "Furnace preparation answer is required.");
  }

  const laneId = lanePath(command.aggregateId, "red", redLane.activationGeneration ?? 1);
  const equipmentId = equipmentPath(assetTypeKey, assetNumber);
  const equipment = await tx.get(equipmentId);
  const otherFacts = await loadEquipmentFacts(tx, assetTypeKey, assetNumber, [command.aggregateId]);
  const awaitingPreparation = preparationRequired === true;
  const contribution = awaitingPreparation ? "awaitingPreparation" : "red";
  const facts = withWorkflowContribution(otherFacts, contribution);
  const projection = projectEquipment(facts, false);
  const complianceId = awaitingPreparation ? `${command.aggregateId}_red_preparation` : null;
  const now = iso(context.serverNow);
  const nextVersion = version + 1;

  if (complianceId != null) {
    tx.create(compliancePath(complianceId), {
      linkedWorkflowId: command.aggregateId,
      linkedExecutionFirestoreId: workflow.jobExecutionId ?? command.aggregateId,
      targetLaneKey: "oprn",
      originLaneKey: "red",
      title: `Place ${assetTypeKey} ${assetNumber} on maintenance stand`,
      description: "Place the furnace on the maintenance stand and confirm preparation for RED work.",
      status: "raised",
      conditionTypeKey: "manual",
      gatesLaneFirestoreId: laneId,
      raisedByUid: context.actor.uid,
      raisedByName: context.actor.name,
      raisedAt: now,
      becameDueAt: now,
      version: 1,
      createdAt: now,
      updatedAt: now,
    });
  }
  tx.update(laneId, {
    gatingComplianceRequestId: complianceId,
    version: (redLane.version ?? 0) + 1,
    updatedAt: now,
  });
  tx.update(workflowPath(command.aggregateId), {
    status: awaitingPreparation ? "awaitingCompliance" : "assigned",
    activeRedWork: !awaitingPreparation,
    awaitingPreparation,
    redPreparationDecision: {
      preparationRequired,
      decidedByUid: context.actor.uid,
      decidedByName: context.actor.name,
      decidedAt: now,
    },
    version: nextVersion,
    updatedAt: now,
  });
  tx.set(equipmentId, equipmentProjectionWrite(equipment.data, facts, projection, {
    assetTypeKey,
    assetNumber,
    trigger: `prepareRedLane:${command.aggregateId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), true);
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: awaitingPreparation ? "red.awaitingPreparation" : "red.readyForWork",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: "red",
    payload: {preparationRequired, complianceId, equipmentState: projection.state},
  });
  tx.create(event.path, event.data);
  return {
    resultKey: awaitingPreparation ? "red-awaiting-preparation" : "red-ready-for-work",
    aggregateVersion: nextVersion,
    result: {preparationRequired, complianceId, equipmentState: projection.state},
  };
};
