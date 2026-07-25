import {mayFinalizeLaneSet} from "./authority";
import {equipmentFactsFromProjection, equipmentProjectionWrite, projectEquipment, withWorkflowContribution} from "./equipmentFacts";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {equipmentPath, executionPath, workflowPath} from "./paths";
import {cleanText, intValue, iso, optionalText, stringArray} from "./utils";

const assetTypes = new Set(["base", "furnace", "forceCooler", "innerCover"]);

const validAssetNumber = (assetType: string, number: number): boolean => {
  if (assetType === "base") return (number >= 101 && number <= 124) || (number >= 201 && number <= 223);
  if (assetType === "furnace") return number >= 1 && number <= 26;
  if (assetType === "forceCooler") return number >= 1 && number <= 25;
  return assetType === "innerCover" && number > 0;
};

export const createLegacyWorkflowJob: CommandHandler = async ({tx, command, context}) => {
  if (!mayFinalizeLaneSet(context.actor)) {
    throw new WorkflowError("permission-denied", "Only Admin, SI or Contract Supervisor may create an unclassified workflow job.");
  }
  if (command.expectedVersion !== 0) {
    throw new WorkflowError("workflow-version-conflict", "New workflow job creation must start at version zero.");
  }
  const executionId = cleanText(command.payload.executionId, "executionId");
  if (executionId !== command.aggregateId || executionId.includes("/")) {
    throw new WorkflowError("invalid-argument", "Execution identity must equal the aggregate identity and be a Firestore document ID.");
  }
  const templateFirestoreId = cleanText(command.payload.templateFirestoreId, "templateFirestoreId");
  const templateName = cleanText(command.payload.templateName, "templateName");
  const assetTypeKey = cleanText(command.payload.assetTypeKey, "assetTypeKey");
  if (!assetTypes.has(assetTypeKey)) throw new WorkflowError("invalid-argument", "Unsupported asset type.");
  const assetNumber = intValue(command.payload.assetNumber, "assetNumber", 1);
  if (!validAssetNumber(assetTypeKey, assetNumber)) {
    throw new WorkflowError("invalid-argument", `Asset number ${assetNumber} is invalid for ${assetTypeKey}.`);
  }
  const assignedAgencies = stringArray(command.payload.assignedAgencies ?? [], "assignedAgencies");
  const chargeNoAtEvent = command.payload.chargeNoAtEvent == null
    ? null
    : intValue(command.payload.chargeNoAtEvent, "chargeNoAtEvent", 0);
  const remarks = optionalText(command.payload.remarks);

  const executionRef = executionPath(executionId);
  const aggregateRef = workflowPath(executionId);
  const equipmentRef = equipmentPath(assetTypeKey, assetNumber);
  const existingExecution = await tx.get(executionRef);
  const existingWorkflow = await tx.get(aggregateRef);
  const currentEquipment = await tx.get(equipmentRef);
  const existingFacts = equipmentFactsFromProjection(currentEquipment.data);
  if (existingExecution.exists || existingWorkflow.exists) {
    throw new WorkflowError("already-exists", "A job or workflow already uses this identity.");
  }

  const now = iso(context.serverNow);
  const facts = withWorkflowContribution(existingFacts, "nonRed");
  const equipment = projectEquipment(facts, false);
  tx.create(executionRef, {
    firestoreId: executionId,
    templateFirestoreId,
    templateName,
    assetType: assetTypeKey,
    assetNumber,
    isCompleted: false,
    assignedByUid: context.actor.uid,
    assignedByName: context.actor.name,
    assignedAgencies,
    chargeNoAtEvent,
    remarks,
    teamsInvolved: [],
    responsesJson: "[]",
    actionsJson: "[]",
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    laneMappingReview: assignedAgencies.length > 0,
    version: 1,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  });
  tx.create(aggregateRef, {
    jobExecutionId: executionId,
    assetTypeKey,
    assetNumber,
    status: "pendingLaneClassification",
    version: 1,
    workflowSchemaVersion: 1,
    laneSetVersion: 0,
    laneSetFinalizedAt: null,
    activeRedWork: false,
    awaitingPreparation: false,
    cancelled: false,
    createdByUid: context.actor.uid,
    createdByName: context.actor.name,
    createdAt: now,
    updatedAt: now,
  });
  tx.set(equipmentRef, equipmentProjectionWrite(currentEquipment.data, facts, equipment, {
    assetTypeKey,
    assetNumber,
    trigger: `jobCreated:${executionId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), true);
  const event = eventPlan({
    aggregateId: executionId,
    eventId: command.commandId,
    eventType: "workflow.jobCreatedPendingClassification",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    payload: {templateFirestoreId, templateName, assetTypeKey, assetNumber, assignedAgencies},
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "workflow-job-created",
    aggregateVersion: 1,
    result: {executionId, workflowId: executionId, status: "pendingLaneClassification", equipmentState: equipment.state},
  };
};
