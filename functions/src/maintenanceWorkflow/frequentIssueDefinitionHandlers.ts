import {WorkflowError} from "./errors";
import {CommandHandler} from "./handlerTypes";
import {JsonMap} from "./types";
import {cleanText, iso, stableJson} from "./utils";

const ASSET_TYPES = new Set([
  "base", "furnace", "forceCooler", "innerCover", "governedCustom",
]);
const MAINTENANCE_TYPES = new Set([
  "scheduled", "breakdown", "performance", "inspection", "overhaul",
]);
const ROUTES = new Set([
  "operations", "electrical", "mechanical", "instrumentation",
  "refractory", "emd", "shiftInCharge", "others",
]);
const SEVERITIES = new Set(["normal", "critical"]);
const EVIDENCE_FIELDS = new Set([
  "chargeNo", "photo", "observation", "measurement", "alarmText",
  "operatingContext",
]);
const WORKFLOW_PROFILES = new Set(["furnaceStuckup"]);
const DEFINITION_FIELDS = [
  "schemaVersion", "code", "title", "description",
  "applicableAssetTypeKeys", "applicableAssetClassIds",
  "applicableComponentNodeIds", "suggestedSeverityKey",
  "suggestedMaintenanceTypeKey", "defaultRouteKey",
  "requiredEvidenceFields", "aliases", "codeOwnedWorkflowProfile",
] as const;

const definitionPath = (id: string): string =>
  `frequent_issue_definitions/${id}`;
const auditPath = (commandId: string): string =>
  `frequent_issue_definition_audits/${commandId}`;

const exactKeys = (
  value: JsonMap,
  expected: readonly string[],
  field: string,
): void => {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} has unsupported or missing fields.`,
      {reasonCode: "frequent-issue-definition-shape-invalid", field},
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
  if (parsed.length > 160 || parsed === "." || parsed === ".." ||
      parsed.includes("/")) {
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

const optionalText = (
  value: unknown,
  field: string,
  maximum: number,
): string | null => {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new WorkflowError("invalid-argument", `${field} must be text or null.`);
  }
  const parsed = value.trim();
  if (parsed.length === 0) return null;
  if (parsed.length > maximum) {
    throw new WorkflowError(
      "invalid-argument",
      `${field} cannot exceed ${maximum} characters.`,
    );
  }
  return parsed;
};

const stringList = (
  value: unknown,
  field: string,
  maximumItems: number,
  maximumLength: number,
): string[] => {
  if (!Array.isArray(value) || value.length > maximumItems ||
      value.some((item) => typeof item !== "string" ||
        item.trim().length === 0 || item.trim().length > maximumLength)) {
    throw new WorkflowError("invalid-argument", `${field} is invalid.`);
  }
  const parsed = value.map((item) => (item as string).trim());
  if (new Set(parsed).size !== parsed.length) {
    throw new WorkflowError("invalid-argument", `${field} contains duplicates.`);
  }
  return parsed;
};

const choice = (
  value: unknown,
  field: string,
  allowed: ReadonlySet<string>,
): string => {
  const parsed = cleanText(value, field);
  if (!allowed.has(parsed)) {
    throw new WorkflowError("invalid-argument", `${field} is unsupported.`);
  }
  return parsed;
};

const normalizedCode = (value: unknown): string => {
  const code = boundedText(value, "definition.code", 2, 40).toUpperCase();
  if (!/^[A-Z0-9][A-Z0-9_-]+$/.test(code)) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.code must use uppercase letters, numbers, hyphens or underscores.",
    );
  }
  return code;
};

interface ParsedDefinition {
  readonly code: string;
  readonly title: string;
  readonly description: string;
  readonly applicableAssetTypeKeys: readonly string[];
  readonly applicableAssetClassIds: readonly string[];
  readonly applicableComponentNodeIds: readonly string[];
  readonly suggestedSeverityKey: string;
  readonly suggestedMaintenanceTypeKey: string;
  readonly defaultRouteKey: string;
  readonly requiredEvidenceFields: readonly string[];
  readonly aliases: readonly string[];
  readonly codeOwnedWorkflowProfile: string | null;
}

const parseDefinition = (value: unknown): ParsedDefinition => {
  const data = record(value, "definition");
  exactKeys(data, DEFINITION_FIELDS, "definition");
  if (data.schemaVersion !== 1) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.schemaVersion is unsupported.",
    );
  }
  const applicableAssetTypeKeys = stringList(
    data.applicableAssetTypeKeys,
    "definition.applicableAssetTypeKeys",
    10,
    40,
  );
  if (applicableAssetTypeKeys.some((item) => !ASSET_TYPES.has(item))) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.applicableAssetTypeKeys contains an unsupported asset type.",
    );
  }
  const applicableAssetClassIds = stringList(
    data.applicableAssetClassIds,
    "definition.applicableAssetClassIds",
    30,
    160,
  ).map((item) => documentId(item, "definition.applicableAssetClassIds"));
  if (applicableAssetTypeKeys.length === 0 &&
      applicableAssetClassIds.length === 0) {
    throw new WorkflowError(
      "invalid-argument",
      "A frequent issue must target at least one asset type or class.",
    );
  }
  const requiredEvidenceFields = stringList(
    data.requiredEvidenceFields,
    "definition.requiredEvidenceFields",
    10,
    40,
  );
  if (requiredEvidenceFields.some((item) => !EVIDENCE_FIELDS.has(item))) {
    throw new WorkflowError(
      "invalid-argument",
      "definition.requiredEvidenceFields contains an unsupported field.",
    );
  }
  const profile = optionalText(
    data.codeOwnedWorkflowProfile,
    "definition.codeOwnedWorkflowProfile",
    80,
  );
  if (profile != null && !WORKFLOW_PROFILES.has(profile)) {
    throw new WorkflowError(
      "invalid-argument",
      "The requested code-owned workflow profile is not implemented.",
    );
  }
  return {
    code: normalizedCode(data.code),
    title: boundedText(data.title, "definition.title", 3, 160),
    description: boundedText(
      data.description,
      "definition.description",
      5,
      1000,
    ),
    applicableAssetTypeKeys,
    applicableAssetClassIds,
    applicableComponentNodeIds: stringList(
      data.applicableComponentNodeIds,
      "definition.applicableComponentNodeIds",
      100,
      160,
    ).map((item) => documentId(item, "definition.applicableComponentNodeIds")),
    suggestedSeverityKey: choice(
      data.suggestedSeverityKey,
      "definition.suggestedSeverityKey",
      SEVERITIES,
    ),
    suggestedMaintenanceTypeKey: choice(
      data.suggestedMaintenanceTypeKey,
      "definition.suggestedMaintenanceTypeKey",
      MAINTENANCE_TYPES,
    ),
    defaultRouteKey: choice(
      data.defaultRouteKey,
      "definition.defaultRouteKey",
      ROUTES,
    ),
    requiredEvidenceFields,
    aliases: stringList(data.aliases, "definition.aliases", 20, 120),
    codeOwnedWorkflowProfile: profile,
  };
};

const writeAudit = (args: {
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

export const upsertFrequentIssueDefinition: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["definition", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const definition = parseDefinition(command.payload.definition);
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current, matchingCodes, audit, ...references] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    tx.query("frequent_issue_definitions", [
      {field: "normalizedCode", op: "==", value: definition.code},
    ]),
    tx.get(auditPath(command.commandId)),
    ...definition.applicableAssetClassIds.map((id) =>
      tx.get(`asset_classes/${id}`)),
    ...definition.applicableComponentNodeIds.map((id) =>
      tx.get(`asset_hierarchy_nodes/${id}`)),
  ]);
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Frequent-issue audit evidence already exists without this receipt.",
      {reasonCode: "frequent-issue-audit-orphan"},
    );
  }
  const currentVersion = current.exists && current.data != null &&
      Number.isSafeInteger(current.data.version) ? current.data.version as number : 0;
  if (currentVersion !== command.expectedVersion) {
    throw new WorkflowError(
      "aborted",
      "The frequent-issue definition changed before this request.",
      {reasonCode: "frequent-issue-version-conflict"},
    );
  }
  if (current.exists && (current.data == null || currentVersion < 1)) {
    throw new WorkflowError(
      "failed-precondition",
      "The saved frequent-issue definition is malformed.",
    );
  }
  const collision = matchingCodes.find((row) =>
    row.path !== definitionPath(definitionId));
  if (collision != null) {
    throw new WorkflowError(
      "already-exists",
      "Another frequent issue already uses this code.",
      {reasonCode: "frequent-issue-code-collision", path: collision.path},
    );
  }

  const classReferences = references.slice(
    0,
    definition.applicableAssetClassIds.length,
  );
  const nodeReferences = references.slice(
    definition.applicableAssetClassIds.length,
  );
  for (let index = 0; index < classReferences.length; index += 1) {
    const snapshot = classReferences[index];
    const expectedId = definition.applicableAssetClassIds[index];
    if (!snapshot.exists || snapshot.data == null ||
        snapshot.data.assetClassId !== expectedId ||
        snapshot.data.status !== "active") {
      throw new WorkflowError(
        "failed-precondition",
        "An applicable asset class is missing or inactive.",
        {assetClassId: expectedId},
      );
    }
  }
  for (let index = 0; index < nodeReferences.length; index += 1) {
    const snapshot = nodeReferences[index];
    const expectedId = definition.applicableComponentNodeIds[index];
    const node = snapshot.data;
    if (!snapshot.exists || node == null || node.nodeId !== expectedId ||
        node.status !== "active" ||
        !["component", "subcomponent"].includes(String(node.nodeType))) {
      throw new WorkflowError(
        "failed-precondition",
        "An applicable component definition is missing or inactive.",
        {nodeId: expectedId},
      );
    }
    const nodeClassId = documentId(
      node.assetClassId,
      "assetHierarchyNode.assetClassId",
    );
    if (!definition.applicableAssetClassIds.includes(nodeClassId)) {
      const nodeClass = await tx.get(`asset_classes/${nodeClassId}`);
      if (!nodeClass.exists || nodeClass.data == null ||
          nodeClass.data.assetClassId !== nodeClassId ||
          nodeClass.data.status !== "active" ||
          typeof nodeClass.data.legacyAssetTypeKey !== "string" ||
          !definition.applicableAssetTypeKeys.includes(
            nodeClass.data.legacyAssetTypeKey,
          )) {
        throw new WorkflowError(
          "failed-precondition",
          "An applicable component is outside the definition's asset scope.",
          {nodeId: expectedId, assetClassId: nodeClassId},
        );
      }
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
    ...definition,
    createdAt: current.data?.createdAt ?? now,
    createdByUid: current.data?.createdByUid ?? context.actor.uid,
    createdByName: current.data?.createdByName ?? context.actor.name,
    updatedAt: now,
    updatedByUid: context.actor.uid,
    updatedByName: context.actor.name,
  };
  if (current.exists) tx.update(definitionPath(definitionId), after);
  else tx.create(definitionPath(definitionId), after);
  writeAudit({
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
      "frequent-issue-definition-updated" :
      "frequent-issue-definition-created",
    aggregateVersion: nextVersion,
    result: {definitionId, code: definition.code, status: after.status},
  };
};

export const setFrequentIssueDefinitionStatus: CommandHandler = async ({
  tx,
  command,
  context,
}) => {
  exactKeys(command.payload, ["status", "reason"], "payload");
  const definitionId = documentId(command.aggregateId, "aggregateId");
  const status = choice(
    command.payload.status,
    "status",
    new Set(["active", "retired"]),
  );
  const reason = boundedText(command.payload.reason, "reason", 5, 500);
  const [current, audit] = await Promise.all([
    tx.get(definitionPath(definitionId)),
    tx.get(auditPath(command.commandId)),
  ]);
  const data = current.data;
  if (!current.exists || data == null) {
    throw new WorkflowError("not-found", "Frequent-issue definition was not found.");
  }
  if (audit.exists) {
    throw new WorkflowError(
      "failed-precondition",
      "Frequent-issue audit evidence already exists without this receipt.",
      {reasonCode: "frequent-issue-audit-orphan"},
    );
  }
  if (data.version !== command.expectedVersion) {
    throw new WorkflowError(
      "aborted",
      "The frequent-issue definition changed before this request.",
      {reasonCode: "frequent-issue-version-conflict"},
    );
  }
  if (data.status === status) {
    throw new WorkflowError(
      "failed-precondition",
      `The frequent-issue definition is already ${status}.`,
    );
  }
  const now = iso(context.serverNow);
  const nextVersion = command.expectedVersion + 1;
  const after: JsonMap = {
    ...data,
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
  writeAudit({
    tx,
    commandId: command.commandId,
    definitionId,
    operation: `set-${status}`,
    actorUid: context.actor.uid,
    actorName: context.actor.name,
    at: now,
    reason,
    before: data,
    after,
  });
  return {
    resultKey: `frequent-issue-definition-${status}`,
    aggregateVersion: nextVersion,
    result: {definitionId, status},
  };
};
