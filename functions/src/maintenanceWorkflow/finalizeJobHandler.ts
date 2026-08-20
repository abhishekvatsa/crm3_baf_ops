import {mayFinalizeJob} from "./authority";
import {
  PersistedActionPayloadError,
  readComponentActionPayload,
} from "../persistedActionPayload";
import {
  PersistedWorkPayloadError,
  readFieldResponsePayload,
} from "../persistedWorkPayload";
import {buildCanonicalClosurePlan} from "./canonicalClosure";
import {activeLanes, assertExpectedVersion, openBlockingCompliance, requireWorkflow} from "./documents";
import {
  equipmentFactsFromProjection,
  equipmentProjectionWrite,
  projectEquipment,
  withWorkflowContribution,
  withoutWorkflowContribution,
  workflowContribution,
} from "./equipmentFacts";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {CommandHandler} from "./handlerTypes";
import {
  applyMaintenanceCompletionWritePlan,
  prepareMaintenanceCompletionWritePlan,
} from "./maintenanceIntelligence";
import {
  compliancePath,
  equipmentIdentityFromWorkflow,
  equipmentPathForIdentity,
  executionPath,
  lanePath,
  workflowPath,
} from "./paths";
import {WORKFLOW_CLOCKS_MINUTES} from "./policy.generated";
import {evaluateRedExit} from "./redPolicy";
import {
  buildRedSuccessorModule,
  deterministicRedSuccessorIds,
  resolveRedSuccessorTemplate,
} from "./redSuccessorTemplateResolver";
import {cleanText, iso, optionalText, plusMinutes, stringArray} from "./utils";

const responseArrayText = (
  value: unknown,
  field: string,
  code: "invalid-argument" | "failed-precondition",
  allowMissing = false,
): string => {
  try {
    return readFieldResponsePayload(value, {field, allowMissing}).text;
  } catch (error) {
    if (error instanceof PersistedWorkPayloadError) {
      throw new WorkflowError(
        code,
        code === "invalid-argument"
          ? "responsesJson contains invalid structured response evidence."
          : "Saved planned-job responses need repair before closure.",
        {
          reasonCode: code === "invalid-argument"
            ? "response-payload-invalid"
            : "execution-response-payload-invalid",
          field: error.field,
        },
      );
    }
    throw error;
  }
};

const actionArrayText = (
  value: unknown,
  field: string,
  code: "invalid-argument" | "failed-precondition",
  allowMissing = false,
): string => {
  try {
    return readComponentActionPayload(value, {field, allowMissing}).text;
  } catch (error) {
    if (error instanceof PersistedActionPayloadError) {
      throw new WorkflowError(
        code,
        code === "invalid-argument"
          ? "actionsJson contains invalid component-action evidence."
          : "Saved planned-job action evidence needs repair before closure.",
        {reasonCode: "action-payload-invalid", field: error.field},
      );
    }
    throw error;
  }
};

export const finalizeJob: CommandHandler = async ({tx, command, context}) => {
  if (!mayFinalizeJob(context.actor)) {
    throw new WorkflowError("permission-denied", "Actor cannot perform final planned-job closure.");
  }

  const workflow = await requireWorkflow(tx, command.aggregateId);
  if (workflow.status === "cancelled" || workflow.cancelled === true) {
    throw new WorkflowError("failed-precondition", "Cancelled workflow cannot be finalised.");
  }
  if (workflow.status === "completed") {
    const completedExecutionId = cleanText(workflow.jobExecutionId ?? command.aggregateId, "jobExecutionId");
    const completedExecution = await tx.get(executionPath(completedExecutionId));
    let closureAttestationHash: string | null = null;
    const metadataJson = completedExecution.data?.metadataJson;
    if (typeof metadataJson === "string") {
      try {
        const metadata = JSON.parse(metadataJson) as {closureAttestation?: {hash?: unknown}};
        closureAttestationHash = typeof metadata.closureAttestation?.hash === "string"
          ? metadata.closureAttestation.hash
          : null;
      } catch (_) {
        closureAttestationHash = null;
      }
    }
    return {
      resultKey: "workflow-already-finalized",
      aggregateVersion: typeof workflow.version === "number" ? workflow.version : 0,
      result: {
        alreadyCompleted: true,
        executionId: completedExecutionId,
        closureAttestationHash,
        successorWorkflowId: typeof workflow.redSuccessorWorkflowId === "string"
          ? workflow.redSuccessorWorkflowId
          : null,
      },
    };
  }
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const lanes = await activeLanes(tx, command.aggregateId);
  if (lanes.length === 0) {
    throw new WorkflowError("lane-set-not-finalized", "Workflow has no active lanes.");
  }
  const notClosed = lanes.filter((lane) => lane.status !== "closed");
  if (notClosed.length > 0) {
    throw new WorkflowError(
      "lane-not-ready-to-close",
      "All active lanes must be closed before finalisation.",
      {openLaneKeys: notClosed.map((lane) => lane.laneKey ?? "unknown")},
    );
  }
  const blocking = await openBlockingCompliance(tx, command.aggregateId);
  if (blocking.length > 0) {
    throw new WorkflowError("blocking-compliance-open", "Workflow has unresolved blocking compliance requests.");
  }

  const parentExecutionId = cleanText(workflow.jobExecutionId ?? command.aggregateId, "jobExecutionId");
  const parentExecutionRef = executionPath(parentExecutionId);
  const parentExecution = await tx.get(parentExecutionRef);
  if (!parentExecution.exists || parentExecution.data == null) {
    throw new WorkflowError("not-found", "Parent job execution was not found.");
  }

  const assetTypeKey = cleanText(workflow.assetTypeKey, "assetTypeKey");
  const assetNumber = typeof workflow.assetNumber === "number" ? workflow.assetNumber : 0;
  if (assetNumber <= 0) {
    throw new WorkflowError("failed-precondition", "Workflow asset identity is invalid.");
  }
  const redAlreadyInWorkflow = lanes.some((lane) => lane.laneKey === "red");
  const redRequired = typeof command.payload.redRequired === "boolean" ? command.payload.redRequired : null;
  const preparationRequired = typeof command.payload.preparationRequired === "boolean"
    ? command.payload.preparationRequired
    : null;
  const red = evaluateRedExit({
    assetTypeKey,
    wouldCompleteParent: true,
    redAlreadyInWorkflow,
    redRequired,
    preparationRequired,
  });
  if (red.action === "promptRedRequirement") {
    throw new WorkflowError("red-answer-required", "RED requirement answer is required.");
  }
  if (red.action === "promptPreparationRequirement") {
    throw new WorkflowError("preparation-answer-required", "Preparation answer is required for this furnace.");
  }

  const equipmentIdentity = equipmentIdentityFromWorkflow(workflow);
  const equipmentId = equipmentPathForIdentity(equipmentIdentity);
  const equipment = await tx.get(equipmentId);
  const otherFacts = withoutWorkflowContribution(
    equipmentFactsFromProjection(equipment.data, equipmentIdentity),
    workflowContribution(workflow),
  );
  const now = iso(context.serverNow);
  const nextVersion = version + 1;
  const currentExecution = parentExecution.data;
  const currentExecutionVersion = typeof currentExecution.version === "number"
    ? currentExecution.version
    : 1;
  const teamsInvolved = command.payload.teamsInvolved == null
    ? Array.isArray(currentExecution.teamsInvolved) ? currentExecution.teamsInvolved : []
    : stringArray(command.payload.teamsInvolved, "teamsInvolved");
  const currentResponsesJson = responseArrayText(
    currentExecution.responsesJson,
    "execution.responsesJson",
    "failed-precondition",
    !Object.prototype.hasOwnProperty.call(currentExecution, "responsesJson"),
  );
  const responsesJson = command.payload.responsesJson == null
    ? currentResponsesJson
    : responseArrayText(
      command.payload.responsesJson,
      "responsesJson",
      "invalid-argument",
    );
  const currentActionsJson = actionArrayText(
    currentExecution.actionsJson,
    "execution.actionsJson",
    "failed-precondition",
    !Object.prototype.hasOwnProperty.call(currentExecution, "actionsJson"),
  );
  const actionsJson = command.payload.actionsJson == null
    ? currentActionsJson
    : actionArrayText(
      command.payload.actionsJson,
      "actionsJson",
      "invalid-argument",
    );
  const remarks = command.payload.remarks == null
    ? typeof currentExecution.remarks === "string" ? currentExecution.remarks : null
    : optionalText(command.payload.remarks);
  const closurePlan = await buildCanonicalClosurePlan({
    tx,
    executionId: parentExecutionId,
    workflowAggregateId: command.aggregateId,
    execution: currentExecution,
    actor: context.actor,
    completedAt: now,
    nextExecutionVersion: currentExecutionVersion + 1,
    remarks,
    teamsInvolved,
    responsesJson,
    actionsJson,
  });

  let successorWorkflowId: string | null = null;
  let successorExecutionId: string | null = null;
  let preparationComplianceId: string | null = null;
  let successorContribution: "none" | "red" | "awaitingPreparation" = "none";
  let successorTemplate: Awaited<ReturnType<typeof resolveRedSuccessorTemplate>> | null = null;
  let successorModules: ReturnType<typeof buildRedSuccessorModule>[] = [];

  if (red.action === "createREDSuccessor" || red.action === "createREDSuccessorAwaitingPreparation") {
    const ids = deterministicRedSuccessorIds(command.aggregateId, command.commandId);
    successorWorkflowId = ids.workflowId;
    successorExecutionId = ids.executionId;
    successorTemplate = await resolveRedSuccessorTemplate(tx, assetTypeKey);
    successorModules = successorTemplate.modules.map((module, index) => buildRedSuccessorModule({
      template: successorTemplate!,
      module,
      index,
      executionId: successorExecutionId!,
      assetTypeKey,
      assetNumber,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: now,
    }));

    const successorWorkflow = await tx.get(workflowPath(successorWorkflowId));
    const successorExecution = await tx.get(executionPath(successorExecutionId));
    const existingModules = await Promise.all(
      successorModules.map((module) => tx.get(`job_modules/${module.id}`)),
    );
    if (successorWorkflow.exists || successorExecution.exists || existingModules.some((row) => row.exists)) {
      throw new WorkflowError("already-exists", "A RED successor already exists for this finalisation identity.");
    }
  }

  const maintenanceCompletionPlan = await prepareMaintenanceCompletionWritePlan({
    tx,
    execution: currentExecution,
    executionId: parentExecutionId,
    sourceType: "workflowPlannedJob",
    completedAt: now,
    completedBy: context.actor,
    recordedAt: now,
  });

  // All transaction reads have completed. Writes begin below.
  if (successorWorkflowId != null && successorExecutionId != null && successorTemplate != null) {
    const awaitingPreparation = red.action === "createREDSuccessorAwaitingPreparation";
    successorContribution = awaitingPreparation ? "awaitingPreparation" : "red";
    const redLanePath = lanePath(successorWorkflowId, "red", 1);

    tx.create(workflowPath(successorWorkflowId), {
      jobExecutionId: successorExecutionId,
      parentWorkflowId: command.aggregateId,
      parentExecutionId: parentExecutionId,
      assetTypeKey,
      assetNumber,
      status: awaitingPreparation ? "awaitingCompliance" : "assigned",
      version: 1,
      workflowSchemaVersion: 1,
      laneSetVersion: 1,
      laneSetFinalizedAt: now,
      laneSetFinalizedByUid: context.actor.uid,
      laneSetFinalizedByName: context.actor.name,
      activeRedWork: !awaitingPreparation,
      awaitingPreparation,
      cancelled: false,
      createdByUid: context.actor.uid,
      createdByName: context.actor.name,
      createdAt: now,
      updatedAt: now,
    });
    tx.create(redLanePath, {
      workflowId: successorWorkflowId,
      jobExecutionId: successorExecutionId,
      laneKey: "red",
      status: "pending",
      activationGeneration: 1,
      version: 1,
      progressRevision: 0,
      displayOrder: 0,
      laneSetFinalized: true,
      addedDuringExecution: false,
      addedByUid: context.actor.uid,
      addedByName: context.actor.name,
      addedAt: now,
      acknowledgementDueAt: awaitingPreparation
        ? null
        : plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement),
      nextEscalationAt: awaitingPreparation
        ? null
        : plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.normalAcknowledgement),
      gatingComplianceRequestId: awaitingPreparation ? `${successorWorkflowId}_preparation` : null,
      assetTypeKey,
      assetNumber,
      createdByUid: context.actor.uid,
      createdByName: context.actor.name,
      createdAt: now,
      updatedAt: now,
    });
    tx.create(executionPath(successorExecutionId), {
      firestoreId: successorExecutionId,
      parentExecutionFirestoreId: parentExecutionId,
      templateFirestoreId: successorTemplate.versionId,
      templateName: successorTemplate.templateName,
      templatePackageId: successorTemplate.packageId,
      templateVersionId: successorTemplate.versionId,
      templateVersionNumber: successorTemplate.versionNumber,
      templateVersionLabel: successorTemplate.versionLabel,
      templateContentHash: successorTemplate.contentHash,
      templatePackageCode: successorTemplate.packageCode,
      assetType: assetTypeKey,
      assetNumber,
      isCompleted: false,
      assignedByUid: context.actor.uid,
      assignedByName: context.actor.name,
      assignedAgencies: ["refractory"],
      workflowSchemaVersion: 1,
      laneSetVersion: 1,
      laneSetFinalizedAt: now,
      laneSetFinalizedByUid: context.actor.uid,
      laneSetFinalizedByName: context.actor.name,
      laneMappingReview: false,
      spawnedRedExecutionFirestoreId: null,
      redAnswerJson: null,
      remarks: `RED successor of ${parentExecutionId}`,
      teamsInvolved: [],
      responsesJson: "[]",
      actionsJson: "[]",
      version: 1,
      modulePopulationVersion: 1,
      modulePopulationSchemaVersion: 1,
      modulePopulationUpdatedAt: now,
      modulePopulationUpdatedByUid: context.actor.uid,
      modulePopulationLastMutation: "redSuccessorCreation",
      modulePopulationLastModuleId: successorModules.at(-1)?.id ?? null,
      metadataJson: JSON.stringify({
        source: "server_governed_red_successor",
        parentWorkflowId: command.aggregateId,
        parentExecutionId,
        packageFirestoreId: successorTemplate.packageId,
        versionFirestoreId: successorTemplate.versionId,
        contentHash: successorTemplate.contentHash,
      }),
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    });
    for (const module of successorModules) {
      tx.create(`job_modules/${module.id}`, module.data);
    }

    if (awaitingPreparation) {
      preparationComplianceId = `${successorWorkflowId}_preparation`;
      tx.create(compliancePath(preparationComplianceId), {
        linkedWorkflowId: successorWorkflowId,
        linkedExecutionFirestoreId: successorExecutionId,
        targetLaneKey: "oprn",
        originLaneKey: "red",
        title: `Place ${assetTypeKey} ${assetNumber} on maintenance stand`,
        description: "Place equipment on stand and confirm preparation for RED work.",
        status: "raised",
        conditionTypeKey: "manual",
        gatesLaneFirestoreId: redLanePath,
        raisedByUid: context.actor.uid,
        raisedByName: context.actor.name,
        raisedAt: now,
        becameDueAt: now,
        acknowledgementDueAt: plusMinutes(
          context.serverNow,
          WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
        ),
        nextEscalationAt: plusMinutes(
          context.serverNow,
          WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
        ),
        version: 1,
        attemptCount: 0,
        currentAttemptId: null,
        correctionCount: 0,
        counterDepth: 0,
        escalationTier: 0,
        createdAt: now,
        updatedAt: now,
      });
    }

    const successorEvent = eventPlan({
      aggregateId: successorWorkflowId,
      eventId: `${command.commandId}_red_successor`,
      eventType: "workflow.redSuccessorCreated",
      actor: context.actor,
      at: context.serverNow,
      commandId: command.commandId,
      laneKey: "red",
      payload: {
        parentWorkflowId: command.aggregateId,
        parentExecutionId,
        templatePackageId: successorTemplate.packageId,
        templateVersionId: successorTemplate.versionId,
        moduleCount: successorModules.length,
        awaitingPreparation,
      },
    });
    tx.create(successorEvent.path, successorEvent.data);
  }

  const facts = withWorkflowContribution(otherFacts, successorContribution);
  const projection = projectEquipment(facts, false);
  tx.update(workflowPath(command.aggregateId), {
    status: "completed",
    completedAt: now,
    completedByUid: context.actor.uid,
    completedByName: context.actor.name,
    redAnswer: {
      required: redRequired,
      preparationRequired,
      answeredByUid: context.actor.uid,
      answeredByName: context.actor.name,
      answeredAt: now,
    },
    redSuccessorWorkflowId: successorWorkflowId,
    activeRedWork: false,
    awaitingPreparation: false,
    version: nextVersion,
    updatedAt: now,
  });

  tx.update(parentExecutionRef, {
    ...closurePlan.executionUpdate,
    maintenanceClassificationPending: maintenanceCompletionPlan == null,
    spawnedRedExecutionFirestoreId: successorExecutionId,
    redAnswerJson: JSON.stringify({
      required: redRequired,
      preparationRequired,
      answeredByUid: context.actor.uid,
      answeredByName: context.actor.name,
      answeredAt: now,
    }),
  });
  tx.set(closurePlan.auditPath, closurePlan.auditData, true);
  applyMaintenanceCompletionWritePlan(tx, maintenanceCompletionPlan);

  tx.set(equipmentId, equipmentProjectionWrite(equipment.data, facts, projection, {
    assetTypeKey,
    assetNumber,
    assetClassId: equipmentIdentity.assetClassId,
    assetInstanceId: equipmentIdentity.assetInstanceId,
    trigger: `finalize:${command.aggregateId}`,
    at: now,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
  }), true);
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "workflow.finalized",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    payload: {
      redAction: red.action,
      successorWorkflowId,
      successorExecutionId,
      preparationComplianceId,
      equipmentState: projection.state,
      closureAttestationHash: closurePlan.attestationHash,
      validatedModuleCount: closurePlan.modules.length,
      maintenanceCompletionEventId: maintenanceCompletionPlan?.eventId ?? null,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "workflow-finalized",
    aggregateVersion: nextVersion,
    result: {
      redAction: red.action,
      successorWorkflowId,
      successorExecutionId,
      preparationComplianceId,
      equipmentState: projection.state,
      closureAttestationHash: closurePlan.attestationHash,
      validatedModuleCount: closurePlan.modules.length,
      maintenanceCompletionEventId: maintenanceCompletionPlan?.eventId ?? null,
    },
  };
};
