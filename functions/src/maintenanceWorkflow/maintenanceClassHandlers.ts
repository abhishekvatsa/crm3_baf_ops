import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {
  applyMaintenanceCompletionWritePlan,
  assertMaintenanceClassApplies,
  dueStatePath,
  FrozenMaintenanceClass,
  frozenMaintenanceClassFromExecution,
  maintenanceAssetIdentityFromExecution,
  MaintenanceResetCounter,
  metadataWithMaintenanceClassification,
  parseFrozenMaintenanceClass,
  prepareMaintenanceCompletionWritePlan,
} from "./maintenanceIntelligence";
import {executionPath, maintenancePath} from "./paths";
import {JsonMap, LaneKey} from "./types";
import {cleanText, iso, persistedInstantText, stableJson} from "./utils";

const definitionPath = (id: string): string =>
  `maintenance_class_definitions/${id}`;
const auditPath = (commandId: string): string =>
  `maintenance_class_audits/${commandId}`;
const classificationAuditPath = (commandId: string): string =>
  `maintenance_classification_audits/${commandId}`;

const ASSET_TYPES = new Set([
  "base", "furnace", "forceCooler", "innerCover", "governedCustom",
]);
const LANES = new Set(["elec", "mech", "inst", "oprn", "emd", "red", "shared"]);
const DEFINITION_FIELDS = [
  "schemaVersion", "code", "title", "description", "assetTypeKeys",
  "assetClassIds", "principalLaneKey", "resetCounters",
] as const;

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  if (Object.keys(value).sort().join(",") !== [...expected].sort().join(",")) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "maintenance-class-shape-invalid", field},
    );
  }
};

const record = (value: unknown, field: string): JsonMap => {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new WorkflowError("invalid-argument", `${field} must be an object.`);
  }
  return value as JsonMap;
};

const documentId = (value: unknown, field: string): string => {
  const parsed = cleanText(value, field);
  if (parsed.length > 160 || parsed === "." || parsed === ".." || parsed.includes("/")) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  return parsed;
};

const boundedText = (
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): string => {
  const parsed = cleanText(value, field);
  if (parsed.length < minimum || parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} must contain ${minimum}-${maximum} characters.`,
    );
  }
  return parsed;
};

const stringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  allowEmpty = false,
): string[] => {
  if (!Array.isArray(value) || value.length > maximumItems ||
      (!allowEmpty && value.length === 0) ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.trim().length > 160)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  const parsed = value.map((item) => documentId(item, field));
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("invalid-argument", `${field} contains duplicates.`);
  }
  return parsed;
};

const normalizedCode = (value: unknown): string => {
  const code = boundedText(value, "definition.code", 2, 48).toUpperCase();
  if (!/^[A-Z0-9][A-Z0-9_-]+$/.test(code)) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.code must use uppercase letters, numbers, hyphens or underscores.",
    );
  }
  return code;
};

const parseResetCounter = (value: unknown, index: number): MaintenanceResetCounter => {
  const data = record(value, `definition.resetCounters[${index}]`);
  exactKeys(data, ["key", "label", "thresholdDays"], `definition.resetCounters[${index}]`);
  const key = normalizedCode(data.key);
  const thresholdDays = data.thresholdDays;
  if (thresholdDays != null &&
      (typeof thresholdDays !== "number" || !Number.isSafeInteger(thresholdDays) ||
       thresholdDays < 1 || thresholdDays > 3650)) {
    throw new WorkflowError(
      "invalid-argument",
      `definition.resetCounters[${index}].thresholdDays must be 1-3650 or null.`,
    );
  }
  return {
    key,
    label: boundedText(data.label, `definition.resetCounters[${index}].label`, 2, 120),
    thresholdDays: thresholdDays as number | null,
  };
};

interface ParsedDefinition {
  readonly code: string;
  readonly title: string;
  readonly description: string;
  readonly assetTypeKeys: readonly string[];
  readonly assetClassIds: readonly string[];
  readonly principalLaneKey: LaneKey;
  readonly resetCounters: readonly MaintenanceResetCounter[];
}

const parseDefinition = (value: unknown): ParsedDefinition => {
  const data = record(value, "definition");
  exactKeys(data, DEFINITION_FIELDS, "definition");
  if (data.schemaVersion !== 1) {
    throw new WorkflowError("invalid-argument", "definition.schemaVersion is unsupported.");
  }
  const assetTypeKeys = stringList(
    data.assetTypeKeys,
    "definition.assetTypeKeys",
    10,
    true,
  );
  if (assetTypeKeys.some((key) => !ASSET_TYPES.has(key))) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.assetTypeKeys contains an unsupported asset type.",
    );
  }
  const assetClassIds = stringList(
    data.assetClassIds,
    "definition.assetClassIds",
    30,
    true,
  );
  if (assetTypeKeys.length === 0 && assetClassIds.length === 0) {
    throw new WorkflowError(
      "invalid-argument",
      "A maintenance class must target at least one asset type or class.",
    );
  }
  const lane = cleanText(data.principalLaneKey, "definition.principalLaneKey");
  if (!LANES.has(lane)) {
    throw new WorkflowError("invalid-argument", "definition.principalLaneKey is unsupported.");
  }
  if (!Array.isArray(data.resetCounters) || data.resetCounters.length === 0 ||
      data.resetCounters.length > 12) {
    throw new WorkflowError("invalid-argument", "definition.resetCounters is invalid.");
  }
  const resetCounters = data.resetCounters.map(parseResetCounter);
  if (new Set(resetCounters.map((counter) => counter.key)).size !== resetCounters.length) {
    throw new WorkflowError("invalid-argument", "definition.resetCounters contains duplicate keys.");
  }
  return {
    code: normalizedCode(data.code),
    title: boundedText(data.title, "definition.title", 3, 160),
    description: boundedText(data.description, "definition.description", 5, 1000),
    assetTypeKeys,
    assetClassIds,
    principalLaneKey: lane as LaneKey,
    resetCounters,
  };
};

export const frozenMaintenanceClassFromDefinition = (
  definition: JsonMap,
): FrozenMaintenanceClass => parseFrozenMaintenanceClass({
  schemaVersion: 1,
  definitionId: definition.definitionId,
  definitionVersion: definition.version,
  code: definition.code,
  title: definition.title,
  assetTypeKeys: definition.assetTypeKeys,
  assetClassIds: definition.assetClassIds,
  resetCounters: definition.resetCounters,
  principalLaneKey: definition.principalLaneKey,
});

const writeDefinitionAudit = (args: {
  readonly tx: Parameters<CommandHandler>[0]["tx"];
  readonly commandId: string;
  readonly definitionId: string;
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
  definitionId: args.definitionId,
  operation: args.operation,
  performedByUid: args.actorUid,
  performedByName: args.actorName,
  performedAt: args.at,
  reason: args.reason,
  beforeJson: stableJson(args.before),
  afterJson: stableJson(args.after),
});

export const upsertMaintenanceClassDefinition: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["definition", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const definition = parseDefinition(command.payload.definition);
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current, matchingCodes, audit, ...classReferences] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    tx.query("maintenance_class_definitions", [
      {field: "normalizedCode", op: "==", value: definition.code},
    ]),
    tx.get(auditPath(command.commandId)),
    ...definition.assetClassIds.map((id) => tx.get(`asset_classes/${id}`)),
  ]);
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance-class audit evidence already exists without this receipt.",
      {reasonCode: "maintenance-class-audit-orphan"},
    );
  }
  const currentVersion = current.exists && current.data != null &&
      Number.isSafeInteger(current.data.version) ? current.data.version as number : 0;
  if (currentVersion !== command.expectedVersion) {
    throw new WorkflowError(
      "aborted",
      "The maintenance class changed before this request.",
      {reasonCode: "maintenance-class-version-conflict"},
    );
  }
  if (current.exists && (current.data == null || currentVersion < 1)) {
    throw new WorkflowError("failed-precondition", "The saved maintenance class is malformed.");
  }
  if (matchingCodes.some((row) => row.path !== definitionPath(definitionId))) {
    throw new WorkflowError(
      "already-exists",
      "Another maintenance class already uses this code.",
      {reasonCode: "maintenance-class-code-collision"},
    );
  }
  for (let index = 0; index < classReferences.length; index += 1) {
    const snapshot = classReferences[index];
    const expectedId = definition.assetClassIds[index];
    if (!snapshot.exists || snapshot.data == null ||
        snapshot.data.assetClassId !== expectedId || snapshot.data.status !== "active") {
      throw new WorkflowError(
        "failed-precondition",
        "An applicable asset class is missing or inactive.",
        {assetClassId: expectedId},
      );
    }
  }
  const now = iso(context.serverNow);
  const nextVersion = currentVersion + 1;
  const before = current.data ?? {};
  const after: JsonMap = {
    schemaVersion: 1,
    definitionId,
    version: nextVersion,
    status: current.data?.status === "retired" ? "retired" : "active",
    normalizedCode: definition.code,
    code: definition.code,
    title: definition.title,
    description: definition.description,
    assetTypeKeys: definition.assetTypeKeys,
    assetClassIds: definition.assetClassIds,
    principalLaneKey: definition.principalLaneKey,
    resetCounters: definition.resetCounters.map((counter) => ({
      key: counter.key,
      label: counter.label,
      thresholdDays: counter.thresholdDays,
    })),
    createdAt: current.data?.createdAt ?? now,
    createdByUid: current.data?.createdByUid ?? context.actor.uid,
    createdByName: current.data?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  if (current.exists) tx.update(definitionPath(definitionId), after);
  else tx.create(definitionPath(definitionId), after);
  writeDefinitionAudit({
    tx,
    commandId: command.commandId,
    definitionId,
    operation: current.exists ? "update" : "create",
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before,
    after,
  });
  return {
    resultKey: current.exists ?
      "maintenance-class-definition-updated" :
      "maintenance-class-definition-created",
    aggregateVersion: nextVersion,
    result: {definitionId, code: definition.code, status: after.status},
  };
};

export const setMaintenanceClassDefinitionStatus: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const status = cleanText(command.payload.status, "status");
  if (!new Set(["active", "retired"]).has(status)) {
    throw new WorkflowError("invalid-argument", "status is unsupported.");
  }
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current, audit] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    tx.get(auditPath(command.commandId)),
  ]);
  if (!current.exists || current.data == null) {
    throw new WorkflowError("not-found", "Maintenance class was not found.");
  }
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance-class audit evidence already exists without this receipt.",
    );
  }
  if (current.data.version !== command.expectedVersion) {
    throw new WorkflowError("aborted", "The maintenance class changed before this request.");
  }
  if (current.data.status === status) {
    throw new WorkflowError("failed-precondition", `The maintenance class is already ${status}.`);
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const after: JsonMap = {
    ...current.data,
    status,
    version: nextVersion,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  tx.update(definitionPath(definitionId), {
    status,
    version: nextVersion,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  });
  writeDefinitionAudit({
    tx,
    commandId: command.commandId,
    definitionId,
    operation: `set-${status}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: current.data,
    after,
  });
  return {
    resultKey: `maintenance-class-definition-${status}`,
    aggregateVersion: nextVersion,
    result: {definitionId, status},
  };
};

const dueProjectionFromSource = (
  path: string,
  counterKey: string,
  sources: readonly {readonly path: string; readonly data: JsonMap}[],
  now: string,
  fallback: {
    readonly assetIdentityKey: string;
    readonly assetTypeKey: string;
    readonly assetNumber: number | null;
    readonly assetClassId: string | null;
    readonly assetInstanceId: string | null;
    readonly assetDisplayName: string | null;
    readonly counterLabel: string;
    readonly thresholdDays: number | null;
  },
): JsonMap => {
  const candidates = sources
    .flatMap((source) => {
      const completedAt = persistedInstantText(source.data.completedAt);
      return Array.isArray(source.data.resetCounterKeys) &&
        (source.data.resetCounterKeys as unknown[]).includes(counterKey) &&
        completedAt != null ? [{...source, completedAt}] : [];
    })
    .sort((left, right) => {
      const byTime = Date.parse(right.completedAt) - Date.parse(left.completedAt);
      if (byTime !== 0) return byTime;
      return Number(right.data.sourceRevision ?? 0) - Number(left.data.sourceRevision ?? 0);
    });
  const latestCandidate = candidates[0];
  const latest = latestCandidate?.data;
  if (latest == null || latestCandidate == null) {
    return {
      schemaVersion: 1,
      dueStateId: path.split("/").at(-1)!,
      assetIdentityKey: fallback.assetIdentityKey,
      assetTypeKey: fallback.assetTypeKey,
      assetNumber: fallback.assetNumber,
      assetClassId: fallback.assetClassId,
      assetInstanceId: fallback.assetInstanceId,
      assetDisplayName: fallback.assetDisplayName,
      counterKey,
      counterLabel: fallback.counterLabel,
      thresholdDays: fallback.thresholdDays,
      lastCompletionAt: null,
      nextDueAt: null,
      lastCompletionEventId: null,
      lastCompletionSourceType: null,
      lastCompletionSourceId: null,
      lastMaintenanceClassCode: null,
      classificationPending: true,
      updatedAt: now,
    };
  }
  const classification = parseFrozenMaintenanceClass(latest.maintenanceClass);
  const counter = classification.resetCounters.find((item) => item.key === counterKey)!;
  const completedAt = latestCandidate.completedAt;
  const nextDue = counter.thresholdDays == null ? null : (() => {
    const date = new Date(completedAt);
    date.setUTCDate(date.getUTCDate() + counter.thresholdDays!);
    return date.toISOString();
  })();
  return {
    schemaVersion: 1,
    dueStateId: path.split("/").at(-1)!,
    assetIdentityKey: latest.assetIdentityKey,
    assetTypeKey: latest.assetTypeKey,
    assetNumber: latest.assetNumber,
    assetClassId: latest.assetClassId ?? null,
    assetInstanceId: latest.assetInstanceId ?? null,
    assetDisplayName: latest.assetDisplayName ?? null,
    counterKey,
    counterLabel: counter.label,
    thresholdDays: counter.thresholdDays,
    lastCompletionAt: completedAt,
    nextDueAt: nextDue,
    lastCompletionEventId: latest.currentEventId,
    lastCompletionSourceType: latest.sourceType,
    lastCompletionSourceId: latest.sourceId,
    lastMaintenanceClassCode: latest.maintenanceClassCode,
    classificationPending: false,
    updatedAt: now,
  };
};

const classificationRevision = (metadataJson: unknown): number => {
  if (typeof metadataJson !== "string" || metadataJson.trim().length === 0) return 0;
  try {
    const decoded = JSON.parse(metadataJson) as unknown;
    if (decoded == null || typeof decoded !== "object" || Array.isArray(decoded)) return 0;
    const value = (decoded as Record<string, unknown>).maintenanceClassificationRevision;
    return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ?
      value : 0;
  } catch (_) {
    return 0;
  }
};

export const classifyMaintenanceExecution: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["definitionId", "definitionVersion", "reason"], "payload");
  const executionId = documentId(command.aggregateId, "aggregateId");
  const definitionId = documentId(command.payload.definitionId, "definitionId");
  const definitionVersion = command.payload.definitionVersion;
  if (typeof definitionVersion !== "number" ||
      !Number.isSafeInteger(definitionVersion) || definitionVersion < 1) {
    throw new WorkflowError("invalid-argument", "definitionVersion is invalid.");
  }
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [execution, definition, audit] = await Promise.all([
    tx.get(executionPath(executionId)),
    tx.get(definitionPath(definitionId)),
    tx.get(classificationAuditPath(command.commandId)),
  ]);
  if (!execution.exists || execution.data == null) {
    throw new WorkflowError("not-found", "Planned-job execution was not found.");
  }
  if (!definition.exists || definition.data == null ||
      definition.data.status !== "active") {
    throw new WorkflowError("failed-precondition", "The maintenance class is missing or inactive.");
  }
  if (definition.data.version !== definitionVersion) {
    throw new WorkflowError(
      "aborted",
      "The maintenance class changed. Reload and retry.",
      {reasonCode: "maintenance-class-version-conflict"},
    );
  }
  if (execution.data.version !== command.expectedVersion) {
    throw new WorkflowError(
      "aborted",
      "The planned job changed before classification.",
      {reasonCode: "maintenance-execution-version-conflict"},
    );
  }
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance-classification audit evidence already exists without this receipt.",
    );
  }
  if (execution.data.isDeleted === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Deleted planned maintenance cannot be classified.",
      {reasonCode: "maintenance-execution-deleted"},
    );
  }
  if (execution.data.isCancelled === true) {
    throw new WorkflowError(
      "failed-precondition",
      "Cancelled maintenance cannot be classified as completed or active work.",
      {reasonCode: "maintenance-execution-cancelled"},
    );
  }
  const completed = execution.data.isCompleted === true;
  if (completed && !context.actor.roles.has("admin") && !context.actor.roles.has("si")) {
    throw new WorkflowError(
      "permission-denied",
      "Only Admin or SI can classify or correct completed maintenance.",
    );
  }
  const classification = frozenMaintenanceClassFromDefinition(definition.data);
  const identity = maintenanceAssetIdentityFromExecution(execution.data);
  assertMaintenanceClassApplies(classification, identity);
  const previous = frozenMaintenanceClassFromExecution(execution.data);
  const previousRevision = classificationRevision(execution.data.metadataJson);
  if (previous != null && previous.definitionId === classification.definitionId &&
      previous.definitionVersion === classification.definitionVersion) {
    throw new WorkflowError("failed-precondition", "This exact maintenance class is already assigned.");
  }
  const now = iso(context.serverNow);
  const revision = previousRevision + 1;
  const metadataJson = metadataWithMaintenanceClassification(
    execution.data.metadataJson,
    classification,
    revision,
    context.actor,
    now,
    reason,
  );
  const nextVersion = command.expectedVersion + 1;
  let completionPlan = null;
  let existingSources: readonly {readonly path: string; readonly data: JsonMap}[] = [];
  if (completed) {
    const completedAt = persistedInstantText(execution.data.completedAt);
    if (completedAt == null || Number.isNaN(Date.parse(completedAt))) {
      throw new WorkflowError(
        "failed-precondition",
        "Completed maintenance has no valid completion timestamp.",
      );
    }
    existingSources = (await tx.query("maintenance_completion_sources", [
      {field: "assetIdentityKey", op: "==", value: identity.assetIdentityKey},
    ])).filter((row) => row.data != null)
      .map((row) => ({path: row.path, data: row.data!}));
    completionPlan = await prepareMaintenanceCompletionWritePlan({
      tx,
      execution: execution.data,
      executionId,
      sourceType: execution.data.workflowSchemaVersion === 1 ?
        "workflowPlannedJob" : "legacyPlannedJob",
      completedAt,
      completedBy: {
        uid: typeof execution.data.completedByUid === "string" ?
          execution.data.completedByUid : context.actor.uid,
        name: typeof execution.data.completedByName === "string" ?
          execution.data.completedByName : context.actor.name,
        roles: context.actor.roles,
      },
      recordedAt: now,
      classification,
      classificationRevision: revision,
    });
  }
  tx.update(executionPath(executionId), {
    metadataJson,
    maintenanceClassificationPending: false,
    version: nextVersion,
    updatedAt: now,
  });
  tx.create(classificationAuditPath(command.commandId), {
    schemaVersion: 1,
    auditId: command.commandId,
    executionId,
    operation: previous == null ? "classify" : "correct-classification",
    classificationRevision: revision,
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    performedAt: now,
    reason,
    beforeJson: stableJson(previous == null ? {} : previous as unknown as JsonMap),
    afterJson: stableJson(classification as unknown as JsonMap),
    completionEffectiveAt: completed ? execution.data.completedAt : null,
  });
  applyMaintenanceCompletionWritePlan(tx, completionPlan);
  if (completed && completionPlan != null && previous != null) {
    const sources = [
      ...existingSources.filter((source) => source.path !== completionPlan!.sourcePath),
      {path: completionPlan.sourcePath, data: completionPlan.sourceData},
    ];
    const affectedCounters = new Set([
      ...previous.resetCounters.map((counter) => counter.key),
      ...classification.resetCounters.map((counter) => counter.key),
    ]);
    for (const counterKey of affectedCounters) {
      const path = dueStatePath(identity.assetIdentityKey, counterKey);
      const counter = classification.resetCounters.find((item) =>
        item.key === counterKey) ?? previous.resetCounters.find((item) =>
        item.key === counterKey)!;
      tx.set(path, dueProjectionFromSource(path, counterKey, sources, now, {
        assetIdentityKey: identity.assetIdentityKey,
        assetTypeKey: identity.assetTypeKey,
        assetNumber: identity.assetNumber,
        assetClassId: identity.assetClassId,
        assetInstanceId: identity.assetInstanceId,
        assetDisplayName: null,
        counterLabel: counter.label,
        thresholdDays: counter.thresholdDays,
      }), true);
    }
  }
  return {
    resultKey: completed ?
      (previous == null ? "completed-maintenance-classified" :
        "completed-maintenance-classification-corrected") :
      (previous == null ? "maintenance-class-assigned" :
        "maintenance-classification-corrected"),
    aggregateVersion: nextVersion,
    result: {
      executionId,
      maintenanceClassCode: classification.code,
      classificationRevision: revision,
      completionEventId: completionPlan?.eventId ?? null,
      completionEffectiveAt: completed ? execution.data.completedAt : null,
    },
  };
};

const maintenanceTicketCompletionRecord = (ticket: JsonMap): JsonMap => {
  const assetTypeKey = cleanText(ticket.assetType, "ticket.assetType");
  if (assetTypeKey === "innerCover") {
    throw new WorkflowError(
      "failed-precondition",
      "Inner Cover cadence must be recorded against its serial-based maintenance plan.",
      {reasonCode: "maintenance-ticket-inner-cover-serial-required"},
    );
  }
  const assetNumber = ticket.assetNumber;
  if (!Number.isSafeInteger(assetNumber) || (assetNumber as number) < 1) {
    throw new WorkflowError("failed-precondition", "The issue asset number is invalid.");
  }
  if (typeof ticket.assetHierarchyRefJson !== "string" ||
      ticket.assetHierarchyRefJson.trim().length === 0) {
    throw new WorkflowError(
      "failed-precondition",
      "The resolved issue has no frozen governed asset identity.",
    );
  }
  let rawReference: unknown;
  try {
    rawReference = JSON.parse(ticket.assetHierarchyRefJson);
  } catch (_) {
    throw new WorkflowError(
      "failed-precondition",
      "The resolved issue asset identity is malformed.",
    );
  }
  const reference = record(rawReference, "ticket.assetHierarchyRefJson");
  if (![3, 4].includes(reference.schemaVersion as number) ||
      !["physicalAsset", "installedComponent", "componentDefinitionOnAsset"]
        .includes(String(reference.scope)) ||
      reference.assetNumber !== assetNumber) {
    throw new WorkflowError(
      "failed-precondition",
      "The resolved issue does not carry an exact physical asset identity.",
      {reasonCode: "maintenance-ticket-asset-identity-invalid"},
    );
  }
  const assetClassId = documentId(reference.assetClassId, "assetClassId");
  const assetInstanceId = documentId(reference.assetInstanceId, "assetInstanceId");
  const assetInstanceName = boundedText(
    reference.assetInstanceName,
    "assetInstanceName",
    1,
    160,
  );
  return {
    ...ticket,
    assetTypeKey,
    assetNumber: assetNumber as number,
    assetClassId,
    assetInstanceId,
    assetInstanceName,
  };
};

export const classifyMaintenanceTicket: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["definitionId", "definitionVersion", "reason"], "payload");
  if (!context.actor.roles.has("admin") && !context.actor.roles.has("si")) {
    throw new WorkflowError(
      "permission-denied",
      "Only Admin or SI can classify completed maintenance issues.",
    );
  }
  const ticketId = documentId(command.aggregateId, "aggregateId");
  const definitionId = documentId(command.payload.definitionId, "definitionId");
  const definitionVersion = command.payload.definitionVersion;
  if (typeof definitionVersion !== "number" ||
      !Number.isSafeInteger(definitionVersion) || definitionVersion < 1) {
    throw new WorkflowError("invalid-argument", "definitionVersion is invalid.");
  }
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [ticket, definition, audit] = await Promise.all([
    tx.get(maintenancePath(ticketId)),
    tx.get(definitionPath(definitionId)),
    tx.get(classificationAuditPath(command.commandId)),
  ]);
  if (!ticket.exists || ticket.data == null) {
    throw new WorkflowError("not-found", "Maintenance issue was not found.");
  }
  if (ticket.data.version !== command.expectedVersion) {
    throw new WorkflowError(
      "aborted",
      "The maintenance issue changed before classification.",
      {reasonCode: "maintenance-ticket-version-conflict"},
    );
  }
  if (ticket.data.isDeleted === true || ticket.data.isResolved !== true ||
      ticket.data.status !== "resolved") {
    throw new WorkflowError(
      "failed-precondition",
      "Only a final resolved maintenance issue can be classified.",
    );
  }
  if (!definition.exists || definition.data == null ||
      definition.data.status !== "active" || definition.data.version !== definitionVersion) {
    throw new WorkflowError(
      "aborted",
      "The selected maintenance class is missing, inactive or changed.",
    );
  }
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Maintenance-classification audit evidence already exists without this receipt.",
    );
  }
  const completedAt = persistedInstantText(ticket.data.endDate);
  const now = iso(context.serverNow);
  if (completedAt == null || Number.isNaN(Date.parse(completedAt))) {
    throw new WorkflowError(
      "failed-precondition",
      "The resolved maintenance issue has no valid completion timestamp.",
    );
  }
  const ageMilliseconds = Date.parse(now) - Date.parse(completedAt);
  if (ageMilliseconds < 4 * 60 * 60 * 1000) {
    throw new WorkflowError(
      "failed-precondition",
      "Classify the issue after its four-hour reopen window has elapsed.",
      {reasonCode: "maintenance-ticket-reopen-window-active"},
    );
  }
  const completionRecord = maintenanceTicketCompletionRecord(ticket.data);
  const identity = maintenanceAssetIdentityFromExecution(completionRecord);
  const classification = frozenMaintenanceClassFromDefinition(definition.data);
  assertMaintenanceClassApplies(classification, identity);
  const previous = frozenMaintenanceClassFromExecution(ticket.data);
  const previousRevision = classificationRevision(ticket.data.metadataJson);
  if (previous != null && previous.definitionId === classification.definitionId &&
      previous.definitionVersion === classification.definitionVersion) {
    throw new WorkflowError("failed-precondition", "This exact maintenance class is already assigned.");
  }
  const revision = previousRevision + 1;
  const metadataJson = metadataWithMaintenanceClassification(
    ticket.data.metadataJson,
    classification,
    revision,
    context.actor,
    now,
    reason,
  );
  const existingSources = (await tx.query("maintenance_completion_sources", [
    {field: "assetIdentityKey", op: "==", value: identity.assetIdentityKey},
  ])).filter((row) => row.data != null)
    .map((row) => ({path: row.path, data: row.data!}));
  const completionPlan = await prepareMaintenanceCompletionWritePlan({
    tx,
    execution: completionRecord,
    executionId: ticketId,
    sourceType: "maintenanceIssue",
    completedAt,
    completedBy: {
      uid: typeof ticket.data.closedByUid === "string" ?
        ticket.data.closedByUid : context.actor.uid,
      name: typeof ticket.data.closedByName === "string" ?
        ticket.data.closedByName : context.actor.name,
      roles: context.actor.roles,
    },
    recordedAt: now,
    classification,
    classificationRevision: revision,
  });
  const nextVersion = command.expectedVersion + 1;
  tx.update(maintenancePath(ticketId), {
    metadataJson,
    maintenanceClassificationPending: false,
    version: nextVersion,
    updatedAt: now,
  });
  tx.create(classificationAuditPath(command.commandId), {
    schemaVersion: 1,
    auditId: command.commandId,
    sourceType: "maintenanceIssue",
    maintenanceTicketId: ticketId,
    operation: previous == null ? "classify" : "correct-classification",
    classificationRevision: revision,
    performedByUid: context.actor.uid,
    performedByName: context.actor.name,
    performedAt: now,
    reason,
    beforeJson: stableJson(previous == null ? {} : previous as unknown as JsonMap),
    afterJson: stableJson(classification as unknown as JsonMap),
    completionEffectiveAt: completedAt,
  });
  applyMaintenanceCompletionWritePlan(tx, completionPlan);
  if (completionPlan != null && previous != null) {
    const sources = [
      ...existingSources.filter((source) => source.path !== completionPlan.sourcePath),
      {path: completionPlan.sourcePath, data: completionPlan.sourceData},
    ];
    const affectedCounters = new Set([
      ...previous.resetCounters.map((counter) => counter.key),
      ...classification.resetCounters.map((counter) => counter.key),
    ]);
    for (const counterKey of affectedCounters) {
      const path = dueStatePath(identity.assetIdentityKey, counterKey);
      const counter = classification.resetCounters.find((item) =>
        item.key === counterKey) ?? previous.resetCounters.find((item) =>
        item.key === counterKey)!;
      tx.set(path, dueProjectionFromSource(path, counterKey, sources, now, {
        assetIdentityKey: identity.assetIdentityKey,
        assetTypeKey: identity.assetTypeKey,
        assetNumber: identity.assetNumber,
        assetClassId: identity.assetClassId,
        assetInstanceId: identity.assetInstanceId,
        assetDisplayName: null,
        counterLabel: counter.label,
        thresholdDays: counter.thresholdDays,
      }), true);
    }
  }
  return {
    resultKey: previous == null ?
      "completed-maintenance-issue-classified" :
      "completed-maintenance-issue-classification-corrected",
    aggregateVersion: nextVersion,
    result: {
      maintenanceTicketId: ticketId,
      maintenanceClassCode: classification.code,
      classificationRevision: revision,
      completionEventId: completionPlan?.eventId ?? null,
      completionEffectiveAt: completedAt,
    },
  };
};
