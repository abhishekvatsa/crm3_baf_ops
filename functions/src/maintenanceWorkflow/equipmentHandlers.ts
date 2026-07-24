import {mayDeployEquipment, mayReconcileEquipment} from "./authority";
import {equipmentProjectionWrite, loadEquipmentFacts, projectEquipment} from "./equipmentFacts";
import {assertExpectedVersion} from "./documents";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {equipmentPath} from "./paths";
import {cleanText, intValue, iso} from "./utils";

export const reconcileEquipment: CommandHandler = async ({tx, command, context}) => {
  if (!mayReconcileEquipment(context.actor)) throw new WorkflowError("permission-denied", "Only Admin/SI may reconcile equipment state.");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  const assetNumber = intValue(command.payload.assetNumber, "assetNumber", 1);
  const path = equipmentPath(assetTypeKey, assetNumber);
  const current = await tx.get(path);
  const currentVersion = assertExpectedVersion(current.data ?? {}, command.expectedVersion);
  const facts = await loadEquipmentFacts(tx, assetTypeKey, assetNumber);
  const operationsDeployed = current.data?.state === "inService" &&
    facts.activeNonRedMaintenanceCount === 0 &&
    facts.activeRedWorkCount === 0 &&
    facts.awaitingPreparationCount === 0;
  const projection = projectEquipment(facts, operationsDeployed);
  const now = iso(context.serverNow);
  const write = equipmentProjectionWrite(current.data, facts, projection, {
    assetTypeKey,
    assetNumber,
    trigger: `reconcile:${command.commandId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  });
  tx.set(path, write, true);
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "equipment.reconciled", actor: context.actor, at: context.serverNow, commandId: command.commandId, payload: {assetTypeKey, assetNumber, state: projection.state}});
  tx.create(event.path, event.data);
  return {resultKey: "equipment-reconciled", aggregateVersion: currentVersion + 1, result: {state: projection.state, assetTypeKey, assetNumber}};
};

export const deployEquipment: CommandHandler = async ({tx, command, context}) => {
  if (!mayDeployEquipment(context.actor)) throw new WorkflowError("permission-denied", "Actor cannot deploy equipment.");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  const assetNumber = intValue(command.payload.assetNumber, "assetNumber", 1);
  const path = equipmentPath(assetTypeKey, assetNumber);
  const current = await tx.get(path);
  if (!current.exists || current.data == null) throw new WorkflowError("not-found", "Equipment status row was not found.");
  const currentVersion = assertExpectedVersion(current.data, command.expectedVersion);
  const facts = await loadEquipmentFacts(tx, assetTypeKey, assetNumber);
  if (facts.activeNonRedMaintenanceCount > 0 || facts.activeRedWorkCount > 0 || facts.awaitingPreparationCount > 0) {
    throw new WorkflowError("equipment-state-conflict", "Equipment with open workflow work cannot be deployed.", facts);
  }
  if (current.data.state !== "available") throw new WorkflowError("failed-precondition", "Only available equipment may be placed in service.");
  const now = iso(context.serverNow);
  tx.update(path, {
    previousState: "available",
    state: "inService",
    inServiceSince: now,
    transitionTrigger: `operationsDeploy:${command.commandId}`,
    lastTransitionAt: now,
    lastTransitionByUid: context.actor.uid,
    lastTransitionByName: context.actor.name,
    version: currentVersion + 1,
    updatedAt: now,
  });
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "equipment.deployed", actor: context.actor, at: context.serverNow, commandId: command.commandId, payload: {assetTypeKey, assetNumber}});
  tx.create(event.path, event.data);
  return {resultKey: "equipment-deployed", aggregateVersion: currentVersion + 1, result: {state: "inService", assetTypeKey, assetNumber}};
};
