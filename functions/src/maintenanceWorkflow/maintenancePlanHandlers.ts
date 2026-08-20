import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {
  applyMaintenanceCompletionWritePlan,
  assertMaintenanceClassApplies,
  frozenMaintenanceClassFromExecution,
  maintenanceAssetIdentityFromExecution,
  parseFrozenMaintenanceClass,
  prepareMaintenanceCompletionWritePlan,
} from "./maintenanceIntelligence";
import {frozenMaintenanceClassFromDefinition} from "./maintenanceClassHandlers";
import {executionPath} from "./paths";
import {JsonMap} from "./types";
import {cleanText, iso, stableJson} from "./utils";

const planPath = (id: string): string => `maintenance_plans/${id}`;
const auditPath = (commandId: string): string => `maintenance_plan_audits/${commandId}`;
const definitionPath = (id: string): string => `maintenance_class_definitions/${id}`;

const maintainableInnerCoverStates = new Set([
  "available", "reserved", "installed", "awaitingInspection",
  "underInspection", "underRepair", "quarantined",
]);

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError("invalid-argument", `${field} has unsupported or missing fields.`);
  }
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." || parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const optionalDocumentId = (value: unknown, field: string): string | null => {
  if (value == null) return null;
  return documentId(value, field);
};

const optionalText = (value: unknown, field: string, maximum: number): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
  }
  const parsed = value.trim();
  if (parsed.length === 0) return null;
  if (parsed.length > maximum) {
    throw new WorkflowError("invalid-argument", `${field} cannot exceed ${maximum} characters.`);
  }
  return parsed;
};

const isoDate = (value: unknown, field: string): string => {
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} is required.`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return date.toISOString();
};

const assetIdentity = (payload: JsonMap): JsonMap => {
  const assetTypeKey = cleanText(payload.assetTypeKey, "assetTypeKey");
  const assetNumber = payload.assetNumber;
  const serialInnerCover = assetTypeKey === "innerCover" && assetNumber == null;
  if (!serialInnerCover &&
      (!Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1)) {
    throw new WorkflowError("invalid-argument", "assetNumber is invalid.");
  }
  const assetClassId = documentId(payload.assetClassId, "assetClassId");
  const assetInstanceId = documentId(payload.assetInstanceId, "assetInstanceId");
  const assetInstanceVersion = payload.assetInstanceVersion;
  if (!Number.isSafeInteger(assetInstanceVersion) ||
      (assetInstanceVersion as number) < 1) {
    throw new WorkflowError("invalid-argument", "assetInstanceVersion is invalid.");
  }
  return {
    assetTypeKey,
    assetNumber: serialInnerCover ? null : assetNumber as number,
    assetClassId,
    assetInstanceId,
    assetInstanceVersion: assetInstanceVersion as number,
    assetIdentityKey: `${assetClassId}:${assetInstanceId}`,
  };
};

const writeAudit = (args: {
  readonly tx: Parameters<CommandHandler>[0]["tx"];
  readonly commandId: string;
  readonly planId: string;
  readonly operation: string;
  readonly actorUid: string;
  readonly actorName: string;
  readonly at: string;
  readonly reason: string;
  readonly before: JsonMap;
  readonly after: JsonMap;
}): void => args.tx.create(auditPath(args.commandId), {
  schemaVersion: 1,
  auditId: args.commandId,
  planId: args.planId,
  operation: args.operation,
  performedByUid: args.actorUid,
  performedByName: args.actorName,
  performedAt: args.at,
  reason: args.reason,
  beforeJson: stableJson(args.before),
  afterJson: stableJson(args.after),
});

export const upsertMaintenancePlan: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, [
    "assetTypeKey", "assetNumber", "assetClassId", "assetInstanceId",
    "assetInstanceVersion",
    "maintenanceClassDefinitionId", "maintenanceClassDefinitionVersion",
    "targetWindowStart", "targetWindowEnd", "sourceDueStateId",
    "templatePackageId", "templateVersionId", "templateContentHash",
    "planningNotes", "reason",
  ], "payload");
  const planId = documentId(command.aggregateId, "aggregateId");
  const identity = assetIdentity(command.payload);
  const definitionId = documentId(
    command.payload.maintenanceClassDefinitionId,
    "maintenanceClassDefinitionId",
  );
  const definitionVersion = command.payload.maintenanceClassDefinitionVersion;
  if (!Number.isSafeInteger(definitionVersion) || (definitionVersion as number) < 1) {
    throw new WorkflowError("invalid-argument", "maintenanceClassDefinitionVersion is invalid.");
  }
  const targetWindowStart = isoDate(command.payload.targetWindowStart, "targetWindowStart");
  const targetWindowEnd = isoDate(command.payload.targetWindowEnd, "targetWindowEnd");
  if (Date.parse(targetWindowEnd) <= Date.parse(targetWindowStart)) {
    throw new WorkflowError("invalid-argument", "The target window must end after it starts.");
  }
  const packageId = optionalDocumentId(command.payload.templatePackageId, "templatePackageId");
  const versionId = optionalDocumentId(command.payload.templateVersionId, "templateVersionId");
  const contentHash = optionalText(command.payload.templateContentHash, "templateContentHash", 180);
  if ((packageId == null || versionId == null || contentHash == null) &&
      (packageId != null || versionId != null || contentHash != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "Template package, version and content hash must be supplied together.",
    );
  }
  const reason = optionalText(command.payload.reason, "reason", 500);
  if (reason == null || reason.length < 5) {
    throw new WorkflowError("invalid-argument", "reason must contain at least 5 characters.");
  }
  const [current, definition, assetClass, assetInstance, audit] = await Promise.all([
    tx.get(planPath(planId)),
    tx.get(definitionPath(definitionId)),
    tx.get(`asset_classes/${identity.assetClassId}`),
    tx.get(identity.assetTypeKey === "innerCover" && identity.assetNumber == null ?
      `inner_cover_profiles/${identity.assetInstanceId}` :
      `asset_instances/${identity.assetInstanceId}`),
    tx.get(auditPath(command.commandId)),
  ]);
  if (audit.exists) {
    throw new WorkflowError("failed-precondition", "Maintenance-plan audit evidence is orphaned.");
  }
  const currentVersion = current.exists && current.data != null &&
      Number.isSafeInteger(current.data.version) ? current.data.version as number : 0;
  if (currentVersion !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The maintenance plan changed before this request.");
  }
  if (current.data != null && !["proposed", "scheduled"].includes(String(current.data.status))) {
    throw new WorkflowError(
      "failed-precondition",
      "Only proposed or scheduled plans can be edited.",
    );
  }
  if (!definition.exists || definition.data == null || definition.data.status !== "active" ||
      definition.data.version !== definitionVersion) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected maintenance class is missing, inactive or changed.",
    );
  }
  if (!assetClass.exists || assetClass.data == null ||
      assetClass.data.status !== "active" || assetClass.data.isDeleted === true ||
      assetClass.data.assetClassId !== identity.assetClassId) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected asset class is missing, inactive or malformed.",
    );
  }
  const expectedAssetType = assetClass.data.legacyAssetTypeKey == null ?
    "governedCustom" : assetClass.data.legacyAssetTypeKey;
  const serialInnerCover = identity.assetTypeKey === "innerCover" &&
    identity.assetNumber == null;
  const physicalAssetValid = serialInnerCover ?
    assetInstance.exists && assetInstance.data != null &&
      assetInstance.data.schemaVersion === 1 &&
      assetInstance.data.innerCoverId === identity.assetInstanceId &&
      assetInstance.data.assetClassId === identity.assetClassId &&
      assetInstance.data.version === identity.assetInstanceVersion &&
      typeof assetInstance.data.serialNumber === "string" &&
      assetInstance.data.serialNumber.trim().length > 0 &&
      maintainableInnerCoverStates.has(String(assetInstance.data.lifecycleState)) :
    assetInstance.exists && assetInstance.data != null &&
      assetInstance.data.status === "active" && assetInstance.data.isDeleted !== true &&
      assetInstance.data.assetInstanceId === identity.assetInstanceId &&
      assetInstance.data.assetClassId === identity.assetClassId &&
      assetInstance.data.assetNumber === identity.assetNumber &&
      assetInstance.data.version === identity.assetInstanceVersion &&
      typeof assetInstance.data.name === "string" &&
      assetInstance.data.name.trim().length > 0;
  if (identity.assetTypeKey !== expectedAssetType || !physicalAssetValid) {
    throw new WorkflowError(
      "failed-precondition",
      "The selected physical asset is missing, inactive, changed or outside its class.",
      {reasonCode: "maintenance-plan-asset-identity-changed"},
    );
  }
  const classification = frozenMaintenanceClassFromDefinition(definition.data);
  assertMaintenanceClassApplies(classification, {
    assetIdentityKey: identity.assetIdentityKey as string,
    assetTypeKey: identity.assetTypeKey as string,
    assetNumber: identity.assetNumber as number | null,
    assetClassId: identity.assetClassId as string | null,
    assetInstanceId: identity.assetInstanceId as string | null,
  });
  const now = iso(context.serverNow);
  const nextVersion = currentVersion + 1;
  const after: JsonMap = {
    schemaVersion: 2,
    planId,
    version: nextVersion,
    status: current.data?.status ?? "proposed",
    ...identity,
    assetInstanceName: serialInnerCover ?
      `Inner Cover ${(assetInstance.data!.serialNumber as string).trim()}` :
      (assetInstance.data!.name as string).trim(),
    maintenanceClass: classification as unknown as JsonMap,
    maintenanceClassDefinitionId: definitionId,
    maintenanceClassDefinitionVersion: definitionVersion as number,
    maintenanceClassCode: classification.code,
    maintenanceClassTitle: classification.title,
    targetWindowStart,
    targetWindowEnd,
    sourceDueStateId: optionalDocumentId(command.payload.sourceDueStateId, "sourceDueStateId"),
    templatePackageId: packageId,
    templateVersionId: versionId,
    templateContentHash: contentHash,
    planningNotes: optionalText(command.payload.planningNotes, "planningNotes", 2000),
    ownerUid: context.actor.uid,
    ownerName: context.actor.name,
    releasedExecutionId: current.data?.releasedExecutionId ?? null,
    createdAt: current.data?.createdAt ?? now,
    createdByUid: current.data?.createdByUid ?? context.actor.uid,
    createdByName: current.data?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  if (current.exists) tx.update(planPath(planId), after);
  else tx.create(planPath(planId), after);
  writeAudit({
    tx,
    commandId: command.commandId,
    planId,
    operation: current.exists ? "update" : "create",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data ?? {},
    after,
  });
  return {
    resultKey: current.exists ? "maintenance-plan-updated" : "maintenance-plan-created",
    aggregateVersion: nextVersion,
    result: {planId, status: after.status, maintenanceClassCode: classification.code},
  };
};

export const setMaintenancePlanStatus: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["status", "reason", "executionId"], "payload");
  const planId = documentId(command.aggregateId, "aggregateId");
  const target = cleanText(command.payload.status, "status");
  if (!["scheduled", "ready", "released", "cancelled"].includes(target)) {
    throw new WorkflowError("invalid-argument", "status is unsupported.");
  }
  const reason = optionalText(command.payload.reason, "reason", 500);
  if (reason == null || reason.length < 5) {
    throw new WorkflowError("invalid-argument", "reason must contain at least 5 characters.");
  }
  const executionId = optionalDocumentId(command.payload.executionId, "executionId");
  if ((target === "released") !== (executionId != null)) {
    throw new WorkflowError(
      "invalid-argument",
      "A released plan requires its governed execution; other transitions must not include one.",
    );
  }
  const current = await tx.get(planPath(planId));
  if (!current.exists || current.data == null) {
    throw new WorkflowError("not-found", "Maintenance plan was not found.");
  }
  if (current.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The maintenance plan changed before this request.");
  }
  const transitions: Readonly<Record<string, readonly string[]>> = {
    proposed: ["scheduled", "cancelled"],
    scheduled: ["ready", "cancelled"],
    ready: ["released", "cancelled"],
    released: [],
    cancelled: [],
  };
  const currentStatus = String(current.data.status);
  if (!(transitions[currentStatus] ?? []).includes(target)) {
    throw new WorkflowError(
      "failed-precondition",
      `Maintenance plan cannot move from ${currentStatus} to ${target}.`,
    );
  }
  let execution: Awaited<ReturnType<typeof tx.get>> | null = null;
  if (executionId != null) {
    execution = await tx.get(executionPath(executionId));
    if (!execution.exists || execution.data == null || execution.data.isDeleted === true ||
        execution.data.isCompleted === true) {
      throw new WorkflowError(
        "failed-precondition",
        "The release execution is missing, deleted or already completed.",
      );
    }
    const executionIdentity = maintenanceAssetIdentityFromExecution(execution.data);
    if (executionIdentity.assetIdentityKey !== current.data.assetIdentityKey) {
      throw new WorkflowError(
        "failed-precondition",
        "The release execution targets a different asset.",
      );
    }
    const executionClass = frozenMaintenanceClassFromExecution(execution.data);
    if (executionClass == null ||
        executionClass.definitionId !== current.data.maintenanceClassDefinitionId ||
        executionClass.definitionVersion !== current.data.maintenanceClassDefinitionVersion) {
      throw new WorkflowError(
        "failed-precondition",
        "The release execution does not carry the plan's frozen maintenance class.",
      );
    }
  }
  const audit = await tx.get(auditPath(command.commandId));
  if (audit.exists) {
    throw new WorkflowError("failed-precondition", "Maintenance-plan audit evidence is orphaned.");
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    status: target,
    version: nextVersion,
    releasedExecutionId: executionId,
    releasedAt: target === "released" ? now : current.data.releasedAt ?? null,
    cancelledAt: target === "cancelled" ? now : current.data.cancelledAt ?? null,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  const after = {...current.data, ...update};
  tx.update(planPath(planId), update);
  writeAudit({
    tx,
    commandId: command.commandId,
    planId,
    operation: `set-${target}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data,
    after,
  });
  return {
    resultKey: `maintenance-plan-${target}`,
    aggregateVersion: nextVersion,
    result: {planId, status: target, executionId},
  };
};

export const completeMaintenancePlan: CommandHandler = async ({tx, command, context}) => {
  exactKeys(command.payload, ["completedAt", "completionEvidence", "reason"], "payload");
  const planId = documentId(command.aggregateId, "aggregateId");
  const completedAt = isoDate(command.payload.completedAt, "completedAt");
  const completionEvidence = optionalText(
    command.payload.completionEvidence,
    "completionEvidence",
    2000,
  );
  const reason = optionalText(command.payload.reason, "reason", 500);
  if (completionEvidence == null || completionEvidence.length < 10) {
    throw new WorkflowError(
      "invalid-argument",
      "completionEvidence must contain at least 10 characters.",
    );
  }
  if (reason == null || reason.length < 5) {
    throw new WorkflowError("invalid-argument", "reason must contain at least 5 characters.");
  }
  const current = await tx.get(planPath(planId));
  if (!current.exists || current.data == null) {
    throw new WorkflowError("not-found", "Maintenance plan was not found.");
  }
  if (current.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The maintenance plan changed before this request.");
  }
  if (current.data.status !== "ready") {
    throw new WorkflowError(
      "failed-precondition",
      "Only a ready maintenance plan can be completed directly.",
    );
  }
  if (current.data.assetTypeKey !== "innerCover" || current.data.assetNumber != null ||
      typeof current.data.assetClassId !== "string" ||
      typeof current.data.assetInstanceId !== "string" ||
      !Number.isSafeInteger(current.data.assetInstanceVersion)) {
    throw new WorkflowError(
      "failed-precondition",
      "Direct plan completion is reserved for exact serial-based Inner Covers.",
      {reasonCode: "maintenance-plan-direct-completion-unsupported"},
    );
  }
  const now = iso(context.serverNow);
  if (Date.parse(completedAt) > Date.parse(now) + 5 * 60 * 1000) {
    throw new WorkflowError("invalid-argument", "completedAt cannot be in the future.");
  }
  const [assetClass, profile, audit] = await Promise.all([
    tx.get(`asset_classes/${current.data.assetClassId}`),
    tx.get(`inner_cover_profiles/${current.data.assetInstanceId}`),
    tx.get(auditPath(command.commandId)),
  ]);
  if (audit.exists) {
    throw new WorkflowError("failed-precondition", "Maintenance-plan audit evidence is orphaned.");
  }
  if (!assetClass.exists || assetClass.data == null ||
      assetClass.data.status !== "active" || assetClass.data.isDeleted === true ||
      assetClass.data.assetClassId !== current.data.assetClassId ||
      assetClass.data.legacyAssetTypeKey !== "innerCover") {
    throw new WorkflowError(
      "failed-precondition",
      "The Inner Cover asset class is missing, inactive or malformed.",
    );
  }
  if (!profile.exists || profile.data == null || profile.data.schemaVersion !== 1 ||
      profile.data.innerCoverId !== current.data.assetInstanceId ||
      profile.data.assetClassId !== current.data.assetClassId ||
      profile.data.version !== current.data.assetInstanceVersion ||
      typeof profile.data.serialNumber !== "string" ||
      profile.data.serialNumber.trim().length === 0 ||
      !maintainableInnerCoverStates.has(String(profile.data.lifecycleState))) {
    throw new WorkflowError(
      "failed-precondition",
      "The planned Inner Cover is missing, changed or no longer maintainable.",
      {reasonCode: "maintenance-plan-inner-cover-identity-changed"},
    );
  }
  const classification = parseFrozenMaintenanceClass(current.data.maintenanceClass);
  const completion = await prepareMaintenanceCompletionWritePlan({
    tx,
    execution: current.data,
    executionId: planId,
    sourceType: "maintenancePlanDirect",
    completedAt,
    completedBy: context.actor,
    recordedAt: now,
    classification,
  });
  const nextVersion = command.expectedVersion + 1;
  const update: JsonMap = {
    status: "completed",
    version: nextVersion,
    completedAt,
    completionEvidence,
    completedByUid: context.actor.uid,
    completedByName: context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  const after = {...current.data, ...update};
  applyMaintenanceCompletionWritePlan(tx, completion);
  tx.update(planPath(planId), update);
  writeAudit({
    tx,
    commandId: command.commandId,
    planId,
    operation: "complete",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data,
    after,
  });
  return {
    resultKey: "maintenance-plan-completed",
    aggregateVersion: nextVersion,
    result: {
      planId,
      status: "completed",
      completionEventId: completion?.eventId ?? null,
    },
  };
};
