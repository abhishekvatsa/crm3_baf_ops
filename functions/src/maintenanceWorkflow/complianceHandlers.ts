import {
  assertLaneAuthority,
  assertMayRaiseCompliance,
  mayMarkConditionDue,
  mayCoordinateCompliance,
  mayWorkLane,
} from "./authority";
import {
  assertExpectedVersion,
  requireActiveLaneForWorkflow,
  requireComplianceForWorkflow,
  requireLaneReferenceForWorkflow,
  requireMutableWorkflow,
  workflowDocumentPath,
} from "./documents";
import {WorkflowError} from "./errors";
import {eventPlan} from "./events";
import {ESCALATION_SUPPRESSION_MINUTES, MAX_ESCALATION_TIER} from "./escalationPolicy";
import {
  equipmentFactsFromProjection,
  equipmentProjectionWrite,
  projectEquipment,
  withWorkflowContribution,
  withoutWorkflowContribution,
  workflowContribution,
} from "./equipmentFacts";
import {CommandHandler} from "./handlerTypes";
import {
  assertMaintenanceBoundToCompliance,
  assertMaintenanceCanBind,
  maintenanceProjectionForActionable,
  maintenanceProjectionForAwaitingConfirmation,
  maintenanceProjectionForCorrection,
  maintenanceProjectionForRaise,
  maintenanceProjectionForRelease,
} from "./maintenanceBridge";
import {complianceAttemptPath, compliancePath, equipmentPath, maintenancePath, workflowPath} from "./paths";
import {ComplianceDoc} from "./types";
import {cleanText, iso, laneKey, optionalText, plusMinutes} from "./utils";
import {WORKFLOW_CLOCKS_MINUTES} from "./policy.generated";

const complianceIdFromPayload = (value: unknown): string => cleanText(value, "complianceId");
const PURPOSES = new Set(["assurance", "deferment", "operationsSupport"]);
const DEFERMENT_BASES = new Set([
  "ongoingCycle", "equipmentRequired", "operationalCompliance",
  "safetyConstraint", "qualityConstraint", "other",
]);
const SUPPORT_TYPES = new Set([
  "craneMovement", "assetRelocation", "isolation", "processPreparation",
  "utilitySupport", "accessOrPermit", "other",
]);
const SUPPORT_RESOURCES = new Set([
  "crane", "transferCar", "operationsCrew", "utilities", "other",
]);

const optionalChoice = (
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError("invalid-argument", `Invalid ${field}.`);
  }
  const parsed = value.trim();
  if (!allowed.has(parsed)) {
    throw new WorkflowError("invalid-argument", `Unsupported ${field}.`);
  }
  return parsed;
};

const optionalRequestText = (value: unknown, field: string): string | null => {
  if (value == null) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new WorkflowError("invalid-argument", `Invalid ${field}.`);
  }
  return value.trim();
};

export const raiseCompliance: CommandHandler = async ({tx, command, context}) => {
  const target = laneKey(command.payload.targetLaneKey, "targetLaneKey");
  const origin = laneKey(command.payload.originLaneKey, "originLaneKey");
  assertMayRaiseCompliance(context.actor, origin);
  const raisedUnderCoordination = !mayWorkLane(context.actor, origin);
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  const id = cleanText(command.payload.complianceId, "complianceId");
  const title = cleanText(command.payload.title, "title");
  const description = cleanText(command.payload.description, "description");
  const conditionType = cleanText(
    command.payload.conditionTypeKey ?? "manual",
    "conditionTypeKey",
  );
  if (
    conditionType !== "manual" &&
    conditionType !== "chargeComplete" &&
    conditionType !== "activityRef"
  ) {
    throw new WorkflowError("invalid-argument", "Unsupported compliance condition type.");
  }
  const requestPurpose = optionalChoice(
    command.payload.requestPurposeKey ?? "assurance",
    "requestPurposeKey",
    PURPOSES,
  )!;
  const defermentBasis = optionalChoice(
    command.payload.defermentBasisKey,
    "defermentBasisKey",
    DEFERMENT_BASES,
  );
  const supportType = optionalChoice(
    command.payload.operationsSupportTypeKey,
    "operationsSupportTypeKey",
    SUPPORT_TYPES,
  );
  const supportResource = optionalChoice(
    command.payload.operationsResourceKey,
    "operationsResourceKey",
    SUPPORT_RESOURCES,
  );
  const requestedLocation = optionalRequestText(
    command.payload.requestedLocation,
    "requestedLocation",
  );

  if (requestPurpose === "deferment") {
    if (target !== "oprn") {
      throw new WorkflowError(
        "invalid-argument",
        "Maintenance-deferment requests must target the Operations lane.",
      );
    }
    if (conditionType === "manual") {
      throw new WorkflowError(
        "invalid-argument",
        "A deferment request requires a charge or activity release condition.",
      );
    }
    if (defermentBasis == null) {
      throw new WorkflowError("invalid-argument", "A deferment basis is required.");
    }
  } else if (defermentBasis != null) {
    throw new WorkflowError(
      "invalid-argument",
      "A deferment basis is valid only for a deferment request.",
    );
  }
  if (requestPurpose === "operationsSupport") {
    if (target !== "oprn") {
      throw new WorkflowError(
        "invalid-argument",
        "Operations-support requests must target the Operations lane.",
      );
    }
    if (supportType == null || supportResource == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Operations-support type and resource are required.",
      );
    }
    if ((supportType === "craneMovement" || supportType === "assetRelocation") &&
        requestedLocation == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Crane movement and asset relocation require a destination or work location.",
      );
    }
  } else if (supportType != null || supportResource != null || requestedLocation != null) {
    throw new WorkflowError(
      "invalid-argument",
      "Operations-support details are valid only for an Operations-support request.",
    );
  }

  const originLane = await requireActiveLaneForWorkflow(
    tx,
    command.aggregateId,
    origin,
    "originLaneKey",
  );
  const targetLane = await requireActiveLaneForWorkflow(
    tx,
    command.aggregateId,
    target,
    "targetLaneKey",
  );
  const gate = command.payload.gatesLaneFirestoreId == null
    ? null
    : await requireLaneReferenceForWorkflow(
      tx,
      command.payload.gatesLaneFirestoreId,
      "gatesLaneFirestoreId",
      command.aggregateId,
    );
  const linkedLane = command.payload.linkedLaneFirestoreId == null
    ? targetLane
    : await requireLaneReferenceForWorkflow(
      tx,
      command.payload.linkedLaneFirestoreId,
      "linkedLaneFirestoreId",
      command.aggregateId,
    );

  const executionId = typeof workflow.jobExecutionId === "string" &&
      workflow.jobExecutionId.length > 0
    ? workflow.jobExecutionId
    : command.aggregateId;
  const linkedModulePath = workflowDocumentPath(
    "job_modules",
    command.payload.linkedModuleFirestoreId,
    "linkedModuleFirestoreId",
  );
  let linkedModuleId: string | null = null;
  if (linkedModulePath != null) {
    const module = await tx.get(linkedModulePath);
    if (!module.exists || module.data == null) {
      throw new WorkflowError("not-found", "Linked module was not found.", {
        linkedModulePath,
      });
    }
    if (module.data.jobExecutionFirestoreId !== executionId) {
      throw new WorkflowError(
        "failed-precondition",
        "Linked module belongs to another job execution.",
        {linkedModulePath, executionId},
      );
    }
    linkedModuleId = linkedModulePath.split("/")[1];
  }

  const linkedMaintenancePath = workflowDocumentPath(
    "maintenance_records",
    command.payload.linkedMaintenanceFirestoreId,
    "linkedMaintenanceFirestoreId",
  );
  const linkedMaintenance = linkedMaintenancePath == null
    ? null
    : await tx.get(linkedMaintenancePath);
  const linkedMaintenanceId = linkedMaintenancePath == null
    ? null
    : linkedMaintenancePath.split("/")[1];
  const existingMaintenanceCompliance = linkedMaintenanceId == null
    ? []
    : await tx.query("compliance_requests", [
      {field: "linkedMaintenanceFirestoreId", op: "==", value: linkedMaintenanceId},
    ]);
  const conflictingMaintenanceCompliance = existingMaintenanceCompliance.find((row) =>
    row.path !== compliancePath(id) &&
    !["confirmedClosed", "cancelled", "superseded"].includes(String(row.data?.status)),
  );
  if (conflictingMaintenanceCompliance != null) {
    throw new WorkflowError(
      "failed-precondition",
      "Linked maintenance work already belongs to another active compliance request.",
      {existingCompliancePath: conflictingMaintenanceCompliance.path},
    );
  }
  const conditionRef = optionalText(command.payload.conditionRef);
  if (conditionType !== "manual") {
    if (linkedMaintenanceId == null) {
      throw new WorkflowError(
        "failed-precondition",
        "Deferred compliance requires a validated linked maintenance item.",
      );
    }
    if (conditionRef == null) {
      throw new WorkflowError(
        "invalid-argument",
        "Deferred compliance requires a condition reference.",
      );
    }
  }

  const workflowAssetTypeKey = typeof workflow.assetTypeKey === "string"
    ? workflow.assetTypeKey
    : null;
  const workflowAssetNumber = typeof workflow.assetNumber === "number"
    ? workflow.assetNumber
    : null;
  if (workflowAssetTypeKey == null || workflowAssetNumber == null ||
      !Number.isSafeInteger(workflowAssetNumber) || workflowAssetNumber < 1) {
    throw new WorkflowError(
      "failed-precondition",
      "Workflow asset identity is invalid.",
    );
  }
  const linkedMaintenanceData = linkedMaintenance == null
    ? null
    : assertMaintenanceCanBind({
      maintenance: linkedMaintenance,
      workflowId: command.aggregateId,
      complianceId: id,
      assetTypeKey: workflowAssetTypeKey ?? "",
      assetNumber: workflowAssetNumber ?? -1,
    });
  if (linkedMaintenance != null &&
      (workflowAssetTypeKey == null || workflowAssetNumber == null || workflowAssetNumber <= 0)) {
    throw new WorkflowError("failed-precondition", "Workflow asset identity is invalid.");
  }

  const immediate = conditionType === "manual";
  const now = iso(context.serverNow);
  tx.create(compliancePath(id), {
    linkedWorkflowId: command.aggregateId,
    linkedExecutionFirestoreId: executionId,
    linkedMaintenanceFirestoreId: linkedMaintenanceId,
    linkedLaneFirestoreId: linkedLane.path.split("/")[1],
    linkedModuleFirestoreId: linkedModuleId,
    gatesLaneFirestoreId: gate?.path ?? null,
    title,
    description,
    originLaneKey: origin,
    originLaneFirestoreId: originLane.path.split("/")[1],
    targetLaneKey: target,
    targetLaneFirestoreId: targetLane.path.split("/")[1],
    status: "raised",
    conditionTypeKey: conditionType,
    conditionRef,
    requestPurposeKey: requestPurpose,
    defermentBasisKey: defermentBasis,
    operationsSupportTypeKey: supportType,
    operationsResourceKey: supportResource,
    requestedLocation,
    raisedUnderCoordination,
    coordinationBasis: raisedUnderCoordination ?
      "supervisory-workflow-coordination" : null,
    priorityKey: optionalText(command.payload.priorityKey) ?? "medium",
    assetTypeKey: workflowAssetTypeKey,
    assetNumber: workflowAssetNumber,
    chargeNoAtEvent: linkedMaintenanceData?.chargeNoAtEvent ?? null,
    becameDueAt: immediate ? now : null,
    acknowledgementDueAt: immediate
      ? plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
      )
      : null,
    nextEscalationAt: immediate
      ? plusMinutes(
        context.serverNow,
        WORKFLOW_CLOCKS_MINUTES.complianceAcknowledgement,
      )
      : null,
    raisedByUid: context.actor.uid,
    raisedByName: context.actor.name,
    raisedAt: now,
    counterDepth: 0,
    correctionCount: 0,
    escalationTier: 0,
    version: 1,
    createdAt: now,
    updatedAt: now,
  });
  if (linkedMaintenancePath != null && linkedMaintenanceData != null) {
    tx.update(linkedMaintenancePath, maintenanceProjectionForRaise({
      maintenance: linkedMaintenanceData,
      workflowId: command.aggregateId,
      complianceId: id,
      originLaneKey: origin,
      targetLaneKey: target,
      conditionTypeKey: conditionType,
      conditionRef,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
    }));
  }
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {
    ...(gate == null ? {} : {status: "awaitingCompliance"}),
    version: nextVersion,
    updatedAt: now,
  });
  const event = eventPlan({
    aggregateId: command.aggregateId,
    eventId: command.commandId,
    eventType: "compliance.raised",
    actor: context.actor,
    at: context.serverNow,
    commandId: command.commandId,
    laneKey: target,
    payload: {
      complianceId: id,
      originLaneKey: origin,
      targetLaneKey: target,
      title,
      conditionTypeKey: conditionType,
      requestPurposeKey: requestPurpose,
      defermentBasisKey: defermentBasis,
      operationsSupportTypeKey: supportType,
      operationsResourceKey: supportResource,
      requestedLocation,
      raisedUnderCoordination,
      coordinationBasis: raisedUnderCoordination ?
        "supervisory-workflow-coordination" : null,
      gatedLanePath: gate?.path ?? null,
      linkedModuleId,
      linkedMaintenanceId,
    },
  });
  tx.create(event.path, event.data);
  return {
    resultKey: "compliance-raised",
    aggregateVersion: nextVersion,
    result: {
      complianceId: id,
      originLaneFirestoreId: originLane.path.split("/")[1],
      targetLaneFirestoreId: targetLane.path.split("/")[1],
    },
  };
};

export const acknowledgeCompliance: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const target = laneKey(compliance.targetLaneKey, "targetLaneKey");
  assertLaneAuthority(context.actor, target, "work");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "raised") throw new WorkflowError("failed-precondition", "Only a raised compliance request may be acknowledged.");
  const completionDueAt = compliance.conditionTypeKey === "manual"
    ? plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition)
    : null;
  tx.update(compliancePath(id), {
    status: "acknowledged",
    acknowledgedByUid: context.actor.uid,
    acknowledgedByName: context.actor.name,
    acknowledgedAt: iso(context.serverNow),
    acknowledgementDueAt: null,
    complianceDueAt: completionDueAt,
    nextEscalationAt: completionDueAt,
    version: (compliance.version ?? 0) + 1,
    updatedAt: iso(context.serverNow),
  });
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "compliance.acknowledged", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: target, payload: {complianceId: id}});
  tx.create(event.path, event.data);
  return {resultKey: "compliance-acknowledged", aggregateVersion: nextVersion, result: {complianceId: id}};
};

export const confirmConditionAndReactivate: CommandHandler = async ({tx, command, context}) => {
  if (!mayMarkConditionDue(context.actor)) throw new WorkflowError("permission-denied", "Actor cannot confirm a deferred condition.");
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "raised" && compliance.status !== "acknowledged") {
    throw new WorkflowError("failed-precondition", "Condition confirmation requires a raised or acknowledged request.");
  }
  if (compliance.conditionTypeKey !== "chargeComplete" && compliance.conditionTypeKey !== "activityRef") {
    throw new WorkflowError("failed-precondition", "Only condition-based requests may use this command.");
  }
  const maintenanceId = compliance.linkedMaintenanceFirestoreId;
  if (typeof maintenanceId !== "string" || maintenanceId.length === 0) {
    throw new WorkflowError("failed-precondition", "Deferred request has no linked maintenance item to reactivate.");
  }
  const maintenance = await tx.get(maintenancePath(maintenanceId));
  const maintenanceData = assertMaintenanceBoundToCompliance({
    maintenance,
    workflowId: command.aggregateId,
    complianceId: id,
  });
  const target = laneKey(compliance.targetLaneKey, "targetLaneKey");
  const attemptNumber = (typeof compliance.attemptCount === "number" ? compliance.attemptCount : 0) + 1;
  const attemptId = `${id}_${attemptNumber}`;
  tx.create(complianceAttemptPath(id, attemptNumber), {
    complianceRequestId: id,
    attemptNumber,
    attemptedByUid: context.actor.uid,
    attemptedByName: context.actor.name,
    attemptedAt: iso(context.serverNow),
    note: optionalText(command.payload.note) ?? "Condition confirmed; linked work reactivated.",
    accepted: false,
    createdAt: iso(context.serverNow),
  });
  tx.update(compliancePath(id), {
    status: "complied",
    currentAttemptId: attemptId,
    attemptCount: attemptNumber,
    becameDueAt: iso(context.serverNow),
    dueMarkedByUid: context.actor.uid,
    dueMarkedByName: context.actor.name,
    dueMarkedAt: iso(context.serverNow),
    compliedByUid: context.actor.uid,
    compliedByName: context.actor.name,
    compliedAt: iso(context.serverNow),
    complianceNote: optionalText(command.payload.note) ?? "Condition confirmed; linked work reactivated.",
    complianceDueAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    nextEscalationAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    version: (compliance.version ?? 0) + 1,
    updatedAt: iso(context.serverNow),
  });
  tx.update(maintenancePath(maintenanceId), maintenanceProjectionForActionable({
    maintenance: maintenanceData,
    targetLaneKey: target,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: context.serverNow,
  }));
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {status: "inProgress", version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "compliance.conditionConfirmedAndWorkReactivated", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: target, payload: {complianceId: id, maintenanceId}});
  tx.create(event.path, event.data);
  return {resultKey: "condition-confirmed-work-reactivated", aggregateVersion: nextVersion, result: {complianceId: id, maintenanceId}};
};

export const markComplianceComplied: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const target = laneKey(compliance.targetLaneKey, "targetLaneKey");
  assertLaneAuthority(context.actor, target, "work");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "acknowledged") throw new WorkflowError("failed-precondition", "Compliance must be acknowledged before it is complied.");
  const note = cleanText(command.payload.note, "note");
  const maintenanceId = typeof compliance.linkedMaintenanceFirestoreId === "string" &&
      compliance.linkedMaintenanceFirestoreId.length > 0
    ? compliance.linkedMaintenanceFirestoreId
    : null;
  const maintenance = maintenanceId == null ? null : await tx.get(maintenancePath(maintenanceId));
  const maintenanceData = maintenance == null ? null : assertMaintenanceBoundToCompliance({
    maintenance,
    workflowId: command.aggregateId,
    complianceId: id,
  });
  const attemptNumber = (typeof compliance.attemptCount === "number" ? compliance.attemptCount : 0) + 1;
  const attemptId = `${id}_${attemptNumber}`;
  tx.create(complianceAttemptPath(id, attemptNumber), {
    complianceRequestId: id,
    attemptNumber,
    attemptedByUid: context.actor.uid,
    attemptedByName: context.actor.name,
    attemptedAt: iso(context.serverNow),
    note,
    accepted: false,
    createdAt: iso(context.serverNow),
  });
  tx.update(compliancePath(id), {
    status: "complied",
    currentAttemptId: attemptId,
    attemptCount: attemptNumber,
    compliedByUid: context.actor.uid,
    compliedByName: context.actor.name,
    compliedAt: iso(context.serverNow),
    complianceNote: note,
    complianceDueAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    nextEscalationAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    version: (compliance.version ?? 0) + 1,
    updatedAt: iso(context.serverNow),
  });
  if (maintenanceId != null && maintenanceData != null) {
    tx.update(maintenancePath(maintenanceId), maintenanceProjectionForAwaitingConfirmation({
      maintenance: maintenanceData,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
    }));
  }
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "compliance.complied", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: target, payload: {complianceId: id}});
  tx.create(event.path, event.data);
  return {resultKey: "compliance-complied", aggregateVersion: nextVersion, result: {complianceId: id}};
};

export const returnComplianceForCorrection: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "complied") throw new WorkflowError("failed-precondition", "Only a complied request may be returned for correction.");
  const origin = compliance.originLaneKey == null ? null : laneKey(compliance.originLaneKey, "originLaneKey");
  if (origin != null) {
    if (!(compliance.raisedUnderCoordination === true &&
        mayCoordinateCompliance(context.actor))) {
      assertLaneAuthority(context.actor, origin, "work");
    }
  } else if (!context.actor.roles.has("admin") && !context.actor.roles.has("si")) throw new WorkflowError("permission-denied", "Only the raising side or Admin/SI may return compliance.");
  const reason = cleanText(command.payload.reason, "reason");
  const maintenanceId = compliance.linkedMaintenanceFirestoreId;
  const maintenance = typeof maintenanceId === "string" && maintenanceId.length > 0
    ? await tx.get(maintenancePath(maintenanceId))
    : null;
  const maintenanceData = maintenance == null ? null : assertMaintenanceBoundToCompliance({
    maintenance,
    workflowId: command.aggregateId,
    complianceId: id,
  });
  const currentAttemptId = typeof compliance.currentAttemptId === "string" ? compliance.currentAttemptId : null;
  const currentAttempt = currentAttemptId == null ? null : await tx.get(`compliance_attempts/${currentAttemptId}`);
  if (currentAttemptId == null || currentAttempt?.exists !== true) {
    throw new WorkflowError("failed-precondition", "The complied request has no preserved compliance attempt.");
  }
  tx.update(`compliance_attempts/${currentAttemptId}`, {
    accepted: false,
    returnedByUid: context.actor.uid,
    returnedByName: context.actor.name,
    returnedAt: iso(context.serverNow),
    returnReason: reason,
    updatedAt: iso(context.serverNow),
  });
  tx.update(compliancePath(id), {
    status: "acknowledged",
    complianceDueAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    nextEscalationAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
    correctionCount: (typeof compliance.correctionCount === "number" ? compliance.correctionCount : 0) + 1,
    lastCorrectionByUid: context.actor.uid,
    lastCorrectionByName: context.actor.name,
    lastCorrectionAt: iso(context.serverNow),
    lastCorrectionReason: reason,
    compliedByUid: null,
    compliedByName: null,
    compliedAt: null,
    complianceNote: null,
    version: (compliance.version ?? 0) + 1,
    updatedAt: iso(context.serverNow),
  });
  if (typeof maintenanceId === "string" && maintenanceId.length > 0 && maintenanceData != null) {
    tx.update(maintenancePath(maintenanceId), maintenanceProjectionForCorrection({
      maintenance: maintenanceData,
      reason,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
    }));
  }
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {status: "awaitingCompliance", version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "compliance.returnedForCorrection", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: origin ?? undefined, payload: {complianceId: id, reason, failedAttemptPreserved: true}});
  tx.create(event.path, event.data);
  return {resultKey: "compliance-returned-for-correction", aggregateVersion: nextVersion, result: {complianceId: id, reason}};
};

export const confirmComplianceClosed: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "complied") throw new WorkflowError("failed-precondition", "Only complied requests may be confirmed closed.");
  const origin = compliance.originLaneKey == null ? null : laneKey(compliance.originLaneKey, "originLaneKey");
  if (origin != null) {
    if (!(compliance.raisedUnderCoordination === true &&
        mayCoordinateCompliance(context.actor))) {
      assertLaneAuthority(context.actor, origin, "work");
    }
  } else if (!context.actor.roles.has("admin") && !context.actor.roles.has("si")) throw new WorkflowError("permission-denied", "Only the raising side or Admin/SI may confirm closure.");

  const gatePath = typeof compliance.gatesLaneFirestoreId === "string" && compliance.gatesLaneFirestoreId.length > 0
    ? compliance.gatesLaneFirestoreId
    : null;
  const gatedLane = gatePath == null ? null : await requireLaneReferenceForWorkflow(
    tx,
    gatePath,
    "gatesLaneFirestoreId",
    command.aggregateId,
    "red",
  );
  const assetTypeKey = gatePath == null ? null : (typeof workflow.assetTypeKey === "string" ? workflow.assetTypeKey : null);
  const assetNumber = gatePath == null ? null : (typeof workflow.assetNumber === "number" ? workflow.assetNumber : null);
  const equipmentId = assetTypeKey != null && assetNumber != null ? equipmentPath(assetTypeKey, assetNumber) : null;
  const equipment = equipmentId == null ? null : await tx.get(equipmentId);
  const otherFacts = assetTypeKey != null && assetNumber != null
    ? withoutWorkflowContribution(
      equipmentFactsFromProjection(equipment?.data ?? null),
      workflowContribution(workflow),
    )
    : null;
  const linkedMaintenanceId = typeof compliance.linkedMaintenanceFirestoreId === "string" &&
      compliance.linkedMaintenanceFirestoreId.length > 0
    ? compliance.linkedMaintenanceFirestoreId
    : null;
  const linkedMaintenance = linkedMaintenanceId == null
    ? null
    : await tx.get(maintenancePath(linkedMaintenanceId));
  const linkedMaintenanceData = linkedMaintenance == null ? null : assertMaintenanceBoundToCompliance({
    maintenance: linkedMaintenance,
    workflowId: command.aggregateId,
    complianceId: id,
  });
  const currentAttemptId = typeof compliance.currentAttemptId === "string" ? compliance.currentAttemptId : null;
  const currentAttempt = currentAttemptId == null ? null : await tx.get(`compliance_attempts/${currentAttemptId}`);
  if (currentAttemptId == null || currentAttempt?.exists !== true) {
    throw new WorkflowError("failed-precondition", "The complied request has no preserved compliance attempt.");
  }
  const now = iso(context.serverNow);
  const nextVersion = version + 1;

  tx.update(`compliance_attempts/${currentAttemptId}`, {
    accepted: true,
    acceptedByUid: context.actor.uid,
    acceptedByName: context.actor.name,
    acceptedAt: now,
    updatedAt: now,
  });
  tx.update(compliancePath(id), {
    status: "confirmedClosed",
    nextEscalationAt: null,
    confirmedByUid: context.actor.uid,
    confirmedByName: context.actor.name,
    confirmedAt: now,
    confirmNote: optionalText(command.payload.note),
    version: (compliance.version ?? 0) + 1,
    updatedAt: now,
  });
  if (linkedMaintenanceId != null && linkedMaintenanceData != null) {
    tx.update(maintenancePath(linkedMaintenanceId), maintenanceProjectionForRelease({
      maintenance: linkedMaintenanceData,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
      at: context.serverNow,
    }));
  }

  let equipmentState: string | null = null;
  if (gatePath != null) {
    if (gatedLane == null) {
      throw new WorkflowError("not-found", "Gated lane was not found.");
    }
    if (assetTypeKey == null || assetNumber == null || equipmentId == null || otherFacts == null) {
      throw new WorkflowError("failed-precondition", "Gated workflow asset identity is invalid.");
    }
    const facts = withWorkflowContribution(otherFacts, "red");
    const projection = projectEquipment(facts, false);
    equipmentState = projection.state;
    tx.update(gatePath, {
      gatingComplianceRequestId: null,
      version: (typeof gatedLane.data.version === "number" ? gatedLane.data.version : 0) + 1,
      updatedAt: now,
    });
    tx.update(workflowPath(command.aggregateId), {
      status: "assigned",
      activeRedWork: true,
      awaitingPreparation: false,
      version: nextVersion,
      updatedAt: now,
    });
    tx.set(equipmentId, equipmentProjectionWrite(equipment?.data ?? null, facts, projection, {
      assetTypeKey,
      assetNumber,
      trigger: `preparationConfirmed:${id}`,
      at: now,
      actorUid: context.actor.uid,
      actorName: context.actor.name,
    }), true);
  } else {
    tx.update(workflowPath(command.aggregateId), {
      ...(workflow.workflowKind === "issueCoordination" ? {
        status: "completed",
        completedAt: now,
      } : {}),
      version: nextVersion,
      updatedAt: now,
    });
  }
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: gatePath == null ? "compliance.confirmedClosed" : "red.preparationConfirmed", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: origin ?? undefined, payload: {complianceId: id, releasedGate: gatePath, equipmentState}});
  tx.create(event.path, event.data);
  return {resultKey: gatePath == null ? "compliance-confirmed-closed" : "red-preparation-confirmed", aggregateVersion: nextVersion, result: {complianceId: id, releasedGate: gatePath, equipmentState}};
};

export const proposeCounterCondition: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const target = laneKey(compliance.targetLaneKey, "targetLaneKey");
  assertLaneAuthority(context.actor, target, "work");
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.status !== "raised" && compliance.status !== "acknowledged") throw new WorkflowError("failed-precondition", "Counter-condition is not allowed in this state.");
  if ((compliance.counterDepth ?? 0) >= 1 || compliance.counterProposal != null) throw new WorkflowError("failed-precondition", "Only one counter-condition may be proposed.");
  const revisedDescription = cleanText(command.payload.revisedDescription, "revisedDescription");
  tx.update(compliancePath(id), {
    counterProposal: {
      revisedDescription,
      proposedByUid: context.actor.uid,
      proposedByName: context.actor.name,
      proposedAt: iso(context.serverNow),
    },
    updatedAt: iso(context.serverNow),
    version: (compliance.version ?? 0) + 1,
  });
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: "compliance.counterProposed", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: target, payload: {complianceId: id, revisedDescription}});
  tx.create(event.path, event.data);
  return {resultKey: "counter-condition-proposed", aggregateVersion: nextVersion, result: {complianceId: id}};
};

export const decideCounterCondition: CommandHandler = async ({tx, command, context}) => {
  const id = complianceIdFromPayload(command.payload.complianceId);
  const compliance = await requireComplianceForWorkflow(tx, id, command.aggregateId);
  const workflow = await requireMutableWorkflow(tx, command.aggregateId);
  const version = assertExpectedVersion(workflow, command.expectedVersion);
  if (compliance.counterProposal == null) throw new WorkflowError("failed-precondition", "No counter-condition is awaiting a decision.");
  const origin = compliance.originLaneKey == null ? null : laneKey(compliance.originLaneKey, "originLaneKey");
  if (origin != null) {
    if (!(compliance.raisedUnderCoordination === true &&
        mayCoordinateCompliance(context.actor))) {
      assertLaneAuthority(context.actor, origin, "work");
    }
  } else if (!context.actor.roles.has("admin") && !context.actor.roles.has("si")) throw new WorkflowError("permission-denied", "Only the raising side or Admin/SI may decide a counter-condition.");
  const accepted = command.payload.accepted === true;
  const note = optionalText(command.payload.note);
  const target = laneKey(compliance.targetLaneKey, "targetLaneKey");
  const gatePath = typeof compliance.gatesLaneFirestoreId === "string" && compliance.gatesLaneFirestoreId.length > 0
    ? compliance.gatesLaneFirestoreId
    : null;
  const gatedLane = gatePath == null ? null : await requireLaneReferenceForWorkflow(
    tx,
    gatePath,
    "gatesLaneFirestoreId",
    command.aggregateId,
  );
  const linkedMaintenanceId = accepted &&
      typeof compliance.linkedMaintenanceFirestoreId === "string" &&
      compliance.linkedMaintenanceFirestoreId.length > 0
    ? compliance.linkedMaintenanceFirestoreId
    : null;
  const linkedMaintenance = linkedMaintenanceId == null
    ? null
    : await tx.get(maintenancePath(linkedMaintenanceId));
  const linkedMaintenanceData = linkedMaintenance == null ? null : assertMaintenanceBoundToCompliance({
    maintenance: linkedMaintenance,
    workflowId: command.aggregateId,
    complianceId: id,
  });
  let result;
  if (accepted) {
    const successorId = cleanText(command.payload.successorComplianceId, "successorComplianceId");
    const revisedDescription = cleanText(compliance.counterProposal.revisedDescription, "counterProposal.revisedDescription");
    tx.update(compliancePath(id), {
      status: "superseded",
      nextEscalationAt: null,
      supersededById: successorId,
      counterDecision: {accepted: true, decidedByUid: context.actor.uid, decidedByName: context.actor.name, decidedAt: iso(context.serverNow), note},
      version: (compliance.version ?? 0) + 1,
      updatedAt: iso(context.serverNow),
    });
    tx.create(compliancePath(successorId), {
      ...compliance,
      status: "acknowledged",
      description: revisedDescription,
      counterDepth: 1,
      counterConditionOfId: id,
      counterProposal: null,
      supersededById: null,
      acknowledgedByUid: compliance.counterProposal.proposedByUid ?? null,
      acknowledgedByName: compliance.counterProposal.proposedByName ?? null,
      acknowledgedAt: iso(context.serverNow),
      raisedAt: iso(context.serverNow),
      acknowledgementDueAt: null,
      complianceDueAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
      nextEscalationAt: plusMinutes(context.serverNow, WORKFLOW_CLOCKS_MINUTES.complianceAfterCondition),
      currentAttemptId: null,
      attemptCount: 0,
      createdAt: iso(context.serverNow),
      updatedAt: iso(context.serverNow),
      version: 1,
    });
    if (gatePath != null) {
      tx.update(gatePath, {
        gatingComplianceRequestId: successorId,
        version: (typeof gatedLane?.data.version === "number" ? gatedLane.data.version : 0) + 1,
        updatedAt: iso(context.serverNow),
      });
    }
    if (linkedMaintenanceId != null && linkedMaintenanceData != null) {
      tx.update(maintenancePath(linkedMaintenanceId), {
        workflowComplianceId: successorId,
        workflowUpdatedAt: iso(context.serverNow),
        updatedAt: iso(context.serverNow),
        version: (typeof linkedMaintenanceData.version === "number" ? linkedMaintenanceData.version : 0) + 1,
      });
    }
    result = {accepted: true, successorComplianceId: successorId, transferredGate: gatePath};
  } else {
    const rejectedTier = Math.max(
      1,
      typeof compliance.escalationTier === "number" ? compliance.escalationTier : 0,
    );
    tx.update(compliancePath(id), {
      counterProposal: null,
      counterDepth: 1,
      escalationTier: rejectedTier,
      lastEscalatedAt: iso(context.serverNow),
      nextEscalationAt: rejectedTier >= MAX_ESCALATION_TIER
        ? null
        : plusMinutes(context.serverNow, ESCALATION_SUPPRESSION_MINUTES),
      counterDecision: {accepted: false, decidedByUid: context.actor.uid, decidedByName: context.actor.name, decidedAt: iso(context.serverNow), note},
      version: (compliance.version ?? 0) + 1,
      updatedAt: iso(context.serverNow),
    });
    result = {accepted: false, escalated: true};
  }
  const nextVersion = version + 1;
  tx.update(workflowPath(command.aggregateId), {version: nextVersion, updatedAt: iso(context.serverNow)});
  const event = eventPlan({aggregateId: command.aggregateId, eventId: command.commandId, eventType: accepted ? "compliance.counterAccepted" : "compliance.counterRejectedEscalated", actor: context.actor, at: context.serverNow, commandId: command.commandId, laneKey: origin ?? undefined, payload: {complianceId: id, ...result}});
  tx.create(event.path, event.data);
  return {resultKey: accepted ? "counter-condition-accepted" : "counter-condition-rejected-escalated", aggregateVersion: nextVersion, result};
};
