import {mayDeployEquipment, mayReconcileEquipment} from "./authority";
import {
  equipmentProjectionWrite,
  assertEquipmentProjectionIdentity,
  loadEquipmentFacts,
  projectEquipment,
} from "./equipmentFacts";
import {assertExpectedVersion} from "./documents";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {equipmentIdentity, equipmentPathForIdentity} from "./paths";
import {cleanText, intValue, iso} from "./utils";
import {equipmentProjectionArchive, equipmentRebindingEvidenceDigest,
  resolveEquipmentRegistrySubject, resolveReviewedEquipmentRegistryRebinding} from "./equipmentRegistrySubject";
import {JsonMap} from "./types";

export const reconcileEquipment: CommandHandler = async ({tx, command, context}) => {
  if (!mayReconcileEquipment(context.actor)) throw new WorkflowError("permission-denied", "Only Admin/SI may reconcile equipment state.");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  const assetNumber = intValue(command.payload.assetNumber, "assetNumber", 1);
  let identity = equipmentIdentity(
    assetTypeKey,
    assetNumber,
    command.payload.assetClassId,
    command.payload.assetInstanceId,
  );
  const path = equipmentPathForIdentity(identity);
  const current = await tx.get(path);
  const currentVersion = assertExpectedVersion(current.data ?? {}, command.expectedVersion);
  const rebinding = command.payload.registryRebinding != null;
  const reviewed = rebinding ? await resolveReviewedEquipmentRegistryRebinding(tx, identity,
    current.data, command.payload.registryRebinding) : null;
  const subject = reviewed ?? await resolveEquipmentRegistrySubject(tx, identity, current.data);
  identity = subject.identity;
  const facts = await loadEquipmentFacts(tx, identity);
  if (current.data != null && !rebinding) assertEquipmentProjectionIdentity(current.data, identity);
  const operationsDeployed = !rebinding && subject.permitsDeployment && current.data?.state === "inService" &&
    facts.activeNonRedMaintenanceCount === 0 &&
    facts.activeRedWorkCount === 0 &&
    facts.awaitingPreparationCount === 0;
  const projection = projectEquipment(facts, operationsDeployed);
  const now = iso(context.serverNow);
  const write = {...equipmentProjectionWrite(rebinding ? null : current.data, facts, projection, {
    assetTypeKey,
    assetNumber,
    assetClassId: identity.assetClassId,
    assetInstanceId: identity.assetInstanceId,
    trigger: `reconcile:${command.commandId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), version: currentVersion + 1};
  const eventPayload: JsonMap = {assetTypeKey, assetNumber, state: projection.state,
    ...(reviewed == null ? {} : {registryRebinding: {...reviewed.evidence,
      replacementProjectionJson: equipmentProjectionArchive(write)}})};
  // A replacement starts its own projection. Merge would retain old physical
  // subject fields that were never assessed for the replacement.
  tx.set(path, write, !rebinding);
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "equipment.reconciled", actor: context.actor, at: context.serverNow, commandId: command.commandId, payload: eventPayload});
  tx.create(event.path, event.data);
  return {resultKey: "equipment-reconciled", aggregateVersion: currentVersion + 1, result: {state: projection.state, assetTypeKey, assetNumber,
    ...(reviewed == null ? {} : {rebound: true, assetClassId: identity.assetClassId, assetInstanceId: identity.assetInstanceId,
      auditId: command.commandId, rebindingEvidenceSha256: equipmentRebindingEvidenceDigest(event.data)})}};
};

export const deployEquipment: CommandHandler = async ({tx, command, context}) => {
  if (!mayDeployEquipment(context.actor)) throw new WorkflowError("permission-denied", "Actor cannot deploy equipment.");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  const assetNumber = intValue(command.payload.assetNumber, "assetNumber", 1);
  let identity = equipmentIdentity(
    assetTypeKey,
    assetNumber,
    command.payload.assetClassId,
    command.payload.assetInstanceId,
  );
  const path = equipmentPathForIdentity(identity);
  const current = await tx.get(path);
  if (!current.exists || current.data == null) throw new WorkflowError("not-found", "Equipment status row was not found.");
  const currentVersion = assertExpectedVersion(current.data, command.expectedVersion);
  const subject = await resolveEquipmentRegistrySubject(tx, identity, current.data);
  identity = subject.identity;
  assertEquipmentProjectionIdentity(current.data, identity);
  const facts = await loadEquipmentFacts(tx, identity);
  if (facts.activeNonRedMaintenanceCount > 0 || facts.activeRedWorkCount > 0 || facts.awaitingPreparationCount > 0) {
    throw new WorkflowError("equipment-state-conflict", "Equipment with open workflow work cannot be deployed.", facts);
  }
  if (current.data.state !== "available") throw new WorkflowError("failed-precondition", "Only available equipment may be placed in service.");
  // This is workflow deployment, not clearance of independent conditions.
  // Missing or contradictory registry identity cannot prove release authority.
  if (!subject.permitsDeployment) {
    throw new WorkflowError(
      "equipment-state-conflict",
      "The register has this equipment administratively out of service. Return it to service in the register before deploying it.",
      {
        reasonCode: "equipment-administratively-out-of-service",
        assetClassId: identity.assetClassId,
        assetInstanceId: identity.assetInstanceId,
      },
    );
  }
  const now = iso(context.serverNow);
  tx.update(path, {
    assetClassId: identity.assetClassId,
    assetInstanceId: identity.assetInstanceId,
    previousState: "available",
    state: "inService",
    inServiceSince: now,
    availableSince: null,
    activeNonRedMaintenanceCount: facts.activeNonRedMaintenanceCount,
    activeRedWorkCount: facts.activeRedWorkCount,
    awaitingPreparationCount: facts.awaitingPreparationCount,
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
