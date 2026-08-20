import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {
  assertMaintenanceClassApplies,
  frozenMaintenanceClassFromExecution,
  maintenanceAssetIdentityFromExecution,
} from "./maintenanceIntelligence";
import {frozenMaintenanceClassFromDefinition} from "./maintenanceClassHandlers";
import {executionPath} from "./paths";
import {JsonMap} from "./types";
import {cleanText, iso, stableJson} from "./utils";

const planPath = (id: string): string => `maintenance_plans/${id}`;
const auditPath = (commandId: string): string => `maintenance_plan_audits/${commandId}`;
const definitionPath = (id: string): string => `maintenance_class_definitions/${id}`;

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
  if (!Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1) {
    throw new WorkflowError("invalid-argument", "assetNumber is invalid.");
  }
  const assetClassId = optionalDocumentId(payload.assetClassId, "assetClassId");
  const assetInstanceId = optionalDocumentId(payload.assetInstanceId, "assetInstanceId");
  if ((assetClassId == null) !== (assetInstanceId == null)) {
    throw new WorkflowError(
      "invalid-argument",
      "assetClassId and assetInstanceId must be provided together.",
    );
  }
  return {
    assetTypeKey,
    assetNumber: assetNumber as number,
    assetClassId,
    assetInstanceId,
    assetIdentityKey: assetClassId == null ?
      `${assetTypeKey}:${assetNumber}` : `${assetClassId}:${assetInstanceId}`,
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
  const [current, definition, audit] = await Promise.all([
    tx.get(planPath(planId)),
    tx.get(definitionPath(definitionId)),
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
  const classification = frozenMaintenanceClassFromDefinition(definition.data);
  assertMaintenanceClassApplies(classification, {
    assetIdentityKey: identity.assetIdentityKey as string,
    assetTypeKey: identity.assetTypeKey as string,
    assetNumber: identity.assetNumber as number,
    assetClassId: identity.assetClassId as string | null,
    assetInstanceId: identity.assetInstanceId as string | null,
  });
  const now = iso(context.serverNow);
  const nextVersion = currentVersion + 1;
  const after: JsonMap = {
    schemaVersion: 1,
    planId,
    version: nextVersion,
    status: current.data?.status ?? "proposed",
    ...identity,
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
